# arc_poison_arrow.gd — "Flecha Venenosa": flecha tóxica envenenada con estela verde.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.piercing_line(ctx, Color(0.52, 0.8, 0.09), 1.05)
	Kit.status_motes(ctx, Color(0.52, 0.8, 0.09), "☣️", 3, -1, ctx.get("target"))
