# BuildingAldea.gd
# ─────────────────────────────────────────────────────────────────────────────
# Geometría procedural low-poly del marcador de ALDEA (`cell.item == "aldea"`):
# 3 casitas sencillas con tejado de madera/paja, más modesta que una ciudad.
#
# Extraído de TabWorld3D.gd::_make_marker (antes un único fichero de ~6000
# líneas con TODOS los edificios mezclados) para que cada maqueta se localice
# y edite en su propio fichero, sin tocar código no relacionado.
# ─────────────────────────────────────────────────────────────────────────────
class_name BuildingAldea
extends RefCounted


## Construye la aldea dentro de `container`. `col_plaster` es la paleta
## compartida de _make_marker (mismo aspecto que otras maquetas low-poly).
## `style` es el override visual OPCIONAL de ## (Design.get_classic_building_style("aldea")): solo se lee `roof_color` aquí
## (el color de pared ya llega sobreescrito en `col_plaster` desde el llamante).
static func build(container: Node3D, col_plaster: Color, style: Dictionary = {}) -> void:
	var plas_mat := StandardMaterial3D.new()
	plas_mat.albedo_color = col_plaster
	plas_mat.roughness = 0.85
	var roof_mat := StandardMaterial3D.new()
	var _roof_ovr: String = String(style.get("roof_color", ""))
	roof_mat.albedo_color = Color(_roof_ovr) if _roof_ovr != "" else Color(0.55, 0.35, 0.2)  # Tejado de madera/paja (humilde)
	roof_mat.roughness = 0.7
	for hd in [
		{"pos": Vector3(-0.3, 0.0, 0.16), "rot": 12.0, "s": 0.30},
		{"pos": Vector3(0.3, 0.0, 0.02), "rot": -18.0, "s": 0.26},
		{"pos": Vector3(0.02, 0.0, -0.32), "rot": 6.0, "s": 0.24},
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
		body.material_override = plas_mat
		body.position.y = s * 0.5
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		hn.add_child(body)
		var roof := MeshInstance3D.new()
		var roof_mesh := PrismMesh.new()
		roof_mesh.size = Vector3(s + 0.06, s * 0.6, s + 0.06)
		roof.mesh = roof_mesh
		roof.material_override = roof_mat
		roof.position.y = s + s * 0.3
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		hn.add_child(roof)
