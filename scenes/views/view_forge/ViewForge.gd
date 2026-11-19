# ViewForge.gd
# ─────────────────────────────────────────────────────────────────────────────
# HERRERÍA / FORJA — REFINAMIENTO DE EQUIPO EN CIUDAD Y BASE
#
# En las CIUDADES (Herrero de ciudad, p. ej. Borin):
#   • Interfaz completa con fondo visual de herrería, NPC herrero a la izquierda,
#     placa de nombre, cuadro de diálogo con novela visual y catálogo de refinamiento.
#   • Permite REFINAR equipo (+0 a +10, ver task5.md / RefineManager) a cambio de ORO.
#   • Botón de retorno "🚪 Volver a la Ciudad" que regresa de forma natural a ViewCity.
# ─────────────────────────────────────────────────────────────────────────────
class_name ViewForge
extends Control

# ─── REFERENCIAS UI ───────────────────────────────────────────────────────────
var _bg_texture: TextureRect
var _title_lbl: Label
var _gold_lbl: Label
var _btn_leave: Button

var _npc_rect: TextureRect
var _dialogue_panel: PanelContainer
var _name_plate: PanelContainer
var _lbl_vn_name: Label
var _lbl_text: Label
var _lbl_more_indicator: Label

var _scroll: ScrollContainer
var _refine_list: GridContainer

# Diálogo y máquina de escribir
var _typing_tween: Tween
var _is_typing: bool = false

## Id de la ciudad y del POI ("" = Herrería propia de la Base).
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


## Configura la forja con los datos del POI / ciudad visitada.
func setup(data: Dictionary = {}) -> void:
	_city_id = String(data.get("city", ""))
	_poi_id = String(data.get("poi_id", data.get("npc", "")))
	_npc_id = String(data.get("npc", _poi_id))
	if AudioManager != null and _city_id != "":
		AudioManager.play_city_music(_city_id)
	_refresh()
	_trigger_welcome_dialogue()


