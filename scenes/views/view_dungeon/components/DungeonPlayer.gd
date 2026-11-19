# DungeonPlayer.gd
# ─────────────────────────────────────────────────────────────────────────────
# CONTROLADOR EN PRIMERA PERSONA DE MAZMORRA (Controles tipo Tanque + Interacciones)
#
# Permite moverse adelante/atrás y girar izquierda/derecha.
# Habilita controles para PC (WASD/flechas) y admite impulsos externos (móvil).
# Añade soporte para agua (lenta), lava (daño continuo) y pinchos (daño + empuje).
# ─────────────────────────────────────────────────────────────────────────────
extends CharacterBody3D

## Emitida al recibir daño de un peligro. `cause` = "lava" | "spikes".
## La escucha ViewDungeon para el feedback en pantalla (viñeta + sonido + vibración).
signal took_damage(cause: String)

## Emitida al entrar/salir del agua (para el tinte azul de pantalla).
signal water_changed(in_water: bool)

const SPEED: float = 3.2   # Se sentía demasiado rápido (era 5.0)
const ROTATION_SPEED: float = 2.2
const ACCEL: float = 18.0        # Arranque más pesado
const DECEL: float = 32.0        # Parada más firme

# ── HEAD-BOB (Game Feel): el movimiento se sentía "plano" —la cámara nunca se
# movía al caminar. Balanceo sutil de la cabeza (vertical en figura-8 + leve
# vaivén lateral), proporcional a la velocidad real, que se desvanece solo al
# frenar en vez de cortar en seco. Respeta `Locale.reduce_motion`. No hay SFX de
# pasos: no existe ningún asset de audio de pisadas en el proyecto todavía
# (`AudioManager.SFX_PATHS`); añadir uno y cablearlo aquí es el siguiente paso
# obvio si se incorpora ese asset.
const BOB_FREQUENCY: float = 1.0      # ciclos/segundo (más lento y suave)
const BOB_AMPLITUDE_Y: float = 0.008  # sube/baja sutil (suavizado para evitar mareo)
const BOB_AMPLITUDE_X: float = 0.005  # vaivén lateral micro (m)
const BOB_BLEND_SPEED: float = 8.0    # suavizado al empezar/dejar de moverse
var _bob_time: float = 0.0
var _bob_blend: float = 0.0
var _head_base_pos: Vector3 = Vector3.ZERO
@onready var _head: Node3D = $head
const WATER_SPEED_FACTOR: float = 0.4  # En agua: 40% de la velocidad (ralentización del 60%)
const LAVA_TICK: float = 0.5     # Cada cuánto aplica daño la lava (s)
const LAVA_DAMAGE: int = 4       # Daño por tick de lava (≈8 HP/s)
const SPIKE_COOLDOWN: float = 0.6  # I-frames tras pisar pinchos (evita rebotes)
const KNOCKBACK_SPEED: float = 12.0
const KNOCKBACK_TIME: float = 0.25
## Fricción casi nula sobre hielo (idea.md §1.2), sustituye a ACCEL/DECEL tanto
## para arrancar como para frenar: conserva la inercia de entrada hasta chocar
## con un obstáculo o pisar suelo normal (puzles de deslizamiento clásicos).
const ICE_ACCEL_DECEL: float = 0.8
## Velocidad vertical al escalar un muro escalable (idea.md §1.1, `DungeonClimbZone.gd`).
const CLIMB_SPEED: float = 2.4

# Gravedad del proyecto
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Control de activación (se desactiva durante combates o transiciones)
var is_active: bool = true

# Input táctil acumulado (desde controles móviles de ViewDungeon)
var touch_movement: Vector2 = Vector2.ZERO
var touch_look: Vector2 = Vector2.ZERO

# Variables de interacción y estado. Las zonas usan CONTADOR (no bool) para que
# solaparse con varias charcas de agua/lava y salir de una no cancele el efecto.
var _water_zones: int = 0
var _lava_zones: int = 0
var _ice_zones: int = 0
var is_in_water: bool = false
var is_in_lava: bool = false
## Suelo de hielo deslizante (idea.md §1.2, `DungeonIceZone.gd`).
var is_on_ice: bool = false
## Escalada de muros (idea.md §1.1, `DungeonClimbZone.gd`): anula la gravedad y
## remapea W/S al eje vertical mientras el jugador está adosado a la pared.
var _climb_zones: int = 0
var is_climbing: bool = false
## Arrastre acumulado de corrientes de agua bajo los pies (idea.md §1.2,
## `DungeonWaterZone.gd`/`current_direction`). Varias corrientes solapadas se
## SUMAN; cada zona añade/quita EXACTAMENTE su propio vector al entrar/salir.
var _water_current: Vector3 = Vector3.ZERO
var _lava_timer: float = 0.0
var _spike_cooldown: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _knockback_timer: float = 0.0
var _last_safe_position: Vector3 = Vector3.ZERO
var _is_repositioning_void: bool = false

