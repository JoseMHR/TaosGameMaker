# pri_resurrection.gd — "Resurrección": cruz de sanación sagrada y partículas de vida.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.heal_cross(ctx, Color(0.4, 0.95, 0.4), 1.1)
	Kit.status_motes(ctx, Color(0.5, 1.0, 0.6), "✨", 4, 1, ctx.get("target"))
