# DungeonSmartFactory.gd
# ─────────────────────────────────────────────────────────────────────────────
# FÁBRICA DE OBJETOS INTELIGENTES DE MAZMORRA
#
# Construye por código una PIEZA DE KIT (definida en `data/dungeon_kits.json`):
# cuerpo físico + malla low-poly + un `Interactable` con sus `SkillReaction`. Es
# la ÚNICA vía por la que las mazmorras (editor) y el Laboratorio Debug crean
# Objetos Inteligentes, de modo que ambos comparten exactamente el mismo
# comportamiento y añadir una pieza nueva = añadir una entrada al catálogo.
#
# Contrato de una pieza:
#   { kit, name{es,en}, icon, archetype, shape, color, mass?, motion?, reaction }
# `archetype` decide el cuerpo y la reacción:
#   breakable | movable | pullable | anchor | switch | time |
#   element_receiver | element_source | ice_block | flame | lava_pool |
#   restore | reveal | false_solid | purify | campfire | emit_event |
#   checkpoint | bounce_pad
#
# Uso:  var node := DungeonSmartFactory.build(piece_id, cell, cell_size, wall_h)
#       node.position = center ; container.add_child(node)
# ─────────────────────────────────────────────────────────────────────────────
class_name DungeonSmartFactory
extends RefCounted


## Construye la pieza `piece_id` con overrides de la celda. Devuelve el nodo raíz
## (sin posicionar) listo para añadir al árbol, o null si el id no existe.
static func build(piece_id: String, cell: Dictionary, cell_size: float, wall_h: float, custom_mat: StandardMaterial3D = null) -> Node3D:
	var def: Dictionary = Design.kit_piece(piece_id)
	if def.is_empty():
		return null
	var archetype := String(def.get("archetype", ""))
	var shape := String(def.get("shape", "box"))
	var color := _color(cell.get("color", def.get("color", "#8a8a8a")))
	var rdef: Dictionary = (def.get("reaction", {}) as Dictionary).duplicate(true)
	_apply_cell_overrides(rdef, cell)
	var root: Node3D = null
	match archetype:
		"breakable":
			root = _build_static(shape, cell_size, wall_h, color, [_make_reaction(rdef)])
		"movable":
			root = _build_rigid(shape, cell_size, wall_h, color, float(def.get("mass", 2.0)), [_make_reaction(rdef)])
		"pullable":
			root = _build_rigid(shape, cell_size, wall_h, color, float(def.get("mass", 1.0)), [_make_reaction(rdef)])
		"anchor":
			root = _build_static(shape, cell_size, wall_h, color, [_make_reaction(rdef)])
		"switch":
			root = _build_static(shape, cell_size, wall_h, color, [_make_reaction(rdef)], true)
		"time":
			root = _build_time(shape, cell_size, wall_h, color, def.get("motion", {}), rdef)
		"auto_platform":
			root = _build_auto_platform(shape, cell_size, wall_h, color, def.get("motion", {}), cell)
		"element_receiver":
			if shape == "roots" or bool(rdef.get("consume", false)):
				root = _build_burnable_roots(cell_size, wall_h, color, rdef)
			else:
				root = _build_two_state(shape, cell_size, wall_h, color, rdef, false)
				_add_element_glyph(root, String(rdef.get("accepted_element", "fuego")), wall_h)
		"element_source":
			if shape == "water" or piece_id == "elem_water_tile":
				root = _build_water_tile(cell_size, wall_h, color, rdef, false)
			else:
				root = _build_static(shape, cell_size, wall_h, color, [_make_reaction(rdef)], true)
				_add_element_glyph(root, String(rdef.get("source_element", "fuego")), wall_h)
		"water_tile":
			var is_deep := bool(def.get("deep", rdef.get("deep", false))) or shape == "deep_water"
			root = _build_water_tile(cell_size, wall_h, color, rdef, is_deep)
		"ice_block":
			root = _build_ice_block(cell_size, wall_h, color, rdef)
		"flame":
			root = _build_flame(cell_size, wall_h, color, rdef)
		"lava_pool":
			root = _build_lava_pool(cell_size, wall_h, rdef)
		"restore":
			root = _build_two_state(shape, cell_size, wall_h, color, rdef, true)
		"reveal":
			root = _build_reveal(shape, cell_size, wall_h, color, rdef)
		"false_solid":
			root = _build_false_solid(shape, cell_size, wall_h, color, rdef, custom_mat)
		"purify":
			root = _build_purify(shape, cell_size, wall_h, color, rdef)
		"campfire":
			root = _build_campfire(shape, cell_size, wall_h, color, rdef)
		"checkpoint":
			root = _build_checkpoint(shape, cell_size, wall_h, color, rdef)
		"emit_event":
			root = _build_static(shape, cell_size, wall_h, color, [_make_reaction(rdef)], true)
		_:
			root = _build_static(shape, cell_size, wall_h, color, [_make_reaction(rdef)])
	if root != null:
		_apply_transform(root, cell)
	return root


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCTORES POR TIPO DE CUERPO
# ══════════════════════════════════════════════════════════════════════════════

## Cuerpo estático con malla + colisión + Interactable(reacciones). `emissive`
## pinta la malla con emisión (interruptores, fuentes elementales).
static func _build_static(shape: String, cs: float, wh: float, color: Color, reactions: Array, emissive: bool = false) -> Node3D:
	var body := StaticBody3D.new()
	_add_shape(body, shape, cs, wh, color, emissive)
	_add_collision(body, shape, cs, wh)
	_attach(body, reactions)
	return body


## Cuerpo rígido (movible/atraíble): malla + colisión + Interactable(reacciones).
static func _build_rigid(shape: String, cs: float, wh: float, color: Color, mass: float, reactions: Array) -> Node3D:
	var body := RigidBody3D.new()
	body.mass = mass
	_add_shape(body, shape, cs, wh, color, false)
	_add_collision(body, shape, cs, wh)
	_attach(body, reactions)
	return body


## Objeto afectado por el tiempo: cuerpo animable (rueda/se desliza) + TimeMotion
## que lo mueve según el factor de la reacción. Un Interactable con TimeAffected.
static func _build_time(shape: String, cs: float, wh: float, color: Color, motion: Dictionary, rdef: Dictionary) -> Node3D:
	var root := Node3D.new()
	var mover := AnimatableBody3D.new()
	mover.name = "Mover"
	mover.sync_to_physics = true
	root.add_child(mover)
	var amplitude := float(motion.get("amplitude", 2.0))
	# BUG (reportado en juego): una "puerta temporizada" ("gate") se abre
	# HUNDIÉNDOSE `amplitude` metros (ver TimeMotion "gate"), pero su malla/
	# colisión genéricas (pensadas para un muro FIJO) usan una altura basada en
	# `wh` casi igual a la del muro entero — con la amplitud típica del kit
	# (`data/dungeon_kits.json:time_door`, 2.2 m) nunca llega a hundirse lo
	# bastante y deja un trozo de colisión bloqueando el paso a la altura del
	# suelo SIEMPRE, aunque la Distorsión Temporal esté activa: por eso parecía
	# que la habilidad "no hacía nada". Solo para "gate", se dimensiona la
	# barrera en función de la amplitud real de ESTA pieza, no de `wh`, para
	# que SIEMPRE quede totalmente despejada al abrirse del todo.
	var gate_amp := amplitude if shape == "gate" else -1.0
	_add_shape(mover, shape, cs, wh, color, false, gate_amp)
	_add_collision(mover, shape, cs, wh, gate_amp)

	var react := _make_reaction(rdef) as ReactionTimeAffected
	_attach(root, [react])

	var tm := TimeMotion.new()
	tm.kind = String(motion.get("kind", "spin"))
	tm.axis = String(motion.get("axis", "y"))
	tm.amplitude = amplitude
	tm.speed = float(motion.get("speed", 2.0))
	tm.time_reaction = react
	root.add_child(tm)
	# El objetivo animado es el hermano "Mover" (TimeMotion lo resuelve por ruta).
	tm.target_path = tm.get_path_to(mover)
	return root


## Plataforma lanzadera SIEMPRE en marcha (sin habilidad/energía de por medio):
## una losa a nivel de suelo que va y vuelve, en bucle infinito, entre la
## casilla donde se coloca y `distance` casillas más allá en la dirección
## elegida ("horizontal" = +X / derecha, "vertical" = +Y / arriba), empezando
## siempre desde la celda de origen. El jugador puede subirse caminando desde
## una casilla de suelo contigua (AnimatableBody3D con `sync_to_physics`
## arrastra al CharacterBody3D que esté encima, igual que en `_build_time`).
## `direction`/`distance` son overrides POR CELDA (se configuran al colocar
## cada plataforma en el editor), con los valores de `motion` como respaldo.
static func _build_auto_platform(shape: String, cs: float, wh: float, color: Color, motion: Dictionary, cell: Dictionary) -> Node3D:
	var root := Node3D.new()
	var mover := AnimatableBody3D.new()
	mover.name = "Mover"
	mover.sync_to_physics = true
	root.add_child(mover)

	_add_shape(mover, shape, cs, wh, color, false)
	_add_collision(mover, shape, cs, wh)

	var direction := String(cell.get("direction", motion.get("direction", "horizontal")))
	var distance := int(cell.get("distance", motion.get("distance", 3)))
	var axis := "y" if direction == "vertical" else "x"

	var tm := TimeMotion.new()
	tm.kind = "shuttle"
	tm.axis = axis
	tm.amplitude = float(max(distance, 1)) * cs
	tm.speed = float(motion.get("speed", 1.0))
	# Sin `time_reaction`: se mueve siempre a velocidad plena, no depende de
	# ninguna habilidad/energía del jugador.
	root.add_child(tm)
	tm.target_path = tm.get_path_to(mover)
	return root


## Objeto de dos estados (element_receiver: apagado/encendido; restore: roto/
## reparado). Construye dos sub-nodos que la reacción alterna por NodePath.
static func _build_two_state(shape: String, cs: float, wh: float, color: Color, rdef: Dictionary, is_restore: bool) -> Node3D:
	var body := StaticBody3D.new()
	_add_collision(body, shape, cs, wh)

	var off := Node3D.new()
	off.name = "Broken" if is_restore else "Unlit"
	_add_shape(off, shape, cs, wh, color, false)
	if is_restore:
		off.rotation_degrees = Vector3(0, 0, 12)   # roto: inclinado
		off.scale = Vector3(1, 0.5, 1)
	body.add_child(off)

	var on := Node3D.new()
	on.name = "Fixed" if is_restore else "Lit"
	on.visible = false
	var bright := color.lightened(0.3)
	_add_shape(on, shape, cs, wh, bright, true)
	if not is_restore:
		var light := OmniLight3D.new()
		light.light_color = bright
		light.light_energy = 2.0
		light.omni_range = cs * 3.0
		light.position = Vector3(0, wh * 0.6, 0)
		on.add_child(light)
	body.add_child(on)

	var react := _make_reaction(rdef)
	if is_restore:
		(react as ReactionRestorable).broken_node = NodePath("Broken")
		(react as ReactionRestorable).fixed_node = NodePath("Fixed")
	else:
		(react as ReactionElementReceiver).inactive_node = NodePath("Unlit")
		(react as ReactionElementReceiver).active_node = NodePath("Lit")
	_attach(body, [react])
	return body


## Objeto oculto que revela el Instinto del Explorador. Empieza invisible.
static func _build_reveal(shape: String, cs: float, wh: float, color: Color, rdef: Dictionary) -> Node3D:
	var body := StaticBody3D.new()
	_add_shape(body, shape, cs, wh, color, true)
	# Sin colisión: es un secreto visual (no bloquea al jugador al revelarse).
	var react := _make_reaction(rdef)
	(react as ReactionRevealable).start_hidden = true
	_attach(body, [react])
	body.visible = false
	return body


## Pared/suelo FALSO: parece geometría sólida idéntica al resto de la mazmorra
## pero NO tiene colisión (se atraviesa / se cae al pisar). El Instinto del Explorador
## lo delata haciéndolo BRILLAR en morado durante unos segundos.
static func _build_false_solid(shape: String, cs: float, wh: float, color: Color, rdef: Dictionary, custom_mat: StandardMaterial3D = null) -> Node3D:
	var root := Node3D.new()
	var mat: StandardMaterial3D = custom_mat if custom_mat != null else _dungeon_surface_material(shape)
	if shape == "platform" or shape == "floor":
		# Losa de suelo falso: idéntica en malla (cs, 1.0, cs) y material al suelo normal
		var mi := _box(Vector3(cs, 1.0, cs), mat, Vector3(0, -0.5, 0))
		root.add_child(mi)
	elif shape == "wall" or shape == "arch":
		# Bloque de pared falsa: idéntica en malla (cs, wh, cs) y material a la pared normal
		var mi := _box(Vector3(cs, wh, cs), mat, Vector3(0, wh * 0.5, 0))
		root.add_child(mi)
	else:
		_add_shape(root, shape, cs, wh, color, false)

	_attach(root, [_make_reaction(rdef)])
	return root


static var _s_water_shader: Shader = null
static var _s_water_tex: Texture2D = null
static var _s_water_mat_normal: ShaderMaterial = null
static var _s_water_mat_deep: ShaderMaterial = null

