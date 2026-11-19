# war_heroic_charge.gd — "Carga Heroica": embestida frontal perforante con impacto demoledor.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.piercing_line(ctx, Color(1.0, 0.8, 0.3), 1.1)
	Kit.impact_burst(ctx, Color(1.0, 0.7, 0.2), 1.05)
