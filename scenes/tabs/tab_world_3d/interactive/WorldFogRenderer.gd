# WorldFogRenderer.gd
# ─────────────────────────────────────────────────────────────────────────────
# NIEBLA DE GUERRA (oculto / penumbra / visible) + VISIBILIDAD DE MARCADORES Y
# DECORACIÓN POR MULTIMESH + COLISIÓN DE RECURSOS AGOTADOS.
#
# Extraído de TabWorld3D.gd (antes en el #region "NIEBLA DE GUERRA" de un único
# fichero de ~4033 líneas). Cada función recibe `world: Node` explícito
# como primer parámetro en vez de depender de un `self` implícito, ya que
# necesita leer/escribir estado propio de TabWorld3D (_cells, _current_cell,
# _ground_mm, _grass_mm, _fog_queue/_fog_cursor/_fog_queued/_prev_fog_pos,
# _anim_coords/_nearby_anim...). Mismo patrón que interactive/TerrainToolsSystem.gd.
# ─────────────────────────────────────────────────────────────────────────────
class_name WorldFogRenderer
extends RefCounted


static func restore_explored(_world: Node) -> void:
	for coord in GlobalState.explored_coords.keys():
		if GlobalState.hexagons_db.has(coord):
			(GlobalState.hexagons_db[coord] as CellResource).set_meta("explored", true)


## Recalcula la visibilidad (meta) de UNA casilla respecto a la posición del jugador.
static func recompute_cell_fog(_world: Node, coord: Vector2i, p_pos: Vector2i) -> void:
	var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
	if cell == null:
		return
	var cheby: int = maxi(absi(p_pos.x - coord.x), absi(p_pos.y - coord.y))
	if cheby <= 1:
		cell.set_meta("visibility", 2)
		cell.set_meta("explored", true)
		GlobalState.mark_explored(coord)
	elif cell.get_meta("explored", false):
		cell.set_meta("visibility", 2)
	else:
		cell.set_meta("visibility", 0)


## Recalcula la niebla de las casillas CONSTRUIDAS. Uso puntual: inicio, teletransporte.
static func update_fog_of_war(world: Node, p_pos: Vector2i) -> void:
	for coord in world._cells.keys():
		recompute_cell_fog(world, coord, p_pos)
	world._prev_fog_pos = p_pos


## Encola (sin recalcular todavía) las casillas del entorno del jugador (ventana del
## radio de marcadores alrededor de la posición anterior y la nueva) para refrescar su
## niebla/visual. El trabajo real lo hace process_fog_queue() con presupuesto por
## frame: así encolar es O(ventana) pero instantáneo (solo Dictionary/Array.append),
## y el cálculo pesado (set_meta, MultiMesh, visibilidad de nodos) se reparte en varios
## frames en vez de bloquear uno solo (causa de los tirones al cruzar de casilla).
## Encola (sin recalcular todavía) las casillas del entorno del jugador para refrescar su
## niebla/visual. El trabajo real lo hace process_fog_queue() con presupuesto por
## frame: reparte el cálculo pesado (MultiMesh, visibilidad de nodos) en varios frames.
static func fog_step(world: Node, old_pos: Vector2i, new_pos: Vector2i) -> void:
	if old_pos == new_pos:
		return
	for dy in range(-world.MARKER_RADIUS_Z, world.MARKER_RADIUS_Z + 1):
		for dx in range(-world.MARKER_RADIUS_X, world.MARKER_RADIUS_X + 1):
			var c: Vector2i = new_pos + Vector2i(dx, dy)
			if world._fog_queued.has(c) or not world._cells.has(c):
				continue

			# Optimización: Solo encolar si no está explorada o si tiene marcador/etiqueta
			var cell: CellResource = GlobalState.hexagons_db.get(c, null) as CellResource
			if cell != null:
				var is_explored: bool = cell.get_meta("explored", false)
				var e: Dictionary = world._cells.get(c, {})
				var has_marker: bool = (not e.is_empty()) and (e["obj"] != null or e["label"] != null)
				if is_explored and not has_marker:
					continue

			world._fog_queued[c] = true
			world._fog_queue.append(c)

	# Encolar únicamente las casillas salientes que tengan marcadores/etiquetas para apagarlos
	for dy in range(-world.MARKER_RADIUS_Z, world.MARKER_RADIUS_Z + 1):
		for dx in range(-world.MARKER_RADIUS_X, world.MARKER_RADIUS_X + 1):
			var oc: Vector2i = old_pos + Vector2i(dx, dy)
			if absi(oc.x - new_pos.x) > world.MARKER_RADIUS_X or absi(oc.y - new_pos.y) > world.MARKER_RADIUS_Z:
				if not world._fog_queued.has(oc) and world._cells.has(oc):
					var e: Dictionary = world._cells.get(oc, {})
					if not e.is_empty() and (e["obj"] != null or e["label"] != null):
						world._fog_queued[oc] = true
						world._fog_queue.append(oc)
	world._prev_fog_pos = new_pos


