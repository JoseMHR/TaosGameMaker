# tm_delay.gd — "Retardo": ralentización cronológica con motas temporales descendentes.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.status_motes(ctx, Color(0.5, 0.6, 0.95), "🐌", 2, -1, ctx.get("target"))
	Kit.status_motes(ctx, Color(0.4, 0.5, 0.8), "⏳", 2, -1, ctx.get("target"))
