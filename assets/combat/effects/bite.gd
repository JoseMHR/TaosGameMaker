# bite.gd — "Mordisco": mandíbulas feroces con crujido e impacto.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.bite_chomp(ctx, Color(1.0, 0.85, 0.4), 1.1)
	Kit.impact_burst(ctx, Color(1.0, 0.85, 0.4), 1.0)
