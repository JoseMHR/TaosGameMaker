class_name LootManager
extends RefCounted
## GESTOR DE BOTÍN, RAREZA, FORJA Y RE-FORJA — Módulo especialista extraído de
## GlobalState.
##
## Centraliza toda la lógica de tiradas de botín (enemigos, cofres), rareza
## de equipamiento y forja/re-forja. Los
## DATOS (`gold`, `inventory`) siguen viviendo en `GlobalState`, que multitud de
## vistas leen de forma directa; este manager sólo aloja la LÓGICA y opera sobre
## esos datos a través de una referencia al `GlobalState` propietario (`_state`).
##
## `GlobalState` mantiene wrappers-fachada con las mismas firmas públicas
## (`roll_rarity`, `roll_equipment_drop`, `grant_loot`, `grant_loot_entries`,
## `can_forge`, `forge`, `is_reforgeable`, `reforge_item`)
## que redirigen a este manager, de modo que ningún llamante externo cambia.

## Referencia al autoload GlobalState propietario de los datos (gold/inventory).
var _state: Node = null

## Enlaza este manager con el GlobalState propietario. Debe llamarse una única vez
## durante la inicialización del autoload (`GlobalState._ready`).
func setup(state: Node) -> void:
	_state = state


## Tira una rareza al azar según los pesos de GameConfig.rarities().
func roll_rarity() -> Dictionary:
	var total: float = 0.0
	for r in GameConfig.rarities():
		total += float(r["weight"])
	var pick: float = randf() * total
	for r in GameConfig.rarities():
		pick -= float(r["weight"])
		if pick <= 0.0:
			return r
	return GameConfig.rarities()[0]

## Aplica el multiplicador de rareza a una plantilla base y la añade al inventario.
## Devuelve el resumen del drop.
func _grant_equipment_from_base(base: Dictionary, rarity: Dictionary) -> Dictionary:
	var mult: float = float(rarity["mult"])
	var base_id: String = String(base["id"])
	# Stats base desde items.json, escalados por el multiplicador de rareza.
	var def: Dictionary = Design.get_item(base_id)
	var bonuses: Dictionary = {}
	for k in def.get("bonuses", {}).keys():
		bonuses[k] = int(round(def["bonuses"][k] * mult))
	var combat: Dictionary = {}
	for k in def.get("combat", {}).keys():
		combat[k] = int(round(def["combat"][k] * mult))
	_state.add_equipment_item(base_id, String(rarity["key"]), bonuses, combat)
	var full_name: String = ("%s %s" % [Locale.t(rarity["loc"]), Design.get_item_name(base_id)]).strip_edges()
	var inst_id: String = "%s_%s" % [base_id, rarity["key"]]
	return {
		"kind": "equipment", "id": inst_id, "name": full_name, "icon": Design.get_item_icon(base_id),
		"rarity": rarity["key"], "color": String(rarity["color"]), "slot": String(def.get("slot", "weapon")), "qty": 1,
	}

## Construye un equipo de botín: plantilla por nivel + rareza aleatoria.
func roll_equipment_drop(drop_level: int) -> Dictionary:
	var pool: Array = []
	for e in GameConfig.LOOT_EQUIPMENT:
		if int(e["level"]) == drop_level:
			pool.append(e)
	if pool.is_empty():
		for e in GameConfig.LOOT_EQUIPMENT:
			if int(e["level"]) <= drop_level:
				pool.append(e)
	if pool.is_empty():
		pool = GameConfig.LOOT_EQUIPMENT
	var base: Dictionary = pool[randi() % pool.size()]
	return _grant_equipment_from_base(base, roll_rarity())

## Procesa la tabla de botín de un enemigo (lista de entradas en línea):
## concede lo que toque y devuelve los drops.
func grant_loot(enemy_data: Dictionary) -> Array:
	var loot = enemy_data.get("loot", [])
	return grant_loot_entries(loot if loot is Array else [])

