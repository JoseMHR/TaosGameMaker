# ViewCombat.gd
# ─────────────────────────────────────────────────────────────────────────────
# SISTEMA DE COMBATE REDISEÑADO: TIEMPO REAL ACTIVO (ATB) + SINERGIAS + DEFENSA ACTIVA
#
# Interfaz responsiva e interactiva construida íntegramente por código.
# ─────────────────────────────────────────────────────────────────────────────
class_name ViewCombat
extends Control

@warning_ignore("unused_signal")
signal combat_ended(victory: bool)

# ─── CONSTANTES DE COMBATE ───────────────────────────────────────────────────
const MAX_QUEUE: int = 3                     # Slots visuales de la cola (máx. 3 en Resonancia MÁX)
const PLAYER_ATB_CHARGE_RATE: float = 25.0  # % de carga por segundo (llena en 4s)
const ENEMY_ATB_CHARGE_RATE: float = 20.0   # % de carga por segundo (llena en 5s)
const DEFENSE_COOLDOWN_MAX: float = 5.0     # Cooldown de defensa activa (s)
const FLEE_COOLDOWN_MAX: float = 5.0        # Cooldown para reintentar huida tras pulsar Huir (s)
const DEFENSE_ACTIVE_DURATION: float = 1.0  # Duración de invulnerabilidad (s)
## Ventana de reacción de "bullet-time" (task_reforma_defensa.md, FASE 1): los
## últimos 0.4s (en puntos de ATB, a ENEMY_DISCHARGE_RATE=100/s) del golpe
## enemigo antes del impacto, durante los cuales el tiempo se ralentiza y se
## proyecta el anillo de impacto (FASE 2) sobre el héroe.
const BULLET_TIME_ATB_WINDOW: float = 40.0
const BULLET_TIME_SCALE: float = 0.3

# ─── REFERENCIAS DE NODOS (GENERADOS PROGRAMÁTICAMENTE) ─────────────────────
var _bg_texture_rect: TextureRect
var _lbl_level: Label
var _lbl_class: Label
var _lbl_gold: Label

@warning_ignore("unused_private_class_variable")
var _lbl_atb_top: Label            # ATB del jugador (%) mostrado en el Top HUD
## Título "ATB" junto a la barra del jugador; pasa a "▶ TU TURNO" en dorado al
## llenarse (indicador breve de a quién le toca actuar).
var _lbl_atb_title: Label
var _lbl_enemy_name: Label
var _lbl_enemy_hp: Label
var _bar_enemy_hp: ProgressBar
var _bar_enemy_hp_ghost: ProgressBar   # Barra "fantasma" rezagada (daño reciente)
var _lbl_ctx_info: RichTextLabel   # Línea contextual de debilidades/resistencias
var _enemy_img_rect: TextureRect
var _enemy_sprite_container: Control
@warning_ignore("unused_private_class_variable")
var _enemy_shadow: Control = null
var _enemy_platform: TextureRect    # Plataforma de suelo del enemigo
var _enemy_panel: VBoxContainer     # Panel superior con nombre/barras del enemigo
var _combat_area: Control            # Área central de combate (enemigo + panel derecho)
var _hero_sprite_rect: TextureRect   # Sprite a cuerpo entero del protagonista (lado izquierdo del escenario)
var _damage_popups_node: Control
var _shield_overlay: Control
var _pause_overlay: CanvasLayer = null
var is_paused: bool = false
@warning_ignore("unused_private_class_variable")
var _atb_glow_tween: Tween = null   # Resplandor de la barra ATB llena
## Insignia PERSISTENTE (no un popup fugaz) sobre la cabeza del enemigo mientras
## descarga su ataque, además de la barra ATB para jugadores
## que no están mirando la barra constantemente. Se muestra en
## `_telegraph_enemy_intent` y se oculta al ejecutar la acción.
var _lbl_enemy_intent_badge: Label
## Pulso/resplandor en bucle sobre el botón DEFENDER mientras
## el enemigo descarga su ataque, para avisar de que hay que reaccionar.
var _defense_pulse_tween: Tween = null
var _enemy_attack_banner: PanelContainer = null
var _lbl_attack_banner_title: Label = null
var _lbl_attack_banner_sub: Label = null
var _attack_banner_tween: Tween = null

var _queue_slots: Array[PanelContainer] = []
var _queue_separators: Array[Control] = []
var _bar_player_atb: ProgressBar
@warning_ignore("unused_private_class_variable")
var _lbl_player_atb: Label
var _bar_enemy_atb: ProgressBar
var _grid_scroll: ScrollContainer   # Scroll vertical que envuelve la cuadrícula 3x2

## Bloques de nivel superior de la "consola de combate" unificada
## Promovidos a miembros para poder reordenarlos
## (reparentarlos) entre el layout horizontal y el reflow vertical/móvil sin
## reconstruir toda la UI. Ver `_apply_console_layout()`.
var _combat_console: PanelContainer = null
var _console_landscape_row: HBoxContainer = null   ## Fila horizontal: [héroe | combo | acciones]
var _console_portrait_col: VBoxContainer = null    ## Columna vertical: [héroe] [combo] [(habilidades | acciones)]
var _console_portrait_bottom_row: HBoxContainer = null  ## Fila inferior del reflow portrait
var _hero_status_dock: PanelContainer = null
var _skills_panel: PanelContainer = null
var _hero_right_column: PanelContainer = null
var _console_is_portrait_layout: bool = false

var _btn_attack: Button
var _btn_defense: Button
var _btn_skills: Button = null
var _btn_items: Button = null
var _btn_defense_cooldown_panel: Panel
var _lbl_defense_cooldown_text: Label

var _bar_player_hp: ProgressBar
var _bar_player_hp_ghost: ProgressBar   # Barra "fantasma" rezagada (daño reciente)
var _lbl_player_hp: Label
## Etiqueta "HP" junto a la barra; cambia a un icono de aviso en peligro (<25%)
## además del color rojo de la barra (accesibilidad daltónica).
var _lbl_hp_tag: Label
var _bar_player_mp: ProgressBar
var _lbl_player_mp: Label
var _portrait_frame: PanelContainer      # Marco circular del retrato del jugador
var _portrait_texture: TextureRect       # Imagen real del protagonista
var _portrait_label: Label               # Inicial de fallback si no hay imagen
var _resonance_circle: ResonanceCircle
var _profession_modal: PanelContainer
var _professions_grid: GridContainer
var _enemy_debuffs_container: HBoxContainer
var is_resonance_active: bool = false
var _quick_info_panel: PanelContainer
var _lbl_quick_type: Label
var _lbl_quick_power: Label
var _lbl_quick_desc: Label
var _is_deck_open: bool = true
var _content_grid: GridContainer
var _tab_buttons: Array[Button] = []
var _right_panel: PanelContainer       # Panel derecho con tabs/cartas/acciones (solo en horizontal)
var _lbl_synergy_chain: Label
var _synergy_queue_panel: PanelContainer
var _center_dock: VBoxContainer
var combat_log: RichTextLabel  # Mantenido por compatibilidad (no visible)
var _log_overlay: PanelContainer # Panel de log flotante inferior-izquierdo (horizontal)
var _lbl_log_prev: Label       # Fila superior: mensaje anterior (pequeño, gris)
var _lbl_log_curr: Label       # Fila inferior: mensaje actual (grande, blanco)
var result_panel: PanelContainer
var lbl_result: Label
var lbl_result_detail: Label
var btn_return: Button
var btn_flee: Button
var btn_pause: Button
var btn_one_hit_kill: Button = null
var _top_hud: HBoxContainer = null

# ─── ESTADO DEL COMBATE ──────────────────────────────────────────────────────
var combat_queue: Array[Dictionary] = []
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_data: Dictionary = {}
var is_combat_active: bool = false
var is_intro_playing: bool = false
var turn_count: int = 0
@warning_ignore("unused_private_class_variable")
var _last_victory: bool = false
## Profesiones que han ejecutado al menos una habilidad de profesión (no
## pociones, ni el "cambio de clase" en sí) durante ESTE combate. Se usa al
## ganar para repartir XP de trabajo individual a cada una (ver
## `docs/design/PROGRESSION.md` §3 y `CombatDamageResolver._end_combat`).
var _jobs_used_this_combat: Array[String] = []
var _orco_turn_count: int = 0
var _orco_suplicar_count: int = 0
var _first_hit_blocked: bool = false
var _eco_confused: bool = false
var _eco_enraged: bool = false
var _eco_process_timer: float = 0.0

# ATB y Cooldowns
var player_atb: float = 0.0
var enemy_atb: float = 0.0
var defense_active_time: float = 0.0
var defense_cooldown: float = 0.0
var _defense_free_timer: float = 0.0
var _time_decay_acc: float = 0.0
var flee_cooldown: float = 0.0
var is_invulnerable: bool = false
var _hero_hurt_timer: float = 0.0
var _hero_attack_timer: float = 0.0
var _hero_action_tween: Tween = null
var _enemy_is_discharging: bool = false
var _enemy_has_hit: bool = false
const ENEMY_DISCHARGE_RATE: float = 100.0
var enemy_hit_threshold: float = 40.0
## Radios (px) del anillo de impacto (task_reforma_defensa.md, FASE 2),
## recalculados en `_update_defense_ring_geometry()` a partir del perfil de
## bloqueo activo (`_block_profile`) — la MISMA fuente de verdad que usa
## `_on_btn_defense_pressed` para decidir la mitigación real, así el anillo
## nunca puede desincronizarse de lo que de verdad otorga la defensa.
var _ring_target_radius: float = 30.0
var _ring_perfect_radius: float = 35.0
var _ring_normal_radius: float = 90.0
const RING_MAX_RADIUS: float = 165.0
## Instancia viva del anillo de impacto mientras dura el "bullet-time"
## (`null` fuera de la ventana de reacción del golpe enemigo).
var _defense_ring: DefenseImpactRing = null
## `true` mientras el tiempo está ralentizado (`Engine.time_scale`) y el
## anillo de impacto proyectado sobre el héroe (últimos BULLET_TIME_ATB_WINDOW
## puntos de la descarga del enemigo).
var _bullet_time_active: bool = false
## `true` mientras el zoom de cámara de enfoque sobre el héroe está activo
## (desde que el enemigo empieza a descargar su ataque hasta que se resuelve).
var _camera_focus_active: bool = false
## TELEGRAFÍA: acción que el enemigo ANUNCIÓ al empezar a descargar su ATB y que
## ejecutará al cruzar el umbral. Da al jugador una ventana para defender/bloquear.
## {} = ataque básico genérico (sin habilidad). Se limpia tras ejecutar.
var _pending_enemy_skill: Dictionary = {}
var _enemy_intent_shown: bool = false

# ─── SISTEMA DE PUNTOS DE ACCIÓN (PA) ────────────────────────────────────────
var current_pa_limit: int = GameConfig.PA_LIMIT_NORMAL  # Límite de PA del turno actual
var queued_pa: int = 0                                  # PA acumulados en la cola
var _executing_queue: bool = false                      # ¿Ejecutando la secuencia?

# ─── SISTEMA DE RESONANCIA (reemplaza SP) ────────────────────────────────────
var player_resonance: float = 0.0     # Barra de Resonancia (0..100)
var resonant_pending: bool = false    # La Resonancia llegó a 100 → el próximo turno es Resonante
var is_resonant_turn: bool = false    # El turno actual es Resonante (4 PA, coste -1)
var _resonant_aura: Control = null     # Panel inferior (borde animado en Estado Resonante)

# ─── PERFIL DE BLOQUEO ACTIVO (QTE de defensa por profesión) ─────────────────
var _block_profile: Dictionary = GameConfig.BLOCK_PROFILE_NONE   # perfil de bloqueo vigente
var _block_quality: String = ""       # "" | "normal" | "perfect" (defensa activa vigente)

# ─── ESCALA TEMPORAL SUAVIZADA (cámara lenta al decidir) ─────────────────────
# Se interpola hacia la escala objetivo para que la entrada/salida de la cámara
# lenta sea gradual (el tiempo casi se detiene, nunca de golpe).
var _world_time_scale: float = 1.0

# Animación y sacudidas
@warning_ignore("unused_private_class_variable")
var _enemy_anim_time: float = 0.0
var _enemy_sprite_base_y: float = 0.0
@warning_ignore("unused_private_class_variable")
var _shake_tween: Tween = null
@warning_ignore("unused_private_class_variable")
var _resonance_glow_tween: Tween = null   # Resplandor pulsante de la barra de Resonancia al 100%
var _enemy_hp_ghost_tween: Tween = null   # Drenado rezagado de la barra fantasma del enemigo
var _player_hp_ghost_tween: Tween = null  # Drenado rezagado de la barra fantasma del jugador
@warning_ignore("unused_private_class_variable")
var _atk_pulse_tween: Tween = null        # Brillo/pulso continuo del botón EJECUTAR
var _resonant_aura_tween: Tween = null    # Tween del ciclo de color del borde resonante
@warning_ignore("unused_private_class_variable")
var _atk_was_enabled: bool = false        # Flanco para pulsar EJECUTAR al habilitarse
@warning_ignore("unused_private_class_variable")
var _def_was_enabled: bool = false        # Flanco para pulsar DEFENDER al habilitarse
@warning_ignore("unused_private_class_variable")
var _hp_danger_tween: Tween = null        # Pulso de aviso en la barra de HP propia en peligro
var _hp_was_in_danger: bool = false
var _active_tab: String = "powers"

# Estados alterados
var enemy_statuses: Dictionary = {}
var player_statuses: Dictionary = {}
var _lbl_enemy_status: Label
var _lbl_player_status: Label
var _resurreccion_used: bool = false
var _extra_turns: int = 0
var _pending_revive_pct: int = 0      # >0 → auto-revive por effect "revive:pct" (Second Chance/Resurrection)

# Las habilidades viven en data/skills.json (por ID); la progresión por profesión
# en data/professions.json ({level, id}); y las sinergias en data/synergies.json
# (por IDs). Se resuelven con Design.get_skill / get_profession_skills / get_synergy.

# ─── PALETA DE UI (rediseño mobile-vertical) ─────────────────────────────────
# Paleta única y cohesiva para todo el combate: fondos profundos violáceos,
# acento dorado, y colores de rol para EJECUTAR (cian) y DEFENDER (magenta).
const COL_BG_DEEP    := Color(0.03, 0.02, 0.05, 1.0)     # lavado del fondo tras el sprite
const COL_PANEL      := Color(0.04, 0.035, 0.07, 0.96)   # paneles sólidos (negro púrpura muy oscuro)
const COL_PANEL_SOFT := Color(0.06, 0.05, 0.10, 0.80)    # paneles translúcidos
const COL_BORDER     := Color(0.24, 0.16, 0.38, 0.8)     # borde púrpura elegante 3px
const COL_GOLD       := Color(0.98, 0.80, 0.32)          # acento principal
const COL_TEXT       := Color(0.93, 0.93, 0.98)          # texto primario
const COL_TEXT_DIM   := Color(0.62, 0.62, 0.75)          # texto secundario
const COL_ATTACK     := Color(0.26, 0.62, 0.96)          # EJECUTAR (cian)
const COL_DEFEND     := Color(0.74, 0.40, 0.98)          # DEFENDER (magenta)
const COL_FLEE       := Color(0.86, 0.44, 0.44)          # Huir (rojo apagado)

# ─── SISTEMA DE TEMAS PARA EL REDISEÑO HORIZONTAL ────────────────────────────
# Paleta por defecto (azul/dorado oscuro). Las demás se activarán desde Opciones.
# la paleta de los 8 temas se centralizó en `UiKit.THEMES`
# (antes vivía duplicada aquí); `_theme_color()` sigue usando el snapshot
# `_ui_theme_id` cacheado en `_ready()` (no `Locale.ui_theme_id` en vivo) para
# no re-tintar el combate a medio turno si el jugador cambia el tema.
@export_enum("default", "crimson", "happyflower", "void", "emerald", "solari", "cyber", "astral") var _ui_theme_id: String = "default"
var _is_landscape: bool = false


## Separador vertical fino entre los 3 bloques de la consola de combate
## unificada: sustituye a los 3 `neoclassic_panel`
## sueltos de antes por una simple línea de acento dentro de UN solo marco
## premium (`combat_console`).
func _make_console_divider() -> Control:
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(2, 0)
	sep.color = _theme_color("accent", Color(0.98, 0.80, 0.32, 0.35))
	sep.color.a = 0.30
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return sep


## Estilo "glossy" reutilizable para barras de progreso (ATB héroe/enemigo):
## Fondo oscuro con borde de acento y relleno con
## sombra/brillo tintado del propio color, en vez del relleno plano de antes.
## Es el fallback sin shader documentado en la tarea (más simple que un
## shader de barra dedicado, pero ya no es un color liso sin vida).
func _style_glossy_bar(bar: ProgressBar, fill_color: Color, radius: int = 6) -> void:
	bar.show_percentage = false
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	bg_style.set_corner_radius_all(radius)
	bg_style.set_border_width_all(2)
	bg_style.border_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.55)
	bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color.lightened(0.08)
	fill_style.set_corner_radius_all(radius)
	fill_style.shadow_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.55)
	fill_style.shadow_size = 6
	# Franja superior más clara (simula brillo especular sin shader).
	fill_style.border_width_top = 2
	fill_style.border_color = fill_color.lightened(0.45)
	bar.add_theme_stylebox_override("fill", fill_style)


## Crea un StyleBoxFlat de panel coherente con la paleta. Centraliza el estilo
## de todos los paneles del rediseño (radio, borde y sombra opcional).
func _panel_style(bg: Color, radius: int = 16, border_c: Color = COL_BORDER, border_w: int = 1, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_w)
	s.border_color = border_c
	if shadow > 0:
		s.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		s.shadow_size = shadow
	return s


## Pulso/resplandor alternado sobre DEFENDER mientras el
## enemigo descarga su ataque (respeta reduce_motion: sin animación, solo un
## resalte de color fijo). Combina el cambio de color
## con un pulso de ESCALA (1.0 → 1.08) para que el aviso sea evidente incluso
## si el jugador no está mirando directamente al botón.
func _set_command_bar_dimmed(dimmed: bool) -> void:
	var alpha: float = 0.35 if dimmed else 1.0
	var tw := create_tween().set_parallel(true)
	if _btn_attack and is_instance_valid(_btn_attack):
		tw.tween_property(_btn_attack, "modulate:a", alpha, 0.20)
	if _btn_skills and is_instance_valid(_btn_skills):
		tw.tween_property(_btn_skills, "modulate:a", alpha, 0.20)
	if _btn_items and is_instance_valid(_btn_items):
		tw.tween_property(_btn_items, "modulate:a", alpha, 0.20)
	for b in _tab_buttons:
		if b and is_instance_valid(b):
			tw.tween_property(b, "modulate:a", alpha, 0.20)
	if btn_flee and is_instance_valid(btn_flee):
		tw.tween_property(btn_flee, "modulate:a", alpha, 0.20)