## Devuelve el nombre de la herrería para la barra superior del HUD.
func get_location_name() -> String:
	if _city_id != "":
		var city_name := Locale.pick(Design.id_name(_city_id)) if Design.has_id(_city_id) else _city_id.capitalize()
		return Locale.pick({
			"es": "Forja de %s" % city_name if not city_name.is_empty() else "Forja y Taller",
			"en": "%s Forge" % city_name if not city_name.is_empty() else "Forge & Workshop"
		})
	return Locale.pick({"es": "Forja del Campamento", "en": "Camp Forge"})


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 0. Fondo dinámico de la herrería
	_bg_texture = TextureRect.new()
	_bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_texture)

	# 1. Cabecera superior translúcida
	var header := PanelContainer.new()
	header.anchor_left = 0.0
	header.anchor_right = 1.0
	header.anchor_top = 0.0
	header.anchor_bottom = 0.0
	header.offset_bottom = 74
	header.add_theme_stylebox_override("panel", UiKit.header())
	add_child(header)

	var hm := UiKit.margins(24, 24, 10, 10)
	header.add_child(hm)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hm.add_child(hbox)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 34)
	_title_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	UiKit.apply_heading(_title_lbl)
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_title_lbl)

	_gold_lbl = Label.new()
	_gold_lbl.add_theme_font_size_override("font_size", 30)
	_gold_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	_gold_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_gold_lbl)

	_btn_leave = Button.new()
	_btn_leave.custom_minimum_size = Vector2(220, 54)
	_btn_leave.add_theme_font_size_override("font_size", 24)
	_btn_leave.focus_mode = Control.FOCUS_NONE
	UiKit.premium_button(_btn_leave, {"border_width": 2.0, "corner_radius": 14.0})
	_btn_leave.pressed.connect(_on_leave_pressed)
	hbox.add_child(_btn_leave)

	# 2. Sprite del Herrero (NPC) a la izquierda, alto y majestuoso
	_npc_rect = TextureRect.new()
	_npc_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_npc_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_npc_rect.texture = load("res://assets/vn/npcs/npc_default.png") as Texture2D
	_npc_rect.anchor_left = 0.0
	_npc_rect.anchor_right = 0.0
	_npc_rect.anchor_top = 0.0
	_npc_rect.anchor_bottom = 1.0
	_npc_rect.offset_left = 60
	_npc_rect.offset_right = 530
	_npc_rect.offset_top = 80
	_npc_rect.offset_bottom = -210
	_npc_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_npc_rect)

	# 3. Lista desplazable del catálogo de refinamiento en la derecha
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 560
	scroll.offset_right = -36
	scroll.offset_top = 100
	scroll.offset_bottom = -260
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_scroll = scroll

	var cm := UiKit.margins(6, 6, 6, 6)
	cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cm)

	_refine_list = GridContainer.new()
	_refine_list.columns = 2
	_refine_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refine_list.add_theme_constant_override("h_separation", 16)
	_refine_list.add_theme_constant_override("v_separation", 12)
	cm.add_child(_refine_list)

	# 4. Caja de diálogo flotante al estilo de Novela Visual
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.anchor_left = 0.0
	_dialogue_panel.anchor_right = 1.0
	_dialogue_panel.anchor_top = 1.0
	_dialogue_panel.anchor_bottom = 1.0
	_dialogue_panel.offset_left = 24
	_dialogue_panel.offset_right = -24
	_dialogue_panel.offset_top = -240
	_dialogue_panel.offset_bottom = -16
	_dialogue_panel.gui_input.connect(_on_dialogue_panel_input)
	add_child(_dialogue_panel)

	# Placa del nombre del Herrero
	var name_wrap := HBoxContainer.new()
	name_wrap.anchor_left = 0.0
	name_wrap.anchor_right = 1.0
	name_wrap.anchor_top = 1.0
	name_wrap.anchor_bottom = 1.0
	name_wrap.offset_left = 36
	name_wrap.offset_right = -36
	name_wrap.offset_top = -290
	name_wrap.offset_bottom = -242
	name_wrap.alignment = BoxContainer.ALIGNMENT_BEGIN
	name_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_wrap)

	_name_plate = PanelContainer.new()
	name_wrap.add_child(_name_plate)

	var plate_m := UiKit.margins(22, 22, 6, 6)
	_name_plate.add_child(plate_m)

	_lbl_vn_name = Label.new()
	_lbl_vn_name.add_theme_font_size_override("font_size", 34)
	_lbl_vn_name.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	plate_m.add_child(_lbl_vn_name)
	_name_plate.visible = false

	var dm := UiKit.margins(36, 36, 20, 18)
	_dialogue_panel.add_child(dm)

	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", 10)
	dm.add_child(dbox)

	_lbl_text = Label.new()
	_lbl_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_text.add_theme_font_size_override("font_size", 34)
	_lbl_text.add_theme_constant_override("line_spacing", 6)
	_lbl_text.add_theme_color_override("font_color", UiKit.theme_color("text", UiKit.TEXT))
	_lbl_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dbox.add_child(_lbl_text)

	_lbl_more_indicator = Label.new()
	_lbl_more_indicator.text = "▼"
	_lbl_more_indicator.add_theme_font_size_override("font_size", 26)
	_lbl_more_indicator.add_theme_color_override("font_color", UiKit.ACCENT)
	_lbl_more_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_more_indicator.size_flags_horizontal = Control.SIZE_SHRINK_END
	_lbl_more_indicator.visible = false
	dbox.add_child(_lbl_more_indicator)

	_apply_theme()


func _apply_theme() -> void:
	if _dialogue_panel != null:
		UiKit.premium_frame(_dialogue_panel, {"pad": 0})
	if _name_plate != null:
		UiKit.premium_frame(_name_plate, {"pad": 0, "border_width": 3.0, "corner_radius": 14.0})
	if _lbl_vn_name != null:
		_lbl_vn_name.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	if _btn_leave != null:
		UiKit.premium_button(_btn_leave, {"border_width": 2.0, "corner_radius": 14.0})


