# war_slash.gd — "Tajo": tajo físico cortante con halo de acero.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.slash(ctx, Color(1.0, 0.9, 0.6), 1.05, -38.0, 1)
	Kit.impact_burst(ctx, Color(0.9, 0.8, 0.5), 1.0)
