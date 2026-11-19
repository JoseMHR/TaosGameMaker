# TabEquip.gd
# Pestaña de Equipo del Hub de Personaje — Diseño en 2 columnas:
# - Mitad izquierda: 6 ranuras equipadas (Casco, Arma, Escudo, Armadura, Zapatos, Accesorio)
# - Mitad derecha: Lista scrolleable de alternativas equipables para la ranura seleccionada
class_name TabEquip
extends Control

var _active_equip_slot: String = "weapon"
var _left_slots_host: VBoxContainer = null
var _right_header_host: VBoxContainer = null
var _right_options_host: VBoxContainer = null
var _dirty: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GlobalState.state_updated.connect(_refresh)
	Locale.locale_changed.connect(_refresh)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree() and _dirty:
			_refresh()
	)


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var margin := UiKit.margins(12, 12, 12, 12)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var split_hbox := HBoxContainer.new()
	split_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 16)
	margin.add_child(split_hbox)

	# ── Mitad Izquierda (40% ancho): 6 Ranuras de equipamiento ──
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.0
	left_vbox.add_theme_constant_override("separation", 10)
	split_hbox.add_child(left_vbox)

	left_vbox.add_child(UiKit.section_header("🛡️  " + Locale.t("char_equip"), 20))

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enable_drag_scroll(left_scroll)
	left_vbox.add_child(left_scroll)

	_left_slots_host = VBoxContainer.new()
	_left_slots_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_slots_host.add_theme_constant_override("separation", 8)
	left_scroll.add_child(_left_slots_host)

	# Separador vertical
	var v_sep := VSeparator.new()
	split_hbox.add_child(v_sep)

	# ── Mitad Derecha (60% ancho): Alternativas equipables ──
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.45
	right_vbox.add_theme_constant_override("separation", 10)
	split_hbox.add_child(right_vbox)

	_right_header_host = VBoxContainer.new()
	_right_header_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_right_header_host)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enable_drag_scroll(right_scroll)
	right_vbox.add_child(right_scroll)

	_right_options_host = VBoxContainer.new()
	_right_options_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_options_host.add_theme_constant_override("separation", 10)
	right_scroll.add_child(_right_options_host)

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
	if _left_slots_host == null or _right_options_host == null:
		return

	# Limpiar contenedores
	for c in _left_slots_host.get_children():
		c.queue_free()
	for c in _right_header_host.get_children():
		c.queue_free()
	for c in _right_options_host.get_children():
		c.queue_free()

	# 1. Construir las 6 ranuras a la izquierda
	for slot in _equip_slots():
		_left_slots_host.add_child(_make_slot_button(slot))

	# 2. Construir la cabecera y opciones a la derecha
	if _active_equip_slot == "":
		_right_header_host.add_child(UiKit.section_header("🔁  " + Locale.t("equip_choose_slot"), 19))
		var hint := Label.new()
		hint.text = Locale.pick({
			"es": "👈 Selecciona una ranura a la izquierda para ver el equipamiento disponible.",
			"en": "👈 Select a slot on the left to see available equipment."
		})
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 16)
		hint.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		_right_options_host.add_child(hint)
		return

	var slot_title: String = Locale.t("equip_" + _active_equip_slot)
	_right_header_host.add_child(UiKit.section_header("🔁  " + Locale.t("equip_available", [slot_title]), 19))
	_build_equip_alternatives(_right_options_host, _active_equip_slot)


func _equip_slots() -> Array[Dictionary]:
	return [
		{"key": "helmet", "icon": "🪖"},
		{"key": "weapon", "icon": "🗡️"},
		{"key": "shield", "icon": "🛡️"},
		{"key": "armor", "icon": "👕"},
		{"key": "shoes", "icon": "🥾"},
		{"key": "accessory", "icon": "💍"},
	]


