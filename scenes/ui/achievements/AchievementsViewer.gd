# AchievementsViewer.gd
# ─────────────────────────────────────────────────────────────────────────────
# VISOR DE LOGROS — overlay reutilizable construido por código.
#
# Muestra TODOS los logros definidos en achievements.json: los ya conseguidos
# (GlobalState.achievements_unlocked) aparecen resaltados con su icono, nombre y
# descripción; los pendientes se muestran atenuados y con la descripción como pista.
# Una cabecera indica el progreso "X / N". Se cierra con el botón o al pulsar fuera.
# ─────────────────────────────────────────────────────────────────────────────
class_name AchievementsViewer
extends Control

## Emitida cuando el usuario cierra el visor.
signal closed

## Modo embebido: rellena su padre sin fondo oscuro ni botón de cerrar, para usarse
## dentro de la pestaña Información (TabInfo). Asignar ANTES de añadir al árbol.
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
	vbox.add_theme_constant_override("separation", 18)
	if embedded:
		var m := UiKit.margins(30, 30, 26, 26)
		m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(m)
		m.add_child(vbox)
	else:
		# Fondo oscuro que también cierra al tocarlo.
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

	# ── Cabecera: título + progreso ──────────────────────────────────────────
	var ids := Design.achievements.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var u_a: bool = bool(GlobalState.achievements_unlocked.get(a, false))
		var u_b: bool = bool(GlobalState.achievements_unlocked.get(b, false))
		if u_a != u_b:
			return u_a # true primero
		return a < b
	)
	var total := ids.size()
	var unlocked := 0
	for id in ids:
		if GlobalState.achievements_unlocked.get(id, false):
			unlocked += 1

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	title.text = "🏆  " + Locale.pick({"es": "Logros", "en": "Achievements"})
	vbox.add_child(title)

	var progress := Label.new()
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 22)
	progress.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	progress.text = "%d / %d" % [unlocked, total]
	vbox.add_child(progress)

	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.06)
	div.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(div)

	# ── Lista de logros (con scroll por si crece) ────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	if total == 0:
		var empty := Label.new()
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 20)
		empty.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		empty.text = "🏆 " + Locale.pick({"es": "No hay logros definidos.", "en": "No achievements defined."})
		list.add_child(empty)
	else:
		for id in ids:
			var ach: Dictionary = Design.get_achievement(String(id))
			var is_unlocked: bool = GlobalState.achievements_unlocked.get(id, false)
			list.add_child(_build_row(ach, is_unlocked))

	# ── Botón cerrar (solo overlay; en TabInfo navega la barra de pestañas) ──────
	if not embedded:
		var btn_close := Button.new()
		btn_close.custom_minimum_size = Vector2(0, 72)
		btn_close.add_theme_font_size_override("font_size", 24)
		btn_close.text = Locale.t("menu_back")
		btn_close.pressed.connect(func() -> void: closed.emit())
		vbox.add_child(btn_close)


## Construye una fila de logro: icono + (nombre / descripción). Los logros
## desbloqueados se muestran a todo color; los pendientes, atenuados.
func _build_row(ach: Dictionary, is_unlocked: bool) -> PanelContainer:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	if is_unlocked:
		sb.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.14)
		sb.border_color = UiKit.ACCENT
		sb.set_border_width_all(2)
	else:
		sb.bg_color = UiKit.SURFACE_ALT
		sb.border_color = UiKit.BORDER
		sb.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	row.add_child(hb)

	# Icono (o candado si está pendiente).
	var icon := Label.new()
	icon.custom_minimum_size = Vector2(56, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 38)
	icon.text = String(ach.get("icon", "🏆")) if is_unlocked else "🔒"
	if not is_unlocked:
		icon.modulate = Color(1, 1, 1, 0.5)
	hb.add_child(icon)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	hb.add_child(texts)

	var name_lbl := Label.new()
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.text = Design._loc_str(ach.get("name", "???"))
	name_lbl.add_theme_color_override("font_color",
		UiKit.ACCENT_SOFT if is_unlocked else UiKit.TEXT_DIM)
	texts.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 18)
	desc_lbl.text = Design._loc_str(ach.get("desc", ""))
	desc_lbl.add_theme_color_override("font_color",
		UiKit.TEXT_DIM if is_unlocked else Color(UiKit.TEXT_DIM.r, UiKit.TEXT_DIM.g, UiKit.TEXT_DIM.b, 0.6))
	texts.add_child(desc_lbl)

	return row


## Cierra el visor al tocar el fondo oscuro (fuera del panel).
func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		closed.emit()
