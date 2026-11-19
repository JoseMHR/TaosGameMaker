# psy_nightmare.gd — "Pesadilla": distorsión mental y ondas psíquicas de confusión.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(0.7, 0.3, 0.9))
	Kit.vortex(ctx, Color(0.66, 0.33, 0.97), 1.05)
	Kit.status_motes(ctx, Color(0.7, 0.4, 1.0), "🌀", 3, -1, ctx.get("target"))
