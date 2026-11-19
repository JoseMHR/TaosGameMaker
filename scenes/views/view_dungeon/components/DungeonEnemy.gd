# DungeonEnemy.gd
# ─────────────────────────────────────────────────────────────────────────────
# CONTROLADOR DE ENEMIGOS EN LA MAZMORRA 3D
#
# Gestiona el sprite 2D billboard, la animación de flote/salto y la zona de detección.
# Cuando el jugador entra y permanece en el área de detección durante 1.5s, se dispara
# la señal combat_triggered hacia ViewDungeon.
#
# MECÁNICA ESPECIAL: Cronófago (temple_boss_time)
# ────────────────────────────────────────────────
# El boss del Sendero del Tiempo huye del jugador en cuanto este entra en su radio
# de detección. Se mueve exactamente un 8% más rápido que el jugador para que sea
# imposible alcanzarlo en condiciones normales. Si el jugador activa la habilidad
# «Distorsión Temporal» (time_distort), la velocidad del boss se reduce un 20%,
# haciéndolo más lento que el jugador y permitiendo el contacto.
# ─────────────────────────────────────────────────────────────────────────────
extends StaticBody3D

signal combat_triggered(is_boss: bool, enemy_id: String, enemy_node: Node)

@export var is_boss: bool = false
@export var enemy_id: String = ""
## Nivel con el que se construirá el combate (EnemyDatabase.build_enemy) al
## detectar al jugador. Lo fija la casilla de mazmorra (`cell.level`, editable
## desde el editor); por defecto 1 (comportamiento histórico).
@export var level: int = 1
## True si `enemy_id` viene de un `ref` EXPLÍCITO puesto en la casilla desde el
## editor (no del fallback genérico de GridDungeonStage._add_enemy). Cuando es
## true, ViewDungeon combate exactamente contra este enemigo/nivel; si es
## false (no debería ocurrir en el contenido autorado: no hay enemigos
## aleatorios), ViewDungeon usa `enemy_id` a nivel 1 como último recurso.
@export var has_explicit_ref: bool = false
@export var detection_time: float = 1.5
@export var can_patrol: bool = true

## Factor de HP con el que empezará el enemigo en el combate (1.0 = normal).
## El golpe de sorpresa en mazmorra lo pone a 0.8 como recompensa de primer golpe.
var incoming_hp_factor: float = 1.0

# Referencias
@onready var sprite: Sprite3D = $Sprite3D
@onready var detection_area: Area3D = $DetectionArea
@onready var detection_mesh: MeshInstance3D = $DetectionArea/DetectionMesh
@onready var interaction_area: Area3D = $InteractionArea

var player_in_range: bool = false
var player_in_detection_zone: bool = false
var detection_timer: float = 0.0

var _start_y: float = 0.0


var ring_mesh: MeshInstance3D = null

## Punto de origen del enemigo (centro de su patrulla) y eje elegido al azar
## para el vaivén lateral (Bug 3.1 de task_bugs_observados.md: antes el enemigo
## era totalmente estático salvo el salto vertical continuo).
var _patrol_origin: Vector3 = Vector3.ZERO
var _patrol_axis: Vector3 = Vector3.RIGHT


const DETECTION_RADIUS_NORMAL: float = 6.5
const DETECTION_RADIUS_BOSS: float = 8.0

# ─── MECÁNICA CRONÓFAGO (temple_boss_time) ───────────────────────────────────
## Velocidad base del jugador (igual que DungeonPlayer.SPEED). El boss la
## multiplica ligeramente para ser imposible de alcanzar sin la habilidad.
const _PLAYER_BASE_SPEED: float = 3.2
## El boss se mueve un 8% más rápido que el jugador en condiciones normales.
const _BOSS_SPEED_MULT_NORMAL: float = 1.08
## Con Distorsión Temporal activa el boss baja al 80% de la velocidad del jugador.
const _BOSS_SPEED_MULT_SLOWED: float = 0.80
## Distancia mínima al límite de la sala (en unidades) para invertir la huída.
const _FLEE_WALL_MARGIN: float = 1.5

