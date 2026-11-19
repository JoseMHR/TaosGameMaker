# OptionsMenu.gd
# Overlay reutilizable de Opciones (idioma, volumen, sonido).
# Construye su interfaz por código y se re-renderiza al cambiar el idioma.
# Reutilizable tanto desde el Menú Principal como desde dentro del juego.
class_name OptionsMenu
extends Control

## Emitida cuando el usuario cierra el panel de opciones.
signal closed
## Emitida cuando el usuario pide volver al menú principal (solo en juego).
signal main_menu_requested

## Si es true, muestra un botón para guardar y salir al menú principal.
## Debe asignarse tras instanciar y ANTES de añadir el nodo al árbol.
var show_main_menu_button: bool = false

## Evita cierres múltiples mientras se reproduce la animación de salida.
var _closing: bool = false

# Referencias a controles que cambian de texto al cambiar idioma.
var _btn_to_menu: Button
var _btn_save: Button
var _title: Label
var _lbl_language: Label
## Botones de idioma indexados por código ("es", "en", "fr", "it", "de", "zh", "ja").
var _lang_buttons: Dictionary = {}
var _lbl_orient: Label
var _btn_landscape: Button
var _btn_portrait: Button
var _lbl_volume: Label
var _slider: HSlider
var _lbl_vol_value: Label
var _lbl_sound: Label
var _btn_sound: Button
var _btn_close: Button
# Accesibilidad
var _lbl_access: Label
var _lbl_reduce_motion: Label
var _btn_reduce_motion: Button
var _lbl_colorblind: Label
var _btn_colorblind: Button
var _lbl_left_handed: Label
var _btn_left_handed: Button
var _lbl_font_scale: Label
var _slider_font: HSlider
var _lbl_text_speed: Label
var _slider_text_speed: HSlider
var _lbl_theme: Label
var _theme_buttons: Dictionary = {}
var _panel: PanelContainer