func _show_enemy_attack_banner(title_text: String, subtitle_text: String = "") -> void:
	if _enemy_attack_banner == null or not is_instance_valid(_enemy_attack_banner):
		return
	if _attack_banner_tween != null and _attack_banner_tween.is_valid():
		_attack_banner_tween.kill()

	if _lbl_attack_banner_title:
		_lbl_attack_banner_title.text = title_text
	if _lbl_attack_banner_sub:
		_lbl_attack_banner_sub.text = subtitle_text if subtitle_text != "" else Locale.pick({
			"es": "🛡️ ¡PULSA DEFENDER PARA BLOQUEAR!",
			"en": "🛡️ PRESS DEFEND TO BLOCK!"
		})

	_enemy_attack_banner.visible = true
	_enemy_attack_banner.position.y = -74.0
	_enemy_attack_banner.modulate.a = 0.0

	_attack_banner_tween = create_tween()
	_attack_banner_tween.set_parallel(true)
	_attack_banner_tween.tween_property(_enemy_attack_banner, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_attack_banner_tween.tween_property(_enemy_attack_banner, "modulate:a", 1.0, 0.16)


func _hide_enemy_attack_banner() -> void:
	if _enemy_attack_banner == null or not is_instance_valid(_enemy_attack_banner) or not _enemy_attack_banner.visible:
		return
	if _attack_banner_tween != null and _attack_banner_tween.is_valid():
		_attack_banner_tween.kill()

	_attack_banner_tween = create_tween()
	_attack_banner_tween.set_parallel(true)
	_attack_banner_tween.tween_property(_enemy_attack_banner, "position:y", -74.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_attack_banner_tween.tween_property(_enemy_attack_banner, "modulate:a", 0.0, 0.20)
	_attack_banner_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(_enemy_attack_banner):
			_enemy_attack_banner.visible = false
	)


func _start_defense_pulse() -> void:
	if _btn_defense == null or not is_instance_valid(_btn_defense):
		return
	_stop_defense_pulse()
	_set_command_bar_dimmed(true)
	if Locale.reduce_motion:
		_btn_defense.modulate = Color(1.25, 1.2, 0.85)
		return
	_btn_defense.pivot_offset = _btn_defense.size * 0.5
	_defense_pulse_tween = _btn_defense.create_tween().set_loops()
	_defense_pulse_tween.tween_property(_btn_defense, "modulate", Color(1.35, 1.3, 0.75), 0.35).set_trans(Tween.TRANS_SINE)
	_defense_pulse_tween.parallel().tween_property(_btn_defense, "scale", Vector2(1.08, 1.08), 0.35).set_trans(Tween.TRANS_SINE)
	_defense_pulse_tween.tween_property(_btn_defense, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_SINE)
	_defense_pulse_tween.parallel().tween_property(_btn_defense, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_SINE)


func _stop_defense_pulse() -> void:
	if _defense_pulse_tween != null and _defense_pulse_tween.is_valid():
		_defense_pulse_tween.kill()
	_defense_pulse_tween = null
	if _btn_defense != null and is_instance_valid(_btn_defense):
		_btn_defense.modulate = Color.WHITE
		_btn_defense.scale = Vector2(1.0, 1.0)
	_set_command_bar_dimmed(false)
	_hide_enemy_attack_banner()


var _hero_idle_tween: Tween = null

func _start_hero_idle_breathing() -> void:
	if _hero_idle_tween != null and _hero_idle_tween.is_valid():
		_hero_idle_tween.kill()
	if _hero_sprite_rect == null or Locale.reduce_motion:
		return
	_hero_sprite_rect.pivot_offset = Vector2(_hero_sprite_rect.size.x * 0.5, _hero_sprite_rect.size.y)
	_hero_idle_tween = _hero_sprite_rect.create_tween().set_loops()
	_hero_idle_tween.tween_property(_hero_sprite_rect, "scale:y", 1.018, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hero_idle_tween.parallel().tween_property(_hero_sprite_rect, "scale:x", 1.008, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hero_idle_tween.tween_property(_hero_sprite_rect, "scale:y", 0.985, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hero_idle_tween.parallel().tween_property(_hero_sprite_rect, "scale:x", 0.995, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Animación visual de ataque del héroe: estocada hacia arriba-izquierda + vibración
func _play_hero_attack_lunge() -> void:
	if _hero_sprite_rect == null or Locale.reduce_motion:
		return
	if _hero_idle_tween != null and _hero_idle_tween.is_valid():
		_hero_idle_tween.pause()
	if _hero_action_tween != null and _hero_action_tween.is_valid():
		_hero_action_tween.kill()

	var base_pos := _hero_sprite_rect.position
	_hero_action_tween = create_tween()
	# 1. Impulso y estiramiento ágil hacia el enemigo (arriba-izquierda)
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos + Vector2(-36.0, -20.0), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hero_action_tween.parallel().tween_property(_hero_sprite_rect, "scale", Vector2(1.05, 0.96), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 2. Micro-vibración en el punto de impacto
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos + Vector2(-33.0, -18.0), 0.03)
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos + Vector2(-35.0, -20.0), 0.03)
	# 3. Recuperación a la posición original
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hero_action_tween.parallel().tween_property(_hero_sprite_rect, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hero_action_tween.finished.connect(func() -> void:
		if _hero_sprite_rect:
			_hero_sprite_rect.position = base_pos
			_hero_sprite_rect.scale = Vector2(1.0, 1.0)
		if _hero_idle_tween != null and _hero_idle_tween.is_valid():
			_hero_idle_tween.play()
	)


## Animación visual de guardia/defensa: agazaparse con vibración de firmeza
func _play_hero_defend_brace() -> void:
	if _hero_sprite_rect == null or Locale.reduce_motion:
		return
	if _hero_idle_tween != null and _hero_idle_tween.is_valid():
		_hero_idle_tween.pause()
	if _hero_action_tween != null and _hero_action_tween.is_valid():
		_hero_action_tween.kill()

	var base_pos := _hero_sprite_rect.position
	_hero_action_tween = create_tween()
	# 1. Asentar peso hacia abajo-derecha
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos + Vector2(6.0, 8.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hero_action_tween.parallel().tween_property(_hero_sprite_rect, "scale", Vector2(1.03, 0.96), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. Vibración de bloqueo
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos + Vector2(4.0, 7.0), 0.03)
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos + Vector2(7.0, 9.0), 0.03)
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos + Vector2(5.0, 8.0), 0.03)
	# 3. Mantener y retornar
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hero_action_tween.parallel().tween_property(_hero_sprite_rect, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hero_action_tween.finished.connect(func() -> void:
		if _hero_sprite_rect:
			_hero_sprite_rect.position = base_pos
			_hero_sprite_rect.scale = Vector2(1.0, 1.0)
		if _hero_idle_tween != null and _hero_idle_tween.is_valid():
			_hero_idle_tween.play()
	)


## Animación visual de dolor/impacto recibido: sacudida hacia atrás y destello
func _play_hero_hurt_shake() -> void:
	if _hero_sprite_rect == null or Locale.reduce_motion:
		return
	if _hero_idle_tween != null and _hero_idle_tween.is_valid():
		_hero_idle_tween.pause()
	if _hero_action_tween != null and _hero_action_tween.is_valid():
		_hero_action_tween.kill()

	var base_pos := _hero_sprite_rect.position
	_hero_action_tween = create_tween()
	# 1. Retroceso brusco con destello rojo
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos + Vector2(24.0, 14.0), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_hero_action_tween.parallel().tween_property(_hero_sprite_rect, "modulate", Color(1.8, 0.65, 0.65), 0.08)
	# 2. Sacudidas rápidas de dolor
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos + Vector2(18.0, 8.0), 0.05)
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos + Vector2(22.0, 12.0), 0.05)
	# 3. Retorno suave a la posición y color original
	_hero_action_tween.tween_property(_hero_sprite_rect, "position", base_pos, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hero_action_tween.parallel().tween_property(_hero_sprite_rect, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hero_action_tween.finished.connect(func() -> void:
		if _hero_sprite_rect:
			_hero_sprite_rect.position = base_pos
			_hero_sprite_rect.modulate = Color.WHITE
		if _hero_idle_tween != null and _hero_idle_tween.is_valid():
			_hero_idle_tween.play()
	)


func _play_hero_lunge_action() -> void:
	_play_hero_attack_lunge()


func _style_jrpg_button(btn: Button, text: String, icon_emoji: String, border_color: Color, bg_color: Color) -> void:
	btn.clip_contents = true
	var style_norm := StyleBoxFlat.new()
	style_norm.bg_color = bg_color
	style_norm.set_corner_radius_all(14)
	style_norm.set_border_width_all(3)
	style_norm.border_color = border_color
	style_norm.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style_norm.shadow_size = 6
	btn.add_theme_stylebox_override("normal", style_norm)

	var style_hov := style_norm.duplicate() as StyleBoxFlat
	style_hov.bg_color = bg_color.lightened(0.12)
	style_hov.border_color = border_color.lightened(0.3)
	style_hov.shadow_color = border_color.lightened(0.3)
	style_hov.shadow_color.a = 0.5
	style_hov.shadow_size = 10
	btn.add_theme_stylebox_override("hover", style_hov)
	btn.add_theme_stylebox_override("pressed", style_hov)
	btn.add_theme_stylebox_override("focus", style_hov)

	# micro-interacción consistente con las tarjetas de
	# habilidad de la rejilla (mismo pop de escala al pasar el ratón/dedo) y un
	# estado "disabled" propio (antes caía al tema por defecto de Godot, que
	# desentonaba con el resto del panel oscuro).
	var style_dis := style_norm.duplicate() as StyleBoxFlat
	style_dis.bg_color = bg_color.darkened(0.35)
	style_dis.border_color = border_color.darkened(0.5)
	style_dis.shadow_size = 0
	btn.add_theme_stylebox_override("disabled", style_dis)

	btn.pivot_offset = btn.custom_minimum_size / 2
	btn.mouse_entered.connect(func() -> void:
		if btn.disabled or Locale.reduce_motion:
			return
		var tw := btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := btn.create_tween().set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	# Botones JRPG cuadrados/táctiles: icono de 28px arriba y texto Cinzel 16px abajo
	var lbl_icon := Label.new()
	lbl_icon.text = icon_emoji
	lbl_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_icon.add_theme_font_size_override("font_size", 28)
	vbox.add_child(lbl_icon)

	var lbl_txt := Label.new()
	lbl_txt.text = text
	lbl_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_txt.add_theme_font_size_override("font_size", 16)
	lbl_txt.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	vbox.add_child(lbl_txt)


## Actualiza el icono y texto de un botón cuadrado estilo JRPG sin reconstruirlo.
func _set_jrpg_button_labels(btn: Button, icon_emoji: String, text: String) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.text = ""
	if btn.get_child_count() > 0:
		var vbox := btn.get_child(0)
		if vbox != null and vbox.get_child_count() >= 2:
			var lbl_icon := vbox.get_child(0) as Label
			var lbl_txt := vbox.get_child(1) as Label
			if lbl_icon != null:
				lbl_icon.text = icon_emoji
			if lbl_txt != null:
				lbl_txt.text = text


## Devuelve un color del tema activo. Si no existe la clave, devuelve el fallback.
## Usa el snapshot `_ui_theme_id` (no `Locale.ui_theme_id` en vivo, ver arriba).
func _theme_color(key: String, fallback: Color = Color.WHITE) -> Color:
	var t_dict: Dictionary = UiKit.THEMES.get(_ui_theme_id, {})
	return t_dict.get(key, fallback)


func _safe_reparent(node: Node, new_parent: Node) -> void:
	if node == null or new_parent == null:
		return
	var cur_p := node.get_parent()
	if cur_p == new_parent:
		return
	if cur_p != null:
		cur_p.remove_child(node)
	new_parent.add_child(node)


## Reorganiza los bloques de la "consola de combate" entre el layout
## horizontal (3 columnas en una fila) y el reflow vertical/móvil
## stats del héroe arriba (compactas) → cola de combo
## a ancho completo → fila inferior con habilidades 2×2 a la izquierda y
## ATB+comandos 2×2 a la derecha (zona del pulgar). REPARENTA los MISMOS nodos
## (nunca los duplica) para no perder ninguna referencia (`_bar_player_hp`,
## `_content_grid`, `_btn_attack`...) — solo cambian de padre.
func _apply_console_layout() -> void:
	if _combat_console == null or _hero_status_dock == null or _hero_right_column == null or _center_dock == null:
		return
	if _is_landscape == not _console_is_portrait_layout:
		return  # ya está en el modo correcto: nada que reparentar
	_console_is_portrait_layout = not _is_landscape

	if _is_landscape:
		# Volver al layout horizontal: sacar los 3 bloques de la estructura
		# portrait (si se llegó a construir) y reinsertarlos en `_console_landscape_row`/`_center_dock`.
		if _console_portrait_col != null:
			_console_portrait_col.visible = false

		_console_landscape_row.visible = true
		_safe_reparent(_hero_status_dock, _console_landscape_row)
		_safe_reparent(_center_dock, _console_landscape_row)
		_safe_reparent(_hero_right_column, _console_landscape_row)
		_console_landscape_row.move_child(_hero_status_dock, 0)
		_console_landscape_row.move_child(_center_dock, 2)
		_console_landscape_row.move_child(_hero_right_column, 4)

		_safe_reparent(_synergy_queue_panel, _center_dock)
		_center_dock.move_child(_synergy_queue_panel, 0)
		_safe_reparent(_skills_panel, _center_dock)
		_center_dock.move_child(_skills_panel, 1)
	else:
		# Reflow vertical/móvil (A.0.2): stats del héroe arriba (compactas) →
		# cola de combo a ancho completo → fila inferior [habilidades 2x2 |
		# ATB+comandos 2x2]. Se construye UNA sola vez y se reutiliza.
		_console_landscape_row.visible = false
		if _console_portrait_col == null:
			_console_portrait_col = VBoxContainer.new()
			_console_portrait_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_console_portrait_col.add_theme_constant_override("separation", 10)
			_combat_console.add_child(_console_portrait_col)

			_console_portrait_bottom_row = HBoxContainer.new()
			_console_portrait_bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_console_portrait_bottom_row.add_theme_constant_override("separation", 14)
			_console_portrait_col.add_child(_console_portrait_bottom_row)
		_console_portrait_col.visible = true

		_safe_reparent(_hero_status_dock, _console_portrait_col)
		_console_portrait_col.move_child(_hero_status_dock, 0)
		_safe_reparent(_synergy_queue_panel, _console_portrait_col)
		_console_portrait_col.move_child(_synergy_queue_panel, 1)

		# Habilidades (2x2, `_skills_panel`) e IZQUIERDA | comandos (ATB+2x2,
		# `_hero_right_column`) a la DERECHA — zona del pulgar diestro;
		# espejado si `Locale.left_handed` está activo.
		_safe_reparent(_skills_panel, _console_portrait_bottom_row)
		_safe_reparent(_hero_right_column, _console_portrait_bottom_row)
		var skills_idx := 1 if Locale.left_handed else 0
		var actions_idx := 0 if Locale.left_handed else 1
		_console_portrait_bottom_row.move_child(_skills_panel, skills_idx)
		_console_portrait_bottom_row.move_child(_hero_right_column, actions_idx)

	# La consola completa se mantiene ACOTADA en horizontal (LEY DEL ANCHO
	# ACOTADO: nunca ocupa todo el ancho "porque sobra espacio"), pero pegada al
	# borde DERECHO en vez de centrada: con el móvil apoyado en una mano, los
	# botones de acción/habilidades quedan al alcance del pulgar en vez de en
	# medio de la pantalla. En el reflow portrait SÍ usa el ancho completo
	# disponible del móvil (no hay "aire a los lados" que preservar ahí).
	_combat_console.size_flags_horizontal = Control.SIZE_SHRINK_END if _is_landscape else Control.SIZE_EXPAND_FILL

	# Ancho fijo en horizontal (LEY DEL ANCHO ACOTADO); a ancho completo del
	# panel en el reflow portrait (no hay más columnas con las que compartir fila).
	_hero_status_dock.custom_minimum_size.x = 380.0 if _is_landscape else 0.0
	_hero_status_dock.size_flags_horizontal = Control.SIZE_FILL if _is_landscape else Control.SIZE_EXPAND_FILL
	_center_dock.custom_minimum_size.x = 520.0 if _is_landscape else 0.0
	_center_dock.size_flags_horizontal = Control.SIZE_FILL if _is_landscape else Control.SIZE_EXPAND_FILL
	_synergy_queue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_right_column.custom_minimum_size.x = 280.0 if _is_landscape else 0.0
	_hero_right_column.size_flags_horizontal = Control.SIZE_FILL if _is_landscape else Control.SIZE_EXPAND_FILL

	# BOOST VERTICAL (mismo factor 2.1x que GameRoot/TabWorld3D/ExplorationHud):
	# los botones cuadrados de acción y la barra ATB quedaban diminutos en
	# retrato porque `window/stretch/aspect=expand` no amplía el ancho lógico
	# al rotar, solo el alto. Solo se toca en el reflow portrait.
	var console_boost := 2.1 if not _is_landscape else 1.0
	var action_min_size := Vector2(160, 86) * console_boost
	_rescale_jrpg_button(_btn_attack, action_min_size, roundi(28 * console_boost), roundi(16 * console_boost))
	_rescale_jrpg_button(_btn_defense, action_min_size, roundi(28 * console_boost), roundi(16 * console_boost))
	if _tab_buttons.size() >= 2:
		_rescale_jrpg_button(_tab_buttons[0], action_min_size, roundi(28 * console_boost), roundi(16 * console_boost))
		_rescale_jrpg_button(_tab_buttons[1], action_min_size, roundi(28 * console_boost), roundi(16 * console_boost))
	if _lbl_atb_title != null and is_instance_valid(_lbl_atb_title):
		_lbl_atb_title.add_theme_font_size_override("font_size", roundi(14 * console_boost))
	if _bar_player_atb != null and is_instance_valid(_bar_player_atb):
		_bar_player_atb.custom_minimum_size = Vector2(240, 16) * console_boost
	if _lbl_defense_cooldown_text != null and is_instance_valid(_lbl_defense_cooldown_text):
		_lbl_defense_cooldown_text.add_theme_font_size_override("font_size", roundi(16 * console_boost))
	_apply_top_hud_layout()


## Reescala un botón cuadrado de acción (ATACAR/DEFENDER/HABS/ITEMS) construido
## con `_style_jrpg_button`: min-size + fuentes del icono/texto internos (un
## único VBox hijo con 2 Labels). Usado por el boost vertical de
## `_apply_console_layout` para no reconstruir el botón en cada reflow.
func _rescale_jrpg_button(btn: Button, min_size: Vector2, icon_font: int, text_font: int) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.custom_minimum_size = min_size
	btn.pivot_offset = min_size / 2
	if btn.get_child_count() == 0:
		return
	var vbox := btn.get_child(0)
	if vbox == null or vbox.get_child_count() < 2:
		return
	var lbl_icon := vbox.get_child(0) as Label
	var lbl_txt := vbox.get_child(1) as Label
	if lbl_icon != null:
		lbl_icon.add_theme_font_size_override("font_size", icon_font)
	if lbl_txt != null:
		lbl_txt.add_theme_font_size_override("font_size", text_font)
	if vbox is BoxContainer:
		var sep := roundi(2.0 * (min_size.y / 86.0))
		(vbox as BoxContainer).add_theme_constant_override("separation", maxi(2, sep))


## Aplica la escala y dimensiones a la barra superior (top_hud) y sus botones
## cuadrados (HUIR, PAUSA, 1-HIT KILL) usando el mismo boost de tamaño táctil
## que los botones de combate (ATACAR/DEFENDER).
func _apply_top_hud_layout() -> void:
	var console_boost := 2.1 if not _is_landscape else 1.0
	var top_btn_size := Vector2(86, 86) * console_boost
	_rescale_jrpg_button(btn_flee, top_btn_size, roundi(28 * console_boost), roundi(14 * console_boost))
	_rescale_jrpg_button(btn_pause, top_btn_size, roundi(28 * console_boost), roundi(14 * console_boost))
	if btn_one_hit_kill != null and is_instance_valid(btn_one_hit_kill):
		_rescale_jrpg_button(btn_one_hit_kill, top_btn_size, roundi(28 * console_boost), roundi(14 * console_boost))
	if _top_hud != null and is_instance_valid(_top_hud):
		_top_hud.custom_minimum_size.y = top_btn_size.y


## Aplica el posicionamiento específico según orientación. En horizontal el
## enemigo se ancla a la izquierda y las pestañas/cartas/acciones al panel derecho.
func _get_hero_full_body_texture_path(prof_name: String, pose_state: Variant = "") -> String:
	return CombatTabsUI.get_prof_fullbody_path(prof_name, pose_state)


## Actualiza la pose del sprite del héroe según el estado actual (hurt > attack > defend > base).
func _update_hero_sprite_pose() -> void:
	if _hero_sprite_rect == null:
		return
	var prof_name := String(GlobalState.profession)
	var pose: String = ""
	if _hero_hurt_timer > 0.0:
		pose = "hurt"
	elif _hero_attack_timer > 0.0:
		pose = "attack"
	elif defense_active_time > 0.0:
		pose = "defend"

	var fullbody_path := _get_hero_full_body_texture_path(prof_name, pose)
	if ResourceLoader.exists(fullbody_path):
		_hero_sprite_rect.texture = load(fullbody_path) as Texture2D
		_hero_sprite_rect.visible = _is_landscape
	elif pose.is_empty():
		_hero_sprite_rect.visible = false


## Conmuta el sprite del protagonista a su pose de defensa o normal.
func set_hero_defending(defending: bool) -> void:
	_update_hero_sprite_pose()
	if defending:
		_play_hero_defend_brace()


## Activa la pose de ataque del héroe durante `duration` segundos con impulso visual.
func play_hero_attack_reaction(duration: float = 0.55) -> void:
	_hero_attack_timer = duration
	_update_hero_sprite_pose()
	_play_hero_attack_lunge()


## Activa la pose de dolor/daño del héroe durante `duration` segundos con sacudida.
func play_hero_hurt_reaction(duration: float = 1.0) -> void:
	_hero_hurt_timer = duration
	_update_hero_sprite_pose()
	_play_hero_hurt_shake()


func _load_portrait_texture() -> void:
	var prof_name := String(GlobalState.profession)
	
	# 1. Cargar el sprite del protagonista a cuerpo completo (escenario izquierdo)
	_hero_hurt_timer = 0.0
	_hero_attack_timer = 0.0
	_update_hero_sprite_pose()
	_start_hero_idle_breathing()

	# 2. Cargar el avatar compacto del protagonista en la barra de vida/mana (HUD jugador)
	var av_path := CombatTabsUI.get_prof_texture_path(prof_name)
	if _portrait_texture != null:
		if ResourceLoader.exists(av_path):
			_portrait_texture.texture = load(av_path) as Texture2D
			if _portrait_label:
				_portrait_label.visible = false
		else:
			if _portrait_label:
				_portrait_label.text = prof_name.substr(0, 1) if prof_name != "" else "P"
				_portrait_label.visible = true


func _apply_orientation_layout() -> void:
	_load_portrait_texture()
	# Reflow de la consola de combate entre horizontal
	# (3 columnas) y vertical/móvil (stats arriba, combo a ancho completo,
	# habilidades+comandos abajo). Debe llamarse ANTES de tocar los paddings
	# del aura de Resonancia (usa los mismos bloques).
	_apply_console_layout()
	_apply_top_hud_layout()
	# Ajustar márgenes del panel inferior según orientación. El marco premium
	# (UiKit.premium_frame) sustituyó el StyleBoxFlat que antes se mutaba a
	# mano aquí; volver a llamarlo con el `pad_*` de la orientación actual
	# reinstala el marco del tema activo con el margen correcto (idempotente).
	if _resonant_aura != null:
		if _is_landscape:
			UiKit.premium_frame(_resonant_aura, {"pad_left": 10, "pad_right": 10, "pad_top": 8, "pad_bottom": 8})
		else:
			UiKit.premium_frame(_resonant_aura, {"pad_left": 18, "pad_right": 18, "pad_top": 16, "pad_bottom": 16})

	# Avatar del jugador siempre visible (64x64)
	if _portrait_frame != null:
		_portrait_frame.visible = true
		_portrait_frame.custom_minimum_size = Vector2(64, 64)

	# Hero sprite (cuerpo entero, lado DERECHO, justo sobre el dock inferior)
	if _hero_sprite_rect != null:
		_hero_sprite_rect.visible = _is_landscape
		if _is_landscape:
			_hero_sprite_rect.anchor_left = 0.60
			_hero_sprite_rect.anchor_right = 0.88
			_hero_sprite_rect.anchor_top = 0.22
			_hero_sprite_rect.anchor_bottom = 0.94
			_hero_sprite_rect.scale = Vector2(0.72, 0.72)

	# Enemigo (lado IZQUIERDO en landscape ocupando todo el alto, centrado arriba en portrait)
	if _enemy_sprite_container != null:
		if _is_landscape:
			_enemy_sprite_container.anchor_left = 0.01
			_enemy_sprite_container.anchor_right = 0.54
			_enemy_sprite_container.anchor_top = 0.02
			_enemy_sprite_container.anchor_bottom = 0.98
		else:
			_enemy_sprite_container.anchor_left = 0.02
			_enemy_sprite_container.anchor_right = 0.98
			_enemy_sprite_container.anchor_top = 0.01
			_enemy_sprite_container.anchor_bottom = 0.65

	if _enemy_img_rect != null and _enemy_img_rect.texture != null and _enemy_sprite_container != null and _enemy_sprite_container.size.x > 0:
		_align_enemy_and_platform()
	# Si estamos en combate, reconstruir las cartas para que respeten la orientación.
	if is_combat_active and _content_grid != null:
		CombatTabsUI.build_tab_grid(self)


#region CICLO DE VIDA E INICIALIZACIÓN DE LA UI

## Motor de turnos ATB. Encapsula el bucle de
## procesamiento ATB en tiempo real; `_process` delega en él. Es `RefCounted`
## (se libera con la vista) y usa `create_tween` de esta vista para el escudo.
var _turn_engine: CombatTurnEngine = null
var is_skill_animating: bool = false

## Evaluador de sinergias y cola. Encapsula la
## capacidad de ranuras y la fusión data-driven de sinergias.
var _queue_system: CombatQueueSystem = null

## Resolución de daño/estados alterados.
## Encapsula intro de combate, daño a enemigo/jugador, fin de combate y todo el
## sistema de estados alterados. Se instancia en `_ready`.
var _damage_resolver: CombatDamageResolver = null

## Panel de resultado, refresco de barras/cola y botones continuar/huida.
## Se instancia en `_ready`.
var _result_ui: CombatResultUI = null

func _ready() -> void:
	_turn_engine = CombatTurnEngine.new()
	_turn_engine.setup(self)
	_queue_system = CombatQueueSystem.new()
	_queue_system.setup(self)
	_damage_resolver = CombatDamageResolver.new()
	_damage_resolver.setup(self)
	_result_ui = CombatResultUI.new()
	_result_ui.setup(self)
	_ui_theme_id = Locale.ui_theme_id
	_build_ui()
	Locale.locale_changed.connect(_refresh_chrome)
	Locale.theme_changed.connect(_on_ui_theme_changed)
	_refresh_chrome()
	resized.connect(_on_view_resized)
	get_viewport().size_changed.connect(_on_view_resized)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_force_end_defense_effects()
			Engine.time_scale = 1.0
	)
	_on_view_resized()


func _on_ui_theme_changed(theme_id: String) -> void:
	_ui_theme_id = theme_id
	# Si no estamos en combate, reconstruimos la UI entera con el nuevo tema.
	# En pleno combate se mantiene el tema actual hasta salir para no perder estado.
	if not is_combat_active:
		_build_ui()
		_on_view_resized()


func _on_view_resized() -> void:
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var new_landscape := sz.x > sz.y
	if new_landscape != _is_landscape:
		_is_landscape = new_landscape
	_apply_orientation_layout()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	# `_build_ui()` libera TODO el árbol anterior (incluida la estructura
	# portrait de la consola, si llegó a construirse) y reconstruye la consola
	# siempre en su arreglo horizontal por defecto: sin este reseteo,
	# `_apply_console_layout()` (llamada justo después vía `_on_view_resized`)
	# creería que ya estaba en portrait y se saltaría el reflow, dejando la
	# consola nueva en horizontal aunque el dispositivo siga en vertical
	_console_portrait_col = null
	_console_portrait_bottom_row = null
	_console_is_portrait_layout = false

	# 1. Fondo de pantalla
	_bg_texture_rect = TextureRect.new()
	_bg_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_texture_rect)

	# Héroe de Espaldas (Capa 2D del escenario: lado DERECHO, justo encima del dock
	# inferior, que le tapa las botas. Anclado desde 20% a 99% del alto).
	_hero_sprite_rect = TextureRect.new()
	_hero_sprite_rect.name = "HeroSprite"
	_hero_sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_sprite_rect.anchor_left = 0.57
	_hero_sprite_rect.anchor_right = 0.88
	_hero_sprite_rect.anchor_top = 0.16
	_hero_sprite_rect.anchor_bottom = 0.94
	_hero_sprite_rect.visible = true
	add_child(_hero_sprite_rect)
	_start_hero_idle_breathing()

	# 2. Contenedor Principal (Capa UI sobre el escenario)
	var main_margin := MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 16)
	main_margin.add_theme_constant_override("margin_right", 16)
	main_margin.add_theme_constant_override("margin_top", 12)
	main_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(main_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	main_margin.add_child(main_vbox)

	# ══════════════════════════════════════════════════════════════════════════
	# ── 1. BARRA SUPERIOR LIMPIA (TOP HUD) ──
	# [NV 50] + HUIR  |  (Espacio libre central y derecho)
	# ══════════════════════════════════════════════════════════════════════════
	_top_hud = HBoxContainer.new()
	_top_hud.custom_minimum_size.y = 86
	_top_hud.add_theme_constant_override("separation", 12)
	main_vbox.add_child(_top_hud)

	var badge_hbox := HBoxContainer.new()
	badge_hbox.add_theme_constant_override("separation", 10)
	_top_hud.add_child(badge_hbox)

	btn_flee = Button.new()
	btn_flee.custom_minimum_size = Vector2(86, 86)
	btn_flee.focus_mode = Control.FOCUS_NONE
	btn_flee.pressed.connect(_on_btn_flee_pressed)
	_style_jrpg_button(btn_flee, Locale.t("combat_flee"), "🏃", _theme_color("flee", Color(0.85, 0.35, 0.38, 0.9)), _theme_color("panel_glass", Color(0.22, 0.08, 0.10, 0.92)))
	UiKit.bind_press_feedback(btn_flee)
	badge_hbox.add_child(btn_flee)

	btn_pause = Button.new()
	btn_pause.custom_minimum_size = Vector2(86, 86)
	btn_pause.focus_mode = Control.FOCUS_NONE
	btn_pause.pressed.connect(toggle_pause)
	_style_jrpg_button(btn_pause, Locale.pick({"es": "PAUSA", "en": "PAUSE"}), "⏸️", _theme_color("accent", Color(0.35, 0.65, 0.88, 0.9)), _theme_color("panel_glass", Color(0.12, 0.16, 0.24, 0.92)))
	UiKit.bind_press_feedback(btn_pause)
	badge_hbox.add_child(btn_pause)

	btn_one_hit_kill = Button.new()
	btn_one_hit_kill.custom_minimum_size = Vector2(86, 86)
	btn_one_hit_kill.focus_mode = Control.FOCUS_NONE
	btn_one_hit_kill.pressed.connect(_on_btn_one_hit_kill_pressed)
	_style_jrpg_button(btn_one_hit_kill, "1-HIT", "⚡", Color(1.0, 0.72, 0.18, 0.9), Color(0.28, 0.12, 0.02, 0.88))
	btn_one_hit_kill.visible = GlobalState.debug_mode or GlobalState.is_test_room
	UiKit.bind_press_feedback(btn_one_hit_kill)
	badge_hbox.add_child(btn_one_hit_kill)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_hud.add_child(top_spacer)

	_apply_top_hud_layout()

	combat_log = RichTextLabel.new()
	combat_log.visible = false
	add_child(combat_log)

	# ══════════════════════════════════════════════════════════════════════════
	# ── 2. ESCENARIO CENTRAL (COMBAT AREA 2D STAGE) ──
	# ══════════════════════════════════════════════════════════════════════════
	_combat_area = Control.new()
	_combat_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_combat_area)

	# Enemigo (Lado IZQUIERDO: capa de escenario 2D que abarca toda la altura)
	_enemy_sprite_container = Control.new()
	_enemy_sprite_container.name = "EnemySpriteContainer"
	_enemy_sprite_container.anchor_left = 0.02
	_enemy_sprite_container.anchor_right = 0.54
	_enemy_sprite_container.anchor_top = 0.02
	_enemy_sprite_container.anchor_bottom = 0.98
	add_child(_enemy_sprite_container)
	move_child(_enemy_sprite_container, 1) # Justo delante del fondo y detrás de la UI

	# HUD del enemigo flotando directamente sobre su cabeza. Ancho
	# ampliado (hasta 460px, la barra ATB es el foco
	# de atención continuo del jugador). `z_index` por encima del sprite/peana
	# como SALVAGUARDA: aunque `_align_enemy_and_platform()` ya calcula la
	# posición del enemigo para no solaparse con este panel, si algún enemigo
	# con proporciones extremas rompiera ese cálculo, el HUD debe seguir
	# dibujándose POR ENCIMA (nunca tapado).
	_enemy_panel = VBoxContainer.new()
	_enemy_panel.custom_minimum_size = Vector2(580, 102)
	_enemy_panel.anchor_left = 0.5
	_enemy_panel.anchor_right = 0.5
	_enemy_panel.anchor_top = 0.0
	_enemy_panel.anchor_bottom = 0.0
	_enemy_panel.offset_left = -290
	_enemy_panel.offset_right = 290
	_enemy_panel.offset_top = 0
	_enemy_panel.offset_bottom = 102
	_enemy_panel.add_theme_constant_override("separation", 4)
	_enemy_panel.z_index = 10
	_enemy_sprite_container.add_child(_enemy_panel)

	# Marco premium tenue de agrupación visual (no debe competir con el brillo
	# de la propia barra ATB, que es el foco real de atención).
	var _enemy_panel_frame_bg := PanelContainer.new()
	_enemy_panel_frame_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_panel_frame_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enemy_panel_frame_bg.z_index = -1
	UiKit.premium_frame(_enemy_panel_frame_bg, {"glow_strength": 0.12, "sweep_speed": 0.0, "pad": 0})
	_enemy_panel.add_child(_enemy_panel_frame_bg)
	_enemy_panel.move_child(_enemy_panel_frame_bg, 0)

	var hbox_enemy_header := HBoxContainer.new()
	hbox_enemy_header.add_theme_constant_override("separation", 8)
	_enemy_panel.add_child(hbox_enemy_header)

	_lbl_enemy_name = Label.new()
	_lbl_enemy_name.text = "Goblin Explorador"
	_lbl_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_enemy_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_enemy_name.add_theme_font_size_override("font_size", 28)
	_lbl_enemy_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_lbl_enemy_name.add_theme_constant_override("shadow_offset_x", 2)
	_lbl_enemy_name.add_theme_constant_override("shadow_offset_y", 2)
	_lbl_enemy_name.add_theme_constant_override("outline_size", 6)
	_lbl_enemy_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hbox_enemy_header.add_child(_lbl_enemy_name)

	_enemy_debuffs_container = HBoxContainer.new()
	_enemy_debuffs_container.alignment = BoxContainer.ALIGNMENT_END
	_enemy_debuffs_container.add_theme_constant_override("separation", 2)
	hbox_enemy_header.add_child(_enemy_debuffs_container)

	# Barra de HP del enemigo más ancha y gruesa (580x28px)
	_lbl_enemy_hp = Label.new()
	_lbl_enemy_hp.text = "-- / -- HP"
	_lbl_enemy_hp.add_theme_font_size_override("font_size", 18)
	_lbl_enemy_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_enemy_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_enemy_hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var enemy_hp_stack := _make_ghost_hp_bar(Color(0.2, 0.8, 0.4), 28, 4, 1)
	_bar_enemy_hp = enemy_hp_stack[1]
	_bar_enemy_hp_ghost = enemy_hp_stack[2]
	_bar_enemy_hp.custom_minimum_size = Vector2(580, 28)
	_bar_enemy_hp.add_child(_lbl_enemy_hp)
	_enemy_panel.add_child(enemy_hp_stack[0])

	# Barra ATB del enemigo más ancha y gruesa (580x26px)
	_bar_enemy_atb = ProgressBar.new()
	_bar_enemy_atb.custom_minimum_size = Vector2(580, 26)
	_bar_enemy_atb.show_percentage = false
	_bar_enemy_atb.visible = true
	_style_glossy_bar(_bar_enemy_atb, _theme_color("enemy_atb", Color(0.95, 0.75, 0.2)))
	_enemy_panel.add_child(_bar_enemy_atb)

	_lbl_enemy_status = Label.new()
	_lbl_enemy_status.visible = false
	_enemy_panel.add_child(_lbl_enemy_status)

	_lbl_ctx_info = RichTextLabel.new()
	_lbl_ctx_info.visible = false
	_enemy_panel.add_child(_lbl_ctx_info)

	_enemy_platform = TextureRect.new()
	_enemy_platform.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_platform.stretch_mode = TextureRect.STRETCH_SCALE
	_enemy_platform.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_sprite_container.add_child(_enemy_platform)

	_enemy_img_rect = TextureRect.new()
	_enemy_img_rect.scale = Vector2.ONE
	_enemy_img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_img_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_enemy_img_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_sprite_container.add_child(_enemy_img_rect)

	_damage_popups_node = Control.new()
	_damage_popups_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_popups_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_sprite_container.add_child(_damage_popups_node)

	_shield_overlay = Control.new()
	_shield_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_overlay.modulate.a = 0.0
	_enemy_sprite_container.add_child(_shield_overlay)

	# insignia persistente de intención sobre la cabeza del
	# enemigo mientras descarga su ataque (además de la barra ATB).
	_lbl_enemy_intent_badge = Label.new()
	_lbl_enemy_intent_badge.visible = false
	_lbl_enemy_intent_badge.anchor_left = 0.5
	_lbl_enemy_intent_badge.anchor_right = 0.5
	_lbl_enemy_intent_badge.offset_left = -90.0
	_lbl_enemy_intent_badge.offset_right = 90.0
	_lbl_enemy_intent_badge.offset_top = 4.0
	_lbl_enemy_intent_badge.offset_bottom = 44.0
	_lbl_enemy_intent_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_enemy_intent_badge.add_theme_font_size_override("font_size", 30)
	_lbl_enemy_intent_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_lbl_enemy_intent_badge.add_theme_constant_override("shadow_offset_x", 2)
	_lbl_enemy_intent_badge.add_theme_constant_override("shadow_offset_y", 2)
	_lbl_enemy_intent_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_sprite_container.add_child(_lbl_enemy_intent_badge)

	# ══════════════════════════════════════════════════════════════════════════
	# ── 3. DOCK INFERIOR DE COMBATE (MOBILE TARGETS) ──
	# 3 bloques → [STATS HÉROE HP/MP] (izquierda, ancho fijo) |
	# [SINERGIA + REJILLA 2X2 SKILLS] (centro, solo el ancho necesario, SIN
	# expandir) | [ATB + 2X2 COMANDOS] (derecha, absorbe el espacio libre y usa
	# botones más grandes). Antes las stats de HP/MP vivían apiladas ENCIMA de
	# los botones de acción en la columna derecha, no a la izquierda del grid
	# de habilidades como pedía el diseño original.
	# ══════════════════════════════════════════════════════════════════════════
	# "consola de combate" unificada — UNA sola pieza con
	# marco premium (en vez de 3 `neoclassic_panel` sueltos), con separadores
	# verticales finos internos entre sus 3 bloques. Ancho total ACOTADO
	# (380+520+280 + separadores/padding, LEY DEL ANCHO ACOTADO) y pegada al
	# borde DERECHO en horizontal (alcance del pulgar): el espacio sobrante es
	# aire/escenario, nunca se estira ningún bloque. `_apply_console_layout`
	# fija el flag definitivo según orientación; este valor inicial ya coincide.
	_combat_console = PanelContainer.new()
	_combat_console.size_flags_horizontal = Control.SIZE_SHRINK_END
	_combat_console.size_flags_vertical = Control.SIZE_SHRINK_END
	UiKit.premium_frame(_combat_console, {"corner_radius": 20.0, "pad": 22})
	main_vbox.add_child(_combat_console)
	# El aura de Resonancia MÁX (_show_resonant_aura) pulsa ahora el marco de
	# TODA la consola (antes solo el bloque de stats): más impactante y
	# coherente con la consola unificada.
	_resonant_aura = _combat_console

	_console_landscape_row = HBoxContainer.new()
	_console_landscape_row.custom_minimum_size.y = 220
	_console_landscape_row.add_theme_constant_override("separation", 14)
	_combat_console.add_child(_console_landscape_row)

	# ── 3.1 IZQUIERDA: STATS DEL HÉROE (HP/MP/Sintonía) ──
	_hero_status_dock = PanelContainer.new()
	_hero_status_dock.custom_minimum_size = Vector2(430, 220)
	_hero_status_dock.size_flags_vertical = Control.SIZE_FILL
	var _hero_dock_empty := StyleBoxEmpty.new()
	_hero_dock_empty.content_margin_left = 22
	_hero_dock_empty.content_margin_right = 16
	_hero_dock_empty.content_margin_top = 10
	_hero_dock_empty.content_margin_bottom = 10
	_hero_status_dock.add_theme_stylebox_override("panel", _hero_dock_empty)

	var hero_stats_vbox := VBoxContainer.new()
	hero_stats_vbox.add_theme_constant_override("separation", 5)
	hero_stats_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero_status_dock.add_child(hero_stats_vbox)

	# Cabecera limpia: Avatar (56x56) + Nombre Profesión + Nivel + Círculo Sintonía (56x56)
	var status_hdr := HBoxContainer.new()
	status_hdr.add_theme_constant_override("separation", 10)
	hero_stats_vbox.add_child(status_hdr)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.custom_minimum_size = Vector2(56, 56)
	_portrait_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_portrait_frame.tooltip_text = "Cambiar Profesión Activa"
	_portrait_frame.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_profession_modal(true)
	)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.05, 0.10, 0.85)
	p_style.set_corner_radius_all(10)
	p_style.set_border_width_all(2)
	p_style.border_color = Color(0.98, 0.80, 0.32)
	_portrait_frame.add_theme_stylebox_override("panel", p_style)
	status_hdr.add_child(_portrait_frame)

	_portrait_texture = TextureRect.new()
	_portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_frame.add_child(_portrait_texture)

	_portrait_label = Label.new()
	_portrait_label.text = "P"
	_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_frame.add_child(_portrait_label)
	_load_portrait_texture()

	var hero_name_vbox := VBoxContainer.new()
	hero_name_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_name_vbox.add_theme_constant_override("separation", 2)
	status_hdr.add_child(hero_name_vbox)

	_lbl_class = Label.new()
	_lbl_class.text = Locale.translate_profession(GlobalState.profession).to_upper()
	_lbl_class.add_theme_font_size_override("font_size", 20)
	_lbl_class.add_theme_color_override("font_color", Color(0.98, 0.82, 0.32))
	hero_name_vbox.add_child(_lbl_class)

	_lbl_level = Label.new()
	_lbl_level.text = "NV %d | JB %d" % [GlobalState.level, GlobalState.job_level]
	_lbl_level.add_theme_font_size_override("font_size", 13)
	_lbl_level.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
	hero_name_vbox.add_child(_lbl_level)

	_resonance_circle = ResonanceCircle.new()
	_resonance_circle.custom_minimum_size = Vector2(56, 56)
	status_hdr.add_child(_resonance_circle)

	# 3 Barras Uniformes (380x18px)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	hero_stats_vbox.add_child(hp_row)
	_lbl_hp_tag = Label.new()
	_lbl_hp_tag.text = "HP"
	_lbl_hp_tag.custom_minimum_size.x = 28
	_lbl_hp_tag.add_theme_font_size_override("font_size", 14)
	_lbl_hp_tag.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	hp_row.add_child(_lbl_hp_tag)
	var hp_stack := _make_ghost_hp_bar(Color(0.2, 0.8, 0.4), 18, 4, 1)
	hp_stack[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(hp_stack[0])
	_bar_player_hp = hp_stack[1]
	_bar_player_hp_ghost = hp_stack[2]
	_lbl_player_hp = _stat_bar_value_direct(hp_row, Color(0.95, 0.6, 0.6))

	var mp_row := HBoxContainer.new()
	mp_row.add_theme_constant_override("separation", 8)
	hero_stats_vbox.add_child(mp_row)
	_bar_player_mp = _make_stat_bar_direct(mp_row, "MP", Color(0.2, 0.55, 0.95))
	_lbl_player_mp = _stat_bar_value_direct(mp_row, Color(0.6, 0.8, 1.0))

	# Fila de Estados Alterados (Prisa, Escudo, Veneno, etc.)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	hero_stats_vbox.add_child(status_row)

	var lbl_status_tag := Label.new()
	lbl_status_tag.text = "EST"
	lbl_status_tag.custom_minimum_size.x = 28
	lbl_status_tag.add_theme_font_size_override("font_size", 14)
	lbl_status_tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	status_row.add_child(lbl_status_tag)

	var status_icons_row := HBoxContainer.new()
	status_icons_row.add_theme_constant_override("separation", 6)
	status_icons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_icons_row)

	_lbl_player_status = Label.new()
	_lbl_player_status.set_meta("icon_row", status_icons_row)
	hero_stats_vbox.add_child(_lbl_player_status)

	# ── 3.2 CENTRO: COLA DE SINERGIAS + REJILLA 2X2 RECTANGULARES ──
	_center_dock = VBoxContainer.new()
	_center_dock.custom_minimum_size = Vector2(520, 220)
	_center_dock.size_flags_vertical = Control.SIZE_FILL
	_center_dock.add_theme_constant_override("separation", 6)
	_console_landscape_row.add_child(_hero_status_dock)
	_console_landscape_row.add_child(_make_console_divider())
	_console_landscape_row.add_child(_center_dock)
	_console_landscape_row.add_child(_make_console_divider())

	# ── 3.3 DERECHA: ATB + 2X2 COMANDOS ──
	_hero_right_column = PanelContainer.new()
	_hero_right_column.custom_minimum_size = Vector2(340, 220)
	_hero_right_column.size_flags_vertical = Control.SIZE_FILL
	var _actions_dock_empty := StyleBoxEmpty.new()
	_actions_dock_empty.set_content_margin_all(10)
	_hero_right_column.add_theme_stylebox_override("panel", _actions_dock_empty)
	_console_landscape_row.add_child(_hero_right_column)

	_synergy_queue_panel = PanelContainer.new()
	_synergy_queue_panel.custom_minimum_size = Vector2(520, 68)
	var _queue_panel_empty := StyleBoxEmpty.new()
	_queue_panel_empty.content_margin_left = 6
	_queue_panel_empty.content_margin_right = 6
	_queue_panel_empty.content_margin_top = 8
	_queue_panel_empty.content_margin_bottom = 2
	_synergy_queue_panel.add_theme_stylebox_override("panel", _queue_panel_empty)
	_center_dock.add_child(_synergy_queue_panel)

	# VBox dentro del panel: label de texto arriba + slots de cola abajo
	var queue_vbox := VBoxContainer.new()
	queue_vbox.add_theme_constant_override("separation", 4)
	_synergy_queue_panel.add_child(queue_vbox)

	# sin texto instructivo permanente. Solo se muestra
	# dinámicamente (ver update_queue_ui_elements) al confirmarse una sinergia.
	_lbl_synergy_chain = Label.new()
	_lbl_synergy_chain.visible = false
	_lbl_synergy_chain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_synergy_chain.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_synergy_chain.add_theme_font_size_override("font_size", 13)
	_lbl_synergy_chain.clip_text = true
	queue_vbox.add_child(_lbl_synergy_chain)

	# HBox con los slots visuales de PA (MAX_QUEUE = 2 slots, hasta 3 con Sintonía MÁX)
	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 4)
	slots_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# sin expandirse verticalmente, la fila de
	# slots se quedaba en su alto mínimo (42px) dentro de un panel de 88px,
	# dejando un hueco vacío por debajo — ahora ocupa TODA la altura del panel.
	slots_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_vbox.add_child(slots_hbox)

	_queue_slots.clear()
	_queue_separators.clear()

	for i in range(MAX_QUEUE):
		# Slot visual: PanelContainer con metadatos para update_queue_ui_elements
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(0, 34)
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot_panel.add_theme_stylebox_override("panel", _queue_slot_style(false, true))
		slot_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot_panel.tooltip_text = ""
		# Capturar i en el closure correctamente
		var slot_i := i
		slot_panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_queue_slot_clicked(slot_i)
		)

		# Label vacío "[ + ]" para cuando no hay habilidad
		var empty_lbl := Label.new()
		empty_lbl.text = "[ + ]"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty_lbl.add_theme_font_size_override("font_size", 18)
		empty_lbl.add_theme_color_override("font_color", Color(0.32, 0.30, 0.40))
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(empty_lbl)

		# VBox con icono + nombre + PA (visible cuando hay habilidad encolada)
		var content_vbox := VBoxContainer.new()
		content_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		content_vbox.add_theme_constant_override("separation", 1)
		content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.visible = false
		slot_panel.add_child(content_vbox)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(icon_rect)

		# icono de respaldo ("⚡") para cartas de combo
		# fusionadas cuyo id de sinergia aún no tiene un PNG dedicado en
		# assets/combat/skills/ — evita que la carta especial se vea vacía/rota.
		var icon_fallback_lbl := Label.new()
		icon_fallback_lbl.text = "⚡"
		icon_fallback_lbl.visible = false
		icon_fallback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_fallback_lbl.add_theme_font_size_override("font_size", 20)
		icon_fallback_lbl.add_theme_color_override("font_color", Color(0.98, 0.82, 0.32))
		icon_fallback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(icon_fallback_lbl)

		var name_lbl := Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.98))
		name_lbl.clip_text = true
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(name_lbl)

		var pa_lbl := Label.new()
		pa_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pa_lbl.add_theme_font_size_override("font_size", 10)
		pa_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))
		pa_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# el coste en PA ya se lee visualmente
		# en cuántas casillas ocupa la habilidad (1 o 2) — el texto "PA n" era
		# redundante. Se mantiene el nodo (CombatResultUI.update_queue_ui_elements
		# sigue actualizando su color/texto para el tooltip) pero oculto.
		pa_lbl.visible = false
		content_vbox.add_child(pa_lbl)

		# Guardar referencias en metadatos para update_queue_ui_elements
		slot_panel.set_meta("empty_lbl", empty_lbl)
		slot_panel.set_meta("hbox", content_vbox)  # "hbox" es el nombre esperado por el código
		slot_panel.set_meta("icon_rect", icon_rect)
		slot_panel.set_meta("icon_fallback_lbl", icon_fallback_lbl)
		slot_panel.set_meta("name_lbl", name_lbl)
		slot_panel.set_meta("pa_lbl", pa_lbl)

		slots_hbox.add_child(slot_panel)
		_queue_slots.append(slot_panel)

		# Separador entre slots (insignia de sinergia "⚡")
		if i < MAX_QUEUE - 1:
			var sep_panel := PanelContainer.new()
			sep_panel.custom_minimum_size = Vector2(28, 28)
			sep_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var sep_style := StyleBoxFlat.new()
			sep_style.bg_color = Color(0.10, 0.08, 0.18, 0.85)
			sep_style.set_corner_radius_all(14)
			sep_style.set_border_width_all(2)
			sep_style.border_color = Color(0.40, 0.35, 0.55, 0.6)
			sep_panel.add_theme_stylebox_override("panel", sep_style)
			sep_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var sep_lbl := Label.new()
			sep_lbl.text = "⚡"
			sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sep_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sep_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			sep_lbl.add_theme_font_size_override("font_size", 14)
			sep_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sep_panel.add_child(sep_lbl)

			slots_hbox.add_child(sep_panel)
			_queue_separators.append(sep_panel)

	_skills_panel = PanelContainer.new()
	_skills_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _skills_panel_empty := StyleBoxEmpty.new()
	_skills_panel_empty.set_content_margin_all(6)
	_skills_panel.add_theme_stylebox_override("panel", _skills_panel_empty)
	_center_dock.add_child(_skills_panel)

	_grid_scroll = ScrollContainer.new()
	_grid_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skills_panel.add_child(_grid_scroll)

	_content_grid = GridContainer.new()
	_content_grid.columns = 2
	_content_grid.add_theme_constant_override("h_separation", 8)
	_content_grid.add_theme_constant_override("v_separation", 6)
	_content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.add_child(_content_grid)

	# ATB HÉROE + MANDOS 2X2 CUADRADOS, dentro de `_hero_right_column` (3.3).
	var right_dock := VBoxContainer.new()
	right_dock.custom_minimum_size = Vector2(340, 220)
	right_dock.size_flags_vertical = Control.SIZE_FILL
	right_dock.add_theme_constant_override("separation", 6)
	_hero_right_column.add_child(right_dock)

	# Barra ATB Héroe superior con estilo Glossy / Neoclásico (300x16px)
	var atb_hbox := HBoxContainer.new()
	atb_hbox.add_theme_constant_override("separation", 6)
	right_dock.add_child(atb_hbox)

	_lbl_atb_title = Label.new()
	_lbl_atb_title.text = "ATB"
	_lbl_atb_title.add_theme_font_size_override("font_size", 14)
	_lbl_atb_title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.32))
	atb_hbox.add_child(_lbl_atb_title)

	_bar_player_atb = ProgressBar.new()
	_bar_player_atb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_player_atb.custom_minimum_size = Vector2(240, 16)
	_bar_player_atb.show_percentage = false
	_style_glossy_bar(_bar_player_atb, _theme_color("atb", Color(0.2, 0.75, 0.95)))
	atb_hbox.add_child(_bar_player_atb)

	# Cuadrícula 2x2 de Botones Cuadrados táctiles (~160x86px, los más grandes de la UI — LEY DE LA PROPORCIÓN, ratio <= 2.2:1).
	var cmd_grid := GridContainer.new()
	cmd_grid.columns = 2
	cmd_grid.add_theme_constant_override("h_separation", 8)
	cmd_grid.add_theme_constant_override("v_separation", 6)
	cmd_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_dock.add_child(cmd_grid)

	# Fila 1: ATACAR | DEFENDER
	_btn_attack = Button.new()
	_btn_attack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_attack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_btn_attack.custom_minimum_size = Vector2(160, 86)
	_btn_attack.focus_mode = Control.FOCUS_NONE
	_btn_attack.pressed.connect(_on_btn_attack_pressed)
	_style_jrpg_button(_btn_attack, "ATACAR", "⚔️", Color(0.85, 0.25, 0.25), Color(0.20, 0.05, 0.08, 0.95))
	cmd_grid.add_child(_btn_attack)

	_btn_defense = Button.new()
	_btn_defense.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_defense.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_btn_defense.custom_minimum_size = Vector2(160, 86)
	_btn_defense.focus_mode = Control.FOCUS_NONE
	_btn_defense.pressed.connect(_on_btn_defense_pressed)
	_style_jrpg_button(_btn_defense, "DEFENDER", "🛡️", Color(0.25, 0.55, 0.95), Color(0.05, 0.10, 0.20, 0.95))
	cmd_grid.add_child(_btn_defense)

	_btn_defense_cooldown_panel = Panel.new()
	var cd_style := StyleBoxFlat.new()
	cd_style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	cd_style.set_corner_radius_all(8)
	_btn_defense_cooldown_panel.add_theme_stylebox_override("panel", cd_style)
	_btn_defense_cooldown_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_btn_defense_cooldown_panel.visible = false
	_btn_defense_cooldown_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_defense.add_child(_btn_defense_cooldown_panel)

	_lbl_defense_cooldown_text = Label.new()
	_lbl_defense_cooldown_text.text = "5.0s"
	_lbl_defense_cooldown_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_defense_cooldown_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_defense_cooldown_text.add_theme_font_size_override("font_size", 16)
	_lbl_defense_cooldown_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_btn_defense_cooldown_panel.add_child(_lbl_defense_cooldown_text)

	# Fila 2: HABS | ITEMS
	_btn_skills = Button.new()
	_btn_skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_skills.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_btn_skills.custom_minimum_size = Vector2(160, 86)
	_btn_skills.focus_mode = Control.FOCUS_NONE
	_btn_skills.pressed.connect(func() -> void:
		CombatTabsUI.on_tab_pressed(self, "powers")
	)
	_style_jrpg_button(_btn_skills, "HABS.", "✨", Color(0.25, 0.80, 0.45), Color(0.05, 0.16, 0.08, 0.95))
	cmd_grid.add_child(_btn_skills)

	_btn_items = Button.new()
	_btn_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_btn_items.custom_minimum_size = Vector2(160, 86)
	_btn_items.focus_mode = Control.FOCUS_NONE
	_btn_items.pressed.connect(func() -> void:
		CombatTabsUI.on_tab_pressed(self, "bag")
	)
	_style_jrpg_button(_btn_items, "ITEMS", "🎒", Color(0.95, 0.78, 0.25), Color(0.18, 0.14, 0.05, 0.95))
	cmd_grid.add_child(_btn_items)

	_tab_buttons = [_btn_skills, _btn_items]
	_right_panel = null

	# Overlay de log inferior (mantenido por compatibilidad)
	_log_overlay = PanelContainer.new()
	_log_overlay.visible = false
	add_child(_log_overlay)

	# Ventana de Resultados
	result_panel = PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(340, 220)
	result_panel.anchor_left = 0.5
	result_panel.anchor_right = 0.5
	result_panel.anchor_top = 0.5
	result_panel.anchor_bottom = 0.5
	result_panel.offset_left = -170
	result_panel.offset_right = 170
	result_panel.offset_top = -110
	result_panel.offset_bottom = 110
	result_panel.visible = false
	add_child(result_panel)

	var res_margin := MarginContainer.new()
	res_margin.add_theme_constant_override("margin_left", 20)
	res_margin.add_theme_constant_override("margin_right", 20)
	res_margin.add_theme_constant_override("margin_top", 20)
	res_margin.add_theme_constant_override("margin_bottom", 20)
	result_panel.add_child(res_margin)

	var res_vbox := VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 15)
	res_margin.add_child(res_vbox)

	lbl_result = Label.new()
	lbl_result.text = "🏆 VICTORIA"
	lbl_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_result.add_theme_font_size_override("font_size", 40)
	res_vbox.add_child(lbl_result)

	lbl_result_detail = Label.new()
	lbl_result_detail.text = "Detalles..."
	lbl_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_result_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_result_detail.add_theme_font_size_override("font_size", 26)
	lbl_result_detail.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	res_vbox.add_child(lbl_result_detail)

	btn_return = Button.new()
	btn_return.text = "Continuar"
	btn_return.custom_minimum_size.y = 72
	btn_return.add_theme_font_size_override("font_size", 26)
	btn_return.pressed.connect(_on_btn_return_pressed)
	var ret_style := StyleBoxFlat.new()
	ret_style.bg_color = _theme_color("accent2", Color(0.15, 0.32, 0.18))
	ret_style.set_corner_radius_all(12)
	btn_return.add_theme_stylebox_override("normal", ret_style)
	res_vbox.add_child(btn_return)

	# Modal de Profesiones
	_profession_modal = PanelContainer.new()
	_profession_modal.visible = false
	_profession_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_profession_modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var modal_bg := StyleBoxFlat.new()
	modal_bg.bg_color = Color(0.02, 0.01, 0.04, 0.85)
	_profession_modal.add_theme_stylebox_override("panel", modal_bg)

	var modal_center := CenterContainer.new()
	modal_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_profession_modal.add_child(modal_center)

	var modal_box := PanelContainer.new()
	modal_box.custom_minimum_size = Vector2(850, 500)
	var modal_box_style := StyleBoxFlat.new()
	modal_box_style.bg_color = Color(0.04, 0.03, 0.08, 0.97)
	modal_box_style.set_corner_radius_all(18)
	modal_box_style.set_border_width_all(3)
	modal_box_style.border_color = Color(0.98, 0.80, 0.32)  # Borde dorado UiKit.COLOR_GOLD_PRIMARY
	modal_box_style.shadow_color = Color(0.98, 0.80, 0.32, 0.55)
	modal_box_style.shadow_size = 24
	modal_box_style.shadow_offset = Vector2(0, 4)
	modal_box_style.content_margin_left = 20
	modal_box_style.content_margin_right = 20
	modal_box_style.content_margin_top = 20
	modal_box_style.content_margin_bottom = 20
	modal_box.add_theme_stylebox_override("panel", modal_box_style)
	modal_center.add_child(modal_box)

	var modal_vbox := VBoxContainer.new()
	modal_vbox.add_theme_constant_override("separation", 16)
	modal_box.add_child(modal_vbox)

	var lbl_modal_title := Label.new()
	lbl_modal_title.text = "Cambiar Profesión Activa"
	lbl_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_modal_title.add_theme_font_size_override("font_size", 24)
	lbl_modal_title.add_theme_color_override("font_color", _theme_color("accent", Color(0.95, 0.8, 0.3)))
	modal_vbox.add_child(lbl_modal_title)

	_professions_grid = GridContainer.new()
	_professions_grid.columns = 1
	_professions_grid.add_theme_constant_override("h_separation", 10)
	_professions_grid.add_theme_constant_override("v_separation", 14)
	_professions_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_professions_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_vbox.add_child(_professions_grid)

	var btn_cancel_prof := Button.new()
	btn_cancel_prof.text = "Cancelar"
	btn_cancel_prof.custom_minimum_size = Vector2(180, 48)
	btn_cancel_prof.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_cancel_prof.focus_mode = Control.FOCUS_NONE
	btn_cancel_prof.pressed.connect(func(): _open_profession_modal(false))
	modal_vbox.add_child(btn_cancel_prof)

	add_child(_profession_modal)

	# ── 7. OVERLAY DE PAUSA EN COMBATE (CanvasLayer para garantizar dibujo sobre todo el escenario/HUD) ──
	# IMPORTANTE: esto vivía antes al final de `_setup_profession_modal()`, así
	# que `_pause_overlay` solo se creaba si el jugador llegaba a abrir el modal
	# de cambio de profesión al menos una vez — en cualquier otra partida (p. ej.
	# una recién empezada en modo debug) `_pause_overlay` se quedaba en null y
	# `set_paused()` congelaba el combate sin mostrar ninguna interfaz. Ahora se
	# construye siempre aquí, en `_build_ui()`, junto con el resto del HUD.
	_pause_overlay = CanvasLayer.new()
	_pause_overlay.layer = 120
	_pause_overlay.visible = false
	add_child(_pause_overlay)

	var bg_pause := ColorRect.new()
	bg_pause.color = Color(0.02, 0.03, 0.06, 0.88)
	bg_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	bg_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(bg_pause)

	var center_pause := CenterContainer.new()
	center_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(center_pause)

	var pause_card := PanelContainer.new()
	UiKit.premium_panel(pause_card, 20, 16)
	center_pause.add_child(pause_card)

	var vb_pause := VBoxContainer.new()
	vb_pause.add_theme_constant_override("separation", 16)
	vb_pause.custom_minimum_size = Vector2(360, 200)
	pause_card.add_child(vb_pause)

	var lbl_pause_title := Label.new()
	lbl_pause_title.text = "⏸️ " + Locale.pick({"es": "PAUSA", "en": "PAUSE"})
	lbl_pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pause_title.add_theme_font_size_override("font_size", 42)
	lbl_pause_title.add_theme_color_override("font_color", Color.WHITE)
	lbl_pause_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	lbl_pause_title.add_theme_constant_override("shadow_offset_x", 2)
	lbl_pause_title.add_theme_constant_override("shadow_offset_y", 2)
	UiKit.apply_heading(lbl_pause_title)
	vb_pause.add_child(lbl_pause_title)

	var lbl_pause_sub := Label.new()
	lbl_pause_sub.text = Locale.pick({
		"es": "Combate en pausa",
		"en": "Combat paused"
	})
	lbl_pause_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pause_sub.add_theme_font_size_override("font_size", 18)
	lbl_pause_sub.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94, 0.85))
	vb_pause.add_child(lbl_pause_sub)

	var btn_resume := Button.new()
	btn_resume.text = "▶️ " + Locale.pick({"es": "Reanudar Combate", "en": "Resume Combat"})
	btn_resume.custom_minimum_size = Vector2(200, 52)
	btn_resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_resume.add_theme_font_size_override("font_size", 16)
	for st in ["normal", "hover", "pressed", "focus"]:
		btn_resume.add_theme_stylebox_override(st, UiKit.button_primary(12))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn_resume.add_theme_color_override(col, UiKit.BG_DEEP)
	btn_resume.pressed.connect(func() -> void: set_paused(false))
	UiKit.bind_press_feedback(btn_resume)
	vb_pause.add_child(btn_resume)

	var lbl_hint := Label.new()
	lbl_hint.text = Locale.pick({
		"es": "(O pulsa Escape / toca en cualquier parte)",
		"en": "(Or press Escape / tap anywhere)"
	})
	lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hint.add_theme_font_size_override("font_size", 13)
	lbl_hint.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78, 0.7))
	vb_pause.add_child(lbl_hint)

	bg_pause.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			toggle_pause()
	)

	_build_enemy_attack_banner()


