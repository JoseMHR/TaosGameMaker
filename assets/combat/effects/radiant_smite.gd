# radiant_smite.gd — "Castigo Radiante": ráfaga de magia concentrada con haz de energía.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.beam(ctx, Color(1.0, 0.95, 0.6), 1.05)
	Kit.impact_burst(ctx, Color(1.0, 0.95, 0.6), 1.0)
