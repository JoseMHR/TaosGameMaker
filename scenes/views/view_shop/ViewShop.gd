# ViewShop.gd
# Vista de la Tienda (se abre desde una ciudad). Muestra el catálogo de la ciudad
# obtenido con GameConfig.get_shop_stock(stock_id) — equipo y consumibles. Comprar
# descuenta oro y añade el ítem a la bolsa.
# Incorpora una caja de diálogo inferior idéntica a la de los POIs. El avatar del mercader
# se sitúa a la izquierda y el catálogo a la derecha.
class_name ViewShop
extends Control

# ─── REFERENCIAS UI (construidas por código) ──────────────────────────────────
var _bg_texture: TextureRect
var _title_lbl: Label
var _gold_lbl: Label
var _list: GridContainer
var _btn_leave: Button
var _npc_rect: TextureRect
var _scroll: ScrollContainer

# Arrastre con el ratón para desplazar el catálogo (click-drag): en móvil el
# ScrollContainer ya soporta el arrastre táctil de forma nativa, pero con ratón
# solo respondía a la rueda. Este arrastre replica el gesto con el puntero para
# que la lista se pueda mover pulsando y arrastrando (útil en escritorio y como
# refuerzo del gesto táctil).
var _drag_active: bool = false
var _drag_last_y: float = 0.0

# Elementos del diálogo inferior (novela visual)
var _dialogue_panel: PanelContainer
var _name_plate: PanelContainer
var _lbl_vn_name: Label
var _lbl_text: Label
var _lbl_more_indicator: Label

# ─── ESTADO ───────────────────────────────────────────────────────────────────
var _poi_id: String = ""
var _city_id: String = ""
var _stock_id: String = "default"
var _npc_id: String = ""

# Tabs de filtrado del catálogo ("all" | "consumable" | "equipment").
var _active_shop_tab: String = "all"
var _tab_btns: Dictionary = {}   # key -> Button

# Animación de diálogo
var _typing_tween: Tween = null
var _indicator_tween: Tween = null
var _is_typing: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GlobalState.state_updated.connect(_on_state_updated)
	Locale.locale_changed.connect(_refresh)
	Locale.theme_changed.connect(func(_id: String) -> void: _apply_dialogue_theme())


func _on_state_updated() -> void:
	if is_visible_in_tree():
		_refresh_dynamic(false)


## Arrastre con el ratón (click-drag) para desplazar el catálogo. Se procesa en
## `_input` (no en `_gui_input`) para que funcione también al arrastrar por encima
## de los botones de compra, sin CONSUMIR el evento: un clic sin movimiento sigue
## llegando al botón y compra igual; un clic con arrastre desplaza la lista.
func _input(ev: InputEvent) -> void:
	if _scroll == null or not is_visible_in_tree():
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and _scroll.get_global_rect().has_point(ev.position):
			_drag_active = true
			_drag_last_y = ev.position.y
		else:
			_drag_active = false
	elif ev is InputEventMouseMotion and _drag_active:
		var dy: float = ev.position.y - _drag_last_y
		_drag_last_y = ev.position.y
		_scroll.scroll_vertical -= int(dy)


