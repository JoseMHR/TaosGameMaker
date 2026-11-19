class_name DefenseImpactRing
extends Control
## INDICADOR DE ANILLO DE IMPACTO — QTE de defensa (task_reforma_defensa.md, FASE 2).
##
## Sustituye a la antigua franja de parry dibujada sobre la pequeña barra ATB
## del enemigo: se proyecta directamente sobre el pecho del héroe durante el
## "bullet-time" de reacción (`ViewCombat._enter_bullet_time`). Dibuja, de
## fuera hacia dentro:
##   1. Banda "normal" (translúcida, color de tema "accent"): rango de ATB en
##      el que `DEFENDER` mitiga daño de forma correcta.
##   2. Banda "perfecta" (translúcida, color de tema "highlight"): sub-rango
##      interior en el que `DEFENDER` logra un Parry Perfecto.
##   3. Diana Central: círculo dorado fijo de 40×40px (el objetivo exacto).
##   4. Anillo de Inserción: aro brillante que se CIERRA progresivamente desde
##      el radio máximo hasta coincidir con la Diana Central en el instante del
##      impacto (`set_progress`, llamado cada frame desde `CombatTurnEngine`).
##
## `top_level = true`: su posición en pantalla es fija (fijada una vez al
## generarse sobre el pecho del héroe) e independiente de cualquier tween local
## del sprite del héroe (respiración, agazapamiento de defensa...), para que el
## anillo no "baile" junto al personaje.

var target_radius: float = 30.0
var perfect_radius: float = 35.0
var normal_radius: float = 90.0
var max_radius: float = 165.0
var current_radius: float = 165.0

var color_target: Color = Color(1.0, 0.85, 0.25, 0.95)
var color_perfect: Color = Color(1.0, 0.85, 0.25, 0.55)
var color_normal: Color = Color(0.35, 0.72, 0.95, 0.35)
var color_closing: Color = Color(1.0, 1.0, 1.0, 0.9)


func _init() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50


## Fija la geometría (radios en px) y la paleta de colores del anillo.
## `colors` admite las claves "target"/"perfect"/"normal"/"closing" (todas
## opcionales; se conserva el color por defecto si se omiten).
func configure(p_target_radius: float, p_perfect_radius: float, p_normal_radius: float, p_max_radius: float, colors: Dictionary = {}) -> void:
	target_radius = p_target_radius
	perfect_radius = p_perfect_radius
	normal_radius = p_normal_radius
	max_radius = p_max_radius
	current_radius = p_max_radius
	color_target = colors.get("target", color_target)
	color_perfect = colors.get("perfect", color_perfect)
	color_normal = colors.get("normal", color_normal)
	color_closing = colors.get("closing", color_closing)
	custom_minimum_size = Vector2(max_radius, max_radius) * 2.0
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()


## Centra el anillo (en coordenadas GLOBALES) sobre `chest_global_pos`.
func center_on(chest_global_pos: Vector2) -> void:
	global_position = chest_global_pos - size * 0.5


## `t` en [0,1]: 1.0 = recién entrado en la ventana de reacción (anillo grande,
## lejos de la diana), 0.0 = instante exacto del impacto (anillo == diana).
func set_progress(t: float) -> void:
	current_radius = lerp(target_radius, max_radius, clampf(t, 0.0, 1.0))
	queue_redraw()


func get_current_radius() -> float:
	return current_radius


func _draw() -> void:
	var center := size * 0.5

	# Banda normal (donut translúcido entre la diana y el radio normal).
	if normal_radius > perfect_radius + 0.5:
		var mid_n := (normal_radius + perfect_radius) * 0.5
		draw_arc(center, mid_n, 0.0, TAU, 64, color_normal, normal_radius - perfect_radius, true)

	# Banda perfecta (donut translúcido, más angosta, justo fuera de la diana).
	if perfect_radius > target_radius + 0.5:
		var mid_p := (perfect_radius + target_radius) * 0.5
		draw_arc(center, mid_p, 0.0, TAU, 48, color_perfect, perfect_radius - target_radius, true)

	# Diana Central: círculo dorado fijo + borde luminoso.
	draw_circle(center, target_radius, color_target)
	draw_arc(center, target_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.8), 2.0, true)

	# Anillo de Inserción (se cierra hacia la diana): más brillante e intenso
	# cuanto más cerca está del impacto, para acentuar la tensión del instante.
	var closeness := 1.0 - clampf((current_radius - target_radius) / max(max_radius - target_radius, 0.001), 0.0, 1.0)
	var closing_col := color_closing
	closing_col.a = lerp(color_closing.a * 0.6, 1.0, closeness)
	draw_arc(center, current_radius, 0.0, TAU, 48, closing_col, lerp(3.0, 5.0, closeness), true)


## Feedback final y autodestrucción según la calidad del bloqueo obtenido:
## "perfect" (expansión dorada + fundido rápido), "normal" (pulso cian suave)
## o cualquier otro valor ("miss"/""), que se desvanece sin celebración.
func resolve(quality: String) -> void:
	if Locale.reduce_motion:
		queue_free()
		return
	var tw := create_tween()
	match quality:
		"perfect":
			tw.set_parallel(true)
			tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "modulate:a", 0.0, 0.26)
		"normal":
			tw.set_parallel(true)
			tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "modulate:a", 0.0, 0.2)
		_:
			tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(queue_free)
