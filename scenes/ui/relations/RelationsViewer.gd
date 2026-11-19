# RelationsViewer.gd
# ─────────────────────────────────────────────────────────────────────────────
# VISOR DE RELACIONES CON NPCs — sub-vista de la pantalla Información (TabInfo).
#
# Lista únicamente aquellos NPCs con los que el jugador ha alcanzado al menos
# 1 punto de relación (afinidad >= 1).
# ─────────────────────────────────────────────────────────────────────────────
class_name RelationsViewer
extends Control

var embedded: bool = true

const NPC_DISPLAY_INFO: Dictionary = {
	# Zona 1: Valle del Yelmo
	"recluso": {"name": "El Anciano del Yelmo", "icon": "🧔", "image": "res://assets/vn/npcs/npc_world_poi_yelmo_recluso.png", "color": Color("ff9f43"), "role": {"es": "Veterano de la Guarnición", "en": "Garrison Veteran"}},
	"house_yelmo_recluso": {"name": "El Anciano del Yelmo", "icon": "🧔", "image": "res://assets/vn/npcs/npc_world_poi_yelmo_recluso.png", "color": Color("ff9f43"), "role": {"es": "Veterano de la Guarnición", "en": "Garrison Veteran"}},
	"house_001": {"name": "El Anciano del Yelmo", "icon": "🧔", "image": "res://assets/vn/npcs/npc_world_poi_yelmo_recluso.png", "color": Color("ff9f43"), "role": {"es": "Veterano de la Guarnición", "en": "Garrison Veteran"}},
	"anciana": {"name": "La Anciana Melancólica", "icon": "👵", "image": "res://assets/vn/npcs/npc_world_poi_yelmo_anciana.png", "color": Color("10ac84"), "role": {"es": "Memorias del Pasado", "en": "Memories of the Past"}},
	"house_yelmo_anciana": {"name": "La Anciana Melancólica", "icon": "👵", "image": "res://assets/vn/npcs/npc_world_poi_yelmo_anciana.png", "color": Color("10ac84"), "role": {"es": "Memorias del Pasado", "en": "Memories of the Past"}},
	"house_002": {"name": "La Anciana Melancólica", "icon": "👵", "image": "res://assets/vn/npcs/npc_world_poi_yelmo_anciana.png", "color": Color("10ac84"), "role": {"es": "Memorias del Pasado", "en": "Memories of the Past"}},
	"pescador": {"name": "Pescador del Valle", "icon": "🎣", "image": "res://assets/vn/npcs/npc_world_poi_hielo_refugio_01.png", "color": Color("41a3ff"), "role": {"es": "Pescador de Aguas Heladas", "en": "Frozen Waters Fisherman"}},
	"house_snow_01": {"name": "Pescador del Valle", "icon": "🎣", "image": "res://assets/vn/npcs/npc_world_poi_hielo_refugio_01.png", "color": Color("41a3ff"), "role": {"es": "Pescador de Aguas Heladas", "en": "Frozen Waters Fisherman"}},
	"house_003": {"name": "Pescador del Valle", "icon": "🎣", "image": "res://assets/vn/npcs/npc_world_poi_hielo_refugio_01.png", "color": Color("41a3ff"), "role": {"es": "Pescador de Aguas Heladas", "en": "Frozen Waters Fisherman"}},
	"poi_presa_001": {"name": "Presa Abandonada", "icon": "🚧", "image": "res://assets/vn/bg/bg_world_poi_yelmo_presa_001.png", "color": Color("4bcffa"), "role": {"es": "Antigua Presa del Valle", "en": "Ancient Valley Dam"}},
	"presa": {"name": "Presa Abandonada", "icon": "🚧", "image": "res://assets/vn/bg/bg_world_poi_yelmo_presa_001.png", "color": Color("4bcffa"), "role": {"es": "Antigua Presa del Valle", "en": "Ancient Valley Dam"}},
	# Zona 3: Praderas de Sylphrena
	"villager_mara": {"name": "Mara la Herbolaria", "icon": "🌿", "image": "res://assets/vn/npcs/npc_city_sylphrena_mara.png", "color": Color("2ed573"), "role": {"es": "Boticaria de Sylphrena", "en": "Sylphrena Apothecary"}},
	"house_pradera_01": {"name": "Mara la Herbolaria", "icon": "🌿", "image": "res://assets/vn/npcs/npc_city_sylphrena_mara.png", "color": Color("2ed573"), "role": {"es": "Boticaria de Sylphrena", "en": "Sylphrena Apothecary"}},
	"lost_diary_npc": {"name": "El Explorador", "icon": "🧭", "image": "res://assets/vn/npcs/npc_city_sylphrena_aldeano.png", "color": Color("eccc68"), "role": {"es": "Cartógrafo de Ruinas", "en": "Ruin Cartographer"}},
	"npc_pollo_mistico": {"name": "El Pollo Oracular", "icon": "🐔", "image": "res://assets/vn/npcs/npc_world_poi_pradera_pollo_mistico.png", "color": Color("ffa502"), "role": {"es": "Profeta Plumífero", "en": "Feathered Prophet"}},
	"npc_mimo_atrapado": {"name": "Marcel el Mimo", "icon": "🤡", "image": "res://assets/vn/npcs/npc_world_poi_pradera_mimo_atrapado.png", "color": Color("ff6b81"), "role": {"es": "Artista Atrapado", "en": "Trapped Artist"}},
	"npc_vendedor_aire": {"name": "Barón Von Vapores", "icon": "🎈", "image": "res://assets/vn/npcs/npc_world_poi_pradera_vendedor_aire.png", "color": Color("70a1ff"), "role": {"es": "Mercader de la Nada", "en": "Merchant of Nothing"}},
	# Zona 4: Reino de Celestia
	"king_celestia": {"name": "Rey de Celestia", "icon": "👑", "image": "res://assets/vn/npcs/npc_city_celestia_palace.png", "color": Color("ffd32a"), "role": {"es": "Soberano del Reino", "en": "Sovereign of the Realm"}},
	"archmage_celestia": {"name": "Archimago Real", "icon": "🧙‍♂️", "image": "res://assets/vn/npcs/npc_city_celestia_archmage.png", "color": Color("a55eea"), "role": {"es": "Consejero Arcano", "en": "Arcane Advisor"}},
	"sage_celestia": {"name": "Sabio de la Corte", "icon": "📜", "image": "res://assets/vn/npcs/npc_city_celestia_sage.png", "color": Color("4bcffa"), "role": {"es": "Historiador Imperial", "en": "Imperial Historian"}},
	"port_master": {"name": "Capitán del Puerto", "icon": "⚓", "image": "res://assets/vn/npcs/npc_world_poi_celestia_puerto.png", "color": Color("0fbcf9"), "role": {"es": "Maestre de Embarcaciones", "en": "Harbormaster"}},
	"npc_hombre_sombreros": {"name": "Lord Sombrerius", "icon": "🎩", "image": "res://assets/vn/npcs/npc_world_poi_pradera_hombre_sombreros.png", "color": Color("575fcf"), "role": {"es": "Crítico de Moda Craneal", "en": "Cranial Fashion Critic"}},
	# Maestros de Templos
	"temple_swordsman": {"name": "Maestro de la Espada", "icon": "⚔️", "image": "res://assets/vn/npcs/npc_temple_guerrero.png", "color": Color("ff5252"), "role": {"es": "Templo del Guerrero", "en": "Warrior Temple"}},
	"temple_archer": {"name": "Maestro Arquero", "icon": "🏹", "image": "res://assets/vn/npcs/npc_temple_arquero.png", "color": Color("2ecc71"), "role": {"es": "Templo del Arquero", "en": "Archer Temple"}},
	"temple_healer": {"name": "Gran Sacerdote", "icon": "🕊️", "image": "res://assets/vn/npcs/npc_temple_sacerdote.png", "color": Color("f1c40f"), "role": {"es": "Templo del Sacerdote", "en": "Priest Temple"}},
	"temple_elementalist": {"name": "Archielementalista", "icon": "🔮", "image": "res://assets/vn/npcs/npc_temple_elementalista.png", "color": Color("9b59b6"), "role": {"es": "Templo del Elementalista", "en": "Elementalist Temple"}},
	"temple_psychic": {"name": "Maestro Psíquico", "icon": "👁️", "image": "res://assets/vn/npcs/npc_temple_psiquico.png", "color": Color("3498db"), "role": {"es": "Templo del Psíquico", "en": "Psychic Temple"}},
	"temple_time": {"name": "Guardián del Tiempo", "icon": "⏳", "image": "res://assets/vn/npcs/npc_temple_tiempo.png", "color": Color("e67e22"), "role": {"es": "Templo del Tiempo", "en": "Time Temple"}},
	# Zona 5: Desierto de Gloriam
	"npc_entrenador_caracoles": {"name": "Don Velocidad", "icon": "🐌", "image": "res://assets/vn/npcs/npc_world_poi_gloriam_entrenador_caracoles.png", "color": Color("f39c12"), "role": {"es": "Entrenador de Caracoles", "en": "Snail Trainer"}},
	"gloriam_nomada": {"name": "Nómada del Desierto", "icon": "🐪", "image": "res://assets/vn/npcs/npc_city_gloriam_oasis.png", "color": Color("e67e22"), "role": {"es": "Guía de las Dunas", "en": "Dune Guide"}},
	"gloriam_habitante": {"name": "Erudito de Gloriam", "icon": "📜", "image": "res://assets/vn/npcs/npc_city_gloriam_residencia.png", "color": Color("d35400"), "role": {"es": "Historiador del Sol", "en": "Sun Historian"}},
	# Zona 6: Ruinas de Arcanum
	"arcanum_cientifico": {"name": "Doctor Arcanum", "icon": "🧪", "image": "res://assets/vn/npcs/npc_city_arcanum_lab.png", "color": Color("1abc9c"), "role": {"es": "Investigador del Laboratorio", "en": "Lab Researcher"}},
	"arcanum_chatarrero": {"name": "Chatarrero Autómata", "icon": "⚙️", "image": "res://assets/vn/npcs/npc_city_arcanum_chatarra.png", "color": Color("95a5a6"), "role": {"es": "Reciclador de Chatarra", "en": "Scrap Recycler"}},
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)

	var m := UiKit.margins(32, 32, 28, 28)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	m.add_child(vbox)

	# Cabecera
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	title.text = "👥  " + Locale.pick({"es": "Relaciones", "en": "Relationships"})
	vbox.add_child(title)

	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.08)
	div.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(div)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# Filtrar relaciones con afinidad >= 1 (consolidando duplicados de claves alias)
	var active_relations: Dictionary = {}
	for raw_key in GlobalState.npc_relations.keys():
		var val := GlobalState.get_npc_relationship(String(raw_key))
		if val >= 1:
			var info: Dictionary = _get_npc_info(String(raw_key))
			var canonical_name: String = info.get("name", String(raw_key))
			if not active_relations.has(canonical_name) or active_relations[canonical_name]["val"] < val:
				active_relations[canonical_name] = {
					"id": raw_key,
					"name": canonical_name,
					"icon": info.get("icon", "👥"),
					"image": info.get("image", ""),
					"color": info.get("color", UiKit.ACCENT),
					"role": info.get("role", {}),
					"val": val
				}

	if active_relations.is_empty():
		var empty_card := PanelContainer.new()
		empty_card.add_theme_stylebox_override("panel", UiKit.card(false, 18, 16))
		var empty_margin := UiKit.margins(24, 24, 24, 24)
		empty_card.add_child(empty_margin)
		
		var empty_lbl := Label.new()
		empty_lbl.text = Locale.pick({
			"es": "Aún no has forjado relación con ningún habitante del mundo.\nHabla con los habitantes para aumentar tu afinidad y forjar alianzas.",
			"en": "You haven't forged relationships with any world inhabitants yet.\nSpeak with NPCs to increase your affinity and forge alliances."
		})
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 28)
		empty_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		empty_margin.add_child(empty_lbl)
		list.add_child(empty_card)
	else:
		# Ordenar por mayor afinidad
		var sorted_keys: Array = active_relations.keys()
		sorted_keys.sort_custom(func(a, b): return int(active_relations[a]["val"]) > int(active_relations[b]["val"]))
		for k in sorted_keys:
			var entry: Dictionary = active_relations[k]
			list.add_child(_make_relation_card(entry))


