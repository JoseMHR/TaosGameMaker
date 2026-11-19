## LoadingScreen.gd
## ─────────────────────────────────────────────────────────────────────────────
## Pantalla de carga asíncrona a pantalla completa con fondo negro sólido,
## consejos de juego destacados en tamaño grande y estado de carga en la esquina
## inferior derecha.
class_name LoadingScreen
extends Control

const TIPS: Array[Dictionary] = [
	{"es": "Usa el Parry en el momento exacto para mitigar el 90% del daño recibido.", "en": "Use Parry at the exact moment to mitigate 90% of incoming damage."},
	{"es": "Cada profesión cuenta con 4 habilidades activas: encadénalas para desatar poderosas sinergias.", "en": "Each profession has 4 active skills: chain them together to unleash powerful synergies."},
	{"es": "Alcanzar la Sintonía máxima desbloquea una ranura adicional en la cola de combate.", "en": "Reaching maximum Attunement unlocks an extra slot in the combat action queue."},
	{"es": "Utiliza las Habilidades de Exploración para superar y abrir obstáculos en mazmorras y mapamundi.", "en": "Use Exploration Skills to overcome and unlock obstacles in dungeons and overworld."},
	{"es": "El hielo te hace resbalar en línea recta, pero la nieve es firme. ¡Observa bien el terreno!", "en": "Ice makes you slide in a straight line, but snow is firm. Watch the ground closely!"},
	{"es": "Puedes descansar en el campamento o guardar tu progreso desde el menú en cualquier momento.", "en": "You can rest at camp or save your progress from the menu at any time."},
	{"es": "Pulsa sobre el avatar de tu héroe en combate para cambiar de profesión al instante.", "en": "Tap your hero's avatar in combat to switch professions instantly."},
	{"es": "Recoge recursos por el mundo para forjar equipo legendario y preparar pociones.", "en": "Gather resources across the world to craft legendary gear and brew potions."},
	{"es": "Las debilidades elementales multiplican el impacto de tus hechizos y técnicas.", "en": "Elemental weaknesses multiply the impact of your spells and techniques."},
]

