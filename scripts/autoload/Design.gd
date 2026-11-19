# Design.gd
# Autoload Singleton — CARGADOR DE DISEÑO DATA-DRIVEN.
# Lee los JSON de diseño (`data/world.json`, `data/ids/<id>.json`,
# `data/npcs/<npc_id>.json`) y ofrece a las vistas todo lo necesario para
# construir el mundo, las ciudades y los diálogos SIN datos incrustados en GDScript.
#
# Contratos que expone:
#   - world  : { width, height, tiles:[[ {terrain, object?} ]] }
#   - ids     : { id -> { id, type, name{es,en}, icon?, desc?, kind?, npc?, stock?, bg?, content? } }
#   - get_npc(npc_id) : { node_id -> { type, text{es,en}, next[], reward, condition? } } (NPCS_DIR, perezoso)
#
# Motor de diálogo (nodos planos):
#   - Un nodo "message" cuya condición se cumple y que NO es destino de ningún
#     `next` es una ENTRADA. `entry_node()` elige la primera entrada válida.
#   - Un nodo "option" se muestra como botón si su condición se cumple.
#   - `condition` es una Expression de Godot; `reward` es un mini-lenguaje.
#
# Mini-lenguaje de `reward` (tokens separados por ';'):
#   gold:-30 | xp:15 | heal | faceta:amabilidad=+1 | item:banana=1 | -item:diario=1
#   flag:regular | relation:+2 | questf:knows_dam | quests:explorer_missing
#   prof:Guerrero | dam | qaction:give_banana
#   Sistema Multi-Quest (misiones secundarias/paralelas, independientes de la
#   historia principal — ver task_arreglos.md §1):
#     quest_start:id | quest_start:id:stage | quest_stage:id=stage
#     quest_complete:id | quest_fail:id
#
# Variables disponibles en `condition`:
#   quest (String), gold, valentia, amabilidad, encanto, astucia, relation, visits (int)
#   Funciones: has_item("id"[,n]), no_item("id"), has_flag("f"), no_flag("f")
#   gflag("f"), no_gflag("f")
#   has_quest("id"), quest_stage("id"), quest_done("id") — Sistema Multi-Quest
extends Node

# ─── RUTAS DE DATOS ───────────────────────────────────────────────────────────
const WORLD_PATH      := "res://data/world.json"
const WORLD_TEST_PATH := "res://data/world_test.json"
## Cada entidad del mapamundi (ciudad, POI, mazmorra, lugar...) vive en su
## propio fichero `res://data/ids/<id>.json` (una por fichero, no un monolito):
## así se localiza y edita cada una de forma aislada. A diferencia de las
## mazmorras, aquí SÍ se cargan TODAS de golpe en `reload()` (son fichas
## pequeñas y se consultan constantemente, incluida una pasada de índice
## inverso para Locale; no compensa la complejidad de una caché perezosa).
const IDS_DIR         := "res://data/ids/"
## Catálogo de tipos de casilla de mazmorra: cada tipo vive en su propio
## fichero `res://data/dungeon_tiles/<t>.json` (metadatos de editor + `render`
## opcional para las casillas cosméticas simples). Se carga entera en
## `reload()` (son ~30 fichas minúsculas). Ver `get_dungeon_tile_render()`.
const DUNGEON_TILES_DIR := "res://data/dungeon_tiles/"
## Catálogo de terrenos del mapamundi: cada código vive en su propio fichero
## `res://data/world_terrains/<code>.json` (física: walkable/damage/speed_mult/
## render 3D 100% data-driven vía TabWorld3D._make_ground_material: texture/tint/
## tint_boost/roughness/emission/emission_energy/emission_pulse/uv_scroll/wave +
## visual: label/color/icon/biome_color/description, con `variants` opcional para
## sub-biomas aleatorios como la pradera). Sustituye al antiguo monolito
## `terrains.json`. Ver `get_terrain_def()`.
const WORLD_TERRAINS_DIR := "res://data/world_terrains/"
## Catálogo de recursos genéricos farmeables del mapamundi (forest/rock/fish/
## milk y sus variantes forestBad/gold): cada código vive en su propio
## fichero `res://data/world_resources/<code>.json`. Ver `get_world_resource()`.
const WORLD_RESOURCES_DIR := "res://data/world_resources/"
## Catálogo de EDIFICIOS del mapamundi vía ASSET (sin código): cada código vive
## en su propio fichero `res://data/world_buildings/<code>.json`
## `{ label, icon, scene, scale?, y_offset?, description? }`, donde `scene` es
## una `.tscn` construida en el editor 3D de Godot (o un modelo importado). Es
## la vía para AÑADIR un edificio nuevo sin GDScript: se registra aquí desde el
## editor y `GenericMarkers.make_marker()` la instancia si `cell.item` coincide con
## el código. Los 6 edificios procedurales cableados (ciudad/aldea/casita/
## templo/cueva/ruinas, en `scenes/tabs/tab_world_3d/buildings/`) siguen
## teniendo prioridad y no usan este catálogo. Ver `get_world_building()`.
const WORLD_BUILDINGS_DIR := "res://data/world_buildings/"
## Overrides visuales OPCIONALES para las 8 maquetas procedurales
## cableadas de arriba (ciudad/aldea/casita/templo/place/cueva/ruinas/presa):
## un único documento `{ code -> { wall_color?, roof_color?, scale? } }`. Si un
## código no tiene entrada (o falta un campo), la maqueta usa su color/escala
## cableado de siempre — este fichero NUNCA es obligatorio. Ver
## `get_classic_building_style()` y `GenericMarkers.make_marker()`.
const WORLD_BUILDINGS_CLASSIC_PATH := "res://data/world_buildings_classic.json"
## Cada NPC vive en su propio fichero `res://data/npcs/<npc_id>.json` (su árbol
## de diálogos completo, incluido el nodo especial "_meta"): evita cargar TODOS
## los diálogos del juego en RAM al arrancar cuando solo hace falta el NPC con
## el que el jugador está hablando AHORA. Carga PEREZOSA y cacheada por id (ver
## `_npc_cache` / `get_npc()`); a diferencia de las mazmorras, no se desaloja al
## alejarse (el contenido total es pequeño y no compensa la complejidad).
const NPCS_DIR        := "res://data/npcs/"
## Ficha descriptiva de cada misión SECUNDARIA del Sistema Multi-Quest (ver
## task_arreglos.md §1): `res://data/quests_secondary/<quest_id>.json`, forma
## `{ "title": {es,en}, "stages": { "0": {"title":{es,en},"hint":{es,en}}, ... } }`.
## Carga perezosa y cacheada por id, mismo patrón que `get_npc()`.
const QUESTS_SECONDARY_DIR := "res://data/quests_secondary/"
## Catálogo de ÍTEMS: cada uno vive en su propio fichero
## `res://data/items/<item_id>.json` (fichas ligeras que consulta constantemente
## el inventario/tienda/botín).
const ITEMS_DIR       := "res://data/items/"
## Catálogo de ENEMIGOS: cada uno vive en su propio fichero
## `res://data/enemies/<enemy_id>.json` (una por fichero, no un monolito, igual
## que IDS_DIR). A diferencia de los NPCs, SÍ se carga TODO de golpe en
## `reload()`: son fichas ligeras que consulta constantemente el Bestiario y el
## combate (aleatorizar enemigo, resolver botín…).
const ENEMIES_DIR     := "res://data/enemies/"
const PROFESSIONS_PATH := "res://data/professions.json"
const SKILLS_PATH     := "res://data/skills.json"
const ENEMY_SKILLS_PATH := "res://data/enemy_skills.json"
const SYNERGIES_PATH  := "res://data/synergies.json"
## Cada mazmorra vive en su propio fichero `res://data/dungeons/<event_id>.json`
## (una por fichero, no un monolito): evita cargar TODAS las mazmorras en RAM
## al arrancar y que el editor tenga que reescribir un JSON gigante para tocar
## una sola. Ver `_ensure_dungeon_ids()` / `get_dungeon_layout()`.
const DUNGEONS_DIR    := "res://data/dungeons/"
const DUNGEON_KITS_PATH := "res://data/dungeon_kits.json"
const EVENTS_PATH     := "res://data/events.json"
const QUESTS_PATH     := "res://data/quests.json"
const WORLD_TRANSFORMS_PATH := "res://data/world_transforms.json"
const SHOPS_PATH      := "res://data/shops.json"
const AMBIENCE_PATH   := "res://data/ambience.json"
const DIALOGUES_PATH  := "res://data/dialogues.json"
## Catálogo de ESCENAS del Sistema Narrativo: cada una vive en su
## propio fichero `res://data/scenes/<scene_id>.json`. OPCIONAL: si la carpeta no existe, el juego
## sigue usando npcs.json/dialogues.json como fuentes clásicas.
const SCENES_DIR      := "res://data/scenes/"
const CINEMATICS_DIR  := "res://data/cinematics/"
const ACHIEVEMENTS_PATH := "res://data/achievements.json"
const TUTORIALS_PATH  := "res://data/tutorials.json"
## Códice de Curiosidades (Task 2): catálogo de entradas de lore ambiental que se
## descubren inspeccionando POIs / conociendo PNJs singulares. OPCIONAL.
const CODEX_PATH      := "res://data/codex.json"