func _make_relation_card(entry: Dictionary) -> PanelContainer:
	var name_txt: String = entry["name"]
	var icon_txt: String = entry.get("icon", "👥")
	var img_path: String = entry.get("image", "")
	var col: Color = entry["color"]
	var val: int = entry["val"]
	var role_dict = entry.get("role", {})
	var role_txt: String = Locale.pick(role_dict) if role_dict is Dictionary and not role_dict.is_empty() else ""

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(col, 18, 16))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var avatar := _make_npc_avatar(img_path, icon_txt, 88, col)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(vbox)

	var name_hb := HBoxContainer.new()
	name_hb.add_theme_constant_override("separation", 10)
	vbox.add_child(name_hb)

	var name_lbl := Label.new()
	name_lbl.text = name_txt
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	name_hb.add_child(name_lbl)

	# Etiqueta de Rango de afinidad
	var tier_txt := _affinity_tier(val)
	var tier_lbl := Label.new()
	tier_lbl.text = "💖 " + tier_txt
	tier_lbl.add_theme_font_size_override("font_size", 20)
	tier_lbl.add_theme_color_override("font_color", col)
	name_hb.add_child(tier_lbl)

	if role_txt != "":
		var role_lbl := Label.new()
		role_lbl.text = role_txt
		role_lbl.add_theme_font_size_override("font_size", 18)
		role_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		vbox.add_child(role_lbl)

	# Barra de afinidad
	var bar := ProgressBar.new()
	bar.max_value = 10
	bar.value = clampi(val, 0, 10)
	bar.custom_minimum_size = Vector2(0, 32)
	UiKit.style_progress(bar, col, 12)

	var bar_lbl := Label.new()
	bar_lbl.text = "%d / 10" % val
	bar_lbl.add_theme_font_size_override("font_size", 20)
	bar_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	bar_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(bar_lbl)
	vbox.add_child(bar)

	return card


