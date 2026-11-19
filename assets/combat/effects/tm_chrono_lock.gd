# tm_chrono_lock.gd — "Cerrojo Temporal": paro temporal absoluto y distorsión cronológica.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(0.4, 0.6, 1.0))
	Kit.status_motes(ctx, Color(0.6, 0.7, 1.0), "🛑", 2, 1, ctx.get("target"))
	Kit.status_motes(ctx, Color(0.5, 0.8, 1.0), "⏳", 2, -1, ctx.get("target"))
