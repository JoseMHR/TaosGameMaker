# SplashScreen.gd
# ─────────────────────────────────────────────────────────────────────────────
# Pantalla cinemática de apertura previa al menú principal.
# Destaca dos propósitos clave del proyecto:
# 1. Promoción del Framework / Motor: "Creado con Taos Game Maker"
# 2. Promoción de la Obra Literaria: "Basado en la novela El secreto de Lázaro"
#
# Cuenta con animación fluida mediante Tweens, partículas de ambiente, soporte
# multilingüe completo a través de Locale, y opción de salto instantáneo (skip).
# ─────────────────────────────────────────────────────────────────────────────
class_name SplashScreen
extends Control

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/main_menu/MainMenu.tscn"

# Fuentes principales del juego
const FONT_CINZEL_PATH: String = "res://assets/common/fonts/Cinzel.ttf"
const FONT_GARAMOND_PATH: String = "res://assets/common/fonts/EBGaramond.ttf"

# Nodos visuales
var _bg_rect: ColorRect
var _particles: CPUParticles2D
var _ambient_glow: TextureRect
var _main_margin: MarginContainer
var _content_box: VBoxContainer

# Bloque 1: Motor / Framework
var _box_engine: VBoxContainer
var _lbl_engine_badge: Label
var _lbl_engine_title: Label
var _lbl_engine_tagline: Label

# Separador Ornamental
var _divider_box: HBoxContainer
var _line_left: ColorRect
var _ornament_center: Label
var _line_right: ColorRect

# Bloque 2: Novela
var _box_novel: VBoxContainer
var _lbl_novel_prefix: Label
var _lbl_novel_title: Label
var _lbl_novel_author: Label

# Indicador de salto y fundido final
var _lbl_skip_hint: Label
var _fade_overlay: ColorRect

# Aviso exclusivo para versión Web
static var force_web_notice: bool = false
var _web_notice_container: Control = null
var _web_notice_card: PanelContainer = null
var _is_web_notice_active: bool = false
var _web_notice_shown: bool = false

# Estado de animación
var _main_tween: Tween = null
var _is_transitioning: bool = false
var _font_cinzel: FontFile = null
var _font_garamond: FontFile = null


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	if SceneManager != null:
		SceneManager.go_to_splash()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_load_fonts()
	_build_ui()
	_start_animation_sequence()

	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()


func _exit_tree() -> void:
	if _main_tween != null and _main_tween.is_valid():
		_main_tween.kill()


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if _is_web_notice_active:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			var key_event := event as InputEventKey
			var kc: Key = key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
			if kc == KEY_SPACE or kc == KEY_ENTER or kc == KEY_KP_ENTER:
				_dismiss_web_notice()
				return
		if event is InputEventJoypadButton and event.is_pressed():
			_dismiss_web_notice()
			return
		return

	# Solo permitir saltar con Espacio, Intro (Enter/KP_Enter), Escape o botón de Gamepad (ignora clicks)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event := event as InputEventKey
		var kc: Key = key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
		if kc == KEY_SPACE or kc == KEY_ENTER or kc == KEY_KP_ENTER or kc == KEY_ESCAPE:
			_skip_to_menu()
			return

	if event is InputEventJoypadButton and event.is_pressed():
		_skip_to_menu()
		return


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _load_fonts() -> void:
	if ResourceLoader.exists(FONT_CINZEL_PATH):
		_font_cinzel = load(FONT_CINZEL_PATH) as FontFile
		if _font_cinzel != null:
			UiKit.ensure_font_cjk_fallback(_font_cinzel)
	if ResourceLoader.exists(FONT_GARAMOND_PATH):
		_font_garamond = load(FONT_GARAMOND_PATH) as FontFile
		if _font_garamond != null:
			UiKit.ensure_font_cjk_fallback(_font_garamond)


