# tm_acceleration.gd — "Aceleración": aceleración temporal y velocidad mística.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.status_motes(ctx, Color(0.4, 0.85, 1.0), "⏩", 3, 1, ctx.get("target"))
	Kit.orbit_sparkles(ctx, Color(0.5, 0.9, 1.0), "✨", 1.05)
