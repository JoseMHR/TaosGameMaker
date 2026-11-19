class_name WorldHudBuilder
extends RefCounted
## JOYSTICK VIRTUAL Y PANEL INFERIOR DE UBICACIÓN — Componente especialista
## extraído de TabWorld3D.
##
## NOTA de implementación: se modela como `RefCounted` (no `Node`), igual que
## `OverworldPhysicsController`/`WorldEnvironmentController`,
## porque no se añade al árbol de escena.
##
## Encapsula: el joystick virtual táctil (aparece donde tocas, gestos de tap
## vs. arrastre) y el panel inferior de ubicación/acción (widget compacto con
## icono/nombre/subtítulo de la casilla, botones ENTRAR/RECOLECTAR/TIENDA DE
## CAMPAÑA/HERRAMIENTA/BOMBA, y el botón de acción flotante sobre el personaje
## en horizontal).
##
## Mantiene una referencia a la `TabWorld3D` propietaria (`_view`), sobre cuyos
## nodos y estado opera. `TabWorld3D` mantiene fachadas con las mismas firmas
## públicas (`_build_joystick`, `_is_pos_over_ui`, `_input`, `_start_touch_gesture`,
## `_drag_touch_gesture`, `_end_touch_gesture`, `_start_joystick`,
## `_update_joystick`, `_reset_joystick`, `_position_joystick`,
## `_build_bottom_panel`, `_gather_action_label`,
## `get_active_location_title`, `_update_location_panel`, `_location_subtitle`)
## que redirigen a este componente, de modo que ningún llamante externo
## (incluidos `CampTentSystem`/`TerrainToolsSystem`, que ya invocan
## `world._update_location_panel(...)`, y `GameRoot`, que llama
## `get_active_location_title` por reflexión) cambia. El comportamiento es
## IDÉNTICO al monolito original.

## Vista del mapamundi propietaria del estado y de los nodos UI.
var _view: Node = null

## Enlaza este componente con la TabWorld3D propietaria. Debe llamarse una vez
## tras instanciarlo (en `TabWorld3D._ready`).
func setup(view: Node) -> void:
	_view = view


#region JOYSTICK VIRTUAL

func _build_joystick() -> void:
	_view._joy_area = Control.new()
	_view._joy_area.anchor_left = 0.0
	_view._joy_area.anchor_right = 1.0
	_view._joy_area.anchor_top = 1.0
	_view._joy_area.anchor_bottom = 1.0
	_view._joy_area.offset_left = 0.0
	_view._joy_area.offset_right = 0.0
	_view._joy_area.offset_top = -660.0
	_view._joy_area.offset_bottom = -250.0
	# Solo visual: el input del joystick se gestiona en _input (captura siempre el release).
	_view._joy_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_view._joy_area)

	_view._joy_base = Panel.new()
	_view._joy_base.size = Vector2(_view.JOY_RADIUS * 2.0, _view.JOY_RADIUS * 2.0)
	_view._joy_base.visible = false
	_view._joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_sb := StyleBoxFlat.new()
	base_sb.bg_color = Color(UiKit.BG_DEEP.r, UiKit.BG_DEEP.g, UiKit.BG_DEEP.b, 0.32)
	base_sb.set_corner_radius_all(int(_view.JOY_RADIUS))
	base_sb.set_border_width_all(2)
	base_sb.border_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.4)
	_view._joy_base.add_theme_stylebox_override("panel", base_sb)
	_view._joy_area.add_child(_view._joy_base)

	var kr: float = _view.JOY_RADIUS * 0.5
	_view._joy_knob = Panel.new()
	_view._joy_knob.size = Vector2(kr * 2.0, kr * 2.0)
	_view._joy_knob.visible = false
	_view._joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_sb := StyleBoxFlat.new()
	knob_sb.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.85)
	knob_sb.set_corner_radius_all(int(kr))
	_view._joy_knob.add_theme_stylebox_override("panel", knob_sb)
	_view._joy_area.add_child(_view._joy_knob)


