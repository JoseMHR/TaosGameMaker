# SceneRunner.gd
# ─────────────────────────────────────────────────────────────────────────────
# Autoload Singleton — INTÉRPRETE DEL SISTEMA NARRATIVO.
#
# Ejecuta una ESCENA (grafo de nodos definido en scenes.json) nodo a nodo. Es el
# corazón del Sistema Narrativo unificado: una sola pieza capaz de representar
# conversaciones, carteles, tutoriales, cinemáticas, recuerdos, finales... todo
# con el mismo motor.
#
# RESPONSABILIDADES (y solo estas):
#   · Recorrer el grafo: resolver el siguiente nodo según su tipo.
#   · Aplicar la LÓGICA de los nodos que no necesitan UI (state/event/flow),
#     reutilizando el mini-lenguaje (Design.apply_reward) y el evaluador de
#     condiciones (Design.eval_condition) ya existentes.
#   · Delegar la PRESENTACIÓN de los nodos narrativos (say/choice) a una vista
#     desacoplada (NarrativeView) mediante señales. El runner NO dibuja nada.
#   · Gestionar la pila de SUBESCENAS (nodo flow "call") para reutilizar escenas.
#
# DESACOPLE: el runner nunca toca Mapamundi/Combate/Mazmorras directamente. Para
# eso emite eventos globales (nodo "event" → GlobalEvents). La UI le devuelve el
# control llamando a advance() / choose(idx).
#
# Cada nodo tiene UNA responsabilidad (Objetivo 2 de la tarea):
#   · say    → mostrar texto/narración/pensamiento (con retrato y fx). next.
#   · choice → ramificar mediante opciones (cada una con condición y destino).
#   · state  → modificar SOLO el Estado Global (ops del mini-lenguaje). next.
#   · event  → emitir un evento global (emit). next.
#   · flow   → control de flujo: goto | call | branch | wait | end.
# ─────────────────────────────────────────────────────────────────────────────
extends Node

## Nodos narrativos: la UI (NarrativeView) los escucha y presenta.
## `data` de say: { speaker, portrait, text, fx, kind:"say" }.
signal say_shown(data: Dictionary)
## `options` de choice: [{ text:String, index:int }] ya filtradas por condición.
## `prompt` es el texto opcional de la pregunta.
signal choice_shown(prompt: String, options: Array)
## La escena de nivel superior ha terminado (se vació la pila). `scene_id` es la raíz.
signal scene_finished(scene_id: String)
## Una escena de nivel superior acaba de empezar.
signal scene_started(scene_id: String)

## Pila de marcos de ejecución (uno por escena/subescena activa). El último es el
## activo. Cada marco: { scene_id, nodes, ctx_npc, return_node, current }.
var _stack: Array[Dictionary] = []

## PRESENTER EXTERNO: normalmente la NarrativeOverlay global
## presenta las escenas. Pero algunas vistas (p. ej. ViewBuilding/ViewPlace)
## quieren presentar la MISMA escena con su propia UI a pantalla completa. Cuando
## una vista "adquiere" la presentación, la NarrativeOverlay se inhibe y esa vista
## se encarga de dibujar say/choice (sigue usando este runner como motor). Así hay
## un solo motor con presentación conmutable, sin duplicar lógica de grafo.
var _presenter: Object = null


## Una vista toma el control de la presentación (se conecta ella misma a las
## señales say_shown/choice_shown/scene_finished). Idempotente por instancia.
func acquire_presenter(who: Object) -> void:
	_presenter = who


## Libera la presentación si `who` es quien la tenía (vuelve a mandar la overlay).
func release_presenter(who: Object) -> void:
	if _presenter == who:
		_presenter = null


## ¿Hay una vista presentando en lugar de la NarrativeOverlay global?
func has_external_presenter() -> bool:
	return _presenter != null and is_instance_valid(_presenter)


