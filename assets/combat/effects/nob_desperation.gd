# nob_desperation.gd — "Desesperación": ráfaga cómica de bofetadas de pánico.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.slap_hand(ctx, Color(1.0, 0.7, 0.4), 1.1)
	Kit.impact_burst(ctx, Color(1.0, 0.5, 0.3), 1.0)
