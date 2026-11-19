# ViewEncargos.gd
# ─────────────────────────────────────────────────────────────────────────────
# TABLÓN DE ENCARGOS — MISIONES Y CONTRATOS EN CIUDAD Y BASE
#
# Interfaz renovada:
#   • Sin NPC en la escena: enfoque directo en el tablón de anuncios de la plaza.
#   • Distribución de 2 paneles equilibrados a pantalla completa:
#       - Izquierda: Encargos en curso (Activos) con progreso y reclamo.
#       - Derecha: Avisos y contratos disponibles en el tablón para aceptar.
#   • Panel inferior narrativo y atmosférico con descripciones inmersivas
#     específicas por ciudad y reactivas a las acciones del jugador.
#   • Integración completa con el sistema de temas y UiKit.
# ─────────────────────────────────────────────────────────────────────────────
class_name ViewEncargos
extends Control

# ─── REFERENCIAS UI ───────────────────────────────────────────────────────────
var _bg_texture: TextureRect
var _overlay_dim: ColorRect

# Cabecera
var _header_panel: PanelContainer
var _title_lbl: Label
var _gold_lbl: Label
var _btn_leave: Button

# Contenedor central de dos columnas
var _columns_container: HBoxContainer

# Panel Izquierdo: Activos
var _active_panel: PanelContainer
var _active_header_lbl: Label
var _active_badge: Label
var _active_scroll: ScrollContainer
var _active_vbox: VBoxContainer

# Panel Derecho: Disponibles
var _avail_panel: PanelContainer
var _avail_header_lbl: Label
var _avail_sub_lbl: Label
var _avail_scroll: ScrollContainer
var _avail_vbox: VBoxContainer

# Panel Inferior Narrativo
var _bottom_panel: PanelContainer
var _lbl_narrative: Label
var _lbl_more_indicator: Label

# Diálogo / máquina de escribir
var _typing_tween: Tween
var _is_typing: bool = false

## Id de la ciudad y del POI ("" = Tablón de la Base).
var _city_id: String = ""
var _poi_id: String = ""
var _npc_id: String = ""


func _ready() -> void:
	_build_ui()
	GlobalState.state_updated.connect(_on_state_updated)
	Locale.locale_changed.connect(_refresh)
	_refresh()


func _on_state_updated() -> void:
	if is_visible_in_tree():
		_refresh()


## Configura el tablón con los datos de la ciudad o POI.
func setup(data: Dictionary) -> void:
	_city_id = String(data.get("city", ""))
	_poi_id = String(data.get("poi_id", data.get("npc", "")))
	_npc_id = String(data.get("npc", _poi_id))

	if _city_id != "":
		GlobalState.ensure_encargos_for_city(_city_id)
		if AudioManager != null:
			AudioManager.play_city_music(_city_id)
	_refresh()
	_trigger_welcome_description()


