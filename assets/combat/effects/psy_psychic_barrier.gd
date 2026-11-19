# psy_psychic_barrier.gd — "Barrera Psíquica": concentración mental y barrera psíquica.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.shield_dome(ctx, Color(0.7, 0.4, 0.95), 1.05)
	Kit.orbit_sparkles(ctx, Color(0.8, 0.5, 1.0), "✨", 1.05)
