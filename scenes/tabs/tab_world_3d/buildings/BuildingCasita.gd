# BuildingCasita.gd
# ─────────────────────────────────────────────────────────────────────────────
# Geometría procedural low-poly del marcador de CASITA (`cell.item ==
# "casita"`): casa individual de adobe con puerta + un pequeño ranchito (corral
# de postes de madera) al lado.
#
# Extraído de TabWorld3D.gd::_make_marker (antes un único fichero de ~6000
# líneas con TODOS los edificios mezclados) para que cada maqueta se localice
# y edite en su propio fichero, sin tocar código no relacionado.
# ─────────────────────────────────────────────────────────────────────────────
class_name BuildingCasita
extends RefCounted


## Construye la casita dentro de `container`. `col_wood` es la paleta
## compartida de _make_marker (mismo aspecto que otras maquetas low-poly).
## `style` es el override visual OPCIONAL de ## (Design.get_classic_building_style("casita")): `wall_color`/`roof_color`.
## `decorated` añade macetas floridas, farolillos encendidos junto a la puerta
## y un banderín en el tejado (Base Nivel 5-6, ver `GenericMarkers.make_marker`).
static func build(container: Node3D, col_wood: Color, style: Dictionary = {}, decorated: bool = false) -> void:
	var plas_mat := StandardMaterial3D.new()
	var _wall_ovr: String = String(style.get("wall_color", ""))
	plas_mat.albedo_color = Color(_wall_ovr) if _wall_ovr != "" else Color(0.86, 0.80, 0.68)  # Adobe cálido
	plas_mat.roughness = 0.85
	var roof_mat := StandardMaterial3D.new()
	var _roof_ovr: String = String(style.get("roof_color", ""))
	roof_mat.albedo_color = Color(_roof_ovr) if _roof_ovr != "" else Color(0.5, 0.28, 0.16)   # Tejado marrón
	roof_mat.roughness = 0.7
	var house := Node3D.new()
	house.position = Vector3(-0.12, 0.0, -0.05)
	container.add_child(house)
	var c_body := MeshInstance3D.new()
	var c_body_mesh := BoxMesh.new()
	c_body_mesh.size = Vector3(0.42, 0.34, 0.42)
	c_body.mesh = c_body_mesh
	c_body.material_override = plas_mat
	c_body.position.y = 0.17
	c_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	house.add_child(c_body)
	var c_roof := MeshInstance3D.new()
	var c_roof_mesh := PrismMesh.new()
	c_roof_mesh.size = Vector3(0.5, 0.26, 0.5)
	c_roof.mesh = c_roof_mesh
	c_roof.material_override = roof_mat
	c_roof.position.y = 0.34 + 0.13
	c_roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	house.add_child(c_roof)
	var door := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.12, 0.18, 0.02)
	door.mesh = door_mesh
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.3, 0.18, 0.1)
	door.material_override = door_mat
	door.position = Vector3(0.0, 0.09, 0.215)
	house.add_child(door)
	# Ranchito: un pequeño corral de postes de madera al lado de la casa.
	var fence_mat := StandardMaterial3D.new()
	fence_mat.albedo_color = col_wood
	for pp in [
		Vector3(0.22, 0.0, 0.30), Vector3(0.44, 0.0, 0.30),
		Vector3(0.44, 0.0, 0.08), Vector3(0.44, 0.0, -0.14),
		Vector3(0.22, 0.0, -0.14),
	]:
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.018
		post_mesh.bottom_radius = 0.018
		post_mesh.height = 0.16
		post_mesh.radial_segments = 6
		post.mesh = post_mesh
		post.material_override = fence_mat
		post.position = pp + Vector3(0.0, 0.08, 0.0)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(post)

	if not decorated:
		return

	# ── VERSIÓN DECORADA (Base Nivel 5-6) ──────────────────────────────────
	# Macetas floridas flanqueando la puerta.
	var pot_mat := StandardMaterial3D.new()
	pot_mat.albedo_color = Color(0.55, 0.32, 0.2)
	pot_mat.roughness = 0.9
	var flower_mat := StandardMaterial3D.new()
	flower_mat.albedo_color = Color(0.92, 0.35, 0.45)
	flower_mat.emission_enabled = true
	flower_mat.emission = Color(0.92, 0.35, 0.45)
	flower_mat.emission_energy_multiplier = 0.4
	for side in [-1, 1]:
		var pot := MeshInstance3D.new()
		var pot_mesh := CylinderMesh.new()
		pot_mesh.top_radius = 0.035
		pot_mesh.bottom_radius = 0.028
		pot_mesh.height = 0.06
		pot.mesh = pot_mesh
		pot.material_override = pot_mat
		pot.position = house.position + Vector3(0.11 * side, 0.03, 0.225)
		pot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(pot)
		var flower := MeshInstance3D.new()
		var flower_mesh := SphereMesh.new()
		flower_mesh.radius = 0.03
		flower_mesh.height = 0.05
		flower.mesh = flower_mesh
		flower.material_override = flower_mat
		flower.position = pot.position + Vector3(0.0, 0.055, 0.0)
		container.add_child(flower)

	# Farolillos encendidos junto a la puerta.
	var lantern_mat := StandardMaterial3D.new()
	lantern_mat.albedo_color = Color(1.0, 0.75, 0.35)
	lantern_mat.emission_enabled = true
	lantern_mat.emission = Color(1.0, 0.75, 0.35)
	lantern_mat.emission_energy_multiplier = 1.6
	for side in [-1, 1]:
		var lantern := MeshInstance3D.new()
		var lantern_mesh := SphereMesh.new()
		lantern_mesh.radius = 0.025
		lantern_mesh.height = 0.045
		lantern.mesh = lantern_mesh
		lantern.material_override = lantern_mat
		lantern.position = house.position + Vector3(0.15 * side, 0.22, 0.22)
		container.add_child(lantern)
		var lantern_light := OmniLight3D.new()
		lantern_light.light_color = Color(1.0, 0.75, 0.35)
		lantern_light.light_energy = 0.5
		lantern_light.omni_range = 1.2
		lantern_light.position = lantern.position
		container.add_child(lantern_light)

	# Banderín en la cumbrera del tejado.
	var flag_pole := MeshInstance3D.new()
	var flag_pole_mesh := CylinderMesh.new()
	flag_pole_mesh.top_radius = 0.008
	flag_pole_mesh.bottom_radius = 0.008
	flag_pole_mesh.height = 0.16
	flag_pole.mesh = flag_pole_mesh
	var pole_mat2 := StandardMaterial3D.new()
	pole_mat2.albedo_color = col_wood
	flag_pole.material_override = pole_mat2
	flag_pole.position = house.position + Vector3(0.0, 0.34 + 0.13 + 0.16, 0.0)
	container.add_child(flag_pole)
	var flag := MeshInstance3D.new()
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.09, 0.06, 0.004)
	flag.mesh = flag_mesh
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = Color(0.98, 0.80, 0.32)  # Dorado, acorde a UiKit.COLOR_GOLD_PRIMARY
	flag.material_override = flag_mat
	flag.position = flag_pole.position + Vector3(0.05, 0.06, 0.0)
	container.add_child(flag)
