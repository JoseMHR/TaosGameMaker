# TabProfessions.gd
# Vista dedicada a la gestión de Profesiones y asignación de 4 Habilidades de Combate.
class_name TabProfessions
extends Control

var _selected_prof: String = ""
var _selected_slot_idx: int = -1
## Si `state_updated` llega mientras la pestaña no está visible (oculta tras
## cambiar de sub-pestaña en el Hub), se marca para refrescar en cuanto vuelve
## a mostrarse en vez de reconstruir en el acto.
var _dirty: bool = false

var _prof_list_box: VBoxContainer
var _oficios_list_box: VBoxContainer
var _active_slots_box: HBoxContainer
var _catalog_grid: GridContainer
var _upcoming_grid: GridContainer
var _upcoming_head: Label
var _upcoming_scroll: ScrollContainer
var _prof_title_lbl: Label
var _activate_btn: Button

const JOBS: Array[String] = [
	"Don Nadie",
	"Guerrero",
	"Arquero",
	"Elementalista",
	"Sacerdote",
	"Psíquico",
	"Tiempo"
]

const OFICIOS_DATA: Array[Dictionary] = [
	{"key": "lenador", "icon": "🪵", "color": Color("c08457")},
	{"key": "minero", "icon": "🪨", "color": Color("93a1b5")},
	{"key": "pesca", "icon": "🐟", "color": Color(0.24, 0.55, 0.95)},
	{"key": "agricultor", "icon": "🌾", "color": Color("e0b93a")},
	{"key": "ganadero", "icon": "🥛", "color": Color("cfd8e3")},
	{"key": "cazador", "icon": "🍖", "color": Color("b5573c")},
	{"key": "cocinero", "icon": "🍳", "color": Color("f2a65a")},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selected_prof = GlobalState.profession if GlobalState.profession != "" else "Don Nadie"
	_build_ui()
	GlobalState.state_updated.connect(_refresh)
	Locale.locale_changed.connect(func() -> void: _build_ui())
	Locale.theme_changed.connect(func(_id: String) -> void: _build_ui())
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree() and _dirty:
			_refresh()
	)


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var root_margin := UiKit.margins(10, 10, 10, 10)
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_margin)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	root_margin.add_child(main_hbox)

	# ── COLUMNA IZQUIERDA (28%): LISTA DE PROFESIONES DE COMBATE ───────────────
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.28
	UiKit.premium_frame(left_panel, {"corner_radius": 14.0, "pad": 0})
	main_hbox.add_child(left_panel)

	var left_margin := UiKit.margins(16, 16, 16, 16)
	left_panel.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 12)
	left_margin.add_child(left_vbox)

	var left_head := Label.new()
	left_head.text = "⚔️ " + Locale.pick({"es": "Profesiones", "en": "Professions"})
	left_head.add_theme_font_size_override("font_size", 22)
	left_head.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY)
	left_vbox.add_child(left_head)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enable_drag_scroll(left_scroll)
	left_vbox.add_child(left_scroll)

	_prof_list_box = VBoxContainer.new()
	_prof_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prof_list_box.add_theme_constant_override("separation", 8)
	left_scroll.add_child(_prof_list_box)

	# ── COLUMNA CENTRAL (48%): SLOTS ACTIVOS + CATÁLOGO DE HABILIDADES ────────
	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_stretch_ratio = 0.48
	UiKit.premium_frame(center_panel, {"corner_radius": 14.0, "pad": 0})
	main_hbox.add_child(center_panel)

	var center_margin := UiKit.margins(20, 20, 16, 16)
	center_panel.add_child(center_margin)

	var center_vbox := VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 12)
	center_margin.add_child(center_vbox)

	# Cabecera de Profesión Seleccionada
	var head_hbox := HBoxContainer.new()
	center_vbox.add_child(head_hbox)

	_prof_title_lbl = Label.new()
	_prof_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prof_title_lbl.add_theme_font_size_override("font_size", 24)
	_prof_title_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY)
	head_hbox.add_child(_prof_title_lbl)

	_activate_btn = Button.new()
	_activate_btn.text = "⚡ " + Locale.pick({"es": "Activar Profesión", "en": "Activate Profession"})
	_activate_btn.custom_minimum_size = Vector2(180, 44)
	_activate_btn.add_theme_font_size_override("font_size", 17)
	UiKit.premium_button(_activate_btn, {"border_width": 2.0, "corner_radius": 10.0})
	_activate_btn.pressed.connect(_on_activate_pressed)
	head_hbox.add_child(_activate_btn)

	center_vbox.add_child(HSeparator.new())

	# SLOTS ACTIVOS DE COMBATE (4)
	var slots_head := Label.new()
	slots_head.text = "🎯 " + Locale.pick({"es": "Habilidades Activas de Combate (4 Slots)", "en": "Active Combat Skills (4 Slots)"})
	slots_head.add_theme_font_size_override("font_size", 19)
	slots_head.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	center_vbox.add_child(slots_head)

	_active_slots_box = HBoxContainer.new()
	_active_slots_box.add_theme_constant_override("separation", 10)
	center_vbox.add_child(_active_slots_box)

	center_vbox.add_child(HSeparator.new())

	# CATÁLOGO DE HABILIDADES APRENDIDAS
	var cat_head := Label.new()
	cat_head.text = "📜 " + Locale.pick({"es": "Catálogo de Habilidades Aprendidas", "en": "Learned Skill Catalog"})
	cat_head.add_theme_font_size_override("font_size", 19)
	cat_head.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	center_vbox.add_child(cat_head)

	var cat_scroll := ScrollContainer.new()
	cat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enable_drag_scroll(cat_scroll)
	center_vbox.add_child(cat_scroll)

	_catalog_grid = GridContainer.new()
	_catalog_grid.columns = 2
	_catalog_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_grid.add_theme_constant_override("h_separation", 10)
	_catalog_grid.add_theme_constant_override("v_separation", 10)
	cat_scroll.add_child(_catalog_grid)

	# "Próximas Habilidades" — tarjetas bloqueadas para las habilidades de mayor
	# nivel que el jugador aún no ha desbloqueado.
	_upcoming_head = Label.new()
	_upcoming_head.text = "🔒 " + Locale.pick({"es": "Próximas Habilidades", "en": "Upcoming Skills"})
	_upcoming_head.add_theme_font_size_override("font_size", 19)
	_upcoming_head.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	center_vbox.add_child(_upcoming_head)

	_upcoming_scroll = ScrollContainer.new()
	_upcoming_scroll.custom_minimum_size.y = 160
	_upcoming_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_upcoming_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enable_drag_scroll(_upcoming_scroll)
	center_vbox.add_child(_upcoming_scroll)

	_upcoming_grid = GridContainer.new()
	_upcoming_grid.columns = 2
	_upcoming_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upcoming_grid.add_theme_constant_override("h_separation", 10)
	_upcoming_grid.add_theme_constant_override("v_separation", 10)
	_upcoming_scroll.add_child(_upcoming_grid)

	# ── COLUMNA DERECHA (24%): LISTA DE OFICIOS / HABILIDADES DE FARMEO ───────
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.24
	UiKit.premium_frame(right_panel, {"corner_radius": 14.0, "pad": 0})
	main_hbox.add_child(right_panel)

	var right_margin := UiKit.margins(16, 16, 16, 16)
	right_panel.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_margin.add_child(right_vbox)

	var right_head := Label.new()
	right_head.text = "⛏️ " + Locale.pick({"es": "Oficios", "en": "Crafts"})
	right_head.add_theme_font_size_override("font_size", 22)
	right_head.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY)
	right_vbox.add_child(right_head)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enable_drag_scroll(right_scroll)
	right_vbox.add_child(right_scroll)

	_oficios_list_box = VBoxContainer.new()
	_oficios_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_oficios_list_box.add_theme_constant_override("separation", 8)
	right_scroll.add_child(_oficios_list_box)

	_refresh()