var _is_cronofago: bool = false
var _flee_tween: Tween = null
var _player_node: CharacterBody3D = null
var _cronofago_flee_dir: Vector3 = Vector3.ZERO
var _cronofago_turn_cooldown: float = 0.0
# ─────────────────────────────────────────────────────────────────────────────


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("dungeon_enemy")
	
	var rad: float = DETECTION_RADIUS_BOSS if is_boss else DETECTION_RADIUS_NORMAL

	# Duplicar el material de detección para que cada enemigo tenga su propio color independiente
	if detection_mesh:
		var mat = detection_mesh.get_active_material(0)
		if mat:
			var dup_mat = mat.duplicate() as Material
			detection_mesh.set_surface_override_material(0, dup_mat)

		# Crear el aro exterior (TorusMesh) escalado al radio de visión
		ring_mesh = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = rad - 0.20
		torus.outer_radius = rad + 0.06
		torus.rings = 48
		torus.ring_segments = 16
		ring_mesh.mesh = torus
		ring_mesh.position = Vector3(0, 0.06, 0) # Ligeramente por encima del suelo y del disco interior

		var ring_mat := StandardMaterial3D.new()
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		ring_mesh.material_override = ring_mat
		detection_area.add_child(ring_mesh)

	_setup_detection_range()

	interaction_area.body_entered.connect(_on_interaction_entered)
	interaction_area.body_exited.connect(_on_interaction_exited)
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)

	_update_detection_color(0.0)
	
	refresh_visuals()

	if sprite:
		_start_y = sprite.position.y
		_start_idle_animation()

	# IMPORTANTE: usar `position` (local relativa al contenedor FloorN) y NO
	# `global_position`, porque `_start_patrol` anima `self.position` con un
	# Tween. Si se usa `global_position` en plantas distintas a la 0, la Y
	# global incluye el offset de la planta (base_y = floor_idx * (wall_h+gap)),
	# lo que hace que el tween intente llevar `self.position.y` a ese valor
	# global y el enemigo quede flotando en el aire. (Bug: centinela_templo
	# volando en la última planta de dun_desierto — 2026-09-20)
	_patrol_origin = position
	_patrol_axis = Vector3.RIGHT if randf() < 0.5 else Vector3.FORWARD

	# ── Detectar si somos el Cronófago (boss del Sendero del Tiempo) ──────────
	_is_cronofago = (enemy_id == "temple_boss_time")
	if _is_cronofago:
		# El Cronófago no hace la patrulla de vaivén normal; su movimiento
		# lo gestiona el sistema de huída en _process.
		can_patrol = false
	elif can_patrol and not Locale.reduce_motion:
		_start_patrol()


## Ajusta el radio físico y visual del área de detección según si es jefe o enemigo estándar.
func _setup_detection_range() -> void:
	var rad: float = DETECTION_RADIUS_BOSS if is_boss else DETECTION_RADIUS_NORMAL
	
	if detection_area:
		var col := detection_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape is CylinderShape3D:
			(col.shape as CylinderShape3D).radius = rad
			
	if detection_mesh and detection_mesh.mesh is CylinderMesh:
		var cyl := (detection_mesh.mesh as CylinderMesh).duplicate() as CylinderMesh
		cyl.top_radius = rad
		cyl.bottom_radius = rad
		detection_mesh.mesh = cyl

	if ring_mesh and ring_mesh.mesh is TorusMesh:
		var torus := (ring_mesh.mesh as TorusMesh)
		torus.inner_radius = rad - 0.20
		torus.outer_radius = rad + 0.06


## Actualiza el sprite 3D y su escala tomando la textura canónica de Design.enemy(enemy_id).
func refresh_visuals() -> void:
	if enemy_id == "":
		return
	var enemy_data: Dictionary = Design.get_enemy(enemy_id)
	var img_path: String = String(enemy_data.get("image", ""))
	if img_path.is_empty():
		img_path = "res://assets/combat/enemies/en_default.png"
	var tex := UiKit.load_texture_safe(img_path)
	if tex != null and sprite != null:
		sprite.texture = tex
		var target_h: float = 2.6 if is_boss else 1.8
		var tex_h: float = float(tex.get_height())
		if tex_h > 0:
			sprite.pixel_size = target_h / tex_h
		sprite.position.y = target_h * 0.5
		_start_y = sprite.position.y
		_setup_detection_range()

		var col_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col_shape != null and col_shape.shape is CapsuleShape3D:
			(col_shape.shape as CapsuleShape3D).height = target_h
			(col_shape.shape as CapsuleShape3D).radius = target_h * 0.25
			col_shape.position.y = target_h * 0.5


