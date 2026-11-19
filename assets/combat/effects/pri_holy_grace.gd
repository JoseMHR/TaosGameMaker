# pri_holy_grace.gd — "Gracia Sagrada": bendición divina con aura de luz ascendente.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.shield_dome(ctx, Color(1.0, 0.95, 0.6), 1.1)
	Kit.status_motes(ctx, Color(1.0, 0.95, 0.7), "✨", 4, 1, ctx.get("target"))
	Kit.orbit_sparkles(ctx, Color(1.0, 0.95, 0.7), "😇", 1.05)
