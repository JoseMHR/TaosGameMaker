# quick_shot.gd — "Tiro Rápido": tiro de flecha perforante de alta velocidad.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.piercing_line(ctx, Color(1.0, 0.85, 0.4), 1.05)
	Kit.impact_burst(ctx, Color(1.0, 0.85, 0.4), 1.0)
