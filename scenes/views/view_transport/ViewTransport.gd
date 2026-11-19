# ViewTransport.gd
# ─────────────────────────────────────────────────────────────────────────────
# PUESTO DE TRANSPORTE / CARROMATOS EN CIUDADES
#
# Permite viajar rápidamente a cualquier destino descubierto (ciudades,
# campamento base) dentro del propio POI de la ciudad, calculando el coste en oro
# de forma proporcional a la distancia del trayecto.
# ─────────────────────────────────────────────────────────────────────────────
class_name ViewTransport
extends Control

# ─── REFERENCIAS UI ───────────────────────────────────────────────────────────
var _bg_texture: TextureRect
var _overlay_dim: ColorRect

var _header_panel: PanelContainer
var _title_lbl: Label
var _gold_lbl: Label
var _btn_leave: Button

var _center_container: CenterContainer
var _dest_panel: PanelContainer
var _dest_header_lbl: Label
var _dest_scroll: ScrollContainer
var _dest_vbox: VBoxContainer

var _bottom_panel: PanelContainer
var _lbl_narrative: Label

# ─── ESTADO ───────────────────────────────────────────────────────────────────
var _city_id: String = ""
var _poi_id: String = ""
var _npc_id: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GlobalState.state_updated.connect(_on_state_updated)
	Locale.locale_changed.connect(_refresh)
	Locale.theme_changed.connect(func(_id: String) -> void: _apply_theme())


func _on_state_updated() -> void:
	if is_visible_in_tree():
		_refresh()


## Configura el POI de transporte con los datos de la ciudad.
func setup(data: Dictionary = {}) -> void:
	_city_id = String(data.get("city", ""))
	_poi_id = String(data.get("poi_id", ""))
	_npc_id = String(data.get("npc", _poi_id))

	if AudioManager != null:
		AudioManager.play_city_music(_city_id)

	_refresh()
	_update_welcome_narrative()


## Devuelve el nombre de la ciudad activa de forma amigable.
func _get_city_name() -> String:
	if _city_id.is_empty():
		return ""
	if Design.has_id(_city_id):
		var n := Locale.pick(Design.id_name(_city_id))
		if not n.is_empty():
			return n
	if _city_id != "":
		var dname: String = Locale.pick(Design.id_name(_city_id))
		if dname != "" and dname != _city_id:
			return dname
	match _city_id:
		"city_sylphrena", "sylphrena":
			return "Sylphrena"
		"city_celestia", "celestia":
			return "Celestia"
		"city_gloriam", "gloriam":
			return "Gloriam"
		"city_arcanum", "arcanum":
			return "Arcanum"
		_:
			return _city_id.replace("city_", "").capitalize()


