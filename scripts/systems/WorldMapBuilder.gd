# WorldMapBuilder.gd
# ─────────────────────────────────────────────────────────────────────────────
# Constructor del MAPAMUNDI (datos) que consume la vista 3D (TabWorld3D).
#
# DATA-DRIVEN: el mundo se define en `data/world.json` (rejilla de casillas con
# `terrain` y `object` opcional) y `data/ids/<id>.json` (definición de cada
# objeto, un fichero por entidad: nombre bilingüe, icono, tipo, npc, etc.).
# Ambos los carga el autoload `Design`.
# Aquí solo se TRADUCE ese diseño a un CellResource por coordenada.
#
# NOMENCLATURA UNIFICADA: el motor usa los MISMOS códigos que el JSON, tanto para
# terrenos (sea/cst/grs/gnd/mnt/bad/ice/des) como para recursos
# (forest/forestBad/rock/gold/fish/milk). No hay traducción a nombres
# internos: el valor de `terrain`/`resource` es literalmente el código del dato.
#
#   ✏️  EDITAR EL MUNDO = editar `data/world.json` / `data/ids/<id>.json` (a mano o con
#       el editor visual de `editor/`). No hace falta tocar este archivo para
#       añadir o mover casillas, ciudades, mazmorras, lugares o recursos.
#
# Rellena GlobalState.hexagons_db con un CellResource por coordenada.
# ─────────────────────────────────────────────────────────────────────────────
class_name WorldMapBuilder
extends RefCounted


# ─── OBJETOS GENÉRICOS (recursos sin entrada en data/ids/) → nodo recolectable ─
# El id del objeto en world.json ya ES el id del recurso (identidad); este mapa
# solo sirve para reconocer, por prefijo, qué objetos son recursos genéricos.
const GENERIC_RESOURCE: Dictionary = {
	"forest": "forest",
	"gold":   "gold",
	"rock":   "rock",
	"fish":   "fish",
	"milk":   "milk",
	"meat":   "meat",
}

# ─── TIPO DE OBJETO (data/ids/<id>.json) → LOCALIZACIÓN (item) del CellResource ─
const TYPE_TO_ITEM: Dictionary = {
	"city":    "ciudad",
	"village": "aldea",
	"house":   "casita",
	"dungeon": "cueva",
	"poi":     "place",
}


