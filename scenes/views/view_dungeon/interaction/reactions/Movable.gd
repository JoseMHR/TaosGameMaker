# Movable.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: MOVIBLE  (verbos: impact, grab)
#
# El objeto (RigidBody3D) recibe un impulso:
#   · impact → empujado ALEJÁNDOSE del origen, en la dirección de la habilidad.
#   · grab   → atraído HACIA el origen (traer un objeto suelto).
# Reutilizable para cajas, barriles, estatuas ligeras, plataformas sueltas…
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionMovable
extends SkillReaction

## Fuerza del empuje por impacto.
@export var impact_force: float = 14.0
## Fuerza de atracción por agarre.
@export var pull_force: float = 12.0


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["impact", "grab"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	var body := host as RigidBody3D
	if body == null:
		return false
	var state_val: String = String(host.get_meta("state", host.get("state") if "state" in host else "normal"))
	if state_val == "broken":
		return false

	var weight_val: String = String(host.get_meta("weight", host.get("weight") if "weight" in host else "heavy"))
	var weight_mult: float = 2.0 if weight_val == "light" else 1.0

	var base := verb_base(String(ctx.get("verb", "")))
	var origin: Vector3 = ctx.get("origin", body.global_position)
	if base == "grab":
		var to_origin := (origin - body.global_position)
		if to_origin.length() < 0.01:
			return false
		body.apply_central_impulse(to_origin.normalized() * pull_force * weight_mult)
		return true

	var dir: Vector3 = ctx.get("direction", (body.global_position - origin))
	if dir.length() < 0.01:
		dir = body.global_position - origin
	body.apply_central_impulse(dir.normalized() * impact_force * weight_mult)
	return true
