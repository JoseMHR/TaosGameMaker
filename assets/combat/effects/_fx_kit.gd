# _fx_kit.gd
# ─────────────────────────────────────────────────────────────────────────────
# KIT MAESTRO DE EFECTOS VISUALES (ESCALA COMPACTA, ELEGANTE Y PROPORCIONADA)
# ─────────────────────────────────────────────────────────────────────────────
extends RefCounted

const CombatFxRef = preload("res://scenes/views/view_combat/components/CombatFx.gd")


class ShapeCanvas:
	extends Control
	var draw_fn: Callable
	func _draw() -> void:
		if draw_fn.is_valid():
			draw_fn.call(self)


# ─── HELPERS CINEMÁTICOS Y DE IMPACTO ─────────────────────────────────────────

static func _parse_color(val: Variant, default_col: Color = Color.WHITE) -> Color:
	if val is Color:
		return val
	if val is String:
		return Color.from_string(val, default_col)
	return default_col


static func _center_of(ctrl: Control) -> Vector2:
	if ctrl == null or not is_instance_valid(ctrl):
		return Vector2.ZERO
	return ctrl.global_position + ctrl.size * 0.5


static func _spawn_canvas(popups: Control, center_pos: Vector2, extent: float, draw_fn: Callable) -> Control:
	if popups == null or not is_instance_valid(popups):
		return null
	var c: ShapeCanvas = ShapeCanvas.new()
	c.draw_fn = draw_fn
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 45
	c.size = Vector2(extent, extent) * 2.0
	c.pivot_offset = c.size * 0.5
	popups.add_child(c)
	c.global_position = center_pos - c.size * 0.5
	c.queue_redraw()
	return c


static func _spawn_icon(popups: Control, pos: Vector2, text: String, size: int, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 46
	popups.add_child(lbl)
	lbl.global_position = pos
	return lbl


## Destello de contraste que SIEMPRE regresa incondicionalmente a Color.WHITE.
static func _flash(host: Control, target_rect: Control, strength: float = 1.6) -> void:
	if host == null or target_rect == null or not is_instance_valid(target_rect):
		return
	target_rect.modulate = Color(strength, strength, strength, 1.0)
	var tw: Tween = host.create_tween()
	tw.tween_property(target_rect, "modulate", Color.WHITE, 0.25).set_ease(Tween.EASE_OUT)


## Sacudida física del objetivo al recibir un impacto.
static func _shake_target(host: Control, target: Control, intensity: float = 9.0, duration: float = 0.28) -> void:
	if host == null or target == null or not is_instance_valid(target):
		return
	var orig_pos: Vector2 = target.position
	var tw: Tween = host.create_tween()
	var steps: int = 4
	for s in range(steps):
		var decay: float = 1.0 - float(s) / float(steps)
		var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)) * intensity * decay
		tw.tween_property(target, "position", orig_pos + offset, duration / float(steps))
	tw.tween_property(target, "position", orig_pos, 0.04)


## Deformación física de compresión/expansión (Squash & Stretch).
static func _squash_target(host: Control, target: Control, squash_y: float = 0.93, stretch_x: float = 1.07) -> void:
	if host == null or target == null or not is_instance_valid(target):
		return
	var orig_scale: Vector2 = target.scale
	var tw: Tween = host.create_tween()
	tw.tween_property(target, "scale", Vector2(orig_scale.x * stretch_x, orig_scale.y * squash_y), 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "scale", orig_scale, 0.16).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func _cleanup(host: Control, node: Control, delay: float) -> void:
	if host == null or node == null:
		return
	var tw: Tween = host.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)


static var _sprite_cache: Dictionary = {}

static func _load_sprite_texture(name: String) -> Texture2D:
	if _sprite_cache.has(name):
		return _sprite_cache[name]
	var path := "res://assets/combat/effectsSprites/%s.png" % name
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_sprite_cache[name] = tex
		return tex
	_sprite_cache[name] = null
	return null


static func _spawn_sprite(popups: Control, tex: Texture2D, center_pos: Vector2, size: Vector2, tint: Color = Color.WHITE) -> TextureRect:
	if popups == null or not is_instance_valid(popups) or tex == null:
		return null
	var spr_rect := TextureRect.new()
	spr_rect.texture = tex
	spr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr_rect.size = size
	spr_rect.pivot_offset = size * 0.5
	spr_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spr_rect.z_index = 48
	spr_rect.modulate = tint
	popups.add_child(spr_rect)
	spr_rect.global_position = center_pos - spr_rect.pivot_offset
	return spr_rect


# ─── PRIMITIVAS VISUALES COMPACTAS Y ELEGANTES ────────────────────────────────

