# CombatTabsUI.gd
# ─────────────────────────────────────────────────────────────────────────────
# GESTIÓN DE TABS E INTERFAZ DE SELECCIÓN de combate: pestañas Poderes/Clases/
# Bolsa, tarjetas de habilidad/clase/consumible y el cambio de clase en combate
# (encolado y aplicado).
#
# Extraído de ViewCombat.gd (antes en el #region "GESTIÓN DE TABS E INTERFAZ
# SELECCIÓN" de un único fichero de ~3965 líneas). Cada función recibe
# `view: ViewCombat` explícito como primer parámetro en vez de depender de un
# `self` implícito, ya que necesita leer/escribir estado propio de ViewCombat
# (_content_grid, _tab_buttons, combat_queue, _active_tab...).
# ─────────────────────────────────────────────────────────────────────────────
class_name CombatTabsUI
extends RefCounted


const PROF_TEXTURES := {
	"Don Nadie": "res://assets/combat/character/prof_av_don_nadie.png",
	"Guerrero": "res://assets/combat/character/prof_av_guerrero.png",
	"Arquero": "res://assets/combat/character/prof_av_arquero.png",
	"Tiempo": "res://assets/combat/character/prof_av_tiempo.png",
	"Psíquico": "res://assets/combat/character/prof_av_psiquico.png",
	"Elementalista": "res://assets/combat/character/prof_av_elementalista.png",
	"Sacerdote": "res://assets/combat/character/prof_av_sacerdote.png"
}


static func get_prof_texture_path(prof_name: String) -> String:
	if PROF_TEXTURES.has(prof_name):
		var main_path: String = PROF_TEXTURES[prof_name]
		if ResourceLoader.exists(main_path):
			return main_path
	return "res://assets/combat/character/prof_av_don_nadie.png"


const PROF_FULLBODY_TEXTURES := {
	"Don Nadie": "res://assets/combat/character/prof_don_nadie.png",
	"Guerrero": "res://assets/combat/character/prof_guerrero.png",
	"Arquero": "res://assets/combat/character/prof_arquero.png",
	"Tiempo": "res://assets/combat/character/prof_tiempo.png",
	"Psíquico": "res://assets/combat/character/prof_psiquico.png",
	"Elementalista": "res://assets/combat/character/prof_elementalista.png",
	"Sacerdote": "res://assets/combat/character/prof_sacerdote.png"
}


static func get_prof_fullbody_path(prof_name: String, pose_state: Variant = "") -> String:
	var base_path: String = PROF_FULLBODY_TEXTURES.get(prof_name, "res://assets/combat/character/prof_don_nadie.png")
	var suffix := ""
	if pose_state is bool:
		suffix = "_defend.png" if pose_state else ".png"
	elif pose_state is String and not pose_state.is_empty():
		suffix = "_%s.png" % pose_state.to_lower()

	if not suffix.is_empty() and suffix != ".png":
		var alt_path := base_path.replace(".png", suffix)
		if ResourceLoader.exists(alt_path):
			return alt_path

	if ResourceLoader.exists(base_path):
		return base_path
	return "res://assets/combat/character/prof_don_nadie.png"


static func on_tab_pressed(view: ViewCombat, tab_key: String) -> void:
	AudioManager.play_sfx("click")
	view._active_tab = tab_key
	refresh_tab_highlight(view)
	build_tab_grid(view)


static func refresh_tab_highlight(view: ViewCombat) -> void:
	for btn in view._tab_buttons:
		if not is_instance_valid(btn):
			continue
		var key: String = String(btn.get_meta("tab_key", ""))
		var is_active: bool = key == view._active_tab
		var base_border: Color = btn.get_meta("base_border", view._theme_color("border", Color(0.2, 0.4, 0.6)))
		var base_bg: Color = btn.get_meta("base_bg", view._theme_color("panel_bg", Color(0.05, 0.06, 0.14)))
		
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(14)
		style.set_border_width_all(4)
		if is_active:
			style.bg_color = base_bg.lightened(0.18)
			style.border_color = Color.GOLD
			style.shadow_color = Color(1.0, 0.85, 0.2, 0.45)
			style.shadow_size = 10
		else:
			style.bg_color = base_bg
			style.border_color = base_border
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
			style.shadow_size = 6
		btn.add_theme_stylebox_override("normal", style)
		if is_active and btn.size.x > 1.0:
			UiKit.pop(btn, 1.05, 0.15)


