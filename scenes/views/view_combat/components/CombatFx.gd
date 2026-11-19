# CombatFx.gd
# ─────────────────────────────────────────────────────────────────────────────
# EFECTOS VISUALES Y FEEDBACK SENSORIAL DE COMBATE
#
# Helpers estáticos reutilizables para feedback de combate:
#   - Partículas ambientales por bioma (cueva, bosque, nieve, desierto, volcán).
#   - Partículas de estados alterados (veneno, quemadura, congelado, sangrado, maldición).
#   - Reacción física al daño: destello blanco, retroceso (knockback), sacudida y números flotantes.
#   - Daño crítico destacado (+50% escala, tinte dorado/fuego y destello radiante).
#   - Animación de desintegración y muerte del enemigo.
# ─────────────────────────────────────────────────────────────────────────────
class_name CombatFx
extends RefCounted


## Número/palabra flotante que asciende y se desvanece sobre un `anchor`.
## `font_size` es configurable para distinguir a simple vista la magnitud.
static func spawn_word(host: Control, popups: Control, text: String, color: Color, anchor: Control, cb_symbol: String = "", font_size: int = 50) -> void:
	if popups == null or anchor == null:
		return
	var lbl := Label.new()
	lbl.text = ("%s %s" % [cb_symbol, text]) if (cb_symbol != "" and Locale.colorblind) else text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 3)
	lbl.add_theme_constant_override("shadow_offset_y", 3)

	var start_y: float = anchor.global_position.y + anchor.size.y * 0.3
	var start_x: float = anchor.global_position.x + anchor.size.x * 0.5 - 90.0
	lbl.global_position = Vector2(start_x, start_y)
	lbl.pivot_offset = Vector2(90.0, 25.0)
	lbl.scale = Vector2(0.4, 0.4)

	popups.add_child(lbl)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "global_position:y", start_y - 120.0, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(lbl, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.finished.connect(lbl.queue_free)


## Banner/texto de aviso centrado en pantalla (ej: "¡DEFENSA PERFECTA!"),
## con gran tamaño, destello y animación de escala.
static func spawn_center_callout(host: Control, popups: Control, text: String, color: Color, cb_symbol: String = "", font_size: int = 56) -> void:
	if popups == null or host == null:
		return
	var vp_sz := host.get_viewport_rect().size
	var lbl := Label.new()
	lbl.text = ("%s %s" % [cb_symbol, text]) if (cb_symbol != "" and Locale.colorblind) else text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 3)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 1.0))

	var start_pos := Vector2(vp_sz.x * 0.5 - 350.0, vp_sz.y * 0.36)
	lbl.custom_minimum_size = Vector2(700, 90)
	lbl.global_position = start_pos
	lbl.pivot_offset = Vector2(350.0, 45.0)
	lbl.scale = Vector2(0.5, 0.5)

	popups.add_child(lbl)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "global_position:y", start_pos.y - 70.0, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "scale", Vector2(1.35, 1.35), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(lbl, "scale", Vector2.ONE, 0.15)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.45)
	tween.finished.connect(lbl.queue_free)


## Daño/curación RESIDUAL por estado alterado (veneno/quemadura/regeneración)
static func spawn_dot_tick(host: Control, popups: Control, text: String, color: Color, anchor: Control) -> void:
	if popups == null or anchor == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.modulate.a = 0.95
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)

	var start_y: float = anchor.global_position.y + anchor.size.y * 0.15
	var start_x: float = anchor.global_position.x + anchor.size.x * 0.5 - 45.0
	lbl.global_position = Vector2(start_x, start_y)

	popups.add_child(lbl)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "global_position:y", start_y - 75.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.finished.connect(lbl.queue_free)


## Valor grande de daño sobre el objetivo (`anchor`), asciende y se desvanece (sin icono a la izquierda).
static func play_special_fx(host: Control, popups: Control, anchor: Control, _icon: String, value: int, color: Color) -> void:
	if popups == null or anchor == null:
		return
	var lbl := Label.new()
	lbl.text = "-%d" % value if value > 0 else "%d" % value
	lbl.add_theme_font_size_override("font_size", 80)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("outline_size", 14)
	lbl.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 4)
	lbl.add_theme_constant_override("shadow_offset_y", 4)

	var start_y: float = anchor.global_position.y + anchor.size.y * 0.35
	var start_x: float = anchor.global_position.x + anchor.size.x * 0.5 - 90.0
	lbl.global_position = Vector2(start_x, start_y)
	lbl.pivot_offset = Vector2(90.0, 35.0)
	lbl.scale = Vector2(0.5, 0.5)

	popups.add_child(lbl)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "global_position:y", start_y - 150.0, 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.1).set_delay(0.3)
	tween.finished.connect(lbl.queue_free)