## Comprueba si la posición global cae sobre elementos de la interfaz.
func _is_pos_over_ui(pos: Vector2) -> bool:
	var root_scene: Node = _view.get_tree().current_scene if _view.get_tree() != null else null
	if root_scene != null and root_scene.has_method("is_radial_menu_open") and root_scene.call("is_radial_menu_open"):
		return true

	var vp_size: Vector2 = (_view as Control).get_viewport_rect().size
	var is_landscape: bool = vp_size.x > vp_size.y

	if is_landscape:
		# En horizontal: franja superior solo sobre tarjetas de esquinas (izq/der)
		if pos.y <= 90.0 and (pos.x <= 380.0 or pos.x >= vp_size.x - 380.0):
			return true
		# Franja inferior solo sobre la tarjeta de pestañas (esquina inferior izquierda)
		if pos.y >= vp_size.y - 70.0 and pos.x <= 480.0:
			return true
	else:
		if pos.y <= 140.0:
			return true
		if pos.y >= vp_size.y - 140.0:
			return true

	# Overlay del minimapa si está abierto
	if _view._minimap_overlay != null and is_instance_valid(_view._minimap_overlay) and _view._minimap_overlay.is_visible_in_tree():
		return true

	if _view._btn_map != null and is_instance_valid(_view._btn_map) and _view._btn_map.is_visible_in_tree() and _view._btn_map.get_global_rect().has_point(pos):
		return true
	var debug_tb: Node = _view.get_node_or_null("DebugToolbar")
	if debug_tb != null and is_instance_valid(debug_tb) and (debug_tb as Control).is_visible_in_tree() and (debug_tb as Control).get_global_rect().has_point(pos):
		return true
	if _view._bottom != null and is_instance_valid(_view._bottom) and _view._bottom.is_visible_in_tree() and _view._bottom.get_global_rect().has_point(pos):
		return true
	if _view._btn_enter != null and is_instance_valid(_view._btn_enter) and _view._btn_enter.is_visible_in_tree() and _view._btn_enter.get_global_rect().has_point(pos):
		return true
	if _view._btn_gather != null and is_instance_valid(_view._btn_gather) and _view._btn_gather.is_visible_in_tree() and _view._btn_gather.get_global_rect().has_point(pos):
		return true

	var hovered: Control = _view.get_viewport().gui_get_hovered_control()
	if hovered != null:
		if hovered == _view or hovered == _view._vp_container or hovered == _view._joy_area or _view._joy_area.is_ancestor_of(hovered):
			return false
		if hovered.is_ancestor_of(_view) or hovered.name in ["GameRoot", "VBoxMain", "ViewStack", "BG"]:
			return false
		if hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true

	return false


