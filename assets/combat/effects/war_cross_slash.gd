# war_cross_slash.gd — "Tajo Cruzado": doble corte cruzado en 'X' con resplandor dorado.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.slash(ctx, Color(1.0, 0.85, 0.3), 1.05, -45.0, 1)
	Kit.slash(ctx, Color(1.0, 0.95, 0.6), 1.05, 45.0, 1)
