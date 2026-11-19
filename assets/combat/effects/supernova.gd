# supernova.gd — "Supernova Cósmica": cataclismo cósmico supremo con pilar celestial y estallido.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(0.9, 0.6, 1.0))
	Kit.magic_pillar(ctx, Color(0.85, 0.45, 1.0), 1.15)
	Kit.vortex(ctx, Color(0.8, 0.4, 1.0), 1.1)
	Kit.impact_burst(ctx, Color(0.9, 0.5, 1.0), 1.05)