## ¿Es `who` quien tiene la presentación? Lo usan las vistas para ignorar señales
## de escenas que no les pertenecen.
func is_presenter(who: Object) -> bool:
	return _presenter == who


## Devuelve el `kind` del nodo al que saltaría advance() desde el `say` actual, sin
## ejecutar nada (solo mira `next` un paso). Devuelve "end" si cierra y "" si el
## nodo actual no es un say. Lo usa un presenter externo para decidir si tras el
## texto muestra opciones (choice) o un botón de continuar (say/end).
func peek_next_kind() -> String:
	if not is_active():
		return "end"
	var node := _current_node()
	if String(node.get("kind", "")) != "say":
		return ""
	var nodes: Dictionary = _top().get("nodes", {})
	var nxt := _next_of(node)
	var steps := 0
	while steps < 32:
		steps += 1
		if nxt == "" or nxt == "end" or nxt == "close":
			return "end"
		var target = nodes.get(nxt, {})
		if not (target is Dictionary):
			return "end"
		var k := String(target.get("kind", ""))
		if k == "state" or k == "event" or k == "flow":
			var op := String(target.get("op", ""))
			if op == "end":
				return "end"
			elif op == "reload_npc":
				var npc_id := String(target.get("npc_id", _ctx()))
				var new_entry := Design.entry_node(npc_id)
				if new_entry != "" and new_entry != "end" and new_entry != "close":
					if nodes.has(new_entry):
						nxt = new_entry
						continue
				return "end"
			nxt = _next_of(target)
		else:
			return k
	return "end"

## Nº máximo de nodos "lógicos" (state/event/flow/goto) encadenados sin UI antes
## de abortar, como salvaguarda contra bucles infinitos por datos mal formados.
const MAX_STEPS_PER_TICK: int = 256


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════

## ID de la escena activa actual (o vacio si no hay escena).
var active_scene_id: String:
	get:
		return _top_id()


## Devuelve el ID de la escena activa actual.
func get_active_scene_id() -> String:
	return _top_id()


## ¿Hay una escena en curso?
func is_active() -> bool:
	return not _stack.is_empty()


## Inicia una escena por su id (scenes.json). `ctx_npc` da contexto a las
## condiciones/recompensas ligadas a un NPC (flags, relación, visitas). Devuelve
## false si la escena no existe o está vacía.
func start_scene(scene_id: String, ctx_npc: String = "") -> bool:
	_stack.clear()
	_chosen_options.clear()
	if not _push_scene(scene_id, ctx_npc, ""):
		return false
	_check_scene_music(scene_id)
	scene_started.emit(scene_id)
	_goto(_top().get("entry", ""))
	return true


## Inicia una escena ya CONSTRUIDA en memoria (no viene de scenes.json). La usan
## los ADAPTADORES para ejecutar contenido legado (diálogos,
## cinemáticas, grafos de NPC) con el mismo motor sin duplicar los datos en disco.
## `scene_dict` = { entry, nodes:{...} }. `scene_id` es solo un id lógico para las
## señales. Devuelve false si la escena construida está vacía.
func start_built_scene(scene_id: String, scene_dict: Dictionary, ctx_npc: String = "") -> bool:
	_stack.clear()
	_chosen_options.clear()
	var nodes = scene_dict.get("nodes", {})
	if not (nodes is Dictionary) or (nodes as Dictionary).is_empty():
		return false
	_stack.append({
		"scene_id": scene_id,
		"nodes": nodes,
		"ctx_npc": ctx_npc,
		"return_node": "",
		"current": "",
		"entry": String(scene_dict.get("entry", "")),
		"meta": scene_dict.get("meta", {}) if scene_dict.get("meta") is Dictionary else {},
	})
	_check_scene_music(scene_id)
	scene_started.emit(scene_id)
	_goto(_top().get("entry", ""))
	return true


