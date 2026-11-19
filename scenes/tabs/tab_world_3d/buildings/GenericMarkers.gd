# GenericMarkers.gd
# ─────────────────────────────────────────────────────────────────────────────
# Geometría procedural low-poly de los marcadores "genéricos" del mapamundi que
# NO tienen su propia maqueta dedicada (puente/muelle/campamento/hoguera/objeto
# interactivo/construcción de campamento/bosque/cantera/ganado/árboles marchitos/
# montaña/fallback). Los 6 edificios grandes (ciudad/aldea/casita/templo/cueva/
# ruinas) siguen viviendo en su propio fichero `Building<Nombre>.gd` en esta
# misma carpeta y se invocan desde aquí.
#
# Extraído de TabWorld3D.gd (antes `_make_marker`, dentro del #region
# "CONSTRUCCIÓN DE CASILLAS 3D" de un único fichero de ~3800 líneas). A
# diferencia de los sistemas de tab_world_3d/interactive/, esta función es PURA
# (solo depende de `cell` + los singletons Design/GlobalState): no necesita
# `world: Node` como parámetro.
# ─────────────────────────────────────────────────────────────────────────────
class_name GenericMarkers
extends RefCounted


## Crea el marcador de una localización en 3D (Sprite3D con la imagen 2D o fallback de cubos/cilindros).
static func make_marker(cell: CellResource) -> Node3D:
	var container := Node3D.new()
	var has_model := false
	
	# Colores base para la paleta low-poly
	var col_wood := Color(0.28, 0.18, 0.12)
	var col_leaves := Color(0.18, 0.42, 0.20)
	var col_stone := Color(0.36, 0.38, 0.40)
	var col_plaster := Color(0.90, 0.88, 0.82)
	var col_roof := Color(0.75, 0.28, 0.22)

	# 0. ASSET MODEL 3D (.glb / .gltf / .tscn / .obj) — Carga desde assets/common/models/ (buildings/decorations)
	var _building_def := (Design.get_world_building(cell.item) if cell.item != "" else {})
	var _model_path := ""
	var _m_scale := 1.0
	var _m_y_offset := 0.0

	# 0a. CAMPAMENTO / BASE: aspecto evolutivo según el nivel de campamento (GlobalState.camp_level)
	# Niveles 1-2: Tienda de campaña (base_tienda)
	# Niveles 3-4: Casita de madera simple (poi_house)
	# Niveles 5+: Casita con mayor nivel de detalle / decorada (poi_house_deco)
	if cell.resource == "base" or cell.event_id == "base" or cell.item == "base":
		if GlobalState.camp_level >= 5:
			_model_path = "poi_house_deco"
		elif GlobalState.camp_level >= 3:
			_model_path = "poi_house"
		else:
			_model_path = "base_tienda"
	elif not _building_def.is_empty():
		_model_path = String(_building_def.get("model_path", _building_def.get("scene", "")))
		_m_scale = float(_building_def.get("scale", 1.0))
		_m_y_offset = float(_building_def.get("y_offset", 0.0))
	elif cell.resource != "":
		var _res_def := Design.get_world_resource(cell.resource)
		if not _res_def.is_empty() and (_res_def.has("model_path") or _res_def.has("scene")):
			_model_path = String(_res_def.get("model_path", _res_def.get("scene", "")))
			_m_scale = float(_res_def.get("scale", 1.0))
			_m_y_offset = float(_res_def.get("y_offset", 0.0))

	# Si no hay ruta explícita configurada, resolver inteligentemente según evento, tipo y objeto
	if _model_path == "":
		if cell.event_id != "" and (ModelLoader.has_model(cell.event_id) or ModelLoader.resolve_path(cell.event_id) != ""):
			_model_path = cell.event_id
		elif cell.event_id == "poi_presa_001" or cell.item == "presa":
			_model_path = "presa"
		elif cell.event_id == "poi_monkey_001" or cell.event_id == "south_bridge" or cell.item == "puente":
			_model_path = "puente"
		elif cell.event_id in ["poi_celestia_puerto", "poi_port_celestia"] or cell.event_id.begins_with("poi_port") or cell.event_id.ends_with("_puerto") or cell.item == "puerto":
			_model_path = "puerto"
		elif cell.resource == "fish" or cell.item == "pesca":
			_model_path = "pesca"
		elif cell.event_id.begins_with("house_") or cell.item == "casita":
			_model_path = "poi_house"
		elif cell.event_id.begins_with("poi_temple_") or cell.item == "templo":
			var eid_low := cell.event_id.to_lower()
			if "arquero" in eid_low or "archer" in eid_low:
				_model_path = "temploArquero"
			elif "elemental" in eid_low:
				_model_path = "temploElementalista"
			elif "guerrero" in eid_low or "warrior" in eid_low:
				_model_path = "temploGuerrero"
			elif "psiquico" in eid_low or "psychic" in eid_low:
				_model_path = "temploPsiquico"
			elif "sacerdote" in eid_low or "priest" in eid_low or "healer" in eid_low:
				_model_path = "temploSacerdote"
			elif "tiempo" in eid_low or "time" in eid_low or "chrono" in eid_low:
				_model_path = "temploTiempo"
			else:
				_model_path = "templo"
		elif cell.event_id.begins_with("sendero_"):
			_model_path = "sendero"
		elif cell.event_id.begins_with("dun_") or cell.item == "cueva":
			_model_path = "cueva"
		elif cell.event_id.begins_with("poi_tumba") or cell.item == "poi_tumba":
			_model_path = "poi_tumba"
		elif cell.event_id.begins_with("poi_") or cell.event_id.begins_with("npc_") or cell.item in ["place", "ruinas"]:
			_model_path = "poi_general"
		elif (cell.resource == "base" or cell.event_id == "base" or cell.item == "base") and GlobalState.camp_level >= 5:
			_model_path = "poi_house_deco"
		elif (cell.resource == "base" or cell.event_id == "base" or cell.item == "base") and GlobalState.camp_level >= 3:
			_model_path = "poi_house"
		elif cell.resource == "base" or cell.event_id == "base" or cell.item == "base":
			_model_path = "base_tienda"
		elif cell.resource == "campfire":
			_model_path = "hoguera"
		elif cell.event_id == "camp_dummy" or cell.resource == "dummy" or cell.item == "dummy":
			_model_path = "camp_dummy"
		elif (cell.chest is Dictionary and not cell.chest.is_empty()) or cell.item == "chest" or cell.event_id == "chest" or cell.event_id == "camp_chest" or cell.resource == "chest":
			_model_path = "cofre"
			_m_scale = 0.8
		elif cell.event_id == "camp_board" or cell.resource == "board":
			_model_path = "camp_board"
		elif cell.event_id == "camp_forge" or cell.resource == "forge":
			_model_path = "camp_forge"
		elif cell.resource == "forest":
			_model_path = "bosque"
		elif cell.is_growing_crop():
			_model_path = "cultivo"
		elif cell.interactive is Dictionary and not cell.interactive.is_empty():
			var ik := String(cell.interactive.get("kind", "sign"))
			match ik:
				"tombstone": _model_path = "lapida"
				"book", "monument", "statue": _model_path = "monumento"
				_: _model_path = "cartel"
		elif cell.resource == "bloqueo_piedra" or cell.item == "bloqueo_piedra" or (cell.obstacle is Dictionary and not cell.obstacle.is_empty()):
			_model_path = "bloqueo_piedra"
		elif cell.item != "":
			_model_path = cell.item
		elif cell.resource != "" and not (cell.resource in ["forestBad", "rock", "gold", "meat", "cerdo", "cerdos", "pigs", "milk", "vaca", "vacas", "ganado", "cow"]):
			_model_path = cell.resource

	if _model_path != "":
		var _loaded_model := ModelLoader.load_model(_model_path, _m_scale, _m_y_offset)
		if _loaded_model != null:
			has_model = true
			# Si es un muelle de pesca, orientarlo automáticamente hacia la tierra firme vecina (no orilla/agua)
			if _model_path == "pesca" or cell.resource == "fish":
				var coord: Vector2i = cell.coord
				var dirs4 := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
				var land_dir := Vector2i.UP
				var found_land := false
				for d in dirs4:
					var nb: CellResource = GlobalState.hexagons_db.get(coord + d, null) as CellResource
					if nb != null and nb.terrain != "sea" and nb.terrain != "cst" and nb.terrain != "wtr" and nb.resource != "fish":
						land_dir = d
						found_land = true
						break
				if not found_land:
					for d in dirs4:
						var nb: CellResource = GlobalState.hexagons_db.get(coord + d, null) as CellResource
						if nb != null and nb.terrain != "sea" and nb.resource != "fish":
							land_dir = d
							break
				var angle := atan2(-land_dir.x, -land_dir.y)
				container.rotation.y = angle
			# Bloqueo de piedra: orientación personalizable desde el editor
			# (data/world_resources o el editor de mapas escriben `orientation`
			# en `cell.obstacle`; "horizontal" es el valor por defecto/legado).
			if _model_path == "bloqueo_piedra":
				var orientation: String = String(cell.obstacle.get("orientation", "horizontal")) if cell.obstacle is Dictionary else "horizontal"
				if orientation == "vertical":
					container.rotation.y = deg_to_rad(90.0)
			if (cell.chest is Dictionary and not cell.chest.is_empty()) or cell.item == "chest":
				var chest_key := "world:%d:%d" % [cell.coord.x, cell.coord.y]
				var anim_player: AnimationPlayer = _loaded_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if anim_player == null:
					for ch in _loaded_model.find_children("*", "AnimationPlayer", true, false):
						if ch is AnimationPlayer:
							anim_player = ch as AnimationPlayer
							break
				if GlobalState.is_chest_opened(chest_key):
					if anim_player != null:
						if anim_player.has_animation("Chest_Opened"):
							anim_player.play("Chest_Opened")
						elif anim_player.has_animation("Chest_Open"):
							anim_player.play("Chest_Open")
							anim_player.seek(anim_player.get_animation("Chest_Open").length, true)
					_dim_model_meshes(_loaded_model)
				else:
					if anim_player != null:
						if anim_player.has_animation("Chest_Closed"):
							anim_player.play("Chest_Closed")
						elif anim_player.has_animation("Chest_Open"):
							anim_player.play("Chest_Open")
							anim_player.seek(0.0, true)
							anim_player.stop()
			container.add_child(_loaded_model)
			return container

	# 1. PUENTES (Puente del Mono y Puente del Sur, ambos cruzables)
	elif cell.event_id == "poi_monkey_001" or cell.event_id == "south_bridge":
		has_model = true
		# Calzada
		var deck := MeshInstance3D.new()
		var deck_mesh := BoxMesh.new()
		deck_mesh.size = Vector3(0.65, 0.08, 2.0)
		deck.mesh = deck_mesh
		var deck_mat := StandardMaterial3D.new()
		deck_mat.albedo_color = col_wood
		deck_mat.roughness = 0.8
		deck.material_override = deck_mat
		deck.position.y = 0.04
		deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(deck)
		
		# Postes barandilla (4 esquinas)
		var post_z_positions = [-0.9, -0.3, 0.3, 0.9]
		for side in [-1, 1]:
			var x_pos: float = 0.30 * side
			for z_pos in post_z_positions:
				var post := MeshInstance3D.new()
				var post_mesh := CylinderMesh.new()
				post_mesh.top_radius = 0.025
				post_mesh.bottom_radius = 0.025
				post_mesh.height = 0.36
				post_mesh.radial_segments = 8
				post.mesh = post_mesh
				post.material_override = deck_mat
				post.position = Vector3(x_pos, 0.18, z_pos)
				post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				container.add_child(post)
			
			# Barandilla horizontal
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(0.04, 0.04, 2.0)
			rail.mesh = rail_mesh
			rail.material_override = deck_mat
			rail.position = Vector3(x_pos, 0.32, 0.0)
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			container.add_child(rail)

	# 2. MUELLE / PESCA (pesca)
	elif cell.resource == "fish":
		has_model = true
		
		# Determinar la dirección de la tierra vecina para orientar el muelle
		var coord: Vector2i = cell.coord
		var land_types := ["empty", "gather", "dungeon", "place", "town", "base", "poi_monkey_001"]
		var dirs4 := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		var land_dir := Vector2i.UP # Dirección por defecto
		for d in dirs4:
			var nb: CellResource = GlobalState.hexagons_db.get(coord + d, null) as CellResource
			if nb and nb.type in land_types:
				land_dir = d
				break
				
		# Orientar el contenedor hacia la tierra
		var angle := atan2(-land_dir.x, -land_dir.y)
		container.rotation.y = angle
		
		# Pasarela de madera (largo 1.2, centrado en Z=-0.4 para que toque el borde Z=-1.0)
		var deck := MeshInstance3D.new()
		var deck_mesh := BoxMesh.new()
		deck_mesh.size = Vector3(0.55, 0.08, 1.2)
		deck.mesh = deck_mesh
		var deck_mat := StandardMaterial3D.new()
		deck_mat.albedo_color = col_wood
		deck_mat.roughness = 0.8
		deck.material_override = deck_mat
		deck.position = Vector3(0.0, 0.04, -0.4)
		deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(deck)
		
		# Postes finales (en el extremo de agua, Z=0.08)
		for side in [-1, 1]:
			var post := MeshInstance3D.new()
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.035
			post_mesh.bottom_radius = 0.035
			post_mesh.height = 0.32
			post_mesh.radial_segments = 8
			post.mesh = post_mesh
			post.material_override = deck_mat
			post.position = Vector3(0.24 * side, 0.16, 0.08)
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			container.add_child(post)
			
		# Barril de pesca decorativo (en el extremo de tierra, Z=-0.7)
		var barrel := MeshInstance3D.new()
		var barrel_mesh := CylinderMesh.new()
		barrel_mesh.top_radius = 0.09
		barrel_mesh.bottom_radius = 0.10
		barrel_mesh.height = 0.22
		barrel_mesh.radial_segments = 12
		barrel.mesh = barrel_mesh
		var barrel_mat := StandardMaterial3D.new()
		barrel_mat.albedo_color = Color(0.22, 0.14, 0.08)
		barrel.material_override = barrel_mat
		barrel.position = Vector3(0.16, 0.11, -0.7)
		barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(barrel)

		# Peces saltando en el agua (más allá de la pasarela)
		add_jumping_fish(container)

	# 3. CAMPAMENTO / BASE (base) — Nivel 3-6: la maqueta de casita (nivel 3-4
	# sencilla, nivel 5-6 decorada con macetas/farolillos/banderín) vive como
	# escena editable en `assets/common/models/buildings/poi_house.tscn` /
	# `poi_house_deco.tscn` (ver ModelLoader/ASSET MODEL 3D arriba y
	# GameConfig.CAMP_STRUCTURES). No añadir geometría por código aquí.

	# 3. CAMPAMENTO / BASE (base) — Fallback procedimental si faltaran las escenas físicas
	elif (cell.resource == "base" or cell.event_id == "base" or cell.item == "base") and GlobalState.camp_level >= 5:
		has_model = true
		BuildingCasita.build(container, col_wood, {}, true)
	elif (cell.resource == "base" or cell.event_id == "base" or cell.item == "base") and GlobalState.camp_level >= 3:
		has_model = true
		BuildingCasita.build(container, col_wood, {}, false)
	elif (cell.resource == "base" or cell.event_id == "base" or cell.item == "base"):
		has_model = true
		# Tienda de campaña (prisma horizontal)
		var tent := MeshInstance3D.new()
		var tent_mesh := PrismMesh.new()
		tent_mesh.size = Vector3(0.75, 0.65, 0.9)
		tent.mesh = tent_mesh
		var tent_mat := StandardMaterial3D.new()
		tent_mat.albedo_color = Color(0.88, 0.42, 0.15) # Naranja vibrante
		tent_mat.roughness = 0.7
		tent.material_override = tent_mat
		# Rotar para alinear el túnel con el eje Z
		tent.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		tent.position = Vector3(-0.25, 0.325, -0.05)
		tent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(tent)
		
		# Postes frontales de la tienda
		for side in [-1, 1]:
			var pole := MeshInstance3D.new()
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.015
			pole_mesh.bottom_radius = 0.015
			pole_mesh.height = 0.62
			pole.mesh = pole_mesh
			var pole_mat := StandardMaterial3D.new()
			pole_mat.albedo_color = col_wood
			pole.material_override = pole_mat
			pole.position = Vector3(-0.25, 0.31, 0.4 * side)
			pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			container.add_child(pole)
		# NOTA: la tienda NO dibuja fogata. La HOGUERA es un item físico aparte, en
		# su propia casilla (a la derecha), para no duplicar el fuego (ver 3b).

	# 3b. HOGUERA (campfire) — item físico separado, para COCINAR. Círculo de
	# piedras + leños cruzados + fuego emisivo + una olla sobre un trípode.
	elif cell.resource == "campfire":
		has_model = true
		# Círculo de piedras
		for i in range(6):
			var stone := MeshInstance3D.new()
			var stone_mesh := SphereMesh.new()
			stone_mesh.radius = 0.06
			stone_mesh.height = 0.09
			stone.mesh = stone_mesh
			var stone_mat := StandardMaterial3D.new()
			stone_mat.albedo_color = col_stone
			stone_mat.roughness = 0.95
			stone.material_override = stone_mat
			var ang := i * TAU / 6.0
			stone.position = Vector3(cos(ang) * 0.24, 0.03, sin(ang) * 0.24)
			stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			container.add_child(stone)
		# Leños cruzados
		for i in range(3):
			var log_inst := MeshInstance3D.new()
			var log_mesh := CylinderMesh.new()
			log_mesh.top_radius = 0.028
			log_mesh.bottom_radius = 0.028
			log_mesh.height = 0.34
			log_inst.mesh = log_mesh
			var log_mat := StandardMaterial3D.new()
			log_mat.albedo_color = Color(0.2, 0.12, 0.08)
			log_inst.material_override = log_mat
			log_inst.rotation_degrees = Vector3(0, i * 60, 90)
			log_inst.position.y = 0.05
			log_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			container.add_child(log_inst)
		# Fuego (esfera luminiscente, mayor que la de la tienda)
		var fire := MeshInstance3D.new()
		var fire_mesh := SphereMesh.new()
		fire_mesh.radius = 0.14
		fire_mesh.height = 0.26
		fire.mesh = fire_mesh
		var fire_mat := StandardMaterial3D.new()
		fire_mat.albedo_color = Color(1.0, 0.4, 0.05)
		fire_mat.emission_enabled = true
		fire_mat.emission = Color(1.0, 0.45, 0.05)
		fire_mat.emission_energy_multiplier = 2.4
		fire.material_override = fire_mat
		fire.position.y = 0.16
		container.add_child(fire)

		# Luz cálida que ilumina la casilla de la hoguera y las adyacentes.
		var fire_light := OmniLight3D.new()
		fire_light.name = "CampfireLight"
		fire_light.light_color = Color(1.0, 0.55, 0.12)
		fire_light.light_energy = 1.6
		fire_light.omni_range = 3.6
		fire_light.position.y = 0.35
		container.add_child(fire_light)

		# Parpadeo de llama (Timer local que varía energía y color).
		var flicker := Timer.new()
		flicker.wait_time = 0.12
		flicker.autostart = true
		flicker.timeout.connect(func() -> void:
			if not is_instance_valid(fire_light):
				return
			fire_light.light_energy = 1.3 + randf() * 0.7
			fire_light.light_color = Color(1.0, 0.50 + randf() * 0.15, 0.08 + randf() * 0.08)
			fire_mesh.radius = 0.12 + randf() * 0.04
			fire_mesh.height = 0.22 + randf() * 0.06
		)
		container.add_child(flicker)

		# Trípode + olla (señala que aquí se COCINA)
		var pot := MeshInstance3D.new()
		var pot_mesh := CylinderMesh.new()
		pot_mesh.top_radius = 0.11
		pot_mesh.bottom_radius = 0.09
		pot_mesh.height = 0.14
		pot.mesh = pot_mesh
		var pot_mat := StandardMaterial3D.new()
		pot_mat.albedo_color = Color(0.12, 0.12, 0.14)
		pot_mat.metallic = 0.6
		pot_mat.roughness = 0.5
		pot.material_override = pot_mat
		pot.position.y = 0.34
		pot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(pot)
		for side in [-1, 1]:
			var leg := MeshInstance3D.new()
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.012
			leg_mesh.bottom_radius = 0.012
			leg_mesh.height = 0.5
			leg.mesh = leg_mesh
			var leg_mat := StandardMaterial3D.new()
			leg_mat.albedo_color = col_wood
			leg.material_override = leg_mat
			leg.rotation_degrees = Vector3(0, 0, 18 * side)
			leg.position = Vector3(0.14 * side, 0.28, 0.0)
			leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			container.add_child(leg)

	# 3c. OBJETO INTERACTIVO (cartel/lápida/libro/monumento…) — modelo low-poly
	# genérico según `interactive.kind`. Reutilizable para nuevos objetos: basta con
	# añadir un `kind` aquí. Por defecto (cartel): poste + tablón de madera.
	elif cell.interactive is Dictionary and not cell.interactive.is_empty():
		has_model = true
		var kind := String(cell.interactive.get("kind", "sign"))
		match kind:
			"tombstone":
				# Lápida: losa de piedra redondeada.
				var slab := MeshInstance3D.new()
				var slab_mesh := BoxMesh.new()
				slab_mesh.size = Vector3(0.4, 0.5, 0.12)
				slab.mesh = slab_mesh
				var slab_mat := StandardMaterial3D.new()
				slab_mat.albedo_color = col_stone
				slab_mat.roughness = 0.95
				slab.material_override = slab_mat
				slab.position.y = 0.25
				slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				container.add_child(slab)
			"book", "monument", "statue":
				# Pedestal + bloque (monumento/estatua/libro sobre atril).
				var base_inst := MeshInstance3D.new()
				var base_mesh := BoxMesh.new()
				base_mesh.size = Vector3(0.44, 0.16, 0.44)
				base_inst.mesh = base_mesh
				var base_mat := StandardMaterial3D.new()
				base_mat.albedo_color = col_stone
				base_inst.material_override = base_mat
				base_inst.position.y = 0.08
				base_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				container.add_child(base_inst)
				var top := MeshInstance3D.new()
				var top_mesh := BoxMesh.new()
				top_mesh.size = Vector3(0.26, 0.34, 0.26)
				top.mesh = top_mesh
				var top_mat := StandardMaterial3D.new()
				top_mat.albedo_color = col_plaster
				top.material_override = top_mat
				top.position.y = 0.33
				top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				container.add_child(top)
			_:
				# Cartel por defecto: poste vertical + tablón horizontal.
				var post := MeshInstance3D.new()
				var post_mesh := CylinderMesh.new()
				post_mesh.top_radius = 0.035
				post_mesh.bottom_radius = 0.035
				post_mesh.height = 0.55
				post.mesh = post_mesh
				var post_mat := StandardMaterial3D.new()
				post_mat.albedo_color = col_wood
				post_mat.roughness = 0.85
				post.material_override = post_mat
				post.position.y = 0.27
				post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				container.add_child(post)
				var board := MeshInstance3D.new()
				var board_mesh := BoxMesh.new()
				board_mesh.size = Vector3(0.5, 0.28, 0.05)
				board.mesh = board_mesh
				var board_mat := StandardMaterial3D.new()
				board_mat.albedo_color = Color(0.55, 0.38, 0.18)
				board_mat.roughness = 0.8
				board.material_override = board_mat
				board.position.y = 0.48
				board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				container.add_child(board)

	# 3d. CONSTRUCCIÓN DEL CAMPAMENTO — Muñeco de Entrenamiento (modelo 3D GLTF real)
	elif cell.event_id == "camp_dummy" or cell.resource == "dummy" or cell.item == "dummy":
		has_model = true
		var dummy_model := ModelLoader.load_model("muneco_entrenamiento", 0.9)
		if dummy_model != null:
			dummy_model.position.y = 0.0
			container.add_child(dummy_model)
		else:
			var platform := MeshInstance3D.new()
			var plat_mesh := BoxMesh.new()
			plat_mesh.size = Vector3(0.6, 0.16, 0.6)
			platform.mesh = plat_mesh
			var plat_mat := StandardMaterial3D.new()
			plat_mat.albedo_color = col_wood
			plat_mat.roughness = 0.85
			platform.material_override = plat_mat
			platform.position.y = 0.08
			platform.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			container.add_child(platform)
			var glyph := Label3D.new()
			glyph.text = cell.icon if cell.icon != "" else "🎯"
			glyph.font_size = 130
			glyph.pixel_size = 0.006
			glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			glyph.position.y = 0.55
			container.add_child(glyph)

	# 3d'. HERRERÍA DE LA BASE — la maqueta (yunque/fragua/barril de agua) vive
	# como escena editable en `assets/common/models/buildings/camp_forge.tscn`
	# (ver ModelLoader/ASSET MODEL 3D arriba). Si ese archivo faltara, cae al
	# rótulo genérico "camp_*" de abajo (evitar volver a meter geometría
	# generada por código aquí, ver task3_cambiosGeneral.md).

	# 3d. CONSTRUCCIÓN DEL CAMPAMENTO (cofre/tablón…) — plataforma
	# de madera + un rótulo billboard con el icono de la construcción. Modelo
	# genérico y reutilizable: cualquier `camp_*` se dibuja igual.
	elif cell.event_id.begins_with("camp_"):
		has_model = true
		var platform := MeshInstance3D.new()
		var plat_mesh := BoxMesh.new()
		plat_mesh.size = Vector3(0.6, 0.16, 0.6)
		platform.mesh = plat_mesh
		var plat_mat := StandardMaterial3D.new()
		plat_mat.albedo_color = col_wood
		plat_mat.roughness = 0.85
		platform.material_override = plat_mat
		platform.position.y = 0.08
		platform.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(platform)
		var glyph := Label3D.new()
		glyph.text = cell.icon if cell.icon != "" else "🏕️"
		glyph.font_size = 130
		glyph.pixel_size = 0.006
		glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glyph.position.y = 0.55
		container.add_child(glyph)

	# 3e. CULTIVO (Agricultor) — pequeño montículo de tierra removida + un
	# icono billboard que pasa de plántula (🌱) a listo para cosechar (icono del
	# ingrediente que entrega) en cuanto `CellResource.is_crop_mature()` es true.
	elif cell.is_growing_crop():
		has_model = true
		var mound := MeshInstance3D.new()
		var mound_mesh := CylinderMesh.new()
		mound_mesh.top_radius = 0.38
		mound_mesh.bottom_radius = 0.44
		mound_mesh.height = 0.14
		mound.mesh = mound_mesh
		var mound_mat := StandardMaterial3D.new()
		mound_mat.albedo_color = Color(0.30, 0.20, 0.12)
		mound_mat.roughness = 0.95
		mound.material_override = mound_mat
		mound.position.y = 0.07
		mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(mound)
		var crop_glyph := Label3D.new()
		var seed_id: String = String(cell.crop.get("type", ""))
		var crop_def: Dictionary = GameConfig.CROP_TYPES.get(seed_id, {})
		if cell.is_crop_mature():
			crop_glyph.text = Design.get_item_icon(String(crop_def.get("harvest_item", "")))
		else:
			crop_glyph.text = "🌱"
		crop_glyph.font_size = 110
		crop_glyph.pixel_size = 0.005
		crop_glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		crop_glyph.position.y = 0.42
		container.add_child(crop_glyph)

	# 4. BOSQUE / ÁRBOLES (bosque)
	elif cell.resource == "forest":
		has_model = true
		# 3 pinos agrupados
		var tree_positions = [
			Vector3(-0.35, 0.0, -0.35),
			Vector3(0.35, 0.0, -0.2),
			Vector3(0.0, 0.0, 0.35)
		]
		var tree_scales = [1.8, 1.5, 2.0]
		for i in range(3):
			var tree := Node3D.new()
			tree.position = tree_positions[i]
			tree.scale = Vector3.ONE * tree_scales[i]
			container.add_child(tree)
			
			# Tronco
			var trunk := MeshInstance3D.new()
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.top_radius = 0.04
			trunk_mesh.bottom_radius = 0.05
			trunk_mesh.height = 0.32
			trunk.mesh = trunk_mesh
			var trunk_mat := StandardMaterial3D.new()
			trunk_mat.albedo_color = col_wood
			trunk.material_override = trunk_mat
			trunk.position.y = 0.16
			trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			tree.add_child(trunk)
			
			# Follaje bajo (cono)
			var foil_low := MeshInstance3D.new()
			var cone_low := CylinderMesh.new()
			cone_low.top_radius = 0.0
			cone_low.bottom_radius = 0.28
			cone_low.height = 0.35
			foil_low.mesh = cone_low
			var foil_mat := StandardMaterial3D.new()
			foil_mat.albedo_color = col_leaves
			foil_mat.roughness = 0.8
			foil_low.material_override = foil_mat
			foil_low.position.y = 0.32 + 0.175
			foil_low.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			tree.add_child(foil_low)
			
			# Follaje alto (cono)
			var foil_high := MeshInstance3D.new()
			var cone_high := CylinderMesh.new()
			cone_high.top_radius = 0.0
			cone_high.bottom_radius = 0.20
			cone_high.height = 0.28
			foil_high.mesh = cone_high
			foil_high.material_override = foil_mat
			foil_high.position.y = 0.32 + 0.25 + 0.14
			foil_high.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			tree.add_child(foil_high)

	# 5. CANTERA / MINAS (cantera de piedra o de oro) — : ya NO se
	# construye un marcador por casilla; `cell.resource` está en
	# TabWorld3D.RESOURCE_DECOR_KINDS, así que _register_one_tile() la enruta a
	# una MultiMesh compartida (ver TabWorld3D._build_shared_rock_mesh /
	# _finalize_resource_decor) y nunca llega a make_marker(). No hay rama aquí.

	# 6. PUERTO DE CELESTIA / MUELLES (item puerto / event poi_port_celestia)
	elif cell.event_id == "poi_port_celestia" or cell.event_id.begins_with("poi_port") or cell.item == "puerto":
		has_model = true
		BuildingPuerto.build(container, cell, Design.get_classic_building_style("puerto"))
		_apply_classic_scale(container, "puerto")

	# 6b. TEMPLOS Y LUGARES (item templo / place) — ver buildings/BuildingTemplo.gd
	elif cell.item == "templo" or cell.item == "place":
		has_model = true
		BuildingTemplo.build(container, cell, Design.get_classic_building_style("templo"))
		_apply_classic_scale(container, "templo")

	# 6b. PRESA (item presa) — ver buildings/BuildingPresa.gd
	elif cell.item == "presa":
		has_model = true
		BuildingPresa.build(container, cell, Design.get_classic_building_style("presa"))
		_apply_classic_scale(container, "presa")

	# 7. MAZMORRAS / CUEVAS / RUINAS (item cueva o ruinas) — ver
	# buildings/BuildingCueva.gd y buildings/BuildingRuinas.gd
	elif cell.item == "cueva" or cell.item == "ruinas":
		has_model = true
		if cell.item == "ruinas":
			BuildingRuinas.build(container, Design.get_classic_building_style("ruinas"))
			_apply_classic_scale(container, "ruinas")
		else:
			BuildingCueva.build(container, Design.get_classic_building_style("cueva"))
			_apply_classic_scale(container, "cueva")

	# 8. CIUDADES (item ciudad — versión grande y vistosa) — ver buildings/BuildingCiudad.gd
	elif cell.item == "ciudad":
		has_model = true
		var _st_ciudad := Design.get_classic_building_style("ciudad")
		BuildingCiudad.build(container,
			_color_or(_st_ciudad, "wall_color", col_plaster),
			_color_or(_st_ciudad, "roof_color", col_roof))
		_apply_classic_scale(container, "ciudad")

	# 9. ALDEA (item aldea — más modesta que una ciudad: solo casitas sencillas)
	# — ver buildings/BuildingAldea.gd
	elif cell.item == "aldea":
		has_model = true
		var _st_aldea := Design.get_classic_building_style("aldea")
		BuildingAldea.build(container, _color_or(_st_aldea, "wall_color", col_plaster), _st_aldea)
		_apply_classic_scale(container, "aldea")

	# 9b. GRANJA DE CERDOS (resource/item: meat, cerdo, cerdos, pigs)
	elif cell.resource in ["meat", "cerdo", "cerdos", "pigs"] or cell.item in ["meat", "cerdo", "cerdos", "pigs"] or cell.object == "meat":
		has_model = true
		var pig_mesh_inst := MeshInstance3D.new()
		pig_mesh_inst.name = "Animal"
		pig_mesh_inst.mesh = build_pig_mesh()
		pig_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(pig_mesh_inst)

	# 9c. GANADO LECHERO / VACAS (resource/item: milk, vaca, vacas, ganado, cow)
	elif cell.resource in ["milk", "vaca", "vacas", "ganado", "cow"] or cell.item in ["milk", "vaca", "vacas", "ganado", "cow"] or cell.object == "milk":
		has_model = true
		var cow_mesh_inst := MeshInstance3D.new()
		cow_mesh_inst.name = "Animal"
		cow_mesh_inst.mesh = build_cow_mesh()
		cow_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		container.add_child(cow_mesh_inst)

	# 9c. ÁRBOLES MARCHITOS (resource arboles_malos / forestBad — bosque escaso y seco de la nieve/yelmo)
	elif cell.resource == "forestBad":
		has_model = true
		for dd in [
			{"pos": Vector3(-0.16, 0.0, 0.10), "s": 0.22, "rot": 0.0},
			{"pos": Vector3(0.18, 0.0, -0.12), "s": 0.18, "rot": 120.0},
		]:
			var tree_inst := ModelLoader.load_model("arbol_marchito", float(dd["s"]))
			if tree_inst != null:
				tree_inst.position = dd["pos"]
				tree_inst.rotation_degrees.y = float(dd["rot"])
				container.add_child(tree_inst)
			else:
				var bark_mat := StandardMaterial3D.new()
				bark_mat.albedo_color = Color(0.35, 0.30, 0.26)
				bark_mat.roughness = 0.95
				var tree_node := Node3D.new()
				tree_node.position = dd["pos"]
				container.add_child(tree_node)
				var trunk := MeshInstance3D.new()
				var trunk_mesh := CylinderMesh.new()
				trunk_mesh.top_radius = 0.03
				trunk_mesh.bottom_radius = 0.05
				trunk_mesh.height = 0.42
				trunk.mesh = trunk_mesh
				trunk.material_override = bark_mat
				trunk.position.y = 0.21
				tree_node.add_child(trunk)

	# 9d. CASITA (item casita — casa individual con su pequeño ranchito) — la
	# maqueta vive en `assets/common/models/buildings/poi_house.tscn` (ver
	# ModelLoader/ASSET MODEL 3D arriba). No añadir geometría por código aquí.

	# 10. MONTAÑAS DECORATIVAS (terreno montaña)
	elif cell.terrain == "mnt":
		has_model = true
		var col_rock := Color(0.24, 0.25, 0.28)
		var peaks_data = [
			{
				"pos": Vector3(-0.05, 0.0, -0.15),
				"height": 1.45,
				"radius": 0.78,
				"rot_y": 0.0
			},
			{
				"pos": Vector3(-0.45, 0.0, 0.35),
				"height": 0.95,
				"radius": 0.58,
				"rot_y": 1.2
			},
			{
				"pos": Vector3(0.45, 0.0, 0.25),
				"height": 0.75,
				"radius": 0.52,
				"rot_y": -0.8
			}
		]
		for data in peaks_data:
			var peak_node := Node3D.new()
			peak_node.position = data["pos"]
			container.add_child(peak_node)
			
			var body := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = data["radius"]
			cone.height = data["height"]
			cone.radial_segments = 5
			body.mesh = cone
			
			var body_mat := StandardMaterial3D.new()
			body_mat.albedo_color = col_rock
			body_mat.roughness = 0.9
			body.material_override = body_mat
			body.position.y = data["height"] * 0.5
			body.rotation.y = data["rot_y"]
			body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			peak_node.add_child(body)
			
			var cap := MeshInstance3D.new()
			var cap_cone := CylinderMesh.new()
			cap_cone.top_radius = 0.0
			# Hacemos el sombrero un 8% más ancho que el cono en esa sección para evitar z-fighting coplanar
			cap_cone.bottom_radius = data["radius"] * 0.35 * 1.08
			cap_cone.height = data["height"] * 0.35
			cap_cone.radial_segments = 5
			cap.mesh = cap_cone
			
			var cap_mat := StandardMaterial3D.new()
			cap_mat.albedo_color = Color(0.95, 0.95, 0.95)
			cap_mat.roughness = 0.8
			cap.material_override = cap_mat
			cap.position.y = data["height"] * 0.825
			# Rotamos el sombrero 36 grados (0.628 rad) para cruzar aristas y evitar interferencias visuales
			cap.rotation.y = data["rot_y"] + 0.628
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			peak_node.add_child(cap)

	else:
		# Fallback general para cualquier otro item/recurso no previsto
		if cell.item != "" or cell.is_gather_node() or cell.resource == "base":
			has_model = true
			var base := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.5, 0.6, 0.5)
			base.mesh = box
			var base_mat := StandardMaterial3D.new()
			base_mat.albedo_color = Color(0.6, 0.5, 0.4)
			base_mat.roughness = 0.8
			base.material_override = base_mat
			base.position.y = 0.3
			base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			container.add_child(base)

	if has_model:
		return container
	else:
		container.queue_free()
		return null