static func _get_water_shader_mat(is_deep: bool = false) -> Material:
	const WATER_SHADER_PATH := "res://scenes/views/view_dungeon/components/dungeon_water.gdshader"
	const WATER_TEX_PATH := "res://assets/dungeon/textures/tile_water_clean.png"

	if is_deep and _s_water_mat_deep != null:
		return _s_water_mat_deep
	if not is_deep and _s_water_mat_normal != null:
		return _s_water_mat_normal

	if _s_water_shader == null and ResourceLoader.exists(WATER_SHADER_PATH):
		_s_water_shader = load(WATER_SHADER_PATH) as Shader
	if _s_water_tex == null and ResourceLoader.exists(WATER_TEX_PATH):
		_s_water_tex = load(WATER_TEX_PATH) as Texture2D

	if _s_water_shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = _s_water_shader
		if _s_water_tex != null:
			sm.set_shader_parameter("water_texture", _s_water_tex)
		if is_deep:
			# Agua profunda: 100% opaca, usando la misma textura pero oscurecida a azul abisal profundo
			sm.set_shader_parameter("tint", Vector3(0.12, 0.18, 0.38))
			sm.set_shader_parameter("caustic_energy", 0.15)
			sm.set_shader_parameter("caustic_pulse", 0.10)
			sm.set_shader_parameter("caustic_color", Vector3(0.08, 0.20, 0.45))
			_s_water_mat_deep = sm
		else:
			_s_water_mat_normal = sm
		return sm

	var std := StandardMaterial3D.new()
	if is_deep:
		std.albedo_color = Color(0.03, 0.07, 0.18, 1.0) # 100% opaco
		std.roughness = 0.15
		std.metallic = 0.1
	else:
		std.albedo_color = Color(0.1, 0.35, 0.75, 0.5)
		std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std.roughness = 0.15
		std.metallic = 0.1
	return std


static func _add_water_ambience(parent: Node3D, cs: float, is_deep: bool = false) -> void:
	var w_light := OmniLight3D.new()
	w_light.light_color = Color(0.10, 0.22, 0.55) if is_deep else Color(0.35, 0.82, 1.0)
	w_light.light_energy = 0.35 if is_deep else 0.8
	w_light.omni_range = cs * 1.4
	w_light.omni_attenuation = 1.6
	w_light.position = Vector3(0, 0.15, 0)
	parent.add_child(w_light)

	var w_particles := CPUParticles3D.new()
	w_particles.amount = 4 if is_deep else 8
	w_particles.lifetime = 2.0
	w_particles.emitting = true
	w_particles.direction = Vector3(0, 1, 0)
	w_particles.spread = 15.0
	w_particles.gravity = Vector3(0, 0.25, 0)
	w_particles.initial_velocity_min = 0.1
	w_particles.initial_velocity_max = 0.3
	w_particles.scale_amount_min = 0.3
	w_particles.scale_amount_max = 0.7
	var wp_mesh := SphereMesh.new()
	wp_mesh.radius = 0.03
	wp_mesh.height = 0.06
	w_particles.mesh = wp_mesh
	var wp_mat := StandardMaterial3D.new()
	wp_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	wp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wp_mat.albedo_color = Color(0.15, 0.35, 0.70, 0.5) if is_deep else Color(0.6, 0.9, 1.0, 0.7)
	w_particles.material_override = wp_mat
	w_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	w_particles.emission_box_extents = Vector3(cs * 0.42, 0.05, cs * 0.42)
	w_particles.position = Vector3(0, 0.05, 0)
	parent.add_child(w_particles)


## Casilla contaminada que purifica el sacerdote. Dos estados: "Polluted" (visible,
## agua verde envenenada con partículas y daño) y "Clean" (oculto hasta limpiar,
## que se convierte en agua azul normal ralentizante o suelo limpio).
static func _build_purify(_shape: String, cs: float, _wh: float, color: Color, rdef: Dictionary) -> Node3D:
	var root := Node3D.new()
	var depth := 0.18

	# --- ESTADO CONTAMINADO (Polluted) ---
	var polluted := Node3D.new()
	polluted.name = "Polluted"

	# Losa de suelo hundida CON colisión física para soportar al jugador dentro del pozo de veneno
	var polluted_slab_body := StaticBody3D.new()
	polluted_slab_body.position = Vector3(0, -(0.5 + depth), 0)
	var polluted_slab_mi := _box(Vector3(cs, 1.0, cs), _mat(Color(0.18, 0.20, 0.16), false), Vector3.ZERO)
	polluted_slab_body.add_child(polluted_slab_mi)
	var polluted_slab_col := CollisionShape3D.new()
	var polluted_slab_shape := BoxShape3D.new()
	polluted_slab_shape.size = Vector3(cs, 1.0, cs)
	polluted_slab_col.shape = polluted_slab_shape
	polluted_slab_body.add_child(polluted_slab_col)
	polluted.add_child(polluted_slab_body)

	const POISON_SHADER_PATH := "res://scenes/views/view_dungeon/components/dungeon_poison.gdshader"
	const POISON_TEX_PATH := "res://assets/dungeon/textures/tile_poison_liquid.png"

	var poison_mat: Material = null
	if ResourceLoader.exists(POISON_SHADER_PATH):
		var sm := ShaderMaterial.new()
		sm.shader = load(POISON_SHADER_PATH) as Shader
		if ResourceLoader.exists(POISON_TEX_PATH):
			sm.set_shader_parameter("poison_texture", load(POISON_TEX_PATH) as Texture2D)
		poison_mat = sm
	else:
		var std := StandardMaterial3D.new()
		std.albedo_color = Color(0.18, 0.75, 0.22, 0.60)
		std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		std.roughness = 0.15
		std.emission_enabled = true
		std.emission = Color(0.12, 0.60, 0.18)
		std.emission_energy_multiplier = 1.3
		poison_mat = std

	var poison_plane := _box(Vector3(cs, depth, cs), poison_mat, Vector3(0, depth * 0.5 - 0.1, 0))
	polluted.add_child(poison_plane)

	# Luz ambiental tóxica que respira suavemente iluminando paredes contiguas
	var p_light := OmniLight3D.new()
	p_light.light_color = Color(0.25, 0.95, 0.35)
	p_light.light_energy = 0.95
	p_light.omni_range = cs * 1.4
	p_light.omni_attenuation = 1.6
	p_light.position = Vector3(0, 0.15, 0)
	polluted.add_child(p_light)

	# Partículas de burbujas de veneno y motas de vapor ácido flotante
	var particles := CPUParticles3D.new()
	particles.amount = 16
	particles.lifetime = 1.8
	particles.emitting = true
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 22.0
	particles.gravity = Vector3(0, 0.45, 0)
	particles.initial_velocity_min = 0.18
	particles.initial_velocity_max = 0.45
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	particles.color = Color(0.35, 1.0, 0.4, 0.75)
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.04
	p_mesh.height = 0.08
	particles.mesh = p_mesh
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.albedo_color = Color(0.35, 1.0, 0.4, 0.7)
	particles.material_override = p_mat
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(cs * 0.42, 0.05, cs * 0.42)
	particles.position = Vector3(0, 0.05, 0)
	polluted.add_child(particles)

	# Área de peligro de veneno (ralentiza como agua + daño de veneno)
	var p_area := Area3D.new()
	p_area.collision_mask = 2
	p_area.position = Vector3(0, 0.75, 0)
	var script_path := "res://scenes/views/view_dungeon/components/DungeonPoisonWaterZone.gd"
	if ResourceLoader.exists(script_path):
		p_area.set_script(load(script_path))
	polluted.add_child(p_area)
	var p_col := CollisionShape3D.new()
	var p_shape := BoxShape3D.new()
	p_shape.size = Vector3(cs, 1.5, cs)
	p_col.shape = p_shape
	p_area.add_child(p_col)

	root.add_child(polluted)

	# --- ESTADO LIMPIO (Clean) ---
	var clean := Node3D.new()
	clean.name = "Clean"
	clean.visible = false

	var clean_type := String(rdef.get("clean", "water"))
	if clean_type == "water":
		var clean_slab_body := StaticBody3D.new()
		clean_slab_body.position = Vector3(0, -(0.5 + depth), 0)
		var clean_slab_mi := _box(Vector3(cs, 1.0, cs), _mat(Color(0.22, 0.24, 0.28), false), Vector3.ZERO)
		clean_slab_body.add_child(clean_slab_mi)
		var clean_slab_col := CollisionShape3D.new()
		var clean_slab_shape := BoxShape3D.new()
		clean_slab_shape.size = Vector3(cs, 1.0, cs)
		clean_slab_col.shape = clean_slab_shape
		clean_slab_body.add_child(clean_slab_col)
		clean.add_child(clean_slab_body)
		var water_mat: Material = _get_water_shader_mat(false)
		var water_plane := _box(Vector3(cs, depth, cs), water_mat, Vector3(0, depth * 0.5 - 0.1, 0))
		clean.add_child(water_plane)
		_add_water_ambience(clean, cs, false)

		var w_area := Area3D.new()
		w_area.collision_mask = 2
		w_area.position = Vector3(0, 0.75, 0)
		var w_script := "res://scenes/views/view_dungeon/components/DungeonWaterZone.gd"
		if ResourceLoader.exists(w_script):
			w_area.set_script(load(w_script))
		clean.add_child(w_area)
		var w_col := CollisionShape3D.new()
		var w_shape := BoxShape3D.new()
		w_shape.size = Vector3(cs, 1.5, cs)
		w_col.shape = w_shape
		w_area.add_child(w_col)
	else:
		var f_body := StaticBody3D.new()
		f_body.position = Vector3(0, -0.5, 0)
		var f_mi := _box(Vector3(cs, 1.0, cs), _dungeon_surface_material("floor"), Vector3.ZERO)
		f_body.add_child(f_mi)
		var f_col := CollisionShape3D.new()
		var f_shape := BoxShape3D.new()
		f_shape.size = Vector3(cs, 1.0, cs)
		f_col.shape = f_shape
		f_body.add_child(f_col)
		clean.add_child(f_body)

	root.add_child(clean)

	var react := _make_reaction(rdef) as ReactionPurify
	react.polluted_node = NodePath("Polluted")
	react.clean_node = NodePath("Clean")
	_attach(root, [react])
	return root


const REACTION_ICE_MELT := preload("res://scenes/views/view_dungeon/interaction/reactions/IceMelt.gd")
const REACTION_FLAME := preload("res://scenes/views/view_dungeon/interaction/reactions/Flame.gd")
const REACTION_WATER_TILE := preload("res://scenes/views/view_dungeon/interaction/reactions/ReactionWaterTile.gd")
const REACTION_LAVA_POOL := preload("res://scenes/views/view_dungeon/interaction/reactions/LavaPool.gd")


## Casilla de agua y Casilla de agua profunda:
## - Normal: losa hundida a -0.18m, lámina de agua traslúcida y ralentización (DungeonWaterZone.gd).
##   Tocar con manos vacías da agua; tocar con hielo congela en hielo resbaladizo (DungeonIceZone.gd).
## - Profunda: sin losa de física (caes al vacío). Tonalidad más oscura.
##   Tocar con hielo congela y activa losa física sólida para permitir cruzar patinando sobre el abismo.
static func _build_water_tile(cs: float, _wh: float, _color: Color, rdef: Dictionary, is_deep: bool) -> Node3D:
	var body := StaticBody3D.new()
	var depth := 0.18

	# ESTADO AGUA (WaterVis)
	var water_vis := Node3D.new()
	water_vis.name = "WaterVis"

	if not is_deep:
		# Losa de suelo hundida con colisión física (idéntica a _build_purify Clean state)
		var sunken_slab_mi := _box(Vector3(cs, 1.0, cs), _mat(Color(0.22, 0.24, 0.28), false), Vector3(0, -(0.5 + depth), 0))
		water_vis.add_child(sunken_slab_mi)
		var sunken_slab_col := CollisionShape3D.new()
		var sunken_slab_shape := BoxShape3D.new()
		sunken_slab_shape.size = Vector3(cs, 1.0, cs)
		sunken_slab_col.shape = sunken_slab_shape
		sunken_slab_col.position = Vector3(0, -(0.5 + depth), 0)
		body.add_child(sunken_slab_col)

	var water_mat: Material = _get_water_shader_mat(is_deep)
	var water_plane := _box(Vector3(cs, depth, cs), water_mat, Vector3(0, depth * 0.5 - 0.1, 0))
	water_vis.add_child(water_plane)
	_add_water_ambience(water_vis, cs, is_deep)
	body.add_child(water_vis)

	# Área de agua ralentizante (DungeonWaterZone.gd)
	var w_area := Area3D.new()
	w_area.name = "WaterArea"
	w_area.collision_mask = 2
	w_area.position = Vector3(0, 0.75, 0)
	var w_script := "res://scenes/views/view_dungeon/components/DungeonWaterZone.gd"
	if ResourceLoader.exists(w_script):
		w_area.set_script(load(w_script))
	var w_col := CollisionShape3D.new()
	var w_shape := BoxShape3D.new()
	w_shape.size = Vector3(cs, 1.5, cs)
	w_col.shape = w_shape
	w_area.add_child(w_col)
	body.add_child(w_area)

	# ESTADO HIELO (IceVis)
	var ice_vis := Node3D.new()
	ice_vis.name = "IceVis"
	ice_vis.visible = false

	var ice_mat := StandardMaterial3D.new()
	ice_mat.albedo_color = Color(0.75, 0.92, 1.0, 0.75)
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_mat.roughness = 0.05
	ice_mat.metallic = 0.2

	var ice_plane := _box(Vector3(cs, 0.05, cs), ice_mat, Vector3(0, 0.03, 0))
	ice_vis.add_child(ice_plane)
	body.add_child(ice_vis)

	# Colisión sólida de hielo a nivel del suelo (activa solo al congelar)
	var ice_solid_col := CollisionShape3D.new()
	ice_solid_col.name = "IceSolidCol"
	var ice_solid_shape := BoxShape3D.new()
	ice_solid_shape.size = Vector3(cs, 1.0, cs)
	ice_solid_col.shape = ice_solid_shape
	ice_solid_col.position = Vector3(0, -0.5, 0)
	ice_solid_col.disabled = true
	body.add_child(ice_solid_col)

	# Área de hielo resbaladizo (DungeonIceZone.gd)
	var i_area := Area3D.new()
	i_area.name = "IceArea"
	i_area.collision_mask = 2
	i_area.position = Vector3(0, 0.4, 0)
	i_area.monitoring = false
	i_area.monitorable = false
	var i_script := "res://scenes/views/view_dungeon/components/DungeonIceZone.gd"
	if ResourceLoader.exists(i_script):
		i_area.set_script(load(i_script))
	var i_col := CollisionShape3D.new()
	var i_shape := BoxShape3D.new()
	i_shape.size = Vector3(cs, 0.8, cs)
	i_col.shape = i_shape
	i_area.add_child(i_col)
	body.add_child(i_area)

	var react := REACTION_WATER_TILE.new()
	react.is_deep = is_deep
	react.frozen = false
	react.water_node = NodePath("WaterVis")
	react.ice_node = NodePath("IceVis")
	react.water_hazard_node = NodePath("WaterArea")
	react.ice_hazard_node = NodePath("IceArea")
	react.ice_collision_node = NodePath("IceSolidCol")
	react.proximity = bool(rdef.get("proximity", true))
	react.activate_event = String(rdef.get("activate_event", ""))
	_attach(body, [react])
	return body


