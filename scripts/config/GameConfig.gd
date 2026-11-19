class_name GameConfig
extends RefCounted
## ════════════════════════════════════════════════════════════════════════════
## GameConfig — CONFIGURACIÓN CENTRAL DEL JUEGO  (☑ EDITA AQUÍ LOS PARÁMETROS)
## ════════════════════════════════════════════════════════════════════════════
## Punto ÚNICO para ajustar todos los parámetros base del juego: valores
## iniciales, fórmulas, costes, tamaños de rejilla, recompensas, etc.
##
## Cambia un valor aquí y se reflejará en todo el proyecto — no hace falta buscar
## fichero por fichero.
##
## Se usa como `GameConfig.NOMBRE` desde cualquier script (clase global, no se
## instancia). Ejemplo:  GameConfig.START_GOLD
## ════════════════════════════════════════════════════════════════════════════


# ═════════════════════════════════════════════════════════════════════════════
# CARGA DATA-DRIVEN DE PARÁMETROS  (data/config.json)  — con FALLBACK a defaults
# ─────────────────────────────────────────────────────────────────────────────
# Los PARÁMETROS DE BALANCE (números escalares) se leen de `data/config.json` si
# existe; si falta la clave (o el fichero), se usa el valor por defecto cableado
# aquí. Así el diseño se ajusta desde el backoffice SIN tocar código, y el juego
# sigue funcionando idéntico aunque no haya config.json. Los datos ESTRUCTURALES
# complejos (colores, rutas, tablas anidadas: STATUS_EFFECTS, BLOCK_PROFILE, RARITIES…)
# siguen en código por seguridad. `GameConfig.X` no cambia para los consumidores.
# ═════════════════════════════════════════════════════════════════════════════
static var _cfg: Dictionary = _load_cfg()

## Carga data/config.json una sola vez (o {} si no existe / es inválido).
static func _load_cfg() -> Dictionary:
	var path := "res://data/config.json"
	if FileAccess.file_exists(path):
		var txt := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary:
			return parsed
	return {}

## Lectores tipados con valor por defecto (fallback).
static func _cf(key: String, def: float) -> float: return float(_cfg.get(key, def))
static func _ci(key: String, def: int) -> int:     return int(_cfg.get(key, def))
static func _cb(key: String, def: bool) -> bool:   return bool(_cfg.get(key, def))
static func _cs(key: String, def: String) -> String: return String(_cfg.get(key, def))
static func _cd(key: String, def: Dictionary) -> Dictionary:
	var v: Variant = _cfg.get(key, def)
	return v if v is Dictionary else def


# ─────────────────────────────────────────────────────────────────────────────
# HÉROE — VALORES INICIALES (al empezar una partida nueva)
# ─────────────────────────────────────────────────────────────────────────────
static var START_GOLD: int          = _ci("START_GOLD", 0)
static var START_LEVEL: int         = _ci("START_LEVEL", 1)
static var START_XP: int            = _ci("START_XP", 0)
static var START_XP_NEEDED: int     = _ci("START_XP_NEEDED", 10)   # = xp_needed_for_char_level(2), ver curva de XP más abajo
static var START_STAT_POINTS: int   = _ci("START_STAT_POINTS", 0)
static var START_PROFESSION: String = _cs("START_PROFESSION", "Don Nadie")   # "Mago" | "Guerrero" | "Arquero" | "Don Nadie"

# ─── MODO DEBUG (arranque de pruebas desde el menú) ──────────────────────────
# Una partida "debug" empieza con héroe de alto nivel, puntos por repartir, oro,
# equipamiento en la bolsa y movimiento acelerado, para testear el contenido rápido.
static var DEBUG_GOLD: int         = _ci("DEBUG_GOLD", 999999)
static var DEBUG_LEVEL: int        = _ci("DEBUG_LEVEL", 50)   # = MAX_CHAR_LEVEL
static var DEBUG_STAT_POINTS: int  = _ci("DEBUG_STAT_POINTS", 50)
static var DEBUG_MOVE_MULTIPLIER: float = _cf("DEBUG_MOVE_MULTIPLIER", 3.0)   # x3 velocidad de movimiento en el mundo
const DEBUG_START_POS: Vector2i = Vector2i(20, 8)   # Junto a la Ciudad Imperial (pradera)

## Las 6 características base del personaje.
static var START_STATS: Dictionary = _cd("START_STATS", {
	"str": 5, "agi": 5, "vit": 5,
	"int": 5, "dex": 5, "luk": 5,
})

## Facetas de personalidad (rango -10 a +10).
static var START_FACETAS: Dictionary = _cd("START_FACETAS", {
	"valor": 0, "bondad": 0, "aspecto": 0, "inteligencia": 0, "cordura": 0,
})


# ─────────────────────────────────────────────────────────────────────────────
# PROGRESIÓN DE NIVEL (task3_rebalanceo_global_limpieza_y_optimizacion.md, FASE1)
# ─────────────────────────────────────────────────────────────────────────────
static var STAT_POINTS_PER_LEVEL: int = _ci("STAT_POINTS_PER_LEVEL", 1)
static var MAX_CHAR_LEVEL: int = _ci("MAX_CHAR_LEVEL", 50)
static var MAX_JOB_LEVEL: int = _ci("MAX_JOB_LEVEL", 30)
## Tope de nivel de los OFICIOS DE FARMEO (leñador/minero/pesca/agricultor/
## ganadero, `GlobalState.skills`). Sistema TOTALMENTE APARTE de `MAX_JOB_LEVEL`
## (que es el nivel de las profesiones de COMBATE: Mago, Guerrero, Arquero…),
## ver `docs/task_arreglosPendientes.md` §0. Antes el farmeo no tenía tope.
static var MAX_SKILL_LEVEL: int = _ci("MAX_SKILL_LEVEL", 10)

## Curva de XP calibrada: Nivel 1->2 pide 10 XP, Nivel 2->3 pide 20 XP.
static func xp_needed_for_char_level(level: int) -> int:
	var l := maxi(1, level - 1)
	if l == 1:
		return 10
	if l == 2:
		return 20
	return int(10.0 * float(l) + 1.5 * pow(float(l), 2.0))

## Curva de XP de profesión: proporcional a la XP base pero con ritmo independiente.
static func xp_needed_for_job_level(level: int) -> int:
	var l := maxi(1, level - 1)
	if l == 1:
		return 10
	if l == 2:
		return 20
	return int(8.0 * float(l) + 1.2 * pow(float(l), 2.0))

## Nº máximo de ENTRADAS distintas en el inventario del jugador (no de unidades:
## 5 pociones cuentan como 1 hueco). Los ítems `category == "important"`
## (misión/llave) NO cuentan para este límite. Crece con STR — ver
## `GlobalState.inventory_slot_cap()` — igual que `CARRY_BASE`/`CARRY_PER_STR`.
## Solo se aplica una vez construido el Cofre de la Base (ver task4.md): antes,
## sin cofre donde guardar el excedente, limitar sería injusto.
static var INVENTORY_SLOT_CAP_BASE: int        = _ci("INVENTORY_SLOT_CAP_BASE", 10)
static var INVENTORY_SLOT_CAP_STR_DIVISOR: int = _ci("INVENTORY_SLOT_CAP_STR_DIVISOR", 5)   # +1 hueco cada N puntos de STR

## Nº máximo de ENTRADAS distintas en el almacén del Cofre de la Base
## (persistente — ver `GlobalState.chest_storage`). Mucho más alto que el del
## jugador: es el lugar donde volcar el excedente.
static var CHEST_SLOT_CAP: int = _ci("CHEST_SLOT_CAP", 1000)


# ═════════════════════════════════════════════════════════════════════════════
# FÓRMULAS DE STATS DERIVADOS  (cómo las 6 características → estadísticas finales)
# ═════════════════════════════════════════════════════════════════════════════
# Las 6 características que subimos con puntos (STR/AGI/VIT/INT/DEX/LUK) NO se usan
# directamente en combate: alimentan estas ESTADÍSTICAS FINALES, que sí son las que
# determinan daños, defensas y probabilidades. El equipo (arma/armadura) SUMA sobre
# estas mismas estadísticas. Filosofía de diseño de cada característica:
#
#   STR  Fuerza      → daño físico (alto), daño a distancia (leve), def. física,
#                      carga máxima.
#   AGI  Agilidad    → velocidad, esquiva.
#   VIT  Vitalidad   → HP máx, defensa física, defensa mágica.
#   INT  Inteligencia→ MP máx, daño mágico, defensa mágica.
#   DEX  Destreza    → daño a distancia (alto), daño físico (leve), puntería, crítico.
#   LUK  Suerte      → crítico (alto), esquiva, puntería (leve).
#
#   max_hp = HP_BASE + vit*HP_PER_VIT + level*HP_PER_LEVEL
#   max_mp = MP_BASE + int*MP_PER_INT + level*MP_PER_LEVEL
#   → Para subir la VIDA MÁXIMA INICIAL, sube HP_BASE (o HP_PER_VIT).
# task3_rebalanceo_global_limpieza_y_optimizacion.md FASE2: fórmulas con término
# de NIVEL explícito (antes solo VIT/INT alimentaban HP/MP salvo un pequeño
# HP_PER_LEVEL/MP_PER_LEVEL); ídem daño y defensa, alineadas con la escala de
# `EnemyDatabase._hp_base/_atk_base/_def_base` para que el TTK objetivo del
# documento (3-4 turnos contra un enemigo del mismo nivel) tenga sentido.
# ─────────────────────────────────────────────────────────────────────────────
static var HP_BASE: int       = _ci("HP_BASE", 9)
static var HP_PER_VIT: int    = _ci("HP_PER_VIT", 2)
static var HP_PER_LEVEL: int  = _ci("HP_PER_LEVEL", 1)
static var MP_BASE: int       = _ci("MP_BASE", 5)
static var MP_PER_INT: int    = _ci("MP_PER_INT", 1)
static var MP_PER_LEVEL: int  = _ci("MP_PER_LEVEL", 1)