# ══════════════════════════════════════════════════════════════════════════════
# RENDERIZADO Y ACTUALIZACIÓN
# ══════════════════════════════════════════════════════════════════════════════
func _refresh() -> void:
	if _title_lbl == null:
		return

	var via_city := _city_id != ""
	if _poi_id != "" and Design.has_id(_poi_id):
		_title_lbl.text = "🛠️ %s" % Locale.pick(Design.id_name(_poi_id))
	elif via_city:
		_title_lbl.text = "🛠️ %s — %s" % [Locale.t("forge_title_city"), Locale.pick(Design.id_name(_city_id))]
	else:
		_title_lbl.text = "🛠️ %s" % Locale.t("forge_title")

	_gold_lbl.text = "💰 %d" % GlobalState.gold
	_btn_leave.text = Locale.pick({"es": "🚪 Volver a la Ciudad", "en": "🚪 Back to City"}) if via_city else Locale.t("forge_leave")

	# Cargar fondo dinámico
	var bg_tex: Texture2D = null
	if _poi_id != "" and Design.has_id(_poi_id):
		var spec: Dictionary = Design.get_id(_poi_id)
		var explicit_bg: String = String(spec.get("bg", ""))
		if explicit_bg != "":
			bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/" + explicit_bg)
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_city_sylphrena_herrero.png")
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/common/ui/bg_default.png")

	if _bg_texture and bg_tex:
		_bg_texture.texture = bg_tex

	_refresh_npc_avatar()
	_render_refine_list()


func _refresh_npc_avatar() -> void:
	var actor_id := _npc_id if _npc_id != "" else _poi_id
	var npc_tex: Texture2D = null

	if actor_id != "":
		if _poi_id != "" and Design.has_id(_poi_id):
			var spec: Dictionary = Design.get_id(_poi_id)
			var bg_name: String = String(spec.get("bg", ""))
			if bg_name.begins_with("bg_"):
				npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/npc_" + bg_name.substr(3))
		if not npc_tex:
			npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/npc_%s.png" % actor_id)
		if not npc_tex:
			npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/npc_city_sylphrena_herrero.png")
		if not npc_tex:
			npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/npc_default.png")

		var npc_name := ""
		if Design.has_npc(actor_id):
			npc_name = Locale.pick(Design.npc_meta(actor_id).get("name", {}))
		elif Design.has_id(actor_id):
			npc_name = Locale.pick(Design.id_name(actor_id))
		else:
			npc_name = Locale.pick({"es": "Borin el Herrero", "en": "Borin the Smith"})

		if _npc_rect and npc_tex:
			_npc_rect.texture = npc_tex
			_npc_rect.visible = true

		if _lbl_vn_name:
			_lbl_vn_name.text = npc_name
		if _name_plate:
			_name_plate.visible = npc_name != ""
	else:
		if _npc_rect:
			_npc_rect.visible = false
		if _name_plate:
			_name_plate.visible = false


func _trigger_welcome_dialogue() -> void:
	var welcome_text := Locale.pick({
		"es": "¡Saludos! Pon tu arma o armadura sobre el yunque. Por unas monedas de oro aumentaré el temple, filo y atributos de tu equipo.",
		"en": "Greetings! Place your weapon or armor on the anvil. For a few gold coins I will temper and enhance your gear's stats."
	})
	_show_text(welcome_text)


func _render_refine_list() -> void:
	for c in _refine_list.get_children():
		c.queue_free()

	var via_city: bool = _city_id != ""
	var any_refine := false

	for item: Dictionary in GlobalState.inventory:
		if String(item.get("category", "")) == "equipment" and item.get("resource") is EquipmentResource:
			_refine_list.add_child(_make_refine_card(item, via_city))
			any_refine = true

	if not any_refine:
		var empty_lbl := Label.new()
		empty_lbl.text = Locale.pick({
			"es": "No tienes piezas de equipo en tu bolsa para refinar.",
			"en": "You have no equipment in your bag to refine."
		})
		empty_lbl.add_theme_font_size_override("font_size", 20)
		empty_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTED)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_refine_list.add_child(empty_lbl)


