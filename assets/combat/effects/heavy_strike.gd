# heavy_strike.gd — "Golpe Pesado": corte vertical brutal de gran potencia y onda de choque.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.slash(ctx, Color(1.0, 0.45, 0.2), 1.15, 90.0, 1)
	Kit.impact_burst(ctx, Color(1.0, 0.5, 0.2), 1.05)
