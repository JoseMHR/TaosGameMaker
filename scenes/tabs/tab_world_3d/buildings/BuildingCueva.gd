# BuildingCueva.gd
# ─────────────────────────────────────────────────────────────────────────────
# Geometría procedural low-poly para el marcador de CUEVA/MAZMORRA en el mapamundi.
# Diseñado específicamente para ser altamente reconocible e impactante desde la
# cámara isométrica cenital:
# - Risco montañoso escarpado con estratos rocosos escalonados y crestas afiladas.
# - Arco monumental de sillares de piedra tallada y escalones de entrada.
# - Embocadura abovedada hacia las profundidades subterráneas con vacío oscuro.
# - Estructura de vigas de madera de refuerzo minero con travesaños diagonales.
# - Cristales luminosos y pebeteros de hierro con fuego vivo en la entrada.
# ─────────────────────────────────────────────────────────────────────────────
class_name BuildingCueva
extends RefCounted


static func build(container: Node3D, style: Dictionary = {}) -> void:
	var _wall_ovr: String = String(style.get("wall_color", ""))
	var rock_col := Color(_wall_ovr) if _wall_ovr != "" else Color(0.36, 0.35, 0.38)

	# ─── PALETA DE MATERIALES ────────────────────────────────────────────────
	var mat_rock_base := StandardMaterial3D.new()
	mat_rock_base.albedo_color = rock_col.darkened(0.20)
	mat_rock_base.roughness = 0.90

	var mat_rock_mid := StandardMaterial3D.new()
	mat_rock_mid.albedo_color = rock_col
	mat_rock_mid.roughness = 0.85

	var mat_rock_light := StandardMaterial3D.new()
	mat_rock_light.albedo_color = rock_col.lightened(0.20)
	mat_rock_light.roughness = 0.80

	var mat_carved_stone := StandardMaterial3D.new()
	mat_carved_stone.albedo_color = Color(0.55, 0.53, 0.50) # Sillares de piedra trabajada
	mat_carved_stone.roughness = 0.75

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.38, 0.24, 0.14)
	mat_wood.roughness = 0.80

	var mat_void := StandardMaterial3D.new()
	mat_void.albedo_color = Color(0.01, 0.01, 0.02) # Oscuridad abisal del interior
	mat_void.roughness = 1.0

	var mat_crystal := StandardMaterial3D.new()
	mat_crystal.albedo_color = Color(0.40, 0.85, 1.0)
	mat_crystal.emission_enabled = true
	mat_crystal.emission = Color(0.25, 0.75, 1.0)
	mat_crystal.emission_energy_multiplier = 3.2
	mat_crystal.roughness = 0.2

	var mat_fire := StandardMaterial3D.new()
	mat_fire.albedo_color = Color(1.0, 0.60, 0.15)
	mat_fire.emission_enabled = true
	mat_fire.emission = Color(1.0, 0.45, 0.05)
	mat_fire.emission_energy_multiplier = 4.0

	var mat_iron := StandardMaterial3D.new()
	mat_iron.albedo_color = Color(0.18, 0.18, 0.20)
	mat_iron.metallic = 0.6
	mat_iron.roughness = 0.5

	# ─── 1. MACIZO MONTAÑOSO ESCALONADO (Montaña y Crestas Rocosas) ─────────
	# Montículo trasero principal
	var peak := MeshInstance3D.new()
	var peak_mesh := PrismMesh.new()
	peak_mesh.size = Vector3(1.70, 1.35, 1.40)
	peak.mesh = peak_mesh
	peak.material_override = mat_rock_mid
	peak.position = Vector3(0.0, 0.68, -0.30)
	peak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(peak)

	# Cresta lateral izquierda
	var left_crag := MeshInstance3D.new()
	var lc_mesh := PrismMesh.new()
	lc_mesh.size = Vector3(0.95, 1.10, 1.10)
	left_crag.mesh = lc_mesh
	left_crag.material_override = mat_rock_base
	left_crag.position = Vector3(-0.62, 0.55, -0.15)
	left_crag.rotation_degrees = Vector3(5, 25, 8)
	left_crag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(left_crag)

	# Cresta lateral derecha
	var right_crag := MeshInstance3D.new()
	var rc_mesh := PrismMesh.new()
	rc_mesh.size = Vector3(0.95, 1.10, 1.10)
	right_crag.mesh = rc_mesh
	right_crag.material_override = mat_rock_base
	right_crag.position = Vector3(0.62, 0.55, -0.15)
	right_crag.rotation_degrees = Vector3(5, -25, -8)
	right_crag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(right_crag)

	# Bloques de estrato rocoso superior con cortes afilados
	var strata := [
		{"pos": Vector3(0.0, 1.12, -0.22),  "sz": Vector3(0.70, 0.38, 0.65), "rot": Vector3(8, 45, 5),   "mat": mat_rock_light},
		{"pos": Vector3(-0.45, 0.85, -0.10),"sz": Vector3(0.55, 0.42, 0.55), "rot": Vector3(15, -30, 12), "mat": mat_rock_mid},
		{"pos": Vector3(0.45, 0.85, -0.10), "sz": Vector3(0.55, 0.42, 0.55), "rot": Vector3(15, 30, -12),  "mat": mat_rock_mid},
		{"pos": Vector3(-0.68, 0.22, 0.25), "sz": Vector3(0.45, 0.40, 0.45), "rot": Vector3(0, 35, 15),   "mat": mat_rock_light},
		{"pos": Vector3(0.68, 0.22, 0.25),  "sz": Vector3(0.45, 0.40, 0.45), "rot": Vector3(0, -35, -15),  "mat": mat_rock_light}
	]
	for st in strata:
		var boulder := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = st["sz"]
		boulder.mesh = b_mesh
		boulder.material_override = st["mat"]
		boulder.position = st["pos"]
		boulder.rotation_degrees = st["rot"]
		boulder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(boulder)

	# ─── 2. ENTRADA CAVERNOSA: ESCALONES Y ARCO DE SILLARES ─────────────────
	# Escalón inferior de piedra
	var step1 := MeshInstance3D.new()
	var s1_mesh := BoxMesh.new()
	s1_mesh.size = Vector3(1.10, 0.08, 0.45)
	step1.mesh = s1_mesh
	step1.material_override = mat_carved_stone
	step1.position = Vector3(0.0, 0.04, 0.38)
	step1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(step1)

	# Escalón superior de piedra
	var step2 := MeshInstance3D.new()
	var s2_mesh := BoxMesh.new()
	s2_mesh.size = Vector3(0.92, 0.08, 0.40)
	step2.mesh = s2_mesh
	step2.material_override = mat_carved_stone
	step2.position = Vector3(0.0, 0.12, 0.20)
	step2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(step2)

	# Pilares de sillares tallados que enmarcan la boca
	for side in [-1, 1]:
		for block_idx in range(4):
			var block := MeshInstance3D.new()
			var blk_mesh := BoxMesh.new()
			blk_mesh.size = Vector3(0.20, 0.22, 0.24)
			block.mesh = blk_mesh
			block.material_override = mat_carved_stone
			block.position = Vector3(side * 0.42, 0.16 + float(block_idx) * 0.22, 0.12)
			block.rotation_degrees = Vector3(0, float(block_idx * 6) * side, 0)
			block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			container.add_child(block)

	# Dintel y Clave de arco de piedra superior
	var arch_top := MeshInstance3D.new()
	var at_mesh := BoxMesh.new()
	at_mesh.size = Vector3(1.10, 0.22, 0.32)
	arch_top.mesh = at_mesh
	arch_top.material_override = mat_carved_stone
	arch_top.position = Vector3(0.0, 0.98, 0.12)
	arch_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(arch_top)

	# Clave de arco decorativa sobresaliente (Keystone)
	var keystone := MeshInstance3D.new()
	var ks_mesh := PrismMesh.new()
	ks_mesh.size = Vector3(0.28, 0.30, 0.15)
	keystone.mesh = ks_mesh
	keystone.material_override = mat_rock_light
	keystone.position = Vector3(0.0, 1.05, 0.22)
	keystone.rotation_degrees = Vector3(180, 0, 0)
	keystone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(keystone)

	# ─── 3. VIGAS DE MINA Y TÚNEL OSCURO SUBTERRÁNEO ─────────────────────────
	# Vigas de madera dentro del arco
	for side in [-1, 1]:
		var timber := MeshInstance3D.new()
		var tm_mesh := BoxMesh.new()
		tm_mesh.size = Vector3(0.08, 0.78, 0.10)
		timber.mesh = tm_mesh
		timber.material_override = mat_wood
		timber.position = Vector3(side * 0.30, 0.50, 0.05)
		timber.rotation_degrees = Vector3(0, 0, side * 3.0)
		timber.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(timber)

	var wood_header := MeshInstance3D.new()
	var wh_mesh := BoxMesh.new()
	wh_mesh.size = Vector3(0.72, 0.09, 0.12)
	wood_header.mesh = wh_mesh
	wood_header.material_override = mat_wood
	wood_header.position = Vector3(0.0, 0.85, 0.05)
	wood_header.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(wood_header)

	# Túnel oscuro abisal (embocadura negra)
	var void_mouth := MeshInstance3D.new()
	var vm_mesh := BoxMesh.new()
	vm_mesh.size = Vector3(0.56, 0.74, 0.45)
	void_mouth.mesh = vm_mesh
	void_mouth.material_override = mat_void
	void_mouth.position = Vector3(0.0, 0.48, -0.10)
	container.add_child(void_mouth)

	# ─── 4. DETALLES: CRISTALES MÁGICOS Y PEBETEROS CON FUEGO ────────────────
	# Cristales de maná incrustados en la roca superior
	for c_data in [
		{"pos": Vector3(-0.35, 1.15, -0.05), "sz": Vector3(0.09, 0.32, 0.09), "rot": Vector3(15, 20, -22)},
		{"pos": Vector3(-0.26, 1.22, -0.08), "sz": Vector3(0.07, 0.24, 0.07), "rot": Vector3(8, 0, -10)},
		{"pos": Vector3(0.38, 1.12, -0.05),  "sz": Vector3(0.08, 0.28, 0.08), "rot": Vector3(12, -25, 25)}
	]:
		var crystal := MeshInstance3D.new()
		var cr_mesh := PrismMesh.new()
		cr_mesh.size = c_data["sz"]
		crystal.mesh = cr_mesh
		crystal.material_override = mat_crystal
		crystal.position = c_data["pos"]
		crystal.rotation_degrees = c_data["rot"]
		crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(crystal)

	# Pebeteros de hierro con fuego a ambos lados de los escalones
	for side in [-1, 1]:
		var brazier_stand := MeshInstance3D.new()
		var bs_mesh := CylinderMesh.new()
		bs_mesh.top_radius = 0.08
		bs_mesh.bottom_radius = 0.06
		bs_mesh.height = 0.32
		bs_mesh.radial_segments = 6
		brazier_stand.mesh = bs_mesh
		brazier_stand.material_override = mat_iron
		brazier_stand.position = Vector3(side * 0.65, 0.20, 0.32)
		brazier_stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(brazier_stand)

		var brazier_bowl := MeshInstance3D.new()
		var bb_mesh := CylinderMesh.new()
		bb_mesh.top_radius = 0.11
		bb_mesh.bottom_radius = 0.05
		bb_mesh.height = 0.09
		bb_mesh.radial_segments = 6
		brazier_bowl.mesh = bb_mesh
		brazier_bowl.material_override = mat_iron
		brazier_bowl.position = Vector3(side * 0.65, 0.38, 0.32)
		brazier_bowl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(brazier_bowl)

		# Fuego crepitante
		var flame := MeshInstance3D.new()
		var fl_mesh := SphereMesh.new()
		fl_mesh.radius = 0.065
		fl_mesh.height = 0.13
		flame.mesh = fl_mesh
		flame.material_override = mat_fire
		flame.position = Vector3(side * 0.65, 0.46, 0.32)
		container.add_child(flame)

	# Luz puntual cálida iluminando el umbral de la cueva
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.70, 0.30)
	light.light_energy = 2.0
	light.omni_range = 2.2
	light.position = Vector3(0.0, 0.50, 0.35)
	container.add_child(light)