## Bloque de hielo: obstáculo sólido que ofrece hielo con las manos vacías.
## Al recibir fuego, se derrite convirtiéndose en una auténtica Casilla de agua
## con su ciclo completo (se puede coger agua o volver a congelar en hielo resbaladizo).
static func _build_ice_block(cs: float, wh: float, color: Color, rdef: Dictionary) -> Node3D:
	var body := StaticBody3D.new()

	# Estado SÓLIDO (hielo)
	var solid := Node3D.new()
	solid.name = "Solid"
	_add_shape(solid, "ice", cs, wh, color, false)
	body.add_child(solid)

	var solid_col := CollisionShape3D.new()
	var solid_shape := BoxShape3D.new()
	solid_shape.size = Vector3(cs * 0.55, cs * 0.55, cs * 0.55)
	solid_col.shape = solid_shape
	solid_col.position = Vector3(0, cs * 0.3, 0)
	body.add_child(solid_col)

	# Estado DERRETIDO (Casilla de agua completa)
	var melted := Node3D.new()
	melted.name = "Melted"
	melted.visible = false

	var water_vis := Node3D.new()
	water_vis.name = "WaterVis"
	var water_mat: Material = _get_water_shader_mat(false)
	water_vis.add_child(_box(Vector3(cs * 0.95, 0.08, cs * 0.95), water_mat, Vector3(0, 0.04, 0)))
	_add_water_ambience(water_vis, cs, false)
	melted.add_child(water_vis)

	var ice_vis := Node3D.new()
	ice_vis.name = "IceVis"
	ice_vis.visible = false
	var ice_mat := StandardMaterial3D.new()
	ice_mat.albedo_color = Color(0.75, 0.92, 1.0, 0.75)
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_mat.roughness = 0.05
	ice_mat.metallic = 0.2
	ice_vis.add_child(_box(Vector3(cs * 0.95, 0.06, cs * 0.95), ice_mat, Vector3(0, 0.03, 0)))
	melted.add_child(ice_vis)

	var w_area := Area3D.new()
	w_area.name = "WaterArea"
	w_area.collision_mask = 2
	w_area.position = Vector3(0, 0.75, 0)
	var w_script := "res://scenes/views/view_dungeon/components/DungeonWaterZone.gd"
	if ResourceLoader.exists(w_script):
		w_area.set_script(load(w_script))
	var w_col := CollisionShape3D.new()
	var w_shape := BoxShape3D.new()
	w_shape.size = Vector3(cs, 1.5, cs)
	w_col.shape = w_shape
	w_area.add_child(w_col)
	melted.add_child(w_area)

	var i_area := Area3D.new()
	i_area.name = "IceArea"
	i_area.collision_mask = 2
	i_area.position = Vector3(0, 0.4, 0)
	i_area.monitoring = false
	i_area.monitorable = false
	var i_script := "res://scenes/views/view_dungeon/components/DungeonIceZone.gd"
	if ResourceLoader.exists(i_script):
		i_area.set_script(load(i_script))
	var i_col := CollisionShape3D.new()
	var i_shape := BoxShape3D.new()
	i_shape.size = Vector3(cs, 0.8, cs)
	i_col.shape = i_shape
	i_area.add_child(i_col)
	melted.add_child(i_area)

	body.add_child(melted)

	# Fuente de hielo del bloque sólido (manos vacías)
	var ice_source := _make_reaction(rdef) as ReactionElementSource
	ice_source.name = "IceSource"

	# Reacción de agua para cuando esté derretido
	var water_tile_react := REACTION_WATER_TILE.new()
	water_tile_react.name = "WaterTileReact"
	water_tile_react.is_deep = false
	water_tile_react.frozen = false
	water_tile_react.water_node = NodePath("Melted/WaterVis")
	water_tile_react.ice_node = NodePath("Melted/IceVis")
	water_tile_react.water_hazard_node = NodePath("Melted/WaterArea")
	water_tile_react.ice_hazard_node = NodePath("Melted/IceArea")
	water_tile_react.proximity = true
	water_tile_react.enabled = false

	# Reacción de fusión con fuego
	var melt_react = REACTION_ICE_MELT.new()
	melt_react.melt_element = String(rdef.get("melt_element", "fuego"))
	melt_react.solid_node = NodePath("Solid")
	melt_react.melted_node = NodePath("Melted")
	melt_react.activate_event = String(rdef.get("activate_event", ""))
	melt_react.ice_source_ref = ice_source
	melt_react.water_source_ref = water_tile_react
	melt_react.solid_collision = solid_col

	_attach(body, [melt_react, ice_source, water_tile_react])
	_add_element_glyph(body, String(rdef.get("source_element", "hielo")), wh)
	return body


## Llama viva: como la hoguera pero sin maderas ni piedras debajo (con marca de hollín).
## Con manos vacías da fuego. Con agua se apaga permanentemente dejando ceniza.
static func _build_flame(cs: float, _wh: float, _col: Color, rdef: Dictionary) -> Node3D:
	var body := StaticBody3D.new()

	var lit := Node3D.new()
	lit.name = "Lit"

	# Marca de suelo chamuscado/hollín bajo la llama (sin madera ni piedras)
	var soot_mat := StandardMaterial3D.new()
	soot_mat.albedo_color = Color(0.08, 0.08, 0.09)
	soot_mat.roughness = 0.95
	var soot := _cyl(cs * 0.22, cs * 0.22, 0.01, soot_mat, Vector3(0, 0.005, 0))
	lit.add_child(soot)

	# Núcleo de brasa resplandeciente en el centro del suelo
	var ember_mat := _mat(Color(1.0, 0.45, 0.05), true)
	ember_mat.emission_energy_multiplier = 3.5
	var ember := _sphere(cs * 0.06, ember_mat, Vector3(0, cs * 0.05, 0))
	lit.add_child(ember)

	# Partículas de llama viva de gran riqueza visual (CPUParticles3D)
	var fire_particles := CPUParticles3D.new()
	fire_particles.amount = 22
	fire_particles.lifetime = 0.75
	fire_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire_particles.emission_sphere_radius = cs * 0.055
	fire_particles.direction = Vector3(0, 1, 0)
	fire_particles.spread = 16.0
	fire_particles.gravity = Vector3(0, cs * 0.8, 0)
	fire_particles.initial_velocity_min = cs * 0.25
	fire_particles.initial_velocity_max = cs * 0.55
	fire_particles.scale_amount_min = cs * 0.06
	fire_particles.scale_amount_max = cs * 0.14
	var p_mesh := QuadMesh.new()
	p_mesh.size = Vector2(cs * 0.13, cs * 0.13)
	var p_mat := StandardMaterial3D.new()
	p_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_color = Color(1.0, 0.7, 0.18, 0.95)
	p_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	p_mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	p_mesh.material = p_mat
	fire_particles.mesh = p_mesh
	var p_grad := Gradient.new()
	p_grad.set_color(0, Color(1.0, 0.95, 0.5, 1.0))
	p_grad.add_point(0.4, Color(1.0, 0.48, 0.08, 0.9))
	p_grad.add_point(0.75, Color(0.85, 0.14, 0.02, 0.5))
	p_grad.set_color(1, Color(0.3, 0.05, 0.01, 0.0))
	fire_particles.color_ramp = p_grad
	fire_particles.position = Vector3(0, cs * 0.06, 0)
	lit.add_child(fire_particles)

	# Chispas flotantes que suben desde la llama
	var sparks := CPUParticles3D.new()
	sparks.amount = 12
	sparks.lifetime = 1.1
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = cs * 0.06
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 26.0
	sparks.gravity = Vector3(0, cs * 0.65, 0)
	sparks.initial_velocity_min = cs * 0.35
	sparks.initial_velocity_max = cs * 0.8
	var sp_mesh := QuadMesh.new()
	sp_mesh.size = Vector2(cs * 0.025, cs * 0.025)
	var sp_mat := StandardMaterial3D.new()
	sp_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	sp_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	sp_mat.vertex_color_use_as_albedo = true
	sp_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	sp_mesh.material = sp_mat
	sparks.mesh = sp_mesh
	var sp_grad := Gradient.new()
	sp_grad.set_color(0, Color(1.0, 0.95, 0.4, 1.0))
	sp_grad.add_point(0.6, Color(1.0, 0.5, 0.1, 0.8))
	sp_grad.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
	sparks.color_ramp = sp_grad
	sparks.position = Vector3(0, cs * 0.08, 0)
	lit.add_child(sparks)

	# Luz cálida viva parpadeante
	var light := FireLightFlicker3D.new()
	light.light_color = Color(1.0, 0.58, 0.18)
	light.light_energy = 2.4
	light.omni_range = cs * 3.5
	light.position = Vector3(0, cs * 0.25, 0)
	lit.add_child(light)

	body.add_child(lit)

	# Marca de ceniza tras apagarse
	var ash := MeshInstance3D.new()
	ash.name = "Ash"
	ash.visible = false
	var ash_cyl := CylinderMesh.new()
	ash_cyl.top_radius = cs * 0.24
	ash_cyl.bottom_radius = cs * 0.26
	ash_cyl.height = 0.01
	ash.mesh = ash_cyl
	ash.material_override = soot_mat
	ash.position = Vector3(0, 0.005, 0)
	body.add_child(ash)

	# Bloqueo físico mientras la llama está encendida: impide atravesar la casilla
	var blocker_col := CollisionShape3D.new()
	blocker_col.name = "BlockerCol"
	var blocker_shape := BoxShape3D.new()
	blocker_shape.size = Vector3(cs * 0.88, 1.5, cs * 0.88)
	blocker_col.shape = blocker_shape
	blocker_col.position = Vector3(0, 0.75, 0)
	body.add_child(blocker_col)

	# Área de peligro: daña y repele hacia atrás si se toca mientras arde (mismo efecto que pinchos)
	var hazard := Area3D.new()
	hazard.name = "Hazard"
	hazard.collision_mask = 2
	hazard.position = Vector3(0, 0.5, 0)
	var hazard_script := "res://scenes/views/view_dungeon/components/DungeonFlameZone.gd"
	if ResourceLoader.exists(hazard_script):
		hazard.set_script(load(hazard_script))
	var hazard_col := CollisionShape3D.new()
	var hazard_shape := BoxShape3D.new()
	hazard_shape.size = Vector3(cs * 0.96, 1.2, cs * 0.96)
	hazard_col.shape = hazard_shape
	hazard.add_child(hazard_col)
	body.add_child(hazard)

	var react = REACTION_FLAME.new()
	react.fire_element = String(rdef.get("source_element", "fuego"))
	react.quench_element = String(rdef.get("quench_element", "agua"))
	react.lit_node = NodePath("Lit")
	react.ash_node = NodePath("Ash")
	react.hazard_node = NodePath("Hazard")
	react.blocker_node = NodePath("BlockerCol")
	react.proximity = bool(rdef.get("proximity", true))
	react.activate_event = String(rdef.get("activate_event", ""))
	_attach(body, [react])
	return body


