# TabWorld3D.gd
# ─────────────────────────────────────────────────────────────────────────────
# PROTOTIPO V2 DEL MAPAMUNDI — Entorno 3D con cámara top-down.
#
# Comparte los mismos datos y reglas del juego: GlobalState.hexagons_db
# (vía WorldMapBuilder), el gating y los diálogos de QuestManager y la navegación de
# SceneManager. El jugador es un CILINDRO 3D; cada casilla y cada localización se
# representan con mallas 3D coloreadas por tipo. La cámara sigue al jugador en una
# vista cenital ligeramente inclinada para dar profundidad y un movimiento natural.
#
# Construido 100% por código (sin .tscn) e instanciado por GameRoot como la vista "world".
# ─────────────────────────────────────────────────────────────────────────────
class_name TabWorld3D
extends Control

# ─── CONSTANTES DEL MUNDO 3D ──────────────────────────────────────────────────
const TILE: float          = 2.0     # Lado de cada casilla (metros)
const GAP: float           = 0.0     # Separación visual entre casillas
const GROUND_H: float      = 0.30    # Grosor de la losa de suelo
const GROUND_TOP: float    = GROUND_H * 0.5
const CAM_HEIGHT: float    = 11.0    # Altura de la cámara sobre el jugador (vertical)
const CAM_BACK: float      = 8.0     # Desplazamiento Z (vertical)
const CAM_HEIGHT_LANDSCAPE: float = 8.5    # Altura de la cámara con zoom cercano (horizontal)
const CAM_BACK_LANDSCAPE: float   = 6.2    # Desplazamiento Z cercano (horizontal)
const CAM_MENU_HEIGHT: float = 6.5     # Zoom más cerrado mientras un menú modal está abierto (horizontal)
const CAM_MENU_BACK: float   = 5.0     # Desplazamiento Z del zoom de menú (horizontal)
const CAM_MENU_OFFSET_X: float = 5.5   # Mira a la derecha del personaje para situarlo en el tercio izquierdo
# Equivalente de zoom de menú en PORTRAIT: el Hub reserva el
# mismo 30%/70% (izq/der) que en horizontal, pero el 30% de un ancho de
# pantalla estrecho es una franja muy fina, así que el desplazamiento lateral
# se reduce (si no, el personaje queda fuera de esa franja) y se compensa con
# un zoom algo más cerrado para que siga siendo reconocible. Valores de
# partida razonables, ajustables desde el editor si el encuadre no convence.
const CAM_MENU_HEIGHT_PORTRAIT: float = 5.5
const CAM_MENU_BACK_PORTRAIT: float   = 4.2
const CAM_MENU_OFFSET_X_PORTRAIT: float = 2.2
# ── CÁMARA DINÁMICA DE REPOSO ───────────────────────────────────────────────
# Si el jugador permanece quieto (sin input de movimiento) más de
# IDLE_THRESHOLD segundos, la cámara se acerca suavemente (multiplica su
# altura/distancia por IDLE_ZOOM_FACTOR) para apreciar mejor al personaje en
# reposo; al reanudar el movimiento, vuelve a la distancia normal.
#
# "marea" — antes el umbral era de solo 0.6s
# (el zoom entraba y salía constantemente con cualquier microparón al
# explorar/recolectar) y el cambio de altura/distancia objetivo era un salto
# INSTANTÁNEO (`cam_h *= IDLE_ZOOM_FACTOR`) que el lerp de posición solo
# suavizaba a medias. Ahora: umbral subido a 3s (de verdad "quieto", no un
# tropiezo) y el propio factor de zoom se interpola con `_idle_zoom_blend`
# (ver `_process`) — más rápido al entrar en reposo, más lento y gradual al
# reanudar la marcha ("sin ser tan brusco").
const IDLE_THRESHOLD: float = 3.0
const IDLE_ZOOM_FACTOR: float = 0.76
const IDLE_ZOOM_BLEND_IN_RATE: float = 2.0    # hacia el acercamiento (reposo)
const IDLE_ZOOM_BLEND_OUT_RATE: float = 0.9   # de vuelta al plano lejano (al caminar)
const MOVE_SPEED: float    = 2.6     # Velocidad del movimiento libre (m/s) equilibrada (ajustada de 3.2 a 2.6 para evitar evasión excesiva)
const JOY_RADIUS: float    = 120.0   # Radio del joystick virtual (px)
# El suelo y el césped se dibujan con MultiMesh (unas pocas draw calls para TODO el
# mapa) y ya NO se les hace culling: se renderizan siempre y la niebla apaga lo lejano
# por color de instancia (coste cero por frame). En cambio, los marcadores/edificios
# siguen siendo nodos, así que SÍ se les aplica un culling por distancia (barato: solo
# alterna .visible, sin tocar materiales) para acotar el nº de draw calls.
const MARKER_RADIUS_X: int = 5       # Culling de marcadores: casillas a cada lado (E/O)
const MARKER_RADIUS_Z: int = 8       # Culling de marcadores en Z (la cámara inclinada ve lejos al norte)
const ANIM_RADIUS: int     = 4       # Casillas con animación por nodo (árboles/interactivo) cercanas
# task_arreglosPendientes.md §4: al finalizar un chunk nuevo (streaming), sus
# marcadores/edificios (nodos individuales, a diferencia del suelo/césped/decor
# genérico que va en MultiMesh) se instanciaban TODOS en el mismo frame síncrono.
# Si ese chunk tenía varios POIs a la vez (ciudad, aldea...) el coste se acumulaba
# en un único frame → micro-tirón al cruzar el límite del chunk explorando. Se
# amortiza construyendo como mucho este nº de marcadores por frame (ver
# _pending_marker_builds / _process_pending_marker_builds).
const MARKER_BUILD_BUDGET_PER_FRAME: int = 3
# Recursos genéricos que, por poder repetirse cientos de veces en un mapa grande
# (cantera/oro/ganado), se dibujan con UNA MultiMesh por tipo (ver
# _finalize_resource_decor) en vez de un nodo/marcador por casilla — igual que ya
# se hace con la decoración de montaña. No incluye bosque/pesca: el bosque anima
# por nodo (viento) y la pesca ya tiene su propio muelle orientado por vecino
#.
const RESOURCE_DECOR_KINDS: Array[String] = ["rock", "rock_worn", "gold", "gold_worn"]
const GRASS_PUSH_RADIUS: float = 0.9 # Radio (m) en el que el jugador aparta el césped (en shader)

# ─── VENTANA DE CONSTRUCCIÓN DE CASILLAS ──────────────────────────────────────
# El lienzo del mundo es enorme; solo se instancian tiles 3D dentro de este
# rectángulo (todo el contenido escrito hoy: valle de yelmo, hielo, pradera con
# la ciudad, desierto con la aldea, etc.). Las casillas no definidas quedan como
# MAR, cubierto por un único plano grande. Para ampliar el mundo en el futuro,
# agranda este rectángulo y añade contenido al GRID de WorldMapBuilder.
var build_min: Vector2i = Vector2i(0, 0)
var build_max: Vector2i = Vector2i(31, 26)

# ─── BIOMAS DE TIERRA (para la mezcla de bordes) ──────────────────────────────
# Cuando dos casillas de TIERRA adyacentes tienen biomas distintos, ambas pasan a
# la MultiMesh "blend" (ver _finalize_ground_blend) que mezcla sus dos texturas
# con un borde irregular en vez de un salto recto. El agua/orilla queda fuera
# (esa transición ya la resuelve el grupo "shore"). El orden importa: es el índice
# que se codifica en el custom data de cada instancia (tex0..tex6 del shader).
const LAND_GROUPS: Array[String] = ["grass", "sand", "snow", "bad", "mountain", "gnd", "beach"]

# ─── GRUPO DE SUELO → CÓDIGO DE TERRENO (para _make_ground_material) ─────────
# Mapea cada grupo de suelo al código de su definición data-driven
# (data/world_terrains/<code>.json) para resolver textura y tinte exactos.
const GROUND_GROUP_TERRAIN_CODE: Dictionary = {
	"shore": "cst", "snow": "ice", "sand": "des", "mountain": "mnt",
	"grass": "grs", "bad": "bad", "gnd": "gnd", "lav": "lav", "icy": "icy",
	"pol": "pol", "beach": "are",
}

# ─── SHADERS DE LAS MULTIMESH ─────────────────────────────────────────────────
# Suelo: textura + tinte + emisión, con oleaje del agua vía TIME (cero CPU). La
# niebla de guerra llega como COLOR de instancia y multiplica ALBEDO/EMISSION.
const GROUND_SHADER_CODE: String = """shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint = vec3(1.0);
uniform float rough = 0.85;
uniform float metal = 0.0;
uniform vec2 uv_scroll = vec2(0.0, 0.0);
uniform float wave_amp = 0.0;
uniform vec3 emis_color : source_color = vec3(0.0);
uniform float emis_energy = 0.0;
uniform float emis_pulse = 0.0;
uniform float sun_specular = 0.0;
varying vec3 v_inst;
varying vec3 v_world;
void vertex() {
	v_inst = COLOR.rgb;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 base_uv = v_world.xz;
	vec2 uv = base_uv + TIME * uv_scroll;
	if (wave_amp > 0.0) {
		uv += vec2(sin(TIME * 2.0) * wave_amp, cos(TIME * 1.6) * wave_amp);
	}
	vec4 tx = texture(tex, uv);
	ALBEDO = tx.rgb * tint * v_inst;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = tx.rgb * emis_color * (emis_energy + sin(TIME * 3.0) * emis_pulse) * v_inst;
	if (v_inst.r < 0.01) {
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
	}
}
"""
# Césped: brizna unitaria doblada en la punta por el viento (TIME) y apartada por la
# proximidad del jugador (uniform player_pos). Niebla vía COLOR de instancia.
# `wind_gust` sube con climas de viento (arena/hojas/lluvia, ver drift en
# ambience.json) para que las ráfagas se noten sin depender de una lista
# cableada de climas. `v_rand` es un hash de la posición de mundo de cada
# brizna (sin coste de CPU ni tocar la MultiMesh) que varía altura y tono.
const GRASS_SHADER_CODE: String = """shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec3 tint : source_color = vec3(0.24, 0.58, 0.20);
uniform vec3 tint_tip : source_color = vec3(0.48, 0.82, 0.28);
uniform float rough = 0.80;
uniform vec3 player_pos = vec3(0.0, 0.0, 0.0);
uniform float push_radius = 1.0;
uniform float wind_gust = 0.0;
varying vec3 v_inst;
varying float v_rand;
varying float v_rand2;
varying float v_height;

void vertex() {
	v_inst = COLOR.rgb;
	vec3 wp = MODEL_MATRIX[3].xyz;
	v_rand = fract(sin(dot(wp.xz, vec2(12.9898, 78.233))) * 43758.5453);
	v_rand2 = fract(sin(dot(wp.xz, vec2(39.346, 11.135))) * 23421.631);
	v_height = clamp(VERTEX.y * 2.2 + 0.1, 0.0, 1.0);
	if (COLOR.r < 0.01) {
		VERTEX = vec3(0.0);
	} else {
		float h = v_height;
		float phase = wp.x * 3.7 + wp.z * 6.3 + v_rand * 6.28;
		float gust_amp = 1.0 + wind_gust * 1.3;
		float gust_freq = 1.0 + wind_gust * 0.15;
		float sx = sin(TIME * 2.1 * gust_freq + phase) * 0.09 * gust_amp + (wind_gust * 0.05);
		float sz = cos(TIME * 1.7 * gust_freq + phase + 1.2) * 0.08 * gust_amp + (wind_gust * 0.03);
		vec2 to_p = vec2(wp.x - player_pos.x, wp.z - player_pos.z);
		float d = length(to_p);
		if (d < push_radius && d > 0.001) {
			float f = (push_radius - d) / push_radius;
			vec2 push_dir = normalize(to_p);
			sx += push_dir.x * f * 0.55;
			sz += push_dir.y * f * 0.55;
		}
		VERTEX.y *= mix(0.80, 1.25, v_rand);
		VERTEX.x += sx * h;
		VERTEX.z += sz * h;
	}
}
void fragment() {
	vec3 base_col = mix(vec3(0.13, 0.35, 0.13), vec3(0.18, 0.42, 0.16), v_rand);
	vec3 tip_col = mix(vec3(0.24, 0.48, 0.18), vec3(0.32, 0.58, 0.22), v_rand2);
	vec3 col = mix(base_col, tip_col, v_height);
	col *= mix(0.92, 1.10, v_rand2);
	ALBEDO = col * v_inst;
	ROUGHNESS = rough;
	SPECULAR = 0.08;
}
"""
# Borde entre biomas: mezcla las texturas de la casilla propia y de la vecina con
# un límite irregular (ruido por posición de MUNDO, no por casilla, para que el
# recorte sea continuo entre ambas casillas del borde) en vez de un salto recto.
# El "custom data" por instancia (INSTANCE_CUSTOM) le dice al shader qué dos
# texturas mezclar (own_id/nb_id, índices en LAND_GROUPS) y hacia qué lado
# (ángulo). Una sola MultiMesh para TODOS los bordes del mapa: coste ínfimo.
const GROUND_BLEND_SHADER_CODE: String = """shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D tex0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex3 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex4 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex5 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex6 : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint0 = vec3(1.0);
uniform vec3 tint1 = vec3(1.0);
uniform vec3 tint2 = vec3(1.0);
uniform vec3 tint3 = vec3(1.0);
uniform vec3 tint4 = vec3(1.0);
uniform vec3 tint5 = vec3(1.0);
uniform vec3 tint6 = vec3(1.0);
uniform float rough = 0.85;
varying vec3 v_inst;
varying vec4 v_custom;
varying vec3 v_world;
void vertex() {
	v_inst = COLOR.rgb;
	v_custom = INSTANCE_CUSTOM;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
vec3 sample_layer(int id, vec2 uv) {
	if (id == 0) { return texture(tex0, uv).rgb * tint0; }
	if (id == 1) { return texture(tex1, uv).rgb * tint1; }
	if (id == 2) { return texture(tex2, uv).rgb * tint2; }
	if (id == 3) { return texture(tex3, uv).rgb * tint3; }
	if (id == 4) { return texture(tex4, uv).rgb * tint4; }
	if (id == 5) { return texture(tex5, uv).rgb * tint5; }
	if (id == 6) { return texture(tex6, uv).rgb * tint6; }
	return texture(tex0, uv).rgb * tint0;
}
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * vnoise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}
void fragment() {
	int own_id = int(round(v_custom.r));
	int nb_id  = int(round(v_custom.g));
	vec3 col = sample_layer(own_id, v_world.xz);
	if (nb_id != own_id) {
		vec3 alt = sample_layer(nb_id, v_world.xz);
		float ang = (v_custom.b - 0.5) * TAU;
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 perp = vec2(-dir.y, dir.x);
		vec2 local = (UV - 0.5) * 2.0;
		float seed = v_custom.a * 71.0;
		float warp = (fbm(v_world.xz * 0.5 + seed) - 0.5) * 0.35;
		local += perp * warp;
		float proj = dot(local, dir);
		float jag = (fbm(v_world.xz * 2.6 + seed * 1.7) - 0.5) * 0.30;
		float blend_strength = smoothstep(0.40, 1.05, proj + jag) * 0.5;
		col = mix(col, alt, blend_strength);
	}
	ALBEDO = col * v_inst;
	ROUGHNESS = rough;
	if (v_inst.r < 0.01) {
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
	}
}
"""