## Carga la tienda usando el poi_id o diccionario de datos para resolver fondo, stock e historia del mercader.
func setup(data_or_id) -> void:
	if data_or_id is Dictionary:
		_poi_id = String(data_or_id.get("poi_id", data_or_id.get("event_id", "")))
		_city_id = String(data_or_id.get("city", ""))
		_npc_id = String(data_or_id.get("npc", ""))
	else:
		_poi_id = String(data_or_id)
		_city_id = ""
		_npc_id = ""

	if data_or_id is Dictionary and data_or_id.has("stock") and String(data_or_id["stock"]) != "":
		_stock_id = String(data_or_id["stock"])
	else:
		var spec := Design.get_id(_poi_id)
		_stock_id = String(spec.get("stock", "default"))
	if _npc_id == "" or _npc_id == _poi_id:
		var spec := Design.get_id(_poi_id)
		_npc_id = String(spec.get("npc", ""))

	if AudioManager != null and _city_id != "":
		AudioManager.play_city_music(_city_id)

	_setup_visuals()
	_refresh_dynamic(true)

	# Diálogo inicial de bienvenida
	_trigger_welcome_dialogue()

	# Efecto de revelado de la vista
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	# 1. Imagen de fondo
	_bg_texture = TextureRect.new()
	_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_texture.texture = load("res://assets/common/ui/bg_default.png") as Texture2D
	_bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_texture)

	# 1b. Dimmer de fondo
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# 2. Cabecera superior
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", UiKit.header(0.85))
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.custom_minimum_size = Vector2(0, 110)
	add_child(header)

	var hm := UiKit.margins(24, 24, 14, 14)
	header.add_child(hm)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hm.add_child(hbox)
	
	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 34)
	_title_lbl.add_theme_color_override("font_color", UiKit.TEXT)
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

	# 2. Sprite del Mercader (NPC) - Alto, majestuoso y con amplio margen lateral
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

	# 3. Lista desplazable del catálogo en 2 columnas proporcionadas
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

	var cvbox := VBoxContainer.new()
	cvbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cvbox.add_theme_constant_override("separation", 10)
	cm.add_child(cvbox)

	# Tabs de filtrado: Todo / Consumible / Equipo — antes iba todo mezclado
	# en una sola lista larga sin forma de acotar la búsqueda.
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 8)
	cvbox.add_child(tabs_row)
	var tab_defs := [
		{"key": "all", "label": Locale.pick({"es": "🗂️ Todo", "en": "🗂️ All"})},
		{"key": "consumable", "label": Locale.pick({"es": "🧪 Consumible", "en": "🧪 Consumable"})},
		{"key": "equipment", "label": Locale.pick({"es": "🛡️ Equipo", "en": "🛡️ Equipment"})},
	]
	for tdef in tab_defs:
		var tkey: String = tdef["key"]
		var tbtn := Button.new()
		tbtn.text = tdef["label"]
		tbtn.custom_minimum_size = Vector2(0, 44)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.focus_mode = Control.FOCUS_NONE
		tbtn.pressed.connect(func() -> void:
			_active_shop_tab = tkey
			_render_stock()
		)
		UiKit.bind_press_feedback(tbtn)
		tabs_row.add_child(tbtn)
		_tab_btns[tkey] = tbtn

	_list = GridContainer.new()
	_list.columns = 2
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("h_separation", 16)
	_list.add_theme_constant_override("v_separation", 12)
	cvbox.add_child(_list)

	# 4. Caja de diálogo flotante al estilo de los POIs / Novela Visual
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

	# Placa del nombre
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

	# Indicador de continuación
	_lbl_more_indicator = Label.new()
	_lbl_more_indicator.text = "▼"
	_lbl_more_indicator.add_theme_font_size_override("font_size", 26)
	_lbl_more_indicator.add_theme_color_override("font_color", UiKit.ACCENT)
	_lbl_more_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_more_indicator.size_flags_horizontal = Control.SIZE_SHRINK_END
	_lbl_more_indicator.visible = false
	dbox.add_child(_lbl_more_indicator)

	_apply_dialogue_theme()


## Aplica los marcos del tema seleccionado al panel de diálogo y placa de nombre.
func _apply_dialogue_theme() -> void:
	if _dialogue_panel != null:
		UiKit.premium_frame(_dialogue_panel, {"pad": 0})
	if _name_plate != null:
		UiKit.premium_frame(_name_plate, {"pad": 0, "border_width": 3.0, "corner_radius": 14.0})
	if _lbl_vn_name != null:
		_lbl_vn_name.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	if _btn_leave != null:
		UiKit.premium_button(_btn_leave, {"border_width": 2.0, "corner_radius": 12.0})


# ══════════════════════════════════════════════════════════════════════════════
# RENDER
# ══════════════════════════════════════════════════════════════════════════════
func _setup_visuals() -> void:
	if _title_lbl == null:
		return
	
	_title_lbl.text = Locale.pick(Design.id_name(_poi_id)) if _poi_id != "" else Locale.t("shop_title")
	_btn_leave.text = Locale.t("shop_leave")
	
	# Cargar fondo dinámico de la tienda (una sola vez por sesión)
	var bg_tex: Texture2D = null
	if _poi_id != "" and Design.has_id(_poi_id):
		var spec := Design.get_id(_poi_id)
		var explicit_bg: String = String(spec.get("bg", ""))
		if explicit_bg != "":
			bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/" + explicit_bg)
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_shop_%s.png" % _stock_id)
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_shop_default.png")
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/common/ui/bg_default.png")
	if _bg_texture and bg_tex:
		_bg_texture.texture = bg_tex

	# Cargar avatar y nombre del NPC (una sola vez)
	_refresh_npc_avatar()


