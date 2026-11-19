# ViewOrbRoom.gd
# ─────────────────────────────────────────────────────────────────────────────
# «Sala de la Esfera» — una sala 3D oscura con un pequeño altar y una esfera
# flotante que emana luz azul, bajo un cielo estrellado. No tiene HUD: solo
# muestra un diálogo contextual (bienvenida al empezar, reproche al morir) y,
# al cerrarse, emite `orb_finished(context)` para que GameRoot continúe el flujo.
#
# Es una vista construida por código (sin .tscn), instanciada por GameRoot igual
# que el Tablón de Encargos o la Forja.
# ─────────────────────────────────────────────────────────────────────────────
class_name ViewOrbRoom
extends Control

## Emitida cuando el jugador cierra el diálogo de la sala. `context` es el mismo
## que se pasó a play() ("welcome", "death", …).
signal orb_finished(context: String)

# Cielo estrellado procedimental barato (hash por celda + parpadeo con TIME).
const SKY_SHADER_CODE: String = """
shader_type sky;
void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
	
	// Base color: deep space blue/purple gradient (high contrast with altar/orb)
	vec3 base = mix(vec3(0.01, 0.012, 0.035), vec3(0.003, 0.001, 0.008), up);
	
	// Soft layered cosmic nebula clouds (dynamic, blended look)
	float n1 = sin(d.x * 1.8 + d.y * 1.2) * cos(d.z * 1.5);
	float n2 = cos(d.y * 2.2 - d.x * 1.4) * sin(d.z * 1.1);
	float n3 = sin(d.z * 3.0 + d.x * 2.0) * 0.5 + 0.5;
	float nebula = clamp((n1 + n2 * 0.7 + n3 * 0.3) * 0.35 + 0.25, 0.0, 1.0);
	
	// Deep space teal/blue nebula gas
	vec3 teal_gas = vec3(0.01, 0.04, 0.12) * pow(nebula, 2.0);
	// Deep mystical violet gas
	float violet_pattern = clamp(cos(d.x * 1.2 - d.y * 1.6) * sin(d.z * 2.0) * 0.5 + 0.5, 0.0, 1.0);
	vec3 violet_gas = vec3(0.05, 0.015, 0.08) * pow(violet_pattern, 3.0);
	
	// Stars setup: smooth, anti-aliased round stars instead of box cells
	vec2 uv = vec2(atan(d.x, d.z) * 2.0, asin(clamp(d.y, -1.0, 1.0)) * 2.0);
	vec2 g_uv = uv * 32.0; // scale
	vec2 ipos = floor(g_uv);
	vec2 fpos = fract(g_uv);
	
	float h = fract(sin(dot(ipos, vec2(12.9898, 78.233))) * 43758.5453);
	float dist = length(fpos - 0.5);
	
	float star_mask = step(0.988, h); // 1.2% density
	float tw = 0.45 + 0.55 * sin(TIME * 2.0 + h * 120.0); // twinkle
	
	// Smooth circular glow
	float star = star_mask * (1.0 - smoothstep(0.0, 0.35, dist)) * tw;
	vec3 star_color = vec3(star) * mix(vec3(0.9, 0.95, 1.0), vec3(1.0, 0.9, 0.75), fract(h * 12.0));
	
	COLOR = base + teal_gas + violet_gas + star_color * 1.5;
}
"""

var _sub_viewport: SubViewport
var _orb: MeshInstance3D
var _orb_shell: MeshInstance3D
var _orb_light: OmniLight3D
var _camera: Camera3D
var _dim: ColorRect
var _panel: PanelContainer
var _name_lbl: Label
var _text_lbl: Label
var _continue_btn: Button
var _pending_context: String = ""
var _time: float = 0.0
var _typing_tween: Tween
var _cam_cinematic: bool = false
var _fade_overlay: ColorRect
var _skip_btn: Button
var _more_lbl: Label
var _indicator_tween: Tween
var _text_pages: Array[String] = []
var _page_idx: int = 0
var _is_typing: bool = false
var _intro_phase: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_scene()
	_build_dialogue()
	resized.connect(_update_responsive_layout)
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	GlobalEvents.theme_changed.connect(_on_theme_changed)
	# Activa/desactiva el render 3D según la visibilidad para evitar el error
	# «Texture dimensions exceed device maximum» al renderizar con tamaño 0×0.
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if _sub_viewport == null:
		return
	_sub_viewport.render_target_update_mode = \
		SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED


