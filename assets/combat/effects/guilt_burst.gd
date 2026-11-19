# guilt_burst.gd — "Estallido de Culpa": ráfaga de magia concentrada con haz de energía.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.beam(ctx, Color(0.4, 0.15, 0.5), 1.05)
	Kit.impact_burst(ctx, Color(0.4, 0.15, 0.5), 1.0)
