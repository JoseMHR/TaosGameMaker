# GlobalState.gd
# Singleton Autoload — Estado global del héroe, inventario y misiones.
# Registrar en Project Settings -> Autoload con el nombre "GlobalState"
extends Node

## Versión del formato de guardado (`to_dict()`/`from_dict()`). Subir este
## número SOLO cuando se introduzca un cambio de formato que `from_dict()` no
## pueda absorber con su propio `.get(key, default)` defensivo habitual (p.
## ej. renombrar una clave raíz o cambiar la forma de un valor existente), y
## registrar la migración correspondiente en `_run_save_migrations()` — ver
## task_arreglos.md §5.1.
const SAVE_VERSION: int = 1

signal state_updated
## (Game Feel): subir de nivel debe sentirse importante, no solo un
## número que cambia. GameRoot escucha estas señales para mostrar un aviso
## celebratorio (reutiliza el mismo toast de logros/tutoriales).
signal leveled_up(new_level: int)
signal job_leveled_up(profession: String, new_level: int)
## Emitida al subir de nivel un OFICIO DE FARMEO (leñador/minero/pesca/
## agricultor/ganadero, ver `skills`). Sistema aparte de `job_leveled_up`
## (profesiones de COMBATE). GameRoot la escucha para mostrar un aviso discreto.
signal skill_leveled_up(skill_key: String, new_level: int)

#region DATOS DEL HÉROE
var player_name: String = "Don Nadie"
## ÚNICA fuente de verdad de "hay una UI MODAL flotante cubriendo la pantalla"
## (Hub de personaje, Menú Radial, o cualquier vista flotante abierta con
## `GameRoot._show_view`: personaje/inventario/diario/forja/encargos/cocina).
## La escriben `TabWorld3D.set_modal_mode()` (fuente principal, cablea TODAS
## las vistas flotantes) y puntualmente `GameRoot._toggle_radial_menu()` /
## `_on_radial_menu_closed()` para una respuesta inmediata al pulsar el botón,
## antes de que termine la animación de cierre. NO cubre el bloqueo por
## narrativa activa: para eso consulta `SceneRunner.is_active()` por separado
## (así lo hace ya `TabWorld3D._apply_free_movement/_unhandled_input/_input`).
var is_movement_locked: bool = false
var gold: int      = GameConfig.START_GOLD
var level: int     = GameConfig.START_LEVEL
var xp: int        = GameConfig.START_XP
var xp_needed: int = GameConfig.START_XP_NEEDED
var hp: int        = 0   # Derivado: se calcula en _ready() / recalculate_derived_stats()
var max_hp: int    = 0
var mp: int        = 0
var max_mp: int    = 0
## Estado de envenenamiento / contaminación activa (efecto visual y DOT).
var is_poisoned: bool = false
## Energía de habilidades de mazmorra (recurso verde del HUD). Transitorio: se
## regenera con el tiempo (ver DungeonPlayer) y arranca al máximo.
var energy: float  = float(GameConfig.MAX_ENERGY)
var max_energy: int = GameConfig.MAX_ENERGY

var stats: Dictionary = GameConfig.START_STATS.duplicate(true)
var stat_points: int  = GameConfig.START_STAT_POINTS

#endregion

#region FACETAS DE PERSONALIDAD (-10 a +10)
var facetas: Dictionary = GameConfig.START_FACETAS.duplicate(true)

#endregion

#region HABILIDADES DE FARMEO
var skills: Dictionary = GameConfig.START_SKILLS.duplicate(true)

#endregion

#region BUFFS TEMPORALES DE COMIDA (Cocinero)
## clave de buff (p. ej. "strength"/"vigor") -> timestamp unix de expiración.
## Se conceden al comer ciertos platos (ver GlobalState.eat_food) y se leen en
## vivo desde get_phys_damage()/get_phys_defense(); si ya expiraron simplemente
## dejan de aplicarse (no hace falta limpiarlos activamente).
var food_buffs: Dictionary = {}

## Fachada: la lógica vive en `CookingBuffsManager` (scripts/systems). Los datos
## (`food_buffs`) siguen viviendo aquí — ver task_arreglos.md §3.
func grant_food_buff(key: String, duration_sec: int) -> void:
	cooking_mgr.grant_food_buff(key, duration_sec)

## ¿Está activo AHORA MISMO el buff de comida `key`?
func has_food_buff(key: String) -> bool:
	return cooking_mgr.has_food_buff(key)

#endregion

#region 6 SLOTS DE EQUIPAMIENTO
var equipped: Dictionary = {
	"helmet":    null,
	"weapon":    null,
	"shield":    null,
	"armor":     null,
	"shoes":     null,
	"accessory": null
}

# ─────────────────────────────────────────────
# CONSTRUCCIONES DE LA BASE  (0 = sin construir, 1 = construida)
# La base empieza VACÍA. Cada construcción se desbloquea recolectando.
# ─────────────────────────────────────────────
var base_levels: Dictionary = {
	"campfire": 0,   # Hoguera — regenera vida en la base (desbloquea: madera)
	"kitchen":  0,   # Cocina — permite cocinar (desbloquea: piedra)
	"dummy":    0,   # Muñeco — vista de entrenamiento (desbloquea: madera+piedra)
}

# ─────────────────────────────────────────────
# RECURSOS YA DESCUBIERTOS (recolectados al menos una vez)
# Sirven para desbloquear construcciones de la base.
# ─────────────────────────────────────────────
var resources_discovered: Dictionary = {
	"wood":  false,
	"stone": false,
	"fish":  false,
	"wheat": false,
	"milk":  false,
}

# ─────────────────────────────────────────────
# BESTIARIO — conocimiento descubierto de cada enemigo (memoria de combate).
# Estructura: enemy_id -> { seen:bool, kills:int, weak:[elem], resist:[elem] }.
# Se rellena al ver/golpear enemigos; lo consulta la vista de Bestiario.
# ─────────────────────────────────────────────
var bestiary: Dictionary = {}

## Ítems descubiertos alguna vez (Enciclopedia): item_id -> true. Se registra la
## PRIMERA vez que el jugador obtiene cada ítem (ver ItemInventoryManager.add_item).
var encyclopedia_unlocked: Dictionary = {}

## CÓDICE DE CURIOSIDADES (Task 2): entradas de lore ambiental descubiertas al
## inspeccionar POIs / conocer PNJs singulares. Estructura: codex_id -> unix_time
## del hallazgo. Se registra vía el token de recompensa `discover:<id>` (ver
## Design._apply_token) y lo consulta CodexViewer. Persiste en el guardado.
var lore_discovered: Dictionary = {}

#endregion

#region INVENTARIO, MISIONES Y PROFESIÓN
var inventory: Array[Dictionary] = []
## Almacén PERSISTENTE del Cofre de la Base (ver task4.md): misma forma que
## `inventory` (id/name/quantity/category/icon), pero SIN límite de huecos y
## que NUNCA se pierde, ni siquiera si se levanta otro Cofre en una Base nueva
## (es un único almacén compartido, no uno por Base). No confundir con
## `opened_chests` (cofres de botín de un solo uso del mundo/mazmorras).
var chest_storage: Array[Dictionary] = []
var quest_state: String = "not_started"
## Misiones SECUNDARIAS/paralelas (independientes de `quest_state`, que solo
## representa la historia principal lineal). Estructura: quest_id -> {
##   "stage": int,            # 0 = iniciada, 1..N = pasos, -1 = completada, -2 = fallada
##   "state": String,         # etiqueta legible de sub-estado opcional
##   "custom_data": Dictionary # contadores propios de la misión (ej: {"gathered": 3})
## }. Lógica en `QuestManager` (start_quest/set_quest_stage/complete_quest/...);
## ver task_arreglos.md §1 (Sistema Multi-Quest).
var quests: Dictionary = {}
## Flags de historia persistentes.
var seen_intro: bool = false      # ¿Se ha mostrado ya el despertar en la Sala de la Esfera?
## Causa de la última muerte, para que `ViewOrbRoom` elija una frase de
## reproche acorde en lugar del mensaje genérico de siempre. Se rellena justo
## antes de disparar la muerte (combate: `CombatDamageResolver`; peligro
## ambiental: `TabWorld3D`/`ViewDungeon`) y se lee una sola vez en
## `ViewOrbRoom._dialogue_for("death")`.
## Formas válidas: {"cause":"level1"} | {"cause":"boss"} |
## {"cause":"normal_high"} | {"cause":"normal_low"} |
## {"cause":"hazard","hazard_type":"lava"|"spikes"|"void_fall"|"pol"|"heat"|"cold"}
var pending_death_cause: Dictionary = {}
var dam_opened: bool = false      # ¿Se ha reabierto la presa? (transforma el valle de yelmo)
var cave_cleared: bool = false    # ¿Se ha derrotado al monstruo de la cueva? (abre el paso este)
## Flags de historia GENÉRICOS y DATA-DRIVEN: cualquier evento/quest de
## `events.json`/`quests.json` puede fijar/consultar flags arbitrarios sin tocar
## código (token `gflag:nombre`, función `gflag("nombre")` en condiciones).
## clave(String) -> true. Persisten en el guardado.
var world_flags: Dictionary = {}
## CAMBIOS FÍSICOS PERSISTENTES DEL MUNDO. Capa GENÉRICA y ESCALABLE: cualquier
## mecánica que modifique una casilla del
## mapamundi (talar/plantar un árbol, destruir una roca, excavar/canalizar agua,
## colocar el campamento o una construcción, etc.) registra aquí un DELTA por
## coordenada en lugar de requerir código de guardado ad-hoc por característica.
## Formato: clave "x,y" (world_delta_key) -> Dictionary de campos a sobrescribir
## sobre el CellResource base, con las MISMAS claves que el DSL de world_transforms
## (terrain/item/resource/name/icon/description/biome_color/event_id/...).
## Al reconstruir el mundo (WorldMapBuilder.build_into_global) estos deltas se
## reaplican sobre las casillas base, de modo que el mundo RECUERDA lo que hizo el
## jugador entre sesiones. Persiste en el guardado.
var world_deltas: Dictionary = {}
## Cofres YA ABIERTOS. clave "event_id:planta:x:y" -> true, para
## que un cofre de mazmorra data-driven no se pueda saquear dos veces. Persiste.
var opened_chests: Dictionary = {}
## Jefes YA DERROTADOS (bug de reaparición). clave "event_id:enemy_id" -> true, para
## que un BOSS de mazmorra no reaparezca al reentrar (los monstruos normales sí
## reaparecen porque el escenario se reconstruye en cada entrada). Persiste.
var defeated_bosses: Dictionary = {}
## ENEMIGOS DEL MAPAMUNDI derrotados. clave "x,y" (punto de aparición) -> timestamp
## unix (int) en el que pueden REAPARECER; 0 = permanente (sin respawn). Mientras
## `now < ts`, el actor no aparece. Persiste.
var overworld_enemies: Dictionary = {}
var debug_mode: bool = false      # Partida iniciada en "Modo Debug" (movimiento x3, etc.)
var debug_speed_mult: float = 3.0  # Multiplicador de velocidad en modo debug (1.0 o 3.0)
var is_test_room: bool = false    # Partida de "Sala de Tests" (mapa reducido + héroe maxeado)
var has_built_base: bool = false
var base_coord: Vector2i = Vector2i(-1, -1)
## Coord de la HOGUERA física, colocada junto a la tienda de campaña al montar el
## campamento. Persiste vía world_deltas; (-1,-1) = sin hoguera. La tienda sirve
## para dormir; la hoguera, para cocinar.
var campfire_coord: Vector2i = Vector2i(-1, -1)
## Nivel del CAMPAMENTO físico (0 = sin campamento; 1 = tienda montada; niveles
## superiores añaden construcciones físicas alrededor).
var camp_level: int = 0
## CONSTRUCCIONES del campamento YA levantadas. clave = key de
## GameConfig.CAMP_STRUCTURES; valor = "x,y" de su casilla. Persiste.
var camp_structures: Dictionary = {}

const JOBS: Array[String] = [
	"Don Nadie",
	"Guerrero",
	"Arquero",
	"Elementalista",
	"Sacerdote",
	"Psíquico",
	"Tiempo"
]

var profession: String = GameConfig.START_PROFESSION
var unlocked_professions: Array[String] = ["Don Nadie"]
var job_level: int = 1
var job_xp: int = 0
var job_xp_needed: int = 100

## Progreso de trabajo POR PROFESIÓN (persistente). La experiencia NO es compartida:
## cada profesión tiene su propia barra de JB. `job_level`/`job_xp`/`job_xp_needed`
## son SIEMPRE los de la profesión activa; al cambiar de profesión (set_profession)
## se guarda el progreso de la anterior aquí y se carga el de la nueva.
## clave = nombre de profesión; valor = { "level", "xp", "xp_needed" }.
## Cada profesión (incluida Don Nadie) tiene su propia barra y nivel de JB.
var profession_levels: Dictionary = {}

## Habilidades de exploración desbloqueadas. Persistente. Contiene ids de
## `ExplorationSkills` (p.ej. "kinetic_wave"). Una habilidad aprendida está siempre
## disponible; no hay loadout ni selección de personaje.
var unlocked_skills: Array[String] = []

## Habilidades de combate activas por profesión (máximo 4 simultáneas equipadas).
var active_combat_skills: Dictionary = {}

## Sendero de profesión completado pendiente de que la Esfera oriente al jugador al salir al mapamundi.
var pending_trial_completed_sendero: String = ""

## Profesión recién desbloqueada pendiente de celebrar con modal al volver al mapamundi.
var pending_unlocked_profession_celebration: String = ""

#endregion

#region ESTADO DEL MAPAMUNDI (persistente)
## Posición actual del jugador en la rejilla del mundo.
var player_pos: Vector2i = GameConfig.WORLD_START_POS

## Posición del BARCO aparcado en la rejilla del mundo. Vector2i(-1,-1) = el
## mapa activo no define ninguno (`world.json` sin campo `boat_spawn`). Solo
## transitable por costa/mar; ver `is_sailing` y `TabWorld3D.is_cell_passable`.
var boat_pos: Vector2i = Vector2i(-1, -1)
## true mientras el jugador controla el BARCO en vez de a su personaje (tras
## pisar su casilla). El barco se aparca de nuevo al "Desembarcar".
var is_sailing: bool = false

## Hora in-game del ciclo día/noche (float [0,24)). Fuente de verdad persistente;
## la gestiona el autoload TimeManager, que la lee al cargar y la actualiza al
## avanzar el tiempo, de modo que el ciclo continúa entre sesiones.
var world_hour: float = 8.0
## Conjunto de coordenadas ya exploradas (para la niebla de guerra). coord -> true
var explored_coords: Dictionary = {}

## DESTINOS DE VIAJE RÁPIDO descubiertos (ciudades visitadas). clave "x,y" ->
## { name:String, icon:String }. Se rellena al pisar/entrar en una ciudad; lo
## consulta el mapamundi para ofrecer viaje rápido entre lugares conocidos. Persiste.
var travel_points: Dictionary = {}

## Bandera transitoria (no persiste): pedida por el NPC transportista de una
## ciudad para abrir el selector de viaje en cuanto se vuelva al mapamundi.
var pending_open_travel: bool = false

## Coordenada pendiente a la que teletransportar al jugador al volver al mapamundi.
var pending_teleport_coord: Vector2i = Vector2i(-1, -1)

## Estado de los NODOS DE RECOLECCIÓN finitos (persistente por casilla).
## clave "x,y" -> {"remaining": int, "ts": int (unix de la última actualización)}.
var gather_nodes: Dictionary = {}

# Base de datos de todas las casillas del mundo (cargada dinámicamente)
var hexagons_db: Dictionary = {}

#endregion