## Interpolación cuadrática de Bézier (a=origen, b=control, c=destino).
static func _quad_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


## Copia semitransparente y menguante del proyectil, dejada atrás en su
## trayectoria: estela de post-imágenes. `texture` es null si
## la habilidad no tiene PNG dedicado (se usa el mismo glifo de respaldo).
static func _spawn_trail_ghost(host: Control, popups: Control, pos: Vector2, proj_size: Vector2, tint: Color, texture: Texture2D, rot: float = 0.0) -> void:
	if popups == null or not is_instance_valid(popups):
		return
	var ghost: Control
	if texture != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ghost = tex_rect
	else:
		var lbl := Label.new()
		lbl.text = "✨"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", int(proj_size.x * 0.55))
		ghost = lbl
	var gsize := proj_size * 0.8
	ghost.custom_minimum_size = gsize
	ghost.size = gsize
	ghost.pivot_offset = gsize * 0.5
	ghost.rotation = rot
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate = Color(tint.r, tint.g, tint.b, 0.5)
	ghost.global_position = pos - gsize * 0.5
	popups.add_child(ghost)

	var gtw := host.create_tween()
	gtw.set_parallel(true)
	gtw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	gtw.tween_property(ghost, "scale", Vector2(0.55, 0.55), 0.22)
	gtw.chain().tween_callback(ghost.queue_free)


## Onda de impacto expansiva del color elemental + destello blanco clásico +
## sonido, al llegar el proyectil.
static func _flash_impact(host: Control, popups: Control, target_rect: Control, tint: Color) -> void:
	if not is_instance_valid(target_rect):
		return
	AudioManager.play_sfx("hit")
	var orig_mod := target_rect.modulate
	target_rect.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var ftw := host.create_tween()
	ftw.tween_property(target_rect, "modulate", orig_mod, 0.08)

	if popups == null or not is_instance_valid(popups) or Locale.reduce_motion:
		return
	var ring := Panel.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.set_corner_radius_all(60)
	rs.set_border_width_all(5)
	rs.border_color = Color(tint.r, tint.g, tint.b, 0.85)
	ring.add_theme_stylebox_override("panel", rs)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_size: Vector2 = target_rect.size * 0.55
	ring.size = ring_size
	ring.pivot_offset = ring_size * 0.5
	ring.global_position = target_rect.global_position + target_rect.size * 0.5 - ring_size * 0.5
	popups.add_child(ring)
	var rtw := host.create_tween()
	rtw.set_parallel(true)
	rtw.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.tween_property(ring, "modulate:a", 0.0, 0.4)
	rtw.chain().tween_callback(ring.queue_free)