# ─── ESTADO CARGADO ───────────────────────────────────────────────────────────
var world: Dictionary = {}
var ids: Dictionary = {}
var dungeon_tiles: Dictionary = {}  # t -> { label, icon, color, group, solid?, entity?, ..., render?:{shape,...} } (DUNGEON_TILES_DIR)
var world_terrains: Dictionary = {}  # code -> { label, color, icon, biome_color, description?, walkable?, damage?, damage_interval?, speed_mult?, texture?, tint?, tint_boost?, roughness?, emission?, emission_energy?, emission_pulse?, uv_scroll?:[x,y], wave?, variants?:[{weight,label,icon,biome_color}] } (WORLD_TERRAINS_DIR)
var world_resources: Dictionary = {} # code -> { label, icon, biome_color, description?, placeable? } (WORLD_RESOURCES_DIR)
var world_buildings: Dictionary = {} # code -> { label, icon, scene, scale?, y_offset?, description? } (WORLD_BUILDINGS_DIR)
var world_buildings_classic: Dictionary = {} # code -> { wall_color?, roof_color?, scale? } overrides de las 8 maquetas cableadas (WORLD_BUILDINGS_CLASSIC_PATH)
var items: Dictionary = {}      # id -> { name{es,en}, desc{es,en}, icon, category, usable, ... }
var enemies: Dictionary = {}    # id -> { name{es,en}, base_*, *_scale, skills[], loot[], ... } (ENEMIES_DIR)
## Caché perezosa de diálogos de NPC cargados por id (ver NPCS_DIR). Cada
## entrada es el árbol de nodos completo de ese NPC (incluido "_meta"). NO se
## rellena entera al arrancar: solo al pedir un NPC concreto (ver `get_npc()`).
var _npc_cache: Dictionary = {}   # npc_id -> nodos Dictionary (lazy)
## Caché perezosa de fichas de misión secundaria (ver QUESTS_SECONDARY_DIR /
## get_quest_secondary()). Igual patrón que `_npc_cache`.
var _quest_secondary_cache: Dictionary = {}   # quest_id -> ficha Dictionary (lazy)
var professions: Dictionary = {} # id -> { name{es,en}, icon, color, skills:[{level,id}] }
var skills: Dictionary = {}        # id -> definición completa de habilidad (skills.json)
var enemy_skills: Dictionary = {}  # id -> { name{es,en}, role, power_mult, type, element, status?, self_status? } (enemy_skills.json)
var synergies: Array = []          # [{ profession, required_ids:[a,b], result_id }]
## Caché perezosa de mazmorras cargadas por id (ver DUNGEONS_DIR). Cada entrada
## es { name, music, boss, random_pool, cell_size, wall_height, spawn, floors[] }.
## NO se rellena entera al arrancar: solo al pedir una mazmorra concreta.
var _dungeon_cache: Dictionary = {}   # event_id -> layout Dictionary (lazy)
## Ids de mazmorras disponibles (nombres de fichero de DUNGEONS_DIR sin ".json").
## Se escanea una sola vez de forma perezosa; ver `_ensure_dungeon_ids()`.
var _dungeon_ids: PackedStringArray = PackedStringArray()
var _dungeon_ids_scanned: bool = false
var dungeon_kits: Dictionary = {} # { kits:{kit_id->{label,verb,icon,color}}, pieces:{piece_id->{kit,name,icon,archetype,shape,color,reaction,...}} }
var events: Dictionary = {}        # event_id -> { condition?, actions:[token], ... } (opcional)
var quests: Dictionary = {}        # { order:[estado], combat_victory:{enemy_id:{event}}, ... } (opcional)
var world_transforms: Dictionary = {} # name -> { rules:[{match,set}] } | { builtin:name } (opcional)
var shops: Dictionary = {}         # stock_id -> [{id, price}] (opcional; fallback GameConfig.SHOP_STOCKS)
var ambience: Dictionary = {}      # { music:{id->path}, terrain:{code->{music?,weather?}}, weather:{id->{...}} } (opcional)
var dialogues: Dictionary = {}     # dialogue_id -> { npc_name{es,en}, npc_avatar, text{es,en}, choices:[{text{es,en}, action}] } (opcional)
## Lazy-loaded (ver `_ensure_dialogues_loaded`): `false` hasta que
## `get_dialogue()` lo necesita por primera vez tras cada `reload()`.
var _dialogues_loaded: bool = false
var scenes: Dictionary = {}        # scene_id -> { entry, nodes:{ id:{kind, ...} } }: grafo del Sistema Narrativo
## Lazy-loaded (ver `_ensure_scenes_loaded`): `false` hasta que `get_scene()`
## lo necesita por primera vez tras cada `reload()`.
var _scenes_loaded: bool = false
var cinematics: Dictionary = {}    # id -> definición de cinemática (data/cinematics/<id>.json)
var _cinematics_loaded: bool = false
var achievements: Dictionary = {}  # ach_id -> { name{es,en}, desc{es,en}, icon, condition, reward } (opcional)
var tutorials: Dictionary = {}     # tut_id -> { name{es,en}, steps:[{text{es,en}, done_when}] } (opcional)
var codex: Dictionary = {}         # codex_id -> { title{es,en}, lore{es,en}, hint{es,en}, icon, category, image? } (opcional, Task 2)

## Cuando es true, se carga el mapamundi reducido de la Sala de Tests
## (`world_test.json`) en lugar del mundo real. Lo activa MainMenu/GlobalState.
var is_test_room: bool = false

## NPC cuyo contexto de flags se usa al evaluar la Expression actual.
var _ctx_npc: String = ""

# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	reload()


## (Re)carga los JSON de diseño desde disco. En la Sala de Tests se carga el
## mapamundi reducido `world_test.json`; el resto de ficheros son los mismos.
func reload() -> void:
	var path_world: String = WORLD_TEST_PATH if (is_test_room and FileAccess.file_exists(WORLD_TEST_PATH)) else WORLD_PATH
	var w = _load_json(path_world)
	world = w if w is Dictionary else {}
	ids = _load_ids_dir()
	dungeon_tiles = _load_dir_collection(DUNGEON_TILES_DIR)
	world_terrains = _load_dir_collection(WORLD_TERRAINS_DIR)
	world_resources = _load_dir_collection(WORLD_RESOURCES_DIR)
	world_buildings = _load_dir_collection(WORLD_BUILDINGS_DIR)
	var wbc = _load_json(WORLD_BUILDINGS_CLASSIC_PATH)
	world_buildings_classic = wbc if wbc is Dictionary else {}
	# NPCS_DIR: carga PEREZOSA (ver get_npc()); aquí solo se invalida la caché
	# para que los diálogos se re-lean bajo demanda tras un reload().
	_npc_cache.clear()
	# QUESTS_SECONDARY_DIR: igual, carga perezosa (ver get_quest_secondary()).
	_quest_secondary_cache.clear()
	items = _load_dir_collection(ITEMS_DIR)
	enemies = _load_dir_collection(ENEMIES_DIR)
	var pr = _load_json(PROFESSIONS_PATH)
	professions = pr if pr is Dictionary else {}
	var sk = _load_json(SKILLS_PATH)
	skills = sk if sk is Dictionary else {}
	var esk = _load_json(ENEMY_SKILLS_PATH)
	enemy_skills = esk if esk is Dictionary else {}
	var sy = _load_json(SYNERGIES_PATH)
	if sy is Dictionary:
		synergies = sy.get("synergies", [])
	else:
		synergies = []
	# Mazmorras (DUNGEONS_DIR): carga perezosa por id, así que aquí solo se
	# invalida la caché y el índice de ids para que se re-escaneen bajo demanda.
	_dungeon_cache.clear()
	_dungeon_ids.clear()
	_dungeon_ids_scanned = false
	# dungeon_kits.json: catálogo de piezas de kit (Objetos Inteligentes) que el
	# editor coloca y el runtime (DungeonSmartFactory) construye. Fuente única.
	if FileAccess.file_exists(DUNGEON_KITS_PATH):
		var dk = _load_json(DUNGEON_KITS_PATH)
		dungeon_kits = dk if dk is Dictionary else {}
	else:
		dungeon_kits = {}
	# events.json / quests.json son OPCIONALES (sistema data-driven de
	# misiones y eventos). Su ausencia no es un error: QuestManager cae al flujo
	# cableado clásico. Cuando existen, la lógica de historia se define en datos.
	if FileAccess.file_exists(EVENTS_PATH):
		var ev = _load_json(EVENTS_PATH)
		events = ev if ev is Dictionary else {}
	else:
		events = {}
	if FileAccess.file_exists(QUESTS_PATH):
		var qs = _load_json(QUESTS_PATH)
		quests = qs if qs is Dictionary else {}
	else:
		quests = {}
	# world_transforms.json es OPCIONAL: DSL declarativo de
	# mutación de celdas por transformación de historia. Si falta, WorldMapBuilder
	# usa sus rutinas cableadas (builtins) como fallback.
	if FileAccess.file_exists(WORLD_TRANSFORMS_PATH):
		var wt = _load_json(WORLD_TRANSFORMS_PATH)
		world_transforms = wt if wt is Dictionary else {}
	else:
		world_transforms = {}
	# shops.json es OPCIONAL: catálogos de tienda por stock_id.
	# Si falta, GameConfig.get_shop_stock usa la constante cableada SHOP_STOCKS.
	if FileAccess.file_exists(SHOPS_PATH):
		var sh = _load_json(SHOPS_PATH)
		shops = sh if sh is Dictionary else {}
	else:
		shops = {}
	# ambience.json es OPCIONAL: música/clima por terreno/región.
	# Si falta, el mundo usa la música por defecto y sin clima.
	if FileAccess.file_exists(AMBIENCE_PATH):
		var am = _load_json(AMBIENCE_PATH)
		ambience = am if am is Dictionary else {}
	else:
		ambience = {}
	# Registra pistas de música data-driven en el AudioManager (si hay).
	var mp = ambience.get("music", null)
	if mp is Dictionary:
		AudioManager.register_music_paths(mp)
	# dialogues.json (diálogos guionizados data-driven) y el directorio
	# scenes/ (grafos del Sistema Narrativo, un fichero por escena) NO se
	# parsean aquí: son los datos MENOS usados en el arranque (solo se
	# consultan al iniciar una conversación/cinemática concreta) y potencialmente
	# los que más crecen con el contenido del juego. Se cargan de forma LAZY,
	# la primera vez que `get_dialogue()`/`get_scene()` los necesitan de verdad.
	dialogues = {}
	_dialogues_loaded = false
	scenes = {}
	_scenes_loaded = false
	cinematics = {}
	_cinematics_loaded = false
	# achievements.json / tutorials.json son OPCIONALES: logros
	# (condición + recompensa) y tutoriales (pasos guiados por condición). Si faltan,
	# MetaManager simplemente no evalúa nada.
	if FileAccess.file_exists(ACHIEVEMENTS_PATH):
		var ac = _load_json(ACHIEVEMENTS_PATH)
		achievements = ac if ac is Dictionary else {}
	else:
		achievements = {}
	if FileAccess.file_exists(TUTORIALS_PATH):
		var tu = _load_json(TUTORIALS_PATH)
		tutorials = tu if tu is Dictionary else {}
	# codex.json es OPCIONAL (Task 2): catálogo del Códice de Curiosidades. Si falta,
	# el CodexViewer simplemente muestra el códice vacío.
	if FileAccess.file_exists(CODEX_PATH):
		var cx = _load_json(CODEX_PATH)
		codex = cx if cx is Dictionary else {}
	else:
		codex = {}
	_build_indices()
	_validate_loaded_data()


