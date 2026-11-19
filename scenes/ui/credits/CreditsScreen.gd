# CreditsScreen.gd
# Pantalla cinematográfica de créditos estilo película.
# Secuencia:
# 1. Título del juego ("Magic World") con fundido y zoom sutil.
# 2. Subtítulo canónico ("Basado en la Saga Esferas") con fundido cruzado.
# 3. Rodillo vertical cinematográfico de créditos (Hollywood style) con aceleración (Espacio/Click) y salto (ESC).
# 4. Al finalizar, retorno al mapamundi con gran mensaje solemne de la Esfera de la Verdad:
#    "Puedes continuar tu partida por si sientes que has olvidado algo por hacer."
class_name CreditsScreen
extends Control

## Emitida cuando el usuario cierra los créditos.
signal closed

## Si es true, al terminar muestra el mensaje de la Esfera para continuar explorando el mapamundi.
## Si es false (abierto desde el menú principal), simplemente vuelve al menú.
@export var show_post_game_prompt: bool = true

# Constantes de velocidad de desplazamiento
const SCROLL_SPEED_NORMAL: float = 62.0 # px/s
const SCROLL_SPEED_FAST: float = 420.0 # px/s

# ─── REFERENCIAS Y ESTADO ───────────────────────────────────────────────────
var _bg: ColorRect
var _title_card: Control
var _lbl_title: Label
var _engine_card: Control
var _engine_text_box: VBoxContainer
var _attribution_card: Control
var _attribution_text_box: VBoxContainer
var _lbl_attribution: Label
var _interactive_qr_cards: Array[Control] = []

var _roll_viewport: Control
var _roll_vbox: VBoxContainer

var _sphere_modal_layer: Control
var _sphere_panel: PanelContainer

var _phase: int = 0 # 0: init, 1: title, 2: engine, 3: attribution, 4: rolling, 5: sphere_modal, 6: closed
var _active_tween: Tween = null
var _scroll_y: float = 0.0
var _roll_total_height: float = 0.0
var _is_speeding_up: bool = false
var _is_rolling: bool = false
var _is_skipping: bool = false
var _prev_movement_locked: bool = false


func _ready() -> void:
	_prev_movement_locked = GlobalState.is_movement_locked
	GlobalState.is_movement_locked = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if AudioManager != null:
		AudioManager.play_music("event_crisis_puerto", 1.0)
	_build_ui()
	_start_sequence()