static func build_tab_grid(view: ViewCombat) -> void:
	# Vaciar cuadrícula. `remove_child()` ANTES de `queue_free()` (no solo
	# `queue_free()`, que difiere el borrado al final del frame): si
	# `build_tab_grid()` se llama dos veces seguidas en el mismo frame (p. ej.
	# al iniciar combate justo cuando `GlobalState` aún está terminando de
	# inicializar la partida, como en una nueva partida en modo debug), las
	# tarjetas viejas seguían contando para el layout del `GridContainer`
	# durante ese frame de más, mezclándose visualmente con las nuevas (el
	# recuadro 2x2 se veía con solo 1-2 casillas ocupando media rejilla hasta
	# que el borrado diferido se aplicaba "unos segundos" después).
	for child in view._content_grid.get_children():
		view._content_grid.remove_child(child)
		child.queue_free()

	match view._active_tab:
		"powers":
			build_powers_grid(view)
		"classes":
			build_classes_grid(view)
		"bag":
			build_bag_grid(view)


## Construye una tarjeta de habilidad táctil y coherente con la paleta.
## `compact` = versión reducida (dos filas cuando hay muchas skills).
## Panel oscuro + borde e icono coloreados por TIPO, nombre y coste (PA/MP).
static func make_skill_card(view: ViewCombat, skill: Dictionary, compact: bool) -> Button:
	var type_col := view._skill_type_color(String(skill.get("type", "physical")))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 80) if compact else Vector2(110, 140)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER if compact else Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.clip_contents = true
	btn.pressed.connect(view._on_skill_pressed.bind(skill, btn))
	btn.pressed.connect(func() -> void: UiKit.pop(btn, 1.06, 0.14))

	var radius := 10 if compact else 14
	var border_c := type_col.lightened(0.35); border_c.a = 0.95
	var style := StyleBoxFlat.new()
	style.bg_color = view._theme_color("panel_bg", view.COL_PANEL)
	style.set_corner_radius_all(radius)
	style.set_border_width_all(3)
	style.border_color = border_c
	style.shadow_color = Color(type_col.r, type_col.g, type_col.b, 0.25)
	style.shadow_size = 4 if compact else 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	
	var style_hover := style.duplicate() as StyleBoxFlat
	style_hover.bg_color = view._theme_color("panel_bg", view.COL_PANEL).lightened(0.08)
	style_hover.border_color = view._theme_color("accent", Color(0.98, 0.80, 0.32)) # Borde dorado JRPG al enfocar
	style_hover.shadow_color = view._theme_color("accent", Color(0.98, 0.80, 0.32, 0.45))
	style_hover.shadow_size = 10
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("focus", style_hover)

	btn.pivot_offset = btn.custom_minimum_size / 2
	btn.mouse_entered.connect(func() -> void:
		var tw := btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4 if compact else 8)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36) if compact else Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var skill_id := String(skill.get("id", ""))
	var img_path := "res://assets/combat/skills/%s.png" % skill_id
	if ResourceLoader.exists(img_path):
		icon_rect.texture = load(img_path)

	var icon_frame := PanelContainer.new()
	var f_style := StyleBoxFlat.new()
	f_style.bg_color = view._theme_color("panel_bg", Color(0, 0, 0, 0.4))
	f_style.set_corner_radius_all(6)
	f_style.set_border_width_all(2)
	f_style.border_color = type_col.lightened(0.15)
	icon_frame.add_theme_stylebox_override("panel", f_style)
	icon_frame.custom_minimum_size = icon_rect.custom_minimum_size
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon_rect)
	vbox.add_child(icon_frame)

	# Sub-vbox para textos
	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 2 if compact else 4)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(text_vbox)

	var name_lbl := Label.new()
	name_lbl.text = view._skill_name(skill)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16 if compact else 18)
	name_lbl.add_theme_color_override("font_color", view._theme_color("text", view.COL_TEXT))
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_child(name_lbl)

	var pa_cost: int = view._effective_pa_cost(skill)
	var mp_cost: int = int(skill.get("cost", 0))
	var cost_lbl := Label.new()
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_size_override("font_size", 14 if compact else 16)
	cost_lbl.add_theme_color_override("font_color", view._theme_color("accent2", Color(0.62, 0.84, 1.0)))
	
	var cost_text := "🔷".repeat(max(pa_cost, 1))
	if mp_cost > 0:
		cost_text += " - 💧 %d" % mp_cost
	cost_lbl.text = cost_text
	text_vbox.add_child(cost_lbl)

	return btn