## 1. Corte / Tajo (Slash)
static func slash(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 1.05, a4: Variant = -38.0, a5: Variant = 1, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color.WHITE
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.05
	var angle_deg: float = float(a4) if (a4 is int or a4 is float) else -38.0
	var count: int = int(a5) if (a5 is int or a5 is float) and int(a5) > 0 else 1
	var center: Vector2 = _center_of(target)
	var radius: float = maxf(target.size.x, 140.0) * 0.75 * size_mult

	_shake_target(host, target, 9.0 * size_mult, 0.28)
	_squash_target(host, target, 0.94, 1.06)

	var sprite_name := "vfx_slash_cross" if count > 1 else "vfx_slash_arc"
	var tex := _load_sprite_texture(sprite_name)
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center, Vector2(radius * 1.3, radius * 1.3), Color(col.r, col.g, col.b, 0.0))
		if spr != null:
			spr.rotation_degrees = angle_deg
			spr.scale = Vector2(0.3, 0.3)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.08)
			tw.tween_property(spr, "scale", Vector2(1.05, 1.05), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.chain().tween_interval(0.12) # Pausa de lectura visual para apreciar el tajo
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.35)
			tw.parallel().tween_property(spr, "scale", Vector2(1.15, 1.15), 0.35)
			_cleanup(host, spr, 0.75)
	else:
		for i in range(count):
			var ang: float = deg_to_rad(angle_deg + float(i) * 30.0)
			var glow: Color = Color(col.r, col.g, col.b, 0.85)
			var core: Color = Color(1.0, 1.0, 1.0, 1.0)
			var draw_fn: Callable = func(cnv: Control) -> void:
				var c: Vector2 = cnv.size * 0.5
				var arc_span: float = 1.4
				cnv.draw_arc(c, radius, ang - arc_span * 0.5, ang + arc_span * 0.5, 36, glow, 22.0 * size_mult, true)
				cnv.draw_arc(c, radius, ang - arc_span * 0.5, ang + arc_span * 0.5, 36, core, 7.0 * size_mult, true)
				var p1: Vector2 = c + Vector2(cos(ang - arc_span * 0.5), sin(ang - arc_span * 0.5)) * radius
				var p2: Vector2 = c + Vector2(cos(ang + arc_span * 0.5), sin(ang + arc_span * 0.5)) * radius
				cnv.draw_circle(p1, 7.0 * size_mult, core)
				cnv.draw_circle(p2, 7.0 * size_mult, core)
			var canvas: Control = _spawn_canvas(popups, center, radius + 75.0, draw_fn)
			if canvas == null:
				continue
			canvas.modulate.a = 0.0
			canvas.rotation = deg_to_rad(randf_range(-10.0, 10.0))
			canvas.scale = Vector2(0.3, 0.3)
			var delay: float = float(i) * 0.10
			var tw: Tween = host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(canvas, "modulate:a", 1.0, 0.06).set_delay(delay)
			tw.tween_property(canvas, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
			tw.chain().tween_property(canvas, "scale", Vector2(1.25, 1.25), 0.45)
			tw.parallel().tween_property(canvas, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
			_cleanup(host, canvas, delay + 0.80)
	_flash(host, target, 1.8)


## 2. Zarpazo / Arañazo (Claw Rake)
static func claw_rake(ctx: Dictionary, color: Variant = Color(0.95, 0.3, 0.2), a3: Variant = 1.05, a4: Variant = 3, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color(0.95, 0.3, 0.2)
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.05
	var center: Vector2 = _center_of(target)
	var radius: float = maxf(target.size.x, 140.0) * 0.75 * size_mult

	_shake_target(host, target, 12.0 * size_mult, 0.30)
	_squash_target(host, target, 0.94, 1.06)

	var tex := _load_sprite_texture("vfx_claw_slash")
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center, Vector2(radius * 1.3, radius * 1.3), Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.scale = Vector2(0.35, 0.35)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.08)
			tw.tween_property(spr, "scale", Vector2(1.05, 1.05), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.chain().tween_interval(0.12) # Pausa de lectura visual
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.35)
			tw.parallel().tween_property(spr, "scale", Vector2(1.15, 1.15), 0.35)
			_cleanup(host, spr, 0.75)
	else:
		var count: int = int(a4) if (a4 is int or a4 is float) and int(a4) > 0 else 3
		var extent: float = radius + 70.0
		for i in range(count):
			var offset_y: float = (float(i) - 1.0) * (26.0 * size_mult)
			var glow: Color = Color(col.r, col.g, col.b, 0.85)
			var core: Color = Color.WHITE.lerp(col, 0.2)
			var draw_fn: Callable = func(cnv: Control) -> void:
				var c: Vector2 = cnv.size * 0.5 + Vector2(0, offset_y)
				var p1: Vector2 = c + Vector2(-radius * 0.8, -radius * 0.5)
				var p2: Vector2 = c + Vector2(radius * 0.8, radius * 0.5)
				cnv.draw_line(p1, p2, glow, 20.0 * size_mult, true)
				cnv.draw_line(p1, p2, core, 6.0 * size_mult, true)
				cnv.draw_circle(p2, 6.0 * size_mult, core)
			var canvas: Control = _spawn_canvas(popups, center, extent, draw_fn)
			if canvas == null:
				continue
			canvas.modulate.a = 0.0
			canvas.scale = Vector2(0.3, 0.3)
			var delay: float = float(i) * 0.09
			var tw: Tween = host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(canvas, "modulate:a", 1.0, 0.06).set_delay(delay)
			tw.tween_property(canvas, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
			tw.chain().tween_property(canvas, "scale", Vector2(1.25, 1.25), 0.45)
			tw.parallel().tween_property(canvas, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
			_cleanup(host, canvas, delay + 0.80)
	_flash(host, target, 1.9)


## 3. Mordisco Feroz (Bite Chomp)
static func bite_chomp(ctx: Dictionary, color: Variant = Color(0.95, 0.95, 1.0), a3: Variant = 1.1, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color(0.95, 0.95, 1.0)
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.1
	var center: Vector2 = _center_of(target)
	var max_r: float = maxf(target.size.x, 140.0) * 0.80 * size_mult

	var tex := _load_sprite_texture("vfx_bite_fangs")
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center, Vector2(max_r * 1.3, max_r * 1.3), Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.scale = Vector2(1.2, 1.2)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.06)
			tw.tween_property(spr, "scale", Vector2(0.85, 0.85), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.chain().tween_callback(func() -> void:
				_shake_target(host, target, 13.0 * size_mult, 0.35)
				_squash_target(host, target, 0.88, 1.12)
				_flash(host, target, 2.0)
			)
			tw.chain().tween_interval(0.12) # Pausa de masticación / mordisco
			tw.chain().tween_property(spr, "scale", Vector2(1.0, 1.0), 0.35)
			tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.35)
			_cleanup(host, spr, 0.75)
	else:
		var draw_fn: Callable = func(cnv: Control) -> void:
			var c: Vector2 = cnv.size * 0.5
			var glow: Color = Color(col.r, col.g, col.b, 0.8)
			var core: Color = Color.WHITE
			for s in [-1.0, 1.0]:
				var pts: PackedVector2Array = PackedVector2Array([
					c + Vector2(-max_r * 0.75, s * max_r * 0.6),
					c + Vector2(-max_r * 0.3, s * max_r * 0.12),
					c + Vector2(0, s * max_r * 0.6),
					c + Vector2(max_r * 0.3, s * max_r * 0.12),
					c + Vector2(max_r * 0.75, s * max_r * 0.6)
				])
				cnv.draw_polyline(pts, glow, 18.0 * size_mult, true)
				cnv.draw_polyline(pts, core, 6.0 * size_mult, true)

		var canvas: Control = _spawn_canvas(popups, center, max_r + 55.0, draw_fn)
		if canvas == null:
			return
		canvas.scale = Vector2(1.4, 1.4)
		canvas.modulate.a = 0.0
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(canvas, "modulate:a", 1.0, 0.06)
		tw.tween_property(canvas, "scale", Vector2(0.95, 0.95), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func() -> void:
			_shake_target(host, target, 11.0 * size_mult, 0.30)
			_squash_target(host, target, 0.88, 1.12)
			_flash(host, target, 1.9)
		)
		tw.tween_property(canvas, "scale", Vector2(1.1, 1.1), 0.40)
		tw.parallel().tween_property(canvas, "modulate:a", 0.0, 0.40)
		_cleanup(host, canvas, 0.80)


## 4. Bofetón de Don Nadie (Slap Hand)
static func slap_hand(ctx: Dictionary, color: Variant = Color(1.0, 0.88, 0.4), a3: Variant = 1.15, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.15
	var center: Vector2 = _center_of(target)
	var sweep_dist: float = maxf(target.size.x, 160.0) * 0.95 * size_mult
	var tex := _load_sprite_texture("vfx_slap_hand")

	var hand: Control
	if tex != null:
		var hand_rect := TextureRect.new()
		hand_rect.texture = tex
		hand_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hand_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hand_rect.size = Vector2(175, 175) * size_mult
		hand_rect.pivot_offset = hand_rect.size * 0.5
		hand = hand_rect
	else:
		var lbl := Label.new()
		lbl.text = "✋"
		lbl.add_theme_font_size_override("font_size", int(90 * size_mult))
		lbl.pivot_offset = Vector2(45, 45) * size_mult
		hand = lbl

	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand.z_index = 48
	hand.modulate = _parse_color(color, Color(1.3, 1.2, 0.9, 1.0))
	popups.add_child(hand)

	var start_pos: Vector2 = center + Vector2(sweep_dist, -45.0) - hand.pivot_offset
	var hit_pos: Vector2 = center - hand.pivot_offset
	var end_pos: Vector2 = center + Vector2(-sweep_dist, 30.0) - hand.pivot_offset

	# Comienzo: la mano aparece visible en el aire preparándose
	hand.global_position = start_pos
	hand.rotation = deg_to_rad(40.0)
	hand.scale = Vector2(0.4, 0.4)
	hand.modulate.a = 0.0

	var tw: Tween = host.create_tween()
	# 1. Aparición y barrido hacia el objetivo (se aprecia claramente la mano acercándose)
	tw.set_parallel(true)
	tw.tween_property(hand, "modulate:a", 1.0, 0.10)
	tw.tween_property(hand, "global_position", hit_pos, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(hand, "scale", Vector2(1.25, 1.25), 0.32).set_trans(Tween.TRANS_BACK)
	tw.tween_property(hand, "rotation", deg_to_rad(-12.0), 0.32)

	# 2. Momento de impacto: se mantiene sobre el objetivo un instante (pausa de lectura visual)
	tw.chain().tween_callback(func() -> void:
		_shake_target(host, target, 14.0 * size_mult, 0.40)
		_squash_target(host, target, 0.85, 1.15)
		_flash(host, target, 2.2)
		for s in range(6):
			var star: Label = Label.new()
			star.text = "✨" if s % 2 == 0 else "💫"
			star.add_theme_font_size_override("font_size", int(32 * size_mult))
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			star.z_index = 50
			popups.add_child(star)
			star.global_position = center + Vector2(randf_range(-35, 35), randf_range(-35, 35))
			var stw: Tween = host.create_tween()
			stw.set_parallel(true)
			var dest: Vector2 = star.global_position + Vector2(randf_range(-90, 90), randf_range(-80, 30))
			stw.tween_property(star, "global_position", dest, 0.65).set_ease(Tween.EASE_OUT)
			stw.tween_property(star, "scale", Vector2(1.2, 1.2), 0.25)
			stw.chain().tween_property(star, "modulate:a", 0.0, 0.35)
			stw.finished.connect(star.queue_free)
	)
	# Breve retención en el impacto para que el ojo capte la silueta
	tw.tween_interval(0.16)

	# 3. Salida / follow-through más suave y legible
	tw.chain().set_parallel(true)
	tw.tween_property(hand, "global_position", end_pos, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(hand, "rotation", deg_to_rad(-65.0), 0.42)
	tw.tween_property(hand, "modulate:a", 0.0, 0.38).set_delay(0.14)
	tw.finished.connect(hand.queue_free)


## 5. Proyectil Parabólico Balístico
static func projectile_arc(ctx: Dictionary, icon: String = "🪨", color: Variant = Color.WHITE, size_mult: float = 1.05) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var origin: Control = ctx.get("origin")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	var col: Color = color if color is Color else Color.WHITE
	var from_p: Vector2 = _center_of(origin) if origin else _center_of(target) + Vector2(-240, -25)
	var to_p: Vector2 = _center_of(target)

	var sprite_key := ""
	if icon in ["🔥", "fire"]:
		sprite_key = "vfx_fire_orb"
	elif icon in ["❄️", "🧊", "ice"]:
		sprite_key = "vfx_ice_spear"
	elif icon in ["🏹", "arrow"]:
		sprite_key = "vfx_arrow_wind"
	elif icon in ["☣️", "poison"]:
		sprite_key = "vfx_arrow_poison"
	elif icon in ["👻", "phantom"]:
		sprite_key = "vfx_arrow_phantom"
	elif icon in ["🎯", "pierce"]:
		sprite_key = "vfx_arrow_pierce"
	elif icon in ["🌑", "🖤", "dark", "void"]:
		sprite_key = "vfx_dark_blast"
	elif icon in ["🌊", "water", "acid"]:
		sprite_key = "vfx_water_surge"
	elif icon in ["☄️", "🌀", "🔮", "mind", "psychic"]:
		sprite_key = "vfx_mind_orb"
	elif icon in ["🌌", "nova", "galaxy"]:
		sprite_key = "vfx_astral_nova"
	elif icon in ["⏳", "⌛", "clock", "time"]:
		sprite_key = "vfx_clock_dial"

	var tex: Texture2D = _load_sprite_texture(sprite_key) if sprite_key != "" else null
	var proj: Control
	if tex != null:
		var proj_rect := TextureRect.new()
		proj_rect.texture = tex
		proj_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		proj_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		proj_rect.size = Vector2(88, 88) * size_mult
		proj_rect.pivot_offset = proj_rect.size * 0.5
		proj = proj_rect
	else:
		var lbl := Label.new()
		lbl.text = icon
		lbl.add_theme_font_size_override("font_size", int(36 * size_mult))
		lbl.add_theme_color_override("font_color", col)
		lbl.pivot_offset = Vector2(18, 18) * size_mult
		proj = lbl

	proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proj.z_index = 48
	popups.add_child(proj)
	proj.global_position = from_p - proj.pivot_offset

	var tw: Tween = host.create_tween()
	var duration: float = 0.46
	var mid_p: Vector2 = (from_p + to_p) * 0.5 + Vector2(0, -90.0 * size_mult)
	tw.tween_method(func(t: float) -> void:
		var q0: Vector2 = from_p.lerp(mid_p, t)
		var q1: Vector2 = mid_p.lerp(to_p, t)
		var pos_now := q0.lerp(q1, t)
		if is_instance_valid(proj):
			proj.global_position = pos_now - proj.pivot_offset
			var is_directional: bool = sprite_key in ["vfx_arrow_wind", "vfx_arrow_poison", "vfx_arrow_pierce", "vfx_arrow_phantom", "vfx_ice_spear"] or icon in ["🏹", "arrow", "🗡️", "spear", "➳", "knife", "dagger", "bolt", "⚡"]
			if is_directional:
				var next_t := minf(t + 0.05, 1.0)
				var pos_next := from_p.lerp(mid_p, next_t).lerp(mid_p.lerp(to_p, next_t), next_t)
				proj.rotation = (pos_next - pos_now).angle()
			else:
				proj.rotation = t * TAU * 1.5
	, 0.0, 1.0, duration).set_ease(Tween.EASE_IN)

	tw.chain().tween_callback(func() -> void:
		AudioManager.play_sfx("hit")
		_shake_target(host, target, 11.0 * size_mult, 0.30)
		_squash_target(host, target, 0.90, 1.10)
		_flash(host, target, 1.8)
		if is_instance_valid(proj):
			proj.queue_free()
		impact_burst(ctx, col, size_mult)
	)


## 6. Columna / Pilar Mágico
static func magic_pillar(ctx: Dictionary, color: Variant = Color(1.0, 0.9, 0.4), size_mult: float = 1.1) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color(1.0, 0.9, 0.4)
	var center: Vector2 = _center_of(target)
	var h: float = maxf(target.size.y, 240.0) * 1.15 * size_mult
	var w: float = maxf(target.size.x, 140.0) * 0.85 * size_mult

	_shake_target(host, target, 10.0 * size_mult, 0.35)

	var is_fire := (col.r > 0.85 and col.b < 0.3)
	var sprite_key := "vfx_fire_eruption" if is_fire else "vfx_holy_beam"
	var tex := _load_sprite_texture(sprite_key)
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center, Vector2(w * 0.95, h * 0.85), Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.scale = Vector2(0.3, 1.1)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.08)
			tw.tween_property(spr, "scale", Vector2(1.05, 0.95), 0.24).set_ease(Tween.EASE_OUT)
			tw.chain().tween_interval(0.14) # Pilar sostenido para apreciación
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.38)
			_cleanup(host, spr, 0.85)
	else:
		var draw_fn: Callable = func(cnv: Control) -> void:
			var c: Vector2 = cnv.size * 0.5
			var glow: Color = Color(col.r, col.g, col.b, 0.75)
			var core: Color = Color.WHITE
			cnv.draw_line(c + Vector2(0, -h * 0.5), c + Vector2(0, h * 0.5), glow, w * 0.9, true)
			cnv.draw_line(c + Vector2(0, -h * 0.5), c + Vector2(0, h * 0.5), core, w * 0.3, true)
			cnv.draw_arc(c + Vector2(0, h * 0.4), w * 0.55, 0, TAU, 28, glow, 12.0 * size_mult, true)
			cnv.draw_circle(c + Vector2(0, h * 0.4), w * 0.35, Color(col.r, col.g, col.b, 0.18))

		var canvas: Control = _spawn_canvas(popups, center, h * 0.55 + 55.0, draw_fn)
		if canvas == null:
			return
		canvas.modulate.a = 0.0
		canvas.scale = Vector2(0.3, 1.1)
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(canvas, "modulate:a", 1.0, 0.06)
		tw.tween_property(canvas, "scale", Vector2(1.1, 1.0), 0.18).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(canvas, "modulate:a", 0.0, 0.45)
		_cleanup(host, canvas, 0.80)
	_flash(host, target, 2.0)


## 7. Congelación de Hielo (Ice Freeze Shatter)
static func ice_freeze_shatter(ctx: Dictionary, color: Variant = Color(0.3, 0.8, 1.0), size_mult: float = 1.05) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color(0.3, 0.8, 1.0)
	var center: Vector2 = _center_of(target)
	var max_r: float = maxf(target.size.x, 140.0) * 0.75 * size_mult

	var tex := _load_sprite_texture("vfx_ice_frost")
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center, Vector2(max_r * 1.3, max_r * 1.3), Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.scale = Vector2(0.35, 0.35)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.08)
			tw.tween_property(spr, "scale", Vector2(1.05, 1.05), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.chain().tween_interval(0.14) # Escarcha sostenida
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.38)
			tw.parallel().tween_property(spr, "scale", Vector2(1.15, 1.15), 0.38)
			_cleanup(host, spr, 0.85)
	else:
		for i in range(8):
			var flake: Label = Label.new()
			flake.text = "❄️" if i % 2 == 0 else "♦"
			flake.add_theme_font_size_override("font_size", int(28 * size_mult))
			flake.add_theme_color_override("font_color", col)
			flake.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flake.z_index = 47
			popups.add_child(flake)
			flake.global_position = center
			var ang: float = float(i) * (TAU / 8.0)
			var dest: Vector2 = center + Vector2(cos(ang), sin(ang)) * (max_r + randf_range(-10, 20))
			var tw: Tween = host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(flake, "global_position", dest, 0.20).set_ease(Tween.EASE_OUT)
			tw.tween_property(flake, "scale", Vector2(1.15, 1.15), 0.20)
			tw.chain().tween_callback(func() -> void:
				_shake_target(host, target, 10.0 * size_mult, 0.25)
				_flash(host, target, 1.8)
			)
			tw.tween_property(flake, "scale", Vector2(1.35, 1.35), 0.35)
			tw.parallel().tween_property(flake, "modulate:a", 0.0, 0.35)
			tw.finished.connect(flake.queue_free)
	_flash(host, target, 1.8)


## 8. Impacto / Explosión (Impact Burst)
static func impact_burst(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 1.05, _a4: Variant = 1, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color.WHITE
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.05
	var center: Vector2 = _center_of(target)
	var max_r: float = maxf(target.size.x, 140.0) * 0.75 * size_mult

	_shake_target(host, target, 11.0 * size_mult, 0.30)
	_squash_target(host, target, 0.90, 1.10)

	var tex := _load_sprite_texture("vfx_impact_crush")
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center, Vector2(max_r * 1.3, max_r * 1.3), Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.scale = Vector2(0.35, 0.35)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.08)
			tw.tween_property(spr, "scale", Vector2(1.05, 1.05), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.chain().tween_interval(0.12) # Pausa de impacto
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.35)
			tw.parallel().tween_property(spr, "scale", Vector2(1.15, 1.15), 0.35)
			_cleanup(host, spr, 0.75)
	else:
		var draw_fn: Callable = func(cnv: Control) -> void:
			var c: Vector2 = cnv.size * 0.5
			var glow: Color = Color(col.r, col.g, col.b, 0.8)
			var core: Color = Color(1.0, 1.0, 1.0, 1.0)
			cnv.draw_arc(c, max_r * 0.75, 0, TAU, 36, glow, 20.0 * size_mult, true)
			cnv.draw_arc(c, max_r * 0.45, 0, TAU, 36, core, 8.0 * size_mult, true)
			for k in range(10):
				var a: float = float(k) * (TAU / 10.0)
				var p1: Vector2 = c + Vector2(cos(a), sin(a)) * (max_r * 0.35)
				var p2: Vector2 = c + Vector2(cos(a), sin(a)) * (max_r * 1.05)
				cnv.draw_line(p1, p2, core, 4.5 * size_mult, true)
				cnv.draw_circle(p2, 5.0 * size_mult, glow)

		var canvas: Control = _spawn_canvas(popups, center, max_r + 55.0, draw_fn)
		if canvas == null:
			return
		canvas.scale = Vector2(0.15, 0.15)
		canvas.modulate.a = 0.0
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(canvas, "modulate:a", 1.0, 0.06)
		tw.tween_property(canvas, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(canvas, "scale", Vector2(1.3, 1.3), 0.45)
		tw.parallel().tween_property(canvas, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
		_cleanup(host, canvas, 0.80)
	_flash(host, target, 1.9)


## 9. Estocada / Rayo Perforante (Piercing Line)
static func piercing_line(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 1.05, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var origin: Control = ctx.get("origin")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color.WHITE
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.05
	var from_p: Vector2 = _center_of(origin) if origin else _center_of(target) + Vector2(-200, 0)
	var to_p: Vector2 = _center_of(target)
	var dir: Vector2 = (to_p - from_p).normalized()
	var center: Vector2 = (from_p + to_p) * 0.5

	_shake_target(host, target, 9.0 * size_mult, 0.26)

	var tex := _load_sprite_texture("vfx_arrow_pierce")
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center, Vector2(75, 75) * size_mult, Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.rotation = dir.angle()
			spr.scale = Vector2(0.4, 0.4)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.06)
			tw.tween_property(spr, "global_position", to_p - spr.pivot_offset, 0.30).set_ease(Tween.EASE_IN)
			tw.tween_property(spr, "scale", Vector2(1.1, 1.1), 0.30)
			tw.chain().tween_interval(0.12) # Pausa al impactar
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.32)
			_cleanup(host, spr, 0.80)
	else:
		var p_start: Vector2 = to_p - dir * 200.0 * size_mult
		var p_end: Vector2 = to_p + dir * 140.0 * size_mult
		var draw_fn: Callable = func(cnv: Control) -> void:
			var c: Vector2 = cnv.size * 0.5
			var half_vec: Vector2 = (p_end - p_start) * 0.5
			cnv.draw_line(c - half_vec, c + half_vec, Color(col.r, col.g, col.b, 0.7), 22.0 * size_mult, true)
			cnv.draw_line(c - half_vec, c + half_vec, Color.WHITE, 7.0 * size_mult, true)
			cnv.draw_circle(c + half_vec, 14.0 * size_mult, Color(col.r, col.g, col.b, 0.9))

		var canvas: Control = _spawn_canvas(popups, center, 220.0 * size_mult, draw_fn)
		if canvas == null:
			return
		canvas.scale = Vector2(0.15, 1.0)
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(canvas, "scale", Vector2(1.18, 1.18), 0.22).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(canvas, "modulate:a", 0.0, 0.45)
		_cleanup(host, canvas, 0.80)
	_flash(host, target, 1.8)


## 10. Lluvia de Flechas (Arrow Volley)
static func arrow_volley(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 5, a4: Variant = 1.05, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var origin: Control = ctx.get("origin")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	var col: Color = color if color is Color else Color.WHITE
	var count: int = int(a3) if (a3 is int or a3 is float) and int(a3) > 0 else 5
	var size_mult: float = float(a4) if (a4 is int or a4 is float) and float(a4) > 0.0 else 1.05
	var center: Vector2 = _center_of(target)

	var tex := _load_sprite_texture("vfx_arrow_rain")
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center + Vector2(0, -25), Vector2(110, 110) * size_mult, Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.scale = Vector2(0.5, 0.5)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.08)
			tw.tween_property(spr, "scale", Vector2(1.05, 1.05), 0.28).set_ease(Tween.EASE_OUT)
			tw.chain().tween_callback(func() -> void:
				AudioManager.play_sfx("hit")
				_shake_target(host, target, 10.0 * size_mult, 0.25)
				_flash(host, target, 1.8)
			)
			tw.chain().tween_interval(0.14) # Pausa para ver la lluvia de flechas
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.38)
			_cleanup(host, spr, 0.85)
	else:
		var from_p: Vector2 = _center_of(origin) if origin else _center_of(target) + Vector2(-240, -80)
		var to_p: Vector2 = _center_of(target)
		for i in range(count):
			var arrow: Label = Label.new()
			arrow.text = "🏹" if i == 0 else "➳"
			arrow.add_theme_font_size_override("font_size", int(30 * size_mult))
			arrow.add_theme_color_override("font_color", col)
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arrow.z_index = 45
			popups.add_child(arrow)
			var start: Vector2 = from_p + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			var dest: Vector2 = to_p + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			arrow.global_position = start
			arrow.rotation = (dest - start).angle()
			var delay: float = float(i) * 0.08
			var tw: Tween = host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(arrow, "global_position", dest, 0.22).set_delay(delay).set_ease(Tween.EASE_IN)
			tw.chain().tween_callback(func() -> void:
				AudioManager.play_sfx("hit")
				_shake_target(host, target, 8.0 * size_mult, 0.18)
				_flash(host, target, 1.7)
			)
			tw.tween_property(arrow, "modulate:a", 0.0, 0.22)
			tw.finished.connect(arrow.queue_free)


## 11. Haz Continuo (Beam)
static func beam(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 1.1, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var origin: Control = ctx.get("origin")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color.WHITE
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.1
	var p1: Vector2 = _center_of(origin) if origin else _center_of(target) + Vector2(-280, 0)
	var p2: Vector2 = _center_of(target)
	var center: Vector2 = (p1 + p2) * 0.5
	var dist: float = (p2 - p1).length()

	_shake_target(host, target, 12.0 * size_mult, 0.35)

	var tex := _load_sprite_texture("vfx_energy_laser")
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center, Vector2(dist * 1.0, 50.0 * size_mult), Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.rotation = (p2 - p1).angle()
			spr.scale = Vector2(0.2, 1.1)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.06)
			tw.tween_property(spr, "scale", Vector2(1.02, 1.0), 0.22).set_ease(Tween.EASE_OUT)
			tw.chain().tween_interval(0.14) # El rayo se sostiene visible
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.40)
			_cleanup(host, spr, 0.85)
	else:
		var draw_fn: Callable = func(cnv: Control) -> void:
			var c: Vector2 = cnv.size * 0.5
			var half: Vector2 = (p2 - p1) * 0.5
			cnv.draw_line(c - half, c + half, Color(col.r, col.g, col.b, 0.7), 36.0 * size_mult, true)
			cnv.draw_line(c - half, c + half, Color.WHITE, 12.0 * size_mult, true)
			cnv.draw_circle(c + half, 20.0 * size_mult, Color(col.r, col.g, col.b, 0.9))

		var canvas: Control = _spawn_canvas(popups, center, dist * 0.6 + 70.0, draw_fn)
		if canvas == null:
			return
		canvas.modulate.a = 0.0
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(canvas, "modulate:a", 1.0, 0.06)
		tw.tween_property(canvas, "scale", Vector2(1.1, 1.25), 0.22)
		tw.chain().tween_property(canvas, "modulate:a", 0.0, 0.45)
		_cleanup(host, canvas, 0.80)
	_flash(host, target, 2.0)


## 12. Relámpago en Zigzag (Zigzag Bolt)
static func zigzag_bolt(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 1.05, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color.WHITE
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.05
	var center: Vector2 = _center_of(target)
	var h: float = maxf(target.size.y, 220.0) * 1.15 * size_mult

	_shake_target(host, target, 14.0 * size_mult, 0.35)

	var tex := _load_sprite_texture("vfx_lightning_bolt")
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center + Vector2(0, -15), Vector2(h * 0.60, h * 0.85), Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.scale = Vector2(0.5, 1.2)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.05)
			tw.tween_property(spr, "scale", Vector2(1.05, 0.95), 0.16).set_ease(Tween.EASE_OUT)
			tw.chain().tween_interval(0.12) # Breve destello sostenido del rayo
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.38)
			_cleanup(host, spr, 0.75)
	else:
		var draw_fn: Callable = func(cnv: Control) -> void:
			var c: Vector2 = cnv.size * 0.5
			var pts: PackedVector2Array = PackedVector2Array([
				c + Vector2(randf_range(-22, 22), -h * 0.6),
				c + Vector2(randf_range(18, 42), -h * 0.2),
				c + Vector2(randf_range(-42, -18), h * 0.1),
				c + Vector2(randf_range(12, 30), h * 0.4),
				c + Vector2(0, h * 0.6)
			])
			cnv.draw_polyline(pts, Color(col.r, col.g, col.b, 0.8), 20.0 * size_mult, true)
			cnv.draw_polyline(pts, Color.WHITE, 7.0 * size_mult, true)

		var canvas: Control = _spawn_canvas(popups, center, h * 0.6 + 55.0, draw_fn)
		if canvas == null:
			return
		canvas.modulate.a = 0.0
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(canvas, "modulate:a", 1.0, 0.05)
		tw.tween_property(canvas, "scale", Vector2(1.15, 1.15), 0.16)
		tw.chain().tween_property(canvas, "modulate:a", 0.0, 0.45)
		_cleanup(host, canvas, 0.80)
	_flash(host, target, 2.2)


## 13. Vórtice / Remolino (Vortex)
static func vortex(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 1.1, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color.WHITE
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.1
	var center: Vector2 = _center_of(target)
	var max_r: float = maxf(target.size.x, 140.0) * 0.75 * size_mult

	_shake_target(host, target, 11.0 * size_mult, 0.35)

	var sprite_key := "vfx_water_surge" if (col.b > 0.6 and col.r < 0.4) else ("vfx_astral_nova" if (col.r > 0.5 and col.b > 0.6) else "")
	var tex: Texture2D = _load_sprite_texture(sprite_key) if sprite_key != "" else null
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center, Vector2(max_r * 1.3, max_r * 1.3), Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.scale = Vector2(0.3, 0.3)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.06)
			tw.tween_property(spr, "rotation", TAU * 1.5, 0.65).set_ease(Tween.EASE_OUT)
			tw.tween_property(spr, "scale", Vector2(1.05, 1.05), 0.28)
			tw.chain().tween_interval(0.14) # Remolino sostenido
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.38)
			_cleanup(host, spr, 0.90)
	else:
		var draw_fn: Callable = func(cnv: Control) -> void:
			var c: Vector2 = cnv.size * 0.5
			var glow: Color = Color(col.r, col.g, col.b, 0.8)
			var core: Color = Color.WHITE
			for ring in range(3):
				var r: float = max_r * (0.35 + float(ring) * 0.3)
				cnv.draw_arc(c, r, float(ring), float(ring) + 4.5, 30, glow, 18.0 * size_mult, true)
				cnv.draw_arc(c, r, float(ring), float(ring) + 4.5, 30, core, 6.0 * size_mult, true)

		var canvas: Control = _spawn_canvas(popups, center, max_r + 55.0, draw_fn)
		if canvas == null:
			return
		canvas.modulate.a = 0.0
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(canvas, "modulate:a", 1.0, 0.07)
		tw.tween_property(canvas, "rotation", TAU * 2.0, 0.65).set_ease(Tween.EASE_OUT)
		tw.tween_property(canvas, "scale", Vector2(1.2, 1.2), 0.22)
		tw.chain().tween_property(canvas, "modulate:a", 0.0, 0.35)
		_cleanup(host, canvas, 0.80)
	_flash(host, target, 1.8)


## 14. Cúpula Protectora (Shield Dome)
static func shield_dome(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 1.05, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("defend")
	var col: Color = color if color is Color else Color.WHITE
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.05
	var center: Vector2 = _center_of(target)
	var max_r: float = maxf(target.size.x, 140.0) * 0.7 * size_mult
	var draw_fn: Callable = func(cnv: Control) -> void:
		var c: Vector2 = cnv.size * 0.5
		var glow: Color = Color(col.r, col.g, col.b, 0.75)
		var core: Color = Color.WHITE
		cnv.draw_arc(c, max_r, PI * 0.8, PI * 2.2, 32, glow, 20.0 * size_mult, true)
		cnv.draw_arc(c, max_r, PI * 0.8, PI * 2.2, 32, core, 7.0 * size_mult, true)
		cnv.draw_circle(c, max_r * 0.85, Color(col.r, col.g, col.b, 0.16))

	var canvas: Control = _spawn_canvas(popups, center, max_r + 48.0, draw_fn)
	if canvas == null:
		return
	canvas.scale = Vector2(0.3, 0.3)
	canvas.modulate.a = 0.0
	var tw: Tween = host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(canvas, "modulate:a", 1.0, 0.07)
	tw.tween_property(canvas, "scale", Vector2(1.15, 1.15), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(canvas, "scale", Vector2(1.25, 1.25), 0.40)
	tw.parallel().tween_property(canvas, "modulate:a", 0.0, 0.40)
	_cleanup(host, canvas, 0.80)


## 15. Onda Sonora (Roar Wave)
static func roar_wave(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 1.1, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var origin: Control = ctx.get("origin")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color.WHITE
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.1
	var center: Vector2 = _center_of(origin) if origin else _center_of(target)
	var max_r: float = maxf(target.size.x, 160.0) * 0.9 * size_mult
	var draw_fn: Callable = func(cnv: Control) -> void:
		var c: Vector2 = cnv.size * 0.5
		for w in range(4):
			var r: float = max_r * (0.25 + float(w) * 0.28)
			cnv.draw_arc(c, r, -PI * 0.35, PI * 0.35, 24, Color(col.r, col.g, col.b, 0.8), 16.0 * size_mult, true)

	var canvas: Control = _spawn_canvas(popups, center, max_r + 48.0, draw_fn)
	if canvas == null:
		return
	canvas.scale = Vector2(0.2, 0.2)
	var tw: Tween = host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(canvas, "modulate:a", 1.0, 0.06)
	tw.tween_property(canvas, "scale", Vector2(1.25, 1.25), 0.50).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(canvas, "modulate:a", 0.0, 0.28)
	_cleanup(host, canvas, 0.80)
	_flash(host, target, 1.7)


## 16. Estallido de Fragmentos / Terremoto (Elemental Shard Burst)
static func elemental_shard_burst(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 1.05, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("hit")
	var col: Color = color if color is Color else Color.WHITE
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.05
	var center: Vector2 = _center_of(target)
	var max_r: float = maxf(target.size.x, 140.0) * 0.75 * size_mult

	var is_earth := (col.g > 0.5 and col.b < 0.4) or (col.r > 0.5 and col.b < 0.3)
	var sprite_key := "vfx_earth_spike" if is_earth else ("vfx_dark_blast" if (col.r < 0.3 and col.g < 0.3 and col.b < 0.3) else "")
	var tex: Texture2D = _load_sprite_texture(sprite_key) if sprite_key != "" else null
	if tex != null:
		var spr := _spawn_sprite(popups, tex, center, Vector2(max_r * 1.3, max_r * 1.3), Color(1.0, 1.0, 1.0, 0.0))
		if spr != null:
			spr.scale = Vector2(0.4, 0.4)
			var tw := host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(spr, "modulate:a", 1.0, 0.05)
			tw.tween_property(spr, "scale", Vector2(1.05, 1.05), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.chain().tween_property(spr, "modulate:a", 0.0, 0.30)
			_cleanup(host, spr, 0.55)
	else:
		for k in range(8):
			var shard: Label = Label.new()
			shard.text = "♦"
			shard.add_theme_font_size_override("font_size", int(28 * size_mult))
			shard.add_theme_color_override("font_color", col)
			shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shard.z_index = 45
			popups.add_child(shard)
			shard.global_position = center
			var ang: float = float(k) * (TAU / 8.0)
			var dest: Vector2 = center + Vector2(cos(ang), sin(ang)) * (max_r + randf_range(-18, 30))
			var tw: Tween = host.create_tween()
			tw.set_parallel(true)
			tw.tween_property(shard, "global_position", dest, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(shard, "scale", Vector2(1.2, 1.2), 0.18)
			tw.chain().tween_property(shard, "modulate:a", 0.0, 0.26)
			tw.finished.connect(shard.queue_free)
	_flash(host, target, 1.8)


## 17. Motas de Estado (Status Motes)
static func status_motes(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = "✨", a4: Variant = 4, a5: Variant = 1, a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target_override: Control = a6 as Control if a6 is Control else null
	var target: Control = null
	if target_override != null and is_instance_valid(target_override):
		target = target_override
	elif ctx.get("target") is Control:
		target = ctx.get("target") as Control
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	var col: Color = color if color is Color else Color.WHITE
	var icon: String = String(a3) if a3 is String else "✨"
	var count: int = int(a4) if (a4 is int or a4 is float) and int(a4) > 0 else 4
	var dir: int = int(a5) if (a5 is int or a5 is float) else 1
	var center: Vector2 = _center_of(target)
	var num_motes: int = max(3, count)
	var size_mult: float = 1.05
	for i in range(num_motes):
		var lbl: Label = Label.new()
		lbl.text = icon
		lbl.add_theme_font_size_override("font_size", int(28 * size_mult))
		lbl.add_theme_color_override("font_color", col)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 48
		popups.add_child(lbl)
		lbl.global_position = center + Vector2(randf_range(-40, 40), randf_range(-25, 40))
		var vertical_dir: float = float(dir)
		var dest: Vector2 = lbl.global_position + Vector2(randf_range(-38, 38), vertical_dir * randf_range(65, 130))
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "global_position", dest, 0.65).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.20)
		tw.chain().tween_property(lbl, "modulate:a", 0.0, 0.25)
		tw.finished.connect(lbl.queue_free)


## 18. Cruz Sagrada de Sanación (Heal Cross)
static func heal_cross(ctx: Dictionary, color: Variant = Color(0.4, 0.95, 0.4), a3: Variant = 1.1, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	AudioManager.play_sfx("heal")
	var col: Color = color if color is Color else Color(0.4, 0.95, 0.4)
	var size_mult: float = float(a3) if (a3 is int or a3 is float) and float(a3) > 0.0 else 1.1
	var center: Vector2 = _center_of(target)
	var max_r: float = 80.0 * size_mult
	var draw_fn: Callable = func(cnv: Control) -> void:
		var c: Vector2 = cnv.size * 0.5
		var glow: Color = Color(col.r, col.g, col.b, 0.85)
		var core: Color = Color.WHITE
		cnv.draw_line(c + Vector2(0, -max_r), c + Vector2(0, max_r), glow, 24.0 * size_mult, true)
		cnv.draw_line(c + Vector2(-max_r * 0.7, -max_r * 0.25), c + Vector2(max_r * 0.7, -max_r * 0.25), glow, 24.0 * size_mult, true)
		cnv.draw_line(c + Vector2(0, -max_r), c + Vector2(0, max_r), core, 8.0 * size_mult, true)
		cnv.draw_line(c + Vector2(-max_r * 0.7, -max_r * 0.25), c + Vector2(max_r * 0.7, -max_r * 0.25), core, 8.0 * size_mult, true)

	var canvas: Control = _spawn_canvas(popups, center, max_r + 42.0, draw_fn)
	if canvas == null:
		return
	canvas.scale = Vector2(0.3, 0.3)
	canvas.modulate.a = 0.0
	var tw: Tween = host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(canvas, "modulate:a", 1.0, 0.06)
	tw.tween_property(canvas, "scale", Vector2(1.18, 1.18), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(canvas, "global_position:y", center.y - 100.0, 0.60).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(canvas, "modulate:a", 0.0, 0.26)
	_cleanup(host, canvas, 0.75)


## 19. Bocadillo Cómico (Speech Bubble)
static func speech_bubble(ctx: Dictionary, text: Variant = "💬", color: Variant = Color.WHITE, a4: Variant = 1.1, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var origin: Control = ctx.get("origin")
	if host == null or popups == null or origin == null or not is_instance_valid(origin):
		return
	AudioManager.play_sfx("click")
	var txt: String = String(text) if text != null else "💬"
	var col: Color = color if color is Color else Color.WHITE
	var size_mult: float = float(a4) if (a4 is int or a4 is float) and float(a4) > 0.0 else 1.1
	var center: Vector2 = _center_of(origin) + Vector2(0, -90.0)
	var lbl: Label = Label.new()
	lbl.text = "💬 %s" % txt
	lbl.add_theme_font_size_override("font_size", int(26 * size_mult))
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 50
	popups.add_child(lbl)
	lbl.global_position = center - Vector2(85, 20)
	lbl.scale = Vector2(0.3, 0.3)
	var tw: Tween = host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "global_position:y", center.y - 45.0, 0.60).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(lbl, "modulate:a", 0.0, 0.25)
	tw.finished.connect(lbl.queue_free)


## 20. Pulso de Pantalla (Screen Pulse)
static func screen_pulse(ctx: Dictionary, color: Variant = Color.WHITE, _a3: Variant = null, _a4: Variant = null, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	if host == null:
		return
	var col: Color = color if color is Color else Color.WHITE
	var rect: ColorRect = ColorRect.new()
	rect.color = Color(col.r, col.g, col.b, 0.32)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 55
	host.add_child(rect)
	var tw: Tween = host.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.55).set_ease(Tween.EASE_OUT)
	tw.finished.connect(rect.queue_free)


## 21. Destellos Orbitales (Orbit Sparkles)
static func orbit_sparkles(ctx: Dictionary, color: Variant = Color.WHITE, a3: Variant = 1.05, a4: Variant = 5, _a5: Variant = null, _a6: Variant = null, _a7: Variant = null) -> void:
	var host: Control = ctx.get("host")
	var popups: Control = ctx.get("popups")
	var target: Control = ctx.get("target")
	if host == null or popups == null or target == null or not is_instance_valid(target):
		return
	var col: Color = color if color is Color else Color.WHITE
	var icon: String = "✨"
	var size_mult: float = 1.05
	if a3 is String:
		icon = a3
		size_mult = float(a4) if (a4 is int or a4 is float) and float(a4) > 0.0 else 1.05
	elif a3 is int or a3 is float:
		size_mult = float(a3)
	var center: Vector2 = _center_of(target)
	var max_r: float = 105.0 * size_mult
	for k in range(5):
		var star: Label = Label.new()
		star.text = icon
		star.add_theme_font_size_override("font_size", int(26 * size_mult))
		star.add_theme_color_override("font_color", col)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.z_index = 45
		popups.add_child(star)
		var start_ang: float = float(k) * (TAU / 5.0)
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		for step in range(4):
			var a: float = start_ang + float(step) * 0.9
			var p: Vector2 = center + Vector2(cos(a), sin(a)) * max_r
			tw.tween_property(star, "global_position", p, 0.14).set_delay(float(step) * 0.12)
		tw.chain().tween_property(star, "modulate:a", 0.0, 0.25)
		tw.finished.connect(star.queue_free)