## Lee `style[field]` (string hex "#rrggbb") como Color, o `fallback` si el
## campo no existe/está vacío. Usado por las 8 maquetas cableadas para aplicar
## su override visual opcional.
static func _color_or(style: Dictionary, field: String, fallback: Color) -> Color:
	var v = style.get(field, "")
	if v is String and v != "":
		return Color(v)
	return fallback


## Aplica la `scale` opcional del override de una maqueta clásica MULTIPLICANDO
## la escala que ya tenga el `container` (p. ej. BuildingCiudad se autoescala
## 1.15x): así `scale: 1.0` (o ausente) no cambia nada.
static func _apply_classic_scale(container: Node3D, code: String) -> void:
	var style := Design.get_classic_building_style(code)
	var s: float = float(style.get("scale", 1.0))
	if s != 1.0:
		container.scale *= Vector3.ONE * s


## Hornea la geometría procedural de la granja de cerdos (familia de cerdos estilizados con comedero).
static func build_pig_mesh() -> ArrayMesh:
	var pig_skin_mat := StandardMaterial3D.new()
	pig_skin_mat.albedo_color = Color(0.97, 0.72, 0.80)
	pig_skin_mat.roughness = 0.82
	pig_skin_mat.vertex_color_use_as_albedo = true

	var pig_snout_mat := StandardMaterial3D.new()
	pig_snout_mat.albedo_color = Color(0.92, 0.48, 0.62)
	pig_snout_mat.roughness = 0.75
	pig_snout_mat.vertex_color_use_as_albedo = true

	var detail_mat := StandardMaterial3D.new()
	detail_mat.albedo_color = Color(0.12, 0.10, 0.12)
	detail_mat.roughness = 0.3
	detail_mat.vertex_color_use_as_albedo = true

	var hoof_mat := StandardMaterial3D.new()
	hoof_mat.albedo_color = Color(0.38, 0.28, 0.28)
	hoof_mat.roughness = 0.85
	hoof_mat.vertex_color_use_as_albedo = true

	var trough_mat := StandardMaterial3D.new()
	trough_mat.albedo_color = Color(0.44, 0.28, 0.16)
	trough_mat.roughness = 0.85
	trough_mat.vertex_color_use_as_albedo = true

	var food_mat := StandardMaterial3D.new()
	food_mat.albedo_color = Color(0.95, 0.32, 0.22) # Manzanas rojas en el comedero
	food_mat.roughness = 0.6
	food_mat.vertex_color_use_as_albedo = true

	var st_skin := SurfaceTool.new()
	st_skin.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_snout := SurfaceTool.new()
	st_snout.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_detail := SurfaceTool.new()
	st_detail.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_hoof := SurfaceTool.new()
	st_hoof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_trough := SurfaceTool.new()
	st_trough.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_food := SurfaceTool.new()
	st_food.begin(Mesh.PRIMITIVE_TRIANGLES)

	var add_pig := func(base_xform: Transform3D, s: float, head_pitch_deg: float) -> void:
		# 1. Cuerpo redondeado rechoncho
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.14 * s
		body_mesh.height = 0.36 * s
		body_mesh.radial_segments = 14
		body_mesh.rings = 6
		var body_rot := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.165 * s, 0.0))
		st_skin.append_from(body_mesh, 0, base_xform * body_rot)

		# 2. Cabeza dulce y redonda con mofletes
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.12 * s
		head_mesh.height = 0.23 * s
		head_mesh.radial_segments = 12
		head_mesh.rings = 6
		var head_pitch := Basis(Vector3.RIGHT, deg_to_rad(head_pitch_deg))
		var head_xform := Transform3D(head_pitch, Vector3(0.0, 0.18 * s, -0.15 * s))
		st_skin.append_from(head_mesh, 0, base_xform * head_xform)

		# Mofletes
		for mx in [-1.0, 1.0]:
			var cheek := SphereMesh.new()
			cheek.radius = 0.05 * s
			cheek.height = 0.09 * s
			cheek.radial_segments = 6
			cheek.rings = 4
			var cheek_xf := Transform3D(head_pitch, Vector3(mx * 0.08 * s, 0.14 * s, -0.16 * s))
			st_snout.append_from(cheek, 0, base_xform * cheek_xf)

		# 3. Morro / Trompa prominente y suave
		var snout_mesh := CylinderMesh.new()
		snout_mesh.top_radius = 0.052 * s
		snout_mesh.bottom_radius = 0.056 * s
		snout_mesh.height = 0.048 * s
		snout_mesh.radial_segments = 10
		var snout_rot := Transform3D(head_pitch * Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.155 * s, -0.245 * s))
		st_snout.append_from(snout_mesh, 0, base_xform * snout_rot)

		# Orificios nasales oscuros
		for nx in [-0.02 * s, 0.02 * s]:
			var nostril := SphereMesh.new()
			nostril.radius = 0.012 * s
			nostril.height = 0.024 * s
			nostril.radial_segments = 5
			nostril.rings = 3
			var nostril_xf := Transform3D(head_pitch, Vector3(nx, 0.155 * s, -0.27 * s))
			st_detail.append_from(nostril, 0, base_xform * nostril_xf)

		# 4. Orejas caídas triangulares
		for ex in [-1.0, 1.0]:
			var ear_mesh := PrismMesh.new()
			ear_mesh.size = Vector3(0.065 * s, 0.085 * s, 0.025 * s)
			var ear_basis := head_pitch * Basis(Vector3.FORWARD, deg_to_rad(ex * 32.0)) * Basis(Vector3.RIGHT, deg_to_rad(-25.0))
			var ear_xf := Transform3D(ear_basis, Vector3(ex * 0.085 * s, 0.26 * s, -0.12 * s))
			st_snout.append_from(ear_mesh, 0, base_xform * ear_xf)

		# 5. Ojos brillantes
		for ox in [-1.0, 1.0]:
			var eye_mesh := SphereMesh.new()
			eye_mesh.radius = 0.018 * s
			eye_mesh.height = 0.036 * s
			eye_mesh.radial_segments = 6
			eye_mesh.rings = 4
			var eye_xf := Transform3D(head_pitch, Vector3(ox * 0.082 * s, 0.21 * s, -0.20 * s))
			st_detail.append_from(eye_mesh, 0, base_xform * eye_xf)

		# 6. Patitas rechonchas con pezuñas oscuras
		for lx in [-1.0, 1.0]:
			for lz in [-1.0, 1.0]:
				var leg_mesh := CylinderMesh.new()
				leg_mesh.top_radius = 0.035 * s
				leg_mesh.bottom_radius = 0.030 * s
				leg_mesh.height = 0.085 * s
				leg_mesh.radial_segments = 8
				var leg_xf := Transform3D(Basis.IDENTITY, Vector3(lx * 0.085 * s, 0.048 * s, lz * 0.095 * s))
				st_skin.append_from(leg_mesh, 0, base_xform * leg_xf)

				var hoof_mesh := CylinderMesh.new()
				hoof_mesh.top_radius = 0.032 * s
				hoof_mesh.bottom_radius = 0.034 * s
				hoof_mesh.height = 0.022 * s
				hoof_mesh.radial_segments = 8
				var hoof_xf := Transform3D(Basis.IDENTITY, Vector3(lx * 0.085 * s, 0.011 * s, lz * 0.095 * s))
				st_hoof.append_from(hoof_mesh, 0, base_xform * hoof_xf)

		# 7. Colita en tirabuzón
		for ti in range(3):
			var tail_seg := CylinderMesh.new()
			tail_seg.top_radius = 0.013 * s
			tail_seg.bottom_radius = 0.015 * s
			tail_seg.height = 0.032 * s
			tail_seg.radial_segments = 5
			var t_ang: float = float(ti) * 35.0
			var t_basis := Basis(Vector3.RIGHT, deg_to_rad(45.0 + t_ang * 0.5)) * Basis(Vector3.UP, deg_to_rad(t_ang))
			var t_xf := Transform3D(t_basis, Vector3(sin(deg_to_rad(t_ang)) * 0.025 * s, 0.18 * s + float(ti) * 0.015 * s, 0.17 * s + float(ti) * 0.015 * s))
			st_snout.append_from(tail_seg, 0, base_xform * t_xf)

	# 1. Cerdo adulto
	var pig1_xf := Transform3D(Basis(Vector3.UP, deg_to_rad(-25.0)), Vector3(-0.18, 0.0, 0.08))
	add_pig.call(pig1_xf, 1.15, -6.0)

	# 2. Cerdo mediano pastando
	var pig2_xf := Transform3D(Basis(Vector3.UP, deg_to_rad(135.0)), Vector3(0.24, 0.0, -0.10))
	add_pig.call(pig2_xf, 0.88, 18.0)

	# 3. Lechón pequeño
	var pig3_xf := Transform3D(Basis(Vector3.UP, deg_to_rad(65.0)), Vector3(0.06, 0.0, 0.22))
	add_pig.call(pig3_xf, 0.58, -4.0)

	# 4. Comedero de madera con manzanas
	var trough_box := BoxMesh.new()
	trough_box.size = Vector3(0.26, 0.09, 0.14)
	var trough_xf := Transform3D(Basis(Vector3.UP, deg_to_rad(20.0)), Vector3(-0.20, 0.045, -0.22))
	st_trough.append_from(trough_box, 0, trough_xf)

	# Manzanas en el comedero
	for ax in [-0.06, 0.0, 0.06]:
		var apple := SphereMesh.new()
		apple.radius = 0.025
		apple.height = 0.05
		apple.radial_segments = 5
		apple.rings = 3
		var apple_xf := Transform3D(Basis.IDENTITY, trough_xf.origin + Vector3(ax, 0.055, 0.0))
		st_food.append_from(apple, 0, apple_xf)

	var array_mesh := ArrayMesh.new()
	st_skin.index()
	st_skin.commit(array_mesh)
	st_snout.index()
	st_snout.commit(array_mesh)
	st_detail.index()
	st_detail.commit(array_mesh)
	st_hoof.index()
	st_hoof.commit(array_mesh)
	st_trough.index()
	st_trough.commit(array_mesh)
	st_food.index()
	st_food.commit(array_mesh)

	array_mesh.surface_set_material(0, pig_skin_mat)
	array_mesh.surface_set_material(1, pig_snout_mat)
	array_mesh.surface_set_material(2, detail_mat)
	array_mesh.surface_set_material(3, hoof_mat)
	array_mesh.surface_set_material(4, trough_mat)
	array_mesh.surface_set_material(5, food_mat)
	return array_mesh