#region ENCARGOS (TABLÓN), CONTADORES Y MEMORIA DE NPCs
## Encargos aceptados actualmente.  id -> true
var active_encargos: Dictionary = {}
## Progreso acumulado de cada encargo aceptado.  id -> int
var encargo_progress: Dictionary = {}
## Contador de enemigos derrotados (de por vida).
var kills_total: int = 0
## Logros desbloqueados.  ach_id -> true
var achievements_unlocked: Dictionary = {}
## Progreso de tutoriales.  tut_id -> índice del paso actual (int).
## Un índice >= nº de pasos significa "completado".
var tutorials_progress: Dictionary = {}
## Memoria de NPCs visitados.  npc_id -> {"visits": int, "flags": {clave:true}}
var npc_memory: Dictionary = {}
## Afinidad acumulada por NPC (diálogos).  npc_id -> int
var npc_relations: Dictionary = {}
## Registro de compras únicas en tiendas (persistente). stock_id -> Array de item_ids agotados.
var shop_purchases: Dictionary = {}

#endregion

#region PROGRESO OFFLINE  (marca de tiempo del último guardado, en unix segundos)
var last_seen_ts: int = 0
## Resumen del último cálculo offline, para que la UI lo muestre una vez.
var pending_offline_summary: Dictionary = {}


#endregion

#region CICLO DE VIDA

## Gestor especialista de inventario y equipamiento: aloja la LÓGICA de
## manipulación de objetos/equipo; los datos (inventory/equipped) siguen
## viviendo en este autoload. Se instancia en `_ready`.
var inventory_mgr: ItemInventoryManager = null

## Gestor especialista de banderas y eventos globales: aloja la LÓGICA de
## world_flags/jefes derrotados; los datos siguen en este autoload. Se
## instancia en `_ready`.
var flags_mgr: GameFlagsManager = null

## Gestor especialista de botín/rareza/forja: aloja la LÓGICA de tiradas de
## botín y forja; los datos (gold/inventory) siguen en este autoload. Se
## instancia en `_ready`.
var loot_mgr: LootManager = null

## Gestor especialista de encargos del tablón: aloja la LÓGICA de
## aceptar/progresar/reclamar encargos; los datos (`active_encargos`/
## `encargo_progress`) siguen en este autoload. Se instancia en `_ready`.
var encargos_mgr: EncargosManager = null

## Gestor especialista de REFINAMIENTO de equipo (+0 a +10, ver task5.md):
## aloja la LÓGICA de coste/riesgo; los datos (inventory) siguen en este
## autoload. Se instancia en `_ready`.
var refine_mgr: RefineManager = null

## Gestor especialista de cocina/consumibles/comida (ver task_arreglos.md §3):
## aloja la LÓGICA de recetas y buffs temporales; los datos (`food_buffs`,
## `skills`) siguen en este autoload. Se instancia en `_ready`.
var cooking_mgr: CookingBuffsManager = null

## Gestor especialista de progresión de Base/Campamento (ver task_arreglos.md
## §3): aloja la LÓGICA de niveles/costes; los datos (`base_levels`,
## `camp_level`, `camp_structures`) siguen en este autoload. NO gestiona la
## colocación física sobre el mapamundi (ver GlobalState.build_camp_structure).
## Se instancia en `_ready`.
var camp_mgr: CampStructuresManager = null

func _ready() -> void:
	inventory_mgr = ItemInventoryManager.new()
	inventory_mgr.setup(self)
	flags_mgr = GameFlagsManager.new()
	flags_mgr.setup(self)
	loot_mgr = LootManager.new()
	loot_mgr.setup(self)
	encargos_mgr = EncargosManager.new()
	encargos_mgr.setup(self)
	refine_mgr = RefineManager.new()
	refine_mgr.setup(self)
	cooking_mgr = CookingBuffsManager.new()
	cooking_mgr.setup(self)
	camp_mgr = CampStructuresManager.new()
	camp_mgr.setup(self)
	recalculate_derived_stats()
	hp = max_hp
	mp = max_mp
	energy = float(max_energy)
	# Siempre arrancar en horizontal (Landscape) por defecto, ignorando la detección del sensor
	set_orientation(true)


## Orientación activa de la interfaz (true = horizontal / landscape, false = vertical / portrait).
## Por especificación, SIEMPRE se inicia en horizontal por defecto, sin importar cómo se sostenga el móvil.
var is_landscape: bool = true

## Cambia la orientación explícitamente.
## En móvil bloquea la orientación con `DisplayServer.screen_set_orientation`.
## En PC redimensiona la ventana para simular el formato correspondiente.
func set_orientation(p_landscape: bool) -> void:
	is_landscape = p_landscape
	if is_landscape:
		if not OS.has_feature("editor") and not OS.has_feature("mobile"):
			DisplayServer.window_set_size(Vector2i(1280, 590))
		if OS.has_feature("mobile"):
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	else:
		if not OS.has_feature("editor") and not OS.has_feature("mobile"):
			DisplayServer.window_set_size(Vector2i(388, 840))
		if OS.has_feature("mobile"):
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	state_updated.emit()


func toggle_orientation() -> void:
	var vp := get_viewport()
	if vp != null:
		var cur_sz := vp.get_visible_rect().size
		is_landscape = cur_sz.x > cur_sz.y
	set_orientation(not is_landscape)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or event.keycode == KEY_F10 or (event.keycode == KEY_O and (event.ctrl_pressed or event.meta_pressed)):
			toggle_orientation()
			get_viewport().set_input_as_handled()

## Reinicia el estado del juego para una nueva partida con los valores iniciales.
## Si `debug` es true, arranca una partida de PRUEBAS (nivel/puntos/oro/equipo altos
## y movimiento acelerado). Si es false, la partida normal empieza débil: 1 de vida,
## 1 de maná, sin oro y SIN equipamiento en la bolsa.
func reset_for_new_game(debug: bool = false) -> void:
	debug_mode  = debug
	gold        = GameConfig.START_GOLD
	level       = GameConfig.START_LEVEL
	xp          = GameConfig.START_XP
	xp_needed   = GameConfig.START_XP_NEEDED
	stats       = GameConfig.START_STATS.duplicate(true)
	stat_points = GameConfig.START_STAT_POINTS
	facetas     = GameConfig.START_FACETAS.duplicate(true)
	skills      = GameConfig.START_SKILLS.duplicate(true)
	food_buffs  = {}
	is_poisoned = false
	profession  = GameConfig.START_PROFESSION
	unlocked_professions = ["Don Nadie"]
	job_level   = 1
	job_xp      = 0
	job_xp_needed = GameConfig.xp_needed_for_job_level(2)
	profession_levels = {
		"Don Nadie": { "level": 1, "xp": 0, "xp_needed": GameConfig.xp_needed_for_job_level(2) }
	}
	unlocked_skills = []
	active_combat_skills.clear()
	active_combat_skills["Don Nadie"] = _default_combat_skill_slots("Don Nadie")
	pending_trial_completed_sendero = ""
	pending_unlocked_profession_celebration = ""
	quest_state = "not_started"
	quests.clear()
	# En modo debug nos saltamos la intro de la Sala de la Esfera (empieza en el mundo).
	seen_intro  = debug
	dam_opened  = false
	cave_cleared = false
	world_flags = {}
	world_deltas = {}
	opened_chests = {}
	defeated_bosses = {}
	overworld_enemies = {}
	is_test_room = false
	achievements_unlocked.clear()
	tutorials_progress.clear()
	has_built_base = false
	base_coord = Vector2i(-1, -1)
	campfire_coord = Vector2i(-1, -1)
	camp_level = 0
	camp_structures = {}
	chest_storage = []

	equipped = {
		"helmet": null, "weapon": null, "shield": null,
		"armor": null, "shoes": null, "accessory": null,
	}
	base_levels = {"campfire": 0, "kitchen": 0, "dummy": 0}
	resources_discovered = {"wood": false, "stone": false, "fish": false, "wheat": false, "milk": false}
	lore_discovered = {}   # Códice de Curiosidades vacío en partida nueva (Task 2).
	shop_purchases = {}    # Compras únicas en tiendas reiniciadas.

	# Estado del mapamundi. La casilla de aparición es DATA-DRIVEN: se lee del mapa
	# cargado (world.json / world_test.json, campo `spawn`, editable desde el editor
	# de mapas) y se acota a la rejilla, de modo que redimensionar el mundo no deja
	# al héroe fuera. Si el mapa no define `spawn`, se usan las constantes de fallback.
	var fallback: Vector2i = GameConfig.DEBUG_START_POS if debug else GameConfig.WORLD_START_POS
	player_pos = Design.world_spawn(fallback)
	boat_pos = Design.world_boat_spawn()
	is_sailing = false
	world_hour = GameConfig.DAY_START_HOUR + 2.0   # amanece a las 6 → empezar a media mañana
	explored_coords.clear()
	gather_nodes.clear()
	# El mapa (hexagons_db) es un caché derivado de Design.world que TabWorld3D solo
	# reconstruye si está vacío. Al ser GlobalState un autoload persistente, hay que
	# limpiarlo aquí para que la nueva partida lo regenere desde el mapa correcto
	# (evita que se arrastre el mapa de la Sala de Tests a una partida normal).
	hexagons_db.clear()

	# Encargos, contadores y memoria de NPCs
	active_encargos.clear()
	encargo_progress.clear()
	kills_total = 0
	npc_relations.clear()
	npc_memory.clear()
	last_seen_ts = _now_unix()
	pending_offline_summary = {}

	# Inventario inicial: la partida normal y modo debug empiezan sin equipo (se consigue jugando o con la barra debug).
	inventory.clear()
	for it: Dictionary in GameConfig.START_INVENTORY:
		add_item(String(it["id"]), int(it["qty"]))

	debug_speed_mult = 3.0 if debug else 1.0

	recalculate_derived_stats()
	hp = 1
	mp = 1
	energy = float(max_energy)
	if SaveManager != null:
		SaveManager.active = true
	state_updated.emit()


## Inicializa una partida de SALA DE TESTS: héroe de nivel 50 con estadísticas al
## máximo, todas las profesiones desbloqueadas/maxeadas, inventario y equipo
## completos, oro abundante y aparición en el centro del mapa de pruebas.
func reset_for_test_room() -> void:
	reset_for_new_game(true)
	is_test_room = true
	gold = 99999
	level = GameConfig.MAX_CHAR_LEVEL
	stat_points = 100
	grant_all_game_items(10)

	# Subir todas las características al máximo
	for stat_key in stats.keys():
		stats[stat_key] = 100

	unlocked_professions.assign(Design.get_professions().keys())
	job_level = GameConfig.MAX_JOB_LEVEL
	job_xp_needed = 1
	unlocked_skills = ExplorationSkills.all_ids()

	# Asegurar que todas las profesiones estén al nivel máximo de trabajo (30) con sus 4 habilidades finales
	for p_key: String in Design.get_professions().keys():
		profession_levels[p_key] = {
			"level": GameConfig.MAX_JOB_LEVEL,
			"xp": 0,
			"xp_needed": 1
		}
		active_combat_skills[p_key] = _default_combat_skill_slots(p_key)

	# Concesión automática de permisos de los 6 entrenadores de sendero en la sala de tests
	world_flags["apprentice_sendero_guerrero"] = true
	world_flags["apprentice_sendero_arquero"] = true
	world_flags["apprentice_sendero_sacerdote"] = true
	world_flags["apprentice_sendero_elementalista"] = true
	world_flags["apprentice_sendero_psiquico"] = true
	world_flags["apprentice_sendero_tiempo"] = true

	var dtb = load("res://scenes/tabs/tab_world_3d/interactive/DebugToolbar.gd")
	if dtb != null:
		dtb.warp_to_zone(8, null)

	# Aparición en el mapa de pruebas (data-driven): se lee el `spawn` de
	# world_test.json (editable desde el editor de mapas → Mapa Debug). Si no está
	# definido, se usa el centro de la sala de pruebas como fallback.
	player_pos = Design.world_spawn(Vector2i(4, 4))
	recalculate_derived_stats()
	hp = max_hp
	mp = max_mp
	energy = float(max_energy)
	state_updated.emit()



#endregion

#region GESTIÓN DE XP Y NIVEL
func add_xp(amount: int) -> void:
	if level >= GameConfig.MAX_CHAR_LEVEL:
		xp = 0
		return
	# Pasiva "Erudito de lo Absurdo" (Task 2): +5% de XP permanente tras completar
	# el Códice de Curiosidades (world_flag `codex_complete`).
	if flags_mgr != null and has_world_flag("codex_complete"):
		amount = int(round(amount * 1.05))
	xp += amount
	var did_level_up := false
	while xp >= xp_needed and level < GameConfig.MAX_CHAR_LEVEL:
		xp -= xp_needed
		level += 1
		xp_needed = GameConfig.xp_needed_for_char_level(level + 1)
		stat_points += GameConfig.STAT_POINTS_PER_LEVEL
		did_level_up = true
	if level >= GameConfig.MAX_CHAR_LEVEL:
		level = GameConfig.MAX_CHAR_LEVEL
		xp = 0
	recalculate_derived_stats()
	if did_level_up:
		if AudioManager != null:
			AudioManager.play_sfx("levelup")
		self.leveled_up.emit(level)


## MODO DEBUG: Incrementa 1 nivel base otorgando sus puntos de stats (+nv).
func debug_add_level() -> void:
	if level >= GameConfig.MAX_CHAR_LEVEL:
		return
	level += 1
	stat_points += GameConfig.STAT_POINTS_PER_LEVEL
	xp = 0
	xp_needed = GameConfig.xp_needed_for_char_level(level + 1)
	recalculate_derived_stats()
	hp = max_hp
	mp = max_mp
	state_updated.emit()
	if AudioManager != null:
		AudioManager.play_sfx("levelup")
	leveled_up.emit(level)


## MODO DEBUG: Reduce 1 nivel base y reajusta los puntos de stats (-nv).
func debug_remove_level() -> void:
	if level <= 1:
		return
	level -= 1
	xp = 0
	xp_needed = GameConfig.xp_needed_for_char_level(level + 1)
	
	# Total de puntos de características que corresponden exactamente al nuevo nivel
	var total_allowed: int = (level - 1) * GameConfig.STAT_POINTS_PER_LEVEL + GameConfig.START_STAT_POINTS
	var spent: int = spent_stat_points()
	if spent > total_allowed:
		# Si los puntos invertidos exceden el tope del nuevo nivel, se restablecen a base
		stats = GameConfig.START_STATS.duplicate(true)
		stat_points = total_allowed
	else:
		stat_points = total_allowed - spent
	
	recalculate_derived_stats()
	hp = mini(hp, max_hp)
	mp = mini(mp, max_mp)
	state_updated.emit()


func add_job_xp(amount: int) -> void:
	if profession == "" or profession == "ninguna":
		return
	if job_level >= GameConfig.MAX_JOB_LEVEL:
		job_xp = 0
		_store_active_job_progress()
		return
	job_xp += amount
	var did_level_up := false
	while job_xp >= job_xp_needed and job_level < GameConfig.MAX_JOB_LEVEL:
		job_xp -= job_xp_needed
		job_level += 1
		job_xp_needed = GameConfig.xp_needed_for_job_level(job_level + 1)
		did_level_up = true
	if job_level >= GameConfig.MAX_JOB_LEVEL:
		job_level = GameConfig.MAX_JOB_LEVEL
		job_xp = 0
	_store_active_job_progress()
	state_updated.emit()
	if did_level_up:
		get_combat_skill_slots(profession)
		if AudioManager != null:
			AudioManager.play_sfx("levelup")
		job_leveled_up.emit(profession, job_level)


## Otorga `amount` de experiencia al nivel BASE del héroe Y a TODAS las
## profesiones ya desbloqueadas (`unlocked_professions`), cada una con su
## propio ritmo de subida de nivel (igual que `add_job_xp`, pero aplicado a
## todas a la vez en vez de solo a la activa). La usa el Muñeco de
## Entrenamiento (ver task4.md): al usarlo, otorga +camp_level de experiencia
## de golpe a la base y a cada profesión — muy útil para arrancar rápido una
## profesión recién desbloqueada.
func add_xp_to_all_jobs(amount: int) -> void:
	add_xp(amount)
	for prof in unlocked_professions:
		if prof == "" or prof == "ninguna":
			continue
		if prof == profession:
			add_job_xp(amount)
		else:
			_grant_job_xp_to_non_active(prof, amount)
	state_updated.emit()


