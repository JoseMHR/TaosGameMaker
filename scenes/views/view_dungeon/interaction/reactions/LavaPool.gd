# LavaPool.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: CHARCA DE LAVA  (verbo: element)
#
# Casilla de lava suelta en el suelo: NO ofrece ningún elemento (no se puede
# coger nada de ella) y daña mucho mientras arde (Area3D "Hazard" hermana, que
# reutiliza el mismo contrato que la lava del suelo genérico —
# `DungeonLavaZone.gd` / `set_in_lava`).
#
# Con la Afinidad Elemental, si llevas AGUA y usas la habilidad, se apaga PARA
# SIEMPRE: desaparece la lava y aparece un suelo de tierra normal (misma
# textura que la roca de la cueva), cesa el daño y la casilla queda cruzable
# sin peligro. Irreversible, igual que el Bloque de Hielo/la Llama.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionLavaPool
extends SkillReaction

## Elemento que apaga la lava para siempre (por defecto agua).
@export var quench_element: String = "agua"
## Nodo visual de la lava encendida. Se oculta al apagarse.
@export var lava_node: NodePath
## Nodo del suelo de tierra normal tras apagarse. Se muestra al apagarse.
@export var doused_node: NodePath
## Área de peligro (`DungeonLavaZone.gd`) que daña al tocarla. Se desactiva al apagarse.
@export var hazard_node: NodePath
## Evento global opcional al apagarse.
@export var activate_event: String = ""

## Recursos visuales para estilizar la lava con el PNG
@export var lava_shader: Shader = preload("res://scenes/views/view_dungeon/components/dungeon_lava.gdshader")
@export var lava_texture_png: Texture2D = preload("res://assets/world/map/tile_lava.png")

var _doused: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["element"])


func _ready() -> void:
	_apply_lava_texture()


func _apply_lava_texture() -> void:
	var lava := get_node_or_null(lava_node) as Node3D
	if lava == null:
		return

	var meshes: Array[Node] = []
	if lava is MeshInstance3D:
		meshes.append(lava)
	else:
		meshes = lava.find_children("*", "MeshInstance3D")

	for m in meshes:
		if m is MeshInstance3D and lava_shader != null:
			var mat := ShaderMaterial.new()
			mat.shader = lava_shader
			if lava_texture_png != null:
				mat.set_shader_parameter("lava_texture", lava_texture_png)
			(m as MeshInstance3D).material_override = mat


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if _doused:
		return false
	var element := String(ctx.get("element", ""))
	if element != quench_element:
		return false

	_doused = true
	enabled = false
	var source = ctx.get("source", null)
	if source != null and (source as Node).has_method("set_stored_element"):
		(source as Node).call("set_stored_element", "")

	var lava := host.get_node_or_null(lava_node)
	var doused := host.get_node_or_null(doused_node)
	if lava is Node3D:
		(lava as Node3D).visible = false
		for p in (lava as Node3D).find_children("*", "CPUParticles3D"):
			if p is CPUParticles3D:
				(p as CPUParticles3D).emitting = false
	if doused is Node3D:
		(doused as Node3D).visible = true

	# Igual que `Purify._disable_areas`/`Flame._extinguish`: avisa a los cuerpos
	# ya solapados antes de desactivar el área, para que no se queden con el
	# daño de lava encallado por no recibir nunca `body_exited`.
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
		GlobalEvents.emit_event(activate_event, {"position": host.global_position})
	return true
