class_name FireLightFlicker3D
extends OmniLight3D
## CONTROLADOR DE ILUMINACIÓN Y PARPADEO PROCEDURAL PARA FUEGO (Móvil / 60 FPS)
## ─────────────────────────────────────────────────────────────────────────────
## Diseñado para hogueras, forjas y antorchas en el mapamundi y POIs.
## - Varía light_energy asíncronamente con Tween entre 1.7 y 2.3 cada 0.08 - 0.12s.
## - Garantiza 0 sombras locales (shadow_enabled = false) para respetar el presupuesto móvil.
## - Auto-culling: detiene el Tween y apaga la luz cuando sale del campo de visión.
## ─────────────────────────────────────────────────────────────────────────────

@export var min_energy: float = 1.7
@export var max_energy: float = 2.3
@export var min_interval: float = 0.08
@export var max_interval: float = 0.12

var _tween: Tween = null
var _notifier: VisibleOnScreenNotifier3D = null
var _is_on_screen: bool = true


func _ready() -> void:
	# Restricción obligatoria de rendimiento móvil: 0 sombras en luces locales
	shadow_enabled = false
	
	_setup_visibility_culling()
	_schedule_next_flicker()


func _setup_visibility_culling() -> void:
	# Configura culling volumétrico según el radio de la luz
	_notifier = VisibleOnScreenNotifier3D.new()
	var half_range: float = maxf(omni_range * 0.75, 1.5)
	_notifier.aabb = AABB(Vector3(-half_range, -half_range, -half_range), Vector3(half_range * 2.0, half_range * 2.0, half_range * 2.0))
	_notifier.screen_entered.connect(_on_screen_entered)
	_notifier.screen_exited.connect(_on_screen_exited)
	add_child(_notifier)


func _on_screen_entered() -> void:
	_is_on_screen = true
	visible = true
	if _tween == null or not _tween.is_valid():
		_schedule_next_flicker()


func _on_screen_exited() -> void:
	_is_on_screen = false
	visible = false
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _schedule_next_flicker() -> void:
	if not _is_on_screen or not is_inside_tree():
		return

	if _tween != null and _tween.is_valid():
		_tween.kill()

	var target_energy: float = randf_range(min_energy, max_energy)
	var step_duration: float = randf_range(min_interval, max_interval)

	_tween = create_tween()
	_tween.tween_property(self, "light_energy", target_energy, step_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(self._schedule_next_flicker)


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
