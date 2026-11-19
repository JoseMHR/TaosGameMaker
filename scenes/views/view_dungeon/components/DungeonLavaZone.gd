extends Node

@export var lava_shader: Shader = preload("res://scenes/views/view_dungeon/components/dungeon_lava.gdshader")
@export var lava_texture_png: Texture2D = preload("res://assets/world/map/tile_lava.png")

func _ready() -> void:
	_setup_hazard_area()
	call_deferred("_apply_lava_shader")

func _setup_hazard_area() -> void:
	var area: Area3D = null
	
	var current_node: Node = self
	if current_node is Area3D:
		area = current_node as Area3D
	elif get_parent() != null and get_parent() is Area3D:
		area = get_parent() as Area3D
	
	if area != null:
		if not area.body_entered.is_connected(_on_body_entered):
			area.body_entered.connect(_on_body_entered)
		if not area.body_exited.is_connected(_on_body_exited):
			area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.has_method("set_in_lava"):
		body.set_in_lava(true)

func _on_body_exited(body: Node) -> void:
	if body.has_method("set_in_lava"):
		body.set_in_lava(false)

func _apply_lava_shader() -> void:
	var target_mesh: MeshInstance3D = _find_mesh_instance(self)

	if target_mesh == null and get_parent() != null:
		target_mesh = _find_mesh_instance(get_parent())

	if target_mesh != null and lava_shader != null:
		if target_mesh.material_override is ShaderMaterial and (target_mesh.material_override as ShaderMaterial).shader == lava_shader:
			return
		var mat := ShaderMaterial.new()
		mat.shader = lava_shader
		if lava_texture_png != null:
			mat.set_shader_parameter("lava_texture", lava_texture_png)
		target_mesh.material_override = mat

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null
