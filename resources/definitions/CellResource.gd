# CellResource.gd
# Recurso personalizado que define cualquier casilla del mapamundi.
# Permite crear nuevas casillas desde el editor: clic derecho -> Nuevo Recurso -> CellResource
class_name CellResource
extends Resource

@export var coord: Vector2i = Vector2i.ZERO
@export var name: String = "Pradera Despejada"
@export var name_i18n: Dictionary = {}
@export var icon: String = "🌱"
@export var biome_color: Color = Color("1c2b17")
@export var description: String = "Una zona tranquila y vacía."
@export var desc_i18n: Dictionary = {}

# ─────────────────────────────────────────────────────────────────────────────
# MODELO EN 3 CAPAS ORTOGONALES  (fácil de ampliar y de autorizar por casilla)
#   1) terrain  — el SUELO/bioma (siempre presente). Decide color, si es
#      transitable (mar/montana no lo son) y el peligro ambiental (desierto→
#      insolación, nieve→congelación).
#   2) item     — una LOCALIZACIÓN fija encima del suelo ("" = ninguna). Al pulsar
#      ENTRAR abre su vista (ciudad/aldea→ciudad, cueva→mazmorra, casita/templo/
#      place/ruinas→lugar).
#   3) resource — un ELEMENTO GASTABLE/modificable ("" = ninguno): canteras, bosque,
#      árboles en mal estado, ganado, pesca, o la base. Abre la vista de recolección.
#
#   Para AÑADIR una casilla basta con fijar terrain (+ opcionalmente item o
#   resource) en data/world.json / data/ids.json (editor visual). El resto
#   (visual, gating, interacción) se deriva.
# ─────────────────────────────────────────────────────────────────────────────
@export_enum("grs", "des", "are", "ice", "icy", "bad", "gnd", "cst", "sea", "mnt", "lav", "pth")
var terrain: String = "grs"

## Localización fija: "" | "ciudad" | "aldea" | "casita" | "cueva" | "templo" | "place" | "ruinas"
@export var item: String = ""

## Elemento gastable: "" | "rock" | "gold" | "forest" | "forestBad" | "base" | "campfire" | "milk" | "fish"
## `base` = tienda de campaña (dormir); `campfire` = hoguera (cocinar). Ambos son
## items FÍSICOS del campamento (pilar "Transformar"), no nodos de recolección.
@export var resource: String = ""

## ¿Es camino de piedra? (+50% velocidad, bloquea enemigos)
func has_stone_path() -> bool:
	return terrain == "pth"

# Si esta casilla requiere que una misión esté en cierto estado para poder entrar
@export var required_quest_state: String = "" # "" significa libre acceso

# Si al pisar esta casilla se desencadena un avance de la misión principal
@export var trigger_quest_state: String = ""

# Si al pisar esta casilla se desencadena un evento específico de events.json
@export var trigger_event: String = ""

# ID de evento para el QuestManager (para no depender de coordenadas fijas en el código)
@export var event_id: String = ""
var object: String:
	get: return event_id

# Diálogo opcional asociado que se activa al entrar
@export var dialogue: DialogueResource = null

## PORTAL data-driven: permite que este POI abra una vista/escena
## concreta al pulsar ENTRAR, desacoplado del `item`/`type`. Se rellena desde
## `ids.json` (`spec.portal`). Formato:
##   { "view": "dungeon"|"place"|"city"|"gather", "event_id": "dun_demo" }
## `view` decide la vista (SceneManager); `event_id` (opcional) el destino/layout.
## Caso especial `view:"event"`: NO cambia de vista; ejecuta el evento
## `event_id` (events.json) EN EL SITIO (p. ej. lanzar una cinemática con `cine:`).
## `label` (opcional) fija el texto del botón ENTRAR para este POI.
@export var portal: Dictionary = {}

## AMBIENTE data-driven por casilla: override opcional de música
## y/o clima para este POI, con prioridad sobre el ambiente por terreno. Se rellena
## desde `ids.json` (`spec.ambience`). Formato: { "music": "world", "weather": "snow" }.
@export var ambience: Dictionary = {}

