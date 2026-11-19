# GlobalEvents.gd
# ─────────────────────────────────────────────────────────────────────────────
# Autoload Singleton — BUS GLOBAL DE EVENTOS.
#
# Es la columna vertebral que DESACOPLA los grandes sistemas del juego (Sistema
# Narrativo, Mapamundi, Mazmorras, Combate, Estado Global...). Ningún sistema
# modifica directamente a otro: en su lugar EMITE un evento con nombre y cualquier
# otro sistema decide si REACCIONA suscribiéndose a él.
#
# Ejemplo del flujo previsto por la tarea:
#   · Una escena narrativa ejecuta un nodo de Evento → GlobalEvents.emit_event("EVENT_DAM_OPENED").
#   · El Sistema Narrativo NO sabe qué significa ese evento; solo lo emite.
#   · El Mapamundi (TabWorld3D/QuestManager) se ha suscrito a "EVENT_DAM_OPENED" y
#     reacciona transformando el terreno.
#
# Filosofía:
#   · Un evento es un NOMBRE (String) + un PAYLOAD opcional (Dictionary).
#   · El emisor nunca conoce a los receptores.
#   · Los receptores nunca conocen al emisor.
#   · La comunicación es siempre unidireccional (fire-and-forget).
#
# Este bus NO ejecuta lógica de juego por sí mismo: solo entrega eventos. La
# lógica vive en cada sistema receptor. Así el motor puede crecer añadiendo
# sistemas nuevos sin tocar a los existentes.
# ─────────────────────────────────────────────────────────────────────────────
extends Node

## Señal genérica: se emite para CUALQUIER evento del juego. Los sistemas que
## quieran observar todos los eventos (p. ej. logros, telemetría, depuración)
## pueden conectarse aquí. `name` es el id del evento; `payload` sus datos.
signal event(name: String, payload: Dictionary)

## Emitida cuando cambia el tema visual de la interfaz (`UiKit.THEMES`). Bus
## GLOBAL estandarizado para el cambio de tema — `Locale.theme_changed` sigue
## existiendo por compatibilidad (algunas vistas ya se conectaban a ella),
## pero cualquier sistema NUEVO debe preferir esta señal. Se emite desde el
## único punto de mutación real, `Locale.set_ui_theme_id()`.
@warning_ignore("unused_signal")
signal theme_changed(theme_id: String)

## Registro de suscriptores por nombre de evento: { "EVENT_X": [Callable, ...] }.
## Se usa para el enrutado dirigido (subscribe/unsubscribe), complementario a la
## señal genérica `event`.
var _subscribers: Dictionary = {}

## Historial ligero de los últimos eventos emitidos (para depuración en el editor
## o paneles de QA). No es la fuente de verdad de nada; solo diagnóstico.
var _log: Array[Dictionary] = []
const LOG_LIMIT: int = 100


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════

## Emite un evento global. `event_name` es un identificador estable (por convención
## en MAYÚSCULAS con prefijo EVENT_, p. ej. "EVENT_DAM_OPENED"). `payload` lleva
## datos opcionales que los receptores pueden usar (coords, ids, cantidades...).
##
## Notifica primero a los suscriptores dirigidos de ese nombre y después emite la
## señal genérica `event` para los observadores globales.
func emit_event(event_name: String, payload: Dictionary = {}) -> void:
	if event_name.is_empty():
		push_warning("GlobalEvents: se intentó emitir un evento con nombre vacío.")
		return
	_record(event_name, payload)
	# 1) Suscriptores dirigidos a este evento concreto.
	var subs: Array = _subscribers.get(event_name, [])
	# Iteramos sobre una copia: un receptor podría des/suscribirse durante la entrega.
	for cb in subs.duplicate():
		if cb is Callable:
			var c: Callable = cb as Callable
			if c.is_valid():
				var target_obj: Object = c.get_object()
				# `is_instance_valid()` por sí solo no basta: un nodo puede seguir
				# "válido" para esa comprobación mientras está a medio liberar
				# (p. ej. `queue_free()` llamado en el mismo fotograma en el que
				# se emite este evento, como al derrotar a un jefe y desmontar la
				# vista de combate/mazmorra) y aun así hacer que `c.call()` reviente
				# con "Trying to call a lambda with an invalid instance". Exigimos
				# también que, si es un Node, no esté ya en cola de borrado.
				var target_ok: bool = target_obj == null or (is_instance_valid(target_obj) and not (target_obj is Node and (target_obj as Node).is_queued_for_deletion()))
				if target_ok:
					c.call(payload)
				else:
					# Instancia liberada (o a punto de liberarse): desuscribir automáticamente.
					subs.erase(cb)
			else:
				subs.erase(cb)
	# 2) Observadores globales (cualquier evento).
	event.emit(event_name, payload)


## Suscribe un Callable a un evento concreto. El Callable recibirá el `payload`
## (Dictionary) como único argumento. Devuelve true si se registró (false si ya
## estaba suscrito ese mismo Callable a ese evento).
func subscribe(event_name: String, callback: Callable) -> bool:
	if event_name.is_empty() or not callback.is_valid():
		return false
	if not _subscribers.has(event_name):
		_subscribers[event_name] = []
	var arr: Array = _subscribers[event_name]
	if arr.has(callback):
		return false
	arr.append(callback)
	return true


## Cancela la suscripción de un Callable a un evento concreto.
func unsubscribe(event_name: String, callback: Callable) -> void:
	if not _subscribers.has(event_name):
		return
	var arr: Array = _subscribers[event_name]
	arr.erase(callback)
	if arr.is_empty():
		_subscribers.erase(event_name)


## Elimina TODAS las suscripciones asociadas a un objeto concreto (útil cuando un
## nodo receptor se libera: `GlobalEvents.unsubscribe_object(self)` en _exit_tree).
func unsubscribe_object(obj: Object) -> void:
	for event_name in _subscribers.keys():
		var arr: Array = _subscribers[event_name]
		for cb in arr.duplicate():
			if cb is Callable:
				var c: Callable = cb as Callable
				var target: Object = c.get_object()
				if target == obj or target == null or not is_instance_valid(target):
					arr.erase(cb)
		if arr.is_empty():
			_subscribers.erase(event_name)


## Devuelve el historial reciente de eventos (más nuevos al final). Solo diagnóstico.
func get_log() -> Array[Dictionary]:
	return _log


## Vacía el historial de eventos.
func clear_log() -> void:
	_log.clear()


# ══════════════════════════════════════════════════════════════════════════════
# INTERNOS
# ══════════════════════════════════════════════════════════════════════════════

## Registra un evento en el historial de diagnóstico, acotado a LOG_LIMIT entradas.
func _record(event_name: String, payload: Dictionary) -> void:
	_log.append({"name": event_name, "payload": payload})
	if _log.size() > LOG_LIMIT:
		_log = _log.slice(_log.size() - LOG_LIMIT)