# ══════════════════════════════════════════════════════════════════════════════
# TARJETA DE REFINAMIENTO DE EQUIPO
# ══════════════════════════════════════════════════════════════════════════════
func _make_refine_card(item: Dictionary, via_city: bool) -> Control:
	var item_id: String = String(item.get("id", ""))
	var res: EquipmentResource = item.get("resource")
	var level: int = res.refine_level
	var at_max: bool = level >= GameConfig.REFINE_MAX_LEVEL
	var affordable: bool = not at_max and GlobalState.can_refine(item_id, via_city)
	var tint: Color = UiKit.ACCENT if affordable else UiKit.BORDER
	if res.rarity != "":
		tint = Color(GameConfig.get_rarity(res.rarity).get("color", "b8c0cc"))

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(280, 96)
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(tint, 14, 0))

	var margin := UiKit.margins(16, 16, 10, 10)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	var icon := Label.new()
	icon.text = String(item.get("icon", "🗡️"))
	icon.add_theme_font_size_override("font_size", 40)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(50, 50)
	hbox.add_child(UiKit.with_corner_badge(icon, UiKit.refine_badge(level)))

	var vtext := VBoxContainer.new()
	vtext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vtext.alignment = BoxContainer.ALIGNMENT_CENTER
	vtext.add_theme_constant_override("separation", 3)
	hbox.add_child(vtext)

	var name_lbl := Label.new()
	var raw_name: String = String(item.get("name", "?"))
	name_lbl.text = raw_name + (" (+%d)" % level if level > 0 else "")
	name_lbl.add_theme_font_size_override("font_size", 25)
	name_lbl.add_theme_color_override("font_color", tint)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vtext.add_child(name_lbl)

	# Subtítulo con bonus actuales y previsión
	var sub_lbl := Label.new()
	sub_lbl.text = _equip_stats_text(res)
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTED)
	sub_lbl.clip_text = true
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vtext.add_child(sub_lbl)

	# Aviso de riesgo si nivel >= 4
	if not at_max and level >= GameConfig.REFINE_RISK_FROM_LEVEL:
		var risk: Dictionary = GameConfig.REFINE_RISK.get(level, {})
		var back_pct: int = int(round(float(risk.get("back", 0.0)) * 100.0))
		var stay_pct: int = int(round(float(risk.get("stay", 0.0)) * 100.0))
		var success_pct: int = 100 - back_pct - stay_pct
		var risk_lbl := Label.new()
		risk_lbl.text = Locale.t("forge_refine_risk", [success_pct, stay_pct, back_pct])
		risk_lbl.add_theme_font_size_override("font_size", 16)
		risk_lbl.add_theme_color_override("font_color", UiKit.BAD if back_pct > 0 else UiKit.ACCENT_SOFT)
		vtext.add_child(risk_lbl)

	# Botón de refinar
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(125, 72)
	btn.add_theme_font_size_override("font_size", 20)
	btn.focus_mode = Control.FOCUS_NONE

	if at_max:
		btn.text = "✨ Nivel Máx\n(+10)"
		btn.disabled = true
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(st, UiKit.button_ghost(12))
		btn.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
	else:
		var gold_cost: int = GameConfig.refine_gold_cost(level)
		btn.text = "Refinar (+%d)\n💰 %d" % [level + 1, gold_cost]
		btn.disabled = not affordable
		if affordable:
			for st in ["normal", "hover", "pressed", "focus"]:
				btn.add_theme_stylebox_override(st, UiKit.button_primary(12))
			for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				btn.add_theme_color_override(col, UiKit.BG_DEEP)
		btn.pressed.connect(func() -> void: _on_refine(item_id, via_city))

	hbox.add_child(btn)
	return card