## Consume la cola de niebla con un presupuesto por frame escalado con la velocidad del jugador.
## Usa siempre world._current_cell para que el resultado sea correcto aunque el jugador siga andando.
static func process_fog_queue(world: Node) -> void:
	if world._fog_cursor >= world._fog_queue.size():
		if world._fog_cursor > 0:
			world._fog_queue.clear()
			world._fog_cursor = 0
		return
	var budget: int = world.FOG_BUDGET_PER_FRAME
	if GlobalState.debug_mode and GlobalState.debug_speed_mult > 1.5:
		budget = int(budget * GlobalState.debug_speed_mult)
	var n: int = mini(budget, world._fog_queue.size() - world._fog_cursor)
	for i in range(n):
		var c: Vector2i = world._fog_queue[world._fog_cursor]
		world._fog_cursor += 1
		world._fog_queued.erase(c)
		# ¿Estaba esta casilla aún en la niebla ANTES de recalcular? Si un POI real
		# sale de la niebla por primera vez al caminar, se celebra el descubrimiento.
		var cell_pre: CellResource = GlobalState.hexagons_db.get(c, null) as CellResource
		var was_explored: bool = cell_pre != null and cell_pre.get_meta("explored", false)
		recompute_cell_fog(world, c, world._current_cell)
		apply_cell_visual(world, c)
		if not was_explored and cell_pre != null and cell_pre.get_meta("explored", false):
			world._maybe_announce_discovery(c, cell_pre)


## Reconstruye la lista de casillas animadas cercanas (acota el coste de _process).
static func rebuild_nearby(world: Node) -> void:
	world._nearby_anim.clear()
	for coord in world._anim_coords:
		if world._cheby(coord, world._current_cell) <= world.ANIM_RADIUS:
			world._nearby_anim.append(coord)


## Aplica visibilidad/niebla a TODAS las casillas (uso puntual: inicio, teletransporte).
static func apply_visibility(world: Node) -> void:
	for coord in world._cells.keys():
		apply_cell_visual(world, coord)


## Busca recursivamente CollisionObject3D dentro del nodo de un recurso.
static func find_collision_objects(node: Node, out: Array[CollisionObject3D]) -> void:
	if node is CollisionObject3D:
		out.append(node as CollisionObject3D)
	for c in node.get_children():
		find_collision_objects(c, out)


## Activa o desactiva las capas de colisión de los CollisionObject3D del nodo de
## recolección, recordando su estado original para poder restaurarlo.
static func update_gather_collision(e: Dictionary, disabled: bool) -> void:
	var state: Dictionary = e.get("gather_collision_state", {})
	if state.get("disabled", false) == disabled:
		return
	var col_objects: Array[CollisionObject3D] = []
	find_collision_objects(e["obj"], col_objects)
	if disabled:
		state = {"disabled": true, "layers": {}, "masks": {}}
		for co in col_objects:
			state["layers"][co.get_instance_id()] = co.collision_layer
			state["masks"][co.get_instance_id()] = co.collision_mask
			co.collision_layer = 0
			co.collision_mask = 0
	else:
		var layers: Dictionary = state.get("layers", {})
		var masks: Dictionary = state.get("masks", {})
		for co in col_objects:
			co.collision_layer = int(layers.get(co.get_instance_id(), co.collision_layer))
			co.collision_mask = int(masks.get(co.get_instance_id(), co.collision_mask))
		state = {"disabled": false}
	e["gather_collision_state"] = state