## Reconstruye GlobalState.hexagons_db completo a partir de Design.world/Design.ids.
static func build_into_global() -> void:
	GlobalState.hexagons_db.clear()

	var tiles: Array = Design.world.get("tiles", [])

	# Paso 1: construir el CellResource de cada casilla desde el JSON.
	for y in range(tiles.size()):
		var row: Array = tiles[y]
		for x in range(row.size()):
			var tile: Dictionary = row[x]
			if tile == null or tile.is_empty():
				continue
			var coord := Vector2i(x, y)
			var code := String(tile.get("terrain", "grs"))
			var obj := String(tile.get("object", ""))
			var cell := _make_cell(coord, code, obj)
			# Obstáculo rompible INLINE en el tile (además del que pueda venir del
			# objeto de data/ids/): permite colocar obstáculos sobre cualquier terreno
			# desde world.json / el editor, sin necesidad de un objeto dedicado.
			var tob = tile.get("obstacle", null)
			if tob is Dictionary and not (tob as Dictionary).is_empty():
				cell.obstacle = (tob as Dictionary).duplicate(true)
				# Aspecto INLINE opcional (icon/name/description): permite que un
				# obstáculo sin objeto de data/ids/ (p. ej. una roca bombeable suelta
				# sobre pradera) se vea distinto del terreno base en vez de heredar
				# su icono/nombre por defecto.
				if tile.has("icon"):
					cell.icon = String(tile["icon"])
				var tname = tile.get("name", null)
				if tname is Dictionary:
					cell.name_i18n = (tname as Dictionary).duplicate(true)
					cell.name = String(tname.get("es", cell.name))
				elif tname is String:
					cell.name = tname
				var tdesc = tile.get("description", null)
				if tdesc is Dictionary and not (tdesc as Dictionary).is_empty():
					cell.desc_i18n = (tdesc as Dictionary).duplicate(true)
					cell.description = String(tdesc.get("es", cell.description))
				elif tdesc is String:
					cell.description = tdesc
			# Objeto interactivo INLINE en el tile (cartel/lápida/libro…), colocable
			# desde world.json / el editor sin necesidad de un objeto de data/ids/.
			var tia = tile.get("interactive", null)
			if tia is Dictionary and not (tia as Dictionary).is_empty():
				cell.interactive = (tia as Dictionary).duplicate(true)
			# Enemigo del mapamundi INLINE en el tile (punto de aparición), colocable
			# desde world.json / el editor.
			var ten = tile.get("enemy", null)
			if ten is Dictionary and not (ten as Dictionary).is_empty():
				cell.enemy = (ten as Dictionary).duplicate(true)
			# Cofre con botín INLINE en el tile (data-driven), colocable desde
			# world.json / el editor sin necesidad de un objeto de data/ids/.
			var tchest = tile.get("chest", null)
			if tchest is Dictionary and not (tchest as Dictionary).is_empty():
				cell.chest = (tchest as Dictionary).duplicate(true)
				if cell.item == "":
					cell.item = "chest"
				if not tile.has("icon"):
					cell.icon = "🧰"
				if not tile.has("name"):
					cell.name = ""
				if not tile.has("description"):
					cell.description = Locale.pick({
						"es": "Un cofre con valiosas recompensas. ¡Tócalo para abrirlo!",
						"en": "A chest with valuable rewards. Touch it to open it!",
						"fr": "Un coffre avec de précieuses récompenses. Touche-le pour l'ouvrir !",
						"it": "Una cassa con ricompense preziose. Toccala per aprirla!",
						"de": "Eine Truhe mit wertvollen Belohnungen. Berühre sie, um sie zu öffnen!",
						"zh": "一个装有珍贵奖励的宝箱。触摸它以打开！",
						"ja": "貴重な報酬が入った宝箱。タッチして開けよう！",
					})
			GlobalState.hexagons_db[coord] = cell

	# Paso 2: derivar campos legado (type/required_skill) y metadatos de niebla.
	for coord: Vector2i in GlobalState.hexagons_db.keys():
		var c: CellResource = GlobalState.hexagons_db[coord] as CellResource
		c.derive_legacy()
		c.set_gather_depleted(c.is_gather_node() and GlobalState.get_gather_remaining(coord) <= 0)
		c.set_meta("visibility", 0)
		c.set_meta("explored", false)

	# Paso 3: reaplicar transformaciones de historia ya consumadas (persistencia).
	# Se enrutan por apply_transform (data-first: usa world_transforms.json si existe,
	# si no cae a la rutina cableada). Así la reconstrucción al cargar es data-driven.
	if GlobalState.get("dam_opened") == true:
		apply_transform("dam_opened")
	if GlobalState.get("cave_cleared") == true:
		apply_transform("cave_cleared")
	if QuestManager.is_quest_at_least("monkey_cleared"):
		apply_transform("monkey_cleared")
	# Persistencia GENÉRICA para transformaciones nuevas declaradas en
	# world_transforms.json (DSL `rules`, sin rutina cableada propia): se
	# reaplican si existe una gflag mundial con el MISMO nombre que la
	# transformación (convención: el reward que la dispara marca
	# `worldt:<nombre>;gflag:<nombre>` a la vez). Evita tener que ampliar este
	# método a mano por cada transformación nueva (p. ej. Acto 3).
	for transform_name in Design.world_transforms.keys():
		if transform_name in ["dam_opened", "cave_cleared", "monkey_cleared"]:
			continue
		var def: Dictionary = Design.get_world_transform(transform_name)
		if def.has("rules") and GlobalState.has_world_flag(transform_name):
			apply_transform(transform_name)

	# Paso 4: reaplicar la base del jugador si fue construida/establecida.
	if GlobalState.has_built_base and GlobalState.base_coord != Vector2i(-1, -1):
		var cell: CellResource = GlobalState.hexagons_db.get(GlobalState.base_coord, null) as CellResource
		if cell:
			cell.event_id = "base"
			cell.item = ""
			cell.resource = "base"
			cell.name_i18n = {
				"es": "Base de Operaciones", "en": "Base of Operations", "fr": "Base d'opérations",
				"it": "Base operativa", "de": "Operationsbasis", "zh": "作战基地", "ja": "活動拠点"
			}
			cell.name = Locale.pick(cell.name_i18n)
			cell.icon = "⛺"
			cell.desc_i18n = {
				"es": "Tu campamento base para descansar y cocinar.",
				"en": "Your base camp to rest and cook.",
				"fr": "Ton camp de base pour te reposer et cuisiner.",
				"it": "Il tuo campo base per riposare e cucinare.",
				"de": "Dein Basislager zum Ausruhen und Kochen.",
				"zh": "你休息和烹饪的基地营地。",
				"ja": "休息や料理をするための拠点キャンプ。"
			}
			cell.description = Locale.pick(cell.desc_i18n)
			cell.derive_legacy()

	# Paso 5: reaplicar los CAMBIOS FÍSICOS PERSISTENTES del jugador (pilar
	# "Transformar"). Es la capa genérica: árboles plantados/talados, rocas
	# destruidas, terreno excavado/canalizado, construcciones del campamento, etc.
	# Se aplica al final para que gane sobre el estado base y sobre las
	# transformaciones de historia. Ver GlobalState.world_deltas.
	apply_world_deltas()