## Otorga `amount` de XP de trabajo a UNA profesión concreta (esté activa o no),
## sin tocar las demás. "Don Nadie" recibe la XP como nivel base (mismo criterio
## que `add_job_xp`). La usa `CombatDamageResolver._end_combat` para repartir XP
## a cada profesión que participó realmente en el combate (ver
## `docs/design/PROGRESSION.md` §3: "individual por trabajo PARTICIPANTE").
func add_job_xp_to(prof: String, amount: int) -> void:
	if prof == "" or prof == "ninguna":
		return
	if prof == profession:
		add_job_xp(amount)
		return
	_grant_job_xp_to_non_active(prof, amount)
	state_updated.emit()


## Lógica de nivelado compartida por `add_xp_to_all_jobs`/`add_job_xp_to` para
## una profesión que NO es la activa en este instante (opera directamente sobre
## `profession_levels`, igual que hace `_store_active_job_progress` con la
## profesión activa). No emite `state_updated`: lo hace el llamante.
func _grant_job_xp_to_non_active(prof: String, amount: int) -> void:
	var p: Dictionary = profession_levels.get(prof, {"level": 1, "xp": 0, "xp_needed": 100})
	var lvl: int = int(p.get("level", 1))
	var pxp: int = int(p.get("xp", 0))
	var pxp_needed: int = int(p.get("xp_needed", 100))
	if lvl >= GameConfig.MAX_JOB_LEVEL:
		return
	pxp += amount
	var did_level_up := false
	while pxp >= pxp_needed and lvl < GameConfig.MAX_JOB_LEVEL:
		pxp -= pxp_needed
		lvl += 1
		pxp_needed = GameConfig.xp_needed_for_job_level(lvl + 1)
		did_level_up = true
	if lvl >= GameConfig.MAX_JOB_LEVEL:
		lvl = GameConfig.MAX_JOB_LEVEL
		pxp = 0
	profession_levels[prof] = {"level": lvl, "xp": pxp, "xp_needed": pxp_needed}
	if did_level_up:
		get_combat_skill_slots(prof)
		if AudioManager != null:
			AudioManager.play_sfx("levelup")
		job_leveled_up.emit(prof, lvl)


## Cambia la profesión activa preservando el progreso de cada una. Guarda la barra
## de JB de la profesión anterior en `profession_levels` y carga la de la nueva.
## Úsalo SIEMPRE en lugar de asignar `profession` directamente desde la UI.
func set_profession(new_prof: String) -> void:
	if new_prof == profession:
		return
	_store_active_job_progress()
	profession = new_prof
	_load_job_progress_for(new_prof)
	state_updated.emit()


## Vuelca el progreso de JB de la profesión activa en `profession_levels`.
func _store_active_job_progress() -> void:
	if profession == "" or profession == "ninguna":
		return
	profession_levels[profession] = {
		"level": job_level, "xp": job_xp, "xp_needed": job_xp_needed
	}


## "Don Nadie" no tiene curva de JB propia: su progreso de profesión SIEMPRE
## refleja el nivel base del héroe (tope en GameConfig.MAX_JOB_LEVEL aunque el
## nivel base siga subiendo por encima). Ver docs/design/PROGRESSION.md §3.3.
func _don_nadie_progress() -> Dictionary:
	if level >= GameConfig.MAX_JOB_LEVEL:
		return {"level": GameConfig.MAX_JOB_LEVEL, "xp": 0, "xp_needed": 1}
	return {"level": level, "xp": xp, "xp_needed": xp_needed}


## Carga en job_level/job_xp/job_xp_needed el progreso guardado de `prof`. Si no existe, empieza a 1.
func _load_job_progress_for(prof: String) -> void:
	if prof == "Don Nadie":
		var dn := _don_nadie_progress()
		job_level = int(dn["level"])
		job_xp = int(dn["xp"])
		job_xp_needed = int(dn["xp_needed"])
		return
	if prof == "" or prof == "ninguna":
		job_level = 1
		job_xp = 0
		job_xp_needed = GameConfig.xp_needed_for_job_level(2)
		return
	var p: Dictionary = profession_levels.get(prof, {})
	job_level = int(p.get("level", 1))
	job_xp = int(p.get("xp", 0))
	job_xp_needed = int(p.get("xp_needed", GameConfig.xp_needed_for_job_level(job_level + 1)))


## Progreso de JB de CUALQUIER profesión (para mostrar el estado de todas). Devuelve
## { "level", "xp", "xp_needed" }. La activa devuelve los valores en vivo. "Don Nadie"
## siempre se calcula reflejando el nivel base (ver _don_nadie_progress).
func get_profession_progress(prof: String) -> Dictionary:
	if prof == "Don Nadie":
		return _don_nadie_progress()
	if prof == profession:
		return {"level": job_level, "xp": job_xp, "xp_needed": job_xp_needed}
	var p: Dictionary = profession_levels.get(prof, {})
	var lvl: int = int(p.get("level", 1))
	return {
		"level": lvl,
		"xp": int(p.get("xp", 0)),
		"xp_needed": int(p.get("xp_needed", GameConfig.xp_needed_for_job_level(lvl + 1))),
	}


## Alias de conveniencia: solo el nivel de JB de `prof` (int), sin xp/xp_needed.
## Usado por la UI (p. ej. TabProfessions) que solo necesita mostrar el nivel.
func get_profession_level(prof: String) -> int:
	return int(get_profession_progress(prof).get("level", 1))


#endregion

#region RECÁLCULO DE ESTADÍSTICAS DERIVADAS Y EQUIPO
func get_stat_with_bonuses(stat_name: String) -> int:
	var total = stats.get(stat_name, 0)
	for slot in equipped:
		var item = equipped[slot]
		if item != null and item is EquipmentResource:
			total += item.effective_stat_bonus(stat_name)
	return total

func recalculate_derived_stats() -> void:
	var vit = get_stat_with_bonuses("vit")
	var intel = get_stat_with_bonuses("int")
	max_hp = GameConfig.HP_BASE + vit * GameConfig.HP_PER_VIT + level * GameConfig.HP_PER_LEVEL
	max_mp = GameConfig.MP_BASE + intel * GameConfig.MP_PER_INT + level * GameConfig.MP_PER_LEVEL
	hp = clampi(hp, 0, max_hp)
	mp = clampi(mp, 0, max_mp)
	xp_needed = GameConfig.xp_needed_for_char_level(level + 1)
	if profession == "Don Nadie":
		var dn := _don_nadie_progress()
		job_level = int(dn["level"])
		job_xp = int(dn["xp"])
		job_xp_needed = int(dn["xp_needed"])
	state_updated.emit()


#endregion

#region SUMA DE BONUS DE COMBATE DEL EQUIPO
## Suma un campo de combate (phys_damage, phys_defense, …) de todo el equipo puesto.
func get_equip_combat(field: String) -> int:
	var total := 0
	for slot in equipped:
		var item = equipped[slot]
		if item != null and item is EquipmentResource:
			total += item.effective_combat(field)
	return total


# ─────────────────────────────────────────────
# ESTADÍSTICAS DERIVADAS (las que usa el COMBATE y muestra la UI)
#   Las 6 características alimentan estas estadísticas finales; el equipo SUMA su
#   bonus de combate directo. El combate SOLO usa estas estadísticas, nunca los
#   puntos crudos de STR/AGI/etc.
# ─────────────────────────────────────────────
func get_phys_damage() -> int:
	var str_val = get_stat_with_bonuses("str")
	var dex_val = get_stat_with_bonuses("dex")
	var dmg := int(str_val * GameConfig.PHYS_DMG_FROM_STR + dex_val * GameConfig.PHYS_DMG_FROM_DEX + level * GameConfig.PHYS_DMG_FROM_LEVEL) + get_equip_combat("phys_damage")
	if has_food_buff("strength"):
		dmg = int(dmg * GameConfig.FOOD_BUFF_STRENGTH_MULT)
	return dmg

func get_mag_damage() -> int:
	var int_val = get_stat_with_bonuses("int")
	return int(int_val * GameConfig.MAG_DMG_FROM_INT + level * GameConfig.MAG_DMG_FROM_LEVEL) + get_equip_combat("mag_damage")

func get_range_damage() -> int:
	var dex_val = get_stat_with_bonuses("dex")
	var str_val = get_stat_with_bonuses("str")
	return int(dex_val * GameConfig.RANGE_DMG_FROM_DEX + str_val * GameConfig.RANGE_DMG_FROM_STR) + get_equip_combat("range_damage")

func get_speed() -> int:
	var agi_val = get_stat_with_bonuses("agi")
	return int(agi_val * GameConfig.SPEED_FROM_AGI)

## Defensa física: reduce el daño físico recibido en combate.
func get_phys_defense() -> int:
	var vit_val = get_stat_with_bonuses("vit")
	var str_val = get_stat_with_bonuses("str")
	var def := int(vit_val * GameConfig.PDEF_FROM_VIT + str_val * GameConfig.PDEF_FROM_STR + level * GameConfig.PDEF_FROM_LEVEL) + get_equip_combat("phys_defense")
	if has_food_buff("vigor"):
		def = int(def * GameConfig.FOOD_BUFF_VIGOR_MULT)
	return def

## Defensa mágica: reduce el daño mágico recibido en combate.
func get_mag_defense() -> int:
	var int_val = get_stat_with_bonuses("int")
	var vit_val = get_stat_with_bonuses("vit")
	return int(int_val * GameConfig.MDEF_FROM_INT + vit_val * GameConfig.MDEF_FROM_VIT + level * GameConfig.MDEF_FROM_LEVEL) + get_equip_combat("mag_defense")

## Esquiva en % (0..DODGE_MAX): probabilidad de evitar por completo un golpe.
func get_dodge() -> float:
	var agi_val = get_stat_with_bonuses("agi")
	var luk_val = get_stat_with_bonuses("luk")
	var v: float = GameConfig.DODGE_BASE + agi_val * GameConfig.DODGE_FROM_AGI + luk_val * GameConfig.DODGE_FROM_LUK
	return clampf(v, 0.0, GameConfig.DODGE_MAX)

## Crítico en % (0..CRIT_MAX): probabilidad de multiplicar el daño infligido.
func get_crit() -> float:
	var luk_val = get_stat_with_bonuses("luk")
	var dex_val = get_stat_with_bonuses("dex")
	var v: float = GameConfig.CRIT_BASE + luk_val * GameConfig.CRIT_FROM_LUK + dex_val * GameConfig.CRIT_FROM_DEX
	return clampf(v, 0.0, GameConfig.CRIT_MAX)

## Puntería en % (0..ACCURACY_MAX): probabilidad base de acertar el ataque.
func get_accuracy() -> float:
	var dex_val = get_stat_with_bonuses("dex")
	var luk_val = get_stat_with_bonuses("luk")
	var v: float = GameConfig.ACCURACY_BASE + dex_val * GameConfig.ACC_FROM_DEX + luk_val * GameConfig.ACC_FROM_LUK
	return clampf(v, 0.0, GameConfig.ACCURACY_MAX)

## Carga máxima (informativa): cuánto peso podría llevar el héroe.
func get_carry_weight() -> int:
	var str_val = get_stat_with_bonuses("str")
	return GameConfig.CARRY_BASE + str_val * GameConfig.CARRY_PER_STR



#endregion

#region GESTIÓN DE INVENTARIO
## Fachada: la lógica vive en `ItemInventoryManager` (scripts/systems). Los datos
## (`inventory`/`equipped`) permanecen en este autoload para no romper las vistas
## que los leen directamente; sólo delegamos la manipulación.

## Añade un ítem al inventario. Si ya existe, incrementa su cantidad.
## Los metadatos (nombre, categoría, icono) se resuelven en caliente desde
## `Design.get_item(id)` (items.json). Acepta parámetros opcionales legados
## (`_name`, `_category`, `_icon`) que se ignoran salvo que el ítem no exista en
## el catálogo (fallback de compatibilidad).
## Devuelve false si el inventario está lleno (ver `inventory_slot_cap()`,
## `ItemInventoryManager.add_item`) y no se pudo añadir; true en cualquier otro caso.
func add_item(id: String, quantity: int, _name: String = "", _category: String = "", _icon: String = "") -> bool:
	return inventory_mgr.add_item(id, quantity, _name, _category, _icon)


## Otorga al inventario todos los ítems existentes en el catálogo del juego (items.json y equipamiento).
## En debug/test room permite disponer de todo el repertorio para testeo inmediato.
## Si additive es true, incrementa la cantidad de ítems acumulables (materiales, consumibles) en qty.
func grant_all_game_items(qty: int = 10, additive: bool = false) -> void:
	if Design.items.is_empty():
		Design.load_all()
	for item_id: String in Design.items.keys():
		var it: Dictionary = Design.items[item_id]
		var cat: String = String(it.get("category", ""))
		var is_equip: bool = (cat == "equipment" or cat in ["weapon", "armor", "accessory", "helmet", "boots", "shield", "tool"])
		var existing: Dictionary = get_item(item_id)
		if existing.is_empty():
			add_item(item_id, 1 if is_equip else qty)
		else:
			if additive and not is_equip:
				add_item(item_id, qty)
			else:
				var current_qty: int = int(existing.get("quantity", 0))
				var target_qty: int = 1 if is_equip else qty
				if current_qty < target_qty:
					add_item(item_id, target_qty - current_qty)
	state_updated.emit()


## ¿Cuenta `id` como un hueco de inventario/cofre? Los ítems `category ==
## "important"` (misión/llave) no cuentan — pueden acumularse sin límite.
func _item_counts_toward_cap(id: String) -> bool:
	return String(Design.get_item(id).get("category", "")) != "important"

## Nº de entradas de `arr` que cuentan para su límite de huecos respectivo.
func _slot_count_of(arr: Array) -> int:
	var n := 0
	for item: Dictionary in arr:
		if _item_counts_toward_cap(String(item["id"])):
			n += 1
	return n

## Límite de huecos del inventario del JUGADOR: crece con STR (igual que
## `get_carry_weight`, ver `GameConfig.INVENTORY_SLOT_CAP_BASE/_STR_DIVISOR`).
## Solo se aplica una vez construido el Cofre de la Base — ver `has_camp_structure`.
func inventory_slot_cap() -> int:
	var str_val: float = get_stat_with_bonuses("str")
	return GameConfig.INVENTORY_SLOT_CAP_BASE + int(floor(str_val / float(GameConfig.INVENTORY_SLOT_CAP_STR_DIVISOR)))

## Nº de huecos de inventario ocupados (ver `inventory_slot_cap`).
func inventory_slot_count() -> int:
	return _slot_count_of(inventory)


#region ALMACÉN DEL COFRE DE LA BASE (persistente — ver task4.md)
## El Cofre y el inventario del jugador son DOS INVENTARIOS con la misma forma
## de entrada (id/name/quantity/category/icon/resource?); mover un ítem entre
## ambos transfiere la entrada COMPLETA (incluido su "resource" de
## EquipmentResource si es equipo con stats/rareza propios), nunca se
## reconstruye desde cero — así no se pierden bonos al guardar equipo.

## Nº de huecos ocupados en el Cofre (ver `GameConfig.CHEST_SLOT_CAP`).
func chest_slot_count() -> int:
	return _slot_count_of(chest_storage)

## Mueve la entrada COMPLETA de `id` (cantidad `quantity`) de `from` a `to`,
## fusionando cantidades si ya existe una entrada con ese id en `to`. Devuelve
## false si no hay tantas unidades en `from`.
func _transfer_item_entry(from: Array, to: Array, id: String, quantity: int) -> bool:
	for i in range(from.size()):
		if from[i]["id"] != id:
			continue
		var have: int = int(from[i]["quantity"])
		if have < quantity:
			return false
		var moved: Dictionary = from[i].duplicate()
		if quantity >= have:
			from.remove_at(i)
		else:
			from[i]["quantity"] = have - quantity
		for existing: Dictionary in to:
			if existing["id"] == id:
				existing["quantity"] = int(existing["quantity"]) + quantity
				return true
		moved["quantity"] = quantity
		to.append(moved)
		return true
	return false

