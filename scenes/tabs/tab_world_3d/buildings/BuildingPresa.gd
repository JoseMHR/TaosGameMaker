# BuildingPresa.gd
# ─────────────────────────────────────────────────────────────────────────────
# Geometría procedural low-poly del marcador de la PRESA (`cell.item == "presa"`):
# un muro de contención escalonado de hormigón que cruza la casilla de lado a
# lado, con una compuerta metálica oxidada cerrada en el centro. Sustituye a la
# maqueta genérica de templo (que no comunicaba "presa") para que la localización
# `poi_presa_001` se reconozca a simple vista.
#
# Sigue el mismo patrón que el resto de `Building<Nombre>.gd` de esta carpeta:
# recibe el `container` ya rotado/posicionado por el llamante y añade su propia
# geometría dentro.
# ─────────────────────────────────────────────────────────────────────────────
class_name BuildingPresa
extends RefCounted


## Construye la geometría de la presa dentro de `container`. `cell` no se usa
## todavía (la presa no tiene variantes por `event_id`), pero se recibe para
## mantener la misma firma que el resto de maquetas. `style` es el override
## visual OPCIONAL de (Design.get_classic_building_style("presa")):
## `wall_color` sobreescribe el hormigón (la variante oscura se deriva
## oscureciéndolo, y la compuerta oxidada no es editable).
static func build(container: Node3D, _cell: CellResource, style: Dictionary = {}) -> void:
	var _wall_ovr: String = String(style.get("wall_color", ""))
	var col_concrete := Color(_wall_ovr) if _wall_ovr != "" else Color(0.62, 0.62, 0.58)
	var col_concrete_dark := col_concrete.darkened(0.25) if _wall_ovr != "" else Color(0.46, 0.46, 0.43)
	var col_rust := Color(0.36, 0.22, 0.14)

	var concrete_mat := StandardMaterial3D.new()
	concrete_mat.albedo_color = col_concrete
	concrete_mat.roughness = 0.9

	var concrete_dark_mat := StandardMaterial3D.new()
	concrete_dark_mat.albedo_color = col_concrete_dark
	concrete_dark_mat.roughness = 0.9

	# Muro principal: bloque ancho que cruza toda la casilla (como el tablero de
	# un puente), escalonado en dos alturas para simular el contrafuerte típico
	# de una presa de gravedad.
	var base_wall := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.35, 0.55, 2.0 * 0.98)
	base_wall.mesh = base_mesh
	base_wall.material_override = concrete_mat
	base_wall.position.y = 0.275
	base_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(base_wall)

	var upper_wall := MeshInstance3D.new()
	var upper_mesh := BoxMesh.new()
	upper_mesh.size = Vector3(0.85, 0.35, 2.0 * 0.98)
	upper_wall.mesh = upper_mesh
	upper_wall.material_override = concrete_dark_mat
	upper_wall.position.y = 0.55 + 0.175
	upper_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(upper_wall)

	# Contrafuertes: dos apoyos triangulares en los extremos que refuerzan el muro.
	for z_side in [-1, 1]:
		var buttress := MeshInstance3D.new()
		var buttress_mesh := PrismMesh.new()
		buttress_mesh.size = Vector3(0.55, 0.55, 0.5)
		buttress.mesh = buttress_mesh
		buttress.material_override = concrete_dark_mat
		buttress.rotation.z = deg_to_rad(90) * (1 if z_side > 0 else -1)
		buttress.rotation.y = deg_to_rad(90)
		buttress.position = Vector3(0.55, 0.275, z_side * (2.0 * 0.98 * 0.5 - 0.25))
		buttress.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(buttress)

	# Compuerta metálica oxidada, cerrada, en el centro del muro.
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = col_rust
	gate_mat.roughness = 0.6
	gate_mat.metallic = 0.35

	var gate := MeshInstance3D.new()
	var gate_mesh := BoxMesh.new()
	gate_mesh.size = Vector3(0.42, 0.44, 0.10)
	gate.mesh = gate_mesh
	gate.material_override = gate_mat
	gate.position = Vector3(0.70, 0.22, 0.0)
	gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(gate)

	# Barras horizontales de la compuerta (rejilla oxidada).
	for i in range(3):
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(0.44, 0.035, 0.14)
		bar.mesh = bar_mesh
		bar.material_override = gate_mat
		bar.position = Vector3(0.71, 0.10 + i * 0.14, 0.0)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(bar)

	# Manivela/rueda de la compuerta, encima del muro.
	var wheel := MeshInstance3D.new()
	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.06
	wheel_mesh.outer_radius = 0.11
	wheel.mesh = wheel_mesh
	wheel.material_override = gate_mat
	wheel.rotation.x = deg_to_rad(90)
	wheel.position = Vector3(0.70, 0.55 + 0.16, 0.0)
	wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.add_child(wheel)

	# Barandilla de la pasarela superior (postes low-poly, como en los puentes).
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = col_concrete_dark
	rail_mat.roughness = 0.8
	for z_pos in [-0.85, -0.28, 0.28, 0.85]:
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.03
		post_mesh.bottom_radius = 0.03
		post_mesh.height = 0.22
		post_mesh.radial_segments = 8
		post.mesh = post_mesh
		post.material_override = rail_mat
		post.position = Vector3(-0.35, 0.55 + 0.11, z_pos)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(post)