## Devuelve el título representativo para el HUD superior de GameRoot.
func get_location_name() -> String:
	var city_name := _get_city_name()
	if city_name.is_empty():
		return Locale.pick({
			"es": "Transporte", "en": "Transport", "fr": "Transport",
			"it": "Trasporto", "de": "Transport", "zh": "运输", "ja": "輸送"
		})
	return Locale.pick({
		"es": "Transporte de %s" % city_name,
		"en": "%s Transport" % city_name,
		"fr": "Transport de %s" % city_name,
		"it": "Trasporto di %s" % city_name,
		"de": "%s Transport" % city_name,
		"zh": "%s 运输" % city_name,
		"ja": "%sの輸送" % city_name
	})


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 0. Fondo dinámico
	_bg_texture = TextureRect.new()
	_bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_texture)

	_overlay_dim = ColorRect.new()
	_overlay_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_dim.color = Color(0.02, 0.04, 0.07, 0.50)
	_overlay_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_dim)

	# 1. Cabecera superior
	_header_panel = PanelContainer.new()
	_header_panel.anchor_left = 0.0
	_header_panel.anchor_right = 1.0
	_header_panel.anchor_top = 0.0
	_header_panel.anchor_bottom = 0.0
	_header_panel.offset_bottom = 76
	_header_panel.add_theme_stylebox_override("panel", UiKit.header())
	add_child(_header_panel)

	var hm := UiKit.margins(28, 28, 8, 8)
	_header_panel.add_child(hm)

	var hbox_header := HBoxContainer.new()
	hbox_header.add_theme_constant_override("separation", 24)
	hm.add_child(hbox_header)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 30)
	_title_lbl.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	UiKit.apply_heading(_title_lbl)
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox_header.add_child(_title_lbl)

	_gold_lbl = Label.new()
	_gold_lbl.add_theme_font_size_override("font_size", 28)
	_gold_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_LIGHT)
	_gold_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox_header.add_child(_gold_lbl)

	_btn_leave = Button.new()
	_btn_leave.custom_minimum_size = Vector2(240, 54)
	_btn_leave.add_theme_font_size_override("font_size", 22)
	_btn_leave.focus_mode = Control.FOCUS_NONE
	UiKit.premium_button(_btn_leave, {"border_width": 2.0, "corner_radius": 12.0})
	_btn_leave.pressed.connect(_on_leave_pressed)
	hbox_header.add_child(_btn_leave)

	# 2. Contenedor central (Centrado y equilibrado en medio de la pantalla)
	var main_area := Control.new()
	main_area.anchor_left = 0.0
	main_area.anchor_right = 1.0
	main_area.anchor_top = 0.0
	main_area.anchor_bottom = 1.0
	main_area.offset_left = 32
	main_area.offset_right = -32
	main_area.offset_top = 86
	main_area.offset_bottom = -166
	add_child(main_area)

	_center_container = CenterContainer.new()
	_center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_area.add_child(_center_container)

	# Panel de Destinos Disponibles (Centrado, ancho óptimo ~980px)
	_dest_panel = PanelContainer.new()
	_dest_panel.custom_minimum_size = Vector2(980, 480)
	_dest_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiKit.premium_frame(_dest_panel, {"border_width": 2.5, "corner_radius": 16.0})
	_center_container.add_child(_dest_panel)

	var dest_margin := UiKit.margins(24, 24, 18, 18)
	_dest_panel.add_child(dest_margin)

	var dest_box := VBoxContainer.new()
	dest_box.add_theme_constant_override("separation", 16)
	dest_margin.add_child(dest_box)

	_dest_header_lbl = Label.new()
	_dest_header_lbl.text = "🗺️ " + Locale.pick({"es": "DESTINOS CONOCIDOS", "en": "KNOWN DESTINATIONS"})
	_dest_header_lbl.add_theme_font_size_override("font_size", 26)
	_dest_header_lbl.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	UiKit.apply_heading(_dest_header_lbl)
	dest_box.add_child(_dest_header_lbl)

	_dest_scroll = ScrollContainer.new()
	_dest_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dest_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dest_box.add_child(_dest_scroll)

	_dest_vbox = VBoxContainer.new()
	_dest_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dest_vbox.add_theme_constant_override("separation", 12)
	_dest_scroll.add_child(_dest_vbox)

	# 3. Panel Inferior Narrativo (Sin icono, textos ampliados)
	_bottom_panel = PanelContainer.new()
	_bottom_panel.anchor_left = 0.0
	_bottom_panel.anchor_right = 1.0
	_bottom_panel.anchor_top = 1.0
	_bottom_panel.anchor_bottom = 1.0
	_bottom_panel.offset_left = 32
	_bottom_panel.offset_right = -32
	_bottom_panel.offset_top = -152
	_bottom_panel.offset_bottom = -14
	UiKit.premium_frame(_bottom_panel, {"border_width": 2.5, "corner_radius": 14.0})
	add_child(_bottom_panel)

	var bm := UiKit.margins(28, 28, 16, 16)
	_bottom_panel.add_child(bm)

	_lbl_narrative = Label.new()
	_lbl_narrative.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_narrative.add_theme_font_size_override("font_size", 24)
	_lbl_narrative.add_theme_constant_override("line_spacing", 6)
	_lbl_narrative.add_theme_color_override("font_color", UiKit.TEXT)
	_lbl_narrative.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_narrative.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lbl_narrative.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bm.add_child(_lbl_narrative)

	_apply_theme()


func _apply_theme() -> void:
	if _header_panel != null:
		_header_panel.add_theme_stylebox_override("panel", UiKit.header())
	if _dest_panel != null:
		UiKit.premium_frame(_dest_panel, {"border_width": 2.5, "corner_radius": 16.0})
	if _bottom_panel != null:
		UiKit.premium_frame(_bottom_panel, {"border_width": 2.5, "corner_radius": 14.0})
	if _btn_leave != null:
		UiKit.premium_button(_btn_leave, {"border_width": 2.0, "corner_radius": 12.0})


