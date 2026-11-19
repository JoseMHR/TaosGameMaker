# BuildingPuerto.gd
# ─────────────────────────────────────────────────────────────────────────────
# Geometría procedural low-poly del PUERTO DE CELESTIA y muelles de embarque.
# Diseñado para máxima legibilidad e impacto desde la cámara isométrica cenital:
# - Gran barco velero con casco náutico estilizado, mástil alto, velas blancas
#   desplegadas al viento, mascarón y banderín azul ondeante.
# - Muelle y pasarela de madera con tablones marcados, pilotes y norays de amarre.
# - Faro / Torre vigía náutica con tejado cónico azul de Celestia y farol de guía.
# - Cajas de mercancías, barriles de ron/pescado y ancla de hierro forjado.
# ─────────────────────────────────────────────────────────────────────────────
class_name BuildingPuerto
extends RefCounted


static func build(container: Node3D, _cell: CellResource, _style: Dictionary = {}) -> void:
	# ─── PALETA DE MATERIALES ────────────────────────────────────────────────
	var mat_pier_wood := StandardMaterial3D.new()
	mat_pier_wood.albedo_color = Color(0.46, 0.32, 0.20)
	mat_pier_wood.roughness = 0.82

	var mat_dark_timber := StandardMaterial3D.new()
	mat_dark_timber.albedo_color = Color(0.28, 0.18, 0.11)
	mat_dark_timber.roughness = 0.88

	var mat_ship_hull := StandardMaterial3D.new()
	mat_ship_hull.albedo_color = Color(0.50, 0.28, 0.16)
	mat_ship_hull.roughness = 0.72

	var mat_ship_deck := StandardMaterial3D.new()
	mat_ship_deck.albedo_color = Color(0.72, 0.56, 0.38)
	mat_ship_deck.roughness = 0.75

	var mat_white_sail := StandardMaterial3D.new()
	mat_white_sail.albedo_color = Color(0.96, 0.94, 0.88)
	mat_white_sail.cull_mode = BaseMaterial3D.CULL_DISABLED # Visible por ambas caras
	mat_white_sail.roughness = 0.90

	var mat_celestia_blue := StandardMaterial3D.new()
	mat_celestia_blue.albedo_color = Color(0.18, 0.48, 0.82)
	mat_celestia_blue.roughness = 0.60

	var mat_gold_brass := StandardMaterial3D.new()
	mat_gold_brass.albedo_color = Color(0.95, 0.78, 0.25)
	mat_gold_brass.metallic = 0.75
	mat_gold_brass.roughness = 0.30

	var mat_stone := StandardMaterial3D.new()
	mat_stone.albedo_color = Color(0.68, 0.68, 0.70)
	mat_stone.roughness = 0.80

	var mat_iron := StandardMaterial3D.new()
	mat_iron.albedo_color = Color(0.20, 0.20, 0.22)
	mat_iron.metallic = 0.7
	mat_iron.roughness = 0.45

	var mat_lamp_glow := StandardMaterial3D.new()
	mat_lamp_glow.albedo_color = Color(1.0, 0.88, 0.45)
	mat_lamp_glow.emission_enabled = true
	mat_lamp_glow.emission = Color(1.0, 0.80, 0.30)
	mat_lamp_glow.emission_energy_multiplier = 3.5

	var mat_lifebuoy := StandardMaterial3D.new()
	mat_lifebuoy.albedo_color = Color(0.92, 0.22, 0.18)

	# ─── 1. MUELLE DE TABLONES Y DÁRSENA ────────────────────────────────────
	# Pasarela principal del muelle
	var pier := MeshInstance3D.new()
	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(0.72, 0.10, 1.35)
	pier.mesh = p_mesh
	pier.material_override = mat_pier_wood
	pier.position = Vector3(-0.20, 0.08, 0.0)
	pier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(pier)

	# Tablones de borde / remates laterales del muelle
	for side in [-1, 1]:
		var border := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(0.06, 0.06, 1.35)
		border.mesh = b_mesh
		border.material_override = mat_dark_timber
		border.position = Vector3(-0.20 + side * 0.34, 0.14, 0.0)
		border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(border)

	# Pilotes de madera que bajan al suelo/agua
	var pilings := [
		Vector3(-0.52, 0.0, -0.55), Vector3(0.12, 0.0, -0.55),
		Vector3(-0.52, 0.0, 0.0),   Vector3(0.12, 0.0, 0.0),
		Vector3(-0.52, 0.0, 0.55),  Vector3(0.12, 0.0, 0.55)
	]
	for p_pos in pilings:
		var piling := MeshInstance3D.new()
		var pl_mesh := CylinderMesh.new()
		pl_mesh.top_radius = 0.04
		pl_mesh.bottom_radius = 0.045
		pl_mesh.height = 0.28
		pl_mesh.radial_segments = 6
		piling.mesh = pl_mesh
		piling.material_override = mat_dark_timber
		piling.position = Vector3(p_pos.x, 0.08, p_pos.z)
		piling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(piling)

	# Norays de amarre con argollas de piedra/hierro
	for b_pos in [Vector3(0.12, 0.18, -0.45), Vector3(0.12, 0.18, 0.45), Vector3(-0.50, 0.18, 0.45)]:
		var bollard := MeshInstance3D.new()
		var bl_mesh := CylinderMesh.new()
		bl_mesh.top_radius = 0.03
		bl_mesh.bottom_radius = 0.035
		bl_mesh.height = 0.12
		bl_mesh.radial_segments = 6
		bollard.mesh = bl_mesh
		bollard.material_override = mat_iron
		bollard.position = b_pos
		bollard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(bollard)

	# ─── 2. BARCO VELERO CON VELAS DESPLEGADAS (Icono Náutico Principal) ─────
	var ship := Node3D.new()
	ship.position = Vector3(0.48, 0.05, 0.0)
	container.add_child(ship)

	# Casco principal
	var hull := MeshInstance3D.new()
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(0.44, 0.22, 1.15)
	hull.mesh = h_mesh
	hull.material_override = mat_ship_hull
	hull.position.y = 0.08
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ship.add_child(hull)

	# Proa afilada del barco (hacia el norte -Z)
	var bow := MeshInstance3D.new()
	var bw_mesh := PrismMesh.new()
	bw_mesh.size = Vector3(0.44, 0.22, 0.40)
	bow.mesh = bw_mesh
	bow.material_override = mat_ship_hull
	bow.rotation_degrees = Vector3(90, 0, 0)
	bow.position = Vector3(0.0, 0.08, -0.72)
	bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ship.add_child(bow)

	# Bauprés (poste saliente de la proa)
	var bowsprit := MeshInstance3D.new()
	var bsp_mesh := CylinderMesh.new()
	bsp_mesh.top_radius = 0.015
	bsp_mesh.bottom_radius = 0.022
	bsp_mesh.height = 0.38
	bsp_mesh.radial_segments = 5
	bowsprit.mesh = bsp_mesh
	bowsprit.material_override = mat_dark_timber
	bowsprit.rotation_degrees = Vector3(-65, 0, 0)
	bowsprit.position = Vector3(0.0, 0.22, -0.98)
	bowsprit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ship.add_child(bowsprit)

	# Cubierta de madera
	var deck := MeshInstance3D.new()
	var dk_mesh := BoxMesh.new()
	dk_mesh.size = Vector3(0.36, 0.04, 1.05)
	deck.mesh = dk_mesh
	deck.material_override = mat_ship_deck
	deck.position.y = 0.18
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ship.add_child(deck)

	# Castillo de popa (cabina del capitán)
	var cabin := MeshInstance3D.new()
	var cb_mesh := BoxMesh.new()
	cb_mesh.size = Vector3(0.38, 0.16, 0.32)
	cabin.mesh = cb_mesh
	cabin.material_override = mat_ship_hull
	cabin.position = Vector3(0.0, 0.26, 0.38)
	cabin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ship.add_child(cabin)

	# Mástil principal alto (imponente verticalidad)
	var mast := MeshInstance3D.new()
	var m_mesh := CylinderMesh.new()
	m_mesh.top_radius = 0.02
	m_mesh.bottom_radius = 0.03
	m_mesh.height = 1.35
	m_mesh.radial_segments = 6
	mast.mesh = m_mesh
	mast.material_override = mat_dark_timber
	mast.position = Vector3(0.0, 0.78, -0.10)
	mast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ship.add_child(mast)

	# Vergas horizontales
	for y_pos in [0.65, 1.15]:
		var yard := MeshInstance3D.new()
		var yd_mesh := CylinderMesh.new()
		yd_mesh.top_radius = 0.015
		yd_mesh.bottom_radius = 0.015
		yd_mesh.height = 0.62
		yd_mesh.radial_segments = 5
		yard.mesh = yd_mesh
		yard.material_override = mat_dark_timber
		yard.rotation_degrees = Vector3(0, 0, 90)
		yard.position = Vector3(0.0, y_pos, -0.10)
		yard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		ship.add_child(yard)

	# Vela mayor blanca desplegada (curvada e hinchada por el viento)
	var sail_main := MeshInstance3D.new()
	var sm_mesh := BoxMesh.new()
	sm_mesh.size = Vector3(0.58, 0.46, 0.02)
	sail_main.mesh = sm_mesh
	sail_main.material_override = mat_white_sail
	sail_main.position = Vector3(0.0, 0.88, -0.09)
	sail_main.rotation_degrees = Vector3(5, 0, 0)
	sail_main.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ship.add_child(sail_main)

	# Vela triangular delantera (Foques)
	var jib := MeshInstance3D.new()
	var jb_mesh := PrismMesh.new()
	jb_mesh.size = Vector3(0.02, 0.65, 0.55)
	jib.mesh = jb_mesh
	jib.material_override = mat_white_sail
	jib.position = Vector3(0.0, 0.68, -0.45)
	jib.rotation_degrees = Vector3(0, 90, 0)
	jib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ship.add_child(jib)

	# Banderín ondeante de Celestia en la punta del mástil
	var flag := MeshInstance3D.new()
	var fg_mesh := PrismMesh.new()
	fg_mesh.size = Vector3(0.02, 0.16, 0.28)
	flag.mesh = fg_mesh
	flag.material_override = mat_celestia_blue
	flag.position = Vector3(0.0, 1.45, 0.05)
	flag.rotation_degrees = Vector3(0, 90, -90)
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ship.add_child(flag)

	# Salvavidas rojo/blanco en la borda
	var buoy := MeshInstance3D.new()
	var by_mesh := TorusMesh.new()
	by_mesh.inner_radius = 0.04
	by_mesh.outer_radius = 0.07
	buoy.mesh = by_mesh
	buoy.material_override = mat_lifebuoy
	buoy.position = Vector3(-0.23, 0.16, 0.05)
	buoy.rotation_degrees = Vector3(0, 0, 90)
	ship.add_child(buoy)

	# ─── 3. FARO / TORRE VIGÍA DEL PUERTO ───────────────────────────────────
	var tower := Node3D.new()
	tower.position = Vector3(-0.52, 0.10, -0.42)
	container.add_child(tower)

	# Base circular de piedra
	var tower_base := MeshInstance3D.new()
	var tb_mesh := CylinderMesh.new()
	tb_mesh.top_radius = 0.22
	tb_mesh.bottom_radius = 0.26
	tb_mesh.height = 0.70
	tb_mesh.radial_segments = 8
	tower_base.mesh = tb_mesh
	tower_base.material_override = mat_stone
	tower_base.position.y = 0.35
	tower_base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tower.add_child(tower_base)

	# Mirador / Balcón superior
	var balcony := MeshInstance3D.new()
	var bc_mesh := CylinderMesh.new()
	bc_mesh.top_radius = 0.25
	bc_mesh.bottom_radius = 0.22
	bc_mesh.height = 0.08
	bc_mesh.radial_segments = 8
	balcony.mesh = bc_mesh
	balcony.material_override = mat_stone
	balcony.position.y = 0.74
	balcony.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tower.add_child(balcony)

	# Linterna / Foco con luz cálida
	var beacon := MeshInstance3D.new()
	var bn_mesh := SphereMesh.new()
	bn_mesh.radius = 0.08
	bn_mesh.height = 0.16
	beacon.mesh = bn_mesh
	beacon.material_override = mat_lamp_glow
	beacon.position.y = 0.86
	tower.add_child(beacon)

	# Tejado cónico azul Celestia
	var roof := MeshInstance3D.new()
	var rf_mesh := CylinderMesh.new()
	rf_mesh.top_radius = 0.0
	rf_mesh.bottom_radius = 0.28
	rf_mesh.height = 0.35
	rf_mesh.radial_segments = 8
	roof.mesh = rf_mesh
	roof.material_override = mat_celestia_blue
	roof.position.y = 1.08
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tower.add_child(roof)

	# Luz omnidireccional del faro
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.40)
	light.light_energy = 2.2
	light.omni_range = 2.8
	light.position = Vector3(0.0, 0.88, 0.0)
	tower.add_child(light)

	# ─── 4. CARGA, BARRILES Y ANCLA EN EL MUELLE ─────────────────────────────
	# Cajas de madera
	var crate1 := MeshInstance3D.new()
	var cr1_mesh := BoxMesh.new()
	cr1_mesh.size = Vector3(0.18, 0.18, 0.18)
	crate1.mesh = cr1_mesh
	crate1.material_override = mat_pier_wood
	crate1.position = Vector3(-0.35, 0.22, 0.25)
	crate1.rotation_degrees = Vector3(0, 18, 0)
	crate1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(crate1)

	var crate2 := MeshInstance3D.new()
	var cr2_mesh := BoxMesh.new()
	cr2_mesh.size = Vector3(0.14, 0.14, 0.14)
	crate2.mesh = cr2_mesh
	crate2.material_override = mat_dark_timber
	crate2.position = Vector3(-0.35, 0.38, 0.25)
	crate2.rotation_degrees = Vector3(0, 32, 0)
	crate2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(crate2)

	# Barril de pescado/ron
	var barrel := MeshInstance3D.new()
	var br_mesh := CylinderMesh.new()
	br_mesh.top_radius = 0.07
	br_mesh.bottom_radius = 0.07
	br_mesh.height = 0.20
	br_mesh.radial_segments = 6
	barrel.mesh = br_mesh
	barrel.material_override = mat_dark_timber
	barrel.position = Vector3(-0.18, 0.23, 0.40)
	barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(barrel)

	# Ancla de hierro apoyada contra el muelle
	var anchor := MeshInstance3D.new()
	var ac_mesh := BoxMesh.new()
	ac_mesh.size = Vector3(0.06, 0.26, 0.06)
	anchor.mesh = ac_mesh
	anchor.material_override = mat_iron
	anchor.position = Vector3(-0.06, 0.20, 0.38)
	anchor.rotation_degrees = Vector3(20, 0, 15)
	anchor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(anchor)
