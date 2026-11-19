# nob_play_dead.gd — "Hacerse el Muerto": calavera cómica y bocanada de polvo.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.status_motes(ctx, Color(0.7, 0.7, 0.8), "💀", 2, 1, ctx.get("origin"))
	Kit.status_motes(ctx, Color(0.5, 0.5, 0.6), "💨", 3, -1, ctx.get("origin"))