func _start_idle_animation() -> void:
	_perform_float()


func _perform_float() -> void:
	if not is_inside_tree() or sprite == null:
		return
		
	var tw := create_tween()
	# Subir sutilmente
	tw.tween_property(sprite, "position:y", _start_y + 0.18, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Bajar sutilmente
	tw.tween_property(sprite, "position:y", _start_y, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Volver a llamar al finalizar
	tw.tween_callback(_perform_float).set_delay(randf_range(0.1, 0.3))


## Vaivén ligero de patrulla (±0.6-0.8m en X o Z, elegido al azar por enemigo)
## con pausas orgánicas en cada extremo, para que el enemigo tenga vida en vez
## de estar totalmente fijo en su coordenada (Bug 3.1). Se detiene solo si el
## nodo se libera (enemigo derrotado); `reduce_motion` lo desactiva del todo.
func _start_patrol() -> void:
	if not is_inside_tree():
		return
	var amp := randf_range(0.6, 0.8)
	var half_dur := randf_range(1.6, 2.4)
	var far_pos := _patrol_origin + _patrol_axis * amp
	var tw := create_tween()
	tw.tween_property(self, "position", far_pos, half_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(randf_range(0.4, 1.0))
	tw.tween_property(self, "position", _patrol_origin, half_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(randf_range(0.4, 1.0))
	tw.tween_callback(_start_patrol)


func _process(delta: float) -> void:
	if GlobalState.is_movement_locked:
		return

	# ── MECÁNICA ESPECIAL: CRONÓFAGO (temple_boss_time) ──────────────────────
	if _is_cronofago and is_inside_tree():
		_process_cronofago(delta)
		return   # El Cronófago no usa el timer de combate normal (huida activa lo reemplaza)

	if player_in_detection_zone:
		detection_timer += delta
		var progress := clampf(detection_timer / detection_time, 0.0, 1.0)
		_update_detection_color(progress)
		
		if detection_timer >= detection_time:
			# Disparar combate!
			player_in_detection_zone = false
			detection_timer = 0.0
			_update_detection_color(0.0)
			combat_triggered.emit(is_boss, enemy_id, self)
	else:
		if detection_timer > 0.0:
			detection_timer -= delta * 2.0 # Se enfría más rápido de lo que se llena
			if detection_timer < 0.0:
				detection_timer = 0.0
			_update_detection_color(detection_timer / detection_time)


# ─── LÓGICA DE HUÍDA DEL CRONÓFAGO ───────────────────────────────────────────

## Comprueba si hay una pared o colisión sólida a una distancia dada en una dirección.
func _is_wall_ahead(from_pos: Vector3, dir: Vector3, distance: float) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var d := dir.normalized()
	var perp := Vector3(-d.z, 0.0, d.x).normalized() * 0.45
	var y_height := from_pos.y + 1.2
	var start_base := Vector3(from_pos.x, y_height, from_pos.z) + d * 0.45

	# Raycast central y dos laterales (evita encajarse en esquinas de 3m)
	var offsets: Array[Vector3] = [Vector3.ZERO, perp, -perp]
	for offset: Vector3 in offsets:
		var ray_from: Vector3 = start_base + offset
		var ray_to: Vector3 = ray_from + d * distance
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1, [get_rid()])
		var result := space.intersect_ray(query)
		if not result.is_empty():
			return true
	return false


## Elige una nueva dirección cardinal (X o Z) que no tenga pared y que se aleje del jugador.
func _pick_cronofago_direction(my_pos: Vector3, player_pos: Vector3, current_dir: Vector3) -> Vector3:
	var to_player := Vector3(player_pos.x - my_pos.x, 0.0, player_pos.z - my_pos.z)
	var to_player_dir := to_player.normalized()

	var perpendiculars: Array[Vector3] = []
	if absf(current_dir.z) > 0.5:
		perpendiculars = [Vector3.LEFT, Vector3.RIGHT]
	elif absf(current_dir.x) > 0.5:
		perpendiculars = [Vector3.FORWARD, Vector3.BACK]

	var candidates: Array[Vector3] = []
	for p in perpendiculars:
		if not _is_wall_ahead(my_pos, p, 1.8):
			candidates.append(p)

	if not candidates.is_empty():
		candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return a.dot(to_player_dir) < b.dot(to_player_dir)
		)
		if candidates[0].dot(to_player_dir) <= 0.35:
			return candidates[0]

	# Si las perpendiculares están bloqueadas o van de frente al jugador, probar marcha atrás
	if current_dir != Vector3.ZERO:
		var reverse_dir := -current_dir
		if not _is_wall_ahead(my_pos, reverse_dir, 1.8) and reverse_dir.dot(to_player_dir) < 0.2:
			return reverse_dir

	# Fallback general sobre los 4 puntos cardinales
	var all_cardinals: Array[Vector3] = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	var open_cardinals: Array[Vector3] = []
	for c in all_cardinals:
		if not _is_wall_ahead(my_pos, c, 1.8):
			open_cardinals.append(c)

	if open_cardinals.is_empty():
		for c in all_cardinals:
			if not _is_wall_ahead(my_pos, c, 0.8):
				open_cardinals.append(c)

	if not open_cardinals.is_empty():
		open_cardinals.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return a.dot(to_player_dir) < b.dot(to_player_dir)
		)
		return open_cardinals[0]

	return current_dir


## Cada frame mueve al Cronófago en líneas rectas a través de pasillos cardinales,
## girando al encontrar paredes y evitando atravesar muros.
## Sin Distorsión Temporal, se mueve un 25% más rápido que el jugador (incluso en debug mode).
## Con Distorsión Temporal, se ralentiza al 70% permitiendo alcanzarlo.
func _process_cronofago(delta: float) -> void:
	if _player_node == null or not is_instance_valid(_player_node):
		_player_node = _find_player()
	if _player_node == null:
		return

	var player_pos := _player_node.global_position
	var my_pos := global_position
	var dist := Vector2(my_pos.x - player_pos.x, my_pos.z - player_pos.z).length()
	var detection_rad := DETECTION_RADIUS_BOSS

	# Si el jugador está muy cerca, iniciar combate inmediatamente
	if dist <= 1.4:
		combat_triggered.emit(is_boss, enemy_id, self)
		return

	if dist <= detection_rad:
		_update_detection_color(1.0 - clampf((dist / detection_rad), 0.0, 1.0))

		var time_slow_active := _is_time_distort_active()
		# Ajustar respecto a la velocidad real del jugador (en debug respeta GlobalState.debug_speed_mult)
		var speed_mult: float = float(GlobalState.debug_speed_mult) if GlobalState.debug_mode else 1.0
		var player_speed: float = _PLAYER_BASE_SPEED * speed_mult
		var boss_speed: float = player_speed * (0.70 if time_slow_active else 1.25)

		var to_player := Vector3(player_pos.x - my_pos.x, 0.0, player_pos.z - my_pos.z)
		var to_player_dir := to_player.normalized()

		# Timer para cambios aleatorios de dirección hacia pasillos perpendiculares libres
		_cronofago_turn_cooldown -= delta
		if _cronofago_turn_cooldown <= 0.0 and _cronofago_flee_dir != Vector3.ZERO:
			_cronofago_turn_cooldown = randf_range(2.0, 3.5)
			var perps: Array[Vector3] = []
			if absf(_cronofago_flee_dir.z) > 0.5:
				perps = [Vector3.LEFT, Vector3.RIGHT]
			else:
				perps = [Vector3.FORWARD, Vector3.BACK]
			perps.shuffle()
			for p in perps:
				if not _is_wall_ahead(my_pos, p, 2.5) and p.dot(to_player_dir) <= 0.0:
					if randf() < 0.60:
						_cronofago_flee_dir = p
						break

		# Si no tenemos dirección de avance o hay una pared cerca enfrente, buscar nuevo rumbo
		if _cronofago_flee_dir == Vector3.ZERO or _is_wall_ahead(my_pos, _cronofago_flee_dir, 1.8):
			_cronofago_flee_dir = _pick_cronofago_direction(my_pos, player_pos, _cronofago_flee_dir)

		if _cronofago_flee_dir != Vector3.ZERO:
			var step_len := boss_speed * delta
			if _is_wall_ahead(my_pos, _cronofago_flee_dir, step_len + 0.6):
				_cronofago_flee_dir = _pick_cronofago_direction(my_pos, player_pos, _cronofago_flee_dir)
			else:
				global_position += _cronofago_flee_dir * step_len
	else:
		_update_detection_color(0.0)
		_cronofago_flee_dir = Vector3.ZERO


## Devuelve true si el jugador tiene la habilidad Distorsión Temporal activa.
func _is_time_distort_active() -> bool:
	if _player_node == null:
		return false
	var ctrl = _player_node.get_node_or_null("SkillController")
	if ctrl == null and _player_node.has_method("skill_controller"):
		ctrl = _player_node.skill_controller()
	if ctrl == null:
		return false
	if ctrl.has_method("is_toggled"):
		return bool(ctrl.is_toggled("time_distort"))
	return false


## Busca el nodo del jugador en el árbol de escena.
func _find_player() -> CharacterBody3D:
	if is_inside_tree():
		var p = get_tree().get_first_node_in_group("player")
		if p is CharacterBody3D:
			return p as CharacterBody3D
		var vd = get_tree().get_first_node_in_group("view_dungeon")
		if vd != null and vd.get("_player_instance") is CharacterBody3D:
			return vd._player_instance as CharacterBody3D
		var root = get_tree().current_scene
		if root != null:
			var p_node = root.find_child("player", true, false)
			if p_node is CharacterBody3D:
				return p_node as CharacterBody3D
	return null

# ─────────────────────────────────────────────────────────────────────────────


func _update_detection_color(progress: float) -> void:
	if not detection_mesh:
		return
	
	# Disco interior: casi imperceptible en reposo (alpha 0.04), sube suavemente a 0.20 al ser detectado
	var inner_color := Color(0.1, 0.5, 1.0, 0.04).lerp(Color(1.0, 0.2, 0.2, 0.20), progress)
	var mat := detection_mesh.get_active_material(0)
	if mat and mat is StandardMaterial3D:
		mat.albedo_color = inner_color

	# Aro exterior: en reposo casi transparente (alpha ~0.18, borde sutil azulado)
	if ring_mesh and ring_mesh.material_override:
		var ring_mat := ring_mesh.material_override as StandardMaterial3D
		if ring_mat:
			var ring_color: Color
			if progress < 0.5:
				ring_color = Color(0.3, 0.65, 1.0, 0.18).lerp(Color(1.0, 0.85, 0.15, 0.55), progress / 0.5)
			else:
				ring_color = Color(1.0, 0.85, 0.15, 0.55).lerp(Color(1.0, 0.15, 0.15, 0.95), (progress - 0.5) / 0.5)
			ring_mat.albedo_color = ring_color


func _on_interaction_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "player":
		player_in_range = true
		# CRONÓFAGO: el combate se dispara al tocar la InteractionArea (no hay timer)
		if _is_cronofago:
			combat_triggered.emit(is_boss, enemy_id, self)


func _on_interaction_exited(body: Node) -> void:
	if body.is_in_group("player") or body.name == "player":
		player_in_range = false


func _on_detection_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "player":
		player_in_detection_zone = true


func _on_detection_exited(body: Node) -> void:
	if body.is_in_group("player") or body.name == "player":
		player_in_detection_zone = false


## Inicia el combate inmediatamente (usado por el golpe de sorpresa en mazmorra),
## con una posible penalización de HP inicial al enemigo (hp_factor < 1.0).
func trigger_combat_now(hp_factor: float = 1.0) -> void:
	incoming_hp_factor = clampf(hp_factor, 0.1, 1.0)
	combat_triggered.emit(is_boss, enemy_id, self)