func _exit_tree() -> void:
	GlobalState.is_movement_locked = _prev_movement_locked
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LA INTERFAZ
# ══════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	# Fondo negro cinematográfico
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.02, 0.04, 1.0)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# ── 1. TARJETA DE TÍTULO ("Magic World") ──────────────────────────────────
	_title_card = Control.new()
	_title_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.modulate.a = 0.0
	add_child(_title_card)

	var title_center := CenterContainer.new()
	title_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_card.add_child(title_center)

	var title_box := VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 18)
	title_center.add_child(title_box)

	_lbl_title = Label.new()
	_lbl_title.text = Locale.t("app_title")
	if _lbl_title.text == "" or _lbl_title.text == "app_title":
		_lbl_title.text = "ECOS DE LA VERDAD"
	else:
		_lbl_title.text = _lbl_title.text.to_upper()
	_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_title.add_theme_font_size_override("font_size", 76)
	_lbl_title.add_theme_color_override("font_color", Color("#fbf5e6"))
	UiKit.apply_heading(_lbl_title)
	title_box.add_child(_lbl_title)

	var title_bar := ColorRect.new()
	title_bar.color = Color(0.85, 0.72, 0.38, 0.75)
	title_bar.custom_minimum_size = Vector2(340, 3)
	title_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_box.add_child(title_bar)

	# ── 2. TARJETA DEL MOTOR ("Creado con Taos Game Maker" + Códigos QR Itch.io y Gumroad) ──
	_engine_card = Control.new()
	_engine_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_engine_card.mouse_filter = Control.MOUSE_FILTER_PASS
	_engine_card.modulate.a = 0.0
	_engine_card.visible = false
	add_child(_engine_card)

	var eng_center := CenterContainer.new()
	eng_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eng_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_engine_card.add_child(eng_center)

	var eng_box := VBoxContainer.new()
	eng_box.alignment = BoxContainer.ALIGNMENT_CENTER
	eng_box.add_theme_constant_override("separation", 18)
	eng_box.mouse_filter = Control.MOUSE_FILTER_PASS
	eng_center.add_child(eng_box)

	# Bloque de textos del motor con animación sutil de zoom independiente
	_engine_text_box = VBoxContainer.new()
	_engine_text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_engine_text_box.add_theme_constant_override("separation", 10)
	_engine_text_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_engine_text_box.resized.connect(func() -> void:
		_engine_text_box.pivot_offset = _engine_text_box.size / 2.0
	)
	eng_box.add_child(_engine_text_box)

	var lbl_eng_badge := Label.new()
	lbl_eng_badge.text = "◆  " + Locale.t("splash_powered_by") + "  ◆"
	lbl_eng_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_eng_badge.add_theme_font_size_override("font_size", 16)
	lbl_eng_badge.add_theme_color_override("font_color", Color("#f59e0b"))
	UiKit.apply_heading(lbl_eng_badge)
	_engine_text_box.add_child(lbl_eng_badge)

	var lbl_eng_title := Label.new()
	lbl_eng_title.text = Locale.t("splash_engine_title")
	lbl_eng_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_eng_title.add_theme_font_size_override("font_size", 46)
	lbl_eng_title.add_theme_color_override("font_color", Color("#fcd34d"))
	lbl_eng_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl_eng_title.add_theme_constant_override("shadow_offset_y", 3)
	UiKit.apply_heading(lbl_eng_title)
	_engine_text_box.add_child(lbl_eng_title)

	var lbl_eng_tag := Label.new()
	lbl_eng_tag.text = Locale.t("splash_engine_tagline")
	lbl_eng_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_eng_tag.add_theme_font_size_override("font_size", 18)
	lbl_eng_tag.add_theme_color_override("font_color", Color("#a7adba"))
	_engine_text_box.add_child(lbl_eng_tag)

	var eng_div := HBoxContainer.new()
	eng_div.alignment = BoxContainer.ALIGNMENT_CENTER
	eng_div.add_theme_constant_override("separation", 16)
	_engine_text_box.add_child(eng_div)

	var eng_div_l := ColorRect.new()
	eng_div_l.custom_minimum_size = Vector2(140, 2)
	eng_div_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eng_div_l.color = Color(0.96, 0.62, 0.04, 0.45)
	eng_div.add_child(eng_div_l)

	var eng_div_mid := Label.new()
	eng_div_mid.text = "•  ◆  •"
	eng_div_mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eng_div_mid.add_theme_font_size_override("font_size", 15)
	eng_div_mid.add_theme_color_override("font_color", Color("#f59e0b"))
	eng_div.add_child(eng_div_mid)

	var eng_div_r := ColorRect.new()
	eng_div_r.custom_minimum_size = Vector2(140, 2)
	eng_div_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eng_div_r.color = Color(0.96, 0.62, 0.04, 0.45)
	eng_div.add_child(eng_div_r)

	var lbl_eng_cta := Label.new()
	lbl_eng_cta.text = Locale.pick({
		"es": "•  Crea tu propio juego RPG  •  Descarga el framework aquí  •",
		"en": "•  Create your own RPG  •  Get the framework here  •",
		"fr": "•  Créez votre propre RPG  •  Téléchargez le framework  •",
		"it": "•  Crea il tuo GDR  •  Scarica il framework qui  •",
		"de": "•  Erstelle dein eigenes RPG  •  Hole dir das Framework  •",
		"zh": "•  打造属于你的RPG游戏  •  在此获取框架  •",
		"ja": "•  自分だけのRPGを創ろう  •  フレームワークはこちら  •"
	})
	lbl_eng_cta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_eng_cta.add_theme_font_size_override("font_size", 18)
	lbl_eng_cta.add_theme_color_override("font_color", Color("#72d5ff"))
	_engine_text_box.add_child(lbl_eng_cta)

	# Fila de códigos QR FIJA (sin escalado ni movimiento para lectura óptima de cámara)
	var qr_row_eng := HBoxContainer.new()
	qr_row_eng.alignment = BoxContainer.ALIGNMENT_CENTER
	qr_row_eng.add_theme_constant_override("separation", 36)
	qr_row_eng.mouse_filter = Control.MOUSE_FILTER_PASS
	eng_box.add_child(qr_row_eng)

	var card_itch := _build_qr_card(
		"res://assets/common/ui/qr/qr_engine_itch.png",
		"Taos Game Maker",
		"https://taosworld.itch.io/taosgamemaker",
		"Itch.io Store"
	)
	var card_gumroad := _build_qr_card(
		"res://assets/common/ui/qr/qr_engine_gumroad.png",
		"Taos Game Maker",
		"https://taosworld.gumroad.com/l/taosgamemaker",
		"Gumroad Library"
	)
	qr_row_eng.add_child(card_itch)
	qr_row_eng.add_child(card_gumroad)

	var lbl_eng_skip := Label.new()
	lbl_eng_skip.text = Locale.pick({
		"es": "Escanea el código QR con tu móvil o haz clic en la tarjeta  •  Pulsa Espacio o Clic para continuar",
		"en": "Scan the QR code with your phone or click the card  •  Press Space or Click to continue",
		"fr": "Scannez le code QR avec votre téléphone ou cliquez  •  Appuyez sur Espace pour continuer",
		"it": "Scansiona il codice QR o clicca sulla scheda  •  Premi Spazio per continuare",
		"de": "QR-Code scannen oder Karte anklicken  •  Leertaste zum Fortfahren",
		"zh": "使用手机扫描二维码或点击卡片  •  按空格键继续",
		"ja": "QRコードをスキャンまたはカードをクリック  •  Spaceキーで次へ"
	})
	lbl_eng_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_eng_skip.add_theme_font_size_override("font_size", 13)
	lbl_eng_skip.add_theme_color_override("font_color", Color("#64748b"))
	eng_box.add_child(lbl_eng_skip)

	# ── 3. TARJETA DE OBRA LITERARIA ("Basado en Saga Lázaro" + Códigos QR Libros) ──
	_attribution_card = Control.new()
	_attribution_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_attribution_card.mouse_filter = Control.MOUSE_FILTER_PASS
	_attribution_card.modulate.a = 0.0
	_attribution_card.visible = false
	add_child(_attribution_card)

	var attr_center := CenterContainer.new()
	attr_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	attr_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_attribution_card.add_child(attr_center)

	var attr_box := VBoxContainer.new()
	attr_box.alignment = BoxContainer.ALIGNMENT_CENTER
	attr_box.add_theme_constant_override("separation", 18)
	attr_box.mouse_filter = Control.MOUSE_FILTER_PASS
	attr_center.add_child(attr_box)

	# Bloque de textos literarios con animación sutil de zoom independiente (QR codes 100% fijos)
	_attribution_text_box = VBoxContainer.new()
	_attribution_text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_attribution_text_box.add_theme_constant_override("separation", 10)
	_attribution_text_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_attribution_text_box.resized.connect(func() -> void:
		_attribution_text_box.pivot_offset = _attribution_text_box.size / 2.0
	)
	attr_box.add_child(_attribution_text_box)

	var lbl_nov_prefix := Label.new()
	lbl_nov_prefix.text = Locale.pick({
		"es": "Basado en la saga literaria",
		"en": "Based on the literary saga",
		"fr": "Basé sur la saga littéraire",
		"it": "Basato sulla saga letteraria",
		"de": "Basierend auf der Buchreihe",
		"zh": "改编自文学传奇",
		"ja": "文学サーガに基づく"
	})
	lbl_nov_prefix.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nov_prefix.add_theme_font_size_override("font_size", 19)
	lbl_nov_prefix.add_theme_color_override("font_color", Color("#e2e8f0"))
	_attribution_text_box.add_child(lbl_nov_prefix)

	_lbl_attribution = Label.new()
	_lbl_attribution.text = "« " + Locale.pick({
		"es": "SAGA LÁZARO",
		"en": "THE LAZARUS SAGA",
		"fr": "LA SAGA DE LAZARE",
		"it": "LA SAGA DI LAZZARO",
		"de": "DIE LAZARUS-SAGA",
		"zh": "拉撒路传奇",
		"ja": "ラザロ・サーガ"
	}) + " »"
	_lbl_attribution.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_attribution.add_theme_font_size_override("font_size", 38)
	_lbl_attribution.add_theme_color_override("font_color", Color("#fcd34d"))
	_lbl_attribution.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_lbl_attribution.add_theme_constant_override("shadow_offset_y", 3)
	UiKit.apply_heading(_lbl_attribution)
	_attribution_text_box.add_child(_lbl_attribution)

	var lbl_nov_author := Label.new()
	lbl_nov_author.text = Locale.pick({
		"es": "de José Manuel Heredia Reyes",
		"en": "by Jose Manuel Heredia Reyes",
		"fr": "par José Manuel Heredia Reyes",
		"it": "di José Manuel Heredia Reyes",
		"de": "von José Manuel Heredia Reyes",
		"zh": "何塞·曼努埃尔·埃雷迪亚·雷耶斯 著",
		"ja": "ホセ・マヌエル・エレディア・レジェス 著"
	})
	lbl_nov_author.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nov_author.add_theme_font_size_override("font_size", 17)
	lbl_nov_author.add_theme_color_override("font_color", Color("#94a3b8"))
	_attribution_text_box.add_child(lbl_nov_author)

	var attr_div := HBoxContainer.new()
	attr_div.alignment = BoxContainer.ALIGNMENT_CENTER
	attr_div.add_theme_constant_override("separation", 16)
	_attribution_text_box.add_child(attr_div)

	var div_l := ColorRect.new()
	div_l.custom_minimum_size = Vector2(140, 2)
	div_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	div_l.color = Color(0.96, 0.62, 0.04, 0.45)
	attr_div.add_child(div_l)

	var div_mid := Label.new()
	div_mid.text = "•  ◆  •"
	div_mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	div_mid.add_theme_font_size_override("font_size", 15)
	div_mid.add_theme_color_override("font_color", Color("#f59e0b"))
	attr_div.add_child(div_mid)

	var div_r := ColorRect.new()
	div_r.custom_minimum_size = Vector2(140, 2)
	div_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	div_r.color = Color(0.96, 0.62, 0.04, 0.45)
	attr_div.add_child(div_r)

	var lbl_qr_cta := Label.new()
	lbl_qr_cta.text = Locale.pick({
		"es": "•  Si deseas conocer el universo, comienza por aquí  •",
		"en": "•  To explore the universe, start your journey here  •",
		"fr": "•  Pour explorer cet univers, commencez ici  •",
		"it": "•  Per scoprire questo universo, inizia da qui  •",
		"de": "•  Um das Universum zu entdecken, beginne hier  •",
		"zh": "•  若想探索这个世界，请由此开启旅途  •",
		"ja": "•  この世界を知るなら、ここから始めよう  •"
	})
	lbl_qr_cta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_qr_cta.add_theme_font_size_override("font_size", 18)
	lbl_qr_cta.add_theme_color_override("font_color", Color("#72d5ff"))
	_attribution_text_box.add_child(lbl_qr_cta)

	var qr_row_books := HBoxContainer.new()
	qr_row_books.alignment = BoxContainer.ALIGNMENT_CENTER
	qr_row_books.add_theme_constant_override("separation", 36)
	qr_row_books.mouse_filter = Control.MOUSE_FILTER_PASS
	attr_box.add_child(qr_row_books)

	var is_es: bool = (Locale.current == "es")
	var qr1_tex: String = "res://assets/common/ui/qr/qr_libro1_es.png" if is_es else "res://assets/common/ui/qr/qr_libro1_en.png"
	var qr2_tex: String = "res://assets/common/ui/qr/qr_libro2_es.png" if is_es else "res://assets/common/ui/qr/qr_libro2_en.png"
	var book1_title: String = "Libro 1: La senda de Lázaro" if is_es else "Book 1: The Path of Lazarus"
	var book2_title: String = "Libro 2: El secreto de Lázaro" if is_es else "Book 2: The Secret of Lazarus"
	var book1_url: String = "https://www.amazon.es/dp/B0HLSQKMR1" if is_es else "https://www.amazon.es/dp/B0HMFQVSF2"
	var book2_url: String = "https://www.amazon.es/dp/B0HLSTMRWC" if is_es else "https://www.amazon.es/dp/B0HMF7GWZD"

	var card_book1 := _build_qr_card(qr1_tex, book1_title, book1_url, "Amazon Kindle & KDP")
	var card_book2 := _build_qr_card(qr2_tex, book2_title, book2_url, "Amazon Kindle & KDP")
	qr_row_books.add_child(card_book1)
	qr_row_books.add_child(card_book2)

	var lbl_book_skip := Label.new()
	lbl_book_skip.text = Locale.pick({
		"es": "Escanea el código QR con tu móvil o haz clic en la tarjeta  •  Pulsa Espacio o Clic para continuar",
		"en": "Scan the QR code with your phone or click the card  •  Press Space or Click to continue",
		"fr": "Scannez le code QR avec votre téléphone ou cliquez  •  Appuyez sur Espace pour continuer",
		"it": "Scansiona il codice QR o clicca sulla scheda  •  Premi Spazio per continuare",
		"de": "QR-Code mit dem Smartphone scannen  •  Leertaste zum Fortfahren",
		"zh": "使用手机扫描二维码或点击卡片  •  按空格键继续",
		"ja": "スマートフォンでQRコードをスキャン  •  Spaceキーで次へ"
	})
	lbl_book_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_book_skip.add_theme_font_size_override("font_size", 13)
	lbl_book_skip.add_theme_color_override("font_color", Color("#64748b"))
	attr_box.add_child(lbl_book_skip)

	# ── 3. CONTENEDOR DEL RODILLO VERTICAL DE CRÉDITOS ───────────────────────
	_roll_viewport = Control.new()
	_roll_viewport.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_roll_viewport.clip_contents = true
	_roll_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll_viewport.modulate.a = 0.0
	add_child(_roll_viewport)

	_roll_vbox = VBoxContainer.new()
	_roll_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_roll_vbox.add_theme_constant_override("separation", 36)
	_roll_viewport.add_child(_roll_vbox)

	_populate_credits_content()

	# ── 4. CAPA MODAL FINAL DE LA ESFERA DE LA VERDAD ────────────────────────
	_sphere_modal_layer = Control.new()
	_sphere_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sphere_modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_sphere_modal_layer.visible = false
	_sphere_modal_layer.modulate.a = 0.0
	add_child(_sphere_modal_layer)

	_build_sphere_modal()


