# Campfire.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: HOGUERA  (verbo: element)
#
# Hoguera que alterna ENCENDIDA/APAGADA según el elemento que lleve el jugador con
# la Afinidad Elemental (contrato duck-typing: `get_stored_element` /
# `set_stored_element` sobre la fuente):
#   · ENCENDIDA + usas la habilidad  → COGES fuego (sustituye tu elemento) y la
#     hoguera se APAGA.
#   · APAGADA + llevas fuego + usas   → DEJAS el fuego (te quedas vacío) y la
#     hoguera se ENCIENDE.
#   · APAGADA sin fuego               → no ocurre nada (no hay con qué prenderla).
#
# Es el ejemplo base del intercambio de elementos con el entorno. Reversible.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionCampfire
extends SkillReaction

## Elemento que ofrece/acepta la hoguera (por defecto fuego).
@export var element: String = "fuego"
## Nodo del estado ENCENDIDO (llama + luz). Se muestra cuando `lit` es true.
@export var lit_node: NodePath
## Nodo del estado APAGADO (leña fría). Se muestra cuando `lit` es false.
@export var unlit_node: NodePath
## Estado inicial: true = empieza encendida.
@export var lit: bool = true


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["element"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	var source = ctx.get("source", null)
	if source == null or not (source is Node) or not (source as Node).has_method("set_stored_element"):
		return false
	var holding := String(ctx.get("element", ""))
	if lit:
		# Coger fuego (sustituye lo que llevaras) y apagar la hoguera.
		(source as Node).call("set_stored_element", element)
		lit = false
		_apply_visual(host)
		return true
	# Apagada: solo se puede encender si llevas su elemento.
	if holding == element:
		(source as Node).call("set_stored_element", "")
		lit = true
		_apply_visual(host)
		return true
	return false


## Sincroniza la visibilidad de los dos estados con `lit`. La visibilidad INICIAL
## la fija la fábrica (el `_ready` de la reacción corre antes de que el Interactable
## resuelva su host), así que aquí solo se actualiza en cada cambio de estado.
func _apply_visual(host: Node3D) -> void:
	var on := host.get_node_or_null(lit_node)
	var off := host.get_node_or_null(unlit_node)
	if on is Node3D:
		(on as Node3D).visible = lit
	if off is Node3D:
		(off as Node3D).visible = not lit