## Proyectil genérico de respaldo para habilidades que no tienen aún script
## dedicado en `assets/combat/effects/`: vuela trazando una parábola suave,
## orientando su dirección hacia el objetivo con estela y destello de impacto.
static func spawn_skill_projectile(host: Control, popups: Control, origin_rect: Control, target_rect: Control, skill: Dictionary, is_synergy: bool = false) -> void:
	if target_rect == null or not is_instance_valid(target_rect):
		return
	if origin_rect == null or not is_instance_valid(origin_rect):
		return

	var skill_id := String(skill.get("id", ""))
	var img_path := "res://assets/combat/skills/%s.png" % skill_id
	var texture: Texture2D = load(img_path) if ResourceLoader.exists(img_path) else null

	var base_size := 88.0 if is_synergy else 64.0
	var tint := Color(1.0, 0.85, 0.35) if is_synergy else Color(1.0, 1.0, 1.0)

	var proj: Control
	if texture != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		proj = tex_rect
	else:
		var lbl := Label.new()
		lbl.text = "⚡" if is_synergy else "✨"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", int(base_size * 0.55))
		proj = lbl
	proj.custom_minimum_size = Vector2(base_size, base_size)
	proj.size = Vector2(base_size, base_size)
	proj.pivot_offset = proj.size * 0.5
	proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proj.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	popups.add_child(proj)

	var start_pos := origin_rect.global_position + origin_rect.size * 0.5
	var end_pos := target_rect.global_position + target_rect.size * 0.5
	proj.global_position = start_pos - proj.size * 0.5
	proj.scale = Vector2(0.55, 0.55)

	if Locale.reduce_motion:
		var dir := (end_pos - start_pos).normalized()
		if dir.length_squared() > 0.001:
			proj.rotation = dir.angle()
		# Sin arco ni estela: fundido rápido directo al objetivo + impacto igual de contundente.
		var rtw := host.create_tween()
		rtw.tween_property(proj, "modulate:a", 1.0, 0.05)
		rtw.parallel().tween_property(proj, "global_position", end_pos - proj.size * 0.5, 0.12).set_trans(Tween.TRANS_QUAD)
		rtw.tween_callback(func() -> void:
			if is_instance_valid(proj):
				proj.queue_free()
			_flash_impact(host, popups, target_rect, tint)
		)
		return

	# Punto de control del arco: por encima de la línea recta origen→destino,
	# para que la habilidad "vuele" con carácter en vez de una recta plana.
	var mid := (start_pos + end_pos) * 0.5
	var arc_height: float = clampf(start_pos.distance_to(end_pos) * 0.22, 24.0, 90.0)
	var control := mid - Vector2(0.0, arc_height)
	var duration := 0.48 if is_synergy else 0.40

	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(proj, "modulate:a", 1.0, 0.06)
	tw.tween_property(proj, "scale", Vector2(1.25, 1.25) if is_synergy else Vector2(1.1, 1.1), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(proj):
			var current_pos := _quad_bezier(start_pos, control, end_pos, t)
			proj.global_position = current_pos - proj.size * 0.5
			var next_pos := _quad_bezier(start_pos, control, end_pos, minf(t + 0.04, 1.0))
			var tangent := next_pos - current_pos
			if tangent.length_squared() > 0.001:
				proj.rotation = tangent.angle()
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Estela: varias copias menguantes repartidas a lo largo del vuelo.
	var trail_count := 6 if is_synergy else 4
	for k in range(1, trail_count + 1):
		var t: float = float(k) / float(trail_count + 1)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(proj) or not is_instance_valid(host):
				return
			_spawn_trail_ghost(host, popups, proj.global_position + proj.size * 0.5, proj.size, tint, texture, proj.rotation)
		).set_delay(duration * t * 0.85)

	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(proj):
			proj.queue_free()
		_flash_impact(host, popups, target_rect, tint)
	)


## Comprueba si una habilidad tiene un script de efecto visual o textura dedicada.
static func has_skill_effect(skill_id: String) -> bool:
	if skill_id == "":
		return false
	if ResourceLoader.exists("res://assets/combat/effects/%s.gd" % skill_id):
		return true
	if ResourceLoader.exists("res://assets/combat/skills/%s.png" % skill_id):
		return true
	return false


## Despacha el efecto visual de una habilidad (jugador o enemiga) a su fichero
## dedicado en `assets/combat/effects/<skill_id>.gd`, si existe: cada fichero
## define una `func play(ctx: Dictionary) -> void` que dibuja el efecto de forma
## 100% procedural (ver `assets/combat/effects/_fx_kit.gd`), sin necesitar
## ningún .png. Si la habilidad todavía no tiene fichero dedicado, recurre al
## proyectil genérico de siempre (`spawn_skill_projectile`) para no romper nada.
## `skill_id` se pasa aparte porque `enemy_skills.json` no siempre incluye su
## propio id embebido dentro del Dictionary (a diferencia de `skills.json`).
static func play_skill_effect(host: Control, popups: Control, origin_rect: Control, target_rect: Control, skill_id: String, skill: Dictionary, tint: Color = Color.WHITE, is_synergy: bool = false) -> void:
	if host != null and "is_skill_animating" in host:
		host.is_skill_animating = true
		var tw := host.create_tween()
		tw.tween_interval(1.10) # Paraliza el ATB durante toda la ejecución de la técnica
		tw.tween_callback(func():
			if is_instance_valid(host) and "is_skill_animating" in host:
				host.is_skill_animating = false
		)

	if skill_id != "":
		var path := "res://assets/combat/effects/%s.gd" % skill_id
		if ResourceLoader.exists(path):
			var script = load(path)
			if script != null:
				var inst = script.new()
				if inst.has_method("play"):
					inst.play({
						"host": host,
						"popups": popups,
						"origin": origin_rect,
						"target": target_rect,
						"tint": tint,
						"is_synergy": is_synergy,
						"skill": skill,
					})
					return
	spawn_skill_projectile(host, popups, origin_rect, target_rect, skill, is_synergy)


