# BuildingTemplo.gd
# ─────────────────────────────────────────────────────────────────────────────
# Geometría procedural low-poly del marcador de TEMPLO/LUGAR (`cell.item ==
# "templo"` o `"place"`): base de mármol + 4 columnas + techo prismático. El
# color del techo varía según el `event_id` concreto del templo (mago/guerrero/
# santuario por defecto).
#
# Extraído de TabWorld3D.gd::_make_marker (antes un único fichero de ~6000
# líneas con TODOS los edificios mezclados) para que cada maqueta se localice
# y edite en su propio fichero, sin tocar código no relacionado.
# ─────────────────────────────────────────────────────────────────────────────
class_name BuildingTemplo
extends RefCounted


## Construye la geometría del templo/lugar dentro de `container` (ya rotado/
## posicionado por el llamante). `cell` se usa solo para elegir el color del
## techo según su `event_id`. `style` es el override visual OPCIONAL de
## (Design.get_classic_building_style("templo")): `wall_color`
## sobreescribe el mármol de base/columnas, `roof_color` sobreescribe la
## selección por `event_id` de más abajo.
static func build(container: Node3D, cell: CellResource, style: Dictionary = {}) -> void:
	# Base de mármol
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.15, 0.08, 1.15)
	base.mesh = base_mesh
	var stone_mat := StandardMaterial3D.new()
	var _wall_ovr: String = String(style.get("wall_color", ""))
	stone_mat.albedo_color = Color(_wall_ovr) if _wall_ovr != "" else Color(0.88, 0.88, 0.85) # Mármol claro
	stone_mat.roughness = 0.5
	base.material_override = stone_mat
	base.position.y = 0.04
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(base)

	# 4 columnas
	var col_mat := stone_mat
	for x in [-1, 1]:
		for z in [-1, 1]:
			var col := MeshInstance3D.new()
			var col_mesh := CylinderMesh.new()
			col_mesh.top_radius = 0.045
			col_mesh.bottom_radius = 0.055
			col_mesh.height = 0.55
			col_mesh.radial_segments = 12
			col.mesh = col_mesh
			col.material_override = col_mat
			col.position = Vector3(0.42 * x, 0.08 + 0.275, 0.42 * z)
			col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			container.add_child(col)

	# Techo prismático triangular
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(1.22, 0.32, 1.22)
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()

	# Color del tejado: el override (si existe) manda sobre la selección por
	# `event_id` de siempre.
	var _roof_ovr: String = String(style.get("roof_color", ""))
	if _roof_ovr != "":
		roof_mat.albedo_color = Color(_roof_ovr)
	elif cell.event_id == "poi_temple_002":
		roof_mat.albedo_color = Color(0.5, 0.2, 0.7) # Púrpura mago
	elif cell.event_id == "poi_temple_001":
		roof_mat.albedo_color = Color(0.85, 0.65, 0.15) # Oro guerrero
	else:
		roof_mat.albedo_color = Color(0.75, 0.22, 0.18) # Rojo santuario

	roof_mat.roughness = 0.4
	roof.material_override = roof_mat
	roof.position = Vector3(0.0, 0.08 + 0.55 + 0.16, 0.0)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(roof)
