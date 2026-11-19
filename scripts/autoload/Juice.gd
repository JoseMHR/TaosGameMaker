# Juice.gd
# ─────────────────────────────────────────────────────────────────────────────
# SERVICIO DE "JUICE" (game feel) — Autoload/Singleton
#
# Punto ÚNICO y reutilizable para el feedback sensorial del juego: hit-stop,
# sacudida de pantalla (screen-shake), destello (flash), "pop" de UI y números
# de daño flotantes. Cualquier sistema (combate, mazmorra, mundo) lo invoca sin
# reimplementar tweens a mano, garantizando coherencia.
#
# ACCESIBILIDAD: respeta `Locale.reduce_motion`. Cuando está activo, los efectos
# de movimiento (shake, hit-stop, pop) se anulan o suavizan; el contenido
# informativo (números de daño, flash tenue) se mantiene para no perder claridad.
#
# Filosofía del proyecto: reutilizable, desacoplado y data-lite (sin dependencias
# duras). Se usa como `Juice.func(...)` (autoload global).
# ─────────────────────────────────────────────────────────────────────────────
extends Node

# ─── Parámetros por defecto (ajustables desde las llamadas) ──────────────────
const HITSTOP_SCALE: float   = 0.05   # time_scale durante el hit-stop
const SHAKE_DECAY: float     = 1.0    # cuánto decae la sacudida por segundo

# Estado interno del hit-stop para evitar solapamientos que dejen el tiempo lento.
var _hitstop_active: bool = false

# ─── Overlay de fundido a negro y pantalla de carga ──────────────────────────
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _loading_center: CenterContainer
var _loading_card: PanelContainer
var _loading_spinner: Control
var _loading_divider: Control
var _loading_title: Label
var _loading_subtitle: Label
var _loading_web_tip: Label
var _loading_web_badge: PanelContainer
var _loading_web_icon: Control = null
var _spinner_angle: float = 0.0
var _loading_active: bool = false
var _loading_card_tween: Tween = null


func _ready() -> void:
	# Capa siempre por encima de todo para los fundidos y pantallas de carga entre vistas.
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 128
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE   # transparente => no bloquea
	_fade_layer.add_child(_fade_rect)

	_build_loading_ui()


func _build_loading_ui() -> void:
	_loading_center = CenterContainer.new()
	_loading_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_center.visible = false
	_loading_center.modulate.a = 0.0
	_fade_layer.add_child(_loading_center)

	# Tarjeta principal: Estilo Obsidian Glass con orla dorada mística
	_loading_card = PanelContainer.new()
	_loading_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.03, 0.055, 0.95)
	sb.set_corner_radius_all(22)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.92, 0.76, 0.38, 0.75)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	sb.shadow_size = 28
	sb.content_margin_left = 64
	sb.content_margin_right = 64
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	_loading_card.add_theme_stylebox_override("panel", sb)
	_loading_center.add_child(_loading_card)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_loading_card.add_child(vbox)

	# 1. Spinner arcano celestial (96x96 px)
	_loading_spinner = Control.new()
	_loading_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_spinner.custom_minimum_size = Vector2(96, 96)
	_loading_spinner.draw.connect(_draw_loading_spinner)
	vbox.add_child(_loading_spinner)

	# 2. Título con tipografía Cinzel
	_loading_title = Label.new()
	_loading_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_title.text = Locale.pick({"es": "Cargando Mazmorra...", "en": "Loading Dungeon..."})
	_loading_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_title.add_theme_font_size_override("font_size", 30)
	_loading_title.add_theme_color_override("font_color", Color(0.98, 0.88, 0.52))
	_loading_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_loading_title.add_theme_constant_override("shadow_offset_y", 2)
	_loading_title.add_theme_constant_override("shadow_offset_x", 0)
	UiKit.apply_heading(_loading_title)
	vbox.add_child(_loading_title)

	# 3. Separador rúnico con diamante sagrado
	_loading_divider = Control.new()
	_loading_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_divider.custom_minimum_size = Vector2(260, 14)
	_loading_divider.draw.connect(_draw_loading_divider)
	vbox.add_child(_loading_divider)

	# 4. Subtítulo místico en plata azulada
	_loading_subtitle = Label.new()
	_loading_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_subtitle.text = Locale.pick({"es": "Generando escenario 3D y texturas...", "en": "Generating 3D environment & textures..."})
	_loading_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_subtitle.add_theme_font_size_override("font_size", 18)
	_loading_subtitle.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
	vbox.add_child(_loading_subtitle)

	# 5. Badge estilizado para Modo Web (si aplica)
	if OS.has_feature("web"):
		_loading_web_badge = PanelContainer.new()
		_loading_web_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var b_sb := StyleBoxFlat.new()
		b_sb.bg_color = Color(0.12, 0.10, 0.18, 0.75)
		b_sb.set_corner_radius_all(14)
		b_sb.border_width_left = 1
		b_sb.border_width_top = 1
		b_sb.border_width_right = 1
		b_sb.border_width_bottom = 1
		b_sb.border_color = Color(0.60, 0.48, 0.85, 0.4)
		b_sb.content_margin_left = 16
		b_sb.content_margin_right = 16
		b_sb.content_margin_top = 7
		b_sb.content_margin_bottom = 7
		_loading_web_badge.add_theme_stylebox_override("panel", b_sb)

		var badge_hbox := HBoxContainer.new()
		badge_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		badge_hbox.add_theme_constant_override("separation", 8)
		_loading_web_badge.add_child(badge_hbox)

		_loading_web_icon = Control.new()
		_loading_web_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_loading_web_icon.custom_minimum_size = Vector2(20, 20)
		_loading_web_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_loading_web_icon.draw.connect(_draw_loading_web_icon)
		_loading_web_icon.resized.connect(func() -> void:
			if _loading_web_icon != null and is_instance_valid(_loading_web_icon):
				_loading_web_icon.queue_redraw()
		)
		badge_hbox.add_child(_loading_web_icon)

		_loading_web_tip = Label.new()
		_loading_web_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_loading_web_tip.text = Locale.pick({
			"es": "Modo Web: la compilación de shaders 3D puede requerir unos instantes...",
			"en": "Web mode: compiling 3D shaders and meshes may take a moment..."
		})
		_loading_web_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_loading_web_tip.add_theme_font_size_override("font_size", 14)
		_loading_web_tip.add_theme_color_override("font_color", Color(0.82, 0.78, 0.92))
		badge_hbox.add_child(_loading_web_tip)
		vbox.add_child(_loading_web_badge)


