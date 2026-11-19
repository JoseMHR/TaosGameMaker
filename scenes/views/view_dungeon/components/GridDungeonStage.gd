# GridDungeonStage.gd
# ─────────────────────────────────────────────────────────────────────────────
# ESCENARIO 3D GENÉRICO Y DATA-DRIVEN DE MAZMORRA DE REJILLA
#
# Construye por código, a partir de un LAYOUT de cuadrícula (definido en
# `data/dungeons/<id>.json` desde el editor visual de mazmorras), un
# escenario 3D explorable en primera persona. Es el ÚNICO tipo de escenario:
# TODAS las mazmorras son data-driven (ya no existen escenarios cableados a mano).
# ViewDungeon siempre usa este stage (con una sala mínima de reserva si un
# event_id no tiene layout todavía).
#
# Contrato del layout (todos los campos con valores por defecto sensatos):
#   {
#     cell_size: float (m, ancho de casilla),  wall_height: float (m),
#     spawn: { f:int, x:int, y:int },
#     floors: [ { name, w, h, cells: [[ celda ]] } ],   # cells[y][x]
#   }
# Cada celda: { t: tipo, h?: altura, color?: "#rrggbb", col?: bool, ref?, to?, ev? }
#   Tipos: void, floor, wall, door, stairs, bridge, lava, water, spikes,
#          teleport, switch, button, lever, monster, npc, item, chest, event,
#          decor, light.
#   chest: cofre saqueable UNA vez. Contenido data-driven en la propia celda:
#          { "t":"chest", "gold": int, "items": [ {"id":"potion","qty":2}, ... ] }.
#          Su estado "abierto" persiste por clave "event_id:planta:x:y"
#          (GlobalState.opened_chests); al reentrar se dibuja apagado.
#
# Las plantas se apilan en el eje Y (planta i a y = i * (wall_height + GAP)).
# El plano XZ mapea la rejilla:  world_x = x * cell_size ,  world_z = y * cell_size.
# ─────────────────────────────────────────────────────────────────────────────
class_name GridDungeonStage
extends Node3D

const ENEMY_SCENE: PackedScene = preload("res://scenes/views/view_dungeon/components/DungeonEnemy.tscn")
const WATER_ZONE_SCRIPT := "res://scenes/views/view_dungeon/components/DungeonWaterZone.gd"
const LAVA_ZONE_SCRIPT := "res://scenes/views/view_dungeon/components/DungeonLavaZone.gd"
const SPIKES_ZONE_SCRIPT := "res://scenes/views/view_dungeon/components/DungeonSpikesZone.gd"
const ICE_ZONE_SCRIPT := "res://scenes/views/view_dungeon/components/DungeonIceZone.gd"
const CLIMB_ZONE_SCRIPT := "res://scenes/views/view_dungeon/components/DungeonClimbZone.gd"

const FLOOR_GAP: float = 0.2  # Separación entre plantas para dar espacio a la losa del suelo (Y=0, Y=3.2, Y=6.4)
## Profundidad del "hueco" de agua/lava (offset de la losa + grosor del líquido).
## Antes era 0.4 — casi el máximo escalón que el jugador puede subir (0.45, ver
## DungeonPlayer.gd), así que el margen para el test de aterrizaje al subir el
## escalón era mínimo y a menudo fallaba: el jugador quedaba atrapado en el
## agua/lava sin poder salir del agujero. Con un hueco más playo hay margen de
## sobra para subir con fiabilidad, sin perder la lectura visual de "hueco".
const LIQUID_PIT_DEPTH: float = 0.18
## Radio (en casillas) de visibilidad de paredes/suelo/props sueltos alrededor del jugador.
const GEOMETRY_CULL_CELLS: float = 32.0
## Task 4 FASE 1.2 — Culling de luces dinámicas (antorchas/braseros/cristales):
## distancia máxima en METROS a la que una luz puede seguir activa y número
## máximo de luces activas SIMULTÁNEAS (se priorizan las más cercanas al
## jugador). El sol direccional (`DirectionalLight3D`) y el `WorldEnvironment`
## nunca se ven afectados por este límite: solo `OmniLight3D` dinámicas creadas
## vía `_add_light()`.
const LIGHT_CULL_RANGE: float = 6.0
const MAX_ACTIVE_LIGHTS: int = 4
## Carpeta ÚNICA de texturas de mazmorra: todo lo que se elija o
## suba como material de suelo/pared vive aquí. Coherente con la jerarquía de
## assets (assets/dungeon/… para mazmorra, assets/world/… para mapamundi, etc.).
const DUNGEON_TEX_DIR := "res://assets/dungeon/textures/"
## Carpeta de modelos decorativos (assets/common/models/decorations/): de aquí
## salen tanto las texturas "sueltas" reutilizadas como pared/suelo de algunas
## temáticas, como los props del auto-scatter de FASE 2.
## Shader de cielo estrellado ligero y limpio (sin nubes pesadas): fondo oscuro + estrellas parpadeantes.
const SIMPLE_STARS_SKY_SHADER: String = """shader_type sky;
void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
	
	// Fondo noche oscura y limpia
	vec3 base = mix(vec3(0.010, 0.012, 0.022), vec3(0.002, 0.003, 0.006), up);
	
	// Estrellas puntuales anti-aliased
	vec2 uv = vec2(atan(d.x, d.z) * 2.0, asin(clamp(d.y, -1.0, 1.0)) * 2.0);
	vec2 g_uv = uv * 36.0;
	vec2 ipos = floor(g_uv);
	vec2 fpos = fract(g_uv);
	
	float h = fract(sin(dot(ipos, vec2(12.9898, 78.233))) * 43758.5453);
	float dist = length(fpos - 0.5);
	
	float star_mask = step(0.982, h);
	float tw = 0.5 + 0.5 * sin(TIME * 2.5 + h * 90.0);
	
	float star = star_mask * (1.0 - smoothstep(0.0, 0.32, dist)) * tw;
	vec3 star_color = vec3(star) * mix(vec3(0.85, 0.92, 1.0), vec3(1.0, 0.95, 0.8), fract(h * 15.0));
	
	COLOR = base + star_color * 1.6;
}
"""

## Shader de cielo del Sendero del Psíquico: noche astral con rayos y arcos eléctricos de energía psíquica morada.
const PSYCHIC_SKY_SHADER: String = """shader_type sky;
void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
	
	// Fondo astral profundo: púrpura cósmico oscuro
	vec3 base = mix(vec3(0.016, 0.005, 0.032), vec3(0.003, 0.001, 0.007), up);
	
	// Rayitos de energía psíquica morados y arcos eléctricos dinámicos
	vec2 uv = vec2(atan(d.x, d.z) * 1.5, asin(clamp(d.y, -1.0, 1.0)) * 2.0);
	float t = TIME * 1.6;
	
	float bolt1 = abs(sin(uv.x * 5.0 + sin(uv.y * 7.0 + t * 2.2) * 1.4 + t));
	float ray1 = pow(1.0 - clamp(bolt1 * 1.3, 0.0, 1.0), 16.0);
	
	float bolt2 = abs(cos(uv.x * 4.0 - cos(uv.y * 5.0 - t * 1.8) * 1.2 - t * 1.2));
	float ray2 = pow(1.0 - clamp(bolt2 * 1.5, 0.0, 1.0), 18.0);
	
	float bolt3 = abs(sin((uv.x * 1.5 + uv.y * 2.0) * 4.0 + sin(t * 2.8) * 0.9));
	float ray3 = pow(1.0 - clamp(bolt3 * 1.6, 0.0, 1.0), 20.0);
	
	vec3 purple_bolt = vec3(0.88, 0.18, 1.0);
	vec3 cyan_spark = vec3(0.25, 0.70, 1.0);
	vec3 magenta_pulse = vec3(1.0, 0.22, 0.75);
	
	vec3 energy_rays = (ray1 * purple_bolt * 2.6) + (ray2 * cyan_spark * 1.5) + (ray3 * magenta_pulse * 2.2);
	
	// Estrellitas sutiles de fondo
	vec2 g_uv = uv * 32.0;
	vec2 ipos = floor(g_uv);
	vec2 fpos = fract(g_uv);
	float h = fract(sin(dot(ipos, vec2(12.9898, 78.233))) * 43758.5453);
	float star_mask = step(0.985, h);
	float tw = 0.5 + 0.5 * sin(TIME * 3.0 + h * 60.0);
	float star = star_mask * (1.0 - smoothstep(0.0, 0.30, length(fpos - 0.5))) * tw;
	vec3 stars = vec3(star) * vec3(0.9, 0.7, 1.0);
	
	COLOR = base + energy_rays + stars;
}
"""

## Task 2 FASE 1: catálogo de temáticas visuales por mazmorra (`data/dungeons/
## <id>.json` → "theme"). Cada entrada define la textura+tinte de superficies,
## la niebla ambiental y (FASE 2) el pool de auto-scatter de esa temática.
## `tex` puede ser "" (sin textura: cae al albedo_color plano, igual que el
## comportamiento histórico sin `tex_cave_wall.png`).
const THEME_CATALOG: Dictionary = {
	"cave": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_cave_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_cave_wall.png",
		"wall_tint": Color(1, 1, 1), "floor_tint": Color(0.62, 0.62, 0.62), "ceiling_tint": Color(0.5, 0.5, 0.5),
		"fog_color": Color(0.10, 0.10, 0.12), "fog_density": 0.06,
		"clutter": [
			{"model": "roca_gastada", "chance": 0.15, "scale_min": 0.14, "scale_max": 0.26},
			{"model": "setas", "chance": 0.15, "scale_min": 0.22, "scale_max": 0.34},
		],
		"corner_decor": [
			{"model": "setas", "chance": 0.5, "scale_min": 0.12, "scale_max": 0.2},
			{"model": "roca_gastada", "chance": 0.5, "scale_min": 0.1, "scale_max": 0.18},
		],
		"decal_color": Color(0.05, 0.06, 0.05, 0.4),
	},
	"ancient_ruins": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_ruins_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_ruins_floor.png",
		"wall_tint": Color(0.95, 0.85, 0.65), "floor_tint": Color(0.6, 0.52, 0.38), "ceiling_tint": Color(0.45, 0.38, 0.28),
		"fog_color": Color(0.35, 0.22, 0.08), "fog_density": 0.02,
		"clutter": [],
		"wall_decor": [
			{"model": "hojas_pared", "chance": 0.6, "scale_min": 0.35, "scale_max": 0.55},
		],
		"corner_decor": [
			{"model": "roca_gastada", "chance": 0.5, "scale_min": 0.12, "scale_max": 0.2},
			{"model": "tronco_caido", "chance": 0.5, "scale_min": 0.16, "scale_max": 0.24},
		],
		"decal_color": Color(0.28, 0.22, 0.1, 0.4),
	},
	"arcanium_lab": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_arcanium_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_arcanium_floor.png",
		"wall_tint": Color(0.85, 0.95, 1.0), "floor_tint": Color(0.7, 0.75, 0.85), "ceiling_tint": Color(0.5, 0.4, 0.6),
		"fog_color": Color(0.25, 0.1, 0.35), "fog_density": 0.035,
		"clutter": [],
		"corner_decor": [],
	},
	"snow_catacomb": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_snow_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_snow_floor.png",
		"wall_tint": Color(0.85, 0.93, 1.0), "floor_tint": Color(0.8, 0.9, 1.0), "ceiling_tint": Color(0.7, 0.8, 0.95),
		"fog_color": Color(0.75, 0.85, 0.95), "fog_density": 0.05,
		"clutter": [
			{"model": "roca_gastada", "chance": 0.15, "scale_min": 0.14, "scale_max": 0.26},
			{"model": "arbol_marchito", "chance": 0.15, "scale_min": 0.35, "scale_max": 0.5},
		],
		"corner_decor": [
			{"model": "roca_gastada", "chance": 1.0, "scale_min": 0.12, "scale_max": 0.2},
		],
		"decal_color": Color(0.85, 0.92, 1.0, 0.45),
	},
	"sand": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_ruins_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_ruins_floor.png",
		"wall_tint": Color(0.82, 0.68, 0.42), "floor_tint": Color(0.76, 0.6, 0.34), "ceiling_tint": Color(0.6, 0.48, 0.3),
		"fog_color": Color(0.7, 0.55, 0.3), "fog_density": 0.03,
		"clutter": [
			{"model": "roca_gastada", "chance": 0.15, "scale_min": 0.14, "scale_max": 0.26},
			{"model": "tronco_caido", "chance": 0.08, "scale_min": 0.3, "scale_max": 0.45},
		],
		"wall_decor": [
			{"model": "hojas_pared", "chance": 0.8, "scale_min": 0.35, "scale_max": 0.5},
		],
		"corner_decor": [
			{"model": "roca_gastada", "chance": 0.6, "scale_min": 0.12, "scale_max": 0.2},
			{"model": "tronco_caido", "chance": 0.4, "scale_min": 0.14, "scale_max": 0.22},
		],
		"decal_color": Color(0.75, 0.6, 0.35, 0.4),
	},
	"temple": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_temple_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_temple_floor.png",
		"wall_tint": Color(1.0, 1.0, 1.0), "floor_tint": Color(0.95, 0.95, 0.95), "ceiling_tint": Color(0.30, 0.25, 0.35),
		"fog_color": Color(0.10, 0.08, 0.15), "fog_density": 0.025,
		"clutter": [],
		"wall_decor": [
			{"model": "hojas_pared", "chance": 1.0, "scale_min": 0.3, "scale_max": 0.45},
		],
		"corner_decor": [
			{"model": "flores_3", "chance": 0.5, "scale_min": 0.14, "scale_max": 0.22},
			{"model": "roca_gastada", "chance": 0.5, "scale_min": 0.1, "scale_max": 0.18},
		],
		"decal_color": Color(0.15, 0.1, 0.05, 0.3),
	},
	"crystal_sanctum": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_crystal_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_crystal_floor.png",
		"wall_tint": Color(1.0, 1.0, 1.0), "floor_tint": Color(1.0, 1.0, 1.0), "ceiling_tint": Color(0.06, 0.03, 0.14),
		"fog_color": Color(0.05, 0.02, 0.10), "fog_density": 0.025,
		"clutter": [],
		"corner_decor": [
			{"model": "flores_4", "chance": 1.0, "scale_min": 0.1, "scale_max": 0.18},
		],
		"decal_color": Color(0.55, 0.2, 0.75, 0.3),
	},
	"magma_caldera": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_magma_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_magma_floor.png",
		"wall_tint": Color(1.0, 1.0, 1.0), "floor_tint": Color(1.0, 1.0, 1.0), "ceiling_tint": Color(0.35, 0.15, 0.1),
		"fog_color": Color(0.25, 0.08, 0.04), "fog_density": 0.035,
		"clutter": [],
		"corner_decor": [
			{"model": "roca_gastada", "chance": 1.0, "scale_min": 0.12, "scale_max": 0.2},
		],
		"decal_color": Color(0.9, 0.3, 0.05, 0.4),
	},
	"overgrown": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_overgrown_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_overgrown_floor.png",
		"wall_tint": Color(1.0, 1.0, 1.0), "floor_tint": Color(1.0, 1.0, 1.0), "ceiling_tint": Color(0.25, 0.35, 0.25),
		"fog_color": Color(0.08, 0.18, 0.1), "fog_density": 0.03,
		"clutter": [],
		"wall_decor": [
			{"model": "hojas_pared", "chance": 0.7, "scale_min": 0.4, "scale_max": 0.6},
		],
		"corner_decor": [
			{"model": "setas", "chance": 0.4, "scale_min": 0.14, "scale_max": 0.22},
			{"model": "flores", "chance": 0.3, "scale_min": 0.12, "scale_max": 0.2},
			{"model": "hierba", "chance": 0.3, "scale_min": 0.16, "scale_max": 0.26},
		],
		"decal_color": Color(0.1, 0.3, 0.08, 0.4),
	},
	"fortress": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_fortress_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_fortress_floor.png",
		"wall_tint": Color(1.0, 1.0, 1.0), "floor_tint": Color(1.0, 1.0, 1.0), "ceiling_tint": Color(0.35, 0.35, 0.4),
		"fog_color": Color(0.12, 0.12, 0.15), "fog_density": 0.03,
		"clutter": [],
		"corner_decor": [
			{"model": "roca_gastada", "chance": 1.0, "scale_min": 0.14, "scale_max": 0.22},
		],
		"decal_color": Color(0.08, 0.08, 0.1, 0.35),
	},
	"sanctuary": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_sanctuary_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_sanctuary_floor.png",
		"wall_tint": Color(1.0, 1.0, 1.0), "floor_tint": Color(1.0, 1.0, 1.0), "ceiling_tint": Color(0.6, 0.55, 0.5),
		"fog_color": Color(0.25, 0.22, 0.18), "fog_density": 0.025,
		"clutter": [],
		"wall_decor": [
			{"model": "hojas_pared", "chance": 1.0, "scale_min": 0.3, "scale_max": 0.45},
		],
		"corner_decor": [
			{"model": "flores_3", "chance": 1.0, "scale_min": 0.14, "scale_max": 0.22},
		],
		"decal_color": Color(0.7, 0.6, 0.4, 0.3),
	},
	"chrono_temple": {
		"tex_wall": DUNGEON_TEX_DIR + "tex_chrono_wall.png",
		"tex_floor": DUNGEON_TEX_DIR + "tex_chrono_floor.png",
		"wall_tint": Color(1.0, 1.0, 1.0), "floor_tint": Color(1.0, 1.0, 1.0), "ceiling_tint": Color(0.03, 0.06, 0.12),
		"fog_color": Color(0.02, 0.05, 0.10), "fog_density": 0.025,
		"clutter": [],
		"corner_decor": [
			{"model": "roca_gastada", "chance": 1.0, "scale_min": 0.12, "scale_max": 0.2},
		],
		"decal_color": Color(0.15, 0.75, 0.80, 0.35),
	},
}

## TASK 3 FASE A: alias de nombres CANÓNICOS (los que usa el documento de diseño
## de atmósfera/scatter) hacia las claves internas ya existentes en
## `THEME_CATALOG`. Puramente cosmético a nivel de vocabulario: no crea datos
## nuevos ni migra los `data/dungeons/<id>.json` existentes (siguen funcionando
## con sus claves de siempre). Mazmorras NUEVAS pueden usar cualquiera de los
## dos nombres indistintamente.
const THEME_ALIASES: Dictionary = {
	"temple_sky": "temple",
	"snow_forest": "snow_catacomb",
	"psychic_path": "crystal_sanctum",
	"desert_ruins": "sand",
}

## Resuelve el `theme` declarado en el JSON de la mazmorra a su entrada real en
## `THEME_CATALOG`, pasando primero por `THEME_ALIASES` si aplica. Si el nombre
## no existe en ninguno de los dos, cae a "cave" (comportamiento histórico).
static func resolve_theme_key(raw_theme: String) -> String:
	var key: String = String(THEME_ALIASES.get(raw_theme, raw_theme))
	return key if THEME_CATALOG.has(key) else "cave"

var _def: Dictionary = {}
var _dungeon_id: String = ""   # event_id de la mazmorra (para claves estables de cofre)
var _cell: float = 3.0
var _wall_h: float = 3.0
var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_ceiling: StandardMaterial3D
var _mat_water: Material
var _mat_poison: Material
## Material de lava: ShaderMaterial animado (tile_lava.png + scroll UV + ondulación).
## Tipo base Material para aceptar ShaderMaterial; comparaciones por referencia siguen
## funcionando igual que antes en if mat == _mat_lava.
var _mat_lava: Material
## GPU de gama baja/móvil (triplanar desactivado en superficies, ver
## _build_materials/_surface_material/_uv_scale_for).
var _is_mobile_gfx: bool = false

## Caches estáticos de shaders de cielo — compilados UNA sola vez por sesión de
## Godot. Evita la recompilación de pipeline en la primera visita a mazmorras
## con cielo generado por código (stars → dun_nieves, psychic → sendero_psiquico).
static var _s_stars_sky_shader: Shader = null
static var _s_psychic_sky_shader: Shader = null
static var _s_void_abyss_shader: Shader = null
static var _s_lava_shader: Shader = null
static var _s_lava_texture: Texture2D = null
static var _s_lava_material: ShaderMaterial = null
static var _s_water_shader: Shader = null
static var _s_water_texture: Texture2D = null
static var _s_water_material: ShaderMaterial = null
static var _s_poison_shader: Shader = null
static var _s_poison_texture: Texture2D = null
static var _s_poison_material: ShaderMaterial = null
static var _s_lava_smoke_mesh: QuadMesh = null
static var _s_lava_smoke_mat: StandardMaterial3D = null
static var _s_lava_smoke_grad: Gradient = null

## Cache estático de materiales de superficie texturizados.
## Clave: "path|kind|tinte". Reutiliza el mismo StandardMaterial3D para celdas que
## comparten tex_key + kind + tinte, reduciendo variantes de pipeline en GPU.
static var _s_surface_mat_cache: Dictionary = {}
static var _s_shared_box_meshes: Dictionary = {}
static var _s_shared_box_shapes: Dictionary = {}
static var _s_tinted_cache: Dictionary = {}

static func _get_shared_box_mesh(size: Vector3) -> BoxMesh:
	var key := size
	if _s_shared_box_meshes.has(key):
		return _s_shared_box_meshes[key]
	var bm := BoxMesh.new()
	bm.size = size
	_s_shared_box_meshes[key] = bm
	return bm

static func _get_shared_box_shape(size: Vector3) -> BoxShape3D:
	var key := size
	if _s_shared_box_shapes.has(key):
		return _s_shared_box_shapes[key]
	var bs := BoxShape3D.new()
	bs.size = size
	_s_shared_box_shapes[key] = bs
	return bs

## Cache estático de la textura decal radial (parámetros idénticos en toda sesión).
## Cache de materiales decal por color de tema: en una mazmorra mono-temática todas
## las celdas decal comparten un único StandardMaterial3D → un único pipeline variant.
static var _s_decal_tex_cache: GradientTexture2D = null
static var _s_decal_mat_cache: Dictionary = {}

## Registro de elementos con estado (puertas/compuertas/luces/interruptores) por
## `eid`, para que los accionadores los enciendan/abran/cierren en tiempo de
## ejecución.
## El `kind` decide qué claves lee `_set_element_state` (ver los `_animate_*`):
##   door   -> { hinge, col, state }                         (gira la bisagra)
##   gate   -> { mesh, col, base_pos, state }                 (se eleva)
##   light  -> { light, base_energy, state }                  (enciende/apaga)
##   lever  -> { visual (pivote), state }                     (gira la caña)
##   button/pressure -> { visual, visual_base, state }        (se hunde)
##   otro (switch de pared) -> { visual, state }               (gira la caja)
var _elements: Dictionary = {}
## Accionadores pendientes de cablear tras construir todas las plantas:
##   [ { "area":Area3D, "targets":Array } ]
var _actuators: Array = []

## Caché de fuentes data-driven para señalética (SystemFont se crea una sola vez).
var _font_cache: Dictionary = {}

## Posición 3D donde debe aparecer el jugador (la calcula build() a partir de spawn).
var spawn_position: Vector3 = Vector3(0.0, 0.5, 0.0)

## Rango dentro del cual los objetos interactivos reciben "resplandor" de feedback.
const _INTERACT_RANGE: float = 4.0
var _pulse_time: float = 0.0

## Caché del nodo del jugador para el culling por distancia (Fase 3,
## task.md): antes se buscaba con `find_child("player", true, false)` — un
## recorrido recursivo de TODO el árbol — en cada frame.
var _player_node_cache: Node3D = null

## Arranques de animación en BUCLE (`create_tween()`) pedidos durante build()
## (antorcha/cristal/gema de ítem/portal de teletransporte…), que TODAVÍA no se
## pueden ejecutar: `create_tween()` exige que el nodo esté ya DENTRO del
## SceneTree, y `build()` se llama desde ViewDungeon ANTES de
## `sub_viewport.add_child(_stage_instance)` (necesita calcular `spawn_position`
## primero). Se encolan aquí como Callable y se vacían en `_ready()`. Bug real
## encontrado en esta auditoría: sin esto, esas animaciones nunca arrancaban
## (fallaban en silencio con un error de Godot) y la mazmorra se sentía más
## "muerta" de lo que el propio código pretendía.
var _current_floor_cells: Array = []
var _pending_tween_setups: Array[Callable] = []
var _floor_containers: Array[Node3D] = []
var _floor_geometry_cache: Dictionary = {}   # floor_index -> Array[Node3D] para evitar get_children() cada 100ms
var _active_portals: Array[Node3D] = []

## Encola (o ejecuta ya, si por lo que sea el nodo ya está en el árbol) el
## arranque de una animación en bucle. Úsalo en vez de llamar a
## `create_tween()` directamente desde cualquier función invocada por build().
func _defer_tween_setup(cb: Callable) -> void:
	if is_inside_tree():
		cb.call()
	else:
		_pending_tween_setups.append(cb)


## Punto de entrada: recibe el layout y construye todo el escenario.
## `dungeon_id` (event_id) permite claves estables de cofre "abierto".
func build(def: Dictionary, dungeon_id: String = "") -> void:
	_def = def
	_dungeon_id = dungeon_id
	_cell = float(def.get("cell_size", 3.0))
	_wall_h = float(def.get("wall_height", 3.0))
	_build_materials()
	_build_environment()
	_identify_boss_teleports(def)
	_active_portals.clear()

	var floors: Array = def.get("floors", [])
	var is_web := OS.has_feature("web")
	for i in range(floors.size()):
		if is_web:
			Juice.set_loading_subtitle(
				Locale.pick({
					"es": "Generando escenario 3D: Planta %d de %d..." % [i + 1, floors.size()],
					"en": "Generating 3D environment: Floor %d of %d..." % [i + 1, floors.size()]
				})
			)
			if is_inside_tree():
				await get_tree().process_frame
		await _build_floor(floors[i], i)

	_build_void_floor(floors)

	if is_web and is_inside_tree():
		Juice.set_loading_subtitle(
			Locale.pick({
				"es": "Optimizando geometría y visibilidad...",
				"en": "Optimizing geometry & visibility..."
			})
		)
		await get_tree().process_frame

	_cache_floor_geometry()
	_wire_actuators()
	_compute_spawn(floors)

	for cb in _pending_tween_setups:
		cb.call()
	_pending_tween_setups.clear()


func _ready() -> void:
	# Si se instancia sin llamar a build() (p. ej. desde el editor), no hace nada.
	if _def.is_empty():
		pass
	# Ahora SÍ estamos dentro del SceneTree: arrancar las animaciones en bucle
	# que build() dejó pendientes (ver `_defer_tween_setup`).
	for cb in _pending_tween_setups:
		cb.call()
	_pending_tween_setups.clear()


var _cull_accum: float = 0.0


func _process(delta: float) -> void:
	_process_flicker_lights(delta)
	_process_portal_facing()
	_cull_accum += delta
	if _cull_accum >= 0.1:
		_process_interactive_highlights(_cull_accum)
		_process_distance_culling()
		_cull_accum = 0.0


func _process_distance_culling() -> void:
	if _player_node_cache == null or not is_instance_valid(_player_node_cache):
		_player_node_cache = find_child("player", true, false) as Node3D
		if _player_node_cache == null:
			return
	var ppos := _player_node_cache.global_position
	var max_dist_sq: float = (GEOMETRY_CULL_CELLS * _cell) * (GEOMETRY_CULL_CELLS * _cell)
	var handled: Dictionary = {}   # root_node -> true; ya resueltos aquí, _process_geometry_culling no los toca
	for eid in _elements.keys():
		var val = _elements[eid]
		var el_list: Array = val if val is Array else [val]
		for el_item in el_list:
			if not (el_item is Dictionary):
				continue
			var el: Dictionary = el_item
			var root_node = el.get("root_node", el.get("node", el.get("mesh", null)))
			if root_node != null and is_instance_valid(root_node) and root_node is Node3D:
				var node_3d := root_node as Node3D
				handled[node_3d] = true
				var in_range: bool = node_3d.global_position.distance_squared_to(ppos) <= max_dist_sq
				if node_3d.visible != in_range:
					node_3d.visible = in_range
					node_3d.set_process(in_range)
	_process_geometry_culling(ppos, handled)
	_process_light_culling(ppos)


## Pre-cachea los nodos de geometría por planta una sola vez al construir el nivel.
func _cache_floor_geometry() -> void:
	_floor_geometry_cache.clear()
	for f_idx in range(_floor_containers.size()):
		var container := _floor_containers[f_idx]
		if not is_instance_valid(container):
			continue
		var list: Array[Node3D] = []
		for child in container.get_children():
			if not (child is Node3D):
				continue
			if child is OmniLight3D or child is Area3D or child is AudioStreamPlayer3D or child is CPUParticles3D or child is WorldEnvironment or child is DirectionalLight3D:
				continue
			if child.name == "Ceiling":
				continue
			list.append(child as Node3D)
		_floor_geometry_cache[f_idx] = list


## task3_rebalanceo FASE5: oculta (visible=false) paredes/suelo/props sueltos de
## la planta a más de 4 casillas del jugador (la colisión NO se ve afectada:
## `visible` es puramente de render, StaticBody3D/CollisionShape3D siguen
## activos). Usa la lista pre-cacheada sin llamar a get_children() repetitivamente.
func _process_geometry_culling(ppos: Vector3, handled: Dictionary) -> void:
	var max_dist_sq: float = (GEOMETRY_CULL_CELLS * _cell) * (GEOMETRY_CULL_CELLS * _cell)
	for f_idx in _floor_geometry_cache.keys():
		var list: Array = _floor_geometry_cache[f_idx]
		var idx := list.size() - 1
		while idx >= 0:
			var node_3d_var: Variant = list[idx]
			if not is_instance_valid(node_3d_var):
				list.remove_at(idx)
				idx -= 1
				continue
			var node_3d := node_3d_var as Node3D
			if node_3d == null or handled.has(node_3d):
				idx -= 1
				continue
			var in_range: bool = node_3d.global_position.distance_squared_to(ppos) <= max_dist_sq
			if node_3d.visible != in_range:
				node_3d.visible = in_range
			idx -= 1