## Crea un CellResource a partir del código de terreno y el id del objeto (o "").
static func _make_cell(coord: Vector2i, code: String, obj_id: String) -> CellResource:
	var cell := CellResource.new()
	cell.coord = coord
	var r: int = absi((coord.x * 73856093) ^ (coord.y * 19349663)) % 100
	_apply_terrain_visual(cell, code, r)

	if obj_id == "":
		return cell

	# Recursos genéricos (forest/rock/fish/milk): no viven en data/ids/.
	for prefix in GENERIC_RESOURCE.keys():
		if obj_id.begins_with(prefix):
			var res_id: String = GENERIC_RESOURCE[prefix]
			# Un bosque en yelmo o nieve es árido: se degrada a "árboles marchitos"
			# (mismo recurso —madera— pero con mucha menos capacidad).
			if res_id == "forest" and cell.terrain in ["bad", "ice"]:
				res_id = "forestBad"
			cell.resource = res_id
			_apply_resource_visual(cell, cell.resource)
			return cell

	# Recursos y obstáculos data-driven de data/world_resources/ (p. ej. bloqueo_piedra)
	var wres_def := Design.get_world_resource(obj_id)
	if not wres_def.is_empty():
		cell.resource = obj_id
		_apply_resource_visual(cell, cell.resource)
		if obj_id == "bloqueo_piedra":
			if cell.obstacle.is_empty():
				cell.obstacle = {
					"tool": "",
					"bombable": true,
					"reward": { "item": "stone", "qty": 3 },
					"after": { "resource": "" },
					"sfx": "hit",
					"orientation": "horizontal"
				}
		return cell

	# Objeto definido en data/ids/<id>.json (ciudad/aldea/casa/mazmorra/lugar).
	var spec: Dictionary = Design.get_id(obj_id)
	if spec.is_empty():
		push_warning("WorldMapBuilder: objeto '%s' sin entrada en data/ids/" % obj_id)
		return cell

	var otype := String(spec.get("type", ""))
	cell.event_id = obj_id
	# Aspecto visual en el mundo. Por defecto se deriva del `type` (TYPE_TO_ITEM),
	# pero cada ficha de data/ids/ puede declarar un `visual` explícito para desacoplar el aspecto
	# del tipo lógico. Así, tras unificar la taxonomía (aldea→city, casita→poi), una
	# ciudad puede seguir mostrándose con la maqueta de aldea (visual:"aldea"), etc.
	var visual := String(spec.get("visual", ""))
	cell.item = visual if visual != "" else String(TYPE_TO_ITEM.get(otype, "place"))

	# Visuales bilingües / multilingües
	var nm = spec.get("name", null)
	if nm is Dictionary:
		cell.name_i18n = (nm as Dictionary).duplicate(true)
		cell.name = String(nm.get("es", cell.name))
	elif nm is String:
		cell.name = nm
	if spec.has("icon"):
		cell.icon = String(spec["icon"])
	var ds = spec.get("desc", null)
	if ds is Dictionary and not (ds as Dictionary).is_empty():
		cell.desc_i18n = (ds as Dictionary).duplicate(true)
		cell.description = String(ds.get("es", cell.description))
	elif ds is String:
		cell.description = ds
	# Portal data-driven opcional: { view, event_id }. Permite que este POI
	# abra una mazmorra/escena concreta al pulsar ENTRAR (ver CellResource.opens_view).
	var pt = spec.get("portal", null)
	if pt is Dictionary:
		cell.portal = (pt as Dictionary).duplicate(true)
	# Ambiente data-driven opcional: { music?, weather? } (override de casilla).
	var amb = spec.get("ambience", null)
	if amb is Dictionary:
		cell.ambience = (amb as Dictionary).duplicate(true)
	# Puerta/muro condicionado opcional (gating): { dir, open_when }. Forma un muro de
	# 3 casillas que no se puede cruzar hacia `dir` mientras la condición sea falsa.
	var gt = spec.get("gate", null)
	if gt is Dictionary:
		cell.gate = (gt as Dictionary).duplicate(true)
	# Obstáculo rompible opcional (herramientas): { tool, after, reward?, ... }.
	var ob = spec.get("obstacle", null)
	if ob is Dictionary:
		cell.obstacle = (ob as Dictionary).duplicate(true)
	# Objeto interactivo opcional (cartel/lápida/libro…): { kind, title, text, ... }.
	var ia = spec.get("interactive", null)
	if ia is Dictionary:
		cell.interactive = (ia as Dictionary).duplicate(true)
	# Enemigo del mapamundi opcional (punto de aparición): { enemy_id, level, ... }.
	var en = spec.get("enemy", null)
	if en is Dictionary:
		cell.enemy = (en as Dictionary).duplicate(true)
	return cell


