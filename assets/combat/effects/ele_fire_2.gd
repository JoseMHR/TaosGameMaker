# ele_fire_2.gd — "Fuego II": proyectil de fuego ardiente con vórtice y ascuas.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.screen_pulse(ctx, Color(1.0, 0.35, 0.1))
	Kit.projectile_arc(ctx, "🔥", Color(1.0, 0.45, 0.1), 1.05)
	Kit.vortex(ctx, Color(1.0, 0.4, 0.1), 1.1)
	Kit.status_motes(ctx, Color(1.0, 0.45, 0.1), "🔥", 3, -1, ctx.get("target"))
