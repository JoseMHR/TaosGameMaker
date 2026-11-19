# ele_water_1.gd — "Agua I": torbellino acuático y choque de alta presión.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.vortex(ctx, Color(0.2, 0.6, 0.95), 1.1)
	Kit.impact_burst(ctx, Color(0.3, 0.7, 1.0), 1.05)
	Kit.status_motes(ctx, Color(0.4, 0.8, 1.0), "💧", 3, 1, ctx.get("target"))