func _build_ui() -> void:
	# 1. Fondo atmosférico oscuro
	_bg_rect = ColorRect.new()
	_bg_rect.name = "Background"
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color(0.025, 0.027, 0.035, 1.0)
	add_child(_bg_rect)

	# 2. Resplandor radial central (halo celestial)
	_ambient_glow = TextureRect.new()
	_ambient_glow.name = "AmbientGlow"
	_ambient_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ambient_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ambient_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_ambient_glow.modulate = Color(1.0, 0.85, 0.45, 0.07)
	_ambient_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	grad_tex.width = 512
	grad_tex.height = 512
	_ambient_glow.texture = grad_tex
	add_child(_ambient_glow)

	# 3. Partículas sutiles de polvo de estrellas / ascuas mágicas
	_particles = CPUParticles2D.new()
	_particles.name = "AmbientStardust"
	_particles.amount = 35
	_particles.lifetime = 6.0
	_particles.preprocess = 2.0
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(960, 540)
	_particles.gravity = Vector2(0, -14)
	_particles.initial_velocity_min = 6.0
	_particles.initial_velocity_max = 18.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 3.5
	_particles.color = Color(1.0, 0.88, 0.55, 0.35)
	_particles.position = Vector2(960, 540)
	add_child(_particles)

	# 4. Contenedor central principal
	_main_margin = MarginContainer.new()
	_main_margin.name = "MainMargin"
	_main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_margin.add_theme_constant_override("margin_left", 60)
	_main_margin.add_theme_constant_override("margin_right", 60)
	_main_margin.add_theme_constant_override("margin_top", 40)
	_main_margin.add_theme_constant_override("margin_bottom", 40)
	add_child(_main_margin)

	var center_box := CenterContainer.new()
	center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_margin.add_child(center_box)

	_content_box = VBoxContainer.new()
	_content_box.name = "ContentBox"
	_content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_box.add_theme_constant_override("separation", 28)
	_content_box.custom_minimum_size = Vector2(800, 0)
	center_box.add_child(_content_box)

	# ── BLOQUE 1: MOTOR / FRAMEWORK ──
	_box_engine = VBoxContainer.new()
	_box_engine.name = "BoxEngine"
	_box_engine.alignment = BoxContainer.ALIGNMENT_CENTER
	_box_engine.add_theme_constant_override("separation", 8)
	_content_box.add_child(_box_engine)

	_lbl_engine_badge = Label.new()
	_lbl_engine_badge.text = Locale.t("splash_powered_by")
	_lbl_engine_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_engine_badge.add_theme_font_size_override("font_size", 16)
	_lbl_engine_badge.add_theme_color_override("font_color", Color("#f59e0b"))
	if _font_cinzel != null:
		_lbl_engine_badge.add_theme_font_override("font", _font_cinzel)
	_box_engine.add_child(_lbl_engine_badge)

	_lbl_engine_title = Label.new()
	_lbl_engine_title.text = Locale.t("splash_engine_title")
	_lbl_engine_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_engine_title.add_theme_font_size_override("font_size", 68)
	_lbl_engine_title.add_theme_color_override("font_color", Color("#fcd34d"))
	_lbl_engine_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_lbl_engine_title.add_theme_constant_override("shadow_offset_x", 0)
	_lbl_engine_title.add_theme_constant_override("shadow_offset_y", 4)
	if _font_cinzel != null:
		_lbl_engine_title.add_theme_font_override("font", _font_cinzel)
	_box_engine.add_child(_lbl_engine_title)

	_lbl_engine_tagline = Label.new()
	_lbl_engine_tagline.text = Locale.t("splash_engine_tagline")
	_lbl_engine_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_engine_tagline.add_theme_font_size_override("font_size", 22)
	_lbl_engine_tagline.add_theme_color_override("font_color", Color("#a7adba"))
	if _font_garamond != null:
		_lbl_engine_tagline.add_theme_font_override("font", _font_garamond)
	_box_engine.add_child(_lbl_engine_tagline)

	# ── SEPARADOR ORNAMENTAL ──
	_divider_box = HBoxContainer.new()
	_divider_box.name = "DividerBox"
	_divider_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_divider_box.add_theme_constant_override("separation", 16)
	_content_box.add_child(_divider_box)

	_line_left = ColorRect.new()
	_line_left.custom_minimum_size = Vector2(160, 2)
	_line_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_line_left.color = Color(0.96, 0.62, 0.04, 0.45)
	_divider_box.add_child(_line_left)

	_ornament_center = Label.new()
	_ornament_center.text = "•  ◆  •"
	_ornament_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ornament_center.add_theme_font_size_override("font_size", 18)
	_ornament_center.add_theme_color_override("font_color", Color("#f59e0b"))
	_divider_box.add_child(_ornament_center)

	_line_right = ColorRect.new()
	_line_right.custom_minimum_size = Vector2(160, 2)
	_line_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_line_right.color = Color(0.96, 0.62, 0.04, 0.45)
	_divider_box.add_child(_line_right)

	# ── BLOQUE 2: NOVELA Y UNIVERSO NARRATIVO ──
	_box_novel = VBoxContainer.new()
	_box_novel.name = "BoxNovel"
	_box_novel.alignment = BoxContainer.ALIGNMENT_CENTER
	_box_novel.add_theme_constant_override("separation", 8)
	_content_box.add_child(_box_novel)

	_lbl_novel_prefix = Label.new()
	_lbl_novel_prefix.text = Locale.t("splash_book_prefix")
	_lbl_novel_prefix.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_novel_prefix.add_theme_font_size_override("font_size", 24)
	_lbl_novel_prefix.add_theme_color_override("font_color", Color("#e2e8f0"))
	if _font_garamond != null:
		_lbl_novel_prefix.add_theme_font_override("font", _font_garamond)
	_box_novel.add_child(_lbl_novel_prefix)

	_lbl_novel_title = Label.new()
	_lbl_novel_title.text = "« " + Locale.t("splash_book_title") + " »"
	_lbl_novel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_novel_title.add_theme_font_size_override("font_size", 48)
	_lbl_novel_title.add_theme_color_override("font_color", Color("#fcd34d"))
	_lbl_novel_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_lbl_novel_title.add_theme_constant_override("shadow_offset_x", 0)
	_lbl_novel_title.add_theme_constant_override("shadow_offset_y", 3)
	if _font_cinzel != null:
		_lbl_novel_title.add_theme_font_override("font", _font_cinzel)
	_box_novel.add_child(_lbl_novel_title)

	_lbl_novel_author = Label.new()
	_lbl_novel_author.text = Locale.t("splash_author")
	_lbl_novel_author.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_novel_author.add_theme_font_size_override("font_size", 20)
	_lbl_novel_author.add_theme_color_override("font_color", Color("#94a3b8"))
	if _font_garamond != null:
		_lbl_novel_author.add_theme_font_override("font", _font_garamond)
	_box_novel.add_child(_lbl_novel_author)

	# ── HINT DE SALTO (INFERIOR) ──
	_lbl_skip_hint = Label.new()
	_lbl_skip_hint.name = "LblSkipHint"
	_lbl_skip_hint.text = Locale.t("splash_skip_hint")
	_lbl_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_skip_hint.add_theme_font_size_override("font_size", 14)
	_lbl_skip_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.45))
	if _font_garamond != null:
		_lbl_skip_hint.add_theme_font_override("font", _font_garamond)
	_lbl_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_lbl_skip_hint.position.y -= 36
	add_child(_lbl_skip_hint)

	# ── CAPA DE FUNDIDO FINAL ──
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_overlay.color = Color(0, 0, 0, 0.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)


