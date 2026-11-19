# Pullable.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: ATRAÍBLE  (verbo: grab)
#
# El objeto MÓVIL (RigidBody3D) es atraído hacia el jugador con el Agarre
# Psíquico. Complementa a `Anchor` (donde es el jugador quien se mueve). Un objeto
# suele tener uno u otro, nunca ambos.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionPullable
extends SkillReaction

## Fuerza de atracción hacia el origen del agarre.
@export var pull_force: float = 12.0


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["grab"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	var body := host as RigidBody3D
	if body == null:
		return false
	var origin: Vector3 = ctx.get("origin", body.global_position)
	var to_origin := origin - body.global_position
	if to_origin.length() < 0.01:
		return false
	body.apply_central_impulse(to_origin.normalized() * pull_force)
	return true
