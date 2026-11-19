# nob_punch.gd — "Guantazo": bofetón de Don Nadie.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.slap_hand(ctx, Color(1.0, 0.88, 0.4), 1.15)
