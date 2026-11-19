class_name WorldCinematicController
extends RefCounted
## CÁMARA DE CINEMÁTICAS Y CINEMÁTICA DE LA PRESA PROGRESIVA — Componente
## especialista extraído de TabWorld3D.
##
## NOTA de implementación: se modela como `RefCounted` (no `Node`), igual que
## `OverworldPhysicsController`/`WorldEnvironmentController`/`WorldHudBuilder`,
## porque no se añade al árbol de escena.
##
## Encapsula: la reacción del mapamundi al evento global `EVENT_CINE_CAMERA`
## (tween de cámara a una casilla durante una escena narrativa) y la devolución
## del control de cámara al terminar cualquier escena del `SceneRunner`; y la
## cinemática espectacular de apertura de la presa (transformación progresiva
## del valle en oleadas, con retardo por distancia al río) junto con el aura
## del campamento base.
##
## Mantiene una referencia a la `TabWorld3D` propietaria (`_view`), sobre cuyos
## nodos y estado opera. `TabWorld3D` mantiene fachadas con las mismas firmas
## públicas (`_on_cine_camera_event`, `_on_scene_runner_finished`,
## `run_dam_opened_cinematic`, `_get_propagation_delay`,
## `_spawn_temp_tile_popup`, `_update_base_aura`) que redirigen a este
## componente, de modo que ningún llamante externo (incluidos `GameRoot`, que
## llama `run_dam_opened_cinematic` directamente, `CampTentSystem`, que llama
## `world._update_base_aura()`, y las suscripciones a
## `GlobalEvents`/`SceneRunner.scene_finished`, que siguen apuntando al método
## de `TabWorld3D`) cambia. El comportamiento es IDÉNTICO al monolito original.

## Vista del mapamundi propietaria del estado y de los nodos UI.
var _view: Node = null

## Enlaza este controlador con la TabWorld3D propietaria. Debe llamarse una vez
## tras instanciarlo (en `TabWorld3D._ready`).
func setup(view: Node) -> void:
	_view = view


#region CÁMARA DE CINEMÁTICAS (desacoplada del Sistema Narrativo)