## Devuelve el título del tablón para la barra superior del HUD.
func get_location_name() -> String:
	if _city_id != "":
		var city_name := Locale.pick(Design.id_name(_city_id)) if Design.has_id(_city_id) else _city_id.capitalize()
		return Locale.pick({
			"es": "Tablón de %s" % city_name if not city_name.is_empty() else "Tablón de Encargos",
			"en": "%s Notice Board" % city_name if not city_name.is_empty() else "Notice Board"
		})
	return Locale.pick({"es": "Tablón de Encargos", "en": "Notice Board"})


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 0. Fondo dinámico del tablón
	_bg_texture = TextureRect.new()
	_bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_texture)

	# Capa de oscurecimiento suave para dar contraste cinematográfico a la UI
	_overlay_dim = ColorRect.new()
	_overlay_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_dim.color = Color(0.02, 0.04, 0.07, 0.40)
	_overlay_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_dim)

	# 1. Cabecera superior
	_header_panel = PanelContainer.new()
	_header_panel.anchor_left = 0.0
	_header_panel.anchor_right = 1.0
	_header_panel.anchor_top = 0.0
	_header_panel.anchor_bottom = 0.0
	_header_panel.offset_bottom = 74
	_header_panel.add_theme_stylebox_override("panel", UiKit.header())
	add_child(_header_panel)

	var hm := UiKit.margins(28, 28, 8, 8)
	_header_panel.add_child(hm)

	var hbox_header := HBoxContainer.new()
	hbox_header.add_theme_constant_override("separation", 20)
	hm.add_child(hbox_header)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 34)
	_title_lbl.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	UiKit.apply_heading(_title_lbl)
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox_header.add_child(_title_lbl)

	_gold_lbl = Label.new()
	_gold_lbl.add_theme_font_size_override("font_size", 32)
	_gold_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_LIGHT)
	_gold_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox_header.add_child(_gold_lbl)

	_btn_leave = Button.new()
	_btn_leave.custom_minimum_size = Vector2(250, 56)
	_btn_leave.add_theme_font_size_override("font_size", 24)
	_btn_leave.focus_mode = Control.FOCUS_NONE
	UiKit.premium_button(_btn_leave, {"border_width": 2.0, "corner_radius": 12.0})
	_btn_leave.pressed.connect(_on_leave_pressed)
	hbox_header.add_child(_btn_leave)

	# 2. Contenedor Central (Dos Paneles)
	var main_area := Control.new()
	main_area.anchor_left = 0.0
	main_area.anchor_right = 1.0
	main_area.anchor_top = 0.0
	main_area.anchor_bottom = 1.0
	main_area.offset_left = 28
	main_area.offset_right = -28
	main_area.offset_top = 84
	main_area.offset_bottom = -174
	add_child(main_area)

	_columns_container = HBoxContainer.new()
	_columns_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_columns_container.add_theme_constant_override("separation", 24)
	main_area.add_child(_columns_container)

	# ── PANEL IZQUIERDO: Encargos en Curso (Activos) ──
	_active_panel = PanelContainer.new()
	_active_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_panel.size_flags_stretch_ratio = 0.65
	UiKit.premium_frame(_active_panel, {"border_width": 2.5, "corner_radius": 14.0})
	_columns_container.add_child(_active_panel)

	var active_margin := UiKit.margins(18, 18, 14, 14)
	_active_panel.add_child(active_margin)

	var active_box := VBoxContainer.new()
	active_box.add_theme_constant_override("separation", 12)
	active_margin.add_child(active_box)

	# Cabecera de activos
	var active_head_box := HBoxContainer.new()
	active_head_box.add_theme_constant_override("separation", 10)
	active_box.add_child(active_head_box)

	_active_header_lbl = Label.new()
	_active_header_lbl.text = "🎯 ENCARGOS EN CURSO"
	_active_header_lbl.add_theme_font_size_override("font_size", 26)
	_active_header_lbl.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	_active_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.apply_heading(_active_header_lbl)
	active_head_box.add_child(_active_header_lbl)

	_active_badge = Label.new()
	_active_badge.text = "(0/3)"
	_active_badge.add_theme_font_size_override("font_size", 24)
	_active_badge.add_theme_color_override("font_color", UiKit.GOOD)
	active_head_box.add_child(_active_badge)

	# Scroll de activos
	_active_scroll = ScrollContainer.new()
	_active_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_active_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	active_box.add_child(_active_scroll)

	_active_vbox = VBoxContainer.new()
	_active_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_vbox.add_theme_constant_override("separation", 10)
	_active_scroll.add_child(_active_vbox)

	# ── PANEL DERECHO: Avisos Disponibles en el Tablón ──
	_avail_panel = PanelContainer.new()
	_avail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_avail_panel.size_flags_stretch_ratio = 1.35
	UiKit.premium_frame(_avail_panel, {"border_width": 2.5, "corner_radius": 14.0})
	_columns_container.add_child(_avail_panel)

	var avail_margin := UiKit.margins(18, 18, 14, 14)
	_avail_panel.add_child(avail_margin)

	var avail_box := VBoxContainer.new()
	avail_box.add_theme_constant_override("separation", 12)
	avail_margin.add_child(avail_box)

	# Cabecera de disponibles
	var avail_head_box := HBoxContainer.new()
	avail_head_box.add_theme_constant_override("separation", 10)
	avail_box.add_child(avail_head_box)

	_avail_header_lbl = Label.new()
	_avail_header_lbl.text = "📌 AVISOS DEL TABLÓN"
	_avail_header_lbl.add_theme_font_size_override("font_size", 28)
	_avail_header_lbl.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	_avail_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.apply_heading(_avail_header_lbl)
	avail_head_box.add_child(_avail_header_lbl)

	_avail_sub_lbl = Label.new()
	_avail_sub_lbl.text = Locale.pick({"es": "Contratos de la ciudad", "en": "City contracts"})
	_avail_sub_lbl.add_theme_font_size_override("font_size", 21)
	_avail_sub_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTED)
	avail_head_box.add_child(_avail_sub_lbl)

	# Scroll de disponibles
	_avail_scroll = ScrollContainer.new()
	_avail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_avail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_avail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	avail_box.add_child(_avail_scroll)

	_avail_vbox = VBoxContainer.new()
	_avail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_avail_vbox.add_theme_constant_override("separation", 10)
	_avail_scroll.add_child(_avail_vbox)

	# 3. Panel Inferior Narrativo y Descriptivo
	_bottom_panel = PanelContainer.new()
	_bottom_panel.anchor_left = 0.0
	_bottom_panel.anchor_right = 1.0
	_bottom_panel.anchor_top = 1.0
	_bottom_panel.anchor_bottom = 1.0
	_bottom_panel.offset_left = 28
	_bottom_panel.offset_right = -28
	_bottom_panel.offset_top = -162
	_bottom_panel.offset_bottom = -14
	_bottom_panel.gui_input.connect(_on_bottom_panel_input)
	UiKit.premium_frame(_bottom_panel, {"border_width": 2.5, "corner_radius": 14.0})
	add_child(_bottom_panel)

	var bm := UiKit.margins(24, 24, 14, 14)
	_bottom_panel.add_child(bm)

	var b_hbox := HBoxContainer.new()
	b_hbox.add_theme_constant_override("separation", 18)
	bm.add_child(b_hbox)

	var board_icon := Label.new()
	board_icon.text = "📜"
	board_icon.add_theme_font_size_override("font_size", 48)
	board_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b_hbox.add_child(board_icon)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	b_hbox.add_child(text_vbox)

	_lbl_narrative = Label.new()
	_lbl_narrative.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_narrative.add_theme_font_size_override("font_size", 26)
	_lbl_narrative.add_theme_constant_override("line_spacing", 6)
	_lbl_narrative.add_theme_color_override("font_color", UiKit.TEXT)
	_lbl_narrative.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_narrative.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lbl_narrative.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_vbox.add_child(_lbl_narrative)

	_lbl_more_indicator = Label.new()
	_lbl_more_indicator.text = "▼"
	_lbl_more_indicator.add_theme_font_size_override("font_size", 26)
	_lbl_more_indicator.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT))
	_lbl_more_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_more_indicator.size_flags_horizontal = Control.SIZE_SHRINK_END
	_lbl_more_indicator.visible = false
	b_hbox.add_child(_lbl_more_indicator)

	_apply_theme()