## Mueve `quantity` unidades de `id` del INVENTARIO al Cofre (preserva stats de
## equipo). Falla si no hay tantas unidades, o si `id` es un tipo nuevo para el
## Cofre y este está lleno (`GameConfig.CHEST_SLOT_CAP`).
func move_item_to_chest(id: String, quantity: int) -> bool:
	if not has_item(id, quantity):
		return false
	var is_new_to_chest := true
	for item: Dictionary in chest_storage:
		if item["id"] == id:
			is_new_to_chest = false
			break
	if is_new_to_chest and _item_counts_toward_cap(id) and chest_slot_count() >= GameConfig.CHEST_SLOT_CAP:
		return false
	if not _transfer_item_entry(inventory, chest_storage, id, quantity):
		return false
	state_updated.emit()
	return true

## Mueve `quantity` unidades de `id` del Cofre AL inventario (preserva stats de
## equipo). Devuelve "" si OK, o "no_space" si no hay tantas unidades en el
## Cofre, o si `id` es un tipo nuevo para el inventario y este está lleno
## (ver `inventory_slot_cap`, solo activo con el Cofre ya construido).
func move_item_from_chest(id: String, quantity: int) -> String:
	var have := 0
	for item: Dictionary in chest_storage:
		if item["id"] == id:
			have = int(item["quantity"])
	if have < quantity:
		return "no_space"
	var is_new_to_inv := true
	for item: Dictionary in inventory:
		if item["id"] == id:
			is_new_to_inv = false
			break
	if is_new_to_inv and _item_counts_toward_cap(id) and has_camp_structure("chest") and inventory_slot_count() >= inventory_slot_cap():
		return "no_space"
	if not _transfer_item_entry(chest_storage, inventory, id, quantity):
		return "no_space"
	state_updated.emit()
	return ""

#endregion

## Elimina 'quantity' unidades de un ítem. Devuelve true si tuvo éxito.
func remove_item(id: String, quantity: int) -> bool:
	return inventory_mgr.remove_item(id, quantity)

## Devuelve true si el inventario contiene al menos 'quantity' unidades del ítem.
func has_item(id: String, quantity: int = 1) -> bool:
	return inventory_mgr.has_item(id, quantity)

## Obtiene los datos de un ítem por su id, o un diccionario vacío si no existe.
func get_item(id: String) -> Dictionary:
	return inventory_mgr.get_item(id)


#endregion

#region MÉTODOS DE EQUIPAMIENTO
## Fachada hacia `ItemInventoryManager` (ver región anterior).

## Añade un equipamiento al inventario a partir de su definición base en items.json.
## - `id`: id base del ítem (p. ej. "steel_sword").
## - `rarity`: si se indica, crea una instancia distinta ("<id>_<rarity>") con el
##   nombre prefijado por la rareza (para el botín con multiplicadores).
## - `custom_bonuses`/`custom_combat`: si se pasan, sustituyen a los de la base
##   (usados por el botín para aplicar el multiplicador de rareza).
func add_equipment_item(id: String, rarity: String = "", custom_bonuses: Dictionary = {}, custom_combat: Dictionary = {}) -> void:
	inventory_mgr.add_equipment_item(id, rarity, custom_bonuses, custom_combat)

## Equipa un ítem de equipamiento identificándolo por su EquipmentResource exacto
## (referencia), evitando cualquier ambigüedad de id/rareza/instancia. Preferido
## desde la UI cuando ya se tiene el recurso en mano (ver TabEquip.gd).
func equip_resource(resource: EquipmentResource) -> void:
	inventory_mgr.equip_resource(resource)

## Equipa un ítem de equipamiento desde el inventario.
func equip_item(item_id: String) -> void:
	inventory_mgr.equip_item(item_id)

## Desequipa el ítem de un slot y lo regresa al inventario.
func unequip_item(slot: String) -> void:
	inventory_mgr.unequip_item(slot)


#endregion

#region HABILIDADES DE FARMEO — Ganancia de XP
## Añade XP a una habilidad de farmeo/oficio (leñador, minero, pesca, agricultor, ganadero…).
## Tope en `GameConfig.MAX_SKILL_LEVEL` (10): al llegar, se queda sin XP pendiente,
## igual que `add_job_xp` hace con `MAX_JOB_LEVEL` para las profesiones de combate
## (sistema APARTE, ver docs/task_arreglosPendientes.md §0).
## Devuelve true si la habilidad subió de nivel (emite `skill_leveled_up`).
func add_skill_xp(skill_key: String, amount: int) -> bool:
	if not skills.has(skill_key):
		return false
	var s: Dictionary = skills[skill_key]
	if int(s.get("level", 1)) >= GameConfig.MAX_SKILL_LEVEL:
		s["xp"] = 0
		return false
	s["xp"] += amount
	var leveled: bool = false
	while s["xp"] >= s["xp_needed"] and int(s["level"]) < GameConfig.MAX_SKILL_LEVEL:
		s["xp"] -= s["xp_needed"]
		s["level"] += 1
		s["xp_needed"] = int(s["xp_needed"] * GameConfig.SKILL_XP_CURVE_MULTIPLIER)
		leveled = true
	if int(s["level"]) >= GameConfig.MAX_SKILL_LEVEL:
		s["level"] = GameConfig.MAX_SKILL_LEVEL
		s["xp"] = 0
	state_updated.emit()
	if leveled:
		if AudioManager != null:
			AudioManager.play_sfx("levelup")
		skill_leveled_up.emit(skill_key, int(s["level"]))
	return leveled


## Multiplicador de VELOCIDAD de recolección de un oficio concreto según su nivel
## (ver GameConfig.GATHER_SPEED_BONUS_LEVELS/_PER_LEVEL): cada nivel de la lista ya
## alcanzado suma un +10% multiplicativo. Solo afecta al oficio indicado — subir de
## nivel leñador no acelera minero, pesca, etc. Oficios sin XP/nivel (`skill_key`
## vacío o desconocido, p. ej. recursos sin oficio requerido) devuelven 1.0.
func gather_speed_multiplier(skill_key: String) -> float:
	if not skills.has(skill_key):
		return 1.0
	var lvl: int = int(skills[skill_key].get("level", 1))
	var bonus_levels_reached: int = 0
	for lv in GameConfig.GATHER_SPEED_BONUS_LEVELS:
		if lvl >= lv:
			bonus_levels_reached += 1
	return pow(1.0 + GameConfig.GATHER_SPEED_BONUS_PER_LEVEL, bonus_levels_reached)


## Unidades entregadas por recolección para un oficio concreto según su nivel,
## en escalones. Solo afecta al oficio indicado, igual que `gather_speed_multiplier`:
##   · Nivel < GATHER_LEVEL_AMOUNT_THRESHOLD (5)              → x1
##   · Nivel >= GATHER_LEVEL_AMOUNT_THRESHOLD (5)              → GATHER_LEVEL_AMOUNT_MULTIPLIER (x2)
##   · Nivel >= GATHER_LEVEL_AMOUNT_MAX_THRESHOLD (10, el tope) → GATHER_LEVEL_AMOUNT_MAX (x3, salto final)
func gather_amount_multiplier(skill_key: String) -> int:
	if not skills.has(skill_key):
		return 1
	var lvl: int = int(skills[skill_key].get("level", 1))
	if lvl >= GameConfig.GATHER_LEVEL_AMOUNT_MAX_THRESHOLD:
		return GameConfig.GATHER_LEVEL_AMOUNT_MAX
	if lvl >= GameConfig.GATHER_LEVEL_AMOUNT_THRESHOLD:
		return GameConfig.GATHER_LEVEL_AMOUNT_MULTIPLIER
	return 1


#endregion

#region RECURSOS DESCUBIERTOS / DESBLOQUEO DE LA BASE
## Marca un recurso como descubierto (al recolectarlo por primera vez).
## Desbloquea las construcciones de la base que dependan de él.
func discover_resource(resource_id: String) -> void:
	if resources_discovered.has(resource_id) and not resources_discovered[resource_id]:
		resources_discovered[resource_id] = true
		state_updated.emit()

## CÓDICE DE CURIOSIDADES (Task 2). Registra una entrada de lore como descubierta
## (POI de inspección inspeccionado, PNJ singular conocido…). Devuelve `true` solo
## si es la PRIMERA vez (para que quien la dispare pueda mostrar un aviso/toast y
## conceder recompensas de una sola vez). Idempotente: repetir no cuenta doble.
func discover_lore(codex_id: String) -> bool:
	if codex_id.strip_edges() == "" or lore_discovered.has(codex_id):
		return false
	lore_discovered[codex_id] = int(Time.get_unix_time_from_system())
	state_updated.emit()
	return true

## ¿Está descubierta una entrada del Códice? (para condiciones de diálogo y UI).
func is_lore_discovered(codex_id: String) -> bool:
	if lore_discovered.has(codex_id):
		return true
	if npc_memory.has(codex_id) and int(npc_memory[codex_id].get("visits", 0)) > 0:
		return true
	if get_relation(codex_id) > 0:
		return true
	return false

## Premio de completismo del Códice (Task 2): se concede UNA sola vez cuando el
## jugador ha descubierto TODAS las entradas (lo dispara Design._check_codex_completion,
## protegido por el world_flag `codex_complete`). El "título" cosmético *Erudito de
## lo Absurdo* se representa con ese mismo flag (lo muestra CodexViewer) y el +5% de
## XP permanente se aplica en `add_xp` mientras el flag esté activo. Aquí solo se
## entrega la bolsa de oro simbólica y se refresca la UI.
func grant_codex_completion_reward() -> void:
	gold += 500
	state_updated.emit()

## Devuelve true si una construcción está desbloqueada (recursos descubiertos).
func is_building_unlocked(key: String) -> bool:
	for b: Dictionary in GameConfig.BASE_BUILDINGS:
		if b["key"] == key:
			for res in b.get("unlock", []):
				if not resources_discovered.get(res, false):
					return false
			return true
	return false

## Devuelve true si la construcción ya está construida.
func is_building_built(key: String) -> bool:
	return int(base_levels.get(key, 0)) > 0

## Devuelve true si el jugador puede pagar el coste de una construcción.
func can_afford_building(key: String) -> bool:
	for b: Dictionary in GameConfig.BASE_BUILDINGS:
		if b["key"] == key:
			for res in b.get("costs", {}).keys():
				if not has_item(res, b["costs"][res]):
					return false
			return true
	return false

## Construye una edificación (una sola vez). Devuelve true si tuvo éxito.
func build_building(key: String) -> bool:
	if is_building_built(key) or not is_building_unlocked(key) or not can_afford_building(key):
		return false
	for b: Dictionary in GameConfig.BASE_BUILDINGS:
		if b["key"] == key:
			for res in b.get("costs", {}).keys():
				remove_item(res, b["costs"][res])
			base_levels[key] = 1
			recalculate_derived_stats()
			state_updated.emit()
			return true
	return false


## Comprueba si un ítem de venta única está agotado en la tienda indicada.
func is_shop_item_sold_out(stock_id: String, item_id: String) -> bool:
	var bought: Array = shop_purchases.get(stock_id, [])
	return item_id in bought


## Registra la compra de un ítem de venta única en una tienda.
func record_shop_purchase(stock_id: String, item_id: String) -> void:
	if not shop_purchases.has(stock_id):
		shop_purchases[stock_id] = []
	if not item_id in shop_purchases[stock_id]:
		shop_purchases[stock_id].append(item_id)
		state_updated.emit()


## Devuelve el array de EXACTAMENTE 4 posiciones de slots de combate de una
## profesión, preservando las cadenas vacías `""` en los huecos sin equipar
## (ej: `["nob_punch", "", "", ""]`). Es la fuente de verdad para cualquier UI
## que dependa de la POSICIÓN del slot (`TabProfessions`): a diferencia de
## `get_active_combat_skills()` (que compacta y se usa solo para el motor de
## combate), esta función nunca reordena ni elimina huecos, así que equipar en
## el slot 2 seguirá colocando la habilidad en el slot 2 en la siguiente lectura.
func get_combat_skill_slots(prof_id: String) -> Array[String]:
	var slots: Array[String] = []
	if active_combat_skills.has(prof_id):
		var raw: Array = active_combat_skills[prof_id]
		var has_any: bool = false
		for i in range(4):
			var sid := String(raw[i]) if i < raw.size() else ""
			if sid != "":
				has_any = true
			slots.append(sid)
		if not has_any:
			slots = _default_combat_skill_slots(prof_id)
	else:
		slots = _default_combat_skill_slots(prof_id)

	# Auto-asignación en huecos libres: si la profesión tiene habilidades aprendidas
	# por su nivel que aún no están equipadas y hay huecos vacíos (""), se asignan automáticamente.
	var sel_lvl: int = int(get_profession_progress(prof_id).get("level", 1))
	if is_test_room:
		sel_lvl = GameConfig.MAX_JOB_LEVEL
	var all_skills: Array = Design.get_profession_skills(prof_id)
	var slots_modified := false
	for s in all_skills:
		var req_lvl: int = int(s.get("level", 1))
		var sid := String(s.get("id", ""))
		if sel_lvl >= req_lvl and sid != "" and not slots.has(sid):
			for i in range(4):
				if slots[i] == "":
					slots[i] = sid
					slots_modified = true
					break

	if slots_modified or not active_combat_skills.has(prof_id):
		active_combat_skills[prof_id] = slots

	return slots


## Comprueba si alguna profesión desbloqueada tiene 5 o más habilidades aprendidas
## y tiene sus 4 ranuras de combate completamente ocupadas (desborde de habilidades).
func has_any_job_skill_overflow() -> bool:
	for prof_id in JOBS:
		var unlocked: bool = prof_id in unlocked_professions or prof_id == "Don Nadie"
		if not unlocked:
			continue
		var sel_lvl: int = int(get_profession_progress(prof_id).get("level", 1))
		if is_test_room:
			sel_lvl = GameConfig.MAX_JOB_LEVEL
		var all_skills: Array = Design.get_profession_skills(prof_id)
		var learned_count: int = 0
		for s in all_skills:
			var req_lvl: int = int(s.get("level", 1))
			var sid := String(s.get("id", ""))
			if sel_lvl >= req_lvl and sid != "":
				learned_count += 1
		if learned_count >= 5:
			var slots := get_combat_skill_slots(prof_id)
			var has_empty_slot := false
			for sid in slots:
				if sid == "":
					has_empty_slot = true
					break
			if not has_empty_slot:
				return true
	return false


## Calcula los slots por defecto (sin persistir) de una profesión: hasta 4
## habilidades ya desbloqueadas por nivel, con los huecos restantes vacíos. Los
## huecos NO se rellenan con habilidades aún no desbloqueadas (evita que, p.
## ej., Don Nadie a Nivel 1 con solo "Guantazo" aprendido aparezca con 4
## habilidades "equipadas" de golpe).
func _default_combat_skill_slots(prof_id: String) -> Array[String]:
	var all_skills: Array = Design.get_profession_skills(prof_id)
	var sel_lvl: int = int(get_profession_progress(prof_id).get("level", 1))
	if is_test_room:
		sel_lvl = GameConfig.MAX_JOB_LEVEL
	var available: Array[String] = []
	for s in all_skills:
		var req_lvl: int = int(s.get("level", 1))
		var sid := String(s.get("id", ""))
		if sel_lvl >= req_lvl and sid != "":
			available.append(sid)
	var defaults: Array[String] = []
	if is_test_room and available.size() > 4:
		# En Sala de Tests: equipar por defecto las 4 últimas habilidades aprendidas de su lista
		var start_idx: int = available.size() - 4
		for i in range(start_idx, available.size()):
			defaults.append(available[i])
	else:
		for sid in available:
			defaults.append(sid)
			if defaults.size() >= 4:
				break
	while defaults.size() < 4:
		defaults.append("")
	return defaults


## Devuelve la lista COMPACTADA (sin cadenas vacías) de habilidades de combate
## activas para una profesión — pensada exclusivamente para el motor de
## combate (`CombatTabsUI`, `TabCharacter`), al que no le importa la posición
## del slot, solo qué habilidades están activas. Para UI que deba respetar la
## posición exacta del slot, usar `get_combat_skill_slots()`.
func get_active_combat_skills(prof_id: String) -> Array[String]:
	var slots := get_combat_skill_slots(prof_id)
	var res: Array[String] = []
	for s_id in slots:
		if s_id != "":
			res.append(s_id)
	return res


