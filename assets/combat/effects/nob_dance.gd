# nob_dance.gd — "Bailar": impacto físico cortante con estela y temblor.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.slash(ctx, Color(1.0, 0.85, 0.4), 1.05, -35.0, 1)
	Kit.impact_burst(ctx, Color(1.0, 0.85, 0.4), 1.0)