## EVENTO GLOBAL: una escena-cinemática pide enfocar la cámara en una
## casilla del mundo, de forma desacoplada: el Sistema Narrativo no conoce la
## cámara; solo emite el evento y el Mapamundi decide cómo reaccionar.
func _on_cine_camera_event(payload: Dictionary) -> void:
	if not is_instance_valid(_view._cam):
		return
	_view._is_cinematic_active = true
	if _view._joy_active:
		_view._reset_joystick()
	var coord := Vector2i(int(payload.get("x", 0)), int(payload.get("y", 0)))
	var dur := float(payload.get("dur", 1.2))
	var target: Vector3 = _view._cell_to_world(coord) + Vector3(0.0, _view.CAM_HEIGHT * 1.5, _view.CAM_BACK * 1.5)
	var tw: Tween = _view.create_tween()
	tw.tween_property(_view._cam, "position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_view._cam.look_at(_view._cell_to_world(coord) + Vector3(0.0, 0.4, 0.0), Vector3.UP)


## Al terminar CUALQUIER escena del SceneRunner devolvemos el control de cámara al
## jugador (por si fue una cinemática que tomó la cámara vía EVENT_CINE_CAMERA).
func _on_scene_runner_finished(_scene_id: String) -> void:
	_view._is_cinematic_active = false
	_view._reset_joystick()
	_view._clear_move_target()

#endregion


#region CINEMÁTICA DE LA PRESA PROGRESIVA

func run_dam_opened_cinematic(on_finished_callback: Callable) -> void:
	if not is_instance_valid(_view) or not _view.is_inside_tree():
		if on_finished_callback:
			on_finished_callback.call()
		return

	_view._is_cinematic_active = true
	if _view._joy_active:
		_view._reset_joystick()

	# Localiza la presa DINÁMICAMENTE (mismo criterio que WorldMapBuilder.apply_dam_opened):
	# la animación debe arrancar exactamente desde su casilla, no de una coordenada fija.
	var presa: Vector2i = Vector2i(-1, -1)
	for coord in GlobalState.hexagons_db.keys():
		var cc: CellResource = GlobalState.hexagons_db[coord] as CellResource
		if cc != null and cc.event_id == "poi_presa_001":
			presa = coord
			break
	if presa == Vector2i(-1, -1):
		presa = Vector2i(6, 8)   # respaldo si no se encuentra (no debería ocurrir)

	# Centrar cámara en la presa.
	var center_wp: Vector3 = _view._cell_to_world(presa)
	var cam_target: Vector3 = center_wp + Vector3(0.0, _view.CAM_HEIGHT * 1.5, _view.CAM_BACK * 1.5)

	var cam_tween: Tween = _view.create_tween()
	cam_tween.tween_property(_view._cam, "position", cam_target, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Recolectar casillas afectadas por la transformación de la presa: el mismo río
	# (columna + rama izquierda) que calcula WorldMapBuilder.apply_dam_opened, relativo
	# a la presa real.
	var river: Array[Vector2i] = []
	for dy in range(0, 9):
		river.append(presa + Vector2i(0, dy))
	for dx in range(1, 5):
		river.append(presa + Vector2i(-dx, 3))

	var affected: Array[Vector2i] = []
	for r in river:
		affected.append(r)

	# Límite occidental de la Zona 1 (Cueva de la Esfera / dun_inicial)
	var min_x: int = presa.x - 6
	for coord in GlobalState.hexagons_db.keys():
		var cc: CellResource = GlobalState.hexagons_db[coord] as CellResource
		if cc != null and (cc.event_id == "dun_inicial" or cc.event_id == "dun_001"):
			min_x = coord.x
			break

	# Toda la zona interior del valle de la Zona 1 (sin invadir la Zona Final al oeste)
	for coord in GlobalState.hexagons_db.keys():
		var cell = GlobalState.hexagons_db[coord] as CellResource
		if cell == null:
			continue
		if coord.x < min_x or coord.x > presa.x + 10:
			continue
		if coord.y < presa.y or coord.y > presa.y + 9:
			continue
		if cell.terrain in ["grs", "gnd", "cst", "bad", "lav"] and not coord in affected:
			affected.append(coord)

	# Calcular retardos y programar la transformación de cada celda
	var max_delay := 0.0
	for coord in affected:
		var delay = _get_propagation_delay(coord, river, presa) * 0.18
		if delay > max_delay:
			max_delay = delay

		# Timer de un solo uso para spawnear el efecto visual de transición
		var closure_coord = coord
		_view.get_tree().create_timer(delay).timeout.connect(func():
			var cell = GlobalState.hexagons_db.get(closure_coord) as CellResource
			if cell:
				_spawn_temp_tile_popup(closure_coord, cell.terrain)
		)

	# Esperar a que termine toda la cinemática
	_view.get_tree().create_timer(max_delay + 0.8).timeout.connect(func():
		_view._is_cinematic_active = false
		if on_finished_callback:
			on_finished_callback.call()
	)


func _get_propagation_delay(coord: Vector2i, river: Array[Vector2i], presa: Vector2i) -> float:
	if coord in river:
		if coord.y == presa.y + 3 and coord.x < presa.x:
			return 3.0 + float(presa.x - coord.x)
		else:
			return float(coord.y - presa.y)

	var min_dist := 999.0
	var closest_river_delay := 0.0
	for r in river:
		var dist = float(maxi(absi(coord.x - r.x), absi(coord.y - r.y)))
		if dist < min_dist:
			min_dist = dist
			closest_river_delay = _get_propagation_delay(r, river, presa)

	return closest_river_delay + min_dist * 1.5


func _spawn_temp_tile_popup(coord: Vector2i, terrain: String) -> void:
	if not is_instance_valid(_view) or not _view.is_inside_tree() or _view._tiles_root == null or not is_instance_valid(_view._tiles_root):
		return
	var wp: Vector3 = _view._cell_to_world(coord)

	# Instanciar prisma hexagonal temporal
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.radial_segments = 6
	cyl.top_radius = _view.TILE * 0.52
	cyl.bottom_radius = _view.TILE * 0.52
	cyl.height = 0.3
	mesh_inst.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	match terrain:
		"cst":
			mat.albedo_color = Color(0.12, 0.48, 0.88, 0.9)
		"grs":
			mat.albedo_color = Color(0.25, 0.68, 0.28, 0.9)
		"gnd":
			mat.albedo_color = Color(0.55, 0.38, 0.22, 0.9)
		_:
			mat.albedo_color = Color(0.4, 0.4, 0.4)
	mesh_inst.material_override = mat

	# Spawn ligeramente hundido
	mesh_inst.position = wp + Vector3(0.0, -0.4, 0.0)
	mesh_inst.scale = Vector3(0.01, 1.0, 0.01)
	_view._tiles_root.add_child(mesh_inst)

	# Sonido sutil
	if randf() < 0.25:
		AudioManager.play_sfx("click")

	var tween: Tween = _view.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3(1.0, 1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_inst, "position", wp + Vector3(0.0, 0.04, 0.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_callback(func():
		mesh_inst.queue_free()
		_view._on_map_cell_changed(coord)
	)


## Perímetro CUADRADO (no invasivo: solo un borde fino, no un suelo relleno) que
## marca el territorio actual de la Base — ver `GlobalState.base_territory_size`
## (1×1 con solo la tienda; 3×3 desde la Hoguera; 4×4 desde el Cofre). Antes era
## un anillo circular fijo que no reflejaba el tamaño real del territorio.
func _update_base_aura() -> void:
	if _view._base_aura_ring != null and is_instance_valid(_view._base_aura_ring):
		_view._base_aura_ring.queue_free()
		_view._base_aura_ring = null
	_view._base_aura_mat = null

	if not GlobalState.has_built_base or GlobalState.base_coord == Vector2i(-1, -1):
		return
	var size := GlobalState.base_territory_size()
	if size <= 0:
		return

	# Centro del cuadrado: coincide con la tienda en lados impares (1,3); en
	# lados pares (4) se sesga medio tile hacia +x/+z, igual que
	# `GlobalState.is_within_base_territory`.
	var lo: int = -int(float(size - 1) / 2.0)
	var hi := size - 1 + lo
	var center_offset := (float(lo) + float(hi)) * 0.5
	var wp: Vector3 = _view._cell_to_world(GlobalState.base_coord) + Vector3(center_offset * 2.0, 0.0, center_offset * 2.0)

	var root := Node3D.new()
	root.position = wp + Vector3(0, 0.06, 0)
	_view._tiles_root.add_child(root)
	_view._base_aura_ring = root

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.15, 0.75, 1.0, 0.45) # cyan discreto
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	_view._base_aura_mat = mat

	var extent := float(size) * 2.0
	var half := extent * 0.5
	var thickness := 0.07
	var edges: Array = [
		Vector3(extent, 0.05, thickness), Vector3(0.0, 0.0, -half),
		Vector3(extent, 0.05, thickness), Vector3(0.0, 0.0, half),
		Vector3(thickness, 0.05, extent), Vector3(-half, 0.0, 0.0),
		Vector3(thickness, 0.05, extent), Vector3(half, 0.0, 0.0),
	]
	for i in range(0, edges.size(), 2):
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = edges[i]
		bar.mesh = box
		bar.material_override = mat
		bar.position = edges[i + 1]
		root.add_child(bar)

#endregion