## Alterna el estado activo de una habilidad de combate para una profesión (máx. 4).
func toggle_active_combat_skill(prof_id: String, skill_id: String) -> bool:
	var active := get_active_combat_skills(prof_id)
	if active.has(skill_id):
		if active.size() <= 1:
			return false
		active.erase(skill_id)
		active_combat_skills[prof_id] = active
		state_updated.emit()
		return true
	else:
		if active.size() >= 4:
			return false
		active.append(skill_id)
		active_combat_skills[prof_id] = active
		state_updated.emit()
		return true


#endregion

#region NIVELES DE CONSTRUCCIÓN — Mejoras (sumidero de oro + recursos)
## Fachada: la lógica vive en `CampStructuresManager` (scripts/systems). Los
## datos (`base_levels`) siguen viviendo aquí — ver task_arreglos.md §3.
func building_level(key: String) -> int:
	return camp_mgr.building_level(key)

func is_building_max(key: String) -> bool:
	return camp_mgr.is_building_max(key)

func building_upgrade_cost(key: String) -> Dictionary:
	return camp_mgr.building_upgrade_cost(key)

func can_afford_upgrade(key: String) -> bool:
	return camp_mgr.can_afford_upgrade(key)

func upgrade_building(key: String) -> bool:
	return camp_mgr.upgrade_building(key)

func get_dummy_idle_xp() -> int:
	return camp_mgr.get_dummy_idle_xp()


#endregion

#region REINICIO DE CARACTERÍSTICAS (sumidero de oro: devuelve los puntos gastados)
## Puntos de característica gastados respecto a los valores iniciales.
func spent_stat_points() -> int:
	var spent: int = 0
	for k in stats.keys():
		spent += int(stats[k]) - int(GameConfig.START_STATS.get(k, 0))
	return maxi(0, spent)

## ¿Se puede reiniciar (hay puntos gastados y oro suficiente)?
func can_reset_stats() -> bool:
	return spent_stat_points() > 0 and gold >= GameConfig.STAT_RESET_COST_GOLD

## Reinicia las características a su valor inicial y devuelve los puntos gastados.
## Cobra GameConfig.STAT_RESET_COST_GOLD. Devuelve true si tuvo éxito.
func reset_stats() -> bool:
	var spent: int = spent_stat_points()
	if spent <= 0 or gold < GameConfig.STAT_RESET_COST_GOLD:
		return false
	gold -= GameConfig.STAT_RESET_COST_GOLD
	stats = GameConfig.START_STATS.duplicate(true)
	stat_points += spent
	recalculate_derived_stats()
	state_updated.emit()
	return true


#endregion

#region BOTÍN, RAREZA, FORJA Y RE-FORJA
## Fachada: la lógica vive en `LootManager` (scripts/systems). Los datos
## (`gold`/`inventory`) permanecen en este autoload; sólo delegamos la lógica.

## Tira una rareza al azar según los pesos de GameConfig.rarities().
func roll_rarity() -> Dictionary:
	return loot_mgr.roll_rarity()

## Construye un equipo de botín: plantilla por nivel + rareza aleatoria.
func roll_equipment_drop(drop_level: int) -> Dictionary:
	return loot_mgr.roll_equipment_drop(drop_level)

## Procesa la tabla de botín de un enemigo (lista de entradas en línea):
## concede lo que toque y devuelve los drops.
func grant_loot(enemy_data: Dictionary) -> Array:
	return loot_mgr.grant_loot(enemy_data)

## "Roller" de botín compartido por enemigos, cofres y recompensas. Ver `LootManager`.
func grant_loot_entries(entries: Array) -> Array:
	return loot_mgr.grant_loot_entries(entries)

## ¿Se puede forjar una receta (oro + recursos)?
func can_forge(recipe: Dictionary) -> bool:
	return loot_mgr.can_forge(recipe)

## Forja un equipo (sumidero de oro + recursos). Devuelve true si tuvo éxito.
func forge(recipe_id: String) -> bool:
	return loot_mgr.forge(recipe_id)

## ¿Un ítem del inventario se puede re-forjar (deriva de una plantilla de botín)?
func is_reforgeable(item_id: String) -> bool:
	return loot_mgr.is_reforgeable(item_id)

## Re-forja un equipo del inventario: gasta oro y vuelve a tirar su rareza.
## Devuelve el resumen del nuevo drop, o {} si falla.
func reforge_item(item_id: String) -> Dictionary:
	return loot_mgr.reforge_item(item_id)

## ¿Se puede intentar REFINAR `item_id` (vía ciudad = oro / vía yunque propio =
## recursos)? Ver `RefineManager.can_refine` / task5.md.
func can_refine(item_id: String, via_city: bool) -> bool:
	return refine_mgr.can_refine(item_id, via_city)

## Intenta refinar `item_id` un nivel más. Ver `RefineManager.refine_item`.
func refine_item(item_id: String, via_city: bool) -> Dictionary:
	return refine_mgr.refine_item(item_id, via_city)


#endregion

#region ENCARGOS (TABLÓN)  — repetibles, dan dirección al bucle
## Fachada: la lógica vive en `EncargosManager` (scripts/systems). Los datos
## (`active_encargos`/`encargo_progress`/`kills_total`) permanecen en este
## autoload; sólo delegamos la lógica.

func is_encargo_active(id: String) -> bool:
	return encargos_mgr.is_encargo_active(id)

func encargo_count(id: String) -> int:
	return encargos_mgr.encargo_count(id)

func can_accept_encargo() -> bool:
	return encargos_mgr.can_accept_encargo()

func accept_encargo(id: String) -> bool:
	return encargos_mgr.accept_encargo(id)

func is_encargo_done(id: String) -> bool:
	return encargos_mgr.is_encargo_done(id)

func claim_encargo(id: String) -> bool:
	return encargos_mgr.claim_encargo(id)

## XP real que otorgará un encargo al reclamarlo (con el suelo del 20% ya
## aplicado); úsalo en la UI para mostrar el número exacto que se va a recibir.
func encargo_effective_xp(e: Dictionary) -> int:
	return encargos_mgr.encargo_effective_xp(e)

## Reporta recolección de un recurso (encargos gather).
func report_gather(res_id: String, amount: int) -> void:
	encargos_mgr.report_gather(res_id, amount)

## Reporta una victoria en combate (contador + encargos kill).
func report_kill() -> void:
	encargos_mgr.report_kill()


# ─── BESTIARIO ────────────────────────────────────────────────────────────────
## Entrada del bestiario para un enemigo (copia mutable con campos por defecto).
func _bestiary_entry(enemy_id: String) -> Dictionary:
	var e = bestiary.get(enemy_id, {})
	return {
		"seen":   bool(e.get("seen", false)) if e is Dictionary else false,
		"kills":  int(e.get("kills", 0)) if e is Dictionary else 0,
		"weak":   (e.get("weak", []) as Array).duplicate() if e is Dictionary and e.get("weak") is Array else [],
		"resist": (e.get("resist", []) as Array).duplicate() if e is Dictionary and e.get("resist") is Array else [],
	}

## Marca un enemigo como VISTO en el bestiario (al iniciar combate contra él).
func mark_enemy_seen(enemy_id: String) -> void:
	if enemy_id == "":
		return
	var entry := _bestiary_entry(enemy_id)
	if not entry["seen"]:
		entry["seen"] = true
		bestiary[enemy_id] = entry
		state_updated.emit()

## Registra una derrota del enemigo en el bestiario (contador de bajas).
func record_enemy_kill(enemy_id: String) -> void:
	if enemy_id == "":
		return
	var entry := _bestiary_entry(enemy_id)
	entry["seen"] = true
	entry["kills"] = int(entry["kills"]) + 1
	bestiary[enemy_id] = entry
	_progress_hunt_quests(enemy_id)
	state_updated.emit()

## Encargos de CAZA de NPC ("mata N enemigos del tipo X desde que aceptaste"),
## p. ej. la quest de bandidos del tabernero de Sylphrena (`data/npcs/tavern.json`).
## Progreso guardado como ENTERO en `world_flags[flag]` (vía `set_world_flag`),
## comprobado desde condiciones de diálogo data-driven con
## `hunt_progress(flag) >= n` (ver `Design.hunt_progress`). Añadir aquí una
## entrada por cada quest nueva de este tipo — no requiere tocar código de combate.
const HUNT_QUEST_TARGETS: Dictionary = {
	"hunt_bandidos_kills": {
		"enemies": ["bandido_arido", "bandido_arquero"],
		"accepted_flag": "hunt_bandidos_accepted",
		"done_flag": "hunt_bandidos_done",
		"cap": 3,
	},
	"hunt_celestia_kills": {
		"enemies": ["goblin", "golem", "aguila_imperial"],
		"accepted_flag": "fort_cleanup_accepted",
		"done_flag": "fort_cleanup_done",
		"cap": 5,
	},
}

## Avanza (si procede) los contadores de `HUNT_QUEST_TARGETS` al derrotar `enemy_id`.
func _progress_hunt_quests(enemy_id: String) -> void:
	for flag: String in HUNT_QUEST_TARGETS.keys():
		var cfg: Dictionary = HUNT_QUEST_TARGETS[flag]
		if not (enemy_id in (cfg["enemies"] as Array)):
			continue
		if not has_world_flag(String(cfg["accepted_flag"])):
			continue
		if has_world_flag(String(cfg["done_flag"])):
			continue
		var cap: int = int(cfg["cap"])
		var cur: int = int(get_world_flag_val(flag, 0))
		if cur < cap:
			set_world_flag(flag, cur + 1)

# ─── VIAJE RÁPIDO (destinos descubiertos) ─────────────────────────────────────
## Registra una ciudad como destino de viaje descubierto (al visitarla). Persiste.
func discover_travel_point(coord: Vector2i, tp_name: String, icon: String) -> void:
	var key := world_delta_key(coord)
	if travel_points.has(key):
		return
	travel_points[key] = {"name": tp_name, "icon": icon}
	state_updated.emit()

## Lista ordenada de destinos de viaje descubiertos: [{coord, name, icon}].
func get_travel_points() -> Array:
	var out: Array = []
	for key in travel_points.keys():
		var e = travel_points[key]
		if e is Dictionary:
			out.append({
				"coord": _parse_delta_key(String(key)),
				"name": String(e.get("name", "")),
				"icon": String(e.get("icon", "🏙️")),
			})
	out.sort_custom(func(a, b): return String(a["name"]) < String(b["name"]))
	return out


## Registra una relación elemental DESCUBIERTA (debilidad/resistencia) al golpear.
func discover_enemy_reaction(enemy_id: String, element: String, weak: bool, resist: bool) -> void:
	if enemy_id == "" or element == "":
		return
	var entry := _bestiary_entry(enemy_id)
	var changed := false
	if weak and not (entry["weak"] as Array).has(element):
		(entry["weak"] as Array).append(element)
		changed = true
	if resist and not (entry["resist"] as Array).has(element):
		(entry["resist"] as Array).append(element)
		changed = true
	if changed:
		entry["seen"] = true
		bestiary[enemy_id] = entry
		state_updated.emit()

## Reporta la entrada en un edificio/NPC (memoria + encargos visit).
func report_visit(npc_id: String) -> void:
	mark_npc_visited(npc_id)
	encargos_mgr.report_visit(npc_id)

## Genera un encargo paramétrico nuevo para `city_id` (idea.md §2.1).
func generate_encargo(city_id: String, target_level: int = -1) -> String:
	return encargos_mgr.generate_encargo(city_id, target_level)

## Garantiza un mínimo de encargos disponibles en el tablón de `city_id`.
func ensure_encargos_for_city(city_id: String, min_available: int = 2) -> void:
	encargos_mgr.ensure_encargos_for_city(city_id, min_available)


#endregion

#region FACETAS (consultas) Y MEMORIA DE NPCs
func _canonical_npc_id(id: String) -> String:
	match id:
		"house_yelmo_recluso", "house_001", "recluso": return "recluso"
		"house_yelmo_anciana", "house_002", "anciana": return "anciana"
		"house_snow_01", "house_003", "pescador": return "pescador"
		"poi_presa_001", "presa": return "poi_presa_001"
		_: return id

## Afinidad acumulada del héroe con un NPC (0 por defecto).
func get_relation(npc_id: String) -> int:
	var canon := _canonical_npc_id(npc_id)
	var val := int(npc_relations.get(canon, 0))
	if val == 0 and canon != npc_id:
		val = int(npc_relations.get(npc_id, 0))
	return val

## Modifica la afinidad con un NPC (puede ser negativa).
func add_relation(npc_id: String, delta: int) -> void:
	var canon := _canonical_npc_id(npc_id)
	var new_val := int(npc_relations.get(canon, 0)) + delta
	npc_relations[canon] = new_val
	if canon != npc_id:
		npc_relations[npc_id] = new_val

func get_faceta(key: String) -> int:
	var k := key.to_lower()
	match k:
		"valentia": k = "valor"
		"amabilidad": k = "bondad"
		"encanto": k = "aspecto"
		"astucia": k = "inteligencia"
	return int(facetas.get(k, 0))

## Afinidad acumulada del héroe con un NPC (0 por defecto).
func get_npc_relationship(npc_id: String) -> int:
	return get_relation(npc_id)

## Precio ajustado por carisma: aspecto/bondad altos abaratan; negativos encarecen.
## Incluye además un descuento fijo permanente (Task2, quest "La Caravana Perdida"
## en Gloriam) si el mundo tiene la bandera "gloriam_caravan_rescued": Zaid corrió
## la voz entre los mercaderes y el jugador compra más barato en TODAS las tiendas.
func charm_price(base_price: int) -> int:
	var charm: float = get_faceta("aspecto") + get_faceta("bondad") * 0.5
	var discount: float = clampf(charm * 0.02, -0.25, 0.30)
	if has_world_flag("gloriam_caravan_rescued"):
		discount = clampf(discount + 0.1, -0.25, 0.35)
	return maxi(1, int(round(base_price * (1.0 - discount))))

func npc_visit_count(npc_id: String) -> int:
	var m = npc_memory.get(npc_id, {})
	return int(m.get("visits", 0)) if m is Dictionary else 0

func mark_npc_visited(npc_id: String) -> void:
	var m: Dictionary = npc_memory.get(npc_id, {"visits": 0, "flags": {}})
	var visits: int = int(m.get("visits", 0))
	if visits == 0:
		add_relation(npc_id, 1)
	m["visits"] = visits + 1
	npc_memory[npc_id] = m

func npc_has_flag(npc_id: String, flag: String) -> bool:
	var m = npc_memory.get(npc_id, {})
	if m is Dictionary:
		var flags = m.get("flags", {})
		return flags is Dictionary and bool(flags.get(flag, false))
	return false

func set_npc_flag(npc_id: String, flag: String) -> void:
	var m: Dictionary = npc_memory.get(npc_id, {"visits": 0, "flags": {}})
	if not (m.get("flags") is Dictionary):
		m["flags"] = {}
	m["flags"][flag] = true
	npc_memory[npc_id] = m


# ─── FLAGS GLOBALES DATA-DRIVEN ─────────────────────────────────────
## Fachada: la lógica vive en `GameFlagsManager` (scripts/systems). El diccionario
## `world_flags` permanece en este autoload por la serialización y las vistas que
## lo leen directamente; sólo delegamos la manipulación.

## Consulta si un flag (global o de NPC) está activo.
func has_flag(flag: String, npc_id: String = "") -> bool:
	return flags_mgr.has_flag(flag, npc_id)

## ¿Está activo el flag global `flag`? (independiente de NPC).
func has_world_flag(flag: String) -> bool:
	return flags_mgr.has_world_flag(flag)

## Activa (o desactiva si `value` es false) un flag global de historia.
func set_world_flag(flag: String, value: Variant = true) -> void:
	flags_mgr.set_world_flag(flag, value)

## Devuelve el valor bruto de un flag global (o `default_val` si no existe).
func get_world_flag_val(flag: String, default_val: Variant = null) -> Variant:
	return flags_mgr.get_world_flag_val(flag, default_val)