## Charca de lava viva: usa la textura del mapamundi (res://assets/world/map/tile_lava.png),
## pulso dinámico de brillo para que parezca lava fundida viva, ascuas flotantes y fragmentos
## de corteza de obsidiana. Se apaga con agua convirtiéndose en losa de roca transitable.
static func _build_lava_pool(cs: float, _wh: float, rdef: Dictionary) -> Node3D:
	var body := Node3D.new()

	var lava := Node3D.new()
	lava.name = "Lava"
	var lava_slab := StaticBody3D.new()
	lava_slab.position = Vector3(0, -0.5, 0)

	var lava_mat: Material = null
	const LAVA_SHADER_PATH := "res://scenes/views/view_dungeon/components/dungeon_lava.gdshader"
	const LAVA_TEX_PATH := "res://assets/world/map/tile_lava.png"
	if ResourceLoader.exists(LAVA_SHADER_PATH):
		var sm := ShaderMaterial.new()
		sm.shader = load(LAVA_SHADER_PATH) as Shader
		if ResourceLoader.exists(LAVA_TEX_PATH):
			sm.set_shader_parameter("lava_texture", load(LAVA_TEX_PATH) as Texture2D)
		lava_mat = sm
	else:
		var std := StandardMaterial3D.new()
		if ResourceLoader.exists(LAVA_TEX_PATH):
			var tex = load(LAVA_TEX_PATH)
			std.albedo_texture = tex
			std.emission_texture = tex
		std.emission_enabled = true
		std.emission = Color(1.0, 0.42, 0.08)
		lava_mat = std

	lava_slab.add_child(_box(Vector3(cs, 1.0, cs), lava_mat, Vector3.ZERO))
	var lava_col := CollisionShape3D.new()
	var lava_shape := BoxShape3D.new()
	lava_shape.size = Vector3(cs, 1.0, cs)
	lava_col.shape = lava_shape
	lava_slab.add_child(lava_col)
	lava.add_child(lava_slab)

	# Partículas de burbujas incandescentes / ascuas de magma ascendentes
	var magma_particles := CPUParticles3D.new()
	magma_particles.amount = 16
	magma_particles.lifetime = 1.3
	magma_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	magma_particles.emission_box_extents = Vector3(cs * 0.4, 0.02, cs * 0.4)
	magma_particles.direction = Vector3(0, 1, 0)
	magma_particles.spread = 15.0
	magma_particles.gravity = Vector3(0, cs * 0.3, 0)
	magma_particles.initial_velocity_min = cs * 0.1
	magma_particles.initial_velocity_max = cs * 0.35
	magma_particles.scale_amount_min = cs * 0.035
	magma_particles.scale_amount_max = cs * 0.085
	var m_mesh := QuadMesh.new()
	m_mesh.size = Vector2(cs * 0.08, cs * 0.08)
	var m_mat := StandardMaterial3D.new()
	m_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	m_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	m_mat.vertex_color_use_as_albedo = true
	m_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	m_mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	m_mesh.material = m_mat
	magma_particles.mesh = m_mesh
	var m_grad := Gradient.new()
	m_grad.set_color(0, Color(1.0, 0.9, 0.3, 1.0))
	m_grad.add_point(0.5, Color(1.0, 0.42, 0.06, 0.85))
	m_grad.set_color(1, Color(0.7, 0.1, 0.0, 0.0))
	magma_particles.color_ramp = m_grad
	magma_particles.position = Vector3(0, 0.02, 0)
	lava.add_child(magma_particles)

	# Luz cálida parpadeante
	var light := FireLightFlicker3D.new()
	light.light_color = Color(1.0, 0.45, 0.12)
	light.light_energy = 2.4
	light.omni_range = cs * 3.5
	light.position = Vector3(0, cs * 0.3, 0)
	lava.add_child(light)
	body.add_child(lava)

	# Estado APAGADO (suelo de tierra normal). Oculto hasta recibir agua.
	var doused := Node3D.new()
	doused.name = "Doused"
	doused.visible = false
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.add_child(_box(Vector3(cs, 1.0, cs), _dungeon_surface_material("floor"), Vector3.ZERO))
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(cs, 1.0, cs)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	doused.add_child(floor_body)
	body.add_child(doused)

	# Área de peligro: daña mucho mientras hay lava
	var hazard := Area3D.new()
	hazard.name = "Hazard"
	hazard.collision_mask = 2
	hazard.position = Vector3(0, 0.5, 0)
	var hazard_script := "res://scenes/views/view_dungeon/components/DungeonLavaZone.gd"
	if ResourceLoader.exists(hazard_script):
		hazard.set_script(load(hazard_script))
	var hazard_col := CollisionShape3D.new()
	var hazard_shape := BoxShape3D.new()
	hazard_shape.size = Vector3(cs * 0.95, 1.5, cs * 0.95)
	hazard_col.shape = hazard_shape
	hazard.add_child(hazard_col)
	body.add_child(hazard)

	var react = REACTION_LAVA_POOL.new()
	react.quench_element = String(rdef.get("quench_element", "agua"))
	react.lava_node = NodePath("Lava")
	react.doused_node = NodePath("Doused")
	react.hazard_node = NodePath("Hazard")
	react.proximity = bool(rdef.get("proximity", true))
	react.activate_event = String(rdef.get("activate_event", ""))
	_attach(body, [react])
	return body


## Hoguera con estados ENCENDIDA/APAGADA que alterna la Afinidad Elemental. Construye
## la leña común más un nodo "Lit" (llama + luz) y un nodo "Unlit" (brasas frías).
static func _build_campfire(_shape: String, cs: float, wh: float, _col_val: Color, rdef: Dictionary) -> Node3D:
	var body := StaticBody3D.new()
	_add_collision(body, "barrel", cs * 0.7, wh)

	# Piedras en círculo alrededor de la leña
	var stone_mat := _mat(Color(0.42, 0.40, 0.38), false)
	stone_mat.roughness = 0.95
	var num_stones := 8
	for s_idx in range(num_stones):
		var s_ang := TAU * float(s_idx) / float(num_stones)
		var s_r := cs * 0.18
		var st := _sphere(cs * 0.045, stone_mat, Vector3(cos(s_ang) * s_r, cs * 0.03, sin(s_ang) * s_r))
		st.scale = Vector3(1.2, 0.8, 1.2)
		body.add_child(st)

	# Leña base (siempre visible).
	var logs := _mat(Color(0.28, 0.18, 0.11), false)
	logs.roughness = 0.9
	for i in range(4):
		var ang := TAU * float(i) / 4.0
		var lg := _cyl(cs * 0.035, cs * 0.035, cs * 0.32, logs, Vector3(cos(ang) * cs * 0.08, cs * 0.05, sin(ang) * cs * 0.08))
		lg.rotation_degrees = Vector3(65, rad_to_deg(ang), 0)
		body.add_child(lg)

	# Lecho de brasas
	var ember_mat := _mat(Color(0.85, 0.22, 0.05), true)
	ember_mat.emission_energy_multiplier = 2.0
	var ember_bed := _cyl(cs * 0.12, cs * 0.14, cs * 0.03, ember_mat, Vector3(0, cs * 0.02, 0))
	body.add_child(ember_bed)

	# Estado ENCENDIDO: núcleo suave + partículas de llama vivas + chispas + luz parpadeante
	var lit := Node3D.new()
	lit.name = "Lit"
	var flame := _mat(Color(1.0, 0.65, 0.1), true)
	flame.emission_energy_multiplier = 3.5
	lit.add_child(_sphere(cs * 0.07, flame, Vector3(0, cs * 0.1, 0)))

	# Partículas de llama viva de la hoguera (CPUParticles3D)
	var fire_particles := CPUParticles3D.new()
	fire_particles.amount = 20
	fire_particles.lifetime = 0.7
	fire_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire_particles.emission_sphere_radius = cs * 0.05
	fire_particles.direction = Vector3(0, 1, 0)
	fire_particles.spread = 15.0
	fire_particles.gravity = Vector3(0, cs * 0.75, 0)
	fire_particles.initial_velocity_min = cs * 0.22
	fire_particles.initial_velocity_max = cs * 0.48
	fire_particles.scale_amount_min = cs * 0.06
	fire_particles.scale_amount_max = cs * 0.13
	var p_mesh := QuadMesh.new()
	p_mesh.size = Vector2(cs * 0.12, cs * 0.12)
	var p_mat := StandardMaterial3D.new()
	p_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	p_mat.vertex_color_use_as_albedo = true
	p_mat.albedo_color = Color(1.0, 0.68, 0.16, 0.95)
	p_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	p_mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	p_mesh.material = p_mat
	fire_particles.mesh = p_mesh
	var p_grad := Gradient.new()
	p_grad.set_color(0, Color(1.0, 0.95, 0.45, 1.0))
	p_grad.add_point(0.45, Color(1.0, 0.48, 0.08, 0.9))
	p_grad.add_point(0.8, Color(0.85, 0.15, 0.02, 0.4))
	p_grad.set_color(1, Color(0.3, 0.05, 0.0, 0.0))
	fire_particles.color_ramp = p_grad
	fire_particles.position = Vector3(0, cs * 0.08, 0)
	lit.add_child(fire_particles)

	# Partículas de chispas vivas
	var sparks := CPUParticles3D.new()
	sparks.amount = 12
	sparks.lifetime = 1.1
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = cs * 0.06
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 24.0
	sparks.gravity = Vector3(0, cs * 0.65, 0)
	sparks.initial_velocity_min = cs * 0.3
	sparks.initial_velocity_max = cs * 0.75
	var sp_mesh := QuadMesh.new()
	sp_mesh.size = Vector2(cs * 0.025, cs * 0.025)
	var sp_mat := StandardMaterial3D.new()
	sp_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	sp_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	sp_mat.vertex_color_use_as_albedo = true
	sp_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	sp_mesh.material = sp_mat
	sparks.mesh = sp_mesh
	var sp_grad := Gradient.new()
	sp_grad.set_color(0, Color(1.0, 0.95, 0.4, 1.0))
	sp_grad.add_point(0.6, Color(1.0, 0.5, 0.1, 0.8))
	sp_grad.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
	sparks.color_ramp = sp_grad
	sparks.position = Vector3(0, cs * 0.1, 0)
	lit.add_child(sparks)

	# Humo sutil en la parte superior de la llama
	var smoke := CPUParticles3D.new()
	smoke.amount = 8
	smoke.lifetime = 1.2
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = cs * 0.04
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 12.0
	smoke.gravity = Vector3(0, cs * 0.35, 0)
	smoke.initial_velocity_min = cs * 0.15
	smoke.initial_velocity_max = cs * 0.3
	smoke.scale_amount_min = cs * 0.08
	smoke.scale_amount_max = cs * 0.18
	var sm_mesh := QuadMesh.new()
	sm_mesh.size = Vector2(cs * 0.1, cs * 0.1)
	var sm_mat := StandardMaterial3D.new()
	sm_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	sm_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	sm_mat.vertex_color_use_as_albedo = true
	sm_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	sm_mesh.material = sm_mat
	smoke.mesh = sm_mesh
	var sm_grad := Gradient.new()
	sm_grad.set_color(0, Color(0.25, 0.22, 0.2, 0.0))
	sm_grad.add_point(0.3, Color(0.3, 0.28, 0.26, 0.2))
	sm_grad.set_color(1, Color(0.35, 0.35, 0.35, 0.0))
	smoke.color_ramp = sm_grad
	smoke.position = Vector3(0, cs * 0.2, 0)
	lit.add_child(smoke)

	# Luz cálida parpadeante
	var light := FireLightFlicker3D.new()
	light.light_color = Color(1.0, 0.58, 0.18)
	light.light_energy = 2.2
	light.omni_range = cs * 3.5
	light.position = Vector3(0, cs * 0.25, 0)
	lit.add_child(light)
	body.add_child(lit)

	# Estado APAGADO: brasas frías oscuras.
	var unlit := Node3D.new()
	unlit.name = "Unlit"
	unlit.add_child(_cyl(cs * 0.1, cs * 0.12, cs * 0.02, _mat(Color(0.12, 0.12, 0.14), false), Vector3(0, cs * 0.02, 0)))
	body.add_child(unlit)

	# Visibilidad inicial coherente con `lit` (la fija la fábrica, no la reacción).
	var start_lit := bool(rdef.get("lit", true))
	lit.visible = start_lit
	unlit.visible = not start_lit

	var react := _make_reaction(rdef) as ReactionCampfire
	react.lit_node = NodePath("Lit")
	react.unlit_node = NodePath("Unlit")
	_attach(body, [react])
	return body


# ══════════════════════════════════════════════════════════════════════════════
# REACCIONES (def → instancia)
# ══════════════════════════════════════════════════════════════════════════════

## Aplica overrides por instancia (celda del editor) sobre la def de reacción:
##   cell.event   → evento global de la reacción (rompible/elemental/restaurable/switch)
##   cell.element → elemento aceptado/ofrecido (piezas elementales)
##   cell.verbs   → verbos que activan el interruptor
## Permite "configurar rápidamente con qué habilidades interactúa cada objeto".
static func _apply_cell_overrides(rdef: Dictionary, cell: Dictionary) -> void:
	var t := String(rdef.get("type", ""))
	var ev := String(cell.get("event", ""))
	if ev != "":
		match t:
			"breakable": rdef["break_event"] = ev
			"element": rdef["activate_event"] = ev
			"restore": rdef["restore_event"] = ev
			"switch": rdef["switch_event"] = ev
			"emit_event": rdef["event_name"] = ev
	var elem := String(cell.get("element", ""))
	if elem != "":
		if t == "element":
			rdef["accepted_element"] = elem
		elif t == "element_source":
			rdef["source_element"] = elem
	var verbs = cell.get("verbs", null)
	if verbs is Array and (t == "switch" or t == "emit_event"):
		rdef["verbs"] = verbs


