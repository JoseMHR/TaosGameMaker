# MainMenu.gd
# Pantalla de inicio del juego.
# - Nueva Partida: borra el guardado y comienza desde cero (con confirmación si ya hay progreso).
# - Continuar: carga el guardado y reanuda exactamente por donde se dejó (activo solo si hay guardado).
# - Opciones: idioma (es/en) y audio, persistentes.
# - Créditos: acredita a JoseMHR.
# Todos los textos se traducen mediante Locale y se refrescan al cambiar idioma.
class_name MainMenu
extends Control

const OPTIONS_SCENE: PackedScene = preload("res://scenes/ui/options/OptionsMenu.tscn")
const CREDITS_SCENE: PackedScene = preload("res://scenes/ui/credits/CreditsScreen.tscn")
const GAME_ROOT_PATH: String = "res://scenes/game/game_root/GameRoot.tscn"

# ─── REFERENCIAS ─────────────────────────────────────────────────────────────
@onready var lbl_title: Label    = $MarginMain/VBoxContent/LblTitle
@onready var lbl_subtitle: Label = $MarginMain/VBoxContent/LblSubtitle
@onready var btn_new_game: Button = $MarginMain/VBoxContent/VBoxButtons/BtnNewGame
@onready var btn_debug_mode: Button = $MarginMain/VBoxContent/VBoxButtons/HBoxDebugAndTest/BtnDebug
@onready var btn_test_room: Button = $MarginMain/VBoxContent/VBoxButtons/HBoxDebugAndTest/BtnTestRoom
@onready var hbox_debug: HBoxContainer = $MarginMain/VBoxContent/VBoxButtons/HBoxDebugAndTest
@onready var vsep_dbg: Control = $MarginMain/VBoxContent/VBoxButtons/VSepDbg
@onready var lbl_hero: Label = $MarginMain/VBoxContent/LblHero
@onready var btn_continue: Button = $MarginMain/VBoxContent/VBoxButtons/BtnContinue
@onready var btn_options: Button  = $MarginMain/VBoxContent/VBoxButtons/BtnOptions
@onready var btn_credits: Button  = $MarginMain/VBoxContent/VBoxButtons/BtnCredits
@onready var btn_quit: Button     = $MarginMain/VBoxContent/VBoxButtons/BtnQuit
var _overlay: Control = null

# ─── EASTER EGG / DESBLOQUEO DE DEBUG (3 clics en LblHero o secuencia "taos") ─
var _secret_clicks: int = 0
var _secret_key_buffer: String = ""
var _hero_sway_time: float = 0.0

# ─── MODO DEMO / ATTRACT (reproduce intro tras 5s de inactividad) ───────────
const IDLE_ATTRACT_TIMEOUT: float = 5.0
var _idle_timer: float = 0.0
var _is_attract_mode: bool = false


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	if SceneManager != null:
		SceneManager.go_to_menu()
	_build_background()
	UiKit.apply_heading(lbl_title)
	if not Locale.locale_changed.is_connected(_refresh_texts):
		Locale.locale_changed.connect(_refresh_texts)
	_refresh_texts()
	_update_continue_state()
	_init_secret_triggers()
	_animate_title()
	AudioManager.play_music("menu")
	if not resized.is_connected(_update_responsive_layout):
		resized.connect(_update_responsive_layout)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_update_responsive_layout):
		vp.size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()


func _exit_tree() -> void:
	_cancel_attract_mode()


func _process(delta: float) -> void:
	# Animación continua de vaivén horizontal del elemento
	if lbl_hero != null and is_instance_valid(lbl_hero):
		_hero_sway_time += delta * 1.8
		var parent_ctl := lbl_hero.get_parent_control()
		if parent_ctl != null and parent_ctl.size.x > 0.0:
			var base_center_x := (parent_ctl.size.x - lbl_hero.size.x) * 0.5
			lbl_hero.position.x = base_center_x + sin(_hero_sway_time) * 45.0

	if _overlay != null and is_instance_valid(_overlay):
		_idle_timer = 0.0
		return
	if _is_attract_mode:
		return
	if SceneRunner != null and SceneRunner.is_active():
		_idle_timer = 0.0
		return
	_idle_timer += delta
	if _idle_timer >= IDLE_ATTRACT_TIMEOUT:
		_idle_timer = 0.0
		_start_attract_mode()