func _apply_theme() -> void:
	if _header_panel != null:
		_header_panel.add_theme_stylebox_override("panel", UiKit.header())
	if _active_panel != null:
		UiKit.premium_frame(_active_panel, {"border_width": 2.5, "corner_radius": 14.0})
	if _avail_panel != null:
		UiKit.premium_frame(_avail_panel, {"border_width": 2.5, "corner_radius": 14.0})
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

	var is_base_board: bool = _city_id == ""
	if is_base_board:
		_title_lbl.text = "📋 %s" % Locale.t("enc_board_title_base")
		_avail_panel.visible = false
		_active_panel.size_flags_stretch_ratio = 1.0
	elif _poi_id != "" and Design.has_id(_poi_id):
		_title_lbl.text = "📋 %s" % Locale.pick(Design.id_name(_poi_id))
		_avail_panel.visible = true
		_active_panel.size_flags_stretch_ratio = 0.65
		_avail_panel.size_flags_stretch_ratio = 1.35
	else:
		var city_name := Locale.pick(Design.id_name(_city_id)) if Design.has_id(_city_id) else _city_id.capitalize()
		_title_lbl.text = "📋 %s — %s" % [Locale.t("enc_board_title"), city_name]
		_avail_panel.visible = true
		_active_panel.size_flags_stretch_ratio = 0.65
		_avail_panel.size_flags_stretch_ratio = 1.35

	_gold_lbl.text = "💰 %d %s" % [GlobalState.gold, Locale.pick({"es": "Oro", "en": "Gold"})]
	_btn_leave.text = Locale.pick({"es": "🚪 Volver a la Ciudad", "en": "🚪 Back to City"}) if not is_base_board else Locale.t("enc_leave")

	var active_count: int = GlobalState.active_encargos.size()
	var max_active: int = GameConfig.ENCARGO_MAX_ACTIVE
	_active_header_lbl.text = "🎯 " + Locale.t("enc_active")
	_active_badge.text = "(%d/%d)" % [active_count, max_active]
	_active_badge.add_theme_color_override("font_color", UiKit.WARN if active_count >= max_active else UiKit.GOOD)

	_avail_header_lbl.text = "📌 " + Locale.t("enc_available")

	# Cargar fondo dinámico de la ciudad
	var bg_tex: Texture2D = null
	if _poi_id != "" and Design.has_id(_poi_id):
		var spec: Dictionary = Design.get_id(_poi_id)
		var explicit_bg: String = String(spec.get("bg", ""))
		if explicit_bg != "":
			bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/" + explicit_bg)
	if not bg_tex and _city_id != "":
		bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_city_%s_board.png" % _city_id.replace("city_", ""))
		if not bg_tex:
			bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_city_%s_board.png" % _city_id)
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_city_sylphrena_board.png")
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/common/ui/bg_default.png")

	if _bg_texture and bg_tex:
		_bg_texture.texture = bg_tex

	# Limpiar listas
	for c in _active_vbox.get_children():
		c.queue_free()
	for c in _avail_vbox.get_children():
		c.queue_free()

	var any_active := false
	var any_avail := false

	for e: Dictionary in GameConfig.all_encargos():
		var id: String = String(e.get("id", ""))
		var active: bool = GlobalState.is_encargo_active(id)
		var c_tag := String(e.get("city", ""))
		var belongs_to_city: bool = is_base_board or c_tag == _city_id

		if active and belongs_to_city:
			_active_vbox.add_child(_make_active_card(e))
			any_active = true
		elif not active and not is_base_board and belongs_to_city:
			_avail_vbox.add_child(_make_avail_card(e))
			any_avail = true

	# Estados vacíos elegantes
	if not any_active:
		var empty_active := _make_empty_state(
			"📜",
			Locale.pick({
				"es": "No tienes ningún encargo en curso.\nRevisa los avisos del tablón para aceptar nuevos contratos.",
				"en": "No active bounties.\nCheck the notice board to accept contracts."
			})
		)
		_active_vbox.add_child(empty_active)

	if not is_base_board and not any_avail:
		var empty_avail := _make_empty_state(
			"✨",
			Locale.pick({
				"es": "Todos los avisos de este tablón han sido aceptados.\nCompleta tus encargos activos o regresa más tarde.",
				"en": "All notices on this board have been accepted.\nComplete active bounties or check back later."
			})
		)
		_avail_vbox.add_child(empty_avail)


