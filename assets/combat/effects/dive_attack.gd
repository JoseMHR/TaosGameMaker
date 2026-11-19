# dive_attack.gd — "Ataque en Picado": impacto físico cortante con estela y temblor.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.slash(ctx, Color(0.5, 0.9, 0.7), 1.05, -35.0, 1)
	Kit.impact_burst(ctx, Color(0.5, 0.9, 0.7), 1.0)