## Botón compacto de ranura izquierda con iconos grandes y claros.
func _make_slot_button(slot: Dictionary) -> Button:
	var slot_key: String = slot["key"]
	var item: EquipmentResource = GlobalState.equipped.get(slot_key)
	var selected: bool = _active_equip_slot == slot_key
	var slot_label: String = Locale.t("equip_" + slot_key)

	var base_col: Color = (UiKit.rarity_color(item.rarity) if item.rarity != "" else UiKit.ACCENT) if item != null else UiKit.BORDER

	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 84)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.focus_mode = Control.FOCUS_NONE

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	style.bg_color = Color(base_col.r, base_col.g, base_col.b, 0.28 if selected else (0.10 if item != null else 0.04))
	style.border_color = (UiKit.COLOR_GOLD_PRIMARY if selected else (base_col if item != null else Color(base_col.r, base_col.g, base_col.b, 0.35)))
	style.set_border_width_all(3 if selected else 1)
	if selected:
		style.shadow_color = Color(UiKit.COLOR_GOLD_PRIMARY.r, UiKit.COLOR_GOLD_PRIMARY.g, UiKit.COLOR_GOLD_PRIMARY.b, 0.4)
		style.shadow_size = 8
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		card.add_theme_stylebox_override(st, style)

	card.pressed.connect(func() -> void:
		_active_equip_slot = slot_key
		AudioManager.play_ui("select")
		_refresh()
	)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 10
	hbox.offset_right = -10
	hbox.offset_top = 6
	hbox.offset_bottom = -6
	card.add_child(hbox)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(58, 58)
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0, 0, 0, 0.45)
	icon_style.set_corner_radius_all(10)
	icon_style.set_border_width_all(2 if selected else 1)
	icon_style.border_color = (UiKit.COLOR_GOLD_PRIMARY if selected else base_col)
	icon_frame.add_theme_stylebox_override("panel", icon_style)

	var icon_lbl := Label.new()
	icon_lbl.text = item.icon if item != null else slot["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 32)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon_lbl)

	var refine_badge: Control = UiKit.refine_badge(item.refine_level) if item != null else null
	var icon_with_badge := UiKit.with_corner_badge(icon_frame, refine_badge)
	icon_with_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_with_badge)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)

	var slot_lbl := Label.new()
	slot_lbl.text = slot_label.to_upper()
	slot_lbl.add_theme_font_size_override("font_size", 13)
	slot_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY if selected else (UiKit.ACCENT if item != null else UiKit.TEXT_DIM))
	slot_lbl.clip_text = true
	slot_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(slot_lbl)

	var item_lbl := Label.new()
	item_lbl.clip_text = true
	if item != null:
		item_lbl.text = item.name
		item_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	else:
		item_lbl.text = Locale.pick({"es": "➕ Vacío", "en": "➕ Empty"})
		item_lbl.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
	item_lbl.add_theme_font_size_override("font_size", 16)
	item_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(item_lbl)

	if item != null:
		var bonus_text := _get_bonuses_text(item)
		if bonus_text != "":
			var bonus_lbl := Label.new()
			bonus_lbl.text = bonus_text
			bonus_lbl.add_theme_font_size_override("font_size", 12)
			bonus_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			bonus_lbl.clip_text = true
			bonus_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			info_vbox.add_child(bonus_lbl)

	return card


## Construye en el contenedor derecho las alternativas disponibles del inventario.
func _build_equip_alternatives(host: VBoxContainer, slot_key: String) -> void:
	var current: EquipmentResource = GlobalState.equipped.get(slot_key)

	if current != null:
		var unbtn := Button.new()
		unbtn.text = Locale.t("equip_unequip", [current.name])
		unbtn.custom_minimum_size = Vector2(0, 48)
		unbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unbtn.add_theme_font_size_override("font_size", 15)
		UiKit.premium_button(unbtn, {"bg_color": Color(0.20, 0.06, 0.08, 0.9), "border_color": UiKit.BAD})
		unbtn.add_theme_color_override("font_color", UiKit.BAD)
		unbtn.pressed.connect(func() -> void:
			var unequipped_name := current.name
			GlobalState.unequip_item(slot_key)
			AudioManager.play_ui("cancel")
			_refresh()
			UiKit.toast(self, Locale.pick({"es": "Guardado en la bolsa: %s" % unequipped_name, "en": "Stored in bag: %s" % unequipped_name}), UiKit.TEXT_DIM)
		)
		host.add_child(unbtn)

	var valid: Array = []
	if current != null:
		valid.append({
			"id": current.id,
			"name": current.name,
			"quantity": 1,
			"category": "equipment",
			"icon": current.icon,
			"resource": current,
			"is_equipped": true,
		})

	for item in GlobalState.inventory:
		if item.get("category") == "equipment":
			var res: EquipmentResource = item.get("resource")
			if res == null:
				var item_id: String = String(item.get("id", ""))
				var def: Dictionary = Design.get_item(item_id)
				var s: String = String(def.get("slot", "weapon"))
				if s == slot_key:
					var eq := EquipmentResource.new()
					eq.id = item_id
					eq.name = String(item.get("name", Design.get_item_name(item_id)))
					eq.slot = s
					eq.icon = String(item.get("icon", def.get("icon", "🗡️")))
					eq.base_id = item_id
					eq.stat_bonuses = def.get("bonuses", {})
					SaveSerializer.apply_combat_fields(eq, def.get("combat", {}))
					item["resource"] = eq
					valid.append(item)
			elif res.slot == slot_key:
				valid.append(item)

	if valid.is_empty():
		var empty_panel := PanelContainer.new()
		empty_panel.custom_minimum_size = Vector2(0, 120)
		empty_panel.add_theme_stylebox_override("panel", UiKit.card(12, 16))
		var empty_vb := VBoxContainer.new()
		empty_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		empty_vb.add_theme_constant_override("separation", 6)
		empty_panel.add_child(empty_vb)

		var empty_icon := Label.new()
		empty_icon.text = "📦"
		empty_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_icon.add_theme_font_size_override("font_size", 32)
		empty_vb.add_child(empty_icon)

		var empty := Label.new()
		empty.text = Locale.t("equip_none_slot")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		empty_vb.add_child(empty)
		host.add_child(empty_panel)
		return

	for item in valid:
		host.add_child(_make_equip_option_card(item, current))