## Hace aparecer el barco en la casilla de agua/orilla a la derecha del Puerto de Celestia.
func spawn_boat_at_port() -> void:
	set_world_flag("boat_obtained", true)
	var found_port := false
	for coord in hexagons_db.keys():
		var c: CellResource = hexagons_db[coord] as CellResource
		if c != null and c.event_id == "poi_celestia_puerto":
			boat_pos = Vector2i(coord.x + 1, coord.y)
			found_port = true
			break
	if not found_port:
		for coord in hexagons_db.keys():
			var c: CellResource = hexagons_db[coord] as CellResource
			if c != null and (c.event_id in ["poi_port_celestia"] or c.event_id.ends_with("_puerto") or c.item == "puerto"):
				boat_pos = Vector2i(coord.x + 1, coord.y)
				found_port = true
				break
	if not found_port:
		var def_spawn := Design.world_boat_spawn()
		boat_pos = def_spawn if def_spawn != Vector2i(-1, -1) else Vector2i(94, 24)
	state_updated.emit()


# ─── CAMBIOS FÍSICOS PERSISTENTES DEL MUNDO (deltas por casilla) ──────────────
# Capa genérica del pilar "Transformar": registra por coordenada los campos que
# una acción del jugador sobrescribe sobre la casilla base. Al reconstruir el
# mundo, WorldMapBuilder.build_into_global reaplica estos deltas (persistencia).

## Clave canónica de un delta por coordenada ("x,y").
func world_delta_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


## Registra (fusiona) un cambio persistente sobre la casilla `coord` y, si el
## mundo ya está construido, lo aplica de inmediato a su CellResource vivo.
## `changes` usa las MISMAS claves que el DSL de world_transforms
## (terrain/item/resource/name/icon/description/biome_color/event_id...).
## `merge` (por defecto) fusiona con el delta previo; si es false, lo reemplaza.
func record_world_delta(coord: Vector2i, changes: Dictionary, merge: bool = true) -> void:
	if changes == null or changes.is_empty():
		return
	var key := world_delta_key(coord)
	var entry: Dictionary = {}
	if merge and world_deltas.has(key) and world_deltas[key] is Dictionary:
		entry = (world_deltas[key] as Dictionary).duplicate(true)
	for k in changes.keys():
		entry[k] = changes[k]
	world_deltas[key] = entry
	# Aplicar en vivo si la casilla ya existe (sin esperar a reconstruir el mundo).
	var cell: CellResource = hexagons_db.get(coord, null) as CellResource
	if cell:
		WorldMapBuilder.apply_delta_to_cell(cell, entry)
	state_updated.emit()


#endregion

#region ENEMIGOS DEL MAPAMUNDI — derrota y reaparición
## ¿Está DERROTADO (aún no reaparecido) el enemigo cuyo punto de aparición es `coord`?
func is_overworld_enemy_defeated(coord: Vector2i) -> bool:
	var key := world_delta_key(coord)
	if not overworld_enemies.has(key):
		return false
	var ts: int = int(overworld_enemies[key])
	if ts == 0:
		return true   # permanente (sin respawn)
	return _now_unix() < ts


## Marca como DERROTADO el enemigo del mapamundi en `coord`. Si `respawn_secs` > 0,
## programa su reaparición; si es 0, la derrota es permanente. Persiste.
func defeat_overworld_enemy(coord: Vector2i, respawn_secs: int = 0) -> void:
	var key := world_delta_key(coord)
	overworld_enemies[key] = (_now_unix() + respawn_secs) if respawn_secs > 0 else 0
	state_updated.emit()


## Devuelve el delta persistente registrado en `coord` (copia), o {} si no hay.
func get_world_delta(coord: Vector2i) -> Dictionary:
	var key := world_delta_key(coord)
	var d = world_deltas.get(key, {})
	return (d as Dictionary).duplicate(true) if d is Dictionary else {}


## ¿Hay algún cambio persistente registrado en `coord`?
func has_world_delta(coord: Vector2i) -> bool:
	return world_deltas.has(world_delta_key(coord))


## Elimina el delta persistente de `coord` (no restaura la casilla en vivo; el
## estado base se recupera al reconstruir el mundo). Devuelve true si existía.
func clear_world_delta(coord: Vector2i) -> bool:
	var key := world_delta_key(coord)
	if world_deltas.has(key):
		world_deltas.erase(key)
		state_updated.emit()
		return true
	return false


# ─── JEFES DERROTADOS (persistencia anti-reaparición) ─────────────────────────
## Fachada hacia `GameFlagsManager` (el diccionario `defeated_bosses` sigue aquí).

## ¿Ya se derrotó al jefe identificado por `key` ("event_id:enemy_id")?
func is_boss_defeated(key: String) -> bool:
	return flags_mgr.is_boss_defeated(key)

## Marca un jefe como derrotado (no volverá a aparecer al reentrar en su mazmorra).
func mark_boss_defeated(key: String) -> void:
	flags_mgr.mark_boss_defeated(key)


# ─── COFRES DATA-DRIVEN ─────────────────────────────────────
## ¿Ya se abrió el cofre identificado por `key` ("event_id:planta:x:y")?
func is_chest_opened(key: String) -> bool:
	return bool(opened_chests.get(key, false))

## Abre un cofre: concede su contenido (oro + ítems) UNA sola vez y lo marca como
## abierto. `contents` es data-driven: { gold:int, items:[{id, qty}] }. Devuelve la
## lista de concesiones aplicadas [{kind:"gold"|"item", id, qty}] (vacía si ya
## estaba abierto o no tenía nada), para que la vista muestre el botín.
func open_chest(key: String, contents: Dictionary) -> Array:
	var granted: Array = []
	if key == "" or is_chest_opened(key):
		return granted
	opened_chests[key] = true
	var gold_amt: int = int(contents.get("gold", 0))
	if gold_amt > 0:
		gold += gold_amt
		granted.append({"kind": "gold", "qty": gold_amt})
	var items = contents.get("items", [])
	if items is Array:
		for entry in items:
			if not (entry is Dictionary):
				continue
			var id := String(entry.get("id", ""))
			var qty := int(entry.get("qty", 1))
			if id == "" or qty <= 0:
				continue
			add_item(id, qty)
			granted.append({"kind": "item", "id": id, "name": Design.get_item_name(id), "icon": Design.get_item_icon(id), "qty": qty})
	state_updated.emit()
	return granted


#endregion

#region PROGRESO OFFLINE (idle) — al volver tras cerrar la app
## Calcula y aplica el progreso acumulado mientras la app estuvo cerrada.
## Devuelve un resumen {seconds, gains:{res:qty}} (vacío si es despreciable).
func apply_offline_progress() -> Dictionary:
	# El juego DEJÓ de ser idle: al continuar partida NO se autorecolecta nada.
	# Solo actualizamos la marca de tiempo para mantener coherente el reloj de guardado.
	last_seen_ts = _now_unix()
	pending_offline_summary = {}
	return {}


#endregion

#region COCINA, CONSUMIBLES Y COMIDA
## Fachada: la lógica vive en `CookingBuffsManager` (scripts/systems). Los datos
## (`food_buffs`, `skills`, hp/mp, inventario) siguen viviendo aquí — ver
## task_arreglos.md §3.
func cook(in_id: String, in_qty: int, out_id: String) -> bool:
	return cooking_mgr.cook(in_id, in_qty, out_id)


func cook_recipe(recipe: Dictionary) -> String:
	return cooking_mgr.cook_recipe(recipe)


func use_consumable(id: String) -> bool:
	return cooking_mgr.use_consumable(id)


func food_restore_values(id: String) -> Dictionary:
	return cooking_mgr.food_restore_values(id)


func food_preview(id: String) -> Dictionary:
	return cooking_mgr.food_preview(id)


func eat_food(id: String) -> Dictionary:
	return cooking_mgr.eat_food(id)


#endregion

#region MAPA — Marcar coordenada como explorada
## Registra una coordenada como explorada (para la niebla de guerra persistente).
func mark_explored(coord: Vector2i) -> void:
	explored_coords[coord] = true


#endregion

#region NODOS DE RECOLECCIÓN FINITOS  (reserva limitada + regeneración temporal)
## Marca de tiempo unix actual (segundos), como entero.
func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())

## Clave de diccionario para un nodo a partir de su coordenada.
func _node_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

## Aplica la regeneración acumulada (por tiempo real) sobre una entrada de nodo.
func _apply_node_regen(entry: Dictionary, cap: int) -> void:
	var interval: float = GameConfig.GATHER_REGEN_INTERVAL
	if interval <= 0.0:
		return
	var now: int = _now_unix()
	var remaining: int = int(entry.get("remaining", cap))
	if remaining >= cap:
		entry["ts"] = now
		return
	var elapsed: int = now - int(entry.get("ts", now))
	if elapsed <= 0:
		return
	var regen: int = int(float(elapsed) / interval)
	if regen > 0:
		entry["remaining"] = mini(cap, remaining + regen)
		if int(entry["remaining"]) >= cap:
			entry["ts"] = now
		else:
			entry["ts"] = int(entry.get("ts", now)) + int(regen * interval)

## Capacidad del nodo en una casilla concreta (según su recurso; o la global).
func _capacity_for(coord: Vector2i) -> int:
	var cell: CellResource = hexagons_db.get(coord, null) as CellResource
	if cell and cell.resource != "":
		return GameConfig.resource_capacity(cell.resource)
	return GameConfig.GATHER_NODE_CAPACITY

## Devuelve cuántas unidades quedan en el nodo de una casilla (aplicando regen).
func get_gather_remaining(coord: Vector2i) -> int:
	var cap: int = _capacity_for(coord)
	var key: String = _node_key(coord)
	if not gather_nodes.has(key):
		gather_nodes[key] = {"remaining": cap, "ts": _now_unix()}
		return cap
	var entry: Dictionary = gather_nodes[key]
	_apply_node_regen(entry, cap)
	return int(entry.get("remaining", cap))

## Capacidad máxima del nodo de una casilla (según su recurso).
func get_gather_capacity(coord: Vector2i) -> int:
	return _capacity_for(coord)

## Coordenada de la casilla de la Base (para reaparecer tras morir).
func get_base_coord() -> Vector2i:
	if has_built_base and base_coord != Vector2i(-1, -1):
		return base_coord
	# Sin base: reaparece en el inicio DATA-DRIVEN del mapa (acotado a la rejilla).
	return Design.world_spawn(GameConfig.WORLD_START_POS)


## Monta el CAMPAMENTO en `coord`: coloca SOLO la TIENDA DE CAMPAÑA (Nivel 1). La
## HOGUERA y el resto de construcciones se levantan aparte, alrededor de la tienda
## (ver build_camp_structure). Retira el campamento anterior si existía.
func establish_base_at(coord: Vector2i) -> void:
	# 1. Limpiar la tienda anterior (si la había).
	for c_coord in hexagons_db.keys():
		var cell: CellResource = hexagons_db[c_coord] as CellResource
		if cell and cell.event_id == "base":
			_reset_camp_cell(cell)
	# 1b. Limpiar la hoguera anterior (celda viva + su delta persistente).
	if campfire_coord != Vector2i(-1, -1):
		var old_fire: CellResource = hexagons_db.get(campfire_coord, null) as CellResource
		if old_fire:
			_reset_camp_cell(old_fire)
		clear_world_delta(campfire_coord)
		campfire_coord = Vector2i(-1, -1)
	# 1c. Limpiar cualquier construcción del campamento anterior (celda + delta).
	for skey in camp_structures.keys():
		var scoord := _parse_delta_key(String(camp_structures[skey]))
		var sc: CellResource = hexagons_db.get(scoord, null) as CellResource
		if sc:
			_reset_camp_cell(sc)
		clear_world_delta(scoord)
	camp_structures = {}

	# 2. Configurar la nueva casilla como la TIENDA DE CAMPAÑA.
	var new_cell: CellResource = hexagons_db.get(coord, null) as CellResource
	if new_cell:
		new_cell.event_id = "base"
		new_cell.item = ""
		new_cell.resource = "base"
		new_cell.icon = "⛺"
		new_cell.description = Locale.pick({
			"es": "Tu base: entra para dormir y recuperarte.",
			"en": "Your base: enter to sleep and recover.",
			"fr": "Ta base : entre pour dormir et récupérer.",
			"it": "La tua base: entra per dormire e recuperare.",
			"de": "Deine Basis: geh hinein, um zu schlafen und dich zu erholen.",
			"zh": "你的营地：进入睡觉并恢复。",
			"ja": "あなたの拠点：入って眠り、回復する。"
		})
		has_built_base = true
		base_coord = coord
		camp_level = 1   # Nivel 1 = solo la tienda; la hoguera es el Nivel 2 (aparte)
		_refresh_base_label()
		new_cell.derive_legacy()
		state_updated.emit()


## Mantiene el NOMBRE visible de la casilla de la Base sincronizado con su
## nivel ("Base nv N" — ver task4.md): se llama cada vez que `camp_level`
## cambia (al montar la tienda, construir la Hoguera o cualquier construcción
## genérica). El identificador de la tienda ("Tienda de Campaña" niveles 1-2 /
## "Casita de Madera" niveles 3-4 / Casita decorada niveles 5-6) queda solo en
## el modelo 3D (ver `GenericMarkers.gd`), no en el nombre mostrado.
func _refresh_base_label() -> void:
	if not has_built_base or base_coord == Vector2i(-1, -1):
		return
	var cell: CellResource = hexagons_db.get(base_coord, null) as CellResource
	if cell == null:
		return
	var base_i18n := {"es": "Base nv %d", "en": "Base lv %d", "fr": "Base niv. %d", "it": "Base liv. %d", "de": "Basis Lv. %d", "zh": "营地 %d 级", "ja": "拠点 Lv%d"}
	cell.name_i18n = {}
	for lang in base_i18n.keys():
		cell.name_i18n[lang] = base_i18n[lang] % camp_level
	cell.name = Locale.pick(cell.name_i18n)
	cell.derive_legacy()


## Casilla donde se puede CONSTRUIR la hoguera del campamento: la que está JUSTO
## DEBAJO de la tienda (Vector2i(0, 1)). Devuelve (-1,-1) si no hay campamento, ya
## existe hoguera, o esa casilla no es válida.
func get_campfire_build_spot() -> Vector2i:
	if not has_built_base or base_coord == Vector2i(-1, -1):
		return Vector2i(-1, -1)
	if campfire_coord != Vector2i(-1, -1):
		return Vector2i(-1, -1)
	var spot := base_coord + Vector2i(0, 1)
	var cell: CellResource = hexagons_db.get(spot, null) as CellResource
	if cell == null or not cell.is_walkable_terrain() or cell.is_solid():
		return Vector2i(-1, -1)
	if cell.item != "" or cell.resource != "" or cell.event_id != "":
		return Vector2i(-1, -1)
	return spot


## Construye la HOGUERA del campamento en `spot` (la casilla a la derecha de la
## tienda), cobrando `wood_cost` de madera. Reutiliza el modelo/menú "campfire" y
## fija campfire_coord. Devuelve "" si OK, o un motivo de error.
func build_campfire_at(spot: Vector2i, wood_cost: int) -> String:
	if not has_built_base or base_coord == Vector2i(-1, -1):
		return "no_camp"
	if campfire_coord != Vector2i(-1, -1):
		return "already"
	if not has_item("wood", wood_cost):
		return "no_resources"
	var cell: CellResource = hexagons_db.get(spot, null) as CellResource
	if cell == null or not cell.is_walkable_terrain() or cell.is_solid() \
			or cell.item != "" or cell.resource != "" or cell.event_id != "":
		return "no_space"
	remove_item("wood", wood_cost)
	record_world_delta(spot, {
		"resource": "campfire", "event_id": "campfire", "item": "",
		"icon": "🔥",
		"name": {"es": "Hoguera", "en": "Campfire", "fr": "Feu de camp", "it": "Falo", "de": "Lagerfeuer", "zh": "篝火", "ja": "かがり火"},
		"description": {"es": "Una hoguera para comer y cocinar.", "en": "A campfire to eat and cook.", "fr": "Un feu de camp pour manger et cuisiner.", "it": "Un falo per mangiare e cucinare.", "de": "Ein Lagerfeuer zum Essen und Kochen.", "zh": "一处用于进食和烹饪的篝火。", "ja": "食事と料理のためのかがり火。"},
	})
	campfire_coord = spot
	camp_structures["campfire"] = world_delta_key(spot)
	camp_level += 1   # Base Nv1 (tienda) → Nv2, automático, sin coste extra.
	_refresh_base_label()
	state_updated.emit()
	return ""