# ══════════════════════════════════════════════════════════════════════════════
# RENDERIZADO Y ACTUALIZACIÓN
# ══════════════════════════════════════════════════════════════════════════════
func _refresh() -> void:
	if _title_lbl == null:
		return

	var city_name := _get_city_name()
	_title_lbl.text = "🚚 " + Locale.pick({
		"es": "Transporte de %s" % city_name if not city_name.is_empty() else "Puesto de Transporte",
		"en": "%s Transport" % city_name if not city_name.is_empty() else "Transport Post"
	})
	_gold_lbl.text = "💰 %d %s" % [GlobalState.gold, Locale.pick({"es": "Oro", "en": "Gold"})]
	_btn_leave.text = Locale.pick({"es": "🚪 Volver a la Ciudad", "en": "🚪 Back to City"})

	# Cargar fondo temático
	var bg_tex: Texture2D = null
	if _poi_id != "" and Design.has_id(_poi_id):
		var spec: Dictionary = Design.get_id(_poi_id)
		var explicit_bg: String = String(spec.get("bg", ""))
		if explicit_bg != "":
			bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/" + explicit_bg)
	if not bg_tex and _city_id != "":
		bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_city_%s_transportista.png" % _city_id.replace("city_", ""))
		if not bg_tex:
			bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_city_%s_transportista.png" % _city_id)
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_city_sylphrena_board.png")
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/common/ui/bg_default.png")

	if _bg_texture and bg_tex:
		_bg_texture.texture = bg_tex

	# Limpiar lista de destinos
	for c in _dest_vbox.get_children():
		c.queue_free()

	var destinations: Array = GlobalState.get_travel_points()
	if GlobalState.has_built_base and GlobalState.base_coord != Vector2i(-1, -1):
		destinations.append({
			"coord": GlobalState.base_coord,
			"name": Locale.pick({"es": "Campamento Base", "en": "Base Camp"}),
			"icon": "⛺",
			"raw_name": true
		})

	if destinations.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = Locale.pick({
			"es": "Aún no has descubierto otros asentamientos a los que viajar.\nExplora el mapamundi para registrar nuevas rutas.",
			"en": "No other travel destinations discovered yet.\nExplore the world map to chart new routes."
		})
		empty_lbl.add_theme_font_size_override("font_size", 22)
		empty_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTED)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dest_vbox.add_child(empty_lbl)
		return

	# Obtener la posición del jugador/ciudad actual
	var origin_pos: Vector2i = GlobalState.player_pos

	for dest in destinations:
		var target_coord: Vector2i = dest.get("coord", Vector2i(-1, -1))
		var dest_name: String = ""
		if dest.get("raw_name", false):
			dest_name = String(dest.get("name", ""))
		else:
			dest_name = Locale.pick(dest.get("name", {}))
		var dest_icon: String = String(dest.get("icon", "🏛️"))

		var is_here := (target_coord == origin_pos)
		var item_card := _build_destination_card(target_coord, dest_name, dest_icon, is_here, origin_pos)
		_dest_vbox.add_child(item_card)


