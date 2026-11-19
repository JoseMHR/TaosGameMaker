class_name ResonanceCircle
extends CenterContainer
## Círculo de resonancia del HUD de combate: dibuja un arco de progreso circular
## (púrpura) que se vuelve dorado y muestra "LISTO" cuando la resonancia está cargada.

var value: float = 0.0
var max_value: float = 100.0
var is_resonant: bool = false
var text_label: Label
# Colores temáticos (se asignan desde ViewCombat con _theme_color).
var track_color: Color = Color(0.12, 0.08, 0.2, 0.8)
var fill_color: Color = Color(0.65, 0.25, 0.85)
var resonant_color: Color = Color(1.0, 0.85, 0.2)
var outer_border_color: Color = Color(0.4, 0.3, 0.6, 0.35)
var normal_text_color: Color = Color(0.9, 0.85, 0.95)
var resonant_text_color: Color = Color(1.0, 0.85, 0.2)
# (Game Feel §3): pulso muy suave mientras la resonancia está LISTA,
# para que se sienta viva y no como una imagen estática. Se detiene solo al
# dejar de estar resonante (p. ej. al consumirla en el siguiente turno).
var _pulse_tween: Tween

func _init() -> void:
	custom_minimum_size = Vector2(90, 90)
	pivot_offset = custom_minimum_size * 0.5
	text_label = Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 16)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(text_label)

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 6.0

	# Dibujar el fondo del círculo (pista)
	draw_arc(center, radius, 0.0, TAU, 64, track_color, 6.0, true)

	# Dibujar el arco de progreso
	var pct := value / max_value
	var angle := pct * TAU
	var color := fill_color if not is_resonant else resonant_color

	# Empezar a dibujar arriba (North) -> -PI/2.0
	if angle > 0.0:
		draw_arc(center, radius, -PI/2.0, -PI/2.0 + angle, 64, color, 8.0, true)

	# Dibujar un borde exterior decorativo fino
	draw_arc(center, radius + 5.0, 0.0, TAU, 64, outer_border_color, 1.0, true)

signal resonance_max_reached

func set_resonance(v: float, max_v: float, resonant: bool) -> void:
	value = v
	max_value = max_v
	var was_resonant := is_resonant
	is_resonant = resonant
	if resonant:
		text_label.text = "LISTO"
		text_label.add_theme_color_override("font_color", resonant_text_color)
		text_label.add_theme_font_size_override("font_size", 14)
	else:
		text_label.text = "%d%%" % int(value)
		text_label.add_theme_color_override("font_color", normal_text_color)
		text_label.add_theme_font_size_override("font_size", 16)
	queue_redraw()
	if resonant and not was_resonant:
		_start_pulse()
		resonance_max_reached.emit()
	elif not resonant and was_resonant:
		_stop_pulse()


## Pulso muy suave (escala 1.0↔1.06) en bucle mientras la resonancia esté lista.
func _start_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if Locale.reduce_motion:
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	scale = Vector2.ONE