## Repinta el cuadro de diálogo con el tema activo, sin reconstruir la UI
## (perdería la página/typewriter en curso).
func _on_theme_changed(_theme_id: String) -> void:
	if _panel != null:
		UiKit.premium_frame(_panel, {"pad": 0})
	if _name_lbl != null:
		_name_lbl.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	if _text_lbl != null:
		_text_lbl.add_theme_color_override("font_color", UiKit.theme_color("text", UiKit.TEXT))
	if _more_lbl != null:
		_more_lbl.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT))
	if _continue_btn != null:
		UiKit.premium_button(_continue_btn)
	if _skip_btn != null:
		UiKit.premium_button(_skip_btn, {"border_width": 2.0, "corner_radius": 12.0})


func _update_responsive_layout() -> void:
	if _panel == null:
		return
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var is_landscape := sz.x > sz.y
	if is_landscape:
		var max_w := sz.x - 120.0
		_panel.anchor_left = 0.5
		_panel.anchor_right = 0.5
		_panel.anchor_top = 1.0
		_panel.anchor_bottom = 1.0
		_panel.offset_left = -max_w * 0.5
		_panel.offset_right = max_w * 0.5
		# panel agrandado (era -250, muy justo para 180px de
		# texto + cabecera + botón/indicador) para igualar el margen real que
		# usa ViewPlace (sistema narrativo 2D) en la misma orientación.
		_panel.offset_top = -320.0
		_panel.offset_bottom = -30.0
		if _name_lbl != null:
			_name_lbl.add_theme_font_size_override("font_size", 28)
		if _text_lbl != null:
			_text_lbl.add_theme_font_size_override("font_size", 32)
	else:
		_panel.anchor_left = 0.0
		_panel.anchor_right = 1.0
		_panel.anchor_top = 1.0
		_panel.anchor_bottom = 1.0
		_panel.offset_left = 24.0
		_panel.offset_right = -24.0
		# idem, era -340 (316px de alto) — ahora coherente con
		# los ~440px que usa ViewPlace en portrait.
		_panel.offset_top = -420.0
		_panel.offset_bottom = -24.0
		if _name_lbl != null:
			_name_lbl.add_theme_font_size_override("font_size", 30)
		if _text_lbl != null:
			_text_lbl.add_theme_font_size_override("font_size", 36)


