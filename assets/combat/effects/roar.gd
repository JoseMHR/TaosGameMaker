# roar.gd — "Rugido Aterrador": rugido sónico devastador con onda expansiva.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.roar_wave(ctx, Color(1.0, 0.85, 0.4), 1.1)
	Kit.status_motes(ctx, Color(1.0, 0.85, 0.4), "🗣️", 3, 1, ctx.get("origin"))