func _process_interactive_highlights(delta: float) -> void:
	if _elements.is_empty():
		return
	_pulse_time += delta
	if _player_node_cache == null or not is_instance_valid(_player_node_cache):
		_player_node_cache = find_child("player", true, false) as Node3D
		if _player_node_cache == null:
			return
	var ppos := _player_node_cache.global_position
	for eid in _elements:
		var val = _elements[eid]
		var el_list: Array = val if val is Array else [val]
		for el_item in el_list:
			if not (el_item is Dictionary):
				continue
			var el: Dictionary = el_item
			var mi = el.get("highlight_mesh", null)
			if not is_instance_valid(mi) or not (mi is MeshInstance3D):
				continue
			var mi_mesh := mi as MeshInstance3D
			var mat := mi_mesh.material_override as StandardMaterial3D
			if mat == null:
				continue
			var base := float(el.get("base_emission", 0.0))
			var base_enabled := bool(el.get("base_emission_enabled", false))
			var dist := mi_mesh.global_position.distance_to(ppos)
			if dist <= _INTERACT_RANGE:
				var pulse := 0.6 + sin(_pulse_time * 4.0) * 0.25
				if not mat.emission_enabled:
					mat.emission_enabled = true
					mat.emission = UiKit.ACCENT
				mat.emission_energy_multiplier = max(base, 0.2) + pulse
				el["highlighted"] = true
			else:
				if el.get("highlighted", false):
					mat.emission_energy_multiplier = base
					mat.emission_enabled = base_enabled
					el["highlighted"] = false


# ══════════════════════════════════════════════════════════════════════════════
# MATERIALES Y ENTORNO
# ══════════════════════════════════════════════════════════════════════════════
## Tematica visual activa de la mazmorra (Task 2 FASE 1). `data/dungeons/<id>.json`
## → "theme": "cave" (por defecto) | "ancient_ruins" | "arcanium_lab" | "snow_catacomb".
var _theme: Dictionary = THEME_CATALOG["cave"]

## Task 4 FASE 5.2 — categoría de superficie del suelo (para variar el SFX de
## pasos, ver `DungeonPlayer.floor_surface_kind`) derivada del TEMA visual de
## la mazmorra: el material de suelo es por DUNGEON, no por celda (ver
## `_build_materials`). Sin entrada explícita, cae a "stone" (piedra/roca,
## el material más común). Los estados "water"/"ice" son por-celda y los
## resuelve el propio `DungeonPlayer` con sus zonas ya existentes.
const THEME_FOOTSTEP_SURFACE: Dictionary = {
	"snow_catacomb": "snow",
	"sand": "sand",
	"arcanium_lab": "metal",
}
func get_floor_surface_kind() -> String:
	return THEME_FOOTSTEP_SURFACE.get(resolve_theme_key(String(_def.get("theme", "cave"))), "stone")


func _build_materials() -> void:
	_theme = THEME_CATALOG[resolve_theme_key(String(_def.get("theme", "cave")))]
	# Textura de la temática: se aplica a PAREDES y TECHO y, con un tinte más
	# oscuro, al suelo, para que las tres superficies se sientan coherentes.
	# Cada celda puede SOBREESCRIBIR su material con `tex` (suelo) o `wall`
	# (pared) apuntando a otra textura (ver _surface_material).
	var tex_wall: Texture2D = null
	var tex_wall_path := String(_def.get("tex_wall", _theme.get("tex_wall", _theme.get("tex", ""))))
	if tex_wall_path != "":
		if not tex_wall_path.begins_with("res://") and not tex_wall_path.begins_with("/"):
			tex_wall_path = DUNGEON_TEX_DIR + tex_wall_path
		if not tex_wall_path.ends_with(".png") and not tex_wall_path.ends_with(".jpg"):
			tex_wall_path += ".png"
		tex_wall = UiKit.load_texture_safe(tex_wall_path)

	var tex_floor: Texture2D = null
	var tex_floor_path := String(_def.get("tex_floor", _theme.get("tex_floor", _theme.get("tex", ""))))
	if tex_floor_path != "":
		if not tex_floor_path.begins_with("res://") and not tex_floor_path.begins_with("/"):
			tex_floor_path = DUNGEON_TEX_DIR + tex_floor_path
		if not tex_floor_path.ends_with(".png") and not tex_floor_path.ends_with(".jpg"):
			tex_floor_path += ".png"
		tex_floor = UiKit.load_texture_safe(tex_floor_path)

	_is_mobile_gfx = OS.has_feature("mobile") or OS.has_feature("web") or OS.has_feature("gl_compatibility") or OS.has_feature("android") or OS.has_feature("ios")

	# NOTA (task_revision.md #2, "texturas horribles" tras la optimización móvil):
	# `uv1_scale` (0.35/0.2/0.3) está calibrado como densidad de repetición POR
	# METRO DE MUNDO para el modo triplanar (uv1_triplanar multiplica la posición
	# de mundo por esa escala antes de proyectar). Con triplanar DESACTIVADO, esa
	# misma escala se aplica en cambio directamente al UV nativo 0..1 de cada cara
	# del BoxMesh — como el valor es << 1, solo se muestrea una franja diminuta de
	# la textura estirada a toda la cara: se ve borrosa/deformada. `_uv_scale_for()`
	# reescala por `_cell`/`_wall_h` (el tamaño real de esa cara) para conservar la
	# MISMA densidad visual sin triplanar, en vez de perder la textura entera.
	_mat_wall = StandardMaterial3D.new()
	if tex_wall:
		_mat_wall.albedo_texture = tex_wall
		_mat_wall.albedo_color = _theme.get("wall_tint", Color(1, 1, 1))
		_mat_wall.uv1_triplanar = true
		_mat_wall.uv1_world_triplanar = true
		_mat_wall.uv1_scale = Vector3(0.35, 0.35, 0.35)
	else:
		_mat_wall.albedo_color = Color(0.42, 0.32, 0.25)
	_mat_wall.roughness = 0.9

	_mat_floor = StandardMaterial3D.new()
	if tex_floor:
		_mat_floor.albedo_texture = tex_floor
		_mat_floor.albedo_color = _theme.get("floor_tint", Color(0.62, 0.62, 0.62))   # tinte oscurecido: distingue el suelo del muro
		_mat_floor.uv1_triplanar = true
		_mat_floor.uv1_world_triplanar = true
		_mat_floor.uv1_scale = Vector3(0.2, 0.2, 0.2)
	else:
		_mat_floor.albedo_color = Color(0.22, 0.24, 0.28)
	_mat_floor.roughness = 0.95

	_mat_ceiling = StandardMaterial3D.new()
	if tex_wall:
		_mat_ceiling.albedo_texture = tex_wall
		_mat_ceiling.albedo_color = _theme.get("ceiling_tint", Color(0.5, 0.5, 0.5))   # más oscuro aún: se aleja de la luz
		_mat_ceiling.uv1_triplanar = true
		_mat_ceiling.uv1_world_triplanar = true
		_mat_ceiling.uv1_scale = Vector3(0.3, 0.3, 0.3)
	else:
		_mat_ceiling.albedo_color = Color(0.16, 0.16, 0.19)
	_mat_ceiling.roughness = 1.0

	_mat_water = _make_water_shader_mat()
	_mat_poison = _make_poison_shader_mat()
	_mat_lava = _make_lava_shader_mat()


static var _s_water_material_deep: ShaderMaterial = null

func _make_water_shader_mat(is_deep: bool = false) -> ShaderMaterial:
	if is_deep and _s_water_material_deep != null:
		return _s_water_material_deep
	if not is_deep and _s_water_material != null:
		return _s_water_material
	if _s_water_shader == null:
		var p := "res://scenes/views/view_dungeon/components/dungeon_water.gdshader"
		if ResourceLoader.exists(p):
			_s_water_shader = load(p) as Shader
	if _s_water_texture == null:
		var tp := "res://assets/dungeon/textures/tile_water_clean.png"
		if ResourceLoader.exists(tp):
			_s_water_texture = load(tp) as Texture2D
	var mat := ShaderMaterial.new()
	if _s_water_shader != null:
		mat.shader = _s_water_shader
	if _s_water_texture != null:
		mat.set_shader_parameter("water_texture", _s_water_texture)
	if is_deep:
		mat.set_shader_parameter("tint", Vector3(0.12, 0.18, 0.38))
		mat.set_shader_parameter("caustic_energy", 0.15)
		mat.set_shader_parameter("caustic_pulse", 0.10)
		mat.set_shader_parameter("caustic_color", Vector3(0.08, 0.20, 0.45))
		_s_water_material_deep = mat
		return _s_water_material_deep
	_s_water_material = mat
	return _s_water_material


func _make_poison_shader_mat() -> ShaderMaterial:
	if _s_poison_material != null:
		return _s_poison_material
	if _s_poison_shader == null:
		var p := "res://scenes/views/view_dungeon/components/dungeon_poison.gdshader"
		if ResourceLoader.exists(p):
			_s_poison_shader = load(p) as Shader
	if _s_poison_texture == null:
		var tp := "res://assets/dungeon/textures/tile_poison_liquid.png"
		if ResourceLoader.exists(tp):
			_s_poison_texture = load(tp) as Texture2D
	var mat := ShaderMaterial.new()
	if _s_poison_shader != null:
		mat.shader = _s_poison_shader
	if _s_poison_texture != null:
		mat.set_shader_parameter("poison_texture", _s_poison_texture)
	_s_poison_material = mat
	return _s_poison_material


func _make_lava_shader_mat() -> ShaderMaterial:
	if _s_lava_material != null:
		return _s_lava_material
	if _s_lava_shader == null:
		var p := "res://scenes/views/view_dungeon/components/dungeon_lava.gdshader"
		if ResourceLoader.exists(p):
			_s_lava_shader = load(p) as Shader
	if _s_lava_texture == null:
		var tp := "res://assets/world/map/tile_lava.png"
		if ResourceLoader.exists(tp):
			_s_lava_texture = load(tp) as Texture2D
	var mat := ShaderMaterial.new()
	if _s_lava_shader != null:
		mat.shader = _s_lava_shader
	if _s_lava_texture != null:
		mat.set_shader_parameter("lava_texture", _s_lava_texture)
	_s_lava_material = mat
	return _s_lava_material


func _create_lava_smoke_particles(cs: float) -> CPUParticles3D:
	if _s_lava_smoke_mesh == null:
		var qm := QuadMesh.new()
		qm.size = Vector2(cs * 0.08, cs * 0.08)
		_s_lava_smoke_mesh = qm

	if _s_lava_smoke_mat == null:
		var sm := StandardMaterial3D.new()
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.vertex_color_use_as_albedo = true
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_s_lava_smoke_mat = sm
		_s_lava_smoke_mesh.material = _s_lava_smoke_mat

	if _s_lava_smoke_grad == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.9, 0.3, 0.95))
		grad.add_point(0.45, Color(1.0, 0.42, 0.06, 0.75))
		grad.set_color(1, Color(0.7, 0.1, 0.0, 0.0))
		_s_lava_smoke_grad = grad

	var p := CPUParticles3D.new()
	p.name = "LavaSmoke"
	p.amount = 12
	p.lifetime = 1.6
	p.preprocess = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(cs * 0.4, 0.02, cs * 0.4)
	p.direction = Vector3(0, 1, 0)
	p.spread = 15.0
	p.gravity = Vector3(0, cs * 0.3, 0)
	p.initial_velocity_min = cs * 0.1
	p.initial_velocity_max = cs * 0.35
	p.scale_amount_min = cs * 0.035
	p.scale_amount_max = cs * 0.085
	p.mesh = _s_lava_smoke_mesh
	p.color_ramp = _s_lava_smoke_grad
	return p


func _build_environment() -> void:
	# Iluminación base DATA-DRIVEN con valores por defecto luminosos: una mazmorra
	# creada en el editor SIEMPRE debe verse (aunque no se coloquen casillas "light").
	var amb_energy: float = float(_def.get("ambient_energy", 1.2))
	var amb_parsed = _parse_color(_def.get("ambient_color", ""))
	var amb_color: Color = amb_parsed if amb_parsed is Color else Color(0.55, 0.55, 0.62)
	var env := Environment.new()

	# Selección de cielo:
	#   · Por defecto: desactivado (BG_COLOR oscuro sobrio).
	#   · "night_sky": cielo volumétrico completo (dun_inicial).
	#   · "stars" / "simple_stars": cielo nocturno limpio con estrellas procedimentales ligeras (dun_nieves).
	var raw_sky = _def.get("sky", "")
	var sky_choice: String = ""
	if raw_sky is String:
		sky_choice = raw_sky.to_lower()
	elif raw_sky is bool:
		sky_choice = "night_sky" if raw_sky else ""
	else:
		sky_choice = str(raw_sky).to_lower()

	var d_id: String = str(_def.get("id", ""))
	var raw_name = _def.get("name", "")
	var d_name: String = ""
	if raw_name is String:
		d_name = raw_name
	elif raw_name is Dictionary:
		d_name = str(raw_name.get("es", raw_name.get("en", "")))
	else:
		d_name = str(raw_name)

	if sky_choice == "" and (d_id == "dun_inicial" or d_name.contains("Esfera")):
		sky_choice = "night_sky"
	elif sky_choice == "" and d_id == "dun_nieves":
		sky_choice = "stars"

	# TASK 3: si la mazmorra no fija "sky" explícitamente, el TEMA resuelto ya
	# sugiere un cielo canónico por defecto (ver catálogo de perfiles del doc de
	# diseño). No sobreescribe nunca un "sky" ya declarado en el JSON.
	if sky_choice == "":
		var resolved_theme_key: String = resolve_theme_key(String(_def.get("theme", "cave")))
		match resolved_theme_key:
			"snow_catacomb":
				sky_choice = "stars"
			"crystal_sanctum":
				sky_choice = "psychic"

	if sky_choice == "night_sky":
		var is_mobile: bool = OS.has_feature("mobile") or OS.has_feature("web") or OS.has_feature("gl_compatibility") or OS.has_feature("android") or OS.has_feature("ios")
		var sky_res_path := "res://assets/dungeon/sky/examples/night_sky.tres"
		if ResourceLoader.exists(sky_res_path):
			var sky_obj := Sky.new()
			var sky_mat = load(sky_res_path)
			if sky_mat is ShaderMaterial:
				if is_mobile:
					sky_mat = (sky_mat as ShaderMaterial).duplicate()
					sky_mat.set_shader_parameter("clouds_density", 0.0)
					# Task 4 FASE 1.1: `clouds_density=0.0` ya oculta las nubes, pero el
					# bucle de raymarching (`cloud_ray_march`, ejecutado en el half-res
					# pass) sigue corriendo `clouds_samples` iteraciones completas
					# aunque el resultado sea invisible. Bajarlo a 12 (frente a las 32
					# de PC) recupera ese coste de GPU desperdiciado en móvil.
					sky_mat.set_shader_parameter("clouds_samples", 12)
				sky_obj.sky_material = sky_mat
				env.background_mode = Environment.BG_SKY
				env.sky = sky_obj
	elif sky_choice in ["psychic", "psiquico", "astral", "rayos", "purple_sky"] or d_id == "sendero_psiquico":
		var sky_obj := Sky.new()
		# Shader cacheado estáticamente: se compila solo la primera vez que se entra
		# a una mazmorra psíquica; las visitas siguientes reutilizan el mismo objeto.
		if _s_psychic_sky_shader == null:
			var psychic_path := "res://assets/dungeon/sky/psychic_sky.gdshader"
			if ResourceLoader.exists(psychic_path):
				_s_psychic_sky_shader = load(psychic_path) as Shader
			if _s_psychic_sky_shader == null:
				_s_psychic_sky_shader = Shader.new()
				_s_psychic_sky_shader.code = PSYCHIC_SKY_SHADER
		var sky_mat := ShaderMaterial.new()
		sky_mat.shader = _s_psychic_sky_shader
		sky_obj.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky_obj
	elif sky_choice in ["stars", "simple_stars", "noche"]:
		var sky_obj := Sky.new()
		# Shader cacheado estáticamente: evita recompilar el pipeline en la primera
		# visita a dun_nieves (o cualquier mazmorra con sky = "stars").
		if _s_stars_sky_shader == null:
			var stars_path := "res://assets/dungeon/sky/simple_stars_sky.gdshader"
			if ResourceLoader.exists(stars_path):
				_s_stars_sky_shader = load(stars_path) as Shader
			if _s_stars_sky_shader == null:
				_s_stars_sky_shader = Shader.new()
				_s_stars_sky_shader.code = SIMPLE_STARS_SKY_SHADER
		var sky_mat := ShaderMaterial.new()
		sky_mat.shader = _s_stars_sky_shader
		sky_obj.sky_material = sky_mat
		env.background_mode = Environment.BG_SKY
		env.sky = sky_obj
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.02, 0.05)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = amb_color
	env.ambient_light_energy = amb_energy
	var fog_val = _def.get("fog", false)
	var fog_on: bool = false
	if fog_val is bool:
		fog_on = fog_val
	elif fog_val is Dictionary:
		fog_on = bool(fog_val.get("enabled", true))
	elif fog_val is int or fog_val is float:
		fog_on = fog_val > 0
	elif fog_val is String:
		fog_on = fog_val.to_lower() == "true" or fog_val == "1"
	env.fog_enabled = fog_on

	var fog_col_raw = _def.get("fog_color", "")
	if fog_val is Dictionary and fog_val.has("color"):
		fog_col_raw = fog_val["color"]
	var fog_color_parsed = _parse_color(fog_col_raw)
	env.fog_light_color = fog_color_parsed if fog_color_parsed is Color else _theme.get("fog_color", Color(0.10, 0.10, 0.12))

	var fog_dens_raw = _def.get("fog_density", null)
	if fog_val is Dictionary and fog_val.has("density"):
		fog_dens_raw = fog_val["density"]
	env.fog_density = float(fog_dens_raw if fog_dens_raw != null else _theme.get("fog_density", 0.02))
	env.fog_sky_affect = float(_def.get("fog_sky_affect", 0.0))
	if d_id == "dun_nieves" or _def.get("id", "") == "dun_nieves":
		env.fog_enabled = true
		env.fog_light_color = Color(0.88, 0.92, 0.96)
		env.fog_density = 0.14
		env.fog_sky_affect = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Luz cenital de relleno (sol) para dar volumen y garantizar visibilidad.
	var fill: float = float(_def.get("fill_light", 0.9))
	if fill > 0.0:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
		sun.light_energy = fill
		sun.light_color = Color(1.0, 0.97, 0.9)
		sun.shadow_enabled = true
		add_child(sun)


# ══════════════════════════════════════════════════════════════════════════════
# FONDO DE VACÍO / FOSO BAJO LA PLANTA MÁS BAJA
# ══════════════════════════════════════════════════════════════════════════════

## Construye el fondo visual de foso/vacío bajo la planta más baja (Y = -2.4).
## Opciones ("void_type"): "none", "lava", "spikes", "abyss".
func _build_void_floor(floors: Array) -> void:
	var void_type := String(_def.get("void_type", "")).strip_edges().to_lower()
	if void_type == "none":
		return
	if void_type == "":
		var theme_key := resolve_theme_key(String(_def.get("theme", "cave")))
		if theme_key == "magma_caldera":
			void_type = "lava"
		elif theme_key == "psychic_path":
			void_type = "abyss"
		else:
			return

	if floors.is_empty():
		return

	var max_w: int = 1
	var max_h: int = 1
	for fl in floors:
		if fl is Dictionary:
			max_w = maxi(max_w, int(fl.get("w", 1)))
			max_h = maxi(max_h, int(fl.get("h", 1)))

	var center_x: float = float(max_w - 1) * _cell * 0.5
	var center_z: float = float(max_h - 1) * _cell * 0.5
	var span_x: float = maxf(float(max_w) * _cell + 100.0, 180.0)
	var span_z: float = maxf(float(max_h) * _cell + 100.0, 180.0)
	var void_y: float = -2.4

	var void_root := Node3D.new()
	void_root.name = "VoidFloor"
	void_root.position = Vector3(center_x, void_y, center_z)
	add_child(void_root)

	match void_type:
		"lava":
			_build_void_lava(void_root, span_x, span_z, max_w, max_h)
		"spikes":
			_build_void_spikes(void_root, span_x, span_z, max_w, max_h)
		"abyss", "vacio", "void":
			_build_void_abyss(void_root, span_x, span_z, max_w, max_h)


func _build_void_lava(root: Node3D, sx: float, sz: float, max_w: int, max_h: int) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(sx, sz)
	plane.subdivide_width = 36
	plane.subdivide_depth = 36
	mi.mesh = plane

	# Usar exactamente el mismo material con shader continuo y textura tile_lava.png que dun_inicial
	mi.material_override = _make_lava_shader_mat()
	root.add_child(mi)

	# Luz ambiental cálida que baña los muros del foso desde abajo
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.2, 0.0)
	light.light_color = Color(1.0, 0.45, 0.12)
	light.light_energy = 2.4
	light.omni_range = maxf(sx, sz) * 0.6
	light.shadow_enabled = false
	root.add_child(light)

	# Humos y ascuas de magma idénticos a los de las celdas de lava vivas
	if not Locale.reduce_motion:
		if _s_lava_smoke_mesh == null:
			var qm := QuadMesh.new()
			qm.size = Vector2(_cell * 0.08, _cell * 0.08)
			_s_lava_smoke_mesh = qm

		if _s_lava_smoke_mat == null:
			var sm := StandardMaterial3D.new()
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.vertex_color_use_as_albedo = true
			sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			_s_lava_smoke_mat = sm
			_s_lava_smoke_mesh.material = _s_lava_smoke_mat

		if _s_lava_smoke_grad == null:
			var grad := Gradient.new()
			grad.set_color(0, Color(1.0, 0.9, 0.3, 0.95))
			grad.add_point(0.45, Color(1.0, 0.42, 0.06, 0.75))
			grad.set_color(1, Color(0.7, 0.1, 0.0, 0.0))
			_s_lava_smoke_grad = grad

		var smoke := CPUParticles3D.new()
		smoke.name = "VoidLavaSmoke"
		smoke.amount = 64
		smoke.lifetime = 2.2
		smoke.preprocess = 1.0
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		smoke.emission_box_extents = Vector3(float(max_w) * _cell * 0.5 + 8.0, 0.2, float(max_h) * _cell * 0.5 + 8.0)
		smoke.direction = Vector3(0, 1, 0)
		smoke.spread = 15.0
		smoke.gravity = Vector3(0, _cell * 0.25, 0)
		smoke.initial_velocity_min = _cell * 0.1
		smoke.initial_velocity_max = _cell * 0.35
		smoke.scale_amount_min = _cell * 0.04
		smoke.scale_amount_max = _cell * 0.09
		smoke.mesh = _s_lava_smoke_mesh
		smoke.color_ramp = _s_lava_smoke_grad
		smoke.position = Vector3(0.0, 0.2, 0.0)
		root.add_child(smoke)


func _build_void_spikes(root: Node3D, sx: float, sz: float, max_w: int, max_h: int) -> void:
	# 1. Base rocosa oscura
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(sx, sz)
	mi.mesh = plane
	var pit_mat := StandardMaterial3D.new()
	pit_mat.albedo_color = Color(0.08, 0.08, 0.09)
	pit_mat.roughness = 0.95
	mi.material_override = pit_mat
	root.add_child(mi)

	# 2. Lecho denso de pinchos metálicos usando MultiMeshInstance3D
	var dungeon_w: float = float(max_w) * _cell + 16.0
	var dungeon_h: float = float(max_h) * _cell + 16.0
	var spacing: float = 0.75
	var count_x: int = int(ceil(dungeon_w / spacing))
	var count_z: int = int(ceil(dungeon_h / spacing))
	var total_spikes: int = count_x * count_z
	if total_spikes > 4000:
		total_spikes = 4000
		spacing = sqrt((dungeon_w * dungeon_h) / float(total_spikes))
		count_x = int(ceil(dungeon_w / spacing))
		count_z = int(ceil(dungeon_h / spacing))

	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count_x * count_z

	var cone := CylinderMesh.new()
	cone.top_radius = 0.015
	cone.bottom_radius = 0.12
	cone.height = 0.7
	cone.radial_segments = 6

	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.38, 0.36, 0.36)
	spike_mat.metallic = 0.85
	spike_mat.roughness = 0.28
	mm.mesh = cone

	var start_x: float = -float(count_x - 1) * spacing * 0.5
	var start_z: float = -float(count_z - 1) * spacing * 0.5
	var idx: int = 0
	for iz in range(count_z):
		for ix in range(count_x):
			var px: float = start_x + float(ix) * spacing + sin(float(ix * 13 + iz * 7)) * 0.12
			var pz: float = start_z + float(iz) * spacing + cos(float(ix * 7 + iz * 13)) * 0.12
			var py: float = 0.35 + sin(float(ix * 3 + iz * 5)) * 0.08
			var t := Transform3D()
			var rot_y: float = float((ix * 37 + iz * 19) % 360) * 0.0174533
			var tilt_x: float = sin(float(ix * 11 + iz * 17)) * 0.1
			var tilt_z: float = cos(float(ix * 17 + iz * 11)) * 0.1
			t.basis = Basis(Vector3.UP, rot_y) * Basis(Vector3.RIGHT, tilt_x) * Basis(Vector3.FORWARD, tilt_z)
			t.origin = Vector3(px, py, pz)
			mm.set_instance_transform(idx, t)
			idx += 1

	mmi.multimesh = mm
	mmi.material_override = spike_mat
	root.add_child(mmi)

	# Luz fría y tenue en los pinchos
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.2, 0.0)
	light.light_color = Color(0.65, 0.72, 0.85)
	light.light_energy = 1.0
	light.omni_range = maxf(sx, sz) * 0.5
	light.shadow_enabled = false
	root.add_child(light)


func _build_void_abyss(root: Node3D, sx: float, sz: float, max_w: int, max_h: int) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(sx, sz)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	mi.mesh = plane

	if _s_void_abyss_shader == null:
		var p := "res://assets/dungeon/shaders/void_abyss.gdshader"
		if ResourceLoader.exists(p):
			_s_void_abyss_shader = load(p) as Shader
	if _s_void_abyss_shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = _s_void_abyss_shader
		mi.material_override = mat
	else:
		var fallback_mat := StandardMaterial3D.new()
		fallback_mat.albedo_color = Color(0.02, 0.01, 0.04)
		mi.material_override = fallback_mat

	root.add_child(mi)

	# Luz misteriosa etérea violeta/azulada ascendente
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.5, 0.0)
	light.light_color = Color(0.45, 0.25, 0.85)
	light.light_energy = 1.8
	light.omni_range = maxf(sx, sz) * 0.6
	light.shadow_enabled = false
	root.add_child(light)

	# Motas astrales / polvo estelar suspendido en el abismo
	if not Locale.reduce_motion:
		var motes := CPUParticles3D.new()
		motes.name = "AbyssMotes"
		motes.amount = 35
		motes.lifetime = 5.0
		motes.preprocess = 2.5
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		motes.emission_box_extents = Vector3(float(max_w) * _cell * 0.5 + 8.0, 0.6, float(max_h) * _cell * 0.5 + 8.0)
		motes.direction = Vector3.UP
		motes.spread = 180.0
		motes.gravity = Vector3(0.0, 0.04, 0.0)
		motes.initial_velocity_min = 0.1
		motes.initial_velocity_max = 0.45
		motes.scale_amount_min = 0.02
		motes.scale_amount_max = 0.05
		var sm := SphereMesh.new()
		sm.radius = 0.03
		sm.height = 0.06
		motes.mesh = sm
		var motes_mat := StandardMaterial3D.new()
		motes_mat.albedo_color = Color(0.3, 0.85, 1.0, 0.8)
		motes_mat.emission_enabled = true
		motes_mat.emission = Color(0.2, 0.7, 1.0)
		motes_mat.emission_energy_multiplier = 3.5
		motes_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		motes.material_override = motes_mat
		root.add_child(motes)


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE UNA PLANTA
# ══════════════════════════════════════════════════════════════════════════════
func _build_floor(fl: Dictionary, index: int) -> void:
	var cells: Array = fl.get("cells", [])
	_current_floor_cells = cells
	var h: int = int(fl.get("h", cells.size()))
	var base_y: float = float(index) * (_wall_h + FLOOR_GAP)

	var container := Node3D.new()
	container.name = "Floor%d" % index
	container.position = Vector3(0.0, base_y, 0.0)
	add_child(container)
	_floor_containers.append(container)

	var is_web := OS.has_feature("web")
	for y in range(h):
		if y >= cells.size():
			continue
		var row: Array = cells[y]
		for x in range(row.size()):
			var cell = row[x]
			if cell is Dictionary:
				_build_cell(container, cell, x, y, index)
		if is_web and is_inside_tree() and (y % 3 == 0):
			await get_tree().process_frame

	# Techo opcional (cuevas): una losa de roca que cubre TODA la planta a la altura
	# del muro, para que el escenario se sienta cerrado (interior de cueva). Se activa
	# con `def.ceiling = true`. La geometría cubre el rango completo de la rejilla.
	var w: int = int(fl.get("w", (cells[0] as Array).size() if cells.size() > 0 else 0))
	if bool(_def.get("ceiling", false)):
		_add_ceiling(container, w, h)

	# Partículas ambientales: NUNCA en mazmorras con techo ni por defecto. Solo si se solicita explícitamente en el JSON (ambient_dust: true) y está a cielo abierto.
	var has_ceiling: bool = bool(_def.get("ceiling", false))
	var allow_ambient_dust: bool = bool(_def.get("ambient_dust", false)) and not has_ceiling
	if allow_ambient_dust and not Locale.reduce_motion:
		_add_ambient_dust(container, w, h)


## Losa de techo que cubre toda la planta (w x h casillas) a la altura del muro.
func _add_ceiling(container: Node3D, w: int, h: int) -> void:
	if w <= 0 or h <= 0:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(float(w) * _cell, 0.6, float(h) * _cell)
	mi.mesh = box
	# Los centros de casilla están en (gx*_cell, gy*_cell); el techo se centra sobre
	# el rango [0..(w-1)]*_cell y se apoya justo encima de los muros (_wall_h).
	mi.position = Vector3(float(w - 1) * _cell * 0.5, _wall_h + 0.3, float(h - 1) * _cell * 0.5)
	mi.material_override = _mat_ceiling
	mi.name = "Ceiling"   # excluido del culling por distancia: es una losa única para toda la planta
	container.add_child(mi)


## Motas de polvo ambientales muy sutiles y dispersas por toda la planta
## (ideas.md #6) — una sola CPUParticles3D barata que cubre el rectángulo de
## la rejilla, igual de barata que las luciérnagas/motas del mapamundi.
func _add_ambient_dust(container: Node3D, w: int, h: int) -> void:
	if w <= 0 or h <= 0:
		return
	var dust := CPUParticles3D.new()
	dust.name = "AmbientDust"
	dust.amount = clampi(int(w * h * 0.6), 8, 40)
	dust.lifetime = 6.0
	dust.preprocess = 3.0
	dust.randomness = 0.8
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.gravity = Vector3(0.0, 0.01, 0.0)
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.08
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(float(w) * _cell * 0.5, _wall_h * 0.4, float(h) * _cell * 0.5)
	dust.position = Vector3(float(w - 1) * _cell * 0.5, _wall_h * 0.5, float(h - 1) * _cell * 0.5)
	dust.scale_amount_min = 0.015
	dust.scale_amount_max = 0.035
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.02
	dust_mesh.height = 0.04
	dust.mesh = dust_mesh
	var dust_mat := StandardMaterial3D.new()
	dust_mat.albedo_color = Color(0.85, 0.8, 0.7, 0.35)
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust.material_override = dust_mat
	container.add_child(dust)