# ─── TIRÓN DEL JUGADOR (Agarre Psíquico sobre un Anclaje) ────────────────────
# El Agarre Psíquico (verbo "grab") puede pedir, vía la reacción `Anchor`, que el
# jugador se desplace hacia un punto fijo. `pull_self_to()` activa este tirón.
const PULL_SPEED: float = 18.0        # Velocidad del tirón hacia el punto de anclaje
var is_being_pulled: bool = false
var pull_target_point: Vector3 = Vector3.ZERO

# Energía (recurso verde del HUD). Se regenera con el tiempo mientras exploramos.
var _energy_regen_accum: float = 0.0   # Acumulador para emitir state_updated con moderación

# Flancos de teclado (pulsación única) para las 6 habilidades (teclas 1-6).
const SKILL_KEYS: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
var _prev_skill_keys: Array = [false, false, false, false, false, false]

# Runtime de habilidades de exploración. Traduce input → verbos que los
# Objetos Inteligentes reciben. Sustituye al antiguo input basado en almas.
var _skill_ctrl: ExplorationSkillController = null


func _ready() -> void:
	add_to_group("player")
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.3
	_skill_ctrl = ExplorationSkillController.new()
	_skill_ctrl.name = "SkillController"
	add_child(_skill_ctrl)
	_skill_ctrl.skill_used.connect(_on_skill_used)
	var cam := _camera()
	_skill_ctrl.aim_node = cam
	_skill_ctrl.origin_node = cam
	_skill_ctrl.player_body = self
	_head_base_pos = _head.position


## Controller de habilidades (lo usa el HUD y el input de teclado).
func skill_controller() -> ExplorationSkillController:
	return _skill_ctrl


## Atrae al jugador hacia un punto (Agarre Psíquico sobre un Anclaje). Reutiliza
## el mecanismo de tirón existente del jugador.
func pull_self_to(point: Vector3) -> void:
	is_being_pulled = true
	pull_target_point = point


