# ElementSource.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: FUENTE ELEMENTAL  (verbo: element)
#
# Objeto del que la Afinidad Elemental ABSORBE un elemento (antorcha encendida →
# fuego, bloque de hielo → hielo, etc.). Complementa a `ElementReceiver` (que lo
# APLICA). El mismo verbo "element" absorbe aquí y aplica allá: es el OBJETO quien
# decide, no la habilidad. Al absorber, pide a la fuente (jugador) que almacene el
# elemento vía `set_stored_element(element)` (duck-typing, como `Anchor`).
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionElementSource
extends SkillReaction

## Elemento que ofrece esta fuente (fuego, hielo, rayo, agua, viento, tierra).
@export_enum("fuego", "hielo", "rayo", "agua", "viento", "tierra") var source_element: String = "fuego"
## Si true, la fuente se agota tras un uso (se apaga y deja de ofrecer elemento).
@export var one_shot: bool = false

var _spent: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["element"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if not enabled:
		return false
	if one_shot and _spent:
		return false
	var source = ctx.get("source", null)
	if source == null or not (source is Node) or not (source as Node).has_method("set_stored_element"):
		return false
	(source as Node).call("set_stored_element", source_element)
	_spent = true
	return true