## Habilita el desplazamiento vertical por arrastre con ratón o pantalla táctil en ScrollContainer.
func _enable_drag_scroll(scroll: ScrollContainer) -> void:
	var drag_state := {"active": false, "start_y": 0.0, "scroll_start": 0}
	scroll.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT) or ev is InputEventScreenTouch:
			if ev.pressed:
				drag_state["active"] = true
				drag_state["start_y"] = ev.global_position.y
				drag_state["scroll_start"] = scroll.scroll_vertical
			else:
				drag_state["active"] = false
		elif (ev is InputEventMouseMotion or ev is InputEventScreenDrag) and bool(drag_state["active"]):
			var dy: float = ev.global_position.y - float(drag_state["start_y"])
			scroll.scroll_vertical = maxi(0, int(float(drag_state["scroll_start"]) - dy))
	)


func _refresh() -> void:
	if not is_visible_in_tree():
		_dirty = true
		return
	_dirty = false
	_render_prof_list()
	_render_active_slots()
	_render_catalog()
	_render_upcoming()
	_render_oficios_list()


func _render_prof_list() -> void:
	if _prof_list_box == null:
		return
	for c in _prof_list_box.get_children():
		c.queue_free()

	for job_id in JOBS:
		var unlocked: bool = job_id in GlobalState.unlocked_professions or job_id == "Don Nadie"
		var is_active: bool = GlobalState.profession == job_id
		var is_selected: bool = _selected_prof == job_id
		var progress: Dictionary = GlobalState.get_profession_progress(job_id)
		var level: int = int(progress.get("level", 1))
		var xp: int = int(progress.get("xp", 0))
		var xp_needed: int = maxi(1, int(progress.get("xp_needed", 100)))
		var xp_pct: float = clampf(float(xp) / float(xp_needed), 0.0, 1.0)

		# Tarjeta considerablemente más grande y cómoda de pulsar
		# (antes 52px de alto, texto de 14px, sin barra de XP ni indicador
		# claro de activación).
		var card := PanelContainer.new()
		card.custom_minimum_size.y = 116
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		if is_selected:
			style.bg_color = Color(0.14, 0.16, 0.28, 0.9)
			style.border_color = UiKit.COLOR_GOLD_PRIMARY
		else:
			style.bg_color = Color(0.06, 0.07, 0.12, 0.7)
			style.border_color = Color(0.2, 0.2, 0.3, 0.5)
		if is_active:
			style.border_color = UiKit.GOOD
			style.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", style)

		var outer_btn := Button.new()
		outer_btn.flat = true
		outer_btn.focus_mode = Control.FOCUS_NONE
		outer_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		outer_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
		if unlocked:
			outer_btn.pressed.connect(func() -> void:
				_selected_prof = job_id
				AudioManager.play_ui("select")
				_refresh()
			)
			card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			card.gui_input.connect(func(ev: InputEvent) -> void:
				if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
					_selected_prof = job_id
					AudioManager.play_ui("select")
					_refresh()
			)
		else:
			outer_btn.disabled = true

		card.add_child(outer_btn)

		# Margen interior para separar los contenidos del borde de la tarjeta
		var row_margin := MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 14)
		row_margin.add_theme_constant_override("margin_right", 14)
		row_margin.add_theme_constant_override("margin_top", 8)
		row_margin.add_theme_constant_override("margin_bottom", 8)
		row_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row_margin)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_margin.add_child(hbox)

		# 1. Avatar grande enmarcado — misma imagen que el selector de clase en
		# combate (`CombatTabsUI.get_prof_texture_path`), en vez de un simple
		# icono/emoji. Bloqueada sigue mostrando el candado.
		var icon_frame := PanelContainer.new()
		icon_frame.custom_minimum_size = Vector2(88, 88)
		icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(0, 0, 0, 0.35)
		icon_style.set_corner_radius_all(10)
		icon_style.set_border_width_all(2)
		icon_style.border_color = UiKit.GOOD if is_active else Color(0.3, 0.3, 0.4, 0.7)
		icon_frame.add_theme_stylebox_override("panel", icon_style)
		if unlocked:
			var avatar_rect := TextureRect.new()
			avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			avatar_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			avatar_rect.offset_left += 6
			avatar_rect.offset_top += 6
			avatar_rect.offset_right -= 6
			avatar_rect.offset_bottom -= 6
			var tex_path := CombatTabsUI.get_prof_texture_path(job_id)
			if ResourceLoader.exists(tex_path):
				avatar_rect.texture = load(tex_path)
			icon_frame.add_child(avatar_rect)
		else:
			var icon_lbl := Label.new()
			icon_lbl.text = "🔒"
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_lbl.add_theme_font_size_override("font_size", 40)
			icon_frame.add_child(icon_lbl)
		hbox.add_child(icon_frame)

		# 2. Nombre + Nivel + barra de experiencia.
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info_vbox.add_theme_constant_override("separation", 4)
		hbox.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = Locale.translate_profession(job_id)
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY if is_active else UiKit.TEXT)
		info_vbox.add_child(name_lbl)

		if unlocked:
			var lvl_lbl := Label.new()
			lvl_lbl.text = Locale.pick({"es": "NV. %d", "en": "LV. %d"}) % level
			lvl_lbl.add_theme_font_size_override("font_size", 16)
			lvl_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			info_vbox.add_child(lvl_lbl)

			var xp_bar := ProgressBar.new()
			xp_bar.custom_minimum_size = Vector2(0, 14)
			xp_bar.max_value = 1.0
			xp_bar.value = xp_pct
			UiKit.style_progress(xp_bar, UiKit.XP, 6)
			info_vbox.add_child(xp_bar)

			var xp_lbl := Label.new()
			xp_lbl.text = "%d / %d XP (%d%%)" % [xp, xp_needed, int(round(xp_pct * 100.0))]
			xp_lbl.add_theme_font_size_override("font_size", 14)
			xp_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			info_vbox.add_child(xp_lbl)
		else:
			var locked_lbl := Label.new()
			locked_lbl.text = Locale.pick({"es": "Bloqueada", "en": "Locked"})
			locked_lbl.add_theme_font_size_override("font_size", 15)
			locked_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			info_vbox.add_child(locked_lbl)

		# 3. Botón de estado / activación:
		# Si está activa -> botón verde "✅ Activada" (al pulsarla selecciona la profesión para verla).
		# Si está desbloqueada -> botón dorado "⚡ Activar" para activarla directamente desde la lista.
		var act_btn: Button = null
		if unlocked:
			act_btn = Button.new()
			act_btn.custom_minimum_size = Vector2(130, 44)
			act_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			act_btn.focus_mode = Control.FOCUS_NONE
			act_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			act_btn.add_theme_font_size_override("font_size", 16)
			if is_active:
				act_btn.text = "✅ " + Locale.pick({"es": "Activada", "en": "Active"})
				UiKit.premium_button(act_btn, {
					"bg_color": Color(UiKit.GOOD.r, UiKit.GOOD.g, UiKit.GOOD.b, 0.25),
					"border_color": UiKit.GOOD,
					"text_color": UiKit.GOOD,
					"corner_radius": 10.0,
					"border_width": 2.0
				})
				act_btn.pressed.connect(func() -> void:
					_selected_prof = job_id
					AudioManager.play_ui("select")
					_refresh()
				)
			else:
				act_btn.text = "⚡ " + Locale.pick({"es": "Activar", "en": "Activate"})
				UiKit.premium_button(act_btn, {
					"bg_color": Color(UiKit.COLOR_GOLD_PRIMARY.r, UiKit.COLOR_GOLD_PRIMARY.g, UiKit.COLOR_GOLD_PRIMARY.b, 0.18),
					"border_color": UiKit.COLOR_GOLD_PRIMARY,
					"text_color": UiKit.COLOR_GOLD_PRIMARY,
					"corner_radius": 10.0,
					"border_width": 2.0
				})
				act_btn.pressed.connect(func() -> void:
					_selected_prof = job_id
					GlobalState.set_profession(job_id)
					AudioManager.play_ui("select")
					_refresh()
				)
			hbox.add_child(act_btn)

		# Toda la fila informativa se ignora para el ratón/toque para que el clic
		# sobre el avatar, textos, barra XP o fondo llegue a outer_btn / card.gui_input.
		_ignore_mouse_recursive(hbox)

		# Restaurar interactividad del botón de activar
		if act_btn != null:
			act_btn.mouse_filter = Control.MOUSE_FILTER_STOP

		_prof_list_box.add_child(card)