func _make_empty_state(icon: String, text: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 126)
	panel.add_theme_stylebox_override("panel", UiKit.card_tinted(UiKit.SURFACE_ALT, 12, 0))

	var m := UiKit.margins(18, 18, 16, 16)
	panel.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 42)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = text
	msg_lbl.add_theme_font_size_override("font_size", 22)
	msg_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTED)
	msg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(msg_lbl)

	return panel


# ══════════════════════════════════════════════════════════════════════════════
# TARJETA DE ENCARGO EN CURSO (ACTIVO)
# ══════════════════════════════════════════════════════════════════════════════
func _make_active_card(e: Dictionary) -> Control:
	var id: String = String(e["id"])
	var amount: int = int(e["amount"])
	var done: bool = GlobalState.is_encargo_done(id)
	var cur: int = GlobalState.encargo_count(id)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 130 if done else 152)
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(UiKit.GOOD if done else UiKit.ACCENT, 12, 0))

	var m := UiKit.margins(16, 16, 12, 12)
	card.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	m.add_child(hbox)

	# Icono
	var icon := Label.new()
	icon.text = String(e.get("icon", "📋"))
	icon.add_theme_font_size_override("font_size", 44)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon)

	# Cuerpo de información
	var vbody := VBoxContainer.new()
	vbody.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbody.alignment = BoxContainer.ALIGNMENT_CENTER
	vbody.add_theme_constant_override("separation", 4)
	hbox.add_child(vbody)

	var title_lbl := Label.new()
	title_lbl.text = "%s  ·  %s" % [_encargo_title(e), _type_label(String(e.get("type", "")))]
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbody.add_child(title_lbl)

	# Recordatorio breve del objetivo: al aceptar un encargo, la descripción de
	# "qué hay que hacer" desaparecía (solo se mostraba en la tarjeta de
	# disponible). Se repite aquí, en una línea corta, para que el jugador no
	# tenga que recordarlo de memoria.
	if not done:
		var goal_text := _encargo_desc(e)
		if goal_text != "":
			var goal_lbl := Label.new()
			goal_lbl.text = goal_text
			goal_lbl.add_theme_font_size_override("font_size", 18)
			goal_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTED)
			goal_lbl.clip_text = true
			goal_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			vbody.add_child(goal_lbl)

	var reward_lbl := Label.new()
	reward_lbl.text = "💰 %d Oro   ✨ %d EXP" % [int(e.get("reward_gold", 0)), GlobalState.encargo_effective_xp(e)]
	reward_lbl.add_theme_font_size_override("font_size", 21)
	reward_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_LIGHT if done else UiKit.TEXT_MUTED)
	vbody.add_child(reward_lbl)

	# Barra de progreso
	var bar := ProgressBar.new()
	bar.max_value = amount
	bar.value = cur
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	UiKit.style_progress(bar, UiKit.GOOD if done else UiKit.ACCENT, 6)
	vbody.add_child(bar)

	var prog_lbl := Label.new()
	if done:
		prog_lbl.text = Locale.pick({"es": "¡Completado! Listo para entregar (%d/%d)" % [cur, amount], "en": "Completed! Ready to claim (%d/%d)" % [cur, amount]})
		prog_lbl.add_theme_color_override("font_color", UiKit.GOOD)
	else:
		prog_lbl.text = Locale.t("enc_progress", [cur, amount])
		prog_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTED)
	prog_lbl.add_theme_font_size_override("font_size", 20)
	vbody.add_child(prog_lbl)

	# Botón de acción / reclamo
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 58)
	btn.add_theme_font_size_override("font_size", 21)
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if done:
		btn.text = "🎁 " + Locale.t("enc_claim")
		btn.disabled = false
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, UiKit.button_primary(10))
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(col, UiKit.BG_DEEP)
		btn.pressed.connect(func() -> void: _on_claim(id, e))
	else:
		btn.text = "⏳ " + Locale.pick({"es": "En curso", "en": "In progress"})
		btn.disabled = true

	hbox.add_child(btn)
	return card