## Construye la sala 3D dentro de un SubViewport.
func _build_scene() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_sub_viewport = SubViewport.new()
	_sub_viewport.own_world_3d = true
	_sub_viewport.transparent_bg = false
	_sub_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_sub_viewport.positional_shadow_atlas_size = 0
	# OPTIMIZACIÓN: arranca en UPDATE_DISABLED para no intentar renderizar
	# mientras la vista está oculta (tamaño 0×0 → error de textura en bucle).
	# Se activa en _on_visibility_changed cuando la vista se hace visible.
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(_sub_viewport)

	var world_root := Node3D.new()
	_sub_viewport.add_child(world_root)

	# ── Cámara mirando al altar ──
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.current = true
	_camera.position = Vector3(0.0, 1.7, 3.4)

	# ── Entorno: sala oscura con cielo estrellado y niebla azul tenue ──
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_shader := Shader.new()
	sky_shader.code = SKY_SHADER_CODE
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sky_shader
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.08, 0.16)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.03, 0.08)
	env.fog_density = 0.06
	env.fog_sky_affect = 0.0
	_camera.environment = env
	world_root.add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)

	# ── Suelo (única superficie): disco de piedra oscura pulida ──
	var floor_inst := MeshInstance3D.new()
	var floor_cyl := CylinderMesh.new()
	floor_cyl.top_radius = 7.0
	floor_cyl.bottom_radius = 7.0
	floor_cyl.height = 0.4
	floor_cyl.radial_segments = 40
	floor_inst.mesh = floor_cyl
	floor_inst.position.y = -0.2
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.04, 0.05, 0.08)
	floor_mat.roughness = 0.15
	floor_mat.metallic = 0.7
	floor_inst.material_override = floor_mat
	world_root.add_child(floor_inst)

	# ── Altar: estilo obsidiana con alta reflectividad + bandas rúnicas brillantes ──
	var obsidian := StandardMaterial3D.new()
	obsidian.albedo_color = Color(0.07, 0.08, 0.12)
	obsidian.roughness = 0.22
	obsidian.metallic = 0.85

	var altar_base := MeshInstance3D.new()
	var ab := CylinderMesh.new()
	ab.top_radius = 0.62; ab.bottom_radius = 0.78; ab.height = 0.35; ab.radial_segments = 24
	altar_base.mesh = ab
	altar_base.position.y = 0.175
	altar_base.material_override = obsidian
	world_root.add_child(altar_base)

	var altar_shaft := MeshInstance3D.new()
	var ash := CylinderMesh.new()
	ash.top_radius = 0.42; ash.bottom_radius = 0.5; ash.height = 0.45; ash.radial_segments = 20
	altar_shaft.mesh = ash
	altar_shaft.position.y = 0.575
	altar_shaft.material_override = obsidian
	world_root.add_child(altar_shaft)

	var altar_top := MeshInstance3D.new()
	var at := CylinderMesh.new()
	at.top_radius = 0.6; at.bottom_radius = 0.5; at.height = 0.2; at.radial_segments = 24
	altar_top.mesh = at
	altar_top.position.y = 0.9
	altar_top.material_override = obsidian
	world_root.add_child(altar_top)

	# Bandas rúnicas emisivas (anillos de luz azul en el altar)
	var rr_mat := StandardMaterial3D.new()
	rr_mat.albedo_color = Color(0.0, 0.5, 1.0)
	rr_mat.emission_enabled = true
	rr_mat.emission = Color(0.1, 0.5, 1.0)
	rr_mat.emission_energy_multiplier = 4.0

	var runic_ring := MeshInstance3D.new()
	var rr_mesh := CylinderMesh.new()
	rr_mesh.top_radius = 0.46; rr_mesh.bottom_radius = 0.46; rr_mesh.height = 0.05; rr_mesh.radial_segments = 20
	runic_ring.mesh = rr_mesh
	runic_ring.position.y = 0.575
	runic_ring.material_override = rr_mat
	world_root.add_child(runic_ring)

	var top_ring := MeshInstance3D.new()
	var tr_mesh := CylinderMesh.new()
	tr_mesh.top_radius = 0.56; tr_mesh.bottom_radius = 0.56; tr_mesh.height = 0.03; tr_mesh.radial_segments = 24
	top_ring.mesh = tr_mesh
	top_ring.position.y = 0.85
	top_ring.material_override = rr_mat
	world_root.add_child(top_ring)

	# ── Esfera flotante con luz azul cálida (Núcleo) ──
	_orb = MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.36
	orb_mesh.height = 0.72
	orb_mesh.radial_segments = 32
	orb_mesh.rings = 20
	_orb.mesh = orb_mesh
	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.55, 0.78, 1.0)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.35, 0.62, 1.0)
	orb_mat.emission_energy_multiplier = 3.0
	orb_mat.rim_enabled = true
	orb_mat.roughness = 0.15
	_orb.material_override = orb_mat
	_orb.position = Vector3(0.0, 1.35, 0.0)
	world_root.add_child(_orb)

	# Capa exterior traslúcida (Holograma/Shell)
	_orb_shell = MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.40
	shell_mesh.height = 0.80
	shell_mesh.radial_segments = 32
	shell_mesh.rings = 20
	_orb_shell.mesh = shell_mesh
	var shell_mat := StandardMaterial3D.new()
	shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_mat.albedo_color = Color(0.7, 0.9, 1.0, 0.3)
	shell_mat.emission_enabled = true
	shell_mat.emission = Color(0.2, 0.5, 1.0)
	shell_mat.emission_energy_multiplier = 1.5
	shell_mat.roughness = 0.05
	shell_mat.rim_enabled = true
	shell_mat.rim = 0.8
	shell_mat.rim_tint = 0.5
	_orb_shell.material_override = shell_mat
	_orb_shell.position = Vector3(0.0, 1.35, 0.0)
	world_root.add_child(_orb_shell)

	_orb_light = OmniLight3D.new()
	_orb_light.light_color = Color(0.55, 0.72, 1.0)
	_orb_light.light_energy = 4.0
	_orb_light.omni_range = 14.0
	_orb_light.omni_attenuation = 1.2
	_orb_light.position = Vector3(0.0, 1.35, 0.0)
	world_root.add_child(_orb_light)

	# Halo interior extra para dar cuerpo al brillo de la esfera
	var halo := OmniLight3D.new()
	halo.light_color = Color(0.75, 0.88, 1.0)
	halo.light_energy = 1.6
	halo.omni_range = 4.0
	halo.position = Vector3(0.0, 1.35, 0.0)
	world_root.add_child(halo)

	# ── Partículas mágicas (Stardust) flotando alrededor de la esfera ──
	var particles := CPUParticles3D.new()
	particles.amount = 35
	particles.lifetime = 2.4
	particles.preprocess = 1.5
	particles.randomness = 0.5
	particles.position = Vector3(0.0, 1.35, 0.0)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.45
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 45.0
	particles.gravity = Vector3(0.0, 0.15, 0.0)
	particles.initial_velocity_min = 0.05
	particles.initial_velocity_max = 0.25
	
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.1))
	scale_curve.add_point(Vector2(0.4, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve
	
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	p_mat.albedo_color = Color(0.65, 0.88, 1.0, 0.85)
	
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.025
	p_mesh.height = 0.05
	p_mesh.radial_segments = 8
	p_mesh.rings = 6
	particles.mesh = p_mesh
	particles.material_override = p_mat
	world_root.add_child(particles)


## Material low-poly reutilizable (albedo + rugosidad).
func _mat(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = 0.0
	return m


## Construye un panel de diálogo propio anclado abajo (estilo novela visual, como
## los Lugares). No depende de medir tamaños en runtime, así que nunca queda fuera
## de pantalla aunque se abra durante el arranque del juego.
func _build_dialogue() -> void:
	# Capa oscura sutil para dar foco al diálogo.
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.45)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Panel anclado al borde inferior (ancho completo, altura fija).
	_panel = PanelContainer.new()
	UiKit.premium_frame(_panel, {"pad": 0})
	_panel.visible = false
	add_child(_panel)
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = 60
	_panel.offset_right = -60
	_panel.offset_top = -250
	_panel.offset_bottom = -30

	var m := UiKit.margins(24, 24, 16, 16)
	_panel.add_child(m)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	m.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)
	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 24)
	_name_lbl.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT_SOFT))
	_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_name_lbl)

	_text_lbl = Label.new()
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.add_theme_font_size_override("font_size", 30)
	_text_lbl.add_theme_color_override("font_color", UiKit.theme_color("text", UiKit.TEXT))
	_text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# altura mínima garantizada para que el texto nunca quede
	# apretado/cortado por un panel demasiado bajo, igual que el resto del
	# sistema narrativo (ViewPlace/NarrativeOverlay).
	_text_lbl.custom_minimum_size.y = 180
	vbox.add_child(_text_lbl)

	# Indicador de «hay más texto»: parpadea al final de cada página intermedia.
	_more_lbl = Label.new()
	_more_lbl.add_theme_font_size_override("font_size", 30)
	_more_lbl.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.ACCENT))
	_more_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more_lbl.visible = false
	vbox.add_child(_more_lbl)

	_continue_btn = Button.new()
	_continue_btn.custom_minimum_size = Vector2(0, 70)
	_continue_btn.add_theme_font_size_override("font_size", 32)
	UiKit.premium_button(_continue_btn)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_continue_btn.visible = false
	vbox.add_child(_continue_btn)

	# Avanzar página al tocar/clicar en el panel (novela visual).
	_panel.gui_input.connect(_on_panel_input)

	# Capa de overlay negra para transición/fundido de salida.
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.visible = false
	add_child(_fade_overlay)
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Botón de SKIP arriba a la derecha para saltar la conversación directamente.
	_skip_btn = Button.new()
	_skip_btn.text = Locale.pick({
		"es": "SALTAR  »",
		"en": "SKIP  »",
		"fr": "PASSER  »",
		"it": "SALTA  »",
		"de": "ÜBERSPRINGEN  »",
		"zh": "跳过  »",
		"ja": "スキップ  »"
	})
	_skip_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skip_btn.offset_left = -180.0
	_skip_btn.offset_right = -24.0
	_skip_btn.offset_top = 24.0
	_skip_btn.offset_bottom = 80.0
	_skip_btn.add_theme_font_size_override("font_size", 24)
	UiKit.premium_button(_skip_btn, {"border_width": 2.0, "corner_radius": 12.0})
	_skip_btn.pressed.connect(_skip_conversation)
	add_child(_skip_btn)


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════
## Entra en la sala mostrando el diálogo del contexto dado.
func play(context: String) -> void:
	if SceneManager != null:
		SceneManager.current_view_name = "orb_room"
	AudioManager.play_music("orb_room")
	_pending_context = context
	var data := _dialogue_for(context)
	if _fade_overlay:
		_fade_overlay.visible = false
		_fade_overlay.color.a = 0.0
	_dim.visible = true
	_panel.visible = true
	if _skip_btn:
		_skip_btn.visible = true
	_panel.modulate.a = 0.0
	_text_lbl.visible_characters = 0
	_continue_btn.modulate.a = 0.0
	_continue_btn.text = String(data["button"])
	
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()

	if context == "welcome":
		# 1. Colocar cámara lejos
		_camera.position = Vector3(0.0, 2.2, 7.5)
		_cam_cinematic = true
		_camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)
		
		# Mostrar panel de diálogo
		var panel_tw := create_tween()
		panel_tw.tween_property(_panel, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
		
		# 2. Primer texto corto: "Bienvenido. Acércate..."
		_name_lbl.text = Locale.pick({"es": "La Esfera", "en": "The Orb"})
		var intro_text = Locale.pick({
			"es": "Vaya, vaya... mira lo que ha traído la marea. Acércate, no muerdo. Casi nunca.",
			"en": "Well, well... look what the tide dragged in. Come closer, I don't bite. Hardly ever."
		})
		_resize_panel_for_text(intro_text)
		_text_lbl.text = intro_text
		_text_lbl.visible_characters = 0
		
		_typing_tween = create_tween()
		# /§14: respeta el ajuste de accesibilidad de velocidad de
		# texto, igual que el resto del sistema narrativo (NarrativeOverlay/ViewBuilding).
		_typing_tween.tween_property(_text_lbl, "visible_characters", intro_text.length(), intro_text.length() * 0.035 / maxf(Locale.text_speed, 0.1))
		_typing_tween.finished.connect(func() -> void:
			_is_typing = false
			_intro_phase = true
			if _more_lbl:
				_more_lbl.text = Locale.pick({"es": "▶  Toca para continuar", "en": "▶  Tap to continue"})
				_more_lbl.visible = true
				_more_lbl.modulate.a = 1.0
				_indicator_tween = _more_lbl.create_tween().set_loops()
				_indicator_tween.tween_property(_more_lbl, "modulate:a", 0.3, 0.55).set_ease(Tween.EASE_IN_OUT)
				_indicator_tween.tween_property(_more_lbl, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_IN_OUT)
		)
	else:
		# Comportamiento normal (ej. al morir)
		_camera.position = Vector3(0.0, 1.7, 3.4)
		_camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)
		
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
		
		_name_lbl.text = String(data["name"])
		_present_pages(String(data["text"]))