## Pone `mouse_filter = IGNORE` en `node` y en todos sus descendientes
## `Control`, para que ninguno intercepte el clic/toque antes de que llegue al
## botón "flat" de fondo de la tarjeta (`outer_btn`). Ver task_bugs_observados.md §2.2.
func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)


func _render_active_slots() -> void:
	if _active_slots_box == null:
		return
	for c in _active_slots_box.get_children():
		c.queue_free()

	# Slots de 4 posiciones SIN compactar (preserva huecos vacíos en su índice
	# real): usar `get_active_combat_skills()` aquí desplazaba las habilidades
	# hacia posiciones incorrectas al haber huecos intermedios.
	var active_skills: Array = GlobalState.get_combat_skill_slots(_selected_prof)
	for i in range(4):
		var skill_id: String = String(active_skills[i]) if i < active_skills.size() else ""
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 60)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 16)

		if skill_id != "":
			var skill_def: Dictionary = Design.get_skill(skill_id)
			var sk_name: String = Locale.pick(skill_def.get("name", {}))
			var img_path := "res://assets/combat/skills/%s.png" % skill_id
			var sk_tex := UiKit.load_texture_safe(img_path)
			if sk_tex:
				btn.text = ""
				var hb_slot := HBoxContainer.new()
				hb_slot.alignment = BoxContainer.ALIGNMENT_CENTER
				hb_slot.add_theme_constant_override("separation", 8)
				hb_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hb_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

				var num_lbl := Label.new()
				num_lbl.text = "%d." % (i + 1)
				num_lbl.add_theme_font_size_override("font_size", 14)
				num_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
				hb_slot.add_child(num_lbl)

				var trect := TextureRect.new()
				trect.custom_minimum_size = Vector2(32, 32)
				trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				trect.texture = sk_tex
				hb_slot.add_child(trect)

				var name_lbl := Label.new()
				name_lbl.text = sk_name
				name_lbl.add_theme_font_size_override("font_size", 14)
				hb_slot.add_child(name_lbl)

				btn.add_child(hb_slot)
			else:
				btn.text = "%d. %s %s" % [i + 1, skill_def.get("icon", "⚔️"), sk_name]
		else:
			var empty_txt := Locale.pick({
				"es": "%d. [ Vacío ]",
				"en": "%d. [ Empty ]",
				"fr": "%d. [ Vide ]",
				"it": "%d. [ Vuoto ]",
				"de": "%d. [ Leer ]",
				"zh": "%d. [ 空 ]",
				"ja": "%d. [ 空き ]"
			}) % (i + 1)
			btn.text = empty_txt
			btn.add_theme_color_override("font_color", UiKit.TEXT_DIM)

		var is_selected_slot: bool = (_selected_slot_idx == i)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		style.bg_color = Color(0.1, 0.12, 0.2, 0.8)
		style.border_color = UiKit.COLOR_GOLD_PRIMARY if is_selected_slot else Color(0.25, 0.3, 0.4)
		btn.add_theme_stylebox_override("normal", style)

		var slot_idx := i
		btn.pressed.connect(func() -> void:
			_selected_slot_idx = slot_idx
			AudioManager.play_ui("select")
			_render_active_slots()
			if skill_id != "":
				_show_skill_info_modal(skill_id)
		)
		_active_slots_box.add_child(btn)


