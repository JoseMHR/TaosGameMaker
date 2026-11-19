# BuildingCiudad.gd
# ─────────────────────────────────────────────────────────────────────────────
# Geometría procedural low-poly del marcador de CIUDAD (`cell.item ==
# "ciudad"`): 2 casas + castillo/torre central + 3 casas extra + 2 torretas de
# esquina, para dar aspecto de urbe grande. Escala el `container` un 15% (una
# ciudad se ve más grande que una aldea).
#
# Extraído de TabWorld3D.gd::_make_marker (antes un único fichero de ~6000
# líneas con TODOS los edificios mezclados) para que cada maqueta se localice
# y edite en su propio fichero, sin tocar código no relacionado.
# ─────────────────────────────────────────────────────────────────────────────
class_name BuildingCiudad
extends RefCounted


## Construye la ciudad dentro de `container`. `col_plaster`/`col_roof` son la
## paleta compartida de _make_marker (mismo aspecto que otras maquetas low-poly).
static func build(container: Node3D, col_plaster: Color, col_roof: Color) -> void:
	container.scale = Vector3.ONE * 1.15   # Una ciudad se ve más grande que una aldea

	# Casa 1 (izquierda)
	var h1 := Node3D.new()
	h1.position = Vector3(-0.35, 0.0, 0.2)
	h1.rotation_degrees.y = 15
	container.add_child(h1)
	# Paredes
	var h1_body := MeshInstance3D.new()
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(0.38, 0.38, 0.38)
	h1_body.mesh = h_mesh
	var plas_mat := StandardMaterial3D.new()
	plas_mat.albedo_color = col_plaster
	plas_mat.roughness = 0.8
	h1_body.material_override = plas_mat
	h1_body.position.y = 0.19
	h1_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	h1.add_child(h1_body)
	# Tejado
	var h1_roof := MeshInstance3D.new()
	var r_mesh := PrismMesh.new()
	r_mesh.size = Vector3(0.42, 0.22, 0.42)
	h1_roof.mesh = r_mesh
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = col_roof
	r_mat.roughness = 0.5
	h1_roof.material_override = r_mat
	h1_roof.position.y = 0.38 + 0.11
	h1_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	h1.add_child(h1_roof)

	# Casa 2 (derecha)
	var h2 := Node3D.new()
	h2.position = Vector3(0.35, 0.0, 0.3)
	h2.rotation_degrees.y = -25
	container.add_child(h2)
	# Paredes
	var h2_body := MeshInstance3D.new()
	h2_body.mesh = h_mesh
	h2_body.material_override = plas_mat
	h2_body.position.y = 0.19
	h2_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	h2.add_child(h2_body)
	# Tejado
	var h2_roof := MeshInstance3D.new()
	h2_roof.mesh = r_mesh
	h2_roof.material_override = r_mat
	h2_roof.position.y = 0.38 + 0.11
	h2_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	h2.add_child(h2_roof)

	# Castillo / Torre central
	var tower := Node3D.new()
	tower.position = Vector3(0.0, 0.0, -0.22)
	container.add_child(tower)
	# Cuerpo cilindro
	var t_body := MeshInstance3D.new()
	var t_cyl := CylinderMesh.new()
	t_cyl.top_radius = 0.18
	t_cyl.bottom_radius = 0.18
	t_cyl.height = 0.85
	t_cyl.radial_segments = 12
	t_body.mesh = t_cyl
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.48, 0.50, 0.52) # Piedra gris torre
	stone_mat.roughness = 0.7
	t_body.material_override = stone_mat
	t_body.position.y = 0.425
	t_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tower.add_child(t_body)
	# Tejado cónico torre
	var t_roof := MeshInstance3D.new()
	var tc_mesh := CylinderMesh.new()
	tc_mesh.top_radius = 0.0
	tc_mesh.bottom_radius = 0.22
	tc_mesh.height = 0.30
	tc_mesh.radial_segments = 12
	t_roof.mesh = tc_mesh
	var tr_mat := StandardMaterial3D.new()
	tr_mat.albedo_color = Color(0.2, 0.45, 0.72) # Tejado azul para la torre del castillo
	tr_mat.roughness = 0.5
	t_roof.material_override = tr_mat
	t_roof.position.y = 0.85 + 0.15
	t_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tower.add_child(t_roof)

	# Extras: más casas + torretas de esquina para dar aspecto de urbe grande.
	var city_plas := StandardMaterial3D.new()
	city_plas.albedo_color = col_plaster
	city_plas.roughness = 0.8
	var city_roof := StandardMaterial3D.new()
	city_roof.albedo_color = col_roof
	city_roof.roughness = 0.5
	for hd in [
		{"pos": Vector3(-0.6, 0.0, -0.28), "rot": 30.0, "s": 0.42},
		{"pos": Vector3(0.62, 0.0, -0.1), "rot": -35.0, "s": 0.42},
		{"pos": Vector3(0.05, 0.0, 0.58), "rot": 8.0, "s": 0.38},
	]:
		var hn := Node3D.new()
		hn.position = hd["pos"]
		hn.rotation_degrees.y = hd["rot"]
		container.add_child(hn)
		var s: float = hd["s"]
		var body := MeshInstance3D.new()
		var body_mesh := BoxMesh.new()
		body_mesh.size = Vector3(s, s, s)
		body.mesh = body_mesh
		body.material_override = city_plas
		body.position.y = s * 0.5
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		hn.add_child(body)
		var roof := MeshInstance3D.new()
		var roof_mesh := PrismMesh.new()
		roof_mesh.size = Vector3(s + 0.06, s * 0.55, s + 0.06)
		roof.mesh = roof_mesh
		roof.material_override = city_roof
		roof.position.y = s + s * 0.28
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		hn.add_child(roof)
	var turret_mat := StandardMaterial3D.new()
	turret_mat.albedo_color = Color(0.5, 0.52, 0.55)
	turret_mat.roughness = 0.7
	for tx in [-1, 1]:
		var turret := MeshInstance3D.new()
		var turret_mesh := CylinderMesh.new()
		turret_mesh.top_radius = 0.09
		turret_mesh.bottom_radius = 0.11
		turret_mesh.height = 0.62
		turret_mesh.radial_segments = 8
		turret.mesh = turret_mesh
		turret.material_override = turret_mat
		turret.position = Vector3(0.62 * tx, 0.31, 0.52)
		turret.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(turret)