func _draw_loading_web_icon() -> void:
	if _loading_web_icon == null or not is_instance_valid(_loading_web_icon):
		return
	var sz := _loading_web_icon.size
	var w: float = sz.x if sz.x > 0.0 else 20.0
	var h: float = sz.y if sz.y > 0.0 else 20.0
	var c := Vector2(w * 0.5, h * 0.5)
	var r := 7.0
	var r_in := 2.5
	_loading_web_icon.draw_circle(c, 9.0, Color(0.60, 0.48, 0.95, 0.35))
	var pts := PackedVector2Array([
		c + Vector2(0, -r),
		c + Vector2(r_in, -r_in),
		c + Vector2(r, 0),
		c + Vector2(r_in, r_in),
		c + Vector2(0, r),
		c + Vector2(-r_in, r_in),
		c + Vector2(-r, 0),
		c + Vector2(-r_in, -r_in)
	])
	_loading_web_icon.draw_colored_polygon(pts, Color(0.98, 0.84, 0.42, 0.95))
	_loading_web_icon.draw_circle(c, 1.8, Color(1.0, 1.0, 1.0, 1.0))


func _draw_loading_spinner() -> void:
	if _loading_spinner == null:
		return
	var c := _loading_spinner.size * 0.5

	# 1. Resplandor etéreo de fondo
	var glow_pulse := 0.6 + 0.4 * sin(_spinner_angle * 1.5)
	_loading_spinner.draw_circle(c, 44.0, Color(0.96, 0.72, 0.18, 0.05 * glow_pulse))
	_loading_spinner.draw_circle(c, 30.0, Color(0.35, 0.78, 1.0, 0.07 * glow_pulse))

	# 2. Anillo exterior dorado rúnico
	var r_outer := 36.0
	_loading_spinner.draw_arc(c, r_outer, _spinner_angle, _spinner_angle + PI * 1.35, 36, Color(0.96, 0.76, 0.24, 0.95), 3.5, true)
	# 8 Puntos cardinales / glifos estelares en el borde exterior
	for i in 8:
		var a := _spinner_angle + (i * TAU / 8.0)
		var pt := c + Vector2(cos(a), sin(a)) * r_outer
		var pt_col := Color(1.0, 0.90, 0.45, 0.4 + 0.5 * sin(_spinner_angle * 2.0 + i))
		_loading_spinner.draw_circle(pt, 1.8, pt_col)

	# 3. Anillo intermedio azul místico en contrarrotación
	var r_mid := 24.0
	_loading_spinner.draw_arc(c, r_mid, -_spinner_angle * 1.4, -_spinner_angle * 1.4 + PI * 1.25, 28, Color(0.38, 0.82, 1.0, 0.85), 2.5, true)

	# 4. Destellos orbitales que giran
	for i in 3:
		var orb_a := _spinner_angle * 2.1 + (i * TAU / 3.0)
		var orb_pt := c + Vector2(cos(orb_a), sin(orb_a)) * (r_mid + 5.5)
		_loading_spinner.draw_circle(orb_pt, 2.2, Color(0.70, 0.95, 1.0, 0.9))

	# 5. Diamante sagrado central (emblema de Ecos de la Verdad)
	var d_scale := 7.0 + 1.8 * sin(_spinner_angle * 2.5)
	var d_pts := PackedVector2Array([
		c + Vector2(0, -d_scale),
		c + Vector2(d_scale * 0.7, 0),
		c + Vector2(0, d_scale),
		c + Vector2(-d_scale * 0.7, 0)
	])
	_loading_spinner.draw_colored_polygon(d_pts, Color(1.0, 0.95, 0.75, 0.95))
	_loading_spinner.draw_circle(c, 2.0, Color(1.0, 1.0, 1.0, 0.98))