func _build_enemy_attack_banner() -> void:
	_enemy_attack_banner = PanelContainer.new()
	_enemy_attack_banner.name = "EnemyAttackBanner"
	_enemy_attack_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_attack_banner.anchor_left = 0.0
	_enemy_attack_banner.anchor_right = 1.0
	_enemy_attack_banner.anchor_top = 0.0
	_enemy_attack_banner.anchor_bottom = 0.0
	_enemy_attack_banner.offset_left = 0.0
	_enemy_attack_banner.offset_right = 0.0
	_enemy_attack_banner.offset_top = 0.0
	_enemy_attack_banner.offset_bottom = 74.0
	_enemy_attack_banner.custom_minimum_size = Vector2(0, 74)
	_enemy_attack_banner.z_index = 85
	_enemy_attack_banner.visible = false

	# Panel base con sombra roja profunda y borde inferior brillante
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.16, 0.03, 0.05, 0.96)
	box.border_width_bottom = 3
	box.border_color = Color(0.98, 0.28, 0.22, 0.95)
	box.shadow_color = Color(0.9, 0.15, 0.15, 0.45)
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, 4)
	_enemy_attack_banner.add_theme_stylebox_override("panel", box)

	# Tira de degradado horizontal centralizado para sensación de alerta cinemática
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.2, 0.15, 0.0))
	grad.add_point(0.2, Color(0.9, 0.15, 0.18, 0.32))
	grad.add_point(0.5, Color(1.0, 0.35, 0.2, 0.65))
	grad.add_point(0.8, Color(0.9, 0.15, 0.18, 0.32))
	grad.set_color(1, Color(0.95, 0.2, 0.15, 0.0))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(1, 0)

	var grad_rect := TextureRect.new()
	grad_rect.texture = grad_tex
	grad_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad_rect.stretch_mode = TextureRect.STRETCH_SCALE
	grad_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_attack_banner.add_child(grad_rect)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_enemy_attack_banner.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var title_hbox := HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(title_hbox)

	var icon_l := Label.new()
	icon_l.text = "⚔️"
	icon_l.add_theme_font_size_override("font_size", 22)
	title_hbox.add_child(icon_l)

	_lbl_attack_banner_title = Label.new()
	_lbl_attack_banner_title.text = "ATAQUE ENEMIGO"
	_lbl_attack_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_attack_banner_title.add_theme_font_size_override("font_size", 22)
	_lbl_attack_banner_title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.94))
	_lbl_attack_banner_title.add_theme_constant_override("outline_size", 6)
	_lbl_attack_banner_title.add_theme_color_override("font_outline_color", Color(0.28, 0.02, 0.04, 1.0))
	title_hbox.add_child(_lbl_attack_banner_title)

	var icon_r := Label.new()
	icon_r.text = "⚔️"
	icon_r.add_theme_font_size_override("font_size", 22)
	title_hbox.add_child(icon_r)

	_lbl_attack_banner_sub = Label.new()
	_lbl_attack_banner_sub.text = "🛡️ ¡PULSA DEFENDER PARA BLOQUEAR EL GOLPE!"
	_lbl_attack_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_attack_banner_sub.add_theme_font_size_override("font_size", 14)
	_lbl_attack_banner_sub.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	_lbl_attack_banner_sub.add_theme_constant_override("outline_size", 4)
	_lbl_attack_banner_sub.add_theme_color_override("font_outline_color", Color(0.18, 0.04, 0.02, 0.9))
	vbox.add_child(_lbl_attack_banner_sub)

	add_child(_enemy_attack_banner)


