# ElementReceiver.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: RECEPTOR ELEMENTAL  (verbo: element:<x>)
#
# Acepta UN elemento concreto (fuego, hielo, rayo, agua, viento, tierra) aplicado
# con la Afinidad Elemental. Al recibir el elemento correcto se transforma (p.ej.
# antorcha encendida, charco congelado, cristal cargado) y emite un evento. Es la
# base de puzles versátiles: la misma habilidad resuelve muchas situaciones.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionElementReceiver
extends SkillReaction

## Elemento aceptado (debe coincidir con ctx["element"]).
@export_enum("fuego", "hielo", "rayo", "agua", "viento", "tierra") var accepted_element: String = "fuego"
## Nodo del estado inicial (se oculta al activar). Opcional.
@export var inactive_node: NodePath
## Nodo del estado activado (se muestra al activar). Opcional.
@export var active_node: NodePath
## Evento global al activarse. P.ej. "EVENT_TORCH_LIT".
@export var activate_event: String = ""
## Si true, solo se puede activar una vez.
@export var one_shot: bool = true

var _active: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["element"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if one_shot and _active:
		return false
	# El elemento puede venir en ctx["element"] o como sufijo del verbo (element:fuego).
	var element := String(ctx.get("element", ""))
	if element == "":
		var full := String(ctx.get("verb", ""))
		var i := full.find(":")
		if i >= 0:
			element = full.substr(i + 1)
	if element != accepted_element:
		return false
	_active = true
	var burn_script := preload("res://scenes/views/view_dungeon/interaction/reactions/BurnableRoots.gd")
	var is_root := host.name.to_lower().contains("root") or host.get_node_or_null("RootsVisual") != null or String(inactive_node).contains("Unlit")
	if element == "fuego" and is_root:
		var burn_react = burn_script.new()
		burn_react.accepted_element = accepted_element
		burn_react.activate_event = activate_event
		var result := burn_react.apply(host, ctx)
		if result:
			_consume_element(ctx)
		return result

	var inactive := host.get_node_or_null(inactive_node)
	var active := host.get_node_or_null(active_node)
	if inactive is Node3D:
		(inactive as Node3D).visible = false
	if active is Node3D:
		(active as Node3D).visible = true
	if activate_event != "":
		GlobalEvents.emit_event(activate_event, {"element": element, "position": host.global_position})
	_consume_element(ctx)
	return true


## Vacía el elemento almacenado del jugador tras usarlo en un receptor.
func _consume_element(ctx: Dictionary) -> void:
	var source = ctx.get("source", null)
	if source != null and (source as Node).has_method("set_stored_element"):
		(source as Node).call("set_stored_element", "")