func _refresh() -> void:
	_setup_visuals()
	_refresh_dynamic(true)


func _refresh_dynamic(rebuild_cards: bool = false) -> void:
	if _gold_lbl != null:
		_gold_lbl.text = "💰 %d" % GlobalState.gold
	if rebuild_cards or _list == null or _list.get_child_count() == 0:
		_render_stock()
	else:
		_update_stock_cards()


func _refresh_npc_avatar() -> void:
	if _npc_id != "" and Design.has_npc(_npc_id):
		var meta := Design.npc_meta(_npc_id)
		
		# Cargar textura del NPC con simetría 1:1 respecto a su fondo de escenario
		var npc_tex: Texture2D = null
		if _poi_id != "" and Design.has_id(_poi_id):
			var spec: Dictionary = Design.get_id(_poi_id)
			var bg_name: String = String(spec.get("bg", ""))
			if bg_name.begins_with("bg_"):
				npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/npc_" + bg_name.substr(3))
		if not npc_tex:
			npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/npc_%s.png" % _npc_id)
		if not npc_tex:
			npc_tex = UiKit.load_texture_safe("res://assets/vn/npcs/npc_default.png")
		if _npc_rect and npc_tex:
			_npc_rect.texture = npc_tex
			_npc_rect.visible = true
			
		# Mostrar nombre
		var npc_name := Locale.pick(meta.get("name", {}))
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
	if _npc_id != "" and Design.has_npc(_npc_id):
		var entry_node_id := Design.entry_node(_npc_id)
		var node: Dictionary = Design.get_npc(_npc_id).get(entry_node_id, {})
		var full_text := Locale.pick(node.get("text", {}))
		_show_text(full_text)
		GlobalState.report_visit(_npc_id)
	else:
		var default_txt := Locale.pick({
			"es": "¡Bienvenido! Echa un vistazo a mis mercancías.",
			"en": "Welcome! Take a look at my wares."
		})
		_show_text(default_txt)


