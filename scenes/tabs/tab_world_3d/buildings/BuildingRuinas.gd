# BuildingRuinas.gd
# ─────────────────────────────────────────────────────────────────────────────
# Geometría procedural low-poly del marcador de RUINAS (`cell.item ==
# "ruinas"`): columna caída + losa rota, en piedra arenosa desértica.
#
# Extraído de TabWorld3D.gd::_make_marker. Ver también BuildingCueva.gd
# (variante estándar, `cell.item == "cueva"`, mismo `elif` en el llamante).
# ─────────────────────────────────────────────────────────────────────────────
class_name BuildingRuinas
extends RefCounted


## Construye las ruinas caídas dentro de `container`. `style` es el override
## visual OPCIONAL de (Design.get_classic_building_style("ruinas")):
## `wall_color` sobreescribe la piedra arenosa.
static func build(container: Node3D, style: Dictionary = {}) -> void:
	# Columna caída rota
	var broken_col := MeshInstance3D.new()
	var col_mesh := CylinderMesh.new()
	col_mesh.top_radius = 0.08
	col_mesh.bottom_radius = 0.08
	col_mesh.height = 0.55
	col_mesh.radial_segments = 12
	broken_col.mesh = col_mesh
	var r_mat := StandardMaterial3D.new()
	var _wall_ovr: String = String(style.get("wall_color", ""))
	r_mat.albedo_color = Color(_wall_ovr) if _wall_ovr != "" else Color(0.68, 0.62, 0.52) # Piedra arenosa
	r_mat.roughness = 0.9
	broken_col.material_override = r_mat
	# Tumbada en el suelo
	broken_col.rotation_degrees = Vector3(75, 35, 10)
	broken_col.position = Vector3(-0.15, 0.08, -0.1)
	broken_col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(broken_col)

	# Losa rota
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(0.5, 0.1, 0.6)
	slab.mesh = slab_mesh
	slab.material_override = r_mat
	slab.rotation_degrees = Vector3(15, -45, 5)
	slab.position = Vector3(0.3, 0.05, 0.25)
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(slab)