# AURORA de los MUROS CONDICIONADOS (gating) BLOQUEADOS: cortina traslúcida con
# bandas de color ondulantes (como una aurora boreal) que avisa de que ahí hay
# una barrera invisible que no se puede cruzar todavía (túnel de las colinas,
# puente del mono…). Se desvanece en los bordes para no cortar en seco.
const AURORA_SHADER_CODE: String = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 color_a : source_color = vec3(0.30, 0.95, 0.65);
uniform vec3 color_b : source_color = vec3(0.55, 0.35, 0.95);
void fragment() {
	float t = TIME * 0.6;
	float wave = sin(UV.x * 5.0 + t * 2.0) * 0.5 + 0.5;
	float bands = sin(UV.y * 9.0 - t * 1.7 + wave * 2.4) * 0.5 + 0.5;
	vec3 col = mix(color_a, color_b, wave);
	float edge_x = smoothstep(0.0, 0.10, UV.x) * smoothstep(0.0, 0.10, 1.0 - UV.x);
	float edge_y = smoothstep(0.0, 0.22, UV.y) * smoothstep(0.0, 0.30, 1.0 - UV.y);
	float alpha = bands * edge_x * edge_y * 0.7;
	ALBEDO = col;
	EMISSION = col * 1.5;
	ALPHA = alpha;
}
"""

# ─── TEXTURAS DE CASILLAS Y BIOMAS ───────────────────────────────────────────
var _tex_tile_sea: Texture2D      = load("res://assets/world/map/tile_sea.png")
var _tex_tile_pradera: Texture2D  = load("res://assets/world/map/tile_pradera.png")
var _tex_tile_sand: Texture2D     = load("res://assets/world/map/tile_sand.png")
var _tex_tile_mountain: Texture2D = load("res://assets/world/map/tile_mountain.png")
var _tex_tile_snow: Texture2D     = load("res://assets/world/map/tile_snow.png")
var _tex_tile_yelmo: Texture2D    = load("res://assets/world/map/tile_yelmo.png")
var _tex_tile_ice: Texture2D      = load("res://assets/world/map/tile_ice.png")
var _tex_tile_lava: Texture2D     = load("res://assets/world/map/tile_lava.png")
var _tex_tile_ground: Texture2D   = load("res://assets/world/map/tile_ground.png")
var _tex_tile_beach: Texture2D    = load("res://assets/world/map/tile_beach.png")
var _tex_tile_contaminacion: Texture2D = load("res://assets/world/map/tile_contaminacion.png")
var _tex_tile_templo: Texture2D   = load("res://assets/world/map/tile_templo.png")

# ─── REFERENCIAS 3D ───────────────────────────────────────────────────────────
var _vp_container: SubViewportContainer
var _sub_viewport: SubViewport
var _cam: Camera3D
var _cam_look_target: Vector3 = Vector3.ZERO   # Suavizado sincronizado de cámara para eliminar vibración de cabeceo
# Iluminación del ciclo día/noche: se modulan según TimeManager.daylight_factor().
var _sun: DirectionalLight3D = null
var _env: Environment = null
var _last_daylight: float = -1.0   # último factor aplicado (evita reescrituras)
var _fireflies: CPUParticles3D = null   # luciérnagas ambientales nocturnas
var _sun_dust: CPUParticles3D = null    # motas de polvo doradas ambientales diurnas
var _tiles_root: Node3D
var _player: Node3D
var _player_mesh: Node3D
var _player_material: StandardMaterial3D = null   # material compartido del modelo del héroe, tintado según la profesión activa
var _last_tinted_profession: String = ""   # evita retintar el material si la profesión no ha cambiado (state_updated es muy frecuente)
var _poison_particles: CPUParticles3D = null
var _poison_timer: float = 0.0
var _poison_tick_accum: float = 0.0
var _poison_dps: float = 4.0
## Task 4 FASE 2.3 — un único emisor reconfigurable (color/velocidad/gravedad)
## para las partículas de terreno bajo los pies (hierba/arena/nieve), en vez
## de un nodo separado por bioma. `_terrain_particles_kind` evita reconfigurar
## el material/emisor en cada frame si el terreno no ha cambiado.
var _terrain_particles: CPUParticles3D = null
var _terrain_particles_kind: String = ""
## Terreno (código `CellResource.terrain`) -> tipo de partícula de paso.
## Sin entrada = sin partículas (p. ej. piedra/camino/montaña).
const TERRAIN_STEP_PARTICLE_KIND: Dictionary = {
	"grs": "grass",
	"des": "sand",
	"are": "sand",
	"icy": "snow",
}
## BARCO (ver GlobalState.boat_pos/is_sailing): silueta que sustituye al
## personaje mientras se navega (hijo de `_player`, sigue su posición/rotación
## gratis) y marcador del barco aparcado visible en el mapa cuando no se navega.
var _boat_rider_visual: Node3D = null
var _boat_parked_marker: Node3D = null
# Pivotes de cadera/hombro para el ciclo de marcha (ver _animate_walk_cycle).
var _player_leg_l: Node3D
var _player_leg_r: Node3D
var _player_arm_l: Node3D
var _player_arm_r: Node3D
var _player_skel: Skeleton3D = null
var _bone_leg_l: int = -1
var _bone_leg_r: int = -1
var _bone_arm_l: int = -1
var _bone_arm_r: int = -1
var _player_anim_player: AnimationPlayer = null
# coord(Vector2i) -> entry {group, mm_index, grass_indices, obj, label,
#   is_water, is_shore, is_trees, is_interactive, vis_applied}
var _cells: Dictionary = {}
# Coords cuyo marcador 3D quedó pendiente de reconstruir porque el cambio de
# celda (map_cell_changed) llegó con el mundo oculto (p. ej. diálogo/narrativa
# abierto sobre el POI). Se procesan en _on_visibility_changed al volver a ser
# visible, para que el POI no se quede mostrando un marcador obsoleto.
var _pending_marker_rebuilds: Dictionary = {}

# ─── ENEMIGOS DEL MAPAMUNDI (actores dinámicos · ) ──────────────────────
# spawn(Vector2i) -> entry { node:Node3D, spawn:Vector2i, coord:Vector2i,
#   def:Dictionary, accum:float, interval:float }. Deambulan lento en radio 1 del
# punto de aparición, nunca persiguen y al contacto inician combate.
@warning_ignore("unused_private_class_variable")
var _enemies: Dictionary = {}
@warning_ignore("unused_private_class_variable")
var _enemy_combat_pending: bool = false   # evita disparar dos combates a la vez
@warning_ignore("unused_private_class_variable")
var _enemy_rng := RandomNumberGenerator.new()

# ─── MULTIMESH: suelo (1 por grupo de terreno) y césped (1 global) ────────────
# El mundo entero se dibuja con estas pocas MultiMesh (batching total). La niebla
# de guerra se aplica por COLOR de instancia y la lee el shader: cambiar la niebla
# de una casilla es una escritura de buffer, no un repintado de material.
# Las claves de _ground_mm ahora llevan el
# prefijo "<chunk_x>_<chunk_y>_" del chunk al que pertenecen (ver
# _chunk_key_prefix), así que siguen siendo un Dictionary[String, MultiMesh]
# plano — ningún punto de lectura existente (_apply_cell_visual, agotamiento de
# recursos, etc.) necesita cambiar, solo lo que se ESCRIBE en entry["group"]/
# entry["decor_group"] al registrar la casilla.
var _ground_mm: Dictionary = {}       # "<chunk>_<group>"(String) -> MultiMesh
var _grass_mm: Dictionary = {}        # chunk_coord(Vector2i) -> MultiMesh
var _grass_mat: Material = null       # se le pasa la posición del jugador cada frame (si es shader)
# Caché de StandardMaterial3D compartidos para los marcadores/edificios: dedup por
# propiedades → mismas piezas comparten material → el motor las agrupa (menos draw calls).
var _shared_mats: Dictionary = {}
# ─── STREAMING DE CHUNKS ──────────────────────────────────────────────────────
var _streamer: WorldChunkStreamer = null
var _chunk_roots: Dictionary = {}        # chunk_coord(Vector2i) -> Node3D (padre de sus MultiMesh/marcadores)
# Cola de marcadores/edificios pendientes de instanciar, repartidos en varios
# frames (ver MARKER_BUILD_BUDGET_PER_FRAME). Cada item: {coord, cell, wp, entry, parent}.
var _pending_marker_builds: Array[Dictionary] = []
# Cachés de materiales/mallas compartidas por chunk: como ahora se hornean por
# chunk (antes una vez para todo el mapa), sin caché se duplicarían 9 veces.
var _ground_mat_cache: Dictionary = {}   # group(String) -> ShaderMaterial
var _ground_blend_mat: ShaderMaterial = null
var _mountain_mesh_cache: ArrayMesh = null
var _resource_mesh_cache: Dictionary = {}  # key(String, "rock"/"gold"/"milk") -> ArrayMesh
var _grass_mesh_cache: Mesh = null
# Shaders compartidos (se crean una vez).
var _ground_shader: Shader = null
var _grass_shader: Shader = null
var _ground_blend_shader: Shader = null
var _gate_aurora_shader: Shader = null
# Visuales de "aurora" pintados sobre cada muro condicionado BLOQUEADO (ver
# _rebuild_gate_auroras): se recrean solo cuando cambia el conjunto de puertas
# activas (no en cada paso), para que el coste sea cero en el caso normal.
var _active_gate_visuals: Array = []
var _gate_visual_key: String = ""

# ─── ESTADO DEL MAPA ─────────────────────────────────────
## Casilla "lógica" actual (la más cercana al jugador). player_pos se mantiene
## sincronizada con GlobalState para guardado / gating / combate.
var player_pos: Vector2i    = GameConfig.WORLD_START_POS
var _current_cell: Vector2i = GameConfig.WORLD_START_POS
var is_traveling: bool      = false   # true mientras el jugador se desplaza (bob/anim)
## Cámara dinámica de reposo: acumulador de tiempo
## quieto y flag de si el zoom de reposo está activo. Ver constantes
## IDLE_THRESHOLD / IDLE_ZOOM_FACTOR.
var _idle_timer: float = 0.0
var _is_idle_zoomed: bool = false
## 0.0 = plano lejano normal, 1.0 = acercamiento de reposo completo. Se
## interpola por-frame en vez de saltar de golpe (ver `IDLE_ZOOM_BLEND_*_RATE`).
var _idle_zoom_blend: float = 0.0
var _walk_time: float       = 0.0
var _facing: float          = 0.0            # Orientación del cilindro (rad)
var _chop_time: float       = -1.0           # >=0 mientras el peón hace el gesto de talar/recolectar
var _weather_overlay: WeatherOverlay = null   # capa de clima data-driven
var _current_music_id: String = ""            # última pista de música aplicada por ambiente

# ─── HIELO RESBALADIZO ───
# Al entrar en una casilla resbaladiza el jugador pierde el control: se fuerza
# el movimiento en la dirección con la que entró hasta salir de la zona (o
# quedar bloqueado contra un obstáculo, lo que restaura el control de inmediato).
var _sliding: bool = false
var _slide_dir: Vector2 = Vector2.ZERO
var _last_move_dir: Vector2 = Vector2.ZERO
# Clima tirado por PROBABILIDAD y CACHEADO por terreno (terrain -> weather_id): así
# el clima es estable mientras recorres un mismo bioma y no parpadea casilla a
# casilla. Se re-tira al cambiar de fase día/noche (_on_world_phase_changed).
@warning_ignore("unused_private_class_variable")
var _weather_by_terrain: Dictionary = {}

# ─── RENDIMIENTO: niebla incremental, culling y animación acotada ─────────────
@warning_ignore("unused_private_class_variable")
var _prev_fog_pos: Vector2i       = Vector2i(9999, 9999)  # última pos con niebla recalculada
var _anim_coords: Array[Vector2i] = []   # casillas con alguna animación (agua/árboles/césped/interactivo)
var _nearby_anim: Array[Vector2i] = []   # subconjunto de _anim_coords cercano (recalc al cambiar de casilla)

# ─── COLA DE NIEBLA (evita tirones al cruzar de casilla) ──────────────────────
# _fog_step ya NO recalcula la ventana entera de golpe (podía ser ~200-300 casillas
# en un solo frame → tirón en móvil). En su lugar encola las casillas afectadas y
# _process_fog_queue() las consume con un presupuesto fijo por frame: el refresco
# "tarda" unos pocos frames en completarse pero nunca bloquea el movimiento.
const FOG_BUDGET_PER_FRAME: int = 40
@warning_ignore("unused_private_class_variable")
var _fog_queue: Array[Vector2i]  = []
@warning_ignore("unused_private_class_variable")
var _fog_cursor: int             = 0
@warning_ignore("unused_private_class_variable")
var _fog_queued: Dictionary      = {}    # coord -> true, evita encolar duplicados

# ─── UI INFERIOR (panel ubicación / viaje), construida por código ─────────────
var _bottom: PanelContainer
@warning_ignore("unused_private_class_variable")
var _hb_actions: HBoxContainer
var _lbl_loc_icon: Label
var _lbl_loc_name: Label
var _lbl_loc_sub: Label
var _icon_circle: PanelContainer
var _btn_enter: Button
@warning_ignore("unused_private_class_variable")
var _travel_overlay: Control   # overlay activo de selección de destino (o null)
var _btn_map: Button   # botón que abre el mapa/minimapa con niebla de guerra
var _minimap_overlay: MinimapViewer   # overlay activo del mapa (o null)
var _btn_gather: Button
var _btn_tent: Button
# Botón contextual de HERRAMIENTA (hacha/pico/pala): aparece cuando el jugador
# está sobre/junto a un obstáculo rompible y posee la herramienta requerida.
var _btn_tool: Button
# Coord del obstáculo objetivo de la herramienta (o INVALID_COORD si ninguno).
@warning_ignore("unused_private_class_variable")
var _tool_target: Vector2i = Vector2i(-9999, -9999)
# Acción de MODIFICACIÓN DE TERRENO disponible ahora mismo (excavar/plantar/talar),
# cuando no hay obstáculo. {} = ninguna. Reutiliza el mismo botón contextual _btn_tool.
@warning_ignore("unused_private_class_variable")
var _terrain_action: Dictionary = {}
# Botón contextual de BOMBA: colocar una bomba (consumible) que estalla tras unos
# segundos y demuele obstáculos con `obstacle.bombable`.
var _btn_bomb: Button
@warning_ignore("unused_private_class_variable")
var _bombs_active: int = 0   # bombas en cuenta atrás (evita spam / recursión visual)
# ── Reloj del mundo (ciclo día/noche) ──
# Panel compacto arriba-derecha con el icono de fase (☀/🌙) y la hora "HH:MM".
# Se refresca por señales del TimeManager (hour_changed / phase_changed), no por frame.
var _clock_panel: PanelContainer
var _lbl_clock_icon: Label
var _lbl_clock_time: Label
var _is_cinematic_active: bool = false
# El estado de "modal flotante abierta" ya NO se guarda en una
# variable local propia; se lee/escribe directamente en `GlobalState.is_movement_locked`
# para que sea la ÚNICA fuente de verdad del bloqueo de movimiento (antes este mapamundi
# tenía su propio flag `_modal_open` desincronizado del global, que sólo reflejaba el
# Hub/Menú Radial y no las vistas flotantes abiertas por `_show_view`).
var _base_aura_ring: Node3D
## Material COMPARTIDO por las 4 barras del perímetro cuadrado del territorio
## (ver `WorldCinematicController._update_base_aura`): el pulso de `_process`
## anima su alfa directamente, ya que el propio `_base_aura_ring` (Node3D) no
## tiene `material_override` (solo sus hijos MeshInstance3D lo tienen).
var _base_aura_mat: StandardMaterial3D
# Previsualización translúcida de la HOGUERA construible, en la casilla a la derecha
# del campamento (mientras no se haya construido). Se recrea en cada _rebuild_tiles.
@warning_ignore("unused_private_class_variable")
var _campfire_ghost: Node3D = null
var _last_gather_time: int = 0
# Acumulador para refrescar periódicamente la visibilidad de nodos de recolección
# agotados cercanos (reaparecen solos al regenerarse, sin esperar a que el
# jugador se mueva de casilla). Ver _animate_nearby.
var _gather_regen_check_accum: float = 0.0
# Daño ambiental por terreno (p. ej. lava): acumulador de tiempo hasta el próximo
# tick. Se reinicia al salir de un terreno peligroso (ver _apply_terrain_hazard).
var _hazard_accum: float = 0.0

# ─── JOYSTICK VIRTUAL (movimiento libre, táctil) ─────────────────────────────
@warning_ignore("unused_private_class_variable")
var _joy_area: Control
@warning_ignore("unused_private_class_variable")
var _joy_base: Panel
@warning_ignore("unused_private_class_variable")
var _joy_knob: Panel
var _joy_active: bool     = false
@warning_ignore("unused_private_class_variable")
var _joy_index: int       = -1   # índice del toque activo (-2 = ratón)
@warning_ignore("unused_private_class_variable")
var _joy_center: Vector2  = Vector2.ZERO
@warning_ignore("unused_private_class_variable")
var _joy_vec: Vector2     = Vector2.ZERO

# ─── MOVIMIENTO POR CLIC (tap = ir a la casilla; arrastrar = joystick) ────────
const TAP_MAX_MS: int         = 350     # duración máxima de un toque para contar como "tap"
const TAP_MAX_MOVE_PX: float  = 16.0    # deslizamiento máximo (px) para seguir siendo "tap"
const MOVE_TARGET_STOP: float = 0.18    # distancia (m) a la que se considera alcanzado el destino
# Destino de "ir a casilla" activo (mundo 3D). Se cancela con joystick/teclado.
var _move_target: Vector3     = Vector3.ZERO
var _has_move_target: bool    = false
var _move_path: Array[Vector3] = []
var _destination_marker: MeshInstance3D = null
var _stuck_timer: float       = 0.0
@warning_ignore("unused_private_class_variable")
var _touch_index: int         = -1
var _touch_start_pos: Vector2 = Vector2.ZERO
@warning_ignore("unused_private_class_variable")
var _touch_start_ms: int      = 0
@warning_ignore("unused_private_class_variable")
var _is_dragging_joystick: bool = false
const JOY_DRAG_THRESHOLD: float = 14.0


#region CICLO DE VIDA

## Controlador de clima/ambiente e iluminación día-noche. Se instancia al inicio
## de `_ready`, antes de la primera aplicación de ambiente/iluminación.
var _env_controller: WorldEnvironmentController = null

## Controlador de física de terreno / hielo resbaladizo. Gestiona las
## transiciones de la inercia de deslizamiento.
var _phys_controller: OverworldPhysicsController = null

## Constructor del joystick virtual y del panel inferior de ubicación/acción.
## Se instancia al inicio de `_ready`.
var _hud_builder: WorldHudBuilder = null

## Controlador de cámara de cinemáticas y de la cinemática de la presa
## progresiva. Se instancia al inicio de `_ready`, antes de suscribirse a
## EVENT_CINE_CAMERA/scene_finished.
var _cine_controller: WorldCinematicController = null

func _ready() -> void:
	_env_controller = WorldEnvironmentController.new()
	_env_controller.setup(self)
	_phys_controller = OverworldPhysicsController.new()
	_phys_controller.setup(self)
	_hud_builder = WorldHudBuilder.new()
	_hud_builder.setup(self)
	_cine_controller = WorldCinematicController.new()
	_cine_controller.setup(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# La raíz NO captura el toque: los taps del mapa caen a _unhandled_input (raycast),
	# mientras el panel inferior y el diálogo (hijos con STOP) sí consumen los suyos.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("world_3d")

	# Asegurar que los datos del mundo estén construidos antes de renderizar.
	if GlobalState.hexagons_db.is_empty():
		WorldMapBuilder.build_into_global()

	# En Modo Debug, sembrar un CARTEL y una ROCA demolible de ejemplo junto al
	# inicio para probar los sistemas. Solo la primera vez (persisten /
	# son idempotentes). NO se siembran enemigos: el mapamundi debe estar limpio.
	# El inventario/oro de pruebas NO se siembra aquí: `GlobalState.
	# reset_for_new_game(true)` (llamado al arrancar la partida debug/Sala de
	# Tests) ya entrega todo el catálogo; volver a sembrarlo aquí (no
	# idempotente, a diferencia de `place_debug_sign`/`place_debug_bombable`)
	# duplicaba el equipo (quantity x2) y disparaba los consumibles cada vez
	# que se reconstruía esta vista, además de rebajar el oro de a 9999.
	if GlobalState.debug_mode:
		DebugWorldSeeder.place_debug_bombable()

	# Ajustar dinámicamente las dimensiones a renderizar a partir del JSON cargado.
	var w_width := int(Design.world.get("width", 32))
	var w_height := int(Design.world.get("height", 27))
	build_max = Vector2i(w_width - 1, w_height - 1)

	player_pos = GlobalState.player_pos
	_current_cell = player_pos

	_build_viewport_and_scene()
	_build_bottom_panel()
	_build_clock()
	_build_joystick()
	if GlobalState.debug_mode:
		DebugToolbar.build_debug_toolbar(self)
	_setup_quest_system()
	_build_tiles()
	_streamer = WorldChunkStreamer.new()
	_streamer.initialize(self, player_pos)
	_flush_pending_marker_builds()
	WorldEnemies.build_enemies(self)   # actores de enemigos del mapamundi
	WorldFogRenderer.restore_explored(self)
	WorldFogRenderer.update_fog_of_war(self, player_pos)
	WorldFogRenderer.apply_visibility(self)
	WorldFogRenderer.rebuild_nearby(self)
	_recompute_gates()   # muros condicionados (gating) según el estado actual

	# Colocar al jugador y la cámara en la casilla inicial garantizando suelo transitable.
	var safe_start_coord := _find_nearest_walkable_cell(player_pos)
	player_pos = safe_start_coord
	_current_cell = safe_start_coord
	GlobalState.player_pos = safe_start_coord
	var start_cell: CellResource = GlobalState.hexagons_db.get(safe_start_coord, null) as CellResource
	var start_pos := _find_safe_spawn_world_pos(safe_start_coord)
	_player.position = start_pos
	_cam.position = _player.position + Vector3(0.0, CAM_HEIGHT, CAM_BACK)
	_cam_look_target = _player.position
	_cam.look_at(_cam_look_target, Vector3.UP)

	# Capa de clima data-driven y ambiente inicial de la casilla de inicio.
	_weather_overlay = WeatherOverlay.new()
	add_child(_weather_overlay)
	_update_ambience(start_cell)

	Locale.locale_changed.connect(_on_locale_changed)
	GlobalState.state_updated.connect(_on_global_state_updated)
	Locale.theme_changed.connect(func(_id: String) -> void: _refresh_world_labels_theme())
	visibility_changed.connect(_on_visibility_changed)
	_on_locale_changed()

	# Ciclo día/noche (TimeManager): refrescamos reloj/iluminación por señal, no por
	# frame, y forzamos el estado inicial acorde a la hora persistida.
	TimeManager.hour_changed.connect(_on_world_hour_changed)
	TimeManager.phase_changed.connect(_on_world_phase_changed)
	_apply_daynight_lighting(true)
	_update_clock()

	if start_cell:
		_update_location_panel(start_cell)
	_update_base_aura()

	resized.connect(_update_responsive_layout)
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()


func _update_responsive_layout() -> void:
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var is_landscape := sz.x > sz.y
	# BOOST VERTICAL (ver GameRoot._setup_redesigned_hud): mismo factor 2.1x que
	# ya usa la barra de pestañas para compensar `window/stretch/aspect=expand`.
	# Solo afecta a retrato; horizontal se queda exactamente igual.
	var b := 2.1 if not is_landscape else 1.0
	if _bottom != null:
		_bottom.visible = true
		if not is_landscape:
			_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			_bottom.offset_top = -210.0 * b
			_bottom.offset_bottom = 0.0
		else:
			_bottom.anchor_left = 1.0
			_bottom.anchor_right = 1.0
			_bottom.anchor_top = 1.0
			_bottom.anchor_bottom = 1.0
			_bottom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
			_bottom.offset_left = 0.0
			_bottom.offset_right = -16.0
			_bottom.offset_top = 0.0
			_bottom.offset_bottom = -16.0
	if _icon_circle != null and is_instance_valid(_icon_circle):
		_icon_circle.custom_minimum_size = Vector2(46 * b, 46 * b)
	if _lbl_loc_icon != null and is_instance_valid(_lbl_loc_icon):
		_lbl_loc_icon.add_theme_font_size_override("font_size", roundi(34 * b))
	if _lbl_loc_name != null and is_instance_valid(_lbl_loc_name):
		_lbl_loc_name.add_theme_font_size_override("font_size", roundi(28 * b))
	if _lbl_loc_sub != null and is_instance_valid(_lbl_loc_sub):
		_lbl_loc_sub.add_theme_font_size_override("font_size", roundi(22 * b))
	for btn in [_btn_gather, _btn_enter, _btn_tool, _btn_bomb, _btn_tent]:
		if btn != null and is_instance_valid(btn):
			btn.custom_minimum_size = Vector2(104 * b, 68 * b)
			btn.add_theme_font_size_override("font_size", roundi(23 * b))


## Activa/desactiva el modo "modal abierta" del mapamundi: bloquea input, detiene
## al personaje y ajusta la cámara en horizontal (personaje en el tercio izquierdo).
func set_modal_mode(active: bool) -> void:
	GlobalState.is_movement_locked = active
	_reset_joystick()
	_clear_move_target()
	if active:
		is_traveling = false
		_update_overworld_footsteps(false)
	if _bottom != null and is_instance_valid(_bottom):
		_bottom.visible = not active
	if _btn_map != null and is_instance_valid(_btn_map):
		var in_dungeon: bool = (SceneManager != null and SceneManager.current_view_name == "dungeon")
		_btn_map.visible = not active and not in_dungeon and is_visible_in_tree()
	if _joy_area != null and is_instance_valid(_joy_area):
		_joy_area.visible = not active
	if not active:
		var cur_cell: CellResource = GlobalState.hexagons_db.get(player_pos, null) as CellResource
		if cur_cell != null:
			_update_location_panel(cur_cell)


func _process(delta: float) -> void:
	# Con el mundo oculto (combate/ciudad/base/menús) NO gastamos CPU aquí; además
	# el SubViewport pasa a UPDATE_DISABLED en _on_visibility_changed (sin GPU).
	if not is_visible_in_tree():
		return
	if not is_instance_valid(_player) or not is_instance_valid(_cam):
		return

	# Termina en el hilo principal cualquier
	# chunk cuya clasificación en segundo plano (WorkerThreadPool) ya esté lista.
	if _streamer != null:
		_streamer.poll_pending(self)

	# Construye, como mucho MARKER_BUILD_BUDGET_PER_FRAME por frame, los
	# marcadores/edificios pendientes de chunks recién finalizados (§4: evita
	# el tirón de instanciar TODOS los POIs de un chunk nuevo de golpe).
	_process_pending_marker_builds()

	# Durante una cinemática la cámara la controla `_on_cine_camera_event` (tween a
	# una casilla); no la reencuadramos sobre el jugador para no pelear con el tween.
	if _is_cinematic_active:
		return

	_apply_free_movement(delta)

	# Cámara cenital que sigue al jugador con suavizado (zoom más cercano en formato horizontal).
	var sz := get_viewport_rect().size
	var is_landscape := sz.x > sz.y
	var cam_h := CAM_HEIGHT_LANDSCAPE if is_landscape else CAM_HEIGHT
	var cam_b := CAM_BACK_LANDSCAPE if is_landscape else CAM_BACK
	var look_offset := Vector3.ZERO
	# Si hay una modal flotante abierta, acercamos el zoom y desplazamos el punto
	# de mira hacia la derecha, dejando al personaje visible en el tercio
	# izquierdo (30% que reserva `CharacterHubModal` en ambas orientaciones).
	if GlobalState.is_movement_locked:
		if is_landscape:
			cam_h = CAM_MENU_HEIGHT
			cam_b = CAM_MENU_BACK
			look_offset = Vector3(CAM_MENU_OFFSET_X, 0.4, 0.0)
		else:
			cam_h = CAM_MENU_HEIGHT_PORTRAIT
			cam_b = CAM_MENU_BACK_PORTRAIT
			look_offset = Vector3(CAM_MENU_OFFSET_X_PORTRAIT, 0.4, 0.0)
		_idle_timer = 0.0
		_is_idle_zoomed = false
		_idle_zoom_blend = 0.0
	else:
		# Cámara dinámica de reposo: sin ninguna modal abierta, si el jugador
		# lleva IDLE_THRESHOLD segundos sin moverse, la cámara se acerca; al
		# reanudar el movimiento (is_traveling ya lo actualizó
		# `_apply_free_movement` arriba), vuelve a alejarse. El acercamiento
		# en sí (`_idle_zoom_blend`) se interpola con una velocidad distinta
		# de entrada/salida para que volver a caminar no tire de la cámara de
		# golpe.
		if is_traveling:
			_idle_timer = 0.0
			_is_idle_zoomed = false
		else:
			_idle_timer += delta
			if _idle_timer >= IDLE_THRESHOLD:
				_is_idle_zoomed = true
			if OrbCompanionManager != null:
				OrbCompanionManager.notify_idle(_idle_timer)
		var blend_rate := IDLE_ZOOM_BLEND_IN_RATE if _is_idle_zoomed else IDLE_ZOOM_BLEND_OUT_RATE
		_idle_zoom_blend = move_toward(_idle_zoom_blend, 1.0 if _is_idle_zoomed else 0.0, blend_rate * delta)
		var zoom_mult := lerpf(1.0, IDLE_ZOOM_FACTOR, _idle_zoom_blend)
		cam_h *= zoom_mult
		cam_b *= zoom_mult

	var target: Vector3 = _player.position + Vector3(0.0, cam_h, cam_b)
	var cam_lerp_factor := clampf(delta * 8.0, 0.0, 1.0)
	_cam.position = _cam.position.lerp(target, cam_lerp_factor)
	var look_goal := _player.position + look_offset
	if _cam_look_target == Vector3.ZERO:
		_cam_look_target = look_goal
	else:
		_cam_look_target = _cam_look_target.lerp(look_goal, cam_lerp_factor)
	_cam.look_at(_cam_look_target, Vector3.UP)

	if is_traveling:
		_walk_time += delta
	_player_mesh.position.y = GROUND_TOP
	_player_mesh.rotation.z = 0.0
	_animate_walk_cycle(delta)

	# Animación de la aurora del territorio de la Base (perímetro cuadrado, no invasivo).
	if _base_aura_ring != null and is_instance_valid(_base_aura_ring):
		var time := Time.get_ticks_msec() / 1000.0
		var pulse := 0.98 + sin(time * 3.0) * 0.02
		_base_aura_ring.scale = Vector3(pulse, 1.0, pulse)
		if _base_aura_mat != null:
			_base_aura_mat.albedo_color.a = 0.30 + sin(time * 3.0) * 0.08

	# Ciclo día/noche: interpola la iluminación según la hora del mundo (TimeManager).
	_apply_daynight_lighting(false)

	# Daño ambiental por terreno (p. ej. lava): tick data-driven mientras se pisa.
	_apply_terrain_hazard(delta)

	# El césped reacciona al jugador en su shader: basta con pasarle su posición una
	# vez por frame (una sola escritura de uniform para TODO el césped del mapa).
	if _grass_mat is ShaderMaterial:
		(_grass_mat as ShaderMaterial).set_shader_parameter("player_pos", _player.position)

	# Vacía progresivamente la cola de niebla pendiente (presupuesto fijo/frame):
	# el movimiento nunca espera a que termine de refrescarse el entorno visual.
	WorldFogRenderer.process_fog_queue(self)

	_animate_nearby(delta)

	# Enemigos del mapamundi: deambular lento + contacto.
	WorldEnemies.process_enemies(self, delta)


## Distancia Chebyshev (nº de casillas) entre dos coordenadas.
func _cheby(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Balancea piernas y brazos en OPOSICIÓN (pierna izq. adelante + brazo der.
## adelante, como una marcha real) mientras el jugador se mueve; en reposo relaja
## los pivotes suavemente a la pose neutra. Solo rota 4 pivotes vacíos (Node3D):
## coste insignificante, la malla real de cada pierna/brazo ya está fusionada.
const WALK_SWING_LEG: float = 0.55   # rad, amplitud del balanceo de piernas
const WALK_SWING_ARM: float = 0.42   # rad, amplitud del balanceo de brazos
const WALK_SWING_FREQ: float = 10.0   # velocidad del ciclo acompasada a MOVE_SPEED 2.6 m/s
func _animate_walk_cycle(delta: float) -> void:
	# 1. Si tenemos animaciones estáticas/dinámicas del estudio cargadas (ej. Walking_A / Idle_A / Throw)
	if is_instance_valid(_player_anim_player) and _player_anim_player.has_animation("Walking_A"):
		if is_traveling:
			var anim_name := "Walking_A"
			if _player_anim_player.current_animation != anim_name:
				_player_anim_player.play(anim_name, 0.15)
			_chop_time = -1.0
		elif _player_anim_player.is_playing() and _player_anim_player.current_animation == "Throw":
			# Dejar que la animación de farmeo "Throw" termine su ejecución
			pass
		else:
			if _player_anim_player.current_animation != "Idle_A" and _player_anim_player.current_animation != "Idle_B":
				_player_anim_player.play("Idle_A", 0.2)
		return

	# 2. Quaternions de descanso para bajar los brazos de la postura en T (horizontal) a los costados del torso (~72°)
	var base_arm_l := Quaternion(Vector3(0, 0, 1), deg_to_rad(72.0))
	var base_arm_r := Quaternion(Vector3(0, 0, 1), deg_to_rad(-72.0))

	# Si el modelo 3D usa Skeleton3D sin AnimationPlayer, animamos las poses de los huesos
	if is_instance_valid(_player_skel) and _bone_leg_l >= 0 and _bone_leg_r >= 0:
		if is_traveling:
			var swing: float = sin(_walk_time * WALK_SWING_FREQ)
			var swing_leg_l := Quaternion(Vector3(1, 0, 0), swing * WALK_SWING_LEG)
			var swing_leg_r := Quaternion(Vector3(1, 0, 0), -swing * WALK_SWING_LEG)
			var swing_arm_l := Quaternion(Vector3(1, 0, 0), -swing * WALK_SWING_ARM) * base_arm_l
			var swing_arm_r := Quaternion(Vector3(1, 0, 0), swing * WALK_SWING_ARM) * base_arm_r

			_player_skel.set_bone_pose_rotation(_bone_leg_l, swing_leg_l)
			_player_skel.set_bone_pose_rotation(_bone_leg_r, swing_leg_r)
			if _bone_arm_l >= 0:
				_player_skel.set_bone_pose_rotation(_bone_arm_l, swing_arm_l)
			if _bone_arm_r >= 0:
				_player_skel.set_bone_pose_rotation(_bone_arm_r, swing_arm_r)
			_chop_time = -1.0
		else:
			_player_skel.set_bone_pose_rotation(_bone_leg_l, Quaternion.IDENTITY)
			_player_skel.set_bone_pose_rotation(_bone_leg_r, Quaternion.IDENTITY)
			if _bone_arm_l >= 0:
				_player_skel.set_bone_pose_rotation(_bone_arm_l, base_arm_l)
			if _bone_arm_r >= 0:
				_player_skel.set_bone_pose_rotation(_bone_arm_r, base_arm_r)
		return

	# Fallback a extremidades Node3D procedimentales
	if not is_instance_valid(_player_leg_l):
		return
	if is_traveling:
		var swing: float = sin(_walk_time * WALK_SWING_FREQ)
		_player_leg_l.rotation.x = swing * WALK_SWING_LEG
		_player_leg_r.rotation.x = -swing * WALK_SWING_LEG
		_player_arm_l.rotation.x = -swing * WALK_SWING_ARM
		_player_arm_r.rotation.x = swing * WALK_SWING_ARM
		_chop_time = -1.0
	elif _chop_time >= 0.0:
		_chop_time += delta
		const CHOP_DUR: float = 0.45
		var p: float = _chop_time / CHOP_DUR
		if p >= 1.0:
			_chop_time = -1.0
			_player_arm_l.rotation.x = 0.0
			_player_arm_r.rotation.x = 0.0
			_player_mesh.rotation.x = 0.0
		else:
			var ang: float
			if p < 0.35:
				ang = lerp(0.0, -1.6, p / 0.35)
			else:
				ang = lerp(-1.6, 1.1, (p - 0.35) / 0.65)
			_player_arm_l.rotation.x = ang
			_player_arm_r.rotation.x = ang
			_player_mesh.rotation.x = clampf(ang, 0.0, 1.1) * 0.18
			_player_leg_l.rotation.x = 0.0
			_player_leg_r.rotation.x = 0.0
	else:
		var t: float = clampf(delta * 8.0, 0.0, 1.0)
		_player_leg_l.rotation.x = lerp_angle(_player_leg_l.rotation.x, 0.0, t)
		_player_leg_r.rotation.x = lerp_angle(_player_leg_r.rotation.x, 0.0, t)
		_player_arm_l.rotation.x = lerp_angle(_player_arm_l.rotation.x, 0.0, t)
		_player_arm_r.rotation.x = lerp_angle(_player_arm_r.rotation.x, 0.0, t)
		_player_mesh.rotation.x = lerp_angle(_player_mesh.rotation.x, 0.0, t)


## Anima SOLO las casillas cercanas con animación POR NODO (árboles y el resaltado
## del item interactivo). El agua y el césped ya NO se animan aquí: lo hace su shader
## con TIME (coste GPU cero-CPU). Itera _nearby_anim (subconjunto acotado) usando las
## flags/refs precalculadas en cada entry — sin consultar hexagons_db por frame.
func _animate_nearby(delta: float) -> void:
	var time_sec := Time.get_ticks_msec() / 1000.0

	# Cada pocos segundos, refresca la visibilidad de los nodos de recolección
	# cercanos: así un árbol/banco de pesca agotado reaparece solo en cuanto se
	# regenera, sin necesidad de que el jugador cambie de casilla.
	_gather_regen_check_accum += delta
	if _gather_regen_check_accum >= 2.0:
		_gather_regen_check_accum = 0.0
		for coord in _nearby_anim:
			var gcell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
			if gcell != null and gcell.is_gather_node():
				WorldFogRenderer.apply_cell_visual(self, coord)

	for coord in _nearby_anim:
		var e: Dictionary = _cells.get(coord, {})
		if e.is_empty():
			continue

		# 1. Balanceo de árboles con el viento (pocos nodos cercanos).
		if e["is_trees"]:
			var container: Node3D = e["obj"] as Node3D
			if container and is_instance_valid(container):
				var idx := 0
				for tree in container.get_children():
					if tree is Node3D:
						var offset: float = idx * 1.5 + (coord.x * 3.0 + coord.y * 7.0)
						tree.rotation.x = sin(time_sec * 2.2 + offset) * 0.035
						tree.rotation.z = cos(time_sec * 2.09 + offset) * 0.035
						idx += 1

		# 2. Resaltado/pulsación del item interactivo bajo el jugador.
		if e["is_interactive"]:
			var obj: Node3D = e["obj"] as Node3D
			if obj and is_instance_valid(obj):
				var target_scale: float = 1.0
				if coord == _current_cell:
					target_scale = 1.15 + sin(time_sec * 5.0) * 0.03
				var current_scale: float = obj.get_meta("current_scale", 1.0)
				current_scale = lerp(current_scale, target_scale, clampf(delta * 10.0, 0.0, 1.0))
				obj.set_meta("current_scale", current_scale)
				obj.scale = Vector3.ONE * current_scale

		# 3. Movimiento orgánico en 360º de animales (vacas y cerdos).
		if e.get("is_animal", false):
			var marker: Node3D = e.get("obj", null) as Node3D
			if marker and is_instance_valid(marker) and marker.visible:
				var animal_node: Node3D = marker.get_node_or_null("Animal") as Node3D
				if animal_node == null and marker.get_child_count() > 0:
					animal_node = marker.get_child(0) as Node3D
				if animal_node and is_instance_valid(animal_node):
					_animate_wandering_animal(animal_node, coord, delta, time_sec)

	# Partículas de agua al caminar por orilla/pesca.
	var e_cur: Dictionary = _cells.get(_current_cell, {})
	var on_shallow: bool = (not e_cur.is_empty()) and e_cur["is_shore"]
	var particles: CPUParticles3D = _player.get_node_or_null("WaterParticles") as CPUParticles3D
	if particles:
		particles.emitting = is_traveling and on_shallow

	# Task 4 FASE 2.3: partículas de terreno (hierba/arena/nieve) bajo los pies.
	_update_terrain_step_particles(is_traveling and not on_shallow)


## Anima un animal (vaca o cerdo) de forma orgánica: deambula muy suavemente en 360º
## alrededor de su casilla, girando despacio hacia donde camina y haciendo pausas para pastar.
func _animate_wandering_animal(animal_node: Node3D, coord: Vector2i, delta: float, time_sec: float) -> void:
	var state_timer: float = float(animal_node.get_meta("wander_timer", -1.0))
	var is_moving: bool = bool(animal_node.get_meta("wander_moving", false))
	var current_offset: Vector3 = animal_node.get_meta("wander_cur_pos", animal_node.position)
	var target_offset: Vector3 = animal_node.get_meta("wander_target_pos", Vector3.ZERO)
	var current_yaw: float = float(animal_node.get_meta("wander_cur_yaw", animal_node.rotation.y))
	var target_yaw: float = float(animal_node.get_meta("wander_target_yaw", animal_node.rotation.y))
	var step_phase: float = float(animal_node.get_meta("wander_step_phase", 0.0))

	# Inicialización determinista por casilla
	if state_timer < 0.0:
		var seed_val: int = (coord.x * 374761393) ^ (coord.y * 668265263)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		state_timer = rng.randf_range(1.0, 4.0)
		current_yaw = rng.randf_range(0.0, TAU)
		target_yaw = current_yaw
		animal_node.set_meta("wander_timer", state_timer)
		animal_node.set_meta("wander_moving", false)
		animal_node.set_meta("wander_cur_pos", Vector3.ZERO)
		animal_node.set_meta("wander_target_pos", Vector3.ZERO)
		animal_node.set_meta("wander_cur_yaw", current_yaw)
		animal_node.set_meta("wander_target_yaw", target_yaw)
		animal_node.set_meta("wander_step_phase", 0.0)
		animal_node.rotation.y = current_yaw
		return

	state_timer -= delta

	if state_timer <= 0.0:
		if is_moving:
			is_moving = false
			state_timer = randf_range(3.5, 7.0)
			animal_node.set_meta("wander_moving", false)
			animal_node.set_meta("wander_timer", state_timer)
		else:
			var angle := randf_range(0.0, TAU)
			var dist := randf_range(0.06, 0.22)
			target_offset = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
			var to_tgt := target_offset - current_offset
			if to_tgt.length() > 0.02:
				target_yaw = atan2(to_tgt.x, to_tgt.z)
				is_moving = true
				state_timer = randf_range(2.8, 5.0)
			else:
				state_timer = randf_range(2.0, 4.0)
			animal_node.set_meta("wander_target_pos", target_offset)
			animal_node.set_meta("wander_target_yaw", target_yaw)
			animal_node.set_meta("wander_moving", is_moving)
			animal_node.set_meta("wander_timer", state_timer)

	current_yaw = lerp_angle(current_yaw, target_yaw, clampf(delta * 2.2, 0.0, 1.0))
	animal_node.set_meta("wander_cur_yaw", current_yaw)

	if is_moving:
		var speed: float = 0.045
		current_offset = current_offset.move_toward(target_offset, speed * delta)
		animal_node.set_meta("wander_cur_pos", current_offset)

		step_phase += delta * 4.5
		animal_node.set_meta("wander_step_phase", step_phase)
		var bob: float = absf(sin(step_phase)) * 0.012

		animal_node.position = Vector3(current_offset.x, bob, current_offset.z)
		animal_node.rotation.y = current_yaw

		if current_offset.distance_to(target_offset) < 0.008:
			is_moving = false
			state_timer = randf_range(3.5, 7.0)
			animal_node.set_meta("wander_moving", false)
			animal_node.set_meta("wander_timer", state_timer)
			animal_node.position = current_offset
	else:
		var idle_sway := sin(time_sec * 1.6 + coord.x * 2.1 + coord.y * 3.7) * 0.025
		animal_node.rotation.y = current_yaw + idle_sway
		animal_node.position = current_offset


## Activa/reconfigura las partículas de paso según el terreno actual. Sin
## partículas fuera de movimiento o sobre terrenos sin entrada en
## `TERRAIN_STEP_PARTICLE_KIND` (piedra, camino, montaña...).
func _update_terrain_step_particles(active: bool) -> void:
	if _terrain_particles == null or not is_instance_valid(_terrain_particles):
		return
	if not active or Locale.reduce_motion:
		_terrain_particles.emitting = false
		return
	var cur_cell: CellResource = GlobalState.hexagons_db.get(_current_cell, null) as CellResource
	var kind: String = TERRAIN_STEP_PARTICLE_KIND.get(cur_cell.terrain, "") if cur_cell != null else ""
	if kind == "":
		_terrain_particles.emitting = false
		return
	if kind != _terrain_particles_kind:
		_configure_terrain_step_particles(kind)
	_terrain_particles.emitting = true


## Reconfigura color/velocidad/gravedad del emisor único de partículas de
## paso para el bioma `kind` ("grass"/"sand"/"snow"). Se llama solo al cambiar
## de terreno, no en cada frame.
func _configure_terrain_step_particles(kind: String) -> void:
	_terrain_particles_kind = kind
	var mat := _terrain_particles.material_override as StandardMaterial3D
	match kind:
		"grass":
			_terrain_particles.amount = 10
			_terrain_particles.lifetime = 0.5
			_terrain_particles.initial_velocity_min = 0.3
			_terrain_particles.initial_velocity_max = 0.8
			_terrain_particles.gravity = Vector3(0.0, -2.5, 0.0)
			_terrain_particles.scale_amount_min = 0.03
			_terrain_particles.scale_amount_max = 0.06
			if mat:
				mat.albedo_color = Color(0.45, 0.75, 0.25, 0.9)
		"sand":
			_terrain_particles.amount = 14
			_terrain_particles.lifetime = 0.55
			_terrain_particles.initial_velocity_min = 0.15
			_terrain_particles.initial_velocity_max = 0.45
			_terrain_particles.gravity = Vector3(0.0, -0.6, 0.0)
			_terrain_particles.scale_amount_min = 0.025
			_terrain_particles.scale_amount_max = 0.05
			if mat:
				mat.albedo_color = Color(0.82, 0.72, 0.48, 0.55)
		"snow":
			_terrain_particles.amount = 12
			_terrain_particles.lifetime = 0.6
			_terrain_particles.initial_velocity_min = 0.2
			_terrain_particles.initial_velocity_max = 0.5
			_terrain_particles.gravity = Vector3(0.0, -0.4, 0.0)
			_terrain_particles.scale_amount_min = 0.025
			_terrain_particles.scale_amount_max = 0.05
			if mat:
				mat.albedo_color = Color(0.95, 0.97, 1.0, 0.85)


#endregion

#region CONSTRUCCIÓN DE LA ESCENA 3D (SubViewport + cámara + luz + jugador)
func _build_viewport_and_scene() -> void:
	_vp_container = SubViewportContainer.new()
	_vp_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp_container.stretch = true
	# El contenedor NO captura el toque: lo gestionamos vía _unhandled_input (raycast).
	_vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vp_container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(1920, 1080)
	_sub_viewport.own_world_3d = true
	_sub_viewport.transparent_bg = false
	# Arranca en UPDATE_DISABLED para evitar renders con tamaño 0×0 al inicio.
	# _on_visibility_changed lo activa a UPDATE_ALWAYS cuando el nodo se muestra.
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# MSAA desactivado: muy caro en móvil y aporta poco en esta vista cenital.
	_sub_viewport.msaa_3d = Viewport.MSAA_DISABLED
	# Sin efectos de post-proceso costosos en móvil.
	_sub_viewport.use_debanding = false
	_vp_container.add_child(_sub_viewport)

	var world_root := Node3D.new()
	_sub_viewport.add_child(world_root)

	# ── Cámara cenital inclinada ──
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.current = true
	var env: Environment = null
	if ResourceLoader.exists("res://resources/world_environment_mobile.tres"):
		env = load("res://resources/world_environment_mobile.tres").duplicate()
	elif ResourceLoader.exists("res://world_environment_mobile.tres"):
		env = load("res://world_environment_mobile.tres").duplicate()
	else:
		env = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.04, 0.05, 0.09)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.64, 0.74)
		env.ambient_light_energy = 0.42
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 1.0
		env.tonemap_white = 1.0
		env.glow_enabled = true
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		env.glow_hdr_threshold = 1.4
		env.glow_bicubic_upscale = false
		env.set_glow_level(1, false)
		env.set_glow_level(2, false)
		env.set_glow_level(3, true)
		env.set_glow_level(4, false)
		env.set_glow_level(5, false)
		env.set_glow_level(6, false)
		env.set_glow_level(7, false)
		env.glow_intensity = 0.35
		env.fog_enabled = true
		env.fog_light_color = Color(0.05, 0.06, 0.10)
		env.fog_density = 0.012
	# Blindaje: asegurar umbral HDR y modo softlight para evitar destello cegador con sol alto
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_intensity = 0.35
	_cam.environment = env
	_env = env
	world_root.add_child(_cam)

	# ── Luz direccional (sol) con sombras suaves para dar volumen ──
	# Ajustes pensados para móvil: 1 sola cascada (ORTHOGONAL) y distancia de sombra
	# corta, de modo que solo proyectan sombra los objetos cercanos al jugador. Así
	# el pase de sombras deja de recorrer todo el mapa (era un gran coste en móvil).
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -38.0, 0.0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 22.0
	sun.directional_shadow_blend_splits = false
	world_root.add_child(sun)
	_sun = sun
	# Aplica la iluminación correspondiente a la hora actual (día/noche) al construir.
	_apply_daynight_lighting(true)

	# ── Raíces de casillas y jugador ──
	_tiles_root = Node3D.new()
	world_root.add_child(_tiles_root)

	_setup_destination_marker(world_root)

	_player = Node3D.new()
	world_root.add_child(_player)
	_player_mesh = Node3D.new()
	_player_mesh.position = Vector3(0.0, GROUND_TOP, 0.0)
	_player.add_child(_player_mesh)

	# BARCO: silueta que sustituye al personaje mientras se navega (oculta por
	# defecto) + marcador del barco aparcado, visible en su casilla del mapa
	# cuando NO se está navegando (ver `_refresh_boat_marker`/`_set_boat_visual`).
	_boat_rider_visual = _build_boat_visual()
	_boat_rider_visual.position = Vector3(0.0, GROUND_TOP, 0.0)
	_boat_rider_visual.visible = false
	_player.add_child(_boat_rider_visual)
	_boat_parked_marker = _build_boat_visual()
	_boat_parked_marker.visible = false
	world_root.add_child(_boat_parked_marker)
	_refresh_boat_marker()
	
	# Partículas de agua para cuando camina por las orillas o pesca
	var water_particles := CPUParticles3D.new()
	water_particles.name = "WaterParticles"
	water_particles.emitting = false
	water_particles.amount = 16
	water_particles.lifetime = 0.4
	water_particles.one_shot = false
	water_particles.explosiveness = 0.1
	water_particles.direction = Vector3(0.0, 1.0, 0.0)
	water_particles.spread = 180.0
	water_particles.gravity = Vector3(0.0, -4.0, 0.0)
	water_particles.initial_velocity_min = 0.6
	water_particles.initial_velocity_max = 1.4
	
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.035
	p_mesh.height = 0.07
	water_particles.mesh = p_mesh
	
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.40, 0.85, 1.0)
	p_mat.roughness = 0.2
	p_mat.emission_enabled = true
	p_mat.emission = Color(0.18, 0.52, 0.78)
	p_mat.emission_energy_multiplier = 0.95
	water_particles.material_override = p_mat
	water_particles.position = Vector3(0.0, 0.02, 0.0)
	_player.add_child(water_particles)

	# Partículas de veneno / radiación verde activa en el jugador
	_poison_particles = CPUParticles3D.new()
	_poison_particles.name = "PoisonParticles"
	_poison_particles.emitting = false
	_poison_particles.amount = 18
	_poison_particles.lifetime = 0.7
	_poison_particles.one_shot = false
	_poison_particles.explosiveness = 0.05
	_poison_particles.direction = Vector3(0.0, 1.0, 0.0)
	_poison_particles.spread = 50.0
	_poison_particles.gravity = Vector3(0.0, 1.5, 0.0)
	_poison_particles.initial_velocity_min = 0.5
	_poison_particles.initial_velocity_max = 1.1
	
	var tox_mesh := SphereMesh.new()
	tox_mesh.radius = 0.035
	tox_mesh.height = 0.07
	_poison_particles.mesh = tox_mesh
	
	var tox_mat := StandardMaterial3D.new()
	tox_mat.albedo_color = Color(0.25, 1.0, 0.25, 0.85)
	tox_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tox_mat.roughness = 0.2
	tox_mat.emission_enabled = true
	tox_mat.emission = Color(0.15, 0.95, 0.15)
	tox_mat.emission_energy_multiplier = 1.8
	_poison_particles.material_override = tox_mat
	_poison_particles.position = Vector3(0.0, 0.05, 0.0)
	_player.add_child(_poison_particles)

	# Task 4 FASE 2.3: partículas de terreno bajo los pies. Un único emisor
	# (reconfigurado por `_configure_terrain_step_particles` según el bioma
	# pisado) en vez de un nodo por terreno — mismo patrón "coste mínimo" que
	# las luciérnagas/motas de polvo de abajo.
	_terrain_particles = CPUParticles3D.new()
	_terrain_particles.name = "TerrainStepParticles"
	_terrain_particles.emitting = false
	_terrain_particles.one_shot = false
	_terrain_particles.explosiveness = 0.15
	_terrain_particles.direction = Vector3(0.0, 1.0, 0.0)
	_terrain_particles.spread = 60.0
	var terrain_mesh := SphereMesh.new()
	terrain_mesh.radius = 0.03
	terrain_mesh.height = 0.06
	_terrain_particles.mesh = terrain_mesh
	var terrain_mat := StandardMaterial3D.new()
	terrain_mat.roughness = 0.9
	terrain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_terrain_particles.material_override = terrain_mat
	_terrain_particles.position = Vector3(0.0, 0.03, 0.0)
	_player.add_child(_terrain_particles)

	# (Pulido del mapamundi): luciérnagas ambientales, muy sutiles,
	# que solo aparecen de noche alrededor del jugador — el mundo se siente
	# habitado sin añadir ninguna mecánica nueva. Coste mínimo (una sola
	# CPUParticles3D que se activa/desactiva según la hora).
	_fireflies = CPUParticles3D.new()
	_fireflies.name = "Fireflies"
	_fireflies.emitting = false
	_fireflies.amount = 14
	_fireflies.lifetime = 3.0
	_fireflies.preprocess = 1.5
	_fireflies.one_shot = false
	_fireflies.explosiveness = 0.0
	_fireflies.randomness = 0.6
	_fireflies.direction = Vector3.UP
	_fireflies.spread = 180.0
	_fireflies.gravity = Vector3.ZERO
	_fireflies.initial_velocity_min = 0.05
	_fireflies.initial_velocity_max = 0.18
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fireflies.emission_sphere_radius = 2.2
	_fireflies.scale_amount_min = 0.03
	_fireflies.scale_amount_max = 0.07
	var ff_mesh := SphereMesh.new()
	ff_mesh.radius = 0.03
	ff_mesh.height = 0.06
	_fireflies.mesh = ff_mesh
	var ff_mat := StandardMaterial3D.new()
	ff_mat.albedo_color = Color(1.0, 0.92, 0.55)
	ff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ff_mat.emission_enabled = true
	ff_mat.emission = Color(1.0, 0.85, 0.4)
	ff_mat.emission_energy_multiplier = 1.6
	ff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fireflies.material_override = ff_mat
	_fireflies.position = Vector3(0.0, 1.0, 0.0)
	_player.add_child(_fireflies)

	# Motas de polvo/luz doradas, dispersas y muy sutiles, visibles solo con el
	# sol alto (ideas.md #3) — mismo patrón que las luciérnagas nocturnas, pero
	# para el día: una única CPUParticles3D barata alrededor del jugador.
	_sun_dust = CPUParticles3D.new()
	_sun_dust.name = "SunDust"
	_sun_dust.emitting = false
	_sun_dust.amount = 10
	_sun_dust.lifetime = 4.5
	_sun_dust.preprocess = 2.0
	_sun_dust.one_shot = false
	_sun_dust.explosiveness = 0.0
	_sun_dust.randomness = 0.7
	_sun_dust.direction = Vector3.UP
	_sun_dust.spread = 180.0
	_sun_dust.gravity = Vector3(0.0, 0.03, 0.0)
	_sun_dust.initial_velocity_min = 0.03
	_sun_dust.initial_velocity_max = 0.10
	_sun_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sun_dust.emission_sphere_radius = 3.0
	_sun_dust.scale_amount_min = 0.02
	_sun_dust.scale_amount_max = 0.045
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.025
	dust_mesh.height = 0.05
	_sun_dust.mesh = dust_mesh
	var dust_mat := StandardMaterial3D.new()
	dust_mat.albedo_color = Color(1.0, 0.95, 0.75, 0.55)
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.emission_enabled = true
	dust_mat.emission = Color(1.0, 0.9, 0.6)
	dust_mat.emission_energy_multiplier = 0.8
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sun_dust.material_override = dust_mat
	_sun_dust.position = Vector3(0.0, 1.3, 0.0)
	_player.add_child(_sun_dust)

	_build_player_character()


## Intenta instanciar el modelo 3D del personaje (.glb) desde los assets del mundo.
## Devuelve true si el modelo existe y se cargó correctamente.
func _build_player_character() -> bool:
	var glb_path := "res://assets/common/models/characters/Rogue_Hooded.glb"
	if not ResourceLoader.exists(glb_path):
		return false
	var packed = load(glb_path)
	if not (packed is PackedScene):
		return false
	var model_inst := (packed as PackedScene).instantiate() as Node3D
	if model_inst == null:
		return false

	# Escalado del modelo GLB para encajar en la casilla del mapamundi y vista cenital
	model_inst.scale = Vector3(0.40, 0.40, 0.40)
	# Orientación correcta (0° para mirar en la dirección del movimiento)
	model_inst.rotation_degrees.y = 0.0

	var player_tex: Texture2D = load("res://assets/common/models/characters/Rogue_Hooded_rogue_texture.png")
	if player_tex != null:
		var p_mat := StandardMaterial3D.new()
		p_mat.albedo_texture = player_tex
		p_mat.roughness = 0.85
		_player_material = p_mat
		_refresh_player_profession_tint()
		for child in model_inst.find_children("", "MeshInstance3D", true, false):
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = p_mat

	_player_mesh.add_child(model_inst)

	# Buscar Skeleton3D para animar las poses de los huesos en _animate_walk_cycle
	_player_skel = _find_skeleton(model_inst)
	if _player_skel != null:
		_bone_leg_l = _player_skel.find_bone("upperleg.l")
		_bone_leg_r = _player_skel.find_bone("upperleg.r")
		_bone_arm_l = _player_skel.find_bone("upperarm.l")
		_bone_arm_r = _player_skel.find_bone("upperarm.r")

	# Fallback a extremidades Node3D
	_player_leg_l = model_inst.find_child("upperleg.l", true, false)
	_player_leg_r = model_inst.find_child("upperleg.r", true, false)
	_player_arm_l = model_inst.find_child("upperarm.l", true, false)
	_player_arm_r = model_inst.find_child("upperarm.r", true, false)

	# Crear un AnimationPlayer para controlar las animaciones de estudio (Walking, Idle, etc.)
	_player_anim_player = AnimationPlayer.new()
	_player_anim_player.name = "PlayerAnimPlayer"
	model_inst.add_child(_player_anim_player)

	# Importar librerías de animación externas compartidas (Rig_Medium_General y Rig_Medium_MovementBasic)
	_import_animation_library("res://assets/common/models/characters/animation/Rig_Medium_General.glb")
	_import_animation_library("res://assets/common/models/characters/animation/Rig_Medium_MovementBasic.glb")

	_enable_model_shadows(model_inst)
	return true


func _import_animation_library(glb_path: String) -> void:
	if not is_instance_valid(_player_anim_player):
		return
	if not ResourceLoader.exists(glb_path):
		return
	var packed = load(glb_path)
	if not (packed is PackedScene):
		return
	var temp_inst := (packed as PackedScene).instantiate()
	if temp_inst == null:
		return

	var source_ap := _find_animation_player(temp_inst)
	if source_ap != null:
		var target_lib: AnimationLibrary
		if _player_anim_player.has_animation_library(""):
			target_lib = _player_anim_player.get_animation_library("")
		else:
			target_lib = AnimationLibrary.new()
			_player_anim_player.add_animation_library("", target_lib)

		var lib_names := source_ap.get_animation_library_list()
		for lib_name in lib_names:
			var lib := source_ap.get_animation_library(lib_name)
			if lib == null:
				continue
			for anim_name in lib.get_animation_list():
				var anim := lib.get_animation(anim_name)
				if anim != null and not target_lib.has_animation(anim_name):
					var cloned := anim.duplicate() as Animation
					if anim_name.begins_with("Walking") or anim_name.begins_with("Running") or anim_name.begins_with("Idle"):
						cloned.loop_mode = Animation.LOOP_LINEAR
					target_lib.add_animation(anim_name, cloned)

	temp_inst.queue_free()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var res := _find_animation_player(child)
		if res != null:
			return res
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var res := _find_skeleton(child)
		if res != null:
			return res
	return null


func _enable_model_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child in node.get_children():
		_enable_model_shadows(child)



## Obtiene la textura correspondiente a la profesión activa del héroe.
## Cambia exclusivamente el color de la ropa (capucha, túnica, máscara, capa)
## manteniendo intactos los tonos originales de piel, ojos, pelo y botas de cuero.
func _get_player_profession_texture(prof: String) -> Texture2D:
	var prof_clean := prof.to_lower().strip_edges()
	var filename := "Rogue_Hooded_texture_arquero.png"
	match prof_clean:
		"arquero", "archer":
			filename = "Rogue_Hooded_texture_arquero.png"
		"guerrero", "warrior":
			filename = "Rogue_Hooded_texture_guerrero.png"
		"psíquico", "psiquico", "psychic":
			filename = "Rogue_Hooded_texture_psiquico.png"
		"sacerdote", "priest", "healer":
			filename = "Rogue_Hooded_texture_sacerdote.png"
		"tiempo", "time", "chrono":
			filename = "Rogue_Hooded_texture_tiempo.png"
		"mago", "mage", "wizard":
			filename = "Rogue_Hooded_texture_mago.png"
		"elementalista", "elemental":
			filename = "Rogue_Hooded_texture_elementalista.png"
		"don nadie", "donnadie", "nobody":
			filename = "Rogue_Hooded_texture_donnadie.png"
		_:
			filename = "Rogue_Hooded_texture_arquero.png"

	var path := "res://assets/common/models/characters/" + filename
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex as Texture2D
	return load("res://assets/common/models/characters/Rogue_Hooded_rogue_texture.png") as Texture2D


## Color identitario del héroe según su profesión activa (mismo campo `color`
## de `data/professions.json` que usa `TabCharacter._profession_color`).
func _profession_color() -> Color:
	var def = Design.get_profession(GlobalState.profession)
	if not def.is_empty():
		return Color.from_string(def.get("color", "41a3ff"), Color(0.30, 0.64, 1.0))
	return Color(0.30, 0.64, 1.0)


## Actualiza la textura del traje del héroe en el mapamundi según la profesión
## activa: Verde=Arquero, Rojo=Guerrero, Morado=Psíquico, Blanco=Sacerdote,
## Amarillo=Tiempo, Azul=Mago, Celeste=Elementalista, Gris=Don Nadie.
func _refresh_player_profession_tint() -> void:
	if _player_material == null:
		return
	if _last_tinted_profession == GlobalState.profession:
		return
	_last_tinted_profession = GlobalState.profession
	_player_material.albedo_color = Color.WHITE
	_player_material.albedo_texture = _get_player_profession_texture(GlobalState.profession)


func _on_global_state_updated() -> void:
	_refresh_player_profession_tint()
	_recompute_gates()
	# El marcador del barco se actualiza siempre (incluso con el mundo oculto por
	# un diálogo) para que esté posicionado correctamente cuando la vista reaparezca.
	_refresh_boat_marker()
	if is_visible_in_tree():
		if GlobalState.has_built_base and GlobalState.base_coord != Vector2i(-1, -1):
			var b_coord: Vector2i = GlobalState.base_coord
			var b_cell: CellResource = GlobalState.hexagons_db.get(b_coord, null) as CellResource
			if b_cell != null and _cells.has(b_coord):
				_rebuild_marker(b_coord, b_cell)


## Crea un StandardMaterial3D sólido (color + rugosidad + metalicidad).
func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


#endregion

#region CONSTRUCCIÓN DE CASILLAS 3D
## Configuración global de UNA SOLA VEZ (océano + shaders compartidos). El
## contenido en sí (suelo/césped/marcadores) ya NO se construye aquí — ver
## `_finalize_chunk_from_classified()`, orquestado por `_streamer`
## (streaming de chunks 3×3 por proximidad).
func _build_tiles() -> void:
	# Un gran plano de océano cubre el fondo lejano (el resto del lienzo 100×100).
	_build_ocean_plane()
	# Recursos de render compartidos (shaders + mallas base). Se crean una sola vez.
	_create_render_resources()


## Reconstruye TODO el mapa visual desde hexagons_db. Reutilizable tras cualquier
## modificación física del mundo (herramientas, campamento, transformaciones): así
## los cambios de terreno/marcadores se reflejan al instante sin salir de la vista.
## El jugador/cámara/sol cuelgan de world_root (no de _tiles_root), así que vaciar
## _tiles_root es seguro. Recrea también el aura de la base.
## Ya NO reconstruye TODO el mapa, solo los
## chunks actualmente activos (streaming), vía `_streamer.rebuild_active_chunks`.
func _rebuild_tiles() -> void:
	if _tiles_root == null:
		return
	# Solo se liberan aquí los hijos GLOBALES de _tiles_root (océano, auroras de
	# puertas...). Los chunks (suelo/césped/marcadores) los descarga/reconstruye
	# _streamer.rebuild_active_chunks() más abajo, que es quien lleva la cuenta
	# real de _chunk_roots — si lo vaciáramos aquí antes de tiempo, el streamer
	# no sabría qué chunks tenía que reconstruir.
	var chunk_root_nodes: Dictionary = {}
	for n in _chunk_roots.values():
		chunk_root_nodes[n] = true
	for child in _tiles_root.get_children():
		if not chunk_root_nodes.has(child):
			child.queue_free()
	# Reiniciar cachés de render/animación que _build_tiles vuelve a poblar.
	_cells.clear()
	_building_template_cache.clear()
	_ground_mm.clear()
	_grass_mm.clear()
	_grass_mat = null
	_shared_mats.clear()
	_ground_mat_cache.clear()
	_ground_blend_mat = null
	_mountain_mesh_cache = null
	_resource_mesh_cache.clear()
	_grass_mesh_cache = null
	_anim_coords.clear()
	_nearby_anim.clear()
	_base_aura_ring = null
	_gate_coords.clear()
	_gate_coords_indexed = false
	_build_tiles()
	if _streamer != null:
		_streamer.rebuild_active_chunks(self)
	_flush_pending_marker_builds()
	WorldFogRenderer.restore_explored(self)
	WorldFogRenderer.update_fog_of_war(self, player_pos)
	WorldFogRenderer.apply_visibility(self)
	WorldFogRenderer.rebuild_nearby(self)
	_update_base_aura()
	WorldEnemies.refresh_enemies(self)            # los actores de enemigos se destruyeron al vaciar _tiles_root
	CampTentSystem.refresh_campfire_ghost(self)   # previsualización translúcida de la hoguera construible
	# El césped y la iluminación se recrean con materiales nuevos: reaplicar la
	# modulación día/noche vigente para que arranquen con el color correcto.
	_last_daylight = -1.0
	_apply_daynight_lighting(true)


## Prefijo de claves de _ground_mm para un chunk dado ("<x>_<y>_"), para que
## grupos idénticos ("grass", "sand"...) de chunks distintos no colisionen en
## el mismo Dictionary global.
func _chunk_key_prefix(chunk_coord: Vector2i) -> String:
	return "%d_%d_" % [chunk_coord.x, chunk_coord.y]


## Construye en el HILO PRINCIPAL un chunk ya clasificado (lista de
## {coord, cell} previamente filtrada — síncronamente en `_build_one_sync` o
## en segundo plano vía `WorldMeshBaker.classify_chunk_cells`). Crea la raíz del
## chunk, registra cada casilla y hornea sus MultiMesh. Llamado por
## `WorldChunkStreamer` — ver `interactive/WorldChunkStreamer.gd`.
func _finalize_chunk_from_classified(chunk_coord: Vector2i, cells: Array) -> void:
	if _chunk_roots.has(chunk_coord) or _tiles_root == null:
		return
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	_tiles_root.add_child(chunk_root)
	_chunk_roots[chunk_coord] = chunk_root

	var ground_xforms: Dictionary = {}
	var grass_xforms: Array[Transform3D] = []
	var ground_blend_data: Array[Dictionary] = []
	var mountain_xforms: Array[Transform3D] = []
	var resource_xforms: Dictionary = {}
	for entry: Dictionary in cells:
		var coord: Vector2i = entry["coord"]
		var cell: CellResource = entry["cell"]
		if cell == null:
			continue
		_register_one_tile(coord, cell, ground_xforms, grass_xforms, ground_blend_data, mountain_xforms, resource_xforms, chunk_coord, chunk_root)

	var prefix := _chunk_key_prefix(chunk_coord)
	_finalize_ground(ground_xforms, prefix, chunk_root)
	_finalize_grass(chunk_coord, grass_xforms, chunk_root)
	_finalize_ground_blend(ground_blend_data, prefix, chunk_root)
	_finalize_mountain_decor(mountain_xforms, prefix, chunk_root)
	for r_key: String in resource_xforms:
		_finalize_resource_decor(r_key, resource_xforms[r_key], prefix, chunk_root)

	# Este chunk puede haberse construido DESPUÉS del arranque (streaming en
	# vivo): aplicar de inmediato la niebla/visibilidad vigente a sus casillas
	# nuevas, si no se verían con el estado "recién creado" (blanco/visible)
	# hasta el siguiente paso del jugador.
	if is_inside_tree():
		for entry: Dictionary in cells:
			var coord: Vector2i = entry["coord"]
			if _cells.has(coord):
				WorldFogRenderer.recompute_cell_fog(self, coord, _current_cell)
				WorldFogRenderer.apply_cell_visual(self, coord)
		WorldFogRenderer.rebuild_nearby(self)


## Descarga un chunk: libera su raíz de nodos (MultiMesh/marcadores/etiquetas)
## de un único golpe y limpia todas las estructuras globales que referenciaban
## sus casillas.
func _unload_chunk(chunk_coord: Vector2i) -> void:
	var root: Node3D = _chunk_roots.get(chunk_coord, null)
	if root != null and is_instance_valid(root):
		root.queue_free()
	_chunk_roots.erase(chunk_coord)
	_grass_mm.erase(chunk_coord)

	# Descartar marcadores aún pendientes de instanciar (§4) que pertenecían a
	# este chunk: su `parent` va a quedar inválido (queue_free de `root` arriba),
	# así que _process_pending_marker_builds los saltaría igualmente, pero
	# quitarlos ya libera turnos de presupuesto para chunks que sí interesan.
	if not _pending_marker_builds.is_empty():
		var kept: Array[Dictionary] = []
		for item: Dictionary in _pending_marker_builds:
			if WorldChunkStreamer.chunk_coord_of(item["coord"]) != chunk_coord:
				kept.append(item)
		_pending_marker_builds = kept

	var prefix := _chunk_key_prefix(chunk_coord)
	for key: String in _ground_mm.keys().duplicate():
		if key.begins_with(prefix):
			_ground_mm.erase(key)

	for coord: Vector2i in _cells.keys().duplicate():
		var e: Dictionary = _cells[coord]
		if e.get("chunk", Vector2i(999999, 999999)) == chunk_coord:
			_cells.erase(coord)
			_anim_coords.erase(coord)
			_nearby_anim.erase(coord)

	# BUG DE LAG ACUMULATIVO: los actores de enemigos del mapamundi
	# (WorldEnemies.spawn_enemy_actor) se crean como hijos DIRECTOS de
	# _tiles_root (no del chunk_root de su chunk), así que descargar un chunk
	# nunca los liberaba: cada enemigo alguna vez spawneado (con su estela de
	# partículas + luz + etiqueta, TODOS activos sin parar) se quedaba vivo
	# para siempre bajo _tiles_root, por lejos que el jugador se alejara. Con
	# minutos de exploración se acumulan decenas de ellos, cada uno gastando
	# CPU/GPU sin parar → el "poco a poco se va relentizando" reportado.
	# Los liberamos aquí igual que el resto de contenido del chunk; WorldEnemies
	# los re-crea solo si el jugador vuelve a acercarse (refresh_enemies).
	for spawn: Vector2i in _enemies.keys().duplicate():
		if WorldChunkStreamer.chunk_coord_of(spawn) != chunk_coord:
			continue
		var enemy_entry: Dictionary = _enemies[spawn]
		var enemy_node: Node3D = enemy_entry.get("node") as Node3D
		if enemy_node != null and is_instance_valid(enemy_node):
			enemy_node.queue_free()
		_enemies.erase(spawn)


## Clave del grupo de suelo (textura/material) de una casilla. Todas las casillas del
## mismo grupo se dibujan en UNA MultiMesh (una draw call).
func _ground_group(cell: CellResource) -> String:
	if cell.terrain == "sea":
		return "sea"
	if cell.terrain == "cst" or cell.resource == "fish":
		return "shore"
	if cell.terrain == "ice":
		return "snow"
	if cell.terrain == "icy":
		return "icy"
	if cell.terrain == "bad":
		return "bad"
	if cell.terrain == "gnd":
		return "gnd"
	if cell.terrain == "are":
		return "beach"
	if cell.terrain == "des":
		return "sand"
	if cell.terrain == "mnt":
		return "mountain"
	if cell.terrain == "grs":
		return "grass"
	if cell.terrain == "lav":
		return "lav"
	if cell.terrain == "pth":
		return "pth"
	if Design.get_terrain_def(cell.terrain).size() > 0:
		return cell.terrain
	return "grass"


## Crea los shaders y mallas base compartidos por las MultiMesh (una sola vez).
func _create_render_resources() -> void:
	_ground_shader = Shader.new()
	_ground_shader.code = GROUND_SHADER_CODE
	_grass_shader = Shader.new()
	_grass_shader.code = GRASS_SHADER_CODE
	_ground_blend_shader = Shader.new()
	_ground_blend_shader.code = GROUND_BLEND_SHADER_CODE
	_gate_aurora_shader = Shader.new()
	_gate_aurora_shader.code = AURORA_SHADER_CODE


## Gran plano de océano que rellena visualmente todo lo que hay más allá de las
## casillas construidas, para no instanciar las ~10 000 casillas del lienzo completo.
func _build_ocean_plane() -> void:
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GameConfig.WORLD_WIDTH * TILE * 2.0, GameConfig.WORLD_HEIGHT * TILE * 2.0)
	ocean.mesh = plane
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.04, 0.08, 0.15)   # Mar profundo, se funde con el fondo/niebla
	m.roughness = 0.25
	ocean.material_override = m
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Centrado en la zona jugable, justo bajo el nivel del agua de las casillas.
	var cx: float = float(build_max.x) * 0.5 * TILE
	var cz: float = float(build_max.y) * 0.5 * TILE
	ocean.position = Vector3(cx, -0.30, cz)
	_tiles_root.add_child(ocean)


## Registra UNA casilla: añade su losa a la MultiMesh de suelo de su grupo, sus
## briznas de césped a la MultiMesh global y construye su marcador/edificio (nodos
## con materiales compartidos). NO crea las MultiMesh todavía (se hace al final).
## `chunk_coord` identifica el chunk al que
## pertenece la casilla (para poder descargarla independientemente más tarde) y
## `parent` es la raíz de ESE chunk (no `_tiles_root` directamente), de forma
## que `_unload_chunk()` pueda liberar todo su contenido con un único `queue_free()`.
func _register_one_tile(coord: Vector2i, cell: CellResource, ground_xforms: Dictionary, grass_xforms: Array[Transform3D], ground_blend_data: Array[Dictionary], mountain_xforms: Array[Transform3D], resource_xforms: Dictionary, chunk_coord: Vector2i, parent: Node3D) -> void:
	var wp: Vector3 = _cell_to_world(coord)
	var is_water: bool = cell.terrain == "sea" or cell.terrain == "cst" or cell.resource == "fish"
	var cy: float = -0.22 if is_water else 0.0

	# ── Suelo: normalmente se acumula en la lista de su grupo de terreno, salvo que
	# tenga un vecino directo de OTRO bioma de tierra: entonces va a la MultiMesh
	# especial "blend" (ver _finalize_ground_blend), que mezcla ambas texturas con
	# un límite irregular en vez del salto recto entre dos casillas.
	var group: String = _ground_group(cell)
	var final_group: String = group
	var mm_index: int = -1
	var blend_dir: Vector2 = _find_land_blend_direction(coord, group)
	if blend_dir != Vector2.ZERO:
		var nb_coord: Vector2i = coord + Vector2i(int(blend_dir.x), int(blend_dir.y))
		var nb_cell: CellResource = GlobalState.hexagons_db.get(nb_coord, null) as CellResource
		var nb_group: String = _ground_group(nb_cell) if nb_cell else group
		mm_index = ground_blend_data.size()
		# Semilla del ruido CANÓNICA POR BORDE, no por casilla (task_revision.md #1:
		# la fusión entre biomas se veía "muy extraña y poco realista"). Antes cada
		# casilla hasheaba SU PROPIA coordenada, así que las dos casillas que
		# comparten un mismo límite dibujaban cada una su línea ondulada con un
		# patrón de ruido distinto y descoordinado -> costura parcheada en vez de
		# una frontera continua. Ordenando el par de coordenadas antes de hashear,
		# ambos lados del borde calculan EXACTAMENTE la misma semilla y, como
		# v_world.xz ya es continuo entre casillas vecinas, el ruido (fbm) que
		# dibuja la línea queda perfectamente empalmado visto desde los dos lados.
		var edge_a: Vector2i = coord
		var edge_b: Vector2i = nb_coord
		if edge_b.x < edge_a.x or (edge_b.x == edge_a.x and edge_b.y < edge_a.y):
			var tmp := edge_a
			edge_a = edge_b
			edge_b = tmp
		var edge_seed := fmod(float(edge_a.x) * 12.9898 + float(edge_a.y) * 78.233 + float(edge_b.x) * 39.346 + float(edge_b.y) * 11.135, 1.0)
		ground_blend_data.append({
			"transform": Transform3D(Basis.IDENTITY, wp + Vector3(0.0, cy, 0.0)),
			"own_id": LAND_GROUPS.find(group),
			"nb_id": LAND_GROUPS.find(nb_group),
			"dir": blend_dir,
			"seed": edge_seed,
		})
		final_group = "blend"
	else:
		if not ground_xforms.has(group):
			ground_xforms[group] = []
		var g_list: Array = ground_xforms[group]
		mm_index = g_list.size()
		g_list.append(Transform3D(Basis.IDENTITY, wp + Vector3(0.0, cy, 0.0)))

	var grass_indices: Array[int] = []
	var chunk_prefix := _chunk_key_prefix(chunk_coord)
	var entry: Dictionary = {
		"group": chunk_prefix + final_group, "mm_index": mm_index, "grass_indices": grass_indices,
		"obj": null, "label": null,
		"decor_group": "", "decor_index": -1, "decor_xform": Transform3D.IDENTITY, "decor_hidden": false,
		# Flags precalculadas para animar/repintar sin consultar hexagons_db por frame.
		"is_water": is_water,
		"is_shore": (cell.terrain == "cst" or cell.resource == "fish"),
		"is_trees": (cell.resource == "forest" or cell.resource == "forestBad"),
		"is_interactive": cell.is_interactive(),
		"vis_applied": -1,
		# Chunk propietario, para poder limpiar
		# _cells/_anim_coords al descargar solo ESE chunk (ver _unload_chunk).
		"chunk": chunk_coord,
	}

	# ── Césped y troncos caídos: solo en praderas despejadas (sin edificios, portales, marcadores, recursos ni obstáculos) ──
	var is_interactive_cell: bool = (cell.interactive is Dictionary and not cell.interactive.is_empty()) or cell.opens_view() == "interactive"
	var has_poi_or_obstacle: bool = (
		is_interactive_cell
		or cell.is_interactive()
		or cell.is_gather_node()
		or cell.resource != ""
		or cell.item != ""
		or cell.event_id != ""
		or (cell.portal is Dictionary and not cell.portal.is_empty())
		or (cell.obstacle is Dictionary and not cell.obstacle.is_empty())
		or cell.gate is Dictionary and not cell.gate.is_empty()
		or cell.is_growing_crop()
		or cell.has_stone_path()
	)
	if cell.terrain == "grs" and not has_poi_or_obstacle:
		_collect_grass_blades(coord, wp, grass_xforms, grass_indices)
		var deco_rng := RandomNumberGenerator.new()
		deco_rng.seed = (coord.x * 1234567) ^ (coord.y * 7654321) ^ 0x3a5b7c9d
		var r_val := deco_rng.randf()

		# 1. Flores en pradera (probabilidad moderada ~11%, mayor que los troncos)
		if r_val < 0.11:
			var fx: float = deco_rng.randf_range(-0.35, 0.35)
			var fz: float = deco_rng.randf_range(-0.35, 0.35)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var f_scale: float = deco_rng.randf_range(0.35, 0.48)
			var flower_key: String = "flores_3" if deco_rng.randf() < 0.5 else "flores_4"
			var f_pos: Vector3 = wp + Vector3(fx, GROUND_TOP + 0.01, fz)
			var rot_b := Basis.from_euler(Vector3(0, yaw, 0))
			var xf := Transform3D(rot_b.scaled(Vector3.ONE * f_scale), f_pos)
			if not resource_xforms.has(flower_key):
				resource_xforms[flower_key] = []
			entry["decor_group"] = chunk_prefix + flower_key + "_decor"
			entry["decor_index"] = resource_xforms[flower_key].size()
			entry["decor_xform"] = xf
			resource_xforms[flower_key].append(xf)

		# 2. Setas en pradera (probabilidad ~6%, algo pequeñitas)
		elif r_val < 0.17:
			var mx: float = deco_rng.randf_range(-0.35, 0.35)
			var mz: float = deco_rng.randf_range(-0.35, 0.35)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var m_scale: float = deco_rng.randf_range(0.26, 0.36)
			var m_pos: Vector3 = wp + Vector3(mx, GROUND_TOP + 0.01, mz)
			var rot_b := Basis.from_euler(Vector3(0, yaw, 0))
			var xf := Transform3D(rot_b.scaled(Vector3.ONE * m_scale), m_pos)
			if not resource_xforms.has("setas"):
				resource_xforms["setas"] = []
			entry["decor_group"] = chunk_prefix + "setas_decor"
			entry["decor_index"] = resource_xforms["setas"].size()
			entry["decor_xform"] = xf
			resource_xforms["setas"].append(xf)

		# 3. Troncos caídos (~4.5% de casillas)
		elif r_val < 0.215:
			var lx: float = deco_rng.randf_range(-0.25, 0.25)
			var lz: float = deco_rng.randf_range(-0.25, 0.25)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var pitch: float = deco_rng.randf_range(-0.06, 0.06)
			var roll: float = deco_rng.randf_range(-0.06, 0.06)
			var scale_val: float = deco_rng.randf_range(0.38, 0.52)
			var log_pos: Vector3 = wp + Vector3(lx, GROUND_TOP + 0.04, lz)
			var rot_b := Basis.from_euler(Vector3(pitch, yaw, roll))
			var xf := Transform3D(rot_b.scaled(Vector3.ONE * scale_val), log_pos)
			if not resource_xforms.has("tronco_caido"):
				resource_xforms["tronco_caido"] = []
			entry["decor_group"] = chunk_prefix + "tronco_caido_decor"
			entry["decor_index"] = resource_xforms["tronco_caido"].size()
			entry["decor_xform"] = xf
			resource_xforms["tronco_caido"].append(xf)

	# ── Decoración del Yelmo (task_revision.md #3: "el mapamundi se ve pobre"):
	# rocas desgastadas frecuentes + lápidas y esqueletos de animales MUY
	# puntuales, para que el erial se sienta castigado/abandonado sin llenar
	# el suelo de props repetidos. Mismo patrón semilla+ruleta que el césped.
	elif cell.terrain == "bad" and not has_poi_or_obstacle:
		var deco_rng := RandomNumberGenerator.new()
		deco_rng.seed = (coord.x * 1234567) ^ (coord.y * 7654321) ^ 0x7e1d02a1
		var r_val := deco_rng.randf()
		if r_val < 0.12:
			var rx: float = deco_rng.randf_range(-0.4, 0.4)
			var rz: float = deco_rng.randf_range(-0.4, 0.4)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var s: float = deco_rng.randf_range(0.18, 0.34)
			var pos: Vector3 = wp + Vector3(rx, GROUND_TOP + 0.01, rz)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * s), pos)
			if not resource_xforms.has("roca_gastada"):
				resource_xforms["roca_gastada"] = []
			entry["decor_group"] = chunk_prefix + "roca_gastada_decor"
			entry["decor_index"] = resource_xforms["roca_gastada"].size()
			entry["decor_xform"] = xf
			resource_xforms["roca_gastada"].append(xf)
		elif r_val < 0.28:
			var tx: float = deco_rng.randf_range(-0.25, 0.25)
			var tz: float = deco_rng.randf_range(-0.25, 0.25)
			# Orientación frontal hacia abajo (sur / cámara), con ligera variación diagonal (±30°)
			var yaw: float = deco_rng.randf_range(deg_to_rad(-30.0), deg_to_rad(30.0))
			var pos: Vector3 = wp + Vector3(tx, GROUND_TOP, tz)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), pos)
			if not resource_xforms.has("tumba"):
				resource_xforms["tumba"] = []
			entry["decor_group"] = chunk_prefix + "tumba_decor"
			entry["decor_index"] = resource_xforms["tumba"].size()
			entry["decor_xform"] = xf
			resource_xforms["tumba"].append(xf)
		elif r_val < 0.33:
			var ex: float = deco_rng.randf_range(-0.3, 0.3)
			var ez: float = deco_rng.randf_range(-0.3, 0.3)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var pos: Vector3 = wp + Vector3(ex, GROUND_TOP, ez)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), pos)
			if not resource_xforms.has("esqueleto_animal"):
				resource_xforms["esqueleto_animal"] = []
			entry["decor_group"] = chunk_prefix + "esqueleto_animal_decor"
			entry["decor_index"] = resource_xforms["esqueleto_animal"].size()
			entry["decor_xform"] = xf
			resource_xforms["esqueleto_animal"].append(xf)

	# ── Decoración de Tierra: piedras sueltas pequeñas + matojos de hierba seca.
	elif cell.terrain == "gnd" and not has_poi_or_obstacle:
		var deco_rng := RandomNumberGenerator.new()
		deco_rng.seed = (coord.x * 1234567) ^ (coord.y * 7654321) ^ 0x2c6f9e11
		var r_val := deco_rng.randf()
		if r_val < 0.12:
			var rx: float = deco_rng.randf_range(-0.4, 0.4)
			var rz: float = deco_rng.randf_range(-0.4, 0.4)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var s: float = deco_rng.randf_range(0.16, 0.3)
			var pos: Vector3 = wp + Vector3(rx, GROUND_TOP + 0.01, rz)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * s), pos)
			if not resource_xforms.has("roca"):
				resource_xforms["roca"] = []
			entry["decor_group"] = chunk_prefix + "roca_decor"
			entry["decor_index"] = resource_xforms["roca"].size()
			entry["decor_xform"] = xf
			resource_xforms["roca"].append(xf)
		elif r_val < 0.30:
			var hx: float = deco_rng.randf_range(-0.4, 0.4)
			var hz: float = deco_rng.randf_range(-0.4, 0.4)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var s: float = deco_rng.randf_range(0.4, 0.62)
			var pos: Vector3 = wp + Vector3(hx, GROUND_TOP, hz)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * s), pos)
			if not resource_xforms.has("hierba"):
				resource_xforms["hierba"] = []
			entry["decor_group"] = chunk_prefix + "hierba_decor"
			entry["decor_index"] = resource_xforms["hierba"].size()
			entry["decor_xform"] = xf
			resource_xforms["hierba"].append(xf)

	# ── Decoración del Desierto: rocas + matojos resecos (árbol marchito a
	# escala de arbusto) +, muy de tarde en tarde, huesos blanqueados por el sol.
	elif cell.terrain == "des" and not has_poi_or_obstacle:
		var deco_rng := RandomNumberGenerator.new()
		deco_rng.seed = (coord.x * 1234567) ^ (coord.y * 7654321) ^ 0x4d8a1f63
		var r_val := deco_rng.randf()
		if r_val < 0.10:
			var rx: float = deco_rng.randf_range(-0.4, 0.4)
			var rz: float = deco_rng.randf_range(-0.4, 0.4)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var s: float = deco_rng.randf_range(0.16, 0.32)
			var pos: Vector3 = wp + Vector3(rx, GROUND_TOP + 0.01, rz)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * s), pos)
			if not resource_xforms.has("roca"):
				resource_xforms["roca"] = []
			entry["decor_group"] = chunk_prefix + "roca_decor"
			entry["decor_index"] = resource_xforms["roca"].size()
			entry["decor_xform"] = xf
			resource_xforms["roca"].append(xf)
		elif r_val < 0.16:
			var bx: float = deco_rng.randf_range(-0.35, 0.35)
			var bz: float = deco_rng.randf_range(-0.35, 0.35)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var s: float = deco_rng.randf_range(0.14, 0.2)
			var pos: Vector3 = wp + Vector3(bx, GROUND_TOP, bz)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * s), pos)
			if not resource_xforms.has("arbol_marchito"):
				resource_xforms["arbol_marchito"] = []
			entry["decor_group"] = chunk_prefix + "arbol_marchito_decor"
			entry["decor_index"] = resource_xforms["arbol_marchito"].size()
			entry["decor_xform"] = xf
			resource_xforms["arbol_marchito"].append(xf)
		elif r_val < 0.175:
			var ex: float = deco_rng.randf_range(-0.3, 0.3)
			var ez: float = deco_rng.randf_range(-0.3, 0.3)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var pos: Vector3 = wp + Vector3(ex, GROUND_TOP, ez)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), pos)
			if not resource_xforms.has("esqueleto_animal"):
				resource_xforms["esqueleto_animal"] = []
			entry["decor_group"] = chunk_prefix + "esqueleto_animal_decor"
			entry["decor_index"] = resource_xforms["esqueleto_animal"].size()
			entry["decor_xform"] = xf
			resource_xforms["esqueleto_animal"].append(xf)

	# ── Decoración de Nieve (Task 2 FASE3): rocas heladas + restos de
	# vegetación marchita asomando entre la nieve. Mismo patrón semilla+ruleta.
	elif cell.terrain == "icy" and not has_poi_or_obstacle:
		var deco_rng := RandomNumberGenerator.new()
		deco_rng.seed = (coord.x * 1234567) ^ (coord.y * 7654321) ^ 0x5f2e8b31
		var r_val := deco_rng.randf()
		if r_val < 0.12:
			var rx: float = deco_rng.randf_range(-0.4, 0.4)
			var rz: float = deco_rng.randf_range(-0.4, 0.4)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var s: float = deco_rng.randf_range(0.16, 0.3)
			var pos: Vector3 = wp + Vector3(rx, GROUND_TOP + 0.01, rz)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * s), pos)
			if not resource_xforms.has("roca_gastada"):
				resource_xforms["roca_gastada"] = []
			entry["decor_group"] = chunk_prefix + "roca_gastada_decor"
			entry["decor_index"] = resource_xforms["roca_gastada"].size()
			entry["decor_xform"] = xf
			resource_xforms["roca_gastada"].append(xf)
		elif r_val < 0.20:
			var bx: float = deco_rng.randf_range(-0.35, 0.35)
			var bz: float = deco_rng.randf_range(-0.35, 0.35)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var s: float = deco_rng.randf_range(0.14, 0.22)
			var pos: Vector3 = wp + Vector3(bx, GROUND_TOP, bz)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * s), pos)
			if not resource_xforms.has("arbol_marchito"):
				resource_xforms["arbol_marchito"] = []
			entry["decor_group"] = chunk_prefix + "arbol_marchito_decor"
			entry["decor_index"] = resource_xforms["arbol_marchito"].size()
			entry["decor_xform"] = xf
			resource_xforms["arbol_marchito"].append(xf)

	# ── Decoración de Playa: cantos rodados pequeños + madera a la deriva
	# (reutiliza el mismo tronco caído de pradera/bosque, encaja igual de bien).
	elif cell.terrain == "are" and not has_poi_or_obstacle:
		var deco_rng := RandomNumberGenerator.new()
		deco_rng.seed = (coord.x * 1234567) ^ (coord.y * 7654321) ^ 0x1a2b3c4d
		var r_val := deco_rng.randf()
		if r_val < 0.08:
			var rx: float = deco_rng.randf_range(-0.4, 0.4)
			var rz: float = deco_rng.randf_range(-0.4, 0.4)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var s: float = deco_rng.randf_range(0.12, 0.22)
			var pos: Vector3 = wp + Vector3(rx, GROUND_TOP + 0.01, rz)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * s), pos)
			if not resource_xforms.has("roca"):
				resource_xforms["roca"] = []
			entry["decor_group"] = chunk_prefix + "roca_decor"
			entry["decor_index"] = resource_xforms["roca"].size()
			entry["decor_xform"] = xf
			resource_xforms["roca"].append(xf)
		elif r_val < 0.13:
			var lx: float = deco_rng.randf_range(-0.3, 0.3)
			var lz: float = deco_rng.randf_range(-0.3, 0.3)
			var yaw: float = deco_rng.randf_range(0.0, TAU)
			var scale_val: float = deco_rng.randf_range(0.28, 0.4)
			var pos: Vector3 = wp + Vector3(lx, GROUND_TOP + 0.02, lz)
			var xf := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * scale_val), pos)
			if not resource_xforms.has("tronco_caido"):
				resource_xforms["tronco_caido"] = []
			entry["decor_group"] = chunk_prefix + "tronco_caido_decor"
			entry["decor_index"] = resource_xforms["tronco_caido"].size()
			entry["decor_xform"] = xf
			resource_xforms["tronco_caido"].append(xf)

	# Recursos genéricos MUY repetidos (cantera/oro/ganado): igual que la montaña,
	# comparten UNA sola MultiMesh por tipo en vez de un nodo/marcador por casilla
	# (ver RESOURCE_DECOR_KINDS / _finalize_resource_decor). No animan y su
	# visibilidad depende solo del AGOTAMIENTO del nodo de recolección (se oculta
	# vía transform a escala 0 en _apply_cell_visual, igual que la niebla).
	if cell.terrain == "mnt":
		# Decoración de montaña: la geometría (3 picos) es IDÉNTICA en todas las
		# casillas de montaña, así que en vez de un marcador/nodo por casilla (con
		# sus propios draw calls) todas comparten UNA sola MultiMesh (ver
		# _finalize_mountain_decor): coste fijo de 2 draw calls para TODO el mapa,
		# tenga 1 o 500 montañas. La niebla se aplica igual que al suelo (por color
		# de instancia) en _apply_cell_visual.
		entry["decor_group"] = chunk_prefix + "mountain_decor"
		entry["decor_index"] = mountain_xforms.size()
		var m_xf := Transform3D(Basis.IDENTITY, wp)
		entry["decor_xform"] = m_xf
		mountain_xforms.append(m_xf)
	elif RESOURCE_DECOR_KINDS.has(cell.resource):
		var r_key: String = cell.resource
		if not resource_xforms.has(r_key):
			resource_xforms[r_key] = []
		var r_list: Array = resource_xforms[r_key]
		var r_xform := Transform3D(Basis.IDENTITY, wp)
		entry["decor_group"] = chunk_prefix + r_key + "_decor"
		entry["decor_index"] = r_list.size()
		entry["decor_xform"] = r_xform
		r_list.append(r_xform)

		# Si es roca, preparamos la ranura paralela en la MultiMesh de roca gastada
		if r_key == "rock" or r_key == "gold":
			var worn_key: String = r_key + "_worn"
			if not resource_xforms.has(worn_key):
				resource_xforms[worn_key] = []
			var worn_list: Array = resource_xforms[worn_key]
			entry["decor_worn_group"] = chunk_prefix + worn_key + "_decor"
			worn_list.append(Transform3D().scaled(Vector3.ZERO))
	else:
		# ── Marcador/edificio de localización encima de la losa (nodos) ──
		# Diferido (ver _process_pending_marker_builds/§4): no instanciar TODOS
		# los POIs del chunk en este mismo frame síncrono.
		_pending_marker_builds.append({"coord": coord, "cell": cell, "wp": wp, "entry": entry, "parent": parent})

	# NOTA: el "Camino de Piedra" (terreno "pth") ya se ve completo solo con su
	# textura de losa (tile_templo.png, ver `_get_base_texture`/`_ground_group`):
	# antes se añadía además un overlay 3D de ladrillos que tapaba esa textura y
	# daba un aspecto inconsistente entre casillas. Retirado a propósito
	# (el asset "suelo_ladrillo" y sus variantes se eliminaron por completo,
	# no estaban en uso en ninguna mazmorra ni en el mapamundi), no añadir de
	# nuevo geometría aquí.

	_cells[coord] = entry

	# Animación POR NODO si hay árboles, item interactivo o animales que deambulan.
	var is_animal: bool = cell.resource in ["milk", "meat", "cerdo", "cerdos", "vaca", "vacas", "cow", "pigs"] or cell.item in ["milk", "meat", "cerdo", "cerdos", "vaca", "vacas", "cow", "pigs"] or cell.object in ["milk", "meat"]
	entry["is_animal"] = is_animal
	if entry["is_trees"] or entry["is_interactive"] or is_animal:
		if not _anim_coords.has(coord):
			_anim_coords.append(coord)


func _find_land_blend_direction(_coord: Vector2i, _group: String) -> Vector2:
	# Desactivado para mantener las casillas nítidas, limpias y vibrantes sin
	# manchas o bandas oscuras de degradado entre biomas.
	return Vector2.ZERO


## Genera las briznas de césped de una casilla con alta variación orgánica
## (densidad no uniforme, tamaños y proporciones variadas, giros e inclinaciones naturales).
func _collect_grass_blades(coord: Vector2i, wp: Vector3, grass_xforms: Array[Transform3D], out_indices: Array[int]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (coord.x * 73856093) ^ (coord.y * 19349663) ^ 0x5bf03635

	# Ruido pseudo-continuo para modular parches naturales
	var patch_val: float = sin(float(coord.x) * 0.45) * cos(float(coord.y) * 0.45) + rng.randf_range(-0.25, 0.25)
	
	# Densidad alta para tapiz continuo de pradera (7 a 12 matas repartidas por toda la casilla de 2x2m)
	var count: int
	if patch_val >= 0.15:
		count = rng.randi_range(9, 13)
	elif patch_val >= -0.25:
		count = rng.randi_range(7, 10)
	else:
		count = rng.randi_range(5, 7)

	for i in range(count):
		# Dispersión en todo el ancho de la casilla (TILE = 2.0m -> radio ±0.85m)
		# evitando huecos o pasillos vacíos entre casillas contiguas
		var rx: float = rng.randf_range(-0.85, 0.85)
		var rz: float = rng.randf_range(-0.85, 0.85)
		
		# Variedad de escala por mata: pequeña / mediana / frondosa
		var clump_type: float = rng.randf()
		var scale_x: float
		var scale_z: float
		var scale_y: float
		
		if clump_type < 0.30:
			# Brote sutil
			scale_x = rng.randf_range(0.35, 0.48)
			scale_z = scale_x * rng.randf_range(0.85, 1.15)
			scale_y = rng.randf_range(0.18, 0.26)
		elif clump_type < 0.75:
			# Mata tupida estándar
			scale_x = rng.randf_range(0.48, 0.65)
			scale_z = scale_x * rng.randf_range(0.85, 1.20)
			scale_y = rng.randf_range(0.24, 0.35)
		else:
			# Mata frondosa grande
			scale_x = rng.randf_range(0.60, 0.82)
			scale_z = scale_x * rng.randf_range(0.90, 1.25)
			scale_y = rng.randf_range(0.30, 0.42)
		
		var yaw: float = rng.randf_range(0.0, TAU)
		var pitch: float = rng.randf_range(-0.12, 0.12)
		var roll_angle: float = rng.randf_range(-0.12, 0.12)
		var pos_y: float = GROUND_TOP + rng.randf_range(-0.01, 0.01)
		var pos: Vector3 = wp + Vector3(rx, pos_y, rz)
		
		var rot_basis := Basis.from_euler(Vector3(pitch, yaw, roll_angle))
		var basis := rot_basis.scaled(Vector3(scale_x, scale_y, scale_z))
		out_indices.append(grass_xforms.size())
		grass_xforms.append(Transform3D(basis, pos))


## Construye el marcador/edificio de una casilla y lo cuelga de _tiles_root, con sus
## materiales deduplicados (compartidos) para que el motor agrupe las draw calls.
## Los 6 edificios grandes son 100% deterministas por su tipo
## (y por `event_id` en el caso del templo): si YA se construyó uno igual antes
## en este mundo, se `duplicate()` la plantilla cacheada (ver
## _building_template_cache/_building_cache_key) en vez de repetir la generación
## procedural + fusión de mallas — así una aldea con 7 casitas solo "construye"
## la primera, y el resto son duplicados baratos (mismas mallas/materiales).
var _building_template_cache: Dictionary = {}  # cache_key(String) -> Node3D (plantilla, fuera del árbol)

## Clave de caché para los 6 edificios grandes ("" si `cell` no es uno de ellos).
## El templo/lugar incluye el `event_id` porque BuildingTemplo.build colorea el
## techo según él (mago/guerrero/santuario): no son intercambiables entre sí.
func _building_cache_key(cell: CellResource) -> String:
	# El campamento base evoluciona visualmente con GlobalState.camp_level: nunca debe cachearse como plantilla estática
	if cell.event_id == "base" or cell.resource == "base" or cell.item == "base":
		return ""
	if cell.event_id != "":
		return cell.event_id
	if cell.item in ["ciudad", "aldea", "casita", "cueva", "ruinas", "place"]:
		return cell.item
	return ""


func _build_marker_for(_coord: Vector2i, cell: CellResource, wp: Vector3, entry: Dictionary, parent: Node3D) -> void:
	var cache_key := _building_cache_key(cell)
	var marker: Node3D
	if cache_key != "" and _building_template_cache.has(cache_key):
		marker = (_building_template_cache[cache_key] as Node3D).duplicate()
	else:
		marker = GenericMarkers.make_marker(cell)
		if marker == null:
			return
		_dedupe_marker_materials(marker)
		# Fusión de mallas (ver _merge_mesh_children): reduce drásticamente los draw
		# calls por marcador. Los árboles se fusionan POR ÁRBOL, no el bosque entero de
		# golpe, para conservar el balanceo individual con el viento de _animate_nearby.
		var is_trees: bool = (cell.resource == "forest" or cell.resource == "forestBad")
		if is_trees:
			for tree_node in marker.get_children():
				if tree_node is Node3D:
					_merge_mesh_children(tree_node as Node3D)
		elif cell.resource == "fish" or cell.item == "chest" or (cell.chest is Dictionary and not cell.chest.is_empty()) or cell.type == "chest":
			pass
		elif cell.resource in ["milk", "meat", "cerdo", "cerdos", "vaca", "vacas", "cow", "pigs"] or cell.item in ["milk", "meat", "cerdo", "cerdos", "vaca", "vacas", "cow", "pigs"] or cell.object in ["milk", "meat"]:
			pass
		else:
			_merge_mesh_children(marker)
		if cache_key != "":
			_building_template_cache[cache_key] = marker.duplicate()
	# make_marker() siempre envuelve la geometría en un Node3D contenedor (nunca
	# devuelve un MeshInstance3D suelto), así que el desplazamiento Y ya viene
	# horneado en la posición de sus hijos: no hace falta y_offset aquí.
	marker.position = wp + Vector3(0.0, GROUND_TOP, 0.0)
	parent.add_child(marker)
	entry["obj"] = marker
	_attach_poi_night_light(marker, cell)

	# Etiqueta flotante con el nombre de la localización, excepto para montañas,
	# objetos interactivos (carteles/lápidas…), cofres y nodos de recolección:
	# su propio modelo 3D / icono ya los identifica y el texto flotante sobre ellos estorba.
	var is_interactive_cell: bool = (cell.interactive is Dictionary and not cell.interactive.is_empty()) or cell.opens_view() == "interactive"
	var is_chest_cell: bool = (cell.chest is Dictionary and not cell.chest.is_empty()) or cell.item == "chest" or cell.type == "chest"
	if cell.terrain != "mnt" and not cell.is_gather_node() and not is_interactive_cell and not is_chest_cell and cell.resource != "campfire":
		var label := Label3D.new()
		label.text = cell.get_display_name()
		label.font_size = 64
		label.pixel_size = 0.006
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.width = 750.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# `Label3D` es 3D (no `Control`), así que NO hereda el `Theme` global de
		# fuente/color (`Locale._apply_theme_font()`) — se aplica el tema aquí
		# explícitamente (los nombres de POI del
		# mapamundi como "Cueva de los perdidos" deben reflejar el tema activo).
		label.font = UiKit.theme_font()
		var poi_accent := UiKit.theme_color("accent2", Color(1.0, 0.95, 0.82))
		label.modulate = Color(poi_accent.r, poi_accent.g, poi_accent.b, 0.85)
		label.outline_size = 16
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
		label.no_depth_test = true
		label.position = wp + Vector3(0.0, GROUND_TOP + 1.7, 0.0)
		parent.add_child(label)
		entry["label"] = label


## Construye hasta `MARKER_BUILD_BUDGET_PER_FRAME` marcadores/edificios en cola
## (ver `_pending_marker_builds`, llenada por `_register_one_tile` al finalizar
## un chunk nuevo). Amortiza el coste de instanciar POIs a lo largo de varios
## frames en vez de todos de golpe (§4, task_arreglosPendientes.md).
func _process_pending_marker_builds() -> void:
	if _pending_marker_builds.is_empty():
		return
	var built := 0
	while built < MARKER_BUILD_BUDGET_PER_FRAME and not _pending_marker_builds.is_empty():
		var item: Dictionary = _pending_marker_builds.pop_front()
		var parent: Node3D = item["parent"]
		# El chunk pudo descargarse (el jugador se alejó) mientras su marcador
		# esperaba turno: descartar sin construir nada (igual que WorldChunkStreamer
		# descarta resultados de chunks ya no deseados).
		if parent == null or not is_instance_valid(parent):
			continue
		var coord: Vector2i = item["coord"]
		_build_marker_for(coord, item["cell"], item["wp"], item["entry"], parent)
		built += 1
		# El marcador se creó DESPUÉS de que la niebla/visibilidad ya se aplicara
		# al resto de la casilla (ver _finalize_chunk_from_classified): aplicarla
		# ahora también a él para que no aparezca visible de golpe si la casilla
		# está en niebla o fuera del radio de marcadores.
		if is_inside_tree() and _cells.has(coord):
			WorldFogRenderer.apply_cell_visual(self, coord)


## Vacía completamente la cola de marcadores pendientes, instanciándolos todos
## de golpe. Se utiliza durante la inicialización del mapa (al iniciar partida o
## cambiar de vista) para que las mazmorras y edificios aparezcan al instante.
func _flush_pending_marker_builds() -> void:
	while not _pending_marker_builds.is_empty():
		var item: Dictionary = _pending_marker_builds.pop_front()
		var parent: Node3D = item.get("parent", null)
		if parent == null or not is_instance_valid(parent):
			continue
		var coord: Vector2i = item["coord"]
		_build_marker_for(coord, item["cell"], item["wp"], item["entry"], parent)
		if is_inside_tree() and _cells.has(coord):
			WorldFogRenderer.apply_cell_visual(self, coord)


## Añade una luz ambiental nocturna (OmniLight3D ligera y atmosférica) a los
## POIs, casas, mazmorras, ciudades, templos, tumbas y campamentos del mapa.
## Solo se enciende de noche según el ciclo día/noche (TimeManager.daylight_factor).
func _attach_poi_night_light(marker: Node3D, cell: CellResource) -> void:
	if marker == null or not is_instance_valid(marker):
		return
	var daylight: float = TimeManager.daylight_factor()
	var night_factor: float = clampf(1.0 - (daylight / 0.5), 0.0, 1.0)
	if marker.has_node("PoiNightLight"):
		var existing: OmniLight3D = marker.get_node("PoiNightLight") as OmniLight3D
		if existing != null:
			if not existing.is_in_group("poi_night_lights"):
				existing.add_to_group("poi_night_lights")
			var base_e: float = float(existing.get_meta("base_energy", 0.9))
			existing.light_energy = base_e * night_factor
			existing.visible = night_factor > 0.01
		return

	var is_poi: bool = false
	var light_col := Color(1.0, 0.78, 0.40)
	var light_range: float = 3.6
	var base_energy: float = 0.95

	var eid := cell.event_id.to_lower()
	var item := cell.item.to_lower()
	var res := cell.resource.to_lower()
	var opens := cell.opens_view().to_lower()

	if eid.begins_with("house_") or item == "casita":
		is_poi = true
		light_col = Color(1.0, 0.76, 0.38) # Cálido de hogar/chimenea
		light_range = 3.5
		base_energy = 0.95
	elif eid.begins_with("city_") or item in ["ciudad", "aldea"]:
		is_poi = true
		light_col = Color(1.0, 0.80, 0.42) # Faroles de ciudad
		light_range = 4.2
		base_energy = 1.15
	elif res in ["campfire", "base"]:
		is_poi = true
		light_col = Color(1.0, 0.58, 0.22) # Fuego de campamento
		light_range = 3.4
		base_energy = 1.1
	elif eid.begins_with("poi_tumba") or item == "poi_tumba":
		is_poi = true
		light_col = Color(0.85, 0.75, 0.52) # Vela espectral tenue
		light_range = 2.8
		base_energy = 0.8
	elif eid.begins_with("dun_") or item == "cueva" or opens == "dungeon":
		is_poi = true
		light_col = Color(0.55, 0.75, 1.0) # Resplandor místico de mazmorra
		light_range = 3.8
		base_energy = 0.95
	elif eid.begins_with("sendero_") or eid.begins_with("poi_temple") or item == "templo":
		is_poi = true
		light_col = Color(0.68, 0.82, 1.0) # Brillo sagrado de templo
		light_range = 3.8
		base_energy = 0.95
	elif item in ["puerto", "presa", "puente"] or eid in ["poi_presa_001", "poi_celestia_puerto", "south_bridge"]:
		is_poi = true
		light_col = Color(0.95, 0.78, 0.42) # Faroles de puerto / puente
		light_range = 3.4
		base_energy = 0.85
	elif eid.begins_with("poi_") or item in ["place", "ruinas"] or opens in ["place", "building", "city"]:
		is_poi = true
		light_col = Color(0.92, 0.75, 0.45) # POI general
		light_range = 3.4
		base_energy = 0.9

	if not is_poi:
		return

	var light := OmniLight3D.new()
	light.name = "PoiNightLight"
	light.light_color = light_col
	light.omni_range = light_range
	light.omni_attenuation = 1.1
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.75, 0.0)
	light.set_meta("base_energy", base_energy)

	light.light_energy = base_energy * night_factor
	light.visible = night_factor > 0.01
	light.add_to_group("poi_night_lights")
	marker.add_child(light)


## Recorre el marcador y sustituye cada StandardMaterial3D por uno compartido de igual
## aspecto. Así las piezas repetidas (madera, piedra, tejado…) comparten material y el
## motor las agrupa en pocas draw calls.
func _dedupe_marker_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override is StandardMaterial3D:
			mi.material_override = _shared_mat_for(mi.material_override as StandardMaterial3D)
		elif mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var sm = mi.get_surface_override_material(s)
				if sm is StandardMaterial3D:
					mi.set_surface_override_material(s, _shared_mat_for(sm as StandardMaterial3D))
				elif mi.mesh.surface_get_material(s) is StandardMaterial3D:
					var m = mi.mesh.surface_get_material(s) as StandardMaterial3D
					mi.set_surface_override_material(s, _shared_mat_for(m))
	for child in node.get_children():
		_dedupe_marker_materials(child)


## Devuelve un StandardMaterial3D compartido equivalente (mismo aspecto) al dado,
## reutilizándolo para todas las piezas idénticas de todos los marcadores del mapa.
func _shared_mat_for(m: StandardMaterial3D) -> StandardMaterial3D:
	var key: String = "%.3f_%.3f_%.3f|%.3f|%.3f|%d|%.3f_%.3f_%.3f|%.3f" % [
		m.albedo_color.r, m.albedo_color.g, m.albedo_color.b,
		m.roughness, m.metallic,
		1 if m.emission_enabled else 0,
		m.emission.r, m.emission.g, m.emission.b,
		m.emission_energy_multiplier,
	]
	if _shared_mats.has(key):
		return _shared_mats[key]
	_shared_mats[key] = m
	return m


## Combina, POR MATERIAL, todos los MeshInstance3D descendientes de 'root' en una
## sola malla (ArrayMesh multi-superficie): un marcador con ~20 piezas (madera,
## piedra, tejado…) pasa de ~20 draw calls a 2-5 (uno por material distinto). Se
## aplica DESPUÉS de _dedupe_marker_materials, así que "mismo Material" ya implica
## "mismo aspecto" y agrupar por referencia es correcto. Los nodos originales
## (incluidos contenedores intermedios tipo "torre"/"casa") se eliminan: quedan
## sustituidos por un único MeshInstance3D sin sombra dinámica (el mayor coste de
## GPU en móvil eran las docenas de piezas sin agrupar, cada una además proyectando
## sombra por separado).
func _merge_mesh_children(root: Node3D, keep_shadow: bool = false) -> void:
	var by_mat: Dictionary = {}   # Material -> SurfaceTool
	for child in root.get_children():
		if child is Node3D:
			_collect_for_merge(child, (child as Node3D).transform, by_mat)
	if by_mat.is_empty():
		return
	for child in root.get_children():
		child.queue_free()
	var array_mesh := ArrayMesh.new()
	var mats: Array = by_mat.keys()
	for mat: Material in mats:
		var st: SurfaceTool = by_mat[mat]
		st.index()
		st.commit(array_mesh)
	var merged := MeshInstance3D.new()
	merged.mesh = array_mesh
	for i in range(mats.size()):
		merged.set_surface_override_material(i, mats[i])
	merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if keep_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(merged)


## Recorre 'node' (con su transform acumulado respecto a la raíz de la fusión) y
## hornea la geometría de cada MeshInstance3D encontrado en el SurfaceTool de su
## material (uno por material distinto), recursando en los contenedores anidados.
func _collect_for_merge(node: Node, xform: Transform3D, by_mat: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			for surf in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.material_override
				if mat == null:
					mat = mi.get_surface_override_material(surf)
				if mat == null:
					mat = mi.mesh.surface_get_material(surf)
				if mat == null:
					continue
				var st: SurfaceTool = by_mat.get(mat, null)
				if st == null:
					st = SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					by_mat[mat] = st
				st.append_from(mi.mesh, surf, xform)
	for child in node.get_children():
		if child is Node3D:
			_collect_for_merge(child, xform * (child as Node3D).transform, by_mat)


## Crea las MultiMesh de suelo de UN CHUNK (una por grupo de terreno dentro de
## él) con los transforms recolectados. `prefix` viene de `_chunk_key_prefix()`
## y `parent` es la raíz del chunk.
func _finalize_ground(ground_xforms: Dictionary, prefix: String, parent: Node3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(TILE - GAP, GROUND_H, TILE - GAP)
	for group: String in ground_xforms.keys():
		var xforms: Array = ground_xforms[group]
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = box
		mm.instance_count = xforms.size()
		for i in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_color(i, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _make_ground_material(group)
		# El suelo recibe sombra pero NO la proyecta (evita duplicar geometría en el pase de sombras).
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		_ground_mm[prefix + group] = mm


## Crea la MultiMesh de césped de UN CHUNK con los transforms recolectados.
## El material (`_grass_mat`) SÍ sigue siendo compartido por todos los chunks
## (uniforms globales, p. ej. la posición del jugador) — solo la MultiMesh de
## instancias es por chunk, para poder liberarla independientemente.
func _finalize_grass(chunk_coord: Vector2i, grass_xforms: Array[Transform3D], parent: Node3D) -> void:
	if grass_xforms.is_empty():
		return
	if _grass_mesh_cache == null:
		var grass_node := ModelLoader.load_model("hierba")
		if grass_node != null:
			var mi: MeshInstance3D = null
			if grass_node is MeshInstance3D:
				mi = grass_node as MeshInstance3D
			else:
				for child in grass_node.get_children():
					if child is MeshInstance3D:
						mi = child as MeshInstance3D
						break
			if mi != null and mi.mesh != null:
				_grass_mesh_cache = mi.mesh
		if _grass_mesh_cache == null:
			_grass_mesh_cache = PrismMesh.new()
			_grass_mesh_cache.size = Vector3(0.5, 0.35, 0.5)
	if _grass_mat == null:
		_grass_mat = ShaderMaterial.new()
		_grass_mat.shader = _grass_shader
		_grass_mat.set_shader_parameter("tint", Color(0.24, 0.58, 0.20))
		_grass_mat.set_shader_parameter("tint_tip", Color(0.48, 0.82, 0.28))
		_grass_mat.set_shader_parameter("rough", 0.80)
		_grass_mat.set_shader_parameter("player_pos", Vector3.ZERO)
		_grass_mat.set_shader_parameter("push_radius", GRASS_PUSH_RADIUS)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _grass_mesh_cache
	mm.instance_count = grass_xforms.size()
	for i in range(grass_xforms.size()):
		mm.set_instance_transform(i, grass_xforms[i])
		mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _grass_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	_grass_mm[chunk_coord] = mm


## Crea la MultiMesh especial de casillas "borde" entre dos biomas de tierra
## distintos: UNA sola malla/material para TODO el mapa (tan barata como cualquier
## otro grupo de suelo) que mezcla las dos texturas con un límite irregular en vez
## de un salto recto, usando el custom data por instancia (own_id/nb_id/ángulo/seed)
## para decirle al shader qué mezclar. Reutiliza _ground_mm["blend"], así que la
## niebla de guerra (_apply_cell_visual) no necesita ningún cambio.
func _finalize_ground_blend(data: Array[Dictionary], prefix: String, parent: Node3D) -> void:
	if data.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(TILE - GAP, GROUND_H, TILE - GAP)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = box
	mm.instance_count = data.size()
	for i in range(data.size()):
		var d: Dictionary = data[i]
		mm.set_instance_transform(i, d["transform"])
		mm.set_instance_color(i, Color.WHITE)
		var own_id: int = maxi(0, int(d["own_id"]))
		var nb_id: int = maxi(0, int(d["nb_id"]))
		var dir: Vector2 = d["dir"]
		var ang_norm: float = atan2(dir.y, dir.x) / TAU + 0.5
		mm.set_instance_custom_data(i, Color(float(own_id), float(nb_id), ang_norm, float(d["seed"])))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if _ground_blend_mat == null:
		_ground_blend_mat = _make_ground_blend_material()
	mmi.material_override = _ground_blend_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	_ground_mm[prefix + "blend"] = mm


## Material de la MultiMesh "blend": las texturas y tintes de LAND_GROUPS como uniforms
## (resueltos 100% data-driven desde las definiciones JSON) + el shader que las mezcla.
func _make_ground_blend_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _ground_blend_shader
	for i in range(LAND_GROUPS.size()):
		var group: String = LAND_GROUPS[i]
		var code: String = GROUND_GROUP_TERRAIN_CODE.get(group, group)
		var tex: Texture2D = _tex_tile_pradera
		var tint := Color.WHITE
		var tdef := Design.get_terrain_def(code)
		if not tdef.is_empty():
			if tdef.has("texture"):
				tex = _texture_for_key(String(tdef["texture"]))
			if tdef.has("tint"):
				tint = _hex_color(String(tdef["tint"])) * float(tdef.get("tint_boost", 1.0))
		mat.set_shader_parameter("tex%d" % i, tex)
		mat.set_shader_parameter("tint%d" % i, tint)
	mat.set_shader_parameter("rough", 0.85)
	return mat


## Crea la MultiMesh compartida de decoración de montaña (los 3 picos, IDÉNTICOS en
## todas las casillas de montaña — ver _register_one_tile). Coste fijo: 2 draw
## calls (roca + nieve de cumbre) para TODAS las montañas del mapa, sea cual sea
## su número. Reutiliza _ground_mm["mountain_decor"], así que _apply_cell_visual
## le aplica la niebla exactamente igual que al suelo (color de instancia).
func _finalize_mountain_decor(xforms: Array[Transform3D], prefix: String, parent: Node3D) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	if _mountain_mesh_cache == null:
		_mountain_mesh_cache = _build_shared_mountain_mesh()
	mm.mesh = _mountain_mesh_cache
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	_ground_mm[prefix + "mountain_decor"] = mm


## Hornea, UNA sola vez, la geometría de la montaña a partir de montana.tscn (o fallback procedural)
## en un ArrayMesh multi-superficie para que la MultiMesh dibuje TODAS las montañas del mapa en coste fijo.
func _build_shared_mountain_mesh() -> ArrayMesh:
	var model_node := ModelLoader.load_model("montana")
	if model_node != null:
		var mi_list: Array[MeshInstance3D] = []
		if model_node is MeshInstance3D:
			mi_list.append(model_node as MeshInstance3D)
		for child in model_node.get_children():
			if child is MeshInstance3D:
				mi_list.append(child as MeshInstance3D)
			for sub in child.get_children():
				if sub is MeshInstance3D:
					mi_list.append(sub as MeshInstance3D)
		
		if not mi_list.is_empty():
			var mat_groups: Dictionary = {}
			for mi in mi_list:
				if mi.mesh == null:
					continue
				for s_idx in range(mi.mesh.get_surface_count()):
					var mat: Material = mi.material_override
					if mat == null:
						mat = mi.get_active_material(s_idx)
					if mat == null:
						mat = mi.mesh.surface_get_material(s_idx)
					if mat == null:
						mat = StandardMaterial3D.new()
					if not mat_groups.has(mat):
						mat_groups[mat] = []
					(mat_groups[mat] as Array).append({
						"mesh": mi.mesh,
						"surface_idx": s_idx,
						"xform": mi.transform
					})
			
			if not mat_groups.is_empty():
				var merged_mesh := ArrayMesh.new()
				var s_count := 0
				for mat in mat_groups.keys():
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					for item in mat_groups[mat]:
						st.append_from(item["mesh"], item["surface_idx"], item["xform"])
					st.index()
					st.commit(merged_mesh)
					var final_mat: Material = mat
					if final_mat is StandardMaterial3D:
						final_mat = (final_mat as StandardMaterial3D).duplicate()
						(final_mat as StandardMaterial3D).vertex_color_use_as_albedo = true
					merged_mesh.surface_set_material(s_count, final_mat)
					s_count += 1
				return merged_mesh

	# Fallback procedural histórico si no se encontrara el archivo montana.tscn
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.24, 0.25, 0.28)
	rock_mat.roughness = 0.9
	rock_mat.vertex_color_use_as_albedo = true
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.95, 0.95, 0.95)
	cap_mat.roughness = 0.8
	cap_mat.vertex_color_use_as_albedo = true

	var st_rock := SurfaceTool.new()
	st_rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_cap := SurfaceTool.new()
	st_cap.begin(Mesh.PRIMITIVE_TRIANGLES)

	var peaks_data: Array[Dictionary] = [
		{"pos": Vector3(-0.05, 0.0, -0.15), "height": 1.45, "radius": 0.78, "rot_y": 0.0},
		{"pos": Vector3(-0.45, 0.0, 0.35), "height": 0.95, "radius": 0.58, "rot_y": 1.2},
		{"pos": Vector3(0.45, 0.0, 0.25), "height": 0.75, "radius": 0.52, "rot_y": -0.8},
	]
	for data: Dictionary in peaks_data:
		var h: float = data["height"]
		var r: float = data["radius"]
		var rot_y: float = data["rot_y"]
		var pos: Vector3 = data["pos"]

		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = r
		cone.height = h
		cone.radial_segments = 5
		var body_xform := Transform3D(Basis(Vector3.UP, rot_y), pos + Vector3(0.0, h * 0.5, 0.0))
		st_rock.append_from(cone, 0, body_xform)

		var cap_cone := CylinderMesh.new()
		cap_cone.top_radius = 0.0
		cap_cone.bottom_radius = r * 0.35 * 1.08
		cap_cone.height = h * 0.35
		cap_cone.radial_segments = 5
		var cap_xform := Transform3D(Basis(Vector3.UP, rot_y + 0.628), pos + Vector3(0.0, h * 0.825, 0.0))
		st_cap.append_from(cap_cone, 0, cap_xform)

	var array_mesh := ArrayMesh.new()
	st_rock.index()
	st_rock.commit(array_mesh)
	st_cap.index()
	st_cap.commit(array_mesh)
	array_mesh.surface_set_material(0, rock_mat)
	array_mesh.surface_set_material(1, cap_mat)
	return array_mesh


## Crea la MultiMesh compartida de UN recurso genérico repetitivo (RESOURCE_DECOR_KINDS:
## cantera de piedra/oro, ganado). Mismo patrón que _finalize_mountain_decor: coste fijo
## de 2 draw calls por TIPO de recurso para todo el mapa, sea cual sea su número de
## casillas. `key` es el código de recurso (cell.resource); la clave de _ground_mm es
## `key + "_decor"` (la usan _apply_cell_visual para la niebla y el agotamiento).
func _finalize_resource_decor(key: String, xforms: Array, prefix: String, parent: Node3D) -> void:
	if xforms.is_empty():
		return
	if not _resource_mesh_cache.has(key):
		if key.begins_with("rock") or key.begins_with("gold"):
			var is_gold: bool = key.begins_with("gold")
			var is_worn: bool = key.ends_with("_worn")
			_resource_mesh_cache[key] = _build_shared_rock_mesh(is_gold, is_worn)
		elif key == "milk" or key == "vaca" or key == "vacas" or key == "cow":
			_resource_mesh_cache[key] = _build_shared_cow_mesh()
		elif key == "meat" or key == "cerdo" or key == "cerdos" or key == "pigs":
			_resource_mesh_cache[key] = _build_shared_pig_mesh()
		elif key == "tronco_caido":
			_resource_mesh_cache[key] = _build_shared_log_mesh()
		elif key == "tumba":
			_resource_mesh_cache[key] = _build_shared_tombstone_mesh()
		elif key == "esqueleto_animal":
			_resource_mesh_cache[key] = _build_shared_skeleton_mesh()
		else:
			# Recursos "genéricos": el código del recurso ES el nombre del modelo a
			# cargar (assets/common/models/...). Antes esta rama solo cubría una
			# lista fija (flores_3/flores_4/setas/roca/roca_gastada/hierba/
			# arbol_marchito); un recurso NUEVO creado desde el editor
			# (WorldResourcesManager.js) con un código fuera de esa lista se
			# quedaba invisible en el mapa pese a estar bien configurado y con su
			# modelo subido (Task 1 Fase 1 §2.1: "verificar el mismo patrón en el
			# mapamundi para recursos"). Ahora cualquier código nuevo se resuelve
			# igual que los históricos, sin lista cerrada.
			_resource_mesh_cache[key] = _extract_mesh_from_model(key)
	var mesh: Mesh = _resource_mesh_cache.get(key, null)
	if mesh == null:
		return
	# Cantera de piedra/oro: se hunden la mitad de su altura para que no
	# parezcan una bola flotando encima del suelo (se ven menos redondas y
	# menos grandes al quedar medio enterradas, como pidió el usuario).
	var y_sink: float = 0.0
	if key.begins_with("rock") or key.begins_with("gold"):
		y_sink = mesh.get_aabb().size.y * 0.5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		var xf: Transform3D = xforms[i]
		if y_sink > 0.0:
			xf.origin.y -= y_sink
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mmi)
	_ground_mm[prefix + key + "_decor"] = mm


## Obtiene la malla del tronco caído cargando el modelo 'tronco_caido' (GLTF).
func _build_shared_log_mesh() -> Mesh:
	return _extract_mesh_from_model("tronco_caido")


## Combina recursivamente todos los MeshInstance3D de un nodo en un único ArrayMesh
## preservando transforms locales y materiales por superficie (ideal para MultiMesh).
func _combine_node_meshes(node: Node3D) -> ArrayMesh:
	if node == null:
		return null
	var final_mesh := ArrayMesh.new()
	var mesh_instances: Array[MeshInstance3D] = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is MeshInstance3D and (curr as MeshInstance3D).mesh != null:
			mesh_instances.append(curr as MeshInstance3D)
		for child in curr.get_children():
			stack.append(child)

	if mesh_instances.is_empty():
		return null

	for mi in mesh_instances:
		var m: Mesh = mi.mesh
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != node:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()

		for surf_idx in range(m.get_surface_count()):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.append_from(m, surf_idx, xf)
			var mat: Material = mi.material_override
			if mat == null:
				mat = m.surface_get_material(surf_idx)
			st.index()
			st.commit(final_mesh)
			var new_surf_idx: int = final_mesh.get_surface_count() - 1
			if new_surf_idx >= 0 and mat != null:
				final_mesh.surface_set_material(new_surf_idx, mat)
	return final_mesh


## Extrae la malla combinada de un modelo cargado con ModelLoader (.tscn / .gltf).
func _extract_mesh_from_model(model_name: String) -> Mesh:
	var node := ModelLoader.load_model(model_name)
	if node != null:
		var combined := _combine_node_meshes(node)
		if combined != null and combined.get_surface_count() > 0:
			return combined
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			return (node as MeshInstance3D).mesh
		for child in node.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
				return (child as MeshInstance3D).mesh
			for sub in child.get_children():
				if sub is MeshInstance3D and (sub as MeshInstance3D).mesh != null:
					return (sub as MeshInstance3D).mesh
	return null


## Obtiene la malla de la cantera/roca u oro cargando exclusivamente los modelos GLTF ('roca', 'roca_gastada', 'oro', 'oro_gastado').
func _build_shared_rock_mesh(is_gold: bool, is_worn: bool = false) -> Mesh:
	var model_name: String
	if is_gold:
		model_name = "oro_gastado" if is_worn else "oro"
	else:
		model_name = "roca_gastada" if is_worn else "roca"
	var rock_node := ModelLoader.load_model(model_name)
	if rock_node != null:
		var mi: MeshInstance3D = null
		if rock_node is MeshInstance3D:
			mi = rock_node as MeshInstance3D
		else:
			for child in rock_node.get_children():
				if child is MeshInstance3D:
					mi = child as MeshInstance3D
					break
		if mi != null and mi.mesh != null:
			return mi.mesh
	return null


## Hornea la geometría de las vacas lecheras (familia de vacas con manchas, cuernos y ubres).
func _build_shared_cow_mesh() -> ArrayMesh:
	return GenericMarkers.build_cow_mesh()


## Hornea la geometría de la granja de cerdos (familia de cerdos con comedero y manzanas).
func _build_shared_pig_mesh() -> ArrayMesh:
	return GenericMarkers.build_pig_mesh()


func _build_shared_cattle_mesh() -> ArrayMesh:
	return GenericMarkers.build_cow_mesh()


## Obtiene la malla de la lápida cargando el modelo detallado lapida.tscn (con vela encendida,
## flores moradas, losa arqueada, base y cruz en relieve).
func _build_shared_tombstone_mesh() -> Mesh:
	var mesh := _extract_mesh_from_model("lapida")
	if mesh != null:
		return mesh
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.55, 0.54, 0.52)
	stone_mat.roughness = 0.95
	var mark_mat := StandardMaterial3D.new()
	mark_mat.albedo_color = Color(0.38, 0.37, 0.35)
	mark_mat.roughness = 0.95

	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_mark := SurfaceTool.new()
	st_mark.begin(Mesh.PRIMITIVE_TRIANGLES)

	var slight_tilt := Basis(Vector3.FORWARD, deg_to_rad(5.0))

	var base := BoxMesh.new()
	base.size = Vector3(0.22, 0.06, 0.13)
	st_stone.append_from(base, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0)))

	var slab := BoxMesh.new()
	slab.size = Vector3(0.24, 0.32, 0.05)
	st_stone.append_from(slab, 0, Transform3D(slight_tilt, Vector3(0.0, 0.06 + 0.16, 0.0)))

	var cross_v := BoxMesh.new()
	cross_v.size = Vector3(0.03, 0.14, 0.01)
	st_mark.append_from(cross_v, 0, Transform3D(slight_tilt, Vector3(0.0, 0.06 + 0.24, 0.028)))
	var cross_h := BoxMesh.new()
	cross_h.size = Vector3(0.11, 0.03, 0.01)
	st_mark.append_from(cross_h, 0, Transform3D(slight_tilt, Vector3(0.0, 0.06 + 0.22, 0.028)))

	var array_mesh := ArrayMesh.new()
	st_stone.index()
	st_stone.commit(array_mesh)
	st_mark.index()
	st_mark.commit(array_mesh)
	array_mesh.surface_set_material(0, stone_mat)
	array_mesh.surface_set_material(1, mark_mat)
	return array_mesh


## Hornea, UNA sola vez, un esqueleto de animal simplificado (columna + costillas
## en arco + cráneo con hocico + un par de huesos sueltos) para la decoración MUY
## puntual del Yelmo/Desierto. Sin modelo .glb/.gltf propio: mismo patrón
## procedural que _build_shared_tombstone_mesh/_build_shared_cattle_mesh.
func _build_shared_skeleton_mesh() -> ArrayMesh:
	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.86, 0.82, 0.7)
	bone_mat.roughness = 0.85

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var spine := BoxMesh.new()
	spine.size = Vector3(0.42, 0.025, 0.03)
	st.append_from(spine, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 0.0)))

	for i in range(5):
		var t: float = float(i) / 4.0
		var sx: float = -0.16 + t * 0.32
		var rib := CylinderMesh.new()
		rib.top_radius = 0.006
		rib.bottom_radius = 0.01
		rib.height = 0.16
		for side in [-1.0, 1.0]:
			var tilt := Basis(Vector3.FORWARD, deg_to_rad(55.0 * side)) * Basis(Vector3.UP, deg_to_rad(90.0))
			var rib_xform := Transform3D(tilt, Vector3(sx, 0.03, 0.05 * side))
			st.append_from(rib, 0, rib_xform)

	var skull := SphereMesh.new()
	skull.radius = 0.055
	skull.height = 0.09
	st.append_from(skull, 0, Transform3D(Basis.IDENTITY, Vector3(-0.24, 0.05, 0.0)))
	var snout := BoxMesh.new()
	snout.size = Vector3(0.06, 0.035, 0.035)
	st.append_from(snout, 0, Transform3D(Basis.IDENTITY, Vector3(-0.30, 0.03, 0.0)))

	for lx in [-0.05, 0.12]:
		var leg := CylinderMesh.new()
		leg.top_radius = 0.012
		leg.bottom_radius = 0.016
		leg.height = 0.22
		var leg_xform := Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)) * Basis(Vector3.FORWARD, deg_to_rad(15.0)), Vector3(lx, 0.014, 0.14))
		st.append_from(leg, 0, leg_xform)

	var array_mesh := ArrayMesh.new()
	st.index()
	st.commit(array_mesh)
	array_mesh.surface_set_material(0, bone_mat)
	return array_mesh


## Material (ShaderMaterial) del suelo para un grupo de terreno: textura + tinte +
## desplazamiento de UV (agua) + emisión (orilla). La niebla la aplica el COLOR de
## instancia que multiplica ALBEDO/EMISSION en el shader.
func _make_ground_material(group: String) -> ShaderMaterial:
	if _ground_mat_cache.has(group):
		return _ground_mat_cache[group]
	var mat := ShaderMaterial.new()
	mat.shader = _ground_shader
	var code: String = GROUND_GROUP_TERRAIN_CODE.get(group, group)
	var tex: Texture2D = _tex_tile_pradera
	var tint := Color.WHITE
	var rough := 0.85
	var uv_scroll := Vector2.ZERO
	var wave := 0.0
	var emis := Color.BLACK
	var emis_e := 0.0
	var emis_p := 0.0
	# 100% DATA-DRIVEN (data/world_terrains/<code>.json), sin excepciones cableadas:
	# resuelve textura/tinte/rugosidad/emisión/movimiento desde la ficha del código
	# (mar/orilla/nieve/yelmo/tierra/arena/montaña incluidos). Si no hay ficha
	# (código desconocido), cae en pradera.
	var tdef := Design.get_terrain_def(code)
	if not tdef.is_empty():
		if tdef.has("texture"):
			tex = _texture_for_key(String(tdef["texture"]))
		if tdef.has("tint"):
			tint = _hex_color(String(tdef["tint"])) * float(tdef.get("tint_boost", 1.0))
		if tdef.has("roughness"):
			rough = float(tdef["roughness"])
		if tdef.has("emission"):
			emis = _hex_color(String(tdef["emission"]))
			emis_e = float(tdef.get("emission_energy", 1.0))
		emis_p = float(tdef.get("emission_pulse", 0.0))
		if tdef.has("uv_scroll"):
			var us: Array = tdef["uv_scroll"]
			uv_scroll = Vector2(float(us[0]), float(us[1]))
		wave = float(tdef.get("wave", 0.0))
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("rough", rough)
	mat.set_shader_parameter("metal", 0.0)
	mat.set_shader_parameter("uv_scroll", uv_scroll)
	mat.set_shader_parameter("wave_amp", wave)
	mat.set_shader_parameter("emis_color", emis)
	mat.set_shader_parameter("emis_energy", emis_e)
	mat.set_shader_parameter("emis_pulse", emis_p)
	# Destello de sol: solo agua real (grupos "sea"/"shore"), no lava ni el
	# resto de terrenos con uv_scroll. Arranca en 0; WorldEnvironmentController
	# lo sincroniza con TimeManager.daylight_factor() en cada refresco de luz
	# (busca estos mismos materiales por nombre de grupo en _ground_mat_cache).
	mat.set_shader_parameter("sun_specular", 0.0)
	_ground_mat_cache[group] = mat
	return mat


## Textura base de la losa según el TERRENO. 100% DATA-DRIVEN (data/world_terrains/
## <code>.json): sin excepciones cableadas, misma fuente que _make_ground_material.
func _get_base_texture(cell: CellResource) -> Texture2D:
	var tdef := Design.get_terrain_def(cell.terrain)
	if not tdef.is_empty() and tdef.has("texture"):
		return _texture_for_key(String(tdef["texture"]))
	return _tex_tile_pradera


## Mapea una CLAVE de textura de data/world_terrains/<code>.json a la textura cargada
## correspondiente. Admite dos formatos (editable 100% desde WorldTerrainsManager):
##   · una CLAVE preestablecida ("sea"/"sand"/"mountain"/"snow"/"yelmo"/"pradera").
##   · una RUTA "res://..." a cualquier imagen que el usuario haya añadido al
##     proyecto (assets/world/map/…): se carga en caliente, sin tocar GDScript.
func _texture_for_key(key: String) -> Texture2D:
	if key.begins_with("res://"):
		if ResourceLoader.exists(key):
			var custom: Resource = load(key)
			if custom is Texture2D:
				return custom
		return _tex_tile_pradera
	match key:
		"sea":      return _tex_tile_sea
		"sand", "des", "desierto": return _tex_tile_sand
		"mountain", "mnt": return _tex_tile_mountain
		"snow":     return _tex_tile_snow
		"yelmo", "bad": return _tex_tile_yelmo
		"ice", "icy": return _tex_tile_ice
		"lava", "lav": return _tex_tile_lava
		"contaminacion", "pol", "tox": return _tex_tile_contaminacion
		"ground", "gnd": return _tex_tile_ground
		"beach", "playa", "are": return _tex_tile_beach
		"templo", "stone", "pth", "camino": return _tex_tile_templo
	return _tex_tile_pradera


## Parsea un color "#rrggbb" con fallback a blanco si es inválido.
func _hex_color(s: String) -> Color:
	if s.begins_with("#"):
		return Color.html(s)
	return Color.WHITE


## Crea el marcador de una localización en 3D — extraído a
## buildings/GenericMarkers.gd (GenericMarkers.make_marker(cell)).


func _cell_to_world(coord: Vector2i) -> Vector3:
	return Vector3(float(coord.x) * TILE, 0.0, float(coord.y) * TILE)


#endregion

#region NIEBLA DE GUERRA — aplicada a materiales (oculto / penumbra / visible)
# Extraído a interactive/WorldFogRenderer.gd (niebla de guerra + visibilidad de
# marcadores/decoración por MultiMesh + colisión de recursos agotados).
#endregion

#region PATHFINDING Y GATING
## Cache de MUROS CONDICIONADOS activos (gating). Cada entrada: { coord, dir }.
## Se recalcula solo sobre las casillas con puertas (pre-indexadas en _gate_coords),
## con coste ínfimo por paso.
var _active_gates: Array = []
var _gate_coords: Array[Vector2i] = []
var _gate_coords_indexed: bool = false


## Recalcula qué puertas/muros están BLOQUEADAS ahora mismo (según sus condiciones).
func _recompute_gates() -> void:
	if not _gate_coords_indexed:
		_gate_coords_indexed = true
		_gate_coords.clear()
		for coord: Vector2i in GlobalState.hexagons_db.keys():
			var cell: CellResource = GlobalState.hexagons_db[coord] as CellResource
			if cell != null and cell.gate is Dictionary and not cell.gate.is_empty():
				_gate_coords.append(coord)
	if _gate_coords.is_empty():
		if not _active_gates.is_empty():
			_active_gates.clear()
			_rebuild_gate_auroras()
		return
	_active_gates.clear()
	for coord in _gate_coords:
		var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
		if cell == null:
			continue
		if cell.gate is Dictionary and not cell.gate.is_empty() and Design.is_gate_locked(cell.gate):
			_active_gates.append({"coord": coord, "dir": String(cell.gate.get("dir", "east"))})
	_rebuild_gate_auroras()


## Repinta la "aurora" (cortina de luz ondulante) sobre cada muro condicionado
## BLOQUEADO, para que el jugador vea que ahí hay una barrera invisible. Solo
## reconstruye la geometría si el conjunto de puertas activas cambió desde la
## última vez (coste cero en el caso normal, que es la mayoría de los pasos).
func _rebuild_gate_auroras() -> void:
	var key_parts: Array[String] = []
	for g in _active_gates:
		var c: Vector2i = g["coord"]
		key_parts.append("%d,%d:%s" % [c.x, c.y, String(g["dir"])])
	var key := ";".join(key_parts)
	if key == _gate_visual_key:
		return
	_gate_visual_key = key
	for v in _active_gate_visuals:
		if is_instance_valid(v):
			v.queue_free()
	_active_gate_visuals.clear()
	if _tiles_root == null:
		return
	const AURORA_HEIGHT: float = 2.4
	const AURORA_WIDTH: float = TILE * 3.0
	const AURORA_THICK: float = 0.06
	for g in _active_gates:
		var c: Vector2i = g["coord"]
		var cx := float(c.x) * TILE
		var cz := float(c.y) * TILE
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		match String(g["dir"]):
			"east":
				box.size = Vector3(AURORA_THICK, AURORA_HEIGHT, AURORA_WIDTH)
				mesh_inst.position = Vector3(cx + TILE * 0.5, AURORA_HEIGHT * 0.5, cz)
			"west":
				box.size = Vector3(AURORA_THICK, AURORA_HEIGHT, AURORA_WIDTH)
				mesh_inst.position = Vector3(cx - TILE * 0.5, AURORA_HEIGHT * 0.5, cz)
			"south":
				box.size = Vector3(AURORA_WIDTH, AURORA_HEIGHT, AURORA_THICK)
				mesh_inst.position = Vector3(cx, AURORA_HEIGHT * 0.5, cz + TILE * 0.5)
			_:   # "north" (y cualquier valor no reconocido, por seguridad)
				box.size = Vector3(AURORA_WIDTH, AURORA_HEIGHT, AURORA_THICK)
				mesh_inst.position = Vector3(cx, AURORA_HEIGHT * 0.5, cz - TILE * 0.5)
		mesh_inst.mesh = box
		var mat := ShaderMaterial.new()
		mat.shader = _gate_aurora_shader
		mesh_inst.material_override = mat
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_tiles_root.add_child(mesh_inst)
		_active_gate_visuals.append(mesh_inst)


## ¿Un movimiento de `from` a `to` cruza el lado bloqueado de algún muro activo?
## El muro abarca 3 casillas (la puerta ± sus 2 vecinas perpendiculares a `dir`),
## de modo que no se puede rodear. Solo bloquea el sentido "hacia `dir`" (se puede
## retroceder). Con pasos pequeños de movimiento basta comprobar el cruce del borde.
func _movement_blocked_by_gate(from: Vector3, to: Vector3) -> bool:
	if _active_gates.is_empty():
		return false
	for g in _active_gates:
		var c: Vector2i = g["coord"]
		var cx := float(c.x) * TILE
		var cz := float(c.y) * TILE
		match String(g["dir"]):
			"east":
				var bx := cx + TILE * 0.5
				if from.x < bx and to.x >= bx and absf(to.z - cz) <= TILE * 1.5:
					return true
			"west":
				var bx := cx - TILE * 0.5
				if from.x > bx and to.x <= bx and absf(to.z - cz) <= TILE * 1.5:
					return true
			"north":
				var bz := cz - TILE * 0.5
				if from.z > bz and to.z <= bz and absf(to.x - cx) <= TILE * 1.5:
					return true
			"south":
				var bz := cz + TILE * 0.5
				if from.z < bz and to.z >= bz and absf(to.x - cx) <= TILE * 1.5:
					return true
	return false


func is_cell_passable(coord: Vector2i) -> bool:
	if not GlobalState.hexagons_db.has(coord):
		return false

	var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
	if cell == null:
		return false

	# Navegando en el BARCO: solo costa/mar son transitables (NUNCA tierra, montañas, etc.)
	# Se evalúa antes que el Modo Debug para que las físicas del barco siempre se respeten.
	if GlobalState.is_sailing:
		if cell.terrain != "sea" and cell.terrain != "cst":
			return false
		return true

	# Bloqueo de crisis: Mientras el Jefe del Puerto esté atacando, no se puede abandonar la Zona 4
	if GlobalState.has_world_flag("boss_puerto_activo") and not GlobalState.has_world_flag("boss_puerto_derrotado"):
		var current_z := Design.get_zone_at(player_pos)
		var target_z := Design.get_zone_at(coord)
		if String(current_z.get("id", "")) == "zona_4_celestia" and String(target_z.get("id", "")) != "zona_4_celestia":
			var msg := "¿A dónde vas? ¿Acaso vas a huir? ¡Ve y mátalo cobarde!"
			if OrbBarksManager != null:
				OrbBarksManager.trigger_story_popup(msg, 4.5)
			else:
				_spawn_world_float(msg, UiKit.WARN)
			return false

	# En Modo Debug el héroe a pie atraviesa CUALQUIER casilla del mapa (mar, montaña o
	# muros de misión) para poder inspeccionar el mundo sin trabas.
	if GlobalState.debug_mode:
		return true

	# El gating es 100% DATA-DRIVEN por celda (`required_quest_state`, editable
	# desde el editor de mapas).
	if not cell.is_walkable_terrain():
		return false
	if cell.required_quest_state != "" and not QuestManager.is_quest_at_least(cell.required_quest_state):
		return false
	return true


#endregion

#region INPUT — MOVIMIENTO LIBRE (joystick táctil + teclado) y botón ENTRAR
func _unhandled_input(event: InputEvent) -> void:
	if _is_cinematic_active or GlobalState.is_movement_locked:
		return
	if not is_visible_in_tree():
		return
	if SceneRunner.is_active():
		return
	if OrbCompanionOverlay != null and OrbCompanionOverlay.is_modal_active():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if GlobalState.debug_mode and event.keycode >= KEY_1 and event.keycode <= KEY_8:
			var zone_num: int = int(event.keycode - KEY_1 + 1)
			DebugToolbar.warp_to_zone(zone_num, self)
			return
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if _btn_enter.visible:
				_on_enter_pressed()
			elif _btn_gather.visible:
				_on_gather_pressed()
		return


## Valida que el gesto fue un tap (breve y sin arrastre) y, si el punto tocado cae
## en una casilla transitable, calcula la ruta por rejilla hexagonal hacia ese punto exacto.
func _try_tap_move(release_pos: Vector2) -> void:
	if OrbCompanionOverlay != null and OrbCompanionOverlay.is_modal_active():
		return
	if _is_pos_over_ui(release_pos) or _is_pos_over_ui(_touch_start_pos):
		return
	var hit := _screen_to_world_point(release_pos)
	if hit.x > 90000.0:
		return
	var coord := _world_to_cell(hit)
	var start_coord := _world_to_cell(_player.position)
	var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
	if cell != null and (cell.chest is Dictionary and not cell.chest.is_empty()):
		if start_coord == coord or (absi(start_coord.x - coord.x) <= 1 and absi(start_coord.y - coord.y) <= 1):
			_check_and_open_world_chest(coord, cell)
			return
	if cell != null and (start_coord == coord or (absi(start_coord.x - coord.x) <= 1 and absi(start_coord.y - coord.y) <= 1)):
		if _check_and_trigger_cell_cinematic(coord, cell, false):
			return
	_move_path = _find_hex_path(start_coord, coord, hit)
	if not _move_path.is_empty():
		_move_target = hit
		_has_move_target = true
		_stuck_timer = 0.0
		_show_destination_marker(hit)
	else:
		_clear_move_target()


## Proyecta un punto de pantalla al plano del suelo 3D (y=0) teniendo en cuenta
## la posición y escala real del SubViewportContainer dentro de la interfaz.
func _screen_to_world_point(screen_pos: Vector2) -> Vector3:
	if not is_instance_valid(_cam) or not is_instance_valid(_sub_viewport) or not is_instance_valid(_vp_container):
		return Vector3(99999.0, 99999.0, 99999.0)
	var local_pos := screen_pos - _vp_container.global_position
	var vp_size := _vp_container.size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return Vector3(99999.0, 99999.0, 99999.0)
	if _sub_viewport.size != Vector2i(vp_size):
		var scale_factor := Vector2(_sub_viewport.size) / vp_size
		local_pos *= scale_factor

	var from: Vector3 = _cam.project_ray_origin(local_pos)
	var dir: Vector3 = _cam.project_ray_normal(local_pos)
	if absf(dir.y) < 0.00001:
		return Vector3(99999.0, 99999.0, 99999.0)
	var t: float = -from.y / dir.y
	if t < 0.0:
		return Vector3(99999.0, 99999.0, 99999.0)
	return from + dir * t


func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var hit := _screen_to_world_point(screen_pos)
	if hit.x > 90000.0:
		return Vector2i(-9999, -9999)
	return _world_to_cell(hit)


## Cancela el destino de "ir a la casilla" (lo llama el joystick/teclado al tomar
## el control, o al llegar/quedar bloqueado).
func _clear_move_target() -> void:
	_has_move_target = false
	_move_path.clear()
	_stuck_timer = 0.0
	_hide_destination_marker()


## Marcador gráfico flotante para indicar el punto exacto tocado por el usuario.
func _setup_destination_marker(parent: Node3D) -> void:
	_destination_marker = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.48
	_destination_marker.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.95, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.9, 1.0)
	mat.emission_energy_multiplier = 2.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_destination_marker.material_override = mat
	_destination_marker.visible = false
	parent.add_child(_destination_marker)


func _show_destination_marker(pos: Vector3) -> void:
	if _destination_marker == null:
		return
	_destination_marker.position = Vector3(pos.x, 0.06, pos.z)
	_destination_marker.visible = true
	_destination_marker.scale = Vector3(0.4, 0.4, 0.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_destination_marker, "scale", Vector3(1.0, 1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_destination_marker() -> void:
	if _destination_marker == null or not is_instance_valid(_destination_marker) or not _destination_marker.visible:
		return
	var tw := create_tween()
	tw.tween_property(_destination_marker, "scale", Vector3(0.2, 0.2, 0.2), 0.16)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_destination_marker):
			_destination_marker.visible = false
	)


#region BARCO — navegación por costa/mar (ver GlobalState.boat_pos/is_sailing)
## Modelo procedural simple del BARCO (casco + mástil + vela): reutilizado tanto
## para el marcador aparcado en el mapa como para la silueta que sustituye al
## personaje mientras se navega.
func _build_boat_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "BoatVisual"
	# Girar 90° en Y para que la proa/popa quede alineada con el eje Z (dirección de avance)
	root.rotation_degrees.y = 90.0

	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(1.1, 0.32, 0.55)
	hull.mesh = hull_mesh
	hull.position = Vector3(0.0, 0.16, 0.0)
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.42, 0.27, 0.14)
	hull.material_override = hull_mat
	root.add_child(hull)

	var mast := MeshInstance3D.new()
	var mast_mesh := CylinderMesh.new()
	mast_mesh.top_radius = 0.035
	mast_mesh.bottom_radius = 0.035
	mast_mesh.height = 1.1
	mast.mesh = mast_mesh
	mast.position = Vector3(0.0, 0.85, 0.0)
	var mast_mat := StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.30, 0.20, 0.10)
	mast.material_override = mast_mat
	root.add_child(mast)

	var sail := MeshInstance3D.new()
	var sail_mesh := PrismMesh.new()
	sail_mesh.size = Vector3(0.55, 0.75, 0.02)
	sail.mesh = sail_mesh
	sail.position = Vector3(0.0, 0.85, 0.0)
	# La vela no necesita rotación local adicional: el root ya gira 90° en Y,
	# por lo que la vela queda perpendicular al eje de avance (correcto).
	sail.rotation.y = 0.0
	var sail_mat := StandardMaterial3D.new()
	sail_mat.albedo_color = Color(0.96, 0.94, 0.88)
	sail.material_override = sail_mat
	root.add_child(sail)

	return root


## Reposiciona/oculta el marcador del barco APARCADO según el estado actual:
## visible en `GlobalState.boat_pos` solo mientras nadie lo esté navegando.
func _refresh_boat_marker() -> void:
	if _boat_parked_marker == null or not is_instance_valid(_boat_parked_marker):
		return
	# Si boat_obtained está activo pero boat_pos es inválido, inicializamos.
	if GlobalState.has_world_flag("boat_obtained") and GlobalState.boat_pos == Vector2i(-1, -1):
		GlobalState.spawn_boat_at_port()
	if GlobalState.is_sailing or GlobalState.boat_pos == Vector2i(-1, -1) or not GlobalState.has_world_flag("boat_obtained"):
		_boat_parked_marker.visible = false
		return
	# Elevar el marcador a altura de suelo para que sea visible sobre el agua
	var world_pos := _cell_to_world(GlobalState.boat_pos)
	_boat_parked_marker.position = Vector3(world_pos.x, GROUND_TOP, world_pos.z)
	_boat_parked_marker.visible = true


## Alterna el aspecto del personaje entre su modelo humano y la silueta del
## barco (y refresca el marcador aparcado, que se oculta mientras se navega).
func _set_boat_visual(sailing: bool) -> void:
	if is_instance_valid(_player_mesh):
		_player_mesh.visible = not sailing
	if is_instance_valid(_boat_rider_visual):
		_boat_rider_visual.visible = sailing
	_refresh_boat_marker()


## El jugador ha pisado la casilla del barco aparcado: se oculta el personaje y
## pasamos a controlar el barco (solo transitable por costa/mar; ver
## `is_cell_passable`). Ver también `_disembark_boat`.
func _board_boat() -> void:
	GlobalState.is_sailing = true
	_set_boat_visual(true)
	_spawn_world_float(Locale.t("boat_boarded"), UiKit.ACCENT_SOFT)
	SaveManager.request_autosave()


## Desembarca del barco: reaparece el personaje en una casilla adyacente que no
## sea mar/montaña ni esté ocupada por un obstáculo sólido; el barco se queda
## aparcado en su casilla actual (debe ser costa), listo para volver a abordarlo.
func _disembark_boat() -> void:
	if not GlobalState.is_sailing:
		return
	var boat_coord := _current_cell
	var landing := Vector2i(-9999, -9999)
	for nc in GlobalState.get_surrounding_hex_coords(boat_coord):
		var nb: CellResource = GlobalState.hexagons_db.get(nc, null) as CellResource
		if nb != null and nb.terrain != "sea" and nb.terrain != "mnt" and not nb.is_solid():
			landing = nc
			break
	if landing == Vector2i(-9999, -9999):
		_spawn_world_float(Locale.t("boat_no_landing"), UiKit.HP)
		return
	AudioManager.play_sfx("click")
	GlobalState.boat_pos = boat_coord
	GlobalState.is_sailing = false
	_set_boat_visual(false)
	teleport_player_to(landing)
	SaveManager.request_autosave()
#endregion


## Busca la ruta más corta A* a través de la rejilla hexagonal evitando colisiones.
func _find_hex_path(start: Vector2i, target: Vector2i, final_hit: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if start == target:
		result.append(final_hit)
		return result

	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0.0 }
	var f_score: Dictionary = { start: float(_cheby(start, target)) }

	var iterations := 0
	var max_iterations := 400

	while open_set.size() > 0 and iterations < max_iterations:
		iterations += 1
		var current: Vector2i = open_set[0]
		var lowest_f: float = f_score.get(current, 999999.0)
		for i in range(1, open_set.size()):
			var node: Vector2i = open_set[i]
			var f_val: float = f_score.get(node, 999999.0)
			if f_val < lowest_f:
				lowest_f = f_val
				current = node

		if current == target:
			var path_coords: Array[Vector2i] = [target]
			var curr_step := target
			while came_from.has(curr_step):
				curr_step = came_from[curr_step]
				if curr_step != start:
					path_coords.push_front(curr_step)
			for c in path_coords:
				result.append(_cell_to_world(c))
			if result.size() > 0:
				result[result.size() - 1] = final_hit
			return result

		open_set.erase(current)
		var current_g: float = g_score.get(current, 999999.0)

		for neighbor in GlobalState.get_surrounding_hex_coords(current):
			if not is_cell_passable(neighbor):
				continue
			var cell: CellResource = GlobalState.hexagons_db.get(neighbor, null) as CellResource
			if cell and cell.is_solid() and neighbor != target:
				continue
			var tentative_g: float = current_g + 1.0
			if tentative_g < g_score.get(neighbor, 999999.0):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + float(_cheby(neighbor, target))
				if not open_set.has(neighbor):
					open_set.append(neighbor)

	# No se encontró ruta al objetivo (bloqueado o fuera de alcance).
	# Cuando se navega en barco, NO forzar el último hit como waypoint: si el
	# destino es tierra, devolver [] para que _move_path.is_empty() lo cancele.
	if GlobalState.is_sailing:
		return result
	result.append(final_hit)
	return result


var _overworld_footsteps_player: AudioStreamPlayer = null
var _overworld_is_stepping: bool = false


func _update_overworld_footsteps(is_moving: bool) -> void:
	_overworld_is_stepping = is_moving
	if _overworld_footsteps_player == null:
		_overworld_footsteps_player = AudioStreamPlayer.new()
		var stream := load("res://assets/common/sfx/sfx_footsteps_walking.wav") as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			if stream.data.size() > 0:
				stream.loop_end = stream.data.size()
		_overworld_footsteps_player.stream = stream
		_overworld_footsteps_player.bus = "Master"
		_overworld_footsteps_player.finished.connect(func() -> void:
			if _overworld_is_stepping and _overworld_footsteps_player != null and is_instance_valid(_overworld_footsteps_player):
				_overworld_footsteps_player.play()
		)
		add_child(_overworld_footsteps_player)

	if is_moving:
		if not _overworld_footsteps_player.playing:
			_overworld_footsteps_player.play()
	else:
		if _overworld_footsteps_player.playing:
			_overworld_footsteps_player.stop()


## Mueve el héroe libremente (joystick/teclado) o siguiendo la ruta por hitos (tap).
func _apply_free_movement(delta: float) -> void:
	if _is_cinematic_active or SceneRunner.is_active() or GlobalState.is_movement_locked:
		is_traveling = false
		_clear_move_target()
		_update_overworld_footsteps(false)
		return

	var dir: Vector2 = Vector2.ZERO
	var kb: Vector2 = _keyboard_dir()
	if _sliding:
		dir = _slide_dir
		_clear_move_target()
	elif kb.length() > 0.01:
		dir = kb
		_clear_move_target()
		_joy_active = false
	elif _joy_active:
		dir = _joy_vec
		_clear_move_target()
	elif _has_move_target:
				if _move_path.size() > 0:
					var next_wp: Vector3 = _move_path[0]
					var to := Vector2(next_wp.x - _player.position.x, next_wp.z - _player.position.z)
					var dist: float = to.length()
					var threshold: float = 0.18 if _move_path.size() == 1 else 0.45
					if dist <= threshold:
						_move_path.remove_at(0)
						if _move_path.is_empty():
							_clear_move_target()
						else:
							next_wp = _move_path[0]
							to = Vector2(next_wp.x - _player.position.x, next_wp.z - _player.position.z)
							dir = to
					else:
						dir = to
				else:
					_clear_move_target()

	if dir.length() > 1.0:
		dir = dir.normalized()
	if dir.length() < 0.12:
		is_traveling = false
		_update_overworld_footsteps(false)
		return

	is_traveling = true
	_update_overworld_footsteps(is_visible_in_tree() and not _is_cinematic_active and not SceneRunner.is_active() and not GlobalState.is_sailing)
	var cur_cell: CellResource = GlobalState.hexagons_db.get(_current_cell, null) as CellResource
	# Sobre hielo resbaladizo no se permiten diagonales: forzar siempre sobre eje X o eje Y
	if cur_cell != null and Design.terrain_is_slippery(cur_cell.terrain) and dir.length_squared() > 0.01:
		if absf(dir.x) >= absf(dir.y):
			dir = Vector2(signf(dir.x) if not is_zero_approx(dir.x) else 1.0, 0.0)
		else:
			dir = Vector2(0.0, signf(dir.y) if not is_zero_approx(dir.y) else 1.0)

	_last_move_dir = dir

	var speed: float = MOVE_SPEED * (GlobalState.debug_speed_mult if GlobalState.debug_mode else 1.0)
	if cur_cell:
		speed *= Design.terrain_speed_mult(cur_cell.terrain)
	var step: float = speed * delta
	var pos: Vector3 = _player.position
	var start_pos := pos

	var nx: Vector3 = pos + Vector3(dir.x * step, 0.0, 0.0)
	if _is_world_pos_walkable(nx) and not _movement_blocked_by_gate(pos, nx):
		pos.x = nx.x
	var from_z := pos
	var nz: Vector3 = Vector3(pos.x, 0.0, pos.z + dir.y * step)
	if _is_world_pos_walkable(nz) and not _movement_blocked_by_gate(from_z, nz):
		pos.z = nz.z
	_player.position = pos

	if _has_move_target:
		if pos.distance_to(start_pos) < step * 0.1:
			_stuck_timer += delta
			if _stuck_timer > 0.4:
				_clear_move_target()
		else:
			_stuck_timer = 0.0

	_phys_controller.maybe_stop_slide(pos, start_pos, step)

	_facing = atan2(dir.x, dir.y)
	_player.rotation.y = lerp_angle(_player.rotation.y, _facing, clampf(delta * 10.0, 0.0, 1.0))

	_enter_cell_if_changed()


## Dirección de teclado (WASD / flechas) como Vector2 (x = este, y = sur).
func _keyboard_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  d.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): d.x += 1.0
	return d


func _world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / TILE), roundi(p.z / TILE))


## ¿La posición de mundo cae en una casilla transitable y no colisiona con el recuadro de montaña/ítem?
func _is_world_pos_walkable(p: Vector3) -> bool:
	# Navegando en barco: restringir estrictamente a costa y mar incluso en debug.
	if GlobalState.is_sailing:
		var sail_c := _world_to_cell(p)
		var sail_cell: CellResource = GlobalState.hexagons_db.get(sail_c, null) as CellResource
		return sail_cell != null and (sail_cell.terrain == "sea" or sail_cell.terrain == "cst")
	# En Modo Debug el héroe a pie atraviesa cualquier casilla
	if GlobalState.debug_mode:
		return true

	var cell_coord := _world_to_cell(p)
	if not is_cell_passable(cell_coord):
		return false

	var player_radius := 0.28
	var half_tile := TILE * 0.5

	# Colisión sólida con el recuadro completo (bounding box) de casillas de montaña/no transitables
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_coord := cell_coord + Vector2i(dx, dy)
			if not is_cell_passable(check_coord):
				var center := _cell_to_world(check_coord)
				if absf(p.x - center.x) < half_tile + player_radius and absf(p.z - center.z) < half_tile + player_radius:
					return false

	var player_cell := _world_to_cell(_player.position) if is_instance_valid(_player) else _current_cell
	var cur_c := _current_cell
	# Impedir traspasar el centro de ítems sólidos (ciudades, templos, canteras, bosques, etc.)
	var check_radius := 0.45
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_coord := cell_coord + Vector2i(dx, dy)
			if check_coord == player_cell or check_coord == cur_c:
				continue
			var cell: CellResource = GlobalState.hexagons_db.get(check_coord, null) as CellResource
			if cell and cell.is_solid():
				var center := _cell_to_world(check_coord)
				var dist_xz := Vector2(p.x - center.x, p.z - center.z).length()
				if dist_xz < check_radius:
					return false
	return true


## Si el jugador cruza a una casilla nueva: sincroniza estado, niebla y panel.
func _enter_cell_if_changed() -> void:
	var c: Vector2i = _world_to_cell(_player.position)
	if c == _current_cell:
		return
	var old_cell := _current_cell
	_current_cell = c
	player_pos = c
	GlobalState.player_pos = c
	# El jugador pisa la casilla del BARCO aparcado: lo aborda automáticamente.
	# Gating (Task1): sin el flag global "boat_obtained" (concedido por
	# port_master.json al zarpar con el Sello Real) el barco permanece inerte,
	# para impedir saltarse Gloriam/Arcanum navegando prematuramente.
	if not GlobalState.is_sailing and GlobalState.boat_pos != Vector2i(-1, -1) and c == GlobalState.boat_pos:
		if GlobalState.has_world_flag("boat_obtained"):
			_board_boat()
		else:
			_spawn_world_float(Locale.t("boat_locked_hint"), UiKit.HP)
	if _streamer != null:
		_streamer.update_active_chunks(self, c)   # streaming 3x3
	WorldFogRenderer.fog_step(self, old_cell, c) # niebla + visual incremental (solo el entorno del jugador)
	WorldFogRenderer.rebuild_nearby(self)      # subconjunto animado alrededor de la nueva casilla
	var cell: CellResource = GlobalState.hexagons_db.get(c, null) as CellResource
	if cell:
		_update_location_panel(cell)
		_update_ambience(cell)
		QuestManager.on_cell_entered(c, cell)
		if OrbCompanionManager != null:
			OrbCompanionManager.notify_step(c, old_cell, cell.terrain)
			if cell.item != "":
				OrbCompanionManager.trigger_bark("poi_discovered")
		# HIELO RESBALADIZO (data-driven, campo `slippery`): al ENTRAR se fuerza el
		# deslizamiento en la dirección con la que se entró; si la nueva casilla ya
		# no es resbaladiza, se restaura el control (salida "por el lado opuesto").
		# Delegado en `OverworldPhysicsController`.
		_phys_controller.apply_slippery_on_enter(cell)
		if cell.chest is Dictionary and not cell.chest.is_empty():
			_check_and_open_world_chest(c, cell)
		_check_and_trigger_cell_cinematic(c, cell, true)
	else:
		_phys_controller.apply_slippery_on_enter(null)
	_recompute_gates()   # refresca muros por si una condición cambió (p. ej. boss caído)
	WorldEnemies.check_enemy_contact(self)
	_check_puerto_crisis_event()   # ¿pisamos la casilla de un enemigo del mapamundi?


## AMBIENTE DATA-DRIVEN: resuelve música y clima de la casilla actual y los
## aplica (música solo si cambia; clima vía WeatherOverlay). Prioridad de resolución:
##   1) override de la propia casilla (cell.ambience = { music?, weather? }, desde ids.json)
##   2) ambiente por terreno (Design.get_terrain_ambience)
## Un valor "" o ausente = usar el defecto (música "world", sin clima).
func _update_ambience(cell: CellResource) -> void:
	_env_controller.update_ambience(cell)


## Devuelve el clima del terreno tirando por probabilidad SOLO la primera vez que
## se ve ese terreno (o tras un reset); luego lo sirve cacheado para que sea
## estable mientras recorres el bioma. La re-tirada global ocurre al cambiar de
## fase (ver _on_world_phase_changed → _reroll_weather).
func _resolve_terrain_weather(terrain: String) -> String:
	return _env_controller.resolve_terrain_weather(terrain)


## Re-tira el clima de todos los terrenos (p. ej. al cambiar día↔noche) y lo
## reaplica a la casilla actual para que el cambio se note de inmediato.
func _reroll_weather() -> void:
	_env_controller.reroll_weather()


#endregion

#region CICLO DÍA / NOCHE — ILUMINACIÓN (consume TimeManager.daylight_factor())
## Interpola la iluminación del mundo según la hora (TimeManager). `force` reaplica
## aunque el factor no haya cambiado (al construir la escena o volver al mundo).
## Delegado en `WorldEnvironmentController`.
func _apply_daynight_lighting(force: bool) -> void:
	_env_controller.apply_daynight_lighting(force)


#endregion

#region DAÑO AMBIENTAL POR TERRENO (data-driven: data/world_terrains/<code>.json)
## Aplica daño periódico mientras el jugador pisa un terreno peligroso (p. ej.
## lava o contaminación) y gestiona el envenenamiento persistente (5 segundos).
func _apply_terrain_hazard(delta: float) -> void:
	if GlobalState.hp <= 0:
		return
	var cell: CellResource = GlobalState.hexagons_db.get(_current_cell, null) as CellResource
	var tcode: String = cell.terrain if cell != null else ""
	var tdef: Dictionary = Design.get_terrain_def(tcode) if not tcode.is_empty() else {}
	
	# Si pisamos un terreno de contaminación / con veneno, refrescamos el temporizador de envenenamiento
	var p_dur: float = float(tdef.get("poison_duration", 5.0 if tcode == "pol" else 0.0))
	if p_dur > 0.0:
		_poison_timer = p_dur
		_poison_dps = float(tdef.get("damage", 4))
		if not GlobalState.is_poisoned:
			GlobalState.is_poisoned = true
			GlobalState.state_updated.emit()

	# 1. Daño directo por pisar baldosa peligrosa (Lava / Contaminación)
	var dmg: int = Design.terrain_damage(tcode)
	if dmg > 0:
		_hazard_accum += delta
		var interval: float = Design.terrain_damage_interval(tcode)
		if _hazard_accum >= interval:
			_hazard_accum -= interval
			GlobalState.hp = maxi(0, GlobalState.hp - dmg)
			GlobalState.state_updated.emit()
			AudioManager.play_sfx("hit")
			var float_icon: String = "☣️ -%d" % dmg if tcode == "pol" else "🔥 -%d" % dmg
			var float_col: Color = Color("39ff14") if tcode == "pol" else UiKit.HP
			_spawn_world_float(float_icon, float_col)
			if GlobalState.hp <= 0:
				# BUG: el daño directo por baldosa (lava/contaminación) nunca
				# comprobaba si la vida llegaba a 0, así que morir pisando lava
				# dejaba la vida en 0 sin disparar realmente la muerte (el único
				# camino que sí lo hacía era el DOT de veneno, más abajo).
				_hazard_accum = 0.0
				_poison_timer = 0.0
				GlobalState.is_poisoned = false
				GlobalState.state_updated.emit()
				if _poison_particles != null:
					_poison_particles.emitting = false
				GlobalState.pending_death_cause = {"cause": "hazard", "hazard_type": tcode}
				AudioManager.play_sfx("defeat")
				AudioManager.clear_stack()
				AudioManager.play_music("world")
				SceneManager.go_to_orb_room("death")
				return
	else:
		_hazard_accum = 0.0

	# 2. Daño por envenenamiento residual (DOT durante 5 segundos)
	if _poison_timer > 0.0:
		_poison_timer -= delta
		_poison_tick_accum += delta
		if not GlobalState.is_poisoned:
			GlobalState.is_poisoned = true
			GlobalState.state_updated.emit()
		
		if _poison_particles != null and not _poison_particles.emitting:
			_poison_particles.emitting = true

		# Tick de daño por segundo cuando no está pisando directamente la baldosa
		if _poison_tick_accum >= 1.0:
			_poison_tick_accum -= 1.0
			if tcode != "pol":
				var poison_dmg: int = int(_poison_dps) if _poison_dps > 0 else 4
				GlobalState.hp = maxi(0, GlobalState.hp - poison_dmg)
				GlobalState.state_updated.emit()
				AudioManager.play_sfx("hit")
				_spawn_world_float("☣️ -%d" % poison_dmg, Color("39ff14"))

		if GlobalState.hp <= 0:
			_poison_timer = 0.0
			_hazard_accum = 0.0
			GlobalState.is_poisoned = false
			GlobalState.state_updated.emit()
			if _poison_particles != null:
				_poison_particles.emitting = false
			GlobalState.pending_death_cause = {"cause": "hazard", "hazard_type": "poison"}
			AudioManager.play_sfx("defeat")
			AudioManager.clear_stack()
			AudioManager.play_music("world")
			SceneManager.go_to_orb_room("death")
	else:
		if GlobalState.is_poisoned:
			GlobalState.is_poisoned = false
			GlobalState.state_updated.emit()
		if _poison_particles != null and _poison_particles.emitting:
			_poison_particles.emitting = false


#endregion

#region RELOJ DEL MUNDO (UI del ciclo día/noche)
## Oculta el reloj sin desprenderlo de `HUDRightSlot` — usado por
## `GameRoot._update_hud_center_and_right_slots()` cuando la vista activa NO es
## una de las que deben mostrarlo (p. ej. mazmorra): al no destruirse nunca las
## vistas, sin esto quedaría visible "colgando" bajo el HUD de HP/MP/Oro.
## El botón de mapa YA NO vive aquí: es flotante junto al ☰ del menú radial
## (ver `GameRoot._build_floating_map_button`), y su visibilidad la gestiona
## GameRoot directamente.
func hide_clock_and_map() -> void:
	if _clock_panel != null and is_instance_valid(_clock_panel):
		_clock_panel.visible = false
	if _btn_map != null and is_instance_valid(_btn_map):
		_btn_map.visible = false


## Libera DEFINITIVAMENTE el reloj/botón de mapa: los desprende de su padre
## actual y los destruye. `attach_clock_and_map_to_slot()` los reparenta dentro
## del `HUDRightSlot` PERSISTENTE de `GameRoot` (fuera del árbol de este nodo),
## así que un simple `queue_free()` de esta instancia de `TabWorld3D` NUNCA los
## alcanza: quedaban huérfanos-pero-vivos colgando del HUD, y la SIGUIENTE
## instancia de `TabWorld3D` (`GameRoot._recreate_world_view()`, tras la
## cinemática de la presa) construía un segundo reloj/mapa en el mismo slot,
## mostrando dos relojes con horas distintas a la vez. Debe llamarse SIEMPRE
## antes de `queue_free()` en una instancia que vaya a descartarse.
func release_clock_and_map() -> void:
	if _btn_map != null and is_instance_valid(_btn_map):
		if _btn_map.get_parent() != null:
			_btn_map.get_parent().remove_child(_btn_map)
		_btn_map.queue_free()
	_btn_map = null
	if _clock_panel != null and is_instance_valid(_clock_panel):
		if _clock_panel.get_parent() != null:
			_clock_panel.get_parent().remove_child(_clock_panel)
		_clock_panel.queue_free()
	_clock_panel = null


## Adjunta el reloj dentro del contenedor del HUD superior. El botón de mapa
## ya no se dockea aquí (ver `ensure_map_button`/`GameRoot._build_floating_map_button`).
func attach_clock_and_map_to_slot(slot: HBoxContainer) -> void:
	if slot == null:
		return
	if _clock_panel == null or not is_instance_valid(_clock_panel):
		_build_clock()
	# BOOST VERTICAL (ver GameRoot._setup_redesigned_hud / _update_responsive_layout).
	var sz := get_viewport_rect().size
	var b := 2.1 if sz.y >= sz.x and sz.x > 0.0 else 1.0

	# Limpiar cualquier reloj o elemento huérfano previo para evitar duplicados en el slot
	for child in slot.get_children():
		if child != _clock_panel:
			slot.remove_child(child)
			child.queue_free()

	if _clock_panel != null and is_instance_valid(_clock_panel):
		if _clock_panel.get_parent() != slot:
			if _clock_panel.get_parent() != null:
				_clock_panel.get_parent().remove_child(_clock_panel)
			slot.add_child(_clock_panel)
		_clock_panel.custom_minimum_size = Vector2(130 * b, 40 * b)
		_clock_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_clock_panel.visible = true
	if _lbl_clock_icon != null and is_instance_valid(_lbl_clock_icon):
		_lbl_clock_icon.add_theme_font_size_override("font_size", roundi(22 * b))
	if _lbl_clock_time != null and is_instance_valid(_lbl_clock_time):
		_lbl_clock_time.add_theme_font_size_override("font_size", roundi(20 * b))
	_update_clock()


## Devuelve el botón de mapa (construyéndolo si aún no existe) para que
## `GameRoot` lo posicione como botón FLOTANTE junto al ☰ del menú radial, en
## vez de dockearlo dentro de la HUD (antes quedaba apretado entre la hora y
## los items a recoger, difícil de pulsar con el dedo).
func ensure_map_button() -> Button:
	if _btn_map != null and is_instance_valid(_btn_map):
		return _btn_map
	_btn_map = Button.new()
	_btn_map.text = "🗺️"
	_btn_map.custom_minimum_size = Vector2(44, 40)
	_btn_map.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "focus"]:
		_btn_map.add_theme_stylebox_override(st, UiKit.button_tonal(UiKit.ACCENT))
	_btn_map.add_theme_color_override("font_color", UiKit.TEXT)
	_btn_map.pressed.connect(_on_map_pressed)
	return _btn_map


## Construye el reloj compacto (icono de fase + "HH:MM").
func _build_clock() -> void:
	if _clock_panel != null and is_instance_valid(_clock_panel):
		if _clock_panel.get_parent() != null:
			_clock_panel.get_parent().remove_child(_clock_panel)
		_clock_panel.queue_free()
		_clock_panel = null

	_clock_panel = PanelContainer.new()
	_clock_panel.custom_minimum_size = Vector2(130, 40)
	_clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cp := UiKit.panel(UiKit.SURFACE, UiKit.BORDER, 10, 1)
	_clock_panel.add_theme_stylebox_override("panel", cp)

	var margin := UiKit.margins(10, 10, 4, 4)
	_clock_panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	margin.add_child(hb)

	_lbl_clock_icon = Label.new()
	_lbl_clock_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_clock_icon.add_theme_font_size_override("font_size", 22)
	hb.add_child(_lbl_clock_icon)

	_lbl_clock_time = Label.new()
	_lbl_clock_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_clock_time.add_theme_font_size_override("font_size", 20)
	_lbl_clock_time.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	UiKit.apply_heading(_lbl_clock_time)
	hb.add_child(_lbl_clock_time)

	# Botón de MAPA
	_btn_map = Button.new()
	_btn_map.text = "🗺️"
	_btn_map.custom_minimum_size = Vector2(44, 40)
	_btn_map.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "focus"]:
		_btn_map.add_theme_stylebox_override(st, UiKit.button_tonal(UiKit.ACCENT))
	_btn_map.add_theme_color_override("font_color", UiKit.TEXT)
	_btn_map.pressed.connect(_on_map_pressed)


## Abre el mapa/minimapa con niebla de guerra como overlay. Se cierra solo.
func _on_map_pressed() -> void:
	if _minimap_overlay != null and is_instance_valid(_minimap_overlay):
		return
	AudioManager.play_sfx("click")
	set_modal_mode(true)
	_minimap_overlay = MinimapViewer.new()
	_minimap_overlay.closed.connect(_close_minimap)
	add_child(_minimap_overlay)


func _close_minimap() -> void:
	set_modal_mode(false)
	if _minimap_overlay != null and is_instance_valid(_minimap_overlay):
		_minimap_overlay.queue_free()
	_minimap_overlay = null


## Refresca icono (☀/🌙) y hora "HH:MM" del reloj a partir del TimeManager.
func _update_clock() -> void:
	if _lbl_clock_time == null:
		return
	_lbl_clock_time.text = TimeManager.get_clock_string()
	_lbl_clock_icon.text = "☀️" if TimeManager.is_day() else "🌙"


## Cada hora in-game: refresca el reloj (barato) sin tocar la iluminación (esa la
## interpola _process suavemente).
func _on_world_hour_changed(_hour: int) -> void:
	_update_clock()


## Al cruzar día↔noche: refresca icono/hora y reevalúa el gating por fase de la
## casilla actual (p. ej. una tienda cerrada de noche) y las puertas condicionadas.
func _on_world_phase_changed(_phase: String) -> void:
	_update_clock()
	_apply_daynight_lighting(true)
	# El cambio de fase re-tira el clima (nuevo día/noche = nuevo tiempo posible).
	_reroll_weather()
	var cell: CellResource = GlobalState.hexagons_db.get(player_pos, null) as CellResource
	if cell:
		_update_location_panel(cell)


#endregion

#region JOYSTICK VIRTUAL (aparece donde tocas en la zona inferior-izquierda)
## Fachada: la lógica vive en `WorldHudBuilder`. Mismas firmas públicas de
## siempre; ningún llamante externo cambia.
func _build_joystick() -> void:
	_hud_builder._build_joystick()

func _is_pos_over_ui(pos: Vector2) -> bool:
	return _hud_builder._is_pos_over_ui(pos)

func _input(event: InputEvent) -> void:
	_hud_builder._input(event)

func _start_touch_gesture(index: int, global_pos: Vector2) -> void:
	_hud_builder._start_touch_gesture(index, global_pos)

func _drag_touch_gesture(global_pos: Vector2) -> void:
	_hud_builder._drag_touch_gesture(global_pos)

func _end_touch_gesture(global_pos: Vector2) -> void:
	_hud_builder._end_touch_gesture(global_pos)

func _start_joystick(index: int, global_pos: Vector2) -> void:
	_hud_builder._start_joystick(index, global_pos)

func _update_joystick(global_pos: Vector2) -> void:
	_hud_builder._update_joystick(global_pos)

func _reset_joystick() -> void:
	_hud_builder._reset_joystick()

func _position_joystick(off: Vector2) -> void:
	_hud_builder._position_joystick(off)


#endregion

#region TELETRANSPORTE Y SPAWN SEGURO (evita siempre aparecer en mar, montaña o casillas bloqueantes)
## Encuentra la casilla transitable más cercana si la dada es inválida, no transitable o bloqueante (mar, montaña).
func _find_nearest_walkable_cell(start_coord: Vector2i) -> Vector2i:
	var start_cell: CellResource = GlobalState.hexagons_db.get(start_coord, null) as CellResource
	if start_cell != null and is_cell_passable(start_coord):
		if GlobalState.is_sailing:
			if start_cell.terrain == "sea" or start_cell.terrain == "cst":
				return start_coord
		else:
			if start_cell.is_walkable_terrain() and start_cell.terrain != "sea" and start_cell.terrain != "mnt":
				return start_coord

	for r in range(1, 12):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var check := start_coord + Vector2i(dx, dy)
				var c_res: CellResource = GlobalState.hexagons_db.get(check, null) as CellResource
				if c_res != null and is_cell_passable(check):
					if GlobalState.is_sailing:
						if c_res.terrain == "sea" or c_res.terrain == "cst":
							return check
					else:
						if c_res.is_walkable_terrain() and c_res.terrain != "sea" and c_res.terrain != "mnt":
							return check
	return start_coord


## Calcula una posición 3D segura para el jugador cerca de la casilla dada (evita
## aparecer dentro del modelo central del POI y GARANTIZA que nunca se aparezca en
## una casilla bloqueante o no transitable como mar o montaña).
func _find_safe_spawn_world_pos(coord: Vector2i) -> Vector3:
	var center := _cell_to_world(coord)
	var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
	var is_solid_poi := cell != null and cell.is_solid()

	# Si la casilla no es un POI sólido, el centro suele ser seguro si es transitable
	if not is_solid_poi and _is_spawn_pos_valid(center):
		return center

	# Candidatos de posición ordenada por preferencia:
	# Probamos desplazamientos moderados (0.55m) en direcciones cardinales y diagonales,
	# manteniéndonos dentro de la casilla actual de forma que no colisione con el modelo
	# ni con muros/montañas/agua adyacentes.
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.55),    # Sur
		Vector3(0.55, 0.0, 0.0),    # Este
		Vector3(-0.55, 0.0, 0.0),   # Oeste
		Vector3(0.0, 0.0, -0.55),   # Norte
		Vector3(0.4, 0.0, 0.4),     # Sur-Este
		Vector3(-0.4, 0.0, 0.4),    # Sur-Oeste
		Vector3(0.4, 0.0, -0.4),    # Norte-Este
		Vector3(-0.4, 0.0, -0.4),   # Norte-Oeste
	]

	for off in offsets:
		var cand: Vector3 = center + off
		if _is_spawn_pos_valid(cand):
			return cand

	# Si ninguno de los desplazamientos dentro de la celda funcionó, probamos el centro si es válido
	if _is_spawn_pos_valid(center):
		return center

	# Fallback: buscar centro de casillas vecinas transitables
	var neighbors: Array[Vector2i] = [
		coord + Vector2i(0, 1),
		coord + Vector2i(1, 0),
		coord + Vector2i(-1, 0),
		coord + Vector2i(0, -1),
		coord + Vector2i(1, 1),
		coord + Vector2i(-1, 1),
		coord + Vector2i(1, -1),
		coord + Vector2i(-1, -1),
	]
	for nc in neighbors:
		var n_center := _cell_to_world(nc)
		if _movement_blocked_by_gate(center, n_center):
			continue
		if _is_spawn_pos_valid(n_center):
			return n_center

	# Último recurso: centro de la casilla
	return center


## Comprueba si una posición 3D es completamente transitable y no cae en casilla
## bloqueante (como mar o montaña).
func _is_spawn_pos_valid(p: Vector3) -> bool:
	var c := _world_to_cell(p)
	if not GlobalState.hexagons_db.has(c):
		return false
	var cell: CellResource = GlobalState.hexagons_db.get(c, null) as CellResource
	if cell == null or not cell.is_walkable_terrain() or not is_cell_passable(c):
		return false
	if not GlobalState.is_sailing and (cell.terrain == "sea" or cell.terrain == "cst" or cell.terrain == "mnt"):
		return false
	return _is_world_pos_walkable(p)


func teleport_player_to(coord: Vector2i) -> void:
	_clear_move_target()
	var safe_coord := _find_nearest_walkable_cell(coord)
	player_pos = safe_coord
	_current_cell = safe_coord
	GlobalState.player_pos = safe_coord
	if _streamer != null:
		_streamer.update_active_chunks(self, safe_coord)   # Streaming 3x3
	WorldFogRenderer.update_fog_of_war(self, safe_coord)
	WorldFogRenderer.apply_visibility(self)
	WorldFogRenderer.rebuild_nearby(self)
	var cell: CellResource = GlobalState.hexagons_db.get(safe_coord, null) as CellResource
	if is_instance_valid(_player):
		var safe_pos := _find_safe_spawn_world_pos(safe_coord)
		_player.position = safe_pos
		_current_cell = _world_to_cell(safe_pos)
		player_pos = _current_cell
		GlobalState.player_pos = _current_cell
		if is_instance_valid(_cam):
			var sz := get_viewport_rect().size
			var is_landscape := sz.x > sz.y
			var cam_h := CAM_HEIGHT_LANDSCAPE if is_landscape else CAM_HEIGHT
			var cam_b := CAM_BACK_LANDSCAPE if is_landscape else CAM_BACK
			_cam.position = _player.position + Vector3(0.0, cam_h, cam_b)
			_cam.look_at(_player.position + Vector3(0.0, 0.4, 0.0), Vector3.UP)
	if cell:
		_update_location_panel(cell)


#endregion

#region PANEL INFERIOR (ubicación / viaje) — construido por código
## Fachada: la lógica vive en `WorldHudBuilder`. Mismas firmas públicas de
## siempre; ningún llamante externo (incluidos `CampTentSystem`/
## `TerrainToolsSystem`, que ya invocan `world._update_location_panel(...)`,
## y `GameRoot`, que llama `get_active_location_title` por reflexión) cambia.
func _build_bottom_panel() -> void:
	_hud_builder._build_bottom_panel()

func _gather_action_label(r: Dictionary) -> String:
	return _hud_builder._gather_action_label(r)

func get_active_location_title() -> String:
	return _hud_builder.get_active_location_title()

func _update_location_panel(cell: CellResource) -> void:
	_hud_builder._update_location_panel(cell)

func _location_subtitle(cell: CellResource) -> String:
	return _hud_builder._location_subtitle(cell)


#endregion

#region GATING POR FASE DÍA/NOCHE (data-driven, reutilizable)
## Fase en la que este POI está ABIERTO: "day" | "night" | "any" (por defecto).
## Se declara en `ids.json` (`spec.portal.open_phase`), de modo que cualquier POI
## —ciudad, tienda, mazmorra, evento— puede restringirse a día o noche sin código.
func _poi_open_phase(cell: CellResource) -> String:
	if cell.portal is Dictionary:
		var p := String(cell.portal.get("open_phase", "any")).to_lower()
		if p == TimeManager.PHASE_DAY or p == TimeManager.PHASE_NIGHT:
			return p
	return "any"


## ¿El POI está CERRADO ahora por la fase del ciclo? (abre solo de día/solo de noche).
func _is_poi_time_locked(cell: CellResource) -> bool:
	var op := _poi_open_phase(cell)
	if op == "any":
		return false
	return op != TimeManager.phase()


## Aplica el gating por fase al botón ENTRAR: si está cerrado por la hora, lo deja
## visible pero DESHABILITADO (atenuado) y muestra en el subtítulo cuándo volver.
func _apply_phase_gate_to_enter(cell: CellResource) -> void:
	if _btn_enter == null:
		return
	if _btn_enter.visible and _is_poi_time_locked(cell):
		_btn_enter.disabled = true
		_btn_enter.modulate = Color(1, 1, 1, 0.5)
		_lbl_loc_sub.text = _phase_lock_hint(cell)
	else:
		_btn_enter.disabled = false
		_btn_enter.modulate = Color(1, 1, 1, 1.0)


## Pista localizada de cuándo estará disponible un POI cerrado por la fase.
func _phase_lock_hint(cell: CellResource) -> String:
	if _poi_open_phase(cell) == TimeManager.PHASE_DAY:
		return Locale.pick({"es": "🌙 Cerrado de noche · vuelve de día", "en": "🌙 Closed at night · come back by day"})
	return Locale.pick({"es": "☀️ Cerrado de día · vuelve de noche", "en": "☀️ Closed by day · come back at night"})


#endregion

#region HERRAMIENTAS + MODIFICACIÓN DEL TERRENO / CAMPAMENTO / ENEMIGOS
# Extraído a interactive/TerrainToolsSystem.gd (herramientas/terreno/bombas),
# interactive/CampTentSystem.gd (montaje inicial del campamento) e
# interactive/WorldEnemies.gd (actores enemigos del mapamundi).
#endregion

#region OBJETOS INTERACTIVOS (cartel/lápida/libro…) — ventana de texto reutilizable
# DEBUG: la siembra de objetos de prueba (roca demolible/enemigo/cartel) vive en
# interactive/DebugWorldSeeder.gd (DebugWorldSeeder.place_debug_*).

## Muestra la ventana de un objeto interactivo: título + texto configurables (desde
## `cell.interactive`) y un botón Aceptar. Sistema genérico reutilizable para
## carteles, lápidas, libros, monumentos, estatuas, pergaminos…
func _open_interactive_popup(cell: CellResource) -> void:
	if cell == null or not (cell.interactive is Dictionary) or cell.interactive.is_empty():
		return
	# UNIFICADO: los objetos interactivos (carteles, libros, lápidas...)
	# se muestran con el mismo motor narrativo que el resto del juego. Se adapta la
	# definición inline de la casilla a una escena de un nodo y se ejecuta en el
	# SceneRunner, que la presenta con la NarrativeOverlay global.
	SceneRunner.start_built_scene("interactive", SceneAdapters.interactive_to_scene(cell.interactive))


# CAMPAMENTO — TIENDA (checkpoint) + HOGUERA (comer/cocinar/descansar/tiempo) +
# MENÚ DE CONSTRUCCIÓN: extraído a interactive/CampTentSystem.gd. Ver también
# interactive/CampEatMenu.gd (menú de comer, invocado desde CampTentSystem).


## Reubica al jugador en la primera casilla vecina transitable (no sólida) cuando
## la casilla actual se ha vuelto sólida bajo sus pies (p. ej. al construir la base).
func _nudge_player_off_solid_cell(from_coord: Vector2i) -> void:
	var cur_cell: CellResource = GlobalState.hexagons_db.get(from_coord, null) as CellResource
	if cur_cell != null:
		# Las entradas a mazmorras y portales nunca deben desplazar al jugador:
		# el jugador entra y sale exactamente por esa casilla.
		if cur_cell.opens_view() == "dungeon" or cur_cell.type == "dungeon" or (cur_cell.portal is Dictionary and not cur_cell.portal.is_empty()):
			return
	var from_wp := _cell_to_world(from_coord)
	for nc in GlobalState.get_surrounding_hex_coords(from_coord):
		var nb: CellResource = GlobalState.hexagons_db.get(nc, null) as CellResource
		if nb == null or not is_cell_passable(nc) or nb.is_solid():
			continue
		# Si vamos a pie, nunca empujar al jugador al agua / costa
		if not GlobalState.is_sailing and (nb.terrain == "sea" or nb.terrain == "cst"):
			continue
		# Nunca cruzar una puerta activa bloqueada
		var to_wp := _cell_to_world(nc)
		if _movement_blocked_by_gate(from_wp, to_wp):
			continue
		teleport_player_to(nc)
		return


func _on_enter_pressed() -> void:
	if GlobalState.is_sailing:
		_disembark_boat()
		return
	AudioManager.play_sfx("click")
	var cell: CellResource = GlobalState.hexagons_db.get(player_pos, null) as CellResource
	if cell == null:
		return
	# HOGUERA CONSTRUIBLE: si estamos en la casilla a la derecha del campamento (aún
	# sin hoguera), pulsar ENTRAR abre el diálogo de construcción (10 maderas).
	if GlobalState.get_campfire_build_spot() == player_pos:
		CampTentSystem.open_campfire_build_confirm(self, player_pos)
		return
	# RESTO DE CONSTRUCCIONES DE LA BASE (Muñeco/Cofre/Tablón/Herrería): a
	# diferencia de la Hoguera, se levantan en la casilla que el jugador elija.
	var buildable_key := GlobalState.get_buildable_structure_at(player_pos)
	if buildable_key != "":
		CampTentSystem.open_camp_structure_build_confirm(self, player_pos, buildable_key)
		return
	# Gating por fase (día/noche): si el POI está cerrado a esta hora, avisamos y
	# no cambiamos de vista. El puente del mono queda exento (misión, no horario).
	if cell.event_id != "poi_monkey_001" and _is_poi_time_locked(cell):
		_spawn_world_float(_phase_lock_hint(cell), UiKit.HP)
		return
	# Portal data-driven: si la casilla declara un destino de event_id,
	# se usa ese (p. ej. un POI que abre la mazmorra "dun_demo" sin llamarse así).
	var target_event_id: String = cell.event_id
	if cell.portal is Dictionary and String(cell.portal.get("event_id", "")) != "":
		target_event_id = String(cell.portal["event_id"])
	var cell_data: Dictionary = {
		"name": cell.name, "name_i18n": cell.name_i18n, "icon": cell.icon, "type": cell.type,
		"terrain": cell.terrain, "item": cell.item, "resource": cell.resource,
		"coord": player_pos, "event_id": target_event_id,
		"required_skill": cell.required_skill, "description": cell.description, "desc_i18n": cell.desc_i18n,
		"biome_color": cell.biome_color, "dialogue": cell.dialogue,
		"portal": cell.portal,
		"entry_tile_coord": player_pos,
	}
	# El puente del mono abre su diálogo de misión (banana / cruzar).
	if cell.event_id == "poi_monkey_001":
		SceneManager.go_to_place(cell_data)
		return
	match cell.opens_view():
		"city":    SceneManager.go_to_city(cell_data)
		"dungeon":
			_confirm_dungeon_entry(target_event_id, cell_data)
		"gather":  _on_gather_pressed()   # el farmeo ahora es en el propio mundo
		"place":   SceneManager.go_to_place(cell_data)
		"base":    CampTentSystem.open_tent_menu(self)         # tienda: descansar hasta el día/noche
		"campfire": CampTentSystem.open_camp_menu(self)        # menú de la hoguera (comer/cocinar/tiempo)
		"camp_struct": CampTentSystem.open_camp_structure(self, cell)  # cofre/herrería/muñeco/tablón…
		"interactive": _open_interactive_popup(cell)  # cartel/lápida/libro…
		"chest":       _check_and_open_world_chest(player_pos, cell)
		"event":
			# Portal-disparador: ejecuta el evento/cinemática en el sitio (sin cambiar
			# de vista), reutilizando el mini-lenguaje. `event_id` es el id del evento.
			if target_event_id != "":
				Design.run_event(target_event_id)
		"cinematic":
			_check_and_trigger_cell_cinematic(_current_cell, cell, false)


## Comprueba y reproduce cinemática en casilla si procede, respetando activación
## al pisar o al interactuar, y la opción 'once' (un solo uso guardado en flags).
func _check_and_trigger_cell_cinematic(coord: Vector2i, cell: CellResource, is_step: bool) -> bool:
	if cell == null:
		return false
	var is_cine := false
	var cine_id := ""
	var trigger_on_step := true
	var is_once := true

	if cell.interactive is Dictionary and String(cell.interactive.get("kind", "")) == "cinematic":
		is_cine = true
		cine_id = String(cell.interactive.get("cinematic_id", cell.interactive.get("cinematic", "")))
		trigger_on_step = bool(cell.interactive.get("trigger_on_step", true))
		is_once = bool(cell.interactive.get("once", true))
	elif cell.portal is Dictionary and cell.portal.get("view") == "cinematic":
		is_cine = true
		cine_id = String(cell.portal.get("cinematic_id", cell.portal.get("event_id", "")))
		trigger_on_step = bool(cell.portal.get("trigger_on_step", false))
		is_once = bool(cell.portal.get("once", false))
	elif cell.opens_view() == "cinematic":
		is_cine = true
		cine_id = cell.event_id
		trigger_on_step = false
		is_once = false

	if not is_cine or cine_id == "":
		return false

	if is_step and not trigger_on_step:
		return false

	var flag := "cine_world_%d_%d_%s" % [coord.x, coord.y, cine_id]
	if is_once and GlobalState.has_world_flag(flag):
		return false

	if is_once:
		GlobalState.set_world_flag(flag, true)

	QuestManager.play_cinematic(cine_id)
	return true


## Comprueba si un cofre del mapamundi está sin abrir y otorga su botín con feedback completo.
func _check_and_open_world_chest(coord: Vector2i, cell: CellResource) -> void:
	if cell == null or cell.chest.is_empty():
		return
	var key := "world:%d:%d" % [coord.x, coord.y]
	if GlobalState.is_chest_opened(key):
		return
	var granted: Array = GlobalState.open_chest(key, cell.chest)
	AudioManager.play_ui("pickup")
	SaveManager.request_autosave()
	var fx_pos: Vector3 = _cell_to_world(coord) + Vector3(0.0, 0.5, 0.0)
	WorldFx.burst(self, fx_pos, Color(1.0, 0.85, 0.35), 16)
	WorldFx.glow_flash(self, fx_pos, Color(1.0, 0.88, 0.5), 3.5, 0.45)
	_show_world_chest_loot_dialogue(granted)
	if OrbCompanionManager != null:
		OrbCompanionManager.trigger_bark("chest_opened")

	# Reproducir animación de apertura en el modelo 3D
	var entry: Dictionary = _cells.get(coord, {})
	var marker: Node3D = entry.get("obj", null) as Node3D
	var played_anim := false
	if marker != null and is_instance_valid(marker):
		var anim_player: AnimationPlayer = marker.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player == null:
			for ch in marker.find_children("*", "AnimationPlayer", true, false):
				if ch is AnimationPlayer:
					anim_player = ch as AnimationPlayer
					break
		if anim_player != null and anim_player.has_animation("Chest_Open"):
			anim_player.play("Chest_Open")
			played_anim = true

	_update_location_panel(cell)

	if marker != null and is_instance_valid(marker):
		var marker_ref: WeakRef = weakref(marker)
		var tw := create_tween()
		tw.tween_interval(0.65)
		tw.tween_callback(func():
			var m: Node3D = marker_ref.get_ref() as Node3D
			if m != null and is_instance_valid(m):
				GenericMarkers._dim_model_meshes(m)
		)
	elif not played_anim:
		_rebuild_marker(coord, cell)


## Muestra un aviso con el botín obtenido de un cofre en el mapamundi.
func _show_world_chest_loot_dialogue(granted: Array) -> void:
	var rows: Array = []
	for g in granted:
		if String(g.get("kind", "")) == "gold":
			rows.append({"icon": "🪙", "text": "%d de oro" % int(g.get("qty", 0))})
		else:
			var id := String(g.get("id", ""))
			var nm := String(g.get("name", ""))
			if nm == "":
				nm = Design.get_item_name(id)
			var ic := Design.get_item_icon(id)
			if ic == "":
				ic = "📦"
			rows.append({"icon": ic, "text": "%s  x%d" % [nm, int(g.get("qty", 1))]})

	var w := clampf(get_viewport_rect().size.x * 0.5, 300.0, 480.0)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.03, 0.95)
	sb.border_color = Color(1.0, 0.82, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = 90.0
	panel.offset_bottom = 90.0
	panel.grow_vertical = Control.GROW_DIRECTION_END

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var lbl_head := Label.new()
	lbl_head.text = "🧰  " + Locale.pick({"es": "¡Cofre abierto!", "en": "Chest opened!"})
	lbl_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_head.add_theme_font_size_override("font_size", 18)
	lbl_head.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	vb.add_child(lbl_head)

	if rows.is_empty():
		var lbl_empty := Label.new()
		lbl_empty.text = Locale.pick({"es": "El cofre está vacío", "en": "The chest is empty"})
		lbl_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_empty.add_theme_font_size_override("font_size", 15)
		lbl_empty.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
		vb.add_child(lbl_empty)
	else:
		for r in rows:
			var hb := HBoxContainer.new()
			hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_theme_constant_override("separation", 10)
			vb.add_child(hb)

			var lic := Label.new()
			lic.text = String(r.get("icon", "📦"))
			lic.add_theme_font_size_override("font_size", 18)
			hb.add_child(lic)

			var ltx := Label.new()
			ltx.text = String(r.get("text", ""))
			ltx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ltx.add_theme_font_size_override("font_size", 15)
			ltx.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
			hb.add_child(ltx)

	add_child(panel)
	panel.modulate = Color(1, 1, 1, 0)
	panel.position.y -= 12.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "position:y", panel.position.y + 12.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.6)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(panel.queue_free)


## Confirmación antes de entrar a una mazmorra/sendero (evita entradas por
## accidente). Distingue 3 casos:
##  · Sendero SIN entrenamiento (no aprendiz del Maestro): mensaje informativo,
##    bloquea la entrada — sustituye al toast anterior "Solo los aprendices...".
##  · Sendero CON entrenamiento: modal "¿Quieres ponerte a prueba...?" con el
##    nivel recomendado (el del jefe) entre paréntesis.
##  · Mazmorra normal: modal "¿Estás seguro?" con el nivel recomendado si tiene jefe.
func _confirm_dungeon_entry(target_event_id: String, cell_data: Dictionary) -> void:
	var layout := Design.get_dungeon_layout(target_event_id)
	var dun_name := Locale.pick(layout.get("name", {})) if not layout.is_empty() else ""
	if dun_name == "":
		dun_name = String(cell_data.get("name", ""))
	var boss_id := String(layout.get("boss", ""))
	var boss_level := int(layout.get("boss_level", 0))
	var level_hint := "" if boss_id == "" else Locale.pick({
		"es": " (Nivel recomendado: %d)" % boss_level,
		"en": " (Recommended level: %d)" % boss_level,
	})

	var is_sendero: bool = target_event_id.begins_with("sendero_")
	if is_sendero and not GlobalState.debug_mode and not GlobalState.is_test_room:
		if not Design.gflag("apprentice_" + target_event_id):
			UiKit.toast(self, Locale.pick({
				"es": "Este es el sendero de %s. No has entrenado en esta profesión como para ponerte a prueba." % dun_name,
				"en": "This is the %s trial path. You haven't trained in this profession to be put to the test." % dun_name,
			}), UiKit.HP)
			return

	if is_sendero:
		UiKit.confirm(self,
			Locale.pick({"es": "⚔️ Sendero de Prueba", "en": "⚔️ Trial Path"}),
			Locale.pick({
				"es": "¿Quieres poner a prueba entrando en el sendero de %s?%s" % [dun_name, level_hint],
				"en": "Do you want to test yourself by entering the %s trial path?%s" % [dun_name, level_hint],
			}),
			Locale.pick({"es": "Entrar", "en": "Enter"}),
			Locale.pick({"es": "Cancelar", "en": "Cancel"}),
			func() -> void: SceneManager.go_to_dungeon(cell_data))
		return

	UiKit.confirm(self,
		Locale.pick({"es": "⚠️ Entrar en la mazmorra", "en": "⚠️ Enter the dungeon"}),
		Locale.pick({
			"es": "Estás a punto de entrar en una mazmorra, ¿Estás seguro?%s" % level_hint,
			"en": "You are about to enter a dungeon, are you sure?%s" % level_hint,
		}),
		Locale.pick({"es": "Entrar", "en": "Enter"}),
		Locale.pick({"es": "Cancelar", "en": "Cancel"}),
		func() -> void: SceneManager.go_to_dungeon(cell_data))


# ─── VIAJE RÁPIDO ─────────────────────────────────────────────────────────────
# Extraído a interactive/TravelSystem.gd (TravelSystem.open_travel_menu(self)).


#endregion

#region RECOLECCIÓN EN EL MUNDO (sin cambiar de vista)
## Resuelve la info del recurso de una casilla (item/icono/nombre/skill/categoría),
## igual que ViewGather, con fallback por oficio.
func _resolve_gather_res(cell: CellResource) -> Dictionary:
	var rid: String = cell.resource
	var info := Design.resolve_gather_resource(rid)
	if not info.is_empty():
		return info
	var sk: String = cell.required_skill if cell.required_skill != "" else "lenador"
	if not GameConfig.GATHER_RESOURCES.has(sk):
		sk = "lenador"
	var g: Dictionary = GameConfig.GATHER_RESOURCES[sk]
	return {"skill": sk, "item": g["id"], "item_loc": g["loc"], "icon": g["icon"], "category": g["category"], "found_loc": "gather_found_" + sk}


## Tinte del estallido de partículas/brillo al recolectar, según el oficio
##: madera parda, piedra gris, pesca azulada, trigo dorado, leche.
func _gather_fx_color(skill: String) -> Color:
	match skill:
		"lenador":    return Color(0.55, 0.38, 0.22)
		"minero":     return Color(0.62, 0.62, 0.66)
		"pesca":      return Color(0.35, 0.62, 0.85)
		"agricultor": return Color(0.85, 0.72, 0.28)
		"ganadero":   return Color(0.92, 0.90, 0.85)
		"cazador":    return Color(0.71, 0.34, 0.24)
		_:            return Color(0.8, 0.65, 0.35)


## Un clic = una recolección directa: gesto de talar, "+N" sobre el peón y el
## recurso va directo a la bolsa. Sin abrir ninguna otra vista.
func _on_gather_pressed() -> void:
	var cell: CellResource = GlobalState.hexagons_db.get(player_pos, null) as CellResource
	if cell == null or cell.opens_view() != "gather":
		return

	# HERRAMIENTA REQUERIDA: sin hacha no se puede talar madera, sin
	# pico no se puede picar piedra. El resto de oficios (pesca/agricultura/
	# ganadería) siguen libres.
	var res: Dictionary = _resolve_gather_res(cell)
	var skill: String = String(res.get("skill", ""))
	var missing_tool: String = String(GameConfig.GATHER_TOOL_REQUIREMENTS.get(skill, ""))
	if missing_tool != "" and not GlobalState.has_item(missing_tool):
		var tool_name := Design.get_item_name(missing_tool)
		_spawn_world_float(Locale.pick({
			"es": "Necesitas %s para esto." % tool_name,
			"en": "You need a %s for this." % tool_name,
		}), UiKit.HP)
		return

	# VELOCIDAD DE RECOLECCIÓN: el nivel del oficio (2-4 y 6-9) acelera solo su
	# propio cooldown de toque (ver GlobalState.gather_speed_multiplier).
	var now := Time.get_ticks_msec()
	var cooldown_ms: int = int(GameConfig.GATHER_TAP_COOLDOWN_MS / GlobalState.gather_speed_multiplier(skill))
	if now - _last_gather_time < cooldown_ms:
		return
	_last_gather_time = now

	# CANTIDAD POR TOQUE: a partir de nivel 5 del oficio se dobla (ver
	# GlobalState.gather_amount_multiplier).
	var per_tap: int = GameConfig.GATHER_AMOUNT_PER_TAP * GlobalState.gather_amount_multiplier(skill)
	var taken: int = GlobalState.consume_gather(player_pos, per_tap)
	if taken <= 0:
		# Nodo agotado: aún no hay nada que extraer (se regenera con el tiempo).
		_spawn_world_float(Locale.t("gather_depleted"), UiKit.HP)
		_refresh_gather_button()
		return

	var item_id: String = String(res.get("item", "wood"))
	var res_name: String = Locale.t(String(res.get("item_loc", "res_wood")))
	var icon: String = String(res.get("icon", "📦"))

	GlobalState.add_item(item_id, taken, res_name, String(res.get("category", "other")), icon)
	GlobalState.discover_resource(item_id)
	GlobalState.report_gather(item_id, taken)
	GlobalState.add_skill_xp(skill, GameConfig.GATHER_XP_PER_TAP)

	AudioManager.play_sfx("gather")
	_play_chop()
	_spawn_world_float("%s +%d" % [icon, taken], UiKit.GOOD)
	# (Game Feel): la recolección debe sentirse contundente, no solo un
	# número que sube: el árbol/roca/banco de pesca da un "punch" de escala y
	# suelta un pequeño estallido de partículas + brillo en el punto exacto.
	var res_entry: Dictionary = _cells.get(player_pos, {})
	var res_obj: Node3D = res_entry.get("obj") as Node3D
	var fx_pos: Vector3 = (res_obj.global_position if res_obj != null else _player.position) + Vector3(0.0, 0.9, 0.0)
	WorldFx.harvest_fx(self, res_obj, fx_pos, _gather_fx_color(skill))
	
	# Refrescamos el estado visual de la casilla (pasa a roca gastada si queda 1, o se oculta si queda 0)
	WorldFogRenderer.apply_cell_visual(self, player_pos)

	# Si se agotó en este toque, estallido de polvo de roca / desvanecimiento
	if GlobalState.get_gather_remaining(player_pos) <= 0:
		WorldFx.burst(self, fx_pos, Color(0.62, 0.60, 0.58), 24)

	_refresh_gather_button()
	SaveManager.request_autosave()


## Refresca el botón de recolección según la reserva del nodo (atenúa si agotado).
func _refresh_gather_button() -> void:
	if _btn_gather == null:
		return
	var remaining: int = GlobalState.get_gather_remaining(player_pos)
	_btn_gather.modulate = Color(1, 1, 1, 1.0) if remaining > 0 else Color(1, 1, 1, 0.45)


## Dispara el gesto de recolección/farmeo reproduciendo la animación "Throw" a mayor velocidad.
func _play_chop() -> void:
	_chop_time = 0.0
	if is_instance_valid(_player_anim_player) and _player_anim_player.has_animation("Throw"):
		_player_anim_player.play("Throw", 0.05, 2.2)


## Muestra un texto flotante (p. ej. "🪵 +1") sobre la cabeza del peón, en 2D,
## proyectando su posición 3D a la pantalla.
func _spawn_world_float(text: String, col: Color = UiKit.GOOD) -> void:
	if not is_instance_valid(_cam) or not is_instance_valid(_player):
		return
	var world_top: Vector3 = _player.position + Vector3(0.0, 1.9, 0.0)
	var screen_pos: Vector2 = _cam.unproject_position(world_top)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = screen_pos - Vector2(30, 20)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 120.0, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)


## Muestra un banner superior al descubrir un lugar: más grande, centrado y duradero.
func _show_discovery_banner(text: String) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.custom_minimum_size = Vector2(520, 64)
	panel.offset_top = 104.0
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	panel.offset_bottom = 168.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.06, 0.12, 0.90)
	bg.border_color = UiKit.ACCENT
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(20)
	bg.content_margin_left = 24
	bg.content_margin_right = 24
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	bg.shadow_color = Color(0, 0, 0, 0.55)
	bg.shadow_size = 14
	panel.add_theme_stylebox_override("panel", bg)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)
	add_child(panel)

	var banner_tween := create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(panel, "position:y", panel.position.y - 40.0, 3.0).set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(panel, "modulate:a", 0.0, 1.0).set_delay(2.0)
	banner_tween.chain().tween_callback(panel.queue_free)


## MOMENTO DE DESCUBRIMIENTO (B1.3): la PRIMERA vez que un POI real (ciudad, mazmorra,
## lugar de interés o portal de evento) sale de la niebla al caminar, se celebra con
## texto flotante + sonido de recompensa + una sacudida sutil de cámara. No dispara para
## utilidades comunes (recolección/campamento/hoguera) ni al recargar zonas ya
## exploradas (sus casillas ya vienen marcadas como exploradas, así que `was_explored`
## es true y no entra aquí). Es data-driven: se decide por `cell.opens_view()`.
func _maybe_announce_discovery(coord: Vector2i, cell: CellResource) -> void:
	if not is_visible_in_tree():
		return
	if not (cell.opens_view() in ["city", "dungeon", "place", "event"]):
		return
	var e: Dictionary = _cells.get(coord, {})
	if e.is_empty() or e.get("obj") == null:
		return
	var nm: String = cell.get_display_name()
	var icon := String(cell.icon)
	var fallback_place := Locale.pick({
		"es": "un lugar nuevo", "en": "a new place", "fr": "un nouveau lieu",
		"it": "un nuovo luogo", "de": "ein neuer Ort", "zh": "一个新地点", "ja": "新しい場所"
	})
	var place := ("%s %s" % [icon, nm]).strip_edges() if nm != "" else fallback_place
	var disc_prefix := Locale.pick({
		"es": "🗺️ Descubierto:", "en": "🗺️ Discovered:", "fr": "🗺️ Découvert :",
		"it": "🗺️ Scoperto:", "de": "🗺️ Entdeckt:", "zh": "🗺️ 已发现：", "ja": "🗺️ 発見："
	})
	var msg := "%s %s" % [disc_prefix, place]
	_show_discovery_banner(msg)
	AudioManager.play_sfx("sfx_pop_1")
	_reveal_around(coord, 1)


## Autodescubre las casillas a una distancia determinada alrededor de una coordenada (POI/dungeon).
func _reveal_around(center: Vector2i, radius: int = 1) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var ncoord := center + Vector2i(dx, dy)
			var ncell: CellResource = GlobalState.hexagons_db.get(ncoord, null) as CellResource
			if ncell != null:
				ncell.set_meta("visibility", 2)
				ncell.set_meta("explored", true)
				GlobalState.mark_explored(ncoord)
				WorldFogRenderer.apply_cell_visual(self, ncoord)


#endregion

#region SISTEMA DE MISIONES Y DIÁLOGO (con la corrección de aplazamiento)
func _setup_quest_system() -> void:
	QuestManager.map_cell_changed.connect(_on_map_cell_changed)
	QuestManager.combat_triggered.connect(_on_combat_triggered)

	# SISTEMA NARRATIVO UNIFICADO: diálogos y cinemáticas se ejecutan como
	# escenas en el SceneRunner y se presentan en la NarrativeOverlay global. Los
	# movimientos de cámara de una cinemática viajan como eventos globales
	# (EVENT_CINE_CAMERA) a los que el mundo reacciona; al terminar la escena se
	# devuelve el control de cámara al jugador.
	GlobalEvents.subscribe("EVENT_CINE_CAMERA", _on_cine_camera_event)
	GlobalEvents.subscribe("dragon_cima_unlocked", func(_p: Dictionary = {}) -> void: _recompute_gates())
	SceneRunner.scene_finished.connect(_on_scene_runner_finished)


func _on_visibility_changed() -> void:
	var vis := is_visible_in_tree()
	# Pausar el render 3D cuando el mundo no se ve (combate/ciudad/base/menús): con
	# UPDATE_DISABLED el SubViewport deja de renderizar y no gasta GPU.
	if _sub_viewport:
		if vis:
			if _vp_container != null and (_vp_container.size.x <= 0 or _vp_container.size.y <= 0):
				_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
				call_deferred("_enable_subviewport_when_ready")
			else:
				_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		else:
			_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not vis:
		_update_overworld_footsteps(false)
		if _weather_overlay and is_instance_valid(_weather_overlay):
			_weather_overlay.apply("", {})
		return
	_reset_joystick()
	_clear_move_target()
	# Reconstruir los marcadores de celdas que cambiaron (map_cell_changed) mientras
	# el mundo estaba oculto (ver _on_map_cell_changed): si no, un POI que se
	# transformó/desapareció durante un diálogo se quedaría mostrando el marcador
	# viejo (y su estado de interacción obsoleto) hasta salir y reentrar al mapa.
	if not _pending_marker_rebuilds.is_empty():
		for coord: Vector2i in _pending_marker_rebuilds.keys():
			var pending_cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
			if pending_cell != null:
				_rebuild_marker(coord, pending_cell)
				WorldFogRenderer.recompute_cell_fog(self, coord, _current_cell)
				WorldFogRenderer.apply_cell_visual(self, coord)
				if coord == player_pos:
					_update_location_panel(pending_cell)
		_pending_marker_rebuilds.clear()
	# Reubicar al jugador de forma segura al volver de cualquier vista (mazmorra, ciudad, lugar...)
	# Garantiza que NUNCA aparezca en casillas bloqueantes (mar o montaña).
	var target_coord := _find_nearest_walkable_cell(GlobalState.player_pos)
	teleport_player_to(target_coord)
	_refresh_boat_marker()               # asegurar visibilidad del barco aparcado al volver al mundo
	WorldFogRenderer.rebuild_nearby(self)
	WorldEnemies.refresh_enemies(self)   # reconcilia enemigos tras volver de combate (derrota/respawn)
	_check_puerto_crisis_event()         # activa jefe, música de crisis y mensaje de la esfera si corresponde
	# Recalcular los MUROS CONDICIONADOS al volver al mundo: una condición pudo
	# cumplirse mientras estábamos fuera (p. ej. derrotar al boss de la cueva abre
	# `cave_cleared`). Sin esto, la barrera seguiría bloqueando aunque ya esté abierta.
	_recompute_gates()
	# Reaplica el ambiente (música/clima) al volver al mundo desde mazmorra/combate,
	# donde la música pudo cambiar (push/pop) o la capa de clima haberse ocultado.
	if _weather_overlay:
		_current_music_id = ""   # forzar reevaluación de la pista tras un pop_music
		var vc: CellResource = GlobalState.hexagons_db.get(_current_cell, null) as CellResource
		if vc:
			_update_ambience(vc)

	# Si se solicitó un teletransporte desde una vista (p. ej. ViewTransport), mover al jugador.
	if GlobalState.pending_teleport_coord != Vector2i(-1, -1):
		var target_c: Vector2i = GlobalState.pending_teleport_coord
		GlobalState.pending_teleport_coord = Vector2i(-1, -1)
		teleport_player_to(target_c)

	# El NPC transportista de una ciudad pidió abrir el selector de viaje al volver.
	if GlobalState.pending_open_travel:
		GlobalState.pending_open_travel = false
		TravelSystem.open_travel_menu(self)


func _enable_subviewport_when_ready() -> void:
	if is_instance_valid(_sub_viewport) and is_visible_in_tree():
		if _vp_container != null and _vp_container.size.x > 0 and _vp_container.size.y > 0:
			_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Una casilla cambió (p. ej. el puente desbloqueado): reconstruir su marcador 3D.
## La losa de suelo vive en una MultiMesh y no cambia de aspecto en estos eventos
## (agua↔orilla comparten grupo de agua), así que solo reconstruimos el marcador.
func _on_map_cell_changed(coord: Vector2i) -> void:
	var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
	if cell == null:
		return
	var e: Dictionary = _cells.get(coord, {})
	if not e.is_empty():
		e["vis_applied"] = -1
	if not is_visible_in_tree():
		# El mundo está oculto (p. ej. diálogo/narrativa abierto sobre el POI):
		# no reconstruimos ahora para no gastar CPU en algo invisible, pero
		# guardamos la coord para reconstruir el marcador al reaparecer
		# (ver _on_visibility_changed), si no el POI se quedaría mostrando un
		# marcador/estado obsoleto hasta salir y volver a entrar al mapa.
		_pending_marker_rebuilds[coord] = true
		return
	_rebuild_marker(coord, cell)
	WorldFogRenderer.recompute_cell_fog(self, coord, _current_cell)
	WorldFogRenderer.apply_cell_visual(self, coord)
	WorldFogRenderer.rebuild_nearby(self)
	if coord == player_pos:
		_update_location_panel(cell)


func _on_combat_triggered(enemy_data: Dictionary) -> void:
	if not enemy_data.has("context"):
		enemy_data["context"] = "world"
	if not enemy_data.has("world_terrain") or String(enemy_data.get("world_terrain", "")) == "":
		var cell_res: CellResource = GlobalState.hexagons_db.get(player_pos, null) as CellResource
		if cell_res != null:
			enemy_data["world_terrain"] = cell_res.terrain
	if not enemy_data.has("world_zone") or String(enemy_data.get("world_zone", "")) == "":
		var zone_def: Dictionary = Design.get_zone_at(player_pos)
		enemy_data["world_zone"] = String(zone_def.get("id", ""))
	SceneManager.start_combat(enemy_data)


## Reconstruye SOLO el marcador/edificio (y etiqueta) de una casilla tras un cambio de
## estado, conservando su losa de suelo (MultiMesh) y sus índices de niebla.
func _rebuild_marker(coord: Vector2i, cell: CellResource) -> void:
	var e: Dictionary = _cells.get(coord, {})
	if e.is_empty():
		return
	for k in ["obj", "label"]:
		var n: Node = e.get(k)
		if n != null and is_instance_valid(n):
			n.queue_free()
	e["obj"] = null
	e["label"] = null
	var wp: Vector3 = _cell_to_world(coord)
	var owning_chunk: Vector2i = e.get("chunk", WorldChunkStreamer.chunk_coord_of(coord))
	var parent: Node3D = _chunk_roots.get(owning_chunk, _tiles_root)
	_build_marker_for(coord, cell, wp, e, parent)
	e["is_trees"] = (cell.resource == "forest" or cell.resource == "forestBad")
	e["is_interactive"] = cell.is_interactive()
	if (e["is_trees"] or e["is_interactive"]) and not _anim_coords.has(coord):
		_anim_coords.append(coord)


#endregion

#region LOCALE
func _on_locale_changed() -> void:
	_refresh_world_labels_text()
	var cell: CellResource = GlobalState.hexagons_db.get(_current_cell, null) as CellResource
	if cell:
		_update_location_panel(cell)


## Actualiza el texto de todos los `Label3D` flotantes de POI al cambiar de idioma.
func _refresh_world_labels_text() -> void:
	for coord in _cells.keys():
		var entry: Dictionary = _cells[coord]
		var label: Label3D = entry.get("label")
		if label != null and is_instance_valid(label):
			var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
			if cell != null:
				label.text = cell.get_display_name()


## Reaplica el tema activo a los `Label3D` flotantes de nombre de POI ya
## instanciados (Bug 1.1 de task_bugs_observados.md): al crearse (_register_one_tile)
## se les asigna `UiKit.theme_font()`/`theme_color()` una única vez, pero al no ser
## `Control` no heredan el `Theme` global y quedaban con los colores del tema
## anterior tras un cambio en caliente desde Opciones.
func _refresh_world_labels_theme() -> void:
	var font := UiKit.theme_font()
	var poi_accent := UiKit.theme_color("accent2", Color(1.0, 0.95, 0.82))
	var modulate_c := Color(poi_accent.r, poi_accent.g, poi_accent.b, 0.85)
	for entry: Dictionary in _cells.values():
		var label: Label3D = entry.get("label")
		if label != null and is_instance_valid(label):
			label.font = font
			label.modulate = modulate_c


#endregion

#region CÁMARA DE CINEMÁTICAS (desacoplada del Sistema Narrativo)
# Las cinemáticas son ESCENAS normales (scenes.json) ejecutadas en el SceneRunner.
# Sus nodos de cámara no mueven la cámara directamente: emiten el evento global
# EVENT_CINE_CAMERA (x,y,dur) al que reacciona este Mapamundi. El resto de nodos
# (banners, esperas, tokens) los resuelve el propio motor.
# ══════════════════════════════════════════════════════════════════════════════
## Fachada: la lógica vive en `WorldCinematicController`. Mismas firmas
## públicas de siempre; las suscripciones a `GlobalEvents`/
## `SceneRunner.scene_finished` (más abajo, en "SISTEMA DE MISIONES Y DIÁLOGO")
## siguen apuntando aquí sin cambios.
func _on_cine_camera_event(payload: Dictionary) -> void:
	_cine_controller._on_cine_camera_event(payload)

func _on_scene_runner_finished(_scene_id: String) -> void:
	_cine_controller._on_scene_runner_finished(_scene_id)


#endregion

#region CINEMÁTICA DE LA PRESA PROGRESIVA
## Fachada: la lógica vive en `WorldCinematicController`. Mismas firmas
## públicas de siempre; ningún llamante externo (incluidos `GameRoot`, que
## llama `run_dam_opened_cinematic` directamente, y `CampTentSystem`, que llama
## `world._update_base_aura()`) cambia.
func run_dam_opened_cinematic(on_finished_callback: Callable) -> void:
	_cine_controller.run_dam_opened_cinematic(on_finished_callback)

func _get_propagation_delay(coord: Vector2i, river: Array[Vector2i], presa: Vector2i) -> float:
	return _cine_controller._get_propagation_delay(coord, river, presa)

func _spawn_temp_tile_popup(coord: Vector2i, terrain: String) -> void:
	_cine_controller._spawn_temp_tile_popup(coord, terrain)

func _update_base_aura() -> void:
	_cine_controller._update_base_aura()

#endregion

## Control de aparición del Jefe del Puerto y alerta de la esfera
func _check_puerto_crisis_event() -> void:
	if GlobalState.has_world_flag("boss_puerto_activo") and not GlobalState.has_world_flag("boss_puerto_derrotado"):
		var boss_coord := Vector2i(93, 23)
		var boss_cell: CellResource = GlobalState.hexagons_db.get(boss_coord, null) as CellResource
		if boss_cell != null and (boss_cell.enemy == null or boss_cell.enemy.is_empty()):
			boss_cell.enemy = { "id": "jefe_puerto", "level": 25, "is_boss": true, "name": "Jefe del Puerto", "icon": "🐙" }
			WorldEnemies.spawn_enemy_actor(self, boss_coord, boss_cell.enemy)
		
		# Asegurar que suena inmediatamente la música de crisis del puerto
		if _current_music_id != "event_crisis_puerto":
			_current_music_id = "event_crisis_puerto"
			if AudioManager != null:
				AudioManager.play_music("event_crisis_puerto", 0.8)

		if not GlobalState.has_world_flag("aviso_esfera_puerto"):
			GlobalState.set_world_flag("aviso_esfera_puerto", true)
			if OrbBarksManager != null:
				get_tree().create_timer(0.3).timeout.connect(func() -> void:
					OrbBarksManager.trigger_important_message("¡Dios mío, una criatura está atacando el puerto! ¡Debes ir corriendo!")
				)
			else:
				_spawn_world_float("¡Dios mío, una criatura está atacando el puerto! ¡Debes ir corriendo!", UiKit.WARN)
