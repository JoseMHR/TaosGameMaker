class_name RefineManager
extends RefCounted
## GESTOR DE REFINAMIENTO DE EQUIPO (+0 a +10) — ver task5.md.
##
## Dos vías, la MISMA lógica, distinta moneda: el herrero de una CIUDAD cobra
## ORO (`via_city = true`); la Herrería (yunque) de la Base cobra RECURSOS
## (`via_city = false`). Ver `GameConfig.refine_gold_cost`/`refine_resource_costs`.
##
## Cada intento SIEMPRE consume el coste, tenga éxito o no (ver GameConfig.REFINE_RISK).
## Refinar SIEMPRE separa una unidad de su pila en una instancia propia con un id
## distinto ("<id>+N"): nunca se muta la EquipmentResource compartida por el resto
## de la pila ni por el ítem equipado (que son la MISMA referencia, ver
## `ItemInventoryManager.add_equipment_item`/`equip_item`).

## Referencia al autoload GlobalState propietario de los datos (gold/inventory).
var _state: Node = null

func setup(state: Node) -> void:
	_state = state


## Busca en el inventario la entrada de equipo con ese id exacto (incluido
## cualquier sufijo "+N" de refinamiento). Devuelve su índice, o -1.
func _find(item_id: String) -> int:
	for i in range(_state.inventory.size()):
		var it: Dictionary = _state.inventory[i]
		if it.get("id") == item_id and it.get("category") == "equipment" and it.get("resource") is EquipmentResource:
			return i
	return -1


## Quita cualquier sufijo "+N" de refinamiento de un store_id ("sword+3" -> "sword").
func _strip_refine_suffix(id: String) -> String:
	var plus_idx: int = id.rfind("+")
	if plus_idx == -1:
		return id
	var suffix: String = id.substr(plus_idx + 1)
	return id.substr(0, plus_idx) if suffix.is_valid_int() else id


func _can_afford(from_level: int, via_city: bool) -> bool:
	if via_city:
		return _state.gold >= GameConfig.refine_gold_cost(from_level)
	var costs: Dictionary = GameConfig.refine_resource_costs(from_level)
	for res_id in costs.keys():
		if not _state.has_item(res_id, int(costs[res_id])):
			return false
	return true

func _pay(from_level: int, via_city: bool) -> void:
	if via_city:
		_state.gold -= GameConfig.refine_gold_cost(from_level)
		return
	var costs: Dictionary = GameConfig.refine_resource_costs(from_level)
	for res_id in costs.keys():
		_state.remove_item(res_id, int(costs[res_id]))


## Clona un EquipmentResource campo a campo: NUNCA comparte referencias con el
## original (ni siquiera el Dictionary `stat_bonuses`), para no mutar de rebote
## otras copias apiladas o el ítem equipado.
func _clone(res: EquipmentResource) -> EquipmentResource:
	var c := EquipmentResource.new()
	c.id = res.id
	c.name = res.name
	c.icon = res.icon
	c.slot = res.slot
	c.base_id = res.base_id
	c.rarity = res.rarity
	c.stat_bonuses = res.stat_bonuses.duplicate(true)
	c.phys_damage = res.phys_damage
	c.mag_damage = res.mag_damage
	c.range_damage = res.range_damage
	c.phys_defense = res.phys_defense
	c.mag_defense = res.mag_defense
	c.refine_level = res.refine_level
	return c


## Añade una instancia refinada al inventario, fusionándola con una pila
## existente del MISMO id (mismo refinamiento) si la hay.
func _add_refined_instance(res: EquipmentResource) -> void:
	for item: Dictionary in _state.inventory:
		if item["id"] == res.id:
			item["quantity"] = int(item["quantity"]) + 1
			return
	_state.inventory.append({
		"id": res.id, "name": res.name, "quantity": 1,
		"category": "equipment", "icon": res.icon, "resource": res,
	})


## ¿Se puede intentar refinar `item_id` (existe, no está al máximo, y el
## jugador puede pagar el coste de su próximo nivel)?
func can_refine(item_id: String, via_city: bool) -> bool:
	var idx: int = _find(item_id)
	if idx == -1:
		return false
	var res: EquipmentResource = _state.inventory[idx]["resource"]
	if res.refine_level >= GameConfig.REFINE_MAX_LEVEL:
		return false
	return _can_afford(res.refine_level, via_city)


## Intenta refinar `item_id` un nivel más. Cobra SIEMPRE (éxito o no). Devuelve
## `{ok: bool, success: bool, backfired: bool, from_level: int, new_level: int,
## item_id: String, name: String}` — "ok" = false si no se pudo pagar, el ítem
## no existe o ya está al máximo (en ese caso no se cobra nada).
func refine_item(item_id: String, via_city: bool) -> Dictionary:
	var idx: int = _find(item_id)
	if idx == -1:
		return {"ok": false}
	var original: EquipmentResource = _state.inventory[idx]["resource"]
	var from_level: int = original.refine_level
	if from_level >= GameConfig.REFINE_MAX_LEVEL or not _can_afford(from_level, via_city):
		return {"ok": false}

	_pay(from_level, via_city)

	# Sacar UNA unidad de la pila original (nunca se muta su EquipmentResource).
	_state.inventory[idx]["quantity"] -= 1
	if _state.inventory[idx]["quantity"] <= 0:
		_state.inventory.remove_at(idx)

	var new_res: EquipmentResource = _clone(original)
	var success := true
	var backfired := false

	if from_level >= GameConfig.REFINE_RISK_FROM_LEVEL:
		var risk: Dictionary = GameConfig.REFINE_RISK.get(from_level, {})
		var back_chance: float = float(risk.get("back", 0.0))
		var stay_chance: float = float(risk.get("stay", 0.0))
		var roll: float = randf()
		if roll < back_chance:
			success = false
			backfired = true
			new_res.refine_level = maxi(0, from_level - 1)
		elif roll < back_chance + stay_chance:
			success = false
			new_res.refine_level = from_level
		else:
			new_res.refine_level = from_level + 1
	else:
		new_res.refine_level = from_level + 1

	var base_store_id: String = _strip_refine_suffix(original.id)
	new_res.id = base_store_id if new_res.refine_level <= 0 else "%s+%d" % [base_store_id, new_res.refine_level]

	_add_refined_instance(new_res)
	_state.state_updated.emit()

	return {
		"ok": true, "success": success, "backfired": backfired,
		"from_level": from_level, "new_level": new_res.refine_level,
		"item_id": new_res.id, "name": new_res.name,
	}