const PROFESSIONS_7: Array[String] = ["Don Nadie", "Guerrero", "Arquero", "Elementalista", "Sacerdote", "Psíquico", "Tiempo"]

func _setup_profession_modal() -> void:
	if _professions_grid == null:
		return
	for child in _professions_grid.get_children():
		child.queue_free()

	_professions_grid.columns = 1
	var unlocked := GlobalState.unlocked_professions

	# Fila 1: Don Nadie (Centrada arriba)
	# las filas necesitan EXPAND_FILL para estirarse al ancho
	# del modal; si no, se quedan a su tamaño mínimo aunque los botones de
	# dentro también sean EXPAND_FILL.
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_professions_grid.add_child(row1)

	# Fila 2: Guerrero, Arquero, Elementalista (3 columnas)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 16)
	row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_professions_grid.add_child(row2)

	# Fila 3: Sacerdote, Psíquico, Tiempo (3 columnas)
	var row3 := HBoxContainer.new()
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	row3.add_theme_constant_override("separation", 16)
	row3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_professions_grid.add_child(row3)

	for prof in PROFESSIONS_7:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 100) if prof == "Don Nadie" else Vector2(180, 100)
		# que los botones aprovechen el ancho disponible del
		# modal en vez de quedarse en su tamaño mínimo (las filas usan
		# ALIGNMENT_CENTER, que sin esto los deja apretados en el centro).
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)

		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(48, 48)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var path := CombatTabsUI.get_prof_texture_path(prof)
		if ResourceLoader.exists(path):
			tex_rect.texture = load(path)
		vbox.add_child(tex_rect)

		var lbl_name := Label.new()
		lbl_name.text = Locale.translate_profession(prof)
		lbl_name.add_theme_font_size_override("font_size", 14)
		lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_name.clip_text = true
		vbox.add_child(lbl_name)

		var is_unlocked := false
		for unl in unlocked:
			if unl.to_lower() == prof.to_lower() or (prof == "Guerrero" and unl.to_lower() == "espadachin"):
				is_unlocked = true
				break

		if is_unlocked:
			btn.disabled = false
			btn.modulate = Color(1, 1, 1, 1)
			var target_prof := prof
			btn.pressed.connect(func(): _on_profession_selected(target_prof))
			btn.tooltip_text = Locale.pick({"es": "Cambiar a %s", "en": "Switch to %s"}) % Locale.translate_profession(prof)
		else:
			btn.disabled = true
			btn.modulate = Color(0.3, 0.3, 0.3, 0.6)
			btn.tooltip_text = Locale.pick({"es": "Bloqueado", "en": "Locked"})

		# borde dorado encendido para la profesión ACTIVA (distinto del
		# desbloqueo simple), tanto para Don Nadie como el resto vía migración.
		var is_active := prof.to_lower() == GlobalState.profession.to_lower()
		if is_active:
			var active_style := StyleBoxFlat.new()
			active_style.bg_color = Color(0.18, 0.14, 0.04, 0.95)
			active_style.set_corner_radius_all(10)
			active_style.set_border_width_all(3)
			active_style.border_color = COL_GOLD
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_stylebox_override("disabled", active_style)
			btn.add_theme_stylebox_override("hover", active_style)

		if prof == "Don Nadie":
			row1.add_child(btn)
		elif prof in ["Guerrero", "Arquero", "Elementalista"]:
			row2.add_child(btn)
		else:
			row3.add_child(btn)


func _unhandled_input(event: InputEvent) -> void:
	if not is_combat_active or is_skill_animating:
		return
	if is_paused:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			get_viewport().set_input_as_handled()
			toggle_pause()
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if (GlobalState.debug_mode or GlobalState.is_test_room) and (event.keycode == KEY_K or event.physical_keycode == KEY_K):
			get_viewport().set_input_as_handled()
			_on_btn_one_hit_kill_pressed()
			return
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			toggle_pause()


func toggle_pause() -> void:
	if not is_combat_active:
		return
	set_paused(not is_paused)


func set_paused(p: bool) -> void:
	if not is_combat_active:
		return
	is_paused = p
	if _pause_overlay != null:
		_pause_overlay.visible = is_paused
	if btn_pause != null and is_instance_valid(btn_pause):
		if is_paused:
			_set_jrpg_button_labels(btn_pause, "▶️", Locale.pick({"es": "SEGUIR", "en": "RESUME"}))
		else:
			_set_jrpg_button_labels(btn_pause, "⏸️", Locale.pick({"es": "PAUSA", "en": "PAUSE"}))
	AudioManager.play_ui("click")


func _open_profession_modal(p_show: bool) -> void:
	if _profession_modal == null:
		return
	if p_show:
		_setup_profession_modal()
		_profession_modal.visible = true
		_profession_modal.modulate.a = 0.0
		_profession_modal.scale = Vector2(0.8, 0.8)
		_profession_modal.pivot_offset = _profession_modal.size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_profession_modal, "modulate:a", 1.0, 0.2)
		tw.tween_property(_profession_modal, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_profession_modal, "modulate:a", 0.0, 0.15)
		tw.finished.connect(func(): _profession_modal.visible = false)


func _on_profession_selected(prof_id: String) -> void:
	CombatTabsUI.change_class_during_combat(self, prof_id)
	_open_profession_modal(false)


func _update_quick_skill_info(skill: Dictionary) -> void:
	if _quick_info_panel == null:
		return
	_quick_info_panel.visible = true
	var name_str := _skill_name(skill)
	var type_str := String(skill.get("type", "physical")).capitalize()
	var pow_val: int = int(skill.get("power", 0))
	var d_val = skill.get("desc", "")
	var desc_str := String(Locale.pick(d_val)) if d_val is Dictionary else String(d_val)
	if desc_str.is_empty():
		desc_str = "Técnica de combate."

	var sid: String = String(skill.get("id", ""))
	if _lbl_quick_type:
		_lbl_quick_type.text = "%s • Tipo: %s" % [name_str, type_str]
	if _lbl_quick_power:
		if sid == "nob_punch" or String(skill.get("tag", "")) == "nobody_punch":
			_lbl_quick_power.text = " • Daño: %d (= Nivel)" % max(1, GlobalState.level)
		else:
			_lbl_quick_power.text = (" • Potencia: %d" % pow_val) if pow_val > 0 else ""
	if _lbl_quick_desc:
		_lbl_quick_desc.text = desc_str


func _toggle_compact_deck(open: bool) -> void:
	if _grid_scroll == null:
		return
	_is_deck_open = open
	var tw := create_tween().set_parallel(true)
	if open:
		_grid_scroll.visible = true
		tw.tween_property(_grid_scroll, "modulate:a", 1.0, 0.15)
	else:
		tw.tween_property(_grid_scroll, "modulate:a", 0.0, 0.15)
		tw.finished.connect(func(): if not _is_deck_open: _grid_scroll.visible = false)


## Crea una fila "[icono] [barra]" directamente en `host`.
func _make_stat_bar_direct(host: HBoxContainer, label_text: String, color: Color) -> ProgressBar:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 28
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	host.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 22
	bar.custom_minimum_size.x = 160
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	UiKit.style_progress_bordered(bar, color, 6, Color.WHITE, 2)
	host.add_child(bar)
	return bar


## Añade la etiqueta numérica directamente al `host`.
func _stat_bar_value_direct(host: HBoxContainer, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = "--/--"
	lbl.custom_minimum_size.x = 80
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	host.add_child(lbl)
	return lbl


## Crea una barra de HP con "daño fantasma": una barra fantasma (rojo claro) DETRÁS
## y la barra real (fondo transparente) DELANTE, apiladas y ocupando el mismo rect.
## Al recibir daño, la real baja al instante y deja ver la fantasma rezagada.
## Devuelve [host, real, ghost].
func _make_ghost_hp_bar(fill_color: Color, height: int, radius: int, border_w: int) -> Array:
	var host := Control.new()
	host.custom_minimum_size.y = height

	var ghost := ProgressBar.new()
	ghost.show_percentage = false
	ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.style_progress_bordered(ghost, fill_color.lightened(0.25), radius, Color.WHITE, border_w)
	host.add_child(ghost)

	var real := ProgressBar.new()
	real.show_percentage = false
	real.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	real.mouse_filter = Control.MOUSE_FILTER_IGNORE
	real.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	real.add_theme_stylebox_override("fill", UiKit.bar_fill(fill_color, radius))
	host.add_child(real)

	return [host, real, ghost]


## Aplica un cambio de HP con efecto de "daño fantasma". La barra real cambia al
## instante; si es DAÑO, la fantasma se queda ~0.45s y luego drena en ~0.55s,
## mostrando en rojo claro cuánto se ha perdido durante ~1s. En curación sube ya.
func _animate_hp_bar(real: ProgressBar, ghost: ProgressBar, new_value: float, is_enemy: bool) -> void:
	if real == null or ghost == null:
		return
	real.value = new_value
	if Locale.reduce_motion:
		ghost.value = new_value
		return
	if new_value < ghost.value:
		var tw := create_tween()
		if is_enemy:
			if _enemy_hp_ghost_tween != null and _enemy_hp_ghost_tween.is_valid():
				_enemy_hp_ghost_tween.kill()
			_enemy_hp_ghost_tween = tw
		else:
			if _player_hp_ghost_tween != null and _player_hp_ghost_tween.is_valid():
				_player_hp_ghost_tween.kill()
			_player_hp_ghost_tween = tw
		tw.tween_interval(0.45)
		tw.tween_property(ghost, "value", new_value, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	elif new_value > ghost.value:
		ghost.value = new_value


## Estilo de una carta de la cola (normal, sinergia o vacía).
func _queue_slot_style(is_synergy: bool, is_empty: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	if is_synergy:
		# Sinergia: oro brillante con halo para destacar la fusión.
		style.bg_color = _theme_color("accent", Color(0.14, 0.11, 0.05, 0.95)).darkened(0.85)
		style.set_border_width_all(3)
		style.border_color = _theme_color("accent", COL_GOLD)
		style.shadow_color = _theme_color("accent", Color(0.98, 0.80, 0.32, 0.4))
		style.shadow_size = 10
	elif is_empty:
		# Vacío/bloqueado: hueco tenue, casi plano (invita a rellenar).
		style.bg_color = _theme_color("panel_bg", Color(0.03, 0.02, 0.05, 0.6))
		style.set_border_width_all(3)
		style.border_color = _theme_color("border", Color(0.22, 0.18, 0.32, 0.70))
	else:
		# Ocupado: carta sólida con leve relieve.
		style.bg_color = _theme_color("panel_glass", Color(0.06, 0.04, 0.1, 0.95))
		style.set_border_width_all(3)
		style.border_color = _theme_color("border", Color(0.48, 0.32, 0.78, 0.9))
		style.shadow_color = _theme_color("border", Color(0.48, 0.32, 0.78, 0.25))
		style.shadow_size = 6
	return style


func add_sintonia(amount: float) -> void:
	var max_res := 100.0
	player_resonance = clampf(player_resonance + amount, 0.0, max_res)
	if player_resonance >= max_res and not is_resonance_active:
		is_resonance_active = true
		resonant_pending = true
		_show_resonance_max_banner()
	if _resonance_circle:
		_resonance_circle.set_resonance(player_resonance, max_res, is_resonance_active)


func _show_resonance_max_banner() -> void:
	var banner := PanelContainer.new()
	UiKit.premium_panel(banner, 10, 10)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.anchor_top = 0.3
	banner.anchor_bottom = 0.3
	banner.offset_left = -220
	banner.offset_right = 220
	banner.offset_top = -26
	banner.offset_bottom = 26
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)

	var lbl := Label.new()
	lbl.text = "⚡ ¡RESONANCIA MÁXIMA ACTIVA! ⚡"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	banner.add_child(lbl)

	banner.scale = Vector2(0.5, 0.5)
	banner.pivot_offset = Vector2(220, 26)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner, "modulate:a", 1.0, 0.3)
	tw.chain().tween_interval(1.5)
	tw.chain().tween_property(banner, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(banner.queue_free)


#endregion

#region INICIAR COMBATE
func reset_hero_position() -> void:
	if _hero_sprite_rect == null:
		return
	if _hero_action_tween != null and _hero_action_tween.is_valid():
		_hero_action_tween.kill()
		_hero_action_tween = null
	_hero_sprite_rect.anchor_left = 0.57
	_hero_sprite_rect.anchor_right = 0.88
	_hero_sprite_rect.anchor_top = 0.16
	_hero_sprite_rect.anchor_bottom = 0.94
	_hero_sprite_rect.offset_left = 0.0
	_hero_sprite_rect.offset_right = 0.0
	_hero_sprite_rect.offset_top = 0.0
	_hero_sprite_rect.offset_bottom = 0.0
	_hero_sprite_rect.modulate = Color.WHITE
	_hero_sprite_rect.scale = Vector2.ONE
	_hero_sprite_rect.rotation = 0.0
	_hero_sprite_rect.visible = true
	_hero_hurt_timer = 0.0
	_hero_attack_timer = 0.0
	_update_hero_sprite_pose()
	_start_hero_idle_breathing()


func start_combat(enemy: Dictionary) -> void:
	reset_hero_position()
	AudioManager.push_combat_music(bool(enemy.get("is_boss", false)))
	enemy_data = enemy
	var is_dummy: bool = bool(enemy.get("is_training_dummy", false)) or String(enemy.get("id", "")) == "muneco_entrenamiento"
	if is_dummy:
		enemy["level"] = 99
		enemy["hp"] = 9999
		enemy["max_hp"] = 9999
		enemy_data["is_training_dummy"] = true
	enemy_hp = enemy.get("hp", 100)
	enemy_max_hp = enemy_hp
	turn_count = 0
	_orco_turn_count = 0
	_orco_suplicar_count = 0
	_first_hit_blocked = false
	_eco_confused = false
	_eco_enraged = false
	_eco_process_timer = 0.0
	is_combat_active = true
	set_paused(false)
	flee_cooldown = 0.0
	_update_flee_button()
	if btn_one_hit_kill != null and is_instance_valid(btn_one_hit_kill):
		btn_one_hit_kill.visible = GlobalState.debug_mode or GlobalState.is_test_room
	_jobs_used_this_combat.clear()
	_enemy_intent_shown = false
	if _lbl_enemy_intent_badge != null:
		_lbl_enemy_intent_badge.visible = false
	GlobalState.mark_enemy_seen(String(enemy.get("id", "")))   # bestiario: enemigo visto

	# Restaurar sprite del héroe por si el combate anterior terminó en derrota
	# (play_hero_defeat_animation lo deja transparente/encogido tras desintegrarse).
	if _hero_sprite_rect != null:
		_hero_sprite_rect.modulate = Color.WHITE
		_hero_sprite_rect.scale = Vector2(0.72, 0.72) if _is_landscape else Vector2.ONE

	# Cargar fondo dinámico por contexto (mazmorra o bioma de mapamundi)
	var target_bg_path: String = _resolve_combat_background_path(enemy)
	var bg_tex: Texture2D = UiKit.load_texture_safe(target_bg_path)
	if not bg_tex:
		var is_boss: bool = enemy.get("is_boss", false)
		bg_tex = UiKit.load_texture_safe("res://assets/combat/bg/bg_combat_boss.png" if is_boss else "res://assets/combat/bg/bg_combat_normal.png")
	if not bg_tex:
		bg_tex = UiKit.load_texture_safe("res://assets/combat/bg/bg_combat_default.png")
	if bg_tex:
		_bg_texture_rect.texture = bg_tex

	# Cargar plataforma dinámica por contexto
	if _enemy_platform:
		var target_plat_path: String = _resolve_combat_platform_path(enemy, target_bg_path)
		var plat_tex: Texture2D = UiKit.load_texture_safe(target_plat_path)
		if not plat_tex:
			plat_tex = _get_legacy_fallback_platform(target_plat_path, target_bg_path, enemy)
		if not plat_tex:
			plat_tex = UiKit.load_texture_safe("res://assets/combat/platform/plat_rock.png")
		_enemy_platform.texture = plat_tex
		_enemy_platform.modulate = Color.WHITE
		_enemy_platform.visible = true

	# Cargar sprite del enemigo
	var enemy_img_path: String = enemy.get("image", "")
	var enemy_tex: Texture2D = UiKit.load_texture_safe(enemy_img_path)
	if not enemy_tex:
		enemy_tex = UiKit.load_texture_safe("res://assets/combat/enemies/en_default.png")
	_enemy_img_rect.texture = enemy_tex
	_enemy_img_rect.modulate = Color.WHITE
	_enemy_img_rect.scale = Vector2.ONE
	_enemy_img_rect.visible = true
	if _enemy_sprite_container != null:
		_enemy_sprite_container.modulate = Color.WHITE
		_enemy_sprite_container.visible = true
	
	# Alinear y escalar dinámicamente el enemigo y la plataforma
	_align_enemy_and_platform()
		
	# Reiniciar estados
	enemy_statuses.clear()
	player_statuses.clear()
	combat_queue.clear()
	_resurreccion_used = false
	_extra_turns = 0
	_pending_revive_pct = 0
	
	# Reiniciar barras ATB, Resonancia y PA
	player_atb = 0.0
	enemy_atb = 0.0
	player_resonance = 0.0
	resonant_pending = false
	is_resonant_turn = false
	queued_pa = 0
	current_pa_limit = _base_pa_limit()
	_executing_queue = false
	_block_quality = ""
	_world_time_scale = 1.0
	_stop_hp_danger_pulse()
	_hp_was_in_danger = false
	if _resonant_aura:
		_show_resonant_aura(false)  # Restores base border; panel stays visible
	defense_active_time = 0.0
	_hero_hurt_timer = 0.0
	_hero_attack_timer = 0.0
	_update_hero_sprite_pose()
	_start_hero_idle_breathing()
	defense_cooldown = 0.0
	_defense_free_timer = 0.0
	_time_decay_acc = 0.0
	is_invulnerable = false
	_enemy_is_discharging = false
	_enemy_has_hit = false
	enemy_hit_threshold = randf_range(25.0, 75.0)

	# Perfil de bloqueo activo según la profesión (ANTES de posicionar las
	# ventanas visuales de defensa, que dependen de su amplitud).
	_block_profile = GameConfig.block_profile(GlobalState.profession)
	_update_defense_ring_geometry()
	_shield_overlay.modulate.a = 0.0
	_btn_defense_cooldown_panel.visible = false

	# Sincronizar Nivel Integrado del dock del héroe
	_lbl_level.text = "NV %d | JB %d" % [GlobalState.level, GlobalState.job_level]
	_lbl_class.text = Locale.translate_profession(GlobalState.profession).to_upper()
	_load_portrait_texture()
	if _lbl_gold:
		_lbl_gold.text = str(GlobalState.gold)

	var raw_name = enemy.get("name", "Enemigo")
	var e_name: String = Locale.pick(raw_name) if raw_name is Dictionary else String(raw_name)
	var e_level: int = int(enemy.get("level", 1))
	_lbl_enemy_name.text = "%s (lv %d)" % [e_name, e_level]
	var p_level: int = int(GlobalState.level)
	var lvl_diff: int = e_level - p_level
	if lvl_diff > 2:
		_lbl_enemy_name.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))   # Rojo (> 2 niveles más alto)
	elif lvl_diff < -2:
		_lbl_enemy_name.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))  # Verde claro (< 2 niveles más bajo)
	else:
		_lbl_enemy_name.add_theme_color_override("font_color", Color.WHITE)               # Blanco (±2 niveles)
	_bar_enemy_hp.max_value = enemy_max_hp
	_bar_enemy_hp.value = enemy_hp
	_bar_enemy_hp_ghost.max_value = enemy_max_hp
	_bar_enemy_hp_ghost.value = enemy_hp
	_lbl_enemy_hp.text = "%d / %d HP" % [enemy_hp, enemy_max_hp]
	_update_enemy_hp_bar_color()
	_update_flee_button()
	if is_dummy:
		log_message("[color=gold]🎯 ¡Combate de entrenamiento contra el Muñeco de Prácticas! (9999 HP, Nivel 99)[/color]")
		log_message("[color=cyan]💡 Cada habilidad que ejecutes te otorgará EXP Base y EXP de Oficio.[/color]")

	# Línea contextual: debilidades/resistencias en una sola línea.
	if _lbl_ctx_info:
		_lbl_ctx_info.text = "[center]%s[/center]" % _enemy_info_text()

	# Cargar cuadrícula
	_active_tab = "powers"
	CombatTabsUI.refresh_tab_highlight(self)
	CombatTabsUI.build_tab_grid(self)
	update_queue_ui_elements()
	_update_player_bars()
	_sync_player_atb_labels()
	_update_action_buttons()
	_update_status_labels()

	if combat_log != null:
		combat_log.clear()
	log_message("[color=yellow]⚔️ ¡COMBATE INICIADO![/color]")
	log_message("Te enfrentas a [b]%s[/b] %s" % [_enemy_name(), enemy.get("icon", "")])
	log_message(_enemy_info_text())

	# Guardar posición base de animación
	_enemy_sprite_base_y = _enemy_img_rect.position.y

	# Entrada cinemática al combate (sprites entran por los laterales y luego aparece el HUD).
	# Se lanza de forma inmediata sin awaits previos para garantizar que la animación arranque limpia
	# desde el fundido a negro, sin parpadeos ni reinicios de posición.
	var intro_tw: Tween = _play_intro_sequence()
	if intro_tw != null and intro_tw.is_valid():
		await intro_tw.finished

	# Primer ataque si el enemigo cuenta con iniciativa previa
	var first_strike: int = int(enemy.get("first_strike", 0))
	if first_strike > 0 and is_combat_active:
		regen_combat_mp(1)
		log_message("[color=red]💥 ¡El enemigo te golpea primero por %d de daño![/color]" % first_strike)
		apply_damage_to_player(first_strike)

	# Mensaje especial de veneno ambiental para el Liche Eterno (Sendero del Sacerdote).
	# Aparece únicamente cuando los combatientes y el HUD ya están totalmente situados en pantalla,
	# de forma fluida y natural, sin recargar los sprites de los personajes.
	var amb_poison: int = int(enemy.get("ambient_poison_per_turn", 0))
	if amb_poison > 0 and is_combat_active:
		is_intro_playing = true
		var player_dose: int = maxi(1, ceili(amb_poison * 0.5))
		log_message("[color=#a855f7]☠️ [b]El veneno de la sala os afecta a los dos... moriréis lentamente.[/b][/color]")
		log_message("[color=#c084fc]⚗️ Cada turno: %s pierde [b]%d HP[/b] · Tú pierdes [b]%d HP[/b]. ¡Cúrate![/color]" % [_enemy_name(), amb_poison, player_dose])
		CombatFx.spawn_center_callout(self, _damage_popups_node, "☠️ ¡Veneno Ambiental!\n-%d HP al Liche · -%d HP a ti" % [amb_poison, player_dose], Color(0.66, 0.33, 0.95))
		await get_tree().create_timer(1.0).timeout
		is_intro_playing = false

	# Mensaje especial de distorsión temporal para el Cronófago (Sendero del Tiempo).
	# Aparece únicamente cuando la escena y el HUD ya están totalmente situados en pantalla.
	var time_decay: int = int(enemy.get("time_decay_per_sec", 0))
	if time_decay > 0 and is_combat_active:
		is_intro_playing = true
		log_message("[color=#eab308]⌛ [b]¡Distorsión Temporal! El Cronófago pierde estabilidad en este plano.[/b][/color]")
		log_message("[color=#fde047]⏳ Pierde [b]-%d HP por segundo[/b]. ¡Sobrevive hasta que el tiempo lo consuma![/color]" % time_decay)
		CombatFx.spawn_center_callout(self, _damage_popups_node, "⌛ ¡Distorsión Temporal!\n-%d HP/s al Cronófago · ¡Sobrevive!" % time_decay, Color(0.9, 0.75, 0.2))
		await get_tree().create_timer(1.2).timeout
		is_intro_playing = false


#endregion

#region BUCLE DE PROCESAMIENTO ATB EN TIEMPO REAL
## Delegación en `CombatTurnEngine` (scenes/views/view_combat/components). La
## lógica del bucle ATB vive ahora en ese motor especialista; esta vista sólo
## reenvía el frame. El comportamiento es idéntico al monolito original.
func _process(delta: float) -> void:
	if is_paused:
		return
	if flee_cooldown > 0.0:
		flee_cooldown = max(0.0, flee_cooldown - delta)
		_update_flee_button()
	if _turn_engine != null and not is_intro_playing:
		_turn_engine.tick(delta)

	# Decaimiento temporal continuo del Cronófago (Sendero del Tiempo)
	if is_combat_active and not is_intro_playing:
		var time_decay_rate: int = int(enemy_data.get("time_decay_per_sec", 0))
		if time_decay_rate > 0 and enemy_hp > 0:
			_time_decay_acc += delta
			while _time_decay_acc >= 1.0:
				_time_decay_acc -= 1.0
				if is_combat_active and enemy_hp > 0:
					var dmg: int = min(time_decay_rate, enemy_hp)
					enemy_hp = max(0, enemy_hp - dmg)
					_bar_enemy_hp.max_value = enemy_max_hp
					_bar_enemy_hp_ghost.max_value = enemy_max_hp
					_animate_hp_bar(_bar_enemy_hp, _bar_enemy_hp_ghost, enemy_hp, true)
					_lbl_enemy_hp.text = "%d / %d HP" % [enemy_hp, enemy_max_hp]
					CombatFx.spawn_dot_tick(self, _damage_popups_node, "-%d" % dmg, Color(0.95, 0.8, 0.2), _enemy_img_rect)
					if enemy_hp <= 0:
						_end_combat(true)
						break