# ══════════════════════════════════════════════════════════════════════════════
# TARJETA DE AVISO DISPONIBLE EN EL TABLÓN
# ══════════════════════════════════════════════════════════════════════════════
func _make_avail_card(e: Dictionary) -> Control:
	var id: String = String(e["id"])
	var can_accept: bool = GlobalState.can_accept_encargo()

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 148)
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(UiKit.SURFACE_ALT, 12, 0))

	var m := UiKit.margins(16, 16, 12, 12)
	card.add_child(m)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	m.add_child(hbox)

	# Icono
	var icon := Label.new()
	icon.text = String(e.get("icon", "📋"))
	icon.add_theme_font_size_override("font_size", 48)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon)

	# Cuerpo de información
	var vbody := VBoxContainer.new()
	vbody.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbody.alignment = BoxContainer.ALIGNMENT_CENTER
	vbody.add_theme_constant_override("separation", 4)
	hbox.add_child(vbody)

	var title_lbl := Label.new()
	title_lbl.text = "%s  ·  %s" % [_encargo_title(e), _type_label(String(e.get("type", "")))]
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbody.add_child(title_lbl)

	var desc_text := _encargo_desc(e)
	if desc_text != "":
		var desc_lbl := Label.new()
		desc_lbl.text = desc_text
		desc_lbl.add_theme_font_size_override("font_size", 22)
		desc_lbl.add_theme_color_override("font_color", UiKit.TEXT)
		desc_lbl.clip_text = true
		desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbody.add_child(desc_lbl)

	var reward_lbl := Label.new()
	reward_lbl.text = "Recompensa: 💰 %d Oro   ✨ %d EXP" % [int(e.get("reward_gold", 0)), GlobalState.encargo_effective_xp(e)]
	reward_lbl.add_theme_font_size_override("font_size", 22)
	reward_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vbody.add_child(reward_lbl)

	# Botón de Aceptar
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 60)
	btn.add_theme_font_size_override("font_size", 21)
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if can_accept:
		btn.text = "📜 " + Locale.pick({"es": "Aceptar", "en": "Accept"})
		btn.disabled = false
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, UiKit.button_primary(10))
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(col, UiKit.BG_DEEP)
		btn.pressed.connect(func() -> void: _on_accept(id, e))
	else:
		btn.text = Locale.pick({"es": "Cupo Lleno", "en": "Full"})
		btn.disabled = true

	hbox.add_child(btn)
	return card