func _input(event: InputEvent) -> void:
	if _is_attract_mode:
		if (event is InputEventKey and event.is_pressed()) or (event is InputEventMouseButton and event.is_pressed()) or (event is InputEventScreenTouch and event.is_pressed()):
			_cancel_attract_mode()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		_idle_timer = 0.0
	elif event is InputEventMouseMotion and event.velocity.length_squared() > 100.0:
		_idle_timer = 0.0

	# Reconocimiento de secuencia secreta por teclado: "t a o s"
	if event is InputEventKey and event.pressed and not event.echo:
		var k := ""
		if event.keycode == KEY_T:
			k = "t"
		elif event.keycode == KEY_A:
			k = "a"
		elif event.keycode == KEY_O:
			k = "o"
		elif event.keycode == KEY_S:
			k = "s"
		elif event.unicode >= 32:
			var c := char(event.unicode).to_lower()
			if c in ["t", "a", "o", "s"]:
				k = c
			else:
				_secret_key_buffer = ""
		else:
			_secret_key_buffer = ""

		if k != "":
			_secret_key_buffer += k
			if _secret_key_buffer.length() > 4:
				_secret_key_buffer = _secret_key_buffer.right(4)
			if _secret_key_buffer == "taos":
				_secret_key_buffer = ""
				_reveal_debug_buttons()


func _start_attract_mode() -> void:
	if not Design.has_cinematic("intro"):
		return
	_is_attract_mode = true
	if NarrativeOverlay != null:
		NarrativeOverlay.attract_mode = true
		if not NarrativeOverlay.attract_interrupted.is_connected(_cancel_attract_mode):
			NarrativeOverlay.attract_interrupted.connect(_cancel_attract_mode)

	SceneRunner.scene_finished.connect(_on_attract_finished, CONNECT_ONE_SHOT)
	SceneRunner.start_scene("intro")


func _cancel_attract_mode() -> void:
	if not _is_attract_mode:
		return
	_is_attract_mode = false
	if NarrativeOverlay != null:
		NarrativeOverlay.attract_mode = false
		if NarrativeOverlay.attract_interrupted.is_connected(_cancel_attract_mode):
			NarrativeOverlay.attract_interrupted.disconnect(_cancel_attract_mode)
	if SceneRunner != null:
		if SceneRunner.scene_finished.is_connected(_on_attract_finished):
			SceneRunner.scene_finished.disconnect(_on_attract_finished)
		SceneRunner.stop()
	AudioManager.play_music("menu")
	_idle_timer = 0.0


func _on_attract_finished(_sc_id: String) -> void:
	if not _is_attract_mode:
		return
	_is_attract_mode = false
	if NarrativeOverlay != null:
		NarrativeOverlay.attract_mode = false
		if NarrativeOverlay.attract_interrupted.is_connected(_cancel_attract_mode):
			NarrativeOverlay.attract_interrupted.disconnect(_cancel_attract_mode)
	AudioManager.play_music("menu")
	_idle_timer = 0.0


func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var is_landscape := sz.x > sz.y
	var margin_main: MarginContainer = get_node_or_null("MarginMain") as MarginContainer
	var vbox_buttons: Control = get_node_or_null("MarginMain/VBoxContent/VBoxButtons") as Control

	if margin_main != null:
		if is_landscape:
			margin_main.add_theme_constant_override("margin_left", 60)
			margin_main.add_theme_constant_override("margin_right", 60)
			margin_main.add_theme_constant_override("margin_top", 40)
			margin_main.add_theme_constant_override("margin_bottom", 40)
		else:
			margin_main.add_theme_constant_override("margin_left", 48)
			margin_main.add_theme_constant_override("margin_right", 48)
			margin_main.add_theme_constant_override("margin_top", 80)
			margin_main.add_theme_constant_override("margin_bottom", 60)

	if vbox_buttons != null:
		if is_landscape:
			vbox_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vbox_buttons.custom_minimum_size.x = clampf(sz.x * 0.42, 480.0, 750.0)
		else:
			vbox_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox_buttons.custom_minimum_size.x = 0.0


