# IceMelt.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: DERRETIR BLOQUE DE HIELO  (verbo: element)
#
# Complementa a `ReactionElementSource` (hielo) del Bloque de Hielo: al recibir
# el elemento de fusión (fuego por defecto), el bloque se derrite de forma
# PERMANENTE en la MISMA casilla de agua caminable/ralentizante que ya se usa
# en `dun_inicial` (ver `DungeonSmartFactory._build_ice_block`, estado "Melted").
# Irreversible, igual que las Raíces quemadas: no vuelve a congelarse y deja de
# ofrecer hielo (se desactiva su `ReactionElementSource` hermana).
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionIceMelt
extends SkillReaction

## Elemento que derrite el hielo (por defecto fuego).
@export var melt_element: String = "fuego"
## Nodo del estado SÓLIDO (hielo, con colisión). Se oculta al derretirse.
@export var solid_node: NodePath
## Nodo del estado DERRETIDO (charca de agua). Se muestra al derretirse.
@export var melted_node: NodePath
## Evento global opcional al derretirse.
@export var activate_event: String = ""

## Reacción hermana (ElementSource de hielo): se desactiva al derretirse, ya
## que el bloque deja de ofrecer hielo una vez convertido en agua. Se asigna
## directamente desde la fábrica (no por NodePath: viven como hermanas bajo el
## mismo Interactable, no bajo `host`).
var ice_source_ref: SkillReaction = null

## Reacción hermana (ElementSource de agua): empieza DESACTIVADA (mientras el
## bloque es hielo sólido) y se activa al derretirse, para que a partir de ese
## momento la charca resultante pueda darte agua igual que una Casilla de agua
## normal. Se asigna directamente desde la fábrica.
var water_source_ref: SkillReaction = null

## Colisión del estado sólido (hijo DIRECTO de `host`, no de `solid_node`: así
## lo exige Godot para que la física la detecte). Se desactiva al derretirse
## SIN tocar la colisión del estado derretido. Se asigna desde la fábrica.
var solid_collision: CollisionShape3D = null

var _melted: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["element"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if not enabled or _melted:
		return false
	var element := String(ctx.get("element", ""))
	if element == "":
		var full := String(ctx.get("verb", ""))
		var i := full.find(":")
		if i >= 0:
			element = full.substr(i + 1)
	if element != melt_element:
		return false

	_melted = true
	_consume_element(ctx)

	var solid := host.get_node_or_null(solid_node)
	var melted := host.get_node_or_null(melted_node)
	if solid is Node3D:
		(solid as Node3D).visible = false
	if solid_collision != null and is_instance_valid(solid_collision):
		solid_collision.disabled = true
	if melted is Node3D:
		(melted as Node3D).visible = true

	if ice_source_ref != null and is_instance_valid(ice_source_ref):
		ice_source_ref.enabled = false
	if water_source_ref != null and is_instance_valid(water_source_ref):
		water_source_ref.enabled = true

	if activate_event != "":
		GlobalEvents.emit_event(activate_event, {"element": element, "position": host.global_position})
	return true


## Vacía el elemento almacenado del jugador tras derretir el bloque.
func _consume_element(ctx: Dictionary) -> void:
	var source = ctx.get("source", null)
	if source != null and (source as Node).has_method("set_stored_element"):
		(source as Node).call("set_stored_element", "")
