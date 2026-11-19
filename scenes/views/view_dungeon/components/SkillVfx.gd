# SkillVfx.gd
# ─────────────────────────────────────────────────────────────────────────────
# FEEDBACK VISUAL PREMIUM DE LAS 6 HABILIDADES DE EXPLORACIÓN
#
# Efectos 3D cinematográficos, multi-capa y AUTODESTRUCTIVOS que representan
# el uso de cada habilidad en mazmorras con acabados de alta calidad.
#
# Incorpora:
#   · Iluminación dinámica de impacto (OmniLight3D que iluminan paredes y suelos de la mazmorra)
#   · Chispas y motas volumétricas (CPUParticles3D aditivas y brillantes)
#   · Haces dobles de energía, anillos sónicos de choque y ondas de escaneo
#   · Pilares de luz sagrada y vórtices elementales
#
# Un efecto por verbo:
#   · grab      → Haz psíquico bifásico (núcleo + vaina), pulsos viajeros, estallido de chispas violetas e impacto luminoso.
#   · impact    → Proyectil sónico cónico con estela de viento, onda expansiva violenta y metralla cinética.
#   · timeshift → Ondas concéntricas de distorsión cronomántica, burbuja de estasis y motas flotantes anti-gravedad.
#   · reveal    → Pulso de sonar arcano expansivo en suelo y aire, estela de motas detectoras de esmeralda.
#   · element   → Vórtice elemental expansivo adaptado al elemento activo (fuego/agua/rayo...) con chispas arremolinadas.
#   · restore   → Pilar celestial de luz dorada, halos sagrados ascendentes y lluvia de estrellas curativas.
# ─────────────────────────────────────────────────────────────────────────────
class_name SkillVfx
extends Node3D


## Punto de entrada: crea el efecto del `verb` dentro de `parent` (nodo del mundo).
## `origin` = origen visual (brazo), `dir` = mirada normalizada, `point` = punto
## apuntado (impacto del raycast o alcance máximo), `color` = color de la habilidad.
static func cast(parent: Node, verb: String, origin: Vector3, dir: Vector3, point: Vector3, color: Color) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	match verb:
		"grab":
			_beam(parent, origin, point, color)
		"impact":
			_wave(parent, origin, dir, point, color)
		"timeshift":
			_pulse(parent, origin, Color(0.30, 0.85, 0.95))
		"reveal":
			_ring(parent, Vector3(origin.x, origin.y - 1.0, origin.z), Color(0.35, 0.95, 0.50))
		"element":
			_aura(parent, origin, color)
		"restore":
			_sparkle(parent, Vector3(origin.x, origin.y - 0.6, origin.z), Color(1.0, 0.90, 0.45))


# ══════════════════════════════════════════════════════════════════════════════
# EFECTOS POR VERBO
# ══════════════════════════════════════════════════════════════════════════════

