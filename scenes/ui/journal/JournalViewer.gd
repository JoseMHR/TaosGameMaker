# JournalViewer.gd
# ─────────────────────────────────────────────────────────────────────────────
# DIARIO / REGISTRO NARRATIVO — overlay reutilizable construido por código.
#
# Resume, para orientar al jugador y premiar su atención:
#   · OBJETIVO ACTUAL: título + pista del estado de misión (`GlobalState.quest_state`,
#     descrito en quests.json → `Design.quest_desc`).
#   · PROGRESO DE LA QUESTLINE: los estados de `Design.quest_order()` en orden,
#     marcando hecho / actual / pendiente.
#   · DECISIONES Y LOGROS DE HISTORIA: profesiones desbloqueadas, jefes derrotados y
#     relaciones con NPCs (afinidad), leídos del Estado Global.
#
# Todo es data-driven y de solo lectura. Se cierra con el botón o al tocar fuera.
# ─────────────────────────────────────────────────────────────────────────────
class_name JournalViewer
extends Control

## Emitida cuando el usuario cierra el visor.
signal closed

## Modo embebido: cuando es true, se dibuja como panel de contenido que rellena su
## padre (sin fondo oscuro, sin botón de cerrar), para usarse dentro de la pestaña
## Información (TabInfo). Debe asignarse ANTES de añadir el nodo al árbol.
var embedded: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	if embedded:
		# Panel de contenido que rellena el detalle de TabInfo.
		var m := UiKit.margins(30, 30, 26, 26)
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(m)
		m.add_child(vbox)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.02, 0.02, 0.04, 0.92)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.gui_input.connect(_on_bg_input)
		add_child(bg)

		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center)

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(760, 0)
		UiKit.premium_dialog_panel(panel, UiKit.theme_color("accent", UiKit.ACCENT), 26)
		center.add_child(panel)

		var margin := UiKit.margins(40, 40, 36, 36)
		panel.add_child(margin)
		margin.add_child(vbox)

	# ── Cabecera ───────────────────────────────────────────────────────────────
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	title.text = "📖  " + Locale.pick({"es": "Diario", "en": "Journal"})
	vbox.add_child(title)

	vbox.add_child(_divider())

	# ── Scroll con las secciones ─────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	_build_current_objective(list)
	_build_questline(list)
	_build_secondary_quests(list)
	_build_story_progress(list)

	# ── Botón cerrar (solo overlay; en TabInfo navega la barra de pestañas) ──────
	if not embedded:
		var btn_close := Button.new()
		btn_close.custom_minimum_size = Vector2(0, 72)
		btn_close.add_theme_font_size_override("font_size", 28)
		btn_close.text = Locale.t("menu_back")
		btn_close.pressed.connect(func() -> void: closed.emit())
		vbox.add_child(btn_close)


## OBJETIVO ACTUAL: tarjeta destacada con el título y la pista del estado activo.
func _build_current_objective(list: VBoxContainer) -> void:
	list.add_child(_section_label("🎯  " + Locale.pick({"es": "Objetivo actual", "en": "Current objective"})))

	var desc := Design.quest_desc(GlobalState.quest_state)
	var t := String(desc.get("title", "")) if not desc.is_empty() else ""
	var h := String(desc.get("hint", "")) if not desc.is_empty() else ""
	if t == "":
		t = Locale.pick({"es": "Sin misión activa", "en": "No active quest"})
		h = Locale.pick({"es": "Explora el mundo para encontrar tu próximo objetivo.", "en": "Explore the world to find your next objective."})

	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	sb.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.14)
	sb.border_color = UiKit.ACCENT
	sb.set_border_width_all(2)
	row.add_theme_stylebox_override("panel", sb)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 4)
	row.add_child(texts)

	var name_lbl := Label.new()
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 34)
	name_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	name_lbl.text = t
	texts.add_child(name_lbl)

	var hint_lbl := Label.new()
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.add_theme_font_size_override("font_size", 28)
	hint_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	hint_lbl.text = h
	texts.add_child(hint_lbl)

	list.add_child(row)


