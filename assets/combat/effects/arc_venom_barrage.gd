# arc_venom_barrage.gd — "Andanada Venenosa": lluvia torrencial de flechas y proyectiles.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.arrow_volley(ctx, Color(0.4, 0.85, 0.2), 5, 1.05)
	Kit.impact_burst(ctx, Color(0.4, 0.85, 0.2), 1.0)
