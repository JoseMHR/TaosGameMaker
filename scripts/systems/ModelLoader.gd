# ModelLoader.gd
# ─────────────────────────────────────────────────────────────────────────────
# CARGADOR UNIVERSAL INTELIGENTE DE MODELOS 3D (.tscn, .glb, .gltf, .obj)
#
# Centraliza la carga e instanciación de elementos 3D bajo `assets/common/models/`.
# Soporta búsqueda universal en cascada con prioridad:
#   1. .tscn (Escena de Godot)
#   2. .glb  (Modelo binario glTF)
#   3. .gltf / .obj (Modelos 3D estándar)
#   4. Fallback procedural por código (si no existe ningún archivo físico)
# ─────────────────────────────────────────────────────────────────────────────
class_name ModelLoader
extends RefCounted

const BASE_MODELS_DIR := "res://assets/common/models/"
const SUB_DIRS: Array[String] = [
	"buildings",
	"interactive",
	"decorations",
	"characters",
	"characters/animation",
	"experimentos",
	"legacy"
]
const EXTENSIONS: Array[String] = [".tscn", ".glb", ".gltf", ".obj"]

## Mapeo de alias inglés/español para mantener un único archivo físico en disco
const ALIASES: Dictionary = {
	"lever": "palanca",
	"switch": "palanca",
	"spikes": "pinchos",
	"chest": "cofre",
	"barrier": "barrera",
	"bloqueo_piedra": "bloqueo_piedra",
	"stone_wall": "bloqueo_piedra",
	"muro_piedra": "bloqueo_piedra",
	"muro": "bloqueo_piedra",
	"column": "columna",
	"pillar": "columna",
	"campfire": "hoguera",
	"hoguera": "hoguera",
	"brazier": "hoguera",
	"tent": "base_tienda",
	"tienda": "base_tienda",
	"tienda_campana": "base_tienda",
	"camp_tent": "base_tienda",
	"camp_chest": "camp_chest",
	"camp_cofre": "camp_chest",
	"camp_board": "camp_board",
	"camp_tablon": "camp_board",
	"camp_forge": "camp_forge",
	"camp_herreria": "camp_forge",
	"camp_dummy": "camp_dummy",
	"sign": "cartel",
	"cartel": "cartel",
	"tombstone": "lapida",
	"lapida": "lapida",
	"monument": "monumento",
	"monumento": "monumento",
	"crop": "cultivo",
	"cultivo": "cultivo",
	"forest": "bosque",
	"bosque": "bosque",
	"ice_block": "bloque_hielo",
	"ice": "bloque_hielo",
	"roots": "raices",
	"door": "puerta_madera",
	"gate": "puerta_madera",
	"puerta": "puerta_madera",
	"puerta_madera": "puerta_madera",
	"crate": "caja_madera",
	"ring": "anilla",
	"teleport": "teletransporte",
	"altar": "teletransporte",
	"town_hall": "ciudad",
	"city": "ciudad",
	"village": "aldea",
	"house": "casita",
	"tower": "torre",
	"castle": "castillo",
	"mountain": "montana",
	"fishing_dock": "pesca",
	"fishing": "pesca",
	"cave_entrance": "cueva",
	"cave": "cueva",
	"temple": "templo",
	"templo_arquero": "temploArquero",
	"temploarquero": "temploArquero",
	"poi_temple_arquero": "temploArquero",
	"temple_arquero": "temploArquero",
	"temple_archer": "temploArquero",
	"templo_elementalista": "temploElementalista",
	"temploelementalista": "temploElementalista",
	"poi_temple_elementalista": "temploElementalista",
	"temple_elementalista": "temploElementalista",
	"temple_elemental": "temploElementalista",
	"templo_guerrero": "temploGuerrero",
	"temploguerrero": "temploGuerrero",
	"poi_temple_guerrero": "temploGuerrero",
	"temple_guerrero": "temploGuerrero",
	"temple_warrior": "temploGuerrero",
	"templo_psiquico": "temploPsiquico",
	"templopsiquico": "temploPsiquico",
	"poi_temple_psiquico": "temploPsiquico",
	"temple_psiquico": "temploPsiquico",
	"temple_psychic": "temploPsiquico",
	"templo_sacerdote": "temploSacerdote",
	"templosacerdote": "temploSacerdote",
	"poi_temple_sacerdote": "temploSacerdote",
	"temple_sacerdote": "temploSacerdote",
	"temple_sacerdotisa": "temploSacerdote",
	"temple_priest": "temploSacerdote",
	"temple_healer": "temploSacerdote",
	"templo_tiempo": "temploTiempo",
	"templotiempo": "temploTiempo",
	"poi_temple_tiempo": "temploTiempo",
	"temple_tiempo": "temploTiempo",
	"temple_time": "temploTiempo",
	"temple_chrono": "temploTiempo",
	"dam": "presa",
	"bridge": "puente",
	"dead_tree": "arbol_marchito",
	"bare_tree": "arbol_marchito",
	"arboles_malos": "arbol_marchito",
	"forestbad": "arbol_marchito",
	"rock": "roca",
	"rock_worn": "roca_gastada",
	"rock_depleted": "roca_gastada",
	"roca_gastada": "roca_gastada",
	"piedra_gastada": "roca_gastada",
	"oro": "oro",
	"oro_gastado": "oro_gastado",
	"rockgold": "oro",
	"rockgold_worn": "oro_gastado",
	"gold": "oro",
	"gold_worn": "oro_gastado",
	"gold_depleted": "oro_gastado",
	"dummy": "muneco_entrenamiento",
	"muneco_entrenamiento": "muneco_entrenamiento",
	"muneco": "muneco_entrenamiento",
	"training_dummy": "muneco_entrenamiento",
	"tronco_caido": "tronco_caido",
	"wood_log": "tronco_caido",
	"fallen_log": "tronco_caido",
	"log": "tronco_caido",
	"tronco": "tronco_caido",
	"torch": "antorcha_encendida",
	"antorcha": "antorcha_encendida",
	"antorcha_encendida": "antorcha_encendida",
	"torch_lit": "antorcha_encendida",
	"caja": "caja_madera",
	"caja_madera": "caja_madera",
	"caja_ligera": "caja_madera",
	"crate_light": "caja_madera",
	"caja_pesada": "caja_pesada",
	"caja_metal": "caja_pesada",
	"crate_heavy": "caja_pesada",
	"heavy_crate": "caja_pesada",
	"box": "caja_madera",
	"cama": "cama",
	"bed": "cama",
	"cofre": "cofre",
	"escalera_con_muros": "escalera_con_muros",
	"escalera_muros": "escalera_con_muros",
	"hojas_pared": "hojas_pared",
	"enredadera_pared": "hojas_pared",
	"enredadera": "hojas_pared",
	"vines": "hojas_pared",
	"vine": "hojas_pared",
	"bomba": "bomba",
	"bomb": "bomba",
	"palanca": "palanca",
	"flores": "flores_3",
	"flores_3": "flores_3",
	"flores_4": "flores_4",
	"flowers": "flores",
	"setas": "setas",
	"mushrooms": "setas",
	"mushroom": "setas",
	"armario_libreria": "armario_libreria",
	"armario_alto": "armario_libreria",
	"bookcase": "armario_libreria",
	"libreria": "armario_libreria",
	"barril_manzanas": "barril_manzanas",
	"barril_manzana": "barril_manzanas",
	"barrel_apples": "barril_manzanas",
	"barril": "barril_manzanas",
	"barrel": "barril_manzanas",
	"flower": "flores",
	"grass": "hierba",
}

