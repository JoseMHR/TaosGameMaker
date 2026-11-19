# CharacterHubModal.gd
# Hub Macro de Personaje Unificado — Modal Flotante sobre el mundo 3D (30% Izq / 70% Der)
class_name CharacterHubModal
extends Control

signal closed
## El Hub ya NO embebe su propia copia de OptionsMenu dentro de `_content_panel`
## (quedaba encogida en el panel de contenido y con fallos de foco/tema
## distintos a los del menú grande de ESC). Emitida cuando el usuario pulsa la
## pestaña "⚙️ Opciones": quien escuche debe cerrar el Hub y abrir el MISMO
## menú de Opciones autosuficiente que usa ESC (`GameRoot._open_menu()`).
signal request_standalone_options

var _scrim_bg: ColorRect
var _header_panel: PanelContainer
var _tab_buttons: Dictionary = {}
var _content_panel: PanelContainer

var _views: Dictionary = {}
var _active_tab: String = "character"
var _subtab_request: String = ""

const TABS: Array[Dictionary] = [
	{"id": "character",   "icon": "👤", "name_es": "Personaje",   "name_en": "Character"},
	{"id": "equip",       "icon": "🛡️", "name_es": "Equipo",      "name_en": "Equipment"},
	{"id": "bag",         "icon": "🎒", "name_es": "Inventario",  "name_en": "Inventory"},
	{"id": "professions", "icon": "⚔️", "name_es": "Profesiones", "name_en": "Professions"},
	{"id": "journal",     "icon": "📜", "name_es": "Diario & Lore","name_en": "Journal & Lore"},
	{"id": "options",     "icon": "⚙️", "name_es": "Opciones",    "name_en": "Options"}
]


func _ready() -> void:
	z_index = 105
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false
	Locale.theme_changed.connect(_on_theme_changed)


## Repinta el Hub entero (scrim, cabecera, pestañas y la
## pestaña activa) cuando el jugador cambia el tema de interfaz desde
## Opciones, sin perder en qué pestaña estaba ni si el Hub estaba abierto.
func _on_theme_changed(_theme_id: String) -> void:
	var was_visible := visible
	var current_tab := _active_tab
	_build_ui()
	visible = was_visible
	if was_visible:
		switch_tab(current_tab)


func _build_ui() -> void:
	# Desenganchar (SIN liberar) la vista de pestaña que estuviera montada en
	# `_content_panel` antes de destruir el árbol de abajo: si no, el
	# queue_free() en cascada se la lleva por delante mientras `_views` sigue
	# apuntando a esa referencia ya liberada, y la próxima vez que se visite
	# esa pestaña `_load_tab_content` intenta castear un objeto libre ("Trying
	# to cast a freed object"). El resto de pestañas cacheadas ya sobreviven
	# así, como huérfanas desenganchadas por `_load_tab_content`.
	if _content_panel != null and is_instance_valid(_content_panel):
		for child in _content_panel.get_children():
			_content_panel.remove_child(child)

	for c in get_children():
		c.queue_free()

	# 1. Scrim Background (Fondo traslúcido semitransparente)
	_scrim_bg = ColorRect.new()
	_scrim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim_bg.color = Color(0.02, 0.03, 0.05, 0.6)
	_scrim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim_bg.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close()
	)
	add_child(_scrim_bg)

	# 2. Ventana modal contenida: con margen amplio a la izquierda (anchor_left 0.115)
	# para no pisar el widget/orbe del mundo y dejar ver el mapamundi de fondo.
	var window_card := PanelContainer.new()
	window_card.anchor_left = 0.115
	window_card.anchor_right = 0.975
	window_card.anchor_top = 0.025
	window_card.anchor_bottom = 0.975
	var window_style := StyleBoxFlat.new()
	window_style.bg_color = Color(0.03, 0.04, 0.07, 0.0)
	window_style.border_color = UiKit.theme_color("accent", UiKit.COLOR_GOLD_PRIMARY)
	window_style.set_border_width_all(2)
	window_style.set_corner_radius_all(18)
	window_style.shadow_color = Color(0, 0, 0, 0.55)
	window_style.shadow_size = 24
	window_card.add_theme_stylebox_override("panel", window_style)
	add_child(window_card)

	var main_margin := MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 10)
	main_margin.add_theme_constant_override("margin_right", 10)
	main_margin.add_theme_constant_override("margin_top", 10)
	main_margin.add_theme_constant_override("margin_bottom", 10)
	window_card.add_child(main_margin)

	var right_container := VBoxContainer.new()
	right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_container.add_theme_constant_override("separation", 10)
	main_margin.add_child(right_container)

	# 3. Cabecera / Barra de Pestañas Superior (limpia, sin marco adicional detrás)
	_header_panel = PanelContainer.new()
	_header_panel.custom_minimum_size.y = 66
	var header_empty := StyleBoxEmpty.new()
	_header_panel.add_theme_stylebox_override("panel", header_empty)
	right_container.add_child(_header_panel)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	_header_panel.add_child(header_hbox)

	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_hbox.add_theme_constant_override("separation", 8)
	header_hbox.add_child(tabs_hbox)

	_tab_buttons.clear()
	for t in TABS:
		var tab_id: String = t["id"]
		var btn := Button.new()
		btn.text = "%s %s" % [t["icon"], Locale.pick({"es": t["name_es"], "en": t["name_en"]})]
		btn.custom_minimum_size = Vector2(160, 56)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 20)
		
		btn.pressed.connect(func() -> void:
			AudioManager.play_ui("select")
			if tab_id == "options":
				request_standalone_options.emit()
			else:
				switch_tab(tab_id)
		)
		tabs_hbox.add_child(btn)
		_tab_buttons[tab_id] = btn

	# Botón "🚪 Cerrar" (icono + texto + estilo tonal)
	var btn_close := Button.new()
	btn_close.text = "🚪 " + Locale.pick({"es": "Cerrar", "en": "Close"})
	btn_close.custom_minimum_size = Vector2(160, 56)
	btn_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_font_size_override("font_size", 20)
	for st in ["normal", "hover", "pressed", "focus"]:
		btn_close.add_theme_stylebox_override(st, UiKit.button_tonal(UiKit.BAD))
	btn_close.pressed.connect(close)
	header_hbox.add_child(btn_close)

	# 4. Host de Contenido Central
	_content_panel = PanelContainer.new()
	_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UiKit.premium_panel(_content_panel, 12, 12)
	right_container.add_child(_content_panel)