## OBSTÁCULO ROMPIBLE data-driven: una
## casilla que puede modificarse con una HERRAMIENTA (hacha/pico/pala) para abrir
## caminos, talar, excavar o canalizar agua. El cambio se PERSISTE vía world_deltas
## (queda hecho para siempre). Se rellena desde `ids.json` (`spec.obstacle`).
## Formato:
##   { "tool": "pico", "hits": 1,
##     "reward": { "item": "stone", "qty": 3 },
##     "after": { "terrain": "gnd", "resource": "" },   # cambios (formato DSL set)
##     "label": { "es": "Picar roca", "en": "Mine rock" }, "sfx": "hit" }
## `tool` = id del item-herramienta requerido. `after` = estado resultante de la
## casilla (mismas claves que world_transforms). Vacío/ausente = sin obstáculo.
@export var obstacle: Dictionary = {}

## PUERTA/MURO CONDICIONADO data-driven (incidencia de gating): mientras no
## se cumpla la condición, esta casilla forma un MURO DE 3 CASILLAS (ella + sus 2
## vecinas perpendiculares) que impide cruzar hacia `dir`, de modo que no se puede
## rodear. Se rellena desde `ids.json` (`spec.gate`). Formato:
##   { "dir": "north"|"south"|"east"|"west", "open_when": "<expresión>"? }
## `dir` = dirección BLOQUEADA (no puedes pasar más allá de la casilla hacia ese lado).
## `open_when` = condición (Godot Expression, ver Design.eval_condition); si evalúa a
## `true` el muro se abre. Ejemplos: "gate_flag('cave_cleared')", "gate_flag('monkey_cleared')".
## SIN `open_when` el muro es PERMANENTE (nunca se abre caminando; p. ej. las
## dos "puertas" de una mazmorra con entradas propias, que solo se cruzan
## atravesándola). `gate` vacío/ausente en la casilla = sin puerta (acceso libre).
@export var gate: Dictionary = {}

## OBJETO INTERACTIVO GENÉRICO data-driven: un elemento físico del mundo
## (cartel, lápida, libro, monumento, estatua, pergamino…) que al pulsar ENTRAR
## muestra una ventana con texto configurable y un botón Aceptar. Reutilizable: el
## `kind` decide el modelo low-poly y el icono por defecto. Se rellena desde
## `ids.json` (`spec.interactive`) o inline en `world.json` (`tile.interactive`).
## Formato:
##   { "kind": "sign"|"tombstone"|"book"|"monument"|...,
##     "icon": "🪧",
##     "title": { "es": "Cartel", "en": "Sign" },
##     "text":  { "es": "…", "en": "…" } }
## Vacío/ausente = no es un objeto interactivo.
@export var interactive: Dictionary = {}

## ENEMIGO DEL MAPAMUNDI data-driven: marca esta casilla como el PUNTO DE
## APARICIÓN de un enemigo que deambula por el mundo. El enemigo es un actor
## dinámico (no bloquea la casilla): se mueve lento y aleatorio sin alejarse más de
## una casilla de aquí, nunca persigue al jugador y, al contacto, inicia combate.
## Al vencerlo desaparece y (si `respawn` > 0) reaparece pasados esos segundos.
## Se rellena desde `ids.json` (`spec.enemy`) o inline en `world.json` (`tile.enemy`).
## Formato:
##   { "enemy_id": "slime", "level": 1, "sprite": "🟢",
##     "move_interval": 2.5,   # segundos entre pasos (por defecto 2.5)
##     "respawn": 60 }         # segundos para reaparecer tras morir (0 = nunca)
## Vacío/ausente = no hay enemigo.
@export var enemy: Dictionary = {}

## COFRE DEL MAPAMUNDI data-driven: contiene recompensas (oro e ítems)
## que se obtienen al pisar/tocar la casilla o pulsar ENTRAR.
## Formato: { "gold": 50, "items": [{"id": "potion", "qty": 1}] }
@export var chest: Dictionary = {}

## Runtime: indica si el nodo de recolección de esta casilla está agotado.
## Lo actualizan WorldMapBuilder al construir y TabWorld3D al refrescar visuales.
var _gather_depleted: bool = false
func set_gather_depleted(v: bool) -> void: _gather_depleted = v
func is_gather_depleted() -> bool: return _gather_depleted

