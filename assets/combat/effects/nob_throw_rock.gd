# nob_throw_rock.gd — "Lanzar Piedra": pedrada balística parabólica.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.projectile_arc(ctx, "🪨", Color(0.75, 0.65, 0.5), 1.05)
