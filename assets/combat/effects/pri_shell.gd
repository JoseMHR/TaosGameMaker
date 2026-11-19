# pri_shell.gd — "Coraza": santuario y cúpula de protección divina.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.shield_dome(ctx, Color(1.0, 0.9, 0.5), 1.1)
	Kit.orbit_sparkles(ctx, Color(1.0, 0.95, 0.7), "✨", 1.05)
