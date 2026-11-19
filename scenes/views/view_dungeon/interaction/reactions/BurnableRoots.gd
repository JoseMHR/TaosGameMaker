# BurnableRoots.gd
# ─────────────────────────────────────────────────────────────────────────────
# REACCIÓN: RAÍCES QUEMABLES POR FUEGO CON PROPAGACIÓN Y RESCOLDO EN EL SUELO
#
# Obstáculo sólido que bloquea una casilla de mazmorra. Al recibir fuego:
#   1. Desactiva las formas de colisión para liberar el paso (sin desactivar
#      el process_mode del nodo, para que los tweens sigan funcionando).
#   2. Pasa al estado de ardor vivo (mallas amarillas/naranjas incandescentes).
#   3. Propaga el fuego a las casillas de raíces contiguas en cadena (0.25s).
#   4. Tras 1s de ardor, encoge las raíces verticalmente hasta desaparecer y
#      deja una mancha plana negra de ceniza/rescoldo (AshMark).
# ─────────────────────────────────────────────────────────────────────────────
class_name ReactionBurnableRoots
extends SkillReaction

## Elemento necesario para quemar (por defecto "fuego").
@export var accepted_element: String = "fuego"
## Evento global opcional emitido al quemarse.
@export var activate_event: String = ""

var _burned: bool = false


func _init() -> void:
	if verbs.is_empty():
		verbs = PackedStringArray(["element"])