## Fondo con portada de inicio de alta calidad y una capa de oscurecimiento suave para legibilidad.
func _build_background() -> void:
	# 1. Imagen de fondo (portada)
	var bg_path := "res://assets/common/ui/main_menu_bg.png"
	var bg_tex: Texture2D = load(bg_path) if ResourceLoader.exists(bg_path) else null
	if bg_tex == null:
		push_warning("No se pudo cargar la imagen de fondo del menú principal!")
	
	if bg_tex:
		var bg_rect := TextureRect.new()
		bg_rect.texture = bg_tex
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_rect)
		bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		move_child(bg_rect, 1) # Detrás de la interfaz

	# 2. Capa de degradado oscuro semi-transparente para asegurar la legibilidad del texto
	var grad := Gradient.new()
	grad.set_color(0, Color(0.04, 0.03, 0.08, 0.55)) # Degradado superior semi-transparente
	grad.set_color(1, Color(0.02, 0.02, 0.04, 0.90)) # Degradado inferior oscuro para los botones
	grad.add_point(0.4, Color(0.03, 0.02, 0.06, 0.70))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(0.0, 1.0)
	grad_tex.width = 64
	grad_tex.height = 256
	
	var overlay := TextureRect.new()
	overlay.texture = grad_tex
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if bg_tex:
		move_child(overlay, 2) # Delante de la portada, detrás del contenido
	else:
		move_child(overlay, 1)


## Animación sutil de "respiración" del icono del título.
func _animate_title() -> void:
	if lbl_hero == null:
		return
	lbl_hero.pivot_offset = lbl_hero.size / 2.0
	var tw := lbl_hero.create_tween().set_loops()
	tw.tween_property(lbl_hero, "scale", Vector2(1.10, 1.10), 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl_hero, "scale", Vector2(1.0, 1.0), 1.4).set_trans(Tween.TRANS_SINE)


# ─── EASTER EGG: REVELAR BOTONES DE DEBUG ────────────────────────────────────
func _init_secret_triggers() -> void:
	if hbox_debug != null:
		hbox_debug.visible = false
	if vsep_dbg != null:
		vsep_dbg.visible = false
	if lbl_hero != null:
		if not lbl_hero.gui_input.is_connected(_on_hero_gui_input):
			lbl_hero.gui_input.connect(_on_hero_gui_input)


func _on_hero_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		_on_secret_hero_clicked()
		get_viewport().set_input_as_handled()


func _on_secret_hero_clicked() -> void:
	_idle_timer = 0.0
	_secret_clicks += 1
	_animate_hero_feedback()
	
	if _secret_clicks < 3:
		AudioManager.play_sfx("click")
	else:
		_reveal_debug_buttons()


func _animate_hero_feedback() -> void:
	if lbl_hero == null:
		return
	var tw := lbl_hero.create_tween()
	tw.tween_property(lbl_hero, "scale", Vector2(1.35, 1.35), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl_hero, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE)


