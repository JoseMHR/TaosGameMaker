# TimeAffected.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: AFECTADO POR EL TIEMPO  (verbo: timeshift)
#
# Alterna entre marcha normal y marcha lenta. Sirve para plataformas móviles,
# cuchillas, molinos, pinchos, puertas temporizadas… El objeto expone su propio
# "factor de tiempo" y quien lo anime debe multiplicar su velocidad por él.
# Emite un evento opcional al cambiar de estado.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionTimeAffected
extends SkillReaction

## Factor de velocidad cuando está ralentizado (0 = detenido, 1 = normal).
@export var slow_factor: float = 0.15
## Evento opcional al alternar. Payload: { "slowed": bool }.
@export var toggle_event: String = ""

## Factor actual (lo leen los animadores/movedores del objeto). 1.0 = normal.
var time_factor: float = 1.0
var _slowed: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["timeshift"])


func apply(host: Node3D, _ctx: Dictionary) -> bool:
	_slowed = not _slowed
	time_factor = slow_factor if _slowed else 1.0
	# Compatibilidad con cuerpos físicos: ajustamos amortiguación como antaño.
	var body := host as RigidBody3D
	if body != null:
		body.linear_damp = 10.0 if _slowed else 0.0
		body.angular_damp = 10.0 if _slowed else 0.0
	if toggle_event != "":
		GlobalEvents.emit_event(toggle_event, {"slowed": _slowed, "position": host.global_position})
	return true