#endregion

#region EJECUCIÓN DE ACCIONES
## ¿El jugador tiene el turno listo y está decidiendo (ATB lleno, sin ejecutar)?
## Durante esta fase el mundo va en cámara lenta.
func _is_awaiting_decision() -> bool:
	return is_combat_active and player_atb >= 100.0 and not _executing_queue


## Se llama UNA vez cuando el ATB del jugador se llena: gestiona el aturdimiento
## y activa el Estado Resonante si estaba pendiente.
func _on_player_turn_ready() -> void:
	if GameConfig.status_any_flag(player_statuses, "skip"):
		log_message("[color=orange]⚡ ¡Estás aturdido / incapacitado! Pierdes el turno.[/color]")
		combat_queue.clear()
		_recount_queued_pa()
		update_queue_ui_elements()
		player_atb = 0.0
		_sync_player_atb_labels()
		_decrement_statuses(player_statuses)
		_update_status_labels()
		return
	is_resonant_turn = resonant_pending
	# Límite de PA por profesión y resonancia.
	current_pa_limit = _get_max_queue_slots()
	if is_resonant_turn:
		_show_resonant_aura(true)
		log_message("[color=gold]✨ ¡TURNO RESONANTE! Dispones de %d PA y todas las habilidades cuestan -1 PA.[/color]" % current_pa_limit)
	_rebuild_powers_if_active()
	update_queue_ui_elements()


## Límite BASE de PA fuera de Sintonía Máxima: 1 ranura para "Don Nadie"
## (profesión sin sinergias registradas), 2 para el resto. Se usa como valor de
## reinicio entre turnos; durante la decisión, `_get_max_queue_slots()` es la
## fuente de verdad (+1 ranura extra con Sintonía al 100%).
func _base_pa_limit() -> int:
	return 1 if GlobalState.profession == "Don Nadie" else 2


## Coste EFECTIVO de PA de una habilidad este turno (-1 en Estado Resonante, mín 1).
func _effective_pa_cost(skill: Dictionary) -> int:
	var base: int = Design.skill_pa_cost(skill)
	if is_resonant_turn or resonant_pending or player_resonance >= GameConfig.RESONANCE_MAX:
		return maxi(1, base - 1)
	return base


## Nº de ranuras de cola disponibles este turno: 1 ranura para
## "Don Nadie", 2 para el resto de profesiones, y +1 extra en Sintonía MÁXIMA (100%).
## Delegado en `CombatQueueSystem`.
func _get_max_queue_slots() -> int:
	return _queue_system.get_max_queue_slots()


## Ejecuta TODA la secuencia encolada en orden FIFO al confirmar. Cobra
## costes, resuelve daños sucesivos y suma Resonancia por cada habilidad.
func _execute_queue_sequence() -> void:
	_executing_queue = true
	_check_and_fuse_synergies()
	update_queue_ui_elements()

	# DoT / regeneración de estados al INICIO del turno (una vez por secuencia).
	var p_tick := _status_tick(player_statuses)
	if p_tick["dot"] > 0:
		apply_damage_to_player(p_tick["dot"])
		CombatFx.spawn_dot_tick(self, _damage_popups_node, "-%d" % p_tick["dot"], Color(0.5, 0.8, 0.1), _lbl_player_hp)
		log_message("[color=#84cc16]☠️ Sufres [b]%d[/b] de daño de estado.[/color]" % p_tick["dot"])
	if float(p_tick.get("regen", 0.0)) > 0.0 and is_combat_active:
		var rgn := int(GlobalState.max_hp * float(p_tick["regen"]))
		if rgn > 0:
			GlobalState.hp = min(GlobalState.hp + rgn, GlobalState.max_hp)
			CombatFx.spawn_dot_tick(self, _damage_popups_node, "+%d" % rgn, UiKit.GOOD, _lbl_player_hp)
			_update_player_bars()

	# Veneno ambiental: el protagonista pierde vida cada vez que es su turno.
	var amb_poison_dmg: int = int(enemy_data.get("ambient_poison_per_turn", 0))
	if amb_poison_dmg > 0 and is_combat_active:
		var player_poison_dmg: int = maxi(1, ceili(amb_poison_dmg * 0.5))
		apply_damage_to_player(player_poison_dmg)
		CombatFx.spawn_dot_tick(self, _damage_popups_node, "-%d" % player_poison_dmg, Color(0.66, 0.33, 0.95), _lbl_player_hp)
		log_message("[color=#c084fc]☠️ El veneno de la sala te afecta en tu turno: [b]-%d HP[/b]. ¡Cúrate![/color]" % player_poison_dmg)
		if not is_combat_active:
			return

	# Ejecutar las habilidades una a una.
	while not combat_queue.is_empty() and is_combat_active:
		var skill: Dictionary = combat_queue.pop_front()
		update_queue_ui_elements()
		_resolve_player_skill(skill)
		_add_resonance_for_skill(skill)
		var is_dummy: bool = bool(enemy_data.get("is_training_dummy", false)) or String(enemy_data.get("id", "")) == "muneco_entrenamiento"
		if is_dummy and skill.get("type", "") != "potion" and skill.get("type", "") != "class_change":
			_grant_dummy_training_xp()
		if not is_combat_active:
			break
		await get_tree().create_timer(0.18).timeout

	combat_queue.clear()
	queued_pa = 0
	update_queue_ui_elements()

	# Tick de fin de turno (Burbuja Temporal → +MP y +Resonancia).
	if player_statuses.has("burbuja_temporal") and is_combat_active:
		var mp_gain := int(GlobalState.max_mp * 0.05)
		GlobalState.mp = min(GlobalState.mp + mp_gain, GlobalState.max_mp)
		player_resonance = min(GameConfig.RESONANCE_MAX, player_resonance + 5.0)
		log_message("[color=cyan]🫧 Burbuja Temporal te otorga +%d MP y +5 Resonancia.[/color]" % mp_gain)

	# ── Gestión del Estado Resonante ────────────────────────────────
	if is_resonant_turn:
		player_resonance = 0.0
		resonant_pending = false
		is_resonant_turn = false
		_show_resonant_aura(false)
	elif player_resonance >= GameConfig.RESONANCE_MAX and not resonant_pending:
		resonant_pending = true
		AudioManager.play_sfx("levelup")
		log_message("[color=gold]✨ ¡Resonancia al máximo! Tu PRÓXIMO turno será Resonante.[/color]")
	current_pa_limit = _base_pa_limit()
	_update_player_bars()

	# Decrementar estados al acabar el turno.
	_decrement_statuses(player_statuses)
	_update_status_labels()

	# Resetear ATB para recargar el siguiente turno.
	player_atb = 0.0
	_sync_player_atb_labels()
	_executing_queue = false
	_rebuild_powers_if_active()


## Suma Resonancia por una habilidad ejecutada. Usa el campo `resonance_gain` de
## skills.json; si falta, cae a la ganancia por coste de PA o de sinergia.
func _add_resonance_for_skill(skill: Dictionary) -> void:
	var gain: float
	if skill.has("resonance_gain"):
		gain = float(skill["resonance_gain"])
	elif skill.get("is_synergy", false):
		gain = GameConfig.RESONANCE_GAIN_SYNERGY
	else:
		var pa: int = Design.skill_pa_cost(skill)
		gain = float(GameConfig.RESONANCE_GAIN_BY_PA.get(pa, 8.0))
	player_resonance = min(GameConfig.RESONANCE_MAX, player_resonance + gain)
	_update_player_bars()


## Otorga experiencia de nivel base y de oficio al usar una habilidad contra el muñeco de entrenamiento.
func _grant_dummy_training_xp() -> void:
	var xp: int = GameConfig.dummy_train_xp(GlobalState.camp_level)
	GlobalState.add_xp(xp)
	GlobalState.add_job_xp(xp)
	_update_player_bars()
	_lbl_level.text = "NV %d | JB %d" % [GlobalState.level, GlobalState.job_level]

	# Efectos visuales de texto flotante bien grandes en pantalla
	CombatFx.spawn_word(self, _damage_popups_node, "+%d EXP" % xp, Color(0.25, 0.88, 1.0), _hero_sprite_rect, "✨", 52)
	CombatFx.spawn_word(self, _damage_popups_node, "+%d OFICIO" % xp, Color(1.0, 0.85, 0.25), _lbl_class, "👑", 52)
	log_message("[color=gold]🎯 ¡Entrenamiento! Ganas +%d EXP Base y +%d EXP de %s.[/color]" % [xp, xp, GlobalState.profession])


## Resuelve el EFECTO de UNA habilidad de forma GENÉRICA a partir de sus atributos
## (type/element/power/status/effect), sin comprobar nombres concretos.
func _resolve_player_skill(skill: Dictionary) -> void:
	var action_type_peek: String = String(skill.get("type", "physical"))
	# Solo activar impulso de ataque físico/ofensivo si no es auto-curación o buff
	if not (action_type_peek in ["heal", "buff", "support", "defense", "passive"]):
		play_hero_attack_reaction(0.65)

	# Cambio de profesión en cola.
	if skill.get("type", "") == "class_change":
		_resolve_class_change_action(skill)
		return

	# Poción (desde la bolsa).
	if skill.get("type", "") == "potion":
		CombatTabsUI.use_potion_action(self, skill)
		return

	var action_name: String = _skill_name(skill)
	var action_icon: String = String(skill.get("icon", "✨"))
	var action_type: String = String(skill.get("type", "physical"))
	var element: String = String(skill.get("element", "physical"))
	var skill_status: Dictionary = skill.get("status", {})
	var effect: String = String(skill.get("effect", ""))

	# Coste de MP: si no llega, golpe básico gratuito (solo para ofensivas).
	var cost := int(skill.get("cost", 0))
	if GlobalState.mp < cost:
		if action_type in ["physical", "magic", "ranged"]:
			log_message("[color=orange]⚠️ MP insuficiente para [b]%s[/b]. ¡Golpe básico![/color]" % action_name)
			_execute_basic_attack_damage()
		else:
			log_message("[color=orange]⚠️ MP insuficiente para [b]%s[/b].[/color]" % action_name)
		return
	if cost > 0:
		GlobalState.mp -= cost
		_update_player_bars()

	# Especial: Boss Orco Berserker
	if String(enemy_data.get("id", "")) == "orco_berserker":
		var tag := String(skill.get("tag", ""))
		var sid := String(skill.get("id", ""))
		if sid == "nob_punch" or tag == "nobody_punch":
			regen_combat_mp(1)
			CombatFx.play_skill_effect(self, _damage_popups_node, _hero_sprite_rect, _enemy_img_rect, sid, skill, Color.WHITE, false)
			var punch_dmg: int = max(1, GlobalState.level)
			apply_damage_to_enemy(punch_dmg)
			apply_damage_to_player(2)
			log_message("[color=#f87171]👊 Quitas %d de daño... De hecho, ¡te has hecho daño en la mano! Recibes 2 de daño.[/color]" % punch_dmg)
			CombatFx.spawn_word(self, _damage_popups_node, "-2 HP", UiKit.BAD, _lbl_player_hp)
			_update_player_bars()
			return
		elif sid == "nob_talk" or tag == "nobody_talk" or effect == "talk":
			CombatFx.play_skill_effect(self, _damage_popups_node, _hero_sprite_rect, _enemy_img_rect, sid, skill, Color.WHITE, false)
			log_message("[color=#fbbf24]💬 [b]%s[/b]: «¡No quiero hablar con un insecto como tú! ¡ROAAAR!»[/color]" % _enemy_name())
			CombatFx.spawn_word(self, _damage_popups_node, "¡NO QUIERE HABLAR!", UiKit.TEXT_DIM, _enemy_img_rect)
			return
		elif sid == "nob_beg" or tag == "nobody_beg" or effect == "pacify":
			CombatFx.play_skill_effect(self, _damage_popups_node, _hero_sprite_rect, _enemy_img_rect, sid, skill, Color.WHITE, false)
			_orco_suplicar_count += 1
			if _orco_suplicar_count == 1:
				log_message("[color=#60a5fa]🥺 Te arrodillas y suplicas desesperadamente. %s se queda completamente confundido mirándote...[/color]" % _enemy_name())
				CombatFx.spawn_word(self, _damage_popups_node, "¡CONFUNDIDO!", Color(0.4, 0.8, 1.0), _enemy_img_rect)
				enemy_atb = 0.0
				_bar_enemy_atb.value = 0.0
			elif _orco_suplicar_count == 2:
				log_message("[color=#60a5fa]🥺 Sigues suplicando con lágrimas en los ojos. %s baja los brazos y suspira...[/color]" % _enemy_name())
				CombatFx.spawn_word(self, _damage_popups_node, "¡CONMOVIDO!", Color(0.4, 0.8, 1.0), _enemy_img_rect)
				enemy_atb = 0.0
				_bar_enemy_atb.value = 0.0
			else:
				log_message("[color=#60a5fa]🥺 Te arrastras por los suelos lloriqueando y suplicando por tu vida una vez más...[/color]")
				log_message("[color=#fbbf24]🤦 [b]%s[/b]: «¡Basta ya, por favor! Me estás dando una vergüenza ajena que no puedo soportar... No pienso pelear contra alguien tan patético. ¡Me largo!»[/color]" % _enemy_name())
				CombatFx.spawn_word(self, _damage_popups_node, "¡VERGÜENZA AJENA!", Color(0.85, 0.65, 1.0), _enemy_img_rect)
				CombatFx.spawn_center_callout(self, _damage_popups_node, "«¡Qué vergüenza ajena me das!\n¡Paso de ti, me largo!»", Color(1.0, 0.75, 0.3))
				enemy_atb = 0.0
				_bar_enemy_atb.value = 0.0
				_pending_enemy_skill = {}
				_enemy_intent_shown = false
				if _lbl_enemy_intent_badge != null:
					_lbl_enemy_intent_badge.visible = false
				_stop_defense_pulse()
				is_combat_active = false
				combat_queue.clear()
				queued_pa = 0
				update_queue_ui_elements()
				await get_tree().create_timer(1.2).timeout
				_end_combat(true, true)
			return

	# Especial: Boss Eco Fragmentado (Catacumba de las Nieves - Estrategia Don Nadie)
	if String(enemy_data.get("id", "")) == "eco_fragmentado":
		var tag := String(skill.get("tag", ""))
		var sid := String(skill.get("id", ""))
		if sid == "nob_beg" or tag == "nobody_beg" or effect == "pacify":
			CombatFx.play_skill_effect(self, _damage_popups_node, _hero_sprite_rect, _enemy_img_rect, sid, skill, Color.WHITE, false)
			log_message("[color=#60a5fa]🥺 Suplicas lastimosamente. ¡%s pierde su ATB y se queda 5 segundos procesando qué significa semejante gesto patético![/color]" % _enemy_name())
			CombatFx.spawn_word(self, _damage_popups_node, "¡PROCESANDO GESTO! (5s)", Color(0.4, 0.8, 1.0), _enemy_img_rect)
			enemy_atb = 0.0
			_bar_enemy_atb.value = 0.0
			_eco_process_timer = 5.0
			return
		elif sid == "nob_talk" or tag == "nobody_talk" or effect == "talk":
			CombatFx.play_skill_effect(self, _damage_popups_node, _hero_sprite_rect, _enemy_img_rect, sid, skill, Color.WHITE, false)
			_eco_confused = true
			log_message("[color=#fbbf24]💬 Le hablas de forma enigmática. ¡%s sufre confusión permanente! (50%% de probabilidad de dañarse a sí mismo el resto del combate).[/color]" % _enemy_name())
			CombatFx.spawn_word(self, _damage_popups_node, "¡CONFUSIÓN (50%)!", Color(0.9, 0.8, 0.2), _enemy_img_rect)
			return
		elif sid == "nob_shout" or tag == "nobody_shout" or effect == "shout":
			CombatFx.play_skill_effect(self, _damage_popups_node, _hero_sprite_rect, _enemy_img_rect, sid, skill, Color.WHITE, false)
			_eco_enraged = true
			log_message("[color=#f87171]🗣️ ¡Gritas con furia descomunal! %s se enfurece: su siguiente ataque infligirá el doble de daño. (Si está confundido, ¡se atacará a sí mismo al 100%%!)[/color]" % _enemy_name())
			CombatFx.spawn_word(self, _damage_popups_node, "¡ENFURECIDO (x2)!", Color(1.0, 0.3, 0.3), _enemy_img_rect)
			return

	# Efectos especiales data-driven (restore/heal_pct/atb/ejecución/etc.).
	if effect != "":
		_apply_skill_effect(skill, effect)

	# Curación (type == heal, power a escala 0-150): proyectil y texto flotante verde dirigidos al héroe.
	if action_type == "heal":
		var hero_target: Control = (_hero_sprite_rect as Control) if (_hero_sprite_rect != null and _hero_sprite_rect.visible) else (_portrait_frame as Control)
		var cast_origin: Control = _hero_sprite_rect if _hero_sprite_rect != null else hero_target
		CombatFx.play_skill_effect(self, _damage_popups_node, cast_origin, hero_target, String(skill.get("id", "")), skill, Color.WHITE, skill.get("is_synergy", false))
		var heal_amt := calculate_special_damage(skill)
		if heal_amt > 0:
			AudioManager.play_sfx("heal")
			GlobalState.hp = min(GlobalState.hp + heal_amt, GlobalState.max_hp)
			var pos := hero_target.global_position + hero_target.size * 0.5 - Vector2(40, 20)
			CombatFx.spawn_floating_number(self, _damage_popups_node, pos, heal_amt, "heal")
			log_message("[color=lime]💚 [b]%s[/b] → +%d HP[/color]" % [action_name, heal_amt])
		_apply_skill_status(skill, heal_amt)
		_update_player_bars()
		return

	var skill_id_str := String(skill.get("id", ""))
	var is_self_action: bool = false
	var st_tgt := String(skill_status.get("target", ""))
	var sk_tgt := String(skill.get("target", ""))
	if sk_tgt == "self" or st_tgt == "self":
		is_self_action = true
	elif sk_tgt == "enemy" or st_tgt == "enemy":
		is_self_action = false
	elif action_type in ["buff", "defense", "support", "passive"]:
		is_self_action = true
	elif skill_id_str in ["psy_meditation", "pri_divine_prayer"]:
		is_self_action = true
	else:
		is_self_action = false

	# Habilidades dirigidas a uno mismo (buffs, defensas, curaciones de recursos, posturas):
	if is_self_action:
		var hero_target: Control = (_hero_sprite_rect as Control) if (_hero_sprite_rect != null and _hero_sprite_rect.visible) else (_portrait_frame as Control)
		var cast_origin: Control = _hero_sprite_rect if _hero_sprite_rect != null else hero_target
		CombatFx.play_skill_effect(self, _damage_popups_node, cast_origin, hero_target, skill_id_str, skill, Color.WHITE, skill.get("is_synergy", false))
		if not skill_status.is_empty():
			_apply_skill_status(skill, 0)
		return

	# Habilidades dirigidas al enemigo (ofensivas, debuffs, robo, provocación, diálogo, etc.):
	CombatFx.play_skill_effect(self, _damage_popups_node, _hero_sprite_rect, _enemy_img_rect, skill_id_str, skill, Color.WHITE, skill.get("is_synergy", false))
	var hits := _effect_hit_count(effect)
	var raw_damage: int = calculate_special_damage(skill)
	var landed := false
	var has_vfx := CombatFx.has_skill_effect(skill_id_str)
	if raw_damage > 0 or action_type in ["physical", "magic", "ranged"]:
		regen_combat_mp(1)
	if raw_damage <= 0:
		# Habilidad de utilidad / debuff / robo dirigida al enemigo sin daño directo
		landed = true
	else:
		for h in range(hits):
			if not is_combat_active:
				break
			var result := _resolve_attack_on_enemy(raw_damage, action_type, element, false, skill)
			if result["miss"]:
				CombatFx.spawn_word(self, _damage_popups_node, Locale.t("combat_miss"), UiKit.TEXT_DIM, _enemy_img_rect)
				continue
			landed = true
			var dmg: int = result["damage"]
			var final_elem: String = String(result.get("element", element))
			apply_damage_to_enemy(dmg, false, final_elem)
			if result["crit"]:
				CombatFx.play_special_fx(self, _damage_popups_node, _enemy_img_rect, "💥", dmg, UiKit.BAD)
				CombatFx.spawn_word(self, _damage_popups_node, Locale.t("combat_crit"), UiKit.ACCENT_SOFT, _enemy_img_rect, "✸")
				_shake(10.0)
				Juice.hit_stop(0.09)
			elif skill.get("is_synergy", false):
				if not has_vfx:
					CombatFx.play_special_fx(self, _damage_popups_node, _enemy_img_rect, action_icon, dmg, Color(1.0, 0.6, 0.1))
				CombatFx.spawn_word(self, _damage_popups_node, "¡SINERGIA!", Color(1.0, 0.55, 0.15), _enemy_img_rect, "✨")
				_shake(12.0)
				Juice.hit_stop(0.08)
			else:
				# Si la habilidad tiene efecto visual o PNG dedicado, no dibujar emoticono superpuesto
				if not has_vfx:
					CombatFx.play_special_fx(self, _damage_popups_node, _enemy_img_rect, action_icon, dmg, Color("f1c40f"))
			_reveal_elemental_reaction(final_elem, result)

	if landed and not skill_status.is_empty() and is_combat_active:
		_apply_skill_status(skill, raw_damage)


func _resolve_class_change_action(skill: Dictionary) -> void:
	var prof := String(skill.get("profession", ""))
	if GlobalState.profession == prof:
		return
		
	GlobalState.set_profession(prof)
	
	# El perfil de bloqueo activo cambia
	_block_profile = GameConfig.block_profile(prof)
	_update_defense_ring_geometry()
	
	log_message("[color=yellow]👑 Ejecutando cambio de clase: [b]%s[/b].[/color]" % prof)

	# (Pulido del combate): el cambio de profesión en pleno combate
	# no tenía NINGÚN feedback visual/sonoro más allá del log — ahora resalta
	# la etiqueta de clase y avisa con una palabra flotante + sonido.
	AudioManager.play_sfx("levelup")
	_lbl_class.text = prof.to_upper()
	CombatFx.spawn_word(self, _damage_popups_node, "👑 %s" % prof.to_upper(), Color(1.0, 0.85, 0.25), _lbl_class)
	Juice.pop(_lbl_class, 1.25, 0.22)

	# Al cambiar de profesión, refrescar la interfaz para que cargue la nueva clase.
	_active_tab = "powers"
	CombatTabsUI.refresh_tab_highlight(self)
	_load_portrait_texture()
	CombatTabsUI.build_tab_grid(self)


## Nº de impactos de una habilidad según su effect ("multi_hit:N"), por defecto 1.
func _effect_hit_count(effect: String) -> int:
	for part in effect.split(";", false):
		if part.begins_with("multi_hit:"):
			return maxi(1, int(part.substr(10)))
	return 1


## Dispatcher GENÉRICO de efectos especiales (data-driven, por tokens ';').
## Cada token es "clave" o "clave:valor". "restore" se maneja aquí; el resto se
## delega en _apply_named_effect. Los efectos que solo modulan el daño (ignore_def,
## multi_hit, unblockable, guaranteed_crit, high_crit) se resuelven en el ataque.
const _DAMAGE_MODIFIER_EFFECTS := [
	"multi_hit", "ignore_def_half", "ignore_def_full", "ignore_mdef",
	"unblockable", "guaranteed_crit", "high_crit", "requires_low_hp",
]

func _apply_skill_effect(skill: Dictionary, effect: String) -> void:
	for raw in effect.split(";", false):
		var tok := raw.strip_edges()
		var key := tok
		var val := ""
		var colon := tok.find(":")
		if colon != -1:
			key = tok.substr(0, colon)
			val = tok.substr(colon + 1)
		if key == "restore":
			# "restore:mp=25,res=20" → recupera MP/Resonancia/HP.
			for pair in val.split(",", false):
				var kv := pair.split("=")
				if kv.size() != 2:
					continue
				var amount := int(kv[1])
				match String(kv[0]):
					"mp":  GlobalState.mp = min(GlobalState.mp + amount, GlobalState.max_mp)
					"hp":  GlobalState.hp = min(GlobalState.hp + amount, GlobalState.max_hp)
					"res": player_resonance = min(GameConfig.RESONANCE_MAX, player_resonance + float(amount))
			_update_player_bars()
			log_message("[color=purple]✨ %s restaura recursos.[/color]" % _skill_name(skill))
		elif key in _DAMAGE_MODIFIER_EFFECTS:
			# Se resuelven en la fase de daño (_resolve_attack_on_enemy / hit count).
			pass
		else:
			_apply_named_effect(skill, key, val)


## Efectos con lógica concreta que no encajan en el flujo estándar de daño.
func _apply_named_effect(skill: Dictionary, key: String, val: String) -> void:
	match key:
		"heal_pct_lost":
			var lost := GlobalState.max_hp - GlobalState.hp
			var amt := int(lost * 0.5)
			if amt > 0:
				GlobalState.hp = min(GlobalState.hp + amt, GlobalState.max_hp)
				CombatFx.spawn_word(self, _damage_popups_node, "+%d" % amt, UiKit.GOOD, _lbl_player_hp)
				_update_player_bars()
		"cleanse":
			player_statuses.clear()
			_update_status_labels()
			log_message("[color=lime]🧼 %s limpia tus estados alterados.[/color]" % _skill_name(skill))
		"reset_defense_cd":
			defense_cooldown = 0.0
			var dur: float = float(val) if val != "" else 5.0
			_defense_free_timer = dur
			if _btn_defense_cooldown_panel != null:
				_btn_defense_cooldown_panel.visible = false
			CombatFx.spawn_word(self, _damage_popups_node, "🛡️ ¡REFLEJO!", Color(0.3, 0.8, 1.0), _lbl_player_hp)
			log_message("[color=cyan]🛡️ %s: ¡Defensa reiniciada y sin cooldown durante %.0fs![/color]" % [_skill_name(skill), dur])
		"self_atb_add":
			var add := float(int(val)) if val != "" else 35.0
			player_atb = min(100.0, player_atb + add)
			_sync_player_atb_labels()
		"atb_push_enemy":
			var push := float(int(val)) if val != "" else 30.0
			enemy_atb = max(0.0, enemy_atb - push)
			_bar_enemy_atb.value = enemy_atb
			log_message("[color=cyan]⏪ %s retrasa el ATB del enemigo.[/color]" % _skill_name(skill))
		"gravity_pct":
			var pct := (float(int(val)) if val != "" else 60.0) / 100.0
			var gdmg := int(enemy_hp * pct)
			if gdmg > 0:
				apply_damage_to_enemy(gdmg)
				CombatFx.play_special_fx(self, _damage_popups_node, _enemy_img_rect, "🪐", gdmg, Color(0.6, 0.5, 0.9))
		"revive":
			_pending_revive_pct = maxi(_pending_revive_pct, int(val) if val != "" else 30)
			log_message("[color=cyan]👼 %s: te protegerás de la muerte.[/color]" % _skill_name(skill))
		"random_heal":
			var maxh := int(val) if val != "" else 100
			var amt := randi_range(1, maxh)
			GlobalState.hp = min(GlobalState.hp + amt, GlobalState.max_hp)
			CombatFx.spawn_word(self, _damage_popups_node, "+%d" % amt, UiKit.GOOD, _lbl_player_hp)
			_update_player_bars()
		"steal":
			var stolen := randi_range(3, 12)
			GlobalState.gold += stolen
			log_message("[color=yellow]💰 %s roba %d de oro.[/color]" % [_skill_name(skill), stolen])
		"talk":
			# Distraes al enemigo con cháchara: probable confusión.
			log_message("[color=gray]💬 %s intenta distraer a %s...[/color]" % [_skill_name(skill), _enemy_name()])
			_try_apply_status_to_enemy({"type": "confusion", "chance": 0.6, "turns": 2, "power": 0}, 0)
		"pacify":
			# Intentas apaciguar al enemigo: reduce su ataque y a veces lo detiene.
			log_message("[color=gray]🥺 %s suplica clemencia...[/color]" % _skill_name(skill))
			_try_apply_status_to_enemy({"type": "atk_down", "chance": 0.75, "turns": 3, "power": 0}, 0)
			_try_apply_status_to_enemy({"type": "stun", "chance": 0.2, "turns": 1, "power": 0}, 0)
		"random_status":
			# Aplica un estado alterado aleatorio al enemigo.
			var pool := ["poison", "burn", "slow", "confusion", "atk_down", "pdef_down", "mdef_down", "stun"]
			var pick: String = pool[randi() % pool.size()]
			log_message("[color=purple]💃 %s provoca un efecto imprevisible...[/color]" % _skill_name(skill))
			_try_apply_status_to_enemy({"type": pick, "chance": 1.0, "turns": 2, "power": 4}, 12)
		"random_big":
			_apply_random_big_effect(skill)
		_:
			# Efecto no reconocido: sabor sin mecánica.
			log_message("[color=gray]✨ %s.[/color]" % _skill_name(skill))


