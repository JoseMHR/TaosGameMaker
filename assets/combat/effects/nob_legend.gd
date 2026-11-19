# nob_legend.gd — "Leyenda de Don Nadie": proclamación legendaria épica con aura dorada.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(1.0, 0.85, 0.3))
	Kit.speech_bubble(ctx, "¡SOY UNA LEYENDA!", Color(1.0, 0.9, 0.4), 1.1)
	Kit.status_motes(ctx, Color(1.0, 0.9, 0.4), "🌟", 4, 1, ctx.get("origin"))