## Aplica el aspecto (nombre/icono/color) del terreno base de una casilla.
## Fuente ÚNICA: `data/world_terrains/<code>.json` (Design.get_terrain_def). Si el
## código no tiene ficha (o le falta el `icon`), cae al aspecto cableado de
## siempre (red de seguridad ante datos incompletos/ausentes).
static func _apply_terrain_visual(cell: CellResource, terr: String, r: int) -> void:
	cell.terrain = terr
	var def := Design.get_terrain_def(terr)
	if not def.is_empty() and def.has("icon"):
		_apply_terrain_def(cell, def, r)
		return
	match terr:
		"grs":  _apply_grs(cell, r)
		"des":  _apply_des(cell)
		"ice":  _apply_ice(cell)
		"bad":  _apply_bad(cell)
		"gnd":  _apply_gnd(cell)
		"cst":  _apply_cst(cell)
		"mnt":  _apply_mnt(cell)
		"lav":  _apply_lav(cell)
		_:      _apply_sea(cell)


## Aplica una definición data-driven de terreno (`data/world_terrains/<code>.json`)
## ya cargada, resolviendo `variants` (sub-biomas con peso, p. ej. la pradera
## alterna "Sendero"/"Pradera") de forma determinista con el hash `r` (mismo
## algoritmo que antes: `r` se calcula por coordenada en `_make_cell`).
static func _apply_terrain_def(cell: CellResource, def: Dictionary, r: int) -> void:
	var vis: Dictionary = def
	var variants = def.get("variants", null)
	if variants is Array and variants.size() > 0:
		var total := 0
		for v in variants:
			total += maxi(1, int((v as Dictionary).get("weight", 1)))
		var idx: int = r % maxi(total, 1)
		var acc := 0
		for v in variants:
			acc += maxi(1, int((v as Dictionary).get("weight", 1)))
			if idx < acc:
				vis = v
				break
	cell.name = String(vis.get("label", def.get("label", cell.terrain)))
	cell.icon = String(vis.get("icon", def.get("icon", "")))
	var bc = vis.get("biome_color", def.get("biome_color", ""))
	if String(bc) != "":
		cell.biome_color = Color(String(bc))
	var desc = vis.get("description", def.get("description", ""))
	if String(desc) != "":
		cell.description = String(desc)


# ─── APLICADORES DE BIOMA (rellenan nombre/icono/color y el terreno) ──────────
static func _apply_grs(cell: CellResource, r: int) -> void:
	if r % 3 == 0:
		cell.name = "Sendero"; cell.icon = "🌱"; cell.biome_color = Color("18241b")
	else:
		cell.name = "Pradera"; cell.icon = "🌿"; cell.biome_color = Color("1c2b17")
	cell.terrain = "grs"

static func _apply_des(cell: CellResource) -> void:
	cell.name = "Llanura Árida"; cell.icon = "🏜️"
	cell.terrain = "des"; cell.biome_color = Color("2a2418")

static func _apply_ice(cell: CellResource) -> void:
	cell.name = "Hielo"; cell.icon = "❄️"
	cell.terrain = "ice"; cell.biome_color = Color("d7e6ef")
	cell.description = "Hielo cortante; el frío cala hasta los huesos."

static func _apply_bad(cell: CellResource) -> void:
	cell.name = "Yelmo"; cell.icon = "🌫️"
	cell.terrain = "bad"; cell.biome_color = Color("6b6e73")

static func _apply_gnd(cell: CellResource) -> void:
	cell.name = "Tierra Fértil"; cell.icon = "🟫"
	cell.terrain = "gnd"; cell.biome_color = Color("4a3a28")
	cell.description = "Tierra fértil recuperada tras reabrir la presa."

static func _apply_cst(cell: CellResource) -> void:
	cell.name = "Orilla"; cell.icon = "🌊"
	cell.terrain = "cst"; cell.biome_color = Color("143b66")
	cell.description = "Agua poco profunda cerca de la costa."

