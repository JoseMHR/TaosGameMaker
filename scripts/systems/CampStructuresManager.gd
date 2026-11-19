class_name CampStructuresManager
extends RefCounted
## GESTOR DE PROGRESIÓN DE LA BASE Y EL CAMPAMENTO — Módulo especialista
## extraído de GlobalState (ver `docs/tasks/task_arreglos.md` §3).
##
## Centraliza la ECONOMÍA de progresión (niveles/costes/consultas) de:
##   - Las construcciones de la Base (`base_levels`, oro + recursos).
##   - El CAMPAMENTO físico por niveles (`camp_level`/`camp_structures`).
##
## NO gestiona la colocación FÍSICA sobre el mapamundi (montar la tienda,
## construir la hoguera, elegir casilla libre): esa lógica manipula
## directamente `hexagons_db`/`CellResource` y sigue viviendo en
## `GlobalState` (`establish_base_at`, `build_camp_structure`,
## `get_campfire_build_spot`, `build_campfire_at`, `is_valid_camp_build_spot`,
## ...) por su fuerte acoplamiento con el renderizado 3D del mundo.
##
## Los DATOS (`base_levels`, `camp_level`, `camp_structures`, `gold`,
## inventario) siguen viviendo en `GlobalState`; este manager sólo aloja la
## LÓGICA y opera sobre ellos a través de una referencia al `GlobalState`
## propietario (`_state`).
##
## `GlobalState` mantiene wrappers-fachada con las mismas firmas públicas
## (`building_level`, `is_building_max`, `building_upgrade_cost`,
## `can_afford_upgrade`, `upgrade_building`, `get_dummy_idle_xp`,
## `get_camp_structure_def`, `has_camp_structure`, `camp_current_structure_key`,
## `camp_level_up_cost`, `can_level_up_camp`, `level_up_camp`) que redirigen a
## este manager, de modo que ningún llamante externo cambia.

## Referencia al autoload GlobalState propietario de los datos.
var _state: Node = null

## Enlaza este manager con el GlobalState propietario. Debe llamarse una única
## vez durante la inicialización del autoload (`GlobalState._ready`).
func setup(state: Node) -> void:
	_state = state


#region NIVELES DE CONSTRUCCIÓN DE LA BASE — Mejoras (sumidero de oro + recursos)
## Nivel actual de una construcción (0 = sin construir).
func building_level(key: String) -> int:
	return int(_state.base_levels.get(key, 0))

## ¿La construcción está al nivel máximo?
func is_building_max(key: String) -> bool:
	return building_level(key) >= GameConfig.BUILDING_MAX_LEVEL

## Coste para subir al siguiente nivel: {"gold": int, "costs": {recurso: cantidad}}.
func building_upgrade_cost(key: String) -> Dictionary:
	var target: int = building_level(key) + 1
	var costs: Dictionary = {}
	for b: Dictionary in GameConfig.BASE_BUILDINGS:
		if b["key"] == key:
			for res in b.get("costs", {}).keys():
				costs[res] = int(ceil(b["costs"][res] * pow(GameConfig.BUILDING_UPGRADE_GROWTH, target - 1)))
			break
	return {"gold": GameConfig.building_upgrade_gold(target), "costs": costs}

## ¿Se puede pagar la mejora (construida, no al máximo, oro + recursos)?
func can_afford_upgrade(key: String) -> bool:
	if building_level(key) < 1 or is_building_max(key):
		return false
	var cost: Dictionary = building_upgrade_cost(key)
	if _state.gold < int(cost["gold"]):
		return false
	for res in cost["costs"].keys():
		if not _state.has_item(res, int(cost["costs"][res])):
			return false
	return true

## Sube de nivel una construcción ya construida. Devuelve true si tuvo éxito.
func upgrade_building(key: String) -> bool:
	if not can_afford_upgrade(key):
		return false
	var cost: Dictionary = building_upgrade_cost(key)
	_state.gold -= int(cost["gold"])
	for res in cost["costs"].keys():
		_state.remove_item(res, int(cost["costs"][res]))
	_state.base_levels[key] = building_level(key) + 1
	_state.recalculate_derived_stats()
	_state.state_updated.emit()
	return true

## XP por tick del Muñeco de entrenamiento según su nivel.
func get_dummy_idle_xp() -> int:
	var lvl: int = building_level("dummy")
	if lvl <= 0:
		return GameConfig.TRAINING_IDLE_XP
	var arr: Array = GameConfig.DUMMY_XP_BY_LEVEL
	return int(arr[clampi(lvl - 1, 0, arr.size() - 1)])
#endregion


#region PROGRESIÓN POR NIVELES DEL CAMPAMENTO (evolución en cola)
## Busca la definición de una construcción del campamento por su `key`, o {}.
func get_camp_structure_def(key: String) -> Dictionary:
	for s in GameConfig.camp_structures():
		if String(s.get("key", "")) == key:
			return s
	return {}

## ¿Ya está construida esta construcción del campamento?
func has_camp_structure(key: String) -> bool:
	return _state.camp_structures.has(key)

## Construcción que desbloquea el NIVEL ACTUAL del campamento ("" si ya están
## todas construidas). La evolución es una cola estricta: GameConfig.camp_structures()[0]
## se desbloquea en el Nivel 1, la [1] en el Nivel 2, etc. Cada nivel desbloquea
## ÚNICAMENTE esa construcción; el resto permanece bloqueado hasta llegar a su turno.
func camp_current_structure_key() -> String:
	var structs: Array = GameConfig.camp_structures()
	if _state.camp_level < 1 or _state.camp_level > structs.size():
		return ""
	return String(structs[_state.camp_level - 1].get("key", ""))

## Coste en madera para subir el campamento al SIGUIENTE nivel: se dobla en cada
## nivel respecto al coste base de montar el campamento (GameConfig.CAMP_WOOD_COST).
func camp_level_up_cost() -> int:
	return GameConfig.CAMP_WOOD_COST * int(pow(2, maxi(0, _state.camp_level - 1)))

## ¿Se puede subir de nivel el campamento ahora? Requiere haber construido YA la
## construcción del nivel actual y que queden niveles/construcciones pendientes.
func can_level_up_camp() -> bool:
	if not _state.has_built_base:
		return false
	var cur := camp_current_structure_key()
	if cur == "":
		return false   # ya se desbloquearon todas las construcciones
	return has_camp_structure(cur)

## Sube el campamento un nivel, cobrando madera (camp_level_up_cost). Devuelve ""
## si OK, o un motivo de error ("no_camp" | "not_ready" | "no_resources").
func level_up_camp() -> String:
	if not _state.has_built_base:
		return "no_camp"
	if not can_level_up_camp():
		return "not_ready"
	var cost := camp_level_up_cost()
	if not _state.has_item("wood", cost):
		return "no_resources"
	_state.remove_item("wood", cost)
	_state.camp_level += 1
	_state.state_updated.emit()
	return ""
#endregion
