class_name CookingBuffsManager
extends RefCounted
## GESTOR DE COCINA, CONSUMIBLES Y COMIDA — Módulo especialista extraído de GlobalState.
##
## Centraliza la lógica de cocinar recetas (`GameConfig.COOKING_RECIPES`), usar
## consumibles (pociones) y comer alimentos en la Hoguera del campamento,
## incluyendo los buffs temporales que puede conceder un plato (ver
## `docs/tasks/task_arreglos.md` §3).
##
## Los DATOS (`food_buffs`, `skills`, `hp`/`mp`, inventario) siguen viviendo en
## `GlobalState` porque la serialización (SaveSerializer / to_dict / from_dict)
## y numerosas vistas los leen de forma directa; este manager sólo aloja la
## LÓGICA y opera sobre esos datos a través de una referencia al `GlobalState`
## propietario (`_state`).
##
## `GlobalState` mantiene wrappers-fachada con las mismas firmas públicas
## (`grant_food_buff`, `has_food_buff`, `cook`, `cook_recipe`, `use_consumable`,
## `food_restore_values`, `food_preview`, `eat_food`) que redirigen a este
## manager, de modo que ningún llamante externo cambia.

## Referencia al autoload GlobalState propietario de los datos.
var _state: Node = null

## Enlaza este manager con el GlobalState propietario. Debe llamarse una única
## vez durante la inicialización del autoload (`GlobalState._ready`).
func setup(state: Node) -> void:
	_state = state


#region BUFFS TEMPORALES DE COMIDA
## Concede (o renueva) un buff temporal de comida por `duration_sec` reales.
func grant_food_buff(key: String, duration_sec: int) -> void:
	if key == "":
		return
	_state.food_buffs[key] = _state._now_unix() + duration_sec
	_state.state_updated.emit()

## ¿Está activo AHORA MISMO el buff de comida `key`?
func has_food_buff(key: String) -> bool:
	return key != "" and int(_state.food_buffs.get(key, 0)) > _state._now_unix()
#endregion


#region COCINA — Convertir un ingrediente en un consumible
## Cocina una receta: consume el ingrediente y entrega el consumible resultante.
## Los metadatos del resultado se resuelven desde items.json (Design.get_item).
func cook(in_id: String, in_qty: int, out_id: String) -> bool:
	if not _state.has_item(in_id, in_qty):
		return false
	_state.remove_item(in_id, in_qty)
	_state.add_item(out_id, 1)
	return true


## Cocina una receta de `GameConfig.COOKING_RECIPES` (1 o más ingredientes):
## consume TODOS los ingredientes y, salvo mala suerte (GameConfig.COOK_FAIL_CHANCE),
## entrega 1 unidad de `out_id` y otorga XP de Cocinero. Devuelve:
##   "ok"           → éxito: ingredientes consumidos, plato entregado + XP.
##   "fail_missing" → nivel insuficiente o faltan ingredientes (NADA se consume).
##   "fail_luck"    → mala suerte al cocinar: ingredientes desperdiciados, sin plato ni XP.
func cook_recipe(recipe: Dictionary) -> String:
	var level_req: int = int(recipe.get("level_req", 1))
	var cook_level: int = int(_state.skills.get(GameConfig.COOKING_SKILL, {}).get("level", 1))
	if cook_level < level_req:
		return "fail_missing"
	var ingredients: Array = recipe.get("ingredients", [])
	if ingredients.is_empty():
		return "fail_missing"
	for ing in ingredients:
		if not _state.has_item(String(ing.get("id", "")), int(ing.get("qty", 1))):
			return "fail_missing"
	for ing in ingredients:
		_state.remove_item(String(ing["id"]), int(ing.get("qty", 1)))
	if randf() < GameConfig.COOK_FAIL_CHANCE:
		return "fail_luck"
	_state.add_item(String(recipe.get("out_id", "")), 1)
	_state.add_skill_xp(GameConfig.COOKING_SKILL, GameConfig.COOKING_XP_PER_DISH)
	return "ok"
#endregion