func _show_text(text: String) -> void:
	if _lbl_text == null:
		return
	_lbl_text.text = text
	_lbl_text.visible_characters = 0
	_is_typing = true
	_pulse_more_indicator(false)
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()
	
	# /§14: la velocidad del typewriter respeta el ajuste de
	# accesibilidad `Locale.text_speed`, igual que ViewBuilding y NarrativeOverlay
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
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	if show_it:
		_lbl_more_indicator.modulate.a = 0.4
		_indicator_tween = _lbl_more_indicator.create_tween().set_loops()
		_indicator_tween.tween_property(_lbl_more_indicator, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_indicator_tween.tween_property(_lbl_more_indicator, "modulate:a", 0.4, 0.45).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _on_dialogue_panel_input(ev: InputEvent) -> void:
	var clicked := false
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			clicked = true
	elif ev is InputEventScreenTouch:
		if ev.pressed:
			clicked = true
			
	if clicked:
		if _is_typing:
			_is_typing = false
			if _typing_tween and _typing_tween.is_valid():
				_typing_tween.kill()
			_lbl_text.visible_characters = _lbl_text.text.length()
			_pulse_more_indicator(true)
		else:
			# Si ya terminó de escribir, interacción adicional o saludo
			AudioManager.play_ui("talk")


func _render_stock() -> void:
	for key in _tab_btns:
		UiKit.style_segmented_tab(_tab_btns[key], key == _active_shop_tab)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for item: Dictionary in GameConfig.get_shop_stock(_stock_id):
		var item_id: String = String(item["id"])
		var is_equipment: bool = String(Design.get_item(item_id).get("category", "")) == "equipment"
		if _active_shop_tab == "consumable" and is_equipment:
			continue
		if _active_shop_tab == "equipment" and not is_equipment:
			continue
		_list.add_child(_make_item_card(item))


func _make_item_card(item: Dictionary) -> Control:
	var item_id: String = String(item["id"])
	var def: Dictionary = Design.get_item(item_id)
	var is_equipment: bool = String(def.get("category", "")) == "equipment"
	var is_unique: bool = is_equipment or item_id == "tent"
	var is_sold_out: bool = is_unique and GlobalState.is_shop_item_sold_out(_stock_id, item_id)
	var base_price: int = int(item["price"])
	var price: int = GlobalState.charm_price(base_price)
	var can_afford: bool = GlobalState.gold >= price and not is_sold_out
	var owned: int = int(GlobalState.get_item(item_id).get("quantity", 0))

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(280, 96)
	if is_sold_out:
		card.add_theme_stylebox_override("panel", UiKit.card_tinted(UiKit.TEXT_DIM, 14, 0))
		card.modulate = Color(0.7, 0.7, 0.75, 0.6)
	else:
		# Marco por tipo: equipo en azul (UiKit.MP), consumibles/otros en verde
		# (UiKit.GOOD) — antes todo se enmarcaba en verde sin distinción.
		card.add_theme_stylebox_override("panel", UiKit.card_tinted(UiKit.MP if is_equipment else UiKit.GOOD, 14, 0))
	var margin := UiKit.margins(16, 16, 10, 10)
	card.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	var icon := Label.new()
	icon.text = Design.get_item_icon(item_id)
	icon.add_theme_font_size_override("font_size", 40)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon)

	var vtext := VBoxContainer.new()
	vtext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vtext.alignment = BoxContainer.ALIGNMENT_CENTER
	vtext.add_theme_constant_override("separation", 3)
	hbox.add_child(vtext)

	var name_lbl := Label.new()
	var raw_name := Design.get_item_name(item_id)
	name_lbl.text = raw_name + "  [AGOTADO]" if is_sold_out else raw_name
	name_lbl.add_theme_font_size_override("font_size", 25)
	if is_sold_out:
		name_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	else:
		name_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vtext.add_child(name_lbl)

	# Subtítulo: bonificaciones (equipo) o efecto de curación (consumible)
	var sub_lbl := Label.new()
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", UiKit.TEXT_MUTED)
	sub_lbl.clip_text = true
	sub_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_equipment:
		sub_lbl.text = _equip_text(def)
	elif item_id == "tent":
		sub_lbl.text = "⛺ Campamento base en el mapa"
	else:
		var heal: int = int(def.get("effects", {}).get("heal", 0))
		var heal_pct: float = float(def.get("effects", {}).get("heal_pct", 0.0))
		if heal > 0:
			sub_lbl.text = Locale.t("derived_hp") + " +%d" % heal
		elif heal_pct > 0:
			sub_lbl.text = Locale.t("derived_hp") + " +%d%%" % int(heal_pct * 100)
		else:
			sub_lbl.text = Locale.pick(def.get("desc", {}))
	vtext.add_child(sub_lbl)

	var h_info := HBoxContainer.new()
	h_info.add_theme_constant_override("separation", 10)
	vtext.add_child(h_info)

	var owned_lbl := Label.new()
	owned_lbl.text = Locale.t("shop_owned", [owned])
	owned_lbl.add_theme_font_size_override("font_size", 17)
	owned_lbl.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
	h_info.add_child(owned_lbl)

	# Nota de precio ajustado por carisma
	if not is_sold_out and price != base_price:
		var note := Label.new()
		note.add_theme_font_size_override("font_size", 17)
		if price < base_price:
			note.text = "💬 −%d%% (%d)" % [int(round((1.0 - float(price) / float(base_price)) * 100.0)), base_price]
			note.add_theme_color_override("font_color", UiKit.GOOD)
		else:
			note.text = "💬 +%d%% (%d)" % [int(round((float(price) / float(base_price) - 1.0) * 100.0)), base_price]
			note.add_theme_color_override("font_color", UiKit.HP)
		h_info.add_child(note)

	# Botón de compra con el precio
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(115, 72)
	btn.add_theme_font_size_override("font_size", 22)
	btn.focus_mode = Control.FOCUS_NONE
	
	if is_sold_out:
		btn.text = "🔒 Agotado"
		btn.disabled = true
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			btn.add_theme_stylebox_override(st, UiKit.button_ghost(12))
		btn.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
	else:
		btn.text = "%s\n💰 %d" % [Locale.t("shop_buy"), price]
		btn.disabled = not can_afford
		if can_afford:
			for st in ["normal", "hover", "pressed", "focus"]:
				btn.add_theme_stylebox_override(st, UiKit.button_primary(12))
			for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				btn.add_theme_color_override(col, UiKit.BG_DEEP)
		btn.pressed.connect(func() -> void: _on_buy(item))
	card.set_meta("item_id", item_id)
	card.set_meta("base_price", base_price)
	card.set_meta("price", price)
	card.set_meta("is_unique", is_unique)
	card.set_meta("is_equipment", is_equipment)
	card.set_meta("raw_name", raw_name)
	card.set_meta("owned_lbl", owned_lbl)
	card.set_meta("name_lbl", name_lbl)
	card.set_meta("btn", btn)

	hbox.add_child(btn)
	return card


