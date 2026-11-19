class_name OrbRotator3D
extends Node3D
## MICRO-ANIMACIÓN PROCEDURAL DE ORBES Y CRISTALES FLOTANTES (Móvil / 60 FPS)
## ─────────────────────────────────────────────────────────────────────────────
## Rota el nodo sobre el eje Y dentro de _process(delta) ÚNICAMENTE cuando está
## visible en pantalla (mediante VisibleOnScreenNotifier3D integrado).
## - Detiene el procesamiento (_set_process(false)) al salir del campo visual.
## - Ofrece suave levitación opcional de bajo coste matemático (sin() sin memoria).
## ─────────────────────────────────────────────────────────────────────────────

@export var rotation_speed: float = 1.25
@export var bob_amplitude: float = 0.025
@export var bob_speed: float = 2.0
@export var culler_radius: float = 0.4

var _base_y: float = 0.0
var _accum_time: float = 0.0
var _notifier: VisibleOnScreenNotifier3D = null
var _is_visible: bool = true


func _ready() -> void:
	_base_y = position.y
	_setup_culler()


func _setup_culler() -> void:
	_notifier = VisibleOnScreenNotifier3D.new()
	_notifier.aabb = AABB(Vector3(-culler_radius, -culler_radius, -culler_radius), Vector3(culler_radius * 2.0, culler_radius * 2.0, culler_radius * 2.0))
	_notifier.screen_entered.connect(_on_screen_entered)
	_notifier.screen_exited.connect(_on_screen_exited)
	add_child(_notifier)


func _on_screen_entered() -> void:
	_is_visible = true
	set_process(true)


func _on_screen_exited() -> void:
	_is_visible = false
	set_process(false)


func _process(delta: float) -> void:
	if not _is_visible:
		return

	rotate_y(rotation_speed * delta)

	if bob_amplitude > 0.0:
		_accum_time += delta * bob_speed
		position.y = _base_y + sin(_accum_time) * bob_amplitude
