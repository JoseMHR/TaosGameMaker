# ViewCity.gd
# Vista interior de una ciudad: muestra un grid de edificios clickables.
# La ciudad activa se recibe como diccionario desde el mapa.
class_name ViewCity
extends Control

# Los edificios de cada ciudad se leen de Design.ids[event_id].content (lista de
# ids de POI); cada POI define en ids.json su icono, nombre/subtítulo bilingüe,
# su "kind" (tavern/church/shop/npc) y su "npc"/"stock". Esta vista es genérica:
# para cambiar qué contiene una ciudad NO se toca este archivo, solo el CSV/JSON.

@onready var bg: ColorRect          = $BG
@onready var lbl_city_icon: Label   = $VBox/Header/MarginHeader/HBoxHeader/LblCityIcon
@onready var lbl_city_name: Label   = $VBox/Header/MarginHeader/HBoxHeader/LblCityName
@onready var grid_buildings: GridContainer = $VBox/GridMargin/GridBuildings
@onready var btn_exit: Button       = $VBox/Header/MarginHeader/HBoxHeader/BtnExit
@onready var btn_toggle_ui: Button = $VBox/BtnToggleUIMargin/BtnToggleUI
@onready var grid_margin: MarginContainer = $VBox/GridMargin
@onready var header_panel: PanelContainer = $VBox/Header

# ─── ESTADO ──────────────────────────────────────────────────────────────────
var _city_id: String = ""
var _setup_done: bool = false
var _bg_texture_rect: TextureRect = null
var _ui_visible: bool = true


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	Locale.locale_changed.connect(_refresh_chrome)
	# Los mosaicos de edificio hornean su color con `UiKit.theme_color()` al
	# construirse; sin esto, un cambio de tema en caliente desde Opciones no se
	# reflejaba hasta salir y volver a entrar en la ciudad (task_bugs_observados.md §5.1).
	Locale.theme_changed.connect(func(_id: String) -> void: _build_building_buttons())
	# Rutinas de NPC por hora del día (idea.md §2.2): si el jugador permanece
	# en la ciudad al cruzar el amanecer/anochecer, los mosaicos con
	# "open_phase" deben abrirse/cerrarse sin necesidad de salir y reentrar.
	TimeManager.phase_changed.connect(func(_phase: String) -> void: _build_building_buttons())
	_refresh_chrome()
	UiKit.apply_heading(lbl_city_name)
	var toggle_margin = get_node_or_null("VBox/BtnToggleUIMargin") as Control
	if toggle_margin != null:
		toggle_margin.visible = false

	# Envolver grid_buildings en un ScrollContainer si no está envuelto
	if grid_margin != null and grid_buildings != null and grid_buildings.get_parent() == grid_margin:
		grid_margin.remove_child(grid_buildings)
		var scroll := ScrollContainer.new()
		scroll.name = "ScrollBuildings"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.add_child(grid_buildings)
		grid_margin.add_child(scroll)

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

## Traduce los elementos de interfaz y reconstruye los edificios (por sus textos).
func _refresh_chrome() -> void:
	btn_exit.text = Locale.t("city_exit")
	if _setup_done:
		lbl_city_name.text = Locale.pick(Design.id_name(_city_id))
		_build_building_buttons()


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════

## Nombre de la ciudad actual (mismo patrón que `ViewBuilding.get_location_name`
## / `ViewPlace.get_location_name`), usado por `GameRoot.gd` para el título
## central del HUD (antes cableado a "El Puerto de Celestia" siempre — ver
## task_bugs_observados.md §5.1).
func get_location_name() -> String:
	return Locale.pick(Design.id_name(_city_id)) if _city_id != "" else ""