func apply(host: Node3D, ctx: Dictionary) -> bool:
	if _burned:
		return false
	var element := String(ctx.get("element", ""))
	if element == "":
		var full := String(ctx.get("verb", ""))
		var i := full.find(":")
		if i >= 0:
			element = full.substr(i + 1)
	if element != accepted_element:
		return false

	_burned = true
	_consume_element(ctx)

	# 1. Desactivar SOLO las formas de colisión (no process_mode, que mataría los tweens)
	_disable_collision_shapes(host)

	# 2. Localizar mallas visuales
	var visual := host.get_node_or_null("RootsVisual") as Node3D
	var unlit := host.get_node_or_null("Unlit") as Node3D
	var lit := host.get_node_or_null("Lit") as Node3D
	if unlit != null:
		unlit.visible = false
	if lit != null:
		lit.visible = true

	var target_visual: Node3D = visual if visual != null else (lit if lit != null else host)

	# Teñir las mallas a amarillo incandescente
	if target_visual != null:
		for child in target_visual.get_children():
			if child is MeshInstance3D:
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(1.0, 0.8, 0.1, 1.0)
				m.emission_enabled = true
				m.emission = Color(1.0, 0.75, 0.1)
				m.emission_energy_multiplier = 4.5
				(child as MeshInstance3D).material_override = m

	# Partículas de fuego intenso
	var fire_particles := CPUParticles3D.new()
	fire_particles.add_to_group("elementos_temporales_mazmorra")
	fire_particles.amount = 32
	fire_particles.lifetime = 1.0
	fire_particles.one_shot = false
	fire_particles.emitting = true
	fire_particles.direction = Vector3(0, 1, 0)
	fire_particles.spread = 38.0
	fire_particles.gravity = Vector3(0, 2.5, 0)
	fire_particles.initial_velocity_min = 1.0
	fire_particles.initial_velocity_max = 2.4
	fire_particles.scale_amount_min = 0.6
	fire_particles.scale_amount_max = 1.3
	fire_particles.color = Color(1.0, 0.5, 0.1)
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.08
	p_mesh.height = 0.16
	fire_particles.mesh = p_mesh
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.albedo_color = Color(1.0, 0.5, 0.1, 0.9)
	p_mat.emission_enabled = true
	p_mat.emission = Color(1.0, 0.4, 0.05)
	p_mat.emission_energy_multiplier = 4.0
	fire_particles.material_override = p_mat
	fire_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire_particles.emission_box_extents = Vector3(1.1, 0.8, 1.1)
	fire_particles.position = Vector3(0, 1.0, 0)
	host.add_child(fire_particles)

	# Luz de llamarada
	var fire_light := OmniLight3D.new()
	fire_light.add_to_group("elementos_temporales_mazmorra")
	fire_light.light_color = Color(1.0, 0.6, 0.15)
	fire_light.light_energy = 5.0
	fire_light.omni_range = 6.5
	fire_light.position = Vector3(0, 1.2, 0)
	host.add_child(fire_light)

	# 3. Propagar fuego a raíces contiguas
	_propagate_fire_to_adjacent(host, element)

	# 4. DESINTEGRACIÓN: usar SceneTreeTimer en vez de tweens sobre el host
	#    para evitar que se bloquee si el host tuviera problemas de process_mode.
	var tree := host.get_tree()
	if tree == null:
		return true

	# Esperar 1 segundo de ardor vivo
	tree.create_timer(1.0).timeout.connect(func() -> void:
		if not is_instance_valid(host):
			return

		# Mostrar mancha de ceniza
		var ash := host.get_node_or_null("AshMark") as Node3D
		if ash != null:
			ash.visible = true
		else:
			_create_ash_mark(host)

		# Apagar emisión de partículas (dejarlas disiparse solas)
		if is_instance_valid(fire_particles):
			fire_particles.emitting = false

		# Animación de encogimiento y desvanecimiento (0.6s)
		var shrink_tw := host.create_tween().set_parallel(true)
		if target_visual != null and is_instance_valid(target_visual):
			shrink_tw.tween_property(target_visual, "scale", Vector3(1.0, 0.001, 1.0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if is_instance_valid(fire_light):
			shrink_tw.tween_property(fire_light, "light_energy", 0.0, 0.6)

		# Tras 0.6s más: ocultar todo lo que quede
		tree.create_timer(0.7).timeout.connect(func() -> void:
			if not is_instance_valid(host):
				return
			if target_visual != null and is_instance_valid(target_visual):
				target_visual.visible = false
			if is_instance_valid(fire_light):
				fire_light.queue_free()
			if is_instance_valid(fire_particles):
				fire_particles.queue_free()
			if activate_event != "":
				GlobalEvents.emit_event(activate_event, {"element": element, "position": host.global_position})
		)
	)

	return true


## Desactiva todas las CollisionShape3D del nodo (recursivo), liberando el paso
## sin desactivar process_mode del host (para que los tweens sigan funcionando).
func _disable_collision_shapes(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_disable_collision_shapes(child)


## Crea una mancha plana negra de ceniza/rescoldo en el suelo.
func _create_ash_mark(host: Node3D) -> Node3D:
	var ash := Node3D.new()
	ash.name = "AshMark"
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.6, 0.006, 2.6)
	mi.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.09)
	m.roughness = 0.95
	mi.material_override = m
	mi.position = Vector3(0, 0.003, 0)
	ash.add_child(mi)
	host.add_child(ash)
	return ash


## Propaga el fuego a casillas de raíces adyacentes (hasta 4.6 m de distancia).
func _propagate_fire_to_adjacent(host: Node3D, element: String) -> void:
	var tree := host.get_tree()
	if tree == null:
		return
	var my_pos := host.global_position

	tree.create_timer(0.25).timeout.connect(func() -> void:
		if not is_instance_valid(host) or tree == null:
			return
		for node in tree.get_nodes_in_group(Interactable.GROUP):
			var inter := node as Interactable
			if inter == null:
				continue
			var h := inter.host()
			if h == null or h == host or not is_instance_valid(h):
				continue
			var dx := h.global_position.x - my_pos.x
			var dz := h.global_position.z - my_pos.z
			if (dx * dx + dz * dz) <= 4.6 * 4.6:
				for child in inter.get_children():
					if child is ReactionBurnableRoots:
						var r_react := child as ReactionBurnableRoots
						if not r_react._burned:
							r_react.apply(h, {"element": element, "verb": "element:" + element})
					elif child is ReactionElementReceiver:
						var er_react := child as ReactionElementReceiver
						if not er_react._active:
							er_react.apply(h, {"element": element, "verb": "element:" + element})
	)


## Vacía el elemento almacenado del jugador tras usarlo en raíces.
func _consume_element(ctx: Dictionary) -> void:
	var source = ctx.get("source", null)
	if source != null and (source as Node).has_method("set_stored_element"):
		(source as Node).call("set_stored_element", "")