## "Roller" de botín compartido por enemigos, cofres y recompensas. Recorre las
## entradas, concede lo que toque (con sus tiradas de probabilidad) y devuelve la
## lista de drops [{kind, id?, name, icon, qty, ...}] para que la vista los muestre.
func grant_loot_entries(entries: Array) -> Array:
	var drops: Array = []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		if not (randf() <= float(entry.get("chance", 1.0))):
			continue
		var kind: String = String(entry.get("kind", ""))
		match kind:
			"gold":
				var g: int = randi_range(int(entry.get("min", 0)), int(entry.get("max", 0)))
				if g > 0:
					_state.gold += g
					drops.append({"kind": "gold", "name": "%d" % g, "icon": "🪙", "qty": g})
			"consumable":
				var cid: String = String(entry["id"])
				var cqty: int = randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
				_state.add_item(cid, cqty)
				drops.append({"kind": "consumable", "id": cid, "name": Design.get_item_name(cid), "icon": Design.get_item_icon(cid), "qty": cqty})
			"item":
				var iid: String = String(entry["id"])
				var iqty: int = int(entry.get("qty", randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))))
				_state.add_item(iid, iqty)
				drops.append({"kind": "item", "id": iid, "name": Design.get_item_name(iid), "icon": Design.get_item_icon(iid), "qty": iqty})
			"resource":
				var rid: String = String(entry["id"])
				var qty: int = randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
				_state.add_item(rid, qty)
				_state.discover_resource(rid)
				_state.report_gather(rid, qty)
				drops.append({"kind": "resource", "id": rid, "name": Design.get_item_name(rid), "icon": Design.get_item_icon(rid), "qty": qty})
			"equipment":
				drops.append(roll_equipment_drop(int(entry.get("level", 1))))
	if not drops.is_empty():
		_state.state_updated.emit()
	return drops

## ¿Se puede forjar una receta (oro + recursos)?
func can_forge(recipe: Dictionary) -> bool:
	if _state.gold < int(recipe.get("gold", 0)):
		return false
	for res in recipe.get("costs", {}).keys():
		if not _state.has_item(res, int(recipe["costs"][res])):
			return false
	return true

## Forja un equipo (sumidero de oro + recursos). Devuelve true si tuvo éxito.
func forge(recipe_id: String) -> bool:
	for r in GameConfig.FORGE_RECIPES:
		if r["id"] == recipe_id:
			if not can_forge(r):
				return false
			_state.gold -= int(r.get("gold", 0))
			for res in r.get("costs", {}).keys():
				_state.remove_item(res, int(r["costs"][res]))
			_state.add_equipment_item(String(r["id"]))
			_state.state_updated.emit()
			return true
	return false

## ¿Un ítem del inventario se puede re-forjar (deriva de una plantilla de botín)?
func is_reforgeable(item_id: String) -> bool:
	for item in _state.inventory:
		if item.get("id") == item_id and item.get("category") == "equipment":
			var res = item.get("resource")
			if res is EquipmentResource and res.base_id != "":
				return true
	return false

## Re-forja un equipo del inventario: gasta oro y vuelve a tirar su rareza.
## Devuelve el resumen del nuevo drop, o {} si falla.
func reforge_item(item_id: String) -> Dictionary:
	if _state.gold < GameConfig.REFORGE_COST_GOLD:
		return {}
	var idx: int = -1
	for i in range(_state.inventory.size()):
		if _state.inventory[i].get("id") == item_id and _state.inventory[i].get("category") == "equipment":
			idx = i
			break
	if idx == -1:
		return {}
	var res = _state.inventory[idx].get("resource")
	if not (res is EquipmentResource) or res.base_id == "":
		return {}
	var base: Dictionary = {}
	for e in GameConfig.LOOT_EQUIPMENT:
		if e["id"] == res.base_id:
			base = e
			break
	if base.is_empty():
		return {}
	_state.gold -= GameConfig.REFORGE_COST_GOLD
	_state.inventory[idx]["quantity"] -= 1
	if _state.inventory[idx]["quantity"] <= 0:
		_state.inventory.remove_at(idx)
	var drop: Dictionary = _grant_equipment_from_base(base, roll_rarity())
	_state.state_updated.emit()
	return drop
