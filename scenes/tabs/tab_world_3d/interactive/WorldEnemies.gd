# WorldEnemies.gd
# ─────────────────────────────────────────────────────────────────────────────
# ENEMIGOS DEL MAPAMUNDI (actores dinámicos · ): deambulan lento y
# aleatorio sin alejarse más de 1 casilla de su aparición, nunca persiguen al
# jugador y, al contacto, inician combate. Al vencerlos desaparecen (y
# reaparecen si su `respawn` > 0). Estado persistido en GlobalState.
#
# Extraído de TabWorld3D.gd (antes en el #region "HERRAMIENTAS + MODIFICACIÓN
# DEL TERRENO" de un único fichero de ~4500 líneas, mal encuadrado dentro de
# esa región). Cada función recibe `world: Node` explícito como primer
# parámetro en vez de depender de un `self` implícito, ya que necesita leer/
# escribir estado propio de TabWorld3D (_enemies, _enemy_rng,
# _enemy_combat_pending, player_pos...).
# ─────────────────────────────────────────────────────────────────────────────
class_name WorldEnemies
extends RefCounted

## Intervalo (s) entre comprobaciones de reaparición de enemigos derrotados.
static var _respawn_check_accum: float = 0.0
const RESPAWN_CHECK_INTERVAL: float = 5.0
static var _enemy_spawn_coords: Array[Vector2i] = []


static func _ensure_enemy_coords_indexed() -> void:
	if _enemy_spawn_coords.is_empty():
		for coord in GlobalState.hexagons_db.keys():
			var cell: CellResource = GlobalState.hexagons_db[coord] as CellResource
			if cell != null and cell.enemy is Dictionary and not cell.enemy.is_empty():
				_enemy_spawn_coords.append(coord)


## Comprueba si un enemigo del mapa debe estar activo y renderizado.
static func is_enemy_active(coord: Vector2i, cell: CellResource) -> bool:
	if cell == null or not (cell.enemy is Dictionary) or cell.enemy.is_empty():
		return false
	var enemy_id := String(cell.enemy.get("enemy", cell.enemy.get("enemy_id", cell.enemy.get("id", ""))))
	if enemy_id == "jefe_puerto":
		if not GlobalState.has_world_flag("boss_puerto_activo") or GlobalState.has_world_flag("boss_puerto_derrotado"):
			return false
	return not GlobalState.is_overworld_enemy_defeated(coord)


## Crea los actores de todos los puntos de aparición de enemigos vivos del mundo.
static func build_enemies(world: Node) -> void:
	if world._enemy_rng.seed == 0:
		world._enemy_rng.randomize()
	_ensure_enemy_coords_indexed()
	for coord in _enemy_spawn_coords:
		var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
		if cell == null or not is_enemy_active(coord, cell):
			continue
		spawn_enemy_actor(world, coord, cell.enemy)


## Reconcilia los actores con el estado persistido: elimina los derrotados, descarta
## los cuyo nodo se haya liberado (p. ej. tras _rebuild_tiles) y vuelve a crear los
## que falten. Se llama al volver de combate y tras reconstruir el mundo.
static func refresh_enemies(world: Node) -> void:
	# Marcar derrotados/inactivos e inhabilitar visibilidad/contacto en lugar de re-entrar en combate.
	for spawn in world._enemies.keys():
		var e: Dictionary = world._enemies[spawn]
		var node = e.get("node")
		var invalid: bool = node == null or not is_instance_valid(node)
		if invalid:
			world._enemies.erase(spawn)
			continue
		var cell: CellResource = GlobalState.hexagons_db.get(spawn, null) as CellResource
		if not is_enemy_active(spawn, cell):
			e["is_defeated"] = true
			e["coord"] = spawn
			node.visible = false
		else:
			e["is_defeated"] = false
			node.visible = true
	# Reaparecer los que están activos y no tienen actor usando la lista pre-indexada.
	_ensure_enemy_coords_indexed()
	for coord in _enemy_spawn_coords:
		var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
		if cell == null or not is_enemy_active(coord, cell):
			continue
		if not world._enemies.has(coord):
			spawn_enemy_actor(world, coord, cell.enemy)
	world._enemy_combat_pending = false