static func _make_reaction(rdef: Dictionary) -> SkillReaction:
	var t := String(rdef.get("type", ""))
	match t:
		"breakable":
			var r := ReactionBreakable.new()
			r.min_strength = float(rdef.get("min_strength", 0.0))
			r.break_event = String(rdef.get("break_event", ""))
			return r
		"movable":
			var r := ReactionMovable.new()
			r.impact_force = float(rdef.get("impact_force", 14.0))
			r.pull_force = float(rdef.get("pull_force", 12.0))
			return r
		"pullable":
			var r := ReactionPullable.new()
			r.pull_force = float(rdef.get("pull_force", 12.0))
			return r
		"anchor":
			var r := ReactionAnchor.new()
			r.anchor_offset = Vector3(0, float(rdef.get("anchor_offset_y", 0.0)), 0)
			return r
		"switch":
			var r := ReactionSwitch.new()
			var vs = rdef.get("verbs", ["impact"])
			if vs is Array:
				r.verbs = PackedStringArray(vs)
			r.one_way = bool(rdef.get("one_way", false))
			r.switch_event = String(rdef.get("switch_event", "EVENT_SWITCH_TOGGLED"))
			return r
		"time":
			var r := ReactionTimeAffected.new()
			r.slow_factor = float(rdef.get("slow_factor", 0.15))
			return r
		"element":
			var r := ReactionElementReceiver.new()
			r.accepted_element = String(rdef.get("accepted_element", "fuego"))
			r.activate_event = String(rdef.get("activate_event", ""))
			return r
		"element_source":
			var r := ReactionElementSource.new()
			r.source_element = String(rdef.get("source_element", "fuego"))
			r.one_shot = bool(rdef.get("one_shot", false))
			r.proximity = bool(rdef.get("proximity", false))
			return r
		"campfire":
			var r := ReactionCampfire.new()
			r.element = String(rdef.get("element", "fuego"))
			r.lit = bool(rdef.get("lit", true))
			r.proximity = bool(rdef.get("proximity", true))
			return r
		"purify":
			var r := ReactionPurify.new()
			r.purify_event = String(rdef.get("purify_event", ""))
			r.proximity = bool(rdef.get("proximity", true))
			return r
		"false_wall":
			var r := ReactionFalseWall.new()
			r.reveal_seconds = float(rdef.get("reveal_seconds", 0.0))
			return r
		"restore":
			var r := ReactionRestorable.new()
			r.restore_event = String(rdef.get("restore_event", ""))
			r.proximity = bool(rdef.get("proximity", false))
			return r
		"reveal":
			var r := ReactionRevealable.new()
			r.reveal_seconds = float(rdef.get("reveal_seconds", 0.0))
			return r
		"emit_event":
			var r := ReactionEmitEvent.new()
			r.event_name = String(rdef.get("event_name", ""))
			var p = rdef.get("payload", {})
			if p is Dictionary:
				r.payload = p
			var vs = rdef.get("verbs", ["impact"])
			if vs is Array:
				r.verbs = PackedStringArray(vs)
			return r
	return SkillReaction.new()


## Cuelga un Interactable (con sus reacciones) bajo `body`. Las reacciones se
## añaden ANTES de insertar en el árbol (Interactable._ready las recolecta).
static func _attach(body: Node3D, reactions: Array) -> void:
	var inter := Interactable.new()
	for r in reactions:
		if r != null:
			inter.add_child(r)
	body.add_child(inter)


# ══════════════════════════════════════════════════════════════════════════════
# MALLAS Y COLISIONES POR FORMA
# ══════════════════════════════════════════════════════════════════════════════
static func _add_shape(parent: Node3D, shape: String, cs: float, wh: float, color: Color, emissive: bool, gate_amplitude: float = -1.0) -> void:
	var mat := _mat(color, emissive)
	match shape:
		"wall", "arch":
			parent.add_child(_box(Vector3(cs, wh, cs), mat, Vector3(0, wh * 0.5, 0)))
		"barrier":
			_build_breakable_barrier(parent, cs, wh, color)
		"rock":
			var n := _box(Vector3(cs * 0.55, cs * 0.5, cs * 0.55), mat, Vector3(0, cs * 0.25, 0))
			n.rotation_degrees = Vector3(0, 25, 8)
			parent.add_child(n)
		"crate", "crate_light", "caja_madera", "caja_ligera":
			var crate_node := ModelLoader.load_model("caja_madera", cs * 0.48)
			if crate_node != null:
				crate_node.position.y = 0.0
				parent.add_child(crate_node)
			else:
				parent.add_child(_box(Vector3(cs * 0.5, cs * 0.5, cs * 0.5), mat, Vector3(0, cs * 0.25, 0)))
		"caja_pesada", "caja_metal", "crate_heavy", "heavy_crate":
			var crate_node := ModelLoader.load_model("caja_pesada", cs * 0.48)
			if crate_node != null:
				crate_node.position.y = 0.0
				parent.add_child(crate_node)
			else:
				parent.add_child(_box(Vector3(cs * 0.5, cs * 0.5, cs * 0.5), mat, Vector3(0, cs * 0.25, 0)))
		"ice":
			var ice_outer_mat := StandardMaterial3D.new()
			ice_outer_mat.albedo_color = Color(0.72, 0.92, 1.0, 0.55)
			ice_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ice_outer_mat.roughness = 0.02
			ice_outer_mat.metallic = 0.25
			ice_outer_mat.clearcoat_enabled = true
			ice_outer_mat.clearcoat = 1.0
			ice_outer_mat.clearcoat_roughness = 0.05
			ice_outer_mat.emission_enabled = true
			ice_outer_mat.emission = Color(0.35, 0.70, 0.95)
			ice_outer_mat.emission_energy_multiplier = 0.18

			var ice_inner_mat := StandardMaterial3D.new()
			ice_inner_mat.albedo_color = Color(0.88, 0.97, 1.0, 0.45)
			ice_inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ice_inner_mat.roughness = 0.05
			ice_inner_mat.clearcoat_enabled = true
			ice_inner_mat.clearcoat = 1.0
			ice_inner_mat.emission_enabled = true
			ice_inner_mat.emission = Color(0.55, 0.85, 1.0)
			ice_inner_mat.emission_energy_multiplier = 0.3

			# Núcleo escarchado — girado 45° para que el bloque exterior (también
			# girado) muestre facetas romboidales en vez de un cubo plano.
			var core := _box(Vector3(cs * 0.30, cs * 0.44, cs * 0.30), ice_inner_mat, Vector3(0, cs * 0.24, 0))
			core.rotation_degrees.y = 45.0
			parent.add_child(core)

			# Racimo de esquirlas de hielo (PrismMesh) de tamaños/ángulos variados
			# alrededor del núcleo, en vez de 4 clones idénticos — silueta más
			# irregular y creíble de un bloque de hielo agrietado.
			var shard_specs := [
				{ "pos": Vector3(0, cs * 0.30, 0), "size": Vector3(cs * 0.30, cs * 0.62, cs * 0.30), "rot": Vector3(0, 20, 0) },
				{ "pos": Vector3(cs * 0.18, cs * 0.14, cs * 0.10), "size": Vector3(cs * 0.20, cs * 0.40, cs * 0.20), "rot": Vector3(-14, 60, 6) },
				{ "pos": Vector3(-cs * 0.16, cs * 0.10, -cs * 0.14), "size": Vector3(cs * 0.17, cs * 0.32, cs * 0.17), "rot": Vector3(10, -50, -8) },
				{ "pos": Vector3(-cs * 0.14, cs * 0.08, cs * 0.16), "size": Vector3(cs * 0.15, cs * 0.26, cs * 0.15), "rot": Vector3(16, 120, 4) },
				{ "pos": Vector3(cs * 0.12, cs * 0.06, -cs * 0.16), "size": Vector3(cs * 0.13, cs * 0.22, cs * 0.13), "rot": Vector3(-18, -110, 0) },
			]
			for spec in shard_specs:
				var shard := MeshInstance3D.new()
				var sm := PrismMesh.new()
				sm.size = spec["size"]
				shard.mesh = sm
				shard.material_override = ice_outer_mat
				shard.position = spec["pos"]
				shard.rotation_degrees = spec["rot"]
				parent.add_child(shard)
		"platform", "bridge":
			parent.add_child(_box(Vector3(cs * 0.9, 0.25, cs * 0.9), mat, Vector3(0, 0.12, 0)))
		"water":
			var water_mat: Material = _get_water_shader_mat(false)
			var n := _box(Vector3(cs * 0.95, 0.1, cs * 0.95), water_mat, Vector3(0, 0.05, 0))
			parent.add_child(n)
			_add_water_ambience(parent, cs, false)
		"fog":
			var n := _box(Vector3(cs * 0.9, 0.1, cs * 0.9), _mat_alpha(color, 0.5, emissive), Vector3(0, 0.05, 0))
			parent.add_child(n)
		"button":
			parent.add_child(_cyl(cs * 0.3, cs * 0.3, 0.12, mat, Vector3(0, 0.06, 0)))
		"button_high":
			parent.add_child(_box(Vector3(0.1, wh * 0.7, 0.1), _mat(color.darkened(0.3), false), Vector3(0, wh * 0.35, 0)))
			parent.add_child(_cyl(cs * 0.22, cs * 0.22, 0.12, mat, Vector3(0, wh * 0.72, 0)))
		"column", "pillar":
			_build_psychic_column(parent, cs, wh, color)
		"ring":
			_build_sonic_ring(parent, cs, wh, color)
		"key":
			parent.add_child(_cyl(cs * 0.06, cs * 0.06, cs * 0.4, mat, Vector3(0, cs * 0.4, 0)))
			parent.add_child(_box(Vector3(cs * 0.18, cs * 0.1, 0.05), mat, Vector3(cs * 0.09, cs * 0.25, 0)))
		"chest":
			parent.add_child(_box(Vector3(cs * 0.5, cs * 0.32, cs * 0.38), mat, Vector3(0, cs * 0.16, 0)))
			parent.add_child(_box(Vector3(cs * 0.53, cs * 0.14, cs * 0.41), _mat(color.lightened(0.1), false), Vector3(0, cs * 0.4, 0)))
		"statue":
			parent.add_child(_box(Vector3(cs * 0.5, cs * 0.22, cs * 0.5), mat, Vector3(0, cs * 0.11, 0)))
			parent.add_child(_box(Vector3(cs * 0.28, wh * 0.5, cs * 0.24), mat, Vector3(0, cs * 0.22 + wh * 0.25, 0)))
			parent.add_child(_sphere(cs * 0.14, mat, Vector3(0, cs * 0.22 + wh * 0.5 + cs * 0.14, 0)))
		"spikes":
			parent.add_child(_box(Vector3(cs * 0.95, 0.03, cs * 0.95), _mat(color.darkened(0.5), false), Vector3(0, 0.015, 0)))
			var off := cs * 0.28
			var offsets := [
				Vector3(0.0, cs * 0.11, 0.0),          # Centro
				Vector3(-off, cs * 0.11, -off),       # Esquina Superior Izquierda
				Vector3(off, cs * 0.11, -off),        # Esquina Superior Derecha
				Vector3(-off, cs * 0.11, off),        # Esquina Inferior Izquierda
				Vector3(off, cs * 0.11, off),         # Esquina Inferior Derecha
			]
			for pos in offsets:
				parent.add_child(_cone(0.12, cs * 0.22, mat, pos))
		"blade":
			parent.add_child(_cyl(cs * 0.1, cs * 0.1, wh * 0.5, _mat(color.darkened(0.4), false), Vector3(0, wh * 0.25, 0)))
			parent.add_child(_box(Vector3(cs * 1.3, 0.12, cs * 0.16), mat, Vector3(0, wh * 0.5, 0)))
		"mill":
			parent.add_child(_cyl(cs * 0.12, cs * 0.12, wh * 0.7, _mat(color.darkened(0.4), false), Vector3(0, wh * 0.35, 0)))
			for i in range(4):
				var b := _box(Vector3(cs * 1.1, 0.1, cs * 0.22), mat, Vector3(0, wh * 0.7, 0))
				b.rotation_degrees = Vector3(0, 45.0 * float(i), 0)
				parent.add_child(b)
		"gate":
			# Altura de las barras: si se conoce la amplitud REAL de esta puerta
			# (viene de `_build_time`, archetype "time"), se dimensionan para que
			# quepan enteras por debajo del suelo al hundirse esa amplitud (si no,
			# se usa el alto de muro `wh` de siempre, para cualquier otro uso).
			var bar_h := wh * 0.9 if gate_amplitude < 0.0 else maxf(0.4, gate_amplitude * 0.8)
			var bar_y := bar_h * 0.5
			for i in range(5):
				var xoff := -cs * 0.32 + (cs * 0.16) * float(i)
				parent.add_child(_box(Vector3(cs * 0.08, bar_h, cs * 0.08), mat, Vector3(xoff, bar_y, 0)))
		"torch":
			parent.add_child(_cyl(0.06, 0.08, wh * 0.55, _mat(Color(0.3, 0.2, 0.1), false), Vector3(0, wh * 0.4, 0)))
			parent.add_child(_sphere(0.2, mat, Vector3(0, wh * 0.7, 0)))
		"brazier":
			parent.add_child(_cyl(cs * 0.22, cs * 0.14, cs * 0.3, _mat(Color(0.3, 0.22, 0.14), false), Vector3(0, cs * 0.35, 0)))
			parent.add_child(_sphere(0.24, mat, Vector3(0, cs * 0.55, 0)))
			var l := OmniLight3D.new()
			l.light_color = color
			l.light_energy = 2.0
			l.omni_range = cs * 3.0
			l.position = Vector3(0, cs * 0.6, 0)
			parent.add_child(l)
		"roots":
			for i in range(5):
				var ang2 := TAU * float(i) / 5.0
				var r := _cyl(0.05, 0.07, wh * 0.6, mat, Vector3(cos(ang2) * cs * 0.12, wh * 0.3, sin(ang2) * cs * 0.12))
				r.rotation_degrees = Vector3(cos(ang2) * 15.0, 0, sin(ang2) * 15.0)
				parent.add_child(r)
		"crystal":
			var mi2 := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(cs * 0.4, cs * 0.8, cs * 0.4)
			mi2.mesh = pm
			mi2.material_override = _mat_alpha(color, 0.85, emissive)
			mi2.position = Vector3(0, cs * 0.4, 0)
			parent.add_child(mi2)
		"gear":
			parent.add_child(_cyl(cs * 0.3, cs * 0.3, 0.15, mat, Vector3(0, wh * 0.4, 0)))
			for i in range(8):
				var ang3 := TAU * float(i) / 8.0
				parent.add_child(_box(Vector3(0.1, 0.15, 0.1), mat, Vector3(cos(ang3) * cs * 0.32, wh * 0.4, sin(ang3) * cs * 0.32)))
		_:
			parent.add_child(_box(Vector3(cs * 0.5, cs * 0.5, cs * 0.5), mat, Vector3(0, cs * 0.25, 0)))