const _THEME_KEYS: Array[String] = ["default", "crimson", "happyflower", "void", "emerald", "solari", "cyber", "astral"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	Locale.locale_changed.connect(_refresh_texts)
	# Retintar el propio panel de Opciones en caliente al
	# cambiar de tema, no solo al reabrirlo.
	GlobalEvents.theme_changed.connect(_on_theme_changed_live)
	_refresh_texts()
	_apply_theme()
	UiKit.animate_in(self, 0.25)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Salvaguarda defensiva (bug reportado: "OptionsMenu.gd:405 Condition
## '!is_inside_tree()' is true"): si algún llamante llega a dejar viva una
## instancia fuera del árbol (p. ej. `remove_child` sin `queue_free`) sus
## conexiones a `Locale.locale_changed`/`GlobalEvents.theme_changed` seguirían
## disparando `_refresh_texts()`/`_apply_theme()` indefinidamente, y estas
## llaman a `get_viewport_rect()` que requiere estar en el árbol. Desconectar
## aquí corta el problema de raíz pase lo que pase en el llamante.
func _exit_tree() -> void:
	if Locale.locale_changed.is_connected(_refresh_texts):
		Locale.locale_changed.disconnect(_refresh_texts)
	if GlobalEvents.theme_changed.is_connected(_on_theme_changed_live):
		GlobalEvents.theme_changed.disconnect(_on_theme_changed_live)


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# MarginContainer a pantalla completa: acota la altura del panel al alto del
	# dispositivo (deja aire arriba/abajo). Si el contenido no cabe, se hace scroll.
	var screen_margin := MarginContainer.new()
	screen_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_margin.add_theme_constant_override("margin_top", 36)
	screen_margin.add_theme_constant_override("margin_bottom", 36)
	screen_margin.add_theme_constant_override("margin_left", 24)
	screen_margin.add_theme_constant_override("margin_right", 24)
	add_child(screen_margin)

	# Centrado horizontal con ancho máximo (~1100) vía espaciadores elásticos.
	var hbox := HBoxContainer.new()
	screen_margin.add_child(hbox)
	var sp_l := Control.new()
	sp_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp_l)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiKit.premium_dialog_panel(panel, UiKit.theme_color("accent", UiKit.ACCENT), 26)
	hbox.add_child(panel)
	_panel = panel

	var sp_r := Control.new()
	sp_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp_r)

	var margin := UiKit.margins(44, 44, 32, 32)
	panel.add_child(margin)

	# Columna raíz: cabecera fija arriba, contenido scrollable en medio y pie con
	# los botones de acción (Guardar/Salir + Volver) SIEMPRE visibles abajo.
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 18)
	margin.add_child(root_vbox)

	# Título (cabecera fija)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	root_vbox.add_child(_title)

	root_vbox.add_child(_divider())

	# Contenido scrollable (ocupa el espacio central disponible)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var drag_state := {"active": false, "start_y": 0.0, "scroll_start": 0}
	scroll.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					drag_state["active"] = true
					drag_state["start_y"] = mb.global_position.y
					drag_state["scroll_start"] = scroll.scroll_vertical
				else:
					drag_state["active"] = false
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll.scroll_vertical += 40
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll.scroll_vertical -= 40
		elif ev is InputEventMouseMotion and bool(drag_state["active"]):
			var mm := ev as InputEventMouseMotion
			var dy: float = mm.global_position.y - float(drag_state["start_y"])
			scroll.scroll_vertical = maxi(0, int(float(drag_state["scroll_start"]) - dy))
		elif ev is InputEventScreenTouch:
			var st := ev as InputEventScreenTouch
			if st.pressed:
				drag_state["active"] = true
				drag_state["start_y"] = st.position.y
				drag_state["scroll_start"] = scroll.scroll_vertical
			else:
				drag_state["active"] = false
		elif ev is InputEventScreenDrag and bool(drag_state["active"]):
			var sd := ev as InputEventScreenDrag
			var dy: float = sd.position.y - float(drag_state["start_y"])
			scroll.scroll_vertical = maxi(0, int(float(drag_state["scroll_start"]) - dy))
	)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 28)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Tema de interfaz (PRIMERA fila: lo primero que puede cambiar el
	# usuario, ya que redefine el aspecto de todo lo demás) ───────────────────
	_lbl_theme = _section_label()
	vbox.add_child(_lbl_theme)

	# Rejilla de 4 columnas (antes HBoxContainer de una sola fila): con 8 temas
	# una sola fila quedaba demasiado apretada/estrecha, sobre todo en vertical.
	var theme_row := GridContainer.new()
	theme_row.columns = 4
	theme_row.add_theme_constant_override("h_separation", 16)
	theme_row.add_theme_constant_override("v_separation", 16)
	vbox.add_child(theme_row)

	for key in _THEME_KEYS:
		var tbtn := _make_choice_button()
		tbtn.text = Locale.t("theme_%s" % key)
		tbtn.pressed.connect(func() -> void: _on_theme_changed(key))
		theme_row.add_child(tbtn)
		_theme_buttons[key] = tbtn

	vbox.add_child(_divider())

	# ── Idioma ───────────────────────────────────────────────────────────────
	_lbl_language = _section_label()
	vbox.add_child(_lbl_language)

	# Rejilla de 4 columnas: con 7 idiomas, una sola fila quedaría demasiado
	# estrecha (sobre todo en orientación vertical).
	var lang_row := GridContainer.new()
	lang_row.columns = 4
	lang_row.add_theme_constant_override("h_separation", 16)
	lang_row.add_theme_constant_override("v_separation", 16)
	vbox.add_child(lang_row)

	for code in Locale.SUPPORTED:
		var lbtn := _make_choice_button()
		lbtn.text = Locale.t("options_lang_%s" % code)
		var lang_code: String = code
		lbtn.pressed.connect(func() -> void: _on_locale_selected(lang_code))
		lang_row.add_child(lbtn)
		_lang_buttons[code] = lbtn

	vbox.add_child(_divider())

	# ── Orientación de Pantalla ──────────────────────────────────────────────
	_lbl_orient = _section_label()
	vbox.add_child(_lbl_orient)

	var orient_row := HBoxContainer.new()
	orient_row.add_theme_constant_override("separation", 16)
	vbox.add_child(orient_row)

	_btn_landscape = _make_choice_button()
	_btn_landscape.text = "💻 Horizontal"
	_btn_landscape.pressed.connect(func() -> void: _set_orientation(true))
	orient_row.add_child(_btn_landscape)

	_btn_portrait = _make_choice_button()
	_btn_portrait.text = "📱 Vertical"
	_btn_portrait.pressed.connect(func() -> void: _set_orientation(false))
	orient_row.add_child(_btn_portrait)

	vbox.add_child(_divider())

	# ── Volumen ────────────────────────────────────────────────────────────────
	var vol_header := HBoxContainer.new()
	vbox.add_child(vol_header)
	_lbl_volume = _section_label()
	_lbl_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_header.add_child(_lbl_volume)
	_lbl_vol_value = Label.new()
	_lbl_vol_value.add_theme_font_size_override("font_size", 22)
	_lbl_vol_value.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vol_header.add_child(_lbl_vol_value)

	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.05
	_slider.value = Locale.master_volume
	_slider.custom_minimum_size = Vector2(0, 40)
	_slider.value_changed.connect(_on_volume_changed)
	vbox.add_child(_slider)

	vbox.add_child(_divider())

	# ── Sonido ───────────────────────────────────────────────────────────────
	var sound_row := HBoxContainer.new()
	vbox.add_child(sound_row)
	_lbl_sound = _section_label()
	_lbl_sound.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_row.add_child(_lbl_sound)
	_btn_sound = _make_choice_button()
	_btn_sound.custom_minimum_size = Vector2(180, 64)
	_btn_sound.pressed.connect(func() -> void: Locale.set_sfx_enabled(not Locale.sfx_enabled))
	sound_row.add_child(_btn_sound)

	vbox.add_child(_divider())

	# ── Accesibilidad ──────────────────────────────────────────────
	_lbl_access = _section_label()
	_lbl_access.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vbox.add_child(_lbl_access)

	# Reducir movimiento
	var rm_row := HBoxContainer.new()
	vbox.add_child(rm_row)
	_lbl_reduce_motion = _section_label()
	_lbl_reduce_motion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rm_row.add_child(_lbl_reduce_motion)
	_btn_reduce_motion = _make_choice_button()
	_btn_reduce_motion.custom_minimum_size = Vector2(180, 56)
	_btn_reduce_motion.pressed.connect(_on_toggle_reduce_motion)
	rm_row.add_child(_btn_reduce_motion)

	# Modo daltónico
	var cb_row := HBoxContainer.new()
	vbox.add_child(cb_row)
	_lbl_colorblind = _section_label()
	_lbl_colorblind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb_row.add_child(_lbl_colorblind)
	_btn_colorblind = _make_choice_button()
	_btn_colorblind.custom_minimum_size = Vector2(180, 56)
	_btn_colorblind.pressed.connect(_on_toggle_colorblind)
	cb_row.add_child(_btn_colorblind)

	# HUD para zurdos (reubica el anillo de habilidades de mazmorra a la izquierda)
	var lh_row := HBoxContainer.new()
	vbox.add_child(lh_row)
	_lbl_left_handed = _section_label()
	_lbl_left_handed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh_row.add_child(_lbl_left_handed)
	_btn_left_handed = _make_choice_button()
	_btn_left_handed.custom_minimum_size = Vector2(180, 56)
	_btn_left_handed.pressed.connect(_on_toggle_left_handed)
	lh_row.add_child(_btn_left_handed)

	# Tamaño de fuente (escala global de UI)
	_lbl_font_scale = _section_label()
	vbox.add_child(_lbl_font_scale)
	_slider_font = HSlider.new()
	_slider_font.min_value = GameConfig.UI_FONT_SCALE_MIN
	_slider_font.max_value = GameConfig.UI_FONT_SCALE_MAX
	_slider_font.step = 0.1
	_slider_font.value = Locale.font_scale
	_slider_font.custom_minimum_size = Vector2(0, 40)
	_slider_font.value_changed.connect(_on_font_scale_changed)
	vbox.add_child(_slider_font)

	# Velocidad de texto (typewriter)
	_lbl_text_speed = _section_label()
	vbox.add_child(_lbl_text_speed)
	_slider_text_speed = HSlider.new()
	_slider_text_speed.min_value = 0.5
	_slider_text_speed.max_value = 2.0
	_slider_text_speed.step = 0.1
	_slider_text_speed.value = Locale.text_speed
	_slider_text_speed.custom_minimum_size = Vector2(0, 40)
	_slider_text_speed.value_changed.connect(_on_text_speed_changed)
	vbox.add_child(_slider_text_speed)

	# ── Pie fijo: acciones SIEMPRE visibles (fuera del scroll) ────────────────
	root_vbox.add_child(_divider())

	var sz_screen := get_viewport_rect().size
	var is_landscape_footer := sz_screen.x > sz_screen.y
	var footer: Container
	if is_landscape_footer:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 16)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		footer = hb
	else:
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 12)
		footer = vb
	root_vbox.add_child(footer)

	# Salir al menú principal (solo en juego)
	if show_main_menu_button:
		_btn_to_menu = Button.new()
		_btn_to_menu.custom_minimum_size = Vector2(0, 52)
		_btn_to_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_btn_to_menu.add_theme_font_size_override("font_size", 22)
		_btn_to_menu.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
		_btn_to_menu.pressed.connect(func() -> void:
			UiKit.confirm(
				self,
				Locale.pick({"es": "Volver al Menú Principal", "en": "Return to Main Menu"}),
				Locale.pick({
					"es": "¿Deseas volver al Menú Principal? La partida se guardará automáticamente.",
					"en": "Do you want to return to the Main Menu? Your progress will be saved automatically."
				}),
				Locale.pick({"es": "Sí, salir", "en": "Yes, exit"}),
				Locale.pick({"es": "Cancelar", "en": "Cancel"}),
				# El guardado real lo hace quien escuche esta señal
				# (`GameRoot._on_return_to_main_menu` /
				# `CharacterHubModal._load_tab_content`'s listener para
				# "options", ambos llaman a `SaveManager.save_game()` antes de
				# cambiar de escena) — no duplicar la llamada aquí.
				func() -> void: main_menu_requested.emit()
			)
		)
		footer.add_child(_btn_to_menu)

		_btn_save = Button.new()
		_btn_save.custom_minimum_size = Vector2(0, 52)
		_btn_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_btn_save.add_theme_font_size_override("font_size", 22)
		_btn_save.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
		_btn_save.pressed.connect(_on_save_game)
		footer.add_child(_btn_save)

	# Volver (cerrar opciones)
	_btn_close = Button.new()
	_btn_close.custom_minimum_size = Vector2(0, 52)
	_btn_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_close.add_theme_font_size_override("font_size", 24)
	_btn_close.pressed.connect(close)
	footer.add_child(_btn_close)