func _check_scene_music(scene_id: String) -> void:
	if AudioManager == null:
		return
	var meta: Dictionary = _top().get("meta", {}) if is_active() else {}
	var track := String(meta.get("music", ""))
	if track != "":
		AudioManager.play_music(track)
	elif scene_id == "epilogo_final" or scene_id.begins_with("epilogo_"):
		AudioManager.play_music("world_zone1_flooded")



## La UI ha terminado de mostrar un nodo `say`: avanza al siguiente nodo.
func advance() -> void:
	if not is_active():
		return
	var node := _current_node()
	if String(node.get("kind", "")) != "say":
		return
	_goto(_next_of(node))


## La UI ha resuelto un nodo `choice`: sigue por la opción `index` (índice dentro
## de las opciones YA filtradas que se emitieron en choice_shown).
func choose(index: int) -> void:
	if not is_active():
		return
	var node := _current_node()
	if String(node.get("kind", "")) != "choice":
		return
	var opts := _visible_options(node)
	if index < 0 or index >= opts.size():
		_finish_all()
		return
	var choice_id: String = String(_top().get("current", ""))
	var original_index: int = int(opts[index].get("_orig_index", index))
	_mark_option_chosen(choice_id, original_index)
	_goto(String(opts[index].get("to", "")))


## Aborta la escena completa (p. ej. si el jugador cierra la ventana o cambia de
## vista). Vacía la pila y notifica el final.
func stop() -> void:
	if _stack.is_empty():
		return
	var root_id := String(_stack[0].get("scene_id", ""))
	_stack.clear()
	scene_finished.emit(root_id)


## Fuerza el avance EN SEGUNDO PLANO (sin presentar UI) por el resto del grafo
## activo, aplicando cualquier nodo `state`/`event` pendiente para no perder
## banderas de quest que debían otorgarse en esta escena. Se detiene en el
## primer nodo `choice` (una decisión no puede resolverse sola) o al llegar al
## final, cerrando la pila y notificando `scene_finished` como stop(). Lo usa
## el jugador al salir con ESC/SKIP en pleno diálogo.
func skip_to_end() -> void:
	if not is_active():
		return
	var steps := 0
	var target := String(_top().get("current", ""))
	while true:
		steps += 1
		if steps > MAX_STEPS_PER_TICK:
			push_warning("SceneRunner: skip_to_end demasiados nodos encadenados en '%s'." % _top_id())
			_finish_all()
			return
		if target == "" or target == "end" or target == "close":
			if _finish_frame():
				target = _pending_return
				_pending_return = ""
				continue
			return
		_top()["current"] = target
		var node := _current_node()
		if node.is_empty():
			_finish_all()
			return
		match String(node.get("kind", "say")):
			"say":
				target = _next_of(node)
			"choice":
				# No se puede resolver una decisión automáticamente: cerramos aquí.
				_finish_all()
				return
			"state":
				Design.apply_reward(String(node.get("ops", "")), _ctx())
				target = _next_of(node)
			"event":
				_run_event_node(node)
				target = _next_of(node)
			"flow":
				target = _skip_flow(node)
				if target == _FLOW_HALT:
					return
			_:
				target = _next_of(node)


## Variante silenciosa de _run_flow() para skip_to_end(): no espera (`wait` se
## resuelve al instante) y encadena subescenas (`call`) sin presentar UI.
func _skip_flow(node: Dictionary) -> String:
	match String(node.get("op", "goto")):
		"goto":
			return String(node.get("to", ""))
		"branch":
			for br in node.get("branches", []):
				if br is Dictionary and Design.eval_condition(String(br.get("condition", "")), _ctx()):
					return String(br.get("to", ""))
			return String(node.get("else", ""))
		"call":
			var sub := String(node.get("scene", ""))
			var ret := _next_of(node)
			if _push_scene(sub, _ctx(), ret):
				return String(_top().get("entry", ""))
			return ret
		"wait":
			return _next_of(node)
		"end":
			_finish_all()
			return _FLOW_HALT
		"credits":
			_finish_all()
			_show_credits()
			return _FLOW_HALT
		"reload_npc":
			var npc_id := String(node.get("npc_id", _ctx()))
			var new_entry := Design.entry_node(npc_id)
			if new_entry != "" and new_entry != "end" and new_entry != "close":
				var nodes: Dictionary = _top().get("nodes", {})
				if nodes.has(new_entry):
					return new_entry
			_finish_all()
			return _FLOW_HALT
		_:
			return _next_of(node)