## Gestiona el input táctil / ratón: si es un clic breve (tap) mueve al héroe a la casilla tocada.
## Si se mantiene pulsado y se arrastra, activa el joystick virtual de movimiento libre.
func _input(event: InputEvent) -> void:
	if not _view.is_visible_in_tree():
		# El mundo puede ocultarse a media pulsación (p. ej. al entrar en una
		# mazmorra mientras se arrastra el joystick): si no reseteamos aquí, el
		# evento de "soltar" nunca llega a procesarse (este método corta antes),
		# el joystick se queda "activo" con el último vector, y al volver a ver
		# el mapamundi _process() retoma el movimiento en esa dirección sin que
		# el jugador esté tocando nada.
		if _view._joy_active or _view._is_dragging_joystick:
			_reset_joystick()
		return
	if GlobalState.is_movement_locked:
		if _view._joy_active or _view._is_dragging_joystick:
			_reset_joystick()
		return
	if _view._is_cinematic_active or SceneRunner.is_active():
		if _view._joy_active or _view._is_dragging_joystick:
			_reset_joystick()
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_start_touch_gesture(event.index, event.position)
		elif event.index == _view._touch_index or event.index == _view._joy_index:
			_end_touch_gesture(event.position)
	elif event is InputEventScreenDrag:
		if event.index == _view._touch_index or event.index == _view._joy_index:
			_drag_touch_gesture(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _view._touch_index == -1:
				_start_touch_gesture(-2, event.position)
		elif _view._touch_index == -2 or _view._joy_index == -2:
			_end_touch_gesture(event.position)
	elif event is InputEventMouseMotion:
		if _view._touch_index == -2 or _view._joy_index == -2:
			_drag_touch_gesture(event.position)


func _start_touch_gesture(index: int, global_pos: Vector2) -> void:
	if _is_pos_over_ui(global_pos):
		return
	if _view._touch_index != -1 and index == -2:
		# Ignorar clic emulado de ratón si ya hay un toque activo en pantalla táctil
		return
	_view._touch_index = index
	_view._touch_start_pos = global_pos
	_view._touch_start_ms = Time.get_ticks_msec()
	_view._is_dragging_joystick = false


func _drag_touch_gesture(global_pos: Vector2) -> void:
	if _view._touch_index == -1 and _view._joy_index == -1:
		return
	var dist: float = global_pos.distance_to(_view._touch_start_pos)
	if not _view._is_dragging_joystick and dist > _view.JOY_DRAG_THRESHOLD:
		_view._is_dragging_joystick = true
		var idx: int = _view._touch_index if _view._touch_index != -1 else _view._joy_index
		_start_joystick(idx, _view._touch_start_pos)

	if _view._is_dragging_joystick:
		_update_joystick(global_pos)


func _end_touch_gesture(global_pos: Vector2) -> void:
	if _view._is_dragging_joystick:
		_reset_joystick()
	else:
		if _view._touch_index != -1 or _view._joy_index != -1:
			var dur: int = Time.get_ticks_msec() - _view._touch_start_ms
			if dur < 500 and global_pos.distance_to(_view._touch_start_pos) <= _view.JOY_DRAG_THRESHOLD:
				_view._try_tap_move(global_pos)
		_reset_joystick()
	_view._touch_index = -1
	_view._is_dragging_joystick = false


func _start_joystick(index: int, global_pos: Vector2) -> void:
	_view._joy_index = index
	_view._joy_active = true
	_view._joy_center = global_pos - _view._joy_area.global_position
	_view._joy_vec = Vector2.ZERO
	_view._joy_base.visible = true
	_view._joy_knob.visible = true
	_position_joystick(Vector2.ZERO)


func _update_joystick(global_pos: Vector2) -> void:
	var off: Vector2 = (global_pos - _view._joy_area.global_position) - _view._joy_center
	if off.length() > _view.JOY_RADIUS:
		off = off.normalized() * _view.JOY_RADIUS
	_view._joy_vec = off / _view.JOY_RADIUS
	_position_joystick(off)


func _reset_joystick() -> void:
	_view._joy_index = -1
	_view._joy_active = false
	_view._joy_vec = Vector2.ZERO
	_view._joy_base.visible = false
	_view._joy_knob.visible = false


func _position_joystick(off: Vector2) -> void:
	_view._joy_base.position = _view._joy_center - _view._joy_base.size * 0.5
	_view._joy_knob.position = _view._joy_center + off - _view._joy_knob.size * 0.5

#endregion


#region PANEL INFERIOR (ubicación / viaje) — construido por código

func _build_bottom_panel() -> void:
	# ELIMINADO: el botón de acción contextual flotante que se proyectaba en 2D
	# bajo el personaje (incómodo para el pulgar y solo permitía UNA acción a
	# la vez, descartando el resto — ver task_bugs_observados.md §1.2). Las
	# acciones disponibles viven ahora SOLO en la fila `hb_actions` de abajo,
	# anclada en la esquina inferior derecha, mostrando TODAS las acciones
	# disponibles simultáneamente en botones grandes y cuadrados.
	_view._bottom = PanelContainer.new()
	_view._bottom.anchor_left = 1.0
	_view._bottom.anchor_right = 1.0
	_view._bottom.anchor_top = 1.0
	_view._bottom.anchor_bottom = 1.0
	_view._bottom.offset_left = 0.0
	_view._bottom.offset_right = -16.0
	_view._bottom.offset_top = 0.0
	_view._bottom.offset_bottom = -16.0
	_view._bottom.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_view._bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_view._bottom.custom_minimum_size = Vector2(280, 0)

	var bp := UiKit.panel(Color(UiKit.BG_BASE.r, UiKit.BG_BASE.g, UiKit.BG_BASE.b, 0.70), UiKit.BORDER, 16, 2)
	bp.shadow_color = Color(0, 0, 0, 0.55)
	bp.shadow_size = 12
	_view._bottom.add_theme_stylebox_override("panel", bp)
	_view.add_child(_view._bottom)

	var margin := UiKit.margins(16, 16, 12, 12)
	_view._bottom.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# ── Fila superior: Icono de casilla + Título + Subtítulo ──
	var hb_header := HBoxContainer.new()
	hb_header.add_theme_constant_override("separation", 12)
	hb_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hb_header)

	_view._icon_circle = PanelContainer.new()
	_view._icon_circle.name = "IconCircle"
	_view._icon_circle.custom_minimum_size = Vector2(46, 46)
	_view._icon_circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ics := StyleBoxFlat.new()
	ics.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.20)
	ics.border_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.8)
	ics.set_border_width_all(1)
	ics.set_corner_radius_all(23)
	_view._icon_circle.add_theme_stylebox_override("panel", ics)
	hb_header.add_child(_view._icon_circle)

	_view._lbl_loc_icon = Label.new()
	_view._lbl_loc_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view._lbl_loc_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_view._lbl_loc_icon.add_theme_font_size_override("font_size", 34)
	_view._icon_circle.add_child(_view._lbl_loc_icon)

	var txt := VBoxContainer.new()
	txt.add_theme_constant_override("separation", 2)
	txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_header.add_child(txt)

	_view._lbl_loc_name = Label.new()
	_view._lbl_loc_name.add_theme_font_size_override("font_size", 28)
	_view._lbl_loc_name.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	_view._lbl_loc_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_view._lbl_loc_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.apply_heading(_view._lbl_loc_name)
	txt.add_child(_view._lbl_loc_name)

	_view._lbl_loc_sub = Label.new()
	_view._lbl_loc_sub.add_theme_font_size_override("font_size", 22)
	_view._lbl_loc_sub.add_theme_color_override("font_color", UiKit.TEXT)
	_view._lbl_loc_sub.visible = true
	txt.add_child(_view._lbl_loc_sub)

	# ── Fila inferior: Botones de Acción ──
	var hb_actions := HBoxContainer.new()
	hb_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	hb_actions.add_theme_constant_override("separation", 8)
	hb_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hb_actions)
	_view._hb_actions = hb_actions

	_view._btn_tent = Button.new()
	_view._btn_tent.text = Locale.pick({"es": "⛺ ¡Montar\nTienda!", "en": "⛺ Pitch\nTent!"})
	_view._btn_tent.add_theme_font_size_override("font_size", 22)
	_view._btn_tent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_view._btn_tent.custom_minimum_size = Vector2(110, 68)
	
	var tent_norm := StyleBoxFlat.new()
	tent_norm.bg_color = Color(0.12, 0.65, 0.32, 0.95)
	tent_norm.border_color = Color(1.0, 0.88, 0.30, 1.0)
	tent_norm.set_corner_radius_all(12)
	var tent_hov := StyleBoxFlat.new()
	tent_hov.bg_color = Color(0.18, 0.78, 0.40, 1.0)
	tent_hov.border_color = Color(1.0, 0.95, 0.50, 1.0)
	tent_hov.set_border_width_all(3)
	tent_hov.set_corner_radius_all(12)
	tent_hov.shadow_color = Color(0.18, 0.78, 0.40, 0.80)
	tent_hov.shadow_size = 12

	_view._btn_tent.add_theme_stylebox_override("normal", tent_norm)
	_view._btn_tent.add_theme_stylebox_override("focus", tent_norm)
	_view._btn_tent.add_theme_stylebox_override("hover", tent_hov)
	_view._btn_tent.add_theme_stylebox_override("pressed", tent_hov)
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_view._btn_tent.add_theme_color_override(col, Color.WHITE)
	_view._btn_tent.visible = false
	_view._btn_tent.pressed.connect(func() -> void: CampTentSystem.on_use_tent_pressed(_view))
	UiKit.bind_press_feedback(_view._btn_tent)
	hb_actions.add_child(_view._btn_tent)

	_view._btn_tool = Button.new()
	_view._btn_tool.add_theme_font_size_override("font_size", 23)
	_view._btn_tool.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_view._btn_tool.custom_minimum_size = Vector2(104, 68)
	for st in ["normal", "hover", "pressed", "focus"]:
		_view._btn_tool.add_theme_stylebox_override(st, UiKit.button_primary(12))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_view._btn_tool.add_theme_color_override(col, UiKit.BG_DEEP)
	_view._btn_tool.visible = false
	_view._btn_tool.pressed.connect(func() -> void: TerrainToolsSystem.on_tool_pressed(_view))
	UiKit.bind_press_feedback(_view._btn_tool)
	hb_actions.add_child(_view._btn_tool)

	_view._btn_bomb = Button.new()
	_view._btn_bomb.add_theme_font_size_override("font_size", 23)
	_view._btn_bomb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_view._btn_bomb.custom_minimum_size = Vector2(104, 68)
	for st in ["normal", "hover", "pressed", "focus"]:
		_view._btn_bomb.add_theme_stylebox_override(st, UiKit.button_primary(12))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_view._btn_bomb.add_theme_color_override(col, UiKit.BG_DEEP)
	_view._btn_bomb.visible = false
	_view._btn_bomb.pressed.connect(func() -> void: TerrainToolsSystem.on_place_bomb_pressed(_view))
	UiKit.bind_press_feedback(_view._btn_bomb)
	hb_actions.add_child(_view._btn_bomb)

	_view._btn_gather = Button.new()
	_view._btn_gather.custom_minimum_size = Vector2(104, 68)
	_view._btn_gather.add_theme_font_size_override("font_size", 23)
	_view._btn_gather.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for st in ["normal", "hover", "pressed", "focus"]:
		_view._btn_gather.add_theme_stylebox_override(st, UiKit.button_primary(12))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_view._btn_gather.add_theme_color_override(col, UiKit.BG_DEEP)
	_view._btn_gather.visible = false
	_view._btn_gather.pressed.connect(_view._on_gather_pressed)
	UiKit.bind_press_feedback(_view._btn_gather)
	hb_actions.add_child(_view._btn_gather)

	_view._btn_enter = Button.new()
	_view._btn_enter.custom_minimum_size = Vector2(104, 68)
	_view._btn_enter.add_theme_font_size_override("font_size", 23)
	_view._btn_enter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for st in ["normal", "hover", "pressed", "focus"]:
		_view._btn_enter.add_theme_stylebox_override(st, UiKit.button_primary(12))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_view._btn_enter.add_theme_color_override(col, UiKit.BG_DEEP)
	_view._btn_enter.visible = false
	_view._btn_enter.pressed.connect(_view._on_enter_pressed)
	UiKit.bind_press_feedback(_view._btn_enter)
	hb_actions.add_child(_view._btn_enter)


