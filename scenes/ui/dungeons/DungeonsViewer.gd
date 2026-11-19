# DungeonsViewer.gd
# ─────────────────────────────────────────────────────────────────────────────
# VISOR DE MAZMORRAS — overlay reutilizable construido por código.
#
# Lista todas las mazmorras de rejilla definidas en data/dungeons/<id>.json
# (Design.all_dungeon_ids(), un fichero por mazmorra). Marca cada una como
# COMPLETADA si su jefe ha sido derrotado (GlobalState.is_boss_defeated(
# "event_id:boss_id")) o PENDIENTE en caso contrario. Una cabecera muestra el
# progreso global "X / N (P%)".
#
# Es de solo lectura (consulta). Pertenece a la pantalla Información.
# Se cierra con el botón o al tocar el fondo.
# ─────────────────────────────────────────────────────────────────────────────
class_name DungeonsViewer
extends Control

## Emitida cuando el usuario cierra el visor.
signal closed

## Modo embebido: rellena su padre sin fondo oscuro ni botón de cerrar, para usarse
## dentro de la pestaña Información (TabInfo). Asignar ANTES de añadir al árbol.
var embedded: bool = false


## Grupos de mazmorras ordenados por las 7 zonas canónicas de progresión (PROGRESSION.md).
const DUNGEON_GROUPS: Array[Dictionary] = [
	{
		"title": {"es": "🛡️ Zona 1: Valle del Yelmo", "en": "🛡️ Zone 1: Helm Valley"},
		"ids": ["dun_inicial", "dun_yelmo"]
	},
	{
		"title": {"es": "❄️ Zona 2: Travesía Helada", "en": "❄️ Zone 2: Frozen Crossing"},
		"ids": ["dun_nieves"]
	},
	{
		"title": {"es": "🌿 Zona 3: Praderas de Sylphrena", "en": "🌿 Zone 3: Sylphrena Meadows"},
		"ids": ["dun_bandidos", "sendero_guerrero", "sendero_arquero", "sendero_sacerdote"]
	},
	{
		"title": {"es": "👑 Zona 4: Reino de Celestia", "en": "👑 Zone 4: Kingdom of Celestia"},
		"ids": ["sendero_elementalista", "sendero_psiquico", "sendero_tiempo"]
	},
	{
		"title": {"es": "🏜️ Zona 5: Desierto de Gloriam", "en": "🏜️ Zone 5: Gloriam Desert"},
		"ids": ["dun_desierto"]
	},
	{
		"title": {"es": "⚡ Zona 6: Ruinas de Arcanum", "en": "⚡ Zone 6: Arcanum Ruins"},
		"ids": ["dun_laboratorio"]
	},
	{
		"title": {"es": "✨ Zona 7: Templo del Origen", "en": "✨ Zone 7: Temple of Origin"},
		"ids": ["dun_final"]
	}
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	if embedded:
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

	var raw_ids: Array = Array(Design.canonical_dungeon_ids())
	var total := raw_ids.size()
	var completed := 0
	for id in raw_ids:
		if _is_completed(String(id)):
			completed += 1
	var pct := int(round(100.0 * completed / float(total))) if total > 0 else 0

	# ── Cabecera: título + progreso ──────────────────────────────────────────
	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	title.text = "🏛️  " + Locale.t("info_dungeons")
	vbox.add_child(title)

	var progress := Label.new()
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_font_size_override("font_size", 22)
	progress.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	progress.text = Locale.t("dungeons_progress") % [completed, total, pct]
	vbox.add_child(progress)

	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.06)
	div.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(div)

	# ── Lista de mazmorras por zona (con scroll) ─────────────────────────────
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
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		empty.text = "🗺️ " + Locale.t("dungeons_empty")
		list.add_child(empty)
	else:
		var added_ids: Array = []
		for grp in DUNGEON_GROUPS:
			var grp_ids: Array = grp.get("ids", [])
			var present_ids: Array = []
			for did in grp_ids:
				if raw_ids.has(did):
					present_ids.append(did)
					added_ids.append(did)
			if not present_ids.is_empty():
				var grp_lbl := Label.new()
				grp_lbl.text = Locale.pick(grp.get("title", {}))
				grp_lbl.add_theme_font_size_override("font_size", 26)
				grp_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
				list.add_child(grp_lbl)
				for did in present_ids:
					list.add_child(_build_row(String(did)))

		# Cualquier mazmorra extra no catalogada
		var extras: Array = []
		for did in raw_ids:
			if not added_ids.has(did):
				extras.append(did)
		if not extras.is_empty():
			var extra_lbl := Label.new()
			extra_lbl.text = Locale.pick({"es": "Otras Mazmorras", "en": "Other Dungeons"})
			extra_lbl.add_theme_font_size_override("font_size", 26)
			extra_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
			list.add_child(extra_lbl)
			for did in extras:
				list.add_child(_build_row(String(did)))

	# ── Botón cerrar (solo overlay; en TabInfo navega la barra de pestañas) ──────
	if not embedded:
		var btn_close := Button.new()
		btn_close.custom_minimum_size = Vector2(0, 72)
		btn_close.add_theme_font_size_override("font_size", 24)
		btn_close.text = Locale.t("menu_back")
		btn_close.pressed.connect(func() -> void: closed.emit())
		vbox.add_child(btn_close)


## ¿Está completada la mazmorra? (su jefe, "event_id:boss_id", ha sido derrotado).
func _is_completed(event_id: String) -> bool:
	return Design.is_dungeon_completed(event_id)


## Fila de una mazmorra: estado (✅/🔓) + nombre + nº de plantas.
func _build_row(event_id: String) -> PanelContainer:
	var done := _is_completed(event_id)
	var dungeon_name := Design.get_dungeon_display_name(event_id)
	var floors: int = Design.get_dungeon_total_floors(event_id)

	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	if done:
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

	var icon := Label.new()
	icon.custom_minimum_size = Vector2(48, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 30)
	icon.text = "✅" if done else "🔓"
	hb.add_child(icon)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	hb.add_child(texts)

	var name_lbl := Label.new()
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.text = dungeon_name
	name_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT if done else UiKit.TEXT)
	texts.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	var state_txt := Locale.t("dungeons_completed") if done else Locale.t("dungeons_pending")
	sub_lbl.text = "%s  ·  %s" % [state_txt, Locale.t("dungeons_floors") % floors]
	texts.add_child(sub_lbl)

	return row


## Cierra el visor al tocar el fondo oscuro (fuera del panel).
func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		closed.emit()
	elif event is InputEventScreenTouch and event.pressed:
		closed.emit()