func _physics_process(delta: float) -> void:
	# I-frames de pinchos (siempre avanzan)
	if _spike_cooldown > 0.0:
		_spike_cooldown -= delta

	# Regeneración de energía (recurso de habilidades). Pausada durante Distorsión Temporal.
	var ctrl := skill_controller()
	var is_time_slow_active: bool = ctrl != null and is_instance_valid(ctrl) and ctrl.is_toggled("time_distort")

	if not is_time_slow_active and GlobalState.energy < float(GlobalState.max_energy):
		GlobalState.energy = minf(float(GlobalState.max_energy), GlobalState.energy + GameConfig.ENERGY_REGEN_PER_SEC * delta)
		_energy_regen_accum += GameConfig.ENERGY_REGEN_PER_SEC * delta
		if _energy_regen_accum >= 1.0:
			_energy_regen_accum = 0.0
			GlobalState.state_updated.emit()

	# Detección de pulsaciones de habilidad (flanco) — solo si el jugador está activo
	if is_active:
		_process_skill_input()

	# ── TIRÓN HACIA UN ANCLAJE (Agarre Psíquico): prioridad sobre el control normal ──
	if is_being_pulled and is_active:
		var to_target := pull_target_point - global_position
		if to_target.length() < 1.5:
			is_being_pulled = false
			velocity = Vector3.ZERO
		else:
			velocity = to_target.normalized() * PULL_SPEED
			move_and_slide()
			return

	# Aplicar gravedad (anulada mientras se escala un muro, idea.md §1.1: la
	# vertical la controla el propio movimiento de escalada más abajo).
	if is_climbing:
		pass
	elif not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if global_position.y >= -1.0 and not is_in_lava and not is_being_pulled:
			_last_safe_position = global_position

	# Protección de caída al vacío (Y < -2.2: al tocar la lava/pinchos/abismo de la planta baja)
	if global_position.y < -2.2 and not _is_repositioning_void:
		_is_repositioning_void = true
		_recover_from_void_fall()

	if not is_active:
		# Al desactivarse (combate/transición) cancelamos cualquier tirón activo.
		is_being_pulled = false
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
		move_and_slide()
		return

	# Procesar empuje (knockback de pinchos): tiene prioridad sobre el control
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		if _knockback_timer <= 0.0:
			_knockback_velocity = Vector3.ZERO
		move_and_slide()
		return

	# Daño continuo por lava
	if is_in_lava:
		_lava_timer += delta
		if _lava_timer >= LAVA_TICK:
			_lava_timer = 0.0
			_apply_dungeon_damage(LAVA_DAMAGE, "lava")

	# 1. Obtener entradas de movimiento (Joystick Izquierdo / WASD)
	var move_input := Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		move_input.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_input.y += 1.0
	if Input.is_key_pressed(KEY_A):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_input.x += 1.0

	if touch_movement != Vector2.ZERO:
		move_input = touch_movement

	if move_input.length() > 1.0:
		move_input = move_input.normalized()

	# Ajustar velocidad: respeta GlobalState.debug_speed_mult (1.0 o 3.0) si está en Modo Debug / Sala de Tests, y 40% en agua.
	var speed_mult: float = float(GlobalState.debug_speed_mult) if GlobalState.debug_mode else 1.0
	var current_speed := SPEED * speed_mult * (WATER_SPEED_FACTOR if is_in_water else 1.0)

	# Dirección de movimiento relativa a la orientación del personaje (transform.basis)
	# move_input.x = strafe (izquierda/derecha), move_input.y = avance/retroceso (-z / +z)
	var target_x := 0.0
	var target_z := 0.0
	if is_climbing:
		# Escalada (idea.md §1.1): W/S suben/bajan por la pared (eje vertical);
		# A/D siguen desplazando lateralmente a lo largo de la cara escalable.
		var lateral_dir := transform.basis * Vector3(move_input.x, 0.0, 0.0)
		target_x = lateral_dir.x * current_speed
		target_z = lateral_dir.z * current_speed
		velocity.y = move_toward(velocity.y, -move_input.y * CLIMB_SPEED, ACCEL * delta)
	else:
		var raw_input := move_input
		if is_on_ice and (not is_zero_approx(raw_input.x) or not is_zero_approx(raw_input.y)):
			# El hielo resbaladizo prohíbe diagonales: siempre sobre eje X o eje Y
			if absf(raw_input.x) >= absf(raw_input.y):
				raw_input.y = 0.0
				raw_input.x = signf(raw_input.x)
			else:
				raw_input.x = 0.0
				raw_input.y = signf(raw_input.y)
		var move_dir_3d := transform.basis * Vector3(raw_input.x, 0.0, raw_input.y)
		if move_dir_3d.length() > 1.0:
			move_dir_3d = move_dir_3d.normalized()
		target_x = move_dir_3d.x * current_speed
		target_z = move_dir_3d.z * current_speed
	var is_requesting_move := not is_zero_approx(move_input.x) or not is_zero_approx(move_input.y)
	var cur_accel := ACCEL if is_requesting_move else DECEL
	if is_on_ice:
		cur_accel = ICE_ACCEL_DECEL
	velocity.x = move_toward(velocity.x, target_x, cur_accel * delta)
	velocity.z = move_toward(velocity.z, target_z, cur_accel * delta)
	# Corrientes de agua direccionales (idea.md §1.2): arrastre continuo además
	# del movimiento propio del jugador, contrarrestable agarrándose a un
	# anclaje (`Anchor.gd`/`pull_self_to`, que ya inmoviliza vía is_being_pulled).
	if _water_current != Vector3.ZERO and not is_being_pulled:
		velocity.x += _water_current.x * delta
		velocity.z += _water_current.z * delta

	# 2. Obtener entradas de cámara (Joystick Derecho / Teclas de Dirección / Q/E)
	var look_input := Vector2.ZERO

	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q):
		look_input.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_E):
		look_input.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		look_input.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		look_input.y += 1.0

	if touch_look != Vector2.ZERO:
		look_input = touch_look

	# Rotación horizontal (Yaw) -> gira el cuerpo del personaje
	if not is_zero_approx(look_input.x):
		rotate_y(-look_input.x * ROTATION_SPEED * delta)

	# Inclinación vertical (Pitch) -> gira la cabeza/cámara
	if not is_zero_approx(look_input.y) and _head != null:
		var pitch_speed := 1.8
		var target_pitch: float = _head.rotation.x - look_input.y * pitch_speed * delta
		_head.rotation.x = clampf(target_pitch, deg_to_rad(-70.0), deg_to_rad(70.0))

	# Guardar posición previa para subir escalones/peldaños pequeños automáticamente
	var prev_pos := global_position
	
	# Mover al personaje con deslizamiento por colisiones
	move_and_slide()
	
	# Si chocamos contra una pared pero queremos avanzar, intentamos subir un pequeño escalón (máx STEP_MAX_HEIGHT)
	if is_on_wall() and not is_climbing and (target_x != 0.0 or target_z != 0.0):
		_try_step_up(prev_pos)

	var horiz_vel := Vector2(velocity.x, velocity.z).length()
	var is_moving := is_active and is_on_floor() and horiz_vel > 0.4
	_update_footsteps(is_moving)
	_update_head_bob(delta)