## Construye los datos del diálogo según el contexto de la sala.
func _dialogue_for(context: String) -> Dictionary:
	var text := ""
	match context:
		"welcome":
			text = Locale.pick({
				"es": "Déjame adivinar: ni idea de quién eres, ni de quién soy, ni de qué narices haces aquí. Tranquilo, es lo normal cuando uno la lía tan pero tan gorda como tú. ¿Qué hiciste? Ni te lo cuento; te daría algo. Digamos que el mundo ahí fuera tiene unas cuantas preguntas para ti... y ninguna es amable. Venga va, te voy a contar el gran secreto de qué ha pasado, quién eres, dónde estás, incluso el secreto de la vida, pero antes hazme un favor, sal de la sala por la puerta que tienes detrás, sube a la planta de arriba y enciende la luz tirando de la palanca que da a tu izquierda. Ve, levántate y anda.",
				"en": "Let me guess: no clue who you are, who I am, or what on earth you're doing here. Relax, that's perfectly normal when you botch things as spectacularly as you did. What did you do? I won't tell you; you'd faint. Let's just say the world out there has a few questions for you... none of them polite. Come on, I'll tell you the great secret of what happened, who you are, where you are, even the secret of life, but first do me a favor, leave the room through the door behind you, go up to the floor above and turn on the light by pulling the lever on your left. Go, get up and walk.",
			})
		"death":
			text = Locale.pick(_death_text_for_cause())
		_:
			text = Locale.pick({
				"es": "La esfera palpita en silencio.",
				"en": "The orb pulses silently.",
			})
	return {
		"name": Locale.pick({"es": "La Esfera", "en": "The Orb"}),
		"text": text,
		"button": UiKit.strip_emojis(Locale.pick({"es": "Levantarse y andar", "en": "Get up and walk"})),
	}