# ══════════════════════════════════════════════════════════════════════════════
# RECORRIDO DEL GRAFO
# ══════════════════════════════════════════════════════════════════════════════

## Salta al nodo `node_id` del marco activo y lo procesa. Los nodos "lógicos"
## (state/event/flow) se resuelven en cadena hasta topar con un nodo de UI
## (say/choice) o con el fin de la escena.
func _goto(node_id: String) -> void:
	var steps := 0
	var target := node_id
	while true:
		steps += 1
		if steps > MAX_STEPS_PER_TICK:
			push_warning("SceneRunner: demasiados nodos encadenados; posible bucle en '%s'." % _top_id())
			_finish_all()
			return
		# Fin de rama: id vacío o palabra reservada de cierre.
		if target == "" or target == "end" or target == "close":
			if _finish_frame():
				# Se reanudó un marco padre en su nodo de retorno: continuar por él.
				target = _pending_return
				_pending_return = ""
				continue
			return
		_top()["current"] = target
		var node := _current_node()
		if node.is_empty():
			push_warning("SceneRunner: nodo '%s' inexistente en escena '%s'." % [target, _top_id()])
			_finish_all()
			return
		match String(node.get("kind", "say")):
			"say":
				_present_say(node)
				return
			"choice":
				_present_choice(node)
				return
			"state":
				Design.apply_reward(String(node.get("ops", "")), _ctx())
				target = _next_of(node)
			"event":
				_run_event_node(node)
				target = _next_of(node)
			"flow":
				var r := _run_flow(node)
				if r == _FLOW_HALT:
					return
				target = r
			_:
				push_warning("SceneRunner: tipo de nodo desconocido '%s'." % String(node.get("kind", "")))
				target = _next_of(node)


## Marcador de "el flujo se detuvo esperando algo" (p. ej. una espera temporal o
## el fin de la escena), para que _goto no siga encadenando.
const _FLOW_HALT: String = "__halt__"

## Nodo de retorno pendiente tras cerrar un marco (subescena) para reanudar el padre.
var _pending_return: String = ""
var _chosen_options: Dictionary = {}


## Ejecuta un nodo de FLUJO y devuelve el siguiente id a procesar (o _FLOW_HALT
## si el flujo se detiene/espera y no debe encadenar).
func _run_flow(node: Dictionary) -> String:
	match String(node.get("op", "goto")):
		"goto":
			return String(node.get("to", ""))
		"branch":
			# Primera rama cuya condición se cumpla; si ninguna, el 'else'.
			for br in node.get("branches", []):
				if br is Dictionary and Design.eval_condition(String(br.get("condition", "")), _ctx()):
					return String(br.get("to", ""))
			return String(node.get("else", ""))
		"call":
			# Subescena reutilizable: apila un marco nuevo; al terminar, se reanuda
			# el marco actual en el nodo `next` (return_node del hijo).
			var sub := String(node.get("scene", ""))
			var ret := _next_of(node)
			if _push_scene(sub, _ctx(), ret):
				_goto(_top().get("entry", ""))
			else:
				_goto(ret)
			return _FLOW_HALT
		"wait":
			# Espera temporal (útil en cinemáticas). Reanuda en `next` al terminar.
			var dur := float(node.get("dur", 0.0))
			var nxt := _next_of(node)
			if dur > 0.0:
				_wait_then(dur, nxt)
				return _FLOW_HALT
			return nxt
		"end":
			_finish_all()
			return _FLOW_HALT
		"credits":
			# Fin de partida (Task 1 FASE 3, multi-finales): cierra la escena y
			# lanza los créditos, reutilizando CreditsScreen.tscn (antes solo
			# alcanzable desde el menú principal).
			_finish_all()
			_show_credits()
			return _FLOW_HALT
		"reload_npc":
			var npc_id := String(node.get("npc_id", _ctx()))
			var new_entry := Design.entry_node(npc_id)
			if new_entry != "" and new_entry != "end" and new_entry != "close":
				var nodes: Dictionary = _top().get("nodes", {})
				if nodes.has(new_entry):
					return new_entry
			_finish_all()
			return _FLOW_HALT
		_:
			return _next_of(node)


