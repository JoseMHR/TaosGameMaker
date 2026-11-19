# ViewGather.gd
# Vista de recolección / farmeo (bosque, mina, río).
# Muestra un fondo temático, un mensaje "Has encontrado un lugar para…" y una
# zona central que, al tocarla repetidamente, genera recursos y XP de habilidad.
# Cada toque produce un efecto flotante "+1 recurso" y actualiza la barra de XP.
class_name ViewGather
extends Control

# La casilla trae su `resource`; sus datos (oficio, ítem, icono, capacidad, textos)
# se resuelven con Design.resolve_gather_resource() — editable sin código en
# `data/world_resources/<code>.json`, con GameConfig.RESOURCE_TYPES
# como valor de respaldo. Los parámetros de farmeo, en GameConfig.

# ─── ESTADO ───────────────────────────────────────────────────────────────────
var _skill: String = "lenador"
var _res_id: String = "forest"        # Recurso de la casilla (RESOURCE_TYPES)
var _res: Dictionary = {}             # Info resuelta del recurso (item/icono/nombre/skill)
var _gathered: int = 0
var _biome: Color = Color("0d3b20")
var _last_gather_time_msec: int = 0
var _coord: Vector2i = Vector2i.ZERO   # Casilla actual (clave del nodo finito)
var _cell_data: Dictionary = {}

# ─── REFERENCIAS UI (construidas por código) ──────────────────────────────────
var _bg: ColorRect
var _bg_texture: TextureRect
var _lbl_name: Label
var _lbl_icon: Label
var _lbl_found: Label
var _lbl_hint: Label
var _lbl_total: Label
var _lbl_skill: Label
var _lbl_owned: Label
var _lbl_bonus: Label
var _bar: ProgressBar
var _node_bar: ProgressBar
var _lbl_node: Label
var _btn_leave: Button
var _fx_layer: Control
var _tap_area: Panel
var _idle_timer: Timer
var _vbox: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	Locale.locale_changed.connect(_refresh_texts)


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════
## Resuelve la info del recurso de la casilla (Design.resolve_gather_resource) con
## fallback por oficio.
func _resolve_res(cell_data: Dictionary) -> Dictionary:
	var rid := String(cell_data.get("resource", ""))
	var info := Design.resolve_gather_resource(rid)
	if not info.is_empty():
		return info
	# Compatibilidad: derivar desde el oficio (required_skill) si no hay resource.
	var sk := String(cell_data.get("required_skill", "lenador"))
	if not GameConfig.GATHER_RESOURCES.has(sk):
		sk = "lenador"
	var g: Dictionary = GameConfig.GATHER_RESOURCES[sk]
	return {"skill": sk, "item": g["id"], "item_loc": g["loc"], "icon": g["icon"], "category": g["category"], "found_loc": "gather_found_" + sk}