## Instancia el actor de un enemigo en su punto de aparición: esfera oscura,
## ojos rojos verticales, aura siniestra y estela de polvo maligno.
## Si es un jefe (is_boss o jefe_puerto), adquiere dimensiones mayores, un anillo
## rúnico en el suelo, anillos de energía orbitales giratorios, emisión profunda y
## chispas incandescentes que saltan continuamente.
static func spawn_enemy_actor(world: Node, spawn: Vector2i, def: Dictionary) -> void:
	var node := Node3D.new()
	node.visible = false
	node.position = world._cell_to_world(spawn)
	world._tiles_root.add_child(node)

	var enemy_id_str := String(def.get("id", def.get("enemy", def.get("enemy_id", ""))))
	var is_boss: bool = bool(def.get("is_boss", false)) or enemy_id_str == "jefe_puerto"

	# Paleta oscura uniforme para todos los enemigos del mapamundi.
	var core_color := Color(0.06, 0.06, 0.06, 1.0)
	var glow_color := Color(0.9, 0.05, 0.05, 1.0)

	# 1. Peana tintada para indicar área de peligro
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.52 if is_boss else 0.32
	base_mesh.bottom_radius = 0.62 if is_boss else 0.36
	base_mesh.height = 0.12 if is_boss else 0.08
	base.mesh = base_mesh
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.18, 0.03, 0.03, 0.95) if is_boss else Color(core_color.r * 0.5, core_color.g * 0.5, core_color.b * 0.5, 0.9)
	if is_boss:
		base_mat.emission_enabled = true
		base_mat.emission = Color(0.8, 0.15, 0.05)
		base_mat.emission_energy_multiplier = 0.8
	base.material_override = base_mat
	base.position.y = 0.05 if is_boss else 0.04
	node.add_child(base)

	# 1b. Anillo rúnico exterior en el suelo para jefes
	if is_boss:
		var ground_ring := MeshInstance3D.new()
		var g_torus := TorusMesh.new()
		g_torus.inner_radius = 0.72
		g_torus.outer_radius = 0.82
		ground_ring.mesh = g_torus
		var g_mat := StandardMaterial3D.new()
		g_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		g_mat.albedo_color = Color(1.0, 0.25, 0.05, 0.85)
		ground_ring.material_override = g_mat
		ground_ring.position.y = 0.02
		node.add_child(ground_ring)

	# 2. Esfera oscura con brillo rojo interior (más imponente si es jefe)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.50 if is_boss else 0.32
	sphere.height = 1.00 if is_boss else 0.64
	orb.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.01, 0.02, 1.0) if is_boss else core_color
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.05, 1.0) if is_boss else glow_color
	mat.emission_energy_multiplier = 1.8 if is_boss else 0.9
	orb.material_override = mat
	orb.position.y = 0.75 if is_boss else 0.55
	node.add_child(orb)

	# 3. Ojos verticales rojos mirando hacia la cámara
	var eye_y: float = 0.86 if is_boss else 0.62
	var eye_z: float = 0.42 if is_boss else 0.26
	var eye_x: float = 0.20 if is_boss else 0.13
	var eye_left := _make_vertical_eye(glow_color if not is_boss else Color(1.0, 0.35, 0.1), is_boss)
	eye_left.position = Vector3(-eye_x, eye_y, eye_z)
	node.add_child(eye_left)
	var eye_right := _make_vertical_eye(glow_color if not is_boss else Color(1.0, 0.35, 0.1), is_boss)
	eye_right.position = Vector3(eye_x, eye_y, eye_z)
	node.add_child(eye_right)

	# 3b. Anillos de energía giroscópicos / orbitales alrededor de la esfera del jefe
	var boss_ring: MeshInstance3D = null
	var boss_ring2: MeshInstance3D = null
	if is_boss:
		boss_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.66
		torus.outer_radius = 0.74
		boss_ring.mesh = torus
		var ring_mat := StandardMaterial3D.new()
		ring_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.albedo_color = Color(1.0, 0.45, 0.1, 0.9)
		boss_ring.material_override = ring_mat
		boss_ring.position.y = 0.75
		boss_ring.rotation_degrees = Vector3(25, 0, 15)
		node.add_child(boss_ring)

		boss_ring2 = MeshInstance3D.new()
		var torus2 := TorusMesh.new()
		torus2.inner_radius = 0.68
		torus2.outer_radius = 0.75
		boss_ring2.mesh = torus2
		var ring_mat2 := StandardMaterial3D.new()
		ring_mat2.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		ring_mat2.albedo_color = Color(1.0, 0.18, 0.05, 0.8)
		boss_ring2.material_override = ring_mat2
		boss_ring2.position.y = 0.75
		boss_ring2.rotation_degrees = Vector3(-35, 45, -20)
		node.add_child(boss_ring2)

	# 4. Etiqueta flotante "Lv X" / "👑 JEFE DEL PUERTO · Lv X"
	var lvl: int = int(def.get("level", 1))
	var lvl_label := Label3D.new()
	if is_boss:
		if enemy_id_str == "jefe_puerto":
			lvl_label.text = "👑 JEFE DEL PUERTO · Lv %d" % lvl
		else:
			lvl_label.text = "👑 JEFE · Lv %d" % lvl
		lvl_label.font_size = 56
		lvl_label.pixel_size = 0.0055
		lvl_label.modulate = Color(1.0, 0.88, 0.25, 1.0)
		lvl_label.outline_size = 18
		lvl_label.position.y = 1.55
	else:
		lvl_label.text = "Lv %d" % lvl
		lvl_label.font_size = 48
		lvl_label.pixel_size = 0.005
		lvl_label.modulate = Color(0.95, 0.9, 0.85, 0.9)
		lvl_label.outline_size = 14
		lvl_label.position.y = 1.05
	lvl_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lvl_label.font = UiKit.theme_font()
	lvl_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
	lvl_label.no_depth_test = true
	node.add_child(lvl_label)

	# 5. Partículas: polvo maligno estándar o chispas + llamas oscuras para el jefe
	if is_boss:
		# Chispas vivas que saltan del boss
		var sparks := CPUParticles3D.new()
		sparks.amount = 45
		sparks.lifetime = 0.8
		sparks.local_coords = false
		sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		sparks.emission_sphere_radius = 0.45
		sparks.direction = Vector3(0.0, 1.0, 0.0)
		sparks.spread = 80.0
		sparks.gravity = Vector3(0.0, -2.8, 0.0)
		sparks.initial_velocity_min = 2.2
		sparks.initial_velocity_max = 4.2
		sparks.scale_amount_min = 0.06
		sparks.scale_amount_max = 0.16
		sparks.color = Color(1.0, 0.85, 0.25, 1.0)
		var spark_mat := StandardMaterial3D.new()
		spark_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		spark_mat.vertex_color_use_as_albedo = true
		var spark_mesh := BoxMesh.new()
		spark_mesh.size = Vector3(0.09, 0.09, 0.09)
		spark_mesh.material = spark_mat
		sparks.mesh = spark_mesh
		sparks.position.y = 0.75
		node.add_child(sparks)

		# Miasma / llamas oscuras carmesí
		var dark_flames := CPUParticles3D.new()
		dark_flames.amount = 28
		dark_flames.lifetime = 1.1
		dark_flames.local_coords = false
		dark_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		dark_flames.emission_sphere_radius = 0.35
		dark_flames.direction = Vector3(0.0, 1.0, 0.0)
		dark_flames.spread = 35.0
		dark_flames.gravity = Vector3(0.0, 0.4, 0.0)
		dark_flames.initial_velocity_min = 0.4
		dark_flames.initial_velocity_max = 1.0
		dark_flames.scale_amount_min = 0.10
		dark_flames.scale_amount_max = 0.25
		dark_flames.color = Color(0.75, 0.08, 0.12, 0.6)
		var flame_mat := StandardMaterial3D.new()
		flame_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flame_mat.vertex_color_use_as_albedo = true
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.10
		flame_mesh.height = 0.20
		flame_mesh.material = flame_mat
		dark_flames.mesh = flame_mesh
		dark_flames.position.y = 0.6
		node.add_child(dark_flames)
	else:
		var trail := CPUParticles3D.new()
		trail.amount = 24
		trail.lifetime = 1.2
		trail.local_coords = false
		trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		trail.emission_sphere_radius = 0.18
		trail.direction = Vector3(0.0, 0.5, 0.0)
		trail.gravity = Vector3(0.0, 0.1, 0.0)
		trail.initial_velocity_min = 0.05
		trail.initial_velocity_max = 0.15
		trail.scale_amount_min = 0.05
		trail.scale_amount_max = 0.12
		trail.color = Color(0.15, 0.02, 0.02, 0.6)
		trail.position.y = 0.4
		node.add_child(trail)

	# 6. Punto de luz propio
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.25, 0.08) if is_boss else Color(0.9, 0.1, 0.1)
	light.light_energy = 1.8 if is_boss else 0.35
	light.omni_range = 4.2 if is_boss else 1.8
	light.position.y = 0.75 if is_boss else 0.55
	node.add_child(light)

	# Asignar a la estructura de datos
	var radius: int = int(def.get("radius", 1))
	var speed: float = float(def.get("speed", 1.0))
	var interval: float = 3.5 / speed if speed > 0.0 else 9999.0
	world._enemies[spawn] = {
		"node": node,
		"spawn": spawn,
		"coord": spawn,
		"def": def,
		"radius": radius,
		"interval": interval,
		"accum": world._enemy_rng.randf_range(0.0, interval * 0.8),
		"is_defeated": false,
		"boss_ring": boss_ring,
		"boss_ring2": boss_ring2,
	}