func _draw_loading_divider() -> void:
	if _loading_divider == null:
		return
	var w := _loading_divider.size.x
	var h := _loading_divider.size.y
	var mid_y := h * 0.5
	var center_x := w * 0.5

	# Línea izquierda con fundido
	_loading_divider.draw_line(Vector2(20, mid_y), Vector2(center_x - 14, mid_y), Color(0.92, 0.76, 0.38, 0.45), 1.5)
	# Línea derecha con fundido
	_loading_divider.draw_line(Vector2(center_x + 14, mid_y), Vector2(w - 20, mid_y), Color(0.92, 0.76, 0.38, 0.45), 1.5)
	# Diamante central dorado
	var d_size := 4.5
	var diamond := PackedVector2Array([
		Vector2(center_x, mid_y - d_size),
		Vector2(center_x + d_size * 0.75, mid_y),
		Vector2(center_x, mid_y + d_size),
		Vector2(center_x - d_size * 0.75, mid_y)
	])
	_loading_divider.draw_colored_polygon(diamond, Color(0.98, 0.84, 0.42, 0.9))


func _process(delta: float) -> void:
	if _loading_active:
		_spinner_angle = fmod(_spinner_angle + delta * 3.6, TAU)
		if _loading_spinner != null:
			_loading_spinner.queue_redraw()
		if _loading_divider != null:
			_loading_divider.queue_redraw()


## Muestra la pantalla de carga con texto personalizado y animación suave
func show_loading(title: String = "", subtitle: String = "") -> void:
	_loading_active = true
	if title != "" and _loading_title != null:
		_loading_title.text = title
	if subtitle != "" and _loading_subtitle != null:
		_loading_subtitle.text = subtitle

	if _loading_center != null:
		_loading_center.visible = true
		if _loading_card_tween != null and _loading_card_tween.is_valid():
			_loading_card_tween.kill()
		_loading_center.modulate.a = 0.0
		if _loading_card != null:
			_loading_card.scale = Vector2(0.92, 0.92)
			_loading_card.pivot_offset = _loading_card.size * 0.5

		_loading_card_tween = create_tween().set_parallel(true)
		_loading_card_tween.tween_property(_loading_center, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
		if _loading_card != null:
			_loading_card_tween.tween_property(_loading_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Actualiza el subtítulo de la pantalla de carga dinámicamente durante procesos largos
func set_loading_subtitle(subtitle: String) -> void:
	if _loading_subtitle != null and is_instance_valid(_loading_subtitle):
		_loading_subtitle.text = subtitle


## Oculta la pantalla de carga con desvanecimiento limpio
func hide_loading() -> void:
	_loading_active = false
	if _loading_center == null:
		return
	if _loading_card_tween != null and _loading_card_tween.is_valid():
		_loading_card_tween.kill()

	_loading_card_tween = create_tween().set_parallel(true)
	_loading_card_tween.tween_property(_loading_center, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	if _loading_card != null:
		_loading_card_tween.tween_property(_loading_card, "scale", Vector2(0.94, 0.94), 0.18).set_trans(Tween.TRANS_CUBIC)
	_loading_card_tween.chain().tween_callback(func() -> void:
		_loading_center.visible = false
	)


## ¿El usuario pidió reducir efectos de movimiento? (accesibilidad)
func reduced() -> bool:
	return Locale.reduce_motion


# ══════════════════════════════════════════════════════════════════════════════
# TRANSICIONES — fundido a negro unificado entre vistas/combate/mazmorra
# ══════════════════════════════════════════════════════════════════════════════
## Funde a negro en `time` segundos. Bloquea el input mientras la pantalla se
## oscurece para evitar clics durante el cambio. Devuelve el Tween por si se
## quiere encadenar.
func fade_out(time: float = 0.22) -> Tween:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, time).set_trans(Tween.TRANS_SINE)
	return tw


## Funde desde negro a transparente y vuelve a dejar pasar el input.
func fade_in(time: float = 0.22) -> Tween:
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, time).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)
	return tw