static func _add_collision(parent: Node3D, shape: String, cs: float, wh: float, gate_amplitude: float = -1.0) -> void:
	var col := CollisionShape3D.new()
	match shape:
		"wall", "arch", "gate", "roots":
			var sh := BoxShape3D.new()
			# Igual que en _add_shape: una "gate" animada (puerta temporizada) usa
			# una colisión más baja, del tamaño de la amplitud real con la que se
			# hunde, para que se despeje del todo al abrirse (ver `_build_time`).
			var use_gate_amp := shape == "gate" and gate_amplitude >= 0.0
			var h := maxf(0.4, gate_amplitude * 0.8) if use_gate_amp else wh * 0.9
			sh.size = Vector3(cs * 0.95, h, cs * 0.95)
			col.shape = sh
			col.position = Vector3(0, h * 0.5, 0)
		"barrier":
			var sh := BoxShape3D.new()
			var bh := wh * 0.65
			sh.size = Vector3(cs * 0.98, bh, cs * 0.4)
			col.shape = sh
			col.position = Vector3(0, bh * 0.5, 0)
		"column", "pillar":
			var sh := CylinderShape3D.new()
			sh.radius = cs * 0.24
			sh.height = wh
			col.shape = sh
			col.position = Vector3(0, wh * 0.5, 0)
		"platform", "bridge", "water", "fog":
			var sh := BoxShape3D.new()
			sh.size = Vector3(cs * 0.9, 0.3, cs * 0.9)
			col.shape = sh
			col.position = Vector3(0, 0.15, 0)
		"blade":
			var sh := BoxShape3D.new()
			sh.size = Vector3(cs * 1.3, wh * 0.5, cs * 0.2)
			col.shape = sh
			col.position = Vector3(0, wh * 0.4, 0)
		"mill":
			var sh := BoxShape3D.new()
			sh.size = Vector3(cs * 1.1, wh * 0.7, cs * 0.3)
			col.shape = sh
			col.position = Vector3(0, wh * 0.5, 0)
		"ring":
			var sh := BoxShape3D.new()
			sh.size = Vector3(cs * 0.7, cs * 0.7, cs * 0.7)
			col.shape = sh
			col.position = Vector3(0, wh * 0.50, 0)
		_:
			var sh := BoxShape3D.new()
			sh.size = Vector3(cs * 0.55, cs * 0.55, cs * 0.55)
			col.shape = sh
			col.position = Vector3(0, cs * 0.3, 0)
	parent.add_child(col)


# ══════════════════════════════════════════════════════════════════════════════
# PRIMITIVAS
# ══════════════════════════════════════════════════════════════════════════════
static func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	return mi


static func _sphere(r: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	return mi


static func _cyl(top: float, bot: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bot
	c.height = h
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	return mi


static func _cone(r: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	return _cyl(0.0, r, h, mat, pos)


static func _build_checkpoint(_shape: String, cell_size: float, wall_h: float, color: Color, _rdef: Dictionary) -> Node3D:
	var root := Node3D.new()
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = cell_size * 0.3
	cyl.bottom_radius = cell_size * 0.35
	cyl.height = wall_h * 0.4
	mesh_inst.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.8, 0.3)
	mat.emission_energy_multiplier = 1.2
	mesh_inst.material_override = mat
	mesh_inst.position.y = wall_h * 0.2
	root.add_child(mesh_inst)

	# Cristal/Esfera flotante en la cima del altar
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	orb.mesh = sphere
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.2, 0.9, 0.7)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.2, 0.9, 0.7)
	orb_mat.emission_energy_multiplier = 2.0
	orb.material_override = orb_mat
	orb.position.y = wall_h * 0.55
	root.add_child(orb)

	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(cell_size * 0.8, wall_h, cell_size * 0.8)
	col.shape = box
	col.position.y = wall_h * 0.5
	area.add_child(col)
	root.add_child(area)

	area.body_entered.connect(func(body: Node) -> void:
		if body is CharacterBody3D:
			var parent_view = body.get_parent()
			while parent_view != null and not parent_view.has_method("set_active_checkpoint"):
				parent_view = parent_view.get_parent()
			if parent_view != null and parent_view.has_method("set_active_checkpoint"):
				parent_view.set_active_checkpoint(root.global_position)
	)

	return root


