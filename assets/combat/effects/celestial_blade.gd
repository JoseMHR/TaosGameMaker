# celestial_blade.gd — "Hoja Celestial": impacto físico cortante con estela y temblor.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.slash(ctx, Color(1.0, 0.95, 0.6), 1.05, -35.0, 1)
	Kit.impact_burst(ctx, Color(1.0, 0.95, 0.6), 1.0)
