# truth_burst.gd — "Estallido de la Verdad": ráfaga de magia concentrada con haz de energía.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.beam(ctx, Color(1.0, 0.85, 0.4), 1.05)
	Kit.impact_burst(ctx, Color(1.0, 0.85, 0.4), 1.0)