func open_at_tab(tab_id: String, subtab: String = "") -> void:
	visible = true
	_subtab_request = subtab
	_notify_world_modal(true)
	switch_tab(tab_id)
	
	modulate.a = 0.0
	scale = Vector2(0.98, 0.98)
	pivot_offset = size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func switch_tab(tab_id: String) -> void:
	if tab_id == "options":
		# Defensa adicional: cualquier llamante que pida la pestaña "options"
		# directamente (p. ej. `open_at_tab("options")`) se redirige también
		# al menú autosuficiente en vez de embeberlo — ver `request_standalone_options`.
		request_standalone_options.emit()
		return
	_active_tab = tab_id
	
	# Resaltar la pestaña activa con UiKit.COLOR_GOLD_PRIMARY
	for tid in _tab_buttons.keys():
		var btn: Button = _tab_buttons[tid]
		var is_active: bool = (String(tid) == tab_id)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		if is_active:
			style.bg_color = Color(0.16, 0.14, 0.26, 0.95)
			style.border_color = UiKit.COLOR_GOLD_PRIMARY
			btn.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY)
		else:
			style.bg_color = Color(0.06, 0.05, 0.10, 0.7)
			style.border_color = Color(0.2, 0.18, 0.28, 0.6)
			btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

	_load_tab_content(tab_id)


func _load_tab_content(tab_id: String) -> void:
	if _content_panel == null:
		return
	for child in _content_panel.get_children():
		_content_panel.remove_child(child)

	match tab_id:
		"character":
			var char_view := _views.get("character", null) as TabCharacter
			if char_view == null:
				char_view = TabCharacter.new()
				_views["character"] = char_view
			_content_panel.add_child(char_view)
		"equip":
			var equip_view := _views.get("equip", null) as TabEquip
			if equip_view == null:
				equip_view = TabEquip.new()
				_views["equip"] = equip_view
			_content_panel.add_child(equip_view)
		"bag":
			var bag_view := _views.get("bag", null) as TabBag
			if bag_view == null:
				bag_view = TabBag.new()
				_views["bag"] = bag_view
			_content_panel.add_child(bag_view)
		"professions":
			var prof_view := _views.get("professions", null) as TabProfessions
			if prof_view == null:
				prof_view = TabProfessions.new()
				_views["professions"] = prof_view
			_content_panel.add_child(prof_view)
		"journal":
			var info_view := _views.get("info", null) as TabInfo
			if info_view == null:
				info_view = TabInfo.new()
				_views["info"] = info_view
			_content_panel.add_child(info_view)
		"options":
			# La pestaña "Opciones" ya no se carga aquí: `switch_tab()` la
			# redirige a `request_standalone_options` antes de llegar a este
			# `match` (ver comentario en `switch_tab`). Caso inalcanzable,
			# mantenido solo para que el `match` documente los 6 ids de `TABS`.
			pass


func close() -> void:
	_notify_world_modal(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.finished.connect(func():
		visible = false
		closed.emit()
	)


func _notify_world_modal(active: bool) -> void:
	GlobalState.is_movement_locked = active
	var p = get_parent()
	if p != null and p.has_method("_set_world_modal"):
		p.call("_set_world_modal", active)
		return
	var world = get_tree().get_first_node_in_group("world_3d")
	if world != null and world.has_method("set_modal_mode"):
		world.call("set_modal_mode", active)
	var dungeon = get_tree().get_first_node_in_group("view_dungeon")
	if dungeon != null:
		if active and dungeon.has_method("stop_exploration"):
			dungeon.call("stop_exploration")
		elif not active and dungeon.has_method("resume_exploration"):
			dungeon.call("resume_exploration")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			get_viewport().set_input_as_handled()
			_cycle_tab(-1)
		elif event.keycode == KEY_E:
			get_viewport().set_input_as_handled()
			_cycle_tab(1)


func _cycle_tab(dir: int) -> void:
	var curr_idx := 0
	for i in range(TABS.size()):
		if TABS[i]["id"] == _active_tab:
			curr_idx = i
			break
	var next_idx := posmod(curr_idx + dir, TABS.size())
	switch_tab(TABS[next_idx]["id"])