## Hornea la geometría procedural de ganado lechero / vacas (familia de vacas lecheras con manchas, ubres, cuernos y cencerro).
static func build_cow_mesh() -> ArrayMesh:
	var cow_white_mat := StandardMaterial3D.new()
	cow_white_mat.albedo_color = Color(0.97, 0.96, 0.94)
	cow_white_mat.roughness = 0.85
	cow_white_mat.vertex_color_use_as_albedo = true

	var cow_spot_mat := StandardMaterial3D.new()
	cow_spot_mat.albedo_color = Color(0.14, 0.13, 0.15)
	cow_spot_mat.roughness = 0.82
	cow_spot_mat.vertex_color_use_as_albedo = true

	var cow_muzzle_mat := StandardMaterial3D.new()
	cow_muzzle_mat.albedo_color = Color(0.96, 0.70, 0.74)
	cow_muzzle_mat.roughness = 0.75
	cow_muzzle_mat.vertex_color_use_as_albedo = true

	var horn_mat := StandardMaterial3D.new()
	horn_mat.albedo_color = Color(0.92, 0.87, 0.76)
	horn_mat.roughness = 0.60
	horn_mat.vertex_color_use_as_albedo = true

	var hoof_mat := StandardMaterial3D.new()
	hoof_mat.albedo_color = Color(0.28, 0.24, 0.24)
	hoof_mat.roughness = 0.85
	hoof_mat.vertex_color_use_as_albedo = true

	var bell_mat := StandardMaterial3D.new()
	bell_mat.albedo_color = Color(0.95, 0.80, 0.22)
	bell_mat.metallic = 0.75
	bell_mat.roughness = 0.35
	bell_mat.vertex_color_use_as_albedo = true

	var collar_mat := StandardMaterial3D.new()
	collar_mat.albedo_color = Color(0.35, 0.20, 0.12)
	collar_mat.roughness = 0.85
	collar_mat.vertex_color_use_as_albedo = true

	var detail_mat := StandardMaterial3D.new()
	detail_mat.albedo_color = Color(0.08, 0.08, 0.10)
	detail_mat.roughness = 0.3
	detail_mat.vertex_color_use_as_albedo = true

	var flower_mat := StandardMaterial3D.new()
	flower_mat.albedo_color = Color(0.98, 0.85, 0.20)
	flower_mat.roughness = 0.60
	flower_mat.vertex_color_use_as_albedo = true

	var st_white := SurfaceTool.new()
	st_white.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_spot := SurfaceTool.new()
	st_spot.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_muzzle := SurfaceTool.new()
	st_muzzle.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_horn := SurfaceTool.new()
	st_horn.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_hoof := SurfaceTool.new()
	st_hoof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_bell := SurfaceTool.new()
	st_bell.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_collar := SurfaceTool.new()
	st_collar.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_detail := SurfaceTool.new()
	st_detail.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_flower := SurfaceTool.new()
	st_flower.begin(Mesh.PRIMITIVE_TRIANGLES)

	var add_cow := func(base_xform: Transform3D, s: float, head_pitch_deg: float, has_bell: bool) -> void:
		# 1. Cuerpo redondeado de vaca lechera
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.16 * s
		body_mesh.height = 0.44 * s
		body_mesh.radial_segments = 14
		body_mesh.rings = 6
		var body_rot := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, 0.24 * s, 0.0))
		st_white.append_from(body_mesh, 0, base_xform * body_rot)

		# Manchas negras icónicas en el cuerpo
		var spot1 := SphereMesh.new()
		spot1.radius = 0.10 * s
		spot1.height = 0.08 * s
		spot1.radial_segments = 8
		var spot1_xf := Transform3D(Basis.IDENTITY, Vector3(-0.09 * s, 0.28 * s, 0.06 * s))
		st_spot.append_from(spot1, 0, base_xform * spot1_xf)

		var spot2 := SphereMesh.new()
		spot2.radius = 0.11 * s
		spot2.height = 0.08 * s
		spot2.radial_segments = 8
		var spot2_xf := Transform3D(Basis.IDENTITY, Vector3(0.08 * s, 0.29 * s, -0.08 * s))
		st_spot.append_from(spot2, 0, base_xform * spot2_xf)

		var spot3 := SphereMesh.new()
		spot3.radius = 0.08 * s
		spot3.height = 0.07 * s
		spot3.radial_segments = 8
		var spot3_xf := Transform3D(Basis.IDENTITY, Vector3(-0.06 * s, 0.22 * s, -0.14 * s))
		st_spot.append_from(spot3, 0, base_xform * spot3_xf)

		# 2. Cabeza dulce con manchas
		var head_mesh := BoxMesh.new()
		head_mesh.size = Vector3(0.19 * s, 0.20 * s, 0.22 * s)
		var head_pitch := Basis(Vector3.RIGHT, deg_to_rad(head_pitch_deg))
		var head_xform := Transform3D(head_pitch, Vector3(0.0, 0.28 * s, -0.22 * s))
		st_white.append_from(head_mesh, 0, base_xform * head_xform)

		# Mancha negra en la frente / ojo izquierdo
		var eye_spot := SphereMesh.new()
		eye_spot.radius = 0.065 * s
		eye_spot.height = 0.06 * s
		eye_spot.radial_segments = 6
		var eye_spot_xf := Transform3D(head_pitch, Vector3(-0.06 * s, 0.32 * s, -0.25 * s))
		st_spot.append_from(eye_spot, 0, base_xform * eye_spot_xf)

		# 3. Morro amplio y rosado
		var muzzle_mesh := BoxMesh.new()
		muzzle_mesh.size = Vector3(0.17 * s, 0.10 * s, 0.12 * s)
		var muzzle_xf := Transform3D(head_pitch, Vector3(0.0, 0.22 * s, -0.32 * s))
		st_muzzle.append_from(muzzle_mesh, 0, base_xform * muzzle_xf)

		# Orificios nasales
		for nx in [-0.035 * s, 0.035 * s]:
			var nostril := SphereMesh.new()
			nostril.radius = 0.014 * s
			nostril.height = 0.024 * s
			nostril.radial_segments = 5
			var nostril_xf := Transform3D(head_pitch, Vector3(nx, 0.23 * s, -0.38 * s))
			st_detail.append_from(nostril, 0, base_xform * nostril_xf)

		# 4. Ojos grandes y cariñosos
		for ox in [-1.0, 1.0]:
			var eye := SphereMesh.new()
			eye.radius = 0.022 * s
			eye.height = 0.040 * s
			eye.radial_segments = 6
			var eye_xf := Transform3D(head_pitch, Vector3(ox * 0.10 * s, 0.30 * s, -0.26 * s))
			st_detail.append_from(eye, 0, base_xform * eye_xf)

		# 5. Cuernos marfil curvados
		for hx in [-1.0, 1.0]:
			var horn := PrismMesh.new()
			horn.size = Vector3(0.045 * s, 0.10 * s, 0.045 * s)
			var horn_basis := head_pitch * Basis(Vector3.FORWARD, deg_to_rad(hx * 35.0)) * Basis(Vector3.RIGHT, deg_to_rad(20.0))
			var horn_xf := Transform3D(horn_basis, Vector3(hx * 0.085 * s, 0.40 * s, -0.20 * s))
			st_horn.append_from(horn, 0, base_xform * horn_xf)

		# 6. Orejas horizontales suaves
		for ex in [-1.0, 1.0]:
			var ear := PrismMesh.new()
			ear.size = Vector3(0.08 * s, 0.10 * s, 0.025 * s)
			var ear_basis := head_pitch * Basis(Vector3.FORWARD, deg_to_rad(ex * 75.0)) * Basis(Vector3.RIGHT, deg_to_rad(-15.0))
			var ear_xf := Transform3D(ear_basis, Vector3(ex * 0.13 * s, 0.33 * s, -0.19 * s))
			st_white.append_from(ear, 0, base_xform * ear_xf)

		# 7. Collar y Cencerro dorado
		if has_bell:
			var collar := TorusMesh.new()
			collar.inner_radius = 0.07 * s
			collar.outer_radius = 0.09 * s
			collar.rings = 10
			var collar_xf := Transform3D(head_pitch * Basis(Vector3.RIGHT, deg_to_rad(70.0)), Vector3(0.0, 0.22 * s, -0.16 * s))
			st_collar.append_from(collar, 0, base_xform * collar_xf)

			var bell := CylinderMesh.new()
			bell.top_radius = 0.022 * s
			bell.bottom_radius = 0.038 * s
			bell.height = 0.065 * s
			bell.radial_segments = 6
			var bell_xf := Transform3D(head_pitch, Vector3(0.0, 0.15 * s, -0.18 * s))
			st_bell.append_from(bell, 0, base_xform * bell_xf)

		# 8. Ubres lecheras rosadas con tetillas
		var udder := SphereMesh.new()
		udder.radius = 0.075 * s
		udder.height = 0.08 * s
		udder.radial_segments = 8
		var udder_xf := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.14 * s, 0.06 * s))
		st_muzzle.append_from(udder, 0, base_xform * udder_xf)

		for tx in [-0.025 * s, 0.025 * s]:
			for tz in [0.045 * s, 0.085 * s]:
				var teat := CylinderMesh.new()
				teat.top_radius = 0.009 * s
				teat.bottom_radius = 0.007 * s
				teat.height = 0.030 * s
				teat.radial_segments = 5
				var teat_xf := Transform3D(Basis.IDENTITY, Vector3(tx, 0.09 * s, tz))
				st_muzzle.append_from(teat, 0, base_xform * teat_xf)

		# 9. Cuatro patas robustas con pezuñas
		for lx in [-1.0, 1.0]:
			for lz in [-1.0, 1.0]:
				var leg := CylinderMesh.new()
				leg.top_radius = 0.038 * s
				leg.bottom_radius = 0.034 * s
				leg.height = 0.16 * s
				leg.radial_segments = 8
				var leg_xf := Transform3D(Basis.IDENTITY, Vector3(lx * 0.10 * s, 0.09 * s, lz * 0.14 * s))
				st_white.append_from(leg, 0, base_xform * leg_xf)

				var hoof := CylinderMesh.new()
				hoof.top_radius = 0.036 * s
				hoof.bottom_radius = 0.038 * s
				hoof.height = 0.032 * s
				hoof.radial_segments = 8
				var hoof_xf := Transform3D(Basis.IDENTITY, Vector3(lx * 0.10 * s, 0.016 * s, lz * 0.14 * s))
				st_hoof.append_from(hoof, 0, base_xform * hoof_xf)

		# 10. Cola con pompón oscuro
		var tail := CylinderMesh.new()
		tail.top_radius = 0.014 * s
		tail.bottom_radius = 0.012 * s
		tail.height = 0.18 * s
		tail.radial_segments = 5
		var tail_rot := Basis(Vector3.RIGHT, deg_to_rad(-18.0))
		var tail_xf := Transform3D(tail_rot, Vector3(0.0, 0.16 * s, 0.24 * s))
		st_white.append_from(tail, 0, base_xform * tail_xf)

		var tuft := SphereMesh.new()
		tuft.radius = 0.026 * s
		tuft.height = 0.048 * s
		tuft.radial_segments = 6
		var tuft_xf := Transform3D(tail_rot, Vector3(0.0, 0.07 * s, 0.27 * s))
		st_spot.append_from(tuft, 0, base_xform * tuft_xf)

	# 1. Vaca madre principal con cencerro
	var cow1_xf := Transform3D(Basis(Vector3.UP, deg_to_rad(-22.0)), Vector3(-0.20, 0.0, 0.05))
	add_cow.call(cow1_xf, 1.15, -4.0, true)

	# 2. Vaca pastando en el prado
	var cow2_xf := Transform3D(Basis(Vector3.UP, deg_to_rad(145.0)), Vector3(0.26, 0.0, -0.08))
	add_cow.call(cow2_xf, 0.95, 22.0, false)

	# 3. Ternerita pequeña adorable
	var cow3_xf := Transform3D(Basis(Vector3.UP, deg_to_rad(55.0)), Vector3(0.08, 0.0, 0.26))
	add_cow.call(cow3_xf, 0.58, -2.0, false)

	# Flores de prado (margaritas/mantequillas)
	for fp in [Vector3(-0.25, 0.04, -0.28), Vector3(0.18, 0.04, 0.28), Vector3(-0.05, 0.04, -0.20)]:
		var fl := SphereMesh.new()
		fl.radius = 0.032
		fl.height = 0.02
		fl.radial_segments = 5
		var fl_xf := Transform3D(Basis.IDENTITY, fp)
		st_flower.append_from(fl, 0, fl_xf)

	var array_mesh := ArrayMesh.new()
	st_white.index()
	st_white.commit(array_mesh)
	st_spot.index()
	st_spot.commit(array_mesh)
	st_muzzle.index()
	st_muzzle.commit(array_mesh)
	st_horn.index()
	st_horn.commit(array_mesh)
	st_hoof.index()
	st_hoof.commit(array_mesh)
	st_bell.index()
	st_bell.commit(array_mesh)
	st_collar.index()
	st_collar.commit(array_mesh)
	st_detail.index()
	st_detail.commit(array_mesh)
	st_flower.index()
	st_flower.commit(array_mesh)

	array_mesh.surface_set_material(0, cow_white_mat)
	array_mesh.surface_set_material(1, cow_spot_mat)
	array_mesh.surface_set_material(2, cow_muzzle_mat)
	array_mesh.surface_set_material(3, horn_mat)
	array_mesh.surface_set_material(4, hoof_mat)
	array_mesh.surface_set_material(5, bell_mat)
	array_mesh.surface_set_material(6, collar_mat)
	array_mesh.surface_set_material(7, detail_mat)
	array_mesh.surface_set_material(8, flower_mat)
	return array_mesh