func _gather_action_label(r: Dictionary) -> String:
	var icon_str := String(r.get("icon", "🪓"))
	var skill := String(r.get("skill", ""))
	var verb := Locale.pick({"es": "Recolectar", "en": "Gather"})
	match skill:
		"woodcutting": verb = Locale.pick({"es": "Talar", "en": "Chop"})
		"mining":      verb = Locale.pick({"es": "Minar", "en": "Mine"})
		"fishing":     verb = Locale.pick({"es": "Pescar", "en": "Fish"})
		"farming":     verb = Locale.pick({"es": "Cosechar", "en": "Harvest"})
	return "%s %s" % [icon_str, verb]


## Devuelve el título de la casilla si contiene un elemento visitable/interactivo (ciudad, POI, tienda, recurso, etc.).
func get_active_location_title() -> String:
	var cell: CellResource = GlobalState.hexagons_db.get(_view.player_pos, null) as CellResource
	if cell == null:
		return ""
	var opens := cell.opens_view()
	var is_visitable: bool = (
		opens in ["city", "dungeon", "gather", "place", "base", "campfire", "interactive", "event"]
		or cell.is_gather_node()
		or cell.resource != ""
		or cell.event_id != ""
		or (cell.interactive is Dictionary and not cell.interactive.is_empty())
		or (cell.portal is Dictionary and not cell.portal.is_empty())
	)
	if not is_visitable:
		return ""
	return cell.get_display_name()


