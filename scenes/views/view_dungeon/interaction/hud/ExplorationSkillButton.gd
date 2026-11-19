# ExplorationSkillButton.gd
# ─────────────────────────────────────────────────────────────────────────────
# BOTÓN CIRCULAR DE HABILIDAD DE EXPLORACIÓN
#
# Botón redondo dibujado a mano para el anillo hexagonal del HUD móvil. Muestra:
#   · color y glifo de la habilidad,
#   · barrido de ENFRIAMIENTO (pastel oscuro que se vacía en sentido horario),
#   · halo de "listo" pulsante cuando puede usarse,
#   · estado BLOQUEADO (candado gris) y SIN ENERGÍA (atenuado),
#   · estado ACTIVO (borde intenso) para habilidades tipo toggle.
#
# Hereda de Button para reutilizar su gestión de entrada (ratón + táctil), pero
# reemplaza por completo el dibujado. Emite `activated(skill_id)` al pulsarse.
# ─────────────────────────────────────────────────────────────────────────────
class_name ExplorationSkillButton
extends Button

## Emitida al pulsar el botón (si no está bloqueado).
signal activated(skill_id: String)

var skill_id: String = ""
var base_color: Color = Color(0.6, 0.6, 0.6)
var glyph: String = "?"

var _unlocked: bool = false
var _ready_to_use: bool = false
var _active: bool = false
var _cooldown_ratio: float = 0.0   # 1 = recién usada, 0 = lista
var _cooldown_left: float = 0.0    # segundos restantes
var _pulse: float = 0.0            # fase de animación del halo
var _target_match: bool = false    # el objeto apuntado acepta el verbo de esta habilidad
var _tutorial_highlight: bool = false  # resaltado activo del tutorial de mazmorra


var icon_texture: Texture2D = null


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	pressed.connect(_on_pressed)


## Configura la identidad visual del botón.
func setup(id: String, color: Color, symbol: String, diameter: float, icon_path: String = "") -> void:
	skill_id = id
	base_color = color
	glyph = symbol
	if icon_path != "":
		icon_texture = UiKit.load_texture_safe(icon_path)
	elif ResourceLoader.exists("res://assets/dungeon/skills/%s.png" % id):
		icon_texture = UiKit.load_texture_safe("res://assets/dungeon/skills/%s.png" % id)
	custom_minimum_size = Vector2(diameter, diameter)
	size = Vector2(diameter, diameter)
	queue_redraw()


## Cambia el diámetro sin tocar icono/color/glifo (más ligero que `setup`);
## lo usa el HUD para el boost de tamaño en retrato. `_draw()` lee `size` en
## cada redibujado, así que todo (glifo, icono, candado, anillos) escala solo.
func set_diameter(diameter: float) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	size = Vector2(diameter, diameter)
	queue_redraw()


## Actualiza el estado dinámico (lo llama el HUD cada frame). `target_match` indica
## que el objeto apuntado por el jugador acepta el verbo de esta habilidad.
func set_state(unlocked: bool, ready_to_use: bool, cooldown_ratio: float, cooldown_left: float, active: bool, target_match: bool = false, tutorial_highlight: bool = false) -> void:
	var clamped_cd := clampf(cooldown_ratio, 0.0, 1.0)
	var changed := (_unlocked != unlocked or _ready_to_use != ready_to_use or absf(_cooldown_ratio - clamped_cd) > 0.001 or absf(_cooldown_left - cooldown_left) > 0.05 or _active != active or _target_match != target_match or _tutorial_highlight != tutorial_highlight)
	_unlocked = unlocked
	_ready_to_use = ready_to_use
	_cooldown_ratio = clamped_cd
	_cooldown_left = maxf(0.0, cooldown_left)
	_active = active
	_target_match = target_match
	_tutorial_highlight = tutorial_highlight
	disabled = not unlocked
	if changed:
		queue_redraw()


func _process(delta: float) -> void:
	if _ready_to_use or _target_match or _tutorial_highlight or _cooldown_ratio > 0.001 or _cooldown_left > 0.0:
		_pulse = fmod(_pulse + delta * 3.5, TAU)
		queue_redraw()

	if _tutorial_highlight:
		pivot_offset = size * 0.5
		var s := 1.0 + 0.16 * (0.5 + 0.5 * sin(_pulse * 2.2))
		scale = Vector2(s, s)
	elif scale != Vector2.ONE:
		scale = Vector2.ONE