## Reacción de pantalla al recibir daño el jugador.
static func blood_screen_fx(host: Control, strength: float) -> void:
	if Locale.reduce_motion:
		return
	var flash := ColorRect.new()
	flash.color = Color(0.72, 0.04, 0.05, clampf(0.18 + strength * 0.30, 0.18, 0.5))
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(flash)

	var tw := host.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(flash.queue_free)


static var _label_pool: Array[Label] = []

static func _acquire_label(parent: Node) -> Label:
	for lbl in _label_pool:
		if lbl != null and is_instance_valid(lbl) and not lbl.visible:
			lbl.visible = true
			lbl.modulate = Color.WHITE
			return lbl
	var new_lbl := Label.new()
	_label_pool.append(new_lbl)
	parent.add_child(new_lbl)
	return new_lbl


static func _release_label(lbl: Label) -> void:
	if lbl != null and is_instance_valid(lbl):
		lbl.visible = false


## Sistema unificado de texto flotante de daño/curación con Object Pooling
## `element`: si el golpe es elemental (no "physical"/""), antepone su glifo
## al número de daño para leer de un vistazo qué elemento impactó.
static func spawn_floating_number(host: Control, popups: Control, pos: Vector2, value: int, type: String, element: String = "") -> void:
	if popups == null or host == null:
		return
	var lbl := _acquire_label(popups)
	var text_str := String.num_int64(value)
	var font_sz := 52
	var font_clr := Color(1.0, 0.9, 0.3)
	var outline_sz := 10
	var outline_clr := Color(1.0, 1.0, 1.0, 1.0)
	var is_crit := false
	var elem_glyph := ""
	if element != "" and element != "physical" and (type == "damage_enemy" or type == "critical"):
		elem_glyph = String(GameConfig.ELEMENTS.get(element, {}).get("icon", ""))

	match type:
		"damage_enemy":
			font_sz = 76
			font_clr = Color(1.0, 0.28, 0.15) # Fuego/Naranja-rojo vivo
			text_str = "-%d HP" % value
			outline_sz = 14
			outline_clr = Color(1.0, 1.0, 1.0, 1.0)
		"damage_player":
			font_sz = 82
			font_clr = Color(1.0, 0.18, 0.18) # Rojo carmesí vivo
			text_str = "-%d HP" % value
			outline_sz = 14
			outline_clr = Color(1.0, 1.0, 1.0, 1.0)
		"heal":
			font_sz = 60
			font_clr = Color(0.12, 0.92, 0.32) # Verde esmeralda vivo
			text_str = "+%d HP" % value
			outline_sz = 12
			outline_clr = Color(1.0, 1.0, 1.0, 1.0)
		"mana":
			font_sz = 52
			font_clr = Color(0.15, 0.70, 1.0) # Azul maná
			text_str = "+%d MP" % value
			outline_sz = 10
			outline_clr = Color(1.0, 1.0, 1.0, 1.0)
		"critical":
			is_crit = true
			font_sz = 98
			font_clr = Color(1.0, 0.12, 0.08) # Rojo fuego crítico extremo
			text_str = "¡¡CRÍTICO!! -%d HP" % value
			outline_sz = 16
			outline_clr = Color(1.0, 1.0, 1.0, 1.0) # Borde blanco extra grueso y nítido
		_:
			font_sz = 56
			font_clr = Color.WHITE
			text_str = "%d" % value
			outline_sz = 10
			outline_clr = Color(1.0, 1.0, 1.0, 1.0)

	if elem_glyph != "":
		text_str = "%s %s" % [elem_glyph, text_str]

	lbl.text = text_str
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", font_clr)
	lbl.add_theme_constant_override("outline_size", outline_sz)
	lbl.add_theme_color_override("font_outline_color", outline_clr)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl.add_theme_constant_override("shadow_offset_x", 4)
	lbl.add_theme_constant_override("shadow_offset_y", 4)

	# Variación aleatoria en la posición para evitar solapes
	var jitter_x: float = randf_range(-30.0, 30.0)
	var jitter_y: float = randf_range(-15.0, 15.0)
	var start_pos := pos + Vector2(jitter_x, jitter_y)
	lbl.global_position = start_pos
	lbl.pivot_offset = Vector2(110.0, 35.0)
	lbl.scale = Vector2(0.4, 0.4) if not is_crit else Vector2(0.3, 0.3)
	lbl.modulate.a = 1.0

	var tw := host.create_tween().set_parallel(true)
	if is_crit:
		# Animación punchy explosiva para impactos críticos
		tw.tween_property(lbl, "scale", Vector2(1.7, 1.7), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.12).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(lbl, "global_position:y", start_pos.y - 140.0, 1.2).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.55)
	else:
		# Animación punchy con rebote para daño y curación regular
		tw.tween_property(lbl, "scale", Vector2(1.45, 1.45), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(lbl, "scale", Vector2(1.1, 1.1), 0.10).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(lbl, "global_position:y", start_pos.y - 105.0, 1.0).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.4)

	tw.finished.connect(func(): _release_label(lbl))