# ── Daño (se suma el bonus del equipo correspondiente) ───────────────────────
static var PHYS_DMG_FROM_STR: float  = _cf("PHYS_DMG_FROM_STR", 0.5)   # STR es la fuente principal del daño físico
static var PHYS_DMG_FROM_DEX: float  = _cf("PHYS_DMG_FROM_DEX", 0.1)   # DEX aporta algo de daño físico
static var PHYS_DMG_FROM_LEVEL: float = _cf("PHYS_DMG_FROM_LEVEL", 0.5)
static var MAG_DMG_FROM_INT: float   = _cf("MAG_DMG_FROM_INT", 0.6)   # INT es la fuente del daño mágico
static var MAG_DMG_FROM_LEVEL: float = _cf("MAG_DMG_FROM_LEVEL", 0.5)
static var RANGE_DMG_FROM_DEX: float = _cf("RANGE_DMG_FROM_DEX", 0.5)   # DEX es la fuente principal del daño a distancia
static var RANGE_DMG_FROM_STR: float = _cf("RANGE_DMG_FROM_STR", 0.1)   # STR aporta algo de daño a distancia (tensar el arco)
static var SPEED_FROM_AGI: float     = _cf("SPEED_FROM_AGI", 1.5)

# ── Defensas (se suma el bonus de la armadura correspondiente) ───────────────
static var PDEF_FROM_VIT: float  = _cf("PDEF_FROM_VIT", 0.2)   # VIT es la fuente principal de la defensa física
static var PDEF_FROM_STR: float  = _cf("PDEF_FROM_STR", 0.1)   # STR endurece la guardia física
static var PDEF_FROM_LEVEL: float = _cf("PDEF_FROM_LEVEL", 0.3)
static var MDEF_FROM_INT: float  = _cf("MDEF_FROM_INT", 0.2)   # INT es la fuente principal de la defensa mágica
static var MDEF_FROM_VIT: float  = _cf("MDEF_FROM_VIT", 0.1)   # VIT también resiste la magia
static var MDEF_FROM_LEVEL: float = _cf("MDEF_FROM_LEVEL", 0.3)

# ── Probabilidades secundarias (en %, con tope) ──────────────────────────────
static var DODGE_BASE: float     = _cf("DODGE_BASE", 2.0)    # % esquiva de partida
static var DODGE_FROM_AGI: float = _cf("DODGE_FROM_AGI", 0.6)
static var DODGE_FROM_LUK: float = _cf("DODGE_FROM_LUK", 0.3)
static var DODGE_MAX: float      = _cf("DODGE_MAX", 60.0)

static var CRIT_BASE: float      = _cf("CRIT_BASE", 3.0)    # % crítico de partida
static var CRIT_FROM_LUK: float  = _cf("CRIT_FROM_LUK", 0.5)    # LUK es la fuente principal del crítico
static var CRIT_FROM_DEX: float  = _cf("CRIT_FROM_DEX", 0.3)    # DEX aporta crítico
static var CRIT_MAX: float       = _cf("CRIT_MAX", 60.0)
static var CRIT_MULTIPLIER: float = _cf("CRIT_MULTIPLIER", 1.6)

static var ACCURACY_BASE: float  = _cf("ACCURACY_BASE", 80.0)   # % puntería de partida
static var ACC_FROM_DEX: float   = _cf("ACC_FROM_DEX", 1.2)    # DEX es la fuente principal de la puntería
static var ACC_FROM_LUK: float   = _cf("ACC_FROM_LUK", 0.4)    # LUK afina la puntería
static var ACCURACY_MAX: float   = _cf("ACCURACY_MAX", 100.0)

# ── Carga máxima (informativa: cuánto peso podría llevar el héroe) ────────────
static var CARRY_BASE: int     = _ci("CARRY_BASE", 50)
static var CARRY_PER_STR: int  = _ci("CARRY_PER_STR", 5)


# ─────────────────────────────────────────────────────────────────────────────
# HABILIDADES DE FARMEO / OFICIOS (lenador / minero / pesca / agricultor / ganadero)
# ─────────────────────────────────────────────────────────────────────────────
static var SKILL_XP_CURVE_MULTIPLIER: float = _cf("SKILL_XP_CURVE_MULTIPLIER", 1.5)  # xp_needed *= esto al subir skill
static var GATHER_XP_PER_TAP: int    = _ci("GATHER_XP_PER_TAP", 10)
static var GATHER_AMOUNT_PER_TAP: int = _ci("GATHER_AMOUNT_PER_TAP", 1)
## Milisegundos de espera entre dos toques de recolección consecutivos (antes de
## aplicar el bonus de velocidad por nivel de oficio; ver GATHER_SPEED_BONUS_PER_LEVEL).
static var GATHER_TAP_COOLDOWN_MS: int = _ci("GATHER_TAP_COOLDOWN_MS", 1000)

## PROGRESIÓN POR NIVEL DE OFICIO (solo afecta al propio oficio que sube de nivel,
## tope en MAX_SKILL_LEVEL = 10):
##   · Cada nivel de la lista GATHER_SPEED_BONUS_LEVELS (2 a 10) multiplica la
##     VELOCIDAD de recolección (menor espera entre toques / tick idle) por
##     (1 + este valor), de forma acumulativa (nivel 10 ≈ x2.36 con el valor por
##     defecto: 9 niveles acumulados de +10%).
##   · A partir de GATHER_LEVEL_AMOUNT_THRESHOLD (nivel 5) cada recolección
##     entrega GATHER_LEVEL_AMOUNT_MULTIPLIER unidades (x2) en vez de 1.
##   · Al llegar al nivel MÁXIMO (GATHER_LEVEL_AMOUNT_MAX_THRESHOLD = 10, el
##     tope del oficio) hay un salto final: entrega GATHER_LEVEL_AMOUNT_MAX (x3).
## Ver GlobalState.gather_speed_multiplier() / gather_amount_multiplier().
static var GATHER_SPEED_BONUS_PER_LEVEL: float = _cf("GATHER_SPEED_BONUS_PER_LEVEL", 0.10)
const GATHER_SPEED_BONUS_LEVELS: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10]
static var GATHER_LEVEL_AMOUNT_THRESHOLD: int      = _ci("GATHER_LEVEL_AMOUNT_THRESHOLD", 5)
static var GATHER_LEVEL_AMOUNT_MULTIPLIER: int     = _ci("GATHER_LEVEL_AMOUNT_MULTIPLIER", 2)
static var GATHER_LEVEL_AMOUNT_MAX_THRESHOLD: int  = _ci("GATHER_LEVEL_AMOUNT_MAX_THRESHOLD", 10)
static var GATHER_LEVEL_AMOUNT_MAX: int            = _ci("GATHER_LEVEL_AMOUNT_MAX", 3)

## NODOS DE RECOLECCIÓN FINITOS  (cada casilla de farmeo se agota y se regenera)
#   Cada casilla "gather" tiene una reserva limitada (capacity). Al recolectar se
#   consume; cuando llega a 0 el nodo queda AGOTADO y se regenera poco a poco con el
#   tiempo real (1 unidad cada GATHER_REGEN_INTERVAL segundos), persistente por casilla.
static var GATHER_NODE_CAPACITY: int   = _ci("GATHER_NODE_CAPACITY", 40)
static var GATHER_REGEN_INTERVAL: float = _cf("GATHER_REGEN_INTERVAL", 30.0) # Segundos reales para regenerar 1 unidad

## RECOLECCIÓN AUTOMÁTICA (idle)  —  si no tocas nada, recolectas solo.
static var GATHER_IDLE_INTERVAL: float = _cf("GATHER_IDLE_INTERVAL", 5.0)
static var GATHER_IDLE_AMOUNT: int     = _ci("GATHER_IDLE_AMOUNT", 1)

## Estado inicial de cada habilidad de farmeo / oficio.
const START_SKILLS: Dictionary = {
	"lenador":    {"level": 1, "xp": 0, "xp_needed": 50},
	"minero":     {"level": 1, "xp": 0, "xp_needed": 50},
	"pesca":      {"level": 1, "xp": 0, "xp_needed": 50},
	"agricultor": {"level": 1, "xp": 0, "xp_needed": 50},
	"ganadero":   {"level": 1, "xp": 0, "xp_needed": 50},
	"cazador":    {"level": 1, "xp": 0, "xp_needed": 50},
	"cocinero":   {"level": 1, "xp": 0, "xp_needed": 50},
}

## Recurso que produce cada habilidad de farmeo (defaults por oficio).
## loc = clave de traducción del nombre (ver Locale.gd).
const GATHER_RESOURCES: Dictionary = {
	"lenador":    {"id": "wood",  "icon": "🪵", "category": "other", "loc": "res_wood"},
	"minero":     {"id": "stone", "icon": "🪨", "category": "other", "loc": "res_stone"},
	"pesca":      {"id": "fish",  "icon": "🐟", "category": "other", "loc": "res_fish"},
	"agricultor": {"id": "wheat", "icon": "🌾", "category": "other", "loc": "res_wheat"},
	"ganadero":   {"id": "milk",  "icon": "🥛", "category": "other", "loc": "res_milk"},
	"cazador":    {"id": "carne", "icon": "🍖", "category": "other", "loc": "res_carne"},
}

## HERRAMIENTA obligatoria para poder recolectar con cada oficio (id de
## `data/items.json`, "" si no requiere ninguna). Sin ella, el toque de
## recolección se rechaza con un aviso (ver TabWorld3D._on_gather_pressed).
const GATHER_TOOL_REQUIREMENTS: Dictionary = {
	"lenador": "hacha",
	"minero":  "pico",
	"pesca":   "cana_pescar",
}

