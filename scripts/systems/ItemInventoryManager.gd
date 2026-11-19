class_name ItemInventoryManager
extends RefCounted
## GESTOR DE INVENTARIO Y EQUIPAMIENTO — Módulo especialista extraído de GlobalState.
##
## Centraliza toda la manipulación de objetos y equipamiento del héroe (añadir,
## quitar, consultar, equipar y desequipar). Los DATOS siguen viviendo en
## `GlobalState` (arrays `inventory`/`equipped`), que multitud de vistas leen de
## forma directa; este manager sólo aloja la LÓGICA y opera sobre esos datos a
## través de una referencia al `GlobalState` propietario (`_state`).
##
## `GlobalState` mantiene wrappers-fachada con las mismas firmas públicas
## (`add_item`, `remove_item`, `has_item`, `get_item`, `add_equipment_item`,
## `equip_item`, `unequip_item`) que redirigen a este manager, de modo que ningún
## llamante externo cambia.

## Referencia al autoload GlobalState propietario de los datos (inventory/equipped).
var _state: Node = null

## Enlaza este manager con el GlobalState propietario. Debe llamarse una única vez
## durante la inicialización del autoload (`GlobalState._ready`).
func setup(state: Node) -> void:
	_state = state

#region GESTIÓN DE INVENTARIO

## ¿Cuenta `id` como un hueco de inventario? Los ítems `category == "important"`
## (misión/llave, ver items.json) no cuentan — pueden acumularse sin límite.
func _counts_toward_cap(id: String) -> bool:
	return String(Design.get_item(id).get("category", "")) != "important"

## Nº de entradas del inventario que SÍ cuentan para `GlobalState.inventory_slot_cap()`.
func slot_count() -> int:
	var n := 0
	for item: Dictionary in _state.inventory:
		if _counts_toward_cap(String(item["id"])):
			n += 1
	return n

## Añade un ítem al inventario. Si ya existe, incrementa su cantidad (nunca
## ocupa un hueco nuevo). Los metadatos (nombre, categoría, icono) se resuelven
## en caliente desde `Design.get_item(id)` (items.json). Acepta parámetros
## opcionales legados (`_name`, `_category`, `_icon`) que se ignoran salvo que
## el ítem no exista en el catálogo (fallback de compatibilidad).
## Devuelve false SOLO si el ítem es un tipo NUEVO y el inventario está lleno
## (`GlobalState.inventory_slot_cap()`, activo solo tras construir el Cofre de
## la Base — ver task4.md); en ese caso no se añade nada. true en cualquier otro caso.
func add_item(id: String, quantity: int, _name: String = "", _category: String = "", _icon: String = "") -> bool:
	var def: Dictionary = Design.get_item(id)
	var category: String = String(def.get("category", _category if _category != "" else "other"))
	if category == "equipment":
		if not (_state.debug_mode or _state.is_test_room) and _state.has_camp_structure("chest") and slot_count() >= _state.inventory_slot_cap():
			return false
		for i in range(maxi(1, quantity)):
			add_equipment_item(id)
		return true

	for item: Dictionary in _state.inventory:
		if item["id"] == id:
			item["quantity"] += quantity
			_state.state_updated.emit()
			return true
	if not (_state.debug_mode or _state.is_test_room) and category != "important" and _state.has_camp_structure("chest") and slot_count() >= _state.inventory_slot_cap():
		return false
	var item_name: String = Design.get_item_name(id) if not def.is_empty() else (_name if _name != "" else id)
	var icon: String = String(def.get("icon", _icon if _icon != "" else "❓"))
	_state.inventory.append({
		"id":       id,
		"name":     item_name,
		"quantity": quantity,
		"category": category,
		"icon":     icon
	})
	if id == "tent":
		_state.set_world_flag("tent_ever_obtained", true)
	_state.encyclopedia_unlocked[id] = true   # primera vez que se obtiene: entra en la Enciclopedia
	_state.state_updated.emit()
	return true

## Elimina 'quantity' unidades de un ítem. Devuelve true si tuvo éxito.
func remove_item(id: String, quantity: int) -> bool:
	var inventory: Array = _state.inventory
	for i: int in range(inventory.size()):
		if inventory[i]["id"] == id:
			inventory[i]["quantity"] -= quantity
			if inventory[i]["quantity"] <= 0:
				inventory.remove_at(i)
			_state.state_updated.emit()
			return true
	return false

## Devuelve true si el inventario contiene al menos 'quantity' unidades del ítem.
func has_item(id: String, quantity: int = 1) -> bool:
	for item: Dictionary in _state.inventory:
		if item["id"] == id and item["quantity"] >= quantity:
			return true
	return false

## Obtiene los datos de un ítem por su id, o un diccionario vacío si no existe.
func get_item(id: String) -> Dictionary:
	for item: Dictionary in _state.inventory:
		if item["id"] == id:
			return item
	return {}

#endregion

#region MÉTODOS DE EQUIPAMIENTO

## Nombre traducido de una rareza por su clave (o "" si es común/sin rareza).
func _rarity_name(rarity_key: String) -> String:
	if rarity_key == "":
		return ""
	for r in GameConfig.rarities():
		if String(r.get("key", "")) == rarity_key:
			return Locale.t(String(r.get("loc", "")))
	return ""