## Efecto "Leyenda de Don Nadie" (random_big): resultado potente e impredecible.
## Elige al azar entre un gran golpe, curación total, auto-potenciación o parón enemigo.
func _apply_random_big_effect(skill: Dictionary) -> void:
	match randi() % 4:
		0:
			# Golpe descomunal (daño mágico puro que ignora defensa).
			var dmg := int(GlobalState.get_mag_damage() * 2.5) + 40
			apply_damage_to_enemy(dmg)
			CombatFx.play_special_fx(self, _damage_popups_node, _enemy_img_rect, "🌟", dmg, Color(1.0, 0.85, 0.25))
			log_message("[color=gold]🌟 ¡%s desata un golpe legendario![/color]" % _skill_name(skill))
		1:
			# Recuperación milagrosa.
			GlobalState.hp = GlobalState.max_hp
			CombatFx.spawn_word(self, _damage_popups_node, "¡MILAGRO!", UiKit.GOOD, _lbl_player_hp)
			_update_player_bars()
			log_message("[color=lime]🌟 ¡%s te restaura por completo![/color]" % _skill_name(skill))
		2:
			# Auto-potenciación heroica.
			_apply_status(player_statuses, "berserk", 4, 0)
			_update_status_labels()
			log_message("[color=orange]🌟 ¡%s te llena de furia legendaria![/color]" % _skill_name(skill))
		_:
			# Parón temporal del enemigo.
			_try_apply_status_to_enemy({"type": "stun", "chance": 1.0, "turns": 2, "power": 0}, 0)
			log_message("[color=cyan]🌟 ¡%s deja al enemigo perplejo![/color]" % _skill_name(skill))


## Muestra u oculta el aura dorada del Estado Resonante (con pulso suave).
## Anima el `ShaderMaterial` del marco premium (`UiKit.premium_frame`) en vez
## de mutar un `StyleBoxFlat`: el borde ya no es una línea plana, así que el
## ciclo de color se aplica sobre `border_color`/`border_color_2` del shader,
## con `glow_strength`/`border_width` intensificados mientras dura el turno
## Resonante.
func _show_resonant_aura(on: bool) -> void:
	if _resonant_aura == null:
		return
	# Matar siempre el tween anterior para evitar que siga animando.
	if _resonant_aura_tween != null and _resonant_aura_tween.is_valid():
		_resonant_aura_tween.kill()
		_resonant_aura_tween = null

	var mat := UiKit.get_premium_material(_resonant_aura)
	if mat == null:
		return

	if on and not Locale.reduce_motion:
		# Ciclo de color entre acentos del tema (suave, sin parpadeo)
		var c1 := _theme_color("accent2", Color(0.25, 0.90, 1.0))
		var c2 := _theme_color("accent", Color(1.0, 0.82, 0.25))
		var c3 := _theme_color("accent2", Color(0.25, 0.90, 1.0))
		mat.set_shader_parameter("border_width", 6.0)
		mat.set_shader_parameter("glow_strength", 0.85)
		_resonant_aura_tween = _resonant_aura.create_tween().set_loops()
		_resonant_aura_tween.tween_method(func(c: Color) -> void:
			if is_instance_valid(mat):
				mat.set_shader_parameter("border_color", c)
				mat.set_shader_parameter("border_color_2", c.darkened(0.3))
		, c1, c2, 0.9).set_trans(Tween.TRANS_SINE)
		_resonant_aura_tween.tween_method(func(c: Color) -> void:
			if is_instance_valid(mat):
				mat.set_shader_parameter("border_color", c)
				mat.set_shader_parameter("border_color_2", c.darkened(0.3))
		, c2, c2.darkened(0.3), 0.9).set_trans(Tween.TRANS_SINE)
		_resonant_aura_tween.tween_method(func(c: Color) -> void:
			if is_instance_valid(mat):
				mat.set_shader_parameter("border_color", c)
				mat.set_shader_parameter("border_color_2", c.darkened(0.3))
		, c2.darkened(0.3), c3, 0.9).set_trans(Tween.TRANS_SINE)
	else:
		# Restaurar el marco al aspecto normal del tema activo.
		UiKit.premium_frame(_resonant_aura)


## Reconstruye la cuadrícula de poderes si está visible (para reflejar el coste de
## PA actual, p. ej. tras entrar en Estado Resonante).
func _rebuild_powers_if_active() -> void:
	if _active_tab == "powers":
		CombatTabsUI.build_tab_grid(self)


## Regenera MP al protagonista durante el combate (+1 MP pasivo por cada ataque propio o del enemigo).
func regen_combat_mp(amount: int = 1) -> void:
	if not is_combat_active:
		return
	if GlobalState.mp < GlobalState.max_mp:
		GlobalState.mp = int(min(GlobalState.max_mp, GlobalState.mp + amount))
		_update_player_bars()
		_update_action_buttons()
		var anchor: Control = _lbl_player_mp if (_lbl_player_mp != null and is_instance_valid(_lbl_player_mp)) else _hero_sprite_rect
		if anchor != null and is_instance_valid(anchor):
			CombatFx.spawn_word(self, _damage_popups_node, "+%d MP" % amount, Color(0.35, 0.82, 1.0), anchor, "💧", 28)


func _execute_basic_attack_damage() -> void:
	regen_combat_mp(1)
	if String(enemy_data.get("id", "")) == "orco_berserker":
		apply_damage_to_enemy(1)
		apply_damage_to_player(2)
		log_message("[color=#f87171]⚔️ Quitas un lamentable único punto de vida... De hecho, ¡te has hecho daño! Recibes 2 puntos de daño.[/color]")
		CombatFx.spawn_word(self, _damage_popups_node, "-2 HP", UiKit.BAD, _lbl_player_hp)
		_update_player_bars()
		return
	var raw_damage := GlobalState.get_phys_damage()
	var result := _resolve_attack_on_enemy(raw_damage, "physical", "physical", false)
	if result["miss"]:
		CombatFx.spawn_word(self, _damage_popups_node, Locale.t("combat_miss"), UiKit.TEXT_DIM, _enemy_img_rect)
	else:
		var dmg: int = result["damage"]
		apply_damage_to_enemy(dmg)
		CombatFx.play_skill_effect(self, _damage_popups_node, _hero_sprite_rect, _enemy_img_rect, "war_slash", {"id": "war_slash", "element": "fisico"})
		CombatFx.play_special_fx(self, _damage_popups_node, _enemy_img_rect, "⚔️", dmg, Color("f1c40f"))


## Selecciona la acción del enemigo según su IA ("aggressive"/"defensive"/"caster")
## y las habilidades desbloqueadas a su nivel (enemy_skills.json). Devuelve {} para
## indicar que debe recurrir a su ataque básico genérico.
func _choose_enemy_skill() -> Dictionary:
	if String(enemy_data.get("id", "")) == "orco_berserker":
		if _orco_turn_count < 2:
			return Design.get_enemy_skill("gritar_furioso")
		else:
			return Design.get_enemy_skill("ataque_mortal")

	var ids: Array = enemy_data.get("skills", [])
	if ids.is_empty():
		return {}
	var attacks: Array = []
	var buffs: Array = []
	var debuffs: Array = []
	for sid in ids:
		var d: Dictionary = Design.get_enemy_skill(String(sid))
		if d.is_empty():
			continue
		match String(d.get("role", "attack")):
			"buff":   buffs.append(d)
			"debuff": debuffs.append(d)
			_:        attacks.append(d)
	if attacks.is_empty() and buffs.is_empty() and debuffs.is_empty():
		return {}

	# ¿El enemigo ya tiene un buff activo? Evita reactivarlo en bucle.
	var already_buffed := false
	for st in enemy_statuses:
		if GameConfig.status_is_good(st):
			already_buffed = true
			break

	var ai := String(enemy_data.get("ai", "aggressive"))
	var roll := randf()
	match ai:
		"defensive":
			if not buffs.is_empty() and not already_buffed and roll < 0.4:
				return buffs[randi() % buffs.size()]
			if not debuffs.is_empty() and roll < 0.55:
				return debuffs[randi() % debuffs.size()]
		"caster":
			if not debuffs.is_empty() and roll < 0.45:
				return debuffs[randi() % debuffs.size()]
			if not buffs.is_empty() and not already_buffed and roll < 0.55:
				return buffs[randi() % buffs.size()]
		_:
			# aggressive: rara vez se envalentona con un buff.
			if not buffs.is_empty() and not already_buffed and roll < 0.15:
				return buffs[randi() % buffs.size()]

	if attacks.is_empty():
		if not debuffs.is_empty():
			return debuffs[randi() % debuffs.size()]
		if not buffs.is_empty():
			return buffs[randi() % buffs.size()]
		return {}

	# Los agresivos prefieren su golpe más fuerte (con algo de variedad); el resto
	# elige un ataque al azar entre los disponibles.
	if ai == "aggressive" and roll >= 0.25:
		var best: Dictionary = attacks[0]
		for a in attacks:
			if float(a.get("power_mult", 1.0)) > float(best.get("power_mult", 1.0)):
				best = a
		return best
	return attacks[randi() % attacks.size()]


## TELEGRAFÍA DE INTENCIÓN: anuncia (visual + log) lo que el enemigo VA a hacer al
## empezar a cargar su golpe, de modo que el jugador tenga tiempo de decidir si
## defiende/bloquea. `skill` = {} indica un ataque básico genérico.
func _telegraph_enemy_intent(skill: Dictionary) -> void:
	if not is_combat_active or _enemy_intent_shown:
		return
	_enemy_intent_shown = true
	var role := String(skill.get("role", "attack")) if not skill.is_empty() else "attack"
	var badge_icon := "⚔️"
	var banner_title := ""
	var banner_sub := ""

	var skill_name_str := ""
	if not skill.is_empty():
		skill_name_str = Locale.pick(skill.get("name", {}))
		if skill_name_str == "":
			skill_name_str = String(skill.get("id", ""))

	match role:
		"buff":
			badge_icon = "⬆️"
			banner_title = Locale.pick({"es": "✨ EL ENEMIGO SE POTENCIA", "en": "✨ ENEMY POWERING UP"})
			banner_sub = skill_name_str if skill_name_str != "" else Locale.pick({"es": "Concentrando energía...", "en": "Gathering energy..."})
		"debuff":
			badge_icon = "⬇️"
			banner_title = Locale.pick({"es": "💀 TÉCNICA DEBILITANTE", "en": "💀 ENEMY DEBUFF"})
			banner_sub = Locale.pick({"es": "🛡️ ¡PULSA DEFENDER PARA BLOQUEAR!", "en": "🛡️ PRESS DEFEND TO BLOCK!"})
		_:
			# Ataque: distingue ataque fuerte de ataque normal
			var pm := float(skill.get("power_mult", 1.0)) if not skill.is_empty() else 1.0
			var is_heavy := pm >= 1.4
			badge_icon = "💥" if is_heavy else "⚔️"
			if is_heavy:
				banner_title = Locale.pick({"es": "⚠️ ¡ATAQUE FUERTE ENEMIGO!", "en": "⚠️ ENEMY HEAVY ATTACK!"})
			else:
				banner_title = Locale.pick({"es": "⚔️ ATAQUE ENEMIGO ⚔️", "en": "⚔️ ENEMY ATTACK ⚔️"})
			if skill_name_str != "":
				banner_title += " · " + skill_name_str.to_upper()
			banner_sub = Locale.pick({
				"es": "🛡️ ¡PULSA DEFENDER PARA BLOQUEAR EL GOLPE!",
				"en": "🛡️ PRESS DEFEND TO BLOCK THE ATTACK!"
			})

	# Mostramos el banner panorámico superior con degradado en vez del texto flotante feo
	_show_enemy_attack_banner(banner_title, banner_sub)
	Juice.flash(_enemy_img_rect, Color(1.4, 1.2, 0.6), 0.22)
	log_message("[color=#fbbf24]⚠️ %s se prepara para actuar…[/color]" % _enemy_name())

	# Insignia persistente visible durante TODA la descarga
	if _lbl_enemy_intent_badge != null:
		_lbl_enemy_intent_badge.text = badge_icon
		_lbl_enemy_intent_badge.visible = true
	_start_defense_pulse()


func _execute_enemy_action() -> void:
	# Caso especial Muñeco de Entrenamiento: inofensivo
	var is_dummy: bool = bool(enemy_data.get("is_training_dummy", false)) or String(enemy_data.get("id", "")) == "muneco_entrenamiento"
	if is_dummy:
		_pending_enemy_skill = {}
		_enemy_intent_shown = false
		if _lbl_enemy_intent_badge != null:
			_lbl_enemy_intent_badge.visible = false
		_stop_defense_pulse()
		play_enemy_hurt_reaction(0.3)
		log_message("[color=#9ca3af]🎯 El muñeco de entrenamiento absorbe los impactos sin inmutarse.[/color]")
		CombatFx.spawn_word(self, _damage_popups_node, "¡RESISTE!", Color(0.7, 0.7, 0.75), _enemy_img_rect, "🎯", 36)
		return

	# 1. DoTs del enemigo (estados de veneno/quemadura aplicados por habilidades)
	var e_tick := _status_tick(enemy_statuses)
	if e_tick["dot"] > 0:
		apply_damage_to_enemy(e_tick["dot"])
		CombatFx.spawn_dot_tick(self, _damage_popups_node, "-%d" % e_tick["dot"], Color(0.95, 0.45, 0.15), _enemy_img_rect)
		log_message("[color=#f97316]🔥 %s sufre [b]%d[/b] de daño por estado.[/color]" % [_enemy_name(), e_tick["dot"]])
		if not is_combat_active:
			return

	# 1b. Veneno ambiental: daño fijo por turno definido en los datos del enemigo.
	# 1b. Veneno ambiental: daño al enemigo en su propio turno.
	# Usado por el Liche Eterno (Sendero del Sacerdote) para hacer viable el combate.
	var amb_poison_dmg: int = int(enemy_data.get("ambient_poison_per_turn", 0))
	if amb_poison_dmg > 0:
		apply_damage_to_enemy(amb_poison_dmg)
		CombatFx.spawn_dot_tick(self, _damage_popups_node, "-%d" % amb_poison_dmg, Color(0.66, 0.33, 0.95), _enemy_img_rect)
		log_message("[color=#a855f7]☠️ El veneno de la sala consume a %s en su turno: [b]-%d HP[/b].[/color]" % [_enemy_name(), amb_poison_dmg])
		if not is_combat_active:
			return

	# Caso especial Boss Orco Berserker (dun_yelmo)
	if String(enemy_data.get("id", "")) == "orco_berserker":
		_orco_turn_count += 1
		_pending_enemy_skill = {}
		_enemy_intent_shown = false
		if _lbl_enemy_intent_badge != null:
			_lbl_enemy_intent_badge.visible = false
		_stop_defense_pulse()

		if _orco_turn_count == 1:
			_play_enemy_windup()
			CombatFx.play_skill_effect(self, _damage_popups_node, _enemy_img_rect, _enemy_img_rect, "gritar_furioso", Design.get_enemy_skill("gritar_furioso"))
			CombatFx.spawn_word(self, _damage_popups_node, "¡GRITO FURIOSO!", Color(1.0, 0.6, 0.1), _enemy_img_rect)
			log_message("[color=#f97316]🪓 [b]%s[/b] usa [b]Gritar Furioso[/b]:\n«Orco se prepara para hacer el ataque destructor de mundos supremo definitivo ultimate especial edition»[/color]" % _enemy_name())
			return
		elif _orco_turn_count == 2:
			_play_enemy_windup()
			CombatFx.play_skill_effect(self, _damage_popups_node, _enemy_img_rect, _enemy_img_rect, "gritar_furioso", Design.get_enemy_skill("gritar_furioso"))
			CombatFx.spawn_word(self, _damage_popups_node, "¡FURIA TOTAL!", Color(1.0, 0.2, 0.2), _enemy_img_rect)
			log_message("[color=#ef4444]🪓 [b]%s[/b] usa [b]Gritar Furioso[/b]:\n«Va en serio, la has cagado, te va a destrozar, vas a desaparecer de la faz de la tierra»[/color]" % _enemy_name())
			return
		else:
			regen_combat_mp(1)
			_play_enemy_lunge()
			CombatFx.play_skill_effect(self, _damage_popups_node, _enemy_img_rect, _hero_sprite_rect, "ataque_mortal", Design.get_enemy_skill("ataque_mortal"))
			CombatFx.spawn_word(self, _damage_popups_node, "¡ATAQUE MORTAL!", Color(1.0, 0.0, 0.0), _lbl_player_hp)
			log_message("[color=#b91c1c]💥 [b]%s[/b] desata su [b]Ataque Mortal[/b]... ¡¡9999 DE DAÑO INEVITABLE!![/color]" % _enemy_name())
			apply_damage_to_player(9999)
			return

	# 2. Acción ya ELEGIDA y telegrafiada al empezar la descarga (ventana de reacción).
	#    Si por algún motivo no hay pendiente (compat.), se elige al vuelo.
	var enemy_skill := _pending_enemy_skill if not _pending_enemy_skill.is_empty() else _choose_enemy_skill()
	_pending_enemy_skill = {}
	_enemy_intent_shown = false
	if _lbl_enemy_intent_badge != null:
		_lbl_enemy_intent_badge.visible = false
	_stop_defense_pulse()

	# 2a. Habilidad de auto-mejora: el enemigo se potencia y consume su turno.
	if not enemy_skill.is_empty() and String(enemy_skill.get("role", "attack")) == "buff":
		var self_st: Dictionary = enemy_skill.get("self_status", {})
		var st_type: String = String(self_st.get("type", ""))
		if st_type != "" and GameConfig.STATUS_EFFECTS.has(st_type):
			_apply_status(enemy_statuses, st_type, int(self_st.get("turns", 3)), int(self_st.get("power", 0)))
			_play_enemy_windup()
			CombatFx.play_skill_effect(self, _damage_popups_node, _enemy_img_rect, _enemy_img_rect, String(enemy_skill.get("id", "")), enemy_skill)
			CombatFx.spawn_word(self, _damage_popups_node, _status_label(st_type), Color(_status_color(st_type)), _enemy_img_rect)
			log_message("[color=#f97316]✨ %s usa [b]%s[/b] y se potencia.[/color]" % [_enemy_name(), Locale.pick(enemy_skill.get("name", {}))])
			_update_status_labels()
			_decrement_statuses(enemy_statuses)
			_update_status_labels()
			return
		else:
			_play_enemy_windup()
			CombatFx.play_skill_effect(self, _damage_popups_node, _enemy_img_rect, _enemy_img_rect, String(enemy_skill.get("id", "")), enemy_skill)
			log_message("[color=#f97316]✨ %s usa [b]%s[/b] y se prepara.[/color]" % [_enemy_name(), Locale.pick(enemy_skill.get("name", {}))])
			_decrement_statuses(enemy_statuses)
			_update_status_labels()
			return

	# 2b. Acción ofensiva. La habilidad puede sobreescribir tipo/elemento/potencia.
	var base_atk: int = int(enemy_data.get("attack", 5))
	var power_mult: float = float(enemy_skill.get("power_mult", 1.0)) if not enemy_skill.is_empty() else 1.0
	var enemy_atk: int = max(1, int(round(base_atk * power_mult)))
	var enemy_type: String = String(enemy_skill.get("type", enemy_data.get("attack_type", "physical"))) if not enemy_skill.is_empty() else String(enemy_data.get("attack_type", "physical"))
	if not enemy_skill.is_empty():
		log_message("[color=#fca5a5]%s usa [b]%s[/b].[/color]" % [_enemy_name(), Locale.pick(enemy_skill.get("name", {}))])

	# Acometida visual (lunge) del enemigo
	_play_enemy_lunge()

	# Especial: Boss Eco Fragmentado (confusión y autodaño x2)
	if String(enemy_data.get("id", "")) == "eco_fragmentado":
		var self_hit_chance: float = 0.0
		if _eco_confused:
			self_hit_chance = 1.0 if _eco_enraged else 0.5
		if randf() < self_hit_chance:
			var self_dmg: int = max(10, int(enemy_max_hp * 0.35))
			if _eco_enraged:
				self_dmg = int(self_dmg * 2.0)
				_eco_enraged = false
				log_message("[color=#f87171]💥 ¡Eco Fragmentado está furioso y confundido: se golpea a sí mismo con furia descomunal (-%d HP)![/color]" % self_dmg)
				CombatFx.spawn_word(self, _damage_popups_node, "¡AUTO-ATAQUE FURIA x2!", Color(1.0, 0.2, 0.2), _enemy_img_rect)
			else:
				log_message("[color=#fbbf24]🌀 Eco Fragmentado está confundido y se golpea a sí mismo (-%d HP).[/color]" % self_dmg)
				CombatFx.spawn_word(self, _damage_popups_node, "¡AUTO-ATAQUE!", Color(0.9, 0.8, 0.2), _enemy_img_rect)
			apply_damage_to_enemy(self_dmg)
			_decrement_statuses(enemy_statuses)
			_update_status_labels()
			return
		if _eco_enraged:
			enemy_atk = int(enemy_atk * 2.0)
			_eco_enraged = false

	regen_combat_mp(1)

	var defending := defense_active_time > 0.0
	var is_perfect_block := defending and _block_quality == "perfect"

	if is_perfect_block:
		# Bloqueo Perfecto: 0 Daño, Parada limpia con escudo, sin pose de dolor ni daño
		AudioManager.play_sfx("defend")
		CombatFx.spawn_word(self, _damage_popups_node, "0", Color(1.0, 0.88, 0.2), _shield_overlay if _shield_overlay else _hero_sprite_rect)
		log_message("[color=gold]✨ ¡DEFENSA PERFECTA! Bloqueas el 100%% del ataque de %s con tu escudo.[/color]" % _enemy_name())
		var KitRef = preload("res://assets/combat/effects/_fx_kit.gd")
		var fx_ctx: Dictionary = {"host": self, "popups": _damage_popups_node, "origin": _enemy_img_rect, "target": _shield_overlay if _shield_overlay else _hero_sprite_rect}
		KitRef.shield_dome(fx_ctx, Color(1.0, 0.88, 0.2), 1.5)
		KitRef.orbit_sparkles(fx_ctx, Color(1.0, 0.95, 0.5), "✨", 1.5)
		# Se cancela la aplicación de daño y de estados negativos
		_decrement_statuses(enemy_statuses)
		_update_status_labels()
		return
	elif player_statuses.has("esquiva_temporal"):
		player_statuses.erase("esquiva_temporal")
		_update_status_labels()
		CombatFx.spawn_word(self, _damage_popups_node, Locale.t("combat_dodge"), UiKit.RANGED, _lbl_player_hp)
		log_message("[color=cyan]⏳ ¡Esquiva Temporal! Esquivas el ataque de %s por completo.[/color]" % _enemy_name())
	else:
		# Esquiva base + buffs de esquiva de estados (esconderse/illusion/…).
		var dodge_chance: float = GlobalState.get_dodge() + GameConfig.status_dodge_add(player_statuses)
		# El enemigo confundido puede fallar su propio ataque.
		var enemy_miss := false
		for st in enemy_statuses:
			if randf() < float(GameConfig.status_def(st).get("miss_chance", 0.0)):
				enemy_miss = true
				break

		if enemy_miss:
			CombatFx.spawn_word(self, _damage_popups_node, "¡FALLA!", UiKit.RANGED, _enemy_img_rect)
			log_message("[color=cyan]🌀 %s está confundido y falla su ataque.[/color]" % _enemy_name())
		elif randf() * 100.0 < dodge_chance:
			CombatFx.spawn_word(self, _damage_popups_node, Locale.t("combat_dodge"), UiKit.RANGED, _lbl_player_hp)
		else:
			# ── RASGO: BLOQUEO DEL PRIMER GOLPE (armadura básica) ──
			var has_first_hit_shield: bool = false
			for eq_slot in GlobalState.equipped.keys():
				var eq_res: EquipmentResource = GlobalState.equipped[eq_slot]
				if eq_res != null:
					for trait_entry in eq_res.active_traits():
						if String(trait_entry.get("type", "")) == "block_first_hit":
							has_first_hit_shield = true
							break
			if has_first_hit_shield and not _first_hit_blocked:
				var is_unstoppable: bool = bool(enemy_skill.get("unstoppable", false)) or bool(enemy_skill.get("imparable", false)) or (String(enemy_data.get("id", "")) == "orco_berserker" and String(enemy_skill.get("id", "")) == "ataque_mortal")
				if is_unstoppable:
					log_message("[color=crimson]⚠️ ¡El ataque de %s es imparable y no puede ser bloqueado por la armadura![/color]" % _enemy_name())
				else:
					_first_hit_blocked = true
					AudioManager.play_sfx("defend")
					CombatFx.spawn_word(self, _damage_popups_node, "¡BLOQUEO TOTAL!", Color(1.0, 0.85, 0.2), _lbl_player_hp)
					log_message("[color=gold]🛡️ ¡Tu armadura absorbe y bloquea por completo el primer golpe de la batalla![/color]")
					_decrement_statuses(enemy_statuses)
					_update_status_labels()
					return

			var defense: int = GlobalState.get_mag_defense() if enemy_type == "magic" else GlobalState.get_phys_defense()
			# Defensa como MITIGACIÓN PORCENTUAL (ver GameConfig.mitigate): la defensa
			# del jugador nunca anula del todo el golpe enemigo, evitando el antiguo
			# "1 de daño" cuando PDEF/MDEF superaban con creces el ataque enemigo.
			var base_net: int = GameConfig.mitigate(float(enemy_atk), float(defense))
			var dmg_mult: float = 1.0

			# Debuffs ofensivos del enemigo (atk_down/mdef_down reducen su daño).
			base_net = max(1, int(base_net * GameConfig.status_out_mult(enemy_statuses)))

			# ── DEFENSA POR BLOQUEO ────────────────────────────────────
			if defending:
				dmg_mult *= _block_damage_mult(enemy_type)
				var pct := int(round((1.0 - dmg_mult) * 100.0))
				if _block_quality == "perfect":
					log_message("[color=gold]✨ ¡Defensa perfecta! Reduce el daño un " + str(pct) + "%.[/color]")
				else:
					log_message("[color=aqua]🛡️ Defensa correcta: reduce el daño un " + str(pct) + "%.[/color]")

			# Mitigación por ESTADOS defensivos del jugador (data-driven).
			dmg_mult *= GameConfig.status_incoming_mult(player_statuses, enemy_type)

			# Mitigación por CUALIDADES de equipamiento activo (refinamiento y pasivas)
			var enemy_element: String = String(enemy_skill.get("element", enemy_data.get("element", "physical"))) if not enemy_skill.is_empty() else String(enemy_data.get("element", "physical"))
			var is_elem: bool = (enemy_element != "physical" and enemy_element != "" and enemy_element != "none")
			var elem_mult: float = 1.0
			for eq_slot in GlobalState.equipped.keys():
				var eq_res: EquipmentResource = GlobalState.equipped[eq_slot]
				if eq_res != null:
					for trait_entry in eq_res.active_traits():
						var tr_type: String = String(trait_entry.get("type", ""))
						if (tr_type == "all_element_resist" or tr_type == "elemental_damage_reduction") and is_elem:
							elem_mult *= (1.0 - float(trait_entry.get("value", 0.0)))
						elif (tr_type == "non_elemental_damage_reduction" or tr_type == "physical_damage_reduction") and not is_elem:
							elem_mult *= (1.0 - float(trait_entry.get("value", 0.0)))
						elif tr_type == "resist_element" and String(trait_entry.get("element", "")) == enemy_element:
							elem_mult *= (1.0 - float(trait_entry.get("value", 0.0)))
						elif tr_type == "damage_reduction" and String(trait_entry.get("damage_type", "")) == enemy_type:
							elem_mult *= (1.0 - float(trait_entry.get("value", 0.0)))
			dmg_mult *= clampf(elem_mult, 0.1, 1.0)

			var net: int = max(1, int(base_net * dmg_mult))
			CombatFx.play_skill_effect(self, _damage_popups_node, _enemy_img_rect, _hero_sprite_rect, String(enemy_skill.get("id", "strike")), enemy_skill)
			apply_damage_to_player(net)
			
			if defending:
				CombatFx.spawn_word(self, _damage_popups_node, "🛡️ -%d" % net, Color(0.4, 0.7, 1.0), _lbl_player_hp)
			else:
				CombatFx.spawn_word(self, _damage_popups_node, "-%d" % net, Color(1, 0.2, 0.2), _lbl_player_hp)
				
			# Intentar aplicar estado al jugador (innato del enemigo)
			var soh: Dictionary = enemy_data.get("status_on_hit", {})
			if not soh.is_empty() and is_combat_active:
				_try_apply_status_to_player(soh)
			# Estado propio de la habilidad usada (target != "self").
			var skill_status: Dictionary = enemy_skill.get("status", {})
			if not skill_status.is_empty() and String(skill_status.get("target", "player")) != "self" and is_combat_active:
				_try_apply_status_to_player(skill_status)

	# Decrementar estados del enemigo al acabar su turno
	_decrement_statuses(enemy_statuses)
	_update_status_labels()


