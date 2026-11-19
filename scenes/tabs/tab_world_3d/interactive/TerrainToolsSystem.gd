# TerrainToolsSystem.gd
# ─────────────────────────────────────────────────────────────────────────────
# HERRAMIENTAS + MODIFICACIÓN DEL TERRENO (data-driven, persistente vía deltas):
# botón contextual de herramienta (romper obstáculo / excavar / plantar)
# y BOMBAS (consumible que demuele obstáculos preparados).
#
# Extraído de TabWorld3D.gd (antes en el #region "HERRAMIENTAS + MODIFICACIÓN
# DEL TERRENO" de un único fichero de ~4500 líneas). Cada función recibe
# `world: Node` explícito como primer parámetro en vez de depender de un
# `self` implícito, ya que necesita leer/escribir estado propio de TabWorld3D
# (_tool_target, _terrain_action, _btn_tool, _btn_bomb, _bombs_active...).
# ─────────────────────────────────────────────────────────────────────────────
class_name TerrainToolsSystem
extends RefCounted


## ¿La casilla es un obstáculo rompible AHORA MISMO por el jugador? (declara
## `obstacle.tool` y el jugador posee esa herramienta).
static func cell_has_actionable_obstacle(cell: CellResource) -> bool:
	if cell == null or not (cell.obstacle is Dictionary) or cell.obstacle.is_empty():
		return false
	var tool_id := String(cell.obstacle.get("tool", ""))
	return tool_id != "" and GlobalState.has_item(tool_id)


## Busca el obstáculo objetivo de la herramienta: primero la casilla actual, luego
## sus 4 vecinas ortogonales. Devuelve su coord, o INVALID si no hay ninguno
## accionable. Permite "abrir caminos" bloqueados desde la casilla contigua.
static func find_tool_target(world: Node) -> Vector2i:
	var cur: CellResource = GlobalState.hexagons_db.get(world._current_cell, null) as CellResource
	if cell_has_actionable_obstacle(cur):
		return world._current_cell
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nc: Vector2i = world._current_cell + d
		var ncell: CellResource = GlobalState.hexagons_db.get(nc, null) as CellResource
		if cell_has_actionable_obstacle(ncell):
			return nc
	return Vector2i(-9999, -9999)


## Muestra/oculta el botón de herramienta. Prioriza el obstáculo rompible; si no
## hay ninguno, ofrece una acción de MODIFICACIÓN DE TERRENO (excavar/plantar).
static func update_tool_button(world: Node) -> void:
	if world._btn_tool == null:
		return
	update_bomb_button(world)
	world._tool_target = find_tool_target(world)
	if world._tool_target != Vector2i(-9999, -9999):
		world._terrain_action = {}
		var cell: CellResource = GlobalState.hexagons_db.get(world._tool_target, null) as CellResource
		var ob: Dictionary = cell.obstacle
		var tool_id := String(ob.get("tool", ""))
		var tool_icon := Design.get_item_icon(tool_id)
		var label: String
		if ob.has("label"):
			label = text_localized(ob["label"])
		else:
			label = Locale.pick({"es": "Usar", "en": "Use"})
		world._btn_tool.text = "%s %s" % [tool_icon, label]
		world._btn_tool.visible = true
		return
	# Sin obstáculo: ¿hay una acción de terreno disponible con la herramienta actual?
	world._terrain_action = find_terrain_action(world)
	if world._terrain_action.is_empty():
		world._btn_tool.visible = false
		return
	var ticon: String = Design.get_item_icon(String(world._terrain_action.get("tool", "")))
	world._btn_tool.text = "%s %s" % [ticon, text_localized(world._terrain_action.get("label", ""))]
	world._btn_tool.visible = true