## Caché en memoria para resoluciones de ruta ultra-rápidas
static var _path_cache: Dictionary = {}

## task3_rebalanceo FASE5: caché del RECURSO ya cargado (PackedScene/Mesh) por
## ruta resuelta. El auto-scatter de FASE2 (GridDungeonStage/_add_floor_clutter,
## TabWorld3D decor por chunk) llama a `load_model()` con el MISMO modelo
## docenas/cientos de veces por mazmorra o chunk; evita pasar por
## `ResourceLoader.load()` en cada instanciación (que ya cachea internamente,
## pero con más overhead que una consulta directa a este Dictionary).
static var _resource_cache: Dictionary = {}


## Intenta cargar e instanciar un modelo o escena 3D desde `model_path`.
## `scale_factor` escala uniformemente el nodo resultante.
## `y_offset` eleva el nodo en el eje Y.
## Devuelve un Node3D listo para añadirse al árbol de la escena, o null si falla.
static func load_model(model_path: String, scale_factor: float = 1.0, y_offset: float = 0.0) -> Node3D:
	var path := resolve_path(model_path)
	if path.is_empty():
		return null

	var resource: Resource = _resource_cache.get(path, null)
	if resource == null:
		resource = ResourceLoader.load(path)
		if resource != null:
			_resource_cache[path] = resource
	if resource == null:
		return null
		
	var instance: Node3D = null
	
	if resource is PackedScene:
		var scene_node: Node = (resource as PackedScene).instantiate()
		if scene_node is Node3D:
			instance = scene_node as Node3D
		elif scene_node != null:
			var wrapper := Node3D.new()
			wrapper.add_child(scene_node)
			instance = wrapper
	elif resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource as Mesh
		instance = mesh_instance
	else:
		return null
		
	if instance != null:
		if scale_factor != 1.0:
			instance.scale *= Vector3.ONE * scale_factor
		if y_offset != 0.0:
			instance.position.y += y_offset
			
	return instance