## Sacudida de cámara/escenario (Tarea C4.2)
static func shake_camera(host: Control, intensity: float, duration: float) -> void:
	if host == null or Locale.reduce_motion:
		return
	var orig_pos := host.position
	var steps := int(maxf(1.0, duration / 0.03))
	var step_dur := duration / float(steps)

	var tw := host.create_tween()
	for i in range(steps):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tw.tween_property(host, "position", orig_pos + offset, step_dur)
	tw.tween_property(host, "position", orig_pos, 0.02)


## Número flotante de daño animado (normal vs crítico).
static func spawn_damage_number(host: Control, popups: Control, anchor: Control, value: int, is_critical: bool, _element: String = "") -> void:
	if popups == null or anchor == null:
		return
	var pos := Vector2(anchor.global_position.x + anchor.size.x * 0.5 - 75.0, anchor.global_position.y + anchor.size.y * 0.25)
	var type_str := "critical" if is_critical else "damage_enemy"
	spawn_floating_number(host, popups, pos, value, type_str, _element)


## Reacción de impacto en el enemigo (retroceso físico + destello blanco + destello en peana + shake).
static func play_hit_reaction(host: Control, enemy_rect: Control, is_critical: bool, platform_rect: Control = null) -> void:
	if enemy_rect == null or not is_instance_valid(enemy_rect):
		return

	var base_pos := enemy_rect.position
	var base_mod := enemy_rect.modulate

	# 1. Flash blanco instantáneo en enemigo y peana 2D
	enemy_rect.modulate = Color(2.5, 2.5, 2.5, 1.0)
	if platform_rect != null and is_instance_valid(platform_rect):
		var p_orig := platform_rect.modulate
		platform_rect.modulate = Color(2.5, 2.5, 2.5, 1.0)
		var ptw := host.create_tween()
		ptw.tween_property(platform_rect, "modulate", p_orig, 0.20)

	# 2. Knockback y Sacudida
	var kb_offset := Vector2(randf_range(-12.0, 12.0), -20.0) if is_critical else Vector2(randf_range(-8.0, 8.0), -12.0)
	
	var tw := host.create_tween()
	tw.tween_property(enemy_rect, "position", base_pos + kb_offset, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(enemy_rect, "position", base_pos, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(enemy_rect, "modulate", base_mod, 0.18)


## Animación elegante de desintegración y muerte del enemigo.
static func play_enemy_death_animation(host: Control, enemy_rect: Control, platform_rect: Control, on_complete: Callable) -> void:
	if enemy_rect == null or not is_instance_valid(enemy_rect):
		if on_complete.is_valid():
			on_complete.call()
		return

	AudioManager.play_sfx("defeat")
	var tw := host.create_tween().set_parallel(true)
	tw.tween_property(enemy_rect, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.12)
	tw.chain().tween_property(enemy_rect, "scale:y", 0.1, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(enemy_rect, "modulate:a", 0.0, 0.40)

	if platform_rect != null and is_instance_valid(platform_rect):
		tw.parallel().tween_property(platform_rect, "modulate:a", 0.0, 0.40)

	tw.finished.connect(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)


## Animación de derrota del héroe: destello rojo intenso (mismo lenguaje visual
## que `_play_hero_hurt_shake`), se mantiene 1s en ese estado (para que se vea
## claramente antes de cortar a resultados) y luego se desintegra igual que
## `play_enemy_death_animation` (encoge en vertical + fundido a transparente).
static func play_hero_defeat_animation(host: Control, hero_rect: Control, on_complete: Callable) -> void:
	if hero_rect == null or not is_instance_valid(hero_rect):
		if on_complete.is_valid():
			on_complete.call()
		return
	if Locale.reduce_motion:
		if on_complete.is_valid():
			on_complete.call()
		return

	AudioManager.play_sfx("defeat")
	var tw := host.create_tween()
	tw.tween_property(hero_rect, "modulate", Color(2.0, 0.35, 0.35, 1.0), 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(hero_rect, "scale:y", 0.1, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(hero_rect, "modulate:a", 0.0, 0.45)
	tw.finished.connect(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)


## Animación de huida: el sprite del héroe corre y sale de la pantalla por la
## derecha. `on_complete` se invoca al terminar (para encadenar el corte a
## resultados/salida de combate).
static func play_hero_flee_animation(host: Control, hero_rect: Control, on_complete: Callable) -> void:
	if hero_rect == null or not is_instance_valid(hero_rect):
		if on_complete.is_valid():
			on_complete.call()
		return
	if Locale.reduce_motion:
		if on_complete.is_valid():
			on_complete.call()
		return

	var vp_w: float = host.get_viewport_rect().size.x
	var tw := host.create_tween()
	tw.tween_property(hero_rect, "position:x", hero_rect.position.x + vp_w, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)


## Animación de huida del enemigo: se marcha hacia la derecha avergonzado y se desvanece.
static func play_enemy_flee_animation(host: Control, enemy_rect: Control, platform_rect: Control, on_complete: Callable) -> void:
	if enemy_rect == null or not is_instance_valid(enemy_rect):
		if on_complete.is_valid():
			on_complete.call()
		return
	if Locale.reduce_motion:
		if on_complete.is_valid():
			on_complete.call()
		return

	AudioManager.play_sfx("flee")
	var vp_w: float = host.get_viewport_rect().size.x
	var tw := host.create_tween().set_parallel(true)
	tw.tween_property(enemy_rect, "position:x", enemy_rect.position.x + vp_w * 0.45, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(enemy_rect, "modulate:a", 0.0, 0.65)
	if platform_rect != null and is_instance_valid(platform_rect):
		tw.tween_property(platform_rect, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(func() -> void:
		if on_complete.is_valid():
			on_complete.call()
	)


## Emisor procedimental de partículas ambientales del escenario según el bioma del encuentro.
static func spawn_biome_particles(popups: Control, terrain_code: String) -> void:
	if popups == null or Locale.reduce_motion:
		return

	var particle_container := Control.new()
	particle_container.name = "BiomeParticles"
	particle_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popups.add_child(particle_container)

	# Elegir color y velocidad según bioma (ice/des/mnt/grs/lav)
	var particle_color := Color(0.9, 0.95, 1.0, 0.4)
	match terrain_code:
		"ice", "snow":
			particle_color = Color(0.8, 0.95, 1.0, 0.6)
		"des", "bad":
			particle_color = Color(0.95, 0.8, 0.5, 0.5)
		"lav", "volcano":
			particle_color = Color(1.0, 0.4, 0.1, 0.7)
		"grs", "forest":
			particle_color = Color(0.6, 0.9, 0.5, 0.4)

	# Crear 12 partículas flotantes decorativas
	for i in range(12):
		var p := ColorRect.new()
		var sz := randf_range(3.0, 6.0)
		p.size = Vector2(sz, sz)
		p.color = particle_color
		p.position = Vector2(randf_range(20.0, popups.size.x - 20.0), randf_range(50.0, popups.size.y * 0.6))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		particle_container.add_child(p)

		# Flotación suave
		var tw := p.create_tween().set_loops()
		var duration := randf_range(3.0, 5.0)
		tw.tween_property(p, "position:y", p.position.y - randf_range(30.0, 60.0), duration).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(p, "position:x", p.position.x + randf_range(-20.0, 20.0), duration).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(p, "color:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