## Crea una línea vertical roja a modo de ojo.
static func _make_vertical_eye(glow_color: Color, is_boss: bool = false) -> MeshInstance3D:
	var eye := MeshInstance3D.new()
	var eye_mesh := BoxMesh.new()
	eye_mesh.size = Vector3(0.06, 0.28, 0.06) if is_boss else Vector3(0.04, 0.18, 0.04)
	eye.mesh = eye_mesh
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.2, 0.05, 1.0) if is_boss else Color(1.0, 0.0, 0.0, 1.0)
	eye_mat.emission_enabled = true
	eye_mat.emission = glow_color
	eye_mat.emission_energy_multiplier = 3.0 if is_boss else 2.0
	eye.material_override = eye_mat
	return eye


## Avance por frame de todos los enemigos: acumula tiempo y da un paso aleatorio
## cuando toca. También comprueba el contacto con el jugador y las reapariciones.
static func process_enemies(world: Node, delta: float) -> void:
	if world._enemy_combat_pending or world._is_cinematic_active or GlobalState.is_movement_locked:
		return
	# Reconciliar enemigos periódicamente para que los respawns aparezcan en caliente.
	_respawn_check_accum += delta
	if _respawn_check_accum >= RESPAWN_CHECK_INTERVAL:
		_respawn_check_accum = 0.0
		refresh_enemies(world)
	for spawn in world._enemies.keys():
		var e: Dictionary = world._enemies[spawn]
		var node = e.get("node")
		if node == null or not is_instance_valid(node):
			continue
		# Visibilidad según niebla de guerra y distancia.
		var is_defeated: bool = bool(e.get("is_defeated", false)) or GlobalState.is_overworld_enemy_defeated(spawn)
		if is_defeated:
			e["is_defeated"] = true
			node.visible = false
			continue

		var near: bool = world._cheby(e["coord"], world._current_cell) <= world.MARKER_RADIUS_X
		if not near:
			if node.visible:
				node.visible = false
			continue

		var c_cell: CellResource = GlobalState.hexagons_db.get(e["coord"], null) as CellResource
		var vis: int = int(c_cell.get_meta("visibility", 0)) if c_cell != null else 0
		node.visible = vis >= 1
		if not node.visible:
			continue

		# Rotación continua de anillos orbitales si es jefe
		if e.has("boss_ring") and e["boss_ring"] != null and is_instance_valid(e["boss_ring"]):
			e["boss_ring"].rotate_y(delta * 2.0)
		if e.has("boss_ring2") and e["boss_ring2"] != null and is_instance_valid(e["boss_ring2"]):
			e["boss_ring2"].rotate_x(delta * 1.5)

		# Suavizar el desplazamiento hacia su casilla objetivo (más lento).
		var target: Vector3 = world._cell_to_world(e["coord"])
		node.position = node.position.lerp(target, clampf(delta * 2.0, 0.0, 1.0))
		# Levitación y bamboleo sutil de la esfera.
		node.position.y = sin(Time.get_ticks_msec() / 1000.0 * 2.2 + float(spawn.x * 3 + spawn.y)) * 0.06
		var radius: int = int(e.get("radius", 1))
		var speed: float = float(e.get("def", {}).get("speed", 1.0))
		if radius > 0 and speed > 0.0:
			e["accum"] = float(e["accum"]) + delta
			if float(e["accum"]) >= float(e["interval"]):
				e["accum"] = 0.0
				step_enemy(world, e)
		if world._enemy_combat_pending:
			return