func _render_catalog() -> void:
	if _catalog_grid == null:
		return
	for c in _catalog_grid.get_children():
		c.queue_free()

	var prof_display := Locale.translate_profession(_selected_prof)
	_prof_title_lbl.text = "⚔️ " + prof_display + (Locale.pick({"es": " (Activa)", "en": " (Active)"}) if GlobalState.profession == _selected_prof else "")
	_activate_btn.visible = (GlobalState.profession != _selected_prof) and (_selected_prof in GlobalState.unlocked_professions or _selected_prof == "Don Nadie")

	# `Design.get_profession_skills()` combina las entradas crudas `{level, id}` de
	# professions.json con la definición completa de skills.json (id/name/icon/...);
	# aquí solo mostramos las YA aprendidas (nivel de JB alcanzado).
	var sel_lvl: int = GlobalState.get_profession_level(_selected_prof)
	var skills_list: Array = []
	for sk_def: Dictionary in Design.get_profession_skills(_selected_prof):
		if int(sk_def.get("level", 1)) <= sel_lvl:
			skills_list.append(sk_def)

	if skills_list.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = Locale.pick({"es": "No hay habilidades disponibles para esta profesión.", "en": "No skills available for this profession."})
		empty_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		_catalog_grid.add_child(empty_lbl)
		return

	for sk_def in skills_list:
		var skill_id := String(sk_def.get("id", ""))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 76)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.1, 0.16, 0.85)
		style.border_color = Color(0.2, 0.25, 0.35, 0.6)
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		card.add_child(hbox)

		var img_path := "res://assets/combat/skills/%s.png" % skill_id
		var sk_tex := UiKit.load_texture_safe(img_path)
		if sk_tex:
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(40, 40)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = sk_tex
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(icon_rect)
		else:
			var icon_lbl := Label.new()
			icon_lbl.text = String(sk_def.get("icon", "⚔️"))
			icon_lbl.add_theme_font_size_override("font_size", 24)
			hbox.add_child(icon_lbl)

		var name_vbox := VBoxContainer.new()
		name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_child(name_vbox)

		var sk_name := Label.new()
		sk_name.text = Locale.pick(sk_def.get("name", {}))
		sk_name.add_theme_font_size_override("font_size", 17)
		name_vbox.add_child(sk_name)

		# Botón de Información detallada de la habilidad
		var info_btn := Button.new()
		info_btn.text = "ℹ️ " + Locale.pick({"es": "Info", "en": "Info"})
		info_btn.custom_minimum_size = Vector2(80, 40)
		info_btn.add_theme_font_size_override("font_size", 14)
		info_btn.focus_mode = Control.FOCUS_NONE
		info_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		info_btn.tooltip_text = Locale.pick({"es": "Ver detalles de la habilidad", "en": "View skill details"})
		UiKit.premium_button(info_btn, {
			"bg_color": Color(0.12, 0.18, 0.3, 0.8),
			"border_color": Color(0.35, 0.5, 0.8, 0.8),
			"text_color": UiKit.ACCENT_SOFT,
			"corner_radius": 8.0,
			"border_width": 1.5
		})
		info_btn.pressed.connect(func() -> void:
			AudioManager.play_ui("select")
			_show_skill_info_modal(skill_id)
		)
		hbox.add_child(info_btn)

		var assign_btn := Button.new()
		assign_btn.text = "➕ " + Locale.pick({"es": "Equipar", "en": "Equip"})
		assign_btn.custom_minimum_size = Vector2(96, 40)
		assign_btn.add_theme_font_size_override("font_size", 14)
		for st in ["normal", "hover", "pressed", "focus"]:
			assign_btn.add_theme_stylebox_override(st, UiKit.button_primary(8))
		assign_btn.pressed.connect(func() -> void:
			_assign_skill(skill_id)
		)
		hbox.add_child(assign_btn)

		# Clic en cualquier parte de la tarjeta abre también la modal de información
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
				AudioManager.play_ui("select")
				_show_skill_info_modal(skill_id)
		)

		_catalog_grid.add_child(card)