# ══════════════════════════════════════════════════════════════════════════════
# NARRATIVA Y MENSAJES ATMOSFÉRICOS
# ══════════════════════════════════════════════════════════════════════════════
func _trigger_welcome_description() -> void:
	var desc := ""
	match _city_id:
		"city_sylphrena", "sylphrena":
			desc = Locale.pick({
				"es": "Frente a ti se alza el tablón comunal de Sylphrena. Entre edictos oficiales y avisos de vecinos, varios pergaminos solicitan el auxilio de aventureros a cambio de recompensas.",
				"en": "Before you stands the community board of Sylphrena. Between town notices and official decrees, several bounties seek adventurers in exchange for renown and gold."
			})
		"city_celestia", "celestia":
			desc = Locale.pick({
				"es": "Los avisos de la Ciudad Sagrada de Celestia cuelgan con sellos dorados. Sacerdotes y eruditos ofrecen contratos a quienes demuestren su devoción y valía.",
				"en": "Notices in the Holy City of Celestia hang with golden seals. Priests and scholars offer contracts to those proving their devotion and valor."
			})
		"city_gloriam", "gloriam":
			desc = Locale.pick({
				"es": "Varios pergaminos curtidos por el sol cuelgan del tablón de Gloriam. Mercaderes y guardias del desierto buscan apoyo para sus expediciones.",
				"en": "Sun-weathered scrolls hang from Gloriam's request board. Desert merchants and guards seek assistance for dangerous expeditions."
			})
		"city_arcanum", "arcanum":
			desc = Locale.pick({
				"es": "Entre diagramas rúnicos y avisos académicos, el tablón de Arcanum reúne peticiones urgentes de contención y recolección de materiales mágicos.",
				"en": "Amid runic diagrams and academic decrees, the Arcanum board gathers urgent requests for magical containment and material gathering."
			})
		_:
			if _city_id == "":
				desc = Locale.pick({
					"es": "El tablón de campaña registra todos los contratos y compromisos actualmente asumidos en tus viajes por el reino.",
					"en": "The camp board tracks all active bounties and commitments undertaken during your travels across the realm."
				})
			else:
				desc = Locale.pick({
					"es": "Examinas los avisos fijados en el tablón. Cumple los encargos para ganar oro, experiencia y reputación.",
					"en": "You examine the notices pinned to the board. Complete tasks to earn gold, experience, and renown."
				})

	_show_text(desc)


func _on_accept(id: String, e: Dictionary) -> void:
	if GlobalState.accept_encargo(id):
		AudioManager.play_ui("click")
		var title := _encargo_title(e)
		var msg := Locale.pick({
			"es": "Has retirado el edicto del tablón. El encargo '%s' ha quedado registrado en tus misiones activas." % title,
			"en": "You pulled the notice from the board. The contract '%s' is now registered in your active quests." % title
		})
		_show_text(msg)
		UiKit.toast(self, Locale.t("enc_accepted", [title]), UiKit.ACCENT_SOFT)
		SaveManager.request_autosave()
		_refresh()


func _on_claim(id: String, e: Dictionary) -> void:
	if GlobalState.claim_encargo(id):
		AudioManager.play_ui("reward")
		var title := _encargo_title(e)
		var gold: int = int(e.get("reward_gold", 0))
		var xp: int = GlobalState.encargo_effective_xp(e)
		var msg := Locale.pick({
			"es": "Entregas las pruebas del encargo completado. ¡Has cumplido '%s' y recibido 💰 %d Oro y ✨ %d EXP!" % [title, gold, xp],
			"en": "You deliver proof of completion. Finished '%s' and received 💰 %d Gold and ✨ %d XP!" % [title, gold, xp]
		})
		_show_text(msg)
		UiKit.toast(self, Locale.t("enc_completed", [title]), UiKit.ACCENT_SOFT)
		SaveManager.request_autosave()
		_refresh()


func _on_leave_pressed() -> void:
	if _city_id != "":
		SceneManager.back_to_city()
	else:
		SceneManager.go_to_world()