var _bar: ProgressBar = null
var _lbl_percent: Label = null
var _lbl_loading: Label = null
var _lbl_tip_title: Label = null
var _lbl_tip_text: Label = null
var _tip_card: PanelContainer = null
var _tip_timer: Timer = null
var _tip_index: int = -1
var _dots_timer: float = 0.0
var _target_progress: float = 0.0
var _current_progress: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 4096

	# 1. Fondo negro sólido opaco (oculta al 100% el menú/escena anterior)
	var bg_solid := ColorRect.new()
	bg_solid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_solid.color = Color(0.03, 0.03, 0.05, 1.0)
	add_child(bg_solid)

	# Gradiente sutil / viñeta para dar profundidad
	var bg_ambient := ColorRect.new()
	bg_ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_ambient.color = Color(0.05, 0.04, 0.08, 0.45)
	add_child(bg_ambient)

	# 2. Contenedor principal
	var main_margin := MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 64)
	main_margin.add_theme_constant_override("margin_right", 64)
	main_margin.add_theme_constant_override("margin_top", 64)
	main_margin.add_theme_constant_override("margin_bottom", 56)
	add_child(main_margin)

	var layout_box := Control.new()
	layout_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.add_child(layout_box)

	# 3. ZONA CENTRAL: Tip / Consejo bien grande y legible
	_tip_card = PanelContainer.new()
	_tip_card.anchor_left = 0.5
	_tip_card.anchor_top = 0.5
	_tip_card.anchor_right = 0.5
	_tip_card.anchor_bottom = 0.5
	_tip_card.offset_left = -480
	_tip_card.offset_top = -140
	_tip_card.offset_right = 480
	_tip_card.offset_bottom = 100
	_tip_card.custom_minimum_size = Vector2(960, 200)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.07, 0.06, 0.10, 0.88)
	card_style.set_corner_radius_all(14)
	card_style.set_border_width_all(2)
	card_style.border_color = Color(0.85, 0.70, 0.32, 0.45)
	card_style.content_margin_left = 36
	card_style.content_margin_right = 36
	card_style.content_margin_top = 28
	card_style.content_margin_bottom = 28
	card_style.shadow_color = Color(0, 0, 0, 0.7)
	card_style.shadow_size = 18
	card_style.shadow_offset = Vector2(0, 8)
	_tip_card.add_theme_stylebox_override("panel", card_style)
	layout_box.add_child(_tip_card)

	var tip_vbox := VBoxContainer.new()
	tip_vbox.add_theme_constant_override("separation", 12)
	_tip_card.add_child(tip_vbox)

	_lbl_tip_title = Label.new()
	_lbl_tip_title.text = "💡  " + Locale.pick({"es": "CONSEJO", "en": "HINT"}).to_upper()
	_lbl_tip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_tip_title.add_theme_font_size_override("font_size", 16)
	_lbl_tip_title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.35))
	_lbl_tip_title.add_theme_constant_override("outline_size", 2)
	_lbl_tip_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl_tip_title.add_theme_font_override("font", UiKit.theme_font())
	tip_vbox.add_child(_lbl_tip_title)

	_lbl_tip_text = Label.new()
	_lbl_tip_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_tip_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_tip_text.add_theme_font_size_override("font_size", 24)
	_lbl_tip_text.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	_lbl_tip_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_lbl_tip_text.add_theme_constant_override("shadow_offset_x", 1)
	_lbl_tip_text.add_theme_constant_override("shadow_offset_y", 2)
	_lbl_tip_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tip_vbox.add_child(_lbl_tip_text)

	# 4. ESQUINA INFERIOR DERECHA: Loading en grande y barra elegante
	var bottom_right_box := VBoxContainer.new()
	bottom_right_box.anchor_left = 1.0
	bottom_right_box.anchor_top = 1.0
	bottom_right_box.anchor_right = 1.0
	bottom_right_box.anchor_bottom = 1.0
	bottom_right_box.offset_left = -440
	bottom_right_box.offset_top = -120
	bottom_right_box.offset_right = 0
	bottom_right_box.offset_bottom = 0
	bottom_right_box.alignment = BoxContainer.ALIGNMENT_END
	bottom_right_box.add_theme_constant_override("separation", 10)
	layout_box.add_child(bottom_right_box)

	var text_row := HBoxContainer.new()
	text_row.alignment = BoxContainer.ALIGNMENT_END
	text_row.add_theme_constant_override("separation", 14)
	bottom_right_box.add_child(text_row)

	_lbl_loading = Label.new()
	_lbl_loading.text = Locale.pick({"es": "Cargando…", "en": "Loading…"})
	_lbl_loading.add_theme_font_size_override("font_size", 28)
	_lbl_loading.add_theme_color_override("font_color", Color(0.98, 0.92, 0.82))
	_lbl_loading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_lbl_loading.add_theme_constant_override("shadow_offset_x", 2)
	_lbl_loading.add_theme_constant_override("shadow_offset_y", 2)
	_lbl_loading.add_theme_font_override("font", UiKit.theme_font())
	text_row.add_child(_lbl_loading)

	_lbl_percent = Label.new()
	_lbl_percent.custom_minimum_size.x = 70
	_lbl_percent.text = "0%"
	_lbl_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_percent.add_theme_font_size_override("font_size", 24)
	_lbl_percent.add_theme_color_override("font_color", Color(0.98, 0.82, 0.35))
	_lbl_percent.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_lbl_percent.add_theme_constant_override("shadow_offset_x", 1)
	_lbl_percent.add_theme_constant_override("shadow_offset_y", 1)
	_lbl_percent.add_theme_font_override("font", UiKit.theme_font())
	text_row.add_child(_lbl_percent)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(420, 14)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.07, 0.12, 0.9)
	bar_bg.set_corner_radius_all(7)
	bar_bg.set_border_width_all(1)
	bar_bg.border_color = Color(0.85, 0.70, 0.32, 0.4)
	_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.96, 0.78, 0.28)
	bar_fill.set_corner_radius_all(7)
	_bar.add_theme_stylebox_override("fill", bar_fill)
	bottom_right_box.add_child(_bar)

	# 5. Timer de rotación de consejos
	_tip_timer = Timer.new()
	_tip_timer.wait_time = 4.5
	_tip_timer.autostart = true
	_tip_timer.timeout.connect(_show_next_tip)
	add_child(_tip_timer)
	_show_next_tip()


func _process(delta: float) -> void:
	# Suavizado de la barra de progreso
	_current_progress = lerpf(_current_progress, _target_progress, delta * 10.0)
	if _bar != null:
		_bar.value = _current_progress
	if _lbl_percent != null:
		_lbl_percent.text = "%d%%" % int(round(_current_progress * 100.0))

	# Animación de puntos en "Cargando..."
	_dots_timer += delta * 2.8
	var dot_count: int = (int(_dots_timer) % 3) + 1
	var dots := ".".repeat(dot_count)
	var base_word := Locale.pick({"es": "Cargando", "en": "Loading"})
	if _lbl_loading != null:
		_lbl_loading.text = "%s%s" % [base_word, dots]


## Actualiza el porcentaje objetivo de carga. `p` en [0.0, 1.0].
func set_progress(p: float) -> void:
	_target_progress = clampf(p, 0.0, 1.0)


func _show_next_tip() -> void:
	if _lbl_tip_text == null or TIPS.is_empty():
		return
	var next := _tip_index
	if TIPS.size() > 1:
		while next == _tip_index:
			next = randi() % TIPS.size()
	else:
		next = 0
	_tip_index = next

	# Transición suave de texto
	var tw := create_tween()
	tw.tween_property(_lbl_tip_text, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		_lbl_tip_text.text = Locale.pick(TIPS[_tip_index])
	)
	tw.tween_property(_lbl_tip_text, "modulate:a", 1.0, 0.25)