func _update_location_panel(cell: CellResource) -> void:
	# Navegando en el BARCO: ningún botón contextual normal aplica (ni
	# recolectar, ni herramienta/bomba/tienda); solo "Desembarcar" en costa.
	if GlobalState.is_sailing:
		_view._lbl_loc_icon.text = "⛵"
		_view._lbl_loc_name.text = Locale.t("boat_sailing")
		_view._lbl_loc_sub.text  = Locale.t("boat_sailing_hint")
		_view._btn_gather.visible = false
		_view._btn_tool.visible = false
		_view._btn_bomb.visible = false
		_view._btn_tent.visible = false
		_view._btn_enter.visible = cell.terrain == "cst"
		_view._btn_enter.disabled = false
		_view._btn_enter.text = Locale.t("boat_disembark")
		if _view._btn_enter.visible:
			_view._btn_enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_view._btn_enter.custom_minimum_size = Vector2(140, 68)
		else:
			_view._btn_enter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_view._btn_enter.custom_minimum_size = Vector2.ZERO
		if _view._icon_circle != null:
			_view._icon_circle.visible = false
		if _view._hb_actions != null:
			_view._hb_actions.visible = _view._btn_enter.visible
		return

	_view._lbl_loc_icon.text = cell.icon
	_view._lbl_loc_name.text = cell.get_display_name()
	_view._lbl_loc_sub.text  = _location_subtitle(cell)

	var root_scene: Node = _view.get_tree().current_scene if _view.get_tree() != null else null
	if root_scene != null and root_scene.has_method("refresh_hud_location_title"):
		root_scene.call("refresh_hud_location_title")

	_view._btn_gather.visible = false

	if cell.event_id == "poi_monkey_001":
		_view._btn_enter.visible = true
		# Las 3 traducciones ya incluyen su propio icono
		# ("🌉  Cruzar Puente", "🍌  Usar Plátano...", "🐒  Puente Bloqueado...");
		# anteponer aquí otro icono duplicaba el emoji en el botón.
		if QuestManager.is_quest_at_least(QuestManager.QS_MONKEY_CLEARED):
			_view._btn_enter.text = Locale.t("world_cross_bridge")
		elif GlobalState.has_item("banana"):
			_view._btn_enter.text = Locale.t("world_use_banana")
		else:
			_view._btn_enter.text = Locale.t("world_bridge_locked")
	else:
		match cell.opens_view():
			"city":
				_view._btn_enter.visible = true
				_view._btn_enter.text = Locale.t("world_enter_city")
				GlobalState.discover_travel_point(_view.player_pos, String(cell.name), String(cell.icon))
			"dungeon":
				_view._btn_enter.visible = true
				_view._btn_enter.text = Locale.t("world_enter_dungeon")
			"gather":
				_view._btn_enter.visible = false
				_view._btn_gather.visible = true
				var res_data: Dictionary = _view._resolve_gather_res(cell)
				_view._btn_gather.text = _gather_action_label(res_data)
				_view._refresh_gather_button()
			"place":
				_view._btn_enter.visible = true
				_view._btn_enter.text = Locale.t("world_enter_place")
			"base":
				_view._btn_enter.visible = true
				_view._btn_enter.text = Locale.pick({"es": "🏕️ Campamento", "en": "🏕️ Camp"})
			"campfire":
				_view._btn_enter.visible = true
				_view._btn_enter.text = Locale.pick({"es": "🔥 Hoguera", "en": "🔥 Campfire"})
			"camp_struct":
				_view._btn_enter.visible = true
				var skey := cell.event_id.trim_prefix("camp_")
				var sdef := GlobalState.get_camp_structure_def(skey)
				var sicon := String(sdef.get("icon", "🏗️"))
				var sname := Locale.pick(sdef.get("name", {"es": "Estructura", "en": "Structure"}))
				if skey == "dummy":
					_view._btn_enter.text = "🎯 " + Locale.pick({"es": "Entrenar (Combate)", "en": "Train (Battle)"})
				else:
					_view._btn_enter.text = "%s %s" % [sicon, sname]
			"interactive":
				_view._btn_enter.visible = true
				var ia_icon := String(cell.interactive.get("icon", "🪧"))
				_view._btn_enter.text = "%s %s" % [ia_icon, Locale.pick({"es": "Leer", "en": "Read"})]
			"chest":
				var is_opened := GlobalState.is_chest_opened("world:%d:%d" % [cell.coord.x, cell.coord.y])
				_view._btn_enter.visible = not is_opened
				_view._btn_enter.text = "🧰 " + Locale.pick({"es": "Abrir cofre", "en": "Open chest"})
			"event":
				_view._btn_enter.visible = true
				_view._btn_enter.text = String(cell.portal.get("label", "▶  " + Locale.pick({"es": "Activar", "en": "Activate"})))
			"cinematic":
				_view._btn_enter.visible = true
				var cine_lbl: String = ""
				if cell.portal is Dictionary:
					cine_lbl = String(cell.portal.get("label", ""))
				if cine_lbl == "":
					cine_lbl = "🎬  " + Locale.pick({"es": "Ver Cinemática", "en": "Watch Cinematic"})
				_view._btn_enter.text = cine_lbl
			_:
				_view._btn_enter.visible = false

	# Evita duplicar iconos: para mazmorras y POIs el botón de acción ya lleva el icono.
	var opens: String = cell.opens_view()
	if _view._icon_circle != null:
		_view._icon_circle.visible = not (opens == "dungeon" or opens == "place")

	# Gating por FASE del ciclo día/noche (data-driven): si el POI declara
	# `portal.open_phase` = "day"|"night" y NO coincide con la fase actual, el botón
	# ENTRAR se muestra pero DESHABILITADO, con una pista de cuándo volver.
	_view._apply_phase_gate_to_enter(cell)

	# HOGUERA CONSTRUIBLE: si esta casilla es el sitio de construcción de la hoguera
	# (a la derecha de la tienda, aún sin hoguera), ofrecemos construirla aquí mismo.
	if GlobalState.get_campfire_build_spot() == cell.coord:
		_view._btn_enter.visible = true
		_view._btn_enter.disabled = false
		_view._btn_enter.text = Locale.pick({"es": "🔥 Construir Hoguera", "en": "🔥 Build Campfire"})
	else:
		var buildable_key := GlobalState.get_buildable_structure_at(cell.coord)
		if buildable_key != "":
			var s_def := GlobalState.get_camp_structure_def(buildable_key)
			var s_icon := String(s_def.get("icon", "🏗️"))
			var s_name := Locale.pick(s_def.get("name", {}))
			_view._btn_enter.visible = true
			_view._btn_enter.disabled = false
			_view._btn_enter.text = "%s %s" % [s_icon, Locale.pick({"es": "Construir " + s_name, "en": "Build " + s_name})]

	# Botón contextual de HERRAMIENTA: obstáculo rompible en la casilla actual o
	# adyacente para el que el jugador tenga la herramienta requerida.
	TerrainToolsSystem.update_tool_button(_view)

	# Mostrar el botón de la tienda de campaña si se cumplen los requisitos
	# (NUNCA en un POI, ciudad, mazmorra o lugar de interés).
	_view._btn_tent.visible = false
	if not cell.is_poi() and cell.opens_view() == "" and GlobalState.has_item("tent") and GlobalState.can_establish_base_at(cell.coord):
		_view._btn_tent.visible = true

	if _view._hb_actions != null:
		var visible_buttons: Array[Button] = []
		for btn in [_view._btn_tent, _view._btn_tool, _view._btn_bomb, _view._btn_gather, _view._btn_enter]:
			if btn != null and btn.visible:
				visible_buttons.append(btn)

		_view._hb_actions.visible = visible_buttons.size() > 0

		var btn_count := visible_buttons.size()
		for btn in [_view._btn_tent, _view._btn_tool, _view._btn_bomb, _view._btn_gather, _view._btn_enter]:
			if btn != null:
				if btn.visible:
					btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					btn.custom_minimum_size = Vector2(0, 68)
					if btn == _view._btn_tent:
						if btn_count == 1:
							btn.text = Locale.pick({"es": "⛺ ¡Montar Tienda!", "en": "⛺ Pitch Tent!"})
						else:
							btn.text = Locale.pick({"es": "⛺ ¡Montar\nTienda!", "en": "⛺ Pitch\nTent!"})
				else:
					btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
					btn.custom_minimum_size = Vector2.ZERO