static func _apply_sea(cell: CellResource) -> void:
	cell.name = "Agua Profunda"; cell.icon = "🌊"
	cell.terrain = "sea"; cell.biome_color = Color("0a1e36")
	cell.description = "Agua profunda que se extiende hasta el horizonte."

static func _apply_mnt(cell: CellResource) -> void:
	cell.name = "Montaña Impasable"; cell.icon = "🏔️"
	cell.terrain = "mnt"; cell.biome_color = Color("3a3a3c")
	cell.description = "Montañas escarpadas e imposibles de cruzar a pie."

static func _apply_lav(cell: CellResource) -> void:
	cell.name = "Lava"; cell.icon = "🌋"
	cell.terrain = "lav"; cell.biome_color = Color("8a2410")
	cell.description = "Roca fundida abrasadora; quema al pisarla."


## Aspecto de un nodo de recolección (nombre/icono/color) según su tipo. Fuente
## ÚNICA: `data/world_resources/<code>.json` (Design.get_world_resource); si no
## hay ficha, cae al aspecto cableado de siempre.
static func _apply_resource_visual(cell: CellResource, res: String) -> void:
	var def := Design.get_world_resource(res)
	if not def.is_empty():
		cell.name = String(def.get("label", res))
		cell.icon = String(def.get("icon", ""))
		var bc = def.get("biome_color", "")
		if String(bc) != "":
			cell.biome_color = Color(String(bc))
		var desc = def.get("description", "")
		if String(desc) != "":
			cell.description = String(desc)
		return
	match res:
		"forest":
			cell.name = "Bosque de Robles"; cell.icon = "🌲"; cell.biome_color = Color("0d3b20")
			cell.description = "Robles frondosos ideales para talar madera."
		"forestBad":
			cell.name = "Árboles Marchitos"; cell.icon = "🪵"; cell.biome_color = Color("2a3540")
			cell.description = "Árboles resecos; dan poca madera, pero algo es algo."
		"rock":
			cell.name = "Cantera de Piedra"; cell.icon = "⛰️"; cell.biome_color = Color("2c2b33")
			cell.description = "Una zona rocosa ideal para extraer piedra."
		"gold":
			cell.name = "Cantera de Oro"; cell.icon = "💰"; cell.biome_color = Color("30431a")
			cell.description = "Una veta dorada entre las rocas."
		"milk":
			cell.name = "Prado de Ganado"; cell.icon = "🐄"; cell.biome_color = Color("284d24")
			cell.description = "Vacas pastando en un prado tranquilo."
		"fish":
			cell.name = "Zona de Pesca"; cell.icon = "🎣"; cell.biome_color = Color("0f2742")
			cell.description = "Un buen lugar para lanzar la caña."


# ══════════════════════════════════════════════════════════════════════════════
# TRANSFORMACIONES DE HISTORIA (se reaplican al reconstruir el mundo al cargar)
# ══════════════════════════════════════════════════════════════════════════════
#
# DATA-FIRST: `apply_transform(name)` es el ÚNICO punto de
# entrada. Consulta `Design.get_world_transform(name)`:
#   · Si define `rules` → aplica el DSL declarativo (match → set) sobre las celdas.
#   · Si define `builtin:x` (o no hay datos) → cae a la rutina cableada `_builtin`.
# Las rutinas cableadas (dam/cave/monkey) se conservan como fallback y para los
# efectos PROCEDURALES que no se expresan en el DSL (la presa: río, proximidad,
# dispersión determinista de bosques). Devuelve las coords afectadas.


# ══════════════════════════════════════════════════════════════════════════════
# CAMBIOS FÍSICOS PERSISTENTES DEL JUGADOR (deltas por casilla · pilar Transformar)
# ══════════════════════════════════════════════════════════════════════════════
#
# Capa GENÉRICA que reaplica lo que el jugador cambió físicamente en el mundo
# (talar/plantar árboles, destruir rocas, excavar/canalizar agua, colocar el
# campamento o construcciones...). Los deltas se almacenan en
# GlobalState.world_deltas (clave "x,y" -> Dictionary de campos) y usan las mismas
# claves que el DSL de world_transforms, por lo que reutilizamos `_apply_set`.


