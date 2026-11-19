# WorldFx.gd
# ─────────────────────────────────────────────────────────────────────────────
# (Game Feel) — helpers de VFX reutilizables para el mundo 3D (mapamundi,
# campamento, mazmorras...). Sin estado propio: cada función crea y autodestruye
# sus propios nodos. Pensado para acciones puntuales (recolectar, construir,
# impactar) que deben sentirse vivas sin añadir peso ni coste permanente.
# ─────────────────────────────────────────────────────────────────────────────
class_name WorldFx
extends RefCounted


## "Punch" de escala en un Node3D (recolección/impacto): se encoge, rebota un
## poco por encima de su tamaño y vuelve a su escala original. No acumula: usa
## SIEMPRE la escala actual del nodo como base, así se puede llamar repetidas
## veces sin que el nodo se quede "creciendo".
static func punch_scale(node: Node3D, strength: float = 0.16, time: float = 0.28) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base_scale: Vector3 = node.scale
	var tw := node.create_tween()
	tw.tween_property(node, "scale", base_scale * (1.0 - strength), time * 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base_scale * (1.0 + strength * 0.35), time * 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base_scale, time * 0.4).set_trans(Tween.TRANS_SINE)


## Aparición de una construcción nueva: entra de escala 0 con un ligero rebote
## (overshoot) hasta su tamaño final. Úsalo justo después de añadir el nodo al
## árbol para que nunca aparezca de forma instantánea.
static func pop_in(node: Node3D, time: float = 0.5) -> void:
	if node == null or not is_instance_valid(node):
		return
	var target_scale: Vector3 = node.scale if node.scale != Vector3.ZERO else Vector3.ONE
	node.scale = Vector3.ZERO
	var tw := node.create_tween()
	tw.tween_property(node, "scale", target_scale * 1.08, time * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", target_scale, time * 0.35).set_trans(Tween.TRANS_SINE)


## Estallido breve de partículas cúbicas en un punto del mundo 3D (recolección,
## construcción, impacto). Autodestruye su propio nodo al terminar el ciclo.
static func burst(parent: Node, world_pos: Vector3, color: Color = Color(0.8, 0.65, 0.35), amount: int = 10) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 0.9
	p.randomness = 0.4
	p.direction = Vector3.UP
	p.spread = 55.0
	p.gravity = Vector3(0.0, -4.5, 0.0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.13
	p.mesh = BoxMesh.new()
	(p.mesh as BoxMesh).size = Vector3.ONE * 0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	p.position = world_pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Destello de luz breve (brillo) en un punto del mundo: sube de golpe y se
## apaga enseguida. Barato: un único OmniLight3D que se autodestruye.
static func glow_flash(parent: Node, world_pos: Vector3, color: Color = Color(1.0, 0.92, 0.65), energy: float = 3.0, time: float = 0.4) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = 2.5
	light.position = world_pos
	parent.add_child(light)
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", energy, time * 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "light_energy", 0.0, time * 0.75).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(light.queue_free)


## Combo de recolección: punch de escala en el nodo del recurso + estallido de
## partículas + brillo suave en `world_pos`. Un único punto de llamada para que
## talar/pescar/minar/etc. se sientan iguales de contundentes en todo el juego.
static func harvest_fx(parent: Node, node: Node3D, world_pos: Vector3, color: Color = Color(0.8, 0.65, 0.35)) -> void:
	punch_scale(node)
	burst(parent, world_pos, color, 8)
	glow_flash(parent, world_pos, color, 2.0, 0.3)


## Combo de construcción: aparición con rebote del nodo construido + polvo
## (partículas grises) + brillo cálido en su base. Un único punto de llamada
## para que toda construcción (hoguera, estructuras de campamento…) se sienta
## igual de satisfactoria.
static func build_fx(parent: Node, node: Node3D, world_pos: Vector3) -> void:
	pop_in(node)
	burst(parent, world_pos, Color(0.55, 0.52, 0.48), 14)
	glow_flash(parent, world_pos, Color(1.0, 0.85, 0.5), 3.5, 0.5)


## Efecto visual contundente de explosión: fogonazo de luz omni intensa,
## onda expansiva de choque esférica, estallido de fuego, chispas rápidas y
## bocanada de humo denso ascendente.
static func explosion_fx(parent: Node, world_pos: Vector3, scale_mult: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	# 1. Fogonazo de luz omni de gran intensidad
	glow_flash(parent, world_pos, Color(1.0, 0.55, 0.15), 9.0 * scale_mult, 0.45)

	# 2. Onda expansiva esférica traslúcida que se expande a gran velocidad
	var wave := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3 * scale_mult
	sphere.height = 0.6 * scale_mult
	wave.mesh = sphere
	var wave_mat := StandardMaterial3D.new()
	wave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wave_mat.albedo_color = Color(1.0, 0.7, 0.2, 0.85)
	wave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave.material_override = wave_mat
	wave.position = world_pos
	parent.add_child(wave)

	var tw := wave.create_tween().set_parallel(true)
	tw.tween_property(wave, "scale", Vector3.ONE * (3.8 * scale_mult), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wave_mat, "albedo_color:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(wave.queue_free)

	# 3. Fuego / Llamas de la detonación
	var p_fire := CPUParticles3D.new()
	p_fire.amount = int(36 * scale_mult)
	p_fire.lifetime = 0.5
	p_fire.one_shot = true
	p_fire.explosiveness = 0.96
	p_fire.direction = Vector3.UP
	p_fire.spread = 160.0
	p_fire.gravity = Vector3(0.0, -3.0, 0.0)
	p_fire.initial_velocity_min = 3.5 * scale_mult
	p_fire.initial_velocity_max = 7.0 * scale_mult
	p_fire.scale_amount_min = 0.12 * scale_mult
	p_fire.scale_amount_max = 0.28 * scale_mult
	p_fire.mesh = BoxMesh.new()
	(p_fire.mesh as BoxMesh).size = Vector3.ONE * 0.15
	var mat_fire := StandardMaterial3D.new()
	mat_fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_fire.albedo_color = Color(1.0, 0.45, 0.08)
	p_fire.material_override = mat_fire
	p_fire.position = world_pos
	parent.add_child(p_fire)
	p_fire.emitting = true
	p_fire.finished.connect(p_fire.queue_free)

	# 4. Chispas rápidas
	var p_sparks := CPUParticles3D.new()
	p_sparks.amount = int(28 * scale_mult)
	p_sparks.lifetime = 0.38
	p_sparks.one_shot = true
	p_sparks.explosiveness = 1.0
	p_sparks.direction = Vector3.UP
	p_sparks.spread = 180.0
	p_sparks.gravity = Vector3(0.0, -8.0, 0.0)
	p_sparks.initial_velocity_min = 6.0 * scale_mult
	p_sparks.initial_velocity_max = 11.0 * scale_mult
	p_sparks.scale_amount_min = 0.04 * scale_mult
	p_sparks.scale_amount_max = 0.09 * scale_mult
	p_sparks.mesh = BoxMesh.new()
	(p_sparks.mesh as BoxMesh).size = Vector3.ONE * 0.08
	var mat_sparks := StandardMaterial3D.new()
	mat_sparks.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_sparks.albedo_color = Color(1.0, 0.95, 0.4)
	p_sparks.material_override = mat_sparks
	p_sparks.position = world_pos
	parent.add_child(p_sparks)
	p_sparks.emitting = true
	p_sparks.finished.connect(p_sparks.queue_free)

	# 5. Humo denso ascendente
	var p_smoke := CPUParticles3D.new()
	p_smoke.amount = int(22 * scale_mult)
	p_smoke.lifetime = 0.85
	p_smoke.one_shot = true
	p_smoke.explosiveness = 0.8
	p_smoke.direction = Vector3.UP
	p_smoke.spread = 65.0
	p_smoke.gravity = Vector3(0.0, -0.8, 0.0)
	p_smoke.initial_velocity_min = 1.2 * scale_mult
	p_smoke.initial_velocity_max = 3.2 * scale_mult
	p_smoke.scale_amount_min = 0.18 * scale_mult
	p_smoke.scale_amount_max = 0.40 * scale_mult
	p_smoke.mesh = BoxMesh.new()
	(p_smoke.mesh as BoxMesh).size = Vector3.ONE * 0.2
	var mat_smoke := StandardMaterial3D.new()
	mat_smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_smoke.albedo_color = Color(0.18, 0.16, 0.15, 0.8)
	mat_smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_smoke.material_override = mat_smoke
	p_smoke.position = world_pos + Vector3(0.0, 0.2, 0.0)
	parent.add_child(p_smoke)
	p_smoke.emitting = true
	p_smoke.finished.connect(p_smoke.queue_free)
