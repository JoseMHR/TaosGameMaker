# feather_storm.gd — "Tormenta de Plumas": tiro de flecha perforante de alta velocidad.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.piercing_line(ctx, Color(0.5, 0.9, 0.7), 1.05)
	Kit.impact_burst(ctx, Color(0.5, 0.9, 0.7), 1.0)
