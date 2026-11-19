# ele_steam.gd — "Vapor": ráfaga de magia concentrada con haz de energía.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.beam(ctx, Color(0.2, 0.6, 0.95), 1.05)
	Kit.impact_burst(ctx, Color(0.2, 0.6, 0.95), 1.0)