## Crea un avatar circular enfocado en la cabeza (zona superior central) de la imagen del NPC.
func _make_npc_avatar(img_path: String, symbol_fallback: String, diameter: int = 88, tint: Color = UiKit.ACCENT) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(diameter, diameter)

	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(diameter, diameter)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.clip_children = Control.CLIP_CHILDREN_ONLY
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.22)
	sb.border_color = tint
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(diameter / 2.0))
	container.add_theme_stylebox_override("panel", sb)
	root.add_child(container)

	var tex: Texture2D = null
	if img_path != "" and ResourceLoader.exists(img_path):
		tex = load(img_path) as Texture2D

	if tex != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		# Recortar la parte superior central (cabeza y rostro: ~65% ancho/alto desde arriba)
		var crop_size := minf(tw, th) * 0.65
		var crop_x := (tw - crop_size) * 0.5
		var crop_y := th * 0.03
		atlas.region = Rect2(crop_x, crop_y, crop_size, crop_size)

		var tex_rect := TextureRect.new()
		tex_rect.texture = atlas
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		container.add_child(tex_rect)
	else:
		var lbl := Label.new()
		lbl.text = symbol_fallback if symbol_fallback != "" else "👥"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", int(diameter * 0.45))
		container.add_child(lbl)

	# Borde exterior nítido
	var border_overlay := Panel.new()
	border_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var osb := StyleBoxFlat.new()
	osb.draw_center = false
	osb.border_color = tint
	osb.set_border_width_all(2)
	osb.set_corner_radius_all(int(diameter / 2.0))
	border_overlay.add_theme_stylebox_override("panel", osb)
	root.add_child(border_overlay)

	return root