## Transición completa: funde a negro, ejecuta `midpoint` (el cambio de vista, con
## la pantalla ya en negro) y vuelve a fundir a la escena. Unifica los "cortes
## secos" al cambiar de contexto. Si se especifican textos de carga, muestra el
## indicador elegante de progreso (vital para Web/móvil al compilar 3D).
func transition(midpoint: Callable, out_time: float = 0.2, in_time: float = 0.24, loading_title: String = "", loading_subtitle: String = "") -> void:
	if loading_title != "":
		show_loading(loading_title, loading_subtitle)
	await fade_out(out_time).finished
	# En Web/Canvas dos frames de cesión son obligatorios para que el navegador pinte el loading en pantalla antes de bloquear el hilo de ejecución
	await get_tree().process_frame
	await get_tree().process_frame
	if midpoint.is_valid():
		var res = midpoint.call()
		if res is Signal:
			await res
	await get_tree().process_frame
	if loading_title != "":
		hide_loading()
	fade_in(in_time)


## Entrada LIGERA de una vista ya visible (p. ej. al cambiar de pestaña inferior):
## fundido + escala sutil desde abajo, SIN el fundido a negro completo de
## `transition()` (demasiado pesado para un gesto tan frecuente). Rápida a
## propósito. Respeta `reduce_motion` (solo fundido, sin escala).
func view_in(view: Control, time: float = 0.16) -> void:
	if view == null or not is_instance_valid(view):
		return
	view.modulate.a = 0.0
	if not reduced():
		view.scale = Vector2(0.985, 0.985)
		view.pivot_offset = view.size * 0.5
	var tw := view.create_tween()
	tw.set_parallel(true)
	tw.tween_property(view, "modulate:a", 1.0, time).set_trans(Tween.TRANS_SINE)
	if not reduced():
		tw.tween_property(view, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ══════════════════════════════════════════════════════════════════════════════
# HIT-STOP — congela brevemente el tiempo para dar peso a los impactos
# ══════════════════════════════════════════════════════════════════════════════
## Ralentiza `Engine.time_scale` durante `duration` segundos (tiempo REAL) y lo
## restaura. Ideal para el momento de impacto de un golpe fuerte/crítico.
## No hace nada si ya hay un hit-stop en curso o si se redujo el movimiento.
func hit_stop(duration: float = 0.08, scale: float = HITSTOP_SCALE) -> void:
	if reduced() or _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = clampf(scale, 0.01, 1.0)
	# El timer ignora time_scale para medir tiempo real mientras el juego va lento.
	var t := get_tree().create_timer(duration, true, false, true)
	await t.timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


# ══════════════════════════════════════════════════════════════════════════════
# SCREEN-SHAKE — sacudida de una cámara o de un nodo 2D/Control
# ══════════════════════════════════════════════════════════════════════════════
## Sacude un nodo (Control, Node2D o Camera3D) con una amplitud que decae hasta
## cero en `duration` segundos. Preserva y restaura la posición/offset base.
## `amount` se interpreta en px para 2D/Control y en unidades de offset para 3D.
func shake(target: Node, amount: float = 8.0, duration: float = 0.28) -> void:
	if target == null or not is_instance_valid(target):
		return
	if reduced():
		return
	if target is Camera3D:
		_shake_camera3d(target, amount, duration)
	elif target is Control:
		_shake_control(target, amount, duration)
	elif target is Node2D:
		_shake_node2d(target, amount, duration)
	elif target != null:
		var vp: Viewport = target.get_viewport() if target.is_inside_tree() else null
		var cam: Camera3D = vp.get_camera_3d() if vp != null else null
		if cam != null:
			_shake_camera3d(cam, amount, duration)
		var p: Node = target.get_parent()
		while p != null and not (p is Control):
			p = p.get_parent()
		if p is Control:
			_shake_control(p as Control, amount, duration)


func _shake_control(c: Control, amount: float, duration: float) -> void:
	var base := c.position
	var elapsed := 0.0
	while elapsed < duration and is_instance_valid(c):
		var f := 1.0 - (elapsed / duration)
		c.position = base + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)) * f
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if is_instance_valid(c):
		c.position = base