func setup(cell_data: Dictionary) -> void:
	# Modelo nuevo: el recurso de la casilla determina oficio, ítem, icono y textos.
	_res_id = String(cell_data.get("resource", ""))
	_res = _resolve_res(cell_data)
	_skill = String(_res.get("skill", "lenador"))
	_biome = cell_data.get("biome_color", _biome)
	_coord = cell_data.get("coord", Vector2i.ZERO)
	_gathered = 0
	if _bg:
		_bg.color = _biome.darkened(0.35)
		
	var bg_tex: Texture2D = UiKit.load_texture_safe("res://assets/vn/bg/bg_gather_%s.png" % _skill)
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/common/ui/bg_default.png")
	if _bg_texture and bg_tex:
		_bg_texture.texture = bg_tex
		
	_cell_data = cell_data
	var gname = cell_data.get("name_i18n", null)
	if gname is Dictionary and not gname.is_empty():
		_lbl_name.text = Locale.pick(gname)
	else:
		_lbl_name.text = Locale.translate_cell_name(String(cell_data.get("name", "")))
	_lbl_icon.text = String(_res.get("icon", "📦"))
	_refresh_texts()
	_refresh_node()
	_refresh_skill_bar()
	# Arrancar la recolección automática (idle) tras el revelado de fondo.
	if _idle_timer:
		_idle_timer.stop()
		
	if _vbox:
		_vbox.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(1.2)
		t.tween_callback(func() -> void:
			var f_tween := create_tween()
			f_tween.tween_property(_vbox, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			if _idle_timer:
				_idle_timer.start(GameConfig.GATHER_IDLE_INTERVAL / GlobalState.gather_speed_multiplier(_skill))
		)


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = _biome.darkened(0.35)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_bg_texture = TextureRect.new()
	_bg_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_texture)

	# Viñeta superior translúcida para dar profundidad.
	var vignette := ColorRect.new()
	vignette.color = Color(0, 0, 0, 0.35)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vignette)

	_vbox = VBoxContainer.new()
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vbox.add_theme_constant_override("separation", 0)
	add_child(_vbox)
	var vbox := _vbox

	# ── Cabecera ───────────────────────────────────────────────────────────────
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", UiKit.header(0.85))
	vbox.add_child(header)
	var hm := UiKit.margins(18, 18, 14, 14)
	header.add_child(hm)
	var hbox := HBoxContainer.new()
	hm.add_child(hbox)
	_lbl_name = Label.new()
	_lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_name.add_theme_font_size_override("font_size", 26)
	_lbl_name.add_theme_color_override("font_color", UiKit.TEXT)
	UiKit.apply_heading(_lbl_name)
	_lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_lbl_name)
	# Indicador contextual: cuánto de este recurso llevas ya en la bolsa.
	var owned_chip := PanelContainer.new()
	owned_chip.add_theme_stylebox_override("panel", UiKit.chip())
	owned_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ocm := UiKit.margins(12, 12, 6, 6)
	owned_chip.add_child(ocm)
	_lbl_owned = Label.new()
	_lbl_owned.add_theme_font_size_override("font_size", 20)
	_lbl_owned.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	ocm.add_child(_lbl_owned)
	hbox.add_child(owned_chip)

	_btn_leave = Button.new()
	_btn_leave.add_theme_font_size_override("font_size", 18)
	_btn_leave.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		SceneManager.go_to_world()
	)
	hbox.add_child(_btn_leave)

	# ── Zona central tappable ──────────────────────────────────────────────────
	_tap_area = Panel.new()
	_tap_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tap_area.add_theme_stylebox_override("panel", UiKit.empty())
	_tap_area.gui_input.connect(_on_tap_input)
	vbox.add_child(_tap_area)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap_area.add_child(center)

	var cbox := VBoxContainer.new()
	cbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cbox.add_theme_constant_override("separation", 18)
	cbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(cbox)

	_lbl_icon = Label.new()
	_lbl_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_icon.add_theme_font_size_override("font_size", 130)
	_lbl_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cbox.add_child(_lbl_icon)
	_pulse(_lbl_icon)

	_lbl_found = Label.new()
	_lbl_found.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_found.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_found.add_theme_font_size_override("font_size", 26)
	_lbl_found.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	_lbl_found.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cbox.add_child(_lbl_found)

	_lbl_hint = Label.new()
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_hint.add_theme_font_size_override("font_size", 20)
	_lbl_hint.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	_lbl_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cbox.add_child(_lbl_hint)

	# ── Pie: barra de habilidad + total ────────────────────────────────────────
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel", UiKit.header(0.92, false))
	vbox.add_child(footer)
	var fm := UiKit.margins(22, 22, 14, 22)
	footer.add_child(fm)
	var fbox := VBoxContainer.new()
	fbox.add_theme_constant_override("separation", 8)
	fm.add_child(fbox)

	# Reserva del nodo finito (cuánto queda por recolectar en esta casilla)
	_lbl_node = Label.new()
	_lbl_node.add_theme_font_size_override("font_size", 18)
	_lbl_node.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	fbox.add_child(_lbl_node)
	_node_bar = ProgressBar.new()
	_node_bar.show_percentage = false
	_node_bar.custom_minimum_size = Vector2(0, 14)
	_node_bar.add_theme_stylebox_override("background", UiKit.bar_bg(7))
	fbox.add_child(_node_bar)

	var frow := HBoxContainer.new()
	fbox.add_child(frow)
	_lbl_skill = Label.new()
	_lbl_skill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_skill.add_theme_font_size_override("font_size", 20)
	frow.add_child(_lbl_skill)
	_lbl_total = Label.new()
	_lbl_total.add_theme_font_size_override("font_size", 20)
	_lbl_total.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	frow.add_child(_lbl_total)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.add_theme_stylebox_override("fill", UiKit.bar_fill(UiKit.GOOD, 8))
	_bar.add_theme_stylebox_override("background", UiKit.bar_bg(8))
	fbox.add_child(_bar)

	# Feedback PASIVO de los bonos activos del oficio (velocidad/cantidad), para
	# que el jugador note en todo momento el efecto de subir de nivel (antes era
	# invisible: task_arreglosPendientes.md §1).
	_lbl_bonus = Label.new()
	_lbl_bonus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_bonus.add_theme_font_size_override("font_size", 15)
	_lbl_bonus.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	fbox.add_child(_lbl_bonus)

	# ── Capa de efectos flotantes ───────────────────────────────────────────────
	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

	# ── Temporizador de recolección automática (idle) ───────────────────────────
	_idle_timer = Timer.new()
	_idle_timer.one_shot = false
	_idle_timer.wait_time = GameConfig.GATHER_IDLE_INTERVAL
	_idle_timer.timeout.connect(_on_idle_tick)
	add_child(_idle_timer)


