# Purify.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: PURIFICAR  (verbo: restore)
#
# Casilla contaminada (veneno en el suelo, agua envenenada) que la Purificación
# del sacerdote LIMPIA. Al recibir el verbo muestra un DESTELLO de brillo, oculta
# el estado contaminado y revela el estado limpio:
#   · casilla venenosa      → casilla sin nada (suelo desnudo).
#   · casilla de agua sucia  → casilla de agua normal (azul).
# Es de un solo uso (una vez limpia, ya no reacciona). Emite un evento opcional.
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionPurify
extends SkillReaction

## Nodo del estado contaminado (se oculta al limpiar). Opcional.
@export var polluted_node: NodePath
## Nodo del estado limpio (se muestra al limpiar; puede estar vacío = "sin nada").
@export var clean_node: NodePath
## Evento global al limpiar. P.ej. "EVENT_TILE_PURIFIED".
@export var purify_event: String = ""
## Color del destello de purificación.
@export var glow_color: Color = Color(0.6, 1.0, 0.85)

var _done: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["restore"])


func execute_purify(target_node: Node) -> void:
	if target_node == null:
		return
	# 1. Purificación de agua tóxica/venenosa
	if target_node.has_meta("is_poisoned") and target_node.get_meta("is_poisoned"):
		target_node.set_meta("is_poisoned", false)
		const WATER_SHADER_PATH := "res://scenes/views/view_dungeon/components/dungeon_water.gdshader"
		const WATER_TEX_PATH := "res://assets/dungeon/textures/tile_water_clean.png"
		var clean_mat: Material = null
		if ResourceLoader.exists(WATER_SHADER_PATH):
			var sm := ShaderMaterial.new()
			sm.shader = load(WATER_SHADER_PATH) as Shader
			if ResourceLoader.exists(WATER_TEX_PATH):
				sm.set_shader_parameter("water_texture", load(WATER_TEX_PATH) as Texture2D)
			clean_mat = sm
		else:
			var std := StandardMaterial3D.new()
			std.albedo_color = Color(0.1, 0.4, 0.9, 0.7)
			clean_mat = std

		if target_node is MeshInstance3D:
			(target_node as MeshInstance3D).material_override = clean_mat
		elif target_node is CSGMesh3D:
			(target_node as CSGMesh3D).material = clean_mat
		if Juice != null and Juice.has_method("spawn_floating_text_3d"):
			Juice.spawn_floating_text_3d(target_node.global_position, "¡Agua Purificada!", Color.CYAN)

	# 2. Reparación de estructuras caídas/rotas
	if target_node.has_meta("state") and String(target_node.get_meta("state")) == "broken":
		target_node.set_meta("state", "normal")
		if "state" in target_node:
			target_node.set("state", "normal")
		var tween := target_node.create_tween()
		tween.tween_property(target_node, "rotation_degrees", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BOUNCE)
		if Juice != null and Juice.has_method("spawn_floating_text_3d"):
			Juice.spawn_floating_text_3d(target_node.global_position, "¡Estructura Reparada!", Color.GOLD)


func apply(host: Node3D, ctx: Dictionary) -> bool:
	execute_purify(host)
	if _done:
		return false

	var state_val: String = String(host.get_meta("state", host.get("state") if "state" in host else "normal"))
	if state_val == "broken":
		host.set_meta("state", "normal")
		if "state" in host:
			host.set("state", "normal")
		var tw_rot := host.create_tween()
		tw_rot.tween_property(host, "rotation_degrees", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_glow_burst(host)
		return true

	_done = true
	var polluted := host.get_node_or_null(polluted_node)
	var clean := host.get_node_or_null(clean_node)
	if polluted is Node3D:
		var p_node := polluted as Node3D
		p_node.visible = false
		p_node.process_mode = Node.PROCESS_MODE_DISABLED
		_disable_areas(p_node)
	if clean is Node3D:
		var c_node := clean as Node3D
		c_node.visible = true
		c_node.process_mode = Node.PROCESS_MODE_INHERIT

	var src := ctx.get("source") as Node
	if src != null and src.has_method("set_in_lava"):
		src.set_in_lava(false)

	_glow_burst(host)
	if purify_event != "":
		GlobalEvents.emit_event(purify_event, {"position": host.global_position})
	return true


func _disable_areas(root: Node) -> void:
	if root is Area3D:
		var a := root as Area3D
		if a.monitoring:
			for b in a.get_overlapping_bodies():
				if b.has_method("set_in_lava"):
					b.set_in_lava(false)
		a.monitoring = false
		a.monitorable = false
	for child in root.get_children():
		_disable_areas(child)


## Destello de purificación bien visible: una esfera emisiva que se expande y
## desvanece + una luz intensa que decae. Deja claro que la casilla se ha limpiado.
func _glow_burst(host: Node3D) -> void:
	# Esfera de brillo que crece y se desvanece.
	var mi := MeshInstance3D.new()
	mi.add_to_group("elementos_temporales_mazmorra")
	var sm := SphereMesh.new()
	sm.radius = 0.4
	sm.height = 0.8
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 4.0
	mi.material_override = mat
	mi.position = Vector3(0, 0.6, 0)
	host.add_child(mi)

	# Luz intensa para que el destello se note aunque la sala esté iluminada.
	var light := OmniLight3D.new()
	light.add_to_group("elementos_temporales_mazmorra")
	light.light_color = glow_color
	light.light_energy = 6.0
	light.omni_range = 6.0
	light.position = Vector3(0, 0.8, 0)
	host.add_child(light)

	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 4.0, 0.6)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.tween_property(light, "light_energy", 0.0, 0.6)
	tw.chain().tween_callback(mi.queue_free)
	tw.tween_callback(light.queue_free)
