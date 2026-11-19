# plasma_shot.gd — "Disparo de Plasma": tiro de flecha perforante de alta velocidad.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.piercing_line(ctx, Color(1.0, 0.9, 0.2), 1.05)
	Kit.impact_burst(ctx, Color(1.0, 0.9, 0.2), 1.0)