## Aplica la niebla de UNA casilla: escribe su COLOR de instancia en la MultiMesh de
## suelo y césped (lo lee el shader para atenuar), muestra/oculta su marcador/etiqueta
## y gestiona la colisión de recursos agotados. Sin culling por-tile.
static func apply_cell_visual(world: Node, coord: Vector2i) -> void:
	var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
	if cell == null:
		return
	var e: Dictionary = world._cells.get(coord, {})
	if e.is_empty():
		return
	var vis: int = int(cell.get_meta("visibility", 0))

	# ── Marcador/edificio (nodos): culling por distancia + niebla ──
	# Se evalúa SIEMPRE (barato: solo alterna .visible) porque su estado depende de la
	# distancia al jugador, que cambia aunque el nivel de niebla no lo haga.
	if e["obj"] != null or e["label"] != null or e.get("stone_path") != null:
		var near: bool = absi(coord.x - world._current_cell.x) <= world.MARKER_RADIUS_X and absi(coord.y - world._current_cell.y) <= world.MARKER_RADIUS_Z
		# Nodo de recolección agotado (árbol talado, banco de pesca vaciado…):
		# desaparece hasta que se regenere (ver GlobalState.get_gather_remaining).
		var depleted: bool = cell.is_gather_node() and GlobalState.get_gather_remaining(coord) <= 0
		cell.set_gather_depleted(depleted)
		if depleted:
			near = false
		# Los recursos agotados no deben seguir colisionando si aun contienen formas.
		if cell.is_gather_node() and e["obj"] != null:
			update_gather_collision(e, depleted)
		if e["obj"] != null:
			(e["obj"] as Node3D).visible = near and vis >= 1
		if e.get("stone_path") != null:
			(e["stone_path"] as Node3D).visible = near and vis >= 1
		if e["label"] != null:
			var label_near: bool = absi(coord.x - world._current_cell.x) <= 1 and absi(coord.y - world._current_cell.y) <= 1
			(e["label"] as Label3D).visible = label_near and vis == 2

	# ── MultiMesh: solo actualizar si cambió la visibilidad o el estado de recolección ──
	var remaining: int = GlobalState.get_gather_remaining(coord) if cell.is_gather_node() else 0
	var vis_changed: bool = int(e.get("vis_applied", -1)) != vis
	var remaining_changed: bool = cell.is_gather_node() and int(e.get("remaining_applied", -999)) != remaining

	if not vis_changed and not remaining_changed:
		return

	e["vis_applied"] = vis
	if cell.is_gather_node():
		e["remaining_applied"] = remaining

	# ── Decoración y recursos en MultiMesh (flores, setas, troncos, rocas, lápidas, esqueletos, montaña, etc.):
	# En niebla total (vis == 0) se ocultan completamente (escala 0).
	# Cuando se descubren (vis >= 1), los recursos de recolección responden a su agotamiento
	# y el resto de decoraciones estáticas se posicionan en su transform base.
	var decor_group: String = e.get("decor_group", "")
	var decor_idx: int = int(e.get("decor_index", -1))
	if decor_group != "" and decor_idx >= 0:
		var dmm: MultiMesh = world._ground_mm.get(decor_group, null)
		var worn_group: String = e.get("decor_worn_group", "")
		var rmm_worn: MultiMesh = world._ground_mm.get(worn_group, null) if worn_group != "" else null
		var base_xform: Transform3D = e.get("decor_xform", Transform3D.IDENTITY)
		var zero_xform := Transform3D().scaled(Vector3.ZERO)

		if vis == 0:
			if dmm != null:
				dmm.set_instance_transform(decor_idx, zero_xform)
			if rmm_worn != null:
				rmm_worn.set_instance_transform(decor_idx, zero_xform)
		else:
			if cell.is_gather_node():
				if remaining <= 0:
					if dmm != null:
						dmm.set_instance_transform(decor_idx, zero_xform)
					if rmm_worn != null:
						rmm_worn.set_instance_transform(decor_idx, zero_xform)
				elif remaining == 1 and rmm_worn != null:
					if dmm != null:
						dmm.set_instance_transform(decor_idx, zero_xform)
					rmm_worn.set_instance_transform(decor_idx, base_xform)
				else:
					if dmm != null:
						dmm.set_instance_transform(decor_idx, base_xform)
					if rmm_worn != null:
						rmm_worn.set_instance_transform(decor_idx, zero_xform)
			else:
				if dmm != null:
					dmm.set_instance_transform(decor_idx, base_xform)

	# ── Suelo + césped (MultiMesh): solo se reescribe el color si cambió la niebla ──
	if not vis_changed:
		return

	var f: float = 1.0
	if vis == 0:
		f = 0.0
	var col := Color(f, f, f, 1.0)

	# Suelo: color de instancia (lo multiplica el shader sobre ALBEDO/EMISSION).
	var mm: MultiMesh = world._ground_mm.get(e["group"], null)
	if mm != null:
		mm.set_instance_color(int(e["mm_index"]), col)

	# Césped de esta casilla: misma atenuación. _grass_mm es ahora un Dictionary
	# chunk_coord -> MultiMesh: hay que resolver
	# primero a qué chunk pertenece esta casilla.
	var gmm: MultiMesh = world._grass_mm.get(e.get("chunk", Vector2i.ZERO), null)
	if gmm != null:
		for gi in e["grass_indices"]:
			gmm.set_instance_color(int(gi), col)

	# Decoración instanciada (p. ej. montaña, troncos caídos): misma atenuación por color.
	if decor_group != "":
		var dmm: MultiMesh = world._ground_mm.get(decor_group, null)
		if dmm != null and decor_idx >= 0:
			dmm.set_instance_color(decor_idx, col)

	var worn_group_vis: String = e.get("decor_worn_group", "")
	if worn_group_vis != "":
		var wmm: MultiMesh = world._ground_mm.get(worn_group_vis, null)
		if wmm != null and decor_idx >= 0:
			wmm.set_instance_color(decor_idx, col)
