# tail_whip.gd — "Coletazo Sísmico": impacto físico cortante con estela y temblor.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.slash(ctx, Color(0.7, 0.5, 0.3), 1.05, -35.0, 1)
	Kit.impact_burst(ctx, Color(0.7, 0.5, 0.3), 1.0)
