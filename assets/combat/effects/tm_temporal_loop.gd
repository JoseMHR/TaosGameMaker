# tm_temporal_loop.gd — "Bucle Temporal": rebobinado cronológico y restauración de estado.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(0.5, 0.8, 1.0))
	Kit.orbit_sparkles(ctx, Color(0.4, 0.7, 1.0), "⏪", 1.05)
	Kit.status_motes(ctx, Color(0.6, 0.9, 1.0), "⏳", 3, 1, ctx.get("target"))