## CULTIVOS (Agricultor) — siembra/cosecha de 24 horas de juego, independiente de
## los nodos de recolección de arriba (ver `CellResource.crop`/`TerrainToolsSystem`).
## Cada entrada, indexada por el id de la SEMILLA (`data/items/*.json`), define
## el ingrediente y la cantidad que entrega la cosecha, más su nombre para la UI.
## `terrain` restringe en qué tipo de suelo se puede plantar cada semilla
## (código de `CellResource.terrain`); por defecto tierra/pradera. El cactus
## se vende en el mercader del desierto y se planta en arena despejada.
## `terraform` (opcional): en vez de conceder un ítem de cosecha, al madurar
## transforma la PROPIA casilla (mismas claves que `record_world_delta`/DSL
## de world_transforms: terrain/resource/icon/name/description...). Lo usa la
## Semilla de Cactus para reverdecer el desierto (ver TerrainToolsSystem).
const CROP_TYPES: Dictionary = {
	"semilla_trigo":  {"harvest_item": "wheat", "harvest_qty": 2, "label": {"es": "Trigo", "en": "Wheat", "fr": "Blé", "it": "Grano", "de": "Weizen", "zh": "小麦", "ja": "小麦"}, "terrain": ["gnd", "grs"]},
	"semilla_arroz":  {"harvest_item": "rice",  "harvest_qty": 2, "label": {"es": "Arroz", "en": "Rice", "fr": "Riz", "it": "Riso", "de": "Reis", "zh": "稻米", "ja": "稲"}, "terrain": ["gnd", "grs"]},
	"semilla_cactus": {
		"label": {"es": "Cactus", "en": "Cactus", "fr": "Cactus", "it": "Cactus", "de": "Kaktus", "zh": "仙人掌", "ja": "サボテン"}, "terrain": ["des"],
		"terraform": {
			"terrain": "grs",
			"resource": "forest",
			"icon": "🌳",
			"name": {"es": "Oasis reverdecido", "en": "Blooming oasis", "fr": "Oasis reverdie", "it": "Oasi rifiorita", "de": "Wieder erblühte Oase", "zh": "复苏的绿洲", "ja": "緑に戻ったオアシス"},
			"description": {"es": "Un cactus que floreció y devolvió la vida a la arena.", "en": "A cactus that bloomed and brought the sand back to life.", "fr": "Un cactus qui a fleuri et redonné vie au sable.", "it": "Un cactus che è fiorito e ha ridato vita alla sabbia.", "de": "Ein Kaktus, der erblüht ist und dem Sand neues Leben schenkte.", "zh": "一株开花的仙人掌，让沙地重新充满生机。", "ja": "花を咲かせ、砂に命を取り戻したサボテン。"},
		},
	},
}
static var CROP_PLANT_XP: int   = _ci("CROP_PLANT_XP", 10)
static var CROP_HARVEST_XP: int = _ci("CROP_HARVEST_XP", 20)

# ─────────────────────────────────────────────────────────────────────────────
# TIPOS DE RECURSO (el "tercer tipo" de casilla: nodos GASTABLES/modificables)
#   Cada entrada define el nodo de recolección: qué oficio (skill) lo trabaja, qué
#   ítem produce, su icono/categoría, sus claves de texto y la CAPACIDAD del nodo
#   (reserva antes de agotarse). Varios recursos pueden compartir oficio pero dar
#   ítems distintos (p. ej. cantera_piedra→piedra y cantera_oro→mineral de oro).
#
#   Esta tabla ya NO es la fuente principal — ahora es solo el valor de
#   RESPALDO para los códigos clásicos. La fuente editable sin código es
#   `data/world_resources/<code>.json` (campos skill/item/item_loc/icon/category/
#   name_loc/found_loc/capacity, gestionados desde el editor en WorldResourcesManager);
#   ver Design.resolve_gather_resource(), que fusiona ambas.
#
#   ➕ Para un recurso nuevo: basta con crear su ficha en el editor (World Resources)
#      con estos campos y colocar su casilla con resource = "<id>" en Entidades
#      (data/ids.json). ViewGather y el mundo 3D lo entienden solos, sin GDScript.
# ─────────────────────────────────────────────────────────────────────────────
const RESOURCE_TYPES: Dictionary = {
	"forest":         {"skill": "lenador",  "item": "wood",     "item_loc": "res_wood",     "icon": "🌲", "category": "other", "name_loc": "node_bosque",  "found_loc": "gather_found_lenador", "capacity": 10},
	"forestBad":      {"skill": "lenador",  "item": "wood",     "item_loc": "res_wood",     "icon": "🪵", "category": "other", "name_loc": "node_arboles", "found_loc": "gather_found_arboles", "capacity": 2},
	"rock":           {"skill": "minero",   "item": "stone",    "item_loc": "res_stone",    "icon": "🪨", "category": "other", "name_loc": "node_cantera", "found_loc": "gather_found_minero",  "capacity": 10},
	"gold":           {"skill": "minero",   "item": "gold_ore", "item_loc": "res_gold_ore", "icon": "💰", "category": "other", "name_loc": "node_oro",     "found_loc": "gather_found_oro",     "capacity": 10},
	"milk":           {"skill": "ganadero", "item": "milk",     "item_loc": "res_milk",     "icon": "🐄", "category": "other", "name_loc": "node_ganado",  "found_loc": "gather_found_ganado",  "capacity": 10},
	"fish":           {"skill": "pesca",    "item": "fish",     "item_loc": "res_fish",     "icon": "🐟", "category": "other", "name_loc": "node_pesca",   "found_loc": "gather_found_pesca",   "capacity": 5},
}

## Capacidad del nodo para un recurso concreto (o la global por defecto). Prioriza
## el campo `capacity` de `data/world_resources/<code>.json` (editable sin código)
## sobre esta tabla cableada; ver Design.resolve_gather_resource.
static func resource_capacity(resource_id: String) -> int:
	var info: Dictionary = Design.resolve_gather_resource(resource_id)
	return int(info.get("capacity", GATHER_NODE_CAPACITY))


# ─────────────────────────────────────────────────────────────────────────────
# ENERGÍA DE HABILIDADES DE MAZMORRA
#
# Recurso que gastan las habilidades de exploración (barra verde del HUD, bajo el
# maná; se regenera con el tiempo). Los costes y enfriamientos por habilidad viven
# ahora en el registro data-driven `ExplorationSkills`.
# ─────────────────────────────────────────────────────────────────────────────
static var MAX_ENERGY: int = _ci("MAX_ENERGY", 100)
static var ENERGY_REGEN_PER_SEC: float = _cf("ENERGY_REGEN_PER_SEC", 1.5)


# ─────────────────────────────────────────────────────────────────────────────
# BASE — CONSTRUCCIONES (la base empieza VACÍA)
#
# Cada construcción se DESBLOQUEA al recolectar por primera vez el/los
# recurso(s) de "unlock" (ver GlobalState.resources_discovered) y se CONSTRUYE
# una sola vez pagando "costs".  "action" define qué ocurre al pulsarla ya
# construida:  passive (efecto pasivo) | cook (abre cocina) | train (abre muñeco).
#
#   ➕ Para añadir una construcción nueva basta con agregar una entrada aquí
#      y sus claves de traducción en Locale.gd. TabBase la renderiza sola.
# ─────────────────────────────────────────────────────────────────────────────
const BASE_BUILDINGS: Array = [
	{
		"key": "campfire", "icon": "🔥",
		"name_loc": "base_campfire", "desc_loc": "base_campfire_desc",
		"costs": {"wood": 15},
		"unlock": ["wood"],
		"action": "passive",
		"upgradable": true,   # cada nivel regenera más HP/MP
	},
	{
		"key": "kitchen", "icon": "🍳",
		"name_loc": "base_kitchen", "desc_loc": "base_kitchen_desc",
		"costs": {"stone": 15},
		"unlock": ["stone"],
		"action": "cook",
	},
	{
		"key": "dummy", "icon": "🎯",
		"name_loc": "base_dummy", "desc_loc": "base_dummy_desc",
		"costs": {"wood": 20, "stone": 20},
		"unlock": ["wood", "stone"],
		"action": "train",
		"upgradable": true,   # cada nivel da más XP idle
	},
	{
		"key": "board", "icon": "📋",
		"name_loc": "base_board", "desc_loc": "base_board_desc",
		"costs": {"wood": 10},
		"unlock": ["wood"],
		"action": "encargos",
	},
	{
		"key": "forge", "icon": "🔨",
		"name_loc": "base_forge", "desc_loc": "base_forge_desc",
		"costs": {"wood": 20, "stone": 15},
		"unlock": ["stone"],
		"action": "forge",
	},
]

## MUÑECO DE ENTRENAMIENTO — idle + clicker (en su propia vista).
static var TRAINING_XP_PER_TAP: int       = _ci("TRAINING_XP_PER_TAP", 1)
static var TRAINING_IDLE_XP: int          = _ci("TRAINING_IDLE_XP", 1)
static var TRAINING_IDLE_INTERVAL: float  = _cf("TRAINING_IDLE_INTERVAL", 5.0)


# ─────────────────────────────────────────────────────────────────────────────
# MUNDO (rejilla de casillas) — AMPLIABLE
# ─────────────────────────────────────────────────────────────────────────────
# Lienzo ampliable; el contenido jugable es compacto, el resto es mar listo para expandir.
static var WORLD_WIDTH: int          = _ci("WORLD_WIDTH", 1000)
static var WORLD_HEIGHT: int         = _ci("WORLD_HEIGHT", 1000)
const WORLD_START_POS: Vector2i = Vector2i(4, 10)   # Casilla PROTAGONISTA (centro del valle de yelmo)

# ─── CICLO DÍA / NOCHE (data-driven, gestionado por el autoload TimeManager) ──
# Duraciones en SEGUNDOS REALES de cada fase (día 3 min / noche 1 min por defecto).
# El reloj in-game avanza 24 h por ciclo, repartidas entre día y noche según las
# horas de inicio; el ritmo real difiere para que la noche pase más rápido.
static var DAY_DURATION_SEC: float   = _cf("DAY_DURATION_SEC", 180.0)
static var NIGHT_DURATION_SEC: float = _cf("NIGHT_DURATION_SEC", 60.0)
static var DAY_START_HOUR: float     = _cf("DAY_START_HOUR", 6.0)
static var NIGHT_START_HOUR: float   = _cf("NIGHT_START_HOUR", 20.0)
static var DAY_TWILIGHT_HOURS: float = _cf("DAY_TWILIGHT_HOURS", 1.0)


# ─── CAMPAMENTO FÍSICO ──────────────────────────────────────────────
# Coste en madera para montar/ampliar el campamento del jugador en el mapamundi.
static var CAMP_WOOD_COST: int     = _ci("CAMP_WOOD_COST", 10)       # Montar el Campamento (Nivel 1)
static var CAMPFIRE_WOOD_COST: int = _ci("CAMPFIRE_WOOD_COST", 20)   # Construir la Hoguera (Nivel 2)

# ─── TRANSPORTE (NPC transportista) ──────────────────────────────────────────
# Único medio de viaje rápido (no hay teletransporte libre): el NPC
# transportista de cada ciudad cobra oro por llevarte a un destino ya visitado.
static var TRAVEL_GOLD_COST: int = _ci("TRAVEL_GOLD_COST", 25)