## Convierte una clave de delta "x,y" en Vector2i (inverso de world_delta_key).
func _parse_delta_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() >= 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i(-9999, -9999)


## Fachada: la lógica vive en `CampStructuresManager` (scripts/systems). Los
## datos (`camp_level`/`camp_structures`) siguen viviendo aquí — ver
## task_arreglos.md §3.
func get_camp_structure_def(key: String) -> Dictionary:
	return camp_mgr.get_camp_structure_def(key)


func has_camp_structure(key: String) -> bool:
	return camp_mgr.has_camp_structure(key)


func camp_current_structure_key() -> String:
	return camp_mgr.camp_current_structure_key()


func camp_level_up_cost() -> int:
	return camp_mgr.camp_level_up_cost()


func can_level_up_camp() -> bool:
	return camp_mgr.can_level_up_camp()


func level_up_camp() -> String:
	return camp_mgr.level_up_camp()


## Levanta una construcción del campamento: valida que haya campamento, que sea la
## construcción que corresponde al nivel actual (evolución en cola, ver
## camp_current_structure_key), que no esté ya construida y que haya recursos;
## cobra el coste y coloca el objeto físico (event_id "camp_<key>") de forma
## PERSISTENTE en `coord` (la casilla elegida por el jugador; ver
## `is_valid_camp_build_spot`). Si `coord` se omite, se auto-asigna con el
## algoritmo legado `_find_free_camp_spot` (compatibilidad). Al construir con
## éxito, la Base SUBE DE NIVEL automáticamente y sin coste extra — la
## evolución de la Base ya cobra su precio en los recursos de cada
## construcción, no hace falta un segundo peaje. Devuelve "" si OK, o un
## motivo de error.
func build_camp_structure(key: String, coord: Vector2i = Vector2i(-9999, -9999)) -> String:
	if not has_built_base or base_coord == Vector2i(-1, -1):
		return "no_camp"
	if has_camp_structure(key):
		return "already"
	if key != camp_current_structure_key():
		return "locked"
	var def := get_camp_structure_def(key)
	if def.is_empty():
		return "unknown"
	# Requisito opcional (p. ej. "plano" que entrega la quest del prólogo): sin ese
	# objeto en la bolsa, la construcción aún no está disponible.
	var requires := String(def.get("requires", ""))
	if requires != "" and not has_item(requires):
		return "no_blueprint"
	var costs: Dictionary = def.get("costs", {})
	for res in costs.keys():
		if not has_item(String(res), int(costs[res])):
			return "no_resources"
	var spot := coord
	if spot == Vector2i(-9999, -9999):
		spot = _find_free_camp_spot()
	elif not is_valid_camp_build_spot(spot, key):
		spot = Vector2i(-9999, -9999)
	if spot == Vector2i(-9999, -9999):
		return "no_space"
	# Cobrar el coste.
	for res in costs.keys():
		remove_item(String(res), int(costs[res]))
	# La HOGUERA es una construcción ESPECIAL: usa resource/event_id "campfire" para
	# reutilizar su modelo 3D y su menú (comer/cocinar), y fija campfire_coord.
	if key == "campfire":
		record_world_delta(spot, {
			"resource": "campfire", "event_id": "campfire", "item": "",
			"icon": "🔥",
			"name": {"es": "Hoguera", "en": "Campfire", "fr": "Feu de camp", "it": "Falo", "de": "Lagerfeuer", "zh": "篝火", "ja": "かがり火"},
			"description": {"es": "Una hoguera para comer y cocinar.", "en": "A campfire to eat and cook.", "fr": "Un feu de camp pour manger et cuisiner.", "it": "Un falo per mangiare e cucinare.", "de": "Ein Lagerfeuer zum Essen und Kochen.", "zh": "一处用于进食和烹饪的篝火。", "ja": "食事と料理のためのかがり火。"},
		})
		campfire_coord = spot
	else:
		# Resto de construcciones: objeto físico genérico (event_id "camp_<key>").
		record_world_delta(spot, {
			"event_id": "camp_" + key,
			"item": "", "resource": "",
			"icon": String(def.get("icon", "🏕️")),
			"name": def.get("name", {"es": "Construcción", "en": "Structure", "fr": "Structure", "it": "Struttura", "de": "Bauwerk", "zh": "建筑", "ja": "施設"}),
			"description": def.get("desc", {"es": "", "en": "", "fr": "", "it": "", "de": "", "zh": "", "ja": ""}),
		})
	camp_structures[key] = world_delta_key(spot)
	camp_level += 1
	_refresh_base_label()
	state_updated.emit()
	return ""


## ¿Se puede montar la TIENDA DE CAMPAÑA (Base) en `coord`?
## ¿Se puede montar la TIENDA DE CAMPAÑA (Base) en `coord`?
## Comprueba que la casilla de la tienda y la casilla de ABAJO (donde va la hoguera)
## estén libres de POIs, casas, obstáculos, recursos bloqueantes o agua.
func can_establish_base_at(coord: Vector2i) -> bool:
	var cell: CellResource = hexagons_db.get(coord, null) as CellResource
	if cell == null or not cell.is_walkable_terrain():
		return false
	if cell.is_poi() or cell.opens_view() != "":
		return false
	if has_built_base and coord == base_coord:
		return true
	if not _is_free_camp_cell(coord):
		return false
	# Solo se exige libre la casilla de ABAJO (donde se construye la hoguera del campamento)
	var spot_down := coord + Vector2i(0, 1)
	if not _is_free_camp_cell(spot_down):
		return false
	return true


## ¿`coord` está transitable, vacía y sin ocupar (sin ítem/recurso/evento/enemigo/portal
## ni POI ni delta de mundo previo)? Chequeo base compartido por `can_establish_base_at`,
## `_find_free_camp_spot` y `is_valid_camp_build_spot`.
func _is_free_camp_cell(coord: Vector2i) -> bool:
	var cell: CellResource = hexagons_db.get(coord, null) as CellResource
	if cell == null or not cell.is_walkable_terrain() or cell.is_solid():
		return false
	if cell.is_poi() or cell.opens_view() != "":
		return false
	if cell.item != "" or cell.resource != "" or cell.event_id != "":
		return false
	if cell.required_quest_state != "" or cell.trigger_quest_state != "" or cell.trigger_event != "":
		return false
	if (cell.interactive is Dictionary and not cell.interactive.is_empty()) \
			or (cell.enemy is Dictionary and not cell.enemy.is_empty()) \
			or (cell.portal is Dictionary and not cell.portal.is_empty()) \
			or (cell.obstacle is Dictionary and not cell.obstacle.is_empty()) \
			or (cell.gate is Dictionary and not cell.gate.is_empty()):
		return false
	if cell.is_interactive() or cell.is_growing_crop():
		return false
	if has_world_delta(coord):
		return false
	return true


## Encuentra una casilla transitable, vacía y sin ocupar cerca de la tienda para
## colocar una nueva construcción. Busca en anillos crecientes (radio 1..3).
## LEGADO: ya no la usan Muñeco/Cofre/Tablón/Herrería (el jugador elige su
## propia casilla, ver `is_valid_camp_build_spot`); se conserva por si algún
## flujo antiguo (partidas guardadas, debug) sigue llamando a `build_camp_structure`
## sin coordenada explícita.
func _find_free_camp_spot() -> Vector2i:
	for radius in range(1, 4):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var nc := base_coord + Vector2i(dx, dy)
				if nc == base_coord or nc == campfire_coord:
					continue
				if _is_free_camp_cell(nc):
					return nc
	return Vector2i(-9999, -9999)


## Modo de colocación de cada construcción del campamento (aparte de la
## Hoguera, que usa su propio flujo fijo junto a la tienda — ver
## `get_campfire_build_spot`): "adjacent" = una de las 8 casillas alrededor de
## la tienda (Muñeco/Cofre); "territory" = cualquier casilla libre dentro del
## territorio actual de la Base (Tablón/Herrería, ver `base_territory_size`).
const CAMP_STRUCTURE_PLACEMENT: Dictionary = {
	"dummy": "adjacent", "chest": "adjacent",
	"board": "territory", "forge": "territory",
}

## Lado (en casillas) del territorio cuadrado de la Base según su nivel: Nv1
## (solo la tienda) = 1×1; Nv2-3 (Hoguera/Muñeco) = 3×3; Nv4+ (Cofre en
## adelante) = 4×4. 0 si no hay Base montada.
func base_territory_size() -> int:
	if not has_built_base:
		return 0
	if camp_level <= 1:
		return 1
	elif camp_level <= 3:
		return 3
	return 4


## ¿`coord` cae dentro del territorio cuadrado (lado `base_territory_size`)
## centrado en la tienda? Para lados pares el cuadrado se sesga hacia +x/+y
## (mismo lado al que ya se sesga la Hoguera junto a la tienda).
func is_within_base_territory(coord: Vector2i) -> bool:
	var size := base_territory_size()
	if size <= 0:
		return false
	var lo: int = -int(float(size - 1) / 2.0)
	var hi := size - 1 + lo
	var dx := coord.x - base_coord.x
	var dy := coord.y - base_coord.y
	return dx >= lo and dx <= hi and dy >= lo and dy <= hi


## Construcción (aparte de la Hoguera, que usa su propio flujo fijo) que se
## puede levantar AHORA MISMO en `coord`: la que le toca turno
## (`camp_current_structure_key`) si esa casilla cumple su modo de colocación.
## "" si no hay ninguna construible ahí. La usa `TabWorld3D._on_enter_pressed`
## para ofrecer el diálogo de construcción cuando el jugador pisa una casilla válida.
func get_buildable_structure_at(coord: Vector2i) -> String:
	var key := camp_current_structure_key()
	if key == "" or key == "campfire":
		return ""
	if is_valid_camp_build_spot(coord, key):
		return key
	return ""


## ¿Puede el jugador levantar la construcción `key` en `coord`? Comprueba que
## hay Base, que la casilla está libre (ver `_is_free_camp_cell`) y que respeta
## el modo de colocación de esa construcción (adyacente a la tienda o dentro
## del territorio actual — ver `CAMP_STRUCTURE_PLACEMENT`).
func is_valid_camp_build_spot(coord: Vector2i, key: String) -> bool:
	if not has_built_base or base_coord == Vector2i(-1, -1):
		return false
	if coord == base_coord or coord == campfire_coord:
		return false
	if not _is_free_camp_cell(coord):
		return false
	var mode := String(CAMP_STRUCTURE_PLACEMENT.get(key, "adjacent"))
	if mode == "territory":
		return is_within_base_territory(coord)
	# "adjacent": una de las 8 casillas cartesianas alrededor de la tienda.
	return absi(coord.x - base_coord.x) <= 1 and absi(coord.y - base_coord.y) <= 1


## Devuelve una casilla del campamento (tienda/hoguera) a "campo abierto" transitable.
func _reset_camp_cell(cell: CellResource) -> void:
	cell.event_id = ""
	cell.item = ""
	cell.resource = ""
	cell.name = "Casilla de Campo"
	cell.description = "Un área transitable en el mapamundi."
	match cell.terrain:
		"grs": cell.icon = "🍀"
		"bad": cell.icon = "🏜️"
		"gnd": cell.icon = "🟫"
		"des": cell.icon = "🏜️"
		"ice": cell.icon = "❄️"
		_:     cell.icon = ""
	cell.derive_legacy()

## Intenta consumir 'amount' del nodo de una casilla. Devuelve lo realmente extraído.
func consume_gather(coord: Vector2i, amount: int) -> int:
	var cap: int = _capacity_for(coord)
	var key: String = _node_key(coord)
	var entry: Dictionary
	if gather_nodes.has(key):
		entry = gather_nodes[key]
		_apply_node_regen(entry, cap)
	else:
		entry = {"remaining": cap, "ts": _now_unix()}
		gather_nodes[key] = entry
	var remaining: int = int(entry.get("remaining", cap))
	var taken: int = mini(amount, remaining)
	if taken > 0:
		if remaining >= cap:
			entry["ts"] = _now_unix()  # empieza a contar la regen desde ahora
		entry["remaining"] = remaining - taken
	return taken


#endregion

#region SERIALIZACIÓN (GUARDADO / CARGA)

## Serializa todo el estado del juego a un Diccionario apto para JSON.
func to_dict() -> Dictionary:
	return {
		"version":        SAVE_VERSION,
		"gold":           gold,
		"level":          level,
		"xp":             xp,
		"xp_needed":      xp_needed,
		"hp":             hp,
		"max_hp":         max_hp,
		"mp":             mp,
		"max_mp":         max_mp,
		"stats":          stats.duplicate(true),
		"stat_points":    stat_points,
		"facetas":        facetas.duplicate(true),
		"skills":         skills.duplicate(true),
		"equipped":       _serialize_equipped(),
		"base_levels":    base_levels.duplicate(true),
		"resources_discovered": resources_discovered.duplicate(true),
		"bestiary":       bestiary.duplicate(true),
		"encyclopedia_unlocked": encyclopedia_unlocked.duplicate(true),
		"lore_discovered": lore_discovered.duplicate(true),
		"inventory":      _serialize_inventory(),
		"chest_storage":  _serialize_inventory_array(chest_storage),
		"quest_state":    quest_state,
		"quests":         quests.duplicate(true),
		"seen_intro":     seen_intro,
		"dam_opened":     dam_opened,
		"cave_cleared":   cave_cleared,
		"world_flags":    world_flags.duplicate(true),
		"world_deltas":   world_deltas.duplicate(true),
		"opened_chests":  opened_chests.duplicate(true),
		"defeated_bosses": defeated_bosses.duplicate(true),
		"overworld_enemies": overworld_enemies.duplicate(true),
		"debug_mode":     debug_mode,
		"is_test_room":   is_test_room,
		"has_built_base": has_built_base,
		"base_coord":     [base_coord.x, base_coord.y],
		"campfire_coord": [campfire_coord.x, campfire_coord.y],
		"camp_level":     camp_level,
		"camp_structures": camp_structures.duplicate(true),
		"profession":     profession,
		"unlocked_professions": unlocked_professions.duplicate(true),
		"job_level": job_level,
		"job_xp": job_xp,
		"job_xp_needed": job_xp_needed,
		"profession_levels": profession_levels.duplicate(true),
		"unlocked_skills": unlocked_skills.duplicate(),
		"active_combat_skills": active_combat_skills.duplicate(true),
		"player_pos":     [player_pos.x, player_pos.y],
		"boat_pos":       [boat_pos.x, boat_pos.y],
		"is_sailing":     is_sailing,
		"world_hour":     world_hour,
		"explored_coords": _serialize_explored(),
		"travel_points":  travel_points.duplicate(true),
		"gather_nodes":   gather_nodes.duplicate(true),
		"food_buffs":     food_buffs.duplicate(true),
		"active_encargos": active_encargos.duplicate(true),
		"encargo_progress": encargo_progress.duplicate(true),
		"kills_total":    kills_total,
		"achievements_unlocked": achievements_unlocked.duplicate(true),
		"tutorials_progress":    tutorials_progress.duplicate(true),
		"npc_memory":     npc_memory.duplicate(true),
		"npc_relations":  npc_relations.duplicate(true),
		"shop_purchases": shop_purchases.duplicate(true),
		"last_seen_ts":   _now_unix(),
	}


## Despachador de migraciones de guardado (task_arreglos.md §5.1). Compara la
## `"version"` embebida en el guardado con `SAVE_VERSION` y aplica, EN ORDEN,
## las migraciones necesarias mutando `data` in-place antes de que `from_dict`
## lea sus claves. Partidas sin `"version"` se asumen v1 (formato anterior a
## esta infraestructura). Añadir aquí un `if save_ver < N:` + función
## `_migrate_save_vX_to_vY(data)` cada vez que se suba `SAVE_VERSION`.
func _run_save_migrations(data: Dictionary) -> void:
	var save_ver: int = int(data.get("version", 1))
	if save_ver >= SAVE_VERSION:
		return
	# (Sin migraciones registradas todavía — SAVE_VERSION sigue en 1. Ejemplo
	# de cómo se encadenaría la siguiente cuando haga falta:
	#   if save_ver < 2:
	#       _migrate_save_v1_to_v2(data)
	#       save_ver = 2
	# )