# ══════════════════════════════════════════════════════════════════════════════
# REFRESCO DE TEXTOS / RESALTADOS
# ══════════════════════════════════════════════════════════════════════════════
func _refresh_texts() -> void:
	_title.text        = Locale.t("options_title")
	_lbl_language.text = Locale.t("options_language")
	for code in _lang_buttons:
		var lbtn: Button = _lang_buttons[code]
		lbtn.text = Locale.t("options_lang_%s" % code)
		_highlight(lbtn, Locale.current == code)
	_lbl_volume.text   = Locale.t("options_volume")
	_lbl_sound.text    = Locale.t("options_sound")
	_btn_sound.text    = Locale.t("options_on") if Locale.sfx_enabled else Locale.t("options_off")
	_btn_close.text    = Locale.t("menu_back")
	if _btn_to_menu != null:
		_btn_to_menu.text = Locale.pick({"es": "Guardar y Salir", "en": "Save and Exit"})
	if _btn_save != null:
		_btn_save.text = Locale.pick({"es": "Guardar partida", "en": "Save game"})
	_lbl_vol_value.text = "%d%%" % int(round(Locale.master_volume * 100.0))
	if _lbl_orient != null:
		_lbl_orient.text = Locale.pick({"es": "Orientación de Pantalla", "en": "Screen Orientation"})
		_highlight(_btn_landscape, GlobalState.is_landscape)
		_highlight(_btn_portrait, not GlobalState.is_landscape)
	_highlight(_btn_sound, Locale.sfx_enabled)

	# Accesibilidad
	if _lbl_access != null:
		_lbl_access.text         = Locale.t("opt_accessibility")
	if _lbl_reduce_motion != null:
		_lbl_reduce_motion.text  = Locale.t("opt_reduce_motion")
	if _lbl_colorblind != null:
		_lbl_colorblind.text     = Locale.t("opt_colorblind")
	if _btn_reduce_motion != null:
		_btn_reduce_motion.text  = Locale.t("options_on") if Locale.reduce_motion else Locale.t("options_off")
		_highlight(_btn_reduce_motion, Locale.reduce_motion)
	if _btn_colorblind != null:
		_btn_colorblind.text     = Locale.t("options_on") if Locale.colorblind else Locale.t("options_off")
		_highlight(_btn_colorblind, Locale.colorblind)
	if _lbl_left_handed != null:
		_lbl_left_handed.text    = Locale.t("opt_left_handed")
	if _btn_left_handed != null:
		_btn_left_handed.text    = Locale.t("options_on") if Locale.left_handed else Locale.t("options_off")
		_highlight(_btn_left_handed, Locale.left_handed)
	if _lbl_font_scale != null:
		_lbl_font_scale.text     = Locale.t("opt_font_scale", [int(round(Locale.font_scale * 100.0))])
	if _lbl_text_speed != null:
		_lbl_text_speed.text     = Locale.t("opt_text_speed", [int(round(Locale.text_speed * 100.0))])
	if _lbl_theme != null:
		_lbl_theme.text = Locale.t("opt_theme")
	for key in _theme_buttons:
		_highlight(_theme_buttons[key], Locale.ui_theme_id == key)