## CONSTRUCCIONES FÍSICAS DEL CAMPAMENTO: evolución por niveles, cola estricta
## (ver `GlobalState.camp_current_structure_key`): Hoguera(2)→Muñeco(3)→Cofre(4)→
## Tablón(5)→Herrería. Cada una se paga UNA vez (`costs`) y coloca un objeto
## físico (event_id="camp_<key>") en una casilla libre: fija junto a la tienda
## para la Hoguera, elegida por el jugador para el resto (ver
## `GlobalState.camp_structure_placement_mode`); `action` decide qué abre.
## ➕ Nueva construcción = añadir entrada aquí + claves en Locale.
const CAMP_STRUCTURES: Array = [
	{
		"key": "campfire", "icon": "🔥", "action": "campfire",
		"name": {"es": "Hoguera", "en": "Campfire", "fr": "Feu de camp", "it": "Falo", "de": "Lagerfeuer", "zh": "篝火", "ja": "かがり火"},
		"desc": {"es": "Para comer y cocinar. Requiere el Plano de la Hoguera.", "en": "To eat and cook. Requires the Campfire Blueprint.", "fr": "Pour manger et cuisiner. Nécessite le plan du feu de camp.", "it": "Per mangiare e cucinare. Richiede la Piantina del Falo.", "de": "Zum Essen und Kochen. Erfordert den Lagerfeuer-Bauplan.", "zh": "用于进食和烹饪。需要篝火图纸。", "ja": "食事と料理のために使う。かがり火の設計図が必要。"},
		"costs": {"wood": 20},
		"requires": "plano_hoguera",
	},
	{
		"key": "dummy", "icon": "🎯", "action": "train",
		"name": {"es": "Muñeco de Entrenamiento", "en": "Training Dummy", "fr": "Mannequin d'entraînement", "it": "Manichino d'allenamento", "de": "Trainingspuppe", "zh": "训练假人", "ja": "訓練人形"},
		"desc": {"es": "Entrena para ganar experiencia de nivel base y de todas tus profesiones.", "en": "Train to gain base and profession experience.", "fr": "S'entraîner pour gagner de l'expérience de base et de métier.", "it": "Allenati per guadagnare esperienza base e di tutte le professioni.", "de": "Trainiere, um Basis- und Berufserfahrung zu sammeln.", "zh": "训练以获得基本等级与所有职业的经验。", "ja": "訓練して基本レベルとすべての職業の経験値を積む。"},
		"costs": {"wood": 15, "stone": 15},
	},
	{
		"key": "chest", "icon": "📦", "action": "chest",
		"name": {"es": "Cofre", "en": "Chest", "fr": "Coffre", "it": "Cassa", "de": "Truhe", "zh": "宝箱", "ja": "宝箱"},
		"desc": {"es": "Un cofre para guardar provisiones a buen recaudo. Nunca pierde su contenido.", "en": "A chest to stash your provisions safely. Never loses its contents.", "fr": "Un coffre pour ranger tes provisions en sécurité. Ne perd jamais son contenu.", "it": "Una cassa per custodire le tue provviste al sicuro. Non perde mai il contenuto.", "de": "Eine Truhe, um deine Vorräte sicher zu verstauen. Verliert nie ihren Inhalt.", "zh": "一个可以安全存放补给的宝箱。永不丢失内容。", "ja": "補給品を安全に保管する宝箱。内容を失うことはない。"},
		"costs": {"wood": 15, "stone": 15},
	},
	{
		"key": "board", "icon": "📋", "action": "encargos",
		"name": {"es": "Tablón de Encargos", "en": "Request Board", "fr": "Tableau des missions", "it": "Bacheca incarichi", "de": "Auftragstafel", "zh": "委托板", "ja": "依頼掲示板"},
		"desc": {"es": "Revisa y entrega, sin viajar, los encargos que has aceptado en las ciudades.", "en": "Review and turn in, without traveling, the requests you've accepted in cities.", "fr": "Consulte et rends, sans voyager, les missions acceptées dans les villes.", "it": "Controlla e consegna, senza viaggiare, gli incarichi accettati nelle città.", "de": "Überprüfe und liefere, ohne zu reisen, die in Städten angenommenen Aufträge ab.", "zh": "不需要旅行就能查看并交付你在城市接受的委托。", "ja": "旅をしなくとも、街で受けた依頼を確認して提出できる。"},
		"costs": {"wood": 20, "stone": 20},
	},
	{
		"key": "forge", "icon": "🔨", "action": "forge",
		"name": {"es": "Herrería", "en": "Forge", "fr": "Forge", "it": "Fucina", "de": "Schmiede", "zh": "锻造坊", "ja": "鍛冶屋"},
		"desc": {"es": "Un yunque para forjar y mejorar tu equipo.", "en": "An anvil to forge and upgrade your gear.", "fr": "Une enclume pour forger et améliorer ton équipement.", "it": "Un'incudine per forgiare e potenziare il tuo equipaggiamento.", "de": "Ein Amboss, um deine Ausrüstung zu schmieden und zu verbessern.", "zh": "一个用于锻造和升级装备的铁砧。", "ja": "装備を鍛造・強化する金床。"},
		"costs": {"wood": 25, "stone": 20},
	},
]

## EXP que otorga el Muñeco de Entrenamiento por golpe, según el Nivel de Base
## actual (`GlobalState.camp_level`): a más construcciones levantadas, más
## rentable resulta seguir entrenando. Los niveles 1-2 no tienen muñeco aún
## (se construye junto con el resto a partir del Nivel 3); se usa el mismo
## valor de esos niveles como suelo/techo si se consulta fuera de rango.
const DUMMY_TRAIN_XP_BY_CAMP_LEVEL: Dictionary = {3: 2, 4: 4, 5: 8, 6: 15}

## EXP del Muñeco de Entrenamiento para el Nivel de Base actual (clamped a
## [3, 6], el rango con datos definidos en `DUMMY_TRAIN_XP_BY_CAMP_LEVEL`).
static func dummy_train_xp(camp_level: int) -> int:
	var lvl: int = clampi(camp_level, 3, 6)
	return int(DUMMY_TRAIN_XP_BY_CAMP_LEVEL.get(lvl, 2))


## Overrides OPCIONALES de construcciones del campamento: data/config.json →
## `{ "camp_structures": { key: { icon?, cost_wood?, cost_stone? } } }`. Mismo
## patrón que `_rarities_merged`/`rarities()`: solo sobreescribe los campos
## presentes, calculado UNA vez al cargar la clase. Solo se pueden ajustar el
## icono y el coste (madera/piedra) — únicos recursos que usan hoy las 5
## construcciones cableadas; no se pueden crear construcciones nuevas aquí (su
## `action` debe seguir interpretándola `CampTentSystem`).
static var _camp_structures_merged: Array = _merge_camp_structures()

static func _merge_camp_structures() -> Array:
	var overrides: Dictionary = _cd("camp_structures", {})
	if overrides.is_empty():
		return CAMP_STRUCTURES
	var out: Array = []
	for s in CAMP_STRUCTURES:
		var ov: Variant = overrides.get(String(s.get("key", "")), null)
		if ov is Dictionary and not (ov as Dictionary).is_empty():
			var ovd: Dictionary = ov as Dictionary
			var merged: Dictionary = (s as Dictionary).duplicate(true)
			if ovd.has("icon"):
				merged["icon"] = ovd["icon"]
			var costs: Dictionary = (merged.get("costs", {}) as Dictionary).duplicate(true)
			if ovd.has("cost_wood"):
				costs["wood"] = int(ovd["cost_wood"])
			if ovd.has("cost_stone"):
				costs["stone"] = int(ovd["cost_stone"])
			merged["costs"] = costs
			out.append(merged)
		else:
			out.append(s)
	return out

## Lista de construcciones del campamento con los overrides de config.json ya
## mezclados. Úsala en vez de `CAMP_STRUCTURES` para que un cambio desde el
## editor tenga efecto real en el juego.
static func camp_structures() -> Array:
	return _camp_structures_merged


# ─────────────────────────────────────────────────────────────────────────────
# PELIGROS AMBIENTALES (insolación en desierto · congelación en nieve): una
# barra se llena mientras pisas un bioma peligroso; al llenarse mueres y
# reapareces en la base con 1 HP (se vacía sola al salir del bioma). Tipo de
# peligro 100% data-driven: campo `hazard` de data/world_terrains/<code>.json
# (editor: WorldTerrainsManager; ver Design.terrain_hazard()).
# ─────────────────────────────────────────────────────────────────────────────
static var HAZARD_FILL_SECONDS: float  = _cf("HAZARD_FILL_SECONDS", 22.0)
static var HAZARD_DECAY_SECONDS: float = _cf("HAZARD_DECAY_SECONDS", 7.0)


# ─────────────────────────────────────────────────────────────────────────────
# COMBATE
# ─────────────────────────────────────────────────────────────────────────────
static var COMBAT_TURN_INTERVAL: float    = _cf("COMBAT_TURN_INTERVAL", 3.5)
static var COMBAT_MAX_QUEUE: int          = _ci("COMBAT_MAX_QUEUE", 4)    # Slots visuales de la cola (máx. 4 en Estado Resonante)
static var COMBAT_DEFAULT_XP_REWARD: int  = _ci("COMBAT_DEFAULT_XP_REWARD", 20)   # XP por defecto si el enemigo no define
static var COMBAT_DEFAULT_GOLD_REWARD: int = _ci("COMBAT_DEFAULT_GOLD_REWARD", 10)

# ── SISTEMA DE PUNTOS DE ACCIÓN (PA) ─────────────────────────────────────────
# Cada turno el jugador dispone de un límite de PA; cada habilidad cuesta 1-3 PA
# (campo `pa_cost` en professions.json, o derivado por Design.skill_pa_cost). Las
# habilidades se encolan hasta agotar el límite y se ejecutan al pulsar ATACAR.
static var PA_LIMIT_NORMAL: int   = _ci("PA_LIMIT_NORMAL", 3)
static var PA_LIMIT_RESONANT: int = _ci("PA_LIMIT_RESONANT", 4)

# ── SISTEMA DE RESONANCIA (reemplaza la antigua barra SP) ────────────────────
# Cada habilidad ejecutada suma Resonancia según su coste de PA. Al llegar a 100,
# el SIGUIENTE turno es un Turno Resonante (más PA y coste reducido); luego vuelve a 0.
static var RESONANCE_MAX: float = _cf("RESONANCE_MAX", 100.0)
const RESONANCE_GAIN_BY_PA: Dictionary = { 1: 8.0, 2: 15.0, 3: 25.0 }  # PA -> resonancia (claves int: se deja en código)
static var RESONANCE_GAIN_SYNERGY: float = _cf("RESONANCE_GAIN_SYNERGY", 35.0)

