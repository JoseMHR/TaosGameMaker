# Flame.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: LLAMA VIVA  (verbo: element)
#
# Llama suelta en el suelo. A diferencia de la Hoguera NO tiene cuerpo sólido:
# se puede entrar en su casilla, pero arde y daña mientras está encendida (ver
# Area3D "Hazard" hermana, que reutiliza el mismo contrato que la lava —
# `DungeonLavaZone.gd` / `set_in_lava` — para el daño continuo).
#
# Con la Afinidad Elemental:
#   · ENCENDIDA + usas la habilidad SIN llevar agua → COGES fuego (tu elemento
#     pasa a ser el suyo). La llama NO se apaga: sigue ardiendo y dañando, a
#     diferencia de la Hoguera (que se apaga al dar su fuego).
#   · ENCENDIDA + llevas agua + usas               → se APAGA PARA SIEMPRE (no
#     hay forma de volver a encenderla): cesa el daño y la casilla queda
#     cruzable sin peligro, igual que las Raíces quemadas.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionFlame
extends SkillReaction

## Elemento que ofrece la llama mientras arde (por defecto fuego).
@export var fire_element: String = "fuego"
## Elemento que la apaga para siempre (por defecto agua).
@export var quench_element: String = "agua"
## Nodo visual de la llama encendida (con luz). Se oculta al apagarse.
@export var lit_node: NodePath
## Nodo de la marca de rescoldo/ceniza tras apagarse. Opcional.
@export var ash_node: NodePath
## Área de peligro (`DungeonFlameZone.gd`) que daña y repele al tocarla. Se desactiva al apagarse.
@export var hazard_node: NodePath
## Colisión física que bloquea el paso mientras la llama arde. Se desactiva al apagarse.
@export var blocker_node: NodePath = NodePath("BlockerCol")
## Evento global opcional al apagarse.
@export var activate_event: String = ""

var _lit: bool = true


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["element"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if not _lit:
		return false
	var source = ctx.get("source", null)
	if source == null or not (source is Node) or not (source as Node).has_method("set_stored_element"):
		return false
	var holding := String(ctx.get("element", ""))
	if holding == quench_element:
		_extinguish(host, holding)
		(source as Node).call("set_stored_element", "")
		return true
	# Coger fuego (sustituye lo que llevaras): la llama sigue ardiendo.
	(source as Node).call("set_stored_element", fire_element)
	return true


## Apaga la llama PARA SIEMPRE: oculta la llama, muestra la ceniza y desactiva
## el área de peligro y la colisión bloqueante, permitiendo cruzar la casilla.
func _extinguish(host: Node3D, element: String) -> void:
	_lit = false
	var lit_vis := host.get_node_or_null(lit_node)
	if lit_vis is Node3D:
		(lit_vis as Node3D).visible = false
	var ash := host.get_node_or_null(ash_node)
	if ash is Node3D:
		(ash as Node3D).visible = true
	var blocker := host.get_node_or_null(blocker_node)
	if blocker is CollisionShape3D:
		(blocker as CollisionShape3D).set_deferred("disabled", true)
	elif blocker is CollisionObject3D:
		for child in (blocker as CollisionObject3D).get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred("disabled", true)
	var hazard := host.get_node_or_null(hazard_node)
	if hazard is Area3D:
		var a := hazard as Area3D
		if a.monitoring:
			for b in a.get_overlapping_bodies():
				if b.has_method("set_in_lava"):
					b.set_in_lava(false)
		a.set_deferred("monitoring", false)
		a.set_deferred("monitorable", false)
	if activate_event != "":
		GlobalEvents.emit_event(activate_event, {"element": element, "position": host.global_position})