## Actualiza en caliente las tarjetas existentes (cantidad poseída, estado de compra y agotado)
## sin destruir ni recrear los nodos de la interfaz.
func _update_stock_cards() -> void:
	if _list == null:
		return
	for card in _list.get_children():
		if not (card is Control) or not card.has_meta("item_id"):
			continue
		var item_id: String = String(card.get_meta("item_id"))
		var price: int = int(card.get_meta("price", 0))
		var is_unique: bool = bool(card.get_meta("is_unique", false))
		var is_equipment: bool = bool(card.get_meta("is_equipment", false))
		var is_sold_out: bool = is_unique and GlobalState.is_shop_item_sold_out(_stock_id, item_id)
		var can_afford: bool = GlobalState.gold >= price and not is_sold_out
		var owned: int = int(GlobalState.get_item(item_id).get("quantity", 0))

		var owned_lbl: Label = card.get_meta("owned_lbl", null) as Label
		if owned_lbl:
			owned_lbl.text = Locale.t("shop_owned", [owned])

		var name_lbl: Label = card.get_meta("name_lbl", null) as Label
		var raw_name: String = String(card.get_meta("raw_name", ""))
		var btn: Button = card.get_meta("btn", null) as Button

		if is_sold_out:
			card.add_theme_stylebox_override("panel", UiKit.card_tinted(UiKit.TEXT_DIM, 14, 0))
			card.modulate = Color(0.7, 0.7, 0.75, 0.6)
			if name_lbl:
				name_lbl.text = raw_name + "  [AGOTADO]"
				name_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			if btn:
				btn.text = "🔒 Agotado"
				btn.disabled = true
				for st in ["normal", "hover", "pressed", "focus", "disabled"]:
					btn.add_theme_stylebox_override(st, UiKit.button_ghost(12))
				btn.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		else:
			card.add_theme_stylebox_override("panel", UiKit.card_tinted(UiKit.MP if is_equipment else UiKit.GOOD, 14, 0))
			card.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if name_lbl:
				name_lbl.text = raw_name
				name_lbl.add_theme_color_override("font_color", UiKit.TEXT)
			if btn:
				btn.text = "%s\n💰 %d" % [Locale.t("shop_buy"), price]
				btn.disabled = not can_afford
				if can_afford:
					for st in ["normal", "hover", "pressed", "focus"]:
						btn.add_theme_stylebox_override(st, UiKit.button_primary(12))
					for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
						btn.add_theme_color_override(col, UiKit.BG_DEEP)
				else:
					for st in ["normal", "hover", "pressed", "focus", "disabled"]:
						btn.remove_theme_stylebox_override(st)
					for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
						btn.remove_theme_color_override(col)