func _affinity_tier(val: int) -> String:
	if val >= 10:
		return Locale.pick({"es": "Vínculo Inquebrantable", "en": "Unbreakable Bond"})
	elif val >= 7:
		return Locale.pick({"es": "Aliado Cercano", "en": "Close Ally"})
	elif val >= 4:
		return Locale.pick({"es": "Amigo", "en": "Friend"})
	return Locale.pick({"es": "Conocido", "en": "Acquaintance"})


func _get_npc_info(npc_id: String) -> Dictionary:
	# 1. Catálogo estático de NPCs y POIs conocidos
	if NPC_DISPLAY_INFO.has(npc_id):
		return NPC_DISPLAY_INFO[npc_id]

	# 2. Entidad registrada en el catálogo de entidades del mundo (data/ids/*.json)
	if Design.ids.has(npc_id):
		var id_def: Dictionary = Design.ids[npc_id]
		var nm = id_def.get("name", null)
		var name_str: String = ""
		if nm is Dictionary:
			name_str = Locale.pick(nm)
		elif nm is String:
			name_str = nm
		if name_str.strip_edges() == "":
			name_str = humanize_id(npc_id)

		var icon_str: String = String(id_def.get("icon", "🏛️"))
		if icon_str == "":
			icon_str = "🏛️"

		var bg_str: String = String(id_def.get("bg", ""))
		var img_path: String = _resolve_image_path(bg_str)

		var role_dict = id_def.get("desc", {})
		if not (role_dict is Dictionary) or role_dict.is_empty():
			var type_str: String = String(id_def.get("type", "poi"))
			role_dict = {"es": "Punto de Interés", "en": "Point of Interest"} if type_str == "poi" else {"es": "Lugar del Mundo", "en": "World Location"}

		return {
			"name": name_str,
			"icon": icon_str,
			"image": img_path,
			"color": UiKit.ACCENT,
			"role": role_dict
		}

	# 3. Metadatos de diálogo de NPC (data/npcs/*.json)
	if Design.has_npc(npc_id):
		var meta := Design.npc_meta(npc_id)
		var meta_name = meta.get("name", null)
		var name_str: String = ""
		if meta_name is Dictionary:
			name_str = Locale.pick(meta_name)
		elif meta_name is String:
			name_str = meta_name
		if name_str.strip_edges() == "":
			var raw_npc := Design.get_npc(npc_id)
			if raw_npc.has("_meta"):
				var m_text = raw_npc["_meta"].get("text", null)
				if m_text is Dictionary:
					name_str = Locale.pick(m_text)
				elif m_text is String:
					name_str = m_text
		if name_str.strip_edges() == "":
			name_str = humanize_id(npc_id)

		var avatar_str: String = String(meta.get("avatar", "👥"))
		if avatar_str == "":
			avatar_str = "👥"
		var img_str: String = String(meta.get("image", ""))
		return {
			"name": name_str,
			"icon": avatar_str,
			"image": img_str,
			"color": UiKit.ACCENT,
			"role": {}
		}

	# 4. Fallback limpio sin IDs técnicos
	var fallback_name := humanize_id(npc_id)
	return {
		"name": fallback_name,
		"icon": "👥",
		"image": "",
		"color": UiKit.ACCENT,
		"role": {}
	}