var _footsteps_player: AudioStreamPlayer = null
var _is_stepping: bool = false

## Task 4 FASE 5.2 — Superficie del suelo bajo los pies. El material de suelo
## es por MAZMORRA (no por celda, ver `GridDungeonStage._build_materials`), así
## que `ViewDungeon` lo fija una vez tras instanciar al jugador (ver
## `GridDungeonStage.get_floor_surface_kind()`). Las zonas de agua/hielo, que sí
## son por celda, ya se rastrean de forma fiable en `is_in_water`/`is_on_ice`
## (contadores de `Area3D`) y tienen prioridad sobre esto — más preciso que un
## `RayCast3D` reimplementando una detección que el jugador ya conoce.
var floor_surface_kind: String = "stone"

const SURFACE_STEP_PATHS: Dictionary = {
	"stone": "res://assets/common/sfx/sfx_footsteps_stone.wav",
	"metal": "res://assets/common/sfx/sfx_footsteps_metal.wav",
	"sand": "res://assets/common/sfx/sfx_footsteps_sand.wav",
	"snow": "res://assets/common/sfx/sfx_footsteps_snow.wav",
	"water": "res://assets/common/sfx/sfx_footsteps_water.wav",
	"ice": "res://assets/common/sfx/sfx_footsteps_ice.wav",
}
const SURFACE_STEP_PROFILE: Dictionary = {
	"stone": {"pitch": 1.0, "volume_db": -1.0},
	"metal": {"pitch": 1.02, "volume_db": 0.0},
	"sand": {"pitch": 0.98, "volume_db": -2.5},
	"snow": {"pitch": 1.0, "volume_db": -2.0},
	"water": {"pitch": 1.0, "volume_db": -1.5},
	"ice": {"pitch": 1.04, "volume_db": -2.0},
}
var _current_step_surface: String = ""


func _update_footsteps(is_moving: bool) -> void:
	_is_stepping = is_moving
	if _footsteps_player == null:
		_footsteps_player = AudioStreamPlayer.new()
		_footsteps_player.bus = "Master"
		_footsteps_player.finished.connect(func() -> void:
			if _is_stepping and _footsteps_player != null and is_instance_valid(_footsteps_player):
				_footsteps_player.play()
		)
		add_child(_footsteps_player)

	if is_moving:
		var surface: String = "water" if is_in_water else ("ice" if is_on_ice else floor_surface_kind)
		if surface != _current_step_surface or _footsteps_player.stream == null:
			_current_step_surface = surface
			var path: String = SURFACE_STEP_PATHS.get(surface, "res://assets/common/sfx/sfx_footsteps_stone.wav")
			var stream := load(path) as AudioStreamWAV
			if stream == null:
				stream = load("res://assets/common/sfx/sfx_footsteps_walking.wav") as AudioStreamWAV
			if stream != null:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				if stream.data.size() > 0:
					stream.loop_end = stream.data.size()
			_footsteps_player.stream = stream
			var profile: Dictionary = SURFACE_STEP_PROFILE.get(surface, SURFACE_STEP_PROFILE["stone"])
			_footsteps_player.pitch_scale = float(profile["pitch"])
			_footsteps_player.volume_db = float(profile["volume_db"])
		if not _footsteps_player.playing:
			_footsteps_player.play()
	else:
		if _footsteps_player.playing:
			_footsteps_player.stop()