static func _mat(color: Color, emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.4
	return m


static func _mat_alpha(color: Color, alpha: float, emissive: bool) -> StandardMaterial3D:
	var m := _mat(color, emissive)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	return m


## Catálogo de glifos por elemento — accesibilidad para daltonismo
## (`Locale.colorblind`, idea.md §4.1). Mismos glifos que ya usa
## `ExplorationHud.gd` (icono de habilidad) y `CombatFx.spawn_word`
## (`cb_symbol` en combate), para que el jugador aprenda un único lenguaje
## visual en todo el juego en vez de depender solo del color del material.
const ELEMENT_GLYPHS := {
	"fuego": "🔥", "hielo": "❄️", "rayo": "⚡",
	"agua": "💧", "viento": "🌪️", "tierra": "🪨",
}

## Añade un glifo billboard flotante sobre `root` (fuente/receptor elemental)
## para no depender SOLO del color del material a la hora de identificar el
## elemento. No-op si el modo daltónico no está activo (`Locale.colorblind`).
static func _add_element_glyph(root: Node3D, element: String, wall_h: float) -> void:
	if root == null or not Locale.colorblind:
		return
	var glyph := String(ELEMENT_GLYPHS.get(element, ""))
	if glyph == "":
		return
	var lbl := Label3D.new()
	lbl.text = glyph
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 72
	lbl.outline_size = 12
	lbl.position = Vector3(0, wall_h * 0.75, 0)
	root.add_child(lbl)


static func _color(v) -> Color:
	var s := String(v)
	if s.begins_with("#"):
		return Color.html(s)
	return Color(0.6, 0.6, 0.6)


## Aplica rotación (grados Y) y escala uniforme opcionales de la celda.
static func _apply_transform(node: Node3D, cell: Dictionary) -> void:
	var rot = cell.get("rot", null)
	if rot != null:
		node.rotation_degrees.y = float(rot)
	var sc = cell.get("scale", null)
	if sc != null and float(sc) > 0.0:
		node.scale = Vector3.ONE * float(sc)


const REACTION_BURNABLE_ROOTS := preload("res://scenes/views/view_dungeon/interaction/reactions/BurnableRoots.gd")


## Raíces quemables por fuego: obstáculo sólido que bloquea toda la casilla. Al recibir
## fuego, arde en llamas durante 1s y se desintegra por completo liberando el paso.
static func _build_burnable_roots(cs: float, wh: float, color: Color, rdef: Dictionary) -> Node3D:
	var body := StaticBody3D.new()
	_add_collision(body, "roots", cs, wh)

	var visual := Node3D.new()
	visual.name = "RootsVisual"

	const ROOTS_TEX_PATH := "res://assets/dungeon/textures/tex_burnable_roots.png"
	var roots_tex: Texture2D = load(ROOTS_TEX_PATH) if ResourceLoader.exists(ROOTS_TEX_PATH) else null

	# Material de corteza leñosa y zarzas musgosas con mapeado triplanar
	var wood_mat := StandardMaterial3D.new()
	if roots_tex != null:
		wood_mat.albedo_texture = roots_tex
		wood_mat.uv1_triplanar = true
		wood_mat.uv1_scale = Vector3(1.1, 1.1, 1.1)
		wood_mat.albedo_color = Color(0.92, 0.98, 0.88)
	else:
		wood_mat.albedo_color = Color(0.28, 0.45, 0.22)
	wood_mat.roughness = 0.86

	# Material para hojas y brotes verdes
	var leaf_mat := StandardMaterial3D.new()
	if roots_tex != null:
		leaf_mat.albedo_texture = roots_tex
		leaf_mat.uv1_triplanar = true
		leaf_mat.uv1_scale = Vector3(2.5, 2.5, 2.5)
		leaf_mat.albedo_color = Color(0.42, 0.85, 0.40)
	else:
		leaf_mat.albedo_color = Color(0.28, 0.70, 0.30)
	leaf_mat.roughness = 0.60

	# Material de espinas
	var thorn_mat := StandardMaterial3D.new()
	thorn_mat.albedo_color = Color(0.35, 0.26, 0.18)
	thorn_mat.roughness = 0.80

	# 1. Distribución 2D de tallos principales ocupando todo el volumen cuadrado de la casilla (X y Z)
	# para que luzcan como una maraña densa y homogénea desde cualquier perspectiva (frontal, lateral o diagonal).
	var stalk_defs := [
		# 4 Esquinas principales
		{"x": -cs * 0.33, "z": -cs * 0.32, "h_mul": 0.92, "r_mul": 1.05},
		{"x":  cs * 0.32, "z": -cs * 0.33, "h_mul": 0.96, "r_mul": 1.02},
		{"x": -cs * 0.31, "z":  cs * 0.33, "h_mul": 0.94, "r_mul": 1.00},
		{"x":  cs * 0.33, "z":  cs * 0.31, "h_mul": 0.90, "r_mul": 1.04},

		# 4 Bordes laterales / caras
		{"x":  cs * 0.02, "z": -cs * 0.35, "h_mul": 0.98, "r_mul": 1.10},
		{"x": -cs * 0.04, "z":  cs * 0.34, "h_mul": 0.95, "r_mul": 1.08},
		{"x": -cs * 0.35, "z":  cs * 0.03, "h_mul": 0.97, "r_mul": 1.12},
		{"x":  cs * 0.34, "z": -cs * 0.02, "h_mul": 0.93, "r_mul": 1.06},

		# 4 Núcleo y volumen interior
		{"x": -cs * 0.16, "z": -cs * 0.14, "h_mul": 1.00, "r_mul": 1.14},
		{"x":  cs * 0.15, "z": -cs * 0.12, "h_mul": 0.95, "r_mul": 1.08},
		{"x": -cs * 0.14, "z":  cs * 0.16, "h_mul": 0.97, "r_mul": 1.10},
		{"x":  cs * 0.16, "z":  cs * 0.15, "h_mul": 1.02, "r_mul": 1.12},
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = int(cs * 100.0) # Semilla determinista para estabilidad visual

	for i in range(stalk_defs.size()):
		var sd: Dictionary = stalk_defs[i]
		var xoff: float = sd["x"] + (rng.randf() - 0.5) * cs * 0.04
		var zoff: float = sd["z"] + (rng.randf() - 0.5) * cs * 0.04
		var h_mul: float = sd["h_mul"]
		var r_mul: float = sd["r_mul"]

		# Inclinación orgánica sutil hacia el centro o cruzada
		var tilt_x := (rng.randf() - 0.5) * 14.0
		var tilt_z := (rng.randf() - 0.5) * 14.0

		# Base ensanchada arraigada en el suelo
		var base_root := _cyl(cs * 0.075 * r_mul, cs * 0.105 * r_mul, wh * 0.10, wood_mat, Vector3(xoff, wh * 0.05, zoff))
		visual.add_child(base_root)

		# Tramo inferior del tallo
		var seg1 := _cyl(cs * 0.065 * r_mul, cs * 0.08 * r_mul, wh * 0.42 * h_mul, wood_mat, Vector3(xoff, wh * 0.25 * h_mul, zoff))
		seg1.rotation_degrees = Vector3(tilt_x, 0, tilt_z)
		visual.add_child(seg1)

		# Tramo superior del tallo (cambio suave de dirección para silueta nudosa)
		var seg2_x := xoff + sin(deg_to_rad(tilt_z)) * (wh * 0.38 * h_mul)
		var seg2_z := zoff - sin(deg_to_rad(tilt_x)) * (wh * 0.38 * h_mul)
		var seg2 := _cyl(cs * 0.045 * r_mul, cs * 0.065 * r_mul, wh * 0.45 * h_mul, wood_mat, Vector3(seg2_x, wh * 0.65 * h_mul, seg2_z))
		seg2.rotation_degrees = Vector3(-tilt_x * 0.6, 0, -tilt_z * 0.8)
		visual.add_child(seg2)

		# Espinas / brotes laterales afilados
		for k in range(2):
			var th_h := wh * (0.3 + float(k) * 0.35) * h_mul
			var th_dir := 1.0 if (i + k) % 2 == 0 else -1.0
			var rot_y := float(i * 30 + k * 90)
			var thorn := _cyl(0.005, cs * 0.022, cs * 0.08, thorn_mat, Vector3(xoff + th_dir * cs * 0.05, th_h, zoff))
			thorn.rotation_degrees = Vector3(0, rot_y, th_dir * 70.0)
			visual.add_child(thorn)

	# 2. Zarzas secundarias entrelazadas en diagonal y en anillo perimetral envolviendo todo el volumen
	var cross_vines := [
		# Anillo perimetral que une los 4 costados
		{"from": Vector3(-cs * 0.30, wh * 0.35, -cs * 0.30), "to": Vector3(cs * 0.30, wh * 0.55, -cs * 0.30)},
		{"from": Vector3(cs * 0.30, wh * 0.40, -cs * 0.28), "to": Vector3(cs * 0.30, wh * 0.65, cs * 0.30)},
		{"from": Vector3(cs * 0.28, wh * 0.50, cs * 0.30), "to": Vector3(-cs * 0.30, wh * 0.38, cs * 0.30)},
		{"from": Vector3(-cs * 0.30, wh * 0.62, cs * 0.28), "to": Vector3(-cs * 0.30, wh * 0.32, -cs * 0.28)},
		# Cruces diagonales internos a través del núcleo
		{"from": Vector3(-cs * 0.32, wh * 0.25, -cs * 0.30), "to": Vector3(cs * 0.30, wh * 0.70, cs * 0.30)},
		{"from": Vector3(cs * 0.32, wh * 0.28, -cs * 0.28), "to": Vector3(-cs * 0.28, wh * 0.72, cs * 0.28)},
		{"from": Vector3(-cs * 0.28, wh * 0.68, cs * 0.26), "to": Vector3(cs * 0.26, wh * 0.22, -cs * 0.28)},
		{"from": Vector3(cs * 0.28, wh * 0.65, cs * 0.26), "to": Vector3(-cs * 0.26, wh * 0.24, -cs * 0.28)},
	]
	for cv in cross_vines:
		var v_start: Vector3 = cv["from"]
		var v_end: Vector3 = cv["to"]
		var v_mid := (v_start + v_end) * 0.5
		var v_diff := v_end - v_start
		var v_len := v_diff.length()
		var cross_r := _cyl(cs * 0.038, cs * 0.045, v_len, wood_mat, v_mid)
		if v_diff.length_squared() > 0.001:
			var up := Vector3.UP
			var norm := v_diff.normalized()
			if abs(norm.dot(up)) < 0.99:
				cross_r.look_at_from_position(v_mid, v_mid + norm, up)
				cross_r.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
		visual.add_child(cross_r)

		# Pequeños racimos de hojas en los cruces
		var leaf_cluster := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = cs * 0.045
		lm.height = cs * 0.075
		leaf_cluster.mesh = lm
		leaf_cluster.material_override = leaf_mat
		leaf_cluster.position = v_mid + Vector3(0, cs * 0.02, 0)
		visual.add_child(leaf_cluster)

	body.add_child(visual)

	# Rescoldo / Mancha negra de ceniza en el suelo (invisible al inicio)
	var ash := Node3D.new()
	ash.name = "AshMark"
	ash.visible = false
	var ash_mat := StandardMaterial3D.new()
	ash_mat.albedo_color = Color(0.08, 0.08, 0.09)
	ash_mat.roughness = 0.95
	var ash_patch := _box(Vector3(cs * 0.85, 0.006, cs * 0.85), ash_mat, Vector3(0, 0.003, 0))
	ash.add_child(ash_patch)
	body.add_child(ash)

	var react = REACTION_BURNABLE_ROOTS.new()
	react.accepted_element = String(rdef.get("accepted_element", "fuego"))
	react.activate_event = String(rdef.get("activate_event", ""))
	_attach(body, [react])

	return body


const DUNGEON_TEX_DIR := "res://assets/dungeon/textures/"

static func _dungeon_surface_material(shape: String) -> StandardMaterial3D:
	var is_wall := shape == "wall" or shape == "arch"
	var tex_path := DUNGEON_TEX_DIR + "tex_cave_wall.png"
	var tex = load(tex_path) if ResourceLoader.exists(tex_path) else null
	var mat := StandardMaterial3D.new()
	if is_wall:
		if tex != null:
			mat.albedo_texture = tex
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
		else:
			mat.albedo_color = Color(0.42, 0.32, 0.25)
		mat.roughness = 0.9
	else:
		if tex != null:
			mat.albedo_texture = tex
			mat.albedo_color = Color(0.62, 0.62, 0.62)
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
		else:
			mat.albedo_color = Color(0.22, 0.24, 0.28)
		mat.roughness = 0.95
	return mat


## Construye la anilla de agarre psíquico estilo Sonic the Hedgehog:
## Rotación continua sobre el eje Y, levitación armónica suave, halo interior resplandeciente,
## gemas de resonancia, luz omnidireccional y partículas arcanas.
static func _build_sonic_ring(parent: Node3D, cs: float, wh: float, color: Color) -> void:
	var rotator_script: Script = preload("res://scripts/graphics/OrbRotator3D.gd")
	var pivot: Node3D = rotator_script.new()
	pivot.name = "RingPivot"
	pivot.set("rotation_speed", 1.8)
	pivot.set("bob_amplitude", 0.08)
	pivot.set("bob_speed", 2.2)
	pivot.set("culler_radius", maxf(1.8, cs * 0.45))
	pivot.position = Vector3(0, wh * 0.50, 0)
	parent.add_child(pivot)

	# 1. Anillo principal exterior metálico y morado vivo muy iluminado
	var ring_mesh := MeshInstance3D.new()
	ring_mesh.name = "RingOuter"
	var tm := TorusMesh.new()
	tm.inner_radius = cs * 0.22
	tm.outer_radius = cs * 0.32
	ring_mesh.mesh = tm

	var ring_purple := Color(0.75, 0.24, 1.0) if (color == Color("#9a8ad0") or color == Color("#8a8a8a")) else color
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = ring_purple
	ring_mat.metallic = 0.85
	ring_mat.roughness = 0.16
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.85, 0.30, 1.0)
	ring_mat.emission_energy_multiplier = 2.8
	ring_mat.rim_enabled = true
	ring_mat.rim = 0.90
	ring_mat.rim_tint = 0.70
	ring_mesh.material_override = ring_mat
	ring_mesh.rotation_degrees = Vector3(90, 0, 0)
	pivot.add_child(ring_mesh)

	# 2. Halo / Aura interior resplandeciente (aditiva translúcida)
	var aura_mesh := MeshInstance3D.new()
	aura_mesh.name = "InnerAura"
	var atm := TorusMesh.new()
	atm.inner_radius = cs * 0.16
	atm.outer_radius = cs * 0.22
	aura_mesh.mesh = atm
	var aura_mat := StandardMaterial3D.new()
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.albedo_color = Color(0.92, 0.55, 1.0, 0.65)
	aura_mesh.material_override = aura_mat
	aura_mesh.rotation_degrees = Vector3(90, 0, 0)
	pivot.add_child(aura_mesh)

	# 3. 4 Gemas / Cristales arcanos en los cuadrantes del anillo
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = Color(0.96, 0.70, 1.0)
	gem_mat.metallic = 0.9
	gem_mat.roughness = 0.1
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.95, 0.55, 1.0)
	gem_mat.emission_energy_multiplier = 3.6
	var gem_dist := cs * 0.27
	var gem_positions := [
		Vector3(0, gem_dist, 0),
		Vector3(0, -gem_dist, 0),
		Vector3(-gem_dist, 0, 0),
		Vector3(gem_dist, 0, 0)
	]
	for gpos in gem_positions:
		var gem := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = cs * 0.038
		sm.height = cs * 0.076
		gem.mesh = sm
		gem.material_override = gem_mat
		gem.position = gpos
		pivot.add_child(gem)

	# 4. Luz Omnidireccional violeta que baña el suelo y paredes circundantes
	var light := OmniLight3D.new()
	light.name = "PurpleLight"
	light.light_color = Color(0.82, 0.40, 1.0)
	light.light_energy = 1.4
	light.omni_range = cs * 1.1
	light.omni_attenuation = 1.6
	pivot.add_child(light)

	# 5. Partículas / motas de energía psíquica flotando alrededor
	var motes := CPUParticles3D.new()
	motes.name = "ArcaneMotes"
	motes.amount = 10
	motes.lifetime = 2.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = cs * 0.30
	motes.direction = Vector3(0, 1, 0)
	motes.spread = 35.0
	motes.gravity = Vector3(0, cs * 0.06, 0)
	motes.initial_velocity_min = cs * 0.02
	motes.initial_velocity_max = cs * 0.06
	motes.scale_amount_min = cs * 0.015
	motes.scale_amount_max = cs * 0.035
	var p_mesh := QuadMesh.new()
	p_mesh.size = Vector2(cs * 0.035, cs * 0.035)
	var p_mat := StandardMaterial3D.new()
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.vertex_color_use_as_albedo = true
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	p_mesh.material = p_mat
	motes.mesh = p_mesh
	var p_grad := Gradient.new()
	p_grad.set_color(0, Color(0.70, 0.25, 1.0, 0.0))
	p_grad.add_point(0.3, Color(0.90, 0.50, 1.0, 0.9))
	p_grad.add_point(0.7, Color(0.95, 0.70, 1.0, 0.8))
	p_grad.set_color(1, Color(0.60, 0.15, 0.9, 0.0))
	motes.color_ramp = p_grad
	pivot.add_child(motes)


