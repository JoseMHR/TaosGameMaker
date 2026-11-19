class_name SaveSerializer
## Conversores puros (sin estado) de (de)serialización usados por GlobalState.
## Transforman ítems/equipamiento entre Diccionario (JSON) y objetos del juego, y
## contienen utilidades de migración de guardados antiguos. No guardan estado: toda
## la información entra por parámetros y sale por el valor de retorno.

## Mapea claves de profesión antiguas a las nuevas (guardados previos).
static func migrate_profession(prof: String) -> String:
	match prof:
		"Arquera":          return "Arquero"
		"Psíquica":         return "Psíquico"
		"Curandera":        return "Sacerdote"
		"Curandero":        return "Sacerdote"
		"Mago del Tiempo":  return "Tiempo"
		_:                  return prof


## Fusiona sobre una copia de `base` los enteros presentes en `src` (si es Dictionary).
static func merge_int_dict(base: Dictionary, src) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	if src is Dictionary:
		for k in out.keys():
			if src.has(k):
				out[k] = int(src[k])
	return out


## Reconstruye una entrada de inventario desde su forma serializada.
static func deserialize_item(entry) -> Dictionary:
	var id: String = String(entry.get("id", ""))
	if entry.has("resource") and entry["resource"] != null:
		# Equipamiento: reconstruir a partir del recurso serializado.
		var res: EquipmentResource = dict_to_equipment(entry["resource"])
		return {
			"id":       id,
			"name":     res.name,
			"quantity": int(entry.get("quantity", 1)),
			"category": "equipment",
			"icon":     res.icon,
			"resource": res,
		}
	# Ítem común: resolver metadatos desde items.json (con fallback a lo guardado).
	var def: Dictionary = Design.get_item(id)
	var item_name: String = Design.get_item_name(id) if not def.is_empty() else String(entry.get("name", id))
	var category: String = String(def.get("category", entry.get("category", "other")))
	var icon: String = String(def.get("icon", entry.get("icon", "❓")))
	return {
		"id":       id,
		"name":     item_name,
		"quantity": int(entry.get("quantity", 1)),
		"category": category,
		"icon":     icon,
	}


## Serializa un EquipmentResource a un Diccionario apto para JSON.
static func equipment_to_dict(res: EquipmentResource) -> Dictionary:
	return {
		"id":           res.id,
		"name":         res.name,
		"icon":         res.icon,
		"slot":         res.slot,
		"base_id":      res.base_id,
		"rarity":       res.rarity,
		"stat_bonuses": res.stat_bonuses.duplicate(true),
		"phys_damage":  res.phys_damage,
		"mag_damage":   res.mag_damage,
		"range_damage": res.range_damage,
		"phys_defense": res.phys_defense,
		"mag_defense":  res.mag_defense,
		"refine_level": res.refine_level,
		"element":      res.element,
		"traits":       res.traits.duplicate(true),
	}


## Aplica un diccionario de bonus de combate sobre un EquipmentResource.
static func apply_combat_fields(equip: EquipmentResource, combat: Dictionary) -> void:
	equip.phys_damage  = int(combat.get("phys_damage", 0))
	equip.mag_damage   = int(combat.get("mag_damage", 0))
	equip.range_damage = int(combat.get("range_damage", 0))
	equip.phys_defense = int(combat.get("phys_defense", 0))
	equip.mag_defense  = int(combat.get("mag_defense", 0))


## Reconstruye un EquipmentResource desde su Diccionario serializado.
static func dict_to_equipment(d: Dictionary) -> EquipmentResource:
	var res := EquipmentResource.new()
	res.id   = d.get("id", "")
	res.name = d.get("name", "")
	res.icon = d.get("icon", "🗡️")
	res.slot = d.get("slot", "weapon")
	res.base_id = d.get("base_id", "")
	res.rarity  = d.get("rarity", "")
	var bonuses := {"str": 0, "agi": 0, "vit": 0, "int": 0, "dex": 0, "luk": 0}
	var sb = d.get("stat_bonuses", {})
	if sb is Dictionary:
		for k in sb.keys():
			if bonuses.has(k):
				bonuses[k] = int(sb[k])
	res.stat_bonuses = bonuses
	res.phys_damage  = int(d.get("phys_damage", 0))
	res.mag_damage   = int(d.get("mag_damage", 0))
	res.range_damage = int(d.get("range_damage", 0))
	res.phys_defense = int(d.get("phys_defense", 0))
	res.mag_defense  = int(d.get("mag_defense", 0))
	res.refine_level = int(d.get("refine_level", 0))
	res.element      = String(d.get("element", ""))
	var traits = d.get("traits", [])
	res.traits       = traits.duplicate(true) if traits is Array else []
	return res