## Reaplica TODOS los deltas persistentes de GlobalState.world_deltas sobre las
## casillas ya construidas de hexagons_db. Devuelve las coords afectadas.
static func apply_world_deltas() -> Array[Vector2i]:
	var affected: Array[Vector2i] = []
	for key in GlobalState.world_deltas.keys():
		var coord := _parse_coord_key(String(key))
		if coord == Vector2i(-1, -1):
			continue
		var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
		var changes = GlobalState.world_deltas[key]
		if cell == null or not (changes is Dictionary):
			continue
		# Purgar cartel de bienvenida antiguo de depuración si existía en partidas guardadas
		var ia: Dictionary = changes.get("interactive", {}) if changes.get("interactive") is Dictionary else {}
		var title_es: String = String(ia.get("title", {}).get("es", "") if ia.get("title") is Dictionary else ia.get("title", ""))
		if title_es == "Cartel de Bienvenida":
			GlobalState.world_deltas.erase(key)
			continue
		apply_delta_to_cell(cell, changes)
		if not affected.has(coord):
			affected.append(coord)
	return affected


## Aplica un único delta (Dictionary de campos) a una casilla concreta y recalcula
## sus campos legado. Punto de entrada usado también por GlobalState.record_world_delta
## para reflejar el cambio en vivo sin reconstruir todo el mundo.
static func apply_delta_to_cell(cell: CellResource, changes: Dictionary) -> void:
	if cell == null or changes == null or changes.is_empty():
		return
	_apply_set(cell, changes)
	cell.derive_legacy()


## Convierte una clave "x,y" en Vector2i. Devuelve (-1,-1) si es inválida.
static func _parse_coord_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	if not (parts[0].is_valid_int() and parts[1].is_valid_int()):
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


## Punto de entrada data-first de las transformaciones del mundo. Devuelve las
## coordenadas de celda modificadas (para que el llamante refresque el mapa).
static func apply_transform(name: String) -> Array[Vector2i]:
	var def: Dictionary = Design.get_world_transform(name)
	if def.has("rules") and def["rules"] is Array:
		return _apply_rules(def["rules"])
	# Sin reglas declarativas: builtin explícito o fallback por nombre.
	var builtin := String(def.get("builtin", name))
	return _run_builtin(builtin)


## Ejecuta una transformación PROCEDURAL cableada por nombre (fallback/builtin).
static func _run_builtin(name: String) -> Array[Vector2i]:
	match name:
		"dam_opened":
			apply_dam_opened()
			return []   # afecta a muchas celdas; el llamante reconstruye el mundo
		"cave_cleared":
			apply_cave_cleared()
			return []
		"monkey_cleared":
			var coord := apply_monkey_cleared()
			return [coord] if coord != Vector2i(-1, -1) else []
		_:
			push_warning("WorldMapBuilder: transformación desconocida '%s'" % name)
			return []


## Aplica una lista de reglas declarativas { match, set } a hexagons_db.
## Devuelve las coordenadas modificadas (sin duplicados).
static func _apply_rules(rules: Array) -> Array[Vector2i]:
	var affected: Array[Vector2i] = []
	for rule in rules:
		if not (rule is Dictionary):
			continue
		var crit: Dictionary = rule.get("match", {})
		var changes: Dictionary = rule.get("set", {})
		for coord: Vector2i in GlobalState.hexagons_db.keys():
			var cell: CellResource = GlobalState.hexagons_db[coord] as CellResource
			if cell == null or not _cell_matches(cell, crit, coord):
				continue
			_apply_set(cell, changes)
			cell.derive_legacy()
			if not affected.has(coord):
				affected.append(coord)
	return affected


## ¿La celda cumple TODOS los criterios de `match`? Claves admitidas:
## event_id, terrain, item, resource (igualdad de String) y coord ([x,y]).
static func _cell_matches(cell: CellResource, crit: Dictionary, coord: Vector2i) -> bool:
	for key in crit.keys():
		match key:
			"event_id":
				if cell.event_id != String(crit[key]): return false
			"terrain":
				if cell.terrain != String(crit[key]): return false
			"item":
				if cell.item != String(crit[key]): return false
			"resource":
				if cell.resource != String(crit[key]): return false
			"coord":
				var xy = crit[key]
				if xy is Array and xy.size() == 2:
					if coord != Vector2i(int(xy[0]), int(xy[1])): return false
				else:
					return false
			_:
				push_warning("WorldMapBuilder: criterio match desconocido '%s'" % key)
				return false
	return true