static func make_skill_card_grid4(view: ViewCombat, skill: Dictionary) -> Button:
	# BOOST VERTICAL (mismo factor 2.1x que el resto del HUD retrato): esta
	# función se reconstruye en cada cambio de orientación vía `build_tab_grid`
	# (llamada desde `_apply_orientation_layout`), así que basta boostear aquí.
	var boost := 2.1 if not view._is_landscape else 1.0
	var type_col := view._skill_type_color(String(skill.get("type", "physical")))
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 56 * boost)
	btn.focus_mode = Control.FOCUS_NONE
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.clip_contents = true

	var name_str := view._skill_name(skill)
	var d_val = skill.get("desc", "")
	var desc_str := String(Locale.pick(d_val)) if d_val is Dictionary else String(d_val)
	if desc_str.is_empty():
		desc_str = "Técnica de combate."

	var mp_cost: int = int(skill.get("cost", 0))
	var pa_cost: int = view._effective_pa_cost(skill)

	btn.tooltip_text = "%s\n%s\nCoste: %d PA · %d MP" % [name_str, desc_str, pa_cost, mp_cost]

	# Estilos visuales neoclásicos compactos
	var border_c := type_col.lightened(0.25); border_c.a = 0.8
	var style := StyleBoxFlat.new()
	style.bg_color = view._theme_color("panel_bg", Color(0.05, 0.07, 0.11, 0.90))
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = border_c
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	var style_hover := style.duplicate() as StyleBoxFlat
	style_hover.bg_color = Color(0.10, 0.14, 0.22, 0.95)
	style_hover.border_color = Color(0.98, 0.82, 0.32)
	style_hover.shadow_color = Color(0.98, 0.82, 0.32, 0.4)
	style_hover.shadow_size = 6

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("focus", style_hover)

	btn.pressed.connect(func() -> void:
		UiKit.pop(btn, 1.04, 0.10)
		view._on_skill_pressed(skill, btn)
	)

	# Actualizar la tarjeta flotante fija (SkillQuickInfoPanel) en hover
	btn.mouse_entered.connect(func() -> void:
		if view.has_method("_update_quick_skill_info"):
			view._update_quick_skill_info(skill)
	)

	# `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` estiraba el hbox a los
	# bordes EXACTOS del botón, ignorando los `content_margin_*` del StyleBox
	# (que solo afectan al texto propio de `Button`, no a hijos añadidos a mano):
	# el icono pisaba el borde izquierdo y el chip de coste el derecho (ver
	# task_bugs_observados.md §4.1). Se sustituye por offsets explícitos que sí
	# respetan el margen interno del botón.
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 8)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12
	hbox.offset_right = -12
	hbox.offset_top = 6
	hbox.offset_bottom = -6
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	# 1. Izquierda: Ícono de habilidad (32x32px)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32) * boost
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var skill_id := String(skill.get("id", ""))
	var img_path := "res://assets/combat/skills/%s.png" % skill_id
	var tex := UiKit.load_texture_safe(img_path)
	if tex != null:
		icon_rect.texture = tex

	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_rect)

	# 2. Centro: Nombre completo de la habilidad (15px, expand_fill)
	var name_lbl := Label.new()
	name_lbl.text = name_str
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", roundi(15 * boost))
	name_lbl.add_theme_color_override("font_color", view._theme_color("text", UiKit.TEXT))
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	# 3. Derecha: Costes de PA (amarillo) y MP (azul) en un chip con fondo oscuro alineado a la derecha
	var cost_chip := PanelContainer.new()
	cost_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.04, 0.05, 0.09, 0.85)
	chip_style.set_corner_radius_all(6)
	chip_style.set_border_width_all(1)
	chip_style.border_color = Color(0.30, 0.35, 0.50, 0.6)
	chip_style.content_margin_left = 8 * boost
	chip_style.content_margin_right = 8 * boost
	chip_style.content_margin_top = 3 * boost
	chip_style.content_margin_bottom = 3 * boost
	cost_chip.add_theme_stylebox_override("panel", chip_style)

	var cost_vbox := VBoxContainer.new()
	cost_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_vbox.add_theme_constant_override("separation", 0)
	cost_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_chip.add_child(cost_vbox)

	var pa_lbl := Label.new()
	pa_lbl.text = "%d PA" % pa_cost
	pa_lbl.add_theme_font_size_override("font_size", roundi(12 * boost))
	pa_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pa_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25))
	pa_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_vbox.add_child(pa_lbl)

	if mp_cost > 0:
		var mp_lbl := Label.new()
		mp_lbl.text = "%d MP" % mp_cost
		mp_lbl.add_theme_font_size_override("font_size", roundi(12 * boost))
		mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if GlobalState.mp < mp_cost:
			btn.disabled = true
			mp_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			mp_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
		cost_vbox.add_child(mp_lbl)

	hbox.add_child(cost_chip)

	return btn


