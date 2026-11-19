# frenzy_bite.gd — "Mordisco Frenético": mandíbulas feroces con crujido e impacto.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.bite_chomp(ctx, Color(0.4, 0.85, 0.2), 1.1)
	Kit.impact_burst(ctx, Color(0.4, 0.85, 0.2), 1.0)