# ── ESCALA TEMPORAL (cámara lenta al decidir) ────────────────────────────────
# Con el ATB del jugador lleno y la cola vacía, el tiempo del enemigo/animaciones/
# estados se ralentiza a este factor para pensar la jugada sin pausar del todo.
static var COMBAT_DECISION_TIME_SCALE: float = _cf("COMBAT_DECISION_TIME_SCALE", 0.2)

# ── PERFIL DE BLOQUEO (QTE de defensa por profesión) ─────────────────────────
# Defensa de DOS zonas, igual para todas las profesiones: la zona AMPLIA reduce
# ~40% del daño; acertar la ventana INTERIOR, más estrecha (`perfect_window`),
# da DEFENSA PERFECTA (~90% de reducción + Resonancia). `Don Nadie` no tiene
# ventana perfecta. Campos: *_window en segundos; *_mult = daño recibido
# (0=nulo, 1=íntegro); `magic_perfect_mult` ajusta la perfecta ante daño mágico.
## Ventanas recortadas (0.45→0.30s normal, 0.22→0.14s perfecta) para exigir
## más precisión sin ser imposible.
const BLOCK_PROFILE: Dictionary = {
	"normal_window": 0.30, "perfect_window": 0.14, "perfect_mult": 0.10, "normal_mult": 0.60, "magic_perfect_mult": 0.10, "perfect_resonance": 25.0, "loc": "block_default",
}
const BLOCK_PROFILE_NONE: Dictionary = {
	"normal_window": 0.30, "perfect_window": 0.00, "perfect_mult": 0.65, "normal_mult": 0.65, "magic_perfect_mult": 0.65, "perfect_resonance": 0.0, "loc": "block_none",
}

## Perfil de bloqueo activo según la profesión. `Don Nadie` no tiene bloqueo perfecto.
static func block_profile(prof: String) -> Dictionary:
	return BLOCK_PROFILE_NONE if prof == "Don Nadie" else BLOCK_PROFILE

# ── FÓRMULAS DE DAÑO LIMPIAS (centralizadas) ─────────────────────────────────
# El daño de una habilidad ofensiva se calcula de forma uniforme:
#   daño_base = ataque * power/100 * MULT      (antes de defensa)
#   daño_final = mitigate(daño_base, defensa)  (mitigación PORCENTUAL, mínimo 1)
# donde `ataque` es la estadística ofensiva del héroe (físico/mágico/distancia),
# `power` es la POTENCIA de la habilidad en escala 0-150 (skills.json) y MULT es
# el ajuste global por tipo. La defensa la aplica quien llama vía `mitigate()`
# (para poder ignorarla/penetrarla). Ver `mitigate()` para el porqué del cambio.
static var PHYS_DMG_MULT: float  = _cf("PHYS_DMG_MULT", 1.0)
static var MAG_DMG_MULT: float   = _cf("MAG_DMG_MULT", 1.0)
static var RANGE_DMG_MULT: float = _cf("RANGE_DMG_MULT", 1.0)

## Constante de la mitigación por defensa (ver `mitigate`). Con K=100, una defensa
## igual a K reduce el daño a la mitad; escala con rendimientos decrecientes.
static var DEF_MITIGATION_K: float = _cf("DEF_MITIGATION_K", 100.0)

## Daño ofensivo base (antes de defensa) de un ataque de `type` con `power`
## (potencia 0-150). Fórmula: ataque * power/100 * MULT.
static func offensive_damage(attack: int, power: float, type: String) -> int:
	var mult: float = PHYS_DMG_MULT
	match type:
		"magic":  mult = MAG_DMG_MULT
		"ranged": mult = RANGE_DMG_MULT
	return int(float(attack) * (power / 100.0) * mult)

## Aplica la DEFENSA como MITIGACIÓN PORCENTUAL (no sustractiva):
##   final = round(raw · K/(K+def)), con mínimo 1.
## Sustituye a la antigua resta `max(1, raw - def)`, que anulaba el daño cuando la
## defensa superaba al ataque (los enemigos hacían "1 de daño" en zonas altas y el
## héroe mataba de uno o dos golpes). La mitigación % nunca anula del todo el daño
## y da rendimientos decrecientes a la defensa, dejando un TTK equilibrado.
static func mitigate(raw: float, defense: float) -> int:
	var d: float = maxf(0.0, defense)
	return int(max(1, round(raw * DEF_MITIGATION_K / (DEF_MITIGATION_K + d))))

## Valor de una curación con `power` (0-150) a partir de una base (INT/nivel).
static func heal_amount(base: int, power: float) -> int:
	return int(float(base) * (power / 100.0))


# ── ESTADOS ALTERADOS (helpers data-driven) ──────────────────────────────────
# El combate lee los modificadores desde la tabla ÚNICA STATUS_EFFECTS (más
# abajo) en vez de comprobar nombres sueltos. Campos de modificador soportados:
#   good, dot, regen, atb_mult, no_charge, skip, miss_chance, silence,
#   mit_phys, mit_mag, dmg_out, crit_add, dodge_add, pdef_mult, mdef_mult,
#   force_crit  (ver la documentación de STATUS_EFFECTS).

## Overrides OPCIONALES de estados alterados: data/config.json
## → `{ "status_effects": { key: { campo: valor, ... } } }`. Solo sobreescribe
## los campos presentes en el override; el resto sigue viniendo de
## STATUS_EFFECTS. Calculado UNA vez al cargar la clase (igual que `_cfg`).
static var _status_overrides: Dictionary = _cd("status_effects", {})

## Definición de un estado (o {} si no existe en la tabla), con el override de
## config.json (si existe) mezclado por encima.
static func status_def(key: String) -> Dictionary:
	var base: Dictionary = STATUS_EFFECTS.get(key, {})
	if base.is_empty():
		return base
	var ov: Variant = _status_overrides.get(key, null)
	if not (ov is Dictionary) or (ov as Dictionary).is_empty():
		return base
	var merged: Dictionary = base.duplicate(true)
	for k in (ov as Dictionary):
		merged[k] = ov[k]
	return merged

## ¿El estado es beneficioso (para colorear la etiqueta)?
static func status_is_good(key: String) -> bool:
	return bool(status_def(key).get("good", false))

## Multiplicador AGREGADO de daño recibido por el portador, según su tipo
## ("physical"/"ranged" -> mit_phys; "magic" -> mit_mag). 1.0 = sin mitigación.
static func status_incoming_mult(statuses: Dictionary, dmg_type: String) -> float:
	var m: float = 1.0
	var key := "mit_mag" if dmg_type == "magic" else "mit_phys"
	for st in statuses:
		m *= float(status_def(st).get(key, 1.0))
	return m

## Multiplicador AGREGADO del daño que inflige el portador (buffs ofensivos).
static func status_out_mult(statuses: Dictionary) -> float:
	var m: float = 1.0
	for st in statuses:
		m *= float(status_def(st).get("dmg_out", 1.0))
	return m

## Multiplicador AGREGADO de carga de ATB del portador (prisa/lentitud).
static func status_atb_mult(statuses: Dictionary) -> float:
	var m: float = 1.0
	for st in statuses:
		m *= float(status_def(st).get("atb_mult", 1.0))
	return m

## AGI → ATB (task_arreglosPendientes.md §2): antes, `GlobalState.get_speed()`
## (derivado de AGI) se calculaba y se mostraba en la ficha de personaje pero
## NUNCA se usaba en combate — el ATB del jugador cargaba a ritmo constante y
## solo lo modulaban los estados (prisa/lentitud). AGI ahora acelera el ATB del
## jugador de forma leve y con tope, para que se note sin romper el ritmo de
## combate (ver `CombatTurnEngine.tick`).
static var ATB_SPEED_FACTOR: float    = _cf("ATB_SPEED_FACTOR", 0.01)   # +1% de carga por punto de "velocidad" derivada
static var ATB_SPEED_MAX_BONUS: float = _cf("ATB_SPEED_MAX_BONUS", 0.35)  # tope +35%

## Multiplicador de ritmo de ATB a partir de la "velocidad" derivada (AGI).
static func atb_speed_multiplier(speed: int) -> float:
	return 1.0 + clampf(float(speed) * ATB_SPEED_FACTOR, 0.0, ATB_SPEED_MAX_BONUS)

## Suma AGREGADA a la probabilidad de crítico (0-1) por estados del portador.
static func status_crit_add(statuses: Dictionary) -> float:
	var a: float = 0.0
	for st in statuses:
		a += float(status_def(st).get("crit_add", 0.0))
	return a

## Suma AGREGADA a la esquiva (%) por estados del portador.
static func status_dodge_add(statuses: Dictionary) -> float:
	var a: float = 0.0
	for st in statuses:
		a += float(status_def(st).get("dodge_add", 0.0))
	return a

## ¿Algún estado del portador tiene la bandera booleana `flag` activa?
static func status_any_flag(statuses: Dictionary, flag: String) -> bool:
	for st in statuses:
		if bool(status_def(st).get(flag, false)):
			return true
	return false


# ─────────────────────────────────────────────────────────────────────────────
# COCINA — ÁRBOL DE RECETAS (Cocinero, niveles 1-9)
#   `ingredients`: lista de {id, qty} (1 o más) consumidos de la bolsa.
#   `out_id`: consumible resultante (items.json, campo "effects" define su cura/buff).
#   `level_req`: nivel mínimo de la habilidad "cocinero" para poder elaborarla.
#   ➕ Añade recetas aquí: la cocina las muestra solas si tienes nivel e ingredientes.
# ─────────────────────────────────────────────────────────────────────────────
const COOKING_RECIPES: Array = [
	{"level_req": 1, "ingredients": [{"id": "fish",  "qty": 1}], "out_id": "cooked_fish"},
	{"level_req": 3, "ingredients": [{"id": "carne", "qty": 1}], "out_id": "carne_asada"},
	{"level_req": 5, "ingredients": [{"id": "wheat", "qty": 1}], "out_id": "pan"},
	{"level_req": 5, "ingredients": [{"id": "rice",  "qty": 1}], "out_id": "arroz_cocinado"},
	{"level_req": 7, "ingredients": [{"id": "pan", "qty": 1}, {"id": "carne_asada", "qty": 1}], "out_id": "hamburguesa"},
	{"level_req": 7, "ingredients": [{"id": "arroz_cocinado", "qty": 1}, {"id": "fish", "qty": 1}], "out_id": "sushi"},
	{"level_req": 9, "ingredients": [{"id": "milk", "qty": 1}], "out_id": "queso_artesanal"},
	{"level_req": 9, "ingredients": [{"id": "milk", "qty": 1}, {"id": "fish", "qty": 1}, {"id": "carne_asada", "qty": 1}], "out_id": "estofado_marinero"},
]