func stop_footsteps() -> void:
	_is_stepping = false
	if _footsteps_player != null and is_instance_valid(_footsteps_player):
		_footsteps_player.stop()


## Balanceo de cabeza al caminar (Game Feel): avanza la fase con la velocidad
## HORIZONTAL real (no la de entrada), así se sincroniza con choques/paredes/
## agua, y se desvanece con un `_bob_blend` suavizado en vez de cortar de golpe
## al soltar las teclas. Sin movimiento ni sobre suelo, vuelve a la pose base.
func _update_head_bob(delta: float) -> void:
	if _head == null:
		return
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var moving := horiz_speed > 0.05 and is_on_floor() and is_active
	var target_blend := 1.0 if moving else 0.0
	_bob_blend = move_toward(_bob_blend, target_blend, BOB_BLEND_SPEED * delta)
	if Locale.reduce_motion or _bob_blend <= 0.0:
		_head.position = _head_base_pos
		if not moving:
			_bob_time = 0.0
		return
	# La fase avanza proporcional a la velocidad real (respeta agua lenta / x3 debug).
	_bob_time += delta * BOB_FREQUENCY * (horiz_speed / SPEED)
	var phase := _bob_time * TAU
	var off_y := sin(phase * 2.0) * BOB_AMPLITUDE_Y * _bob_blend
	var off_x := sin(phase) * BOB_AMPLITUDE_X * _bob_blend
	_head.position = _head_base_pos + Vector3(off_x, off_y, 0.0)