func _build_cell(container: Node3D, cell: Dictionary, gx: int, gy: int, floor_index: int = 0) -> void:
	cell["gx"] = gx
	cell["gy"] = gy
	var t := String(cell.get("t", "void"))
	if t == "void":
		return

	var cx: float = float(gx) * _cell
	var cz: float = float(gy) * _cell
	var center := Vector3(cx, 0.0, cz)
	# Tinte EFECTIVO de la superficie: color explícito de la celda, o el color base
	# del material elegido (tex de suelo / wall de pared). Así "material del suelo"
	# y "material de la pared" del editor tienen efecto visual real.
	var tint = _surface_tint(cell)

	# Casillas COSMÉTICAS simples (suelo/pared/líquido/pincho/luz/vacío): la
	# geometría concreta viene del catálogo data-driven `data/dungeon_tiles/<t>.json`
	# (ver Design.get_dungeon_tile_render / _build_generic). Si el catálogo no
	# trae `render` para el tipo (p. ej. fichero borrado), cae al código de
	# siempre como red de seguridad, así que nunca se rompe una mazmorra existente.
	match t:
		"wall":
			if not _build_generic(container, center, cell, tint, Design.get_dungeon_tile_render(t)):
				_add_floor_slab(container, center, tint)
				_add_wall_block(container, center, _cell_height(cell), tint, cell.get("col", true) != false, String(cell.get("wall", "")))
			_apply_wall_decor(container, center, cell, floor_index)
		"climb_wall":
			# Muro escalable (idea.md §1.1): bloque SÓLIDO idéntico a "wall" en
			# colisión (bloquea el paso normal), con una franja de Area3D
			# adosada a su cara ABIERTA — definida por "dir"/"facing"/"rot",
			# MISMA convención de orientación que el resto de props/decoración
			# (`_resolve_rotation_degrees`) — que activa el modo de escalada
			# del jugador (`DungeonClimbZone.gd` → `DungeonPlayer.set_climbing`).
			_add_floor_slab(container, center, tint)
			var climb_h := _cell_height(cell)
			_add_wall_block(container, center, climb_h, tint, true, String(cell.get("wall", "")), "climb_wall")
			var climb_rot := _resolve_rotation_degrees(cell)
			var climb_outward: Vector3 = Basis(Vector3.UP, deg_to_rad(climb_rot)) * Vector3(0, 0, -1)
			var climb_area := Area3D.new()
			climb_area.collision_mask = 2
			climb_area.position = center + climb_outward * (_cell * 0.5) + Vector3(0, climb_h * 0.5, 0)
			climb_area.rotation.y = deg_to_rad(climb_rot)
			if ResourceLoader.exists(CLIMB_ZONE_SCRIPT):
				climb_area.set_script(load(CLIMB_ZONE_SCRIPT))
			container.add_child(climb_area)
			var climb_col := CollisionShape3D.new()
			var climb_shape := BoxShape3D.new()
			# Profundidad (eje Z local, ya alineado con climb_outward por la
			# rotación del propio Area3D) a caballo entre dentro y fuera del
			# muro: detecta al jugador tanto acercándose como ya pegado a él.
			climb_shape.size = Vector3(_cell * 0.9, climb_h * 0.95, 1.0)
			climb_col.shape = climb_shape
			climb_area.add_child(climb_col)
		"floor", "bridge":
			if not _build_generic(container, center, cell, tint, Design.get_dungeon_tile_render(t)):
				_add_floor_slab(container, center, tint, String(cell.get("tex", "")))
			if t == "floor":
				_add_floor_clutter(container, center, cell)
				_apply_corner_decor(container, center, cell, floor_index)
				_apply_floor_decal(container, center, cell, floor_index)
		"stairs", "ramp", "escalera_con_muros":
			_add_floor_slab(container, center, tint)
			_add_ramp(container, center, cell)
		"hojas_pared":
			_add_floor_slab(container, center, tint)
			_add_decor_prop(container, center, cell, "hojas_pared")
		"door":
			_add_floor_slab(container, center, tint)
			var door_kind := String(cell.get("kind", "door"))
			if door_kind == "gate":
				_add_gate(container, center, cell)
			else:
				_add_door(container, center, cell)
		"water":
			if not _build_generic(container, center, cell, tint, Design.get_dungeon_tile_render(t)):
				_add_floor_slab(container, center + Vector3(0, -LIQUID_PIT_DEPTH, 0), tint)
				var is_poisoned: bool = cell.get("poisoned", false) or cell.get("hazard", "") == "poison"
				var w_mat: Material = _make_poison_shader_mat() if is_poisoned else _make_water_shader_mat()
				# Corriente de agua direccional (idea.md §1.2, opcional por celda):
				# "current_dir": [dx, dz] (se normaliza) + "current_speed" (u/s).
				var current_vec := Vector3.ZERO
				var current_dir = cell.get("current_dir", null)
				if current_dir is Array and current_dir.size() >= 2:
					var raw := Vector3(float(current_dir[0]), 0.0, float(current_dir[1]))
					if raw.length() > 0.001:
						current_vec = raw.normalized() * float(cell.get("current_speed", 2.5))
				var w_node := _add_liquid(container, center, w_mat, WATER_ZONE_SCRIPT, LIQUID_PIT_DEPTH, current_vec)
				if w_node != null:
					w_node.set_meta("is_poisoned", is_poisoned)
					if is_poisoned:
						var p_light := OmniLight3D.new()
						p_light.light_color = Color(0.25, 0.95, 0.35)
						p_light.light_energy = 0.9
						p_light.omni_range = _cell * 1.4
						p_light.position = center + Vector3(0, 0.1, 0)
						container.add_child(p_light)

						var p_parts := CPUParticles3D.new()
						p_parts.amount = 12
						p_parts.lifetime = 1.8
						p_parts.direction = Vector3.UP
						p_parts.spread = 20.0
						p_parts.gravity = Vector3(0, 0.4, 0)
						p_parts.initial_velocity_min = 0.15
						p_parts.initial_velocity_max = 0.4
						p_parts.color = Color(0.35, 1.0, 0.4, 0.75)
						var sp := SphereMesh.new()
						sp.radius = 0.035
						sp.height = 0.07
						p_parts.mesh = sp
						var pmat := StandardMaterial3D.new()
						pmat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
						pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						pmat.albedo_color = Color(0.35, 1.0, 0.4, 0.7)
						p_parts.material_override = pmat
						p_parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
						p_parts.emission_box_extents = Vector3(_cell * 0.4, 0.05, _cell * 0.4)
						p_parts.position = center + Vector3(0, 0.05, 0)
						container.add_child(p_parts)
					else:
						var w_light := OmniLight3D.new()
						w_light.light_color = Color(0.35, 0.85, 1.0)
						w_light.light_energy = 0.75
						w_light.omni_range = _cell * 1.4
						w_light.position = center + Vector3(0, 0.1, 0)
						container.add_child(w_light)

						var w_parts := CPUParticles3D.new()
						w_parts.amount = 8
						w_parts.lifetime = 2.0
						w_parts.direction = Vector3.UP
						w_parts.spread = 15.0
						w_parts.gravity = Vector3(0, 0.25, 0)
						w_parts.initial_velocity_min = 0.1
						w_parts.initial_velocity_max = 0.3
						w_parts.scale_amount_min = 0.3
						w_parts.scale_amount_max = 0.7
						var wp_mesh := SphereMesh.new()
						wp_mesh.radius = 0.03
						wp_mesh.height = 0.06
						w_parts.mesh = wp_mesh
						var wp_mat := StandardMaterial3D.new()
						wp_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
						wp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						wp_mat.albedo_color = Color(0.6, 0.9, 1.0, 0.7)
						w_parts.material_override = wp_mat
						w_parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
						w_parts.emission_box_extents = Vector3(_cell * 0.4, 0.05, _cell * 0.4)
						w_parts.position = center + Vector3(0, 0.05, 0)
						container.add_child(w_parts)
		"ice_floor":
			# Suelo de hielo deslizante (idea.md §1.2): a diferencia de "ice_block"
			# (obstáculo sólido), esta es una losa PISABLE con fricción casi nula
			# (`DungeonIceZone.gd` -> `DungeonPlayer.set_on_ice`).
			_add_floor_slab(container, center, tint)
			var ice_floor_visual := MeshInstance3D.new()
			var ice_floor_plane := BoxMesh.new()
			ice_floor_plane.size = Vector3(_cell, 0.05, _cell)
			ice_floor_visual.mesh = ice_floor_plane
			var ice_floor_mat := StandardMaterial3D.new()
			ice_floor_mat.albedo_color = Color(0.75, 0.92, 1.0, 0.75)
			ice_floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ice_floor_mat.roughness = 0.05
			ice_floor_mat.metallic = 0.2
			ice_floor_visual.material_override = ice_floor_mat
			ice_floor_visual.position = center + Vector3(0, 0.03, 0)
			container.add_child(ice_floor_visual)

			var ice_area := Area3D.new()
			ice_area.collision_mask = 2
			ice_area.position = center + Vector3(0, 0.4, 0)
			if ResourceLoader.exists(ICE_ZONE_SCRIPT):
				ice_area.set_script(load(ICE_ZONE_SCRIPT))
			container.add_child(ice_area)
			var ice_col := CollisionShape3D.new()
			var ice_area_shape := BoxShape3D.new()
			ice_area_shape.size = Vector3(_cell, 0.8, _cell)
			ice_col.shape = ice_area_shape
			ice_area.add_child(ice_col)
		"ice_block":
			_add_floor_slab(container, center, tint)
			var ice_mat := StandardMaterial3D.new()
			ice_mat.albedo_color = Color(0.70, 0.90, 1.0, 0.65)
			ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ice_mat.roughness = 0.05
			ice_mat.metallic = 0.15
			ice_mat.emission_enabled = true
			ice_mat.emission = Color(0.25, 0.65, 0.95)
			ice_mat.emission_energy_multiplier = 0.35

			var ice_inner_mat := StandardMaterial3D.new()
			ice_inner_mat.albedo_color = Color(0.85, 0.96, 1.0, 0.55)
			ice_inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ice_inner_mat.roughness = 0.1
			ice_inner_mat.emission_enabled = true
			ice_inner_mat.emission = Color(0.5, 0.85, 1.0)
			ice_inner_mat.emission_energy_multiplier = 0.6

			# Bloque exterior de hielo translúcido
			var ice_box := CSGBox3D.new()
			ice_box.size = Vector3(_cell * 0.96, _wall_h, _cell * 0.96)
			ice_box.position = center + Vector3(0, _wall_h / 2.0, 0)
			ice_box.material = ice_mat
			container.add_child(ice_box)

			# Núcleo interior escarchado
			var ice_core := CSGBox3D.new()
			ice_core.size = Vector3(_cell * 0.72, _wall_h * 0.88, _cell * 0.72)
			ice_core.position = center + Vector3(0, _wall_h / 2.0, 0)
			ice_core.material = ice_inner_mat
			container.add_child(ice_core)

			# Agujas / Crestas de hielo en la parte superior
			for sx in [-0.28, 0.28]:
				for sz in [-0.28, 0.28]:
					var spike := MeshInstance3D.new()
					var sm := PrismMesh.new()
					sm.size = Vector3(_cell * 0.26, 0.45, _cell * 0.26)
					spike.mesh = sm
					spike.material_override = ice_mat
					spike.position = center + Vector3(sx * _cell, _wall_h + 0.18, sz * _cell)
					spike.rotation_degrees = Vector3(randf_range(-10, 10), randf_range(0, 180), randf_range(-10, 10))
					container.add_child(spike)
		"moving_platform", "elevator":
			_add_floor_slab(container, center, tint)
			# "elevator"/"moving_platform" son alias distintos (ver ModelLoader.ALIASES)
			# de dos maquetas .tscn separadas: se elige la que corresponda a `t`.
			var plat_default := "ascensor" if t == "elevator" else "plataforma_movil"
			var plat_model: Node3D = ModelLoader.load_model(_tile_model_override(t, plat_default), _cell)
			if plat_model != null:
				plat_model.position = center
				container.add_child(plat_model)
			else:
				var plat := CSGBox3D.new()
				plat.size = Vector3(_cell * 0.9, 0.4, _cell * 0.9)
				plat.position = center + Vector3(0, 0.2, 0)
				var plat_mat := StandardMaterial3D.new()
				plat_mat.albedo_color = Color(0.8, 0.6, 0.2)
				plat.material = plat_mat
				container.add_child(plat)
		"lava":
			if not _build_generic(container, center, cell, tint, Design.get_dungeon_tile_render(t)):
				_add_lava_slab(container, center)
				_add_light(container, center + Vector3(0, 0.6, 0), Color(1.0, 0.4, 0.1), 1.6, _cell * 2.5)
		"spikes":
			if not _build_generic(container, center, cell, tint, Design.get_dungeon_tile_render(t)):
				_add_floor_slab(container, center, tint)
				_add_spikes(container, center, "spikes", cell)
		"monster":
			_add_floor_slab(container, center, tint)
			_add_enemy(container, center, cell)
		"chest":
			_add_floor_slab(container, center, tint)
			_add_chest(container, center, cell, gx, gy, floor_index)
		"gate":
			_add_floor_slab(container, center, tint)
			_add_gate(container, center, cell)
		"switch", "lever":
			_add_floor_slab(container, center, tint)
			_add_actuator(container, center, cell)
		"weight_plate":
			_add_floor_slab(container, center, tint)
			_add_weight_plate(container, center, cell)
		"torch":
			_add_floor_slab(container, center, tint)
			_add_torch(container, center, cell)
		"crystal":
			_add_floor_slab(container, center, tint)
			_add_crystal(container, center, cell)
		"column":
			_add_floor_slab(container, center, tint)
			_add_column(container, center, cell)
		"barrel":
			_add_floor_slab(container, center, tint)
			_add_decor_prop(container, center, cell, "barril_manzanas")
		"crate":
			_add_floor_slab(container, center, tint)
			_add_decor_prop(container, center, cell, "caja_madera")
		"caja_pesada", "caja_metal":
			_add_floor_slab(container, center, tint)
			_add_decor_prop(container, center, cell, "caja_pesada")
		"armario_libreria", "barril_manzanas", "cama", "bomba", "bomb":
			_add_floor_slab(container, center, tint)
			_add_decor_prop(container, center, cell, t)
		"statue":
			_add_floor_slab(container, center, tint)
			_add_statue(container, center, cell)
		"rune":
			_add_floor_slab(container, center, tint)
			_add_rune(container, center, cell)
		"campfire":
			_add_floor_slab(container, center, tint)
			_add_campfire(container, center, cell)
		"smart":
			var kit_id := String(cell.get("kit", ""))
			var kit_def: Dictionary = Design.kit_piece(kit_id)
			var shape := String(kit_def.get("shape", ""))
			var archetype := String(kit_def.get("archetype", ""))
			var is_custom_floor := kit_id == "reveal_floor" or archetype == "purify" or archetype == "water_tile" or kit_id == "elem_water_tile" or kit_id == "elem_deep_water_tile" or archetype == "auto_platform" or archetype == "lava_pool" or kit_id == "elem_lava" or (archetype == "false_solid" and (shape == "platform" or shape == "floor"))
			if not is_custom_floor:
				_add_floor_slab(container, center, tint)
			_add_smart_object(container, center, cell)
		"sign":
			_add_floor_slab(container, center, tint)
			_add_sign(container, center, cell)
		"teleport", "event", "npc", "item", "cinematic":
			_add_floor_slab(container, center, tint)
			_add_marker(container, center, cell, gx, gy, floor_index)
		"decor":
			_add_floor_slab(container, center, tint)
			var decor_model: String = String(cell.get("model", cell.get("prop", cell.get("id", ""))))
			if decor_model != "":
				_add_decor_prop(container, center, cell, decor_model)
			else:
				_add_marker(container, center, cell)
		"light":
			if not _build_generic(container, center, cell, tint, Design.get_dungeon_tile_render(t)):
				_add_floor_slab(container, center, tint)
				_add_light(container, center + Vector3(0, _wall_h * 0.6, 0), Color(1.0, 0.85, 0.6), 2.4, _cell * 3.0)
		_:
			# Tipo desconocido para el match: si su catálogo declara un `render`
			# de forma simple (p. ej. un reskin nuevo de líquido/pared), se
			# construye sin tocar este fichero; si no, solo losa de suelo.
			if not _build_generic(container, center, cell, tint, Design.get_dungeon_tile_render(t)):
				_add_floor_slab(container, center, tint)

	# Luz por celda: cualquier casilla puede emitir luz si el diseñador puso
	# "light" > 0 en el editor (antorchas, cristales, runas… o iluminar una zona).
	# Es aditiva a la luz que algunos tipos ya generan por su `render`.
	_add_cell_light(container, center, cell)

	# SOPORTE DE FLECHA Y TEXTO EN PAREDES Y SUELOS (Señaléctica Data-Driven)
	_add_signage_overlay(container, center, cell)


# ══════════════════════════════════════════════════════════════════════════════
# PRIMITIVAS DE CONSTRUCCIÓN
# ══════════════════════════════════════════════════════════════════════════════
func _add_floor_slab(container: Node3D, center: Vector3, tint, tex_key: String = "") -> void:
	var body := StaticBody3D.new()
	var slab_h: float = 0.2
	body.position = center + Vector3(0, -slab_h * 0.5, 0)
	container.add_child(body)
	var mi := MeshInstance3D.new()
	var box_sz := Vector3(_cell, slab_h, _cell)
	mi.mesh = _get_shared_box_mesh(box_sz)
	mi.material_override = _surface_material(_mat_floor, tex_key, tint, "floor")
	body.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = _get_shared_box_shape(box_sz)
	body.add_child(col)


func _add_lava_slab(container: Node3D, center: Vector3) -> MeshInstance3D:
	var body := StaticBody3D.new()
	var slab_h: float = 0.2
	body.position = center + Vector3(0, -slab_h * 0.5, 0)
	container.add_child(body)
	var mi := MeshInstance3D.new()
	var box_sz := Vector3(_cell, slab_h, _cell)
	mi.mesh = _get_shared_box_mesh(box_sz)
	mi.material_override = _mat_lava
	body.add_child(mi)
	var col := CollisionShape3D.new()
	col.shape = _get_shared_box_shape(box_sz)
	body.add_child(col)

	var script = load(LAVA_ZONE_SCRIPT)
	if script:
		var lava_area := Area3D.new()
		lava_area.collision_mask = 2
		lava_area.set_script(script)
		var lcol := CollisionShape3D.new()
		var lshape := BoxShape3D.new()
		lshape.size = Vector3(_cell, 2.0, _cell)
		lcol.shape = lshape
		lava_area.add_child(lcol)
		body.add_child(lava_area)

	var warn_area := Area3D.new()
	warn_area.collision_mask = 2
	warn_area.position = center + Vector3(0, 0.75, 0)
	container.add_child(warn_area)
	var warn_col := CollisionShape3D.new()
	var warn_shape := BoxShape3D.new()
	warn_shape.size = Vector3(_cell * 1.8, 1.5, _cell * 1.8)
	warn_col.shape = warn_shape
	warn_area.add_child(warn_col)
	warn_area.body_entered.connect(func(_b): _set_hazard_warning(mi, true, Color(1.0, 0.35, 0.05)))
	warn_area.body_exited.connect(func(_b): _set_hazard_warning(mi, false, Color(1.0, 0.35, 0.05)))

	if not Locale.reduce_motion:
		var smoke := _create_lava_smoke_particles(_cell)
		if smoke != null:
			smoke.position = Vector3(0, slab_h * 0.5 + 0.02, 0)
			body.add_child(smoke)

	return mi


## `model_type` es opcional: si se pasa (p. ej. "climb_wall") y ese tipo tiene
## un `model` propio en Design.get_dungeon_tile_render, se usa como visual EN
## VEZ del bloque procedural — la colisión de abajo es una caja fija del
## tamaño de la celda, independiente del visual, así que el reemplazo nunca
## puede dejar el muro sin bloquear el paso.
func _add_wall_block(container: Node3D, center: Vector3, height: float, tint, collide: bool = true, tex_key: String = "", model_type: String = "") -> void:
	var body := StaticBody3D.new()
	body.position = center + Vector3(0, height * 0.5, 0)
	container.add_child(body)
	var custom_model: Node3D = null
	if model_type != "":
		var override_name := _tile_model_override(model_type, "")
		if override_name != "":
			custom_model = ModelLoader.load_model(override_name, _cell)
	if custom_model != null:
		custom_model.position = Vector3(0, height * -0.5, 0)
		body.add_child(custom_model)
	else:
		var mi := MeshInstance3D.new()
		var box_sz := Vector3(_cell, height, _cell)
		mi.mesh = _get_shared_box_mesh(box_sz)
		mi.material_override = _surface_material(_mat_wall, tex_key, tint, "wall")
		body.add_child(mi)
	# `collide` permite muros DECORATIVOS atravesables (celda con "col": false),
	# para vallas/cornisas/relieves que no deben bloquear el paso.
	if collide:
		var col := CollisionShape3D.new()
		col.shape = _get_shared_box_shape(Vector3(_cell, height, _cell))
		body.add_child(col)


## PROP DE MODELO 3D (.glb / .tscn importado bajo assets/common/models/).
## El tipo de casilla declara en su `render`:
##   { "shape":"model", "model":"prop_barril", "solid":bool?, "y_offset":float?,
##     "collision":[w,h,d]? }
## `model` es el nombre del fichero o subcarpeta en res://assets/common/models/ (o directo).
## Si el modelo no existe se deja un marcador visible (nunca invisible).
func _add_model(container: Node3D, center: Vector3, cell: Dictionary, render: Dictionary) -> void:
	_add_floor_slab(container, center, _parse_color(cell.get("color", "")))
	var file := String(render.get("model", render.get("model_path", "")))
	if file == "":
		file = String(cell.get("t", ""))
	if file == "":
		return
	var y_offset := float(render.get("y_offset", 0.0))
	var scale_factor := float(render.get("scale", cell.get("scale", 1.0)))
	var inst: Node3D = ModelLoader.load_model(file, scale_factor, y_offset)
	if inst == null:
		# Modelo ausente: marcador para que el diseñador vea que falta el asset.
		_add_marker(container, center, cell)
		return
	var root := Node3D.new()
	root.position = center
	container.add_child(root)
	root.add_child(inst)
	# Colisión opcional (caja): activa si render.solid y la celda no la desactiva.
	var solid: bool = bool(render.get("solid", false)) and bool(cell.get("col", true))
	if solid:
		var size := Vector3(_cell * 0.6, _wall_h * 0.6, _cell * 0.6)
		var cs = render.get("collision", null)
		if cs is Array and cs.size() >= 3:
			size = Vector3(float(cs[0]), float(cs[1]), float(cs[2]))
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = Vector3(0, size.y * 0.5, 0)
		body.add_child(col)
		root.add_child(body)
	_apply_transform(root, cell)


func _add_liquid(container: Node3D, center: Vector3, mat: Material, script_path: String, depth: float, current_direction: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	# Malla plana visual del líquido.
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(_cell, depth, _cell)
	mi.mesh = box
	mi.material_override = mat
	mi.position = center + Vector3(0, depth * 0.5 - 0.1, 0)
	container.add_child(mi)

	# Elementos visuales dinámicos decorativos según el tipo de líquido
	if mat == _mat_water:
		var water_decor := Node3D.new()
		water_decor.name = "WaterDecor"
		water_decor.position = center + Vector3(0, depth * 0.5 + 0.02, 0)
		container.add_child(water_decor)

		# 1. Nenúfar/Placa verde flotante de agua estilizada
		var lily_mat := StandardMaterial3D.new()
		lily_mat.albedo_color = Color(0.12, 0.52, 0.22)
		lily_mat.roughness = 0.6
		var lily_mesh := CylinderMesh.new()
		lily_mesh.top_radius = 0.32
		lily_mesh.bottom_radius = 0.32
		lily_mesh.height = 0.02
		var lily_node := _mesh_node(lily_mesh, lily_mat, Vector3(_cell * 0.22, 0.01, -_cell * 0.18))
		water_decor.add_child(lily_node)

		# 2. Burbuja/Gota de cristal de agua bioluminiscente flotante
		var bubble_mat := StandardMaterial3D.new()
		bubble_mat.albedo_color = Color(0.4, 0.85, 1.0, 0.65)
		bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bubble_mat.emission_enabled = true
		bubble_mat.emission = Color(0.3, 0.75, 1.0)
		bubble_mat.emission_energy_multiplier = 1.8
		var bubble_mesh := SphereMesh.new()
		bubble_mesh.radius = 0.07
		bubble_mesh.height = 0.14
		var bnode := _mesh_node(bubble_mesh, bubble_mat, Vector3(-_cell * 0.24, 0.05, _cell * 0.20))
		water_decor.add_child(bnode)

		# Animación de oleaje/bamboleo flotante sutil en la superficie del agua
		_defer_tween_setup(func() -> void:
			if is_instance_valid(water_decor):
				var tw := water_decor.create_tween().set_loops()
				tw.tween_property(water_decor, "position:y", water_decor.position.y + 0.04, 1.8).set_trans(Tween.TRANS_SINE)
				tw.tween_property(water_decor, "position:y", water_decor.position.y - 0.04, 1.8).set_trans(Tween.TRANS_SINE)
		)

		# Goteo ambiental sobre la propia agua (ideas.md #6): motas que caen y
		# desaparecen justo al tocar la superficie, sin salpicadura simulada.
		if not Locale.reduce_motion:
			var drip := CPUParticles3D.new()
			drip.name = "WaterDrip"
			drip.amount = 4
			drip.lifetime = 1.6
			drip.preprocess = 1.0
			drip.randomness = 0.9
			drip.direction = Vector3.DOWN
			drip.spread = 8.0
			drip.gravity = Vector3(0.0, -1.4, 0.0)
			drip.initial_velocity_min = 0.05
			drip.initial_velocity_max = 0.15
			drip.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			drip.emission_box_extents = Vector3(_cell * 0.3, 0.05, _cell * 0.3)
			drip.position = center + Vector3(0, _wall_h * 0.85, 0)
			drip.scale_amount_min = 0.02
			drip.scale_amount_max = 0.035
			var drip_mesh := SphereMesh.new()
			drip_mesh.radius = 0.02
			drip_mesh.height = 0.04
			drip.mesh = drip_mesh
			var drip_mat := StandardMaterial3D.new()
			drip_mat.albedo_color = Color(0.55, 0.8, 1.0, 0.6)
			drip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			drip_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			drip.material_override = drip_mat
			container.add_child(drip)

	elif mat == _mat_lava:
		pass

	# Área física que activa el efecto en el jugador.
	var area := Area3D.new()
	area.collision_mask = 2
	area.position = center + Vector3(0, 0.75, 0)
	if ResourceLoader.exists(script_path):
		area.set_script(load(script_path))
		# Corriente de agua direccional (idea.md §1.2): solo aplica si el script
		# cargado es DungeonWaterZone.gd (expone la propiedad); en lava/pinchos
		# `current_direction` siempre es ZERO y este bloque no hace nada.
		if current_direction != Vector3.ZERO and "current_direction" in area:
			area.current_direction = current_direction
	container.add_child(area)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_cell, 1.5, _cell)
	col.shape = shape
	area.add_child(col)

	# Aviso de "casi" (ideas.md #7): la lava avisa con un pulso de calor en su
	# propia superficie antes de que el jugador llegue a pisarla, sin tocar el
	# material compartido (usa un overlay propio de `mi`, ver _set_hazard_warning).
	if mat == _mat_lava:
		var warn_area := Area3D.new()
		warn_area.collision_mask = 2
		warn_area.position = center + Vector3(0, 0.75, 0)
		container.add_child(warn_area)
		var warn_col := CollisionShape3D.new()
		var warn_shape := BoxShape3D.new()
		warn_shape.size = Vector3(_cell * 1.8, 1.5, _cell * 1.8)
		warn_col.shape = warn_shape
		warn_area.add_child(warn_col)
		warn_area.body_entered.connect(func(_b): _set_hazard_warning(mi, true, Color(1.0, 0.35, 0.05)))
		warn_area.body_exited.connect(func(_b): _set_hazard_warning(mi, false, Color(1.0, 0.35, 0.05)))
	return mi


func _add_spikes(container: Node3D, center: Vector3, hazard: String = "spikes", cell: Dictionary = {}) -> void:
	# Usa assets/common/models/interactive/pinchos.tscn (escalado a la casilla);
	# si falta el archivo, cae a los 5 pinchos metálicos procedurales de siempre.
	var visual := Node3D.new()
	visual.name = "SpikesVisual"
	visual.position = center
	container.add_child(visual)

	var spike_meshes: Array[MeshInstance3D] = []
	var spikes_model: Node3D = ModelLoader.load_model(_tile_model_override(String(cell.get("t", "spikes")), "pinchos"), _cell)
	if spikes_model != null:
		visual.add_child(spikes_model)
		for ch in spikes_model.find_children("S*", "MeshInstance3D", true, false):
			if ch is MeshInstance3D:
				spike_meshes.append(ch as MeshInstance3D)
	else:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.005
		cyl.bottom_radius = 0.12
		cyl.height = 0.18
		cyl.radial_segments = 4

		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.16, 0.18)
		m.metallic = 0.88
		m.roughness = 0.24

		var off := _cell * 0.28
		var offsets := [
			Vector3(0.0, 0.09, 0.0),          # Centro
			Vector3(-off, 0.09, -off),       # Esquina Superior Izquierda
			Vector3(off, 0.09, -off),        # Esquina Superior Derecha
			Vector3(-off, 0.09, off),        # Esquina Inferior Izquierda
			Vector3(off, 0.09, off),         # Esquina Inferior Derecha
		]

		for pos in offsets:
			var mi := MeshInstance3D.new()
			mi.mesh = cyl
			mi.material_override = m
			mi.position = pos
			mi.rotation_degrees = Vector3(0, 45, 0)
			visual.add_child(mi)
			spike_meshes.append(mi)

	var area := Area3D.new()
	area.collision_mask = 2
	area.position = center + Vector3(0, 0.4, 0)
	var script_path := _hazard_script(hazard)
	if ResourceLoader.exists(script_path):
		area.set_script(load(script_path))
	container.add_child(area)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_cell, 0.8, _cell)
	col.shape = shape
	area.add_child(col)

	# Aviso de "casi" (ideas.md #7): área más ancha que la de daño; al entrar,
	# los pinchos brillan en rojo antes de que el jugador llegue a pisarlos.
	var warn_area := Area3D.new()
	warn_area.collision_mask = 2
	warn_area.position = center + Vector3(0, 0.4, 0)
	container.add_child(warn_area)
	var warn_col := CollisionShape3D.new()
	var warn_shape := BoxShape3D.new()
	warn_shape.size = Vector3(_cell * 1.8, 1.2, _cell * 1.8)
	warn_col.shape = warn_shape
	warn_area.add_child(warn_col)
	warn_area.body_entered.connect(func(_b):
		for sm in spike_meshes:
			_set_hazard_warning(sm, true, Color(1.0, 0.15, 0.1))
	)
	warn_area.body_exited.connect(func(_b):
		for sm in spike_meshes:
			_set_hazard_warning(sm, false, Color(1.0, 0.15, 0.1))
	)

	# Bloqueo físico de paso cuando los pinchos están extendidos
	var blocker_body := StaticBody3D.new()
	blocker_body.name = "SpikesBlocker"
	blocker_body.position = center + Vector3(0, 0.25, 0)
	container.add_child(blocker_body)
	var blocker_col := CollisionShape3D.new()
	var blocker_shape := BoxShape3D.new()
	blocker_shape.size = Vector3(_cell * 0.96, 0.5, _cell * 0.96)
	blocker_col.shape = blocker_shape
	blocker_body.add_child(blocker_col)

	var eid := String(cell.get("eid", ""))
	if eid != "":
		var state := String(cell.get("state", "closed"))
		var el := {
			"kind": "spikes",
			"state": state,
			"visual": visual,
			"col": col,
			"blocker_col": blocker_col,
			"area": area,
			"warn_col": warn_col,
			"spike_meshes": spike_meshes
		}
		_register_element(eid, el)
		_set_element_state(el, true)


