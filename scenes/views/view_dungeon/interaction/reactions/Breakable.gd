# Breakable.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: ROMPIBLE  (verbo: impact)
#
# El objeto se destruye al recibir un impacto. Opcionalmente emite un evento
# global (para abrir puertas, revelar atajos…) y/o deja botín. No conoce quién
# lo rompe ni qué debe pasar después: solo anuncia "me he roto".
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionBreakable
extends SkillReaction

## Evento global a emitir al romperse (vacío = ninguno). P.ej. "EVENT_WALL_BROKEN".
@export var break_event: String = ""
## Fuerza mínima del impacto necesaria para romperlo (0 = cualquier impacto).
@export var min_strength: float = 0.0
## Si true, libera el nodo; si false, solo lo oculta y desactiva colisión.
@export var free_on_break: bool = true

var _broken: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["impact"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if _broken:
		return false
	if float(ctx.get("strength", 1.0)) < min_strength:
		return false
	_broken = true
	if break_event != "":
		GlobalEvents.emit_event(break_event, {"position": host.global_position})
	AudioManager.play_sfx("hit")
	var parent := host.get_parent()
	if parent != null and is_instance_valid(parent):
		WorldFx.burst(parent, host.global_position, Color(0.72, 0.68, 0.6), 16)
		WorldFx.glow_flash(parent, host.global_position, Color(0.95, 0.75, 0.35), 2.5, 0.3)
	Juice.shake(host, 0.08, 0.15)
	if free_on_break:
		host.queue_free()
	else:
		host.visible = false
		if host is CollisionObject3D:
			(host as CollisionObject3D).process_mode = Node.PROCESS_MODE_DISABLED
	return true
