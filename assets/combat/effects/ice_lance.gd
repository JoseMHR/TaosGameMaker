# ice_lance.gd — "Lanza de Hielo": congelación en cristales de escarcha y estallido gélido.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.piercing_line(ctx, Color(0.3, 0.8, 1.0), 1.05)
	Kit.ice_freeze_shatter(ctx, Color(0.4, 0.9, 1.0), 1.05)
	Kit.status_motes(ctx, Color(0.2, 0.75, 1.0), "❄️", 3, -1, ctx.get("target"))