func _reveal_debug_buttons() -> void:
	if hbox_debug == null:
		return
	if hbox_debug.visible:
		AudioManager.play_sfx("click")
		return

	AudioManager.play_sfx("levelup")
	hbox_debug.visible = true
	if vsep_dbg != null:
		vsep_dbg.visible = true

	# Efecto de aparición suave
	hbox_debug.modulate.a = 0.0
	var tw := hbox_debug.create_tween()
	tw.tween_property(hbox_debug, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _refresh_texts() -> void:
	lbl_title.text    = Locale.t("app_title")
	lbl_subtitle.text = Locale.t("app_subtitle")
	btn_new_game.text = Locale.t("menu_new_game")
	btn_debug_mode.text = Locale.t("menu_debug_mode")
	btn_test_room.text = Locale.t("menu_test_room")
	btn_continue.text = Locale.t("menu_continue")
	btn_options.text  = Locale.t("menu_options")
	btn_credits.text  = Locale.t("menu_credits")
	if btn_quit != null:
		btn_quit.text = Locale.t("menu_quit")


## Habilita "Continuar" solo si existe una partida guardada.
func _update_continue_state() -> void:
	var has_save: bool = SaveManager.has_save()
	btn_continue.disabled = not has_save
	btn_continue.modulate = Color(1, 1, 1, 1.0) if has_save else Color(1, 1, 1, 0.4)


# ══════════════════════════════════════════════════════════════════════════════
# BOTONES DEL MENÚ
# ══════════════════════════════════════════════════════════════════════════════
## Pide confirmación si hay progreso; si no, arranca una partida nueva.
func _on_btn_new_game_pressed() -> void:
	_cancel_attract_mode()
	AudioManager.play_sfx("main_menu_click")
	if SaveManager.has_save():
		_show_new_game_confirm()
	else:
		_start_new_game()


func _start_new_game() -> void:
	_cancel_attract_mode()
	SaveManager.delete_save()
	_ensure_real_world()
	GlobalState.reset_for_new_game(false)
	# Forzar seen_intro = false para que GameRoot arranque en el prólogo.
	GlobalState.seen_intro = false
	if SaveManager != null:
		SaveManager.active = true
	SceneManager.change_view_threaded(GAME_ROOT_PATH)


## Modo Debug: partida de pruebas (nivel/oro/equipo altos, movimiento x3).
## Usa un guardado COMPLETAMENTE INDEPENDIENTE del normal (ver SaveManager):
## nunca borra ni sobrescribe la partida real, así que no hace falta pedir
## confirmación (nada que el jugador pueda perder).
func _on_btn_debug_mode_pressed() -> void:
	_cancel_attract_mode()
	AudioManager.play_sfx("main_menu_click")
	_start_debug_game()


func _start_debug_game() -> void:
	_cancel_attract_mode()
	_ensure_real_world()
	GlobalState.reset_for_new_game(true)
	if SaveManager != null:
		SaveManager.active = true
	SceneManager.change_view_threaded(GAME_ROOT_PATH)


## Sala de Tests: héroe maxeado, todas las profesiones, inventario/equipo completos,
## velocidad x3 y mapamundi de pruebas con dos mazmorras. Guardado independiente:
## no toca la partida real (ver comentario de _on_btn_debug_mode_pressed).
func _on_btn_test_room_pressed() -> void:
	_cancel_attract_mode()
	AudioManager.play_sfx("main_menu_click")
	_start_test_room()


func _start_test_room() -> void:
	_cancel_attract_mode()
	# Cargar el mapamundi reducido de pruebas antes de inicializar el estado.
	Design.is_test_room = true
	Design.reload()
	GlobalState.reset_for_test_room()
	if SaveManager != null:
		SaveManager.active = true
	SceneManager.change_view_threaded(GAME_ROOT_PATH)


## Asegura que Design use el mundo REAL (por si se venía de la Sala de Tests).
func _ensure_real_world() -> void:
	if Design.is_test_room:
		Design.is_test_room = false
		Design.reload()


## Carga el guardado y reanuda la partida.
func _on_btn_continue_pressed() -> void:
	_cancel_attract_mode()
	AudioManager.play_sfx("main_menu_click")
	if not SaveManager.has_save():
		return
	SaveManager.load_game()
	SceneManager.change_view_threaded(GAME_ROOT_PATH)


func _on_btn_options_pressed() -> void:
	_cancel_attract_mode()
	AudioManager.play_sfx("main_menu_click")
	_open_overlay(OPTIONS_SCENE.instantiate())


func _on_btn_credits_pressed() -> void:
	_cancel_attract_mode()
	AudioManager.play_sfx("main_menu_click")
	var cs := CREDITS_SCENE.instantiate()
	cs.set("show_post_game_prompt", false)
	_open_overlay(cs)


func _on_btn_quit_pressed() -> void:
	AudioManager.play_sfx("main_menu_click")
	get_tree().quit()


# ══════════════════════════════════════════════════════════════════════════════
# GESTIÓN DE OVERLAYS (opciones / créditos / confirmación)
# ══════════════════════════════════════════════════════════════════════════════
func _open_overlay(node: Control) -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = node
	add_child(node)
	if node.has_signal("closed"):
		node.closed.connect(_close_overlay)


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_update_continue_state()
	_refresh_texts()


## Diálogo de confirmación antes de borrar el progreso al empezar de nuevo.
func _show_new_game_confirm() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	var on_ok := func() -> void: _start_new_game()
	_overlay = UiKit.confirm(
		self,
		Locale.t("menu_new_game_confirm_title"),
		Locale.t("menu_new_game_confirm_body"),
		Locale.t("menu_confirm"),
		Locale.t("menu_cancel"),
		on_ok,
		UiKit.BAD
	)
