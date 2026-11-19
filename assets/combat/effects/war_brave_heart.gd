# war_brave_heart.gd — "Corazón Valiente": rugido de valor y aura de furia marcial.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(1.0, 0.2, 0.1))
	Kit.status_motes(ctx, Color(1.0, 0.3, 0.1), "🔥", 4, 1, ctx.get("origin"))
	Kit.orbit_sparkles(ctx, Color(1.0, 0.4, 0.2), "⚔️", 1.05)
