class_name GameFlagsManager
extends RefCounted
## GESTOR DE BANDERAS Y EVENTOS GLOBALES — Módulo especialista extraído de GlobalState.
##
## Centraliza la lógica de las banderas de historia data-driven (`world_flags`) y
## de los jefes derrotados (`defeated_bosses`), además de una consulta de
## conveniencia sobre profesiones desbloqueadas (`unlocked_professions`).
##
## Los DATOS siguen viviendo en `GlobalState` porque la serialización
## (SaveSerializer / to_dict / from_dict) y numerosas vistas los leen de forma
## directa; este manager sólo aloja la LÓGICA y opera sobre esos diccionarios a
## través de una referencia al `GlobalState` propietario (`_state`).
##
## `GlobalState` mantiene wrappers-fachada con las mismas firmas públicas
## (`has_flag`, `has_world_flag`, `set_world_flag`, `get_world_flag_val`,
## `is_boss_defeated`, `mark_boss_defeated`) que redirigen a este manager, de modo
## que ningún llamante externo cambia.

## Referencia al autoload GlobalState propietario de los datos de banderas.
var _state: Node = null

## Enlaza este manager con el GlobalState propietario. Debe llamarse una única vez
## durante la inicialización del autoload (`GlobalState._ready`).
func setup(state: Node) -> void:
	_state = state

#region FLAGS GLOBALES DATA-DRIVEN

## Consulta si un flag (global o de NPC) está activo.
func has_flag(flag: String, npc_id: String = "") -> bool:
	if has_world_flag(flag):
		return true
	if npc_id != "" and _state.npc_has_flag(npc_id, flag):
		return true
	return false

## ¿Está activo el flag global `flag`? (independiente de NPC).
func has_world_flag(flag: String) -> bool:
	return bool(_state.world_flags.get(flag, false))

## Activa (o desactiva si `value` es false) un flag global de historia.
func set_world_flag(flag: String, value: Variant = true) -> void:
	if flag.strip_edges() == "":
		return
	if value is bool and not value:
		_state.world_flags.erase(flag)
	else:
		_state.world_flags[flag] = value
	_state.state_updated.emit()

## Devuelve el valor bruto de un flag global (o `default_val` si no existe).
func get_world_flag_val(flag: String, default_val: Variant = null) -> Variant:
	return _state.world_flags.get(flag, default_val)

#endregion

#region JEFES DERROTADOS (persistencia anti-reaparición)

## ¿Ya se derrotó al jefe identificado por `key` ("event_id:enemy_id")?
func is_boss_defeated(key: String) -> bool:
	return key != "" and bool(_state.defeated_bosses.get(key, false))

## Marca un jefe como derrotado (no volverá a aparecer al reentrar en su mazmorra).
func mark_boss_defeated(key: String) -> void:
	if key != "":
		_state.defeated_bosses[key] = true

#endregion

#region PROFESIONES

## ¿Está desbloqueada la profesión `prof`? ("Don Nadie" siempre lo está.)
func is_profession_unlocked(prof: String) -> bool:
	return prof == "Don Nadie" or prof in _state.unlocked_professions

#endregion