## Asigna los campos de `set` a la celda. Los textos (name/description) admiten
## String o Dictionary {es,en} (se traduce con Locale). `biome_color` es hex.
static func _apply_set(cell: CellResource, changes: Dictionary) -> void:
	for key in changes.keys():
		var v = changes[key]
		match key:
			"name":         cell.name = _text(v)
			"icon":         cell.icon = String(v)
			"description":  cell.description = _text(v)
			"terrain":      cell.terrain = String(v)
			"item":         cell.item = String(v)
			"resource":     cell.resource = String(v)
			"required_quest_state": cell.required_quest_state = String(v)
			"event_id":     cell.event_id = String(v)
			"biome_color":  cell.biome_color = Color(String(v))
			"obstacle":     cell.obstacle = (v as Dictionary).duplicate(true) if v is Dictionary else {}
			"interactive":  cell.interactive = (v as Dictionary).duplicate(true) if v is Dictionary else {}
			"enemy":        cell.enemy = (v as Dictionary).duplicate(true) if v is Dictionary else {}
			"crop":         cell.crop = (v as Dictionary).duplicate(true) if v is Dictionary else {}
			"path":         cell.path = String(v)
			"walkable":
				# Atajo declarativo (Task 5, 4.2 `set_collision_mask`): en vez de
				# escribir a mano el Dictionary `obstacle` completo, `walkable:false`
				# marca la celda sólida (obstacle.solid=true) y `walkable:true` la
				# libera (obstacle={}). Equivalente a `set.obstacle` pero legible.
				cell.obstacle = {} if bool(v) else {"solid": true}
			_:
				push_warning("WorldMapBuilder: campo set desconocido '%s'" % key)


## Resuelve un texto que puede ser String directo o {es,en} bilingüe.
static func _text(v: Variant) -> String:
	if v is Dictionary:
		return Locale.pick(v)
	return String(v)



## Despeja el Puente del Mono tras darle la banana: deja de ser una localización
## sólida y pasa a ser un puente transitable hacia el norte. Idempotente.
## Devuelve la coordenada afectada (o (-1,-1) si no hay puente en el mundo).
static func apply_monkey_cleared() -> Vector2i:
	for coord in GlobalState.hexagons_db:
		var cell: CellResource = GlobalState.hexagons_db[coord] as CellResource
		if cell.event_id == "poi_monkey_001":
			cell.name         = "Puente Libre"
			cell.icon         = "🌉"
			cell.terrain      = "cst"
			cell.item         = ""
			cell.resource     = ""
			cell.biome_color  = Color("4a3728")
			cell.required_quest_state = ""
			cell.derive_legacy()
			return coord
	return Vector2i(-1, -1)


## Abre la casilla de la cueva del monstruo tras derrotarlo: pasa a ser una
## casilla transitable (deja de ser una localización sólida).
static func apply_cave_cleared() -> void:
	for coord in GlobalState.hexagons_db:
		var cell: CellResource = GlobalState.hexagons_db[coord] as CellResource
		if cell != null:
			var target_id := cell.event_id
			if cell.portal is Dictionary and String((cell.portal as Dictionary).get("event_id", "")) != "":
				target_id = String((cell.portal as Dictionary)["event_id"])
			if target_id == "dun_yelmo" or target_id == "dun_yelmo_start" or target_id == "dun_001":
				cell.name = "Cueva Despejada"
				cell.description = "El paso está libre del monstruo, pero aún puedes entrar a explorar."