## PROGRESO DE LA QUESTLINE: cada estado de `quest_order` con su marca de estado.
func _build_questline(list: VBoxContainer) -> void:
	var order := Design.quest_order()
	if order.is_empty():
		return
	list.add_child(_section_label("🗺️  " + Locale.pick({"es": "Camino principal", "en": "Main path"})))

	var current_idx := order.find(GlobalState.quest_state)
	for i in range(order.size()):
		var state := String(order[i])
		var desc := Design.quest_desc(state)
		var t_val = desc.get("title", state)
		var t: String = Locale.pick(t_val) if t_val is Dictionary else String(t_val)
		var is_done := current_idx != -1 and i < current_idx
		var is_current := i == current_idx
		list.add_child(_step_row(t, is_done, is_current))


## MISIONES SECUNDARIAS/PARALELAS del Sistema Multi-Quest (`GlobalState.quests`,
## independiente de la historia principal `quest_state`) — ver task_arreglos.md §1.
## No dibuja nada si el jugador no tiene ninguna secundaria iniciada (habitual
## mientras no se haya añadido contenido a `data/quests_secondary/`).
func _build_secondary_quests(list: VBoxContainer) -> void:
	var active_ids: Array = []
	var done_ids: Array = []
	for qid: String in GlobalState.quests.keys():
		var stage: int = int(GlobalState.quests[qid].get("stage", 0))
		if stage >= 0:
			active_ids.append(qid)
		elif stage == -1:
			done_ids.append(qid)
	if active_ids.is_empty() and done_ids.is_empty():
		return

	if not active_ids.is_empty():
		list.add_child(_section_label("📜  " + Locale.pick({"es": "Misiones secundarias", "en": "Side quests"})))
		for qid in active_ids:
			list.add_child(_secondary_quest_row(qid, int(GlobalState.quests[qid].get("stage", 0)), false))

	if not done_ids.is_empty():
		list.add_child(_section_label("🏆  " + Locale.pick({"es": "Misiones completadas", "en": "Completed quests"})))
		for qid in done_ids:
			list.add_child(_secondary_quest_row(qid, -1, true))


## Fila de una misión secundaria: título + pista (si `data/quests_secondary/`
## tiene ficha para esta fase) con marca de completada/en curso. Si no existe
## ficha, cae en el propio id como título (nunca deja la fila vacía).
func _secondary_quest_row(quest_id: String, stage: int, done: bool) -> PanelContainer:
	var stage_info := Design.get_quest_secondary_stage(quest_id, stage)
	var quest_info := Design.get_quest_secondary(quest_id)
	var title_dict = stage_info.get("title", quest_info.get("title", {}))
	var title := Locale.pick(title_dict) if title_dict is Dictionary and not title_dict.is_empty() else quest_id
	var hint_dict = stage_info.get("hint", {})
	var hint := Locale.pick(hint_dict) if hint_dict is Dictionary and not hint_dict.is_empty() else ""

	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	sb.bg_color = Color(UiKit.GOOD.r, UiKit.GOOD.g, UiKit.GOOD.b, 0.10) if done else UiKit.SURFACE_ALT
	sb.border_color = UiKit.GOOD if done else UiKit.BORDER
	sb.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	row.add_child(hb)

	var mark := Label.new()
	mark.custom_minimum_size = Vector2(44, 0)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 28)
	mark.text = "✅" if done else "▶"
	hb.add_child(mark)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 3)
	hb.add_child(texts)

	var title_lbl := Label.new()
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", UiKit.TEXT if not done else UiKit.GOOD)
	title_lbl.text = title
	texts.add_child(title_lbl)

	if hint != "":
		var hint_lbl := Label.new()
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_lbl.add_theme_font_size_override("font_size", 18)
		hint_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		hint_lbl.text = hint
		texts.add_child(hint_lbl)

	return row


