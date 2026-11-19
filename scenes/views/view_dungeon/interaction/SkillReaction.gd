# SkillReaction.gd
# ─────────────────────────────────────────────────────────────────────────────
# BASE DE LAS REACCIONES DE OBJETO INTELIGENTE
#
# Una reacción es un "ladrillo" reutilizable que se añade como hijo de un
# `Interactable`. Declara a qué VERBOS responde (impact, grab, timeshift,
# reveal, element, restore) y define QUÉ hace en `apply()`. El motor y las
# habilidades NUNCA conocen la reacción concreta: solo emiten un verbo.
#
# Componer objetos = combinar reacciones en el editor. No se programa por objeto.
# ─────────────────────────────────────────────────────────────────────────────
class_name SkillReaction
extends Node

## Verbos a los que responde esta reacción (base, sin sufijo). P.ej. ["impact"],
## ["grab"], ["element"]. Un verbo con datos ("element:fire") casa por su base
## ("element").
@export var verbs: PackedStringArray = PackedStringArray()

## Si es false, la reacción se ignora (útil para activarla/desactivarla por evento
## o desde el editor sin borrarla).
@export var enabled: bool = true

## Si true, un verbo DIRIGIDO (raycast: restore/element) también puede activar esta
## reacción por CERCANÍA cuando el jugador no está apuntando exactamente al objeto
## (p.ej. limpiar una casilla venenosa a tus pies, absorber agua de la casilla en la
## que estás, o coger fuego de una hoguera contigua). Las reacciones de ÁREA no lo
## necesitan. Lo activa la fábrica según el catálogo (campo "proximity" de la pieza).
@export var proximity: bool = false


## Base de un verbo: "element:fire" -> "element".
static func verb_base(verb: String) -> String:
	var i := verb.find(":")
	return verb.substr(0, i) if i >= 0 else verb


## ¿Responde esta reacción al verbo dado?
func matches(verb: String) -> bool:
	if not enabled:
		return false
	var base := verb_base(verb)
	for v in verbs:
		if verb_base(String(v)) == base:
			return true
	return false


## Ejecuta la reacción sobre `host` (raíz del objeto) con el contexto de la
## habilidad. Devuelve true si la reacción hizo algo. SOBRESCRIBIR en cada hijo.
##   ctx = { verb, origin: Vector3, direction: Vector3, element: String,
##           source: Node, strength: float }
func apply(_host: Node3D, _ctx: Dictionary) -> bool:
	push_warning("SkillReaction.apply() sin sobrescribir en %s" % get_class())
	return false
