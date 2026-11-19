# arc_rain_of_arrows.gd — "Lluvia de Flechas": lluvia torrencial de flechas y proyectiles.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.arrow_volley(ctx, Color(1.0, 0.85, 0.4), 5, 1.05)
	Kit.impact_burst(ctx, Color(1.0, 0.85, 0.4), 1.0)