## Tarjetas BLOQUEADAS para las habilidades de la profesión seleccionada que
## aún no se han desbloqueado (nivel de JB insuficiente) — solo muestran el
## nivel requerido y un nombre oculto ("???"), sin icono ni nombre reales,
## para no revelar contenido no alcanzado todavía.
func _render_upcoming() -> void:
	if _upcoming_grid == null:
		return
	for c in _upcoming_grid.get_children():
		c.queue_free()

	var sel_lvl: int = GlobalState.get_profession_level(_selected_prof)
	var locked_list: Array = []
	for sk_def: Dictionary in Design.get_profession_skills(_selected_prof):
		if int(sk_def.get("level", 1)) > sel_lvl:
			locked_list.append(sk_def)

	var has_locked: bool = not locked_list.is_empty()
	if _upcoming_head != null:
		_upcoming_head.visible = has_locked
	if _upcoming_scroll != null:
		_upcoming_scroll.visible = has_locked
	if not has_locked:
		return

	for sk_def in locked_list:
		var req_lvl := int(sk_def.get("level", 1))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 68)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.06, 0.08, 0.8)
		style.border_color = Color(0.2, 0.2, 0.22, 0.5)
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		card.add_child(hbox)

		var icon_lbl := Label.new()
		icon_lbl.text = "🔒"
		icon_lbl.add_theme_font_size_override("font_size", 26)
		hbox.add_child(icon_lbl)

		var name_vbox := VBoxContainer.new()
		name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(name_vbox)

		var name_lbl := Label.new()
		name_lbl.text = Locale.pick({"es": "Nivel %d: ???" % req_lvl, "en": "Level %d: ???" % req_lvl})
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		name_vbox.add_child(name_lbl)

		# Indicar cuántos niveles faltan para desbloquear, no solo el nivel
		# absoluto requerido — da una sensación de progreso inmediata sin
		# revelar el contenido bloqueado.
		var levels_left := maxi(0, req_lvl - sel_lvl)
		var progress_lbl := Label.new()
		progress_lbl.text = Locale.pick({
			"es": "Te faltan %d nivel%s" % [levels_left, "es" if levels_left != 1 else ""],
			"en": "%d level%s to go" % [levels_left, "s" if levels_left != 1 else ""],
		})
		progress_lbl.add_theme_font_size_override("font_size", 14)
		progress_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY)
		name_vbox.add_child(progress_lbl)

		_upcoming_grid.add_child(card)


