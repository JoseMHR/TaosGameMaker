# war_shield_crusher.gd — "Triturador de Escudos": golpe frontal de escudo y aturdimiento.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.shield_dome(ctx, Color(0.6, 0.8, 1.0), 1.05)
	Kit.impact_burst(ctx, Color(0.9, 0.8, 0.3), 1.05)
	Kit.status_motes(ctx, Color(1.0, 0.85, 0.3), "💫", 3, 1, ctx.get("target"))