## DECISIONES Y LOGROS DE HISTORIA leídos del Estado Global.
func _build_story_progress(list: VBoxContainer) -> void:
	list.add_child(_section_label("⭐  " + Locale.pick({"es": "Decisiones y hazañas", "en": "Decisions & deeds"})))

	# Profesiones dominadas
	var profs: Array = GlobalState.unlocked_professions
	var profs_translated: Array = []
	for p in profs:
		profs_translated.append(Locale.translate_profession(String(p)))
	var profs_txt := ", ".join(profs_translated) if not profs_translated.is_empty() else Locale.pick({"es": "Don Nadie (inicial)", "en": "Nobody (starter)"})
	list.add_child(_fact_row("⚔️", Locale.pick({"es": "Profesiones dominadas", "en": "Mastered professions"}), "%d / 7  (%s)" % [profs.size(), profs_txt]))

	# Jefes derrotados
	var bosses := GlobalState.defeated_bosses.size()
	list.add_child(_fact_row("💀", Locale.pick({"es": "Jefes mayores derrotados", "en": "Major bosses defeated"}), str(bosses)))

	# Puntos de Interés / Curiosidades
	var total_codex := Design.codex_total()
	var disc_codex := 0
	for cid in Design.codex.keys():
		if GlobalState.is_lore_discovered(String(cid)):
			disc_codex += 1
	list.add_child(_fact_row("🔍", Locale.pick({"es": "Lugares y misterios descubiertos", "en": "Places & mysteries discovered"}), "%d / %d" % [disc_codex, total_codex]))

	# Mazmorras completadas
	var raw_dungeons: Array = Array(Design.canonical_dungeon_ids())
	var done_dungeons := 0
	for did in raw_dungeons:
		if Design.is_dungeon_completed(String(did)):
			done_dungeons += 1
	list.add_child(_fact_row("🏛️", Locale.pick({"es": "Mazmorras superadas", "en": "Dungeons cleared"}), "%d / %d" % [done_dungeons, raw_dungeons.size()]))


# ══════════════════════════════════════════════════════════════════════════════
# WIDGETS AUXILIARES
# ══════════════════════════════════════════════════════════════════════════════

## Fila de paso de la questline: check (hecho), flecha (actual) o punto (pendiente).
func _step_row(text: String, is_done: bool, is_current: bool) -> PanelContainer:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(12)
	if is_current:
		sb.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.12)
		sb.border_color = UiKit.ACCENT
		sb.set_border_width_all(2)
	else:
		sb.bg_color = UiKit.SURFACE_ALT
		sb.border_color = UiKit.BORDER
		sb.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	row.add_child(hb)

	var mark := Label.new()
	mark.custom_minimum_size = Vector2(50, 0)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 34)
	mark.text = "✅" if is_done else ("▶" if is_current else "•")
	hb.add_child(mark)

	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.text = text
	var col := UiKit.ACCENT_SOFT if is_current else (UiKit.TEXT if is_done else UiKit.TEXT_DIM)
	lbl.add_theme_color_override("font_color", col)
	hb.add_child(lbl)

	return row


## Fila de dato: icono + etiqueta + valor.
func _fact_row(icon: String, label: String, value: String) -> PanelContainer:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	sb.bg_color = UiKit.SURFACE_ALT
	sb.border_color = UiKit.BORDER
	sb.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	row.add_child(hb)

	var icon_lbl := Label.new()
	icon_lbl.custom_minimum_size = Vector2(50, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 34)
	icon_lbl.text = icon
	hb.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	name_lbl.text = label
	hb.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 28)
	val_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	val_lbl.text = value
	hb.add_child(val_lbl)

	return row


## Etiqueta de sección.
func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", UiKit.TEXT)
	lbl.text = text
	return lbl


## Divisor horizontal tenue.
func _divider() -> ColorRect:
	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.06)
	div.custom_minimum_size = Vector2(0, 2)
	return div


## Cierra el visor al tocar el fondo oscuro (fuera del panel).
func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		closed.emit()