## Comprueba si existe un archivo de modelo correspondiente en disco.
static func has_model(raw_path: String) -> bool:
	return resolve_path(raw_path) != ""


## Resuelve la ruta dada buscando de forma inteligente en el catálogo común de modelos.
## Aplica cascada de extensiones (.tscn > .glb > .gltf > .obj) y busca en subcarpetas.
static func resolve_path(raw_path: String) -> String:
	var key := raw_path.strip_edges()
	if key.is_empty():
		return ""
	if _path_cache.has(key):
		return _path_cache[key]

	var resolved := _do_resolve_path(key)
	_path_cache[key] = resolved
	return resolved


static func _do_resolve_path(raw: String) -> String:
	# 1. Normalizar compatibilidad con rutas legadas
	var clean := raw
	if "assets/world/character/" in clean:
		clean = clean.replace("assets/world/character/", "assets/common/models/characters/")
	elif "assets/dungeon/items/" in clean:
		clean = clean.replace("assets/dungeon/items/", "assets/common/models/interactive/")
	elif "assets/world/items/" in clean:
		clean = clean.replace("assets/world/items/", "assets/common/models/buildings/")
	elif "assets/combat/models/" in clean:
		clean = clean.replace("assets/combat/models/", "assets/common/models/legacy/")

	# 2. Si es una ruta explícita res:// o assets/...
	var p := normalize_path(clean)
	var direct_match := _check_file_with_extensions(p)
	if not direct_match.is_empty():
		return direct_match

	# 3. Extraer nombre base o ruta relativa
	var file_or_rel := clean.replace("res://", "")
	if file_or_rel.begins_with("assets/common/models/"):
		file_or_rel = file_or_rel.replace("assets/common/models/", "")

	# Resolver alias si existe (ej. 'chest' -> 'cofre')
	var stem := file_or_rel.get_file().get_basename().to_lower()
	var alias_stem: String = ALIASES.get(stem, "")
	var alias_rel := file_or_rel
	if not alias_stem.is_empty():
		alias_rel = file_or_rel.get_base_dir() + "/" + alias_stem if not file_or_rel.get_base_dir().is_empty() else alias_stem

	# 4. Probar en la raíz de BASE_MODELS_DIR
	var root_cand := _check_file_with_extensions(BASE_MODELS_DIR + file_or_rel)
	if not root_cand.is_empty():
		return root_cand
	if not alias_stem.is_empty():
		var root_alias := _check_file_with_extensions(BASE_MODELS_DIR + alias_rel)
		if not root_alias.is_empty():
			return root_alias

	# 5. Probar en cada subdirectorio categorizado
	var simple_name := file_or_rel.get_file()
	for sub: String in SUB_DIRS:
		var sub_cand := _check_file_with_extensions(BASE_MODELS_DIR + sub + "/" + file_or_rel)
		if not sub_cand.is_empty():
			return sub_cand
		if not alias_stem.is_empty():
			var sub_alias := _check_file_with_extensions(BASE_MODELS_DIR + sub + "/" + alias_stem)
			if not sub_alias.is_empty():
				return sub_alias
		if simple_name != file_or_rel:
			var sub_simple := _check_file_with_extensions(BASE_MODELS_DIR + sub + "/" + simple_name)
			if not sub_simple.is_empty():
				return sub_simple

	return ""


## Comprueba si un path existe tal cual o agregándole extensiones soportadas en orden de prioridad.
static func _check_file_with_extensions(path: String) -> String:
	if ResourceLoader.exists(path):
		return path

	var base := path
	# Si ya tiene una extensión conocida pero no existe, quitarla para probar las de mayor prioridad
	for ext: String in EXTENSIONS:
		if base.ends_with(ext):
			base = base.substr(0, base.length() - ext.length())
			break

	for ext: String in EXTENSIONS:
		var cand: String = base + ext
		if ResourceLoader.exists(cand):
			return cand

	return ""


## Normaliza una ruta dada a formato `res://...`.
static func normalize_path(raw_path: String) -> String:
	var p := raw_path.strip_edges()
	if p.is_empty():
		return ""
	if p.begins_with("res://"):
		return p
	if p.begins_with("/"):
		p = p.substr(1)
	return "res://" + p


## Limpia la caché interna de rutas y recursos (útil si se importan archivos en caliente).
static func clear_cache() -> void:
	_path_cache.clear()
	_resource_cache.clear()