## Accesor defensivo con fallback seguro.
func get_skill_field(skill_id: String, field: String, default_value: Variant = null) -> Variant:
	var skill_dict: Dictionary = get_skill(skill_id)
	if skill_dict.is_empty() or not skill_dict.has(field):
		if OS.is_debug_build():
			push_warning("Design: Campo '%s' no encontrado para skill '%s'. Usando fallback." % [field, skill_id])
		return default_value
	return skill_dict[field]


## Validación defensiva de datos cargados en modo debug.
func _validate_loaded_data() -> void:
	if not OS.is_debug_build():
		return
	if enemies is Dictionary:
		for enemy_id in enemies.keys():
			var edef: Dictionary = enemies[enemy_id]
			if edef is Dictionary:
				var has_hp := edef.has("hp") or edef.has("base_hp") or edef.has("archetype")
				var has_atk := edef.has("atk") or edef.has("base_attack") or edef.has("attack") or edef.has("archetype")
				if not has_hp or not has_atk:
					push_warning("Design: El enemigo '%s' no especifica hp/atk ni archetype." % enemy_id)


## Índices inversos (texto español -> {es,en}) para que Locale traduzca en vivo
## los nombres/descripciones de celda que provienen de data/ids/<id>.json.
var _name_index: Dictionary = {}
var _desc_index: Dictionary = {}

func _build_indices() -> void:
	_name_index.clear()
	_desc_index.clear()
	for id in ids:
		var o: Dictionary = ids[id]
		var nm = o.get("name", null)
		if nm is Dictionary and String(nm.get("es", "")) != "":
			_name_index[String(nm["es"])] = nm
		var ds = o.get("desc", null)
		if ds is Dictionary and String(ds.get("es", "")) != "":
			_desc_index[String(ds["es"])] = ds


## Traducción bilingüe de un nombre de celda por su texto español (o "" si no existe).
func tr_cell_name(es_text: String) -> String:
	var nm = _name_index.get(es_text, null)
	if nm is Dictionary:
		return Locale.pick(nm)
	var trimmed := es_text.strip_edges()
	nm = _name_index.get(trimmed, null)
	if nm is Dictionary:
		return Locale.pick(nm)
	var spec: Dictionary = get_id(trimmed)
	if not spec.is_empty() and spec.has("name"):
		return Locale.pick(spec["name"])
	return ""


## Traducción bilingüe de una descripción de celda por su texto español (o "").
func tr_cell_desc(es_text: String) -> String:
	var ds = _desc_index.get(es_text, null)
	if ds is Dictionary:
		return Locale.pick(ds)
	var trimmed := es_text.strip_edges()
	ds = _desc_index.get(trimmed, null)
	if ds is Dictionary:
		return Locale.pick(ds)
	var spec: Dictionary = get_id(trimmed)
	if not spec.is_empty() and spec.has("desc"):
		return Locale.pick(spec["desc"])
	return ""


## Lee el campo `boat_spawn` del world.json / world_test.json activo
## ({ "x": int, "y": int }): la casilla donde aparece el BARCO aparcado la
## primera vez. Vector2i(-1,-1) si el mapa no define ninguno (sin barco en
## ese mundo). Ver `GlobalState.boat_pos`.
func world_boat_spawn() -> Vector2i:
	var s = world.get("boat_spawn", null)
	if s is Dictionary and s.has("x") and s.has("y"):
		return Vector2i(int(s["x"]), int(s["y"]))
	return Vector2i(-1, -1)


## Casilla de APARICIÓN del protagonista definida en el mapa cargado (data-driven).
## Lee el campo `spawn` del world.json / world_test.json activo ({ "x": int, "y": int })
## y la ACOTA a los límites del mapa (para que redimensionar el mundo no deje al
## héroe fuera de la rejilla). Si el mapa no define `spawn`, devuelve `fallback`.
func world_spawn(fallback: Vector2i) -> Vector2i:
	var s = world.get("spawn", null)
	var pos := fallback
	if s is Dictionary and s.has("x") and s.has("y"):
		pos = Vector2i(int(s["x"]), int(s["y"]))
	# Acotar a la rejilla real del mapa (evita spawns fuera de rango tras un resize).
	var w := int(world.get("width", 0))
	var h := int(world.get("height", 0))
	if w > 0 and h > 0:
		pos.x = clampi(pos.x, 0, w - 1)
		pos.y = clampi(pos.y, 0, h - 1)
	return pos


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Design: no se encuentra %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Design: no se puede abrir %s" % path)
		return null
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_error("Design: JSON inválido en %s" % path)
	return parsed


## Carga TODAS las entidades del mapamundi desde IDS_DIR (un fichero por id) y
## las devuelve fusionadas en un único Dictionary { id -> spec }, exactamente
## con la misma forma que tenía antes el monolito `ids.json`. Se llama una vez
## por `reload()`: el resto del motor (get_id, _build_indices, WorldMapBuilder…)
## no necesita saber que ahora son N ficheros en vez de uno.
func _load_ids_dir() -> Dictionary:
	return _load_dir_collection(IDS_DIR)


## Genérico: carga TODOS los `.json` de un directorio (un fichero por clave) y
## los devuelve fusionados en un único Dictionary { nombre_sin_extensión -> spec }.
## Usado por IDS_DIR y DUNGEON_TILES_DIR (colecciones "un fichero por id").
func _load_dir_collection(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var spec = _load_json(dir_path + fname)
			if spec is Dictionary:
				out[fname.substr(0, fname.length() - 5)] = spec
		fname = dir.get_next()
	dir.list_dir_end()
	return out


# ══════════════════════════════════════════════════════════════════════════════
# ACCESO A DATOS
# ══════════════════════════════════════════════════════════════════════════════
## Definición de un objeto/celda por su id (o {} si no existe).
func get_id(id: String) -> Dictionary:
	return ids.get(id, {})


## ¿Existe la definición de este id en ids?
func has_id(id: String) -> bool:
	return ids.has(id)


## Alias de get_id para obtener la definición cruda de un id.
func id_raw(id: String) -> Dictionary:
	return get_id(id)


## Metadatos completos de un tipo de casilla de mazmorra (o {} si no existe).
func get_dungeon_tile(t: String) -> Dictionary:
	return dungeon_tiles.get(t, {})


## Especificación de render genérico de un tipo de casilla ({} si el tipo no es
## cosmético/genérico y su geometría vive en GDScript, ver GridDungeonStage.gd).
func get_dungeon_tile_render(t: String) -> Dictionary:
	var spec: Dictionary = get_dungeon_tile(t)
	var render = spec.get("render", {})
	return render if render is Dictionary else {}


## Nombre bilingüe {es,en} de un id (para Locale.pick).
func id_name(id: String) -> Variant:
	return get_id(id).get("name", {"es": id, "en": id, "fr": id, "it": id, "de": id, "zh": id, "ja": id})


## Icono de un id ("" si no tiene).
func id_icon(id: String) -> String:
	return String(get_id(id).get("icon", ""))


# ─── ÍTEMS (items.json) ───────────────────────────────────────────────────────
## Definición completa de un ítem por su id (o {} si no existe).
func get_item(id: String) -> Dictionary:
	return items.get(id, {})

## Nombre ya traducido de un ítem (o el propio id si no existe).
func get_item_name(id: String) -> String:
	var d: Dictionary = get_item(id)
	if d.has("name"):
		return Locale.pick(d["name"])
	return id

## Descripción ya traducida de un ítem ("" si no tiene).
func get_item_desc(id: String) -> String:
	var d: Dictionary = get_item(id)
	if d.has("desc"):
		return Locale.pick(d["desc"])
	return ""

## Icono de un ítem ("❓" si no existe).
func get_item_icon(id: String) -> String:
	return String(get_item(id).get("icon", "❓"))

## Categoría de un ítem ("other" por defecto).
func get_item_category(id: String) -> String:
	return String(get_item(id).get("category", "other"))

## ¿El ítem existe en el catálogo?
func has_item_def(id: String) -> bool:
	return items.has(id)


# ─── PROFESIONES (professions.json) ───────────────────────────────────────────
## Definición cruda de una profesión por su id (o {} si no existe). Normaliza
## `id` con `SaveSerializer.migrate_profession()` antes del lookup: la UI y
## `data/professions.json` usan las mismas claves canónicas ("Arquero",
## "Psíquico", "Sacerdote", ...); la migración solo entra en juego con
## guardados antiguos que aún tuvieran una variante previa ("Arquera",
## "Psíquica", "Curandera"/"Curandero").
func get_profession(id: String) -> Dictionary:
	if not professions.has(id):
		id = SaveSerializer.migrate_profession(id)
	return professions.get(id, {})

## Diccionario con todas las profesiones
func get_professions() -> Dictionary:
	return professions


## Lista de habilidades RESUELTAS de una profesión: cada entrada de progresión
## `{level, id}` se combina con la definición completa de skills.json, de modo
## que quien la consume (combate/personaje) recibe dicts listos para usar con
## `level`, `id`, `name{es,en}`, `icon`, `cost`, `power`, `type`, `element`,
## `pa_cost`, `tag`, `status`, `desc`, `resonance_gain`, `effect`, ...
func get_profession_skills(prof_id: String) -> Array:
	var out: Array = []
	for entry in get_profession(prof_id).get("skills", []):
		var sid := String(entry.get("id", ""))
		var def: Dictionary = get_skill(sid)
		if def.is_empty():
			push_warning("Design: la profesión '%s' referencia una skill inexistente '%s'" % [prof_id, sid])
			continue
		var merged: Dictionary = def.duplicate(true)
		merged["level"] = int(entry.get("level", 1))
		out.append(merged)
	return out


# ─── HABILIDADES (skills.json) ────────────────────────────────────────────────
## Definición completa de una habilidad por su id (o {} si no existe).
func get_skill(id: String) -> Dictionary:
	return skills.get(id, {})

## ¿Existe la habilidad en el catálogo global?
func has_skill(id: String) -> bool:
	return skills.has(id)

## Definición de una habilidad de enemigo por su id (o {} si no existe). Se le
## inyecta su propio "id" (la clave de `enemy_skills.json`, que no se repite
## dentro de la ficha) para que consumidores como `CombatFx.play_skill_effect`
## puedan localizar su fichero de efecto dedicado en `assets/combat/effects/`.
func get_enemy_skill(id: String) -> Dictionary:
	var d: Dictionary = enemy_skills.get(id, {})
	if not d.is_empty() and not d.has("id"):
		d["id"] = id
	return d


# ─── SINERGIAS (synergies.json) ───────────────────────────────────────────────
## Devuelve la definición de la habilidad de fusión resultante de combinar dos
## habilidades (por sus IDs, en cualquier orden), o {} si no hay sinergia. Se
## puede acotar por profesión; si `prof` es "" se ignora ese filtro.
func get_synergy(prof: String, id_a: String, id_b: String) -> Dictionary:
	if id_a == "" or id_b == "":
		return {}
	for syn in synergies:
		if prof != "" and String(syn.get("profession", "")) != prof:
			continue
		var req: Array = syn.get("required_ids", [])
		if req.size() < 2:
			continue
		var ra := String(req[0])
		var rb := String(req[1])
		if (ra == id_a and rb == id_b) or (ra == id_b and rb == id_a):
			return get_skill(String(syn.get("result_id", "")))
	return {}


## Devuelve la definición de la habilidad triple resultante de combinar 3 habilidades
## (en cualquier orden). Solo aplica cuando la Sintonía está al 100%.
## Devuelve {} si no existe sinergia triple definida en synergies.json.
func get_triple_synergy(prof: String, id_a: String, id_b: String, id_c: String) -> Dictionary:
	if id_a == "" or id_b == "" or id_c == "":
		return {}
	var ids_in := [id_a, id_b, id_c]
	ids_in.sort()
	for syn in synergies:
		if prof != "" and String(syn.get("profession", "")) != prof:
			continue
		var req: Array = syn.get("required_ids", [])
		if req.size() < 3:
			continue
		var req_sorted: Array = []
		for r in req:
			req_sorted.append(String(r))
		req_sorted.sort()
		if req_sorted == ids_in:
			return get_skill(String(syn.get("result_id", "")))
	return {}


## Coste de Puntos de Acción (PA) de una habilidad. Si el JSON no lo define, se
## deriva de su potencia/coste para mantener el balance sin editar todas las
## habilidades a mano (1 PA = básica, 2 PA = media, 3 PA = definitiva/cara).
## Nota: la escala de `power` es 0-150 (ver GameConfig.offensive_damage).
func skill_pa_cost(skill: Dictionary) -> int:
	if skill.has("pa_cost"):
		return clampi(int(skill["pa_cost"]), 1, 3)
	var power: float = float(skill.get("power", 0.0))
	var cost: int = int(skill.get("cost", 0))
	if power >= 110.0 or cost >= 18:
		return 3
	if power >= 60.0 or cost >= 8:
		return 2
	return 1


## Tag de una habilidad (para agrupación/visual). Las sinergias se resuelven por
## IDs (ver `get_synergy`); el tag es informativo. "" si no define ninguno.
func skill_tag(skill: Dictionary) -> String:
	return String(skill.get("tag", ""))


# ─── ENEMIGOS (ENEMIES_DIR: data/enemies/<id>.json) ───────────────────────────
## Definición cruda de un enemigo por su id (o {} si no existe).
func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})


