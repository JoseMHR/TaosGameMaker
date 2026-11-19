# war_divine_execution.gd — "Ejecución Divina": pilar de justicia divina y tajo ejecutor.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(1.0, 0.9, 0.5))
	Kit.magic_pillar(ctx, Color(1.0, 0.95, 0.7), 1.1)
	Kit.slash(ctx, Color(1.0, 0.85, 0.2), 1.15, -35.0, 2)