func _location_subtitle(cell: CellResource) -> String:
	if cell.event_id == "poi_monkey_001":
		return Locale.pick({
			"es": "Paso bloqueado hacia el norte", "en": "Path north is blocked", "fr": "Passage bloqué vers le nord",
			"it": "Passaggio bloccato a nord", "de": "Weg nach Norden blockiert", "zh": "向北的通道被阻挡", "ja": "北への道が塞がれている"
		})
	match cell.opens_view():
		"city":    return Locale.pick({
			"es": "Comercio, gremios y misiones", "en": "Trade, guilds and quests", "fr": "Commerce, guildes et quêtes",
			"it": "Commercio, gilde e missioni", "de": "Handel, Gilden und Quests", "zh": "贸易、公会与任务", "ja": "商業、ギルド、クエスト"
		})
		"dungeon": return Locale.pick({
			"es": "Peligro: enemigos y botín", "en": "Danger: foes and loot", "fr": "Danger : ennemis et butin",
			"it": "Pericolo: nemici e bottino", "de": "Gefahr: Feinde und Beute", "zh": "危险：敌人与战利品", "ja": "危険：敵と戦利品"
		})
		"gather":  return Locale.pick({
			"es": "Zona de recolección de recursos", "en": "Resource gathering", "fr": "Zone de récolte de ressources",
			"it": "Raccolta risorse", "de": "Rohstoffsammelgebiet", "zh": "资源采集区", "ja": "素材採取エリア"
		})
		"place":   return Locale.pick({
			"es": "Lugar de interés", "en": "Point of interest", "fr": "Point d'intérêt",
			"it": "Punto di interesse", "de": "Sehenswürdigkeit", "zh": "兴趣点", "ja": "名所・拠点"
		})
		"base":    return Locale.pick({
			"es": "Tu tienda: duerme para recuperarte", "en": "Your tent: sleep to recover", "fr": "Ta tente : dors pour récupérer",
			"it": "La tua tenda: dormi per riprenderti", "de": "Dein Zelt: schlafe zur Erholung", "zh": "你的帐篷：睡觉以恢复", "ja": "テント：寝て回復する"
		})
		"campfire": return Locale.pick({
			"es": "Hoguera: cocina tus provisiones", "en": "Campfire: cook your provisions", "fr": "Feu de camp : cuisine tes provisions",
			"it": "Fuoco da campo: cucina le provviste", "de": "Lagerfeuer: koche deine Vorräte", "zh": "营火：烹饪你的补给", "ja": "焚き火：食材を調理する"
		})
		_:         return Locale.pick({
			"es": "Terreno despejado", "en": "Open terrain", "fr": "Terrain dégagé",
			"it": "Terreno aperto", "de": "Offenes Gelände", "zh": "开阔地形", "ja": "開けた地形"
		})

#endregion