## Habilidad de oficio cuyo nivel desbloquea el árbol de recetas de arriba.
const COOKING_SKILL: String = "cocinero"
## XP de Cocinero al elaborar CUALQUIER receta (ver GlobalState.cook_recipe).
static var COOKING_XP_PER_DISH: int = _ci("COOKING_XP_PER_DISH", 15)
## Probabilidad [0-1] de que cocinar salga mal: se consumen los ingredientes
## igualmente pero NO se entrega el plato ni XP de Cocinero (ver
## CookingBuffsManager.cook_recipe / ViewCook._on_cook, feedback "desastre").
static var COOK_FAIL_CHANCE: float = _cf("COOK_FAIL_CHANCE", 0.25)

## Buffs temporales de comida (Hamburguesa/Queso Artesanal): multiplicador
## aplicado en vivo por GlobalState.get_phys_damage()/get_phys_defense() mientras
## el buff esté activo, y duración por defecto si la receta no especifica la suya.
static var FOOD_BUFF_STRENGTH_MULT: float = _cf("FOOD_BUFF_STRENGTH_MULT", 1.10)  # [🗡️ Fuerza]
static var FOOD_BUFF_VIGOR_MULT: float    = _cf("FOOD_BUFF_VIGOR_MULT", 1.5)      # [🛡️ Vigor] (task1 FASE1: con def base baja el redondeo entero anulaba un mult. de 1.15)
static var FOOD_BUFF_DURATION_SEC: int    = _ci("FOOD_BUFF_DURATION_SEC", 600)    # 10 min reales

## task3_rebalanceo FASE3: buff temporal de inicio de partida ("El Yelmo"),
## concedido en `GlobalState.reset_for_new_game()` para que el héroe (que
## arranca con 1 de vida) tenga margen de sobrevivir la primera acometida.
static var STARTING_HP_BUFF_MULT: float        = _cf("STARTING_HP_BUFF_MULT", 1.30)
static var STARTING_HP_BUFF_DURATION_SEC: int  = _ci("STARTING_HP_BUFF_DURATION_SEC", 600)

# ─────────────────────────────────────────────────────────────────────────────
# TIENDA — CATÁLOGOS POR CIUDAD   (se compra con oro)
#   kind: "consumable" | "equipment".  loc = clave de nombre en Locale.gd.
#   SHOP_STOCKS está indexado por "stock id"; cada edificio "shop" de una ciudad
#   (en CityDatabase) indica qué catálogo usa. Así cada ciudad vende cosas distintas.
#   ➕ Para una tienda nueva: añade aquí un id con su lista y referencia ese id en
#      CityDatabase ({"kind": "shop", "stock": "<id>"}).
# ─────────────────────────────────────────────────────────────────────────────
# Cada entrada solo define {id, price}. El resto (nombre, icono, slot, bonuses,
# combat, categoría) se resuelve dinámicamente desde items.json (Design.get_item).
const SHOP_STOCKS: Dictionary = {
	# Surtido básico (fallback para ciudades sin catálogo propio).
	"default": [
		{"id": "potion",        "price": 30},
		{"id": "steel_sword",   "price": 120},
		{"id": "knight_helmet", "price": 90},
	],
	# Ciudad Imperial — surtido completo y de alta gama.
	"imperial": [
		{"id": "potion",        "price": 30},
		{"id": "steel_sword",   "price": 120},
		{"id": "tower_shield",  "price": 110},
		{"id": "plate_armor",   "price": 150},
		{"id": "knight_helmet", "price": 90},
		{"id": "swift_boots",   "price": 80},
		{"id": "ruby_ring",     "price": 130},
	],
	# Pueblo de Arena — bazar del desierto: pociones caras, agilidad y suerte.
	"desert": [
		{"id": "potion",      "price": 45},
		{"id": "swift_boots", "price": 70},
		{"id": "ruby_ring",   "price": 160},
	],
}

## Devuelve el catálogo de una tienda por su id (o el "default" si no existe).
## DATA-FIRST: si data/shops.json define el catálogo (o el
## "default"), se usa ese; si no, cae a la constante cableada SHOP_STOCKS.
static func get_shop_stock(stock_id: String) -> Array:
	var shops: Dictionary = Design.shops
	if shops.has(stock_id):
		return shops[stock_id]
	if shops.has("default"):
		return shops["default"]
	return SHOP_STOCKS.get(stock_id, SHOP_STOCKS.get("default", []))


# ─────────────────────────────────────────────────────────────────────────────
# MAZMORRA (exploración)
# ─────────────────────────────────────────────────────────────────────────────
static var DUNGEON_TICK_INTERVAL: float = _cf("DUNGEON_TICK_INTERVAL", 1.2)
static var DUNGEON_TICK_AMOUNT: int     = _ci("DUNGEON_TICK_AMOUNT", 10)    # % de exploración por tick
static var DUNGEON_AMBUSH_CHANCE: float = _cf("DUNGEON_AMBUSH_CHANCE", 0.15)


# ─────────────────────────────────────────────────────────────────────────────
# INVENTARIO INICIAL   (id, name, qty, category, icon)
#   category: "important" | "consumable" | "equipment" | "other"
# ─────────────────────────────────────────────────────────────────────────────
const START_INVENTORY: Array = []

## Equipo inicial disponible en la bolsa (solo IDs; los datos vienen de items.json).
const START_EQUIPMENT: Array = [
	"bronze_sword", "worn_shield", "leather_chest", "bronze_helmet", "travel_boots", "fortune_ring",
]


# ═════════════════════════════════════════════════════════════════════════════
# ELEMENTOS Y DEBILIDADES   (profundidad de combate)
#   Cada habilidad mágica tiene un "element". Cada enemigo declara weak_to / resist.
#   Si el elemento del golpe está en weak_to → x ELEMENT_WEAK_MULT; si está en
#   resist → x ELEMENT_RESIST_MULT; en otro caso x1.
# ═════════════════════════════════════════════════════════════════════════════
static var ELEMENT_WEAK_MULT: float   = _cf("ELEMENT_WEAK_MULT", 1.5)
static var ELEMENT_RESIST_MULT: float = _cf("ELEMENT_RESIST_MULT", 0.5)

const ELEMENTS: Dictionary = {
	"fire":      {"loc": "elem_fire",      "icon": "🔥", "color": "f97316"},
	"ice":       {"loc": "elem_ice",       "icon": "❄️", "color": "38bdf8"},
	"lightning": {"loc": "elem_lightning", "icon": "⚡", "color": "facc15"},
	"poison":    {"loc": "elem_poison",    "icon": "🟢", "color": "84cc16"},
	"water":     {"loc": "elem_water",     "icon": "💧", "color": "3b82f6"},
	"wind":      {"loc": "elem_wind",      "icon": "🌬️", "color": "5eead4"},
	"earth":     {"loc": "elem_earth",     "icon": "🪨", "color": "a16207"},
	"holy":      {"loc": "elem_holy",      "icon": "✨", "color": "fde68a"},
	"physical":  {"loc": "elem_physical",  "icon": "⚔️", "color": "cbd5e1"},
	"ranged":    {"loc": "elem_ranged",    "icon": "🏹", "color": "4ade80"},
	"magic":     {"loc": "elem_magic",     "icon": "🔮", "color": "a855f7"},
	"dark":      {"loc": "elem_dark",      "icon": "🌑", "color": "64748b"},
	"time":      {"loc": "elem_time",      "icon": "⏳", "color": "eab308"},
	"psychic":   {"loc": "elem_psychic",   "icon": "🧠", "color": "c084fc"},
	"none":      {"loc": "elem_none",      "icon": "▪️", "color": "94a3b8"},
}