func _on_pressed() -> void:
	if _unlocked:
		activated.emit(skill_id)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5

	# Halo "listo": anillo exterior pulsante.
	if _unlocked and _ready_to_use:
		var glow := 0.35 + 0.25 * (0.5 + 0.5 * sin(_pulse))
		draw_arc(c, r + 3.0, 0.0, TAU, 40, Color(base_color.r, base_color.g, base_color.b, glow), 6.0, true)

	# Énfasis de OBJETIVO: si el objeto apuntado acepta esta habilidad, un anillo
	# blanco pulsante externo indica "esta habilidad tendría efecto aquí".
	if _unlocked and _target_match:
		var em := 0.5 + 0.4 * (0.5 + 0.5 * sin(_pulse))
		draw_arc(c, r + 8.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, em), 3.5, true)

	# Resaltado TUTORIAL ESPECTACULAR: efecto masivo con rayos estelares y múltiples
	# anillos concéntricos brillantes para llamar la atención del jugador.
	if _unlocked and _tutorial_highlight:
		var tut_em := 0.5 + 0.5 * sin(_pulse * 2.2)
		# 1. Rayos estelares giratorios de energía
		var ray_count := 8
		var ray_rot := _pulse * 1.4
		for i in range(ray_count):
			var a := ray_rot + float(i) * (TAU / float(ray_count))
			var inner_p := c + Vector2(cos(a), sin(a)) * (r + 4.0)
			var outer_p := c + Vector2(cos(a), sin(a)) * (r + 28.0 + 10.0 * tut_em)
			draw_line(inner_p, outer_p, Color(base_color.r, base_color.g, base_color.b, 0.45 + 0.45 * tut_em), 4.5, true)

		# 2. Múltiples anillos concéntricos pulsantes (dorado / color base / blanco)
		draw_arc(c, r + 8.0, 0.0, TAU, 56, Color(base_color.r, base_color.g, base_color.b, 0.95), 7.0, true)
		draw_arc(c, r + 18.0 + 6.0 * tut_em, 0.0, TAU, 56, Color(1.0, 0.88, 0.4, 0.9 * tut_em), 5.0, true)
		draw_arc(c, r + 26.0 + 10.0 * tut_em, 0.0, TAU, 56, Color(1.0, 1.0, 1.0, 0.7 * tut_em), 3.0, true)

	# Fondo del botón.
	var fill := base_color
	if not _unlocked:
		fill = Color(0.16, 0.16, 0.20)
	elif _held():
		fill = base_color.lightened(0.25)
	var bg := Color(fill.r, fill.g, fill.b, 0.50 if _unlocked else 0.45)
	draw_circle(c, r, bg)

	# Glifo / textura de imagen / candado (DIBUJADO ANTES del sombreado de cooldown).
	var on_cooldown := _unlocked and _cooldown_left > 0.001
	if not _unlocked:
		# Dibujo vectorial de candado clásico y estilizado (independiente de fuentes/plataformas)
		var lock_w := r * 0.44
		var lock_h := r * 0.36
		var body_rect := Rect2(c.x - lock_w * 0.5, c.y - lock_h * 0.1, lock_w, lock_h)
		draw_rect(body_rect, Color(0.72, 0.68, 0.58, 0.70), true)
		var shackle_r := lock_w * 0.30
		var shackle_c := Vector2(c.x, c.y - lock_h * 0.1)
		draw_arc(shackle_c, shackle_r, PI, TAU, 24, Color(0.72, 0.68, 0.58, 0.70), 2.5, true)
		draw_circle(Vector2(c.x, c.y + lock_h * 0.08), lock_w * 0.09, Color(0.12, 0.12, 0.15, 0.90))
	elif icon_texture != null:
		var tex_size := Vector2(r * 1.35, r * 1.35)
		var tex_rect := Rect2(c - tex_size * 0.5, tex_size)
		var mod := Color(0.50, 0.50, 0.55, 0.75) if on_cooldown else (Color(1, 1, 1, 0.95 if _ready_to_use else 0.65))
		draw_texture_rect(icon_texture, tex_rect, false, mod)
	else:
		var font := get_theme_default_font()
		var fsize := int(r * 1.0)
		var text_col := Color(0.6, 0.6, 0.65, 0.75) if on_cooldown else (Color(1, 1, 1, 0.95 if _ready_to_use else 0.65))
		var tsize := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var ascent := font.get_ascent(fsize)
		var descent := font.get_descent(fsize)
		var glyph_pos := Vector2(c.x - tsize.x * 0.5, c.y + (ascent - descent) * 0.5)
		draw_string(font, glyph_pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, text_col)

	# Borde del botón.
	var border := Color(fill.r, fill.g, fill.b, 0.95) if _unlocked else Color(0.45, 0.42, 0.35, 0.50)
	var border_w := 4.0 if _active else (2.5 if _unlocked else 2.0)
	draw_arc(c, r - border_w * 0.5, 0.0, TAU, 48, border, border_w, true)

	# Barrido de enfriamiento (pastel oscuro y borde radial SOBRE el icono).
	if on_cooldown:
		var pts := PackedVector2Array([c])
		var start := -PI * 0.5
		var end := start + TAU * _cooldown_ratio
		var steps := maxi(2, int(48 * _cooldown_ratio))
		for i in range(steps + 1):
			var a := start + (end - start) * (float(i) / steps)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color(0.01, 0.01, 0.04, 0.70))
		
		# Línea de barrido brillante en el filo
		var edge_p := c + Vector2(cos(end), sin(end)) * r
		draw_line(c, edge_p, Color(1.0, 1.0, 1.0, 0.65), 2.0, true)

		# Contador numérico de segundos (formato 10.4, 5.2, 1.2)
		var font := get_theme_default_font()
		var fsize := int(r * 0.58)
		var txt := "%.1f" % _cooldown_left
		var tsize := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
		var text_pos := Vector2(c.x - tsize.x * 0.5, c.y + font.get_ascent(fsize) * 0.35)

		# Sombra / borde negro para máxima legibilidad
		for off in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5), Vector2(0, 2)]:
			draw_string(font, text_pos + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.0, 0.0, 0.0, 0.95))

		# Texto numérico principal brillante
		draw_string(font, text_pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1.0, 0.95, 0.82, 1.0))


## ¿Está el botón siendo pulsado ahora mismo?
func _held() -> bool:
	return get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
