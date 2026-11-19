# pri_holy_light.gd — "Luz Sagrada": pilar de luz sagrada celestial y purificación.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(1.0, 0.95, 0.6))
	Kit.magic_pillar(ctx, Color(1.0, 0.95, 0.7), 1.1)
	Kit.impact_burst(ctx, Color(1.0, 0.85, 0.4), 1.05)