# ═════════════════════════════════════════════════════════════════════════════
# ESTADOS ALTERADOS   (tabla ÚNICA data-driven — display + modificadores)
#   Campos de DISPLAY:   loc (clave Locale), icon, color, good (beneficioso)
#   Campos de MODIFICADOR (todos opcionales; los lee el combate vía helpers):
#     dot          true → inflige daño al inicio de cada turno del portador
#     regen        curación por turno al portador (fracción del HP máx, 0-1)
#     skip         el portador pierde el turno (aturdimiento)
#     no_charge    el portador no puede cargar ATB (bloqueo temporal)
#     atb_mult     multiplica la carga de ATB del portador (prisa/lentitud)
#     miss_chance  prob. de que los ataques del portador fallen (confusión)
#     silence      el portador no puede lanzar magia
#     mit_phys     multiplica el daño FÍSICO recibido por el portador (<1 mitiga)
#     mit_mag      multiplica el daño MÁGICO recibido por el portador
#     dmg_out      multiplica el daño que INFLIGE el portador
#     crit_add     suma a la probabilidad de crítico del portador (0-1)
#     dodge_add    suma a la esquiva del portador (%)
#     pdef_mult    multiplica la DEF física del portador (debuff de armadura)
#     mdef_mult    multiplica la DEF mágica del portador
#     force_crit   el portador hace crítico garantizado en su próximo golpe
# ═════════════════════════════════════════════════════════════════════════════
const STATUS_EFFECTS: Dictionary = {
	# — DoT / control (normalmente sobre el ENEMIGO) —
	"poison": {"loc": "status_poison", "icon": "🟢", "color": "84cc16", "dot": true},
	"bleed":  {"loc": "status_bleed",  "icon": "🩸", "color": "b91c1c", "dot": true},
	"burn":   {"loc": "status_burn",   "icon": "🔥", "color": "f97316", "dot": true},
	"stun":   {"loc": "status_stun",   "icon": "💫", "color": "facc15", "skip": true},
	"slow":   {"loc": "status_slow",   "icon": "🐌", "color": "38bdf8", "atb_mult": 0.75},
	"chrono_lock": {"loc": "status_chrono_lock", "icon": "🔒", "color": "818cf8", "no_charge": true},
	"confusion": {"loc": "status_confusion", "icon": "🌀", "color": "a855f7", "miss_chance": 0.4},
	"silence": {"loc": "status_silence", "icon": "🤫", "color": "6b7280", "silence": true},
	"pdef_down": {"loc": "status_pdef_down", "icon": "🪓", "color": "e11d48", "pdef_mult": 0.75},
	"mdef_down": {"loc": "status_mdef_down", "icon": "💢", "color": "e11d48", "mdef_mult": 0.75, "dmg_out": 0.9},
	"atk_down": {"loc": "status_atk_down", "icon": "🗣️", "color": "94a3b8", "dmg_out": 0.9},
	"distorsion": {"loc": "status_distorsion", "icon": "🌀", "color": "6366f1"},
	# — Beneficiosos (normalmente sobre el JUGADOR) —
	"barrera": {"loc": "status_barrera", "icon": "🧱", "color": "3b82f6", "good": true, "mit_phys": 0.65},
	"barrera_ii": {"loc": "status_barrera_ii", "icon": "🧱", "color": "2563eb", "good": true, "mit_phys": 0.50},
	"escudo": {"loc": "status_escudo", "icon": "🛡️", "color": "a855f7", "good": true, "mit_mag": 0.65},
	"muro_ii": {"loc": "status_muro_ii", "icon": "🧱", "color": "f59e0b", "good": true, "mit_phys": 0.75, "mit_mag": 0.75},
	"burbuja_temporal": {"loc": "status_burbuja_temporal", "icon": "🫧", "color": "0ea5e9", "good": true, "mit_phys": 0.8, "mit_mag": 0.8},
	"counter_stance": {"loc": "status_counter_stance", "icon": "↩️", "color": "f97316", "good": true, "mit_phys": 0.7},
	"concentracion": {"loc": "status_concentracion", "icon": "🎯", "color": "eab308", "good": true, "dmg_out": 1.25},
	"fuerza_mental": {"loc": "status_fuerza_mental", "icon": "🧠", "color": "f43f5e", "good": true, "dmg_out": 1.3},
	"fuerza_interior": {"loc": "status_fuerza_interior", "icon": "🔥", "color": "ef4444", "good": true, "dmg_out": 1.5},
	"mente_serena": {"loc": "status_mente_serena", "icon": "🧘", "color": "f59e0b", "good": true},
	"prisa": {"loc": "status_prisa", "icon": "🏃", "color": "06b6d4", "good": true, "atb_mult": 1.25},
	"prisa_ii": {"loc": "status_prisa_ii", "icon": "💨", "color": "0891b2", "good": true, "atb_mult": 1.45},
	"berserk": {"loc": "status_berserk", "icon": "😤", "color": "ef4444", "good": true, "dmg_out": 1.5, "pdef_mult": 0.75},
	"focus": {"loc": "status_focus", "icon": "🧠", "color": "c084fc", "good": true, "dmg_out": 1.3},
	"blessing": {"loc": "status_blessing", "icon": "🌟", "color": "fde047", "good": true, "dmg_out": 1.15, "mit_phys": 0.9, "mit_mag": 0.9},
	"crit_up": {"loc": "status_crit_up", "icon": "🎯", "color": "f59e0b", "good": true, "crit_add": 0.30},
	"guaranteed_crit": {"loc": "status_guaranteed_crit", "icon": "💥", "color": "f97316", "good": true, "force_crit": true},
	"esconderse": {"loc": "status_esconderse", "icon": "🌫️", "color": "10b981", "good": true, "dodge_add": 40.0},
	"illusion": {"loc": "status_illusion", "icon": "🔮", "color": "ec4899", "good": true, "dodge_add": 30.0},
	"esquiva_temporal": {"loc": "status_esquiva_temporal", "icon": "⏳", "color": "38bdf8", "good": true, "dodge_add": 999.0},
	"regen": {"loc": "status_regen", "icon": "🌿", "color": "22c55e", "good": true, "regen": 0.08},
}


# ═════════════════════════════════════════════════════════════════════════════
# COMBOS   (encolar habilidades del mismo tipo da bonus)
# ═════════════════════════════════════════════════════════════════════════════
static var COMBO_CHAIN_LEN: int    = _ci("COMBO_CHAIN_LEN", 3)
static var COMBO_DMG_MULT: float   = _cf("COMBO_DMG_MULT", 1.5)


# ═════════════════════════════════════════════════════════════════════════════
# RAREZA DEL BOTÍN   (multiplica los bonus del equipo soltado)
#   weight = peso relativo para la tirada aleatoria.
# ═════════════════════════════════════════════════════════════════════════════
const RARITIES: Array = [
	{"key": "common",    "loc": "rarity_common",    "color": "b8c0cc", "mult": 1.0, "weight": 58.0},
	{"key": "uncommon",  "loc": "rarity_uncommon",  "color": "4ade80", "mult": 1.3, "weight": 26.0},
	{"key": "rare",      "loc": "rarity_rare",      "color": "3b82f6", "mult": 1.7, "weight": 12.0},
	{"key": "epic",      "loc": "rarity_epic",      "color": "a855f7", "mult": 2.2, "weight": 3.5},
	{"key": "legendary", "loc": "rarity_legendary", "color": "f59e0b", "mult": 3.2, "weight": 0.5},
]

## Overrides OPCIONALES de rareza de botín: data/config.json →
## `{ "loot_rarities": { key: { campo: valor, ... } } }`. Mismo patrón que
## `_status_overrides`: solo sobreescribe los campos presentes, calculado UNA
## vez al cargar la clase. `rarities()` es la lista MEZCLADA — todo consumidor
## (tirada de rareza, nombre/color por key…) debe leer de aquí, NUNCA de
## `RARITIES` directamente, o el override no tendría ningún efecto real.
static var _rarities_merged: Array = _merge_rarities()

static func _merge_rarities() -> Array:
	var overrides: Dictionary = _cd("loot_rarities", {})
	if overrides.is_empty():
		return RARITIES
	var out: Array = []
	for r in RARITIES:
		var ov: Variant = overrides.get(String(r.get("key", "")), null)
		if ov is Dictionary and not (ov as Dictionary).is_empty():
			var merged: Dictionary = (r as Dictionary).duplicate(true)
			for k in (ov as Dictionary):
				merged[k] = ov[k]
			out.append(merged)
		else:
			out.append(r)
	return out

## Lista de rarezas con los overrides de config.json ya mezclados. Úsala en vez
## de `RARITIES` para que un cambio desde el editor tenga efecto real en el
## juego (tirada de botín, nombre/color por key…).
static func rarities() -> Array:
	return _rarities_merged

## Plantillas base de equipo que sueltan los enemigos (id + nivel; los stats se
## leen de items.json y se les aplica el multiplicador de rareza encima).
const LOOT_EQUIPMENT: Array = [
	{"level": 1, "id": "rusty_dagger"},
	{"level": 1, "id": "wood_buckler"},
	{"level": 2, "id": "hunters_bow"},
	{"level": 2, "id": "mage_pendant"},
	{"level": 2, "id": "iron_greaves"},
	{"level": 3, "id": "dragon_helm"},
	{"level": 3, "id": "flame_blade"},
	{"level": 7, "id": "cota_escarcha"},
	{"level": 7, "id": "amuleto_escarcha"},
]


# ═════════════════════════════════════════════════════════════════════════════
# FORJA   (sumidero de oro + recursos → equipo)  — edificio de la Base
# ═════════════════════════════════════════════════════════════════════════════
# Cada receta define {id, gold, costs}. El nombre/slot/icono/bonuses/combat del
# resultado se obtienen de items.json (Design.get_item).
const FORGE_RECIPES: Array = [
	{"id": "iron_sword",  "gold": 60, "costs": {"wood": 5,  "stone": 10}},
	{"id": "iron_shield", "gold": 50, "costs": {"wood": 8,  "stone": 8}},
	{"id": "oak_bow",     "gold": 55, "costs": {"wood": 14}},
]

## Coste en oro de RE-FORJAR (volver a tirar la rareza) de un equipo del inventario.
static var REFORGE_COST_GOLD: int = _ci("REFORGE_COST_GOLD", 80)


# ═════════════════════════════════════════════════════════════════════════════
# REFINAMIENTO DE EQUIPO (+0 a +10)  — ver task5.md / RefineManager
#   Cada nivel aplica un +10% de eficacia a TODOS los bonus del equipo (stats +
#   combate); +10 = +100% = el doble. Dos vías, misma lógica, distinta moneda:
#     • Herrero de CIUDAD (POI "kind": "forge" en su ids.json): cobra ORO.
#     • Herrería de la BASE (yunque propio, action "forge" en CAMP_STRUCTURES):
#       cobra RECURSOS (madera/piedra), sin oro.
#   Antes de REFINE_RISK_FROM_LEVEL el intento siempre tiene éxito. Desde ahí,
#   hay probabilidad de fallo (ver REFINE_RISK): al fallar, el nivel se
#   MANTIENE o RETROCEDE. El coste se paga siempre, tenga éxito o no.
# ═════════════════════════════════════════════════════════════════════════════
static var REFINE_MAX_LEVEL: int = _ci("REFINE_MAX_LEVEL", 10)
static var REFINE_BONUS_PER_LEVEL: float = _cf("REFINE_BONUS_PER_LEVEL", 0.10)

## Coste en ORO (herrero de ciudad) para pasar de `from_level` a `from_level+1`:
## escala suave con REFINE_GOLD_GROWTH_EARLY hasta REFINE_RISK_FROM_LEVEL, y con
## REFINE_GOLD_GROWTH_LATE (más agresivo) a partir de ahí.
static var REFINE_GOLD_BASE: int           = _ci("REFINE_GOLD_BASE", 40)
static var REFINE_GOLD_GROWTH_EARLY: float = _cf("REFINE_GOLD_GROWTH_EARLY", 1.3)
static var REFINE_GOLD_GROWTH_LATE: float  = _cf("REFINE_GOLD_GROWTH_LATE", 1.7)

## Coste en RECURSOS (yunque propio) para pasar de `from_level` a `from_level+1`,
## con la misma curva suave/agresiva que el oro. `REFINE_RESOURCE_COSTS` da el
## peso relativo de cada recurso (madera/piedra a partes iguales).
static var REFINE_RES_BASE: int           = _ci("REFINE_RES_BASE", 8)
static var REFINE_RES_GROWTH_EARLY: float = _cf("REFINE_RES_GROWTH_EARLY", 1.25)
static var REFINE_RES_GROWTH_LATE: float  = _cf("REFINE_RES_GROWTH_LATE", 1.6)
const REFINE_RESOURCE_COSTS: Dictionary = {"wood": 1.0, "stone": 1.0}

