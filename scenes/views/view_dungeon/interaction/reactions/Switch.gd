# Switch.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: INTERRUPTOR  (verbo configurable)
#
# Activador reutilizable: al recibir un verbo compatible alterna un estado on/off
# y emite un evento global (SwitchActivated). NO conoce qué abre: el puzle se
# cablea por evento (una puerta escucha ese evento). Puede activarse por impacto,
# por un elemento, por agarre… según los `verbs` que se le configuren.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionSwitch
extends SkillReaction

## Identificador lógico del interruptor (va en el payload del evento).
@export var switch_id: String = ""
## Evento global al cambiar. Payload: { "switch_id": String, "on": bool }.
@export var switch_event: String = "EVENT_SWITCH_TOGGLED"
## Si true, solo se puede activar (no vuelve a off).
@export var one_way: bool = false
## Estado inicial.
@export var on: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["impact", "grab"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if one_way and on:
		return false
	on = true if one_way else not on
	if switch_event != "":
		GlobalEvents.emit_event(switch_event, {
			"switch_id": switch_id,
			"on": on,
			"position": host.global_position,
		})
	return true