const _CREDITS_SCENE: PackedScene = preload("res://scenes/ui/credits/CreditsScreen.tscn")

## Muestra los créditos como overlay sobre la escena actual (fin de partida).
func _show_credits() -> void:
	var root := get_tree().root
	if root == null:
		return
	if AudioManager != null:
		AudioManager.play_music("event_crisis_puerto", 1.0)
	var overlay: Control = _CREDITS_SCENE.instantiate()
	if overlay != null:
		overlay.set("show_post_game_prompt", true)
	root.add_child(overlay)


## Espera `dur` segundos (tiempo real, aunque el juego esté pausado) y salta a `nxt`.
func _wait_then(dur: float, nxt: String) -> void:
	var t := get_tree().create_timer(dur, true, false, true)
	await t.timeout
	if is_active():
		_goto(nxt)


# ══════════════════════════════════════════════════════════════════════════════
# PRESENTACIÓN (delegada a la NarrativeView vía señales)
# ══════════════════════════════════════════════════════════════════════════════

## Emite un nodo `say` ya localizado para que la UI lo muestre.
## `auto` (segundos) hace que el nodo avance solo sin esperar al jugador (útil en
## cinemáticas). `style` = "box" (panel inferior, por defecto) | "banner"
## (narración centrada a pantalla, sin retrato).
func _present_say(node: Dictionary) -> void:
	if AudioManager != null:
		var node_music := String(node.get("music", ""))
		if node_music != "":
			AudioManager.play_music(node_music)
		elif String(node.get("bg", "")).begins_with("bg_ending_"):
			AudioManager.play_music("world_zone1_flooded")
	var data := {
		"kind": "say",
		"speaker": _loc(node.get("speaker", "")),
		"portrait": String(node.get("portrait", "")),
		"text": _loc(node.get("text", "")),
		"fx": node.get("fx", {}),
		"auto": float(node.get("auto", 0.0)),
		"style": String(node.get("style", "box")),
		"bg": String(node.get("bg", "")),
	}
	say_shown.emit(data)


## Filtra las opciones visibles de un `choice` por su condición y las emite.
func _present_choice(node: Dictionary) -> void:
	var opts := _visible_options(node)
	var out: Array = []
	for i in opts.size():
		out.append({"text": _loc(opts[i].get("text", "")), "index": i})
	choice_shown.emit(_loc(node.get("prompt", "")), out)


## Opciones de un `choice` cuya condición se cumple (en orden). Cada una: la
## definición original {text, condition?, to}.
func _choice_key(choice_id: String, original_index: int) -> String:
	return choice_id + ":" + str(original_index)


func _is_option_chosen(choice_id: String, original_index: int) -> bool:
	var key := _choice_key(choice_id, original_index)
	if _chosen_options.has(key):
		return true
	var npc_id := _ctx()
	if npc_id != "":
		return GlobalState.npc_has_flag(npc_id, "chosen_" + key)
	return false


func _mark_option_chosen(choice_id: String, original_index: int) -> void:
	var key := _choice_key(choice_id, original_index)
	_chosen_options[key] = true
	var npc_id := _ctx()
	if npc_id != "":
		GlobalState.set_npc_flag(npc_id, "chosen_" + key)


