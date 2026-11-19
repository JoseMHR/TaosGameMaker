# judgement_beam.gd — "Rayo del Juicio": haz colosal de energía y estallido destructor.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(1.0, 0.95, 0.6))
	Kit.beam(ctx, Color(1.0, 0.95, 0.6), 1.15)
	Kit.impact_burst(ctx, Color(1.0, 0.95, 0.6), 1.05)