func enemy(id: String) -> Dictionary:
	return get_enemy(id)


# ─── MAZMORRAS DE REJILLA (data/dungeons/<id>.json, data-driven, opcional) ────
## Cada mazmorra es su propio fichero (ver DUNGEONS_DIR): esto evita cargar TODAS
## las mazmorras en RAM al arrancar y que tocar una sola implique reescribir un
## JSON gigante. `has_dungeon_layout`/`get_dungeon_layout` cargan y cachean por
## demanda; `all_dungeon_ids` es la única operación que toca el directorio.

## ¿Hay un layout de rejilla definido para este event_id? ViewDungeon construye
## SIEMPRE con GridDungeonStage; si no hay layout, usa una sala mínima de reserva.
func has_dungeon_layout(event_id: String) -> bool:
	if _dungeon_cache.has(event_id):
		return true
	return FileAccess.file_exists(_dungeon_path(event_id))

## Layout de rejilla de una mazmorra por su event_id (o {} si no existe).
## Perezoso y cacheado: solo lee su propio fichero, nunca el resto de mazmorras.
func get_dungeon_layout(event_id: String) -> Dictionary:
	if _dungeon_cache.has(event_id):
		return _dungeon_cache[event_id]
	var path := _dungeon_path(event_id)
	var layout: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed = _load_json(path)
		layout = parsed if parsed is Dictionary else {}
	_dungeon_cache[event_id] = layout
	return layout

## Todos los ids de mazmorra disponibles (nombres de fichero de DUNGEONS_DIR sin
## ".json"), ordenados. Escanea el directorio una sola vez por `reload()`. Solo
## la usan pantallas de listado (p. ej. el visor "Mazmorras" del menú de info);
## el flujo normal de entrar a una mazmorra concreta NO la necesita.
func all_dungeon_ids() -> PackedStringArray:
	_ensure_dungeon_ids()
	return _dungeon_ids


## Ids canónicos de mazmorras para el jugador (excluye sub-secciones internas de la
## mazmorra final y ficheros de backup). Para el jugador, el Templo del Origen es una sola mazmorra.
func canonical_dungeon_ids() -> PackedStringArray:
	var all_ids := all_dungeon_ids()
	var result: Array[String] = []
	for did in all_ids:
		var s := String(did)
		if s.ends_with("_bak") or s.begins_with("dun_final_"):
			continue
		result.append(s)
	return PackedStringArray(result)


## Nombre a mostrar de una mazmorra para el jugador (con localización).
## Para dun_final devuelve "Templo del Origen" a secas, unificando sus fases.
func get_dungeon_display_name(event_id: String) -> String:
	if event_id == "dun_final" or event_id.begins_with("dun_final_"):
		return Locale.pick({"es": "Templo del Origen", "en": "Temple of Origin"})
	var layout := get_dungeon_layout(event_id)
	return Locale.pick(layout.get("name", event_id))


## Nº total de plantas de la mazmorra para el jugador.
## Para dun_final suma las plantas de todas sus fases/secciones internas.
func get_dungeon_total_floors(event_id: String) -> int:
	if event_id == "dun_final":
		var count := 0
		for did in ["dun_final", "dun_final_2", "dun_final_3", "dun_final_4", "dun_final_5", "dun_final_6"]:
			var lay := get_dungeon_layout(did)
			count += (lay.get("floors", []) as Array).size()
		return count
	var layout := get_dungeon_layout(event_id)
	return (layout.get("floors", []) as Array).size()


## Comprueba si la mazmorra ha sido completada (su jefe derrotado).
## Para dun_final verifica la derrota de "guardian_supremo" en dun_final / dun_final_6.
func is_dungeon_completed(event_id: String) -> bool:
	if event_id == "dun_final" or event_id.begins_with("dun_final_"):
		return GlobalState.is_boss_defeated("dun_final:guardian_supremo") \
			or GlobalState.is_boss_defeated("dun_final_6:guardian_supremo")
	var layout := get_dungeon_layout(event_id)
	var boss_id := String(layout.get("boss", ""))
	if boss_id == "":
		return false
	return GlobalState.is_boss_defeated(event_id + ":" + boss_id)


func _dungeon_path(event_id: String) -> String:
	return DUNGEONS_DIR + event_id + ".json"

