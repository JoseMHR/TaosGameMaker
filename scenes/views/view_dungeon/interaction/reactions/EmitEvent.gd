# EmitEvent.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: EMITIR EVENTO  (verbo configurable)
#
# La reacción más simple y versátil: al recibir un verbo compatible, dispara un
# evento global con un payload configurable. Permite conectar cualquier objeto al
# resto del juego (misiones, mapamundi, campamento…) sin escribir código nuevo.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionEmitEvent
extends SkillReaction

## Nombre del evento a emitir. P.ej. "EVENT_DUNGEON_SECRET_FOUND".
@export var event_name: String = ""
## Payload extra (se fusiona con la posición del host).
@export var payload: Dictionary = {}


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if event_name == "":
		return false
	var data := payload.duplicate(true)
	data["position"] = host.global_position
	data["verb"] = ctx.get("verb", "")
	GlobalEvents.emit_event(event_name, data)
	return true