## 1. AGARRE PSÍQUICO (grab): Haz de energía nítido + pulso viajero + estallido
static func _beam(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	var d := to - from
	var length := d.length()
	if length < 0.1:
		return

	var norm_dir := d.normalized()
	var center_pos := from + d * 0.5
	var beam_basis := _basis_from_y(norm_dir)

	# Luz de impacto concentrada en el objetivo
	_spawn_light(parent, to, color.lightened(0.3), 3.0, 5.0, 0.35)

	# Haz de energía nítido y luminoso
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = length
	cyl.radial_segments = 6
	var mi := _spawn(parent, cyl, Transform3D(beam_basis, center_pos), color.lightened(0.25), 0.95)
	var mat := mi.material_override as StandardMaterial3D
	if mat != null:
		mat.emission_energy_multiplier = 3.5

	# Pulso de energía viajero rápido
	var ring_node := _spawn(parent, TorusMesh.new(), Transform3D(beam_basis, from), Color.WHITE, 0.9)
	var torus_mesh := ring_node.mesh as TorusMesh
	torus_mesh.inner_radius = 0.08
	torus_mesh.outer_radius = 0.18
	torus_mesh.rings = 4
	torus_mesh.ring_segments = 12
	var t_ring := ring_node.create_tween()
	t_ring.tween_property(ring_node, "global_position", to, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t_ring.chain().tween_callback(ring_node.queue_free)

	# Desvanecimiento ágil del haz
	_expand_and_free(mi, 1.0, 1.0, 0.35)

	# Estallido ligero de 10 chispas psíquicas e impacto
	_spawn_particles(parent, to, color.lightened(0.3), 10, 4.2, 0.35, 160.0, -norm_dir)
	var impact_ring := _spawn(parent, TorusMesh.new(), Transform3D(beam_basis, to), color.lightened(0.4), 0.85)
	var tm := impact_ring.mesh as TorusMesh
	tm.inner_radius = 0.18
	tm.outer_radius = 0.32
	tm.rings = 4
	tm.ring_segments = 14
	_expand_and_free(impact_ring, 0.5, 1.8, 0.28)


## 2. ONDA CINÉTICA (impact): Proyectil sónico + onda expansiva nítida
static func _wave(parent: Node, origin: Vector3, dir: Vector3, target_point: Vector3, color: Color) -> void:
	var dist := origin.distance_to(target_point)
	if dist < 0.1:
		return

	var norm_dir := dir.normalized()
	var travel_time := clampf(dist / 32.0, 0.08, 0.25)

	# Fogón ligero en el origen
	_spawn_light(parent, origin, color, 2.2, 4.5, 0.18)

	# Proyectil cinético: disco sónico frontal
	var torus := TorusMesh.new()
	torus.inner_radius = 0.22
	torus.outer_radius = 0.48
	torus.rings = 4
	torus.ring_segments = 16
	var mi_wave := _spawn(parent, torus, Transform3D(_basis_from_y(norm_dir), origin), color.lightened(0.1), 0.95)

	var t := mi_wave.create_tween()
	t.tween_property(mi_wave, "global_position", target_point, travel_time).set_trans(Tween.TRANS_LINEAR)

	t.chain().tween_callback(func() -> void:
		if not is_instance_valid(mi_wave): return

		# Detonación de impacto: luz y 12 chispas cinéticas
		_spawn_light(parent, target_point, color.lightened(0.3), 3.5, 5.5, 0.28)
		_spawn_particles(parent, target_point, color.lightened(0.2), 12, 5.0, 0.35, 150.0, -norm_dir)

		# Anillo de onda expansiva
		_expand_and_free(mi_wave, 1.0, 2.6, 0.20)
	)


## 3. DISTORSIÓN TEMPORAL (timeshift): Ondas cronománticas esbeltas + motas suaves
static func _pulse(parent: Node, center: Vector3, color: Color) -> void:
	# Luz suave temporal
	_spawn_light(parent, center + Vector3(0, 0.3, 0), color, 2.5, 5.5, 0.35)

	# Doble onda cronomántica concéntrica a media altura
	for i in range(2):
		var ring := _spawn(parent, TorusMesh.new(), Transform3D(Basis(), center + Vector3(0, -0.1 * i, 0)), color.lightened(float(i) * 0.2), 0.85)
		var tm := ring.mesh as TorusMesh
		tm.inner_radius = 0.4
		tm.outer_radius = 0.65
		tm.rings = 4
		tm.ring_segments = 18
		var target_s := 3.5 + float(i) * 1.5
		var dur := 0.35 + float(i) * 0.08
		_expand_and_free(ring, 0.5, target_s, dur)

	# 10 motas de tiempo suspendido flotando suavemente hacia arriba
	_spawn_particles(parent, center + Vector3(0, 0.2, 0), color.lightened(0.3), 10, 1.6, 0.45, 180.0, Vector3.UP, Vector3(0, 1.5, 0))


## 4. INSTINTO DEL EXPLORADOR (reveal): Sonar de suelo + luciérnagas ligeras
static func _ring(parent: Node, center: Vector3, color: Color) -> void:
	# Iluminación esmeralda ambiental suave
	_spawn_light(parent, center + Vector3(0, 0.5, 0), color, 2.5, 6.5, 0.45)

	# Onda de sonar nítida por el suelo
	var ring_primary := _spawn(parent, TorusMesh.new(), Transform3D(Basis(), center), color, 0.85)
	var tm1 := ring_primary.mesh as TorusMesh
	tm1.inner_radius = 0.6
	tm1.outer_radius = 0.85
	tm1.rings = 4
	tm1.ring_segments = 24
	_expand_and_free(ring_primary, 0.6, 12.0, 0.50)

	# 12 luciérnagas mágicas ligeras suspendidas brevemente
	_spawn_particles(parent, center + Vector3(0, 0.5, 0), color.lightened(0.35), 12, 2.5, 0.65, 180.0, Vector3.UP, Vector3(0, -0.1, 0))


## 5. AFINIDAD ELEMENTAL (element): Onda elemental nítida + chispas
static func _aura(parent: Node, center: Vector3, color: Color) -> void:
	# Luz de flash elemental
	_spawn_light(parent, center + Vector3(0, 0.4, 0), color, 2.8, 5.0, 0.32)

	# Anillo elemental expansivo horizontal
	var ring := _spawn(parent, TorusMesh.new(), Transform3D(Basis(), center + Vector3(0, -0.1, 0)), color.lightened(0.2), 0.85)
	var tm := ring.mesh as TorusMesh
	tm.inner_radius = 0.45
	tm.outer_radius = 0.72
	tm.rings = 4
	tm.ring_segments = 18
	_expand_and_free(ring, 0.5, 2.8, 0.35)

	# 12 chispas elementales ascendentes
	_spawn_particles(parent, center + Vector3(0, 0.2, 0), color.lightened(0.3), 12, 2.6, 0.45, 180.0, Vector3.UP, Vector3(0, 1.4, 0))


## 6. RESTAURACIÓN / PURIFICACIÓN (restore): Aurora y halo celestial ligero alrededor del jugador
static func _sparkle(parent: Node, center: Vector3, _color: Color) -> void:
	# 1. Luz celestial suave y rápida (no ciega ni ralentiza)
	_spawn_light(parent, center + Vector3(0, 0.4, 0), Color(1.0, 0.94, 0.70), 2.4, 5.0, 0.35)

	# 2. Onda de aura purificadora horizontal (anillo esbelto a media altura)
	var ring_aura := _spawn(parent, TorusMesh.new(), Transform3D(Basis(), center + Vector3(0, -0.1, 0)), Color(0.70, 0.98, 0.80), 0.85)
	var r_tm := ring_aura.mesh as TorusMesh
	r_tm.inner_radius = 0.55
	r_tm.outer_radius = 0.78
	r_tm.rings = 4
	r_tm.ring_segments = 20
	_expand_and_free(ring_aura, 0.5, 2.8, 0.42)

	# 3. Halo sagrado dorado que asciende suavemente
	var halo := _spawn(parent, TorusMesh.new(), Transform3D(Basis(), center + Vector3(0, 0.1, 0)), Color(1.0, 0.90, 0.45), 0.8)
	var h_tm := halo.mesh as TorusMesh
	h_tm.inner_radius = 0.38
	h_tm.outer_radius = 0.52
	h_tm.rings = 4
	h_tm.ring_segments = 18
	_expand_and_free(halo, 0.6, 1.8, 0.38, Vector3(0, 1.1, 0))

	# 4. Breve y sutil lluvia de 12 motas de stardust ascendente (muy ligero para móviles)
	_spawn_particles(parent, center + Vector3(0, 0.2, 0), Color(1.0, 0.96, 0.65), 12, 1.8, 0.45, 120.0, Vector3.UP, Vector3(0, 1.6, 0))


# ══════════════════════════════════════════════════════════════════════════════
# UTILIDADES Y HELPERS VISUALES
# ══════════════════════════════════════════════════════════════════════════════

## Crea una luz omnidireccional efímera que ilumina los muros y el entorno en 3D.
static func _spawn_light(parent: Node, pos: Vector3, color: Color, energy: float, reach: float, duration: float) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = pos

	var t := light.create_tween()
	t.tween_property(light, "light_energy", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(light.queue_free)


## Genera un estallido volumétrico de chispas/partículas aditivas que se auto-destruye.
static func _spawn_particles(parent: Node, pos: Vector3, color: Color, count: int, speed: float, lifetime: float,
		spread_angle: float = 180.0, dir: Vector3 = Vector3.ZERO, gravity_vec: Vector3 = Vector3(0, -1.5, 0)) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var p := CPUParticles3D.new()
	p.amount = count
	p.one_shot = true
	p.explosiveness = 0.92
	p.lifetime = lifetime
	p.direction = dir.normalized() if dir != Vector3.ZERO else Vector3.UP
	p.spread = spread_angle
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed * 1.35
	p.gravity = gravity_vec
	p.damping_min = 2.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6

	# Mesh de cada partícula: quad orientado a cámara con material aditivo y brillante
	var q := QuadMesh.new()
	q.size = Vector2(0.10, 0.10)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.5
	q.material = mat
	p.mesh = q

	parent.add_child(p)
	p.global_position = pos
	p.emitting = true

	var t := p.create_tween()
	t.tween_interval(lifetime + 0.1)
	t.chain().tween_callback(p.queue_free)


## Material emisivo sin sombreado y con mezcla aditiva para un resplandor mágico.
static func _mat(color: Color, alpha: float, add_blend: bool = true, two_sided: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add_blend else BaseMaterial3D.BLEND_MODE_MIX
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	return m


## Crea un MeshInstance3D visual (sin sombra) dentro de `parent` con su transform.
static func _spawn(parent: Node, mesh: Mesh, xform: Transform3D, color: Color, alpha: float, two_sided: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, alpha, true, two_sided)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_transform = xform
	return mi


## Expande la escala de `mi` y desvanece su material suavemente, luego lo libera.
static func _expand_and_free(mi: MeshInstance3D, from_s: float, to_s: float, dur: float, move: Vector3 = Vector3.ZERO) -> void:
	mi.scale = Vector3.ONE * from_s
	var mat := mi.material_override as StandardMaterial3D
	var t := mi.create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3.ONE * to_s, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if mat != null:
		t.tween_property(mat, "albedo_color:a", 0.0, dur).set_ease(Tween.EASE_IN)
		t.tween_property(mat, "emission_energy_multiplier", 0.0, dur)
	if move != Vector3.ZERO:
		t.tween_property(mi, "global_position", mi.global_position + move, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(mi.queue_free)


## Base ortonormal cuyo eje Y apunta en `dir` (para orientar cilindros y toros).
static func _basis_from_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.001:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