## Elige la frase de reproche de la Esfera según `GlobalState.pending_death_cause`
## (rellenado justo antes de morir por combate o peligro ambiental — ver
## `CombatDamageResolver._end_combat`, `TabWorld3D._apply_terrain_hazard`,
## `GameRoot._player_died_from_hazard` y `ViewDungeon._on_player_died`). Se
## consume una sola vez: si la causa no está reconocida, cae al mensaje
## genérico de siempre para garantizar que SIEMPRE haya una respuesta.
func _death_text_for_cause() -> Dictionary:
	var info: Dictionary = GlobalState.pending_death_cause
	GlobalState.pending_death_cause = {}
	var cause := String(info.get("cause", ""))
	var default_text := {
		"es": "¿En serio? ¿Ya? Y yo que pensaba que este tenía potencial... Anda, sacúdete el polvo y vuelve a intentarlo, campeón. No tengo todo el día. Bueno, en realidad sí, pero tú no.",
		"en": "Seriously? Already? And here I thought this one had potential... Come on, dust yourself off and try again, champ. I don't have all day. Well, actually I do — but you don't.",
	}
	match cause:
		"level1":
			return default_text
		"boss":
			return {
				"es": "¿En serio pensabas que estabas a la altura de ESE jefe? Ese boss parece que es demasiado para ti, campeón. Sube de nivel, mejora el equipo y vuelve a intentarlo... las prisas no matan. Bueno, sí, acaban de matarte.",
				"en": "Did you really think you were ready for THAT boss? That one seems to be too much for you, champ. Level up, gear up, and try again... haste doesn't kill. Well, actually, it just did.",
			}
		"normal_high":
			return {
				"es": "Vaya, menuda paliza te ha dado ese mataos cualquiera. ¿Has probado a huir cuando ves que no puedes con él? Apenas le rascaste la pintura, no te hagas el valiente.",
				"en": "Wow, that random nobody really handed you a beating. Ever tried fleeing when you can't handle a fight? You barely scratched its paint, don't play the hero.",
			}
		"normal_low":
			return {
				"es": "Vaya, te ha matado un cualquiera... pero por los pelos. Sabes que no debes apurar tanto, ¿no? Usa pociones si ves que vas a morir, o huye si te queda poca vida y no tienes con qué curarte. Pero no te hagas el valiente.",
				"en": "Wow, some random nobody killed you... but just barely. You know you shouldn't push it that far, right? Use potions if you're about to die, or flee if you're low on health with nothing to heal with. But don't play the hero.",
			}
		"hazard":
			match String(info.get("hazard_type", "")):
				"spikes":
					return {
						"es": "Cuidado con los pinchos. Los pinchos pinchan. Es obvio, pero parece que para ti no.",
						"en": "Careful with the spikes. Spikes are, in fact, spiky. Obvious, but apparently not for you.",
					}
				"void_fall":
					return {
						"es": "¿En serio te has suicidado tirándote por un barranco? Ni el vacío te quería tanto.",
						"en": "Did you seriously just throw yourself off a cliff? Not even the void wanted you that badly.",
					}
				"lava", "lav":
					return {
						"es": "La lava quema. Mucho. Es lava. ¿De verdad hacía falta que te lo dijera?",
						"en": "Lava burns. A lot. It's lava. Did I really need to spell that one out for you?",
					}
				"pol", "tox", "poison", "contaminacion":
					return {
						"es": "El veneno no perdona. Podrías haber usado un antídoto, o simplemente no respirar contaminación. Ambas eran opciones válidas.",
						"en": "Poison doesn't forgive. You could have used an antidote, or simply not breathed in toxic fumes. Both were valid options.",
					}
				"heat":
					return {
						"es": "El calor del desierto no era una sugerencia, era una advertencia. Deberías haberla escuchado.",
						"en": "The desert heat wasn't a suggestion, it was a warning. You should have listened.",
					}
				"cold":
					return {
						"es": "El frío te ha calado hasta los huesos... literalmente. Abrígate la próxima vez.",
						"en": "The cold chilled you to the bone... literally. Dress warmer next time.",
					}
				_:
					return default_text
		_:
			return default_text