## Inicializa la vista con los datos de la casilla ciudad. El event_id de la celda
## es el id de la ciudad en ids.json (qué POIs contiene + fondo).
func setup(cell_data: Dictionary) -> void:
	_city_id = String(cell_data.get("event_id", ""))
	var city_data: Dictionary = Design.get_id(_city_id)
	lbl_city_name.text = Locale.pick(Design.id_name(_city_id))
	lbl_city_icon.text = Design.id_icon(_city_id) if Design.id_icon(_city_id) != "" else String(cell_data.get("icon", "🏰"))

	# Cambiar música a la banda sonora de la ciudad (bgm_city.ogg)
	if AudioManager != null:
		AudioManager.play_city_music(_city_id)

	# Resetear visibilidad de interfaz
	_ui_visible = true
	if grid_margin: grid_margin.visible = true
	if header_panel: header_panel.visible = true
	var toggle_margin = get_node_or_null("VBox/BtnToggleUIMargin") as Control
	if toggle_margin != null: toggle_margin.visible = false
	var hud = get_node_or_null("/root/GameRoot/VBoxMain/PanelHUD")
	if hud:
		hud.visible = true

	if not _bg_texture_rect:
		_bg_texture_rect = TextureRect.new()
		_bg_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_bg_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_bg_texture_rect)
		move_child(_bg_texture_rect, 0)
		bg.visible = false

	var bg_tex: Texture2D = null
	var explicit_bg: String = String(city_data.get("bg", "")) if not city_data.is_empty() else String(cell_data.get("bg", ""))
	if explicit_bg != "":
		bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/" + explicit_bg)
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/vn/bg/bg_%s.png" % _city_id)
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/common/ui/bg_default.png")

	if _bg_texture_rect and bg_tex:
		_bg_texture_rect.texture = bg_tex

	_setup_done = true
	_update_layout()
	_build_building_buttons()

	# Efecto de revelado de fondo
	$VBox.modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property($VBox, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DINÁMICA DE BOTONES
# ══════════════════════════════════════════════════════════════════════════════
func _build_building_buttons() -> void:
	for child in grid_buildings.get_children():
		child.queue_free()
	if not _setup_done:
		return
	var city: Dictionary = Design.get_id(_city_id)
	var is_first := true
	for poi_id in city.get("content", []):
		var tile := _make_building_tile(String(poi_id))
		grid_buildings.add_child(tile)
		if is_first:
			tile.grab_focus()
			is_first = false


## Crea el mosaico de un POI resolviendo icono/nombre/subtítulo y su acción según
## el "kind": tavern/church/npc (abren un NPC en ViewBuilding) o shop (ViewShop).
func _make_building_tile(poi_id: String) -> Control:
	var spec: Dictionary = Design.get_id(poi_id)
	var kind: String = String(spec.get("kind", "npc"))
	var icon: String = String(spec.get("icon", "🏠"))
	var bname: String = Locale.pick(spec.get("name", {"es": "", "en": ""}))
	var bdesc: String = Locale.pick(spec.get("desc", {})) if spec.has("desc") else ""

	# Rutinas de NPC por hora del día (idea.md §2.2): un NPC/edificio puede
	# declarar "open_phase": "day"|"night" en su ids.json para estar cerrado
	# fuera de esa franja — MISMO campo/convención ya usada para los portales
	# del mapamundi (`TabWorld3D._poi_open_phase`), aplicada aquí a los
	# edificios internos de una ciudad. "any" (por defecto) = siempre abierto.
	var open_phase := String(spec.get("open_phase", "any")).to_lower()
	var is_time_locked := (open_phase == TimeManager.PHASE_DAY or open_phase == TimeManager.PHASE_NIGHT) \
		and open_phase != TimeManager.phase()

	# Colores tomados del tema ACTIVO (`UiKit.theme_color`), no de las constantes
	# fijas del kit: antes los mosaicos de edificio no cambiaban de paleta al
	# cambiar de tema desde Opciones (ver task_bugs_observados.md §5.1).
	var theme_panel := UiKit.theme_color("panel_bg", UiKit.SURFACE)
	var theme_border := UiKit.theme_color("border", UiKit.BORDER)
	var theme_accent := UiKit.theme_color("accent", UiKit.ACCENT)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(theme_panel.r, theme_panel.g, theme_panel.b, 0.88)
	normal_style.set_border_width_all(1)
	normal_style.border_color = theme_border
	normal_style.set_corner_radius_all(16)
	normal_style.shadow_color = Color(0, 0, 0, 0.35)
	normal_style.shadow_size = 6

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = theme_panel.lightened(0.12)
	focus_style.bg_color.a = 0.96
	focus_style.set_border_width_all(3)
	focus_style.border_color = theme_accent
	focus_style.set_corner_radius_all(16)
	focus_style.shadow_color = Color(theme_accent.r, theme_accent.g, theme_accent.b, 0.22)
	focus_style.shadow_size = 12

	var btn := PanelContainer.new()
	btn.custom_minimum_size = Vector2(0, 96)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("panel", normal_style)

	btn.focus_entered.connect(func() -> void:
		btn.add_theme_stylebox_override("panel", focus_style)
		UiKit.pop(btn, 1.03, 0.16)
	)
	btn.focus_exited.connect(func() -> void:
		btn.add_theme_stylebox_override("panel", normal_style)
	)
	btn.mouse_entered.connect(func() -> void:
		btn.add_theme_stylebox_override("panel", focus_style)
		UiKit.pop(btn, 1.03, 0.16)
	)
	btn.mouse_exited.connect(func() -> void:
		btn.add_theme_stylebox_override("panel", normal_style)
	)

	var margin := UiKit.margins(18, 18, 12, 12)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(hbox)

	var lbl_icon := Label.new()
	lbl_icon.text = icon
	lbl_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_icon.add_theme_font_size_override("font_size", 42)
	hbox.add_child(lbl_icon)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 4)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Autowrap en vez de `clip_text` (antes el texto desaparecía comprimido en
	# vertical/landscape estrecho, ver task_bugs_observados.md §5.1).
	var lbl_name := Label.new()
	lbl_name.text = bname
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_name.add_theme_font_size_override("font_size", 26)
	lbl_name.add_theme_color_override("font_color", UiKit.TEXT)
	inner.add_child(lbl_name)

	if bdesc != "":
		var lbl_desc := Label.new()
		lbl_desc.text = bdesc
		lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_desc.add_theme_font_size_override("font_size", 20)
		lbl_desc.add_theme_color_override("font_color", UiKit.TEXT_MUTED)
		inner.add_child(lbl_desc)

	if is_time_locked:
		# Cerrado por franja horaria: atenuado, pero SIGUE visible en la lista
		# (transmite "vuelve más tarde" mejor que hacerlo desaparecer del todo).
		var lbl_closed := Label.new()
		lbl_closed.text = Locale.pick({"es": "🌙 Cerrado de noche · vuelve de día", "en": "🌙 Closed at night · come back by day"}) \
			if open_phase == TimeManager.PHASE_DAY \
			else Locale.pick({"es": "☀️ Cerrado de día · vuelve de noche", "en": "☀️ Closed by day · come back at night"})
		lbl_closed.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_closed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_closed.add_theme_font_size_override("font_size", 18)
		lbl_closed.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
		inner.add_child(lbl_closed)
		btn.modulate = Color(1.0, 1.0, 1.0, 0.55)

	hbox.add_child(inner)
	btn.add_child(margin)

	# Acción al tocar el mosaico (tienda → ViewShop con su stock; resto → NPC).
	var target_npc: String = String(spec.get("npc", ""))
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		var pressed := false
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
				pressed = true
		elif ev is InputEventScreenTouch:
			if ev.pressed:
				pressed = true
		elif ev is InputEventKey:
			if ev.keycode == KEY_SPACE and ev.pressed and not ev.echo:
				pressed = true

		if not pressed:
			return
		if is_time_locked:
			AudioManager.play_sfx("click")
			UiKit.toast(self, Locale.pick({"es": "Cerrado a esta hora.", "en": "Closed at this hour."}), UiKit.TEXT_DIM)
			return
		if kind == "shop":
			SceneManager.go_to_shop({"city": _city_id, "poi_id": poi_id, "npc": target_npc if target_npc != "" else poi_id})
		elif kind == "board":
			SceneManager.go_to_encargos({"city": _city_id, "poi_id": poi_id, "npc": target_npc if target_npc != "" else poi_id})
		elif kind == "forge":
			SceneManager.go_to_forge({"city": _city_id, "poi_id": poi_id, "npc": target_npc if target_npc != "" else poi_id})
		elif kind == "transport":
			SceneManager.go_to_transport({"city": _city_id, "poi_id": poi_id, "npc": target_npc if target_npc != "" else poi_id})
		else:
			SceneManager.go_to_building({"city": _city_id, "poi_id": poi_id, "npc": target_npc if target_npc != "" else poi_id})
	)

	return btn