## Activa/desactiva el pulso de advertencia de "casi" de una trampa (ideas.md
## #7) en `mi`. Usa `material_overlay` (capa propia de esa instancia concreta,
## nunca comparte material con otras trampas del mismo tipo) para poder
## pulsarlo sin arriesgar tocar un material compartido como `_mat_lava`.
func _set_hazard_warning(mi: MeshInstance3D, active: bool, glow_color: Color) -> void:
	if mi == null or not is_instance_valid(mi):
		return
	if mi.has_meta("warn_tween"):
		var old = mi.get_meta("warn_tween")
		if old is Tween and old.is_valid():
			old.kill()
		mi.remove_meta("warn_tween")
	if not active:
		mi.material_overlay = null
		return
	if Locale.reduce_motion:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 0.2
	mi.material_overlay = mat
	var tw := mi.create_tween().set_loops()
	tw.tween_property(mat, "emission_energy_multiplier", 2.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mat, "emission_energy_multiplier", 0.2, 0.35).set_trans(Tween.TRANS_SINE)
	mi.set_meta("warn_tween", tw)


# ══════════════════════════════════════════════════════════════════════════════
# CASILLAS COSMÉTICAS GENÉRICAS (data-driven, ver data/dungeon_tiles/<t>.json)
# ══════════════════════════════════════════════════════════════════════════════
## Construye una casilla a partir de su `render` catalogado (Design.get_dungeon_tile_render).
## Devuelve `false` si `render` está vacío o su `shape` no es reconocida, para que
## quien llama pueda caer al camino de código dedicado (compatibilidad/seguridad).
func _build_generic(container: Node3D, center: Vector3, cell: Dictionary, tint, render: Dictionary) -> bool:
	match String(render.get("shape", "")):
		"none":
			return true
		"floor":
			_add_floor_slab(container, center, tint, String(cell.get("tex", "")))
			return true
		"wall":
			_add_floor_slab(container, center, tint)
			_add_wall_block(container, center, _cell_height(cell), tint, cell.get("col", true) != false, String(cell.get("wall", "")))
			return true
		"model":
			_add_model(container, center, cell, render)
			return true
		"liquid":
			var mat: Material = _mat_lava if String(render.get("material", "water")) == "lava" else _mat_water
			_add_floor_slab(container, center + Vector3(0, -LIQUID_PIT_DEPTH, 0), tint)
			_add_liquid(container, center, mat, _hazard_script(String(render.get("hazard", ""))), LIQUID_PIT_DEPTH)
			var light_spec = render.get("light", null)
			if light_spec is Dictionary:
				_add_light_from_spec(container, center, light_spec)
			return true
		"cone", "spikes", "pinchos":
			_add_floor_slab(container, center, tint)
			_add_spikes(container, center, String(render.get("hazard", "spikes")), cell)
			return true
		"light":
			_add_floor_slab(container, center, tint)
			var light: OmniLight3D = _add_light_from_spec(container, center, render.get("light", {}))
			_register_light_element(light, cell)
			return true
	return false


## Registra una luz con `eid` en `_elements` para que un
## interruptor/palanca/botón la pueda encender o apagar — antes NINGÚN tipo de
## luz era un objetivo válido, solo puertas y compuertas ("un interruptor sin
## lógica de este tipo no sirve de nada", bug reportado).
func _register_light_element(light: OmniLight3D, cell: Dictionary) -> void:
	var eid := String(cell.get("eid", ""))
	if eid == "" or not (light is OmniLight3D and is_instance_valid(light)):
		return
	var state := String(cell.get("state", "on"))
	var el := { "kind": "light", "state": state, "light": light, "base_energy": light.light_energy }
	_register_element(eid, el)
	_set_element_state(el, true)


## Traduce la clave `hazard` del catálogo al script GDScript real del Area3D
## de peligro ("" si no hay ninguno asociado a esa clave).
func _hazard_script(hazard: String) -> String:
	match hazard:
		"water": return WATER_ZONE_SCRIPT
		"lava": return LAVA_ZONE_SCRIPT
		"spikes": return SPIKES_ZONE_SCRIPT
	return ""


## Añade una OmniLight3D a partir de una spec data-driven:
##   { color:[r,g,b], energy:float, range_mult:float, height:float | height_mult:float }
## `height` es un offset absoluto sobre `center`; si no está, se usa
## `_wall_h * height_mult` (por defecto 0.5).
func _add_light_from_spec(container: Node3D, center: Vector3, spec: Dictionary) -> OmniLight3D:
	var col_arr: Array = spec.get("color", [1.0, 1.0, 1.0])
	var color := Color(1.0, 1.0, 1.0)
	if col_arr is Array and col_arr.size() >= 3:
		color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
	var energy := float(spec.get("energy", 1.5))
	var range_mult := float(spec.get("range_mult", 2.0))
	var height: float = float(spec.get("height")) if spec.has("height") else _wall_h * float(spec.get("height_mult", 0.5))
	return _add_light(container, center + Vector3(0, height, 0), color, energy, _cell * range_mult)


func _add_enemy(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Node3D
	var is_boss := bool(cell.get("boss", false))
	var eid := String(cell.get("ref", ""))
	if eid == "":
		eid = String(_def.get("boss", "dungeon_boss")) if is_boss else "goblin_explorador"
	enemy.set("is_boss", is_boss)
	enemy.set("enemy_id", eid)
	enemy.set("level", maxi(1, int(cell.get("level", 1))))
	enemy.set("has_explicit_ref", String(cell.get("ref", "")) != "")
	if cell.has("patrol") or cell.has("no_patrol"):
		enemy.set("can_patrol", bool(cell.get("patrol", not bool(cell.get("no_patrol", false)))))
	enemy.position = center + Vector3(0, 0.05, 0)
	container.add_child(enemy)
	if enemy.has_method("refresh_visuals"):
		enemy.call("refresh_visuals")


## Marcador genérico (portal de salida, teletransporte, interactivos, entidades,
## decoración). Los interactivos "event/switch/button/lever/teleport" que salen
## de la mazmorra se agrupan como "exit_portal" para reutilizar el flujo de salida.
func _add_marker(container: Node3D, center: Vector3, cell: Dictionary, gx: int = 0, gy: int = 0, floor_index: int = 0) -> void:
	var t := String(cell.get("t", ""))
	var area := Area3D.new()
	area.collision_mask = 2
	area.position = center + Vector3(0, 0.1, 0)
	# Distingue la SALIDA de la mazmorra (sin destino interno) del
	# teletransporte INTERNO, para darles un aspecto distinto (ver
	# _add_teleport_visual / task_arreglosPendientes.md §3).
	var is_exit_portal := false
	if t == "teleport":
		var dest = cell.get("to", null)
		if dest is Dictionary:
			# Teletransporte INTERNO: mueve al jugador a {f,x,y} dentro de la mazmorra.
			area.add_to_group("dungeon_teleport")
			area.set_meta("tp_to", dest)
		else:
			# Sin destino interno → se trata como salida de la mazmorra. Si la celda
			# declara `portal:"<nombre>"`, es una salida NOMBRADA:
			# ViewDungeon._on_exit_portal_entered la usa para buscar en el mapamundi
			# la casilla concreta que declara esa misma entrada (`portal.entry`) y
			# reaparecer justo ahí, en vez de volver siempre al punto de entrada.
			is_exit_portal = true
			area.name = "ExitPortal"
			area.add_to_group("exit_portal")
			var portal_name := String(cell.get("portal", ""))
			if portal_name != "":
				area.set_meta("portal_name", portal_name)
		if bool(cell.get("is_boss_teleport", false)):
			area.set_meta("is_boss_teleport", true)
			area.add_to_group("boss_teleport")
	elif t == "cinematic":
		var cine_id := str(cell.get("cinematic_id", cell.get("id", "")))
		var once := bool(cell.get("once", false))
		var flag_key := "cine_dun_%s_%d_%d_%d_%s" % [_dungeon_id, floor_index, gx, gy, cine_id]
		if once and GlobalState.has_world_flag(flag_key):
			return
		area.name = "DungeonCinematic"
		area.add_to_group("dungeon_cinematic")
		area.set_meta("cinematic_id", cine_id)
		area.set_meta("trigger_on_step", bool(cell.get("trigger_on_step", true)))
		area.set_meta("once", once)
		area.set_meta("cell_coord", Vector2i(gx, gy))
		area.set_meta("floor_index", floor_index)
	container.add_child(area)

	match t:
		"teleport":
			_add_teleport_visual(area, is_exit_portal)
		"item":
			_add_item_pickup_visual(area)
		"npc":
			_add_npc_marker_visual(area)
		"cinematic":
			_add_cinematic_marker_visual(area)
		_:
			# "event"/"decor" y cualquier otro genérico: losa plana emisiva (marca
			# la casilla sin pretender ser un objeto concreto).
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(_cell * 0.8, 0.15, _cell * 0.8)
			var col_vis := _marker_color(t)
			var mm := StandardMaterial3D.new()
			mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mm.albedo_color = Color(col_vis.r, col_vis.g, col_vis.b, 0.5)
			mm.emission_enabled = true
			mm.emission = col_vis
			mm.emission_energy_multiplier = 2.0
			mesh.mesh = box
			mesh.material_override = mm
			area.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_cell * 0.9, 2.0, _cell * 0.9)
	col.shape = shape
	area.add_child(col)