# ══════════════════════════════════════════════════════════════════════════════
# CONSTRUCCIÓN DE LAS TARJETAS QR DE LOS LIBROS
# ══════════════════════════════════════════════════════════════════════════════
func _load_qr_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	var global_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(global_path):
		var img := Image.new()
		var err := img.load(path)
		if err == OK:
			return ImageTexture.create_from_image(img)
	return null


func _build_qr_card(tex_path: String, title_text: String, url: String, tag_text: String = "Amazon Kindle & KDP") -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(210, 240)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.13, 0.88)
	style.set_corner_radius_all(14)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.72, 0.38, 0.45)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# Marco blanco puro para el QR para garantizar máxima legibilidad en cámaras de móvil
	var qr_frame := PanelContainer.new()
	qr_frame.custom_minimum_size = Vector2(148, 148)
	qr_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	qr_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	frame_style.set_corner_radius_all(8)
	qr_frame.add_theme_stylebox_override("panel", frame_style)
	vbox.add_child(qr_frame)

	var qr_m := MarginContainer.new()
	qr_m.add_theme_constant_override("margin_left", 6)
	qr_m.add_theme_constant_override("margin_top", 6)
	qr_m.add_theme_constant_override("margin_right", 6)
	qr_m.add_theme_constant_override("margin_bottom", 6)
	qr_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qr_frame.add_child(qr_m)

	var qr_tex_rect := TextureRect.new()
	qr_tex_rect.texture = _load_qr_texture(tex_path)
	qr_tex_rect.custom_minimum_size = Vector2(136, 136)
	qr_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qr_m.add_child(qr_tex_rect)

	var lbl_b := Label.new()
	lbl_b.text = title_text
	lbl_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_b.add_theme_font_size_override("font_size", 15)
	lbl_b.add_theme_color_override("font_color", Color("#fcd34d"))
	vbox.add_child(lbl_b)

	var lbl_tag := Label.new()
	lbl_tag.text = tag_text
	lbl_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tag.add_theme_font_size_override("font_size", 12)
	lbl_tag.add_theme_color_override("font_color", Color("#94a3b8"))
	vbox.add_child(lbl_tag)

	# Al hacer clic sobre la tarjeta en PC/Web, abre directamente el enlace en el navegador
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			OS.shell_open(url)
	)

	_interactive_qr_cards.append(card)
	return card


