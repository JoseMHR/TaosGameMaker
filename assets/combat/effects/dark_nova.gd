# dark_nova.gd — "Nova Oscura": haz colosal de energía y estallido destructor.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(0.4, 0.15, 0.5))
	Kit.beam(ctx, Color(0.4, 0.15, 0.5), 1.15)
	Kit.impact_burst(ctx, Color(0.4, 0.15, 0.5), 1.05)