# ══════════════════════════════════════════════════════════════════════════════
# INTERACCIÓN: RECOLECTAR
# ══════════════════════════════════════════════════════════════════════════════
func _on_tap_input(event: InputEvent) -> void:
	var tapped := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
		at = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped = true
		at = event.position
	if tapped:
		_gather(at)


func _gather(at: Vector2) -> void:
	var now := Time.get_ticks_msec()
	var cooldown_ms: int = int(GameConfig.GATHER_TAP_COOLDOWN_MS / GlobalState.gather_speed_multiplier(_skill))
	if now - _last_gather_time_msec < cooldown_ms:
		return
	_last_gather_time_msec = now

	var per_tap: int = GameConfig.GATHER_AMOUNT_PER_TAP * GlobalState.gather_amount_multiplier(_skill)
	var taken: int = GlobalState.consume_gather(_coord, per_tap)
	if taken <= 0:
		# Nodo agotado: nada que extraer hasta que se regenere.
		_spawn_float(Locale.t("gather_depleted"), at, UiKit.HP)
		_refresh_node()
		return

	AudioManager.play_sfx("gather")
	# Al tocar manualmente reiniciamos el contador idle ("si no tocas nada…"),
	# ya con el intervalo acelerado por el nivel de este oficio.
	if _idle_timer:
		_idle_timer.start(GameConfig.GATHER_IDLE_INTERVAL / GlobalState.gather_speed_multiplier(_skill))
	_apply_gather(taken, at, false)


## Recolección automática (idle): se dispara si el jugador no toca nada.
func _on_idle_tick() -> void:
	if not is_visible_in_tree():
		return
	var idle_amount: int = GameConfig.GATHER_IDLE_AMOUNT * GlobalState.gather_amount_multiplier(_skill)
	var taken: int = GlobalState.consume_gather(_coord, idle_amount)
	if taken <= 0:
		_refresh_node()
		return
	var at: Vector2 = _fx_layer.size * Vector2(0.5, 0.42)
	_apply_gather(taken, at, true)


## Aplica la recolección de 'amount' unidades (manual o automática) y refresca UI.
func _apply_gather(amount: int, at: Vector2, is_auto: bool) -> void:
	var item_id: String = String(_res.get("item", "wood"))
	var res_name: String = Locale.t(String(_res.get("item_loc", "res_wood")))
	var icon: String = String(_res.get("icon", "📦"))
	GlobalState.add_item(item_id, amount, res_name, String(_res.get("category", "other")), icon)
	GlobalState.discover_resource(item_id)  # Desbloquea construcciones de la base
	GlobalState.report_gather(item_id, amount)  # Progreso de encargos del tablón
	_gathered += amount
	var leveled: bool = GlobalState.add_skill_xp(_skill, GameConfig.GATHER_XP_PER_TAP)
	var col: Color = UiKit.XP if is_auto else UiKit.GOOD
	var prefix: String = "💤 " if is_auto else ""
	_spawn_float("%s%s %s" % [prefix, icon, Locale.t("gather_got", [res_name])], at, col)
	if leveled:
		_spawn_float(Locale.t("gather_skill_up", [Locale.t("skill_" + _skill), GlobalState.skills[_skill]["level"]]), at + Vector2(0, -60), UiKit.ACCENT_SOFT)
	_refresh_node()
	_refresh_skill_bar()
	SaveManager.request_autosave()