## Reconstruye el estado del juego desde un Diccionario (cargado de disco).
func from_dict(data: Dictionary) -> void:
	_run_save_migrations(data)
	gold        = int(data.get("gold", gold))
	level       = int(data.get("level", level))
	xp          = int(data.get("xp", xp))
	xp_needed   = int(data.get("xp_needed", xp_needed))
	hp          = int(data.get("hp", hp))
	max_hp      = int(data.get("max_hp", max_hp))
	mp          = int(data.get("mp", mp))
	max_mp      = int(data.get("max_mp", max_mp))
	stat_points = int(data.get("stat_points", stat_points))
	quest_state = String(data.get("quest_state", quest_state))
	quests.clear()
	var qs_data = data.get("quests", {})
	if qs_data is Dictionary:
		for k in qs_data.keys():
			var qv = qs_data[k]
			if qv is Dictionary:
				quests[String(k)] = qv.duplicate(true)
	seen_intro   = bool(data.get("seen_intro", seen_intro))
	dam_opened   = bool(data.get("dam_opened", dam_opened))
	cave_cleared = bool(data.get("cave_cleared", cave_cleared))
	var wf = data.get("world_flags", {})
	world_flags = wf.duplicate(true) if wf is Dictionary else {}
	var wd = data.get("world_deltas", {})
	world_deltas = wd.duplicate(true) if wd is Dictionary else {}
	var oc = data.get("opened_chests", {})
	opened_chests = oc.duplicate(true) if oc is Dictionary else {}
	var db = data.get("defeated_bosses", {})
	defeated_bosses = db.duplicate(true) if db is Dictionary else {}
	var owe = data.get("overworld_enemies", {})
	overworld_enemies = owe.duplicate(true) if owe is Dictionary else {}
	debug_mode   = bool(data.get("debug_mode", debug_mode))
	is_test_room = bool(data.get("is_test_room", is_test_room))
	# Sincronizar Design con el tipo de mapa del guardado EN AMBOS SENTIDOS: la Sala
	# de Tests usa el mapamundi reducido y una partida normal el real. Si el flag de
	# Design no coincide (p. ej. se jugó a la Sala de Tests y luego se pulsa
	# Continuar sobre un guardado normal), recargamos el mapa correcto y limpiamos
	# el caché hexagons_db para que TabWorld3D lo reconstruya desde Design.world.
	if Design.is_test_room != is_test_room:
		Design.is_test_room = is_test_room
		Design.reload()
		hexagons_db.clear()
	has_built_base = bool(data.get("has_built_base", has_built_base))
	var bc = data.get("base_coord", [-1, -1])
	if bc is Array and bc.size() >= 2:
		base_coord = Vector2i(int(bc[0]), int(bc[1]))
	var fc = data.get("campfire_coord", [-1, -1])
	if fc is Array and fc.size() >= 2:
		campfire_coord = Vector2i(int(fc[0]), int(fc[1]))
	# camp_level: si falta (partidas antiguas) se infiere de has_built_base.
	camp_level = int(data.get("camp_level", 1 if has_built_base else 0))
	var cs = data.get("camp_structures", {})
	camp_structures = cs.duplicate(true) if cs is Dictionary else {}
	# Nomenclatura de profesiones actualizada: migramos claves antiguas.
	profession  = SaveSerializer.migrate_profession(String(data.get("profession", profession)))
	if profession == "ninguna" or profession == "":
		profession = "Don Nadie"
	unlocked_professions.clear()
	for p in data.get("unlocked_professions", ["Don Nadie"]):
		var prof_name := SaveSerializer.migrate_profession(String(p))
		if prof_name == "ninguna" or prof_name == "":
			prof_name = "Don Nadie"
		if not unlocked_professions.has(prof_name):
			unlocked_professions.append(prof_name)
	job_level   = int(data.get("job_level", 1))
	job_xp      = int(data.get("job_xp", 0))
	job_xp_needed = int(data.get("job_xp_needed", 100))
	# Progreso por profesión (JB no compartido).
	var pl = data.get("profession_levels", {})
	profession_levels = pl.duplicate(true) if pl is Dictionary else {}
	if not profession_levels.has("Don Nadie"):
		if profession == "Don Nadie":
			profession_levels["Don Nadie"] = {"level": job_level, "xp": job_xp, "xp_needed": job_xp_needed}
		else:
			profession_levels["Don Nadie"] = {"level": 1, "xp": 0, "xp_needed": GameConfig.xp_needed_for_job_level(2)}
	if profession != "" and profession != "ninguna" and not profession_levels.has(profession):
		profession_levels[profession] = {
			"level": job_level, "xp": job_xp, "xp_needed": job_xp_needed
		}

	# Habilidades de exploración desbloqueadas (persistente).
	unlocked_skills.clear()
	for sk_id in data.get("unlocked_skills", []):
		var skill_id := String(sk_id)
		if skill_id != "" and not unlocked_skills.has(skill_id):
			unlocked_skills.append(skill_id)
	max_energy = GameConfig.MAX_ENERGY
	energy = float(max_energy)
	var acs = data.get("active_combat_skills", {})
	active_combat_skills = acs.duplicate(true) if acs is Dictionary else {}

	stats   = SaveSerializer.merge_int_dict(stats, data.get("stats", {}))
	facetas = SaveSerializer.merge_int_dict(facetas, data.get("facetas", {}))

	# Skills es un diccionario de diccionarios { level, xp, xp_needed }
	var sk: Dictionary = data.get("skills", {})
	for key: String in skills.keys():
		if sk.has(key):
			skills[key]["level"]     = int(sk[key].get("level", skills[key]["level"]))
			skills[key]["xp"]        = int(sk[key].get("xp", skills[key]["xp"]))
			skills[key]["xp_needed"] = int(sk[key].get("xp_needed", skills[key]["xp_needed"]))

	# Niveles de base
	var bl: Dictionary = data.get("base_levels", {})
	for key: String in base_levels.keys():
		base_levels[key] = int(bl.get(key, base_levels[key]))

	# Recursos descubiertos
	var rd: Dictionary = data.get("resources_discovered", {})
	for key: String in resources_discovered.keys():
		resources_discovered[key] = bool(rd.get(key, resources_discovered[key]))

	# Bestiario (conocimiento de enemigos descubierto)
	var bs = data.get("bestiary", {})
	bestiary = bs.duplicate(true) if bs is Dictionary else {}

	# Enciclopedia (ítems descubiertos alguna vez)
	var eu = data.get("encyclopedia_unlocked", {})
	encyclopedia_unlocked = eu.duplicate(true) if eu is Dictionary else {}

	# Códice de Curiosidades (lore ambiental descubierto — Task 2)
	var ld = data.get("lore_discovered", {})
	lore_discovered = ld.duplicate(true) if ld is Dictionary else {}

	# Compras únicas en tiendas (persistente)
	var sp = data.get("shop_purchases", {})
	shop_purchases = sp.duplicate(true) if sp is Dictionary else {}

	# Inventario
	inventory.clear()
	for entry in data.get("inventory", []):
		inventory.append(SaveSerializer.deserialize_item(entry))

	# Almacén del Cofre de la Base (persistente — ver task4.md).
	chest_storage.clear()
	for entry in data.get("chest_storage", []):
		chest_storage.append(SaveSerializer.deserialize_item(entry))

	# Equipo
	for slot: String in equipped.keys():
		equipped[slot] = null
	var eq: Dictionary = data.get("equipped", {})
	for slot: String in eq.keys():
		if eq[slot] != null and equipped.has(slot):
			var loaded_eq: EquipmentResource = SaveSerializer.dict_to_equipment(eq[slot])
			# Defensa ante guardados corruptos/editados a mano: solo aceptar el
			# ítem en esta ranura si su propio `slot` (definido por su tipo,
			# p. ej. armadura/escudo/casco) coincide con la clave bajo la que
			# se guardó. Evita que un escudo pueda acabar equipado como
			# armadura si el JSON de guardado tuviera las claves cambiadas.
			if loaded_eq != null and loaded_eq.slot == slot:
				equipped[slot] = loaded_eq
			elif loaded_eq != null:
				push_warning("[GlobalState] Ignorado equipo '%s' guardado en ranura '%s' (su slot real es '%s')." % [loaded_eq.name, slot, loaded_eq.slot])

	# Mapamundi
	var pp = data.get("player_pos", [1, 1])
	if pp is Array and pp.size() >= 2:
		player_pos = Vector2i(int(pp[0]), int(pp[1]))
	# `boat_pos` puede faltar en partidas guardadas ANTES de esta funcionalidad:
	# en ese caso se recae en el `boat_spawn` del mapa activo (así el barco
	# también aparece en partidas ya existentes).
	var bp = data.get("boat_pos", null)
	if bp is Array and bp.size() >= 2:
		boat_pos = Vector2i(int(bp[0]), int(bp[1]))
	else:
		boat_pos = Design.world_boat_spawn()
	is_sailing = bool(data.get("is_sailing", false))
	world_hour = clampf(float(data.get("world_hour", world_hour)), 0.0, 24.0)
	explored_coords.clear()
	for c in data.get("explored_coords", []):
		_deserialize_explored_entry(c)

	# Destinos de viaje rápido descubiertos
	var tps = data.get("travel_points", {})
	travel_points = tps.duplicate(true) if tps is Dictionary else {}

	# Nodos de recolección finitos
	gather_nodes.clear()
	var gn = data.get("gather_nodes", {})
	if gn is Dictionary:
		for k in gn.keys():
			var e = gn[k]
			if e is Dictionary:
				gather_nodes[String(k)] = {
					"remaining": int(e.get("remaining", GameConfig.GATHER_NODE_CAPACITY)),
					"ts": int(e.get("ts", 0)),
				}

	var fb = data.get("food_buffs", {})
	food_buffs = fb.duplicate(true) if fb is Dictionary else {}
	food_buffs.erase("starting_shield")

	# Encargos, contadores y memoria de NPCs
	active_encargos.clear()
	var ae = data.get("active_encargos", {})
	if ae is Dictionary:
		for k in ae.keys():
			active_encargos[String(k)] = bool(ae[k])
	encargo_progress.clear()
	var ep = data.get("encargo_progress", {})
	if ep is Dictionary:
		for k in ep.keys():
			encargo_progress[String(k)] = int(ep[k])
	kills_total = int(data.get("kills_total", 0))
	achievements_unlocked.clear()
	var au = data.get("achievements_unlocked", {})
	if au is Dictionary:
		for k in au.keys():
			achievements_unlocked[String(k)] = bool(au[k])
	tutorials_progress.clear()
	var tp = data.get("tutorials_progress", {})
	if tp is Dictionary:
		for k in tp.keys():
			tutorials_progress[String(k)] = int(tp[k])
	npc_memory.clear()
	var nm = data.get("npc_memory", {})
	if nm is Dictionary:
		for k in nm.keys():
			var entry = nm[k]
			if entry is Dictionary:
				var flags: Dictionary = {}
				var f = entry.get("flags", {})
				if f is Dictionary:
					for fk in f.keys():
						flags[String(fk)] = bool(f[fk])
				npc_memory[String(k)] = {"visits": int(entry.get("visits", 0)), "flags": flags}
	npc_relations.clear()
	var nr = data.get("npc_relations", {})
	if nr is Dictionary:
		for k in nr.keys():
			npc_relations[String(k)] = int(nr[k])
	last_seen_ts = int(data.get("last_seen_ts", _now_unix()))

	recalculate_derived_stats()
	state_updated.emit()


## Comprime `explored_coords` por FILA en tramos contiguos de X (task_arreglos.md
## §5.2): en vez de un `[x, y]` por casilla explorada, cada tramo continuo de
## una fila se guarda como `[y, x_start, x_end]` (ambos inclusive). La
## exploración real (caminar) produce sobre todo tramos largos, así que con
## mapas grandes esto reduce el tamaño del guardado en 1-2 órdenes de magnitud
## frente al array plano de puntos sueltos. Ver `_deserialize_explored_entry`
## para el lado de lectura (tolerante también al formato antiguo).
func _serialize_explored() -> Array:
	var by_row: Dictionary = {}   # y (int) -> Array[int] de xs sin ordenar
	for coord: Vector2i in explored_coords.keys():
		if not by_row.has(coord.y):
			by_row[coord.y] = []
		by_row[coord.y].append(coord.x)

	var arr: Array = []
	for y: int in by_row.keys():
		var xs: Array = by_row[y]
		xs.sort()
		var range_start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size()):
			var x: int = xs[i]
			if x != prev + 1:
				arr.append([y, range_start, prev])
				range_start = x
			prev = x
		arr.append([y, range_start, prev])
	return arr

## Lee UNA entrada de `explored_coords` guardada, tolerando AMBOS formatos:
## `[x, y]` (formato antiguo, un punto por celda, partidas previas a
## task_arreglos.md §5.2) y `[y, x_start, x_end]` (tramo comprimido por fila,
## formato actual de `_serialize_explored`). Se distinguen por tamaño del
## array, sin necesidad de migración de versión de guardado.
func _deserialize_explored_entry(c) -> void:
	if not (c is Array):
		return
	if c.size() == 2:
		explored_coords[Vector2i(int(c[0]), int(c[1]))] = true
	elif c.size() >= 3:
		var y: int = int(c[0])
		var x_start: int = int(c[1])
		var x_end: int = int(c[2])
		for x in range(x_start, x_end + 1):
			explored_coords[Vector2i(x, y)] = true


func _serialize_equipped() -> Dictionary:
	var out: Dictionary = {}
	for slot: String in equipped.keys():
		var res = equipped[slot]
		if res is EquipmentResource:
			out[slot] = SaveSerializer.equipment_to_dict(res)
		else:
			out[slot] = null
	return out

## Serializa el inventario de forma COMPACTA: para ítems comunes basta con
## {id, quantity} (nombre/categoría/icono se resuelven desde items.json al cargar).
## El equipamiento (con posibles stats/rareza modificados) sí guarda su recurso.
func _serialize_inventory() -> Array:
	return _serialize_inventory_array(inventory)

## Igual que `_serialize_inventory`, pero para cualquier array con la misma
## forma (reutilizado por `chest_storage`, el almacén del Cofre de la Base).
func _serialize_inventory_array(items: Array) -> Array:
	var out: Array = []
	for item: Dictionary in items:
		if item.get("resource") is EquipmentResource:
			out.append({
				"id":       item.get("id", ""),
				"quantity": item.get("quantity", 1),
				"resource": SaveSerializer.equipment_to_dict(item["resource"]),
			})
		else:
			# Ítem común: solo id + cantidad (metadatos en caliente desde items.json).
			out.append({
				"id":       item.get("id", ""),
				"quantity": item.get("quantity", 1),
			})
	return out


func get_surrounding_hex_coords(coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	neighbors.append(Vector2i(coord.x + 1, coord.y))
	neighbors.append(Vector2i(coord.x - 1, coord.y))
	if coord.y % 2 == 0:
		neighbors.append(Vector2i(coord.x, coord.y - 1))
		neighbors.append(Vector2i(coord.x, coord.y + 1))
		neighbors.append(Vector2i(coord.x - 1, coord.y - 1))
		neighbors.append(Vector2i(coord.x - 1, coord.y + 1))
	else:
		neighbors.append(Vector2i(coord.x, coord.y - 1))
		neighbors.append(Vector2i(coord.x, coord.y + 1))
		neighbors.append(Vector2i(coord.x + 1, coord.y - 1))
		neighbors.append(Vector2i(coord.x + 1, coord.y + 1))
	return neighbors

#endregion

## Devuelve true si el jugador ha desbloqueado las 6 profesiones de los senderos.
func has_all_professions_unlocked() -> bool:
	var required := ["Guerrero", "Arquero", "Elementalista", "Sacerdote", "Psíquico", "Tiempo"]
	for req in required:
		var req_migrated := SaveSerializer.migrate_profession(req)
		var found := false
		for up in unlocked_professions:
			if SaveSerializer.migrate_profession(up) == req_migrated:
				found = true
				break
		if not found:
			return false
	return true