## Aplica el uso de la herramienta sobre el obstáculo objetivo: concede la
## recompensa, aplica el cambio `after` de forma PERSISTENTE (world_deltas) y
## limpia el obstáculo para que no se repita. Refresca visual, gating y panel.
static func on_tool_pressed(world: Node) -> void:
	# Sin obstáculo objetivo: puede ser una acción de MODIFICACIÓN DE TERRENO.
	if world._tool_target == Vector2i(-9999, -9999):
		if not world._terrain_action.is_empty():
			apply_terrain_action(world, world._terrain_action)
		return
	var cell: CellResource = GlobalState.hexagons_db.get(world._tool_target, null) as CellResource
	if not cell_has_actionable_obstacle(cell):
		return
	var ob: Dictionary = cell.obstacle.duplicate(true)

	# Recompensa opcional (madera/piedra/mineral/tesoro…).
	var reward = ob.get("reward", null)
	if reward is Dictionary:
		var rid := String(reward.get("item", ""))
		var rqty := int(reward.get("qty", 1))
		if rid != "" and rqty > 0:
			GlobalState.add_item(rid, rqty, Design.get_item_name(rid), "", Design.get_item_icon(rid))
			GlobalState.discover_resource(rid)
			world._spawn_world_float("%s +%d" % [Design.get_item_icon(rid), rqty], UiKit.GOOD)

	# Cambio PERSISTENTE del mundo: fusionamos `after` con el borrado del obstáculo
	# para que el estado quede consumado para siempre (pilar "Transformar").
	var changes: Dictionary = {}
	var after = ob.get("after", null)
	if after is Dictionary:
		for k in (after as Dictionary).keys():
			changes[k] = after[k]
	changes["obstacle"] = {}
	GlobalState.record_world_delta(world._tool_target, changes)

	# Feedback + refresco: sonido, animación de golpe y reconstrucción visual del
	# mapa (el terreno/marcador modificado se refleja al instante).
	AudioManager.play_sfx(String(ob.get("sfx", "hit")))
	world._play_chop()
	world._rebuild_tiles()
	world._recompute_gates()
	SaveManager.request_autosave()

	# Reevaluar el panel (el obstáculo ya no existe; puede aparecer otra acción).
	var here: CellResource = GlobalState.hexagons_db.get(world._current_cell, null) as CellResource
	if here:
		world._update_location_panel(here)


