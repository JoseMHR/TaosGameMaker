# war_wall.gd — "Muro": cúpula de protección y muralla defensiva.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.shield_dome(ctx, Color(1.0, 0.85, 0.4), 1.1)
	Kit.orbit_sparkles(ctx, Color(1.0, 0.85, 0.4), "🛡️", 1.05)