func _on_theme_changed(theme_id: String) -> void:
	AudioManager.play_ui("select")
	Locale.set_ui_theme_id(theme_id)
	_refresh_texts()
	_apply_theme()


## Callback de `GlobalEvents.theme_changed`: retinta este mismo panel aunque el
## tema se haya cambiado desde OTRA instancia de Opciones (poco probable, pero
## mantiene el comportamiento consistente con el resto de la interfaz reactiva
## al tema — GameRoot/NarrativeOverlay/ViewCombat).
func _on_theme_changed_live(_theme_id: String) -> void:
	_refresh_texts()
	_apply_theme()


## Repinta el panel del propio menú de Opciones y los rótulos de acento con
## los colores del tema activo antes se quedaban
## fijos al tema "default" hasta reabrir la ventana.
func _apply_theme() -> void:
	if _panel == null:
		return
	var accent := UiKit.theme_color("accent", UiKit.ACCENT)
	UiKit.premium_dialog_panel(_panel, accent, 26)
	if _title != null:
		_title.add_theme_color_override("font_color", accent)
	if _lbl_vol_value != null:
		_lbl_vol_value.add_theme_color_override("font_color", accent)
	if _lbl_access != null:
		_lbl_access.add_theme_color_override("font_color", accent)
	if _btn_to_menu != null:
		_btn_to_menu.add_theme_color_override("font_color", accent)
	if _btn_save != null:
		_btn_save.add_theme_color_override("font_color", accent)