## ¿Hay agua (mar/orilla) en alguna casilla ortogonal a `coord`?
static func adjacent_to_water(coord: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: CellResource = GlobalState.hexagons_db.get(coord + d, null) as CellResource
		if nb != null and nb.terrain in ["sea", "cst"]:
			return true
	return false


## ¿`coord` está a 2 o más casillas de distancia de cualquier mar/costa? (ver
## task4.md: el cultivo no vale en suelo salino cercano al agua). Comprueba
## que ninguna casilla a distancia <= 1 (las 8 vecinas + ella misma) sea
## "sea"/"cst"; si la más cercana está a distancia 1, se rechaza.
static func _is_far_enough_from_water(coord: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var nc := coord + Vector2i(dx, dy)
			var cell: CellResource = GlobalState.hexagons_db.get(nc, null) as CellResource
			if cell != null and (cell.terrain == "sea" or cell.terrain == "cst"):
				return false
	return true


## ¿La casilla está totalmente vacía (sin localización, recurso, evento, objeto
## interactivo ni enemigo)? Para poder plantar/modificar sin pisar otro contenido.
static func cell_is_bare(cell: CellResource) -> bool:
	if cell == null:
		return false
	return cell.item == "" and cell.resource == "" and cell.event_id == "" \
		and (not (cell.interactive is Dictionary) or cell.interactive.is_empty()) \
		and (not (cell.enemy is Dictionary) or cell.enemy.is_empty())


## Determina la acción de MODIFICACIÓN DE TERRENO disponible con la herramienta que
## el jugador posee, sobre la casilla actual. Devuelve un
## dict { coord, tool, label, changes, reward?, sfx? } o {} si ninguna aplica.
## Reglas del pilar "Transformar" (herramientas multiuso):
##   · PALA + arena/llanura árida (des) junto al mar → excavar: se llena de agua (cst).
##   · PALA + pradera (grs) vacía → plantar un árbol (nodo de bosque · madera).
static func find_terrain_action(world: Node) -> Dictionary:
	var cur: CellResource = GlobalState.hexagons_db.get(world._current_cell, null) as CellResource
	if cur == null:
		return {}

	# 1) Excavar arena junto al mar (Pala) → agua.
	if GlobalState.has_item("pala") and cur.terrain == "des" and cell_is_bare(cur) \
			and adjacent_to_water(world._current_cell):
		return {
			"coord": world._current_cell, "tool": "pala",
			"label": {"es": "Excavar arena", "en": "Dig sand"},
			"changes": {
				"terrain": "cst", "resource": "", "item": "", "icon": "🌊",
				"name": {"es": "Agua", "en": "Water"},
				"description": {"es": "Agua que ha ganado terreno tras excavar la arena.", "en": "Water that flooded in after digging the sand."},
				"biome_color": "143b66",
			},
			"sfx": "hit",
		}

	# 2) Plantar un árbol en pradera vacía (Pala).
	if GlobalState.has_item("pala") and cur.terrain == "grs" and cell_is_bare(cur) \
			and not cur.is_solid():
		return {
			"coord": world._current_cell, "tool": "pala",
			"label": {"es": "Plantar árbol", "en": "Plant tree"},
			"changes": {
				"resource": "forest", "icon": "🌲",
				"name": {"es": "Bosque plantado", "en": "Planted grove"},
				"description": {"es": "Un árbol que plantaste. Con el tiempo dará madera.", "en": "A tree you planted. In time it yields wood."},
			},
			"sfx": "hit",
		}

	# 3) Cosechar un cultivo YA MADURO (Agricultor). No requiere herramienta: basta
	#    con que haya pasado un ciclo día/noche completo desde que se plantó (ver
	#    `CellResource.is_crop_mature` / `TimeManager.full_day_duration_sec`).
	if cur.is_growing_crop() and cur.is_crop_mature():
		var seed_id: String = String(cur.crop.get("type", ""))
		var cdef: Dictionary = GameConfig.CROP_TYPES.get(seed_id, {})
		if not cdef.is_empty():
			var crop_label: Dictionary = cdef.get("label", {})
			# Semillas "terraform" (p. ej. Cactus): en vez de dar un ítem de
			# cosecha, transforman la propia casilla (ver GameConfig.CROP_TYPES).
			var terraform: Dictionary = cdef.get("terraform", {})
			if not terraform.is_empty():
				var changes: Dictionary = {"crop": {}}
				for k in terraform.keys():
					changes[k] = terraform[k]
				return {
					"coord": world._current_cell, "tool": seed_id,
					"label": {
						"es": "🌳 Reverdecer (%s)" % String(crop_label.get("es", "")),
						"en": "🌳 Bloom (%s)" % String(crop_label.get("en", "")),
					},
					"changes": changes,
					"skill_xp": {"skill": "agricultor", "amount": GameConfig.CROP_HARVEST_XP},
					"sfx": "gather",
				}
			var harvest_item := String(cdef.get("harvest_item", ""))
			return {
				"coord": world._current_cell, "tool": harvest_item,
				"label": {
					"es": "Cosechar %s" % String(crop_label.get("es", "")),
					"en": "Harvest %s" % String(crop_label.get("en", "")),
				},
				"changes": {"crop": {}},
				"reward": {"item": harvest_item, "qty": int(cdef.get("harvest_qty", 1))},
				"skill_xp": {"skill": "agricultor", "amount": GameConfig.CROP_HARVEST_XP},
				"sfx": "gather",
			}

	# 4) Plantar una semilla (Agricultor) en terreno despejado y sin cultivo.
	# Restringido al territorio de la Base y lejos del mar/costa (ver task4.md):
	# el suelo salino cercano al agua no vale para cultivar. El terreno válido
	# depende de la semilla (`CROP_TYPES[id].terrain`, p. ej. el cactus se
	# planta en arena de desierto, no en tierra/pradera).
	if not cur.is_growing_crop() and cell_is_bare(cur) \
			and not cur.is_solid() and GlobalState.is_within_base_territory(world._current_cell) \
			and _is_far_enough_from_water(world._current_cell):
		for seed_id in GameConfig.CROP_TYPES.keys():
			if GlobalState.has_item(seed_id):
				var cdef: Dictionary = GameConfig.CROP_TYPES[seed_id]
				var allowed_terrain: Array = cdef.get("terrain", ["gnd", "grs"])
				if not allowed_terrain.has(cur.terrain):
					continue
				var crop_label: Dictionary = cdef.get("label", {})
				return {
					"coord": world._current_cell, "tool": seed_id,
					"label": {
						"es": "Plantar %s" % String(crop_label.get("es", "")),
						"en": "Plant %s" % String(crop_label.get("en", "")),
					},
					"changes": {"crop": {"type": seed_id, "planted_at": int(Time.get_unix_time_from_system())}},
					"consume": {"item": seed_id, "qty": 1},
					"skill_xp": {"skill": "agricultor", "amount": GameConfig.CROP_PLANT_XP},
					"sfx": "hit",
				}

	return {}


## Ejecuta una acción de modificación de terreno: concede su recompensa (si la hay),
## aplica el cambio PERSISTENTE (world_deltas) y refresca el mundo. Si la casilla
## pasa a ser sólida (p. ej. al plantar) y el jugador está encima, lo reubica.
static func apply_terrain_action(world: Node, act: Dictionary) -> void:
	var coord: Vector2i = act["coord"]
	var reward = act.get("reward", null)
	if reward is Dictionary and String(reward.get("item", "")) != "":
		var rid := String(reward["item"])
		var rqty := int(reward.get("qty", 1))
		GlobalState.add_item(rid, rqty, Design.get_item_name(rid), "", Design.get_item_icon(rid))
		GlobalState.discover_resource(rid)
		world._spawn_world_float("%s +%d" % [Design.get_item_icon(rid), rqty], UiKit.GOOD)

	# Consumo opcional de un ítem del jugador (p. ej. la semilla al plantar), a
	# diferencia de `tool` (arriba, en find_terrain_action) que solo exige
	# POSEER la herramienta sin gastarla (pala/pico/hacha son reutilizables).
	var consume = act.get("consume", null)
	if consume is Dictionary:
		var cid := String(consume.get("item", ""))
		var cqty := int(consume.get("qty", 1))
		if cid != "" and cqty > 0:
			GlobalState.remove_item(cid, cqty)

	# XP de oficio opcional (p. ej. Agricultor al plantar/cosechar un cultivo).
	var sxp = act.get("skill_xp", null)
	if sxp is Dictionary:
		var skey := String(sxp.get("skill", ""))
		var samt := int(sxp.get("amount", 0))
		if skey != "" and samt > 0:
			GlobalState.add_skill_xp(skey, samt)

	GlobalState.record_world_delta(coord, act["changes"])
	AudioManager.play_sfx(String(act.get("sfx", "hit")))
	world._play_chop()
	world._rebuild_tiles()
	world._recompute_gates()
	SaveManager.request_autosave()

	# Si la casilla modificada se ha vuelto sólida (p. ej. árbol plantado) y el
	# jugador quedó dentro, empujarlo a una vecina transitable.
	var mod: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
	if coord == world.player_pos and mod != null and mod.is_solid():
		world._nudge_player_off_solid_cell(coord)

	world._terrain_action = {}
	var here: CellResource = GlobalState.hexagons_db.get(world._current_cell, null) as CellResource
	if here:
		world._update_location_panel(here)


# ══════════════════════════════════════════════════════════════════════════════
# BOMBAS (consumible) — se colocan, estallan tras unos segundos y demuelen
#   obstáculos preparados (obstacle.bombable). Persistente vía world_deltas.
# ══════════════════════════════════════════════════════════════════════════════
const BOMB_FUSE_SECS: float = 5.0   # tiempo de mecha antes de estallar (5 segundos)

## ¿Hay un obstáculo DEMOLIBLE (obstacle.bombable) en la casilla actual o vecina?
static func has_bombable_target(world: Node) -> bool:
	var candidates: Array[Vector2i] = [world._current_cell]
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		candidates.append(world._current_cell + d)
	for coord in candidates:
		var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
		if cell != null:
			if cell.resource == "bloqueo_piedra":
				return true
			if cell.obstacle is Dictionary and bool(cell.obstacle.get("bombable", false)):
				return true
	return false


## Muestra el botón de BOMBA cuando tiene sentido: el jugador posee una bomba y,
## o bien hay un obstáculo demolible cerca, o la casilla actual está libre (sin
## item) para plantarla ahí — una opción más del mapamundi, igual que Farmear o
## la Tienda de Campaña, no solo un botón contextual atado a un obstáculo.
static func update_bomb_button(world: Node) -> void:
	if world._btn_bomb == null:
		return
	var cur: CellResource = GlobalState.hexagons_db.get(world._current_cell, null) as CellResource
	var can_place_here: bool = cur != null and cell_is_bare(cur) and not cur.is_solid()
	if GlobalState.has_item("bomba") and (can_place_here or has_bombable_target(world)) and world._bombs_active < 3:
		world._btn_bomb.text = "%s %s" % [Design.get_item_icon("bomba"), Locale.pick({"es": "Poner bomba", "en": "Place bomb"})]
		world._btn_bomb.visible = true
	else:
		world._btn_bomb.visible = false


## Coloca una bomba en la casilla actual: consume el consumible, instancia el actor
## con mecha y programa la explosión. La curación no interviene aquí.
static func on_place_bomb_pressed(world: Node) -> void:
	if not GlobalState.has_item("bomba"):
		return
	GlobalState.remove_item("bomba", 1)
	world._btn_bomb.visible = false
	spawn_bomb_actor(world, world._current_cell)
	AudioManager.play_sfx("click")


## Instancia el actor visual de la bomba (esfera oscura + mecha parpadeante) y
## lanza su cuenta atrás de 5 segundos con contador grande; al terminar, detona.
static func spawn_bomb_actor(world: Node, coord: Vector2i) -> void:
	world._bombs_active += 1
	var node := Node3D.new()
	node.position = world._cell_to_world(coord)
	world._tiles_root.add_child(node)

	var bomb_model := ModelLoader.load_model("bomba", 0.7)
	var bomb_mat: StandardMaterial3D = null
	if bomb_model != null:
		bomb_model.position.y = 0.0
		node.add_child(bomb_model)
	else:
		var body := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.26
		sph.height = 0.52
		body.mesh = sph
		bomb_mat = StandardMaterial3D.new()
		bomb_mat.albedo_color = Color(0.08, 0.08, 0.1)
		body.material_override = bomb_mat
		body.position.y = 0.3
		node.add_child(body)

	var spark := Label3D.new()
	spark.text = "💥"
	spark.font_size = 90
	spark.pixel_size = 0.005
	spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spark.position.y = 0.90
	node.add_child(spark)

	# Contador grande bien visible (5, 4, 3, 2, 1) sobre la bomba
	var countdown_label := Label3D.new()
	countdown_label.text = "5"
	countdown_label.font_size = 140
	countdown_label.outline_size = 16
	countdown_label.modulate = Color(1.0, 0.25, 0.15)
	countdown_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	countdown_label.pixel_size = 0.006
	countdown_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	countdown_label.position.y = 1.35
	node.add_child(countdown_label)

	# Luz roja de alerta que parpadea mientras arde la mecha
	var blink_light := OmniLight3D.new()
	blink_light.light_color = Color(1.0, 0.1, 0.05)
	blink_light.light_energy = 0.0
	blink_light.omni_range = 1.4
	blink_light.position.y = 0.35
	node.add_child(blink_light)

	# Parpadeo rojo/normal de la mecha (cuerpo + luz + emoji) hasta detonar.
	var tw: Tween = node.create_tween().set_loops()
	tw.tween_property(spark, "modulate:a", 0.2, 0.18)
	tw.parallel().tween_property(blink_light, "light_energy", 1.8, 0.18)
	if bomb_mat != null:
		tw.parallel().tween_property(bomb_mat, "albedo_color", Color(0.9, 0.05, 0.05), 0.18)
	tw.tween_property(spark, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(blink_light, "light_energy", 0.0, 0.18)
	if bomb_mat != null:
		tw.parallel().tween_property(bomb_mat, "albedo_color", Color(0.08, 0.08, 0.1), 0.18)

	# Cuenta atrás de 5 segundos actualizando el cartel grande cada segundo
	for sec_remaining in range(int(BOMB_FUSE_SECS), 0, -1):
		if not is_instance_valid(node):
			break
		countdown_label.text = str(sec_remaining)
		if sec_remaining <= 2:
			countdown_label.modulate = Color(1.0, 0.1, 0.1) # Rojo intenso al final
			countdown_label.scale = Vector3(1.3, 1.3, 1.3)
		else:
			countdown_label.modulate = Color(1.0, 0.6, 0.1) if sec_remaining > 3 else Color(1.0, 0.3, 0.1)
			countdown_label.scale = Vector3(1.15, 1.15, 1.15)
		var pop_tween: Tween = world.create_tween()
		pop_tween.tween_property(countdown_label, "scale", Vector3(1.0, 1.0, 1.0), 0.35)
		await world.get_tree().create_timer(1.0).timeout

	if is_instance_valid(tw):
		tw.kill()
	if is_instance_valid(node):
		node.queue_free()
	detonate_bomb(world, coord)


## Los 8 vecinos de una casilla (anillo completo, no solo ortogonales): la
## explosión de una bomba afecta a la casilla en la que se puso Y a TODAS las
## de alrededor (task2_mundo.md).
const _BLAST_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## Detona en `coord`: destruye los obstáculos demolibles (aplicando su `after`
## de forma persistente y dando su recompensa) Y agota de golpe cualquier
## nodo de recolección farmeable (árbol/cantera/oro/pesca/ganado…) que haya en
## esa casilla o en las 8 de alrededor — igual que si se hubiera recolectado a
## mano hasta vaciarlo, pero de un solo golpe. Refresca el mundo.
static func detonate_bomb(world: Node, coord: Vector2i) -> void:
	world._bombs_active = maxi(0, world._bombs_active - 1)
	AudioManager.play_sfx("hit")
	world._spawn_world_float("💥", UiKit.WARN)

	var affected: Array[Vector2i] = [coord]
	for d in _BLAST_NEIGHBORS:
		affected.append(coord + d)
	var changed: bool = false
	var hit_animal: bool = false
	for c in affected:
		var cell: CellResource = GlobalState.hexagons_db.get(c, null) as CellResource
		if cell == null:
			continue

		var is_animal: bool = cell.resource in ["milk", "meat", "cerdo", "cerdos", "vaca", "vacas", "cow", "pigs"] or cell.item in ["milk", "meat", "cerdo", "cerdos", "vaca", "vacas", "cow", "pigs"] or cell.object in ["milk", "meat"]
		if is_animal:
			hit_animal = true

		# 1) Obstáculo demolible (p. ej. "Bloqueo de piedra" o "Camino bloqueado por piedra"): se
		# destruye con efecto visual y aplica su `after` (libera el paso).
		var is_bloqueo: bool = cell.resource == "bloqueo_piedra"
		var is_bombable_ob: bool = cell.obstacle is Dictionary and bool(cell.obstacle.get("bombable", false))
		if is_bloqueo or is_bombable_ob:
			var ob: Dictionary = cell.obstacle.duplicate(true) if cell.obstacle is Dictionary else {}
			var reward = ob.get("reward", null)
			if reward is Dictionary:
				var rid := String(reward.get("item", ""))
				var rqty := int(reward.get("qty", 1))
				if rid != "" and rqty > 0:
					GlobalState.add_item(rid, rqty, Design.get_item_name(rid), "", Design.get_item_icon(rid))
					GlobalState.discover_resource(rid)
			elif is_bloqueo:
				GlobalState.add_item("stone", 3, Design.get_item_name("stone"), "", Design.get_item_icon("stone"))
				GlobalState.discover_resource("stone")
				world._spawn_world_float("🪨 +3", UiKit.GOOD)

			var changes: Dictionary = {}
			var after = ob.get("after", null)
			if after is Dictionary:
				for k in (after as Dictionary).keys():
					changes[k] = after[k]
			if is_bloqueo:
				changes["resource"] = ""
				changes["object"] = ""
			changes["obstacle"] = {}
			GlobalState.record_world_delta(c, changes)
			var obstacle_entry: Dictionary = world._cells.get(c, {})
			var obstacle_obj: Node3D = obstacle_entry.get("obj") as Node3D
			var obstacle_pos: Vector3 = (obstacle_obj.global_position if obstacle_obj != null else world._cell_to_world(c)) + Vector3(0.0, 0.6, 0.0)
			WorldFx.burst(world, obstacle_pos, Color(0.55, 0.52, 0.5), 28)
			changed = true

		# 2) Nodo de recolección farmeable: la explosión lo agota de golpe,
		# entregando TODO lo que le quedaba (árbol/piedra/oro/pesca/ganado).
		if cell.is_gather_node():
			var remaining: int = GlobalState.get_gather_remaining(c)
			if remaining > 0:
				var taken: int = GlobalState.consume_gather(c, remaining)
				if taken > 0:
					var res: Dictionary = world._resolve_gather_res(cell)
					var item_id: String = String(res.get("item", "wood"))
					var res_name: String = Locale.t(String(res.get("item_loc", "res_wood")))
					var icon: String = String(res.get("icon", "📦"))
					GlobalState.add_item(item_id, taken, res_name, String(res.get("category", "other")), icon)
					GlobalState.discover_resource(item_id)
					GlobalState.report_gather(item_id, taken)
					world._spawn_world_float("%s +%d" % [icon, taken], UiKit.GOOD)
					var gather_entry: Dictionary = world._cells.get(c, {})
					var gather_obj: Node3D = gather_entry.get("obj") as Node3D
					var gather_pos: Vector3 = (gather_obj.global_position if gather_obj != null else world._cell_to_world(c)) + Vector3(0.0, 0.6, 0.0)
					WorldFx.harvest_fx(world, gather_obj, gather_pos, Color(0.62, 0.60, 0.58))
					WorldFogRenderer.apply_cell_visual(world, c)
					changed = true

	if hit_animal and OrbBarksManager != null:
		var bark_txt := Locale.pick({
			"es": "¡Debería darte vergüenza! ¡Ese pobre animalito no te había hecho nada!",
			"en": "You should be ashamed, that poor little animal hadn't done anything to you!"
		})
		OrbBarksManager.trigger_bark(bark_txt, 5.0)

	if changed:
		world._rebuild_tiles()
		world._recompute_gates()
		SaveManager.request_autosave()
	var here: CellResource = GlobalState.hexagons_db.get(world._current_cell, null) as CellResource
	if here:
		world._update_location_panel(here)


## Resuelve un texto que puede ser String o {es,en} bilingüe.
static func text_localized(v: Variant) -> String:
	if v is Dictionary:
		return Locale.pick(v)
	return String(v)
