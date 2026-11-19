# TabInfo.gd
# ─────────────────────────────────────────────────────────────────────────────
# PANTALLA INFORMACIÓN — vista de pestaña (como Personaje y Bolsa), NO un modal.
#
# Diseño maestro-detalle: a la IZQUIERDA una lista con las secciones (Diario,
# Bestiario, Mazmorras, Logros, Enciclopedia) y a la DERECHA el contenido de la
# sección seleccionada. El Diario es la primera y más importante.
#
# Reutiliza los visores existentes (JournalViewer, BestiaryViewer, DungeonsViewer,
# AchievementsViewer, EncyclopediaViewer) en su modo `embedded` (sin fondo oscuro,
# sin botón de cerrar): cada uno rellena el panel de detalle. Así no se duplica
# el contenido y cada visor sigue siendo la única fuente de su render.
# ─────────────────────────────────────────────────────────────────────────────
class_name TabInfo
extends Control

## Secciones de Información (orden: Diario primero). `make` crea el visor embebido.
var _sections: Array = []
## Clave de la sección seleccionada actualmente.
var _active_section: String = "journal"
## Botones de la lista izquierda (clave de sección -> Button) para el resaltado.
var _nav_btns: Dictionary = {}
## Panel de detalle (derecha) donde se dibuja el visor de la sección activa.
var _detail: Control = null


var _is_updating_layout: bool = false


func _ready() -> void:
	_sections = [
		{"key": "journal",      "icon": "📔", "title": "info_journal",       "make": func() -> Control: return JournalViewer.new()},
		{"key": "codex",        "icon": "🔍", "title": "info_codex",         "make": func() -> Control: return CodexViewer.new()},
		{"key": "relations",    "icon": "👥", "title": "info_relations",     "make": func() -> Control: return RelationsViewer.new()},
		{"key": "bestiary",     "icon": "📖", "title": "char_bestiary",      "make": func() -> Control: return BestiaryViewer.new()},
		{"key": "dungeons",     "icon": "🏛️", "title": "info_dungeons",       "make": func() -> Control: return DungeonsViewer.new()},
		{"key": "achievements", "icon": "🏆", "title": "info_achievements",   "make": func() -> Control: return AchievementsViewer.new()},
	]
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)
	Locale.locale_changed.connect(_on_locale_changed)
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()


func _update_responsive_layout() -> void:
	if not is_inside_tree() or _is_updating_layout:
		return
	_is_updating_layout = true
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		_is_updating_layout = false
		return
	var is_landscape := sz.x > sz.y
	if is_landscape:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		custom_minimum_size = Vector2.ZERO
	else:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		anchor_left = 0.04
		anchor_right = 0.96
		anchor_top = 0.04
		anchor_bottom = 0.96
		offset_left = 0.0
		offset_right = 0.0
		offset_top = 10.0
		offset_bottom = -10.0
		custom_minimum_size = Vector2.ZERO
	_is_updating_layout = false


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ (maestro-detalle)
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	# Antes esta pestaña dibujaba su propio "ModalCard" con
	# borde cian, redundante ahora que vive embebida dentro del panel dorado
	# del Hub (CharacterHubModal._content_panel). Se elimina ese envoltorio y
	# el contenido rellena directamente el marco que ya proporciona el Hub.
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	# ── Lista de secciones (izquierda) ───────────────────────────────────────
	var nav_panel := PanelContainer.new()
	nav_panel.custom_minimum_size = Vector2(280, 0)
	var nav_sb := StyleBoxFlat.new()
	nav_sb.bg_color = UiKit.BG_DEEP
	nav_sb.border_width_right = 1
	nav_sb.border_color = UiKit.BORDER
	nav_panel.add_theme_stylebox_override("panel", nav_sb)
	hbox.add_child(nav_panel)

	var nav_scroll := ScrollContainer.new()
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav_panel.add_child(nav_scroll)

	var nav_margin := UiKit.margins(12, 12, 16, 16)
	nav_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_scroll.add_child(nav_margin)

	var nav_list := VBoxContainer.new()
	nav_list.add_theme_constant_override("separation", 10)
	nav_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_margin.add_child(nav_list)

	var header := Label.new()
	header.text = "ℹ️ " + Locale.t("info_title")
	header.add_theme_font_size_override("font_size", 32)
	header.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	nav_list.add_child(header)

	var div := ColorRect.new()
	div.color = Color(1, 1, 1, 0.06)
	div.custom_minimum_size = Vector2(0, 2)
	nav_list.add_child(div)

	_nav_btns.clear()
	for section in _sections:
		var btn := _make_nav_button(section)
		_nav_btns[section["key"]] = btn
		nav_list.add_child(btn)

	# ── Panel de detalle (derecha) ───────────────────────────────────────────
	_detail = Control.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_detail)

	_render_detail()


## Botón de una sección en la lista izquierda: icono + título, resaltado si activa.
func _make_nav_button(section: Dictionary) -> Button:
	var key: String = section["key"]
	var active: bool = key == _active_section
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 88)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 26)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 8
	if active:
		style.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.18)
		style.border_color = UiKit.ACCENT
		style.border_width_left = 4
	else:
		style.bg_color = UiKit.SURFACE_ALT
		style.border_color = UiKit.BORDER
		style.set_border_width_all(1)
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, style)
	btn.add_theme_color_override("font_color", UiKit.ACCENT_SOFT if active else UiKit.TEXT)
	btn.text = "%s  %s" % [section["icon"], Locale.t(section["title"])]
	btn.pressed.connect(func() -> void: _select_section(key))
	return btn


## Cambia la sección activa y redibuja lista (resaltado) + detalle.
func _select_section(key: String) -> void:
	if key == _active_section and _detail != null and _detail.get_child_count() > 0:
		return
	AudioManager.play_sfx("click")
	_active_section = key
	# Re-estiliza los botones sin reconstruir todo (solo el resaltado).
	for k in _nav_btns:
		var b: Button = _nav_btns[k]
		var section: Dictionary = _section_by_key(k)
		var new_btn := _make_nav_button(section)
		b.replace_by(new_btn)
		_nav_btns[k] = new_btn
	_render_detail()


## Dibuja en el panel de detalle el visor de la sección activa, en modo embebido.
func _render_detail() -> void:
	if _detail == null:
		return
	for child in _detail.get_children():
		child.queue_free()
	var section: Dictionary = _section_by_key(_active_section)
	if section.is_empty():
		return
	var maker: Callable = section["make"]
	var viewer: Control = maker.call()
	viewer.set("embedded", true)
	_detail.add_child(viewer)
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _section_by_key(key: String) -> Dictionary:
	for section in _sections:
		if section["key"] == key:
			return section
	return {}


## Al volver a mostrarse la pestaña, refresca el detalle (los datos pueden haber
## cambiado: logros nuevos, progreso de mazmorras, entradas de diario, etc.).
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_render_detail()


func _on_locale_changed() -> void:
	if is_inside_tree():
		_build_ui()