func _is_mouse_over_qr_cards(pos: Vector2) -> bool:
	for card in _interactive_qr_cards:
		if card != null and is_instance_valid(card) and card.is_visible_in_tree():
			if card.get_global_rect().has_point(pos):
				return true
	return false


# ══════════════════════════════════════════════════════════════════════════════
# CONTENIDO DE LOS CRÉDITOS CINEMATOGRÁFICOS
# ══════════════════════════════════════════════════════════════════════════════
func _populate_credits_content() -> void:
	var sections := [
		{
			"header": {
				"es": "DIRECCIÓN Y GUION",
				"en": "DIRECTION & SCREENPLAY",
				"fr": "DIRECTION ET SCÉNARIO",
				"it": "REGIA E SCENEGGIATURA",
				"de": "REGIE UND DREHBUCH",
				"zh": "导演与编剧",
				"ja": "監督・脚本"
			},
			"items": [
				{
					"role": {
						"es": "Dirección General",
						"en": "General Direction",
						"fr": "Direction Générale",
						"it": "Direzione Generale",
						"de": "Gesamtleitung",
						"zh": "总导演",
						"ja": "総指揮"
					},
					"name": "JoseMHR"
				},
				{
					"role": {
						"es": "Guion Original y Narrativa",
						"en": "Original Story & Narrative",
						"fr": "Histoire Originale & Narration",
						"it": "Storia Originale e Narrativa",
						"de": "Originalgeschichte & Erzählung",
						"zh": "原创剧本与叙事",
						"ja": "オリジナル脚本・ストーリー"
					},
					"name": "JoseMHR"
				}
			]
		},
		{
			"header": {
				"es": "DISEÑO DE JUEGO Y SISTEMAS",
				"en": "GAME & SYSTEMS DESIGN",
				"fr": "GAME DESIGN & SYSTÈMES",
				"it": "GAME DESIGN E SISTEMI",
				"de": "SPIEL- & SYSTEMDESIGN",
				"zh": "游戏设计与系统",
				"ja": "ゲームデザイン＆システム"
			},
			"items": [
				{
					"role": {
						"es": "Sistema de Combate",
						"en": "Combat Design",
						"fr": "Système de Combat",
						"it": "Sistema di Combattimento",
						"de": "Kampfsystem",
						"zh": "战斗系统",
						"ja": "バトルシステム"
					},
					"name": "JoseMHR"
				},
				{
					"role": {
						"es": "Sistema de Mazmorras",
						"en": "Grid Dungeon System",
						"fr": "Système de Donjon en Grille",
						"it": "Sistema Dungeon a Griglia",
						"de": "Grid-Dungeon-System",
						"zh": "网格地牢系统",
						"ja": "グリッドダンジョンシステム"
					},
					"name": "JoseMHR"
				},
				{
					"role": {
						"es": "Sistema Narrativo",
						"en": "Narrative System",
						"fr": "Système Narratif",
						"it": "Sistema Narrativo",
						"de": "Erzählsystem",
						"zh": "叙事系统",
						"ja": "会話・イベントシステム"
					},
					"name": "JoseMHR"
				},
				{
					"role": {
						"es": "Sistema Mapamundi",
						"en": "Worldmap System",
						"fr": "Système de Carte du Monde",
						"it": "Sistema Mappa del Mondo",
						"de": "Weltkartensystem",
						"zh": "世界地图系统",
						"ja": "ワールドマップシステム"
					},
					"name": "JoseMHR"
				}
			]
		},
		{
			"header": {
				"es": "UNIVERSO Y NARRATIVA",
				"en": "UNIVERSE & LORE",
				"fr": "UNIVERS & NARRATION",
				"it": "UNIVERSO E NARRATIVA",
				"de": "UNIVERSUM & LORE",
				"zh": "世界观与背景",
				"ja": "世界観＆設定"
			},
			"items": [
				{
					"role": {
						"es": "Obra y Universo Original",
						"en": "Original Universe & Lore",
						"fr": "Univers et Œuvre Originaux",
						"it": "Opera e Universo Originale",
						"de": "Originalwerk & Universum",
						"zh": "原作与世界观",
						"ja": "原作・世界観"
					},
					"name": {
						"es": "Saga Lázaro (José Manuel Heredia Reyes)",
						"en": "The Lazarus Saga (Jose Manuel Heredia Reyes)",
						"fr": "La Saga de Lazare (José Manuel Heredia Reyes)",
						"it": "La Saga di Lazzaro (José Manuel Heredia Reyes)",
						"de": "Die Lazarus-Saga (José Manuel Heredia Reyes)",
						"zh": "《拉撒路传奇》（何塞·曼努埃尔·埃雷迪亚·雷耶斯 著）",
						"ja": "『ラザロ・サーガ』（ホセ・マヌエル・エレディア・レジェス 著）"
					}
				}
			]
		},
		{
			"header": {
				"es": "MOTOR Y TECNOLOGÍA",
				"en": "ENGINE & TECHNOLOGY",
				"fr": "MOTEUR & TECHNOLOGIE",
				"it": "MOTORE E TECNOLOGIA",
				"de": "ENGINE & TECHNOLOGIE",
				"zh": "引擎与技术",
				"ja": "エンジン＆技術"
			},
			"items": [
				{
					"role": {
						"es": "Framework y Suite del Editor",
						"en": "Framework & Editor Suite",
						"fr": "Framework & Suite Éditeur",
						"it": "Framework e Suite dell'Editor",
						"de": "Framework & Editor-Suite",
						"zh": "框架与编辑器套件",
						"ja": "フレームワーク＆エディタスイート"
					},
					"name": "Taos Game Maker"
				},
				{
					"role": {
						"es": "Motor Gráfico Base",
						"en": "Core Game Engine",
						"fr": "Moteur Graphique de Base",
						"it": "Motore Grafico di Base",
						"de": "Basis-Spiel-Engine",
						"zh": "底层游戏引擎",
						"ja": "ベースゲームエンジン"
					},
					"name": "Godot Engine 4.7"
				}
			]
		},
		{
			"header": {
				"es": "ARTE, ILUSTRACIÓN Y SONIDO",
				"en": "ART, ILLUSTRATION & AUDIO",
				"fr": "ART, ILLUSTRATION & AUDIO",
				"it": "ARTE, ILLUSTRAZIONE E AUDIO",
				"de": "GRAFIK, ILLUSTRATION & AUDIO",
				"zh": "美术、插画与音频",
				"ja": "アート・イラスト・音響"
			},
			"items": [
				{
					"role": {
						"es": "Fondos de Escenario",
						"en": "Setting & Background Art",
						"fr": "Décors d'Arrière-plan",
						"it": "Sfondi degli Ambienti",
						"de": "Hintergrundgrafiken",
						"zh": "场景与背景美术",
						"ja": "背景アート"
					},
					"name": "Gemini IA"
				},
				{
					"role": {
						"es": "Modelos 3D",
						"en": "3D Models",
						"fr": "Modèles 3D",
						"it": "Modelli 3D",
						"de": "3D-Modelle",
						"zh": "3D模型",
						"ja": "3Dモデル"
					},
					"name": "Gemini IA"
				},
				{
					"role": {
						"es": "Modelo 3D del Protagonista",
						"en": "Protagonist 3D Model",
						"fr": "Modèle 3D du Protagoniste",
						"it": "Modello 3D del Protagonista",
						"de": "3D-Modell des Protagonisten",
						"zh": "主角3D模型",
						"ja": "主人公3Dモデル"
					},
					"name": "Kay Lousberg"
				},
				{
					"role": {
						"es": "BGM de background",
						"en": "Background BGM",
						"fr": "BGM d'ambiance",
						"it": "BGM di sottofondo",
						"de": "Hintergrund-BGM",
						"zh": "背景音乐 (BGM)",
						"ja": "背景BGM"
					},
					"name": "Liborio Conti: no-copyright-music"
				}
			]
		},
		{
			"header": {
				"es": "TECNOLOGÍA",
				"en": "TECHNOLOGY",
				"fr": "TECHNOLOGIE",
				"it": "TECNOLOGIA",
				"de": "TECHNOLOGIE",
				"zh": "技术与引擎",
				"ja": "使用技術"
			},
			"items": [
				{
					"role": {
						"es": "Motor de Videojuego",
						"en": "Game Engine",
						"fr": "Moteur de Jeu",
						"it": "Motore di Gioco",
						"de": "Spiel-Engine",
						"zh": "游戏引擎",
						"ja": "ゲームエンジン"
					},
					"name": "Godot Engine 4 (GDScript)"
				},
				{
					"role": {
						"es": "Framework RPG",
						"en": "RPG Framework",
						"fr": "Framework RPG",
						"it": "Framework GDR",
						"de": "RPG-Framework",
						"zh": "RPG 框架",
						"ja": "RPG フレームワーク"
					},
					"name": "Taos Game Maker"
				}
			]
		},
		{
			"header": {
				"es": "DEDICATORIA Y AGRADECIMIENTOS",
				"en": "DEDICATION & SPECIAL THANKS",
				"fr": "DÉDICACE ET REMERCIEMENTS",
				"it": "DEDICA E RINGRAZIAMENTI",
				"de": "WIDMUNG & BESONDERER DANK",
				"zh": "献词与特别鸣谢",
				"ja": "謝辞＆スペシャルサンクス"
			},
			"items": [
				{
					"role": {
						"es": "Agradecimiento especial",
						"en": "Special Gratitude",
						"fr": "Remerciements Particuliers",
						"it": "Ringraziamento Speciale",
						"de": "Besonderer Dank",
						"zh": "特别感谢",
						"ja": "特別な感謝を込めて"
					},
					"name": {
						"es": "A todos los que hayan leído la Saga Lázaro",
						"en": "To everyone who has read The Lazarus Saga",
						"fr": "À tous ceux qui ont lu la Saga de Lazare",
						"it": "A tutti coloro che hanno letto la Saga di Lazzaro",
						"de": "An alle, die die Lazarus-Saga gelesen haben",
						"zh": "致所有阅读过《拉撒路传奇》的朋友们",
						"ja": "『ラザロ・サーガ』を読んでくださったすべての皆様へ"
					}
				}
			]
		}
	]

	# Espaciador inicial
	var pad_top := Control.new()
	pad_top.custom_minimum_size = Vector2(0, 40)
	_roll_vbox.add_child(pad_top)

	for sec in sections:
		var sec_header: String = Locale.pick(sec["header"])
		var lbl_h := Label.new()
		lbl_h.text = sec_header.to_upper()
		lbl_h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_h.add_theme_font_size_override("font_size", 24)
		lbl_h.add_theme_color_override("font_color", Color("#d8af56")) # Oro suave
		_roll_vbox.add_child(lbl_h)

		var divider := ColorRect.new()
		divider.color = Color(1, 1, 1, 0.12)
		divider.custom_minimum_size = Vector2(280, 2)
		divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_roll_vbox.add_child(divider)

		for item in sec["items"]:
			var item_box := VBoxContainer.new()
			item_box.alignment = BoxContainer.ALIGNMENT_CENTER
			item_box.add_theme_constant_override("separation", 4)

			var lbl_role := Label.new()
			lbl_role.text = Locale.pick(item["role"])
			lbl_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl_role.add_theme_font_size_override("font_size", 20)
			lbl_role.add_theme_color_override("font_color", Color("#8f9cb5")) # Gris azulado suave
			item_box.add_child(lbl_role)

			var lbl_name := Label.new()
			var raw_name = item["name"]
			var name_str: String = Locale.pick(raw_name) if raw_name is Dictionary else String(raw_name)
			lbl_name.text = name_str
			lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl_name.add_theme_font_size_override("font_size", 34 if name_str.length() < 35 else 26)
			lbl_name.add_theme_color_override("font_color", Color("#ffffff"))
			item_box.add_child(lbl_name)

			_roll_vbox.add_child(item_box)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 52)
		_roll_vbox.add_child(spacer)

	# Espaciador final
	var pad_bottom := Control.new()
	pad_bottom.custom_minimum_size = Vector2(0, 220)
	_roll_vbox.add_child(pad_bottom)