func _shake_node2d(n: Node2D, amount: float, duration: float) -> void:
	var base := n.position
	var elapsed := 0.0
	while elapsed < duration and is_instance_valid(n):
		var f := 1.0 - (elapsed / duration)
		n.position = base + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)) * f
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if is_instance_valid(n):
		n.position = base


func _shake_camera3d(cam: Camera3D, amount: float, duration: float) -> void:
	var base_h := cam.h_offset
	var base_v := cam.v_offset
	var elapsed := 0.0
	var amp := amount * 0.06   # escala a unidades razonables de offset de cámara
	while elapsed < duration and is_instance_valid(cam):
		var f := 1.0 - (elapsed / duration)
		cam.h_offset = base_h + randf_range(-amp, amp) * f
		cam.v_offset = base_v + randf_range(-amp, amp) * f
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if is_instance_valid(cam):
		cam.h_offset = base_h
		cam.v_offset = base_v


# ══════════════════════════════════════════════════════════════════════════════
# FLASH — destello de color sobre un CanvasItem (sprite/panel)
# ══════════════════════════════════════════════════════════════════════════════
## Tiñe brevemente `ci.modulate` con `color` y lo devuelve a su valor original.
## Se mantiene incluso con reduce_motion (es informativo, no cinético), pero más
## tenue. Útil para "recibir daño", "curación", "resaltar objetivo".
func flash(ci: CanvasItem, color: Color = Color(1, 1, 1, 1), duration: float = 0.18) -> void:
	if ci == null or not is_instance_valid(ci):
		return
	var base: Color = ci.modulate
	var peak := color
	if reduced():
		peak = base.lerp(color, 0.5)
	var tw := ci.create_tween()
	tw.tween_property(ci, "modulate", peak, duration * 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ci, "modulate", base, duration * 0.65).set_trans(Tween.TRANS_SINE)


# ══════════════════════════════════════════════════════════════════════════════
# POP — pequeño rebote de escala (feedback al pulsar / aparecer)
# ══════════════════════════════════════════════════════════════════════════════
## Rebote de escala sobre un Control. Delega en el patrón de UiKit.pop, pero
## respeta reduce_motion (si está activo, no anima).
func pop(node: Control, scale: float = 1.12, time: float = 0.18) -> void:
	if node == null or not is_instance_valid(node):
		return
	if reduced():
		return
	UiKit.pop(node, scale, time)


# ══════════════════════════════════════════════════════════════════════════════
# NÚMEROS DE DAÑO FLOTANTES — con jerarquía visual por tipo
# ══════════════════════════════════════════════════════════════════════════════
## Muestra un número/etiqueta flotante en `parent` en la posición local `pos` que
## sube y se desvanece. `kind` controla color y tamaño (jerarquía visual):
##   "crit"   → grande, ámbar     | "weak" → verde (débil, ¡bien!)
##   "resist" → gris (resistido)  | "heal" → verde curación
##   "damage" → rojo normal       | "info" → texto tenue
## Con reduce_motion el número aparece igualmente (sólo sube menos).
func damage_number(parent: Node, pos: Vector2, text: String, kind: String = "damage") -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var color := UiKit.HP
	var size := 30
	match kind:
		"crit":
			color = UiKit.ACCENT_SOFT
			size = 46
		"weak":
			color = UiKit.GOOD
			size = 36
		"resist":
			color = UiKit.TEXT_DIM
			size = 26
		"heal":
			color = UiKit.GOOD
			size = 32
		"mp":
			color = UiKit.MP
			size = 30
		"info":
			color = UiKit.TEXT_DIM
			size = 26
		_:
			color = UiKit.HP
			size = 30

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 100
	parent.add_child(lbl)
	lbl.position = pos - Vector2(0, 10)
	lbl.pivot_offset = lbl.size * 0.5

	var rise := 70.0 if not reduced() else 30.0
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	# Un pequeño "pop" de entrada para los críticos (informativo, se mantiene).
	if kind == "crit":
		lbl.scale = Vector2(0.6, 0.6)
		tw.tween_property(lbl, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", lbl.position.y - rise, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(lbl.queue_free)