## Sube un escalón pequeño (borde de una pared/losa baja, p. ej. el borde de un
## hueco de agua/lava) con el que el jugador acaba de chocar de frente. Antes se
## probaba UNA sola caída con velocidad fija (-9.8 m/s durante un solo tick de
## física): con huecos cercanos al límite de STEP_MAX_HEIGHT esa caída no
## recorría lo suficiente para "aterrizar" y se revertía el intento — el
## jugador quedaba atrapado (bug reportado: agua/lava sin salida). Ahora se usa
## un RAYCAST hacia abajo desde la posición elevada: si encuentra suelo dentro
## del rango del escalón, el jugador se coloca EXACTAMENTE ahí (sin depender de
## cuánto "cae" en un tick), y solo si no hay suelo alcanzable se revierte.
const STEP_MAX_HEIGHT: float = 0.45
func _try_step_up(prev_pos: Vector3) -> void:
	var blocked_pos := global_position
	# Reintenta el avance de este frame, pero elevado por encima del escalón.
	global_position = prev_pos + Vector3(0.0, STEP_MAX_HEIGHT, 0.0)
	move_and_slide()

	var space := get_world_3d().direct_space_state
	var from := global_position
	var to := from + Vector3(0.0, -(STEP_MAX_HEIGHT + 0.1), 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		global_position = blocked_pos
		return
	# Firme sobre el punto de impacto (pequeño margen para no re-chocar por hundimiento).
	global_position.y = hit.get("position", from).y + 0.02
	velocity.y = 0.0


# ══════════════════════════════════════════════════════════════════════════════
# MÉTODOS DE INTERACCIÓN
# ══════════════════════════════════════════════════════════════════════════════

func set_in_water(val: bool) -> void:
	if val:
		_water_zones += 1
	else:
		_water_zones = maxi(0, _water_zones - 1)
	var now_in := _water_zones > 0
	if now_in != is_in_water:
		is_in_water = now_in
		water_changed.emit(is_in_water)


func set_in_lava(val: bool) -> void:
	if val:
		_lava_zones += 1
	else:
		_lava_zones = maxi(0, _lava_zones - 1)
	var was_in := is_in_lava
	is_in_lava = _lava_zones > 0
	if is_in_lava and not was_in:
		_lava_timer = LAVA_TICK # Aplicar daño inmediato al pisar
		var orb: Node = get_node_or_null("/root/OrbCompanionManager")
		if orb != null and orb.has_method("trigger_bark"):
			orb.call("trigger_bark", "lava_step")


## Suelo de hielo deslizante (idea.md §1.2, `DungeonIceZone.gd`).
func set_on_ice(val: bool) -> void:
	if val:
		_ice_zones += 1
	else:
		_ice_zones = maxi(0, _ice_zones - 1)
	var was_on := is_on_ice
	is_on_ice = _ice_zones > 0
	if is_on_ice and not was_on:
		var orb: Node = get_node_or_null("/root/OrbCompanionManager")
		if orb != null and orb.has_method("trigger_bark"):
			orb.call("trigger_bark", "ice_slip")


## Escalada de muros (idea.md §1.1, `DungeonClimbZone.gd`). Contador (no bool)
## para que solapar dos franjas de escalada contiguas no corte el modo al
## cruzar el borde entre ambas. Al soltarse, anula la velocidad vertical de
## escalada para que la gravedad retome el control desde velocidad cero.
func set_climbing(val: bool) -> void:
	if val:
		_climb_zones += 1
	else:
		_climb_zones = maxi(0, _climb_zones - 1)
	is_climbing = _climb_zones > 0
	if not is_climbing:
		velocity.y = 0.0


## Corrientes de agua direccionales (idea.md §1.2, `DungeonWaterZone.gd`). Cada
## zona llama a esto con SU vector fijo al entrar y lo resta simétricamente al
## salir (`remove_water_current`); solapar varias corrientes las suma.
func add_water_current(dir: Vector3) -> void:
	_water_current += dir


func remove_water_current(dir: Vector3) -> void:
	_water_current -= dir


## Impulso vertical instantáneo (Trampolín, idea.md §1.1): sustituye
## `velocity.y` directamente, dejando que la gravedad se encargue de la caída
## exactamente igual que en un salto normal.
func apply_vertical_impulse(force: float) -> void:
	velocity.y = force


func take_damage_spikes(amount: int, spike_pos: Vector3) -> void:
	# I-frames: ignora nuevos pinchos durante el enfriamiento (evita rebotes múltiples)
	if _spike_cooldown > 0.0:
		return
	_spike_cooldown = SPIKE_COOLDOWN
	_apply_dungeon_damage(amount, "spikes")

	# Calcular empuje en sentido opuesto al pincho
	var push_dir := (global_position - spike_pos)
	push_dir.y = 0.0
	if push_dir.length_squared() < 0.01:
		push_dir = -global_transform.basis.z # Empujar hacia atrás por defecto
	else:
		push_dir = push_dir.normalized()

	_knockback_velocity = push_dir * KNOCKBACK_SPEED
	_knockback_timer = KNOCKBACK_TIME


func take_damage_flame(amount: int, flame_pos: Vector3) -> void:
	# I-frames: ignora nuevo daño durante el enfriamiento (evita rebotes múltiples)
	if _spike_cooldown > 0.0:
		return
	_spike_cooldown = SPIKE_COOLDOWN
	_apply_dungeon_damage(amount, "flame")

	# Calcular empuje en sentido opuesto a la llama (mismo efecto que pinchos)
	var push_dir := (global_position - flame_pos)
	push_dir.y = 0.0
	if push_dir.length_squared() < 0.01:
		push_dir = -global_transform.basis.z # Empujar hacia atrás por defecto
	else:
		push_dir = push_dir.normalized()

	_knockback_velocity = push_dir * KNOCKBACK_SPEED
	_knockback_timer = KNOCKBACK_TIME


func _apply_dungeon_damage(amount: int, cause: String = "") -> void:
	GlobalState.hp = clampi(GlobalState.hp - amount, 0, GlobalState.max_hp)
	GlobalState.state_updated.emit()
	took_damage.emit(cause)
	if GlobalState.hp <= 0:
		# Encontrar el nodo raíz ViewDungeon para gatillar la defunción
		var parent_node = get_parent()
		while parent_node != null and not parent_node.has_method("_on_player_died"):
			parent_node = parent_node.get_parent()
		if parent_node != null:
			parent_node._on_player_died(cause)


# ══════════════════════════════════════════════════════════════════════════════
# HABILIDADES DE EXPLORACIÓN — input de teclado → ExplorationSkillController
# ══════════════════════════════════════════════════════════════════════════════

## Cámara del jugador (nodo de apuntado del controller de habilidades).
func _camera() -> Camera3D:
	return $head/Camera3D as Camera3D


## Detección de pulsaciones (flanco de subida) de las teclas 1-6 → habilidad i.
func _process_skill_input() -> void:
	if _skill_ctrl == null:
		return
	var ids := ExplorationSkills.ORDER
	for i in range(SKILL_KEYS.size()):
		var pressed := Input.is_key_pressed(SKILL_KEYS[i])
		if pressed and not bool(_prev_skill_keys[i]) and i < ids.size():
			_skill_ctrl.try_use(String(ids[i]))
		_prev_skill_keys[i] = pressed


# ══════════════════════════════════════════════════════════════════════════════
# ELEMENTO ALMACENADO (Afinidad Elemental)
# ══════════════════════════════════════════════════════════════════════════════

## Almacena el elemento activo de la Afinidad Elemental (lo invoca la reacción
## `ElementSource` al absorber de una antorcha/bloque). Lo delega en el controller.
func set_stored_element(element: String) -> void:
	if _skill_ctrl != null:
		_skill_ctrl.set_element(element)


# ══════════════════════════════════════════════════════════════════════════════
# FEEDBACK VISUAL DE HABILIDADES
#
# Al USAR con éxito una habilidad (señal `skill_used`), el jugador dispara su
# efecto visual propio (vía `SkillVfx`), SIEMPRE y con independencia de si un
# Objeto Inteligente reaccionó. El origen imita el "brazo" (bajo la cámara) y el
# destino es el punto apuntado (impacto del raycast o alcance máximo).
# ══════════════════════════════════════════════════════════════════════════════

## Reacciona al uso de una habilidad reproduciendo su feedback visual.
func _on_skill_used(skill_id: String) -> void:
	var verb := ExplorationSkills.verb(skill_id)
	if verb == "":
		return
	var cam := _camera()
	if cam == null:
		return
	var dir := (-cam.global_transform.basis.z).normalized()
	var cam_pos := cam.global_position
	# Origen visual "desde el brazo": algo por delante y por debajo de la cámara.
	var origin := cam_pos + dir * 0.4 + Vector3(0, -0.35, 0)
	var reach := ExplorationSkills.range_of(skill_id)
	if reach <= 0.0:
		reach = 6.0
	var point := _aim_point(cam_pos, dir, reach)
	var color: Color = ExplorationSkills.get_skill(skill_id).get("color", Color.WHITE)
	if verb == "element":
		color = _element_color(_skill_ctrl.current_element, color)
	SkillVfx.cast(get_parent(), verb, origin, dir, point, color)
	Input.vibrate_handheld(30)

	# Retroceso táctil de la cámara al lanzar la habilidad
	var head_node := get_node_or_null("head") as Node3D
	if head_node != null:
		var recoil_z := 0.06 if verb == "impact" else 0.03
		var kick_t := create_tween()
		kick_t.tween_property(head_node, "position:z", head_node.position.z + recoil_z, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		kick_t.tween_property(head_node, "position:z", head_node.position.z, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Punto apuntado: primer impacto del raycast desde `from` en `dir` hasta `reach`
## metros; si no golpea nada, el punto a alcance máximo.
func _aim_point(from: Vector3, dir: Vector3, reach: float) -> Vector3:
	var world := get_world_3d()
	if world == null:
		return from + dir * reach
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach)
	q.exclude = [get_rid()]
	var hit := world.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return from + dir * reach
	return hit.get("position", from + dir * reach)


## Color del aura de la Afinidad Elemental según el elemento activo (o `fallback`).
func _element_color(element: String, fallback: Color) -> Color:
	match element:
		"fuego": return Color(0.95, 0.45, 0.20)
		"agua": return Color(0.30, 0.60, 0.95)
		"hielo": return Color(0.60, 0.85, 0.95)
		"rayo", "electrico": return Color(0.95, 0.90, 0.30)
		"viento": return Color(0.60, 0.90, 0.70)
		"tierra": return Color(0.70, 0.55, 0.35)
		"veneno", "toxico": return Color(0.55, 0.85, 0.30)
		"sagrado", "luz": return Color(1.0, 0.95, 0.70)
		"oscuridad": return Color(0.55, 0.35, 0.75)
		_: return fallback


## Reposiciona de forma segura al jugador al caer al vacío, restando 10% HP y con audio feedback.
func _recover_from_void_fall() -> void:
	AudioManager.play_sfx("hit")
	_apply_dungeon_damage(max(1, int(GlobalState.max_hp * 0.10)), "void_fall")
	if not is_inside_tree() or GlobalState.hp <= 0:
		_is_repositioning_void = false
		return
	var target_pos := _last_safe_position if _last_safe_position != Vector3.ZERO else Vector3(0, 0.5, 0)
	global_position = target_pos
	velocity = Vector3.ZERO
	var tree := get_tree()
	if tree != null:
		tree.create_timer(0.3).timeout.connect(func() -> void:
			_is_repositioning_void = false
		)
	else:
		_is_repositioning_void = false