# ══════════════════════════════════════════════════════════════════════════════
# MODAL FINAL DE LA ESFERA DE LA VERDAD
# ══════════════════════════════════════════════════════════════════════════════
func _build_sphere_modal() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sphere_modal_layer.add_child(center)

	_sphere_panel = PanelContainer.new()
	_sphere_panel.custom_minimum_size = Vector2(760, 0)
	UiKit.premium_dialog_panel(_sphere_panel, Color("#4fc3f7"), 28, 0)
	center.add_child(_sphere_panel)

	var margin := UiKit.margins(48, 48, 40, 40)
	_sphere_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# Orbe flotante con brillo
	var orb_icon := Label.new()
	orb_icon.text = "◆"
	orb_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orb_icon.add_theme_font_size_override("font_size", 84)
	orb_icon.add_theme_color_override("font_color", Color("#72d5ff"))
	vbox.add_child(orb_icon)

	var pulse_tw := orb_icon.create_tween().set_loops()
	pulse_tw.tween_property(orb_icon, "modulate:a", 0.65, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(orb_icon, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Título
	var title_lbl := Label.new()
	title_lbl.text = Locale.pick({
		"es": "La Esfera de la Verdad",
		"en": "The Sphere of Truth",
		"fr": "La Sphère de la Vérité",
		"it": "La Sfera della Verità",
		"de": "Die Sphäre der Wahrheit",
		"zh": "真理之球",
		"ja": "真実の球体"
	})
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", Color("#72d5ff"))
	UiKit.apply_heading(title_lbl)
	vbox.add_child(title_lbl)

	# Mensaje solemne
	var msg_lbl := Label.new()
	msg_lbl.text = Locale.pick({
		"es": "«Puedes continuar tu partida por si sientes que has olvidado algo por hacer.»",
		"en": "«You may continue your journey in case you feel you have left something undone.»",
		"fr": "« Vous pouvez continuer votre voyage au cas où vous auriez oublié quelque chose. »",
		"it": "«Puoi continuare il tuo viaggio se senti di aver dimenticato qualcosa da fare.»",
		"de": "«Du kannst deine Reise fortsetzen, falls du das Gefühl hast, etwas vergessen zu haben.»",
		"zh": "“你可以继续你的旅程，以防你觉得还有未完成的心愿。”",
		"ja": "「まだやり残したことがあると感じるなら、旅を続けることができます。」"
	})
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_font_size_override("font_size", 26)
	msg_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	vbox.add_child(msg_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	# Botón para continuar
	var btn_continue := Button.new()
	btn_continue.text = Locale.pick({
		"es": "Continuar Partida",
		"en": "Continue Playing",
		"fr": "Continuer la Partie",
		"it": "Continua la Partita",
		"de": "Spiel Fortsetzen",
		"zh": "继续旅程",
		"ja": "冒険を続ける"
	})
	btn_continue.custom_minimum_size = Vector2(340, 72)
	btn_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_continue.add_theme_font_size_override("font_size", 26)
	UiKit.premium_button(btn_continue, {"corner_radius": 16.0, "border_width": 2.5})
	btn_continue.pressed.connect(_on_sphere_continue_pressed)
	vbox.add_child(btn_continue)


# ══════════════════════════════════════════════════════════════════════════════
# SECUENCIA CINEMATOGRÁFICA
# ══════════════════════════════════════════════════════════════════════════════
func _start_sequence() -> void:
	_phase = 1
	_play_title_card()


## Fase 1: Fundido y zoom suave del título
func _play_title_card() -> void:
	_title_card.modulate.a = 0.0
	_title_card.pivot_offset = get_viewport_rect().size / 2.0
	_title_card.scale = Vector2(0.96, 0.96)

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(_title_card, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_title_card, "scale", Vector2(1.03, 1.03), 4.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_active_tween.chain().tween_interval(1.8)
	_active_tween.chain().tween_property(_title_card, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.chain().tween_callback(func() -> void:
		_title_card.visible = false
		_phase = 2
		_play_engine_card()
	)


## Fase 2: "Creado con Taos Game Maker" y Códigos QR del motor (Itch.io y Gumroad)
func _play_engine_card() -> void:
	_engine_card.modulate.a = 0.0
	_engine_card.visible = true
	_engine_card.scale = Vector2.ONE

	if _engine_text_box != null:
		var txt_size := _engine_text_box.get_combined_minimum_size()
		if _engine_text_box.size.x > 0.0 and _engine_text_box.size.y > 0.0:
			txt_size = _engine_text_box.size
		_engine_text_box.pivot_offset = txt_size / 2.0
		_engine_text_box.scale = Vector2(0.96, 0.96)

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(_engine_card, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _engine_text_box != null:
		_active_tween.tween_property(_engine_text_box, "scale", Vector2(1.04, 1.04), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_active_tween.chain().tween_interval(8.0)
	_active_tween.chain().tween_property(_engine_card, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.chain().tween_callback(func() -> void:
		_engine_card.visible = false
		_phase = 3
		_play_attribution_card()
	)


## Fase 3: "Basado en Saga Lázaro" y Códigos QR de los libros
func _play_attribution_card() -> void:
	_attribution_card.modulate.a = 0.0
	_attribution_card.visible = true
	_attribution_card.scale = Vector2.ONE

	if _attribution_text_box != null:
		var txt_size := _attribution_text_box.get_combined_minimum_size()
		if _attribution_text_box.size.x > 0.0 and _attribution_text_box.size.y > 0.0:
			txt_size = _attribution_text_box.size
		_attribution_text_box.pivot_offset = txt_size / 2.0
		_attribution_text_box.scale = Vector2(0.96, 0.96)

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(_attribution_card, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _attribution_text_box != null:
		_active_tween.tween_property(_attribution_text_box, "scale", Vector2(1.04, 1.04), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_active_tween.chain().tween_interval(8.0)
	_active_tween.chain().tween_property(_attribution_card, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.chain().tween_callback(func() -> void:
		_attribution_card.visible = false
		_phase = 4
		_start_credits_roll()
	)


## Fase 4: Inicio del rodillo vertical de créditos
func _start_credits_roll() -> void:
	var viewport_h: float = get_viewport_rect().size.y
	if viewport_h <= 0.0:
		viewport_h = 1080.0

	var vp_w := get_viewport_rect().size.x
	if vp_w <= 0.0:
		vp_w = 1920.0

	var roll_w := minf(860.0, vp_w - 80.0)
	_roll_vbox.custom_minimum_size = Vector2(roll_w, 0)
	_roll_vbox.anchor_left = 0.5
	_roll_vbox.anchor_right = 0.5
	_roll_vbox.offset_left = - roll_w * 0.5
	_roll_vbox.offset_right = roll_w * 0.5

	# Espera un frame para calcular la altura total del contenido
	await get_tree().process_frame
	_roll_total_height = _roll_vbox.get_combined_minimum_size().y
	_scroll_y = viewport_h + 40.0
	_roll_vbox.position.y = _scroll_y

	_roll_viewport.modulate.a = 0.0
	_roll_viewport.visible = true

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(_roll_viewport, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)

	_is_rolling = true


func _process(delta: float) -> void:
	if not _is_rolling:
		return

	var speed := SCROLL_SPEED_FAST if _is_speeding_up else SCROLL_SPEED_NORMAL
	_scroll_y -= speed * delta
	_roll_vbox.position.y = _scroll_y

	# Comprueba si el rodillo ha salido completamente por la parte superior
	if _scroll_y < -_roll_total_height - 60.0:
		_is_rolling = false
		_on_roll_finished()


func _on_roll_finished() -> void:
	if _phase >= 5:
		return
	_phase = 5

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(_roll_viewport, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)

	if show_post_game_prompt:
		# Fundido sutil del fondo para vislumbrar el mapamundi detrás del modal
		_active_tween.tween_property(_bg, "color:a", 0.72, 1.2).set_trans(Tween.TRANS_SINE)
		_active_tween.chain().tween_callback(_show_sphere_prompt)
	else:
		_active_tween.chain().tween_property(_bg, "color:a", 0.0, 0.6)
		_active_tween.chain().tween_callback(_close_credits)


## Fase 5: Muestra el mensaje de la Esfera de la Verdad
func _show_sphere_prompt() -> void:
	_sphere_modal_layer.visible = true
	_sphere_modal_layer.modulate.a = 0.0

	UiKit.animate_in(_sphere_panel, 0.3)
	var tw := create_tween()
	tw.tween_property(_sphere_modal_layer, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)


func _on_sphere_continue_pressed() -> void:
	if AudioManager != null:
		AudioManager.play_sfx("main_menu_click")
	_close_credits()


func _skip_credits() -> void:
	if _is_skipping:
		return
	_is_skipping = true
	_is_rolling = false

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	if _title_card != null:
		_title_card.visible = false
	if _engine_card != null:
		_engine_card.visible = false
	if _attribution_card != null:
		_attribution_card.visible = false
	if _roll_viewport != null:
		_roll_viewport.visible = false

	if show_post_game_prompt:
		_phase = 5
		var tw := create_tween()
		tw.tween_property(_bg, "color:a", 0.72, 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_show_sphere_prompt)
	else:
		_close_credits()


func _close_credits() -> void:
	if _phase == 6:
		return
	_phase = 6
	GlobalState.is_movement_locked = _prev_movement_locked

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if AudioManager != null:
			if not show_post_game_prompt:
				AudioManager.play_music("menu", 1.0)
			else:
				AudioManager.play_music("world", 1.5)
		closed.emit()
		queue_free()
	)


# ══════════════════════════════════════════════════════════════════════════════
# ENTRADAS DE TECLADO / RATÓN (Acelerar y Omitir)
# NOTA CRÍTICA: Se usa _input() en lugar de _unhandled_input() para interceptar
# y consumir absolutamente todas las teclas y clics antes de que cualquier
# elemento del mapamundi (como el botón Entrar o hotkeys) pueda recibirlas.
# ══════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if not visible or _phase >= 6:
		return

	# ESC: Omitir créditos inmediatamente
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_skip_credits()
		return

	# Modal de la Esfera (Fase 5): Espacio o Enter pulsan el botón de continuar
	if _phase == 5:
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			get_viewport().set_input_as_handled()
			_on_sphere_continue_pressed()
			return
		return

	# Fases de tarjetas iniciales (1: título, 2: motor, 3: saga): Espacio / Enter / Clic avanza a la siguiente tarjeta
	if _phase < 4:
		# Si en Fase 2 o 3 se hace clic sobre las tarjetas QR, dejamos que su gui_input abra el enlace en el navegador
		if (_phase == 2 or _phase == 3) and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _is_mouse_over_qr_cards(event.position):
				return

		if (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			get_viewport().set_input_as_handled()
			if _active_tween != null and _active_tween.is_valid():
				_active_tween.kill()
			if _phase == 1:
				_title_card.visible = false
				_phase = 2
				_play_engine_card()
			elif _phase == 2:
				_engine_card.visible = false
				_phase = 3
				_play_attribution_card()
			elif _phase == 3:
				_attribution_card.visible = false
				_phase = 4
				_start_credits_roll()
			return
		elif event is InputEventKey or event is InputEventMouseButton:
			# Consumir cualquier otra tecla/clic para aislar completamente el fondo
			get_viewport().set_input_as_handled()
			return

	# Fase de rodillo (4): Mantener Espacio / Enter / Flecha Abajo / Clic acelera el scroll
	if _phase == 4:
		if event is InputEventKey:
			if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_DOWN]:
				_is_speeding_up = event.pressed
				get_viewport().set_input_as_handled()
			else:
				# Bloquear cualquier otra tecla (hotkeys de inventario, mapa, etc.)
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_is_speeding_up = event.pressed
			get_viewport().set_input_as_handled()