func _on_save_game() -> void:
	var ok := SaveManager.save_game()
	if ok:
		UiKit.toast(
			self,
			Locale.pick({"es": "¡Partida guardada con éxito!", "en": "Game saved successfully!"}),
			Color(0.35, 0.9, 0.55)
		)
	else:
		UiKit.toast(
			self,
			Locale.pick({
				"es": "No se puede guardar dentro de una mazmorra. Usa \"Guardar y Salir\" para abandonarla.",
				"en": "Cannot save while inside a dungeon. Use \"Save and Exit\" to abandon it."
			}),
			UiKit.WARN
		)


func _set_orientation(target_landscape: bool) -> void:
	GlobalState.set_orientation(target_landscape)
	_refresh_texts()


func _on_volume_changed(value: float) -> void:
	Locale.set_master_volume(value)
	_lbl_vol_value.text = "%d%%" % int(round(value * 100.0))


func _on_font_scale_changed(value: float) -> void:
	Locale.set_font_scale(value)
	_lbl_font_scale.text = Locale.t("opt_font_scale", [int(round(Locale.font_scale * 100.0))])


func _on_text_speed_changed(value: float) -> void:
	Locale.set_text_speed(value)
	_lbl_text_speed.text = Locale.t("opt_text_speed", [int(round(Locale.text_speed * 100.0))])


