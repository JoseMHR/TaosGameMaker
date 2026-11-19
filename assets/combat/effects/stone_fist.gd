# stone_fist.gd — "Puño de Piedra": peñasco balístico y cataclismo de tierra.
extends RefCounted
const Kit = preload("res://assets/combat/effects/_fx_kit.gd")

func play(ctx: Dictionary) -> void:
	Kit.projectile_arc(ctx, "🪨", Color(0.65, 0.5, 0.35), 1.05)
	Kit.impact_burst(ctx, Color(0.63, 0.38, 0.1), 1.1)
	Kit.elemental_shard_burst(ctx, Color(0.55, 0.35, 0.15), 1.05)