static func make_empty_skill_card_grid4(view: ViewCombat) -> Button:
	# BOOST VERTICAL: mismo factor que `make_skill_card_grid4`, para que el
	# alto coincida con las tarjetas rellenas de la misma rejilla.
	var boost := 2.1 if not view._is_landscape else 1.0
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 56 * boost)
	btn.disabled = true
	btn.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = view._theme_color("panel_bg", Color(0.04, 0.03, 0.07, 0.35))
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = view._theme_color("border", Color(0.18, 0.12, 0.28, 0.4))
	btn.add_theme_stylebox_override("disabled", style)

	var lbl := Label.new()
	lbl.text = "— Vacío —"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", roundi(14 * boost))
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	btn.add_child(lbl)

	return btn


static func build_powers_grid(view: ViewCombat) -> void:
	var prof_id: String = String(GlobalState.profession)
	var active_skill_ids: Array[String] = GlobalState.get_active_combat_skills(prof_id)
	var all_prof_skills: Array = Design.get_profession_skills(prof_id)

	# Filtrar solo las habilidades activas (máx 4) que además estén desbloqueadas por nivel de trabajo
	var unlocked_active_skills: Array[Dictionary] = []
	for skill in all_prof_skills:
		var sid := String(skill.get("id", ""))
		var req_lvl: int = int(skill.get("level", 1))
		if active_skill_ids.has(sid) and (GlobalState.is_test_room or GlobalState.job_level >= req_lvl):
			unlocked_active_skills.append(skill)

	# Asegurar que _content_grid y el scroll permitan expandirse en vertical y horizontal
	if view._grid_scroll != null:
		view._grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		view._grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		view._grid_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	if view._content_grid is GridContainer:
		view._content_grid.columns = 2
		view._content_grid.add_theme_constant_override("h_separation", 8)
		view._content_grid.add_theme_constant_override("v_separation", 8)

	for skill in unlocked_active_skills:
		view._content_grid.add_child(make_skill_card_grid4(view, skill))

	# Garantizar siempre 4 ranuras fijas que ocupan todo el recuadro 2x2
	while view._content_grid.get_child_count() < 4:
		view._content_grid.add_child(make_empty_skill_card_grid4(view))


