# Actuator.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: ACCIONADOR / PALANCA / INTERRUPTOR
#
# Permite que una palanca o interruptor (`lever` / `switch`) de mazmorra
# se active a distancia al ser impactado por habilidades compatibles:
# Onda Cinética ("impact") o Agarre Psíquico ("grab").
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionActuator
extends SkillReaction

var trigger_callable: Callable = Callable()


func _init(on_trigger: Callable = Callable(), custom_verbs: PackedStringArray = PackedStringArray()) -> void:
	if custom_verbs.is_empty():
		verbs = PackedStringArray(["impact", "grab"])
	else:
		verbs = custom_verbs
	trigger_callable = on_trigger


func apply(_host: Node3D, _ctx: Dictionary) -> bool:
	if trigger_callable.is_valid():
		var res = trigger_callable.call()
		return bool(res) if res != null else true
	return false