## Da un paso aleatorio a una casilla vecina (o se queda quieto) sin alejarse más
## del radio de patrulla asignado (`radius`) ni pisar terreno intransitable/sólido.
static func step_enemy(world: Node, e: Dictionary) -> void:
	var spawn: Vector2i = e["spawn"]
	if bool(e.get("is_defeated", false)) or GlobalState.is_overworld_enemy_defeated(spawn):
		return
	var cur: Vector2i = e["coord"]
	var radius: int = int(e.get("radius", 1))
	var options: Array[Vector2i] = [cur]   # quedarse quieto siempre es válido
	for nc in GlobalState.get_surrounding_hex_coords(cur):
		if world._cheby(nc, spawn) > radius:
			continue   # respeta el radio máximo de patrulla
		var cell: CellResource = GlobalState.hexagons_db.get(nc, null) as CellResource
		if cell == null or not cell.is_walkable_terrain() or cell.is_solid():
			continue
		# TERRITORIO DE LA BASE: los enemigos no pueden entrar (ver task4.md).
		if GlobalState.is_within_base_territory(nc):
			continue
		# CAMINO DE PIEDRA: los enemigos no pueden pisar caminos de piedra (pth).
		if cell.has_stone_path():
			continue
		options.append(nc)
	var pick: Vector2i = options[world._enemy_rng.randi_range(0, options.size() - 1)]
	e["coord"] = pick
	# Contacto con el jugador → combate.
	if pick == world.player_pos:
		trigger_overworld_combat(world, e)