# ══════════════════════════════════════════════════════════════════════════════
# COMPRA
# ══════════════════════════════════════════════════════════════════════════════
func _on_buy(item: Dictionary) -> void:
	var item_id: String = String(item["id"])
	var def: Dictionary = Design.get_item(item_id)
	var is_equipment: bool = String(def.get("category", "")) == "equipment"
	var is_unique: bool = is_equipment or item_id == "tent"
	
	if is_unique and GlobalState.is_shop_item_sold_out(_stock_id, item_id):
		AudioManager.play_ui("error")
		UiKit.toast(self, "Este artículo ya está agotado en esta tienda.", UiKit.BAD)
		return

	var price: int = GlobalState.charm_price(int(item["price"]))
	var item_name: String = Design.get_item_name(item_id)
	
	if GlobalState.gold < price:
		var error_msg := Locale.pick({
			"es": "Disculpa, no tienes suficiente oro para comprar %s." % item_name,
			"en": "I'm sorry, you do not have enough gold to buy %s." % item_name
		})
		_show_text(error_msg)
		AudioManager.play_ui("error")
		UiKit.toast(self, Locale.t("shop_no_gold"), UiKit.BAD)
		return
		
	GlobalState.gold -= price
	var empty_slot: String = ""
	if is_equipment:
		empty_slot = String(def.get("slot", ""))
		if empty_slot != "" and GlobalState.equipped.get(empty_slot) != null:
			empty_slot = ""   # la ranura ya tiene algo puesto: no hace falta preguntar
		GlobalState.add_equipment_item(item_id)
	else:
		GlobalState.add_item(item_id, 1)
		
	if is_unique:
		GlobalState.record_shop_purchase(_stock_id, item_id)
	
	var thank_msg := Locale.pick({
		"es": "¡Muchas gracias! Has adquirido %s." % item_name,
		"en": "Thank you very much! You have acquired %s." % item_name
	})
	_show_text(thank_msg)
	
	AudioManager.play_ui("success")
	UiKit.toast(self, Locale.t("shop_bought", [item_name]), UiKit.ACCENT_SOFT)
	SaveManager.request_autosave()
	_update_stock_cards()

	# Ranura vacía: ofrece equipar de inmediato la pieza recién comprada, sin
	# tener que ir a la bolsa a hacerlo a mano.
	if empty_slot != "":
		UiKit.confirm(self,
			Locale.pick({"es": "¿Equipar ahora?", "en": "Equip now?"}),
			Locale.pick({
				"es": "Veo que no tienes nada equipado en esa ranura. ¿Te lo quieres poner?",
				"en": "I see you have nothing equipped in that slot. Would you like to wear it?"
			}),
			Locale.pick({"es": "Sí, equipar", "en": "Yes, equip"}),
			Locale.pick({"es": "No, gracias", "en": "No, thanks"}),
			func() -> void:
				GlobalState.equip_item(item_id)
				AudioManager.play_ui("confirm")
				UiKit.toast(self, Locale.pick({"es": "✅ %s equipado." % item_name, "en": "✅ %s equipped." % item_name}), UiKit.ACCENT_SOFT)
				SaveManager.request_autosave()
				_update_stock_cards()
		)


## Texto combinado de bonus de característica + bonus de combate + cualidades de una pieza de tienda.
func _equip_text(item: Dictionary) -> String:
	var parts: Array[String] = []
	var combat: Dictionary = item.get("combat", {})
	var labels := {
		"phys_damage": "🗡️", "mag_damage": "🔮", "range_damage": "🏹",
		"phys_defense": "🛡️", "mag_defense": "✨",
	}
	for k in labels:
		if int(combat.get(k, 0)) != 0:
			parts.append("%s +%d" % [labels[k], int(combat[k])])
	var bonuses: Dictionary = item.get("bonuses", {})
	for k in bonuses:
		if int(bonuses[k]) != 0:
			parts.append("%s +%d" % [String(k).to_upper(), int(bonuses[k])])
	
	# Cualidad / Refinamiento
	var traits: Array = item.get("traits", [])
	if not traits.is_empty():
		var t0: Dictionary = traits[0]
		var t_desc: String = String(t0.get("desc", ""))
		var min_ref: int = int(t0.get("min_refine", 0))
		if t_desc != "":
			if min_ref > 0:
				parts.append("✨ [Refine +%d: %s]" % [min_ref, t_desc])
			else:
				parts.append("✨ [%s]" % t_desc)
	return "  ".join(parts)


func _on_leave_pressed() -> void:
	if _city_id != "":
		SceneManager.back_to_city()
	else:
		SceneManager.go_to_world()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			_on_leave_pressed()