## El jugador toca/clicka durante el texto inicial: inicia el viaje de cámara.
func _finish_intro() -> void:
	_intro_phase = false
	if _more_lbl:
		_more_lbl.visible = false
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	
	# Ocultar panel de diálogo temporalmente durante el viaje
	var hide_tw := create_tween()
	hide_tw.tween_property(_panel, "modulate:a", 0.0, 0.3)
	
	# Zoom de cámara
	var zoom_tw := create_tween()
	zoom_tw.tween_property(_camera, "position", Vector3(0.0, 1.7, 3.4), 2.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Efecto de latido/brillo incrementado mientras se acerca
	var light_tw := create_tween()
	light_tw.tween_property(_orb_light, "light_energy", 12.0, 1.1)
	light_tw.tween_property(_orb_light, "light_energy", 4.0, 1.1)
	
	await zoom_tw.finished
	_cam_cinematic = false
	_camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)
	
	# Mostrar panel de nuevo
	var show_tw := create_tween()
	show_tw.tween_property(_panel, "modulate:a", 1.0, 0.4)
	
	# 3. Lanzar diálogo principal (paginado: no cabe en una sola pantalla).
	var data := _dialogue_for(_pending_context)
	_name_lbl.text = String(data["name"])
	_present_pages(String(data["text"]))


func _on_continue_pressed() -> void:
	var ctx := _pending_context
	_pending_context = ""
	
	# Desvanecer panel de diálogo
	var panel_tw := create_tween()
	panel_tw.tween_property(_panel, "modulate:a", 0.0, 0.25)
	
	# Activar y desvanecer a negro el overlay de pantalla
	if _fade_overlay:
		_fade_overlay.visible = true
		var fade_tw := create_tween()
		fade_tw.tween_property(_fade_overlay, "color:a", 1.0, 0.55).set_ease(Tween.EASE_OUT)
		await fade_tw.finished
	
	_panel.visible = false
	_dim.visible = false
	if _skip_btn:
		_skip_btn.visible = false
	if _fade_overlay:
		_fade_overlay.visible = false
		_fade_overlay.color.a = 0.0
	orb_finished.emit(ctx)