## Confirmación visual inmediata al cambiar idioma (antes era
## un cambio silencioso de textos), mismo patrón de toast que Guardar Partida.
func _on_locale_selected(locale_id: String) -> void:
	if Locale.current == locale_id:
		return
	Locale.set_locale(locale_id)
	AudioManager.play_ui("select")
	# Tras el cambio, `Locale.current` ya es el nuevo idioma: el nombre del
	# idioma y el propio mensaje salen traducidos al idioma recién elegido.
	var lang_name := Locale.t("options_lang_%s" % locale_id)
	UiKit.toast(
		self,
		Locale.t("options_language_changed", [lang_name]),
		UiKit.ACCENT_SOFT
	)


func _on_toggle_reduce_motion() -> void:
	Locale.set_reduce_motion(not Locale.reduce_motion)
	_refresh_texts()


func _on_toggle_left_handed() -> void:
	Locale.set_left_handed(not Locale.left_handed)
	AudioManager.play_ui("select")
	_refresh_texts()


func _on_toggle_colorblind() -> void:
	Locale.set_colorblind(not Locale.colorblind)
	_refresh_texts()


# ══════════════════════════════════════════════════════════════════════════════
# CIERRE ANIMADO
# ══════════════════════════════════════════════════════════════════════════════
func close() -> void:
	if _closing:
		return
	_closing = true
	UiKit.animate_out(self, 0.18, func() -> void: closed.emit())


# ══════════════════════════════════════════════════════════════════════════════
# HELPERS DE ESTILO
# ══════════════════════════════════════════════════════════════════════════════
func _section_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", UiKit.TEXT)
	return l

func _divider() -> Control:
	var c := ColorRect.new()
	c.color = Color(1, 1, 1, 0.06)
	c.custom_minimum_size = Vector2(0, 2)
	return c

func _make_choice_button() -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", 32)
	return b

## Resalta (o no) un botón de elección. Lee del TEMA ACTIVO (`UiKit.theme_color`)
## en vez de las constantes fijas `UiKit.ACCENT`/`SURFACE_ALT`/`BORDER`/`TEXT_DIM`:
## antes, seleccionar un tema distinto de "default" dejaba el resaltado del
## propio menú de Opciones con los colores del tema anterior.
func _highlight(btn: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(14)
	s.set_content_margin_all(10)
	if active:
		# "highlight" el dorado/color de selección
		# del tema se reserva EXCLUSIVAMENTE para señalar el elemento
		# elegido/activo — "accent" (ahora azul en el tema por defecto) es el
		# color de marca general, no el de selección.
		var sel := UiKit.theme_color("highlight", UiKit.theme_color("accent", UiKit.ACCENT))
		s.bg_color = Color(sel.r, sel.g, sel.b, 0.20)
		s.border_color = sel
		s.set_border_width_all(2)
		btn.add_theme_color_override("font_color", sel)
	else:
		s.bg_color = UiKit.theme_color("panel_glass", UiKit.SURFACE_ALT)
		s.border_color = UiKit.theme_color("border", UiKit.BORDER)
		s.set_border_width_all(1)
		btn.add_theme_color_override("font_color", UiKit.theme_color("text_dim", UiKit.TEXT_DIM))
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus", s)