## Retroceso sutil (wind-up) mientras el enemigo carga su ataque: sube y atrás.
func _play_enemy_windup() -> void:
	if _enemy_img_rect == null:
		return
	# Normalizar la escala de respiración antes de animar la posición.
	_enemy_img_rect.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(_enemy_img_rect, "position:y", _enemy_sprite_base_y - 25.0, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Acometida rápida y exagerada hacia abajo/adelante al infligir el daño, con
## regreso suave a la posición de reposo.
func _play_enemy_lunge() -> void:
	if _enemy_img_rect == null:
		return
	var strike_y := _enemy_sprite_base_y + 110.0
	var tw := create_tween()
	# 1. Golpe rápido (acometida en 0.08s)
	tw.tween_property(_enemy_img_rect, "position:y", strike_y, 0.08) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# 2. Pausa de impacto (0.08s)
	tw.tween_interval(0.08)
	# 3. Retorno a la posición base de reposo (0.3s)
	tw.tween_property(_enemy_img_rect, "position:y", _enemy_sprite_base_y, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Reacción visual de impacto/absorción del enemigo (p. ej. muñeco de entrenamiento absorbiendo golpes)
func play_enemy_hurt_reaction(duration: float = 0.3) -> void:
	if _enemy_img_rect != null and is_instance_valid(_enemy_img_rect):
		CombatFx.play_hit_reaction(self, _enemy_img_rect, false)
		Juice.shake(_enemy_img_rect, 6.0, duration)
		Juice.flash(_enemy_img_rect, Color(1.2, 1.2, 1.2), 0.12)


#endregion

#region BULLET-TIME Y ANILLO DE IMPACTO (QTE DE DEFENSA, task_reforma_defensa.md)
## Radio (px) del anillo de impacto correspondiente a `diff` puntos de ATB de
## distancia respecto al instante de impacto (`enemy_hit_threshold`). Fórmula
## lineal ÚNICA compartida por el anillo animado y por las bandas de color
## estáticas (`_update_defense_ring_geometry`), para que ambos coincidan siempre.
func _atb_diff_to_ring_radius(diff: float) -> float:
	return lerp(_ring_target_radius, RING_MAX_RADIUS, clampf(diff / BULLET_TIME_ATB_WINDOW, 0.0, 1.0))


## Punto (coordenadas GLOBALES de pantalla) sobre el que se proyecta el anillo
## de impacto: la "peana/pecho" del héroe, un poco por encima del centro de su
## sprite a cuerpo entero.
func _hero_chest_global_pos() -> Vector2:
	if _hero_sprite_rect == null:
		return get_global_rect().get_center()
	var r := _hero_sprite_rect.get_global_rect()
	return r.position + Vector2(r.size.x * 0.5, r.size.y * 0.42)


## FASE 1 — Zoom de cámara de enfoque: al empezar el enemigo a descargar su
## ataque (windup), empuja en primer plano la silueta del héroe y atenúa el
## resto del escenario, para dirigir la atención antes de que llegue el golpe.
## Sin cámara real en esta escena (combate 2D por Control): se simula con
## escala/atenuación sobre los propios sprites — ver `_exit_camera_focus()`.
func _enter_camera_focus() -> void:
	if _camera_focus_active:
		return
	_camera_focus_active = true
	if Locale.reduce_motion or _hero_sprite_rect == null:
		return
	_hero_sprite_rect.pivot_offset = _hero_sprite_rect.size * Vector2(0.5, 0.7)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_hero_sprite_rect, "scale", Vector2(1.16, 1.16), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _enemy_sprite_container != null:
		tw.tween_property(_enemy_sprite_container, "modulate", Color(0.55, 0.55, 0.62), 0.2)
	if _enemy_panel != null:
		tw.tween_property(_enemy_panel, "modulate", Color(0.6, 0.6, 0.65), 0.2)


## Restaura el escenario a su estado normal tras resolverse el golpe enemigo
## (bloqueado o encajado).
func _exit_camera_focus() -> void:
	if not _camera_focus_active:
		return
	_camera_focus_active = false
	if Locale.reduce_motion or _hero_sprite_rect == null:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_hero_sprite_rect, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _enemy_sprite_container != null:
		tw.tween_property(_enemy_sprite_container, "modulate", Color.WHITE, 0.22)
	if _enemy_panel != null:
		tw.tween_property(_enemy_panel, "modulate", Color.WHITE, 0.22)


## FASE 1/2 — Entra en "bullet-time": ralentiza `Engine.time_scale` (respetando
## `reduce_motion`, que desactiva SOLO la ralentización, no el anillo — sigue
## siendo la única pista visual del timing de defensa) y proyecta el anillo de
## impacto sobre el pecho del héroe.
func _enter_bullet_time() -> void:
	if _bullet_time_active:
		return
	_bullet_time_active = true
	if not Locale.reduce_motion:
		Engine.time_scale = BULLET_TIME_SCALE
	_defense_ring = DefenseImpactRing.new()
	var colors := {
		"target": _theme_color("highlight", Color(1.0, 0.85, 0.25)),
		"perfect": Color(_theme_color("highlight", Color(1.0, 0.85, 0.25)), 0.5),
		"normal": Color(_theme_color("accent", Color(0.35, 0.72, 0.95)), 0.35),
		"closing": _theme_color("text", Color(1.0, 1.0, 1.0)),
	}
	_defense_ring.configure(_ring_target_radius, _ring_perfect_radius, _ring_normal_radius, RING_MAX_RADIUS, colors)
	add_child(_defense_ring)
	_defense_ring.center_on(_hero_chest_global_pos())
	_defense_ring.set_progress(1.0)


## Restaura `Engine.time_scale` al salir del "bullet-time" (llamado desde
## `_resolve_defense_encounter`, nunca directamente).
func _exit_bullet_time() -> void:
	if not _bullet_time_active:
		return
	_bullet_time_active = false
	Engine.time_scale = 1.0


## Resuelve la ventana de reacción del golpe enemigo: da feedback final al
## anillo de impacto según `quality` ("perfect" | "normal" | "miss") y sale
## tanto del "bullet-time" como del zoom de cámara. Se llama UNA vez por golpe,
## desde `_on_btn_defense_pressed()` (si el jugador reacciona a tiempo) o desde
## `CombatTurnEngine.tick()` (si el golpe impacta sin haber pulsado DEFENDER).
## Es un no-op si ya se resolvió (no hay "bullet-time" activo).
func _resolve_defense_encounter(quality: String) -> void:
	if not _bullet_time_active:
		return
	if _defense_ring != null and is_instance_valid(_defense_ring):
		_defense_ring.resolve(quality)
	_defense_ring = null
	_exit_bullet_time()
	_exit_camera_focus()
	_stop_defense_pulse()
	_hide_enemy_attack_banner()


## Salvaguarda de limpieza total (fin abrupto del combate en plena ventana de
## reacción): libera el anillo sin animación y restaura cámara/tiempo al
## instante. Ver `CombatDamageResolver._end_combat()`.
func _force_end_defense_effects() -> void:
	if _defense_ring != null and is_instance_valid(_defense_ring):
		_defense_ring.queue_free()
	_defense_ring = null
	_bullet_time_active = false
	Engine.time_scale = 1.0
	_camera_focus_active = false
	_stop_defense_pulse()
	_hide_enemy_attack_banner()
	if _hero_sprite_rect != null:
		_hero_sprite_rect.scale = Vector2.ONE
	if _enemy_img_rect != null:
		_enemy_img_rect.modulate = Color.WHITE
		_enemy_img_rect.scale = Vector2.ONE
	if _enemy_platform != null:
		_enemy_platform.modulate = Color.WHITE
	if _enemy_sprite_container != null:
		_enemy_sprite_container.modulate = Color.WHITE
	if _enemy_panel != null:
		_enemy_panel.modulate = Color.WHITE
#endregion

#region BOTONES DE ACCIONES RÁPIDAS
## Botón ATACAR: ahora CONFIRMA y ejecuta toda la secuencia encolada.
func _on_btn_attack_pressed() -> void:
	if not is_combat_active or is_skill_animating or _executing_queue or _enemy_is_discharging:
		return
	if player_atb < 100.0:
		log_message("[color=orange]⏳ Tu barra ATB aún no está lista.[/color]")
		return
	if combat_queue.is_empty():
		log_message("[color=orange]⚠️ Encola al menos una habilidad antes de confirmar.[/color]")
		return
	AudioManager.play_sfx("click")
	_execute_queue_sequence()


## Botón DEFENSA: QTE de bloqueo.
## La ventana ya NO se comprueba contra un valor fijo (70%-90%/
## 85%±2%) — eso estaba desincronizado del punto de impacto REAL
## (`enemy_hit_threshold`, aleatorio 25%-75% por encuentro, ver `_reset_combat_
## state()`), que es lo que `CombatTurnEngine`/`_execute_enemy_action` usa de
## verdad para disparar el golpe, y lo que ya proyecta el anillo de impacto
## sobre el héroe (`DefenseImpactRing`). Ahora la ventana se centra en
## `enemy_hit_threshold` con la amplitud del perfil de bloqueo
## (`_block_profile.normal_window`/`perfect_window`), coherente con la marca
## visual (`_update_defense_ring_geometry`) y con el gate de habilitado del
## botón en `CombatResultUI._update_action_buttons()`.
## - Zona correcta → mitigación según el perfil (-40% por defecto), "¡Defensa!".
## - Zona perfecta (sub-zona interior) → mitigación según el perfil (-90% por
##   defecto), Parry Perfecto SOULS-LIKE (task_reforma_defensa.md, FASE 3):
##   hit-stop, flash blanco, sacudida de pantalla, sonido de impacto pesado,
##   banner dorado "¡DEFENSA PERFECTA!" y +20% de Resonancia.
func _on_btn_defense_pressed() -> void:
	if not is_combat_active or defense_cooldown > 0.0 or defense_active_time > 0.0:
		return
	AudioManager.play_sfx("click")
	defense_active_time = DEFENSE_ACTIVE_DURATION
	set_hero_defending(true)

	_block_quality = "none"  # Fuera de ventana por defecto
	var prof: Dictionary = _block_profile

	# Zona QTE: evaluada 1:1 contra el radio visual del anillo animado
	if _enemy_is_discharging and not _enemy_has_hit:
		if _defense_ring != null and is_instance_valid(_defense_ring):
			var r := _defense_ring.get_current_radius()
			if r <= _ring_perfect_radius + 6.0:
				_block_quality = "perfect"
			elif r <= _ring_normal_radius + 10.0:
				_block_quality = "normal"
		else:
			var normal_tol: float = float(prof.get("normal_window", 0.45)) * ENEMY_DISCHARGE_RATE
			var perfect_tol: float = float(prof.get("perfect_window", 0.22)) * ENEMY_DISCHARGE_RATE
			var diff := absf(enemy_atb - enemy_hit_threshold)
			if diff <= normal_tol * 1.15:
				_block_quality = "normal"
				if perfect_tol > 0.0 and diff <= perfect_tol * 1.15:
					_block_quality = "perfect"
	else:
		# Sin descarga activa: defensa básica sin zona
		_block_quality = "normal"

	# El golpe ya se resolvió: se sale del "bullet-time"/zoom de cámara y el
	# anillo de impacto da su feedback final ANTES de la celebración de abajo,
	# para no encadenar dos ralentizaciones de `Engine.time_scale` seguidas.
	_resolve_defense_encounter(_block_quality)

	if _block_quality == "perfect":
		# DEFENSA PERFECTA: sale grande y centrado en el medio de la pantalla
		CombatFx.spawn_center_callout(self, _damage_popups_node, Locale.pick({"es": "¡DEFENSA PERFECTA!", "en": "PERFECT BLOCK!"}), COL_GOLD, "✨", 64)
		# Ganar +20% de resonancia fija + lo que defina el perfil de bloqueo
		var base_res_gain: float = float(prof.get("perfect_resonance", 0.0))
		var total_res_gain: float = maxf(base_res_gain, 20.0)  # Mínimo +20%
		player_resonance = min(GameConfig.RESONANCE_MAX, player_resonance + total_res_gain)
		CombatFx.spawn_word(self, _damage_popups_node, "+%d Resonancia" % int(total_res_gain), _theme_color("accent2", Color(1.0, 0.85, 0.25)), _shield_overlay)
		_update_player_bars()
		log_message("[color=gold]✨ ¡DEFENSA PERFECTA! +%d Resonancia. Parry.[/color]" % int(total_res_gain))
		AudioManager.play_sfx("parry_perfect")
		Juice.hit_stop(0.15)
		Juice.shake(self, 8.0, 0.3)
		_play_perfect_parry_flash()
		# Task 4 FASE 4.2: pulso háptico en móviles al lograr el Parry Perfecto.
		# `vibrate_handheld` es un no-op silencioso en plataformas sin soporte
		# (PC/web), así que no hace falta comprobar `OS.has_feature("mobile")`.
		Input.vibrate_handheld(60)
		var tw := create_tween()
		tw.tween_property(_shield_overlay, "modulate:a", 1.0, 0.08)
		tw.tween_property(_shield_overlay, "modulate:a", 0.5, 0.12)
	elif _block_quality == "normal":
		# DEFENSA CORRECTA: -40% daño (centrada en el medio de la pantalla)
		CombatFx.spawn_center_callout(self, _damage_popups_node, Locale.pick({"es": "¡DEFENSA!", "en": "BLOCK!"}), _theme_color("accent", Color(0.35, 0.72, 0.95)), "🛡️", 54)
		log_message("[color=aqua]🛡️ ¡Defensa correcta! (-40% daño)[/color]")
		var tw := create_tween()
		tw.tween_property(_shield_overlay, "modulate:a", 0.55, 0.15)
	else:
		# FUERA DE VENTANA: sin mitigación especial
		CombatFx.spawn_center_callout(self, _damage_popups_node, Locale.pick({"es": "BLOQUEADO", "en": "BLOCKED"}), Color(0.75, 0.75, 0.8), "🛡️", 44)
		log_message("[color=gray]🛡️ Defensa fuera de ventana.[/color]")


## Flash blanco de 2 frames sobre TODA la pantalla de combate al lograr un
## Parry Perfecto (task_reforma_defensa.md, FASE 3 — souls-like): un
## `ColorRect` opaco se muestra 2 frames y se desvanece en 0.1s. Se mantiene
## incluso con `reduce_motion` (destello informativo/breve, no una animación
## sostenida) — coherente con la filosofía de accesibilidad de `Juice.flash()`.
func _play_perfect_parry_flash() -> void:
	var flash_rect := ColorRect.new()
	flash_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash_rect)
	move_child(flash_rect, get_child_count() - 1)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.1).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(flash_rect.queue_free)


## ¿El bloqueo perfecto actual anula por completo este tipo de daño?
func _block_full_block(enemy_type: String) -> bool:
	var prof: Dictionary = _block_profile
	var m: float = float(prof.get("magic_perfect_mult", 1.0)) if enemy_type == "magic" else float(prof.get("perfect_mult", 1.0))
	return m <= 0.001


## Multiplicador de daño recibido según la calidad del bloqueo QTE. Lee los
## multiplicadores del perfil de bloqueo activo (`GameConfig.BLOCK_PROFILE`)
## en vez de hardcodearlos, para que el perfil más débil de "Don Nadie"
## (`BLOCK_PROFILE_NONE`) se respete también en el daño físico.
## - perfect: -90% daño (mult = 0.10 por defecto)
## - normal: -40% daño (mult = 0.60 por defecto)
## - none / fuera de ventana: daño completo (mult = 1.0)
func _block_damage_mult(enemy_type: String) -> float:
	var prof: Dictionary = _block_profile
	# Fallbacks alineados con `GameConfig.BLOCK_PROFILE` (0.10/0.60 = -90%/-40%):
	# si el perfil careciera de la clave, mitigar como el perfil por defecto en
	# vez de con valores antiguos ya desfasados.
	if _block_quality == "perfect":
		if enemy_type == "magic":
			return float(prof.get("magic_perfect_mult", 0.10))
		return float(prof.get("perfect_mult", 0.10))
	elif _block_quality == "normal":
		return float(prof.get("normal_mult", 0.60))
	return 1.0  # Sin mitigación fuera de ventana


#endregion

#region ENCOLAR Y CHEQUEAR SINERGIAS (por IDs, data-driven desde synergies.json)
func _on_skill_pressed(skill_data: Dictionary, source_btn: Control = null) -> void:
	if not is_combat_active or _executing_queue or _enemy_is_discharging:
		return
	# Si hay un cambio de clase encolado, ocupa TODO el turno: no admite más acciones.
	if not combat_queue.is_empty() and String(combat_queue[0].get("type", "")) == "class_change":
		log_message("[color=orange]⚠️ El cambio de clase ocupa todo el turno.[/color]")
		return
	if combat_queue.size() >= _get_max_queue_slots():
		log_message("[color=orange]⚠️ Cola llena.[/color]")
		return

	# Si la resonancia llegó al 100% o el turno resonante estaba pendiente, sincronizar bandera
	if resonant_pending or player_resonance >= GameConfig.RESONANCE_MAX:
		is_resonant_turn = true

	var pa: int = _effective_pa_cost(skill_data)
	# Re-evaluar el límite de PA en cada encolado: si la Resonancia llegó al 100%
	# durante este turno (resonant_pending activado mid-turn), _get_max_queue_slots()
	# ya devuelve 3 pero current_pa_limit aún vale 2 (fijado al inicio del turno).
	# Sincronizar aquí evita que el 3er slot quede bloqueado por la comprobación de PA.
	current_pa_limit = _get_max_queue_slots()
	if queued_pa + pa > current_pa_limit:
		log_message("[color=orange]⚠️ No tienes suficientes PA para [b]%s[/b] (cuesta %d PA).[/color]" % [_skill_name(skill_data), pa])
		return

	var entry: Dictionary = skill_data.duplicate(true)
	entry["pa"] = pa
	var target_slot := queued_pa  # slot destino es la primera casilla de PA libre
	combat_queue.append(entry)
	# XP de profesión por trabajo PARTICIPANTE (docs/design/PROGRESSION.md §3):
	# se registra la profesión activa al ENCOLAR una habilidad de profesión de
	# verdad (no una poción, que no pertenece a ninguna profesión).
	if String(skill_data.get("type", "")) != "potion" and not _jobs_used_this_combat.has(GlobalState.profession):
		_jobs_used_this_combat.append(GlobalState.profession)
	# sin esto, `queued_pa` se quedaba en 0 tras el primer
	# encolado (solo se recalculaba al desencolar) y el chequeo de PA de
	# arriba dejaba de ser una restricción real hasta el primer desencolado.
	_recount_queued_pa()
	# La selección de habilidad no tenía sonido ni pop táctil del
	# botón pulsado (solo la carta fantasma volando hacia la cola).
	AudioManager.play_sfx("click")
	# Animación de vuelo de la carta hacia su slot.
	if source_btn != null:
		Juice.pop(source_btn, 1.1, 0.12)
		_flash_skill_card(source_btn)
		_animate_skill_fly(source_btn, entry, target_slot)
	_check_and_fuse_synergies()
	update_queue_ui_elements()


## Fusiona pares (y triples con Sintonía MÁX) de la cola cuyos IDs formen una
## sinergia definida en data/synergies.json. Sin lógica hardcodeada por nombre.
## Delegado en `CombatQueueSystem`.
func _check_and_fuse_synergies() -> void:
	_queue_system.check_and_fuse_synergies()



