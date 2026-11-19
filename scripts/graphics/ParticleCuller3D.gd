class_name ParticleCuller3D
extends VisibleOnScreenNotifier3D
## OPTIMIZACIÓN DE PARTÍCULAS POR CULLING AUTOMÁTICO (Móvil / 60 FPS)
## ─────────────────────────────────────────────────────────────────────────────
## Monitorea la visibilidad en pantalla del emisor de partículas adjunto
## (CPUParticles3D o GPUParticles3D).
## - Al salir de pantalla (screen_exited): emitting = false
## - Al entrar en pantalla (screen_entered): emitting = true
## Elimina completamente el consumo de draw calls y actualización de partículas
## fuera de la cámara.
## ─────────────────────────────────────────────────────────────────────────────

@export var particle_node: NodePath

var _emitter: Node = null


func _ready() -> void:
	if not particle_node.is_empty():
		_emitter = get_node_or_null(particle_node)
	elif get_parent() is CPUParticles3D or get_parent() is GPUParticles3D:
		_emitter = get_parent()

	screen_entered.connect(_on_screen_entered)
	screen_exited.connect(_on_screen_exited)

	# Estado inicial según visibilidad de arranque
	if _emitter != null and "emitting" in _emitter:
		_emitter.emitting = is_on_screen()


func _on_screen_entered() -> void:
	if _emitter != null and "emitting" in _emitter:
		_emitter.emitting = true


func _on_screen_exited() -> void:
	if _emitter != null and "emitting" in _emitter:
		_emitter.emitting = false
