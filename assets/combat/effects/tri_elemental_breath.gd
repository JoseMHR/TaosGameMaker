# tri_elemental_breath.gd — "Aliento Trivalente": haz mental concentrado y onda de choque psíquica.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.beam(ctx, Color(0.7, 0.4, 0.95), 1.05)
	Kit.impact_burst(ctx, Color(0.8, 0.5, 1.0), 1.0)
	Kit.status_motes(ctx, Color(0.7, 0.3, 0.9), "✨", 3, 1, ctx.get("target"))
