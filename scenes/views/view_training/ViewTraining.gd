# ViewTraining.gd
# Vista del Muñeco de Entrenamiento (se abre desde la Base cuando el muñeco está
# construido). Un único botón "Entrenar" otorga de golpe tanta experiencia como
# el NIVEL de la Base al nivel base del héroe Y a TODAS sus profesiones
# desbloqueadas (ver GlobalState.add_xp_to_all_jobs y task4.md) — muy útil para
# arrancar rápido una profesión recién desbloqueada.
class_name ViewTraining
extends Control

# ─── REFERENCIAS UI (construidas por código) ──────────────────────────────────
var _title_lbl: Label
var _hint_lbl: Label
var _idle_lbl: Label
var _level_lbl: Label
var _bar: ProgressBar
var _btn_leave: Button
var _btn_train: Button
var _dummy_icon: Label
var _tap_area: Panel
var _fx_layer: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GlobalState.state_updated.connect(_on_state_updated)
	Locale.locale_changed.connect(_refresh_texts)
	visibility_changed.connect(_on_visibility_changed)


func _on_state_updated() -> void:
	if is_visible_in_tree():
		_refresh_footer()


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.BG_DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	# Cabecera
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", UiKit.header())
	vbox.add_child(header)
	var hm := UiKit.margins(18, 18, 14, 14)
	header.add_child(hm)
	var hbox := HBoxContainer.new()
	hm.add_child(hbox)
	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 26)
	_title_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	UiKit.apply_heading(_title_lbl)
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_title_lbl)
	_btn_leave = Button.new()
	_btn_leave.add_theme_font_size_override("font_size", 18)
	_btn_leave.pressed.connect(func() -> void: SceneManager.go_to_world())
	hbox.add_child(_btn_leave)

	# Zona central (ya no es táctil: el toque directo al muñeco daba pie a
	# spam-clicking; una sola acción explícita es más clara y evita el abuso).
	_tap_area = Panel.new()
	_tap_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tap_area.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	vbox.add_child(_tap_area)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap_area.add_child(center)

	var cbox := VBoxContainer.new()
	cbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cbox.add_theme_constant_override("separation", 16)
	cbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(cbox)

	_dummy_icon = Label.new()
	_dummy_icon.text = "🎯"
	_dummy_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dummy_icon.add_theme_font_size_override("font_size", 150)
	_dummy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cbox.add_child(_dummy_icon)
	_pulse(_dummy_icon)

	_hint_lbl = Label.new()
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_lbl.add_theme_font_size_override("font_size", 22)
	_hint_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cbox.add_child(_hint_lbl)

	_idle_lbl = Label.new()
	_idle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idle_lbl.add_theme_font_size_override("font_size", 18)
	_idle_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	_idle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cbox.add_child(_idle_lbl)

	_btn_train = Button.new()
	_btn_train.custom_minimum_size = Vector2(220, 72)
	_btn_train.add_theme_font_size_override("font_size", 24)
	for st in ["normal", "hover", "pressed", "focus"]:
		_btn_train.add_theme_stylebox_override(st, UiKit.button_primary(14))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_btn_train.add_theme_color_override(col, UiKit.BG_DEEP)
	_btn_train.pressed.connect(_on_train_pressed)
	cbox.add_child(_btn_train)

	# Pie: nivel de héroe + barra de XP
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", UiKit.header(0.92, false))
	vbox.add_child(footer)
	var fm := UiKit.margins(22, 22, 14, 22)
	footer.add_child(fm)
	var fbox := VBoxContainer.new()
	fbox.add_theme_constant_override("separation", 8)
	fm.add_child(fbox)
	_level_lbl = Label.new()
	_level_lbl.add_theme_font_size_override("font_size", 20)
	fbox.add_child(_level_lbl)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 16)
	UiKit.style_progress(_bar, UiKit.XP, 8)
	fbox.add_child(_bar)

	# Capa de efectos flotantes
	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

	_refresh_texts()
	_refresh_footer()


# ══════════════════════════════════════════════════════════════════════════════
# VISIBILIDAD
# ══════════════════════════════════════════════════════════════════════════════
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh_footer()


# ══════════════════════════════════════════════════════════════════════════════
# INTERACCIÓN — un único botón: +camp_level de XP a la base y a cada profesión.
# ══════════════════════════════════════════════════════════════════════════════
func _on_train_pressed() -> void:
	var amount: int = maxi(1, GlobalState.camp_level)
	GlobalState.add_xp_to_all_jobs(amount)
	var at := size * 0.5 + Vector2(randf_range(-40, 40), -60)
	_spawn_float(Locale.t("train_gain", [amount]), at, UiKit.XP)
	_hit_shake()
	SaveManager.request_autosave()


# ══════════════════════════════════════════════════════════════════════════════
# REFRESCOS
# ══════════════════════════════════════════════════════════════════════════════
func _refresh_texts() -> void:
	if _title_lbl == null:
		return
	_title_lbl.text = Locale.t("train_title")
	_hint_lbl.text = Locale.t("train_tap")
	_idle_lbl.text = Locale.t("train_idle", [maxi(1, GlobalState.camp_level)])
	_btn_train.text = Locale.t("train_button")
	_btn_leave.text = Locale.t("train_leave")
	_refresh_footer()


func _refresh_footer() -> void:
	if _level_lbl == null:
		return
	_level_lbl.text = "%s     %s" % [Locale.t("hud_level", [GlobalState.level]), Locale.t("char_exp", [GlobalState.xp, GlobalState.xp_needed])]
	_bar.max_value = GlobalState.xp_needed
	_bar.value = GlobalState.xp


# ══════════════════════════════════════════════════════════════════════════════
# EFECTOS
# ══════════════════════════════════════════════════════════════════════════════
func _spawn_float(text: String, at: Vector2, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = at - Vector2(30, 20)
	_fx_layer.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 140.0, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.2)
	tw.finished.connect(lbl.queue_free)


func _hit_shake() -> void:
	var tw := create_tween()
	_dummy_icon.pivot_offset = _dummy_icon.size * 0.5
	tw.tween_property(_dummy_icon, "rotation", deg_to_rad(6), 0.05)
	tw.tween_property(_dummy_icon, "rotation", deg_to_rad(-6), 0.08)
	tw.tween_property(_dummy_icon, "rotation", 0.0, 0.05)


func _pulse(node: Control) -> void:
	node.pivot_offset = Vector2(75, 75)
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2(1.06, 1.06), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE)