## CULTIVO data-driven (Agricultor): una semilla plantada en esta casilla, ajena
## a la capa `resource` (nodos de recolección genéricos) para no heredar su
## solidez/ViewGather/capacidad por toques, que no encajan con "esperar 24h y
## cosechar una vez". Formato: { "type": "semilla_trigo", "planted_at": <unix_ts> }.
## `type` = clave de `GameConfig.CROP_TYPES`. Vacío/ausente = sin cultivo.
## Se rellena vía `TerrainToolsSystem.apply_terrain_action` (world_deltas).
@export var crop: Dictionary = {}

## ¿Hay una semilla plantada en esta casilla?
func is_growing_crop() -> bool:
	return crop is Dictionary and not crop.is_empty()

## ¿La semilla plantada ya maduró? Madura tras un ciclo día/noche completo
## (`TimeManager.full_day_duration_sec()`, "24 horas de juego") en segundos
## reales desde `planted_at`, sin necesidad de un segundo estado persistido.
func is_crop_mature() -> bool:
	if not is_growing_crop():
		return false
	var planted_at: int = int(crop.get("planted_at", 0))
	return int(Time.get_unix_time_from_system()) - planted_at >= int(TimeManager.full_day_duration_sec())

# ─────────────────────────────────────────────────────────────────────────────
# CAMPOS LEGADO (derivados de terrain/item/resource por derive_legacy()).
#   Se conservan para el código y datos que aún consultan `type`/`required_skill`.
#   No los edites a mano: se recalculan al construir el mundo.
# ─────────────────────────────────────────────────────────────────────────────
@export var type: String = "empty"
@export var required_skill: String = "ninguna"


# ══════════════════════════════════════════════════════════════════════════════
# CONSULTAS DERIVADAS (usadas por el mundo 3D, el gating y la interacción)
# ══════════════════════════════════════════════════════════════════════════════

## ¿Se puede pisar el terreno de esta casilla? DATA-DRIVEN: lo decide
## `data/world_terrains/<code>.json` (campo `walkable`); si el terreno no está
## definido allí, se mantiene la regla cableada de siempre (el mar y la
## montaña no son transitables).
func is_walkable_terrain() -> bool:
	return Design.terrain_is_walkable(terrain)


## ¿Es un nodo de recolección (bosque/cantera/ganado/pesca…)? El campamento
## (tienda/hoguera) NO cuenta: son items físicos con los que se interactúa aparte.
## El "bloqueo de piedra" tampoco cuenta: no se recolecta, se destruye con una
## bomba desde una casilla adyacente (ver TerrainToolsSystem.has_bombable_target).
func is_gather_node() -> bool:
	return resource != "" and resource != "base" and resource != "campfire" and resource != "bloqueo_piedra"


## Habilidad de oficio que requiere el recurso de esta casilla ("" si no aplica).
func gather_skill() -> String:
	var info: Dictionary = Design.resolve_gather_resource(resource)
	return String(info.get("skill", ""))


## ¿Bloquea el paso por su centro? (ciudades, casas, canteras, base…; la pesca no,
## para poder acercarse a la orilla).
func is_solid() -> bool:
	if item != "" and item != "chest":
		return true
	if resource == "base" or resource == "campfire":
		return true
	if resource == "bloqueo_piedra" or (obstacle is Dictionary and not obstacle.is_empty()):
		return true
	if event_id.begins_with("camp_"):
		return true   # construcciones físicas del campamento (cofre/herrería/…)
	if not is_gather_node() or resource == "fish":
		return false
	return GlobalState.get_gather_remaining(coord) > 0


## ¿Tiene algo con lo que interactuar al pulsar ENTRAR?
func is_interactive() -> bool:
	if portal is Dictionary and String(portal.get("view", "")) != "":
		return true
	if interactive is Dictionary and not interactive.is_empty():
		return true
	if chest is Dictionary and not chest.is_empty():
		return true
	return item != "" or resource != "" or event_id != "" \
		or event_id.begins_with("camp_")


## ¿Es un Punto de Interés (POI), mazmorra, ciudad, puente, portal o estructura interactiva?
func is_poi() -> bool:
	if event_id != "":
		return true
	if portal is Dictionary and not portal.is_empty():
		return true
	if gate is Dictionary and not gate.is_empty():
		return true
	if interactive is Dictionary and not interactive.is_empty():
		return true
	if chest is Dictionary and not chest.is_empty():
		return true
	if enemy is Dictionary and not enemy.is_empty():
		return true
	if obstacle is Dictionary and not obstacle.is_empty():
		return true
	if item in ["ciudad", "aldea", "cueva", "ruinas", "casita", "templo", "place", "presa", "puente", "puerto", "pesca", "chest"]:
		return true
	if type in ["town", "dungeon", "place", "chest", "base", "campfire", "cinematic"]:
		return true
	var ov := opens_view()
	if ov != "" and ov != "gather":
		return true
	return false