func _equip_stats_text(res: EquipmentResource) -> String:
	var parts: Array[String] = []
	for k in res.stat_bonuses.keys():
		parts.append("%s +%d" % [String(k).to_upper(), int(res.stat_bonuses[k])])
	var labels := {
		"phys_damage": "🗡️", "mag_damage": "🔮", "range_damage": "🏹",
		"phys_defense": "🛡️", "mag_defense": "✨",
	}
	for f in labels.keys():
		var val: int = int(res.get(f))
		if val > 0:
			parts.append("%s +%d" % [labels[f], val])
	if res.refine_level > 0:
		parts.append("[+%d%% bonus]" % (res.refine_level * 10))
	return "  ".join(parts)


# ══════════════════════════════════════════════════════════════════════════════
# GESTIÓN DE ACCIONES Y TEXTO
# ══════════════════════════════════════════════════════════════════════════════
func _on_refine(item_id: String, via_city: bool) -> void:
	var result: Dictionary = GlobalState.refine_item(item_id, via_city)
	if not result.get("ok", false):
		AudioManager.play_ui("error")
		var no_gold_msg := Locale.pick({
			"es": "No tienes suficiente oro para costear el temple de esta pieza.",
			"en": "You don't have enough gold to afford tempering this item."
		})
		_show_text(no_gold_msg)
		UiKit.toast(self, Locale.t("forge_no_gold" if via_city else "forge_no_res"), UiKit.BAD)
		return

	var item_name: String = String(result.get("name", ""))
	var new_level: int = int(result.get("new_level", 0))

	if result.get("backfired", false):
		AudioManager.play_ui("error")
		var backfire_msg := Locale.pick({
			"es": "¡Maldición! El acero ha sufrido una impureza al templar... %s ha bajado a nivel +%d." % [item_name, new_level],
			"en": "Blast it! An impurity surfaced during tempering... %s dropped to +%d." % [item_name, new_level]
		})
		_show_text(backfire_msg)
		UiKit.toast(self, Locale.t("forge_refine_backfire", [item_name, new_level]), UiKit.BAD)
	elif result.get("success", false):
		AudioManager.play_ui("reward")
		var success_msg := Locale.pick({
			"es": "¡Magnífico temple! Tu %s ha alcanzado el nivel +%d (+%d%% de eficacia extra)." % [item_name, new_level, new_level * 10],
			"en": "Magnificent tempering! Your %s reached +%d (+%d%% extra effectiveness)." % [item_name, new_level, new_level * 10]
		})
		_show_text(success_msg)
		UiKit.toast(self, Locale.t("forge_refine_success", [item_name, new_level]), UiKit.ACCENT_SOFT)
	else:
		AudioManager.play_ui("cancel")
		var stay_msg := Locale.pick({
			"es": "El temple no ha cuajado esta vez, pero el acero se ha mantenido firme en nivel +%d." % new_level,
			"en": "The temper didn't take this time, but the steel held firm at level +%d." % new_level
		})
		_show_text(stay_msg)
		UiKit.toast(self, Locale.t("forge_refine_stay", [item_name, new_level]), UiKit.TEXT_DIM)

	SaveManager.request_autosave()
	_refresh()


func _on_leave_pressed() -> void:
	if _city_id != "":
		SceneManager.back_to_city()
	else:
		SceneManager.go_to_world()


func _show_text(text: String) -> void:
	if _lbl_text == null:
		return
	_lbl_text.text = text
	_lbl_text.visible_characters = 0
	_is_typing = true
	_pulse_more_indicator(false)
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()

	_typing_tween = create_tween()
	var char_duration: float = 0.022 / maxf(Locale.text_speed, 0.1)
	_typing_tween.tween_property(_lbl_text, "visible_characters", text.length(), text.length() * char_duration)
	_typing_tween.finished.connect(func() -> void:
		_is_typing = false
		_pulse_more_indicator(true)
	)


func _pulse_more_indicator(show_it: bool) -> void:
	if _lbl_more_indicator == null:
		return
	_lbl_more_indicator.visible = show_it


func _on_dialogue_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_typing:
			if _typing_tween and _typing_tween.is_valid():
				_typing_tween.kill()
			_lbl_text.visible_characters = _lbl_text.text.length()
			_is_typing = false
			_pulse_more_indicator(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			_on_leave_pressed()


func _on_leave() -> void:
	_on_leave_pressed()