static func build_classes_grid(view: ViewCombat) -> void:
	var profs := GlobalState.unlocked_professions

	# En horizontal se apila verticalmente; en vertical sigue en fila horizontal.
	var use_v := view._is_landscape
	var box: BoxContainer = VBoxContainer.new() if use_v else HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	view._content_grid.add_child(box)

	if view._grid_scroll != null:
		view._grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if use_v else ScrollContainer.SCROLL_MODE_AUTO
		view._grid_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO if use_v else ScrollContainer.SCROLL_MODE_DISABLED

	# Usar el nombre canónico de la profesión ("Guerrero",
	# el mismo que usan quests/diálogos/`professions.json`), sin renombrarlo a
	# "Espadachín" (invento solo de esta pantalla, inconsistente con el resto
	# del juego).
	for prof in profs:
		var label := Locale.translate_profession(prof)

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		if use_v:
			btn.custom_minimum_size = Vector2(0, 72)
		else:
			btn.custom_minimum_size = Vector2(80, 0)
		btn.pressed.connect(func() -> void: enqueue_class_change(view, prof))
		btn.pressed.connect(func() -> void: UiKit.pop(btn, 1.05, 0.15))
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_contents = true

		var is_active := GlobalState.profession == prof
		var style := StyleBoxFlat.new()
		style.bg_color = view._theme_color("panel_glass", Color(0.14, 0.09, 0.26, 0.95)) if is_active else view._theme_color("panel_bg", view.COL_PANEL)
		style.set_corner_radius_all(14)
		style.set_border_width_all(3)
		style.border_color = view._theme_color("accent", Color(0.98, 0.80, 0.32)) if is_active else view._theme_color("border", Color(0.24, 0.16, 0.38, 0.8))
		style.shadow_color = view._theme_color("accent", Color(0.98, 0.80, 0.32, 0.35)) if is_active else Color(0, 0, 0, 0.2)
		style.shadow_size = 8 if is_active else 4
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		
		var style_hover := style.duplicate() as StyleBoxFlat
		style_hover.bg_color = style.bg_color.lightened(0.06)
		style_hover.border_color = view._theme_color("accent", Color(0.98, 0.80, 0.32))
		style_hover.shadow_color = view._theme_color("accent", Color(0.98, 0.80, 0.32, 0.45))
		style_hover.shadow_size = 10
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_hover)
		btn.add_theme_stylebox_override("focus", style_hover)

		btn.mouse_entered.connect(func() -> void:
			var tw := btn.create_tween().set_parallel(true)
			tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
		)
		btn.mouse_exited.connect(func() -> void:
			var tw := btn.create_tween().set_parallel(true)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 8)
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)

		# 1. Imagen / Icono de la profesión (grande arriba)
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var prof_img := get_prof_texture_path(prof)
		if ResourceLoader.exists(prof_img):
			icon_rect.texture = load(prof_img)

		var icon_frame := PanelContainer.new()
		var f_style := StyleBoxFlat.new()
		f_style.bg_color = view._theme_color("panel_bg", Color(0, 0, 0, 0.45))
		f_style.set_corner_radius_all(10)
		f_style.set_border_width_all(2)
		f_style.border_color = view._theme_color("accent", Color(0.98, 0.80, 0.32)) if is_active else view._theme_color("border", Color(0.28, 0.22, 0.42, 0.9))
		icon_frame.add_theme_stylebox_override("panel", f_style)
		icon_frame.custom_minimum_size = Vector2(74, 74)
		icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(icon_rect)
		vbox.add_child(icon_frame)

		# 2. Nombre de la profesión
		var name_lbl := Label.new()
		name_lbl.text = label
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", view._theme_color("accent", Color(0.98, 0.82, 0.32)) if is_active else view._theme_color("text", Color(0.95, 0.95, 0.98)))
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(name_lbl)

		# 3. Badge "ACTIVA" si es la profesión en uso
		if is_active:
			var active_lbl := Label.new()
			active_lbl.text = "ACTIVA"
			active_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			active_lbl.add_theme_font_size_override("font_size", 16)
			active_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
			vbox.add_child(active_lbl)

		box.add_child(btn)