func _visible_options(node: Dictionary) -> Array:
	var out: Array = []
	var current_id: String = String(_top().get("current", "")) if is_active() else ""
	var opts: Array = node.get("options", []) as Array
	for i in range(opts.size()):
		var opt = opts[i]
		if not (opt is Dictionary):
			continue
		var is_once := bool(opt.get("once", false))
		if is_once and _is_option_chosen(current_id, i):
			continue
		if Design.eval_condition(String(opt.get("condition", "")), _ctx()):
			var copy: Dictionary = (opt as Dictionary).duplicate()
			copy["_orig_index"] = i
			out.append(copy)
	return out


## Emite el/los evento(s) global(es) de un nodo `event`. `emit` puede ser un
## String o un Array de nombres. `payload` opcional (Dictionary) se adjunta.
func _run_event_node(node: Dictionary) -> void:
	var payload: Dictionary = node.get("payload", {}) if node.get("payload") is Dictionary else {}
	var e = node.get("emit", "")
	if e is Array:
		for ev_name in e:
			GlobalEvents.emit_event(String(ev_name), payload)
	elif String(e) != "":
		GlobalEvents.emit_event(String(e), payload)


# ══════════════════════════════════════════════════════════════════════════════
# PILA DE MARCOS (escenas / subescenas)
# ══════════════════════════════════════════════════════════════════════════════

## Apila un marco para la escena `scene_id`. `return_node` es el nodo del marco
## PADRE al que volver cuando esta (sub)escena termine. Devuelve false si no existe.
func _push_scene(scene_id: String, ctx_npc: String, return_node: String) -> bool:
	var sc := Design.get_scene(scene_id)
	if sc.is_empty():
		push_warning("SceneRunner: escena '%s' no encontrada." % scene_id)
		return false
	var nodes = sc.get("nodes", {})
	var meta = sc.get("meta", {})
	_stack.append({
		"scene_id": scene_id,
		"nodes": nodes if nodes is Dictionary else {},
		"ctx_npc": ctx_npc,
		"return_node": return_node,
		"current": "",
		"entry": String(sc.get("entry", "")),
		"meta": meta if meta is Dictionary else {},
	})
	return true


## Cierra el marco activo. Si había un marco padre, deja preparado su nodo de
## retorno en `_pending_return` y devuelve true (para que _goto lo reanude). Si
## era el marco raíz, emite scene_finished y devuelve false.
func _finish_frame() -> bool:
	if _stack.is_empty():
		return false
	var frame: Dictionary = _stack.pop_back()
	if _stack.is_empty():
		scene_finished.emit(String(frame.get("scene_id", "")))
		return false
	_pending_return = String(frame.get("return_node", ""))
	return true


## Cierra TODA la pila (fin abrupto o nodo 'end' de nivel superior).
func _finish_all() -> void:
	if _stack.is_empty():
		return
	var root_id := String(_stack[0].get("scene_id", ""))
	_stack.clear()
	scene_finished.emit(root_id)


# ─── Accesores del marco activo ───────────────────────────────────────────────
func _top() -> Dictionary:
	return _stack[_stack.size() - 1]

func _top_id() -> String:
	return String(_top().get("scene_id", "")) if is_active() else ""

func _ctx() -> String:
	return String(_top().get("ctx_npc", "")) if is_active() else ""

func _current_node() -> Dictionary:
	var nodes: Dictionary = _top().get("nodes", {})
	return nodes.get(String(_top().get("current", "")), {})

## Siguiente nodo declarado por `next` (String o primer elemento si es Array).
func _next_of(node: Dictionary) -> String:
	var nx = node.get("next", "")
	if nx is Array:
		return String(nx[0]) if (nx as Array).size() > 0 else ""
	return String(nx)


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ══════════════════════════════════════════════════════════════════════════════

## Localiza un valor de texto que puede ser String directo o mapa {es,en}.
func _loc(v) -> String:
	if v is Dictionary:
		return Locale.pick(v)
	return String(v)
