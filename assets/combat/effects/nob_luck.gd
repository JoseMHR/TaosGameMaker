# nob_luck.gd — "Suerte": trébol de la fortuna y resplandor de suerte.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.status_motes(ctx, Color(0.3, 0.9, 0.4), "🍀", 3, 1, ctx.get("origin"))
	Kit.orbit_sparkles(ctx, Color(0.4, 1.0, 0.5), "✨", 1.05)