func _ensure_dungeon_ids() -> void:
	if _dungeon_ids_scanned:
		return
	_dungeon_ids_scanned = true
	_dungeon_ids.clear()
	var dir := DirAccess.open(DUNGEONS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			_dungeon_ids.append(fname.substr(0, fname.length() - 5))
		fname = dir.get_next()
	dir.list_dir_end()
	var sorted_ids := Array(_dungeon_ids)
	sorted_ids.sort()
	_dungeon_ids = PackedStringArray(sorted_ids)


# ─── KITS DE OBJETOS INTELIGENTES (dungeon_kits.json) ─────────────────
## Definición de una pieza de kit por su id (o {} si no existe). La usa
## DungeonSmartFactory para construir el Objeto Inteligente.
func kit_piece(piece_id: String) -> Dictionary:
	var pieces = dungeon_kits.get("pieces", {})
	if pieces is Dictionary:
		var p = pieces.get(piece_id, {})
		return p if p is Dictionary else {}
	return {}

## Todas las piezas de kit: { piece_id -> def } (o {} si no hay catálogo).
func kit_pieces() -> Dictionary:
	var pieces = dungeon_kits.get("pieces", {})
	return pieces if pieces is Dictionary else {}

## Metadatos de los kits: { kit_id -> { label, verb, icon, color } }.
func kits() -> Dictionary:
	var k = dungeon_kits.get("kits", {})
	return k if k is Dictionary else {}


# ─── AMBIENTE: MÚSICA Y CLIMA (ambience.json, data-driven, opcional) ──────────
## Ambiente asociado a un código de terreno: { music?, weather? } (o {} si no hay).
func get_terrain_ambience(terrain: String) -> Dictionary:
	var t = ambience.get("terrain", {})
	if t is Dictionary and t.has(terrain):
		var d = t[terrain]
		return d if d is Dictionary else {}
	return {}

## Definición visual de un clima por su id: { color, count, speed, size, drift,
## intensity?, ambient_color?, ambient_alpha?, sound?, sound_db? } (o {}).
func get_weather_def(weather_id: String) -> Dictionary:
	if weather_id == "" or weather_id == "none":
		return {}
	var w = ambience.get("weather", {})
	if w is Dictionary and w.has(weather_id):
		var d = w[weather_id]
		return d if d is Dictionary else {}
	return {}

## Selecciona el CLIMA activo para un terreno según su PROBABILIDAD, de forma
## data-driven y REUTILIZABLE. Función PURA: recibe `roll` ∈ [0,1) (el llamador
## controla el RNG y cuándo re-tirar) y devuelve el id de clima resultante
## ("none" si no toca ninguno). Dos formatos admitidos en `terrain[code]`:
##   1) `weather` (String)  → clima FIJO (compatibilidad hacia atrás).
##   2) `weather_options` (Array de { weather, probability })  → ruleta ponderada.
##      Las probabilidades no necesitan sumar 1; el resto de la masa cae en "none".
func pick_terrain_weather(terrain: String, roll: float) -> String:
	var amb := get_terrain_ambience(terrain)
	if amb.is_empty():
		return "none"
	var opts = amb.get("weather_options", null)
	if opts is Array and not opts.is_empty():
		var acc := 0.0
		for o in opts:
			if not (o is Dictionary):
				continue
			acc += maxf(0.0, float(o.get("probability", 0.0)))
			if roll < acc:
				return String(o.get("weather", "none"))
		return "none"
	# Formato simple: clima fijo (sin probabilidad).
	return String(amb.get("weather", "none"))

## Devuelve la zona del mundo en la coordenada `coord` (o {} si no está acotada).
func get_zone_at(coord: Vector2i) -> Dictionary:
	var zones = ambience.get("zones", [])
	if zones is Array:
		for z in zones:
			if not (z is Dictionary):
				continue
			var b: Dictionary = z.get("bounds", {})
			if b.is_empty():
				continue
			if coord.x >= int(b.get("x_min", 0)) and coord.x <= int(b.get("x_max", 999)) and \
			   coord.y >= int(b.get("y_min", 0)) and coord.y <= int(b.get("y_max", 999)):
				return z
	return {}

## Devuelve la música de fondo que corresponde a la gran zona en la coordenada `coord`.
func get_zone_music_at(coord: Vector2i) -> String:
	var z := get_zone_at(coord)
	if z.is_empty():
		return "world_zone3"
	var zid := String(z.get("id", ""))
	if zid == "zona_1_yelmo":
		if GlobalState.has_world_flag("dam_opened"):
			return String(z.get("music_dam_opened", "world_zone1_drained"))
		return String(z.get("music", "world_zone1_flooded"))
	elif zid == "zona_4_celestia":
		if GlobalState.has_world_flag("boss_puerto_activo") and not GlobalState.has_world_flag("boss_puerto_derrotado"):
			return "event_crisis_puerto"
	return String(z.get("music", "world_zone3"))

# ─── TERRENOS (data/world_terrains/<code>.json, un fichero por código) ────────
## Definición física/visual de un terreno por su código (o {} si no está definido).
func get_terrain_def(code: String) -> Dictionary:
	var d = world_terrains.get(code, null)
	return d if d is Dictionary else {}

## ¿Es transitable este terreno? Prioriza `world_terrains/`; si no está definido,
## mantiene la regla cableada de siempre (mar y montaña no lo son).
func terrain_is_walkable(code: String) -> bool:
	var d := get_terrain_def(code)
	if d.has("walkable"):
		return bool(d["walkable"])
	return code != "sea" and code != "mnt"

## Daño ambiental por tick del terreno (0 si ninguno). P. ej. la lava.
func terrain_damage(code: String) -> int:
	return int(get_terrain_def(code).get("damage", 0))

## Intervalo (segundos) entre ticks de daño ambiental del terreno.
func terrain_damage_interval(code: String) -> float:
	return maxf(0.05, float(get_terrain_def(code).get("damage_interval", 0.6)))

## Multiplicador de velocidad de movimiento al pisar el terreno (1.0 = normal).
func terrain_speed_mult(code: String) -> float:
	return maxf(0.05, float(get_terrain_def(code).get("speed_mult", 1.0)))

## Peligro ambiental del terreno para la barra bajo el HUD del mapamundi:
## "heat" (insolación) | "cold" (congelación) | "" (ninguno). 100% DATA-DRIVEN
## (campo `hazard`, editable desde WorldTerrainsManager); antes vivía cableado
## en GameConfig.TERRAIN_HAZARD + una regla especial de "rodeado de desierto"
## (ver GameRoot.gd), ya retirada: ahora cada terreno decide su propio peligro
## sin casos especiales (p. ej. separar "desierto" de "arena").
func terrain_hazard(code: String) -> String:
	return String(get_terrain_def(code).get("hazard", ""))

## ¿Es resbaladizo este terreno? (hielo: el jugador pierde el control y desliza
## en la dirección de entrada hasta salir de la zona). Campo `slippery` de
## data/world_terrains/<code>.json.
func terrain_is_slippery(code: String) -> bool:
	return bool(get_terrain_def(code).get("slippery", false))

## ¿Es fusionable (blendable) este terreno con sus casillas vecinas?
## Campo `blendable` de data/world_terrains/<code>.json (true por defecto para biomas terrestres).
func terrain_is_blendable(code: String) -> bool:
	var d := get_terrain_def(code)
	if d.has("blendable"):
		return bool(d["blendable"])
	return code != "sea" and code != "cst" and code != "lav" and code != "icy"

# ─── RECURSOS DEL MAPAMUNDI (data/world_resources/<code>.json, un fichero por código) ─
## Definición visual (label/icon/biome_color/description/placeable) de un recurso
## farmeable genérico por su código (forest/forestBad/rock/gold/fish/milk),
## o {} si no está definido (el llamante cae a su aspecto cableado de siempre).
func get_world_resource(code: String) -> Dictionary:
	var d = world_resources.get(code, null)
	return d if d is Dictionary else {}

## Definición de RECOLECCIÓN (oficio/ítem/icono/categoría/capacidad/textos) de un
## recurso del mapamundi, con la MISMA forma que usaban GameConfig.RESOURCE_TYPES.
## Empieza con la entrada cableada de GameConfig como base (red de seguridad
## para recursos antiguos sin estos campos en su JSON) y la SOBRESCRIBE con lo
## que traiga la ficha de datos, campo a campo. Así un recurso nuevo creado
## íntegramente desde el editor (sin entrada en GameConfig) también funciona
## con solo definir estos campos en su JSON.
func resolve_gather_resource(code: String) -> Dictionary:
	var out: Dictionary = (GameConfig.RESOURCE_TYPES.get(code, {}) as Dictionary).duplicate()
	var d := get_world_resource(code)
	for k in ["skill", "item", "item_loc", "icon", "category", "name_loc", "found_loc", "capacity"]:
		if d.has(k):
			out[k] = d[k]
	return out

# ─── EDIFICIOS VÍA ASSET (data/world_buildings/<code>.json, un fichero por código) ───
## Definición de un edificio-asset (label/icon/scene/scale/y_offset/description) por
## su código, o {} si no está definido (el llamante cae a la maqueta procedural
## cableada de siempre, si la hay, o al marcador genérico de respaldo).
func get_world_building(code: String) -> Dictionary:
	if code == "":
		return {}
	var d = world_buildings.get(code, null)
	return d if d is Dictionary else {}

## Override visual OPCIONAL de una de las 8 maquetas procedurales cableadas
## (ciudad/aldea/casita/templo/place/cueva/ruinas/presa), o {} si no hay ficha
## (la maqueta usa entonces su color/escala cableado de siempre). Campos
## posibles: `wall_color`/`roof_color` (string hex "#rrggbb") y `scale` (float).
func get_classic_building_style(code: String) -> Dictionary:
	var d = world_buildings_classic.get(code, null)
	return d if d is Dictionary else {}

## Carga bajo demanda `dialogues.json` (una sola vez por `reload()`). Ver
## comentario de `_dialogues_loaded`.
func _ensure_dialogues_loaded() -> void:
	if _dialogues_loaded:
		return
	_dialogues_loaded = true
	if FileAccess.file_exists(DIALOGUES_PATH):
		var dg = _load_json(DIALOGUES_PATH)
		dialogues = dg if dg is Dictionary else {}
	else:
		dialogues = {}


## Carga bajo demanda el directorio `scenes/` (una sola vez por `reload()`).
## Ver comentario de `_scenes_loaded`.
func _ensure_scenes_loaded() -> void:
	if _scenes_loaded:
		return
	_scenes_loaded = true
	scenes = _load_dir_collection(SCENES_DIR)


func _ensure_cinematics_loaded() -> void:
	if _cinematics_loaded:
		return
	_cinematics_loaded = true
	cinematics = _load_dir_collection(CINEMATICS_DIR)


func get_cinematic(id: String) -> Dictionary:
	_ensure_cinematics_loaded()
	var c = cinematics.get(id, null)
	return c if c is Dictionary else {}


func has_cinematic(id: String) -> bool:
	_ensure_cinematics_loaded()
	return cinematics.has(id)


## Escena narrativa por su id (scenes.json o adaptada desde cinematics):
## { entry, nodes:{...} } (o {} si no existe). La consume el SceneRunner del Sistema Narrativo.
func get_scene(scene_id: String) -> Dictionary:
	_ensure_scenes_loaded()
	var s = scenes.get(scene_id, null)
	if s is Dictionary:
		return s
	_ensure_cinematics_loaded()
	if cinematics.has(scene_id):
		return SceneAdapters.cinematic_to_scene(cinematics[scene_id])
	return {}

## ¿Existe una escena con ese id en scenes.json o cinematics?
func has_scene(scene_id: String) -> bool:
	_ensure_scenes_loaded()
	if scenes.has(scene_id):
		return true
	_ensure_cinematics_loaded()
	return cinematics.has(scene_id)

## Definición de un logro por su id (achievements.json): { name, desc, icon,
## condition, reward } (o {}).
func get_achievement(ach_id: String) -> Dictionary:
	var a = achievements.get(ach_id, null)
	return a if a is Dictionary else {}

## Definición de un tutorial por su id (tutorials.json): { name, steps:[...] } (o {}).
func get_tutorial(tut_id: String) -> Dictionary:
	var t = tutorials.get(tut_id, null)
	return t if t is Dictionary else {}

## Localiza un valor que puede ser un String directo o un mapa {es,en}.
func _loc_str(v) -> String:
	if v is Dictionary:
		return Locale.pick(v)
	return String(v)


## Todos los nodos de diálogo de un NPC (o {}). Perezoso y cacheado: la primera
## vez que se pide un NPC se lee su fichero `res://data/npcs/<id>.json`; las
## siguientes se devuelve directamente de `_npc_cache`.
func get_npc(npc_id: String) -> Dictionary:
	if _npc_cache.has(npc_id):
		return _npc_cache[npc_id]
	var graph: Dictionary = {}
	var path := NPCS_DIR + npc_id + ".json"
	if FileAccess.file_exists(path):
		var parsed = _load_json(path)
		graph = parsed if parsed is Dictionary else {}
	_npc_cache[npc_id] = graph
	return graph


## ¿Existe diálogo para este NPC (aparte del _meta)?
func has_npc(npc_id: String) -> bool:
	if _npc_cache.has(npc_id):
		return not _npc_cache[npc_id].is_empty()
	return FileAccess.file_exists(NPCS_DIR + npc_id + ".json")


## Ficha descriptiva de una misión SECUNDARIA del Sistema Multi-Quest (o {} si
## no tiene ficha propia). Perezoso y cacheado, igual patrón que `get_npc()`.
## Usado por `JournalViewer` para mostrar título/pista de las misiones activas
## en `GlobalState.quests` — ver task_arreglos.md §1.
func get_quest_secondary(quest_id: String) -> Dictionary:
	if _quest_secondary_cache.has(quest_id):
		return _quest_secondary_cache[quest_id]
	var data: Dictionary = {}
	var path := QUESTS_SECONDARY_DIR + quest_id + ".json"
	if FileAccess.file_exists(path):
		var parsed = _load_json(path)
		data = parsed if parsed is Dictionary else {}
	_quest_secondary_cache[quest_id] = data
	return data


## Título/pista de una misión secundaria en una fase concreta (o {} si no hay
## ficha o esa fase no está descrita). `stage` se busca como clave String
## ("0", "1", ...) dentro de `stages`.
func get_quest_secondary_stage(quest_id: String, stage: int) -> Dictionary:
	var q := get_quest_secondary(quest_id)
	var stages: Dictionary = q.get("stages", {})
	return stages.get(str(stage), {})


# ══════════════════════════════════════════════════════════════════════════════
# METADATOS DEL NPC  (nodo especial "_meta": text=nombre, reward=avatar/bg)
# ══════════════════════════════════════════════════════════════════════════════
func npc_meta(npc_id: String) -> Dictionary:
	var meta: Dictionary = get_npc(npc_id).get("_meta", {})
	var out := {
		"name": meta.get("text", {"es": "", "en": "", "fr": "", "it": "", "de": "", "zh": "", "ja": ""}),
		"avatar": "",
		"bg": null,
	}
	for raw in String(meta.get("reward", "")).split(";", false):
		var t := raw.strip_edges()
		if t.begins_with("avatar="):
			out["avatar"] = t.substr(7)
		elif t.begins_with("bg="):
			var rgb := t.substr(3).split(",")
			if rgb.size() >= 3:
				out["bg"] = Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	return out


# ══════════════════════════════════════════════════════════════════════════════
# MOTOR DE DIÁLOGO — selección de nodos
# ══════════════════════════════════════════════════════════════════════════════
## Devuelve el id del nodo de ENTRADA: el primer "message" no referenciado por
## ningún `next` cuya condición se cumpla. Si ninguno pasa, el último candidato.
func entry_node(npc_id: String) -> String:
	var nodes: Dictionary = get_npc(npc_id)
	if nodes.is_empty():
		return ""
	if nodes.has("entry"):
		var enode: Dictionary = nodes["entry"]
		var etype := String(enode.get("type", ""))
		if etype == "choice" or etype == "flow":
			for nx in enode.get("next", []):
				var nxs := String(nx)
				var target_node: Dictionary = nodes.get(nxs, {})
				var cond := String(target_node.get("condition", ""))
				if cond == "" or cond == "default" or eval_condition(cond, npc_id):
					return nxs
		elif eval_condition(String(enode.get("condition", "")), npc_id):
			return "entry"
	var targeted: Dictionary = {}
	for nid in nodes:
		if nid == "_meta":
			continue
		for nx in nodes[nid].get("next", []):
			if nx != "close" and nx != "":
				targeted[nx] = true
	var fallback := ""
	var first_valid_msg := ""
	for nid in nodes:
		if nid == "_meta":
			continue
		var node: Dictionary = nodes[nid]
		var ntype := String(node.get("type", ""))
		if ntype != "message" and ntype != "entry" and ntype != "choice":
			continue
		if first_valid_msg == "" and eval_condition(String(node.get("condition", "")), npc_id):
			first_valid_msg = nid
		if targeted.has(nid):
			continue
		fallback = nid
		if eval_condition(String(node.get("condition", "")), npc_id):
			return nid
	if fallback != "":
		return fallback
	return first_valid_msg


## Resuelve el encuentro en un POI evaluando sus reglas de presencia condicionales.
## Permite desacoplar el Lugar físico (POI) de los Actores (NPCs) que aparecen en él.
func resolve_poi_encounter(poi_id: String) -> Dictionary:
	var id_data: Dictionary = ids.get(poi_id, {})
	var out := {
		"poi_id": poi_id,
		"name": id_data.get("name", {"es": poi_id, "en": poi_id, "fr": poi_id, "it": poi_id, "de": poi_id, "zh": poi_id, "ja": poi_id}),
		"bg": String(id_data.get("bg", "")),
		"music": String(id_data.get("music", "")),
		"actor": String(id_data.get("npc", poi_id)),
		"entry_node": "",
		"scene_id": "",
		"is_empty": false,
	}
	var presences: Array = id_data.get("presences", [])
	if presences.is_empty():
		return out

	for rule in presences:
		if not (rule is Dictionary):
			continue
		var cond := String(rule.get("condition", "default")).strip_edges()
		var matches := false
		if cond == "" or cond == "default" or cond == "true" or cond == "always":
			matches = true
		else:
			matches = eval_condition(cond, poi_id)

		if matches:
			var act := String(rule.get("actor", "")).strip_edges()
			var sc := String(rule.get("scene", "")).strip_edges()
			var entry := String(rule.get("entry_node", "")).strip_edges()
			if act == "none" or act == "empty":
				out["is_empty"] = true
				out["actor"] = ""
			elif act != "":
				out["actor"] = act
			out["scene_id"] = sc
			out["entry_node"] = entry
			break
	return out


# ══════════════════════════════════════════════════════════════════════════════
# EVALUACIÓN DE CONDICIONES (Godot Expression)
# ══════════════════════════════════════════════════════════════════════════════
const _COND_VARS := [
	"quest", "gold", "valentia", "amabilidad", "encanto", "astucia",
	"valor", "bondad", "aspecto", "inteligencia", "cordura",
	"relation", "visits",
]
var _expr_cache: Dictionary = {}

func eval_condition(cond: String, npc_id: String) -> bool:
	var c := cond.strip_edges()
	if c == "" or c == "default" or c == "true":
		return true
	if c == "false":
		return false
	_ctx_npc = npc_id
	var expr: Expression = _expr_cache.get(c, null)
	if expr == null:
		expr = Expression.new()
		if expr.parse(c, _COND_VARS) != OK:
			push_warning("Design: condición inválida '%s': %s" % [cond, expr.get_error_text()])
			return false
		_expr_cache[c] = expr
	var inputs := [
		GlobalState.quest_state,
		GlobalState.gold,
		GlobalState.get_faceta("valor"),
		GlobalState.get_faceta("bondad"),
		GlobalState.get_faceta("aspecto"),
		GlobalState.get_faceta("inteligencia"),
		GlobalState.get_faceta("valor"),
		GlobalState.get_faceta("bondad"),
		GlobalState.get_faceta("aspecto"),
		GlobalState.get_faceta("inteligencia"),
		GlobalState.get_faceta("cordura"),
		GlobalState.get_relation(npc_id),
		GlobalState.npc_visit_count(npc_id),
	]
	var result = expr.execute(inputs, self)
	if expr.has_execute_failed():
		push_warning("Design: fallo al evaluar '%s': %s" % [cond, expr.get_error_text()])
		return false
	return bool(result)


# ─── Funciones invocables desde las Expression (base_instance = self) ──────────
func has_item(id: String, qty: int = 1) -> bool:
	return GlobalState.has_item(id, qty)

func no_item(id: String, qty: int = 1) -> bool:
	return not GlobalState.has_item(id, qty)

func has_flag(flag: String) -> bool:
	return GlobalState.npc_has_flag(_ctx_npc, flag)

func no_flag(flag: String) -> bool:
	return not GlobalState.npc_has_flag(_ctx_npc, flag)

## Flag GLOBAL de historia (no ligado a NPC), para condiciones data-driven.
## Uso en una Expression: `gflag("dam_opened")` o `has_gflag("dam_opened")`.
func gflag(flag: String) -> bool:
	return GlobalState.has_world_flag(flag)

func has_gflag(flag: String) -> bool:
	return GlobalState.has_world_flag(flag)

## Negación de gflag(), para condiciones data-driven (evita depender del operador
## `not` del parser de Expression). Uso: `no_gflag("apprentice_sendero_guerrero")`.
func no_gflag(flag: String) -> bool:
	return not GlobalState.has_world_flag(flag)

## ¿Entrada del Códice de Curiosidades ya descubierta? (Task 2). Uso en una
## Expression: `discovered("poi_tumba_elara")`. Sirve para mostrar un texto
## distinto (o esconder la interacción con recompensa) en visitas posteriores.
func discovered(codex_id: String) -> bool:
	return GlobalState.is_lore_discovered(codex_id)

## Negación de discovered() (evita depender del operador `not` del parser).
## Uso: `not_discovered("poi_tumba_elara")` para ofrecer la interacción una vez.
func not_discovered(codex_id: String) -> bool:
	return not GlobalState.is_lore_discovered(codex_id)

## ── Sistema Multi-Quest (misiones secundarias/paralelas, ver task_arreglos.md §1) ──
## ¿La misión secundaria `quest_id` está iniciada y en curso? Uso en una
## Expression: `has_quest("herrero_encargo")`.
func has_quest(quest_id: String) -> bool:
	return QuestManager.is_quest_active(quest_id)

## Fase actual de la misión secundaria `quest_id` (-999 si nunca se inició).
## Uso en una Expression: `quest_stage("herrero_encargo") == 2`.
func quest_stage(quest_id: String) -> int:
	return QuestManager.get_quest_stage(quest_id)

## ¿La misión secundaria `quest_id` fue completada? Uso: `quest_done("herrero_encargo")`.
func quest_done(quest_id: String) -> bool:
	return QuestManager.is_quest_completed(quest_id)

## Bandera de progreso invocable desde condiciones de PUERTA/MURO (gating).
## Uso en una Expression: `gate_flag('cave_cleared')`. Reconoce los hitos clave
## del mundo (cueva/mono) y, por defecto, cualquier bandera global de historia.
func gate_flag(key: String) -> bool:
	match key:
		"cave_cleared":
			return GlobalState.cave_cleared
		"monkey_cleared":
			return QuestManager.is_quest_at_least(QuestManager.QS_MONKEY_CLEARED)
		_:
			return GlobalState.has_world_flag(key)


## ¿Está BLOQUEADA esta puerta/muro? (gating, incidencia de casillas condicionadas).
## `gate` = { dir, open_when? }. Devuelve true (bloqueada) si hay condición y NO se
## cumple, o si NO hay `open_when` en absoluto (muro PERMANENTE: nunca se abre solo
## caminando — p. ej. las dos "puertas" de una mazmorra con entradas/salidas propias
## que solo se cruzan atravesando la mazmorra). Solo es "abierta" (false) cuando NO
## hay `gate` en la celda, o cuando `open_when` se cumple.
func is_gate_locked(gate: Dictionary) -> bool:
	if gate == null or gate.is_empty():
		return false
	var cond := String(gate.get("open_when", ""))
	if cond.strip_edges() == "":
		return true
	return not eval_condition(cond, "")


## Contador/estadística del jugador para condiciones de logros y tutoriales.
## Uso en una Expression: `stat("kills") >= 10`.
func stat(key: String) -> int:
	match key:
		"kills": return GlobalState.kills_total
		"level": return GlobalState.level
		"xp": return GlobalState.xp
		"gold": return GlobalState.gold
		"job_level": return GlobalState.job_level
		_:
			return 0


## Afinidad con un NPC CONCRETO (por id), invocable desde condiciones. Permite que
## el diálogo/opciones de un NPC reaccionen a la relación con OTRO (consecuencias de
## facción/reputación). Uso en una Expression: `rel("herrero") >= 3`.
func rel(npc_id: String) -> int:
	return GlobalState.get_relation(npc_id)


## Nº de visitas a un NPC concreto (por id), invocable desde condiciones.
## Uso en una Expression: `visits_of("posadera") == 0` (primera visita).
func visits_of(npc_id: String) -> int:
	return GlobalState.npc_visit_count(npc_id)


## Profesión desbloqueada, invocable desde condiciones (consecuencias por clase).
## Uso en una Expression: `has_prof("Guerrero")`.
func has_prof(prof: String) -> bool:
	return prof in GlobalState.unlocked_professions

## Negación de has_prof() (evita depender del operador `not` del parser).
## Uso en una Expression: `no_prof("Guerrero")`.
func no_prof(prof: String) -> bool:
	return not (prof in GlobalState.unlocked_professions)

## ¿Tiene todas las 6 profesiones de maestría desbloqueadas?
func has_all_professions() -> bool:
	return GlobalState.has_all_professions_unlocked()


## ¿Se ha derrotado el jefe de una mazmorra? Invocable desde condiciones.
## Uso en una Expression: `defeated("sendero_psiquico:temple_boss_psychic")`.
func defeated(key: String) -> bool:
	return GlobalState.is_boss_defeated(key)


## Progreso de un contador de CAZA de NPC (quest "mata N enemigos del tipo X
## desde que aceptaste", ver `GlobalState.HUNT_QUEST_TARGETS`). Invocable desde
## condiciones. Uso en una Expression: `hunt_progress("hunt_bandidos_kills") >= 3`.
func hunt_progress(flag: String) -> int:
	return int(GlobalState.get_world_flag_val(flag, 0))


# ══════════════════════════════════════════════════════════════════════════════
# APLICACIÓN DE RECOMPENSAS (mini-lenguaje)
# ══════════════════════════════════════════════════════════════════════════════
func apply_reward(reward: String, npc_id: String) -> void:
	if reward.strip_edges() == "":
		return

	var tokens: Array[String] = []
	var has_already_set_flag := false

	for raw in reward.split(";", false):
		var tok := raw.strip_edges()
		if tok != "":
			tokens.append(tok)
			if tok.begins_with("flag:"):
				var flag_name := tok.substr(5).strip_edges()
				if GlobalState.has_flag(flag_name, npc_id):
					has_already_set_flag = true

	for tok in tokens:
		if has_already_set_flag and (tok.begins_with("rel:") or tok.begins_with("relation:") or tok.begins_with("rel=") or tok.begins_with("relation=") or tok == "rel" or tok == "relation"):
			# Esta primera charla ya ocurrió anteriormente; no volver a incrementar afinidad.
			continue
		_apply_token(tok, npc_id)

	GlobalState.state_updated.emit()


func _apply_token(tok: String, npc_id: String) -> void:
	tok = tok.strip_edges()
	if tok == "":
		return

	# Retirar ítem: "-item:id=n" o "-item=id=n"
	if tok.begins_with("-item:") or tok.begins_with("-item="):
		var body := tok.substr(6)
		var rp := body.split("=")
		GlobalState.remove_item(rp[0], _pint(rp[1]) if rp.size() > 1 else 1)
		return

	var colon := tok.find(":")
	var eq := tok.find("=")
	var key := ""
	var val := ""

	if colon != -1:
		key = tok.substr(0, colon).strip_edges().to_lower()
		val = tok.substr(colon + 1).strip_edges()
	elif eq != -1:
		key = tok.substr(0, eq).strip_edges().to_lower()
		val = tok.substr(eq + 1).strip_edges()
	else:
		key = tok.strip_edges().to_lower()
		val = ""

	match key:
		"gold":
			GlobalState.gold = maxi(0, GlobalState.gold + _pint(val))
		"xp":
			GlobalState.add_xp(_pint(val))
		"heal":
			if val == "" or val == "max":
				GlobalState.hp = GlobalState.max_hp
				GlobalState.mp = GlobalState.max_mp
			else:
				var amount := _pint(val)
				if amount >= 9999:
					GlobalState.hp = GlobalState.max_hp
					GlobalState.mp = GlobalState.max_mp
				else:
					GlobalState.hp = mini(GlobalState.max_hp, GlobalState.hp + amount)
		"damage":
			# Daño directo fuera de combate: "damage:N" (cantidad fija de HP) o
			# "damage:N%" (porcentaje del HP MÁXIMO). Nunca mata (se queda en 1
			# como mínimo) para no disparar la Sala de la Esfera desde un evento
			# de sabor como el POI de la roca sonriente.
			var dmg: int
			if val.ends_with("%"):
				var pct: float = float(_pint(val.substr(0, val.length() - 1))) / 100.0
				dmg = int(round(float(GlobalState.max_hp) * pct))
			else:
				dmg = _pint(val)
			GlobalState.hp = maxi(1, GlobalState.hp - dmg)
		"bark":
			if OrbBarksManager != null:
				OrbBarksManager.trigger_bark_from_token(val)
		"music":
			# Cambia la música de fondo al vuelo desde un nodo de diálogo, p. ej.
			# el giro "modo creepy" de un POI normalmente alegre. La próxima vez
			# que se entre al POI, `ViewPlace` restaura su `music` propio de
			# `data/ids/<id>.json`, así que no hace falta revertirlo a mano.
			if AudioManager.has_music_track(val):
				AudioManager.play_music(val)
		"faceta":
			var fp := val.split("=")
			if fp.size() == 2:
				var fk := String(fp[0]).strip_edges().to_lower()
				match fk:
					"valentia": fk = "valor"
					"amabilidad": fk = "bondad"
					"encanto": fk = "aspecto"
					"astucia": fk = "inteligencia"
				var amount := _pint(fp[1])
				GlobalState.facetas[fk] = clampi(int(GlobalState.facetas.get(fk, 0)) + amount, -10, 10)
				GlobalEvents.emit_event("stat_increased", {"type": "faceta", "key": fk, "amount": amount})
		"item":
			var ip := val.split("=")
			_give_item(String(ip[0]), _pint(ip[1]) if ip.size() > 1 else 1)
		"flag":
			GlobalState.set_npc_flag(npc_id, val)
		"rel", "relation":
			var target_npc := npc_id
			var amount := 1
			if val.contains("="):
				var rp := val.split("=")
				target_npc = String(rp[0]).strip_edges()
				amount = _pint(rp[1])
			elif val != "" and _pint(val) != 0:
				amount = _pint(val)
			if target_npc != "":
				GlobalState.add_relation(target_npc, amount)
				GlobalEvents.emit_event("stat_increased", {"type": "rel", "npc": target_npc, "amount": amount})
		"questf":
			QuestManager.set_quest_forward(val)
		"quests":
			GlobalState.quest_state = val
		"quest_start":
			# "quest_start:id" o "quest_start:id:stage" (Sistema Multi-Quest,
			# independiente de `quest_state` — ver task_arreglos.md §1).
			var qsp := val.split(":")
			QuestManager.start_quest(String(qsp[0]), _pint(qsp[1]) if qsp.size() > 1 else 0)
		"quest_stage":
			# "quest_stage:id=stage"
			var qtp := val.split("=")
			if qtp.size() == 2:
				QuestManager.set_quest_stage(String(qtp[0]), _pint(qtp[1]))
		"quest_complete":
			QuestManager.complete_quest(val)
		"quest_fail":
			QuestManager.fail_quest(val)
		"prof":
			var is_new: bool = not (val in GlobalState.unlocked_professions)
			if is_new:
				GlobalState.unlocked_professions.append(val)
				GlobalState.pending_unlocked_profession_celebration = val
			GlobalState.set_profession(val)
			# Aprender la profesión desbloquea también su habilidad de exploración.
			ExplorationSkills.unlock_for_profession(val)
		"dam":
			QuestManager.open_dam()
		"qaction":
			QuestManager.handle_choice(val)
		"gflag":
			# Flag global data-driven: "gflag:nombre" activa, "gflag:nombre=0" desactiva.
			var gp := val.split("=")
			var on := true if gp.size() < 2 else (_pint(gp[1]) != 0)
			GlobalState.set_world_flag(String(gp[0]), on)
		"boat_spawn", "spawn_boat":
			GlobalState.spawn_boat_at_port()
		"boat_pos":
			var bp := val.split(",")
			if bp.size() >= 2:
				GlobalState.boat_pos = Vector2i(_pint(bp[0]), _pint(bp[1]))
				GlobalState.set_world_flag("boat_obtained", true)
				GlobalState.state_updated.emit()
		"discover":
			# Códice de Curiosidades (Task 2): registra una entrada de lore como
			# descubierta. Si es NUEVA, muestra un aviso y comprueba el completismo.
			if GlobalState.discover_lore(val):
				GlobalEvents.emit_event("lore_discovered", {"id": val})
				_check_codex_completion()
		"worldt":
			# Transformación del mundo (presa/cueva/mono…) por nombre, sin coords fijas.
			QuestManager.run_world_transform(val)
		"combat":
			# Combate: "combat:enemy_id[:level[:boss]]".
			var cp := val.split(":")
			var eid := String(cp[0])
			var lvl := _pint(cp[1]) if cp.size() > 1 else 1
			var boss := (cp.size() > 2 and cp[2] == "boss")
			QuestManager.trigger_combat(eid, lvl, boss)
		"event":
			# Composición: ejecuta otro evento nombrado de events.json.
			run_event(val, npc_id)
		"emit":
			# Emite un EVENTO GLOBAL al bus: "emit:EVENT_NAME[=k=v,k2=v2]".
			# El emisor no sabe quién reacciona; cada sistema decide si se suscribe.
			_emit_global_event(val)
		"dialogue":
			# Muestra un diálogo por su id. Preferimos una escena del Sistema
			# Narrativo (scenes.json) si existe; si no, se adapta el diálogo legado.
			QuestManager.request_dialogue_id(val)
		"cine":
			# Lanza una escena (scenes.json) por su id, con la cámara del
			# mundo reaccionando a los nodos "event" EVENT_CINE_CAMERA.
			QuestManager.play_cinematic(val)
		"shop", "open_shop":
			# Abre la vista de tienda desde un diálogo/POI: "open_shop[:stock_id]"
			var stock_name := val.strip_edges()
			var shop_data: Dictionary = {
				"stock": stock_name,
				"poi_id": npc_id,
				"npc": npc_id,
			}
			if Design.has_id(npc_id):
				var poi_spec := Design.get_id(npc_id)
				if stock_name == "" and poi_spec.has("stock"):
					shop_data["stock"] = String(poi_spec["stock"])
				if poi_spec.has("city"):
					shop_data["city"] = String(poi_spec["city"])
			if shop_data["stock"] == "":
				shop_data["stock"] = "default"
			SceneManager.go_to_shop(shop_data)
		_:
			push_warning("Design: token de reward desconocido '%s'" % tok)


## Parsea y emite un evento global al bus GlobalEvents desde el mini-lenguaje.
## Formato: "EVENT_NAME" o "EVENT_NAME=clave=valor,clave2=valor2". Las parejas
## clave=valor forman el `payload` (todas como String; el receptor las interpreta).
func _emit_global_event(spec: String) -> void:
	var name_part := spec
	var payload: Dictionary = {}
	var eq := spec.find("=")
	if eq != -1:
		name_part = spec.substr(0, eq)
		var rest := spec.substr(eq + 1)
		for pair in rest.split(",", false):
			var kv := pair.split("=")
			if kv.size() >= 2:
				payload[String(kv[0]).strip_edges()] = String(kv[1]).strip_edges()
	GlobalEvents.emit_event(name_part.strip_edges(), payload)


# ══════════════════════════════════════════════════════════════════════════════
# CÓDICE DE CURIOSIDADES (Task 2)
# ══════════════════════════════════════════════════════════════════════════════
## Ficha de una entrada del Códice (o {} si no existe en el catálogo).
func get_codex_entry(codex_id: String) -> Dictionary:
	var e = codex.get(codex_id, {})
	return e if e is Dictionary else {}

## Ids de todas las entradas del Códice, ordenadas por `category` y luego por id
## para un render estable en la rejilla del CodexViewer.
func codex_ids() -> Array:
	var ids_arr: Array = codex.keys()
	ids_arr.sort_custom(func(a, b):
		var ca := String(get_codex_entry(a).get("category", ""))
		var cb := String(get_codex_entry(b).get("category", ""))
		if ca == cb:
			return String(a) < String(b)
		return ca < cb)
	return ids_arr

## Total de entradas del Códice definidas en el catálogo.
func codex_total() -> int:
	return codex.size()

## Comprueba si el jugador ha descubierto TODAS las entradas del Códice; si es la
## primera vez, concede el premio de completismo (una sola vez, vía world_flag) y
## emite el evento para el aviso. Ver GlobalState.grant_codex_completion_reward.
func _check_codex_completion() -> void:
	var total := codex_total()
	if total <= 0 or GlobalState.has_world_flag("codex_complete"):
		return
	for cid in codex.keys():
		if not GlobalState.is_lore_discovered(String(cid)):
			return
	GlobalState.set_world_flag("codex_complete", true)
	GlobalState.grant_codex_completion_reward()
	GlobalEvents.emit_event("codex_completed", {})


func _give_item(id: String, qty: int) -> void:
	# Los metadatos (nombre/categoría/icono) los resuelve GlobalState desde items.json.
	GlobalState.add_item(id, qty)
	GlobalEvents.emit_event("item_received", {"id": id, "qty": qty})


## Convierte a int tolerando un signo '+' inicial ("+2" -> 2).
func _pint(s) -> int:
	var t := String(s).strip_edges()
	if t.begins_with("+"):
		t = t.substr(1)
	return int(t)


# ══════════════════════════════════════════════════════════════════════════════
# EVENTOS DATA-DRIVEN
# ──────────────────────────────────────────────────────────────────────────────
# Un EVENTO es una lista ordenada de acciones (el mismo mini-lenguaje de
# `apply_reward`) identificada por un nombre en `events.json`. Opcionalmente lleva
# una `condition` (Expression) que, si es falsa, aborta el evento. Los eventos
# permiten definir en DATOS la lógica que antes vivía cableada en QuestManager
# (dar banana, iniciar combate de la cueva, abrir la presa, etc.).
# ══════════════════════════════════════════════════════════════════════════════

## ¿Existe un evento con ese id en events.json?
func has_event(event_id: String) -> bool:
	return events.has(event_id)


## Ejecuta un evento nombrado (lista de acciones del mini-lenguaje). Respeta su
## `condition` opcional. Devuelve true si se ejecutó, false si no existe o su
## condición no se cumplió. `npc_id` da contexto a los flags/relación de NPC.
func run_event(event_id: String, npc_id: String = "") -> bool:
	var ev = events.get(event_id, null)
	if not (ev is Dictionary):
		push_warning("Design: evento desconocido '%s'" % event_id)
		return false
	var cond := String(ev.get("condition", ""))
	if cond != "" and not eval_condition(cond, npc_id):
		return false
	var actions = ev.get("actions", [])
	if actions is Array:
		for raw in actions:
			var tok := String(raw).strip_edges()
			if tok != "":
				_apply_token(tok, npc_id)
	GlobalState.state_updated.emit()
	return true


# ══════════════════════════════════════════════════════════════════════════════
# QUESTLINE DATA-DRIVEN
# ══════════════════════════════════════════════════════════════════════════════

## Orden monotónico de los estados de la questline principal (para avance
## unidireccional). Vacío si quests.json no lo define (QuestManager usa su
## constante cableada como fallback).
func quest_order() -> Array:
	var o = quests.get("order", [])
	return o if o is Array else []


## Descripción legible de un estado de misión (para el Diario): { title, hint }
## localizados, o {} si quests.json no define descripción para ese estado.
func quest_desc(state: String) -> Dictionary:
	var d = quests.get("descriptions", {})
	if d is Dictionary and d.has(state):
		var entry = d[state]
		if entry is Dictionary:
			return {
				"title": _loc_str(entry.get("title", state)),
				"hint": _loc_str(entry.get("hint", "")),
			}
	return {}


## Definición de evento a disparar al vencer a `enemy_id`, o "" si no hay hook.
## quests.json → { "combat_victory": { "enemy_id": { "event": "id_evento" } } }.
func quest_combat_event(enemy_id: String) -> String:
	var cv = quests.get("combat_victory", {})
	if cv is Dictionary and cv.has(enemy_id):
		var entry = cv[enemy_id]
		if entry is Dictionary:
			return String(entry.get("event", ""))
	return ""


## Definición data-driven de una transformación del mundo, o {} si no
## está en world_transforms.json. Formato: { rules:[{match,set}] } (declarativa)
## o { builtin:"nombre" } (delega en una rutina procedural de WorldMapBuilder).
func get_world_transform(transform_name: String) -> Dictionary:
	var d = world_transforms.get(transform_name, {})
	return d if d is Dictionary else {}
