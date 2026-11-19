# tm_chrono_break.gd — "Ruptura Temporal": manipulación de vórtice cronológico.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.vortex(ctx, Color(0.4, 0.7, 1.0), 1.05)
	Kit.status_motes(ctx, Color(0.5, 0.8, 1.0), "⏳", 3, 1, ctx.get("target"))