func _on_viewport_size_changed() -> void:
	if not is_inside_tree():
		return
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	if _particles != null:
		_particles.position = vp_size * 0.5
		_particles.emission_rect_extents = vp_size * 0.5

	if _box_engine != null:
		_box_engine.pivot_offset = _box_engine.size * 0.5
	if _divider_box != null:
		_divider_box.pivot_offset = _divider_box.size * 0.5
	if _box_novel != null:
		_box_novel.pivot_offset = _box_novel.size * 0.5

	if _lbl_skip_hint != null:
		_lbl_skip_hint.size.x = vp_size.x
		_lbl_skip_hint.position = Vector2(0, vp_size.y - 48)

	if _web_notice_card != null and is_instance_valid(_web_notice_card):
		_web_notice_card.custom_minimum_size.x = minf(740.0, vp_size.x - 40.0)


# ══════════════════════════════════════════════════════════════════════════════
# SECUENCIA DE ANIMACIÓN Y TRANSICIÓN
# ══════════════════════════════════════════════════════════════════════════════
func _start_animation_sequence() -> void:
	# Estado inicial: oculto
	_box_engine.modulate.a = 0.0
	_divider_box.modulate.a = 0.0
	_box_novel.modulate.a = 0.0
	_lbl_skip_hint.modulate.a = 0.0

	# Escalas iniciales (efecto breathing zoom suave)
	_box_engine.scale = Vector2(0.95, 0.95)
	_divider_box.scale = Vector2(0.05, 1.0)
	_box_novel.scale = Vector2(0.95, 0.95)

	# Sonido suave de bienvenida
	if AudioManager != null:
		AudioManager.play_sfx("skill_instinto")

	_main_tween = create_tween()

	# ── PASO 1: Aparición majestuosa de "Creado con Taos Game Maker" (0.0s -> 1.1s)
	_main_tween.tween_interval(0.2)
	_main_tween.parallel().tween_property(_box_engine, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_main_tween.parallel().tween_property(_box_engine, "scale", Vector2(1.0, 1.0), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Aparición discreta del recordatorio de salto (skip)
	_main_tween.parallel().tween_property(_lbl_skip_hint, "modulate:a", 0.5, 1.2).set_delay(0.8)

	# ── PASO 2: Despliegue del separador ornamental áureo (1.5s -> 2.1s)
	_main_tween.tween_interval(0.4)
	_main_tween.parallel().tween_property(_divider_box, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_main_tween.parallel().tween_property(_divider_box, "scale:x", 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# ── PASO 3: Agregado elegante de "Basado en la novela El secreto de Lázaro" (2.1s -> 3.3s)
	_main_tween.parallel().tween_property(_box_novel, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_main_tween.parallel().tween_property(_box_novel, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# ── PASO 4: Tiempo de lectura y contemplación para ambas promociones (3.3s -> 7.5s)
	_main_tween.tween_interval(4.2)

	# ── PASO 5: Fundido cinemático a negro y transición al Menú Principal (5.5s -> 6.3s)
	_main_tween.tween_property(_fade_overlay, "color:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_main_tween.tween_callback(_goto_main_menu)


func _skip_to_menu() -> void:
	if _is_transitioning or _is_web_notice_active:
		return
	_is_transitioning = true

	if _main_tween != null and _main_tween.is_valid():
		_main_tween.kill()

	if AudioManager != null:
		AudioManager.play_sfx("click")

	# Fundido rápido a negro en 0.25 segundos
	var skip_tween := create_tween()
	skip_tween.tween_property(_fade_overlay, "color:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	skip_tween.tween_callback(_goto_main_menu)


func _goto_main_menu() -> void:
	if (OS.has_feature("web") or force_web_notice) and not _web_notice_shown:
		_show_web_notice()
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _show_web_notice() -> void:
	if _web_notice_shown:
		return
	_web_notice_shown = true
	_is_web_notice_active = true
	_is_transitioning = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Atenuar fundido previo si se saltó con tecla
	if _fade_overlay != null:
		var tw_fade := create_tween()
		tw_fade.tween_property(_fade_overlay, "color:a", 0.0, 0.25)

	# Ocultar los textos de presentación para centrar en el aviso
	if _main_margin != null:
		_main_margin.visible = false
	if _lbl_skip_hint != null:
		_lbl_skip_hint.visible = false

	_build_web_notice_ui()


func _build_web_notice_ui() -> void:
	_web_notice_container = Control.new()
	_web_notice_container.name = "WebNoticeContainer"
	_web_notice_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_web_notice_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_web_notice_container.modulate.a = 0.0
	add_child(_web_notice_container)

	# Fondo oscurecido para centrar la atención sobre la tarjeta
	var dim_bg := ColorRect.new()
	dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_bg.color = Color(0.015, 0.018, 0.025, 0.78)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_web_notice_container.add_child(dim_bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_web_notice_container.add_child(center)

	_web_notice_card = PanelContainer.new()
	_web_notice_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var vp_w := get_viewport_rect().size.x
	_web_notice_card.custom_minimum_size = Vector2(minf(760.0, vp_w - 40.0 if vp_w > 0.0 else 760.0), 0)
	UiKit.premium_dialog_panel(_web_notice_card, UiKit.COLOR_GOLD_PRIMARY, 22, 0)
	center.add_child(_web_notice_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	_web_notice_card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# 1. Badge superior estilo píldora
	var badge_box := HBoxContainer.new()
	badge_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(badge_box)

	var badge_panel := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(UiKit.COLOR_GOLD_PRIMARY.r, UiKit.COLOR_GOLD_PRIMARY.g, UiKit.COLOR_GOLD_PRIMARY.b, 0.16)
	b_style.border_color = UiKit.COLOR_GOLD_PRIMARY
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(12)
	b_style.content_margin_left = 16
	b_style.content_margin_right = 16
	b_style.content_margin_top = 5
	b_style.content_margin_bottom = 5
	badge_panel.add_theme_stylebox_override("panel", b_style)

	var badge_lbl := Label.new()
	badge_lbl.text = Locale.pick({
		"es": "🌐  MODO NAVEGADOR WEB",
		"en": "🌐  WEB BROWSER MODE",
		"fr": "🌐  MODE NAVIGATEUR WEB",
		"it": "🌐  MODALITÀ BROWSER WEB",
		"de": "🌐  WEB-BROWSER-MODUS",
		"zh": "🌐  网页浏览器模式",
		"ja": "🌐  ウェブブラウザモード"
	})
	badge_lbl.add_theme_font_size_override("font_size", 14)
	badge_lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY)
	badge_panel.add_child(badge_lbl)
	badge_box.add_child(badge_panel)

	# 2. Título de aviso
	var title_lbl := Label.new()
	title_lbl.text = Locale.pick({
		"es": "AVISO DE RENDIMIENTO",
		"en": "PERFORMANCE NOTICE",
		"fr": "AVIS DE PERFORMANCE",
		"it": "AVVISO SULLE PRESTAZIONI",
		"de": "LEISTUNGSHINWEIS",
		"zh": "性能与加载提示",
		"ja": "パフォーマンスに関するお知らせ"
	})
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	if _font_cinzel != null:
		title_lbl.add_theme_font_override("font", _font_cinzel)
	vbox.add_child(title_lbl)

	# Separador dorado
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(UiKit.COLOR_GOLD_PRIMARY.r, UiKit.COLOR_GOLD_PRIMARY.g, UiKit.COLOR_GOLD_PRIMARY.b, 0.35)
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# 3. Mensaje descriptivo
	var msg_lbl := Label.new()
	msg_lbl.text = Locale.pick({
		"es": "Estás ejecutando la versión web del juego directamente en tu navegador.\n\nTen en cuenta que en la versión web el procesamiento de polígonos y escenas 3D es más exigente: las cargas pueden tardar más de lo habitual y ciertas texturas podrían mostrarse con calidad o resolución reducida para garantizar un rendimiento fluido y estable.",
		"en": "You are running the web version of the game directly in your browser.\n\nPlease note that web environments require heavier processing for 3D polygons and environments: loading may take longer than usual and certain textures may appear at reduced quality or resolution to ensure smooth and stable performance.",
		"fr": "Vous jouez à la version web du jeu directement dans votre navigateur.\n\nVeuillez noter que le traitement des polygones et scènes 3D est plus exigeant dans un navigateur : les chargements peuvent être plus longs et certaines textures peuvent présenter une qualité réduite afin d'assurer une expérience fluide et stable.",
		"it": "Stai giocando alla versione web direttamente nel tuo browser.\n\nTieni presente che gli ambienti web richiedono maggiori risorse per elaborare poligoni e scene 3D: i caricamenti potrebbero richiedere più tempo e alcune texture potrebbero avere una qualità ridotta per garantire un'esperienza fluida e stabile.",
		"de": "Du spielst die Webversion des Spiels direkt im Browser.\n\nBitte beachte, dass die Verarbeitung von 3D-Polygonen und Szenen im Web anspruchsvoller ist: Ladezeiten können länger ausfallen und manche Texturen erscheinen mit reduzierter Qualität, um ein flüssiges und stabiles Spielerlebnis zu sichern.",
		"zh": "您正在浏览器中直接运行本游戏的网页版。\n\n请注意，网页环境在渲染3D多边形与场景时需要更多处理资源：场景加载可能会比平时稍慢，且部分纹理可能会降低画质或分辨率，以确保游玩过程流畅稳定。",
		"ja": "現在ブラウザ上でWeb版のゲームをプレイしています。\n\nWeb環境では3Dポリゴンや空間の描画処理が重くなるため、ロードに時間がかかったり、滑らかで安定した動作を維持するために一部テクスチャの画質や解像度が制限される場合があります。"
	})
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.add_theme_font_size_override("font_size", 18)
	msg_lbl.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98))
	if _font_garamond != null:
		msg_lbl.add_theme_font_override("font", _font_garamond)
	vbox.add_child(msg_lbl)

	# 4. Consejo / Recomendación
	var tip_lbl := Label.new()
	tip_lbl.text = Locale.pick({
		"es": "💡 Recomendación: cierra otras pestañas del navegador para liberar memoria gráfica.",
		"en": "💡 Tip: close other browser tabs to free up GPU memory.",
		"fr": "💡 Conseil : fermez les autres onglets pour libérer de la mémoire graphique.",
		"it": "💡 Suggerimento: chiudi le altre schede del browser per liberare memoria grafica.",
		"de": "💡 Tipp: Schließe andere Browser-Tabs, um Grafikspeicher freizugeben.",
		"zh": "💡 建议：关闭其他浏览器标签页以释放显存与内存。",
		"ja": "💡 ヒント: 他のブラウザタブを閉じるとグラフィックメモリが解放され、より快適になります。"
	})
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.add_theme_font_size_override("font_size", 14)
	tip_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 0.75))
	if _font_garamond != null:
		tip_lbl.add_theme_font_override("font", _font_garamond)
	vbox.add_child(tip_lbl)

	# 5. Botón de confirmación / continuar
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_box)

	var btn := Button.new()
	btn.text = "✨  " + Locale.pick({
		"es": "ENTENDIDO · CONTINUAR",
		"en": "UNDERSTOOD · CONTINUE",
		"fr": "COMPRIS · CONTINUER",
		"it": "HO CAPITO · CONTINUA",
		"de": "VERSTANDEN · WEITER",
		"zh": "明白了 · 继续",
		"ja": "了解 · 続ける"
	})
	btn.custom_minimum_size = Vector2(320, 56)
	btn.add_theme_font_size_override("font_size", 18)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiKit.premium_button(btn, {"border_width": 2.0, "corner_radius": 14.0})
	btn.pressed.connect(_dismiss_web_notice)
	btn_box.add_child(btn)

	# Animación de entrada suave
	var tw := create_tween()
	tw.tween_property(_web_notice_container, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	UiKit.pop(_web_notice_card, 1.04, 0.25)


func _dismiss_web_notice() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	if AudioManager != null:
		AudioManager.play_sfx("click")

	var tw := create_tween()
	if _web_notice_container != null:
		tw.tween_property(_web_notice_container, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _fade_overlay != null:
		tw.parallel().tween_property(_fade_overlay, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	)