## Añade un equipamiento al inventario a partir de su definición base en items.json.
## - `id`: id base del ítem (p. ej. "steel_sword").
## - `rarity`: si se indica, crea una instancia distinta ("<id>_<rarity>") con el
##   nombre prefijado por la rareza (para el botín con multiplicadores).
## - `custom_bonuses`/`custom_combat`: si se pasan, sustituyen a los de la base
##   (usados por el botín para aplicar el multiplicador de rareza).
func add_equipment_item(id: String, rarity: String = "", custom_bonuses: Dictionary = {}, custom_combat: Dictionary = {}) -> void:
	var def: Dictionary = Design.get_item(id)
	var slot: String = String(def.get("slot", "weapon"))
	var icon: String = String(def.get("icon", "🗡️"))
	var base_bonuses: Dictionary = def.get("bonuses", {})
	var base_combat: Dictionary = def.get("combat", {})
	var bonuses: Dictionary = custom_bonuses if not custom_bonuses.is_empty() else base_bonuses
	var combat: Dictionary = custom_combat if not custom_combat.is_empty() else base_combat

	# Id e instancia: con rareza, se guarda como una entrada distinta.
	var store_id: String = id
	var display_name: String = Design.get_item_name(id)
	if rarity != "":
		store_id = "%s_%s" % [id, rarity]
		var rn: String = _rarity_name(rarity)
		display_name = ("%s %s" % [rn, display_name]).strip_edges()

	var equip := EquipmentResource.new()
	equip.id = store_id
	equip.name = display_name
	equip.slot = slot
	equip.icon = icon
	equip.base_id = id
	equip.rarity = rarity
	var default_bonuses = {"str": 0, "agi": 0, "vit": 0, "int": 0, "dex": 0, "luk": 0}
	for k in bonuses:
		default_bonuses[k] = bonuses[k]
	equip.stat_bonuses = default_bonuses
	SaveSerializer.apply_combat_fields(equip, combat)
	equip.element = String(def.get("element", ""))
	var traits = def.get("traits", [])
	equip.traits = traits.duplicate(true) if traits is Array else []

	for item in _state.inventory:
		if item["id"] == store_id:
			item["quantity"] += 1
			_state.state_updated.emit()
			return

	_state.inventory.append({
		"id": store_id,
		"name": display_name,
		"quantity": 1,
		"category": "equipment",
		"icon": icon,
		"resource": equip
	})
	_state.encyclopedia_unlocked[id] = true
	_state.state_updated.emit()

## Equipa un ítem de equipamiento desde el inventario, buscándolo por `id`
## (acepta tanto el id base como el `store_id` con sufijo de rareza).
## Fallback defensivo: si el `id` exacto no aparece (instancias con id/rareza
## generados por rutas distintas, p. ej. botín), se intenta también por
## `resource.id`/`resource.base_id` antes de desistir.
func equip_item(item_id: String) -> void:
	var inventory: Array = _state.inventory
	var found_idx: int = -1
	for i in range(inventory.size()):
		var it: Dictionary = inventory[i]
		if it.get("category") != "equipment":
			continue
		if String(it.get("id", "")) == item_id:
			found_idx = i
			break
		var res: EquipmentResource = it.get("resource")
		if res != null and (res.id == item_id or res.base_id == item_id):
			found_idx = i
			break

	if found_idx == -1:
		push_warning("ItemInventoryManager.equip_item: no se encontró equipamiento con id '%s' en el inventario." % item_id)
		return

	_equip_at_index(found_idx)

## Equipa un ítem de equipamiento identificándolo por su `EquipmentResource`
## exacto (identidad de referencia), sin depender de ningún esquema de `id`.
## Preferible desde la UI cuando ya se tiene el recurso en mano (evita
## cualquier ambigüedad de `store_id` con rareza/instancia única).
func equip_resource(resource: EquipmentResource) -> void:
	if resource == null:
		return
	var inventory: Array = _state.inventory
	var found_idx: int = -1
	for i in range(inventory.size()):
		var it: Dictionary = inventory[i]
		if it.get("category") == "equipment" and it.get("resource") == resource:
			found_idx = i
			break

	if found_idx == -1:
		push_warning("ItemInventoryManager.equip_resource: el recurso '%s' ya no está en el inventario." % resource.name)
		return

	_equip_at_index(found_idx)

## Lógica común de equipar dado el índice ya localizado en `_state.inventory`.
func _equip_at_index(idx: int) -> void:
	var item: Dictionary = _state.inventory[idx]
	var resource: EquipmentResource = item.get("resource")
	if resource == null:
		return

	var slot = resource.slot
	# Desequipar lo que esté puesto en ese slot
	if _state.equipped.get(slot) != null:
		unequip_item(slot)

	# Equipar
	_state.equipped[slot] = resource

	# Restar del inventario
	item["quantity"] -= 1
	if item["quantity"] <= 0:
		_state.inventory.remove_at(idx)

	_state.recalculate_derived_stats()
	_state.state_updated.emit()

## Desequipa el ítem de un slot y lo regresa al inventario.
func unequip_item(slot: String) -> void:
	var resource: EquipmentResource = _state.equipped.get(slot)
	if resource == null:
		return

	# Agregar al inventario
	var found = false
	for item in _state.inventory:
		if item["id"] == resource.id:
			item["quantity"] += 1
			found = true
			break

	if not found:
		_state.inventory.append({
			"id": resource.id,
			"name": resource.name,
			"quantity": 1,
			"category": "equipment",
			"icon": resource.icon,
			"resource": resource
		})

	_state.equipped[slot] = null
	_state.recalculate_derived_stats()
	_state.state_updated.emit()

#endregion