#region CONSUMIBLES — Usar un ítem consumible
## Usa un consumible aplicando su efecto (definido en el campo "effects" de
## items.json). Devuelve true si se usó (p.ej. no se gasta una poción con la vida llena).
func use_consumable(id: String) -> bool:
	var def: Dictionary = Design.get_item(id)
	if def.is_empty() or not _state.has_item(id, 1):
		return false
	if not bool(def.get("usable", false)):
		return false
	var effects: Dictionary = def.get("effects", {})
	# task3 FASE3: heal_pct/mana_pct (0.0-1.0) sobre el máximo ACTUAL, para que
	# una poción siga siendo útil igual de nivel 1 que de nivel 25. Se mantiene
	# el fallback a heal/mana planos por compatibilidad con datos antiguos.
	var heal: int = int(effects.get("heal_pct", 0.0) * _state.max_hp) if effects.has("heal_pct") else int(effects.get("heal", 0))
	var mana: int = int(effects.get("mana_pct", 0.0) * _state.max_mp) if effects.has("mana_pct") else int(effects.get("mana", 0))
	# Nada que curar: no gastar el consumible.
	if heal > 0 and _state.hp >= _state.max_hp and (mana <= 0 or _state.mp >= _state.max_mp):
		return false
	if heal <= 0 and mana <= 0:
		return false
	if _state.remove_item(id, 1):
		if heal > 0:
			_state.hp = mini(_state.max_hp, _state.hp + heal)
		if mana > 0:
			_state.mp = mini(_state.max_mp, _state.mp + mana)
		_state.recalculate_derived_stats()
		AudioManager.play_sfx("heal")
		return true
	return false
#endregion


#region COMIDA (Comestibles) — comer en la Hoguera del campamento
## Valores de recuperación (vida/maná) de un comestible, leídos de su `effects`.
## Data-driven: soporta las claves nuevas `hp`/`mp` y las legado `heal`/`mana`.
func food_restore_values(id: String) -> Dictionary:
	var def: Dictionary = Design.get_item(id)
	var e: Dictionary = def.get("effects", {})
	# task3 FASE3: heal_pct/mana_pct sobre el máximo ACTUAL (soporta legado hp/mp/heal/mana planos).
	var hp_val: int = int(e.get("heal_pct", 0.0) * _state.max_hp) if e.has("heal_pct") else int(e.get("hp", e.get("heal", 0)))
	var mp_val: int = int(e.get("mana_pct", 0.0) * _state.max_mp) if e.has("mana_pct") else int(e.get("mp", e.get("mana", 0)))
	return {
		"hp": hp_val,
		"mp": mp_val,
	}


## Previsualiza el resultado de comer un alimento SIN consumirlo: devuelve los
## valores actuales y los proyectados de vida/maná (acotados a los máximos) para
## dibujar las barras "antes/después" del menú Comer.
func food_preview(id: String) -> Dictionary:
	var v: Dictionary = food_restore_values(id)
	var hp_after: int = mini(_state.max_hp, _state.hp + int(v["hp"]))
	var mp_after: int = mini(_state.max_mp, _state.mp + int(v["mp"]))
	return {
		"hp_now": _state.hp, "hp_after": hp_after, "hp_gain": hp_after - _state.hp,
		"mp_now": _state.mp, "mp_after": mp_after, "mp_gain": mp_after - _state.mp,
		"max_hp": _state.max_hp, "max_mp": _state.max_mp,
	}


## Come un alimento: consume 1 unidad y aplica su recuperación de vida/maná.
## Devuelve las cantidades REALES recuperadas {hp, mp}, o un diccionario vacío si
## no se pudo (sin alimento, o ya al máximo de ambas). No avanza el tiempo: de eso
## se encarga quien invoca (la Hoguera hace pasar 1 hora tras la animación).
func eat_food(id: String) -> Dictionary:
	if not _state.has_item(id, 1):
		return {}
	var v: Dictionary = food_restore_values(id)
	var hp_gain: int = mini(_state.max_hp - _state.hp, maxi(0, int(v["hp"])))
	var mp_gain: int = mini(_state.max_mp - _state.mp, maxi(0, int(v["mp"])))
	# Buff temporal opcional (Hamburguesa/Queso Artesanal): { "key": "strength", "duration": 600 }.
	var buff: Dictionary = Design.get_item(id).get("effects", {}).get("buff", {})
	if hp_gain <= 0 and mp_gain <= 0 and buff.is_empty():
		return {}   # nada que recuperar ni buff que conceder: no malgastar el alimento
	if not _state.remove_item(id, 1):
		return {}
	_state.hp += hp_gain
	_state.mp += mp_gain
	if not buff.is_empty():
		grant_food_buff(String(buff.get("key", "")), int(buff.get("duration", GameConfig.FOOD_BUFF_DURATION_SEC)))
	_state.recalculate_derived_stats()
	AudioManager.play_sfx("heal")
	return {"hp": hp_gain, "mp": mp_gain}
#endregion