## Encola un cambio de clase. CONSUME EL TURNO COMPLETO: ocupa todas las casillas de
## PA y no puede convivir con otras acciones. Se aplica al ejecutar la cola.
static func enqueue_class_change(view: ViewCombat, prof: String) -> void:
	if not view.is_combat_active or view._executing_queue:
		return
	if GlobalState.profession == prof:
		view.log_message("[color=orange]⚠️ Ya eres [b]%s[/b].[/color]" % prof)
		return
	# El cambio de clase SACRIFICA el turno completo: no puede convivir con otras
	# acciones en la cola. Si hay algo encolado, se rechaza con un aviso claro.
	if not view.combat_queue.is_empty():
		view.log_message("[color=orange]⚠️ El cambio de clase ocupa todo el turno. Vacía la cola antes de encolarlo.[/color]")
		return
	# Ocupa TODAS las casillas de PA disponibles este turno (feedback: turno sacrificado).
	var full_turn_pa := view._get_max_queue_slots()
	var skill_entry := {
		"id": "class_change_%s" % prof.to_lower().replace(" ", "_"),
		"name": "👑 Cambiar a %s" % prof,
		"type": "class_change",
		"profession": prof,
		"pa": full_turn_pa,
		"icon": "👑",
		"cost": 0,
		"full_turn": true,
	}
	AudioManager.play_sfx("click")
	view.combat_queue.append(skill_entry)
	view._recount_queued_pa()
	view.update_queue_ui_elements()
	view.log_message("[color=cyan]👑 Cambio de clase a [b]%s[/b] encolado: consume el turno para preparar el siguiente.[/color]" % skill_entry.name)


static func change_class_during_combat(view: ViewCombat, prof: String) -> void:
	if GlobalState.profession == prof:
		return
	AudioManager.play_sfx("click")
	GlobalState.set_profession(prof)

	# El perfil de bloqueo activo depende de la profesión.
	view._block_profile = GameConfig.block_profile(prof)
	view._update_defense_ring_geometry()

	# Al cambiar de clase, la cola pendiente puede tener PA/tags inválidos: se vacía.
	view.combat_queue.clear()
	view.queued_pa = 0
	# Recalcular el límite de PA del turno para la NUEVA
	# profesión — sin esto quedaba cacheado el de la profesión anterior (p.ej.
	# 1 PA de "Don Nadie") hasta el siguiente turno, bloqueando de más.
	view.current_pa_limit = view._get_max_queue_slots()
	view.update_queue_ui_elements()
	
	# Sincronizar TopHUD
	view._lbl_class.text = prof.to_upper()
	
	# Loguear cambio de clase
	view.log_message("[color=yellow]👑 Cambiaste tu clase a [b]%s[/b] en combate.[/color]" % prof)
	
	# Redirigir automáticamente a la pestaña de poderes
	view._active_tab = "powers"
	refresh_tab_highlight(view)
	view._load_portrait_texture()
	build_tab_grid(view)