func _resolve_image_path(bg_name: String) -> String:
	if bg_name == "":
		return ""
	if bg_name.begins_with("res://"):
		if ResourceLoader.exists(bg_name):
			return bg_name
		return ""
	var candidates: Array = [
		"res://assets/vn/bg/" + bg_name,
		"res://assets/vn/backgrounds/" + bg_name,
		"res://assets/vn/npcs/" + bg_name,
		"res://assets/vn/portraits/" + bg_name
	]
	for cand in candidates:
		if ResourceLoader.exists(cand):
			return cand
	return ""


static func humanize_id(raw_id: String) -> String:
	var s := raw_id.strip_edges()
	if s == "":
		return ""
	# Quitar prefijos técnicos comunes
	for prefix in ["poi_", "npc_", "house_", "obj_", "event_", "city_", "dun_", "marker_"]:
		if s.begins_with(prefix):
			s = s.substr(prefix.length())
			break
	# Quitar sufijos numéricos finales si quedan palabras descriptivas (ej. "presa_001" -> "presa")
	var parts := s.split("_", false)
	if parts.size() > 1 and parts[-1].is_valid_int():
		parts.remove_at(parts.size() - 1)
		s = "_".join(parts)
	# Reemplazar guiones y espacios
	s = s.replace("_", " ").replace("-", " ")
	var words := s.split(" ", false)
	var capitalized: Array = []
	for w in words:
		capitalized.append(w.capitalize())
	var result := " ".join(capitalized)
	return result if result != "" else raw_id