func _assign_skill(skill_id: String) -> void:
	# Partir de los slots SIN compactar: así equipar en el slot 2 no desplaza
	# de sitio a la habilidad que ya ocupaba el slot 0.
	var current: Array = GlobalState.get_combat_skill_slots(_selected_prof).duplicate()
	while current.size() < 4:
		current.append("")

	var target_slot := _selected_slot_idx
	if target_slot < 0:
		# Si no hay slot seleccionado, buscar el primer hueco libre
		for i in range(4):
			if current[i] == "":
				target_slot = i
				break
		if target_slot < 0:
			target_slot = 0

	# Si la habilidad ya estaba equipada en otro slot, desequiparla de allí para evitar duplicados
	for i in range(4):
		if i != target_slot and current[i] == skill_id:
			current[i] = ""

	current[target_slot] = skill_id
	GlobalState.active_combat_skills[_selected_prof] = current
	GlobalState.state_updated.emit()
	AudioManager.play_ui("select")
	_refresh()


func _on_activate_pressed() -> void:
	GlobalState.set_profession(_selected_prof)
	AudioManager.play_ui("select")
	_refresh()


func _render_oficios_list() -> void:
	if _oficios_list_box == null:
		return
	for c in _oficios_list_box.get_children():
		c.queue_free()

	for of_data in OFICIOS_DATA:
		var key: String = of_data["key"]
		var icon: String = of_data["icon"]
		var col: Color = of_data["color"]
		var sd: Dictionary = GlobalState.skills.get(key, {"level": 1, "xp": 0, "xp_needed": 50})
		var lvl: int = int(sd.get("level", 1))
		var xp: int = int(sd.get("xp", 0))
		var needed: int = maxi(1, int(sd.get("xp_needed", 50)))
		var xp_pct: float = clampf(float(xp) / float(needed), 0.0, 1.0)
		var of_name: String = Locale.t("skill_" + key)
		if of_name == "skill_" + key:
			of_name = key.capitalize()

		var card := PanelContainer.new()
		card.custom_minimum_size.y = 86
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.bg_color = Color(0.06, 0.07, 0.12, 0.75)
		style.border_color = Color(col.r, col.g, col.b, 0.4)
		card.add_theme_stylebox_override("panel", style)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 12)
		card_margin.add_theme_constant_override("margin_right", 12)
		card_margin.add_theme_constant_override("margin_top", 10)
		card_margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(card_margin)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		card_margin.add_child(hbox)

		# Icono con marco de color del oficio
		var icon_frame := PanelContainer.new()
		icon_frame.custom_minimum_size = Vector2(56, 56)
		icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(col.r, col.g, col.b, 0.15)
		icon_style.set_corner_radius_all(8)
		icon_style.set_border_width_all(1)
		icon_style.border_color = col
		icon_frame.add_theme_stylebox_override("panel", icon_style)

		var icon_lbl := Label.new()
		icon_lbl.text = icon
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 28)
		icon_frame.add_child(icon_lbl)
		hbox.add_child(icon_frame)

		# Contenedor de textos y barra
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info_vbox.add_theme_constant_override("separation", 3)
		hbox.add_child(info_vbox)

		# Fila superior: Nombre + Nivel
		var top_hbox := HBoxContainer.new()
		info_vbox.add_child(top_hbox)

		var name_lbl := Label.new()
		name_lbl.text = of_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", UiKit.TEXT)
		top_hbox.add_child(name_lbl)

		var lvl_lbl := Label.new()
		lvl_lbl.text = Locale.pick({"es": "Nv. %d", "en": "Lv. %d"}) % lvl
		lvl_lbl.add_theme_font_size_override("font_size", 15)
		lvl_lbl.add_theme_color_override("font_color", col)
		top_hbox.add_child(lvl_lbl)

		# Recurso asociado (si hay)
		var res: Dictionary = GameConfig.GATHER_RESOURCES.get(key, {})
		if not res.is_empty():
			var owned: int = int(GlobalState.get_item(res["id"]).get("quantity", 0))
			var res_lbl := Label.new()
			res_lbl.text = "%s %s: %d" % [res.get("icon", ""), Locale.t(res.get("loc", "")), owned]
			res_lbl.add_theme_font_size_override("font_size", 12)
			res_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			info_vbox.add_child(res_lbl)

		# Barra de experiencia
		var xp_bar := ProgressBar.new()
		xp_bar.custom_minimum_size = Vector2(0, 10)
		xp_bar.max_value = 1.0
		xp_bar.value = xp_pct
		UiKit.style_progress(xp_bar, col, 5)
		info_vbox.add_child(xp_bar)

		# Texto de XP
		var xp_lbl := Label.new()
		xp_lbl.text = "%d / %d XP (%d%%)" % [xp, needed, int(round(xp_pct * 100.0))]
		xp_lbl.add_theme_font_size_override("font_size", 12)
		xp_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		info_vbox.add_child(xp_lbl)

		_oficios_list_box.add_child(card)