## Transforma el valle tras reabrir la presa:
##  - La columna de la presa (desde su casilla, 8 hacia abajo) se convierte en río.
##  - El yelmo a distancia <=2 del río pasa a pradera; el resto del yelmo, a tierra.
## Es idempotente: se puede reaplicar al recargar la partida.
## La geometría se calcula RELATIVA a la casilla de la presa (poi_presa_001), no con
## coordenadas fijas, para que siga funcionando si el mundo se redimensiona.
static func apply_dam_opened() -> void:
	# Localiza la presa dinámicamente (su event_id se conserva tras transformarse,
	# por lo que también funciona al reaplicar al recargar la partida).
	var presa := Vector2i(-1, -1)
	for coord: Vector2i in GlobalState.hexagons_db.keys():
		var cc: CellResource = GlobalState.hexagons_db[coord] as CellResource
		if cc != null and cc.event_id == "poi_presa_001":
			presa = coord
			break
	if presa == Vector2i(-1, -1):
		push_warning("WorldMapBuilder: apply_dam_opened sin casilla de presa (poi_presa_001).")
		return

	# 1. Río que baja desde la presa (su casilla + 8 hacia abajo, por su columna).
	var river: Array[Vector2i] = []
	for dy in range(0, 9):
		var coord := Vector2i(presa.x, presa.y + dy)
		var c: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
		if c == null:
			continue
		river.append(coord)
		if c.event_id == "poi_presa_001":
			# La presa sigue siendo una localización, pero ahora abierta y fluyendo.
			c.terrain = "cst"
			c.name = "Presa Abierta"
			c.icon = "🌊"
			c.description = "La presa fluye de nuevo; el agua baja libre hacia el valle."
			c.biome_color = Color("143b66")
		else:
			_apply_terrain_visual(c, "cst", 0)

	# 1b. Rama izquierda del río (4 casillas a la izquierda, 3 filas bajo la presa).
	for offset_x in range(1, 5):
		var coord := Vector2i(presa.x - offset_x, presa.y + 3)
		var c: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
		if c != null:
			river.append(coord)
			_apply_terrain_visual(c, "cst", 0)

	# 1c. Zonas de pesca: una junto a la presa y otras dos repartidas por las costas,
	# evitando que queden 3 seguidas en la misma columna.
	var fish_candidates: Array[Vector2i] = [
		presa + Vector2i(0, 1),   # justo debajo de la presa
		presa + Vector2i(-1, 3),  # costa izquierda cercana
		presa + Vector2i(-4, 3),  # costa izquierda lejana
	]
	for coord in fish_candidates:
		var fc: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
		if fc != null and fc.event_id == "" and fc.item == "":
			fc.resource = "fish"
			_apply_resource_visual(fc, "fish")
			fc.derive_legacy()

	# Límite occidental de la Zona 1 (Cueva de la Esfera / dun_inicial). La transformación
	# de la presa NUNCA debe sobrepasar hacia el oeste de esta coordenada para no
	# alterar la Zona Final (dun_final) ni su terreno volcánico/lava.
	var min_x := presa.x - 6
	for coord: Vector2i in GlobalState.hexagons_db.keys():
		var cc: CellResource = GlobalState.hexagons_db[coord] as CellResource
		if cc != null and (cc.event_id == "dun_inicial" or cc.event_id == "dun_001"):
			min_x = coord.x
			break

	# 2. Resto del yelmo del valle de la Zona 1: pradera si está cerca del río, si no tierra.
	# Se acota estrictamente a la Zona 1 (desde min_x hacia el este, sin afectar la Zona Final).
	# Se SALTAN las localizaciones/POIs/mazmorras (item o event_id): son contenido fijo.
	var new_praderas: Array[CellResource] = []
	for coord: Vector2i in GlobalState.hexagons_db.keys():
		var cell: CellResource = GlobalState.hexagons_db[coord] as CellResource
		if cell == null:
			continue
		# No avanzar más al oeste de la Cueva de la Esfera (min_x) ni fuera del valle
		if coord.x < min_x or coord.x > presa.x + 10:
			continue
		if coord.y < presa.y or coord.y > presa.y + 9:
			continue
		# Transformar el yelmo ("bad") y la lava ("lav") dentro del valle de la Zona 1 para extinguirla
		if cell.terrain != "bad" and cell.terrain != "lav":
			continue
		var near := false
		for rv in river:
			if maxi(absi(coord.x - rv.x), absi(coord.y - rv.y)) <= 2:
				near = true
				break
		var res := cell.resource   # preservar nodos (p. ej. canteras)
		# Al reabrir la presa el valle REVIVE: no puede quedar ningún árbol marchito
		# (forestBad). Se limpian para dejar paso a pradera/bosques sanos.
		if res == "forestBad":
			res = ""
		var item := cell.item
		var eid := cell.event_id
		var old_name := cell.name
		var old_desc := cell.description
		var old_icon := cell.icon
		if near:
			_apply_terrain_visual(cell, "grs", absi((coord.x * 73856093) ^ (coord.y * 19349663)) % 100)
			if res == "" and item == "" and eid == "":
				new_praderas.append(cell)
		else:
			_apply_terrain_visual(cell, "gnd", 0)
		cell.resource = res
		cell.item = item
		cell.event_id = eid
		if eid != "" or item != "":
			cell.name = old_name
			cell.description = old_desc
			cell.icon = old_icon
		if res != "":
			_apply_resource_visual(cell, res)

	# 3. Generar 4 bosques deterministas en las nuevas praderas.
	if new_praderas.size() > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 98765
		for i in range(new_praderas.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var temp = new_praderas[i]
			new_praderas[i] = new_praderas[j]
			new_praderas[j] = temp
		var limit := mini(4, new_praderas.size())
		for k in range(limit):
			var cell: CellResource = new_praderas[k]
			cell.resource = "forest"
			_apply_resource_visual(cell, "forest")

	# 4. Re-derivar campos legado de todo (el terreno cambió en muchas casillas).
	for coord: Vector2i in GlobalState.hexagons_db.keys():
		(GlobalState.hexagons_db[coord] as CellResource).derive_legacy()
