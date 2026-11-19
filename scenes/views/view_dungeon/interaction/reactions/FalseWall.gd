# FalseWall.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: PARED/SUELO FALSO  (verbo: reveal)
#
# Pieza que PARECE una pared o un suelo normal pero NO tiene colisión: se puede
# atravesar. A simple vista es indistinguible de la geometría sólida. El Instinto
# del Explorador/Cazador la delata: al recibir el verbo `reveal` (de ÁREA), las
# casillas falsas dentro de su rango BRILLAN en morado y permanecen reveladas hasta
# salir de la mazmorra.
#
# No cambia el mundo (sigue siendo atravesable): la resalta para el jugador.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionFalseWall
extends SkillReaction

## Segundos que dura el brillo (si <= 0, permanece revelado hasta salir de la mazmorra).
@export var reveal_seconds: float = 0.0
## Color del brillo revelador.
@export var glow_color: Color = Color(0.72, 0.30, 1.0)
## Intensidad de la emisión del brillo.
@export var glow_energy: float = 4.0

var _timer: SceneTreeTimer = null
## mesh -> material_overlay original (para restaurar al apagar el brillo).
var _backup: Dictionary = {}
## Materiales de brillo activos (para pulsarlos mientras dura el revelado).
var _glow_mats: Array[StandardMaterial3D] = []
var _pulse: Tween = null
var _is_revealed: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["reveal"])


func apply(host: Node3D, _ctx: Dictionary) -> bool:
	if _is_revealed:
		return true
	_is_revealed = true
	_glow_on(host)
	if reveal_seconds > 0.0:
		_timer = host.get_tree().create_timer(reveal_seconds)
		_timer.timeout.connect(_glow_off, CONNECT_ONE_SHOT)
	# Si reveal_seconds <= 0.0, permanece revelada hasta salir de la mazmorra.
	return true


## Aplica un overlay emisivo morado (semitransparente teñido) a todas las mallas y
## arranca un PULSO para que la pieza falsa cante a la vista.
func _glow_on(host: Node3D) -> void:
	if not _glow_mats.is_empty():
		return
	_glow_mats.clear()
	for mi in _iter_meshes(host):
		if not _backup.has(mi):
			_backup[mi] = mi.material_overlay
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.45)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = glow_color
		mat.emission_energy_multiplier = glow_energy
		mi.material_overlay = mat
		_glow_mats.append(mat)
	if _glow_mats.is_empty():
		return
	# Pulso de intensidad de emisión (ida y vuelta, en bucle) mientras está revelada.
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = host.create_tween().set_loops()
	_pulse.tween_method(_set_glow_energy, glow_energy, glow_energy * 0.3, 0.5)
	_pulse.tween_method(_set_glow_energy, glow_energy * 0.3, glow_energy, 0.5)


## Fija la intensidad de emisión en todos los materiales de brillo activos.
func _set_glow_energy(e: float) -> void:
	for m in _glow_mats:
		if is_instance_valid(m):
			m.emission_energy_multiplier = e


## Restaura los materiales originales.
func _glow_off() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	_glow_mats.clear()
	for mi in _backup.keys():
		if is_instance_valid(mi):
			mi.material_overlay = _backup[mi]
	_backup.clear()


func _iter_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for child in root.get_children():
		out.append_array(_iter_meshes(child))
	return out