func _build_destination_card(target_coord: Vector2i, dest_name: String, icon_str: String, is_here: bool, origin_pos: Vector2i) -> Control:
	# Cálculo de distancia y coste proporcional
	var dist: float = origin_pos.distance_to(target_coord)
	var leagues: int = maxi(1, int(round(dist)))
	var cost: int = maxi(15, int(round(15.0 + dist * 3.0)))
	var can_afford: bool = GlobalState.gold >= cost

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 108)
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(UiKit.SURFACE_ALT, 14, 0))

	var m := UiKit.margins(20, 20, 14, 14)
	card.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	m.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = icon_str
	icon_lbl.add_theme_font_size_override("font_size", 44)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	var vbody := VBoxContainer.new()
	vbody.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbody.alignment = BoxContainer.ALIGNMENT_CENTER
	vbody.add_theme_constant_override("separation", 6)
	hbox.add_child(vbody)

	var name_lbl := Label.new()
	name_lbl.text = dest_name
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	UiKit.apply_heading(name_lbl)
	vbody.add_child(name_lbl)

	var sub_lbl := Label.new()
	if is_here:
		sub_lbl.text = Locale.pick({"es": "📍 Ubicación actual en esta ciudad", "en": "📍 Current location in this city"})
		sub_lbl.add_theme_color_override("font_color", UiKit.GOOD)
	else:
		sub_lbl.text = Locale.pick({
			"es": "Distancia: ~%d leguas  ·  Tarifa: 💰 %d Oro",
			"en": "Distance: ~%d leagues  ·  Fare: 💰 %d Gold"
		}) % [leagues, cost]
		sub_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_LIGHT if can_afford else UiKit.WARN)
	sub_lbl.add_theme_font_size_override("font_size", 20)
	vbody.add_child(sub_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(180, 64)
	btn.add_theme_font_size_override("font_size", 20)
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if is_here:
		btn.text = Locale.pick({"es": "📍 Aquí", "en": "📍 Here"})
		btn.disabled = true
	elif not can_afford:
		btn.text = Locale.pick({"es": "Falta Oro", "en": "Need Gold"})
		btn.disabled = true
	else:
		btn.text = "🐎 " + Locale.pick({"es": "Viajar", "en": "Travel"})
		btn.disabled = false
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, UiKit.button_primary(12))
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(col, UiKit.BG_DEEP)
		btn.pressed.connect(func() -> void: _on_travel_pressed(target_coord, dest_name, cost))

	hbox.add_child(btn)
	return card


func _update_welcome_narrative() -> void:
	match _city_id:
		"city_sylphrena", "sylphrena":
			_lbl_narrative.text = Locale.pick({
				"es": "«El carromatero ajusta las riendas de los bueyes». Buen día, aventurero. Las rutas comerciales de Sylphrena están despejadas. Elige a dónde partir.",
				"en": "«The carter tightens the oxen's reins». Good day, traveler. Sylphrena's trade routes are open. Choose your destination."
			})
		"city_celestia", "celestia":
			_lbl_narrative.text = Locale.pick({
				"es": "«El cochero celestial prepara su carruaje». Que la luz bendiga tu viaje. Partimos de inmediato a cualquier punto sagrado o enclave del mapa.",
				"en": "«The celestial driver readies his carriage». May the light bless your path. We depart immediately to any sacred place or enclave."
			})
		"city_gloriam", "gloriam":
			_lbl_narrative.text = Locale.pick({
				"es": "«Un veterano conductor del desierto revisa los odres de agua». Las dunas de Gloriam son traicioneras; viajar en convoy es tu opción más segura.",
				"en": "«A veteran desert driver checks the water bags». Gloriam's dunes are unforgiving; traveling by caravan is your safest choice."
			})
		"city_arcanum", "arcanum":
			_lbl_narrative.text = Locale.pick({
				"es": "«El piloto de la torre ajusta los propulsores arcanos». Plataforma de despegue preparada para transporte interregional hacia cualquier punto conectado.",
				"en": "«The tower pilot adjusts arcane thrusters». Launch platform ready for interregional travel to any connected waypoint."
			})
		_:
			_lbl_narrative.text = Locale.pick({
				"es": "El puesto de transporte dispone de monturas y carretas preparadas para partir hacia cualquier asentamiento descubierto.",
				"en": "The transport post has mounts and wagons ready to depart to any charted settlement."
			})


# ══════════════════════════════════════════════════════════════════════════════
# EVENTOS Y ACCIONES
# ══════════════════════════════════════════════════════════════════════════════
func _on_travel_pressed(target_coord: Vector2i, _dest_name: String, cost: int) -> void:
	if GlobalState.gold < cost:
		UiKit.toast(self, Locale.pick({"es": "No tienes suficiente oro para el viaje.", "en": "Not enough gold for the trip."}), UiKit.HP)
		return

	GlobalState.gold -= cost
	GlobalState.state_updated.emit()
	GlobalState.pending_teleport_coord = target_coord

	AudioManager.play_ui("reward")
	SaveManager.request_autosave()

	# Salir de la ciudad e ir al mundo
	SceneManager.go_to_world()


func _on_leave_pressed() -> void:
	AudioManager.play_ui("cancel")
	SceneManager.back_to_city()