## Clave de navegación (SceneManager) al pulsar ENTRAR, o "" si no hay interacción.
func opens_view() -> String:
	# Un portal data-driven manda: abre la vista que declare (ids.json spec.portal).
	if portal is Dictionary and String(portal.get("view", "")) != "":
		return String(portal["view"])
	if type == "cinematic" or item == "cinematic":
		return "cinematic"
	if interactive is Dictionary and (String(interactive.get("kind", "")) == "cinematic" or interactive.has("cinematic")):
		return "cinematic"
	if type == "town" or item in ["ciudad", "aldea"]:
		return "city"
	if type == "dungeon" or item in ["cueva", "ruinas"]:
		return "dungeon"
	if type == "place" or item in ["casita", "templo", "place", "presa", "puente", "puerto", "pesca"] or (event_id.begins_with("poi_") or event_id.begins_with("house_") or event_id.begins_with("templo_") or event_id.begins_with("sendero_")):
		return "place"
	if resource == "base":
		return "base"
	if resource == "campfire":
		return "campfire"
	if event_id.begins_with("camp_"):
		return "camp_struct"   # cofre/herrería/… construidos en el campamento
	if interactive is Dictionary and not interactive.is_empty():
		return "interactive"
	if chest is Dictionary and not chest.is_empty():
		return "chest"
	if is_gather_node():
		return "gather"
	if item != "":
		return "place"
	return ""


## Recalcula los campos legado (type/required_skill) a partir del modelo nuevo.
## Lo llama WorldMapBuilder para cada casilla tras generarla o cargarla.
func derive_legacy() -> void:
	required_skill = gather_skill() if is_gather_node() else "ninguna"
	if item == "ciudad" or item == "aldea":
		type = "town"
	elif item == "cueva" or item == "ruinas":
		type = "dungeon"
	elif item == "casita" or item == "templo" or item == "place" or item == "presa" or event_id.begins_with("poi_") or event_id.begins_with("house_") or event_id.begins_with("templo_") or event_id.begins_with("sendero_"):
		type = "place"
	elif resource == "base" or resource == "campfire":
		type = "base"
	elif event_id.begins_with("camp_"):
		type = "base"
	elif (chest is Dictionary and not chest.is_empty()) or item == "chest":
		type = "chest"
	elif interactive is Dictionary and not interactive.is_empty():
		type = "interactive"
	elif is_gather_node():
		type = "gather"
	elif terrain == "sea":
		type = "water"
	elif terrain == "mnt":
		type = "mountain"
	elif terrain == "cst":
		type = "shore"
	elif item != "" or event_id != "":
		type = "place"
	else:
		type = "empty"


## Devuelve el nombre de la casilla traducido al idioma activo.
func get_display_name() -> String:
	if not name_i18n.is_empty():
		return Locale.pick(name_i18n)
	if event_id != "":
		var spec: Dictionary = Design.get_id(event_id)
		if not spec.is_empty():
			var nm = spec.get("name", null)
			if nm is Dictionary:
				return Locale.pick(nm)
	if interactive is Dictionary and interactive.has("title"):
		var it = interactive["title"]
		if it is Dictionary:
			return Locale.pick(it)
		elif it is String and it != "":
			return Locale.translate_cell_name(it)
	return Locale.translate_cell_name(name)


## Devuelve la descripción de la casilla traducida al idioma activo.
func get_display_description() -> String:
	if not desc_i18n.is_empty():
		return Locale.pick(desc_i18n)
	if event_id != "":
		var spec: Dictionary = Design.get_id(event_id)
		if not spec.is_empty():
			var ds = spec.get("desc", null)
			if ds is Dictionary:
				return Locale.pick(ds)
	if interactive is Dictionary and interactive.has("text"):
		var tx = interactive["text"]
		if tx is Dictionary:
			return Locale.pick(tx)
		elif tx is String and tx != "":
			return Locale.translate_cell_desc(name, tx)
	return Locale.translate_cell_desc(name, description)