static func build_bag_grid(view: ViewCombat) -> void:
	var consumables: Array = []
	for item in GlobalState.inventory:
		# Faltaba comprobar el flag "usable" del
		# CATÁLOGO (items.json vía `Design.get_item`, no la entrada de
		# inventario — esta última nunca guarda "usable") — ítems como la
		# bomba de colocación (`category: "consumable", usable: false`,
		# pensada para el mapamundi, no para combate) se colaban aquí sin
		# tener icono de habilidad de combate dedicado, apareciendo como un
		# "ítem fantasma" sin icono.
		if item.get("category", "") != "consumable":
			continue
		var item_def: Dictionary = Design.get_item(str(item.get("id", "")))
		if not bool(item_def.get("usable", true)):
			continue
		consumables.append(item)

	if consumables.is_empty():
		var label := Label.new()
		label.text = "No tienes pociones."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.GRAY)
		view._content_grid.add_child(label)
		return

	if view._content_grid is GridContainer:
		view._content_grid.columns = 1
		view._content_grid.add_theme_constant_override("h_separation", 8)
		view._content_grid.add_theme_constant_override("v_separation", 8)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	view._content_grid.add_child(box)

	if view._grid_scroll != null:
		view._grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		view._grid_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
		view._grid_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	var boost := 1.8 if not view._is_landscape else 1.0

	for item in consumables:
		var it_name = item.get("name", "")
		var it_name_str: String = Locale.pick(it_name) if it_name is Dictionary else str(it_name)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size   = Vector2(0, int(56 * boost))
		btn.pressed.connect(func() -> void: on_potion_pressed(view, item))
		btn.pressed.connect(func() -> void: UiKit.pop(btn, 1.05, 0.15))
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_contents = true

		var style := StyleBoxFlat.new()
		style.bg_color = view._theme_color("item", Color(0.04, 0.14, 0.08, 0.95))
		style.set_corner_radius_all(14)
		style.set_border_width_all(3)
		style.border_color = view._theme_color("item", Color(0.2, 0.55, 0.3, 0.8))
		style.shadow_color = view._theme_color("item", Color(0.2, 0.55, 0.3, 0.25))
		style.shadow_size = 8
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		
		var style_hover := style.duplicate() as StyleBoxFlat
		style_hover.bg_color = style.bg_color.lightened(0.06)
		style_hover.border_color = view._theme_color("accent", Color(0.98, 0.80, 0.32)) # Borde dorado JRPG
		style_hover.shadow_color = view._theme_color("accent", Color(0.98, 0.80, 0.32, 0.45))
		style_hover.shadow_size = 10
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_hover)
		btn.add_theme_stylebox_override("focus", style_hover)

		btn.mouse_entered.connect(func() -> void:
			var tw := btn.create_tween().set_parallel(true)
			tw.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.1)
		)
		btn.mouse_exited.connect(func() -> void:
			var tw := btn.create_tween().set_parallel(true)
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		)

		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		hbox.add_theme_constant_override("separation", 12)
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hbox)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var item_id := str(item.get("id", ""))
		var img_path := "res://assets/combat/skills/item_%s.png" % item_id
		var icon_fallback_lbl: Label = null
		if ResourceLoader.exists(img_path):
			icon_rect.texture = load(img_path)
		else:
			# Sin PNG dedicado de combate: usar el propio icono/emoji del
			# ítem (items.json) en vez de dejar el marco vacío/"sin icono".
			icon_rect.visible = false
			icon_fallback_lbl = Label.new()
			icon_fallback_lbl.text = str(item.get("icon", "❓"))
			icon_fallback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_fallback_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_fallback_lbl.add_theme_font_size_override("font_size", 28)
			icon_fallback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon_frame := PanelContainer.new()
		var f_style := StyleBoxFlat.new()
		f_style.bg_color = view._theme_color("panel_bg", Color(0, 0, 0, 0.4))
		f_style.set_corner_radius_all(8)
		f_style.set_border_width_all(2)
		f_style.border_color = view._theme_color("item", Color(0.2, 0.55, 0.3, 0.9))
		icon_frame.add_theme_stylebox_override("panel", f_style)
		icon_frame.custom_minimum_size = Vector2(48, 48)
		icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(icon_rect)
		if icon_fallback_lbl != null:
			icon_frame.add_child(icon_fallback_lbl)
		hbox.add_child(icon_frame)

		var text_vbox := VBoxContainer.new()
		text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(text_vbox)

		var name_lbl := Label.new()
		name_lbl.text = it_name_str
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", view._theme_color("text", Color(0.95, 0.95, 0.98)))
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text_vbox.add_child(name_lbl)

		var qty_lbl := Label.new()
		qty_lbl.text = "x%d en bolsa" % int(item.get("quantity", 0))
		qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		qty_lbl.add_theme_font_size_override("font_size", 14)
		qty_lbl.add_theme_color_override("font_color", view._theme_color("accent", Color(0.65, 0.95, 0.70)))
		text_vbox.add_child(qty_lbl)

		box.add_child(btn)