## Carta fantasma que vuela desde el botón pulsado hasta el slot destino de la cola
## (200-300 ms), reforzando el feedback táctil del encolado.
func _animate_skill_fly(source_btn: Control, skill: Dictionary, slot_index: int) -> void:
	if _damage_popups_node == null or Locale.reduce_motion:
		return
	if slot_index < 0 or slot_index >= _queue_slots.size():
		return

	# Crear un mini panel contenedor flotante que parezca una carta premium
	var ghost := PanelContainer.new()
	var g_style := StyleBoxFlat.new()
	g_style.bg_color = _theme_color("panel_glass", Color(0.18, 0.12, 0.28, 0.9)) # Púrpura oscuro semitransparente
	g_style.set_corner_radius_all(10)
	g_style.set_border_width_all(2)
	g_style.border_color = _theme_color("accent", Color(0.7, 0.45, 0.95)) # Bordes neón
	g_style.shadow_color = _theme_color("accent", Color(0.65, 0.35, 0.9, 0.3)) # Brillo/Sombra morada
	g_style.shadow_size = 8
	ghost.add_theme_stylebox_override("panel", g_style)

	ghost.custom_minimum_size = Vector2(50, 50)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 100

	var icon_rect := TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var skill_id := String(skill.get("id", ""))
	var img_path := ""
	if skill.get("type", "") == "potion" or skill.has("item_id"):
		var item_id := String(skill.get("item_id", ""))
		img_path = "res://assets/combat/skills/item_%s.png" % item_id
	else:
		img_path = "res://assets/combat/skills/%s.png" % skill_id

	if ResourceLoader.exists(img_path):
		icon_rect.texture = load(img_path)
	ghost.add_child(icon_rect)

	_damage_popups_node.add_child(ghost)

	var from_pos: Vector2 = source_btn.global_position + source_btn.size * 0.5
	var slot: Control = _queue_slots[slot_index]
	var to_pos: Vector2 = slot.global_position + slot.size * 0.5

	# Centrar inicialmente en el botón de origen
	ghost.global_position = from_pos - Vector2(25, 25)
	ghost.pivot_offset = Vector2(25, 25)

	var tw := create_tween().set_parallel(true)
	# Desplazarse al slot destino con curva elástica/suave
	tw.tween_property(ghost, "global_position", to_pos - Vector2(25, 25), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Girar 15 grados en el aire
	tw.tween_property(ghost, "rotation_degrees", 15.0, 0.3)
	# Reducir ligeramente a escala de encaje (de 1.0 a 0.8)
	tw.tween_property(ghost, "scale", Vector2(0.8, 0.8), 0.3)
	tw.chain().tween_callback(ghost.queue_free)


## Destello rápido del botón de la habilidad al ser pulsado.
func _flash_skill_card(btn: Control) -> void:
	if Locale.reduce_motion:
		return
	var flash := create_tween()
	var glow := _theme_color("accent", Color(1.3, 1.1, 0.8))
	flash.tween_property(btn, "modulate", glow, 0.08)
	flash.tween_property(btn, "modulate", Color.WHITE, 0.22)


## Efecto de FUSIÓN dedicado tras detectar una sinergia: pop + destello de la carta,
## onda dorada expansiva y dos chispas que convergen sobre el slot fusionado, más la
## palabra "SINERGIA". Premia visualmente el descubrimiento (Filosofía Visual).
func _animate_synergy_fusion(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _queue_slots.size() or Locale.reduce_motion:
		return
	var slot: Control = _queue_slots[slot_index]
	UiKit.pop(slot, 1.22, 0.24)
	var flash := create_tween()
	flash.tween_property(slot, "modulate", Color(1.9, 1.6, 0.7), 0.1)
	flash.tween_property(slot, "modulate", Color.WHITE, 0.28)

	if _damage_popups_node == null:
		return
	var center: Vector2 = slot.global_position + slot.size * 0.5
	var gold := Color(1.0, 0.85, 0.35)

	# Onda dorada expansiva (anillo redondeado que crece y se desvanece).
	var ring := Panel.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.set_corner_radius_all(60)
	rs.set_border_width_all(4)
	rs.border_color = gold
	ring.add_theme_stylebox_override("panel", rs)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = slot.size
	ring.pivot_offset = slot.size * 0.5
	ring.global_position = center - slot.size * 0.5
	ring.z_index = 90
	_damage_popups_node.add_child(ring)
	var rt := create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.45)
	rt.chain().tween_callback(ring.queue_free)

	# Dos chispas que convergen desde los lados hacia el centro del slot.
	for dir in [-1.0, 1.0]:
		var spark := Panel.new()
		var ss := StyleBoxFlat.new()
		ss.bg_color = gold
		ss.set_corner_radius_all(9)
		spark.add_theme_stylebox_override("panel", ss)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.size = Vector2(18, 18)
		spark.pivot_offset = Vector2(9, 9)
		spark.global_position = center - Vector2(9, 9) + Vector2(dir * 90.0, 0)
		spark.z_index = 91
		_damage_popups_node.add_child(spark)
		var st := create_tween().set_parallel(true)
		st.tween_property(spark, "global_position", center - Vector2(9, 9), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		st.tween_property(spark, "scale", Vector2(1.8, 1.8), 0.22)
		st.chain().tween_property(spark, "scale", Vector2(0.1, 0.1), 0.12)
		st.chain().tween_callback(spark.queue_free)

	CombatFx.spawn_word(self, _damage_popups_node, "SINERGIA", gold, slot, "🌟")


## Nombre YA traducido de una habilidad, tolerando `name` como String o {es,en}.
func _skill_name(skill: Dictionary) -> String:
	var nm = skill.get("name", "")
	return Locale.pick(nm) if nm is Dictionary else String(nm)


## Recalcula los PA acumulados a partir del contenido actual de la cola.
func _recount_queued_pa() -> void:
	queued_pa = 0
	for s in combat_queue:
		queued_pa += int(s.get("pa", _effective_pa_cost(s)))


#endregion

#region GESTIÓN DE TABS E INTERFAZ SELECCIÓN
# Extraído a components/CombatTabsUI.gd (CombatTabsUI.on_tab_pressed/build_tab_grid/...).


#endregion

#region RESOLUCIÓN DE COMBATE Y DAÑO / ESTADOS ALTERADOS
## Fachada: la lógica vive en `CombatDamageResolver`. Mismas firmas públicas de siempre; ningún llamante
## externo (incluido `CombatTurnEngine`, que ya invoca algunas vía `_view.`)
## cambia.
func _play_intro_sequence() -> Tween:
	return _damage_resolver._play_intro_sequence()

func apply_damage_to_enemy(amount: int, is_critical: bool = false, element: String = "") -> void:
	_damage_resolver.apply_damage_to_enemy(amount, is_critical, element)

func apply_damage_to_player(amount: int) -> void:
	_damage_resolver.apply_damage_to_player(amount)

func _end_combat(victory: bool, enemy_fled: bool = false) -> void:
	_damage_resolver._end_combat(victory, enemy_fled)

func _resolve_attack_on_enemy(raw_damage: int, type: String, element: String, combo: bool, skill: Dictionary = {}) -> Dictionary:
	return _damage_resolver._resolve_attack_on_enemy(raw_damage, type, element, combo, skill)

func _reveal_elemental_reaction(element: String, result: Dictionary) -> void:
	_damage_resolver._reveal_elemental_reaction(element, result)

func _consume_status(statuses: Dictionary, key: String) -> void:
	_damage_resolver._consume_status(statuses, key)

func _status_tick(statuses: Dictionary) -> Dictionary:
	return _damage_resolver._status_tick(statuses)

func _decrement_statuses(statuses: Dictionary) -> void:
	_damage_resolver._decrement_statuses(statuses)

func _apply_status(statuses: Dictionary, type: String, turns: int, power: int) -> void:
	_damage_resolver._apply_status(statuses, type, turns, power)

func _try_apply_status_to_enemy(status: Dictionary, dmg: int) -> void:
	_damage_resolver._try_apply_status_to_enemy(status, dmg)

func _try_apply_status_to_player(soh: Dictionary) -> void:
	_damage_resolver._try_apply_status_to_player(soh)

func _apply_skill_status(skill: Dictionary, dmg: int) -> void:
	_damage_resolver._apply_skill_status(skill, dmg)

func _update_status_labels() -> void:
	_damage_resolver._update_status_labels()

func _rebuild_status_icons(row: HBoxContainer, statuses: Dictionary) -> void:
	_damage_resolver._rebuild_status_icons(row, statuses)

func _rebuild_status_icons_deferred(row: HBoxContainer, statuses: Dictionary) -> void:
	_damage_resolver._rebuild_status_icons_deferred(row, statuses)

func _status_summary(statuses: Dictionary) -> String:
	return _damage_resolver._status_summary(statuses)

func _status_icon(type: String) -> String:
	return _damage_resolver._status_icon(type)

func _status_color(type: String) -> String:
	return _damage_resolver._status_color(type)

func _status_label(type: String) -> String:
	return _damage_resolver._status_label(type)


#endregion

#region PANEL DE RESULTADO, REFRESCO DE BARRAS/COLA Y BOTONES
## Fachada: la lógica vive en `CombatResultUI`. Mismas firmas públicas de siempre; ningún llamante
## externo (incluidos `CombatTurnEngine`, `CombatQueueSystem` y
## `CombatDamageResolver`, que ya invocan varias vía `_view.`) cambia.
func _animate_result_panel(victory: bool) -> void:
	_result_ui._animate_result_panel(victory)

func _shake(intensity: float) -> void:
	_result_ui._shake(intensity)

func _build_queue_box_mapping() -> Array:
	return _result_ui._build_queue_box_mapping()

func update_queue_ui_elements() -> void:
	_result_ui.update_queue_ui_elements()

func _animate_synergy_badge(badge: Control, active: bool) -> void:
	_result_ui._animate_synergy_badge(badge, active)

func _on_queue_slot_clicked(slot_index: int) -> void:
	_result_ui._on_queue_slot_clicked(slot_index)

func _update_player_bars() -> void:
	_result_ui._update_player_bars()

func _update_resonance_glow() -> void:
	_result_ui._update_resonance_glow()

func _start_hp_danger_pulse() -> void:
	_result_ui._start_hp_danger_pulse()

func _stop_hp_danger_pulse() -> void:
	_result_ui._stop_hp_danger_pulse()

func _sync_player_atb_labels() -> void:
	_result_ui._sync_player_atb_labels()

func _update_action_buttons() -> void:
	_result_ui._update_action_buttons()

func _refresh_chrome() -> void:
	_result_ui._refresh_chrome()

func _on_btn_return_pressed() -> void:
	_result_ui._on_btn_return_pressed()

func _update_flee_button() -> void:
	if btn_flee == null or not is_instance_valid(btn_flee):
		return
	var is_dummy: bool = bool(enemy_data.get("is_training_dummy", false)) or String(enemy_data.get("id", "")) == "muneco_entrenamiento"
	if is_dummy:
		_set_jrpg_button_labels(btn_flee, "🚪", Locale.pick({"es": "SALIR", "en": "EXIT"}))
		btn_flee.tooltip_text = Locale.pick({"es": "Terminar entrenamiento y volver a la base", "en": "End training and return to camp"})
		btn_flee.modulate = Color.WHITE
		btn_flee.disabled = false
		return
	var is_boss_enemy: bool = bool(enemy_data.get("is_boss", false))
	var can_flee: bool = not is_boss_enemy and bool(enemy_data.get("can_flee", true))
	if not can_flee:
		_set_jrpg_button_labels(btn_flee, "🚫", Locale.pick({"es": "BLOQUEO", "en": "LOCKED"}))
		btn_flee.tooltip_text = Locale.pick({"es": "¡Este combate no permite huida!", "en": "This battle cannot be fled!"})
		btn_flee.modulate = Color(0.7, 0.7, 0.75, 0.85)
		btn_flee.disabled = true
	elif flee_cooldown > 0.0:
		_set_jrpg_button_labels(btn_flee, "⏳", "%.1fs" % flee_cooldown)
		btn_flee.tooltip_text = Locale.pick({
			"es": "Espera %.1fs para volver a intentar huir" % flee_cooldown,
			"en": "Wait %.1fs before attempting to flee again" % flee_cooldown
		})
		btn_flee.modulate = Color(0.7, 0.7, 0.75, 0.85)
		btn_flee.disabled = true
	else:
		_set_jrpg_button_labels(btn_flee, "🏃", Locale.t("combat_flee"))
		btn_flee.tooltip_text = Locale.pick({"es": "Intentar escapar del combate", "en": "Attempt to escape from battle"})
		btn_flee.modulate = Color.WHITE
		btn_flee.disabled = false


func _update_enemy_hp_bar_color() -> void:
	if _bar_enemy_hp == null or _bar_enemy_hp.max_value <= 0:
		return
	var pct := float(_bar_enemy_hp.value) / float(_bar_enemy_hp.max_value)
	var fill_style := StyleBoxFlat.new()
	fill_style.set_corner_radius_all(4)
	if pct > 0.5:
		fill_style.bg_color = Color(0.2, 0.8, 0.4)       # Verde esmeralda (>50%)
	elif pct >= 0.25:
		fill_style.bg_color = Color(0.95, 0.8, 0.2)      # Amarillo (25%-50%)
	else:
		fill_style.bg_color = Color(0.95, 0.2, 0.2)      # Rojo crítico (<25%)
	_bar_enemy_hp.add_theme_stylebox_override("fill", fill_style)


func _on_btn_flee_pressed() -> void:
	if not is_combat_active or is_skill_animating:
		return
	var is_dummy: bool = bool(enemy_data.get("is_training_dummy", false)) or String(enemy_data.get("id", "")) == "muneco_entrenamiento"
	if is_dummy:
		_result_ui._on_btn_flee_pressed()
		return
	if flee_cooldown > 0.0:
		return
	var is_boss_enemy: bool = bool(enemy_data.get("is_boss", false))
	var can_flee: bool = not is_boss_enemy and bool(enemy_data.get("can_flee", true))
	if not can_flee:
		AudioManager.play_sfx("click")
		CombatFx.spawn_word(self, _damage_popups_node, "¡No hay escapatoria!", Color(1.0, 0.35, 0.35), btn_flee, "🚫", 32)
		return
	flee_cooldown = FLEE_COOLDOWN_MAX
	_update_flee_button()
	_result_ui._on_btn_flee_pressed()


func _on_btn_one_hit_kill_pressed() -> void:
	if not is_combat_active or is_skill_animating:
		return
	var overkill: int = maxi(enemy_max_hp * 10, 999999)
	apply_damage_to_enemy(overkill, true, "divine")


#endregion

#region AUXILIARES E IA DEL ENEMIGO
## Daño/valor base de una habilidad ANTES de defensa. Fórmula LIMPIA y centralizada
## en GameConfig (potencia 0-150 → power/100); la defensa la resta el resolver.
## Resuelve por ATRIBUTOS (type/power), sin comprobaciones por nombre.
func calculate_special_damage(skill: Dictionary) -> int:
	var sid: String = String(skill.get("id", ""))
	if sid == "nob_punch" or String(skill.get("tag", "")) == "nobody_punch":
		return max(1, GlobalState.level)
	var power: float = float(skill.get("power", 0.0))
	var type: String = String(skill.get("type", "physical"))
	match type:
		"magic":
			return GameConfig.offensive_damage(GlobalState.get_mag_damage(), power, "magic")
		"ranged":
			return GameConfig.offensive_damage(GlobalState.get_range_damage(), power, "ranged")
		"heal":
			return GameConfig.heal_amount(GlobalState.stats["int"] * 3 + GlobalState.level * 2, power)
		_:
			return GameConfig.offensive_damage(GlobalState.get_phys_damage(), power, "physical")


# Mensajes que son redundantes con el feedback visual (popups de daño,
# barras de vida, nombre del enemigo en header) y no deben mostrarse en el toast.
const _LOG_SKIP_PREFIXES: Array[String] = [
	"Te enfrentas",   # nombre del enemigo (ya en header)
	"TURNO",          # numero de turno (no aporta)
]

## Toast de combate de 2 filas: el mensaje nuevo aparece abajo (grande) y
## el anterior sube arriba (pequeño y gris). Solo se muestran mensajes
## que no tienen representación visual equivalente en pantalla.
func log_message(text: String) -> void:
	# Filtrar mensajes redundantes con el feedback visual
	var clean := text.replace("[b]", "").replace("[/b]", "")
	for prefix in _LOG_SKIP_PREFIXES:
		if prefix in clean:
			return

	# Extraer el texto puro quitando tags BBCode para las labels simples
	var plain := text
	var tag_re := RegEx.new()
	if tag_re.compile("\\[[^\\]]*\\]") == OK:
		plain = tag_re.sub(plain, "", true)

	if _lbl_log_prev and _lbl_log_curr:
		# El actual sube al historial (pequeño)
		_lbl_log_prev.text = _lbl_log_curr.text
		# El nuevo ocupa la fila principal (grande)
		_lbl_log_curr.text = plain
		# Entrada animada: fade-in del label actual
		_lbl_log_curr.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_lbl_log_curr, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)


func _enemy_name() -> String:
	var raw_name = enemy_data.get("name", "Enemigo")
	return Locale.pick(raw_name) if raw_name is Dictionary else str(raw_name)


## Resuelve la ruta del fondo de combate dinámico según si el combate ocurre
## en una mazmorra (por tema/id de mazmorra) o en el mapamundi (por bioma/terreno).
func _resolve_combat_background_path(enemy: Dictionary) -> String:
	var context: String = String(enemy.get("context", "")).to_lower()

	# 1. Caso Mazmorra (por tema o ID de mazmorra):
	if context == "dungeon" or enemy.has("dungeon_theme") or enemy.has("dungeon_id"):
		var dungeon_theme: String = String(enemy.get("dungeon_theme", "cave")).to_lower()
		var did: String = String(enemy.get("dungeon_id", "")).to_lower()
		
		if "nieves" in did or dungeon_theme in ["snow", "snow_catacomb", "ice"]:
			return "res://assets/combat/bg/bg_combat_dungeon_snow.png"
		elif "desierto" in did or dungeon_theme in ["sand", "desert", "desert_ruins"]:
			return "res://assets/combat/bg/bg_combat_dungeon_desert.png"
		elif "laboratorio" in did or dungeon_theme in ["arcanium_lab", "lab", "tech"]:
			return "res://assets/combat/bg/bg_combat_dungeon_lab.png"
		elif "sendero_arquero" in did or dungeon_theme == "overgrown":
			return "res://assets/combat/bg/bg_combat_dungeon_overgrown.png"
		elif "sendero_guerrero" in did or dungeon_theme == "fortress":
			return "res://assets/combat/bg/bg_combat_dungeon_fortress.png"
		elif "sendero_psiquico" in did or dungeon_theme == "crystal_sanctum":
			return "res://assets/combat/bg/bg_combat_dungeon_crystal.png"
		elif "sendero_tiempo" in did or dungeon_theme == "chrono_temple":
			return "res://assets/combat/bg/bg_combat_dungeon_chrono.png"
		elif "sendero_elementalista" in did or dungeon_theme == "magma_caldera":
			return "res://assets/combat/bg/bg_combat_volcano.png"
		elif "sendero_sacerdote" in did or dungeon_theme == "sanctuary":
			return "res://assets/combat/bg/bg_combat_dungeon_sanctuary.png"
		elif "dun_final" in did or "inicial" in did or dungeon_theme == "temple":
			return "res://assets/combat/bg/bg_combat_dungeon_temple.png"
		else:
			return "res://assets/combat/bg/bg_combat_dungeon_cave.png"

	# 2. Caso Mapamundi (prioridad estricta al TERRENO exacto de la casilla):
	var terrain: String = String(enemy.get("world_terrain", "")).to_lower()
	var zone: String = String(enemy.get("world_zone", "")).to_lower()
	var coord: Vector2i = enemy.get("cell_coord", GlobalState.player_pos)
	if (terrain == "" or zone == "") and coord != Vector2i(-1, -1):
		var c_res: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
		if c_res != null:
			if terrain == "":
				terrain = c_res.terrain.to_lower()
		if zone == "":
			var z_def: Dictionary = Design.get_zone_at(coord)
			zone = String(z_def.get("id", "")).to_lower()

	var is_dam_opened: bool = GlobalState.has_world_flag("dam_opened") or GlobalState.dam_opened

	# 2.1 Mapeo estricto por código de TERRENO
	if terrain in ["lav", "magma", "volcano"]:
		return "res://assets/combat/bg/bg_combat_volcano.png"
	elif terrain in ["ice", "snw", "snow", "icy"]:
		return "res://assets/combat/bg/bg_combat_snow.png"
	elif terrain in ["des", "snd", "are", "sand", "desert"]:
		return "res://assets/combat/bg/bg_combat_desert.png"
	elif terrain in ["swp", "swamp", "ciénaga"]:
		return "res://assets/combat/bg/bg_combat_swamp.png"
	elif terrain in ["bad"]:
		# El Yelmo: si la presa está abierta es pradera/valle verde, si no es la ciénaga inundada
		if is_dam_opened:
			return "res://assets/combat/bg/bg_combat_grassland.png"
		else:
			return "res://assets/combat/bg/bg_combat_swamp.png"
	elif terrain in ["mnt", "mountain", "rock", "cliff"]:
		return "res://assets/combat/bg/bg_combat_mountain.png"
	elif terrain in ["for", "forest", "wood", "jungle"]:
		return "res://assets/combat/bg/bg_combat_forest.png"
	elif terrain in ["void", "cor", "pol"]:
		# Vacío cósmico / corrupción / contaminación
		return "res://assets/combat/bg/bg_combat_void.png"
	elif terrain in ["pth", "cst"]:
		# Caminos de piedra / adoquines
		if "nieve" in zone or "snow" in zone:
			return "res://assets/combat/bg/bg_combat_snow.png"
		elif "desierto" in zone or "gloriam" in zone:
			return "res://assets/combat/bg/bg_combat_desert.png"
		elif "yelmo" in zone:
			return "res://assets/combat/bg/bg_combat_grassland.png" if is_dam_opened else "res://assets/combat/bg/bg_combat_swamp.png"
		elif "arcanum" in zone:
			return "res://assets/combat/bg/bg_combat_void.png"
		else:
			return "res://assets/combat/bg/bg_combat_grassland.png"
	elif terrain in ["gnd"]:
		# Tierra fértil / huerto / fango
		if "yelmo" in zone:
			return "res://assets/combat/bg/bg_combat_grassland.png" if is_dam_opened else "res://assets/combat/bg/bg_combat_swamp.png"
		elif "arcanum" in zone:
			return "res://assets/combat/bg/bg_combat_void.png"
		elif "desierto" in zone or "gloriam" in zone:
			return "res://assets/combat/bg/bg_combat_desert.png"
		else:
			return "res://assets/combat/bg/bg_combat_grassland.png"
	elif terrain in ["grs"]:
		# Pradera / hierba
		if "sylphrena" in zone:
			return "res://assets/combat/bg/bg_combat_forest.png"
		else:
			return "res://assets/combat/bg/bg_combat_grassland.png"

	# 2.2 Si el terreno no coincidió, inferir por ZONA del mapa
	if "nieve" in zone or "snow" in zone:
		return "res://assets/combat/bg/bg_combat_snow.png"
	elif "desierto" in zone or "gloriam" in zone:
		return "res://assets/combat/bg/bg_combat_desert.png"
	elif "yelmo" in zone:
		return "res://assets/combat/bg/bg_combat_grassland.png" if is_dam_opened else "res://assets/combat/bg/bg_combat_swamp.png"
	elif "sylphrena" in zone:
		return "res://assets/combat/bg/bg_combat_forest.png"
	elif "celestia" in zone:
		return "res://assets/combat/bg/bg_combat_grassland.png"
	elif "arcanum" in zone:
		return "res://assets/combat/bg/bg_combat_void.png"
	elif "final" in zone or "epilogo" in zone or "secreta" in zone:
		return "res://assets/combat/bg/bg_combat_void.png"
	else:
		return "res://assets/combat/bg/bg_combat_grassland.png"


## Resuelve la plataforma de combate según el contexto y el fondo seleccionado.
func _resolve_combat_platform_path(enemy: Dictionary, bg_path: String) -> String:
	var bg_lower := bg_path.to_lower()
	var terrain: String = String(enemy.get("world_terrain", "")).to_lower()
	var is_dam_opened: bool = GlobalState.has_world_flag("dam_opened") or GlobalState.dam_opened

	# 1. Plataformas de mazmorra
	if "dungeon_snow" in bg_lower:
		return "res://assets/combat/platform/plat_combat_dungeon_ice.png"
	elif "dungeon_desert" in bg_lower:
		return "res://assets/combat/platform/plat_combat_dungeon_sand.png"
	elif "dungeon_lab" in bg_lower:
		return "res://assets/combat/platform/plat_combat_dungeon_lab.png"
	elif "dungeon_temple" in bg_lower or "sanctuary" in bg_lower:
		return "res://assets/combat/platform/plat_combat_dungeon_temple.png"
	elif "dungeon_crystal" in bg_lower:
		return "res://assets/combat/platform/plat_combat_dungeon_crystal.png"
	elif "dungeon_chrono" in bg_lower:
		return "res://assets/combat/platform/plat_combat_dungeon_chrono.png"
	elif "dungeon_magma" in bg_lower:
		return "res://assets/combat/platform/plat_combat_volcano.png"
	elif "dungeon_cave" in bg_lower or "fortress" in bg_lower:
		return "res://assets/combat/platform/plat_combat_dungeon_stone.png"

	# 2. Plataformas de mapamundi por terreno exacto
	if terrain in ["pth", "cst"]:
		return "res://assets/combat/platform/plat_combat_dungeon_stone.png"
	elif terrain in ["pol", "void", "cor"]:
		return "res://assets/combat/platform/plat_combat_void.png"
	elif terrain in ["bad"]:
		return "res://assets/combat/platform/plat_combat_grassland.png" if is_dam_opened else "res://assets/combat/platform/plat_combat_swamp.png"
	elif terrain in ["swp", "swamp"]:
		return "res://assets/combat/platform/plat_combat_swamp.png"
	elif terrain in ["lav", "magma", "volcano"]:
		return "res://assets/combat/platform/plat_combat_volcano.png"
	elif terrain in ["ice", "snw", "snow", "icy"]:
		return "res://assets/combat/platform/plat_combat_snow.png"
	elif terrain in ["des", "snd", "are", "sand", "desert"]:
		return "res://assets/combat/platform/plat_combat_desert.png"
	elif terrain in ["for", "forest", "wood"]:
		return "res://assets/combat/platform/plat_combat_forest.png"
	elif terrain in ["gnd", "grs"]:
		return "res://assets/combat/platform/plat_combat_grassland.png"
	elif terrain in ["mnt", "mountain", "rock"]:
		return "res://assets/combat/platform/plat_combat_rock.png"

	# 3. Plataformas por fondo si no hay terreno específico
	if "snow" in bg_lower:
		return "res://assets/combat/platform/plat_combat_snow.png"
	elif "desert" in bg_lower:
		return "res://assets/combat/platform/plat_combat_desert.png"
	elif "forest" in bg_lower:
		return "res://assets/combat/platform/plat_combat_forest.png"
	elif "swamp" in bg_lower:
		return "res://assets/combat/platform/plat_combat_swamp.png"
	elif "volcano" in bg_lower:
		return "res://assets/combat/platform/plat_combat_volcano.png"
	elif "void" in bg_lower:
		return "res://assets/combat/platform/plat_combat_void.png"
	elif "mountain" in bg_lower:
		return "res://assets/combat/platform/plat_combat_rock.png"
	else:
		return "res://assets/combat/platform/plat_combat_grassland.png"


## Fallback a plataformas conservadas temporalmente (plat_forest.png y plat_rock.png)
func _get_legacy_fallback_platform(plat_path: String, bg_path: String, _enemy: Dictionary) -> Texture2D:
	var path_lower: String = (plat_path + " " + bg_path).to_lower()
	if "forest" in path_lower or "grass" in path_lower or "swamp" in path_lower or "overgrown" in path_lower:
		var tex := UiKit.load_texture_safe("res://assets/combat/platform/plat_forest.png")
		if tex != null:
			return tex
	return UiKit.load_texture_safe("res://assets/combat/platform/plat_rock.png")


func _element_icon(element: String) -> String:
	return String(GameConfig.ELEMENTS.get(element, {}).get("icon", ""))


func _icons_for(elements: Array) -> String:
	var out: Array = []
	for e in elements:
		out.append(_element_icon(String(e)))
	return " ".join(out)


func _enemy_info_text() -> String:
	var parts: Array = []
	parts.append("%s %s" % [Locale.t("combat_info_type"), _element_icon(String(enemy_data.get("element", "physical")))])
	var weak: Array = enemy_data.get("weak_to", [])
	if not weak.is_empty():
		parts.append("%s %s" % [Locale.t("combat_info_weak"), _icons_for(weak)])
	var res: Array = enemy_data.get("resist", [])
	if not res.is_empty():
		parts.append("%s %s" % [Locale.t("combat_info_resist"), _icons_for(res)])
	parts.append("%s %d/%d" % [Locale.t("combat_info_def"), int(enemy_data.get("phys_defense", 0)), int(enemy_data.get("mag_defense", 0))])
	var dim := _theme_color("text_dim", Color(0.58, 0.64, 0.72))
	return "[color=#%s]" % dim.to_html() + "   ·   ".join(parts) + "[/color]"


func _skill_type_color(type: String) -> Color:
	match type:
		"magic":    return Color(0.12, 0.40, 0.8) # Magic blue
		"physical": return Color(0.55, 0.45, 0.25) # Physical gold/bronze
		"ranged":   return Color(0.1, 0.55, 0.3) # Ranged green
		"heal":     return Color(0.15, 0.48, 0.2) # Heal green
		"defense":  return Color(0.18, 0.25, 0.45) # Defense steel blue
		"buff":     return Color(0.35, 0.22, 0.45) # Purple
		_:          return Color(0.2, 0.18, 0.24)


func _format_drops(drops: Array) -> String:
	var parts: Array = []
	for d in drops:
		var q: int = int(d.get("qty", 1))
		if String(d.get("kind", "")) == "gold":
			parts.append("%s%d" % [String(d.get("icon", "🪙")), q])
		elif q > 1:
			parts.append("%s%s x%d" % [String(d.get("icon", "")), String(d.get("name", "")), q])
		else:
			parts.append("%s%s" % [String(d.get("icon", "")), String(d.get("name", ""))])
	return ", ".join(parts)


func _update_defense_ring_geometry() -> void:
	var prof: Dictionary = _block_profile
	var normal_tol: float = float(prof.get("normal_window", 0.45)) * ENEMY_DISCHARGE_RATE
	var perfect_tol: float = float(prof.get("perfect_window", 0.22)) * ENEMY_DISCHARGE_RATE
	_ring_normal_radius = _atb_diff_to_ring_radius(normal_tol)
	_ring_perfect_radius = _atb_diff_to_ring_radius(perfect_tol) if perfect_tol > 0.0 else _ring_target_radius


func _align_enemy_and_platform() -> void:
	if _enemy_img_rect == null or _enemy_platform == null or _enemy_sprite_container == null:
		return
	var enemy_tex := _enemy_img_rect.texture
	if enemy_tex == null:
		return

	# Esperar un frame si el tamaño del contenedor no ha sido calculado (p. ej., al instanciar)
	if _enemy_sprite_container.size.x == 0:
		await get_tree().process_frame
		if not is_instance_valid(_enemy_sprite_container):
			return

	var container_size := _enemy_sprite_container.size
	if container_size.x == 0:
		container_size = Vector2(800, 450) # Fallback seguro

	var is_landscape := container_size.x > container_size.y
	var center_x := container_size.x * (0.43 if is_landscape else 0.50)
	var header_height := 112.0 # Espacio superior para nombre, barras de vida y ATB ensanchadas

	# 1. Base de la plataforma: situada abajo en el escenario (97% del alto)
	var plat_base_y := container_size.y * (0.97 if is_landscape else 0.92)
	var tex_size := enemy_tex.get_size()
	var aspect := tex_size.x / maxf(tex_size.y, 1.0)
	var visual_scale := float(enemy_data.get("visual_scale", 1.0))

	# 2. Estimación de plataforma y superficie de pisada exacta sobre la hierba (53% de la altura de peana)
	var plat_w := clampf(container_size.x * (0.86 if is_landscape else 0.90), 340.0, 720.0)
	var plat_h := plat_w * 0.45
	var plat_left := center_x - (plat_w * 0.5)
	var plat_top := plat_base_y - plat_h
	var surface_y := plat_top + (plat_h * 0.53)

	# 3. Sprite del enemigo apoyado exactamente sobre la superficie de la peana
	var available_h := surface_y - header_height - 6.0
	var enemy_h := available_h * 0.98 * visual_scale
	var enemy_w := enemy_h * aspect

	# Limitar el ancho si superara el contenedor horizontalmente
	var max_enemy_w := container_size.x * (0.85 if is_landscape else 0.88)
	if enemy_w > max_enemy_w:
		enemy_w = max_enemy_w
		enemy_h = enemy_w / aspect

	# Ajustar el ancho de la plataforma al tamaño del enemigo agrandado
	plat_w = clampf(maxf(enemy_w * 1.25, container_size.x * 0.80), 340.0, container_size.x * 0.96)
	plat_h = plat_w * 0.45
	plat_left = center_x - (plat_w * 0.5)
	plat_top = plat_base_y - plat_h
	surface_y = plat_top + (plat_h * 0.53)

	var enemy_bottom := surface_y
	var enemy_top := enemy_bottom - enemy_h
	var enemy_left := center_x - (enemy_w * 0.5)

	# Salvaguarda: no tapar la cabecera
	if enemy_top < header_height:
		var overlap := header_height - enemy_top
		enemy_h -= overlap
		enemy_w = enemy_h * aspect
		enemy_top = header_height
		enemy_left = center_x - (enemy_w * 0.5)

	# 4. Asignar posiciones y tamaños exactos a la plataforma y al enemigo
	_enemy_platform.anchor_left = 0.0
	_enemy_platform.anchor_top = 0.0
	_enemy_platform.anchor_right = 0.0
	_enemy_platform.anchor_bottom = 0.0
	_enemy_platform.offset_left = plat_left
	_enemy_platform.offset_top = plat_top
	_enemy_platform.offset_right = plat_left + plat_w
	_enemy_platform.offset_bottom = plat_top + plat_h

	_enemy_img_rect.anchor_left = 0.0
	_enemy_img_rect.anchor_top = 0.0
	_enemy_img_rect.anchor_right = 0.0
	_enemy_img_rect.anchor_bottom = 0.0
	_enemy_img_rect.offset_left = enemy_left
	_enemy_img_rect.offset_top = enemy_top
	_enemy_img_rect.offset_right = enemy_left + enemy_w
	_enemy_img_rect.offset_bottom = enemy_bottom

	_enemy_sprite_base_y = enemy_top

	# 5. Panel de estado centrado arriba (580px de ancho)
	if _enemy_panel != null:
		_enemy_panel.anchor_left = 0.0
		_enemy_panel.anchor_top = 0.0
		_enemy_panel.anchor_right = 0.0
		_enemy_panel.anchor_bottom = 0.0
		_enemy_panel.offset_left = center_x - 290.0
		_enemy_panel.offset_top = 0.0
		_enemy_panel.offset_right = center_x + 290.0
		_enemy_panel.offset_bottom = 102.0


#endregion