func _encargo_title(e: Dictionary) -> String:
	if e.has("title_text"):
		return Locale.pick(e["title_text"])
	if e.has("title"):
		var title_val = e["title"]
		return Locale.pick(title_val) if title_val is Dictionary else String(title_val)
	if e.has("name"):
		var n = e["name"]
		return Locale.pick(n) if n is Dictionary else String(n)
	if e.has("loc"):
		var loc_key := String(e["loc"])
		var loc_t := Locale.t(loc_key)
		if not loc_t.begins_with("LOC_") and loc_t != loc_key:
			return loc_t
	var loc_id := "enc_" + String(e.get("id", ""))
	var id_t := Locale.t(loc_id)
	if not id_t.begins_with("LOC_") and id_t != loc_id:
		return id_t
	# Fallback por tipo y target
	var t := String(e.get("type", ""))
	var target := String(e.get("target", ""))
	if t == "gather":
		return "Recolección de " + target.capitalize()
	elif t == "kill":
		return "Cacería de Bestias"
	elif t == "visit":
		return "Ronda de Inspección"
	return String(e.get("id", "")).replace("_", " ").capitalize()


func _encargo_desc(e: Dictionary) -> String:
	if e.has("desc_text"):
		return Locale.pick(e["desc_text"])
	if e.has("desc"):
		var d = e["desc"]
		return Locale.pick(d) if d is Dictionary else String(d)
	if e.has("loc_desc"):
		var loc_d_key := String(e["loc_desc"])
		var loc_d := Locale.t(loc_d_key)
		if not loc_d.begins_with("LOC_") and loc_d != loc_d_key:
			return loc_d
	# Generar descripción amigable por tipo y target
	var t := String(e.get("type", ""))
	var amt: int = int(e.get("amount", 1))
	var target := String(e.get("target", ""))
	match t:
		"gather", "gather_resource":
			var res_name: String = target.capitalize()
			if target == "wood": res_name = Locale.pick({"es": "madera", "en": "wood"})
			elif target == "stone": res_name = Locale.pick({"es": "piedra", "en": "stone"})
			elif target == "gold": res_name = Locale.pick({"es": "pepitas de oro", "en": "gold nuggets"})
			elif target == "fish": res_name = Locale.pick({"es": "pescado fresco", "en": "fresh fish"})
			return Locale.pick({
				"es": "Reúne %d unidades de %s para abastecer a la ciudad." % [amt, res_name],
				"en": "Gather %d units of %s to supply the town." % [amt, res_name]
			})
		"kill", "defeat_enemy":
			return Locale.pick({
				"es": "Derrota a %d criaturas hostiles para asegurar los alrededores." % amt,
				"en": "Defeat %d hostile creatures to secure the surroundings." % amt
			})
		"visit", "visit_poi":
			return Locale.pick({
				"es": "Visita %d enclaves o edificios para inspeccionar la zona." % amt,
				"en": "Visit %d locations or buildings to inspect the area." % amt
			})
	return ""


func _type_label(t: String) -> String:
	match t:
		"gather", "gather_resource": return Locale.pick({"es": "Recolección", "en": "Gathering"})
		"kill", "defeat_enemy": return Locale.pick({"es": "Caza", "en": "Hunt"})
		"visit", "visit_poi": return Locale.pick({"es": "Exploración", "en": "Explore"})
		"dungeon_clear": return Locale.pick({"es": "Mazmorra", "en": "Dungeon"})
		_: return t.capitalize()


func _show_text(text: String) -> void:
	if _lbl_narrative == null:
		return
	_lbl_narrative.text = text
	_lbl_narrative.visible_characters = 0
	_is_typing = true
	_pulse_more_indicator(false)
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()

	_typing_tween = create_tween()
	var char_duration: float = 0.018 / maxf(Locale.text_speed, 0.1)
	_typing_tween.tween_property(_lbl_narrative, "visible_characters", text.length(), text.length() * char_duration)
	_typing_tween.finished.connect(func() -> void:
		_is_typing = false
		_pulse_more_indicator(true)
	)


func _pulse_more_indicator(show_it: bool) -> void:
	if _lbl_more_indicator == null:
		return
	_lbl_more_indicator.visible = show_it


func _on_bottom_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_typing:
			if _typing_tween and _typing_tween.is_valid():
				_typing_tween.kill()
			_lbl_narrative.visible_characters = _lbl_narrative.text.length()
			_is_typing = false
			_pulse_more_indicator(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			_on_leave_pressed()