# ══════════════════════════════════════════════════════════════════════════════
# AJUSTE DE CONTENEDORES
# ══════════════════════════════════════════════════════════════════════════════
func _update_layout() -> void:
	var sz := get_viewport_rect().size
	if sz.x <= 0 or sz.y <= 0:
		return
	var vbox := get_node_or_null("VBox") as VBoxContainer
	var spacer := get_node_or_null("VBox/Spacer") as Control
	if vbox == null or grid_margin == null or grid_buildings == null:
		return
	var is_landscape := sz.x > sz.y
	# Lista de edificios: 1 columna (apilados verticalmente) por defecto; si
	# la ciudad tiene muchos POIs se reparten en 2 columnas para no generar
	# una lista interminable que obligue a scrollear en exceso.
	var poi_count := int(Design.get_id(_city_id).get("content", []).size()) if _setup_done else 0
	grid_buildings.columns = 2 if poi_count > 6 else 1
	grid_buildings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_buildings.add_theme_constant_override("h_separation", 16)
	grid_buildings.add_theme_constant_override("v_separation", 14)
	if is_landscape:
		vbox.anchor_left = 0.44
		vbox.anchor_right = 1.0
		vbox.anchor_top = 0.0
		vbox.anchor_bottom = 1.0
		vbox.offset_left = 12
		vbox.offset_right = -16
		vbox.offset_top = 10
		vbox.offset_bottom = -16
		vbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
		grid_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid_buildings.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if spacer:
			spacer.visible = false
	else:
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		grid_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid_buildings.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if spacer:
			spacer.visible = true


func _on_btn_exit_pressed() -> void:
	SceneManager.go_to_world()


func _on_btn_toggle_ui_pressed() -> void:
	_ui_visible = !_ui_visible
	if grid_margin: grid_margin.visible = _ui_visible
	if header_panel: header_panel.visible = _ui_visible

	if _ui_visible:
		btn_toggle_ui.text = "Ocultar Interfaz"
	else:
		btn_toggle_ui.text = "Mostrar Interfaz"

	var hud = get_node_or_null("/root/GameRoot/VBoxMain/PanelHUD")
	if hud:
		hud.visible = _ui_visible