## Objeto RECOGIBLE genérico ("item" sin modelo .glb propio): gema flotante y
## giratoria sobre un halo en el suelo — se lee como "esto se puede coger", a
## diferencia de la losa plana genérica que antes compartía con event/npc/decor
##.
func _add_item_pickup_visual(area: Area3D) -> void:
	var col_vis := _marker_color("item")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col_vis
	mat.emission_enabled = true
	mat.emission = col_vis
	mat.emission_energy_multiplier = 2.4
	mat.metallic = 0.3
	mat.roughness = 0.15

	var halo := MeshInstance3D.new()
	var halo_mesh := CylinderMesh.new()
	halo_mesh.top_radius = _cell * 0.22
	halo_mesh.bottom_radius = _cell * 0.22
	halo_mesh.height = 0.04
	halo.mesh = halo_mesh
	var halo_mat := mat.duplicate() as StandardMaterial3D
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(col_vis.r, col_vis.g, col_vis.b, 0.35)
	halo.material_override = halo_mat
	halo.position = Vector3(0, 0.02, 0)
	area.add_child(halo)

	var gem := MeshInstance3D.new()
	var gem_mesh := PrismMesh.new()
	gem_mesh.size = Vector3(_cell * 0.26, _cell * 0.36, _cell * 0.26)
	gem.mesh = gem_mesh
	gem.material_override = mat
	gem.position = Vector3(0, 0.45, 0)
	area.add_child(gem)

	if not Locale.reduce_motion:
		_defer_tween_setup(func() -> void:
			if not is_instance_valid(area) or not is_instance_valid(gem):
				return
			var tw := gem.create_tween().set_loops()
			tw.tween_property(gem, "rotation:y", TAU, 2.6).as_relative().set_trans(Tween.TRANS_LINEAR)
			var tw2 := gem.create_tween().set_loops()
			tw2.tween_property(gem, "position:y", 0.58, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw2.tween_property(gem, "position:y", 0.45, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		)


## Marcador visual de cinemática interactiva en mazmorra: halo rúnico púrpura,
## gema prismática flotante que rota suavemente e icono de claqueta 🎬.
func _add_cinematic_marker_visual(area: Area3D) -> void:
	var col_vis := _marker_color("cinematic")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col_vis
	mat.emission_enabled = true
	mat.emission = col_vis
	mat.emission_energy_multiplier = 2.8
	mat.metallic = 0.5
	mat.roughness = 0.1

	var halo := MeshInstance3D.new()
	var halo_mesh := CylinderMesh.new()
	halo_mesh.top_radius = _cell * 0.32
	halo_mesh.bottom_radius = _cell * 0.32
	halo_mesh.height = 0.04
	halo.mesh = halo_mesh
	var halo_mat := mat.duplicate() as StandardMaterial3D
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(col_vis.r, col_vis.g, col_vis.b, 0.4)
	halo.material_override = halo_mat
	halo.position = Vector3(0, 0.02, 0)
	area.add_child(halo)

	var gem := MeshInstance3D.new()
	var gem_mesh := PrismMesh.new()
	gem_mesh.size = Vector3(_cell * 0.28, _cell * 0.42, _cell * 0.28)
	gem.mesh = gem_mesh
	gem.material_override = mat
	gem.position = Vector3(0, 0.5, 0)
	area.add_child(gem)

	var lbl := Label3D.new()
	lbl.text = "🎬"
	lbl.position = Vector3(0, 0.95, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.95, 0.6)
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.outline_size = 10
	lbl.font_size = 38
	lbl.pixel_size = 0.007
	lbl.double_sided = true
	area.add_child(lbl)

	if not Locale.reduce_motion:
		_defer_tween_setup(func() -> void:
			if not is_instance_valid(area) or not is_instance_valid(gem):
				return
			var tw := gem.create_tween().set_loops()
			tw.tween_property(gem, "rotation:y", TAU, 3.2).as_relative().set_trans(Tween.TRANS_LINEAR)
			var tw2 := gem.create_tween().set_loops()
			tw2.tween_property(gem, "position:y", 0.62, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw2.tween_property(gem, "position:y", 0.48, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		)


## NPC genérico (sin modelo propio): silueta humanoide low-poly (cuerpo + cabeza)
## en vez de la losa plana — se distingue de un simple marcador de evento/objeto
## de un vistazo.
func _add_npc_marker_visual(area: Area3D) -> void:
	var col_vis := _marker_color("npc")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col_vis
	mat.roughness = 0.7

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = _cell * 0.16
	body_mesh.height = _wall_h * 0.55
	body.mesh = body_mesh
	body.material_override = mat
	body.position = Vector3(0, _wall_h * 0.3, 0)
	area.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = _cell * 0.13
	head_mesh.height = _cell * 0.26
	head.mesh = head_mesh
	head.material_override = mat
	head.position = Vector3(0, _wall_h * 0.58, 0)
	area.add_child(head)

	# Halo en el suelo (mismo color que el marcador genérico) para que siga
	# leyéndose como "casilla interactiva" al pasar por encima.
	var halo := MeshInstance3D.new()
	var halo_mesh := CylinderMesh.new()
	halo_mesh.top_radius = _cell * 0.3
	halo_mesh.bottom_radius = _cell * 0.3
	halo_mesh.height = 0.04
	halo.mesh = halo_mesh
	var halo_mat := StandardMaterial3D.new()
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(col_vis.r, col_vis.g, col_vis.b, 0.3)
	halo_mat.emission_enabled = true
	halo_mat.emission = col_vis
	halo.material_override = halo_mat
	halo.position = Vector3(0, 0.02, 0)
	area.add_child(halo)


## Crea un portal de salida en la posición indicada (p. ej. la casilla de entrada)
## y devuelve el Area3D para que ViewDungeon lo conecte.
func add_exit_teleport_at(world_pos: Vector3, portal_name: String = "") -> Area3D:
	var area := Area3D.new()
	area.collision_mask = 2
	area.position = world_pos + Vector3(0, 0.1, 0)
	area.name = "ExitPortal"
	area.add_to_group("exit_portal")
	if portal_name != "":
		area.set_meta("portal_name", portal_name)
	_add_teleport_visual(area, true)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_cell * 0.9, 2.0, _cell * 0.9)
	col.shape = shape
	area.add_child(col)
	add_child(area)
	return area


## Shader del "velo"/membrana del portal: vórtice animado por TIME (sin coste de
## CPU por frame). Comparte el plano y la rotación con el marco del portal
## (`portal_rotator`), manteniéndose perfectamente alineados desde cualquier ángulo.
const PORTAL_VORTEX_SHADER_CODE: String = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 color_a : source_color = vec3(0.55, 0.30, 0.95);
uniform vec3 color_b : source_color = vec3(0.85, 0.55, 1.0);
uniform float speed : hint_range(0.0, 4.0) = 1.4;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv) * 2.0;
	float angle = atan(uv.y, uv.x);
	float swirl = sin(angle * 5.0 - dist * 14.0 + TIME * speed * 3.0) * 0.5 + 0.5;
	float disc = smoothstep(1.0, 0.82, dist);
	float hole = smoothstep(0.0, 0.22, dist);
	vec3 col = mix(color_a, color_b, swirl);
	ALBEDO = col;
	EMISSION = col * (1.1 + swirl * 1.6);
	ALPHA = disc * hole * (0.5 + swirl * 0.5);
}
"""

## Caché ESTÁTICA de shader/materiales del portal (presupuesto de recursos de
## la Vía A, task_arreglosPendientes.md §3): TODAS las instancias de portal de
## un mismo tipo (salida en dorado / teletransporte interno en violeta)
## comparten el MISMO recurso Shader/Material, así el motor solo compila el
## shader una vez por partida y no se duplica memoria de material por portal.
static var _portal_vortex_shader: Shader = null
static var _portal_vortex_mat_cache: Dictionary = {}   # "exit"/"internal" -> ShaderMaterial
static var _portal_ring_mat_cache: Dictionary = {}      # "exit"/"internal" -> StandardMaterial3D

static func _get_portal_vortex_material(is_exit: bool, col_vis: Color) -> ShaderMaterial:
	var key := "exit" if is_exit else "internal"
	if _portal_vortex_mat_cache.has(key):
		return _portal_vortex_mat_cache[key]
	if _portal_vortex_shader == null:
		_portal_vortex_shader = Shader.new()
		_portal_vortex_shader.code = PORTAL_VORTEX_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _portal_vortex_shader
	mat.set_shader_parameter("color_a", col_vis)
	mat.set_shader_parameter("color_b", Color(minf(col_vis.r + 0.3, 1.0), minf(col_vis.g + 0.3, 1.0), minf(col_vis.b + 0.3, 1.0)))
	_portal_vortex_mat_cache[key] = mat
	return mat

static func _get_portal_ring_material(is_exit: bool, col_vis: Color) -> StandardMaterial3D:
	var key := "exit" if is_exit else "internal"
	if _portal_ring_mat_cache.has(key):
		return _portal_ring_mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col_vis.r * 1.2, col_vis.g * 1.1, col_vis.b * 1.3, 0.92)
	mat.emission_enabled = true
	mat.emission = col_vis
	mat.emission_energy_multiplier = 3.6
	_portal_ring_mat_cache[key] = mat
	return mat


## Aspecto del PORTAL (Vía A de task_arreglosPendientes.md §3): un aro VERTICAL
## (marco de puerta reconocible, en vez del antiguo disco plano en el suelo que
## se leía como "alfombra de teletransporte") con runas orbitando y una
## membrana central en vórtice (shader, siempre mirando a cámara). `is_exit`
## distingue la SALIDA de la mazmorra (dorado) del teletransporte interno
## (violeta) — antes indistinguibles. Presupuesto de recursos bajo: 1 sola luz,
## shader/material compartidos entre TODOS los portales (ver caché estática
## arriba), y partículas gateadas por accesibilidad (`Locale.reduce_motion`).
func _add_teleport_visual(area: Area3D, is_exit: bool = false) -> void:
	# Reemplazable por un modelo propio (Design.get_dungeon_tile_render("teleport").model):
	# si se define, sustituye TODO el VFX procedural de abajo.
	var teleport_model: Node3D = ModelLoader.load_model(_tile_model_override("teleport", ""), _cell * 0.8)
	if teleport_model != null:
		area.add_child(teleport_model)
		return
	var col_vis := _marker_color("teleport_exit" if is_exit else "teleport")
	var ring_mat := _get_portal_ring_material(is_exit, col_vis)

	# Radio del aro/puerta: proporcional a la altura de pared, para que se lea
	# como un umbral atravesable (puerta), no como una alfombra en el suelo.
	var ring_radius: float = _wall_h * 0.42

	# 1. Halo tenue en el suelo: ancla el portal a la casilla sin ser el
	# protagonista del efecto (antes era un disco grande y plano).
	var halo := MeshInstance3D.new()
	var halo_mesh := CylinderMesh.new()
	halo_mesh.top_radius = ring_radius * 0.9
	halo_mesh.bottom_radius = ring_radius * 0.9
	halo_mesh.height = 0.004
	halo_mesh.radial_segments = 32
	halo.mesh = halo_mesh
	var halo_mat := ring_mat.duplicate() as StandardMaterial3D
	halo_mat.albedo_color.a = 0.10
	halo_mat.emission_energy_multiplier = 1.2
	halo.material_override = halo_mat
	halo.position = Vector3(0, 0.012, 0)
	area.add_child(halo)

	# 2. Contenedor orientable del portal (gira en Y hacia el jugador/cámara):
	# agrupa el marco vertical (aros y runas) y la membrana central en el MISMO plano,
	# evitando que el aro quede de perfil o corte transversalmente el vórtice.
	var portal_rotator := Node3D.new()
	portal_rotator.name = "PortalRotator"
	portal_rotator.position = Vector3(0, ring_radius, 0)
	area.add_child(portal_rotator)
	_active_portals.append(portal_rotator)

	# Orientación inicial inmediata si el jugador ya está disponible
	if _player_node_cache != null and is_instance_valid(_player_node_cache):
		var init_diff := _player_node_cache.global_position - area.global_position
		init_diff.y = 0.0
		if init_diff.length_squared() > 0.001:
			portal_rotator.rotation.y = atan2(init_diff.x, init_diff.z)

	var frame_root := Node3D.new()
	frame_root.name = "FrameRoot"
	frame_root.rotation_degrees.x = 90.0
	portal_rotator.add_child(frame_root)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.outer_radius = ring_radius
	torus.inner_radius = ring_radius * 0.965
	torus.rings = 64
	torus.ring_segments = 12
	ring.mesh = torus
	ring.material_override = ring_mat
	frame_root.add_child(ring)

	var echo_ring := MeshInstance3D.new()
	var echo_torus := TorusMesh.new()
	echo_torus.outer_radius = ring_radius * 0.90
	echo_torus.inner_radius = ring_radius * 0.885
	echo_torus.rings = 48
	echo_torus.ring_segments = 8
	echo_ring.mesh = echo_torus
	var echo_mat := ring_mat.duplicate() as StandardMaterial3D
	echo_mat.albedo_color.a = 0.65
	echo_ring.material_override = echo_mat
	frame_root.add_child(echo_ring)

	# 3. Runas orbitando el marco (6 en vez de las 8 originales, para acotar
	# draw calls); siguen leyéndose como "puerta rúnica".
	var runes := Node3D.new()
	frame_root.add_child(runes)
	const RUNE_COUNT: int = 6
	for i in range(RUNE_COUNT):
		var ang: float = TAU * float(i) / float(RUNE_COUNT)
		var rune := MeshInstance3D.new()
		var rune_mesh := PrismMesh.new()
		rune_mesh.size = Vector3(0.03, 0.075, 0.014)
		rune.mesh = rune_mesh
		rune.material_override = ring_mat
		var r: float = ring_radius * 0.96
		rune.position = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		rune.rotation_degrees = Vector3(0, rad_to_deg(ang) + 90.0, 0)
		runes.add_child(rune)

	# 4. Membrana central: vórtice coplanar al marco dentro de `portal_rotator`.
	var membrane := MeshInstance3D.new()
	var membrane_mesh := QuadMesh.new()
	membrane_mesh.size = Vector2(ring_radius * 1.7, ring_radius * 1.7)
	membrane.mesh = membrane_mesh
	membrane.material_override = _get_portal_vortex_material(is_exit, col_vis)
	portal_rotator.add_child(membrane)

	var glow := OmniLight3D.new()
	glow.light_color = col_vis
	glow.light_energy = 2.0
	glow.omni_range = _cell * 2.2
	glow.position = Vector3(0, ring_radius, 0)
	area.add_child(glow)

	# 5. Destellos ascendentes sutiles, gateados por accesibilidad (cuestan CPU
	# en dispositivos de gama baja, ver Locale.reduce_motion / §4 rendimiento).
	if not Locale.reduce_motion:
		var particles := CPUParticles3D.new()
		particles.amount = 14
		particles.lifetime = 2.0
		particles.emitting = true
		particles.direction = Vector3(0, 1, 0)
		particles.spread = 10.0
		particles.gravity = Vector3.ZERO
		particles.initial_velocity_min = 0.3
		particles.initial_velocity_max = 0.7
		particles.scale_amount_min = 0.4
		particles.scale_amount_max = 0.9
		particles.color = col_vis
		var p_mesh := SphereMesh.new()
		p_mesh.radius = 0.016
		p_mesh.height = 0.032
		particles.mesh = p_mesh
		var p_mat := StandardMaterial3D.new()
		p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		p_mat.emission_enabled = true
		p_mat.emission = col_vis
		p_mat.emission_energy_multiplier = 3.5
		particles.material_override = p_mat
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = ring_radius * 0.5
		particles.position = Vector3(0, ring_radius * 0.3, 0)
		area.add_child(particles)

	# Animación continua (tweens en bucle, coste ínfimo); el vórtice de la
	# membrana ya se anima solo vía shader TIME, sin lógica extra en _process.
	_defer_tween_setup(func() -> void:
		if not is_instance_valid(area) or not is_instance_valid(ring) or not is_instance_valid(runes):
			return
		var tw_outer := ring.create_tween().set_loops()
		tw_outer.tween_property(ring, "rotation:y", TAU, 14.0).as_relative().set_trans(Tween.TRANS_LINEAR)
		var tw_echo := echo_ring.create_tween().set_loops()
		tw_echo.tween_property(echo_ring, "rotation:y", -TAU, 18.0).as_relative().set_trans(Tween.TRANS_LINEAR)
		var tw_runes := runes.create_tween().set_loops()
		tw_runes.tween_property(runes, "rotation:y", TAU, 22.0).as_relative().set_trans(Tween.TRANS_LINEAR)
		var tw_halo := halo.create_tween().set_loops()
		tw_halo.tween_property(halo, "scale", Vector3(1.08, 1.0, 1.08), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_halo.tween_property(halo, "scale", Vector3.ONE, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)


## Orienta los portales activos en Y hacia la posición de la cámara/jugador para
## que el marco vertical y el remolino se vean siempre de frente y coplanares.
func _process_portal_facing() -> void:
	if _active_portals.is_empty():
		return
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var cam_pos: Vector3
	if cam != null:
		cam_pos = cam.global_position
	elif _player_node_cache != null and is_instance_valid(_player_node_cache):
		cam_pos = _player_node_cache.global_position
	else:
		return

	var i: int = _active_portals.size() - 1
	while i >= 0:
		var p: Node3D = _active_portals[i]
		if not is_instance_valid(p) or not p.is_inside_tree():
			_active_portals.remove_at(i)
			i -= 1
			continue
		var diff := cam_pos - p.global_position
		diff.y = 0.0
		if diff.length_squared() > 0.001:
			p.rotation.y = atan2(diff.x, diff.z)
		i -= 1


## Cofre data-driven. Contenido en la celda: { gold:int, items:[{id, qty}] }.
## Clave estable "event_id:planta:x:y" para no saquearlo dos veces (persiste en
## GlobalState.opened_chests). Usa el modelo 3D animado (cofre.gltf).
func _add_chest(container: Node3D, center: Vector3, cell: Dictionary, gx: int, gy: int, floor_index: int) -> void:
	var key := "%s:%d:%d:%d" % [_dungeon_id, floor_index, gx, gy]
	var opened: bool = GlobalState.is_chest_opened(key)

	var root := Node3D.new()
	root.name = "Chest"
	root.position = center
	container.add_child(root)

	var chest_model: Node3D = ModelLoader.load_model(_tile_model_override("chest", "cofre"), _cell * 0.46)
	var anim_player: AnimationPlayer = null
	if chest_model != null:
		root.add_child(chest_model)
		anim_player = chest_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player == null:
			for ch in chest_model.find_children("*", "AnimationPlayer", true, false):
				if ch is AnimationPlayer:
					anim_player = ch as AnimationPlayer
					break
		if anim_player != null:
			if opened:
				if anim_player.has_animation("Chest_Opened"):
					anim_player.play("Chest_Opened")
				elif anim_player.has_animation("Chest_Open"):
					anim_player.play("Chest_Open")
					anim_player.seek(anim_player.get_animation("Chest_Open").length, true)
			else:
				if anim_player.has_animation("Chest_Closed"):
					anim_player.play("Chest_Closed")
				elif anim_player.has_animation("Chest_Open"):
					anim_player.play("Chest_Open")
					anim_player.seek(0.0, true)
					anim_player.stop()
	else:
		var col_vis := _marker_color("chest")
		var fallback_chest := _build_lowpoly_chest(col_vis, opened)
		root.add_child(fallback_chest)

	# Colisión física sólida
	var body := StaticBody3D.new()
	var scol := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(_cell * 0.55, _cell * 0.45, _cell * 0.45)
	scol.shape = sh
	scol.position = Vector3(0, sh.size.y * 0.5, 0)
	body.add_child(scol)
	root.add_child(body)

	_apply_transform(root, cell)

	if opened:
		return

	# Área de recogida: al entrar el jugador, ViewDungeon concede el botín (grupo).
	var area := Area3D.new()
	area.collision_mask = 2
	area.position = center + Vector3(0, 0.4, 0)
	area.add_to_group("dungeon_chest")
	area.set_meta("chest_key", key)
	area.set_meta("chest_gold", int(cell.get("gold", 0)))
	area.set_meta("chest_items", cell.get("items", []))
	area.set_meta("chest_loot", cell.get("loot", null))
	area.set_meta("chest_trap", bool(cell.get("trap", false)))
	area.set_meta("chest_trap_damage", int(cell.get("trap_damage", 25)))
	area.set_meta("chest_mesh", root)
	area.set_meta("chest_anim", anim_player)
	container.add_child(area)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_cell * 0.8, 1.6, _cell * 0.8)
	col.shape = shape
	area.add_child(col)


## Construye un COFRE low-poly por código (sin assets): base de madera, tapa (caja
## superior) y herrajes/cerradura dorados. `accent` tiñe el brillo de los herrajes;
## si `opened` es true se dibuja en tonos apagados (madera grisácea, sin emisión).
## Devuelve un Node3D raíz; ViewDungeon apaga sus mallas al saquearlo (chest_mesh).
func _build_lowpoly_chest(accent: Color, opened: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Chest"
	var s := _cell

	# Materiales compartidos: madera (cuerpo/tapa) y oro (herrajes/cerradura).
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.26, 0.13) if not opened else Color(0.34, 0.30, 0.26)
	wood.roughness = 0.9
	var wood_lid := StandardMaterial3D.new()
	wood_lid.albedo_color = Color(0.36, 0.22, 0.11) if not opened else Color(0.30, 0.27, 0.24)
	wood_lid.roughness = 0.9
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.78, 0.32) if not opened else Color(0.45, 0.42, 0.30)
	gold.metallic = 0.6
	gold.roughness = 0.35
	gold.emission_enabled = not opened
	gold.emission = accent
	gold.emission_energy_multiplier = 1.2

	# Cuerpo (caja baja de madera).
	var body := BoxMesh.new()
	body.size = Vector3(s * 0.52, s * 0.30, s * 0.38)
	root.add_child(_mesh_node(body, wood, Vector3(0, body.size.y * 0.5, 0)))

	# Tapa (caja algo más ancha, encima del cuerpo).
	var lid := BoxMesh.new()
	lid.size = Vector3(s * 0.55, s * 0.16, s * 0.41)
	var lid_node := _mesh_node(lid, wood_lid, Vector3(0, body.size.y + lid.size.y * 0.5, 0))
	lid_node.name = "Lid"
	root.add_child(lid_node)

	# Fleje/aro dorado alrededor de la unión cuerpo-tapa.
	var band := BoxMesh.new()
	band.size = Vector3(s * 0.57, s * 0.05, s * 0.43)
	root.add_child(_mesh_node(band, gold, Vector3(0, body.size.y, 0)))

	# Cerradura frontal (cubo dorado saliente en el centro del frente).
	var lock := BoxMesh.new()
	lock.size = Vector3(s * 0.10, s * 0.14, s * 0.05)
	root.add_child(_mesh_node(lock, gold, Vector3(0, body.size.y * 0.9, band.size.z * 0.5)))

	# Patas/esquineras traseras y delanteras (herrajes dorados en las 4 esquinas).
	var foot_h := s * 0.10
	var fx := body.size.x * 0.5 - s * 0.03
	var fz := body.size.z * 0.5 - s * 0.03
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var foot := BoxMesh.new()
			foot.size = Vector3(s * 0.06, foot_h, s * 0.06)
			root.add_child(_mesh_node(foot, gold, Vector3(fx * sx, foot_h * 0.5, fz * sz)))
	return root


## Crea un MeshInstance3D con `mesh`, `mat` y posición local (ayuda de _build_lowpoly_chest).
func _mesh_node(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi


## Busca el primer MeshInstance3D dentro de un nodo (incluido él mismo).
func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node == null or not is_instance_valid(node):
		return null
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		if c is MeshInstance3D:
			return c
		if c is Node3D:
			var found := _find_first_mesh_instance(c)
			if found != null:
				return found
	return null


## Guarda la malla que se resaltará cuando el jugador esté cerca del elemento.
func _track_interactable_mesh(el: Dictionary) -> void:
	if el.has("highlight_mesh"):
		return
	var root: Node = el.get("visual", null)
	if root == null:
		root = el.get("mesh", null)
	var mi := _find_first_mesh_instance(root)
	el["highlight_mesh"] = mi
	if mi != null:
		var mat := mi.material_override as StandardMaterial3D
		if mat != null:
			el["base_emission"] = mat.emission_energy_multiplier
			el["base_emission_enabled"] = mat.emission_enabled
			el["original_emission"] = mat.emission


## Devuelve la OmniLight3D creada.
func _add_light(container: Node3D, pos: Vector3, color: Color, energy: float, rng: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	# OPTIMIZACIÓN MÓVIL: las luces secundarias (antorchas, cristales,
	# braseros…) NO proyectan sombras en tiempo real para evitar pases de sombra
	# costosos en GPU móvil. La única luz con sombras es el sol direccional.
	light.shadow_enabled = false
	container.add_child(light)
	_dynamic_lights.append(light)
	return light


## Task 4 FASE 1.2 — registro de TODAS las luces dinámicas creadas vía
## `_add_light()` (antorchas, cristales, hogueras, lava…), para poder limitar
## cuántas están activas a la vez según la distancia al jugador.
var _dynamic_lights: Array[OmniLight3D] = []


## Apaga (visible=false) las luces dinámicas fuera de `LIGHT_CULL_RANGE` metros
## o que no estén entre las `MAX_ACTIVE_LIGHTS` más cercanas al jugador; el
## resto se reactivan. Precalcula distancias para evitar closures lentos en el hilo.
func _process_light_culling(ppos: Vector3) -> void:
	if _dynamic_lights.is_empty():
		return
	var range_sq: float = LIGHT_CULL_RANGE * LIGHT_CULL_RANGE
	var candidates: Array[Dictionary] = []
	var i := _dynamic_lights.size() - 1
	while i >= 0:
		var light := _dynamic_lights[i]
		if light == null or not is_instance_valid(light) or not light.is_inside_tree():
			_dynamic_lights.remove_at(i)
		else:
			var dsq: float = light.global_position.distance_squared_to(ppos)
			if dsq <= range_sq:
				candidates.append({"light": light, "dsq": dsq})
			else:
				if light.visible:
					light.visible = false
		i -= 1

	if candidates.size() > MAX_ACTIVE_LIGHTS:
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["dsq"]) < float(b["dsq"]))

	for idx in range(candidates.size()):
		var cand := candidates[idx]
		var l := cand["light"] as OmniLight3D
		var should_be_visible := (idx < MAX_ACTIVE_LIGHTS)
		if l.visible != should_be_visible:
			l.visible = should_be_visible


var _flicker_lights: Array[Dictionary] = []


func _process_flicker_lights(_delta: float) -> void:
	if _flicker_lights.is_empty():
		return
	var time := Time.get_ticks_msec() * 0.001
	var i := _flicker_lights.size() - 1
	while i >= 0:
		var d: Dictionary = _flicker_lights[i]
		var light_obj: Variant = d.get("light")
		if light_obj == null or not is_instance_valid(light_obj) or not (light_obj is OmniLight3D) or not (light_obj as OmniLight3D).is_inside_tree():
			_flicker_lights.remove_at(i)
		else:
			var light := light_obj as OmniLight3D
			# Solo recalcular y ensuciar buffer GPU si la luz está visible
			if light.visible:
				var base: float = float(d["base"])
				var str_val: float = float(d["str"])
				var phase: float = float(d["phase"])
				var speed: float = float(d["speed"])
				var noise_val := sin(time * speed + phase) * 0.6 + cos(time * (speed * 0.73) + phase * 1.5) * 0.4
				light.light_energy = base * (1.0 + noise_val * str_val * 0.7)
		i -= 1


## Parpadeo ORGÁNICO de fuego (Game Feel): alto rendimiento sin asignación de Tweens.
func _add_flicker(light: OmniLight3D, base_energy: float, strength: float = 0.35) -> void:
	if light == null or not is_instance_valid(light) or Locale.reduce_motion:
		return
	_flicker_lights.append({
		"light": light,
		"base": base_energy,
		"str": strength,
		"phase": randf() * TAU,
		"speed": randf_range(11.0, 17.0)
	})


## Pulso SUAVE de "respiración" (cristales/runas mágicas): a diferencia del
## parpadeo de fuego, un cristal no titila — brilla y se atenúa con un ritmo
## lento y regular. Un único tween en bucle (sí encaja aquí el `set_loops()`
## periódico: es justo el efecto "constante y calmado" que se busca).
func _add_pulse(light: OmniLight3D, base_energy: float, amplitude: float = 0.28, period: float = 2.4) -> void:
	if light == null or not is_instance_valid(light) or Locale.reduce_motion:
		return
	var tw := light.create_tween().set_loops()
	tw.tween_property(light, "light_energy", base_energy * (1.0 + amplitude), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(light, "light_energy", base_energy * (1.0 - amplitude), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ══════════════════════════════════════════════════════════════════════════════
# CATÁLOGO DE ELEMENTOS INTERACTIVOS Y DECORATIVOS
# Todos son low-poly por código (sin assets) y respetan `rot`/`scale` de la celda,
# para que NADA colocado en el editor sea invisible o inexistente en el motor.
# ══════════════════════════════════════════════════════════════════════════════

## Aplica rotación (grados en Y) y escala uniforme opcionales declaradas en la celda.
func _apply_transform(node: Node3D, cell: Dictionary) -> void:
	var rot = cell.get("rot", null)
	if rot != null:
		node.rotation_degrees.y = float(rot)
	var sc = cell.get("scale", null)
	if sc != null and float(sc) > 0.0:
		node.scale = Vector3.ONE * float(sc)


## Escalera: rampa low-poly de peldaños (visual) + CONEXIÓN REAL entre plantas
##. Antes era puramente decorativa: no había forma de subir a
## la planta de arriba con una mazmorra de 2+ niveles (bug reportado). Como los
## huecos entre plantas apiladas (`FLOOR_GAP` + altura de pared) son demasiado
## grandes para una rampa físicamente caminable en el ancho de una sola celda,
## se reutiliza el MISMO mecanismo que las casillas "teleport" (grupo
## "dungeon_teleport", gestionado por ViewDungeon._on_teleport_entered): si la
## RAMPA / ESCALERA 3D CAMINABLE ENTRE PLANTAS CONTINUAS.
## Construye un plano inclinado 3D exacto que arranca a nivel del suelo (Y=0.0) en el borde frontal
## y asciende hasta la altura del piso superior (Y=_wall_h) en el borde trasero.
## Escalera / Rampa 3D caminable entre plantas continuas.
## Carga el modelo 3D si es una escalera gltf (escalera_con_muros, escalera_estrecha, escalera_madera_simple, escalera_madera_solida)
## y genera un plano inclinado suave ConcavePolygonShape3D para subir y bajar de planta caminando sin tropezar.
func _add_ramp(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var root := Node3D.new()
	root.position = center
	container.add_child(root)

	var t_name := String(cell.get("model", cell.get("prop", cell.get("t", "ramp"))))
	var model_name: String = ""
	if t_name in ["escalera_con_muros", "stairs"]:
		model_name = "escalera_con_muros"

	var stair_node: Node3D = null
	if model_name != "":
		stair_node = ModelLoader.load_model(model_name)

	var half_w: float = _cell * 0.5
	var half_d: float = _cell * 0.5
	var h: float = float(cell.get("h", _wall_h + FLOOR_GAP))

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1

	var p_fl := Vector3(-half_w, 0.0,  half_d)
	var p_fr := Vector3( half_w, 0.0,  half_d)
	var p_bl := Vector3(-half_w, h,   -half_d)
	var p_br := Vector3( half_w, h,   -half_d)

	var p_bfl := Vector3(-half_w, -0.2, half_d)
	var p_bfr := Vector3( half_w, -0.2, half_d)
	var p_bbl := Vector3(-half_w, 0.0, -half_d)
	var p_bbr := Vector3( half_w, 0.0, -half_d)

	if stair_node != null:
		var aabb := _calculate_node_aabb(stair_node)
		# Escala para encajar en el ancho de la celda y alcanzar la altura h del piso superior
		var sc_x: float = (_cell * 0.96) / maxf(aabb.size.x, 0.1)
		var sc_y: float = h / maxf(aabb.size.y, 0.1)
		var sc_z: float = (_cell * 0.96) / maxf(aabb.size.z, 0.1)
		stair_node.scale = Vector3(sc_x, sc_y, sc_z)
		stair_node.position = Vector3(0, 0, -half_d)
		body.add_child(stair_node)
	else:
		var mat: StandardMaterial3D = _surface_material(_mat_wall, String(cell.get("wall", cell.get("tex", ""))), null, "wall")

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mat)

		var norm_top := Vector3(0.0, half_d * 2.0, h).normalized()
		st.set_normal(norm_top)
		st.set_uv(Vector2(0, 1))
		st.add_vertex(p_fl)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(p_bl)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(p_fr)

		st.set_uv(Vector2(1, 1))
		st.add_vertex(p_fr)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(p_bl)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p_br)

		_add_quad_st(st, p_bfl, p_bbl, p_fl, p_bl, Vector3(-1, 0, 0))
		_add_quad_st(st, p_fr, p_br, p_bfr, p_bbr, Vector3(1, 0, 0))
		_add_quad_st(st, p_bl, p_bbl, p_br, p_bbr, Vector3(0, 0, -1))

		var mesh := st.commit()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		body.add_child(mi)

	# Rampa de colisión sólida (prisma 3D) con normales hacia arriba para pisada firme del jugador
	var faces := PackedVector3Array([
		# Cara superior inclinada transitable (normal hacia arriba)
		p_fl, p_fr, p_bl,
		p_fr, p_br, p_bl,
		# Cara superior invertida (doble cara de seguridad)
		p_fl, p_bl, p_fr,
		p_fr, p_bl, p_br,
		# Base inferior
		p_bfl, p_bbl, p_bfr,
		p_bfr, p_bbl, p_bbr,
		# Muro trasero
		p_bl, p_br, p_bbl,
		p_br, p_bbr, p_bbl,
		# Muro lateral izquierdo
		p_fl, p_bl, p_bfl,
		p_bl, p_bbl, p_bfl,
		# Muro lateral derecho
		p_fr, p_bfr, p_br,
		p_br, p_bfr, p_bbr
	])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	root.add_child(body)
	_apply_transform(root, cell)


func _add_quad_st(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, norm: Vector3) -> void:
	st.set_normal(norm)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(p0)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(p1)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(p2)

	st.set_uv(Vector2(1, 1))
	st.add_vertex(p2)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(p1)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(p3)


## Puerta con hoja que GIRA sobre una bisagra al abrirse. Bloquea si state=closed/
## locked; pasable si open (por defecto, para no romper mazmorras existentes
## sin `state`). Registra `eid`. Usa assets/common/models/interactive/puerta_madera.gltf
## (hoja con herrajes que gira sobre su bisagra, enmarcada por jambas de muro);
## si falta el archivo, cae al marco+hoja procedural de reserva.
func _add_door(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	_add_light(container, center + Vector3(0, _wall_h * 0.5, 0), Color(0.9, 0.8, 0.5), 1.4, _cell * 2.0)
	var eid := String(cell.get("eid", ""))
	var state := String(cell.get("state", "open"))
	var kind := String(cell.get("kind", "door"))
	var timed := (kind == "timed")
	var duration := float(cell.get("duration", 1.0)) if timed else 0.0
	var root := Node3D.new()
	root.position = center
	container.add_child(root)
	var hinge := Node3D.new()
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var door_model_name: String = _tile_model_override(String(cell.get("t", "door")), "puerta_madera")
	var door_model: Node3D = ModelLoader.load_model(door_model_name, 1.0)
	if door_model != null:
		# Detectar dimensiones reales del modelo para calcular escala y bisagra
		var aabb := AABB()
		var found_mesh := false
		for mi in door_model.find_children("*", "MeshInstance3D", true, false):
			if mi is MeshInstance3D and mi.mesh:
				var mi_aabb: AABB = mi.transform * mi.mesh.get_aabb()
				if not found_mesh:
					aabb = mi_aabb
					found_mesh = true
				else:
					aabb = aabb.merge(mi_aabb)
		var native_h := aabb.size.y if (found_mesh and aabb.size.y > 0.2) else 2.14
		var native_w := aabb.size.x if (found_mesh and aabb.size.x > 0.2) else 1.11
		var target_h: float = _wall_h * 0.88
		var door_scale: float = target_h / native_h
		door_model.scale = Vector3.ONE * door_scale
		var door_w: float = native_w * door_scale
		var door_h: float = native_h * door_scale

		# Si el origen del modelo ya está en el borde izquierdo (bisagra como en puerta_madera.gltf):
		var hinge_at_origin: bool = (aabb.position.x > -0.15) if found_mesh else true
		if hinge_at_origin:
			hinge.position = Vector3(-door_w * 0.5, 0, 0)
			door_model.position = Vector3(-aabb.position.x * door_scale, -aabb.position.y * door_scale, 0)
		else:
			# Modelo centrado en el origen (formato legado)
			hinge.position = Vector3(-door_w * 0.5, 0, 0)
			door_model.position = Vector3(door_w * 0.5, 0, 0)

		root.add_child(hinge)
		hinge.add_child(body)
		body.add_child(door_model)

		var col_shape := BoxShape3D.new()
		col_shape.size = Vector3(door_w, door_h, maxf(aabb.size.z * door_scale, 0.22))
		col.shape = col_shape
		col.position = Vector3(door_w * 0.5, door_h * 0.5, 0)
		body.add_child(col)

		# Jambas laterales y dintel para enmarcar la puerta en la celda de pared
		var jamb_w := (_cell - door_w) * 0.5
		if jamb_w > 0.05:
			var frame_body := StaticBody3D.new()
			root.add_child(frame_body)
			var wall_mat := _mat_wall
			for sx in [-1.0, 1.0]:
				var jamb_mesh := BoxMesh.new()
				jamb_mesh.size = Vector3(jamb_w, _wall_h, _cell * 0.25)
				var jamb_mi := MeshInstance3D.new()
				jamb_mi.mesh = jamb_mesh
				if wall_mat != null:
					jamb_mi.material_override = wall_mat
				jamb_mi.position = Vector3(sx * (_cell * 0.5 - jamb_w * 0.5), _wall_h * 0.5, 0)
				frame_body.add_child(jamb_mi)
				var j_col := CollisionShape3D.new()
				var j_shape := BoxShape3D.new()
				j_shape.size = jamb_mesh.size
				j_col.shape = j_shape
				j_col.position = jamb_mi.position
				frame_body.add_child(j_col)
			var lintel_h := _wall_h - door_h
			if lintel_h > 0.05:
				var lintel_mesh := BoxMesh.new()
				lintel_mesh.size = Vector3(door_w, lintel_h, _cell * 0.25)
				var lintel_mi := MeshInstance3D.new()
				lintel_mi.mesh = lintel_mesh
				if wall_mat != null:
					lintel_mi.material_override = wall_mat
				lintel_mi.position = Vector3(0, door_h + lintel_h * 0.5, 0)
				frame_body.add_child(lintel_mi)
				var l_col := CollisionShape3D.new()
				var l_shape := BoxShape3D.new()
				l_shape.size = lintel_mesh.size
				l_col.shape = l_shape
				l_col.position = lintel_mi.position
				frame_body.add_child(l_col)
	else:
		var frame := StandardMaterial3D.new()
		frame.albedo_color = Color(0.35, 0.24, 0.14)
		frame.roughness = 0.9
		for sx in [-1.0, 1.0]:
			var post := BoxMesh.new()
			post.size = Vector3(_cell * 0.1, _wall_h * 0.9, _cell * 0.2)
			root.add_child(_mesh_node(post, frame, Vector3(sx * _cell * 0.4, _wall_h * 0.45, 0)))
		# Bisagra en el poste izquierdo: la hoja es hija del pivote, desplazada
		# medio ancho hacia el lado contrario — así GIRA sobre ese borde como una
		# puerta real, en vez de hundirse o desvanecerse.
		hinge.position = Vector3(-_cell * 0.36, 0, 0)
		root.add_child(hinge)
		hinge.add_child(body)
		var leaf := BoxMesh.new()
		leaf.size = Vector3(_cell * 0.72, _wall_h * 0.85, _cell * 0.14)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.5, 0.33, 0.16) if state != "locked" else Color(0.4, 0.28, 0.16)
		lm.roughness = 0.85
		var mi := MeshInstance3D.new()
		mi.mesh = leaf
		mi.material_override = lm
		mi.position = Vector3(leaf.size.x * 0.5, _wall_h * 0.45, 0)
		body.add_child(mi)
		var shape := BoxShape3D.new()
		shape.size = leaf.size
		col.shape = shape
		col.position = mi.position
		body.add_child(col)
	_apply_transform(root, cell)
	var open := (state == "open")
	hinge.rotation_degrees.y = 92.0 if open else 0.0
	col.set_deferred("disabled", open)
	if eid != "":
		var timer: Timer = null
		if timed:
			timer = Timer.new()
			timer.one_shot = true
			timer.wait_time = duration
			timer.timeout.connect(func() -> void: _apply_action(eid, "close"))
			container.add_child(timer)
		var el := { "kind": "door", "hinge": hinge, "col": col, "state": state, "eid": eid, "timed": timed, "duration": duration, "timer": timer }
		_register_element(eid, el)
		_set_element_state(el, true)


## Compuerta de rejas. Bloquea cerrada; pasable abierta. Registra `eid` para que
## un accionador la abra/cierre en tiempo de ejecución.
func _add_gate(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var eid := String(cell.get("eid", ""))
	var state := String(cell.get("state", "closed"))
	var root := Node3D.new()
	root.position = center
	container.add_child(root)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.48, 0.44)
	stone.roughness = 0.95
	for sx in [-1.0, 1.0]:
		var post := BoxMesh.new()
		post.size = Vector3(_cell * 0.12, _wall_h * 0.95, _cell * 0.25)
		root.add_child(_mesh_node(post, stone, Vector3(sx * _cell * 0.42, _wall_h * 0.475, 0)))
	var body := StaticBody3D.new()
	var mesh_root := Node3D.new()
	body.add_child(mesh_root)
	# Reja reemplazable por un .glb/.gltf/.tscn propio (Design.get_dungeon_tile_render("gate").model);
	# la colisión (más abajo) es una caja fija independiente del visual, así
	# que un modelo custom nunca puede dejar la compuerta sin bloquear el paso.
	var gate_model: Node3D = ModelLoader.load_model(_tile_model_override("gate", ""), _cell)
	if gate_model != null:
		mesh_root.add_child(gate_model)
	else:
		var bars_mat := StandardMaterial3D.new()
		bars_mat.albedo_color = Color(0.3, 0.3, 0.34)
		bars_mat.metallic = 0.7
		bars_mat.roughness = 0.4
		for i in range(5):
			var bar := BoxMesh.new()
			bar.size = Vector3(_cell * 0.08, _wall_h * 0.9, _cell * 0.08)
			var xoff := -_cell * 0.32 + (_cell * 0.16) * float(i)
			mesh_root.add_child(_mesh_node(bar, bars_mat, Vector3(xoff, _wall_h * 0.45, 0)))
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_cell * 0.8, _wall_h * 0.9, _cell * 0.12)
	col.shape = shape
	col.position = Vector3(0, _wall_h * 0.45, 0)
	body.add_child(col)
	root.add_child(body)
	_apply_transform(root, cell)
	var open := (state == "open")
	mesh_root.visible = not open
	col.set_deferred("disabled", open)
	if eid != "":
		var el := { "kind": "gate", "mesh": mesh_root, "col": col, "state": state, "base_pos": mesh_root.position }
		_register_element(eid, el)
		_set_element_state(el, true)
		# Apertura POR EVENTO: la compuerta puede declarar `open_on`, el nombre
		# de un evento global. Cuando un Objeto Inteligente lo emite (romper un muro,
		# encender unas raíces, reparar un mecanismo, pulsar un interruptor con la
		# habilidad correspondiente…), la compuerta se abre. Es el puente data-driven
		# que convierte "usar la habilidad" en "avanzar a la siguiente sala".
		var open_on := String(cell.get("open_on", ""))
		if open_on != "":
			GlobalEvents.subscribe(open_on, _on_gate_open_event.bind(eid))



## Contraventana / Puerta de madera con dos estados (abierta / cerrada).
## Bloquea el paso y muestra contraventana_cerrada.gltf si state=closed;
## pasable y muestra contraventana_abierta.gltf si state=open.
## Soporta enlaces con palancas/interruptores vía `eid`.
func _add_shutters(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var eid := String(cell.get("eid", ""))
	var state := String(cell.get("state", "closed"))
	var timed: bool = (String(cell.get("kind", "")) == "timed")
	var duration := float(cell.get("duration", 1.0)) if timed else 0.0

	var root := Node3D.new()
	root.position = center
	container.add_child(root)

	var m_closed: Node3D = ModelLoader.load_model("contraventana_cerrada", _cell * 0.90)
	var m_open: Node3D = ModelLoader.load_model("contraventana_abierta", _cell * 0.90)

	var rot_y := _resolve_rotation_degrees(cell)
	root.rotation_degrees.y = rot_y

	# Ajuste pegado a la pared
	var is_wall_snap: bool = bool(cell.get("wall_snap", cell.get("snap_wall", cell.get("pegado_pared", cell.get("align", "") == "wall"))))
	var z_offset: float = -(_cell * 0.35) if is_wall_snap else 0.0

	if m_closed != null:
		m_closed.position.z = z_offset
		root.add_child(m_closed)
	if m_open != null:
		m_open.position.z = z_offset
		root.add_child(m_open)

	# Colisión sólida (solo activa en estado cerrado)
	var body := StaticBody3D.new()
	var scol := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_cell * 0.9, _wall_h * 0.85, 0.35)
	scol.shape = shape
	scol.position = Vector3(0, _wall_h * 0.45, z_offset)
	body.add_child(scol)
	root.add_child(body)

	_apply_transform(root, cell)

	var open := (state == "open")
	if m_closed != null:
		m_closed.visible = not open
	if m_open != null:
		m_open.visible = open
	scol.set_deferred("disabled", open)

	if eid != "":
		var timer: Timer = null
		if timed:
			timer = Timer.new()
			timer.one_shot = true
			timer.wait_time = duration
			timer.timeout.connect(func() -> void: _apply_action(eid, "close"))
			container.add_child(timer)
		var el := {
			"kind": "shutters",
			"mesh_closed": m_closed,
			"mesh_open": m_open,
			"col": scol,
			"state": state,
			"eid": eid,
			"timed": timed,
			"duration": duration,
			"timer": timer
		}
		_register_element(eid, el)
		_set_element_state(el, true)


## Accionador (interruptor/botón/palanca/placa). Visual por tipo + Área de "pisar"
## que acciona sus `targets` (eids). Se cablea en _wire_actuators(). ## F8: antes el propio accionador NUNCA cambiaba de aspecto al usarse — un
## interruptor "sin lógica visual" no se sentía real (bug reportado: "que un
## interruptor parezca de verdad un interruptor"). Si declara `eid`, ahora se
## registra en `_elements` como cualquier otro elemento con estado: la palanca
## gira, el botón/placa se hunde al pisarlo, con el mismo pipeline de
## sonido+polvo que puertas/compuertas.
func _add_actuator(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var t := String(cell.get("t", ""))
	var eid := String(cell.get("eid", ""))
	var state := String(cell.get("state", "off"))
	# si esta palanca/interruptor ya se accionó en una visita
	# anterior, nace directamente activada en vez de reiniciarse al valor del JSON.
	if eid != "" and _is_actuator_persisted_active(eid):
		_activated_actuators[eid] = true
		state = "on"
	var mode := String(cell.get("mode", ""))
	# Un interruptor puede verse como botón, placa de presión o interruptor de pared.
	var actuator_kind := t
	if t == "switch":
		actuator_kind = mode if mode in ["button", "pressure", "wall"] else "wall"
	var root := Node3D.new()
	root.position = center
	container.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.7)
	mat.metallic = 0.5
	mat.roughness = 0.5
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.7, 0.85)
	mat.emission_energy_multiplier = 1.2
	# `visual` guarda el nodo que se anima al accionar (pivote para la palanca,
	# la propia malla para botón/placa/interruptor de pared).
	var visual: Node3D = null
	var visual_base := Vector3.ZERO
	var lever_led_mat: StandardMaterial3D = null
	var anim_player: AnimationPlayer = null
	match actuator_kind:
		"lever":
			var lever_model: Node3D = ModelLoader.load_model(_tile_model_override(t, "palanca"), _cell * 0.45)
			if lever_model != null:
				lever_model.scale.y *= 0.5
				root.add_child(lever_model)
				anim_player = lever_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if anim_player == null:
					for ch in lever_model.find_children("*", "AnimationPlayer", true, false):
						if ch is AnimationPlayer:
							anim_player = ch as AnimationPlayer
							break
				var is_on := (state == "open" or state == "on")
				if anim_player != null:
					var init_anim := "Lever_On" if is_on else "Lever_Off"
					if anim_player.has_animation(init_anim):
						anim_player.play(init_anim)
						anim_player.seek(anim_player.get_animation(init_anim).length, true)
				visual = lever_model
			else:
				var base_mat := StandardMaterial3D.new()
				base_mat.albedo_color = Color(0.18, 0.18, 0.22)
				base_mat.metallic = 0.8
				base_mat.roughness = 0.3
				var base := BoxMesh.new()
				base.size = Vector3(_cell * 0.22, 0.14, _cell * 0.22)
				root.add_child(_mesh_node(base, base_mat, Vector3(0, 0.07, 0)))

				var rim_mat := StandardMaterial3D.new()
				rim_mat.albedo_color = Color(0.8, 0.65, 0.25)
				rim_mat.metallic = 0.9
				rim_mat.roughness = 0.2
				var rim := CylinderMesh.new()
				rim.top_radius = _cell * 0.09
				rim.bottom_radius = _cell * 0.10
				rim.height = 0.06
				root.add_child(_mesh_node(rim, rim_mat, Vector3(0, 0.14, 0)))

				var pivot := Node3D.new()
				pivot.position = Vector3(0, 0.16, 0)
				root.add_child(pivot)

				var handle_mat := StandardMaterial3D.new()
				handle_mat.albedo_color = Color(0.7, 0.7, 0.75)
				handle_mat.metallic = 0.9
				handle_mat.roughness = 0.25
				var handle := CylinderMesh.new()
				handle.top_radius = 0.04
				handle.bottom_radius = 0.05
				handle.height = _cell * 0.225
				pivot.add_child(_mesh_node(handle, handle_mat, Vector3(0, _cell * 0.11, 0)))

				var knob_mesh := SphereMesh.new()
				knob_mesh.radius = 0.05
				knob_mesh.height = 0.10
				pivot.add_child(_mesh_node(knob_mesh, rim_mat, Vector3(0, _cell * 0.22, 0)))

				lever_led_mat = StandardMaterial3D.new()
				var is_on := (state == "open" or state == "on")
				lever_led_mat.albedo_color = Color(0.1, 1.0, 0.6) if is_on else Color(1.0, 0.2, 0.1)
				lever_led_mat.emission_enabled = true
				lever_led_mat.emission = Color(0.1, 1.0, 0.6) if is_on else Color(1.0, 0.2, 0.1)
				lever_led_mat.emission_energy_multiplier = 3.0
				var led_mesh := SphereMesh.new()
				led_mesh.radius = 0.035
				led_mesh.height = 0.07
				root.add_child(_mesh_node(led_mesh, lever_led_mat, Vector3(0, 0.18, _cell * 0.09)))

				visual = pivot
				visual_base = Vector3(-65.0, 0, 0)
		"button", "pressure":
			var plate_model: Node3D = ModelLoader.load_model(_tile_model_override(t, "interruptor"))
			if plate_model != null:
				root.add_child(plate_model)
				visual = plate_model
				visual_base = plate_model.position
			else:
				var plate := CylinderMesh.new()
				plate.top_radius = _cell * 0.3
				plate.bottom_radius = _cell * 0.32
				plate.height = 0.12
				var pn := _mesh_node(plate, mat, Vector3(0, 0.06, 0))
				root.add_child(pn)
				visual = pn
				visual_base = pn.position
		_:
			var switch_model: Node3D = ModelLoader.load_model(_tile_model_override(t, "interruptor"))
			if switch_model != null:
				switch_model.position = Vector3(0, _cell * 0.3, -_cell * 0.35)
				root.add_child(switch_model)
				visual = switch_model
				visual_base = switch_model.position
			else:
				var boxm := BoxMesh.new()
				boxm.size = Vector3(_cell * 0.3, _cell * 0.3, 0.12)
				var sn := _mesh_node(boxm, mat, Vector3(0, _cell * 0.3, -_cell * 0.35))
				root.add_child(sn)
				visual = sn
				visual_base = sn.position
	_apply_transform(root, cell)
	var area := Area3D.new()
	area.collision_mask = 2
	area.position = center + Vector3(0, 0.4, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_cell * 0.8, 1.2, _cell * 0.8)
	col.shape = shape
	area.add_child(col)
	container.add_child(area)
	if actuator_kind == "lever" and eid == "":
		eid = "_lever_%d_%d" % [int(center.x), int(center.z)]
	var targets = cell.get("targets", [])
	var targets_arr: Array = targets if (targets is Array) else []
	if targets_arr.size() > 0 or eid != "":
		_actuators.append({ "area": area, "targets": targets_arr, "eid": eid })

	# Objeto inteligente para activación por habilidades a distancia (Onda Cinética / Agarre Psíquico)
	if actuator_kind in ["lever", "switch", "wall", "button"]:
		var inter := Interactable.new()
		inter.name = "Interactable"
		inter.set_host(root)
		var custom_verbs: PackedStringArray = PackedStringArray()
		if cell.has("verbs") and cell["verbs"] is Array:
			custom_verbs = PackedStringArray(cell["verbs"])
		var react := ReactionActuator.new(trigger_actuator.bind(eid, targets_arr), custom_verbs)
		inter.add_child(react)
		area.add_child(inter)
	if eid != "" and visual != null:
		var kind := actuator_kind if actuator_kind != "" else "switch"
		var single_use: bool = bool(cell.get("single_use", not bool(cell.get("multi_use", cell.get("toggle", false)))))
		var el := {
			"kind": kind,
			"state": state,
			"visual": visual,
			"visual_base": visual_base,
			"anim_player": anim_player,
			"single_use": single_use
		}
		if actuator_kind == "lever" and lever_led_mat != null:
			el["led_mat"] = lever_led_mat
		_register_element(eid, el)
		_set_element_state(el, true)


## Placa de presión SOSTENIDA con contrapeso (idea.md §1.3): a diferencia del
## accionador "button"/"pressure" (`_add_actuator`, toggle persistente de un
## solo pisotón del jugador), esta placa permanece activa MIENTRAS haya sobre
## ella el jugador o un objeto suficientemente pesado (`RigidBody3D` con
## `mass >= min_mass`, p. ej. las cajas/estatuas del kit "kinetic_wave" de
## `DungeonSmartFactory`), y se desactiva en cuanto queda vacía. No participa
## del sistema de `_activated_actuators`/persistencia de las palancas (no
## tiene sentido persistir "hay algo encima" entre visitas): actúa
## directamente sobre `_apply_action(eid, "open"/"close")` de sus `targets`.
func _add_weight_plate(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var min_mass: float = float(cell.get("min_mass", 1.0))
	var targets = cell.get("targets", [])

	var root := Node3D.new()
	root.position = center
	container.add_child(root)

	var plate_base_y := 0.07
	# Reemplazable por un modelo propio (Design.get_dungeon_tile_render("weight_plate").model);
	# el Area3D de detección (abajo) es independiente del visual elegido.
	var plate_node: Node3D = ModelLoader.load_model(_tile_model_override("weight_plate", ""), _cell * 0.7)
	if plate_node != null:
		plate_node.position = Vector3(0, plate_base_y, 0)
		root.add_child(plate_node)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.4, 0.2)
		mat.metallic = 0.4
		mat.roughness = 0.6
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.45, 0.2)
		mat.emission_energy_multiplier = 0.8
		var plate := CylinderMesh.new()
		plate.top_radius = _cell * 0.36
		plate.bottom_radius = _cell * 0.4
		plate.height = 0.14
		plate_node = _mesh_node(plate, mat, Vector3(0, plate_base_y, 0))
		root.add_child(plate_node)

	var area := Area3D.new()
	area.collision_mask = 3  # jugador (capa 2) + objetos físicos empujables (capa 1 por defecto)
	area.position = Vector3(0, 0.3, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(_cell * 0.75, 0.6, _cell * 0.75)
	col.shape = shape
	area.add_child(col)
	root.add_child(area)

	var occupants: Array = []

	var apply_to_targets := func(action: String) -> void:
		if not (targets is Array):
			return
		for tg in targets:
			if tg is Dictionary:
				_apply_action(String(tg.get("eid", "")), action)

	var qualifies := func(body: Node) -> bool:
		if body is CharacterBody3D:
			return true
		if body is RigidBody3D:
			return (body as RigidBody3D).mass >= min_mass
		return false

	area.body_entered.connect(func(body: Node) -> void:
		if not qualifies.call(body) or occupants.has(body):
			return
		occupants.append(body)
		if occupants.size() == 1:
			apply_to_targets.call("open")
			AudioManager.play_sfx("click")
			if is_instance_valid(plate_node):
				var tw := plate_node.create_tween()
				tw.tween_property(plate_node, "position:y", plate_base_y - 0.06, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	area.body_exited.connect(func(body: Node) -> void:
		occupants.erase(body)
		if occupants.is_empty():
			apply_to_targets.call("close")
			if is_instance_valid(plate_node):
				var tw := plate_node.create_tween()
				tw.tween_property(plate_node, "position:y", plate_base_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	)


## Desplazamiento de rejilla (gx, gy) hacia la casilla vecina de cada cara.
const _TORCH_FACE_OFFSET := {
	"norte": Vector2i(0, -1),
	"sur":   Vector2i(0, 1),
	"este":  Vector2i(1, 0),
	"oeste": Vector2i(-1, 0),
}

## Normaliza cualquier sinónimo de cara (español/inglés/grados) a una de las 4
## claves canónicas usadas por `_TORCH_FACE_OFFSET`.
func _canonical_wall_face(raw: String) -> String:
	match raw:
		"sur", "south", "0", "0.0": return "sur"
		"este", "east", "270", "270.0": return "este"
		"oeste", "west", "90", "90.0": return "oeste"
		_: return "norte"

## Tipo (`t`) de la casilla en (gx, gy) de la planta que se está construyendo,
## o "" si cae fuera de la rejilla.
func _cell_type_at(gx: int, gy: int) -> String:
	if gy < 0 or gy >= _current_floor_cells.size():
		return ""
	var row: Array = _current_floor_cells[gy]
	if gx < 0 or gx >= row.size():
		return ""
	var c = row[gx]
	return String(c.get("t", "")) if c is Dictionary else ""

## ¿La casilla vecina en esa cara (norte/sur/este/oeste) es una pared real?
func _has_wall_on_face(gx: int, gy: int, face: String) -> bool:
	var off: Vector2i = _TORCH_FACE_OFFSET.get(face, Vector2i.ZERO)
	return _cell_type_at(gx + off.x, gy + off.y) == "wall"

## Antorcha de pared con modelo GLTF realista: mango anclado e inclinada en diagonal hacia la sala con luz cálida parpadeante.
func _add_torch(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var root := Node3D.new()

	# Determinar en qué cara de la pared (norte, sur, este, oeste) se coloca la antorcha
	var torch_face := String(cell.get("torch_face", cell.get("face", ""))).to_lower()
	if torch_face == "":
		var rot_num: float = float(cell.get("rot", 180))
		if rot_num == 0.0: torch_face = "sur"
		elif rot_num == 90.0: torch_face = "oeste"
		elif rot_num == 270.0: torch_face = "este"
		else: torch_face = "norte"
	torch_face = _canonical_wall_face(torch_face)

	# Auto-corrección: si la cara declarada NO tiene pared real al lado, se
	# recoloca en la primera cara adyacente que sí la tenga — evita antorchas
	# "flotando en el aire" cuando el dato de la mazmorra quedó desalineado.
	var gx: int = int(cell.get("gx", 0))
	var gy: int = int(cell.get("gy", 0))
	if not _has_wall_on_face(gx, gy, torch_face):
		for candidate in ["norte", "sur", "este", "oeste"]:
			if _has_wall_on_face(gx, gy, candidate):
				torch_face = candidate
				break

	var wall_pos := Vector3.ZERO
	var rot_y := 0.0

	match torch_face:
		"sur":
			wall_pos = center + Vector3(0, _wall_h * 0.50, _cell * 0.46)
			rot_y = 180.0
		"este":
			wall_pos = center + Vector3(_cell * 0.46, _wall_h * 0.50, 0)
			rot_y = -90.0
		"oeste":
			wall_pos = center + Vector3(-_cell * 0.46, _wall_h * 0.50, 0)
			rot_y = 90.0
		_: # "norte" por defecto (pared del fondo)
			wall_pos = center + Vector3(0, _wall_h * 0.50, -_cell * 0.46)
			rot_y = 0.0

	root.position = wall_pos
	root.rotation_degrees = Vector3(0, rot_y, 0)
	root.name = "Torch"
	container.add_child(root)

	# Modelo 3D GLTF de antorcha encendida (reemplazable desde el editor, igual
	# que columna/estatua/puerta: Design.get_dungeon_tile_render("torch").model).
	var torch_model: Node3D = ModelLoader.load_model(_tile_model_override("torch", "antorcha_encendida"), 0.45)
	if torch_model != null:
		# Inclinada en diagonal saliendo de la pared hacia la sala (+X en rotación)
		torch_model.rotation_degrees.x = 22.0
		torch_model.position = Vector3(0, 0.0, 0.05)
		root.add_child(torch_model)

	var fire_local_pos := Vector3(0, 0.32, 0.16)
	var torch_light := _add_light(container, root.position + fire_local_pos.rotated(Vector3.UP, deg_to_rad(rot_y)), Color(1.0, 0.65, 0.28), 1.7, _cell * 2.4)
	torch_light.name = "TorchLight"
	_defer_tween_setup(func() -> void: _add_flicker(torch_light, 1.7))


## Cristal luminoso: prisma translúcido emisivo + luz azulada.
func _add_crystal(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var root := Node3D.new()
	root.position = center
	container.add_child(root)
	# Reemplazable por un modelo propio (Design.get_dungeon_tile_render("crystal").model);
	var crystal_model: Node3D = ModelLoader.load_model(_tile_model_override("crystal", ""), _cell * 0.5)
	if crystal_model != null:
		crystal_model.position = Vector3(0, _cell * 0.1, 0)
		root.add_child(crystal_model)
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.4, 0.7, 1.0, 0.8)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.4, 0.7, 1.0)
		m.emission_energy_multiplier = 2.2
		m.roughness = 0.1
		m.metallic = 0.3
		var pm := PrismMesh.new()
		pm.size = Vector3(_cell * 0.4, _cell * 0.8, _cell * 0.4)
		root.add_child(_mesh_node(pm, m, Vector3(0, _cell * 0.4, 0)))
	_apply_transform(root, cell)
	var crystal_light := _add_light(container, center + Vector3(0, _cell * 0.5, 0), Color(0.4, 0.7, 1.0), 1.4, _cell * 2.2)
	_defer_tween_setup(func() -> void: _add_pulse(crystal_light, 1.4))


## Devuelve la fuente pedida por la celda. Cachea SystemFont y reconoce aliases
## como "horror" / "creepy" / "cinzel" para usar fuentes del sistema.
func _get_font(font_key: String) -> Font:
	var key := font_key.to_lower().strip_edges()
	if key == "" or key == "default":
		var hf := UiKit.heading_font() if UiKit != null else null
		return hf if hf != null else ThemeDB.fallback_font
	if _font_cache.has(key):
		return _font_cache[key]
	if key in ["cinzel", "carved", "ancient", "stone", "tumba", "monumental", "horror", "creepy", "blood"]:
		var hf := UiKit.heading_font()
		if hf != null:
			_font_cache[key] = hf
			return hf
	if key in ["garamond", "manuscript", "serif", "parchment", "diary", "manuscrito"]:
		var tf := UiKit.theme_font()
		if tf != null:
			_font_cache[key] = tf
			return tf
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([key, "Cinzel", "EBGaramond", "Georgia", "Baskerville", "Palatino", "Times New Roman", "serif"])
	sf.font_weight = 600
	_font_cache[key] = sf
	return sf


## Señaléctica Data-Driven (Flechas y Textos en Paredes y Suelos)
## Todo el renderizado usa draw_string / draw_colored_polygon en Control.draw
## para garantizar que el SubViewport tenga contenido desde el primer frame.
func _add_signage_overlay(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var raw_dir := String(cell.get("arrow", cell.get("arrow_dir", ""))).to_lower()
	var raw_text = cell.get("text", "")
	var text_str: String = Locale.pick(raw_text) if Locale != null else (raw_text.get("es", "") if raw_text is Dictionary else str(raw_text))
	if raw_dir == "" and text_str == "":
		return

	# Normalizar dirección de la flecha
	var dir := "up"
	if raw_dir in ["left", "izquierda"]: dir = "left"
	elif raw_dir in ["right", "derecha"]: dir = "right"
	elif raw_dir in ["down", "abajo"]: dir = "down"
	elif raw_dir in ["up", "arriba"]: dir = "up"

	var t_type := String(cell.get("t", "")).to_lower()
	var tile_render: Dictionary = Design.get_dungeon_tile_render(t_type)
	var tile_shape := String(tile_render.get("shape", "")).to_lower()
	var is_wall: bool = (t_type == "wall" or t_type.contains("wall") or tile_shape == "wall" or cell.has("wall") or cell.has("h"))

	# Colores desde el editor (hex libre o nombres legados). Por defecto, un
	# dorado tenue de "runa tallada e iluminada" en vez del cian/amarillo plano
	# de antes, que chocaba con la piedra/roca realista del resto de la mazmorra.
	var parsed_a = _parse_color(cell.get("arrow_color", ""))
	var arrow_col: Color = parsed_a if parsed_a is Color else Color(0.85, 0.64, 0.22)

	var parsed_t = _parse_color(cell.get("text_color", ""))
	var text_col: Color = parsed_t if parsed_t is Color else Color(1.0, 0.96, 0.82)

	var rot_deg: float = float(cell.get("rot", 0))

	# Determinar caras de proyección según la selección explícita del editor
	var angles: Array = []
	if is_wall:
		var face_val := String(cell.get("wall_face", cell.get("face", "sur"))).to_lower()
		match face_val:
			"norte", "north":
				angles = [180.0]
			"este", "east":
				angles = [90.0]
			"oeste", "west":
				angles = [270.0]
			"todas", "all", "360":
				angles = [0.0, 90.0, 180.0, 270.0]
			_: # "sur" por defecto
				angles = [0.0]
	else:
		angles = [rot_deg]

	# SubViewport para el renderizado del letrero (UPDATE_ONCE: se dibuja una sola vez)
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(vp)

	var panel := Control.new()
	panel.custom_minimum_size = Vector2(512, 512)
	panel.size = Vector2(512, 512)
	vp.add_child(panel)

	# Drawer único para todo el renderizado
	var drawer := Control.new()
	drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Capturar variables para el closure
	var _dir := dir
	var _raw_dir := raw_dir
	var _text := text_str
	var _acol := arrow_col
	var _tcol := text_col
	var raw_bg = cell.get("text_bg", false)
	var _show_bg: bool = (raw_bg == true or str(raw_bg).to_lower() == "true")
	var _fnt: Font = _get_font(String(cell.get("text_font", "ancient" if is_wall else "default")))
	var _text_size: int = int(cell.get("text_size", 0))
	# Flechas de suelo/pared: alpha reducido aún más (
	# "demasiado llamativas... más disimuladas, que no sea tan invasivo") — antes
	# 0.88/0.7, ahora bastante más tenues para leerse como una marca discreta
	# en la piedra en vez de un icono llamativo.
	var _fill_alpha: float = 0.55 if is_wall else 0.4

	drawer.draw.connect(func() -> void:
		var vc := Vector2(256, 256)
		var fnt: Font = _fnt

		# ── MODO 1: FLECHA + TEXTO → Texto DENTRO de la flecha ────
		if _raw_dir != "" and _text != "":
			# Dibujar flecha orientada en (vc = 256, 256)
			var pts := PackedVector2Array()
			pts.append(Vector2(0, -210))
			pts.append(Vector2(140, -50))
			pts.append(Vector2(70, -50))
			pts.append(Vector2(70, 200))
			pts.append(Vector2(-70, 200))
			pts.append(Vector2(-70, -50))
			pts.append(Vector2(-140, -50))

			var rot_rad := 0.0
			match _dir:
				"down": rot_rad = PI
				"left": rot_rad = -PI * 0.5
				"right": rot_rad = PI * 0.5

			var final_pts := PackedVector2Array()
			for pt in pts:
				final_pts.append(pt.rotated(rot_rad) + vc)

			drawer.draw_colored_polygon(final_pts, Color(_acol.r, _acol.g, _acol.b, _fill_alpha))
			var border_pts := final_pts.duplicate()
			border_pts.append(final_pts[0])
			# Borde de "resplandor tallado": halo ancho y tenue en el color de la
			# runa + un filo interior fino y cálido, en vez del contorno blanco
			# duro anterior. Alphas rebajados de nuevo
			# para que el brillo del filo no
			# compita con el resto de la escena.
			drawer.draw_polyline(border_pts, Color(_acol.r, _acol.g, _acol.b, 0.20), 14.0, true)
			drawer.draw_polyline(border_pts, Color(1.0, 0.92, 0.75, 0.5), 3.0, true)

			# Determinar el centro del rectángulo/cuerpo de la flecha según su orientación
			var body_center := vc
			var max_w := 120.0
			match _dir:
				"up":
					body_center = vc + Vector2(0, 65)
					max_w = 110.0
				"down":
					body_center = vc + Vector2(0, -65)
					max_w = 110.0
				"left":
					body_center = vc + Vector2(50, 0)
					max_w = 210.0
				"right":
					body_center = vc + Vector2(-50, 0)
					max_w = 210.0

			var fsize := _text_size if _text_size > 0 else 24
			var outline_sz := 2
			var words := _text.split(" ")
			var lines: Array[String] = []
			var cur := ""
			for w in words:
				var tl := (cur + " " + w).strip_edges() if cur != "" else w
				if fnt.get_string_size(tl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_w and cur != "":
					lines.append(cur)
					cur = w
				else:
					cur = tl
			if cur != "":
				lines.append(cur)

			var lh := fnt.get_height(fsize) + 2.0
			var th := lh * lines.size()
			var sy := body_center.y - th * 0.5 + fnt.get_ascent(fsize)

			for i in lines.size():
				var ln := lines[i]
				var lw := fnt.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
				var lx := body_center.x - lw * 0.5
				var ly := sy + i * lh
				drawer.draw_string(fnt, Vector2(lx + 1.5, ly + 1.5), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.04, 0.03, 0.02, 0.7))
				drawer.draw_string_outline(fnt, Vector2(lx, ly), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, outline_sz, Color(0.05, 0.04, 0.03, 0.5))
				drawer.draw_string(fnt, Vector2(lx, ly), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, _tcol)

		# ── MODO 2: SOLO FLECHA (sin texto) ───────────────────────
		elif _raw_dir != "":
			var pts := PackedVector2Array()
			pts.append(Vector2(0, -190))
			pts.append(Vector2(125, -50))
			pts.append(Vector2(60, -50))
			pts.append(Vector2(60, 180))
			pts.append(Vector2(-60, 180))
			pts.append(Vector2(-60, -50))
			pts.append(Vector2(-125, -50))

			var rot_rad := 0.0
			match _dir:
				"down": rot_rad = PI
				"left": rot_rad = -PI * 0.5
				"right": rot_rad = PI * 0.5

			var final_pts := PackedVector2Array()
			for pt in pts:
				final_pts.append(pt.rotated(rot_rad) + vc)

			drawer.draw_colored_polygon(final_pts, Color(_acol.r, _acol.g, _acol.b, _fill_alpha))
			var border_pts := final_pts.duplicate()
			border_pts.append(final_pts[0])
			# Mismo halo cálido tallado que el Modo 1, con los alphas rebajados
			# de (ver comentario ahí).
			drawer.draw_polyline(border_pts, Color(_acol.r, _acol.g, _acol.b, 0.20), 14.0, true)
			drawer.draw_polyline(border_pts, Color(1.0, 0.92, 0.75, 0.5), 3.0, true)

		# ── MODO 3: SOLO TEXTO (sin flecha) → Placa grabada ──────
		elif _text != "":
			# Fondo placa (solo si el usuario lo activó en el editor)
			if _show_bg:
				var bg_rect := Rect2(30, 80, 452, 352)
				drawer.draw_rect(bg_rect, Color(0.04, 0.05, 0.08, 0.78))
				drawer.draw_rect(bg_rect, Color(_acol.r, _acol.g, _acol.b, 0.50), false, 4.0)

			var fsize := _text_size if _text_size > 0 else 32
			var outline_sz := 2
			var text_x_margin := 40.0
			var text_width := 512.0 - text_x_margin * 2.0

			var words := _text.split(" ")
			var lines: Array[String] = []
			var cur := ""
			for w in words:
				var tl := (cur + " " + w).strip_edges() if cur != "" else w
				if fnt.get_string_size(tl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > text_width and cur != "":
					lines.append(cur)
					cur = w
				else:
					cur = tl
			if cur != "":
				lines.append(cur)

			var lh := fnt.get_height(fsize) + 5.0
			var th := lh * lines.size()
			var sy := 80.0 + (352.0 - th) * 0.5 + fnt.get_ascent(fsize)

			for i in lines.size():
				var ln := lines[i]
				var lw := fnt.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
				var lx := (512.0 - lw) * 0.5
				var ly := sy + i * lh
				# Relieve tallado en piedra: sombra sutil de cincel (offset 2px) + contorno ligero
				drawer.draw_string(fnt, Vector2(lx + 2.0, ly + 2.0), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.03, 0.02, 0.02, 0.65))
				drawer.draw_string_outline(fnt, Vector2(lx, ly), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, outline_sz, Color(0.05, 0.04, 0.03, 0.45))
				drawer.draw_string(fnt, Vector2(lx, ly), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, _tcol)
	)
	panel.add_child(drawer)

	# Material 3D para la textura proyectada
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = vp.get_texture()
	mat.emission_enabled = true
	mat.emission_texture = vp.get_texture()
	var emission_val: float = float(cell.get("text_emission", -1.0))
	if emission_val >= 0.0:
		mat.emission_energy_multiplier = emission_val
	else:
		# Textura de piedra tallada: emisión tenue realista para no parecer neón
		mat.emission_energy_multiplier = 0.12 if is_wall else 0.25

	var quad := QuadMesh.new()
	if is_wall:
		quad.size = Vector2(_cell * 0.88, _wall_h * 0.78)
		for angle in angles:
			var qnode := MeshInstance3D.new()
			qnode.mesh = quad
			qnode.material_override = mat
			var offset_dist := _cell * 0.505
			var face_offset := Vector3(0, _wall_h * 0.5, offset_dist).rotated(Vector3.UP, deg_to_rad(angle))
			qnode.position = center + face_offset
			qnode.rotation_degrees = Vector3(0, angle, 0)
			qnode.name = "Signage"
			container.add_child(qnode)
	else:
		quad.size = Vector2(_cell * 0.88, _cell * 0.88)
		var qnode := MeshInstance3D.new()
		qnode.mesh = quad
		qnode.material_override = mat
		qnode.position = center + Vector3(0, 0.018, 0)
		qnode.rotation_degrees = Vector3(-90.0, rot_deg, 0)
		qnode.name = "Signage"
		container.add_child(qnode)


## Decoración ambiental MUY dispersa en casillas de suelo llano (task_revision.md
## #4: "las mazmorras esta sumamente pobre... generar aleatoriamente elementos
## decorativo igual que hacemos con las casillas en el mapamundi"): escombros
## sueltos u hongos, determinista por (gx,gy) para que la mazmorra se vea igual
## entre visitas/recargas. Puramente cosmético: sin colisión, no se registra en
## `_elements`. Si el modelo no existe (ResourceLoader), simplemente no pone nada
## (no hay geometría de contingencia razonable para "escombro genérico").
func _add_floor_clutter(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var gx: int = int(cell.get("gx", 0))
	var gy: int = int(cell.get("gy", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = (gx * 1234567) ^ (gy * 7654321) ^ 0x9c3fa17d
	var r_val := rng.randf()
	var model_name := ""
	var scale_min := 0.16
	var scale_max := 0.3
	var acc := 0.0
	for entry in (_theme.get("clutter", []) as Array):
		acc += float(entry.get("chance", 0.0))
		if r_val < acc:
			model_name = String(entry.get("model", ""))
			scale_min = float(entry.get("scale_min", 0.16))
			scale_max = float(entry.get("scale_max", 0.3))
			break
	if model_name == "":
		return
	var prop: Node3D = ModelLoader.load_model(model_name, rng.randf_range(scale_min, scale_max))
	if prop == null:
		return
	prop.position = center + Vector3(rng.randf_range(-_cell * 0.3, _cell * 0.3), 0.01, rng.randf_range(-_cell * 0.3, _cell * 0.3))
	prop.rotation.y = rng.randf_range(0.0, TAU)
	container.add_child(prop)


# ══════════════════════════════════════════════════════════════════════════════
# TASK 3 FASE 2 — MOTOR DE SCATTER SEGURO (CAPAS 1/2/3, ver docs/tasks/
# task3_sonnet_atmosfera_mazmorras_y_auto_scatter.md). ADITIVO a
# `_add_floor_clutter` de arriba (que ya cubría el scatter "clásico" de
# objetos de suelo): estas tres capas nuevas son ESTRICTAMENTE seguras para la
# navegación — cero colisión física, cero volumen en el centro transitable de
# una casilla, y posición 100% determinista (se recalcula igual cada visita).
# Cada tema (`THEME_CATALOG`) puede declarar `wall_decor`/`corner_decor`
# (mismo formato que `clutter`: {model, chance, scale_min, scale_max}) y
# `decal_color` (Color); si faltan, la capa correspondiente simplemente no
# genera nada (no hay "relleno genérico" forzado, igual que `clutter: []`).
# ══════════════════════════════════════════════════════════════════════════════

## Tirada determinista [0,1) para una celda concreta de una planta, con una
## "sal" que separa las tiradas de cada capa/uso entre sí (para que CAPA 1,
## CAPA 2 y CAPA 3 no compartan resultado y se acoplen). Se basa en el id de
## mazmorra + planta + coordenadas de rejilla: la MISMA sala genera SIEMPRE la
## MISMA decoración entre visitas y recargas (regla de "Generación Determinista").
func _scatter_roll(gx: int, gy: int, floor_index: int, salt: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|%d|%d" % [_dungeon_id, floor_index, gx, gy, salt])
	return rng.randf()


## Elimina cualquier colisionador físico de un prop cargado con `ModelLoader`.
## Las 3 capas de scatter seguro son PURAMENTE visuales (regla "Cero Colisiones
## Físicas en Adornos"): nunca deben alterar la física del jugador ni de
## proyectiles, aunque el modelo original traiga cuerpo/forma de colisión.
func _strip_collisions(node: Node3D) -> void:
	for body in node.find_children("*", "StaticBody3D", true, false):
		body.queue_free()
	for shape in node.find_children("*", "CollisionShape3D", true, false):
		shape.queue_free()


## CAPA 1 (Wall-Attached): adorno de pared (enredaderas, hojas, musgo…) pegado
## a la cara de una celda "wall" que da a una celda transitable (nunca en una
## pared "enterrada" entre otras paredes, donde no se vería). La separación
## mínima (~4 casillas) se logra restringiendo qué celdas siquiera evalúan la
## tirada: solo aquellas alineadas a la rejilla dispersa `gx%4==0 or gy%4==0`.
func _apply_wall_decor(container: Node3D, center: Vector3, cell: Dictionary, floor_index: int) -> void:
	var pool: Array = _theme.get("wall_decor", [])
	if pool.is_empty():
		return
	var gx: int = int(cell.get("gx", 0))
	var gy: int = int(cell.get("gy", 0))
	if gx % 4 != 0 and gy % 4 != 0:
		return
	var free_face := ""
	for face in ["norte", "sur", "este", "oeste"]:
		if not _has_wall_on_face(gx, gy, face):
			free_face = face
			break
	if free_face == "":
		return
	if _scatter_roll(gx, gy, floor_index, 101) > 0.22:
		return
	var model_name := ""
	var scale_min := 0.3
	var scale_max := 0.5
	var acc := 0.0
	var pick := _scatter_roll(gx, gy, floor_index, 102)
	for entry in pool:
		acc += float(entry.get("chance", 0.0))
		if pick < acc:
			model_name = String(entry.get("model", ""))
			scale_min = float(entry.get("scale_min", 0.3))
			scale_max = float(entry.get("scale_max", 0.5))
			break
	if model_name == "":
		return
	var s: float = lerpf(scale_min, scale_max, _scatter_roll(gx, gy, floor_index, 103))
	var prop: Node3D = ModelLoader.load_model(model_name, s)
	if prop == null:
		return
	_strip_collisions(prop)
	# Misma convención cara→posición/rotación que `_add_torch` (norte/sur/
	# este/oeste), pegado al zócalo de la pared, con jitter vertical sutil.
	var wall_pos := Vector3.ZERO
	var rot_y := 0.0
	match free_face:
		"sur":
			wall_pos = center + Vector3(0, 0, _cell * 0.47)
			rot_y = 180.0
		"este":
			wall_pos = center + Vector3(_cell * 0.47, 0, 0)
			rot_y = -90.0
		"oeste":
			wall_pos = center + Vector3(-_cell * 0.47, 0, 0)
			rot_y = 90.0
		_:
			wall_pos = center + Vector3(0, 0, -_cell * 0.47)
			rot_y = 0.0
	var jitter_y: float = lerpf(_wall_h * 0.15, _wall_h * 0.55, _scatter_roll(gx, gy, floor_index, 104))
	prop.position = wall_pos + Vector3(0, jitter_y, 0)
	prop.rotation.y = deg_to_rad(rot_y)
	container.add_child(prop)


## CAPA 2 (Corner-Only): pequeño grupo decorativo (setas, flores, escombros)
## SOLO en celdas de suelo con EXACTAMENTE 2 paredes perpendiculares
## adyacentes (esquina en "L", 90°) — nunca en pasillos rectos (2 paredes
## opuestas) ni en celdas sin ninguna pared cerca. Se pega hacia esa esquina,
## jamás al centro transitable de la casilla.
func _apply_corner_decor(container: Node3D, center: Vector3, cell: Dictionary, floor_index: int) -> void:
	var pool: Array = _theme.get("corner_decor", [])
	if pool.is_empty():
		return
	var gx: int = int(cell.get("gx", 0))
	var gy: int = int(cell.get("gy", 0))
	var walls: Array[String] = []
	for face in ["norte", "sur", "este", "oeste"]:
		if _has_wall_on_face(gx, gy, face):
			walls.append(face)
	if walls.size() != 2:
		return
	const OPPOSITE := {"norte": "sur", "sur": "norte", "este": "oeste", "oeste": "este"}
	if OPPOSITE.get(walls[0], "") == walls[1]:
		return  # paredes opuestas = pasillo recto, no esquina en L
	if _scatter_roll(gx, gy, floor_index, 201) > 0.28:
		return
	var model_name := ""
	var scale_min := 0.25
	var scale_max := 0.4
	var acc := 0.0
	var pick := _scatter_roll(gx, gy, floor_index, 202)
	for entry in pool:
		acc += float(entry.get("chance", 0.0))
		if pick < acc:
			model_name = String(entry.get("model", ""))
			scale_min = float(entry.get("scale_min", 0.25))
			scale_max = float(entry.get("scale_max", 0.4))
			break
	if model_name == "":
		return
	var s: float = lerpf(scale_min, scale_max, _scatter_roll(gx, gy, floor_index, 203))
	var prop: Node3D = ModelLoader.load_model(model_name, s)
	if prop == null:
		return
	_strip_collisions(prop)
	var off_a: Vector2i = _TORCH_FACE_OFFSET.get(walls[0], Vector2i.ZERO)
	var off_b: Vector2i = _TORCH_FACE_OFFSET.get(walls[1], Vector2i.ZERO)
	var corner_dir := Vector3(float(off_a.x + off_b.x), 0.0, float(off_a.y + off_b.y))
	prop.position = center + corner_dir * (_cell * 0.34)
	prop.rotation.y = _scatter_roll(gx, gy, floor_index, 204) * TAU
	container.add_child(prop)


## CAPA 3 (Flat Floor Decals): calcomanía plana SIN volumen (grietas, escarcha,
## manchas de humedad) renderizada como un `QuadMesh` horizontal a Y≈0.002m,
## con una máscara alfa radial GENERADA EN CÓDIGO (`GradientTexture2D`) — no
## depende de ningún fichero de textura nuevo. Puramente visual: nunca puede
## bloquear el paso ni la visión.
func _apply_floor_decal(container: Node3D, center: Vector3, cell: Dictionary, floor_index: int) -> void:
	var decal_color_raw: Variant = _theme.get("decal_color", null)
	if not (decal_color_raw is Color):
		return
	var gx: int = int(cell.get("gx", 0))
	var gy: int = int(cell.get("gy", 0))
	if _scatter_roll(gx, gy, floor_index, 301) > 0.18:
		return

	# Textura decal radial compartida — los parámetros son idénticos en toda la sesión.
	if _s_decal_tex_cache == null:
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0)])
		var mask_tex := GradientTexture2D.new()
		mask_tex.gradient = grad
		mask_tex.fill = GradientTexture2D.FILL_RADIAL
		mask_tex.fill_from = Vector2(0.5, 0.5)
		mask_tex.fill_to = Vector2(1.0, 0.5)
		mask_tex.width = 32
		mask_tex.height = 32
		_s_decal_tex_cache = mask_tex

	# Material decal compartido por color de tema: en una mazmorra mono-temática todas
	# las celdas decal reutilizan el mismo StandardMaterial3D → un único pipeline variant.
	var color_key: String = str(decal_color_raw)
	if not _s_decal_mat_cache.has(color_key):
		var mat_new := StandardMaterial3D.new()
		mat_new.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_new.albedo_color = decal_color_raw as Color
		mat_new.albedo_texture = _s_decal_tex_cache
		mat_new.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_new.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat_new.render_priority = 1
		_s_decal_mat_cache[color_key] = mat_new
	var mat := _s_decal_mat_cache[color_key] as StandardMaterial3D

	var quad := QuadMesh.new()
	var sz: float = _cell * lerpf(0.35, 0.6, _scatter_roll(gx, gy, floor_index, 302))
	quad.size = Vector2(sz, sz)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.rotation_degrees.x = -90.0
	mi.rotation.y = _scatter_roll(gx, gy, floor_index, 303) * TAU
	mi.position = center + Vector3(
		lerp(-_cell * 0.25, _cell * 0.25, _scatter_roll(gx, gy, floor_index, 304)),
		0.002,
		lerp(-_cell * 0.25, _cell * 0.25, _scatter_roll(gx, gy, floor_index, 305))
	)
	container.add_child(mi)


## Columna de piedra maciza (con colisión) + capiteles. Usa assets/common/models/
## interactive/columna.tscn (escalada a la altura del muro); si falta el
## archivo, cae al procedural de siempre.
func _add_column(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var root := Node3D.new()
	root.position = center
	container.add_child(root)
	var col_model: Node3D = ModelLoader.load_model(_tile_model_override("column", "columna"), _wall_h / 1.4)
	if col_model != null:
		root.add_child(col_model)
	else:
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.7, 0.68, 0.62)
		stone.roughness = 0.9
		var shaft := CylinderMesh.new()
		shaft.top_radius = _cell * 0.22
		shaft.bottom_radius = _cell * 0.24
		shaft.height = _wall_h
		root.add_child(_mesh_node(shaft, stone, Vector3(0, _wall_h * 0.5, 0)))
		var cap := BoxMesh.new()
		cap.size = Vector3(_cell * 0.6, _cell * 0.15, _cell * 0.6)
		root.add_child(_mesh_node(cap, stone, Vector3(0, _wall_h - _cell * 0.075, 0)))
		root.add_child(_mesh_node(cap, stone, Vector3(0, _cell * 0.075, 0)))
	var body := StaticBody3D.new()
	var scol := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = _cell * 0.24
	sh.height = _wall_h
	scol.shape = sh
	scol.position = Vector3(0, _wall_h * 0.5, 0)
	body.add_child(scol)
	root.add_child(body)
	_apply_transform(root, cell)


## Resuelve la rotación en grados (Y) de una celda por su número `rot` o texto `dir` cardinal.
func _resolve_rotation_degrees(cell: Dictionary) -> float:
	if cell.has("rot"):
		return float(cell["rot"])
	var dir := String(cell.get("dir", cell.get("direction", cell.get("facing", "")))).to_lower()
	match dir:
		"derecha", "este", "east", "d", "e", "right":
			return 90.0
		"abajo", "sur", "south", "s", "down":
			return 180.0
		"izquierda", "oeste", "west", "i", "o", "w", "left":
			return 270.0
		_: # "arriba", "norte", "north", "up"
			return 0.0


## Calcula el AABB aproximado de un Node3D recorriendo sus VisualInstance3D hijas.
func _calculate_node_aabb(node: Node3D) -> AABB:
	var total_aabb := AABB()
	var first := true
	for child in node.find_children("*", "VisualInstance3D", true, false):
		if child is VisualInstance3D:
			var a: AABB = (child as VisualInstance3D).get_aabb()
			if first:
				total_aabb = a
				first = false
			else:
				total_aabb = total_aabb.merge(a)
	if first:
		total_aabb = AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 1.0, 0.8))
	return total_aabb


## Añade un objeto de decoración 3D con colisión física sólida, orientación cardinal y ajuste pegado a la pared opcional.
func _add_decor_prop(container: Node3D, center: Vector3, cell: Dictionary, default_model: String = "") -> void:
	var root := Node3D.new()
	root.position = center
	container.add_child(root)

	var model_name: String = String(cell.get("model", cell.get("prop", cell.get("id", default_model))))
	if model_name == "":
		model_name = String(cell.get("t", "barril_manzanas"))

	var prop_node: Node3D = ModelLoader.load_model(model_name)
	if prop_node != null:
		# Auto-escalado para asegurar que NUNCA ocupe más de una casilla
		var aabb := _calculate_node_aabb(prop_node)
		var max_xz: float = maxf(aabb.size.x, aabb.size.z)
		if max_xz > _cell * 0.92 and max_xz > 0.001:
			var auto_scale: float = (_cell * 0.90) / max_xz
			prop_node.scale = Vector3.ONE * auto_scale

		# Orientación cardinal / rotación en Y
		var rot_y := _resolve_rotation_degrees(cell)
		root.rotation_degrees.y = rot_y

		# Ajuste "pegado a la pared" vs "en el medio de la casilla"
		var is_wall_model: bool = model_name in [
			"hojas_pared", "enredadera_pared", "enredadera", "vines", "vine",
			"antorcha_pared", "antorcha", "torch"
		]
		var is_wall_snap: bool = is_wall_model or bool(cell.get("wall_snap", cell.get("snap_wall", cell.get("pegado_pared", cell.get("align", "") == "wall"))))
		if is_wall_snap:
			if model_name in ["hojas_pared", "enredadera_pared", "enredadera", "vines", "vine"]:
				# Colocar las hojas justo delante de la pared (a 5 cm) para que no penetren dentro de la caja de colisión del muro
				prop_node.position.z = -(_cell * 0.5) + 0.05
			elif is_wall_model:
				var mesh_back_z: float = aabb.position.z * prop_node.scale.z
				prop_node.position.z = -(_cell * 0.5) - mesh_back_z + 0.02
			else:
				# Para muebles con fondo (armarios, estanterías, etc.): apoyar la cara trasera contra la pared
				var back_offset: float = (_cell * 0.5) - (maxf(aabb.size.z * prop_node.scale.z, 0.1) * 0.5) - 0.02
				prop_node.position.z = -back_offset

		# Ajuste de elevación Y (para enredaderas/hojas de pared colgadas u offsets personalizados)
		if model_name in ["hojas_pared", "enredadera_pared", "enredadera", "vines", "vine"]:
			# El modelo tiene Y de -2.12m a +0.48m. Posicionamos para que la cima quede justo bajo el techo/borde superior.
			prop_node.position.y = maxf(_wall_h - 0.50, 1.5)
			# Sombreado de vegetación: doble cara y difusión suave para que las hojas superiores no se oscurezcan
			for child in prop_node.find_children("*", "MeshInstance3D", true, false):
				if child is MeshInstance3D:
					var mi_node := child as MeshInstance3D
					var mat = mi_node.get_active_material(0)
					if mat is StandardMaterial3D:
						var fol_mat: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
						fol_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
						fol_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
						fol_mat.backlight_enabled = true
						fol_mat.backlight = Color(0.20, 0.40, 0.15)
						mi_node.material_override = fol_mat
		elif cell.has("y_offset"):
			prop_node.position.y += float(cell["y_offset"])
		elif cell.has("y"):
			prop_node.position.y += float(cell["y"])

		root.add_child(prop_node)

		# Colisión física sólida StaticBody3D solo si la casilla es sólida
		var is_solid: bool = bool(cell.get("solid", true))
		if model_name in ["hojas_pared", "enredadera_pared", "enredadera", "vines", "vine", "hierba", "flores", "flores_3", "flores_4", "setas", "mushrooms"]:
			is_solid = bool(cell.get("solid", false))

		if is_solid:
			var body := StaticBody3D.new()
			var scol := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			var col_w: float = clampf(aabb.size.x * prop_node.scale.x * 0.95, 0.3, _cell * 0.92)
			var col_h: float = clampf(aabb.size.y * prop_node.scale.y, 0.3, _wall_h * 1.2)
			var col_d: float = clampf(aabb.size.z * prop_node.scale.z * 0.95, 0.3, _cell * 0.92)
			box_shape.size = Vector3(col_w, col_h, col_d)
			scol.shape = box_shape
			scol.position = prop_node.position + Vector3(0, col_h * 0.5, 0)
			body.add_child(scol)
			root.add_child(body)
	else:
		# Fallback procedural
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.45, 0.28, 0.14)
		wood.roughness = 0.85
		var s := _cell * 0.5
		var b := BoxMesh.new()
		b.size = Vector3(s, s, s)
		root.add_child(_mesh_node(b, wood, Vector3(0, s * 0.5, 0)))
		var body := StaticBody3D.new()
		var scol := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(s, s, s)
		scol.shape = sh
		scol.position = Vector3(0, s * 0.5, 0)
		body.add_child(scol)
		root.add_child(body)

	_apply_transform(root, cell)


## Barril de madera (mantiene compatibilidad llamando a _add_decor_prop).
func _add_barrel(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	_add_decor_prop(container, center, cell, "barril_vacio")


## Caja de madera (mantiene compatibilidad llamando a _add_decor_prop).
func _add_crate(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	_add_decor_prop(container, center, cell, "caja_madera")


## Estatua de piedra: pedestal + cuerpo + cabeza. Usa assets/common/models/
## interactive/estatua.tscn (escalada a la altura del muro); si falta el
## archivo, cae al procedural de siempre.
func _add_statue(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var root := Node3D.new()
	root.position = center
	container.add_child(root)
	var statue_model: Node3D = ModelLoader.load_model(_tile_model_override("statue", "estatua"), _wall_h / 1.4)
	if statue_model != null:
		root.add_child(statue_model)
	else:
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.6, 0.6, 0.62)
		stone.roughness = 0.9
		var ped := BoxMesh.new()
		ped.size = Vector3(_cell * 0.5, _cell * 0.25, _cell * 0.5)
		root.add_child(_mesh_node(ped, stone, Vector3(0, _cell * 0.125, 0)))
		var bodym := BoxMesh.new()
		bodym.size = Vector3(_cell * 0.28, _wall_h * 0.55, _cell * 0.24)
		root.add_child(_mesh_node(bodym, stone, Vector3(0, _cell * 0.25 + _wall_h * 0.275, 0)))
		var head := SphereMesh.new()
		head.radius = _cell * 0.14
		head.height = _cell * 0.28
		root.add_child(_mesh_node(head, stone, Vector3(0, _cell * 0.25 + _wall_h * 0.55 + _cell * 0.14, 0)))
	_apply_transform(root, cell)


## Objeto Inteligente (pieza de kit). Delegado en DungeonSmartFactory: construye
## cuerpo + malla + Interactable + reacciones a partir del catálogo dungeon_kits.
## La celda declara `kit` (id de la pieza) y overrides opcionales (rot, scale).
func _add_smart_object(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var piece := String(cell.get("kit", ""))
	if piece == "":
		return
	var def: Dictionary = Design.kit_piece(piece)
	var archetype := String(def.get("archetype", ""))
	var shape := String(def.get("shape", "box"))
	var custom_mat: StandardMaterial3D = null
	if archetype == "false_solid" or archetype == "reveal":
		if shape == "wall" or shape == "arch":
			var tex_key := String(cell.get("wall", ""))
			if tex_key == "" and cell.has("tex") and not String(cell["tex"]).contains("floor"):
				tex_key = String(cell["tex"])
			var tint = _surface_tint(cell)
			custom_mat = _surface_material(_mat_wall, tex_key, tint, "wall")
		elif shape == "floor" or shape == "platform":
			var tex_key := String(cell.get("floor", ""))
			if tex_key == "" and cell.has("tex") and not String(cell["tex"]).contains("wall"):
				tex_key = String(cell["tex"])
			var tint = _surface_tint(cell)
			custom_mat = _surface_material(_mat_floor, tex_key, tint, "floor")
	var node := DungeonSmartFactory.build(piece, cell, _cell, _wall_h, custom_mat)
	if node == null:
		return
	node.position = center
	container.add_child(node)


## Cartel de guía data-driven (usado por los tutoriales): poste + placa con texto
## flotante (Label3D billboard). El texto viene en `cell.text`; el color en
## `cell.color` (opcional). No bloquea el paso.
func _add_sign(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var raw_text = cell.get("text", "")
	var text: String = Locale.pick(raw_text) if Locale != null else (raw_text.get("es", "") if raw_text is Dictionary else str(raw_text))
	if text == "":
		return
	var col := Color(0.95, 0.9, 0.65)
	var col_val = cell.get("color", "")
	if col_val is String and String(col_val) != "":
		col = Color.html(String(col_val))
	elif col_val is Color:
		col = col_val
	var root := Node3D.new()
	root.position = center
	container.add_child(root)
	# Poste de madera, reemplazable por un modelo propio
	# (Design.get_dungeon_tile_render("sign").model); el texto flotante (abajo)
	# se mantiene siempre encima, lo use o no.
	var sign_model: Node3D = ModelLoader.load_model(_tile_model_override("sign", ""), _wall_h * 0.55)
	if sign_model != null:
		root.add_child(sign_model)
	else:
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.28, 0.18, 0.1)
		var post := BoxMesh.new()
		post.size = Vector3(0.12, _wall_h * 0.55, 0.12)
		root.add_child(_mesh_node(post, wood, Vector3(0, _wall_h * 0.275, 0)))
	# Texto flotante.
	var lbl := Label3D.new()
	lbl.add_to_group("elementos_temporales_mazmorra")
	lbl.text = text
	lbl.position = Vector3(0, _wall_h * 0.7, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = col
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.outline_size = 12
	lbl.font_size = 44
	lbl.pixel_size = 0.006
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.double_sided = true
	root.add_child(lbl)
	_apply_transform(root, cell)


## Runa mágica en el suelo: disco emisivo + luz tenue.
func _add_rune(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var root := Node3D.new()
	root.position = center
	container.add_child(root)
	# Reemplazable por un modelo propio (Design.get_dungeon_tile_render("rune").model);
	var rune_model: Node3D = ModelLoader.load_model(_tile_model_override("rune", ""), _cell * 0.7)
	if rune_model != null:
		rune_model.position = Vector3(0, 0.03, 0)
		root.add_child(rune_model)
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.2, 0.9, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.7, 0.3, 1.0)
		m.emission_energy_multiplier = 2.5
		var disc := CylinderMesh.new()
		disc.top_radius = _cell * 0.35
		disc.bottom_radius = _cell * 0.35
		disc.height = 0.05
		root.add_child(_mesh_node(disc, m, Vector3(0, 0.03, 0)))
	_apply_transform(root, cell)
	_add_light(container, center + Vector3(0, 0.3, 0), Color(0.7, 0.3, 1.0), 1.0, _cell * 1.8)


## Hoguera: círculo de piedras + troncos + llama emisiva + luz cálida amplia.
func _add_campfire(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var root := Node3D.new()
	root.position = center
	container.add_child(root)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.4, 0.4, 0.42)
	stone.roughness = 0.95
	var n := 6
	for i in range(n):
		var ang := TAU * float(i) / float(n)
		var r := _cell * 0.28
		var st := BoxMesh.new()
		st.size = Vector3(0.16, 0.14, 0.16)
		root.add_child(_mesh_node(st, stone, Vector3(cos(ang) * r, 0.07, sin(ang) * r)))
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.18, 0.09)
	wood.roughness = 0.9
	for j in range(2):
		var logm := CylinderMesh.new()
		logm.top_radius = 0.06
		logm.bottom_radius = 0.06
		logm.height = _cell * 0.4
		var ln := _mesh_node(logm, wood, Vector3(0, 0.12, 0))
		ln.rotation_degrees = Vector3(90, float(j) * 90.0, 0)
		root.add_child(ln)
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1.0, 0.5, 0.12)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.45, 0.1)
	flame.emission_energy_multiplier = 3.0
	var fs := SphereMesh.new()
	fs.radius = 0.22
	fs.height = 0.5
	root.add_child(_mesh_node(fs, flame, Vector3(0, 0.35, 0)))
	_apply_transform(root, cell)
	_add_light(container, center + Vector3(0, 0.5, 0), Color(1.0, 0.55, 0.2), 2.2, _cell * 3.0)
	# Partículas de chispas y humo para dar vida a la hoguera.
	if not Locale.reduce_motion:
		var embers := _campfire_particles(Color(1.0, 0.5, 0.1), 0.03, 0.06, 8, 0.8, 0.5)
		root.add_child(embers)
		var smoke := _campfire_particles(Color(0.22, 0.22, 0.24, 0.18), 0.08, 0.16, 4, 1.4, 0.15)
		smoke.gravity = Vector3(0.0, 0.6, 0.0)
		root.add_child(smoke)


# ══════════════════════════════════════════════════════════════════════════════
## Crea un CPUParticles3D básico con apariencia de chispa/humo para hogueras.
func _campfire_particles(color: Color, scale_min: float, scale_max: float, amount: int, lifetime: float, velocity: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.08
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 25.0
	p.gravity = Vector3(0.0, 0.4, 0.0)
	p.initial_velocity_min = velocity * 0.5
	p.initial_velocity_max = velocity
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	p.color = color
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	p.material_override = mat
	p.mesh = SphereMesh.new()
	return p


# ══════════════════════════════════════════════════════════════════════════════
# RUNTIME DE ACCIONADORES (interruptor/palanca/botón/placa → compuerta/puerta)
# ══════════════════════════════════════════════════════════════════════════════
## Conecta cada accionador a su callback tras construir TODAS las plantas (los
## objetivos por `eid` pueden estar en otra planta ya construida).
func _wire_actuators() -> void:
	for a in _actuators:
		var area = a.get("area", null)
		if area is Area3D and is_instance_valid(area) and not area.body_entered.is_connected(_on_actuator_entered):
			area.body_entered.connect(_on_actuator_entered.bind(a.get("targets", []), a.get("eid", "")))
	_replay_persisted_actuators()


## reaplica (instantáneamente, sin tween/sonido) los efectos de
## los accionadores que YA se activaron en una visita anterior a esta mazmorra
## — p. ej. los pinchos de una palanca ya tirada nacen bajados en vez de
## reiniciarse al estado por defecto del JSON.
func _replay_persisted_actuators() -> void:
	for a in _actuators:
		var eid := String(a.get("eid", ""))
		if eid == "" or not _is_actuator_persisted_active(eid):
			continue
		var targets = a.get("targets", [])
		if not (targets is Array):
			continue
		for tg in targets:
			var tg_eid := ""
			var tg_action := "toggle"
			if tg is Dictionary:
				tg_eid = String(tg.get("eid", ""))
				tg_action = String(tg.get("action", "toggle"))
			elif tg is String:
				tg_eid = tg
				tg_action = "open"
			else:
				continue
			if tg_eid == "floor_0_lava" or tg_eid == "lava_floor_0" or tg_action == "convert_lava":
				_convert_floor_to_lava(0)
			else:
				_apply_action(tg_eid, tg_action, true)


## Clave de persistencia de un accionador dentro de ESTA mazmorra (GameFlagsManager).
func _actuator_flag_key(eid: String) -> String:
	return "dun_%s_%s_active" % [_dungeon_id, eid]


## ¿Este accionador (por `eid`) ya se activó en una visita anterior a la mazmorra?
func _is_actuator_persisted_active(eid: String) -> bool:
	return _dungeon_id != "" and eid != "" and GlobalState.has_world_flag(_actuator_flag_key(eid))


## Un Objeto Inteligente emitió el evento de apertura de una compuerta `open_on`:
## la abre por su `eid`. El payload del evento se ignora (solo importa que ocurrió).
func _on_gate_open_event(_payload: Dictionary, eid: String) -> void:
	_apply_action(eid, "open")


## Al liberar el escenario (salir de la mazmorra o reconstruirlo) se cancelan las
## suscripciones a eventos de compuertas para no dejar callables colgando.
func _exit_tree() -> void:
	GlobalEvents.unsubscribe_object(self)


var _lava_floors: Dictionary = {}


var _activated_actuators: Dictionary = {}
var _prologue_lever_pulled: bool = false
var _last_spike_sfx_frame: int = -1


## El jugador pisa o activa un accionador/palanca: aplica la acción declarada.
func _on_actuator_entered(body: Node, targets, actuator_eid: String) -> void:
	if body == null or body.name != "player":
		return
	var targets_arr: Array = targets if (targets is Array) else []
	trigger_actuator(actuator_eid, targets_arr)


## Acciona una palanca/interruptor (por pisarla el jugador o por impacto de habilidad a distancia)
func trigger_actuator(actuator_eid: String, targets: Array) -> bool:
	var el: Dictionary = _elements.get(actuator_eid, {})
	var is_single_use: bool = bool(el.get("single_use", true))
	var key := actuator_eid if actuator_eid != "" else str(targets)
	if is_single_use and _activated_actuators.get(key, false):
		if "sendero_guerrero" in _dungeon_id:
			if actuator_eid == "lever_sg_spikes":
				if OrbBarksManager != null:
					OrbBarksManager.trigger_bark(Locale.pick({
						"es": "«Esta ya abrió el mecanismo. No hace falta insistir más.»",
						"en": "“This one already opened the mechanism. No need to keep pulling it.”"
					}), 4.0)
			elif targets.is_empty() or actuator_eid.begins_with("lever_sg_dummy"):
				if AudioManager != null:
					AudioManager.play_sfx("click")
				if OrbBarksManager != null:
					OrbBarksManager.trigger_bark(Locale.pick({
						"es": "«Esta palanca parece inútil, ¿habrá otra que sirva para algo?»",
						"en": "“This lever seems useless, could there be another one that works?”"
					}), 5.0)
		return false

	var current_state: String = String(el.get("state", "off"))
	var is_currently_on: bool = (current_state in ["on", "open"])
	var next_action: String = "off" if (is_currently_on and not is_single_use) else "on"

	# Lógica del prólogo (dun_inicial)
	var is_prologue_lever := actuator_eid.begins_with("lever_") and _dungeon_id == "dun_inicial"

	if is_prologue_lever:
		if _prologue_lever_pulled:
			_activated_actuators[key] = true
			var bark_txt := Locale.pick({
				"es": "Ya no, ya es demasiado tarde. ¡Lárgate y no toques nada más, por favor!",
				"en": "No, it's too late now. Get out and don't touch anything else, please!"
			})
			if OrbBarksManager != null:
				OrbBarksManager.trigger_bark(bark_txt, 5.0)
			return false

		_prologue_lever_pulled = true

	if is_single_use:
		_activated_actuators[key] = true
		if actuator_eid != "":
			GlobalState.set_world_flag(_actuator_flag_key(actuator_eid), true)
	else:
		_activated_actuators[key] = (next_action == "on")
		if actuator_eid != "":
			GlobalState.set_world_flag(_actuator_flag_key(actuator_eid), next_action == "on")

	# Animar visualmente la propia palanca
	if actuator_eid != "" and _elements.has(actuator_eid):
		_apply_action(actuator_eid, next_action)

	# Lógica específica de El Sendero del Guerrero (sendero_guerrero): palanca correcta vs palancas inútiles
	if "sendero_guerrero" in _dungeon_id:
		if actuator_eid == "lever_sg_spikes":
			Juice.shake(self, 16.0, 0.7)
			if AudioManager != null:
				AudioManager.play_sfx("tremor")
			get_tree().create_timer(0.6).timeout.connect(func():
				if OrbBarksManager != null:
					OrbBarksManager.trigger_bark(Locale.pick({
						"es": "«Vaya, parece que has tocado lo que tenías que tocar.»",
						"en": "“Well, looks like you touched what you were supposed to touch.”"
					}), 5.0)
			)
		elif targets.is_empty() or actuator_eid.begins_with("lever_sg_dummy"):
			if AudioManager != null:
				AudioManager.play_sfx("click")
			if OrbBarksManager != null:
				OrbBarksManager.trigger_bark(Locale.pick({
					"es": "«Esta palanca parece inútil, ¿habrá otra que sirva para algo?»",
					"en": "“This lever seems useless, could there be another one that works?”"
				}), 5.0)

	# Lógica específica de El Sendero del Elementalista: desactivación de los pinchos que protegen al boss
	if "sendero_elementalista" in _dungeon_id and actuator_eid == "lever_boss_spikes":
		Juice.shake(self, 18.0, 0.8)
		Input.vibrate_handheld(60)
		if AudioManager != null:
			AudioManager.play_sfx("tremor")
		get_tree().create_timer(0.6).timeout.connect(func():
			if OrbBarksManager != null:
				OrbBarksManager.trigger_bark(Locale.pick({
					"es": "«Parece que has activado algo en otro lado, bien hecho.»",
					"en": "“Looks like you activated something somewhere else, well done.”"
				}), 5.0)
		)

	# Requisito 1: Terremoto, shake y temblor de pantalla al activar la palanca del prólogo
	if _dungeon_id == "dun_inicial":
		Juice.shake(self, 18.0, 0.8)
		_start_earthquake_loop()

		if AudioManager != null:
			AudioManager.play_music("combat")

	if is_prologue_lever:
		if OrbBarksManager != null:
			OrbBarksManager.set_phase(2, true)
		if ExplorationSkills != null:
			for skill_id in ExplorationSkills.all_ids():
				ExplorationSkills.unlock(skill_id)
			if GlobalState != null:
				GlobalState.energy = float(GlobalState.max_energy)
				GlobalState.state_updated.emit()

	# ideas.md #9: nodo de la propia palanca/interruptor, para trazar la chispa
	# de energía hacia cada objetivo que active (ver más abajo).
	var actuator_node: Node3D = _element_anchor_node(_elements.get(actuator_eid, {}))
	for tg in targets:
		var eid := ""
		var action := "toggle"
		if tg is Dictionary:
			eid = String(tg.get("eid", ""))
			action = String(tg.get("action", "toggle"))
		elif tg is String:
			eid = tg
			action = "open"
		else:
			continue
		if eid == "floor_0_lava" or eid == "lava_floor_0" or action == "convert_lava":
			_convert_floor_to_lava(0)
		else:
			_apply_action(eid, action)
			if actuator_node != null and not Locale.reduce_motion:
				var target_node: Node3D = _element_anchor_node(_elements.get(eid, {}))
				if target_node != null:
					_spawn_energy_link(actuator_node.global_position, target_node.global_position)
	return true


## Nodo 3D representativo de un elemento registrado en `_elements` (para
## sacar su posición de mundo), sea cual sea su `kind` (palanca, puerta,
## compuerta, luz...) — cada kind guarda su nodo animable bajo una clave
## distinta. Soporta elementos individuales o arrays de elementos con el mismo eid.
func _element_anchor_node(el_val: Variant) -> Node3D:
	if el_val is Array:
		var arr := el_val as Array
		if not arr.is_empty():
			return _element_anchor_node(arr[0])
		return null
	if not (el_val is Dictionary):
		return null
	var el: Dictionary = el_val
	for key in ["visual", "mesh", "hinge", "light"]:
		var n = el.get(key, null)
		if n is Node3D and is_instance_valid(n):
			return n
	return null


## Chispa de energía que viaja desde una palanca/interruptor hasta lo que
## acciona (ideas.md #9): la relación causa-efecto se ve, no solo se infiera
## por el sonido/estado que cambian a la vez. Se autodestruye al llegar.
func _spawn_energy_link(from_pos: Vector3, to_pos: Vector3) -> void:
	var spark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	spark.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.9, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 1.0)
	mat.emission_energy_multiplier = 3.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.material_override = mat
	add_child(spark)
	spark.global_position = from_pos
	var dist := from_pos.distance_to(to_pos)
	var dur := clampf(dist / 6.0, 0.25, 1.0)
	var tw := create_tween()
	tw.tween_property(spark, "global_position", to_pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		WorldFx.glow_flash(self, to_pos, Color(0.4, 0.95, 1.0), 3.0, 0.35)
		if is_instance_valid(spark):
			spark.queue_free()
	)


var _earthquake_active: bool = false


## Inicia la secuencia de terremotos/sacudidas periódicas al accionar una palanca importante.
func _start_earthquake_loop() -> void:
	if _earthquake_active:
		return
	_earthquake_active = true
	_run_earthquake_step()


func _run_earthquake_step() -> void:
	if not _earthquake_active or not is_inside_tree():
		return
	Juice.shake(self, randf_range(7.0, 11.0), randf_range(0.35, 0.55))
	if AudioManager != null:
		AudioManager.play_sfx("sfx_temblor")
	var t := get_tree().create_timer(randf_range(3.5, 5.5))
	t.timeout.connect(_run_earthquake_step)


## Convierte todas las losas de suelo de una planta en LAVA ardiente al accionar la palanca,
## eliminando por completo cualquier objeto, mueble, decoración o ítem de dicha planta.
func _convert_floor_to_lava(floor_idx: int) -> void:
	if _lava_floors.get(floor_idx, false):
		return
	_lava_floors[floor_idx] = true

	# Sacudida inicial + bucle de terremotos periódicos (sin mensaje rojo)
	Juice.shake(self, 14.0, 0.6)
	_start_earthquake_loop()

	var floor_node := get_node_or_null("Floor%d" % floor_idx)
	if floor_node == null:
		return

	var script = load(LAVA_ZONE_SCRIPT)
	var sum_pos := Vector3.ZERO
	var slab_count := 0
	var covered_coords: Dictionary = {}

	for child in floor_node.get_children():
		# 1. Detectar si es una losa de suelo (se transforma en lava)
		var is_floor_slab := false
		if child is StaticBody3D and child.position.y < 0.2:
			for sub in child.get_children():
				if sub is MeshInstance3D and sub.mesh is BoxMesh and (sub.mesh as BoxMesh).size.y <= 0.35:
					is_floor_slab = true
					sub.material_override = _make_lava_shader_mat()
					break
			if is_floor_slab:
				child.position.y = -0.06
				if script:
					var lava_area := Area3D.new()
					lava_area.collision_mask = 2
					lava_area.set_script(script)
					var col := CollisionShape3D.new()
					var shape := BoxShape3D.new()
					shape.size = Vector3(_cell, 2.0, _cell)
					col.shape = shape
					lava_area.add_child(col)
					child.add_child(lava_area)
				if not Locale.reduce_motion:
					var smoke := _create_lava_smoke_particles(_cell)
					if smoke != null:
						smoke.position = Vector3(0, 0.12, 0)
						child.add_child(smoke)
				var gx := int(roundf(child.position.x / _cell))
				var gy := int(roundf(child.position.z / _cell))
				covered_coords[Vector2i(gx, gy)] = true
				sum_pos += child.position
				slab_count += 1
				continue

		# 2. Detectar si es un muro perimetral alto (se conserva para delimitar la caverna)
		var is_wall_block := false
		if child is StaticBody3D and child.position.y >= 0.5:
			for sub in child.get_children():
				if sub is MeshInstance3D and sub.mesh is BoxMesh and (sub.mesh as BoxMesh).size.y >= _wall_h * 0.5:
					is_wall_block = true
					break
		if is_wall_block:
			continue

		# 3. TODO lo demás en la planta (muebles, ítems, cofres, decoraciones, enredaderas, escaleras, etc.)
		# se destruye por completo para que solo quede la lava
		child.queue_free()

	# 4. Asegurar que TODAS las casillas transitables/habitables tengan losa de lava
	# (evita huecos al vacío en casillas de rampas, puertas o props eliminados)
	var floors_arr: Array = _def.get("floors", [])
	if floor_idx >= 0 and floor_idx < floors_arr.size():
		var fl: Dictionary = floors_arr[floor_idx]
		var cells: Array = fl.get("cells", [])
		for y in range(cells.size()):
			var row: Array = cells[y]
			for x in range(row.size()):
				var c: Dictionary = row[x] if row[x] is Dictionary else {}
				var t: String = String(c.get("t", "void"))
				if t != "void" and t != "wall":
					var coord := Vector2i(x, y)
					if not covered_coords.has(coord):
						var pos := Vector3(float(x) * _cell, -0.06, float(y) * _cell)
						var body := StaticBody3D.new()
						body.position = pos
						floor_node.add_child(body)
						var mi := MeshInstance3D.new()
						var box := BoxMesh.new()
						box.size = Vector3(_cell, 0.2, _cell)
						mi.mesh = box
						mi.material_override = _make_lava_shader_mat()
						body.add_child(mi)
						var col := CollisionShape3D.new()
						var shape := BoxShape3D.new()
						shape.size = box.size
						col.shape = shape
						body.add_child(col)
						if script:
							var lava_area := Area3D.new()
							lava_area.collision_mask = 2
							lava_area.set_script(script)
							var lcol := CollisionShape3D.new()
							var lshape := BoxShape3D.new()
							lshape.size = Vector3(_cell, 2.0, _cell)
							lcol.shape = lshape
							lava_area.add_child(lcol)
							body.add_child(lava_area)
						if not Locale.reduce_motion:
							var smoke := _create_lava_smoke_particles(_cell)
							if smoke != null:
								smoke.position = Vector3(0, 0.12, 0)
								body.add_child(smoke)
						covered_coords[coord] = true
						sum_pos += pos
						slab_count += 1

	# Añadir una luz cálida central para reforzar el brillo de la lava
	if slab_count > 0:
		var lava_center := sum_pos / float(slab_count)
		lava_center.y = _wall_h * 0.6
		var lava_light := _add_light(floor_node, lava_center, Color(1.0, 0.35, 0.08), 2.4, _cell * 6.0)
		lava_light.name = "LavaLight"

	# Si el jugador está sobre esta planta al romperse la presa, recibe daño de lava de inmediato
	var player_node := find_child("player", true, false) as Node3D
	if player_node != null and is_instance_valid(player_node) and player_node.global_position.y < _wall_h * 0.8:
		if player_node.has_method("set_in_lava"):
			player_node.call("set_in_lava", true)


## Registra un elemento en `_elements`. Si varios elementos comparten el mismo `eid`
## (por ejemplo, los 3 bloques de pinchos de una fila entera), los agrupa en un Array
## para que cualquier accionador los manipule juntos como un único grupo funcional.
func _register_element(eid: String, el: Dictionary) -> void:
	if eid == "":
		return
	if _elements.has(eid):
		var existing = _elements[eid]
		if existing is Array:
			existing.append(el)
		else:
			_elements[eid] = [existing, el]
	else:
		_elements[eid] = el


## Aplica una acción (open/close/on/off/toggle) al elemento o elementos con estado `eid`.
## `instant`: true para saltar directamente al estado (sin tween ni sonido) —
## usado al reaplicar accionamientos persistidos de una visita anterior
## Igual que la pose inicial declarada en el JSON.
func _apply_action(eid: String, action: String, instant: bool = false) -> void:
	if eid == "" or not _elements.has(eid):
		return
	var target_val = _elements[eid]
	var el_list: Array = target_val if target_val is Array else [target_val]
	for el_item in el_list:
		if not (el_item is Dictionary):
			continue
		var el: Dictionary = el_item
		var state := String(el.get("state", "closed"))
		var new_state := state
		match action:
			"open", "on":
				new_state = "open"
			"close", "off":
				new_state = "closed"
			"toggle":
				new_state = "closed" if state == "open" else "open"
			_:
				new_state = state
		el["state"] = new_state
		_set_element_state(el, instant)


## Refleja el estado (open/closed = on/off) de un elemento con una animación
## acorde a su `kind` — : antes SOLO existían puerta (hundirse) y
## compuerta (elevarse); ahora cada tipo reacciona de forma creíble: la puerta
## GIRA sobre su bisagra, la compuerta se eleva como un portón, una LUZ se
## enciende/apaga, y el propio interruptor/palanca/botón/placa se mueve al
## accionarse (antes nunca cambiaba de aspecto — bug reportado: "un interruptor
## sin lógica de este tipo no sirve de nada").
## `instant`: true al construir el escenario (aplica la pose inicial sin sonido
## ni tween); false (por defecto) en accionamientos reales durante el juego.
func _set_element_state(el: Dictionary, instant: bool = false) -> void:
	_track_interactable_mesh(el)
	var open: bool = (String(el.get("state", "closed")) == "open")
	var col = el.get("col", null)
	if col is CollisionShape3D and is_instance_valid(col):
		col.set_deferred("disabled", open)
	match String(el.get("kind", "door")):
		"door":
			_animate_door(el, open, instant)
			var timer = el.get("timer", null)
			if timer is Timer and is_instance_valid(timer):
				if open and not instant:
					timer.wait_time = float(el.get("duration", 1.0))
					timer.start()
				else:
					timer.stop()
		"gate":
			_animate_gate(el, open, instant)
		"shutters", "contraventana":
			_animate_shutters(el, open, instant)
		"light":
			_animate_light(el, open, instant)
		"lever":
			_animate_lever(el, open, instant)
		"button", "pressure":
			_animate_plate(el, open, instant)
		"spikes":
			_animate_spikes(el, open, instant)
		_:
			_animate_wall_switch(el, open, instant)


## Puerta: gira su bisagra 0°<->~92°.
func _animate_door(el: Dictionary, open: bool, instant: bool) -> void:
	var hinge = el.get("hinge", null)
	if not (hinge is Node3D and is_instance_valid(hinge)):
		return
	var target := 92.0 if open else 0.0
	if instant:
		hinge.rotation_degrees.y = target
		return
	AudioManager.play_sfx("click")
	_spawn_dust_burst(hinge.global_position)
	if Locale.reduce_motion:
		hinge.rotation_degrees.y = target
		return
	var tw := create_tween()
	tw.tween_property(hinge, "rotation_degrees:y", target, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Compuerta: se eleva como un portón/reja y se oculta arriba al terminar.
func _animate_gate(el: Dictionary, open: bool, instant: bool) -> void:
	var mesh = el.get("mesh", null)
	if not (mesh is Node3D and is_instance_valid(mesh)):
		return
	var base_pos: Vector3 = el.get("base_pos", mesh.position)
	var target_y: float = base_pos.y + _wall_h * 0.9 if open else base_pos.y
	if instant:
		mesh.position.y = target_y
		mesh.visible = not open
		return
	mesh.visible = true
	AudioManager.play_sfx("gather")
	_spawn_dust_burst(mesh.global_position)
	if Locale.reduce_motion:
		mesh.position.y = target_y
		mesh.visible = not open
		return
	var tw := create_tween()
	tw.tween_property(mesh, "position:y", target_y, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if open:
		tw.tween_callback(func() -> void: mesh.visible = false)


## Contraventana / Puerta de madera con 2 estados: conmuta entre cerrada y abierta.
func _animate_shutters(el: Dictionary, open: bool, instant: bool) -> void:
	var m_closed = el.get("mesh_closed", null)
	var m_open = el.get("mesh_open", null)
	if m_closed is Node3D and is_instance_valid(m_closed):
		m_closed.visible = not open
	if m_open is Node3D and is_instance_valid(m_open):
		m_open.visible = open
	if not instant:
		AudioManager.play_sfx("click")
		if m_open is Node3D and is_instance_valid(m_open):
			_spawn_dust_burst(m_open.global_position)


## Luz: la enciende/apaga (energía a 0, sin destruir el nodo) — permite que un
## interruptor controle antorchas/cristales/runas/lámparas colocadas como
## celda "light" con `eid`.
func _animate_light(el: Dictionary, open: bool, instant: bool) -> void:
	var light = el.get("light", null)
	var base_energy: float = float(el.get("base_energy", 1.0))
	var target: float = base_energy if open else 0.0
	if not (light is Light3D and is_instance_valid(light)):
		return
	if instant:
		light.light_energy = target
		return
	AudioManager.play_sfx("click")
	if Locale.reduce_motion:
		light.light_energy = target
		return
	var tw := create_tween()
	tw.tween_property(light, "light_energy", target, 0.3).set_trans(Tween.TRANS_SINE)


## Palanca: la anima con su AnimationPlayer (Lever_On/Lever_Off) o rota su pivote procedural.
func _animate_lever(el: Dictionary, open: bool, instant: bool) -> void:
	var anim_player = el.get("anim_player", null)
	var visual = el.get("visual", null)
	if anim_player is AnimationPlayer and is_instance_valid(anim_player):
		var anim_name := "Lever_On" if open else "Lever_Off"
		if anim_player.has_animation(anim_name):
			if instant:
				anim_player.play(anim_name)
				anim_player.seek(anim_player.get_animation(anim_name).length, true)
			else:
				AudioManager.play_sfx("click")
				anim_player.play(anim_name)
				if visual is Node3D and is_instance_valid(visual):
					_spawn_dust_burst(visual.global_position)
				elif anim_player.get_parent() is Node3D:
					_spawn_dust_burst((anim_player.get_parent() as Node3D).global_position)
		return

	var pivot = el.get("visual", null)
	if not (pivot is Node3D and is_instance_valid(pivot)):
		return
	var target: float = 65.0 if open else -65.0

	var led_mat = el.get("led_mat", null)
	if led_mat is StandardMaterial3D:
		var c := Color(0.1, 1.0, 0.6) if open else Color(1.0, 0.2, 0.1)
		led_mat.albedo_color = c
		led_mat.emission = c

	if instant:
		pivot.rotation_degrees.x = target
		return
	AudioManager.play_sfx("click")
	_spawn_dust_burst(pivot.global_position)
	if Locale.reduce_motion:
		pivot.rotation_degrees.x = target
		return
	var tw := create_tween()
	tw.tween_property(pivot, "rotation_degrees:x", target, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Botón/placa de presión: se hunde ligeramente al activarse.
func _animate_plate(el: Dictionary, open: bool, instant: bool) -> void:
	var mesh = el.get("visual", null)
	var base_pos = el.get("visual_base", null)
	if not (mesh is Node3D and is_instance_valid(mesh) and base_pos is Vector3):
		return
	var target_y: float = base_pos.y - 0.05 if open else base_pos.y
	if instant:
		mesh.position.y = target_y
		return
	AudioManager.play_sfx("click")
	_spawn_dust_burst(mesh.global_position)
	if Locale.reduce_motion:
		mesh.position.y = target_y
		return
	var tw := create_tween()
	tw.tween_property(mesh, "position:y", target_y, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Interruptor de pared (genérico): pequeño giro de la caja como una palanca de
## pared clásica.
func _animate_wall_switch(el: Dictionary, open: bool, instant: bool) -> void:
	var mesh = el.get("visual", null)
	if not (mesh is Node3D and is_instance_valid(mesh)):
		return
	var target: float = -18.0 if open else 18.0
	if instant:
		mesh.rotation_degrees.x = target
		return
	AudioManager.play_sfx("click")
	_spawn_dust_burst(mesh.global_position)
	if Locale.reduce_motion:
		mesh.rotation_degrees.x = target
		return
	var tw := create_tween()
	tw.tween_property(mesh, "rotation_degrees:x", target, 0.15).set_trans(Tween.TRANS_SINE)


## Pinchos: se retraen (open) o se extienden (closed) escalando la altura del
## conjunto de pinchos. La colisión del área de peligro y el bloqueo se desactivan en "open".
func _animate_spikes(el: Dictionary, open: bool, instant: bool) -> void:
	var visual = el.get("visual", null)
	if not (visual is Node3D and is_instance_valid(visual)):
		return
	var target: float = 0.05 if open else 1.0
	var blocker_col = el.get("blocker_col", null)
	if blocker_col is CollisionShape3D and is_instance_valid(blocker_col):
		blocker_col.set_deferred("disabled", open)
	var col = el.get("col", null)
	if col is CollisionShape3D and is_instance_valid(col):
		col.set_deferred("disabled", open)
	var area = el.get("area", null)
	if area is Area3D and is_instance_valid(area):
		if area.has_method("set_active"):
			area.set_active(not open)
		else:
			area.set("is_active", not open)
			area.set_deferred("monitoring", not open)
			area.set_deferred("monitorable", not open)
	var warn_col = el.get("warn_col", null)
	if warn_col is CollisionShape3D and is_instance_valid(warn_col):
		warn_col.set_deferred("disabled", open)
	var spike_meshes = el.get("spike_meshes", [])
	if open and spike_meshes is Array:
		for sm in spike_meshes:
			_set_hazard_warning(sm, false, Color(1.0, 0.15, 0.1))

	if instant:
		visual.scale.y = target
		return
	var cur_frame := Engine.get_process_frames()
	if _last_spike_sfx_frame != cur_frame:
		_last_spike_sfx_frame = cur_frame
		AudioManager.play_sfx("click")
	_spawn_dust_burst(visual.global_position)
	if Locale.reduce_motion:
		visual.scale.y = target
		return
	var tw := create_tween()
	tw.tween_property(visual, "scale:y", target, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Ráfaga breve de polvo (piedra/madera) al accionar una puerta o compuerta.
func _spawn_dust_burst(at: Vector3) -> void:
	if Locale.reduce_motion:
		return
	if not is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.85
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 60.0
	p.gravity = Vector3(0.0, -3.0, 0.0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.68, 0.6, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.mesh = SphereMesh.new()
	p.material_override = mat
	# `global_position` requiere que el nodo
	# YA esté dentro del árbol para resolver la transformada global — antes
	# se asignaba antes de `add_child()`, lo que disparaba el aviso interno
	# de Godot "Condition '!is_inside_tree()' is true" (node_3d.cpp) y dejaba
	# la ráfaga de polvo en el origen (Transform3D() identidad).
	add_child(p)
	p.global_position = at
	p.emitting = true
	var t := get_tree().create_timer(p.lifetime + 0.1)
	t.timeout.connect(p.queue_free)


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES
# ══════════════════════════════════════════════════════════════════════════════
## Identifica de forma data-driven el teletransporte asociado al jefe (el que está junto al boss).
## Marca la casilla con `is_boss_teleport = true` para que luego se configure con el grupo "boss_teleport".
func _identify_boss_teleports(def: Dictionary) -> void:
	var boss_id: String = String(def.get("boss", ""))
	var floors: Array = def.get("floors", [])
	if floors.is_empty():
		return

	# 1. Buscar la posición del jefe en los datos del layout
	var boss_floor: int = -1
	var boss_pos := Vector2i(-1, -1)
	for fi in range(floors.size()):
		var fl = floors[fi]
		if not (fl is Dictionary):
			continue
		var cells: Array = fl.get("cells", [])
		for y in range(cells.size()):
			var row = cells[y]
			if not (row is Array):
				continue
			for x in range(row.size()):
				var cell = row[x]
				if not (cell is Dictionary):
					continue
				if String(cell.get("t", "")) == "monster":
					if bool(cell.get("boss", false)) or (boss_id != "" and (String(cell.get("ref", "")) == boss_id or String(cell.get("id", "")) == boss_id)):
						boss_floor = fi
						boss_pos = Vector2i(x, y)
						break
			if boss_floor != -1:
				break
		if boss_floor != -1:
			break

	# Posición de spawn del jugador
	var spawn_dict: Dictionary = def.get("spawn", {})
	var spawn_floor: int = int(spawn_dict.get("f", 0))
	var spawn_pos := Vector2i(int(spawn_dict.get("x", 0)), int(spawn_dict.get("y", 0)))

	# 2. Identificar el teletransporte del jefe
	for fi in range(floors.size()):
		var fl = floors[fi]
		if not (fl is Dictionary):
			continue
		var cells: Array = fl.get("cells", [])
		for y in range(cells.size()):
			var row = cells[y]
			if not (row is Array):
				continue
			for x in range(row.size()):
				var cell = row[x]
				if not (cell is Dictionary):
					continue
				if String(cell.get("t", "")) == "teleport":
					if bool(cell.get("boss_teleport", false)) or bool(cell.get("boss_exit", false)):
						cell["is_boss_teleport"] = true
					elif boss_floor != -1:
						var dist_to_boss: float = (abs(x - boss_pos.x) + abs(y - boss_pos.y)) if fi == boss_floor else 999.0
						var dist_to_spawn: float = (abs(x - spawn_pos.x) + abs(y - spawn_pos.y)) if fi == spawn_floor else 999.0
						if dist_to_boss < dist_to_spawn:
							cell["is_boss_teleport"] = true


func _compute_spawn(_floors: Array) -> void:
	var sp = _def.get("spawn", {})
	var fi := int(sp.get("f", 0)) if sp is Dictionary else 0
	var sx := int(sp.get("x", 0)) if sp is Dictionary else 0
	var sy := int(sp.get("y", 0)) if sp is Dictionary else 0
	spawn_position = cell_to_world(fi, sx, sy)


## Convierte una coordenada de rejilla (planta f, columna x, fila y) a posición 3D
## en el mundo del escenario. Lo usa el spawn y los teletransportes internos.
func cell_to_world(f: int, x: int, y: int) -> Vector3:
	var base_y: float = float(f) * (_wall_h + FLOOR_GAP)
	return Vector3(float(x) * _cell, base_y + 0.6, float(y) * _cell)


## Convierte una posición 3D del mundo a coordenada de rejilla (planta, x, y).
## Lo usa el tutorial de dun_inicial para detectar cuándo el jugador se acerca
## a un kit que requiere una habilidad por primera vez.
func cell_from_world(pos: Vector3) -> Dictionary:
	var f: int = int(floor(pos.y / (_wall_h + FLOOR_GAP)))
	var x: int = roundi(pos.x / _cell)
	var y: int = roundi(pos.z / _cell)
	return {"f": f, "x": x, "y": y}


func _cell_height(cell: Dictionary) -> float:
	var h = cell.get("h", null)
	if h != null and float(h) > 0.0:
		return float(h)
	return _wall_h


## Aplica un tinte a un material base sin mutar el original (duplica solo si hace falta).
func _tinted(base: StandardMaterial3D, tint: Variant) -> StandardMaterial3D:
	if not (tint is Color):
		return base
	var key: String = "%d_%s" % [base.get_instance_id(), str(tint)]
	if _s_tinted_cache.has(key):
		return _s_tinted_cache[key]
	var dup := base.duplicate() as StandardMaterial3D
	dup.albedo_color = tint as Color
	_s_tinted_cache[key] = dup
	return dup


## Material de una superficie (suelo/pared) de una celda. Si `tex_key` nombra una
## textura REAL en assets/dungeon/textures/<key>[.png], construye un material con
## esa textura (tintada opcionalmente por `tint`). Si no, cae al material base
## tintado (donde `tint` ya trae el color del preset resuelto por _surface_tint).
## Así "material del suelo/pared" del editor admite tanto presets de color plano
## como texturas seleccionadas o subidas por el diseñador.
func _surface_material(base: StandardMaterial3D, tex_key: String, tint, kind: String) -> StandardMaterial3D:
	if tex_key != "":
		var path := DUNGEON_TEX_DIR + tex_key
		if not path.ends_with(".png") and not path.ends_with(".jpg"):
			path += ".png"
		var tex := UiKit.load_texture_safe(path)
		if tex != null:
			# Cache estático: celdas con el mismo tex_key + kind + tinte comparten
			# el mismo StandardMaterial3D, reduciendo variantes de pipeline en GPU.
			var tint_key: String = str(tint) if tint != null else ""
			var cache_key: String = path + "|" + kind + "|" + tint_key
			if _s_surface_mat_cache.has(cache_key):
				return _s_surface_mat_cache[cache_key] as StandardMaterial3D
			var m := StandardMaterial3D.new()
			m.albedo_texture = tex
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			var base_scale := Vector3(0.35, 0.35, 0.35) if kind == "wall" else Vector3(0.2, 0.2, 0.2)
			m.uv1_scale = base_scale
			m.roughness = 0.9 if kind == "wall" else 0.95
			if tint != null:
				m.albedo_color = tint
			_s_surface_mat_cache[cache_key] = m
			return m
	return _tinted(base, tint)


## Nombre de modelo a cargar para un tipo de casilla con LÓGICA DEDICADA (columna/
## estatua/interruptor/pinchos/puerta/palanca/plataforma...): normalmente FIJO
## por código, pero si esa ficha data/dungeon_tiles/<t>.json declara `render.model`
## (el MISMO campo que ya rellena el picker/subida de modelos 3D del editor —
## DungeonTilesManager.js — aunque estos tipos NO pasen por el camino genérico
## `_build_generic`, ver su comentario "los tipos con lógica dedicada... su render
## aquí no se usa"), se usa ESE en su lugar. Así se puede sustituir el aspecto de
## estos elementos "inteligentes" por un .glb/.gltf/.tscn propio sin tocar código
## (task_revision.md #5: "debería ser capaz de remplazarse todos los items por
## nuevos glb o gltf").
func _tile_model_override(t: String, default_name: String) -> String:
	var custom := String(Design.get_dungeon_tile_render(t).get("model", ""))
	return custom if custom != "" else default_name


## Convierte una densidad de repetición POR METRO (calibrada para `uv1_triplanar`,
## que multiplica la posición de MUNDO por esta escala) en la escala equivalente
## para el UV NATIVO 0..1 de una cara de `_cell` metros, usado cuando el triplanar
## está desactivado (`_is_mobile_gfx`). Sin este reescalado la textura se ve
## borrosa/estirada en gama baja: solo se muestrearía una franja diminuta (ver
## nota en _build_materials). Con triplanar activo se devuelve la escala tal cual.
func _uv_scale_for(per_meter_scale: Vector3, cell_size: float) -> Vector3:
	if _is_mobile_gfx:
		return per_meter_scale * cell_size
	return per_meter_scale


func _parse_color(v) -> Variant:
	if v is Color:
		return v
	var s := String(v).to_lower().strip_edges()
	if s == "":
		return null
	match s:
		"cyan", "blue", "azul":
			return Color(0.0, 0.8, 1.0)
		"gold", "yellow", "dorado", "amarillo":
			return Color(1.0, 0.8, 0.1)
		"red", "rojo":
			return Color(1.0, 0.2, 0.15)
		"green", "verde":
			return Color(0.15, 0.9, 0.3)
		"purple", "purpura", "púrpura":
			return Color(0.7, 0.25, 0.95)
		"white", "blanco":
			return Color(0.95, 0.95, 0.95)
		"orange", "naranja":
			return Color(1.0, 0.5, 0.0)
	if s.begins_with("#") and Color.html_is_valid(s):
		return Color.html(s)
	if Color.html_is_valid(s):
		return Color.html(s)
	return null


# Color base representativo de cada PRESET de material de suelo/pared del editor.
# Deben casar con los swatches del editor (TexSwatchPicker) para que lo que el
# diseñador ve al elegir sea lo que aparece en 3D. Estos son presets de COLOR
# plano; para texturas reales el editor guarda el nombre de fichero y _surface_material
# carga el PNG de assets/dungeon/textures.
const _TEX_COLORS := {
	"stone": Color(0.467, 0.467, 0.490),
	"dirt": Color(0.431, 0.271, 0.149),
	"grass": Color(0.255, 0.541, 0.200),
	"sand": Color(0.839, 0.741, 0.471),
	"wood": Color(0.498, 0.322, 0.153),
	"metal": Color(0.608, 0.631, 0.671),
	"tiles": Color(0.353, 0.380, 0.431),
	"lava_rock": Color(0.227, 0.102, 0.063),
}
const _WALL_COLORS := {
	"stone": Color(0.467, 0.467, 0.490),
	"brick": Color(0.561, 0.263, 0.188),
	"cave": Color(0.333, 0.251, 0.184),
	"wood": Color(0.498, 0.322, 0.153),
	"metal": Color(0.608, 0.631, 0.671),
	"ice": Color(0.663, 0.863, 0.929),
}


## Tinte efectivo de la superficie de una celda: gana el color explícito; si no,
## el color base del material elegido (wall para paredes, tex para suelos). Null
## si no hay nada → el material por defecto del motor.
func _surface_tint(cell: Dictionary) -> Variant:
	var c = _parse_color(cell.get("color", ""))
	if c is Color:
		return c
	var wall := String(cell.get("wall", ""))
	if wall != "" and _WALL_COLORS.has(wall):
		return _WALL_COLORS[wall]
	var tex := String(cell.get("tex", ""))
	if tex != "" and _TEX_COLORS.has(tex):
		return _TEX_COLORS[tex]
	return null


## Luz puntual opcional por celda (campo "light" del editor, en energía). Aditiva.
func _add_cell_light(container: Node3D, center: Vector3, cell: Dictionary) -> void:
	var e := float(cell.get("light", 0.0))
	if e <= 0.0:
		return
	var c = _parse_color(cell.get("color", ""))
	var col := Color(1.0, 0.85, 0.6)
	if c != null:
		col = c
	_add_light(container, center + Vector3(0, _wall_h * 0.6, 0), col, e, _cell * (2.0 + e))


func _marker_color(t: String) -> Color:
	match t:
		"teleport": return Color(0.55, 0.3, 0.9)
		# Portal de SALIDA de la mazmorra: dorado, para distinguirlo de un
		# vistazo del teletransporte INTERNO (violeta) — antes compartían el
		# mismo color/forma (task_arreglosPendientes.md §3).
		"teleport_exit": return Color(0.95, 0.78, 0.22)
		"chest", "item": return Color(0.9, 0.75, 0.2)
		"npc": return Color(0.2, 0.8, 0.45)
		"event": return Color(0.9, 0.35, 0.2)
		"cinematic": return Color(0.68, 0.35, 0.98)
		"switch", "button", "lever": return Color(0.25, 0.7, 0.8)
		_: return Color(0.5, 0.6, 0.7)