## Construye una columna de piedra tallada antigua y el punto de anclaje de agarre psíquico:
## Fuste de piedra con relieves rúnicos antiguos (res://assets/dungeon/textures/tex_column_stone.png),
## molduras escalonadas y abrazaderas de bronce, junto con un halo psíquico giratorio,
## aura translúcida, gemas orbitales de resonancia, luz omnidireccional y partículas arcanas.
static func _build_psychic_column(parent: Node3D, cs: float, wh: float, color: Color) -> void:
	const COLUMN_TEX_PATH := "res://assets/dungeon/textures/tex_column_stone.png"
	var stone_tex: Texture2D = load(COLUMN_TEX_PATH) if ResourceLoader.exists(COLUMN_TEX_PATH) else null

	# Material principal de piedra tallada con relieve rúnico
	var column_mat := StandardMaterial3D.new()
	if stone_tex != null:
		column_mat.albedo_texture = stone_tex
		column_mat.uv1_triplanar = true
		column_mat.uv1_scale = Vector3(0.55, 0.55, 0.55)
		column_mat.albedo_color = Color(0.92, 0.90, 0.88)
	else:
		column_mat.albedo_color = Color(0.52, 0.50, 0.48)
	column_mat.roughness = 0.78
	column_mat.metallic = 0.10

	# Material de basa y capitel (piedra de remate ligeramente más oscura y rugosa)
	var trim_mat := StandardMaterial3D.new()
	if stone_tex != null:
		trim_mat.albedo_texture = stone_tex
		trim_mat.uv1_triplanar = true
		trim_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
		trim_mat.albedo_color = Color(0.78, 0.76, 0.74)
	else:
		trim_mat.albedo_color = Color(0.40, 0.38, 0.36)
	trim_mat.roughness = 0.85

	# Abrazaderas y molduras metálicas de bronce arcaico
	var bronze_mat := StandardMaterial3D.new()
	bronze_mat.albedo_color = Color(0.78, 0.60, 0.35)
	bronze_mat.metallic = 0.85
	bronze_mat.roughness = 0.28
	bronze_mat.rim_enabled = true
	bronze_mat.rim = 0.5

	# 1. Basa / Pedestal inferior escalonado
	parent.add_child(_box(Vector3(cs * 0.54, wh * 0.05, cs * 0.54), trim_mat, Vector3(0, wh * 0.025, 0)))
	parent.add_child(_box(Vector3(cs * 0.48, wh * 0.04, cs * 0.48), trim_mat, Vector3(0, wh * 0.07, 0)))
	parent.add_child(_cyl(cs * 0.32, cs * 0.38, wh * 0.05, trim_mat, Vector3(0, wh * 0.115, 0)))
	parent.add_child(_cyl(cs * 0.29, cs * 0.29, wh * 0.02, bronze_mat, Vector3(0, wh * 0.15, 0)))

	# 2. Fuste principal estriado con molduras de agarre
	parent.add_child(_cyl(cs * 0.24, cs * 0.27, wh * 0.68, column_mat, Vector3(0, wh * 0.50, 0)))
	parent.add_child(_cyl(cs * 0.28, cs * 0.28, wh * 0.025, bronze_mat, Vector3(0, wh * 0.36, 0)))
	parent.add_child(_cyl(cs * 0.28, cs * 0.28, wh * 0.025, bronze_mat, Vector3(0, wh * 0.66, 0)))

	# 3. Capitel y Ábaco superior
	parent.add_child(_cyl(cs * 0.29, cs * 0.26, wh * 0.03, bronze_mat, Vector3(0, wh * 0.85, 0)))
	parent.add_child(_cyl(cs * 0.36, cs * 0.28, wh * 0.06, trim_mat, Vector3(0, wh * 0.895, 0)))
	parent.add_child(_box(Vector3(cs * 0.50, wh * 0.04, cs * 0.50), trim_mat, Vector3(0, wh * 0.945, 0)))
	parent.add_child(_box(Vector3(cs * 0.56, wh * 0.04, cs * 0.56), trim_mat, Vector3(0, wh * 0.98, 0)))

	# 4. Anclaje dinámico de agarre psíquico (anillo giratorio con halo etéreo)
	var rotator_script: Script = preload("res://scripts/graphics/OrbRotator3D.gd")
	var pivot: Node3D = rotator_script.new()
	pivot.name = "PsychicAnchorPivot"
	pivot.set("rotation_speed", 0.9)
	pivot.set("bob_amplitude", 0.015)
	pivot.set("bob_speed", 2.0)
	pivot.set("culler_radius", cs * 0.6)
	pivot.position = Vector3(0, wh * 0.51, 0)
	parent.add_child(pivot)

	# 4.1 Halo exterior luminoso
	var ring_outer := MeshInstance3D.new()
	ring_outer.name = "RingOuter"
	var rtm := TorusMesh.new()
	rtm.inner_radius = cs * 0.25
	rtm.outer_radius = cs * 0.29
	ring_outer.mesh = rtm
	var rmat := StandardMaterial3D.new()
	var base_ring_col := Color(0.85, 0.40, 1.0) if (color == Color("#7a5aae") or color == Color("#6e6d6b") or color == Color("#8a8a8a")) else color
	rmat.albedo_color = base_ring_col
	rmat.metallic = 0.80
	rmat.roughness = 0.18
	rmat.emission_enabled = true
	rmat.emission = base_ring_col
	rmat.emission_energy_multiplier = 3.2
	rmat.rim_enabled = true
	rmat.rim = 1.0
	rmat.rim_tint = 0.7
	ring_outer.material_override = rmat
	pivot.add_child(ring_outer)

	# 4.2 Aura etérea translúcida aditiva
	var aura_inner := MeshInstance3D.new()
	aura_inner.name = "InnerAura"
	var atm := TorusMesh.new()
	atm.inner_radius = cs * 0.22
	atm.outer_radius = cs * 0.32
	aura_inner.mesh = atm
	var amat := StandardMaterial3D.new()
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	amat.cull_mode = BaseMaterial3D.CULL_DISABLED
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	amat.albedo_color = Color(0.92, 0.45, 1.0, 0.35)
	aura_inner.material_override = amat
	pivot.add_child(aura_inner)

	# 4.3 Cuatro cristales de resonancia orbitales
	var gem_mat := StandardMaterial3D.new()
	gem_mat.albedo_color = Color(0.96, 0.70, 1.0)
	gem_mat.metallic = 0.9
	gem_mat.roughness = 0.1
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.95, 0.50, 1.0)
	gem_mat.emission_energy_multiplier = 3.8
	var gem_dist := cs * 0.27
	var gem_positions := [
		Vector3(0, 0, gem_dist),
		Vector3(0, 0, -gem_dist),
		Vector3(-gem_dist, 0, 0),
		Vector3(gem_dist, 0, 0)
	]
	for gpos in gem_positions:
		var gem := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = cs * 0.028
		sm.height = cs * 0.056
		gem.mesh = sm
		gem.material_override = gem_mat
		gem.position = gpos
		pivot.add_child(gem)

	# 4.4 Luz mística suave que ilumina la columna y el suelo
	var ps_light := OmniLight3D.new()
	ps_light.name = "PsychicGlow"
	ps_light.light_color = Color(0.85, 0.38, 1.0)
	ps_light.light_energy = 1.4
	ps_light.omni_range = cs * 1.3
	ps_light.omni_attenuation = 1.6
	pivot.add_child(ps_light)

	# 4.5 Partículas de chispas psíquicas flotantes
	var motes := CPUParticles3D.new()
	motes.name = "PsychicMotes"
	motes.amount = 8
	motes.lifetime = 1.8
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_radius = cs * 0.28
	motes.emission_ring_inner_radius = cs * 0.24
	motes.direction = Vector3(0, 1, 0)
	motes.spread = 20.0
	motes.gravity = Vector3(0, cs * 0.05, 0)
	motes.initial_velocity_min = cs * 0.02
	motes.initial_velocity_max = cs * 0.05
	motes.scale_amount_min = cs * 0.015
	motes.scale_amount_max = cs * 0.030
	var p_mesh := QuadMesh.new()
	p_mesh.size = Vector2(cs * 0.03, cs * 0.03)
	var p_mat := StandardMaterial3D.new()
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.vertex_color_use_as_albedo = true
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	p_mesh.material = p_mat
	motes.mesh = p_mesh
	var p_grad := Gradient.new()
	p_grad.set_color(0, Color(0.70, 0.25, 1.0, 0.0))
	p_grad.add_point(0.3, Color(0.90, 0.50, 1.0, 0.85))
	p_grad.add_point(0.7, Color(0.95, 0.70, 1.0, 0.75))
	p_grad.set_color(1, Color(0.60, 0.15, 0.9, 0.0))
	motes.color_ramp = p_grad
	pivot.add_child(motes)


## Construye una barricada de madera reforzada de mazmorra con fisuras de impacto cinético:
## Tablones de roble añejo agrietados (res://assets/dungeon/textures/tex_wood_barricade.png),
## herrajes y pernos de hierro forjado, y grietas cinéticas fracturadas con fulgor cálido.
static func _build_breakable_barrier(parent: Node3D, cs: float, wh: float, color: Color) -> void:
	var bh := wh * 0.65
	var bw := cs * 0.98
	var bd := cs * 0.35
	var h_center := bh * 0.5

	const BARRICADE_TEX_PATH := "res://assets/dungeon/textures/tex_wood_barricade.png"
	var wood_tex: Texture2D = load(BARRICADE_TEX_PATH) if ResourceLoader.exists(BARRICADE_TEX_PATH) else null

	# Material de tablones de madera añeja
	var plank_mat := StandardMaterial3D.new()
	if wood_tex != null:
		plank_mat.albedo_texture = wood_tex
		plank_mat.uv1_triplanar = true
		plank_mat.uv1_scale = Vector3(0.85, 0.85, 0.85)
		plank_mat.albedo_color = Color(0.92, 0.88, 0.82)
	else:
		plank_mat.albedo_color = color
	plank_mat.roughness = 0.82

	# Material de postes maestros y vigas (madera más densa y oscura)
	var timber_mat := StandardMaterial3D.new()
	if wood_tex != null:
		timber_mat.albedo_texture = wood_tex
		timber_mat.uv1_triplanar = true
		timber_mat.uv1_scale = Vector3(0.65, 0.65, 0.65)
		timber_mat.albedo_color = Color(0.76, 0.70, 0.65)
	else:
		timber_mat.albedo_color = color.darkened(0.25)
	timber_mat.roughness = 0.88

	# Hierro forjado medieval
	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.26, 0.26, 0.30)
	iron_mat.metallic = 0.85
	iron_mat.roughness = 0.35

	# Remaches / pernos metálicos
	var rivet_mat := StandardMaterial3D.new()
	rivet_mat.albedo_color = Color(0.40, 0.38, 0.36)
	rivet_mat.metallic = 0.90
	rivet_mat.roughness = 0.25

	# Fulgor de fisura cinética rompible (luz ámbar cálida)
	var crack_mat := StandardMaterial3D.new()
	crack_mat.albedo_color = Color(1.0, 0.70, 0.20)
	crack_mat.emission_enabled = true
	crack_mat.emission = Color(1.0, 0.60, 0.12)
	crack_mat.emission_energy_multiplier = 3.6
	crack_mat.rim_enabled = true
	crack_mat.rim = 1.0

	# 1. Postes maestros laterales con zapatas y cantoneras de hierro
	var post_x: float = bw * 0.44
	for dir: float in [-1.0, 1.0]:
		var px: float = dir * post_x
		# Viga vertical maestra
		parent.add_child(_box(Vector3(bw * 0.12, bh, bd * 1.05), timber_mat, Vector3(px, h_center, 0)))
		# Zapata de suelo de hierro
		parent.add_child(_box(Vector3(bw * 0.15, bh * 0.08, bd * 1.15), iron_mat, Vector3(px, bh * 0.04, 0)))
		# Tapa de hierro superior
		parent.add_child(_box(Vector3(bw * 0.15, bh * 0.06, bd * 1.15), iron_mat, Vector3(px, bh * 0.97, 0)))
		# Abrazaderas intermedias con pernos
		parent.add_child(_box(Vector3(bw * 0.14, bh * 0.12, bd * 1.10), iron_mat, Vector3(px, bh * 0.22, 0)))
		parent.add_child(_box(Vector3(bw * 0.14, bh * 0.12, bd * 1.10), iron_mat, Vector3(px, bh * 0.78, 0)))
		# Pernos
		parent.add_child(_sphere(cs * 0.016, rivet_mat, Vector3(px, bh * 0.22, bd * 0.58)))
		parent.add_child(_sphere(cs * 0.016, rivet_mat, Vector3(px, bh * 0.78, bd * 0.58)))

	# 2. Tablones horizontales masivos apilados con sutil relieve de profundidad
	const PLANK_COUNT: int = 4
	for i in range(PLANK_COUNT):
		var y_pos := (bh * 0.12) + float(i) * (bh * 0.25)
		var z_offset := 0.012 if i % 2 == 0 else -0.012
		parent.add_child(_box(Vector3(bw * 0.78, bh * 0.24, bd * 0.80), plank_mat, Vector3(0, y_pos, z_offset)))

	# 3. Vigas cruzadas en X (frontal y dorsal)
	var brace_front := _box(Vector3(bw * 0.84, bh * 0.11, bd * 0.88), timber_mat, Vector3(0, h_center, bd * 0.06))
	brace_front.rotation_degrees = Vector3(0, 0, 24)
	parent.add_child(brace_front)

	var brace_back := _box(Vector3(bw * 0.84, bh * 0.11, bd * 0.88), timber_mat, Vector3(0, h_center, -bd * 0.06))
	brace_back.rotation_degrees = Vector3(0, 0, -24)
	parent.add_child(brace_back)

	# Placa central de refuerzo en la intersección de la X con perno maestro
	parent.add_child(_box(Vector3(bw * 0.14, bh * 0.14, bd * 1.02), iron_mat, Vector3(0, h_center, 0)))
	parent.add_child(_sphere(cs * 0.024, rivet_mat, Vector3(0, h_center, bd * 0.52)))
	parent.add_child(_sphere(cs * 0.024, rivet_mat, Vector3(0, h_center, -bd * 0.52)))

	# 4. Fracturas cinéticas luminosas (falla de rotura orgánica y perceptible)
	var f1 := _box(Vector3(bw * 0.38, bh * 0.045, bd * 0.98), crack_mat, Vector3(-bw * 0.08, h_center + bh * 0.08, 0))
	f1.rotation_degrees = Vector3(0, 0, 18)
	parent.add_child(f1)

	var f2 := _box(Vector3(bw * 0.32, bh * 0.045, bd * 0.98), crack_mat, Vector3(bw * 0.09, h_center - bh * 0.07, 0))
	f2.rotation_degrees = Vector3(0, 0, -22)
	parent.add_child(f2)

	var f3 := _box(Vector3(bw * 0.16, bh * 0.035, bd * 0.96), crack_mat, Vector3(-bw * 0.18, h_center - bh * 0.12, 0))
	f3.rotation_degrees = Vector3(0, 0, -35)
	parent.add_child(f3)

	var f4 := _box(Vector3(bw * 0.18, bh * 0.035, bd * 0.96), crack_mat, Vector3(bw * 0.16, h_center + bh * 0.14, 0))
	f4.rotation_degrees = Vector3(0, 0, 40)
	parent.add_child(f4)

	# 5. Fulgor cálido ambiental en la fractura (indica objeto interactivo rompible)
	var crack_light := OmniLight3D.new()
	crack_light.name = "KineticWeakpointLight"
	crack_light.light_color = Color(1.0, 0.65, 0.18)
	crack_light.light_energy = 0.85
	crack_light.omni_range = cs * 1.3
	crack_light.omni_attenuation = 1.6
	crack_light.position = Vector3(0, h_center, 0)
	parent.add_child(crack_light)