## Salta toda la conversación inicial de la Esfera de forma inmediata.
func _skip_conversation() -> void:
	_intro_phase = false
	if _more_lbl:
		_more_lbl.visible = false
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()
	var ctx := _pending_context if _pending_context != "" else "welcome"
	_pending_context = ""
	AudioManager.play_sfx("click")
	if _fade_overlay:
		_fade_overlay.visible = true
		var fade_tw := create_tween()
		fade_tw.tween_property(_fade_overlay, "color:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
		await fade_tw.finished
	_panel.visible = false
	_dim.visible = false
	if _skip_btn:
		_skip_btn.visible = false
	if _fade_overlay:
		_fade_overlay.visible = false
		_fade_overlay.color.a = 0.0
	orb_finished.emit(ctx)


# ══════════════════════════════════════════════════════════════════════════════
# PAGINACIÓN DE TEXTO (novela visual: el discurso de la Esfera no cabe en una
# sola pantalla, así que se trocea en páginas y se avanza tocando/clicando).
# ══════════════════════════════════════════════════════════════════════════════
## Trocea `full_text` en páginas y muestra la primera con máquina de escribir.
func _present_pages(full_text: String) -> void:
	_text_pages = _split_text_into_pages(full_text)
	_page_idx = 0
	_continue_btn.modulate.a = 0.0
	_continue_btn.disabled = true
	_continue_btn.visible = false
	_show_page()


## Presupuesto de altura fijo reservado por la cabecera (retrato+nombre), los
## márgenes del panel y la fila de botón/indicador «continuar» — el resto de
## la altura del panel es lo que le queda de verdad a `_text_lbl`.
const _DIALOGUE_CHROME_HEIGHT: float = 162.0

## Alto máximo REAL disponible para el texto dentro del panel actual (según su
## orientación/tamaño ya resueltos por `_update_responsive_layout`), en vez de
## un tope fijo (260px) que no se correspondía con el alto real del panel en
## ninguna orientación — sobre todo en horizontal, donde el panel es más bajo
## y ese tope quedaba muy por encima del hueco real. Al no coincidir, tanto el
## resize como la paginación (abajo) infrautilizaban el espacio disponible,
## cortando el texto en páginas mucho más cortas de lo que cabía visualmente
## ("los textos no están aprovechando el
## espacio que tienen en el recuadro, cortándose muy pronto").
func _max_dialogue_text_height() -> float:
	var panel_h: float = _panel.size.y if _panel != null else 0.0
	if panel_h <= 1.0:
		var sz := get_viewport_rect().size
		panel_h = 396.0 if sz.x <= sz.y else 290.0
	return maxf(60.0, panel_h - _DIALOGUE_CHROME_HEIGHT)


## Ajusta dinámicamente la altura mínima de `_text_lbl` (y por tanto la del
## panel, que crece con `SIZE_EXPAND_FILL`) según las líneas que ocupará
## REALMENTE el texto envuelto (autowrap) a la anchura actual — en vez de una
## altura fija que a veces sobraba (párrafos cortos con hueco vacío) o
## apuraba (párrafos largos casi cortados). Acotada entre 60px (una línea) y
## el alto real disponible (`_max_dialogue_text_height()`).
func _resize_panel_for_text(text: String) -> void:
	if _text_lbl == null:
		return
	var font: Font = _text_lbl.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var fsize := _text_lbl.get_theme_font_size("font_size")
	if fsize <= 0:
		fsize = 30
	var wrap_w := _text_lbl.size.x
	if wrap_w <= 1.0:
		# Aún no hay layout resuelto (primera apertura): estimar con el ancho
		# actual del panel menos sus márgenes, o un fallback razonable.
		wrap_w = (_panel.size.x - 80.0) if (_panel != null and _panel.size.x > 1.0) else 700.0
	var text_size: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fsize)
	_text_lbl.custom_minimum_size.y = clampf(text_size.y, 60.0, _max_dialogue_text_height())


