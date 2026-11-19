# ele_wind_2.gd — "Viento II": ráfagas de viento huracanado cortante.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.slash(ctx, Color(0.5, 0.9, 0.7), 1.05, -25.0, 2)
	Kit.vortex(ctx, Color(0.6, 0.95, 0.8), 1.05)
