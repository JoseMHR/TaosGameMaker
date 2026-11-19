# nob_talk.gd — "Hablar": diálogo y expresión cómica.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.speech_bubble(ctx, "💬", Color(1.0, 0.95, 0.8), 1.1)
	Kit.status_motes(ctx, Color(1.0, 0.85, 0.4), "💬", 3, 1, ctx.get("target"))