func _show_skill_info_modal(skill_id: String) -> void:
	if skill_id == "":
		return
	var sk_def: Dictionary = Design.get_skill(skill_id)
	if sk_def.is_empty():
		return

	var sk_name: String = Locale.pick(sk_def.get("name", {}))
	var icon: String = String(sk_def.get("icon", "⚔️"))
	var d_val = sk_def.get("desc", {})
	var desc_str: String = Locale.pick(d_val) if d_val is Dictionary else String(d_val)
	if desc_str.is_empty():
		desc_str = Locale.pick({"es": "Técnica de combate.", "en": "Combat technique."})

	var sk_type: String = String(sk_def.get("type", "physical")).to_lower()
	var element: String = String(sk_def.get("element", "none")).to_lower()
	var power: int = int(sk_def.get("power", 0))
	var mp_cost: int = int(sk_def.get("cost", 0))
	var pa_cost: int = int(sk_def.get("pa_cost", 1))
	var res_gain: int = int(sk_def.get("resonance_gain", 0))
	var status = sk_def.get("status", null)

	var lines: Array[String] = []
	lines.append(desc_str)
	lines.append("")

	var type_label: String = ""
	match sk_type:
		"physical": type_label = Locale.pick({"es": "Ataque Físico", "en": "Physical Attack"})
		"magical": type_label = Locale.pick({"es": "Ataque Mágico", "en": "Magical Attack"})
		"heal": type_label = Locale.pick({"es": "Curación", "en": "Healing"})
		"buff": type_label = Locale.pick({"es": "Mejora / Soporte", "en": "Buff / Support"})
		"debuff": type_label = Locale.pick({"es": "Alteración de Estado", "en": "Debuff"})
		_: type_label = sk_type.capitalize()

	var elem_label: String = ""
	match element:
		"physical": elem_label = Locale.pick({"es": "Físico", "en": "Physical"})
		"fire": elem_label = "🔥 " + Locale.pick({"es": "Fuego", "en": "Fire"})
		"ice", "water": elem_label = "💧 " + Locale.pick({"es": "Agua / Hielo", "en": "Water / Ice"})
		"wind": elem_label = "🌪️ " + Locale.pick({"es": "Viento", "en": "Wind"})
		"earth": elem_label = "🪨 " + Locale.pick({"es": "Tierra", "en": "Earth"})
		"lightning": elem_label = "⚡ " + Locale.pick({"es": "Rayo", "en": "Lightning"})
		"light": elem_label = "✨ " + Locale.pick({"es": "Luz", "en": "Light"})
		"dark": elem_label = "🌑 " + Locale.pick({"es": "Oscuridad", "en": "Dark"})
		"none": elem_label = Locale.pick({"es": "Neutro", "en": "Neutral"})
		_: elem_label = element.capitalize()

	lines.append("🏷️  %s: %s (%s)" % [Locale.pick({"es": "Tipo", "en": "Type"}), type_label, elem_label])

	var cost_parts: Array[String] = []
	cost_parts.append("%d PA" % pa_cost)
	if mp_cost > 0:
		cost_parts.append("%d MP" % mp_cost)
	lines.append("⚡  %s: %s" % [Locale.pick({"es": "Coste", "en": "Cost"}), " · ".join(cost_parts)])

	if sk_type == "heal" or sk_def.has("heal"):
		var heal_val: int = int(sk_def.get("heal", power))
		if heal_val > 0:
			lines.append("💚  %s: %d" % [Locale.pick({"es": "Potencia de Curación", "en": "Healing Power"}), heal_val])
	elif power > 0:
		lines.append("⚔️  %s: %d" % [Locale.pick({"es": "Potencia de Daño", "en": "Damage Power"}), power])

	if res_gain > 0:
		lines.append("🌀  %s: +%d" % [Locale.pick({"es": "Resonancia", "en": "Resonance"}), res_gain])

	if status is Dictionary and not status.is_empty():
		var st_type: String = String(status.get("type", ""))
		var st_turns: int = int(status.get("turns", 1))
		lines.append("⏳  %s: %s (%d %s)" % [
			Locale.pick({"es": "Efecto", "en": "Effect"}),
			st_type.capitalize(),
			st_turns,
			Locale.pick({"es": "turnos", "en": "turns"})
		])

	var title: String = "%s %s" % [icon, sk_name]
	var body: String = "\n".join(lines)
	UiKit.alert(self, title, body, Locale.pick({"es": "Entendido", "en": "Understood"}))

