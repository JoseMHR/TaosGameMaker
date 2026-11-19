# Anchor.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: ANCLAJE  (verbo: grab)
#
# Punto FIJO al que el jugador se atrae a sí mismo con el Agarre Psíquico (a
# diferencia de `Pullable`, donde el objeto viene al jugador). No mueve al objeto:
# pide a la fuente (el jugador) que se desplace hacia el punto de anclaje.
#
# La reacción no conoce al jugador: usa duck-typing sobre `source` si expone
# `pull_self_to(point: Vector3)`.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionAnchor
extends SkillReaction

## Punto de anclaje relativo al host (por defecto, el propio origen del host).
@export var anchor_offset: Vector3 = Vector3.ZERO


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["grab"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	var source = ctx.get("source", null)
	if source == null or not (source is Node) or not (source as Node).has_method("pull_self_to"):
		return false
	var point := host.global_position + anchor_offset
	var hit_point = ctx.get("point", point)
	# Preferimos el punto exacto de impacto si la habilidad lo aportó.
	(source as Node).call("pull_self_to", hit_point if hit_point is Vector3 else point)
	return true