static func on_potion_pressed(view: ViewCombat, item: Dictionary) -> void:
	if not view.is_combat_active:
		return
	if view.combat_queue.size() >= view._get_max_queue_slots():
		view.log_message("[color=orange]⚠️ Cola llena.[/color]")
		return
		
	# Verificar si quedan
	if not GlobalState.has_item(item["id"], 1):
		view.log_message("[color=orange]⚠️ No te quedan pociones de ese tipo.[/color]")
		return

	var potion_action = {
		"name": item["name"],
		"icon": item["icon"],
		"cost": 0,
		"type": "potion",
		"item_id": item["id"]
	}
	view._on_skill_pressed(potion_action)


static func use_potion_action(view: ViewCombat, skill: Dictionary) -> void:
	var item_id: String = skill["item_id"]
	if not GlobalState.has_item(item_id, 1):
		view.log_message("[color=orange]⚠️ Intentaste usar %s pero ya no te quedan.[/color]" % skill["name"])
		return

	# Consumir el item del inventario global
	GlobalState.remove_item(item_id, 1)

	var item_def: Dictionary = Design.get_item(item_id)
	var heal_hp: int = int(item_def.get("hp_heal", 40))
	var heal_mp: int = int(item_def.get("mp_heal", 40))
	
	AudioManager.play_sfx("heal")
	if item_id == "potion" or heal_hp > 0:
		GlobalState.hp = min(GlobalState.hp + heal_hp, GlobalState.max_hp)
		var hero_anchor: Control = view._hero_sprite_rect if (view._hero_sprite_rect != null and is_instance_valid(view._hero_sprite_rect)) else (view._lbl_player_hp if view._lbl_player_hp != null else view._hero_status_dock)
		CombatFx.spawn_word(view, view._damage_popups_node, "+%d HP" % heal_hp, UiKit.GOOD, hero_anchor, "💚", 44)
		view.log_message("[color=lime]🧪 Usas %s → +%d HP recuperados[/color]" % [skill["name"], heal_hp])
	else:
		GlobalState.mp = min(GlobalState.mp + heal_mp, GlobalState.max_mp)
		var hero_anchor: Control = view._hero_sprite_rect if (view._hero_sprite_rect != null and is_instance_valid(view._hero_sprite_rect)) else (view._lbl_player_mp if view._lbl_player_mp != null else view._hero_status_dock)
		CombatFx.spawn_word(view, view._damage_popups_node, "+%d MP" % heal_mp, Color(0.25, 0.75, 1.0), hero_anchor, "💧", 44)
		view.log_message("[color=cyan]🧪 Usas %s → +%d MP recuperados[/color]" % [skill["name"], heal_mp])

	view._update_player_bars()
	
	# Actualizar bolsa si está activa.
	# Llamaba a `build_bag_grid()` directamente
	# sin vaciar antes `_content_grid` (a diferencia de `build_tab_grid()`, que
	# sí lo hace) — cada poción usada AÑADÍA una fila nueva de botones encima
	# de la anterior en vez de sustituirla, así que la lista iba acumulando
	# "pociones fantasma" duplicadas con cada uso.
	if view._active_tab == "bag":
		for child in view._content_grid.get_children():
			view._content_grid.remove_child(child)
			child.queue_free()
		build_bag_grid(view)
