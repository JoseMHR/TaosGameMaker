# ele_lightning.gd — "Rayo": relámpago en zigzag de alto voltaje con destello.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(1.0, 1.0, 0.7))
	Kit.zigzag_bolt(ctx, Color(1.0, 0.9, 0.2), 1.1)
	Kit.impact_burst(ctx, Color(1.0, 0.95, 0.4), 1.05)
