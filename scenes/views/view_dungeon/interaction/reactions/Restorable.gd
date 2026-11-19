# Restorable.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: RESTAURABLE  (verbo: restore)
#
# Objeto roto/corrupto (puente caído, mecanismo averiado, estatua agrietada, agua
# tóxica) que se REPARA con la Restauración de la Curandera. Constructiva: pasa de
# "roto" a "reparado" una sola vez y emite un evento para que el puzle avance.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionRestorable
extends SkillReaction

## Nodo que representa el estado ROTO (se oculta al restaurar).
@export var broken_node: NodePath
## Nodo que representa el estado REPARADO (se muestra al restaurar).
@export var fixed_node: NodePath
## Evento global al restaurar. P.ej. "EVENT_BRIDGE_REPAIRED".
@export var restore_event: String = ""

var _restored: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["restore"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if _restored:
		return false
	_restored = true
	var broken := host.get_node_or_null(broken_node)
	var fixed := host.get_node_or_null(fixed_node)
	if broken is Node3D:
		(broken as Node3D).visible = false
	if fixed is Node3D:
		(fixed as Node3D).visible = true
	if restore_event != "":
		GlobalEvents.emit_event(restore_event, {"position": host.global_position})
	return true