## Tarjeta de una alternativa: icono, nombre, deltas vs. equipado y botón de equipar.
func _make_equip_option_card(item: Dictionary, current: EquipmentResource) -> PanelContainer:
	var res: EquipmentResource = item["resource"]
	var equipped_now: bool = bool(item.get("is_equipped", false)) or (current != null and (current == res or current.id == res.id))
	var rc: Color = UiKit.rarity_color(res.rarity) if res.rarity != "" else UiKit.ACCENT
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(rc, 12, 10))
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)

	var icon := Label.new()
	icon.text = res.icon
	icon.add_theme_font_size_override("font_size", 28)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(36, 36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UiKit.with_corner_badge(icon, UiKit.refine_badge(res.refine_level)))

	var name_lbl := Label.new()
	name_lbl.text = res.name + ("  [E]" if equipped_now else "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", rc)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(name_lbl)

	var act := Button.new()
	act.custom_minimum_size = Vector2(110, 44)
	act.add_theme_font_size_override("font_size", 16)
	if equipped_now:
		act.text = Locale.t("equip_current")
		act.disabled = true
		UiKit.premium_button(act, {"disabled": true})
	else:
		act.text = Locale.t("equip_do")
		UiKit.premium_button(act)
		act.pressed.connect(func() -> void:
			GlobalState.equip_resource(res)
			AudioManager.play_ui("confirm")
			_refresh()
			UiKit.toast(self, Locale.pick({"es": "%s equipado" % res.name, "en": "%s equipped" % res.name}), rc)
		)
	head.add_child(act)

	# Deltas de estadísticas respecto a lo que hay equipado ahora.
	var deltas := _equip_deltas(res, current)
	if deltas.is_empty():
		var same := Label.new()
		same.text = Locale.t("equip_no_change")
		same.add_theme_font_size_override("font_size", 13)
		same.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		same.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(same)
	else:
		# HFlowContainer (en vez de HBoxContainer) para que los chips de delta
		# ENVUELVAN a la siguiente línea cuando no caben en el ancho de la
		# tarjeta, en vez de desbordarse fuera de ella (incidencia reportada:
		# equipos con muchos bonus se salían del recuadro).
		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_PASS
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 4)
		for d in deltas:
			flow.add_child(_delta_chip(d["label"], int(d["delta"])))
		vb.add_child(flow)
	return card


## Calcula los deltas (candidato − equipado) por estadística; sólo los != 0.
func _equip_deltas(candidate: EquipmentResource, current: EquipmentResource) -> Array:
	var cand := _equip_values(candidate)
	var cur := _equip_values(current)
	var keys: Array = []
	for k in cand.keys():
		if not keys.has(k):
			keys.append(k)
	for k in cur.keys():
		if not keys.has(k):
			keys.append(k)
	var out: Array = []
	for k in keys:
		var delta: int = int(cand.get(k, 0)) - int(cur.get(k, 0))
		if delta != 0:
			out.append({"label": _stat_short_label(k), "delta": delta})
	return out


## Extrae un diccionario {stat/combate: valor} de un equipo (omite los 0).
func _equip_values(res: EquipmentResource) -> Dictionary:
	var d: Dictionary = {}
	if res == null:
		return d
	for k in ["str", "agi", "vit", "int", "dex", "luk"]:
		var v: int = res.effective_stat_bonus(k)
		if v != 0:
			d[k] = v
	for f in ["phys_damage", "mag_damage", "range_damage", "phys_defense", "mag_defense"]:
		var cv: int = res.effective_combat(f)
		if cv != 0:
			d[f] = cv
	return d


## Chip de delta: verde si mejora, rojo si empeora.
func _delta_chip(label: String, delta: int) -> PanelContainer:
	var col: Color = UiKit.GOOD if delta > 0 else UiKit.BAD
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", UiKit.chip(col))
	var m := UiKit.margins(8, 8, 3, 3)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(m)
	var lbl := Label.new()
	lbl.text = "%s %+d" % [label, delta]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(lbl)
	return chip


## Etiqueta corta de una estadística/campo de combate para los deltas.
func _stat_short_label(key: String) -> String:
	match key:
		"str", "agi", "vit", "int", "dex", "luk":
			return key.to_upper()
		"phys_damage": return Locale.t("delta_pdmg")
		"mag_damage": return Locale.t("delta_mdmg")
		"range_damage": return Locale.t("delta_rdmg")
		"phys_defense": return Locale.t("delta_pdef")
		"mag_defense": return Locale.t("delta_mdef")
		_: return key


## Texto compacto de los bonus de característica de un equipo (para las ranuras).
## Usa el bonus EFECTIVO (con el +10%/nivel de refinamiento ya aplicado).
func _get_bonuses_text(res: EquipmentResource) -> String:
	var list: Array[String] = []
	for k in res.stat_bonuses:
		var v: int = res.effective_stat_bonus(String(k))
		if v != 0:
			list.append("%s +%d" % [String(k).to_upper(), v])
	return ", ".join(list)