## Divide el texto en páginas midiendo el alto REAL que ocupará envuelto al
## ancho del label (mismo criterio y presupuesto que `_resize_panel_for_text`),
## en vez de un límite arbitrario de 120 caracteres que no tenía relación
## alguna con el espacio visual disponible — cada página ahora aprovecha TODO
## el alto que el panel puede ofrecerle antes de pasar a la siguiente.
func _split_text_into_pages(text: String) -> Array[String]:
	var pages: Array[String] = []
	var font: Font = _text_lbl.get_theme_font("font") if _text_lbl != null else null
	if font == null:
		font = ThemeDB.fallback_font
	var fsize := (_text_lbl.get_theme_font_size("font_size") if _text_lbl != null else 0)
	if fsize <= 0:
		fsize = 30
	var wrap_w := _text_lbl.size.x if _text_lbl != null else 0.0
	if wrap_w <= 1.0:
		wrap_w = (_panel.size.x - 80.0) if (_panel != null and _panel.size.x > 1.0) else 700.0
	var max_h := _max_dialogue_text_height()

	var paragraphs := text.split("\n\n")
	for para in paragraphs:
		var current_chunk := ""
		var words := para.split(" ")
		for word in words:
			var candidate := word if current_chunk == "" else current_chunk + " " + word
			var h: float = font.get_multiline_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fsize).y
			if h > max_h and current_chunk != "":
				pages.append(current_chunk.strip_edges())
				current_chunk = word
			else:
				current_chunk = candidate
		if current_chunk != "":
			pages.append(current_chunk.strip_edges())
	if pages.is_empty():
		pages.append("")
	return pages


## Muestra la página actual con la máquina de escribir; al terminar, decide si
## mostrar el indicador «hay más» o el botón de continuar (última página).
func _show_page() -> void:
	if _page_idx >= _text_pages.size():
		return
	var page_text := _text_pages[_page_idx]
	_resize_panel_for_text(page_text)
	_text_lbl.text = page_text
	_text_lbl.visible_characters = 0
	_is_typing = true
	if _more_lbl:
		_more_lbl.visible = false
		if _indicator_tween and _indicator_tween.is_valid():
			_indicator_tween.kill()
	if _typing_tween and _typing_tween.is_valid():
		_typing_tween.kill()
	_typing_tween = create_tween()
	var char_duration: float = 0.02 / maxf(Locale.text_speed, 0.1)
	_typing_tween.tween_property(_text_lbl, "visible_characters", page_text.length(), maxf(0.2, page_text.length() * char_duration))
	_typing_tween.finished.connect(func() -> void:
		_is_typing = false
		_update_more_indicator()
	)


## Al final de una página: parpadea «▼ Toca para continuar» si hay más páginas,
## o revela el botón de continuar si es la última.
func _update_more_indicator() -> void:
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	if _page_idx < _text_pages.size() - 1:
		_continue_btn.visible = false
		_continue_btn.disabled = true
		if _more_lbl:
			_more_lbl.text = Locale.pick({"es": "▼ Toca para continuar", "en": "▼ Tap to continue"})
			_more_lbl.visible = true
			_more_lbl.modulate.a = 1.0
			_indicator_tween = _more_lbl.create_tween().set_loops()
			_indicator_tween.tween_property(_more_lbl, "modulate:a", 0.3, 0.55).set_ease(Tween.EASE_IN_OUT)
			_indicator_tween.tween_property(_more_lbl, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_IN_OUT)
	else:
		if _more_lbl:
			_more_lbl.visible = false
		_continue_btn.disabled = false
		_continue_btn.visible = true
		var btn_tw := create_tween()
		btn_tw.tween_property(_continue_btn, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)


## Avanza el diálogo: si está escribiendo, completa la página; si no, pasa a la
## siguiente. No hace nada en la última página (el botón cierra la sala).
func _advance_pages() -> void:
	if _text_pages.is_empty():
		return
	if _is_typing:
		_is_typing = false
		if _typing_tween and _typing_tween.is_valid():
			_typing_tween.kill()
		_text_lbl.visible_characters = -1
		_update_more_indicator()
		return
	if _page_idx < _text_pages.size() - 1:
		_page_idx += 1
		_show_page()


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _intro_phase:
			_finish_intro()
		else:
			_advance_pages()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			get_viewport().set_input_as_handled()
			if _intro_phase:
				_finish_intro()
			else:
				_advance_pages()


# ══════════════════════════════════════════════════════════════════════════════
# ANIMACIÓN (flotación y latido de la esfera)
# ══════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var pulse := sin(_time * 2.2)
	if _orb:
		_orb.position.y = 1.35 + sin(_time * 1.6) * 0.08
		_orb.rotation.y += delta * 0.4
		_orb.rotation.x += delta * 0.15
		var mat := _orb.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 3.0 + pulse * 1.0
	if _orb_shell:
		_orb_shell.position.y = _orb.position.y
		_orb_shell.rotation.y -= delta * 0.6
		_orb_shell.rotation.z += delta * 0.25
		var mat := _orb_shell.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 1.5 + pulse * 0.5
	if _orb_light:
		_orb_light.light_energy = 4.0 + pulse * 1.2
	if _cam_cinematic and _camera:
		_camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)