## Inicia el combate contra un enemigo del mapamundi, pasándole su punto de
## aparición y el respawn para que la victoria lo marque como derrotado.
static func trigger_overworld_combat(world: Node, e: Dictionary) -> void:
	if world._enemy_combat_pending:
		return
	var spawn: Vector2i = e.get("spawn", Vector2i(-1, -1))
	if bool(e.get("is_defeated", false)) or (spawn != Vector2i(-1, -1) and GlobalState.is_overworld_enemy_defeated(spawn)):
		return
	world._enemy_combat_pending = true
	var def: Dictionary = e["def"]
	var enemy_id := String(def.get("enemy", def.get("enemy_id", "slime")))
	var level := int(def.get("level", 1))
	var respawn_raw = def.get("respawn", true)
	var respawn_secs: int = 0
	if respawn_raw is bool:
		respawn_secs = 120 if respawn_raw else 0
	elif respawn_raw is int or respawn_raw is float:
		respawn_secs = int(respawn_raw)
	else:
		respawn_secs = 120

	var enemy_data: Dictionary = EnemyDatabase.build_enemy(enemy_id, level, false)
	enemy_data["cell_coord"] = e["spawn"]
	enemy_data["overworld_respawn"] = respawn_secs
	enemy_data["allow_flee"] = true
	var target_coord: Vector2i = e.get("spawn", world.player_pos)
	var cell_res: CellResource = GlobalState.hexagons_db.get(target_coord, null) as CellResource
	if cell_res == null:
		cell_res = GlobalState.hexagons_db.get(world.player_pos, null) as CellResource
	if cell_res != null:
		enemy_data["world_terrain"] = cell_res.terrain
	var zone_def: Dictionary = Design.get_zone_at(target_coord)
	enemy_data["world_zone"] = String(zone_def.get("id", ""))
	
	# Efecto/destello de impacto al entrar en combate
	Juice.flash(world, Color(1.0, 0.2, 0.2, 0.4), 0.2)
	AudioManager.play_sfx("click")
	QuestManager.combat_triggered.emit(enemy_data)


## Comprueba si algún enemigo está sobre la casilla del jugador (tras moverse el
## jugador). Se llama al cruzar de casilla.
static func check_enemy_contact(world: Node) -> void:
	if world._enemy_combat_pending:
		return
	for spawn in world._enemies.keys():
		var e: Dictionary = world._enemies[spawn]
		if bool(e.get("is_defeated", false)) or GlobalState.is_overworld_enemy_defeated(spawn):
			continue
		if Vector2i(e["coord"]) == world.player_pos:
			trigger_overworld_combat(world, e)
			return
