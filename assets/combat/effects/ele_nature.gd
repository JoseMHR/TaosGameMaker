# ele_nature.gd — "Naturaleza": ráfaga de magia concentrada con haz de energía.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.beam(ctx, Color(0.7, 0.5, 0.3), 1.05)
	Kit.impact_burst(ctx, Color(0.7, 0.5, 0.3), 1.0)