## Nivel desde el que un intento de refinar puede fallar (antes, éxito garantizado).
static var REFINE_RISK_FROM_LEVEL: int = _ci("REFINE_RISK_FROM_LEVEL", 5)

## Probabilidades de fallo al intentar subir DESDE el nivel indicado (clave):
##   "stay" = % de quedarse igual · "back" = % de retroceder un nivel (el resto,
##   hasta 100%, es éxito). Solo se consultan desde REFINE_RISK_FROM_LEVEL.
const REFINE_RISK: Dictionary = {
	5:  {"stay": 0.35, "back": 0.0},
	6:  {"stay": 0.50, "back": 0.0},
	7:  {"stay": 0.45, "back": 0.10},
	8:  {"stay": 0.45, "back": 0.20},
	9:  {"stay": 0.50, "back": 0.25},
	10: {"stay": 0.50, "back": 0.40},
}

## Coste en oro (herrero de ciudad) para subir de `from_level` a `from_level+1`.
static func refine_gold_cost(from_level: int) -> int:
	var growth: float = REFINE_GOLD_GROWTH_EARLY if from_level < REFINE_RISK_FROM_LEVEL else REFINE_GOLD_GROWTH_LATE
	return int(round(REFINE_GOLD_BASE * pow(growth, from_level)))

## Coste en recursos (yunque propio) para subir de `from_level` a `from_level+1`.
static func refine_resource_costs(from_level: int) -> Dictionary:
	var growth: float = REFINE_RES_GROWTH_EARLY if from_level < REFINE_RISK_FROM_LEVEL else REFINE_RES_GROWTH_LATE
	var mult: float = pow(growth, from_level)
	var out: Dictionary = {}
	for res in REFINE_RESOURCE_COSTS.keys():
		out[res] = maxi(1, int(round(REFINE_RES_BASE * float(REFINE_RESOURCE_COSTS[res]) * mult)))
	return out

## Coste en oro de REINICIAR las características (devuelve todos los puntos gastados).
static var STAT_RESET_COST_GOLD: int = _ci("STAT_RESET_COST_GOLD", 50)


# ═════════════════════════════════════════════════════════════════════════════
# NIVELES DE CONSTRUCCIÓN DE LA BASE   (mejorables con oro + recursos)
#   Cada construcción puede subir hasta BUILDING_MAX_LEVEL. Cada nivel mejora su
#   efecto (definido por consumidores: Hoguera regen, Muñeco XP, etc.).
#   El coste de subir al nivel L = base_cost escalado por BUILDING_UPGRADE_GROWTH^(L-1).
# ═════════════════════════════════════════════════════════════════════════════
static var BUILDING_MAX_LEVEL: int            = _ci("BUILDING_MAX_LEVEL", 3)
static var BUILDING_UPGRADE_GROWTH: float     = _cf("BUILDING_UPGRADE_GROWTH", 1.8)
static var BUILDING_UPGRADE_GOLD_BASE: int    = _ci("BUILDING_UPGRADE_GOLD_BASE", 50)

## Efectos por nivel (índice 0 = nivel 1). Consumidos por las vistas correspondientes.
const DUMMY_XP_BY_LEVEL: Array       = [1, 2, 3]


# ═════════════════════════════════════════════════════════════════════════════
# ENCARGOS (TABLÓN)   — dan dirección al bucle. Repetibles.
#   type: "gather" (recolectar target) | "kill" (derrotar enemigos; target "any") |
#         "visit" (entrar en edificios distintos).
#   city: id de la ciudad dueña del encargo (su tablón SOLO lista los suyos,
#         ver ViewCity/ViewEncargos). El Tablón de la Base (ViewEncargos sin
#         filtro de ciudad) agrega los ACTIVOS de TODAS las ciudades para poder
#         entregarlos sin volver a viajar.
# ═════════════════════════════════════════════════════════════════════════════
static var ENCARGO_MAX_ACTIVE: int = _ci("ENCARGO_MAX_ACTIVE", 3)
## Suelo de XP de un encargo al reclamarlo: nunca menos de este % de la XP que
## el héroe necesita para su PRÓXIMO nivel base (ver EncargosManager.encargo_effective_xp).
## Evita que los encargos se queden obsoletos en XP a medida que se sube de nivel.
static var ENCARGO_MIN_XP_PCT: float = _cf("ENCARGO_MIN_XP_PCT", 0.20)

const ENCARGOS: Array = [
	{"id": "gather_wood",  "city": "city_sylphrena", "type": "gather", "target": "wood",  "amount": 20, "loc": "enc_gather_wood",  "icon": "🪵", "reward_gold": 45, "reward_xp": 30},
	{"id": "hunt",         "city": "city_sylphrena", "type": "kill",   "target": "any",   "amount": 3,  "loc": "enc_hunt",         "icon": "⚔️", "reward_gold": 70, "reward_xp": 55},
	{"id": "gather_stone", "city": "city_sylphrena", "type": "gather", "target": "stone", "amount": 15, "loc": "enc_gather_stone", "icon": "🪨", "reward_gold": 45, "reward_xp": 30},
	{"id": "fisher",       "city": "city_celestia",  "type": "gather", "target": "fish",  "amount": 10, "loc": "enc_fisher",       "icon": "🐟", "reward_gold": 35, "reward_xp": 25},
	{"id": "wanderer",     "city": "city_celestia",  "type": "visit",  "target": "any",   "amount": 3,  "loc": "enc_wanderer",     "icon": "🚶", "reward_gold": 40, "reward_xp": 35},
	{"id": "gloriam_herbs", "city": "city_gloriam", "type": "gather", "target": "gold", "amount": 15, "loc": "enc_gloriam_herbs", "icon": "💰", "reward_gold": 65, "reward_xp": 50},
	{"id": "gloriam_scorpions", "city": "city_gloriam", "type": "kill", "target": "any", "amount": 4, "loc": "enc_gloriam_scorpions", "icon": "🦂", "reward_gold": 90, "reward_xp": 75},
	{"id": "gloriam_trade", "city": "city_gloriam", "type": "visit", "target": "any", "amount": 3, "loc": "enc_gloriam_trade", "icon": "🐪", "reward_gold": 75, "reward_xp": 60},
	{"id": "arcanum_salvage", "city": "city_arcanum", "type": "gather", "target": "stone", "amount": 25, "loc": "enc_arcanum_salvage", "icon": "🔩", "reward_gold": 120, "reward_xp": 90},
	{"id": "arcanum_automata", "city": "city_arcanum", "type": "kill", "target": "any", "amount": 5, "loc": "enc_arcanum_automata", "icon": "⚙️", "reward_gold": 150, "reward_xp": 120},
	{"id": "arcanum_patrol", "city": "city_arcanum", "type": "visit", "target": "any", "amount": 4, "loc": "enc_arcanum_patrol", "icon": "🏙️", "reward_gold": 110, "reward_xp": 85},
]


# ═════════════════════════════════════════════════════════════════════════════
# PROGRESO OFFLINE (idle)   — al volver, los nodos se rellenan y recolectas algo.
# ═════════════════════════════════════════════════════════════════════════════
static var OFFLINE_MAX_SECONDS: int          = _ci("OFFLINE_MAX_SECONDS", 8 * 3600)   # tope de acumulación (8 h)
static var OFFLINE_MIN_SECONDS: int          = _ci("OFFLINE_MIN_SECONDS", 60)         # por debajo de esto no se muestra
static var OFFLINE_GATHER_PER_INTERVAL: int  = _ci("OFFLINE_GATHER_PER_INTERVAL", 1)
static var OFFLINE_GATHER_CAP_PER_RES: int   = _ci("OFFLINE_GATHER_CAP_PER_RES", 80)         # tope por recurso al volver


# ═════════════════════════════════════════════════════════════════════════════
# ACCESIBILIDAD   (persistente en Locale/SettingsManager)
# ═════════════════════════════════════════════════════════════════════════════
static var UI_FONT_SCALE_MIN: float     = _cf("UI_FONT_SCALE_MIN", 0.8)
static var UI_FONT_SCALE_MAX: float     = _cf("UI_FONT_SCALE_MAX", 1.5)
static var UI_FONT_SCALE_DEFAULT: float = _cf("UI_FONT_SCALE_DEFAULT", 1.0)
static var COLORBLIND_DEFAULT: bool     = _cb("COLORBLIND_DEFAULT", false)


## Devuelve la definición de una rareza por su key (o la primera = común), con
## el override de config.json ya mezclado (ver `rarities()`).
static func get_rarity(key: String) -> Dictionary:
	for r in rarities():
		if r["key"] == key:
			return r
	return rarities()[0]

## Coste en oro para subir una construcción al nivel objetivo (target_level ≥ 2).
static func building_upgrade_gold(target_level: int) -> int:
	var lvl: int = maxi(2, target_level)
	return int(BUILDING_UPGRADE_GOLD_BASE * pow(BUILDING_UPGRADE_GROWTH, lvl - 2))

## Encargos PARAMÉTRICOS generados en tiempo de ejecución por
## `EncargosManager.generate_encargo()` (idea.md §2.1, plantillas en
## `data/templates/bounties_templates.json`). Viven SOLO en memoria durante la
## sesión (no se guardan en el save): son un catálogo "de usar y tirar" para dar
## volumen de contenido secundario sin redactar cientos de encargos a mano.
static var GENERATED_ENCARGOS: Array = []
## Contador incremental para IDs únicos de encargos generados ("gen_<tipo>_<n>").
static var GENERATED_ENCARGO_SEQ: int = 0

## Catálogo completo de encargos disponibles: los de autoría manual (`ENCARGOS`)
## más los generados dinámicamente (`GENERATED_ENCARGOS`).
static func all_encargos() -> Array:
	return ENCARGOS + GENERATED_ENCARGOS

## Devuelve la definición de un encargo por su id (o {}). Busca primero en el
## catálogo manual y después en el generado dinámicamente.
static func get_encargo(id: String) -> Dictionary:
	for e in ENCARGOS:
		if e["id"] == id:
			return e
	for e in GENERATED_ENCARGOS:
		if e["id"] == id:
			return e
	return {}