## Alias histórico para compatibilidad con llamadas a build_cattle_mesh (redirecciona a vacas lecheras).
static func build_cattle_mesh() -> ArrayMesh:
	return build_cow_mesh()


## Añade los peces que saltan fuera del agua cerca del muelle de pesca.
static func add_jumping_fish(container: Node3D) -> void:
	var fish_mat := StandardMaterial3D.new()
	fish_mat.albedo_color = Color(0.55, 0.72, 0.88)
	fish_mat.roughness = 0.35
	fish_mat.metallic = 0.25
	fish_mat.emission_enabled = true
	fish_mat.emission = Color(0.3, 0.65, 0.85)
	fish_mat.emission_energy_multiplier = 0.6

	var fish_spots := [Vector3(0.22, 0.0, 0.55), Vector3(-0.28, 0.0, 0.78)]
	for i in range(fish_spots.size()):
		var fish := Node3D.new()
		fish.position = fish_spots[i]
		fish.position.y = -0.10
		fish.rotation_degrees.x = -20.0
		container.add_child(fish)

		var body := MeshInstance3D.new()
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.035
		body_mesh.height = 0.16
		body.mesh = body_mesh
		body.material_override = fish_mat
		body.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		fish.add_child(body)

		var tail := MeshInstance3D.new()
		var tail_mesh := PrismMesh.new()
		tail_mesh.size = Vector3(0.05, 0.06, 0.04)
		tail.mesh = tail_mesh
		tail.material_override = fish_mat
		tail.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		tail.position = Vector3(0.0, 0.0, -0.09)
		fish.add_child(tail)

		var offset_i := i
		var start_anim := func():
			var fish_tween := fish.create_tween().set_loops()
			fish_tween.tween_interval(0.8 + offset_i * 1.3)
			fish_tween.tween_property(fish, "position:y", 0.18, 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			fish_tween.parallel().tween_property(fish, "rotation:x", deg_to_rad(35.0), 0.35)
			fish_tween.tween_property(fish, "position:y", -0.10, 0.30) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fish_tween.parallel().tween_property(fish, "rotation:x", deg_to_rad(-20.0), 0.30)
			fish_tween.tween_interval(1.6 + offset_i * 0.6)

		if fish.is_inside_tree():
			start_anim.call()
		else:
			fish.tree_entered.connect(start_anim)


## Apaga visualmente un modelo 3D de cofre ya saqueado (oscurece albedo y desactiva emisión).
static func _dim_model_meshes(root: Node3D) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			var mat := mi.material_override as StandardMaterial3D
			if not mat and mi.mesh and mi.mesh.get_surface_count() > 0:
				mat = mi.get_active_material(0) as StandardMaterial3D
			if mat:
				var m := mat.duplicate() as StandardMaterial3D
				m.emission_enabled = false
				m.albedo_color = m.albedo_color.darkened(0.55)
				mi.material_override = m
		elif child is Node3D:
			_dim_model_meshes(child)