## Refresca la barra de reserva del nodo finito y el estado agotado.
func _refresh_node() -> void:
	if _node_bar == null:
		return
	var cap: int = GlobalState.get_gather_capacity(_coord)
	var remaining: int = GlobalState.get_gather_remaining(_coord)
	_node_bar.max_value = cap
	_node_bar.value = remaining
	var ratio: float = float(remaining) / float(maxi(1, cap))
	var col: Color = UiKit.GOOD
	if ratio <= 0.2:
		col = UiKit.BAD
	elif ratio <= 0.5:
		col = UiKit.WARN
	_node_bar.add_theme_stylebox_override("fill", UiKit.bar_fill(col, 7))
	if remaining <= 0:
		_lbl_node.text = Locale.t("gather_depleted")
		_lbl_node.add_theme_color_override("font_color", UiKit.HP)
		if _lbl_icon:
			_lbl_icon.modulate = Color(1, 1, 1, 0.30)
		if _lbl_hint:
			_lbl_hint.text = Locale.t("gather_depleted_hint")
	else:
		_lbl_node.text = Locale.t("gather_node", [remaining, cap])
		_lbl_node.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		if _lbl_icon:
			_lbl_icon.modulate = Color(1, 1, 1, 1)
		if _lbl_hint:
			_lbl_hint.text = Locale.t("gather_tap")


func _spawn_float(text: String, at: Vector2, col: Color = UiKit.GOOD) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = at - Vector2(40, 20)
	_fx_layer.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 140.0, 1.0).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.2)
	tw.finished.connect(lbl.queue_free)


# ══════════════════════════════════════════════════════════════════════════════
# REFRESCOS
# ══════════════════════════════════════════════════════════════════════════════
func _refresh_texts() -> void:
	if _lbl_name != null and not _cell_data.is_empty():
		var gname = _cell_data.get("name_i18n", null)
		if gname is Dictionary and not gname.is_empty():
			_lbl_name.text = Locale.pick(gname)
		else:
			_lbl_name.text = Locale.translate_cell_name(String(_cell_data.get("name", "")))
	_btn_leave.text = Locale.t("gather_leave")
	_lbl_found.text = Locale.t(String(_res.get("found_loc", "gather_found_" + _skill)))
	_lbl_hint.text  = Locale.t("gather_tap")
	_lbl_total.text = Locale.t("gather_total", [_gathered])
	_refresh_skill_bar()
	_refresh_node()


func _refresh_skill_bar() -> void:
	var s: Dictionary = GlobalState.skills.get(_skill, {"level": 1, "xp": 0, "xp_needed": 50})
	var r_icon: String = String(_res.get("icon", "📦"))
	_lbl_skill.text = "%s  %s" % [r_icon, Locale.t("skill_level", [s["level"], s["xp"], s["xp_needed"]])]
	_lbl_total.text = Locale.t("gather_total", [_gathered])
	_bar.max_value = s["xp_needed"]
	_bar.value = s["xp"]
	# Total de este recurso en la bolsa (indicador contextual de cabecera).
	if _lbl_owned:
		var owned: int = int(GlobalState.get_item(String(_res.get("item", "wood"))).get("quantity", 0))
		_lbl_owned.text = "%s %d" % [r_icon, owned]
	_refresh_bonus_chip()


## Chip pasivo con los bonos ACTIVOS del oficio en este momento (velocidad y
## cantidad por recolección), para que se note siempre el efecto del nivel.
func _refresh_bonus_chip() -> void:
	if _lbl_bonus == null:
		return
	var speed_mult: float = GlobalState.gather_speed_multiplier(_skill)
	var amount_mult: int = GlobalState.gather_amount_multiplier(_skill)
	var speed_pct: int = int(round((speed_mult - 1.0) * 100.0))
	var parts: Array[String] = []
	if amount_mult > 1:
		parts.append("x%d" % amount_mult)
	if speed_pct > 0:
		parts.append(Locale.pick({"es": "velocidad +%d%%" % speed_pct, "en": "speed +%d%%" % speed_pct}))
	if parts.is_empty():
		_lbl_bonus.text = Locale.pick({
			"es": "Sube de nivel para desbloquear bonos de recolección.",
			"en": "Level up to unlock gathering bonuses."})
	else:
		_lbl_bonus.text = "⛏️ " + " · ".join(parts)


# ══════════════════════════════════════════════════════════════════════════════
# HELPERS DE ESTILO / ANIMACIÓN
# ══════════════════════════════════════════════════════════════════════════════
func _pulse(node: Control) -> void:
	node.pivot_offset = Vector2(65, 65)
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2(1.08, 1.08), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
