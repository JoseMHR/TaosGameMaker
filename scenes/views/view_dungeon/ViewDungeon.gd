# ViewDungeon.gd
# ─────────────────────────────────────────────────────────────────────────────
# CONTROLADOR DE EXPLORACIÓN DE MAZMORRA EN 3D (Primera Persona)
#
# Instancia el escenario 3D y el jugador. Controla el movimiento en primera persona
# (teclado + controles táctiles), gestiona el inicio de combates por proximidad de enemigos
# y la salida mediante portales o botones.
# ─────────────────────────────────────────────────────────────────────────────
class_name ViewDungeon
extends Control

# Constantes de escenas y scripts
const PLAYER_SCENE: PackedScene = preload("res://scenes/views/view_dungeon/components/DungeonPlayer.tscn")
const GRID_STAGE_SCRIPT := preload("res://scenes/views/view_dungeon/components/GridDungeonStage.gd")
const EXPLORATION_HUD_SCRIPT := preload("res://scenes/views/view_dungeon/interaction/hud/ExplorationHud.gd")
const DUNGEON_MINIMAP_SCRIPT := preload("res://scenes/views/view_dungeon/components/DungeonMinimap.gd")

# ─── REFERENCIAS UI ──────────────────────────────────────────────────────────
@onready var lbl_dungeon_name: Label = $VBox/Header/MarginHeader/HBoxH/LblDungeonName
@onready var btn_leave: Button = $VBox/Header/MarginHeader/HBoxH/BtnLeave
@onready var viewport_container: SubViewportContainer = $VBox/ViewportContainer
@onready var sub_viewport: SubViewport = $VBox/ViewportContainer/SubViewport

# ─── ESTADO ──────────────────────────────────────────────────────────────────
var _cell_data: Dictionary = {}
var _dungeon: Dictionary = {} # layout data-driven de la mazmorra actual (data/dungeons/<id>.json)
var _is_active: bool = false
var _dungeon_id: String:
	get:
		return str(_cell_data.get("event_id", _dungeon.get("id", "")))

# Instancias 3D
var _stage_instance: Node3D = null
var _player_instance: CharacterBody3D = null
var _current_enemy_node: Node = null
## Momento (ms) hasta el que se ignoran los teletransportes, para no re-disparar al
## aterrizar cerca del pad de destino.
var _tp_cooldown_until: int = 0

# Feedback de peligros (viñeta de daño + tinte de agua). Se crean por código.
var _hazard_overlay: ColorRect = null
var _damage_tween: Tween = null

# Texturas de enemigos por enemy_id (para pintar el sprite billboard sea cual sea
# el layout de la mazmorra). Si un id no está aquí, se respeta el sprite de la escena.
const ENEMY_TEXTURES: Dictionary = {
	"sombra_oscura": "res://assets/combat/enemies/en_dark_shadow.png",
	"robot_mecanico": "res://assets/combat/enemies/en_sentinel_robot.png",
	"goblin_explorador": "res://assets/combat/enemies/en_goblin_scout.png",
	"orco_berserker": "res://assets/combat/enemies/en_orc_berserker.png",
	"lobo": "res://assets/combat/enemies/en_wolf.png",
	"lobo_alfa": "res://assets/combat/enemies/en_wolf.png",
	"murcielago": "res://assets/combat/enemies/en_dark_shadow.png",
	"limo_verde": "res://assets/combat/enemies/en_slime.png",
	"arania_cueva": "res://assets/combat/enemies/en_dark_shadow.png",
	# Sala de Tests / plantillas del editor — Maniquíes de Prueba
	"test_dummy_weak": "res://assets/combat/enemies/en_default.png",
	"test_dummy_boss": "res://assets/combat/enemies/en_sentinel_robot.png",
	# Jefes de templo (Senderos de profesión). Reutilizan sprites existentes hasta
	# disponer de arte propio (el fichero se puede sustituir conservando el nombre).
	"temple_boss_warrior": "res://assets/combat/enemies/en_stone_colossus.png",
	"temple_boss_time": "res://assets/combat/enemies/en_chronophage.png",
	"temple_boss_archer": "res://assets/combat/enemies/en_tempest_harpy.png",
	"temple_boss_psychic": "res://assets/combat/enemies/en_ethereal_void.png",
	"temple_boss_elemental": "res://assets/combat/enemies/en_unstable_core.png",
	"temple_boss_healer": "res://assets/combat/enemies/en_eternal_lich.png",
}

# Joysticks virtuales (izquierdo = movimiento, derecho = cámara)
const JOY_RADIUS: float = 120.0 # Radio de los joysticks virtuales (px)
var _joy_area: Control

# Joystick Izquierdo (Movimiento)
var _left_joy_base: Panel
var _left_joy_knob: Panel
var _left_joy_active: bool = false
var _left_joy_index: int = -1 # índice del toque activo (-2 = ratón)
var _left_joy_center: Vector2 = Vector2.ZERO
var _left_joy_vec: Vector2 = Vector2.ZERO

# Joystick Derecho (Cámara)
var _right_joy_base: Panel
var _right_joy_knob: Panel
var _right_joy_active: bool = false
var _right_joy_index: int = -1 # índice del toque activo (-2 = ratón)
var _right_joy_center: Vector2 = Vector2.ZERO
var _right_joy_vec: Vector2 = Vector2.ZERO

# ─── EFECTO DE PANTALLA: VIÑETA DE TIEMPO RALENTIZADO ─────────────────────────
# Viñeta verde de "Distorsión Temporal": la muestra/oculta _on_time_slow_changed
# según el toggle del ExplorationSkillController.
var _time_vignette: Panel = null
var _time_vignette_tween: Tween = null
var _time_slow_shown: bool = false

# HUD de exploración (anillo hexagonal de 6 habilidades). Reemplaza al cluster de
# almas Q/R/F; se cablea al ExplorationSkillController del jugador en setup().
var _hud: ExplorationHud = null

# Minimapa de orientación (Game Feel): radar con niebla de guerra centrado en
# el jugador, esquina superior derecha. Ver DungeonMinimap.gd.
var _minimap: DungeonMinimap = null
## Botón de acceso directo al menú del personaje (esquina superior derecha,
## debajo del minimapa). Llama a SceneManager.switch_tab("character").
var _dungeon_menu_btn: Button = null
## Planta actual del jugador (índice en `_dungeon.floors`), para saber qué
## `cells` pasarle al minimapa al entrar o cambiar de planta (escaleras).
var _current_floor: int = 0
var _last_combat_was_boss: bool = false

## Configuración de los bocadillos de tutorial de dun_inicial: kit de celda →
## habilidad a resaltar + mensaje de la esfera. Se dispara la primera vez que
## el jugador se acerca a cada kit en la planta superior.
const _TUTORIAL_KIT_BARKS: Dictionary = {
	"break_barrier": {
		"skill": "kinetic_wave",
		"text": {
			"es": "¡Corre! Usa tu habilidad Onda Cinética para destruirlo.",
			"en": "Run! Use your Kinetic Wave skill to destroy it.",
			"fr": "Cours ! Utilise ton Onde Cinétique pour le détruire.",
			"it": "Corri! Usa la tua Onda Cinetica per distruggerlo.",
			"de": "Renn! Nutze deine Kinetische Welle, um es zu zerstören.",
			"zh": "快跑！使用动能波技能摧毁它。",
			"ja": "走れ！キネティックウェーブの技を使って破壊しろ。"
		},
		"dist": 2
	},
	"grab_column": {
		"skill": "psychic_grab",
		"text": {
			"es": "¡Genial! Ahora usa Agarre Psíquico para alcanzar aquella columna.",
			"en": "Great! Now use Psychic Grab to reach that column.",
			"fr": "Génial ! Maintenant, utilise la Poigne Psychique pour atteindre cette colonne.",
			"it": "Ottimo! Ora usa la Presa Psichica per raggiungere quella colonna.",
			"de": "Großartig! Nutze nun den Psychischen Griff, um jene Säule zu erreichen.",
			"zh": "太棒了！现在使用念力抓取抓住那根柱子。",
			"ja": "上出来だ！次はサイキックグラブを使ってあの柱を掴め。"
		},
		"dist": 2
	},
	"reveal_floor": {
		"skill": "explorer_instinct",
		"text": {
			"es": "¡Espera, insensato! ¿No ves que hay suelo invisible? Usa Instinto de Explorador.",
			"en": "Wait, you fool! Don't you see there's an invisible floor? Use Explorer's Instinct.",
			"fr": "Attends, insensé ! Tu ne vois pas qu'il y a un sol invisible ? Utilise l'Instinct d'Explorateur.",
			"it": "Aspetta, incauto! Non vedi che c'è un pavimento invisibile? Usa l'Istinto dell'Esploratore.",
			"de": "Warte, Tor! Siehst du nicht, dass dort ein unsichtbarer Boden ist? Nutze den Entdeckerinstinkt.",
			"zh": "等等，冒失鬼！你没看到那里有隐形地面吗？使用探索者本能。",
			"ja": "待て、慌てるな！見えない床があるのが分からないのか？探検家の直感を使え。"
		},
		"dist": 2
	},
	"purify_poison_water": {
		"skill": "restoration",
		"text": {
			"es": "¡No toques esa agua! Está envenenada; usa Purificación.",
			"en": "Don't touch that water! It's poisoned; use Purification.",
			"fr": "Ne touche pas à cette eau ! Elle est empoisonnée ; utilise Purification.",
			"it": "Non toccare quell'acqua! È avvelenata; usa Purificazione.",
			"de": "Fass das Wasser nicht an! Es ist vergiftet; nutze Reinigung.",
			"zh": "别碰那水！有毒，使用净化。",
			"ja": "その水に触れるな！毒が入っている。浄化を使え。"
		},
		"dist": 2
	},
	"elem_roots": {
		"skill": "elemental_affinity",
		"text": {
			"es": "No puedes cruzar esas raíces. ¡Quémalas! Usa tu Afinidad Elemental para absorber el fuego y lanzarlo.",
			"en": "You can't cross those roots. Burn them! Use your Elemental Affinity to absorb fire and cast it.",
			"fr": "Tu ne peux pas traverser ces racines. Brûle-les ! Utilise ton Affinité Élémentaire pour absorber le feu et le projeter.",
			"it": "Non puoi attraversare quelle radici. Bruciale! Usa la tua Affinità Elementale per assorbire il fuoco e scagliarlo.",
			"de": "Du kannst diese Wurzeln nicht passieren. Verbrenne sie! Nutze deine Elementare Affinität, um Feuer aufzunehmen und zu schleudern.",
			"zh": "你穿不过这些树根。烧掉它们！使用你的元素亲和吸收火焰并释放出来。",
			"ja": "その根は通れない。焼き払え！属性親和を使って炎を吸収し、放つんだ。"
		},
		"dist": 2
	},
}
const _TUTORIAL_HIGHLIGHT_DURATION: float = 6.0
var _tutorial_kits_seen: Dictionary = {}

# ─── MAZMORRA DE NIEVE (dun_nieves): niebla cegadora y desorientación ────────
var _is_snow_dungeon: bool = false
var _snow_walls_coords: Array[Vector2i] = []
var _dungeon_entry_spawn_pos: Vector3 = Vector3.ZERO
var _dungeon_entry_floor: int = 0
var _snow_lost_in_progress: bool = false
var _snow_lost_cooldown: float = 0.0
var _snow_mist_overlay: ColorRect = null
var _snow_sound_player: AudioStreamPlayer = null


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA Y PROCESO
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	if not Locale.locale_changed.is_connected(_refresh_chrome):
		Locale.locale_changed.connect(_refresh_chrome)
	_refresh_chrome()
	if btn_leave != null and not btn_leave.pressed.is_connected(_on_btn_leave_pressed):
		btn_leave.pressed.connect(_on_btn_leave_pressed)
	_build_joystick()
	_build_hazard_overlay()
	_build_snow_mist_overlay()
	_build_skill_effects()
	_build_exploration_hud()
	_build_minimap()
	add_to_group("view_dungeon")
	if not resized.is_connected(_update_responsive_layout):
		resized.connect(_update_responsive_layout)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_update_responsive_layout):
		vp.size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	# OPTIMIZACIÓN MÓVIL: el SubViewport 3D está en UPDATE_ALWAYS, así que sin esto
	# seguiría renderizando la mazmorra CADA frame aunque esté oculta detrás del
	# combate/menús (gasto de GPU inútil). Mismo patrón que TabWorld3D: al ocultarse
	# pasa a UPDATE_DISABLED (0 GPU) y al mostrarse vuelve a UPDATE_ALWAYS.
	if not visibility_changed.is_connected(_on_dungeon_visibility_changed):
		visibility_changed.connect(_on_dungeon_visibility_changed)
	_on_dungeon_visibility_changed()


## Pausa el render del SubViewport de la mazmorra cuando la vista no es visible
## (combate encima, menús, mapamundi) y lo reanuda al volver a mostrarse.
func _on_dungeon_visibility_changed() -> void:
	if sub_viewport == null or not is_instance_valid(sub_viewport):
		return
	if is_visible_in_tree():
		if viewport_container != null and (viewport_container.size.x <= 0.0 or viewport_container.size.y <= 0.0):
			sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			call_deferred("_enable_subviewport_when_ready")
		else:
			sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _enable_subviewport_when_ready() -> void:
	if is_instance_valid(sub_viewport) and is_visible_in_tree():
		if viewport_container != null and viewport_container.size.x > 0.0 and viewport_container.size.y > 0.0:
			sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func get_dungeon_name() -> String:
	# 1. Definición del layout de la mazmorra (_dungeon["name"])
	if _dungeon is Dictionary and _dungeon.has("name"):
		var dun_nm = _dungeon["name"]
		if dun_nm is Dictionary and not (dun_nm as Dictionary).is_empty():
			return Locale.pick(dun_nm)
		elif str(dun_nm) != "" and str(dun_nm) != "Mazmorra":
			var tr_dun := Locale.translate_cell_name(str(dun_nm))
			if tr_dun != str(dun_nm):
				return tr_dun
	# 2. Definición del objeto en data/ids (Design.ids)
	var event_id: String = str(_cell_data.get("event_id", _dungeon.get("id", "")))
	if event_id != "":
		var meta: Dictionary = Design.get_id(event_id)
		if meta is Dictionary and meta.has("name"):
			var meta_nm = meta["name"]
			if meta_nm is Dictionary and not (meta_nm as Dictionary).is_empty():
				return Locale.pick(meta_nm)
			elif str(meta_nm) != "":
				var tr_meta := Locale.translate_cell_name(str(meta_nm))
				if tr_meta != str(meta_nm):
					return tr_meta
	# 3. Diccionario name_i18n de la celda de origen
	var name_i18n = _cell_data.get("name_i18n", null)
	if name_i18n is Dictionary and not (name_i18n as Dictionary).is_empty():
		return Locale.pick(name_i18n)
	# 4. Nombre directo en cell_data
	var raw_name = _cell_data.get("name", null)
	if raw_name is Dictionary and not (raw_name as Dictionary).is_empty():
		return Locale.pick(raw_name)
	elif raw_name != null and str(raw_name) != "" and str(raw_name) != "Mazmorra":
		return Locale.translate_cell_name(str(raw_name))
	# 5. Primera planta de la mazmorra
	if _dungeon is Dictionary and _dungeon.has("floors") and _dungeon["floors"].size() > 0:
		var fl0 = _dungeon["floors"][0]
		if fl0 is Dictionary and fl0.has("name"):
			var fl_nm = fl0["name"]
			if fl_nm is Dictionary:
				return Locale.pick(fl_nm)
			elif str(fl_nm) != "":
				return Locale.translate_cell_name(str(fl_nm))
	return Locale.t("loc_dungeon")


func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var is_landscape := sz.x > sz.y
	var header_node: Control = get_node_or_null("VBox/Header") as Control
	if header_node != null:
		header_node.visible = not is_landscape
	_reposition_minimap(sz)
	if is_visible_in_tree() and viewport_container != null and viewport_container.size.x > 0.0 and viewport_container.size.y > 0.0:
		if sub_viewport != null and is_instance_valid(sub_viewport):
			sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Recoloca el minimapa a partir del tamaño REAL del viewport (`get_viewport_rect()`,
## el mismo usado ya arriba para el resto del layout responsive), en vez de
## dejarlo fijado de una sola vez con `set_anchors_and_offsets_preset()` al
## crearlo (en ciertas resoluciones/orientaciones
## quedaba mal calculado y el recuadro terminaba mayormente fuera de la
## pantalla, con solo el borde asomando). Se recalcula en cada resize, igual
## que ya hace `ExplorationHud._layout()`.
func _reposition_minimap(viewport_size: Vector2) -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud._layout()
	if _minimap == null or not is_instance_valid(_minimap):
		return
	# Si el minimapa está integrado en top_right_container del HUD, no necesita cálculo manual
	if _minimap.get_parent() != null and _minimap.get_parent() != $MobileControls:
		return
	const MARGIN := 16.0
	var msize: Vector2 = _minimap.size if _minimap.size.x > 0.0 else _minimap.custom_minimum_size
	_minimap.position = Vector2(viewport_size.x - msize.x - MARGIN, MARGIN)
	# Botón de menú: pegado al margen derecho debajo del minimapa, con 12 px de separación.
	if _dungeon_menu_btn != null and is_instance_valid(_dungeon_menu_btn) and _dungeon_menu_btn.get_parent() == $MobileControls:
		var bsize := _dungeon_menu_btn.custom_minimum_size
		var btn_x := viewport_size.x - bsize.x - MARGIN
		_dungeon_menu_btn.position = Vector2(btn_x, _minimap.position.y + msize.y + 12.0)


## Capa de color a pantalla completa para el feedback de peligros: rojo al recibir
## daño (pulso) y azul tenue mientras estás en el agua. No captura toques.
func _build_hazard_overlay() -> void:
	_hazard_overlay = ColorRect.new()
	_hazard_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hazard_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hazard_overlay.color = Color(0.8, 0.05, 0.05, 0.0)
	add_child(_hazard_overlay)


## Capa difuminada blanca y reproductor de sonido de ventisca para dun_nieves.
func _build_snow_mist_overlay() -> void:
	if _snow_mist_overlay == null:
		_snow_mist_overlay = ColorRect.new()
		_snow_mist_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_snow_mist_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_snow_mist_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
		_snow_mist_overlay.z_index = 50
		add_child(_snow_mist_overlay)

	if _snow_sound_player == null:
		_snow_sound_player = AudioStreamPlayer.new()
		_snow_sound_player.bus = "Master"
		var snow_sfx = load("res://assets/common/sfx/sfx_ambient_wind_snow_loop.ogg")
		if snow_sfx != null:
			_snow_sound_player.stream = snow_sfx
		add_child(_snow_sound_player)


## Instancia el HUD de exploración y lo añade a la capa de controles móviles.
func _build_exploration_hud() -> void:
	_hud = EXPLORATION_HUD_SCRIPT.new()
	$MobileControls.add_child(_hud)


## Instancia el minimapa (radar de niebla de guerra) en la esquina superior
## derecha, por encima del joystick/HUD de habilidades (que viven a la
## izquierda/centro), para que nunca se solapen.
func _build_minimap() -> void:
	_minimap = DUNGEON_MINIMAP_SCRIPT.new()
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("add_minimap"):
		_hud.add_minimap(_minimap)
		_dungeon_menu_btn = _hud.btn_menu
	else:
		$MobileControls.add_child(_minimap)
		# Fallback: botón de menú de personaje en $MobileControls
		_dungeon_menu_btn = Button.new()
		_dungeon_menu_btn.text = ""
		_dungeon_menu_btn.tooltip_text = "Menú de personaje"
		_dungeon_menu_btn.custom_minimum_size = Vector2(64.0, 64.0)
		_dungeon_menu_btn.draw.connect(_draw_dungeon_menu_hamburger)
		var btn_sb := StyleBoxFlat.new()
		btn_sb.bg_color = Color(0.08, 0.06, 0.12, 0.88)
		btn_sb.set_corner_radius_all(10)
		btn_sb.set_border_width_all(2)
		btn_sb.border_color = Color(0.55, 0.35, 0.9, 0.7)
		btn_sb.content_margin_left = 12
		btn_sb.content_margin_right = 12
		btn_sb.content_margin_top = 8
		btn_sb.content_margin_bottom = 8
		_dungeon_menu_btn.add_theme_stylebox_override("normal", btn_sb)
		var btn_sb_hover := btn_sb.duplicate() as StyleBoxFlat
		btn_sb_hover.bg_color = Color(0.18, 0.12, 0.28, 0.95)
		btn_sb_hover.border_color = Color(0.75, 0.55, 1.0, 0.95)
		_dungeon_menu_btn.add_theme_stylebox_override("hover", btn_sb_hover)
		var btn_sb_press := btn_sb.duplicate() as StyleBoxFlat
		btn_sb_press.bg_color = Color(0.30, 0.18, 0.48, 1.0)
		_dungeon_menu_btn.add_theme_stylebox_override("pressed", btn_sb_press)
		_dungeon_menu_btn.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
		_dungeon_menu_btn.add_theme_font_size_override("font_size", 30)
		_dungeon_menu_btn.pressed.connect(func() -> void:
			var root: Node = get_tree().get_first_node_in_group("game_root")
			if root != null and root.has_method("open_hub_modal_tab"):
				root.open_hub_modal_tab("character")
			else:
				SceneManager.switch_tab("character")
		)
		$MobileControls.add_child(_dungeon_menu_btn)

	_reposition_minimap(get_viewport_rect().size)


func _draw_dungeon_menu_hamburger() -> void:
	if _dungeon_menu_btn == null or not is_instance_valid(_dungeon_menu_btn):
		return
	var sz := _dungeon_menu_btn.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var line_w: float = roundf(sz.x * 0.44)
	var line_h: float = maxf(2.5, roundf(sz.y * 0.055))
	var start_x: float = roundf((sz.x - line_w) * 0.5)
	var center_y: float = roundf(sz.y * 0.5)
	var spacing: float = roundf(sz.y * 0.16)
	var col := Color(0.85, 0.65, 1.0)
	_dungeon_menu_btn.draw_rect(Rect2(start_x, center_y - spacing - line_h * 0.5, line_w, line_h), col, true)
	_dungeon_menu_btn.draw_rect(Rect2(start_x, center_y - line_h * 0.5, line_w, line_h), col, true)
	_dungeon_menu_btn.draw_rect(Rect2(start_x, center_y + spacing - line_h * 0.5, line_w, line_h), col, true)


## Pasa al minimapa las celdas de la planta `floor_idx` (reinicia su niebla de
## guerra: cada planta se explora de cero). No-op si el minimapa no llegó a
## instanciarse o la planta no existe.
func _setup_minimap_floor(floor_idx: int) -> void:
	if _minimap == null:
		return
	var floors: Array = _dungeon.get("floors", [])
	if floor_idx < 0 or floor_idx >= floors.size():
		return
	var cells: Array = (floors[floor_idx] as Dictionary).get("cells", [])
	if _minimap.has_method("set_boss_defeated"):
		_minimap.call("set_boss_defeated", GlobalState.is_boss_defeated(_boss_key()))
	_minimap.set_floor_data(cells, float(_dungeon.get("cell_size", 3.0)))


# ══════════════════════════════════════════════════════════════════════════════
# HABILIDADES: EFECTO DE PANTALLA (viñeta de tiempo). El HUD hexagonal vive en
# ExplorationHud; el input de habilidades lo gestiona el ExplorationSkillController.
# ══════════════════════════════════════════════════════════════════════════════

## Efecto a pantalla completa: viñeta verde de "tiempo ralentizado".
func _build_skill_effects() -> void:
	# Viñeta verde translúcida de "tiempo ralentizado" (borde fosforescente).
	_time_vignette = Panel.new()
	_time_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_time_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vig := StyleBoxFlat.new()
	vig.bg_color = Color(0.1, 1.0, 0.4, 0.0) # Centro transparente
	vig.border_color = Color(0.25, 1.0, 0.5, 0.9) # Borde verde fosforescente
	vig.set_border_width_all(26)
	vig.shadow_color = Color(0.2, 1.0, 0.45, 0.6)
	vig.shadow_size = 40
	_time_vignette.add_theme_stylebox_override("panel", vig)
	_time_vignette.visible = false
	add_child(_time_vignette)


func _on_time_slow_changed(active: bool) -> void:
	if _time_vignette == null:
		return
	if active == _time_slow_shown:
		return
	_time_slow_shown = active
	if _time_vignette_tween and _time_vignette_tween.is_valid():
		_time_vignette_tween.kill()
	if active:
		_time_vignette.visible = true
		_time_vignette.modulate.a = 0.15
		_time_vignette_tween = _time_vignette.create_tween().set_loops()
		_time_vignette_tween.tween_property(_time_vignette, "modulate:a", 0.25, 0.7).set_trans(Tween.TRANS_SINE)
		_time_vignette_tween.tween_property(_time_vignette, "modulate:a", 0.15, 0.7).set_trans(Tween.TRANS_SINE)
	else:
		_time_vignette.visible = false


func _process(delta: float) -> void:
	if not _is_active or _player_instance == null or not _player_instance.is_active:
		return
		
	# Asignar las direcciones de los joysticks virtuales (movimiento y cámara)
	_player_instance.touch_movement = _left_joy_vec
	_player_instance.touch_look = _right_joy_vec

	# Feedback de "tiempo ralentizado" según el toggle de la Distorsión Temporal.
	var ctrl = _player_instance.skill_controller()
	if ctrl != null:
		_on_time_slow_changed(ctrl.is_toggled("time_distort"))

	# Actualizar la planta actual según la posición 3D real (al subir rampas / escaleras)
	if _stage_instance != null:
		var cp: Dictionary = _stage_instance.cell_from_world(_player_instance.global_position)
		var pf: int = int(cp.get("f", _current_floor))
		var floors_arr: Array = _dungeon.get("floors", [])
		if pf != _current_floor and pf >= 0 and pf < floors_arr.size():
			_current_floor = pf
			_setup_minimap_floor(_current_floor)
			if _is_snow_dungeon:
				_cache_snow_walls()

	# Minimapa: posición + avance real del jugador (-basis.z, proyectado a XZ).
	if _minimap != null:
		var fwd3: Vector3 = - _player_instance.global_transform.basis.z
		_minimap.update_player(_player_instance.global_position, Vector2(fwd3.x, fwd3.z))
	
	# Tutorial de dun_inicial: pistas al acercarse a los kits de la planta superior.
	_update_tutorial_barks(delta)

	# Mecánica especial de dun_nieves: desorientación al alejarse > 5 casillas de una pared de nieve
	if _is_snow_dungeon and _is_active and not _snow_lost_in_progress:
		if _snow_lost_cooldown > 0.0:
			_snow_lost_cooldown -= delta
		else:
			_check_snow_dungeon_lost()


# ═══════════════════════════════════════════════════════════════════════════════
# TUTORIAL DE DUN_INICIAL: pistas de la Esfera al acercarse a cada obstáculo
# ═══════════════════════════════════════════════════════════════════════════════
## Revisa los kits de la planta actual en busca de los 5 obstáculos del prólogo.
## La primera vez que el jugador se acerca a uno, la Esfera suelta un bark con
## la pista y el botón de la habilidad correspondiente brilla intensamente.
func _update_tutorial_barks(_delta: float) -> void:
	if _stage_instance == null or _player_instance == null or _dungeon.is_empty():
		return
	if str(_cell_data.get("event_id", "")) != "dun_inicial":
		return
	if GlobalState.has_world_flag("dun_inicial_skills_forgotten"):
		return

	var floors: Array = _dungeon.get("floors", [])
	if _current_floor < 0 or _current_floor >= floors.size():
		return
	var floor_def: Dictionary = floors[_current_floor]
	var cells: Array = floor_def.get("cells", [])
	if cells.is_empty():
		return
	var h: int = cells.size()
	var w: int = (cells[0] as Array).size() if cells[0] is Array else 0

	var cell_pos: Dictionary = _stage_instance.cell_from_world(_player_instance.global_position)
	if cell_pos.get("f", 0) != _current_floor:
		return
	var px: int = cell_pos["x"]
	var py: int = cell_pos["y"]

	for kit_key in _TUTORIAL_KIT_BARKS.keys():
		if _tutorial_kits_seen.get(kit_key, false):
			continue
		var cfg: Dictionary = _TUTORIAL_KIT_BARKS[kit_key]
		var dist: int = cfg.get("dist", 2)
		var found := false
		for dy in range(-dist, dist + 1):
			var y := py + dy
			if y < 0 or y >= h:
				continue
			var row: Array = cells[y]
			for dx in range(-dist, dist + 1):
				var x := px + dx
				if x < 0 or x >= w:
					continue
				var cell = row[x]
				if cell is Dictionary and str(cell.get("kit", "")) == kit_key:
					found = true
					break
			if found:
				break
		if found:
			_tutorial_kits_seen[kit_key] = true
			var skill_id: String = str(cfg.get("skill", ""))
			if OrbBarksManager != null:
				var raw_txt = cfg.get("text", "")
				var bark_str: String = Locale.pick(raw_txt) if raw_txt is Dictionary else str(raw_txt)
				OrbBarksManager.trigger_bark(bark_str, 6.0)
			if _hud != null and skill_id != "":
				_hud.set_tutorial_highlight(skill_id, _TUTORIAL_HIGHLIGHT_DURATION)


# ─── JOYSTICKS VIRTUALES (movimiento + cámara) ────────────────────────────────
func _build_joystick() -> void:
	_joy_area = Control.new()
	_joy_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_joy_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$MobileControls.add_child(_joy_area)

	# --- Joystick Izquierdo (Movimiento) ---
	_left_joy_base = Panel.new()
	_left_joy_base.size = Vector2(JOY_RADIUS * 2.0, JOY_RADIUS * 2.0)
	_left_joy_base.visible = false
	_left_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_base_sb := StyleBoxFlat.new()
	left_base_sb.bg_color = Color(UiKit.BG_DEEP.r, UiKit.BG_DEEP.g, UiKit.BG_DEEP.b, 0.32)
	left_base_sb.set_corner_radius_all(int(JOY_RADIUS))
	left_base_sb.set_border_width_all(2)
	left_base_sb.border_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.4)
	_left_joy_base.add_theme_stylebox_override("panel", left_base_sb)
	_joy_area.add_child(_left_joy_base)

	var kr: float = JOY_RADIUS * 0.5
	_left_joy_knob = Panel.new()
	_left_joy_knob.size = Vector2(kr * 2.0, kr * 2.0)
	_left_joy_knob.visible = false
	_left_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_knob_sb := StyleBoxFlat.new()
	left_knob_sb.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.85)
	left_knob_sb.set_corner_radius_all(int(kr))
	_left_joy_knob.add_theme_stylebox_override("panel", left_knob_sb)
	_joy_area.add_child(_left_joy_knob)

	# --- Joystick Derecho (Cámara) ---
	_right_joy_base = Panel.new()
	_right_joy_base.size = Vector2(JOY_RADIUS * 2.0, JOY_RADIUS * 2.0)
	_right_joy_base.visible = false
	_right_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right_base_sb := StyleBoxFlat.new()
	right_base_sb.bg_color = Color(UiKit.BG_DEEP.r, UiKit.BG_DEEP.g, UiKit.BG_DEEP.b, 0.32)
	right_base_sb.set_corner_radius_all(int(JOY_RADIUS))
	right_base_sb.set_border_width_all(2)
	right_base_sb.border_color = Color(0.3, 0.8, 1.0, 0.4)
	_right_joy_base.add_theme_stylebox_override("panel", right_base_sb)
	_joy_area.add_child(_right_joy_base)

	_right_joy_knob = Panel.new()
	_right_joy_knob.size = Vector2(kr * 2.0, kr * 2.0)
	_right_joy_knob.visible = false
	_right_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right_knob_sb := StyleBoxFlat.new()
	right_knob_sb.bg_color = Color(0.3, 0.8, 1.0, 0.85)
	right_knob_sb.set_corner_radius_all(int(kr))
	_right_joy_knob.add_theme_stylebox_override("panel", right_knob_sb)
	_joy_area.add_child(_right_joy_knob)


func _input(event: InputEvent) -> void:
	if not _is_active or not is_visible_in_tree():
		# La mazmorra puede desactivarse/ocultarse a media pulsación (p. ej. al
		# salir de vuelta al mapamundi mientras se arrastra un joystick): si no
		# reseteamos aquí, el evento de "soltar" nunca llega a procesarse y el
		# joystick se queda "activo" con el último vector, moviendo al
		# personaje sin que el jugador toque nada al reactivarse esta vista.
		if _left_joy_active:
			_reset_left_joystick()
		if _right_joy_active:
			_reset_right_joystick()
		return

	var vp_width := get_viewport_rect().size.x
	var split_x := vp_width * 0.5

	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < split_x:
				if not _left_joy_active and _can_start_joystick_at(event.position):
					_start_left_joystick(event.index, event.position)
			else:
				if not _right_joy_active and _can_start_joystick_at(event.position):
					_start_right_joystick(event.index, event.position)
		else:
			if event.index == _left_joy_index:
				_reset_left_joystick()
			if event.index == _right_joy_index:
				_reset_right_joystick()

	elif event is InputEventScreenDrag:
		if event.index == _left_joy_index:
			_update_left_joystick(event.position)
		elif event.index == _right_joy_index:
			_update_right_joystick(event.position)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.x < split_x:
				if not _left_joy_active and _can_start_joystick_at(event.position):
					_start_left_joystick(-2, event.position)
			else:
				if not _right_joy_active and _can_start_joystick_at(event.position):
					_start_right_joystick(-2, event.position)
		else:
			if _left_joy_index == -2:
				_reset_left_joystick()
			if _right_joy_index == -2:
				_reset_right_joystick()

	elif event is InputEventMouseMotion:
		if _left_joy_index == -2:
			_update_left_joystick(event.position)
		if _right_joy_index == -2:
			_update_right_joystick(event.position)


func _can_start_joystick_at(pos: Vector2) -> bool:
	if _joy_area == null or not _joy_area.get_global_rect().has_point(pos):
		return false
	if _hud != null and _hud.blocks_joystick_point(pos):
		return false
	return true


# --- Joystick Izquierdo (Movimiento) ---
func _start_left_joystick(index: int, global_pos: Vector2) -> void:
	_left_joy_index = index
	_left_joy_active = true
	_left_joy_center = global_pos - _joy_area.global_position
	_left_joy_vec = Vector2.ZERO
	_left_joy_base.visible = true
	_left_joy_knob.visible = true
	_position_left_joystick(Vector2.ZERO)


func _update_left_joystick(global_pos: Vector2) -> void:
	var off: Vector2 = (global_pos - _joy_area.global_position) - _left_joy_center
	if off.length() > JOY_RADIUS:
		off = off.normalized() * JOY_RADIUS
	_left_joy_vec = off / JOY_RADIUS
	_position_left_joystick(off)


func _reset_left_joystick() -> void:
	_left_joy_index = -1
	_left_joy_active = false
	_left_joy_vec = Vector2.ZERO
	if _left_joy_base != null:
		_left_joy_base.visible = false
	if _left_joy_knob != null:
		_left_joy_knob.visible = false


func _position_left_joystick(off: Vector2) -> void:
	_left_joy_base.position = _left_joy_center - _left_joy_base.size * 0.5
	_left_joy_knob.position = _left_joy_center + off - _left_joy_knob.size * 0.5


# --- Joystick Derecho (Cámara) ---
func _start_right_joystick(index: int, global_pos: Vector2) -> void:
	_right_joy_index = index
	_right_joy_active = true
	_right_joy_center = global_pos - _joy_area.global_position
	_right_joy_vec = Vector2.ZERO
	_right_joy_base.visible = true
	_right_joy_knob.visible = true
	_position_right_joystick(Vector2.ZERO)


func _update_right_joystick(global_pos: Vector2) -> void:
	var off: Vector2 = (global_pos - _joy_area.global_position) - _right_joy_center
	if off.length() > JOY_RADIUS:
		off = off.normalized() * JOY_RADIUS
	_right_joy_vec = off / JOY_RADIUS
	_position_right_joystick(off)


func _reset_right_joystick() -> void:
	_right_joy_index = -1
	_right_joy_active = false
	_right_joy_vec = Vector2.ZERO
	if _right_joy_base != null:
		_right_joy_base.visible = false
	if _right_joy_knob != null:
		_right_joy_knob.visible = false


func _position_right_joystick(off: Vector2) -> void:
	_right_joy_base.position = _right_joy_center - _right_joy_base.size * 0.5
	_right_joy_knob.position = _right_joy_center + off - _right_joy_knob.size * 0.5


## Traduce los elementos de interfaz de la mazmorra.
func _refresh_chrome() -> void:
	btn_leave.text = Locale.t("dungeon_leave")
	if lbl_dungeon_name != null:
		lbl_dungeon_name.text = get_dungeon_name()
	var root_scene: Node = get_tree().current_scene if get_tree() != null else null
	if root_scene != null and root_scene.has_method("refresh_hud_location_title"):
		root_scene.call("refresh_hud_location_title")


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════
func setup(cell_data: Dictionary) -> void:
	_cell_data = cell_data
	_is_active = true

	# Definición ÚNICA de esta mazmorra: SIEMPRE un layout de rejilla data-driven
	# (data/dungeons/<event_id>.json, cargado perezosamente por Design), editable
	# desde el editor visual de mazmorras.
	var event_id: String = cell_data.get("event_id", "")
	# TODAS las mazmorras son DATA-DRIVEN (grid, data/dungeons/<id>.json). Ya no hay
	# escenarios 3D "a mano": si un event_id no tiene layout, se usa una sala mínima
	# de reserva (también data-driven), editable después desde el editor de mazmorras.
	_dungeon = Design.get_dungeon_layout(event_id) if Design.has_dungeon_layout(event_id) else _fallback_layout()

	var dungeon_music: String = str(_dungeon.get("music", ""))
	if dungeon_music == "" or dungeon_music == "dungeon":
		var theme_name: String = str(_dungeon.get("theme", "cave"))
		if AudioManager.has_music_track(theme_name):
			dungeon_music = theme_name
		else:
			dungeon_music = "dungeon"
	AudioManager.push_music(dungeon_music)
	# TASK 3 FASE C: canal de ambiente en bucle independiente de la música (campo
	# plano opcional `ambient_sfx_loop` en el JSON de la mazmorra). Silencioso si
	# no hay ninguno registrado (ver AudioManager.AMBIENT_SFX_PATHS).
	AudioManager.play_ambient_loop(str(_dungeon.get("ambient_sfx_loop", "")))
	var title_str: String = get_dungeon_name()
	lbl_dungeon_name.text = title_str
	lbl_dungeon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiKit.apply_heading(lbl_dungeon_name)
	lbl_dungeon_name.add_theme_font_size_override("font_size", 40)
	lbl_dungeon_name.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 0.85))
	lbl_dungeon_name.add_theme_constant_override("outline_size", 2)
	lbl_dungeon_name.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	lbl_dungeon_name.add_theme_constant_override("shadow_offset_x", 2)
	lbl_dungeon_name.add_theme_constant_override("shadow_offset_y", 2)
	if has_node("VBox/Header/MarginHeader/HBoxH/LblDungeonIcon"):
		$VBox/Header/MarginHeader/HBoxH/LblDungeonIcon.visible = false

	# Limpieza de cualquier instancia 3D anterior
	_clean_up_3d()

	# Instanciar el escenario 3D de rejilla dentro del Viewport a partir de los datos.
	var grid: Node3D = GRID_STAGE_SCRIPT.new()
	_stage_instance = grid
	sub_viewport.add_child(_stage_instance)
	await grid.build(_dungeon, event_id)
	var spawn_pos: Vector3 = grid.spawn_position
	
	# REAPARICIÓN EN DUN_INICIAL: si ya salió una vez, aparecer delante del portal de salida
	if event_id == "dun_inicial":
		_tutorial_kits_seen.clear()
		if GlobalState.has_world_flag("dun_inicial_skills_forgotten"):
			# Re-entrada a la cueva tras superar el prólogo: aparecer junto a la
			# puerta de salida de la planta superior (Planta 2), no en el vacío.
			_current_floor = 2
			var spawn_cell := Vector2i(3, 37)
			var floors: Array = _dungeon.get("floors", [])
			if floors.size() > 2:
				var f2_cells: Array = floors[2].get("cells", [])
				for fy in range(f2_cells.size()):
					for fx in range(f2_cells[fy].size()):
						var c_dict: Dictionary = f2_cells[fy][fx]
						if c_dict.get("t") == "teleport" and not c_dict.has("target_floor"):
							spawn_cell = Vector2i(fx, max(0, fy - 1))
							break
			spawn_pos = grid.cell_to_world(2, spawn_cell.x, spawn_cell.y)
		elif OrbBarksManager != null and OrbBarksManager.get_current_phase() <= 1:
			OrbBarksManager.set_phase(1, true)
	elif (event_id.begins_with("dun_yelmo") or event_id == "dun_001" or str(_dungeon.get("id", "")) == "dun_yelmo") and GlobalState.get_profession_level("Don Nadie") < 5:
		if OrbBarksManager != null:
			get_tree().create_timer(0.4).timeout.connect(func() -> void:
				if is_instance_valid(self) and _is_active and OrbBarksManager != null:
					OrbBarksManager.trigger_important_message(
						Locale.pick({
							"es": "Si yo fuera tú no me vendría hasta tener un level más alto, te lo recomiendo encarecidamente, pero tú mismo, a mí me da igual verte en bucle perdiendo el tiempo.",
							"en": "If I were you I wouldn't come here until you have a higher level, I strongly recommend it, but suit yourself, it makes no difference to me watching you in a loop wasting your time."
						})
					)
			)
	
	# ENTRADA NOMBRADA: si la casilla del mapamundi declara
	# `portal.entry` y la mazmorra tiene un portal con ese nombre, se entra AHÍ en
	# vez del spawn genérico. Así una misma mazmorra puede tener 2-3 "puertas"
	# (p. ej. dun_001/dun_001_east, dos montañas contiguas) que aparecen en sitios
	# distintos por dentro. NO se muta `_dungeon` (es la caché compartida de
	# Design._dungeon_cache): solo se recalcula `spawn_pos` en local.
	var entry_name := ""
	if cell_data.get("portal") is Dictionary:
		entry_name = str((cell_data["portal"] as Dictionary).get("entry", ""))
	if _current_floor == 0: # Solo usar spawn normal si no se ha establecido antes
		_current_floor = int(_dungeon.get("spawn", {}).get("f", 0))
	if entry_name != "" and _dungeon.get("portals") is Dictionary:
		var named_portal = (_dungeon["portals"] as Dictionary).get(entry_name, null)
		var sp = named_portal.get("spawn", null) if named_portal is Dictionary else null
		if sp is Dictionary:
			_current_floor = int(sp.get("f", 0))
			spawn_pos = grid.cell_to_world(int(sp.get("f", 0)), int(sp.get("x", 0)), int(sp.get("y", 0)))
	
	_is_snow_dungeon = (event_id == "dun_nieves" or str(_dungeon.get("id", "")) == "dun_nieves")
	_dungeon_entry_spawn_pos = spawn_pos
	_dungeon_entry_floor = _current_floor
	_snow_lost_in_progress = false
	_snow_lost_cooldown = 2.5
	if _snow_mist_overlay != null:
		_snow_mist_overlay.color.a = 0.0
	_cache_snow_walls()

	_setup_minimap_floor(_current_floor)

	# Anti-reaparición del JEFE: si ya se derrotó en una visita anterior, retirar sus
	# nodos del escenario recién construido (los monstruos normales sí reaparecen).
	_remove_defeated_boss_nodes()
	_update_boss_teleport_visibility(false)

	# Cooldown inicial para teletransportadores y portales.
	_tp_cooldown_until = Time.get_ticks_msec() + 1500

	# Instanciar el jugador en primera persona
	_player_instance = PLAYER_SCENE.instantiate() as CharacterBody3D
	_stage_instance.add_child(_player_instance)
	_player_instance.position = spawn_pos
	# Task 4 FASE 5.2: material de suelo (por mazmorra) para variar el SFX de pasos.
	_player_instance.floor_surface_kind = grid.get_floor_surface_kind()

	# En dun_nieves: limitar visión a no más de 5 casillas de distancia
	if _is_snow_dungeon:
		var cam := _player_instance.get_node_or_null("head/Camera3D") as Camera3D
		if cam != null:
			var c_sz: float = float(_dungeon.get("cell_size", 4.0))
			cam.far = 5.25 * c_sz
		var omni := _player_instance.get_node_or_null("head/OmniLight3D") as OmniLight3D
		if omni != null:
			omni.omni_range = 5.25 * float(_dungeon.get("cell_size", 4.0))
		if _minimap != null:
			_minimap.view_radius = 5

	# Asegurar que el botón de mapamundi nunca se muestre en mazmorras
	_hide_world_map_button()

	# Feedback de peligros: escuchar al jugador (daño y estado de agua)
	if _hazard_overlay:
		_hazard_overlay.color.a = 0.0
	if _player_instance.has_signal("took_damage"):
		_player_instance.took_damage.connect(_on_player_took_damage)
	if _player_instance.has_signal("water_changed"):
		_player_instance.water_changed.connect(_on_player_water_changed)

	# HUD de exploración: cablear al controller de habilidades del jugador.
	if _time_vignette:
		_time_vignette.visible = false
	_time_slow_shown = false
	if _hud:
		_hud.bind(_player_instance.skill_controller())

	# Al entrar a CUALQUIER escenario se limpian los desbloqueos temporales de la
	# sesión anterior (evita arrastrar la habilidad de un tutorial ya abandonado).
	ExplorationSkills.clear_session()

	# Laboratorio Debug: si es la sala `dun_lab`, desbloquea todas las
	# habilidades y llena la sala de kits compuestos para validar los verbos.
	if event_id == "dun_lab":
		_build_debug_lab()

	# Tutorial: si el layout declara `tutorial_skill`, se concede TEMPORAL
	# para que el jugador pueda practicarla; al completar (portal de salida) se
	# obtiene de forma permanente vía `complete_event` (token prof:).
	_setup_tutorial(event_id)

	# Configurar y vincular los enemigos del escenario
	_setup_dungeon_enemies()

	# Vincular todos los portales de salida de este escenario
	var portals: Array[Node] = []
	for n in get_tree().get_nodes_in_group("exit_portal"):
		if _stage_instance.is_ancestor_of(n):
			portals.append(n)
			
	if portals.is_empty():
		var fallback_portal = _stage_instance.get_node_or_null("Rooms/RoomSouth/ExitPortal")
		if fallback_portal:
			portals.append(fallback_portal)
			
	for p in portals:
		if p.has_signal("body_entered") and not p.body_entered.is_connected(_on_exit_portal_entered):
			p.body_entered.connect(_on_exit_portal_entered.bind(p))

	# Si el layout no declara salida, mostrar el botón "Salir" como fallback.
	if btn_leave != null:
		btn_leave.visible = portals.is_empty()

	# Vincular los cofres data-driven de este escenario (grupo "dungeon_chest").
	for c in get_tree().get_nodes_in_group("dungeon_chest"):
		if _stage_instance.is_ancestor_of(c) and c.has_signal("body_entered") \
				and not c.body_entered.is_connected(_on_chest_entered):
			c.body_entered.connect(_on_chest_entered.bind(c))

	# Vincular los teletransportes internos (grupo "dungeon_teleport").
	for tp in get_tree().get_nodes_in_group("dungeon_teleport"):
		if _stage_instance.is_ancestor_of(tp) and tp.has_signal("body_entered") \
				and not tp.body_entered.is_connected(_on_teleport_entered):
			tp.body_entered.connect(_on_teleport_entered.bind(tp))

	# Vincular activadores de cinemática (grupo "dungeon_cinematic").
	for cine in get_tree().get_nodes_in_group("dungeon_cinematic"):
		if _stage_instance.is_ancestor_of(cine) and cine.has_signal("body_entered") \
				and not cine.body_entered.is_connected(_on_dungeon_cinematic_entered):
			cine.body_entered.connect(_on_dungeon_cinematic_entered.bind(cine))

	# Efecto visual de transición (fundido de entrada de la interfaz)
	$VBox.modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_callback(func() -> void:
		var f_tween := create_tween()
		f_tween.tween_property($VBox, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	)

	_setup_dun_final_6_event()


## Configura el Laboratorio Debug: desbloquea las 6 habilidades de exploración,
## rellena la barra de energía y vincula el HUD al controlador de habilidades.
## Los elementos 3D se cargan exclusivamente desde la matriz limpia de dun_lab.json.
func _build_debug_lab() -> void:
	for id in ExplorationSkills.all_ids():
		ExplorationSkills.unlock(id)
	GlobalState.energy = float(GlobalState.max_energy)
	GlobalState.state_updated.emit()
	if _hud and _player_instance != null:
		_hud.bind(_player_instance.skill_controller())


## Estado de PRUEBA de profesión (Sendero) activo: guarda la profesión previa para
## restaurarla si el jugador ABANDONA sin completar. Al completar, la profesión la
## fija el `complete_event` (token prof:), así que no se restaura.
var _trial_active: bool = false
var _trial_prev_profession: String = ""


## Prepara una mini-mazmorra tutorial (Sendero de profesión). Si el layout declara
## `tutorial_skill`:
##   - Sesión EXCLUSIVA: dentro del sendero SOLO se puede usar la habilidad de esa
##     profesión (aunque el jugador ya domine otras), para que descubra la novedad.
##   - Profesión ACTIVA en combate = la del sendero (aunque aún no sea permanente),
##     de modo que el jefe se afronta con esa clase. Se guarda la previa por si
##     abandona. El premio permanente se otorga al salir vía `complete_event`.
func _setup_tutorial(_event_id: String) -> void:
	var skill := str(_dungeon.get("tutorial_skill", ""))
	if skill == "":
		return
	ExplorationSkills.begin_exclusive_session(skill)
	var prof := str(ExplorationSkills.get_skill(skill).get("profession", ""))
	if prof != "" and prof != GlobalState.profession:
		_trial_prev_profession = GlobalState.profession
		_trial_active = true
		GlobalState.set_profession(prof)
	GlobalState.energy = float(GlobalState.max_energy)
	GlobalState.state_updated.emit()
	if _hud:
		_hud.bind(_player_instance.skill_controller())


## Restaura la profesión previa a la PRUEBA (solo si se abandona sin completar).
func _restore_trial_profession() -> void:
	if _trial_active:
		GlobalState.set_profession(_trial_prev_profession)
		_trial_active = false


func stop_exploration() -> void:
	_is_active = false
	if _player_instance:
		_player_instance.is_active = false
		_player_instance.stop_footsteps()


func resume_exploration() -> void:
	Engine.time_scale = 1.0
	_is_active = true
	_hide_world_map_button()
	if _player_instance:
		_player_instance.is_active = true
		
	# Si regresamos de un combate ordinario y ganamos, eliminamos el enemigo del mapa 3D
	if _current_enemy_node and is_instance_valid(_current_enemy_node):
		_current_enemy_node.queue_free()
		_current_enemy_node = null

	if _last_combat_was_boss:
		_last_combat_was_boss = false
		_update_boss_teleport_visibility(true)
		if _minimap != null and _minimap.has_method("set_boss_defeated"):
			_minimap.call("set_boss_defeated", true)

		if _dungeon_id == "dun_final_6":
			stop_exploration()
			Juice.transition(func() -> void:
				SceneRunner.start_scene("epilogo_final")
			)
			return


# ══════════════════════════════════════════════════════════════════════════════
# GESTIÓN INTERNA DE ENEMIGOS 3D
# ══════════════════════════════════════════════════════════════════════════════
func _setup_dungeon_enemies() -> void:
	if _stage_instance == null:
		return

	# Descubrir todos los enemigos del escenario por grupo (independiente del layout).
	for enemy in get_tree().get_nodes_in_group("dungeon_enemy"):
		if not _stage_instance.is_ancestor_of(enemy):
			continue
		if not enemy.combat_triggered.is_connected(_on_enemy_combat_triggered):
			enemy.combat_triggered.connect(_on_enemy_combat_triggered)
		# Pintar el sprite según enemy_id, usando siempre la textura canónica de Design.enemy(eid)
		if enemy.has_method("refresh_visuals"):
			enemy.call("refresh_visuals")


## Señal recibida desde DungeonEnemy cuando detecta al jugador.
func _on_enemy_combat_triggered(is_boss: bool, enemy_id: String, enemy_node: Node) -> void:
	if not _is_active:
		return
		
	stop_exploration()
	_current_enemy_node = enemy_node
	
	# Construir base de datos de combate del enemigo. Si la casilla puso un
	# `ref` EXPLÍCITO en el editor (DungeonEnemy.has_explicit_ref), se combate
	# EXACTAMENTE contra ese enemigo/nivel (Task 1 Fase 3: "colocar un enemigo
	# indicando solo el level" — antes el `ref`/`level` de la casilla solo
	# afectaban al aspecto, nunca a con quién se luchaba de verdad). Todas las
	# casillas "monster" de las mazmorras autoradas traen `ref` explícito (no
	# hay enemigos aleatorios); si alguna vez faltara, se usa el jefe de la
	# mazmorra como último recurso determinista.
	var has_ref: bool = enemy_node != null and is_instance_valid(enemy_node) and bool(enemy_node.get("has_explicit_ref"))
	var enemy_data: Dictionary
	if has_ref:
		var lvl: int = maxi(1, int(enemy_node.get("level")))
		enemy_data = EnemyDatabase.build_enemy(enemy_id, lvl, is_boss)
	elif is_boss:
		enemy_data = _get_boss_data()
	else:
		enemy_data = EnemyDatabase.build_enemy(enemy_id, 1, false)

	enemy_data["is_boss"] = is_boss
	enemy_data["cell_coord"] = _cell_data.get("coord", Vector2i.ZERO)
	_last_combat_was_boss = is_boss
	if is_boss:
		# Clave estable del jefe para marcarlo como derrotado al ganar (anti-reaparición).
		enemy_data["boss_key"] = _boss_key()

	# Recompensa de primer golpe (golpe de sorpresa): el enemigo empieza con menos HP.
	var hp_factor: float = 1.0
	if enemy_node and is_instance_valid(enemy_node) and "incoming_hp_factor" in enemy_node:
		hp_factor = float(enemy_node.incoming_hp_factor)
	if hp_factor < 1.0:
		enemy_data["hp"] = maxi(1, int(round(float(enemy_data.get("hp", 1)) * hp_factor)))

	# Contexto de mazmorra para fondo y plataforma dinámicos
	enemy_data["context"] = "dungeon"
	enemy_data["dungeon_id"] = str(_cell_data.get("event_id", _dungeon.get("id", "")))
	enemy_data["dungeon_theme"] = str(_dungeon.get("theme", "cave"))

	# Cambiar a la vista de combate global
	SceneManager.start_combat(enemy_data)


func _get_boss_data() -> Dictionary:
	# El jefe lo define el layout de la mazmorra (data/dungeons/<id>.json). QuestManager.on_combat_victory
	# reacciona al enemy_id (p. ej. la Sombra Oscura de la Caverna Profunda suelta el Diario).
	# `boss_level` es opcional (por defecto 1) y permite fijar la curva de progresión
	# por zona (Task 1 FASE 1) sin afectar a mazmorras que no lo definan.
	var boss_id: String = str(_dungeon.get("boss", "dungeon_boss"))
	var boss_lvl: int = maxi(1, int(_dungeon.get("boss_level", 1)))
	return EnemyDatabase.build_enemy(boss_id, boss_lvl, true)


## Clave estable de este jefe para el registro anti-reaparición ("event_id:enemy_id").
func _boss_key() -> String:
	if _dungeon.has("boss_key"):
		return str(_dungeon["boss_key"])
	var event_id: String = str(_cell_data.get("event_id", ""))
	var boss_id: String = str(_dungeon.get("boss", "dungeon_boss"))
	return "%s:%s" % [event_id, boss_id]


## Elimina del escenario los nodos de JEFE ya derrotados (bug de reaparición): tras
## vencer al boss, al reentrar la mazmorra NO debe volver a aparecer (los monstruos
## normales sí, porque el escenario se reconstruye entero en cada entrada). Recorre
## el árbol del escenario y libera los DungeonEnemy marcados como `is_boss`.
func _remove_defeated_boss_nodes() -> void:
	if _stage_instance == null or not is_instance_valid(_stage_instance):
		return
	if not GlobalState.is_boss_defeated(_boss_key()):
		return
	for node in _collect_boss_nodes(_stage_instance):
		node.queue_free()


## Recolecta recursivamente los nodos de enemigo marcados como jefe (is_boss == true).
func _collect_boss_nodes(root: Node) -> Array:
	var found: Array = []
	for child in root.get_children():
		if "is_boss" in child and bool(child.get("is_boss")):
			found.append(child)
		found.append_array(_collect_boss_nodes(child))
	return found


## Actualiza la visibilidad y colisión de los teletransportes vinculados a jefes.
## Si el jefe de la mazmorra NO ha sido derrotado, el teletransporte junto al jefe
## permanece invisible y desactivado. Tras vencer al jefe, se hace visible y usable.
func _update_boss_teleport_visibility(animate: bool = false) -> void:
	if _stage_instance == null or not is_instance_valid(_stage_instance):
		return
	var defeated: bool = GlobalState.is_boss_defeated(_boss_key())
	for tp in get_tree().get_nodes_in_group("boss_teleport"):
		if not is_instance_valid(tp):
			continue
		if not _stage_instance.is_ancestor_of(tp):
			continue
		if defeated:
			var was_hidden: bool = not tp.visible
			tp.visible = true
			if tp is Area3D:
				tp.monitoring = true
				tp.monitorable = true
			if was_hidden and animate:
				var tp_pos: Vector3 = tp.global_position if tp is Node3D else (_player_instance.position if _player_instance != null else Vector3.ZERO)
				WorldFx.burst(_stage_instance, tp_pos, Color(0.55, 0.85, 1.0), 20)
				WorldFx.glow_flash(_stage_instance, tp_pos, Color(0.7, 0.9, 1.0), 4.0, 0.6)
				AudioManager.play_sfx("click")
		else:
			tp.visible = false
			if tp is Area3D:
				tp.monitoring = false
				tp.monitorable = false


## Layout de RESERVA (data-driven) para un event_id sin fichero en data/dungeons/:
## una sala 7x7 con el jefe genérico. Evita cualquier escenario cableado a mano.
func _fallback_layout() -> Dictionary:
	return {
		"name": "Mazmorra", "boss": "dungeon_boss",
		"music": "dungeon", "cell_size": 3.0, "wall_height": 3.0,
		"spawn": {"f": 0, "x": 3, "y": 5},
		"floors": [ {"name": "Planta 0", "w": 7, "h": 7, "cells": _fallback_cells()}],
	}

## Celdas de la sala de reserva (borde de muro, jefe genérico al fondo).
func _fallback_cells() -> Array:
	var w := {"t": "wall"}
	var f := {"t": "floor"}
	var b := {"t": "monster", "ref": "dungeon_boss", "boss": true}
	return [
		[w, w, w, w, w, w, w],
		[w, f, f, f, f, f, w],
		[w, f, f, b, f, f, w],
		[w, f, f, f, f, f, w],
		[w, f, f, f, f, f, w],
		[w, f, f, f, f, f, w],
		[w, w, w, w, w, w, w],
	]


# ══════════════════════════════════════════════════════════════════════════════
# ACCIONES Y LIMPIEZA
# ══════════════════════════════════════════════════════════════════════════════
## Purga todos los elementos visuales/efectos temporales de la mazmorra.
static func purge_dungeon_temp_elements(tree: SceneTree) -> void:
	if tree == null:
		return
	for nodo in tree.get_nodes_in_group("elementos_temporales_mazmorra"):
		if is_instance_valid(nodo):
			nodo.queue_free()


func _clean_up_3d() -> void:
	purge_dungeon_temp_elements(get_tree())
	if _stage_instance and is_instance_valid(_stage_instance):
		_stage_instance.queue_free()
	_stage_instance = null
	_player_instance = null
	_current_enemy_node = null
	_is_snow_dungeon = false
	_snow_lost_in_progress = false
	_snow_walls_coords.clear()
	if _snow_sound_player != null and _snow_sound_player.playing:
		_snow_sound_player.stop()
	if _snow_mist_overlay != null:
		_snow_mist_overlay.color.a = 0.0
	# La energía es un recurso de exploración: al salir de la mazmorra se rellena
	# (fuera de la mazmorra no hay quien la regenere y no se usa).
	if GlobalState.energy < float(GlobalState.max_energy):
		GlobalState.energy = float(GlobalState.max_energy)
		GlobalState.state_updated.emit()


func _on_btn_leave_pressed() -> void:
	AudioManager.play_sfx("click")
	stop_exploration()
	AudioManager.pop_music()
	AudioManager.stop_ambient_loop()
	_clean_up_3d()
	# Abandono de una PRUEBA sin completarla: revertir profesión y sesión exclusiva.
	_restore_trial_profession()
	ExplorationSkills.clear_session()
	var origin_coord = _cell_data.get("entry_tile_coord", null)
	if origin_coord is Vector2i and GlobalState.hexagons_db.has(origin_coord):
		GlobalState.player_pos = origin_coord
		SaveManager.request_autosave()
	_force_unlock_movement_on_exit()
	SceneManager.go_to_world()


## Desbloquea el movimiento INCONDICIONALMENTE al volver al
## mapamundi desde una mazmorra. Sin esto, si algo dentro de la mazmorra (una
## diálogo/bark que no cerró por su vía normal) dejó `is_movement_locked` en
## true, el jugador quedaba inmóvil en el mundo tras volver a entrar y salir.
func _force_unlock_movement_on_exit() -> void:
	GlobalState.is_movement_locked = false
	if GlobalEvents.has_signal("poi_exited"):
		GlobalEvents.poi_exited.emit("")


func _on_exit_portal_entered(body: Node, portal: Node = null) -> void:
	if body.name != "player":
		return
	if portal != null and portal.is_in_group("boss_teleport") and not GlobalState.is_boss_defeated(_boss_key()):
		return
	if Time.get_ticks_msec() < _tp_cooldown_until:
		return
	_handle_exit_portal.call_deferred(portal)


func _handle_exit_portal(portal: Node = null) -> void:
	var portal_name := str(portal.get_meta("portal_name")) if portal != null and is_instance_valid(portal) and portal.has_meta("portal_name") else ""
	var in_exit_group := portal != null and is_instance_valid(portal) and portal.is_in_group("exit_portal")

	AudioManager.play_sfx("click")
	stop_exploration()
	AudioManager.pop_music()
	AudioManager.stop_ambient_loop()
	_clean_up_3d()

	# Olvidar habilidades al salir por primera vez de dun_inicial (tutorial inicial)
	var exit_event_id := str(_cell_data.get("event_id", ""))
	if exit_event_id == "dun_inicial" and not GlobalState.has_world_flag("dun_inicial_skills_forgotten"):
		GlobalState.unlocked_skills.clear()
		GlobalState.set_world_flag("dun_inicial_skills_forgotten")
		GlobalState.set_world_flag("prologue_dungeon_cleared")
		GlobalState.state_updated.emit()
		SaveManager.request_autosave()

	# Si salimos por el portal de salida final de la cueva, marcar como completada.
	# Se enruta por QuestManager.run_world_transform (data-first + emite
	# map_cell_changed) para que el mundo 3D refresque el marcador de la casilla,
	# igual que al vencer al jefe. Antes usaba la ruta cableada sin refresco visual.
	# La Cueva Facilita (dun_001) solo se marca DESPEJADA (abre la reja al este)
	# si el jefe está derrotado. Así el portal de RETIRADA de la entrada permite
	# salir sin trampear el paso: solo el portal del fondo, tras vencer a la
	# bestia, abre el valle. Cualquier portal vale una vez muerto el jefe.
	if in_exit_group and (_cell_data.get("event_id", "") in ["dun_yelmo", "dun_yelmo_start", "dun_001"]) \
			and GlobalState.is_boss_defeated(_boss_key()):
		QuestManager.run_world_transform("cave_cleared")
		SaveManager.request_autosave()

	# Completar mazmorra: si el layout define `complete_event`, se ejecuta al
	# salir. En los Senderos (tutoriales de profesión) ya NO otorga la
	# profesión/habilidad directamente (token "prof:"): solo marca la PRUEBA
	# como superada (gflag `trial_done_sendero_<id>`). La profesión de verdad
	# se concede al volver con el Maestro y decirle "He completado la prueba"
	# (ver `data/npcs/temple_*.json`), para que el jugador se entere de lo que
	# ha pasado en vez de desbloquearse en silencio (ver task3_cambiosGeneral.md).
	# Como la profesión YA NO se concede aquí (ver arriba), hay que restaurar la
	# profesión previa a la PRUEBA igual que si se hubiera abandonado: si el
	# jugador confirma después con el Maestro, el reward "prof:" de esa opción
	# vuelve a activarla (esta vez sí, de forma permanente).
	_restore_trial_profession()
	var complete_event := str(_dungeon.get("complete_event", ""))
	if complete_event != "":
		Design.run_event(complete_event)
		SaveManager.request_autosave()
		# QUEST DE LAS PROFESIONES: aviso claro al salir por el portal final de
		# un Sendero — la prueba está superada, la Esfera de la Verdad orientará
		# al jugador al llegar al mapamundi para indicarle que regrese con su maestro.
		if exit_event_id.begins_with("sendero_") or _dungeon_id.begins_with("sendero_"):
			var sid: String = _dungeon_id if _dungeon_id.begins_with("sendero_") else exit_event_id
			if GlobalState.has_world_flag("trial_done_" + sid) or GlobalState.is_boss_defeated(_boss_key()):
				GlobalState.pending_trial_completed_sendero = sid
	ExplorationSkills.clear_session()

	# Salida NOMBRADA: si este portal declara `portal:"<nombre>"`
	# en su celda, se busca en el mapamundi la casilla que declara esa MISMA
	# entrada (`portal.entry`) para esta mazmorra y se reaparece ahí — así cada
	# salida de la mazmorra puede llevar a un sitio distinto del mundo (p. ej. la
	# puerta este de dun_001 en vez de la oeste por la que se entró). Si no hay
	# nombre o no se encuentra, cae al portal de salida genérico de siempre
	# (`exit_to:{x,y}`, o quedarse en la casilla de entrada).
	if portal_name == "" or not _apply_named_portal_exit(portal_name):
		_apply_dungeon_exit_to()
	_force_unlock_movement_on_exit()
	SceneManager.go_to_world()


## Reubica al jugador en la casilla `exit_to:{x,y}` del layout de mazmorra, si existe
## y es válida. Data-driven: no toca código por mazmorra. Persiste con autosave.
func _apply_dungeon_exit_to() -> void:
	var dest = _dungeon.get("exit_to", null)
	if dest is Dictionary:
		var coord := Vector2i(int(dest.get("x", -1)), int(dest.get("y", -1)))
		if coord.x >= 0 and coord.y >= 0 and GlobalState.hexagons_db.has(coord):
			var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource
			if cell != null and cell.is_walkable_terrain():
				GlobalState.player_pos = coord
				SaveManager.request_autosave()
				return
			else:
				push_warning("ViewDungeon: exit_to %s es terreno bloqueante (%s); se ignora." % [coord, cell.terrain if cell else "null"])
		else:
			push_warning("ViewDungeon: exit_to %s fuera del mapa; se ignora." % coord)

	# Fallback si no hay exit_to o no es válido: volver a la coordenada de entrada
	var origin_coord = _cell_data.get("entry_tile_coord", null)
	if origin_coord is Vector2i and GlobalState.hexagons_db.has(origin_coord):
		GlobalState.player_pos = origin_coord
		SaveManager.request_autosave()


## Reubica al jugador en la casilla del mapamundi cuya `portal.entry` coincide con
## `entry_name` PARA ESTA MISMA mazmorra. No
## usa coordenadas fijas: busca en vivo, así que sigue funcionando si se mueve la
## casilla en el editor. Devuelve true si encontró destino y reubicó al jugador.
func _apply_named_portal_exit(entry_name: String) -> bool:
	var dungeon_id := str(_cell_data.get("event_id", ""))
	if dungeon_id == "":
		dungeon_id = str(_dungeon.get("id", ""))
	if dungeon_id == "":
		return false
	var coord := _find_portal_world_coord(dungeon_id, entry_name)
	var cell: CellResource = GlobalState.hexagons_db.get(coord, null) as CellResource if coord.x >= 0 and coord.y >= 0 else null
	if coord.x < 0 or coord.y < 0 or cell == null or not cell.is_walkable_terrain():
		# Fallback: si no encontró por portal_name o no es transitable, usar la coordenada de la casilla por la que entró
		var origin_coord = _cell_data.get("entry_tile_coord", null)
		if origin_coord is Vector2i and GlobalState.hexagons_db.has(origin_coord):
			var orig_cell: CellResource = GlobalState.hexagons_db[origin_coord] as CellResource
			if orig_cell != null and orig_cell.is_walkable_terrain():
				GlobalState.player_pos = origin_coord
				SaveManager.request_autosave()
				return true
		return false
	GlobalState.player_pos = coord
	SaveManager.request_autosave()
	return true


## Busca la casilla del mapamundi cuyo `portal.entry == entry_name` y cuyo destino
## efectivo (`portal.event_id` si lo declara; si no, su propio `event_id`) es
## `dungeon_id`. Devuelve (-1,-1) si no existe ninguna.
func _find_portal_world_coord(dungeon_id: String, entry_name: String) -> Vector2i:
	if entry_name == "":
		return Vector2i(-1, -1)

	for coord: Vector2i in GlobalState.hexagons_db.keys():
		var c: CellResource = GlobalState.hexagons_db[coord] as CellResource
		if c == null:
			continue

		var cell_entry := ""
		var cell_target_id := c.event_id

		if c.portal is Dictionary:
			var pt: Dictionary = c.portal
			cell_entry = str(pt.get("entry", ""))
			if str(pt.get("event_id", "")) != "":
				cell_target_id = str(pt["event_id"])

		# Coincidencia: la casilla del mapa conduce a esta mazmorra y tiene la entrada `entry_name`
		if (cell_target_id == dungeon_id or c.event_id == dungeon_id) and cell_entry == entry_name:
			return coord

	return Vector2i(-1, -1)


## El jugador toca un cofre: concede su contenido UNA vez (data-driven), lo apaga
## y muestra el botín. La persistencia la lleva GlobalState.open_chest.
func _on_chest_entered(body: Node, chest: Node = null) -> void:
	if body.name != "player" or chest == null or not is_instance_valid(chest):
		return
	var key := str(chest.get_meta("chest_key")) if chest.has_meta("chest_key") else ""
	if key == "" or GlobalState.is_chest_opened(key):
		return
	var is_trap: bool = bool(chest.get_meta("chest_trap")) if chest.has_meta("chest_trap") else false
	if is_trap:
		var trap_dmg: int = int(chest.get_meta("chest_trap_damage")) if chest.has_meta("chest_trap_damage") else 25
		GlobalState.hp = maxi(1, GlobalState.hp - trap_dmg)
		GlobalState.state_updated.emit()
		GlobalState.open_chest(key, {})
		chest.set_deferred("monitoring", false)

		# 1. Abrir visualmente el cofre (animación 3D o giro de la tapa)
		var trap_anim = chest.get_meta("chest_anim") if chest.has_meta("chest_anim") else null
		if trap_anim is AnimationPlayer and is_instance_valid(trap_anim):
			if trap_anim.has_animation("Chest_Open"):
				trap_anim.play("Chest_Open")
			elif trap_anim.has_animation("Chest_Opened"):
				trap_anim.play("Chest_Opened")

		var mesh_trap = chest.get_meta("chest_mesh") if chest.has_meta("chest_mesh") else null
		if mesh_trap is Node3D and is_instance_valid(mesh_trap):
			var lid_node := mesh_trap.find_child("Lid", true, false) as Node3D
			if lid_node != null:
				var tw_lid := create_tween()
				tw_lid.tween_property(lid_node, "rotation_degrees:x", -75.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Juice.shake(mesh_trap, 0.45, 0.45)
			var fx_pos: Vector3 = mesh_trap.global_position + Vector3(0.0, 0.5, 0.0)
			WorldFx.explosion_fx(_stage_instance, fx_pos, 1.3)
			_char_chest_meshes(mesh_trap)

		# 2. Sonido y sacudida de la detonación
		AudioManager.play_sfx("hit")
		AudioManager.play_sfx("sfx_temblor")
		Input.vibrate_handheld(350)
		if _player_instance != null and is_instance_valid(_player_instance):
			Juice.shake(_player_instance, 0.45, 0.45)
		if _hazard_overlay != null:
			if _damage_tween and _damage_tween.is_valid():
				_damage_tween.kill()
			_hazard_overlay.color = Color(1.0, 0.15, 0.05, 0.70)
			_damage_tween = create_tween()
			_damage_tween.tween_property(_hazard_overlay, "color", _rest_overlay_color(), 0.45) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

		# 3. Comentario de la Esfera de la Verdad
		var sphere_comment: String = ""
		if _dungeon_id == "dun_final_3" or _dungeon_id.begins_with("dun_final"):
			sphere_comment = Locale.pick({
				"es": "«¡No seas codicioso y no toques nada excepto la lámp... digo, ¡la salida!»",
				"en": "«Don't be greedy and don't touch anything except the lamp... I mean, the exit!»"
			})
		else:
			sphere_comment = Locale.pick({
				"es": "«¡¿Ves?! ¡No toques! ¿Para qué tocas?»",
				"en": "«See?! Don't touch, why do you have to touch?!»"
			})

		UiKit.toast(self, "🔮 La Esfera: " + sphere_comment, Color(1.0, 0.45, 0.2))
		if OrbBarksManager != null:
			OrbBarksManager.trigger_bark(sphere_comment, 5.5)

		SaveManager.request_autosave()
		return

	var contents := {
		"gold": int(chest.get_meta("chest_gold")) if chest.has_meta("chest_gold") else 0,
		"items": chest.get_meta("chest_items") if chest.has_meta("chest_items") else [],
		"loot": chest.get_meta("chest_loot") if chest.has_meta("chest_loot") else null,
	}
	var granted: Array = GlobalState.open_chest(key, contents)
	AudioManager.play_ui("pickup")
	SaveManager.request_autosave()
	# Abrir el cofre visualmente con su animación y efectos
	var anim = chest.get_meta("chest_anim") if chest.has_meta("chest_anim") else null
	if anim is AnimationPlayer and is_instance_valid(anim):
		if anim.has_animation("Chest_Open"):
			anim.play("Chest_Open")
		elif anim.has_animation("Chest_Opened"):
			anim.play("Chest_Opened")

	var mesh = chest.get_meta("chest_mesh") if chest.has_meta("chest_mesh") else null
	if mesh is Node3D and is_instance_valid(mesh):
		# Destello + estallido dorado al abrir para que la recompensa se sienta importante
		var fx_pos: Vector3 = mesh.global_position + Vector3(0.0, 0.5, 0.0)
		WorldFx.burst(_stage_instance, fx_pos, Color(1.0, 0.85, 0.35), 16)
		WorldFx.glow_flash(_stage_instance, fx_pos, Color(1.0, 0.88, 0.5), 3.5, 0.45)
		_dim_chest_meshes(mesh)
	chest.set_deferred("monitoring", false)
	_show_chest_loot_dialogue(granted)


## Apaga visualmente un cofre saqueado: recorre las mallas del modelo low-poly
## (cuerpo/tapa/herrajes) y les quita la emisión y baja el albedo a tonos apagados.
func _dim_chest_meshes(root: Node3D) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var m := ((child as MeshInstance3D).material_override) as StandardMaterial3D
			if m:
				m.emission_enabled = false
				m.albedo_color = m.albedo_color.darkened(0.45)


## Calcina visualmente un cofre tras una detonación trampa: recorre las mallas
## y las tiñe de color carbón oscuro apagando cualquier emisión previa.
func _char_chest_meshes(root: Node3D) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var m := ((child as MeshInstance3D).material_override) as StandardMaterial3D
			if m:
				m.emission_enabled = false
				m.albedo_color = Color(0.12, 0.10, 0.08)
		elif child is Node3D:
			_char_chest_meshes(child)


## Muestra un aviso transitorio (panel) con el botín obtenido de un cofre. Se dibuja
## como una tarjeta acotada arriba-centro: cabecera "🧰 Cofre" + una línea por premio
## (icono + nombre + cantidad). Anchura fija (no ocupa toda la pantalla) y fundido.
func _show_chest_loot_dialogue(granted: Array) -> void:
	# Construir las filas del botín: { icon, text }.
	var rows: Array = []
	for g in granted:
		if str(g.get("kind", "")) == "gold":
			rows.append({"icon": "🪙", "text": "%d de oro" % int(g.get("qty", 0))})
		else:
			# Prefiere el nombre ya resuelto por el botín (equipos con rareza, etc.);
			# si no viene, cae a resolver por id desde items.json.
			var id := str(g.get("id", ""))
			var nm := str(g.get("name", ""))
			if nm == "":
				nm = Design.get_item_name(id)
			var ic := Design.get_item_icon(id)
			if ic == "":
				ic = "📦"
			rows.append({"icon": ic, "text": "%s  x%d" % [nm, int(g.get("qty", 1))]})

	var w := clampf(get_viewport_rect().size.x * 0.6, 300.0, 520.0)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.03, 0.95)
	sb.border_color = Color(1.0, 0.82, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = 110.0
	panel.offset_bottom = 110.0
	panel.grow_vertical = Control.GROW_DIRECTION_END

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var lbl_head := Label.new()
	lbl_head.text = "🧰  " + Locale.pick({"es": "Cofre abierto", "en": "Chest opened"})
	lbl_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_head.add_theme_font_size_override("font_size", 18)
	lbl_head.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	vb.add_child(lbl_head)

	if rows.is_empty():
		var lbl_empty := Label.new()
		lbl_empty.text = Locale.pick({"es": "El cofre está vacío", "en": "The chest is empty"})
		lbl_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_empty.add_theme_font_size_override("font_size", 15)
		lbl_empty.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
		vb.add_child(lbl_empty)
	else:
		for r in rows:
			var row := Label.new()
			row.text = "%s  %s" % [str(r.get("icon", "")), str(r.get("text", ""))]
			row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_theme_font_size_override("font_size", 17)
			row.add_theme_color_override("font_color", Color(0.97, 0.94, 0.82))
			vb.add_child(row)

	add_child(panel)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


## El jugador entra o pisa una casilla con cinemática asignada.
func _on_dungeon_cinematic_entered(body: Node, marker: Node = null) -> void:
	if body.name != "player" or marker == null or not is_instance_valid(marker):
		return
	var trigger_on_step: bool = bool(marker.get_meta("trigger_on_step")) if marker.has_meta("trigger_on_step") else true
	if not trigger_on_step:
		return
	_trigger_dungeon_cinematic(marker)


func _trigger_dungeon_cinematic(marker: Node) -> void:
	if marker == null or not is_instance_valid(marker):
		return
	var cine_id := str(marker.get_meta("cinematic_id")) if marker.has_meta("cinematic_id") else ""
	if cine_id == "":
		return
	var once: bool = bool(marker.get_meta("once")) if marker.has_meta("once") else false
	var coord: Vector2i = marker.get_meta("cell_coord") if marker.has_meta("cell_coord") else Vector2i.ZERO
	var floor_idx: int = int(marker.get_meta("floor_index")) if marker.has_meta("floor_index") else _current_floor
	var flag_key := "cine_dun_%s_%d_%d_%d_%s" % [_dungeon_id, floor_idx, coord.x, coord.y, cine_id]
	if once and GlobalState.has_world_flag(flag_key):
		return
	if once:
		GlobalState.set_world_flag(flag_key, true)
		if marker is Area3D:
			marker.set_deferred("monitoring", false)
			var tw := marker.create_tween()
			tw.tween_property(marker, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(marker.queue_free)
	QuestManager.play_cinematic(cine_id)


## El jugador pisa un teletransporte interno: lo mueve a la casilla destino {f,x,y}
## dentro de la misma mazmorra. Un cooldown evita el rebote inmediato al aterrizar.
func _on_teleport_entered(body: Node, pad: Node = null) -> void:
	if body.name != "player" or pad == null or not is_instance_valid(pad):
		return
	if pad.is_in_group("boss_teleport") and not GlobalState.is_boss_defeated(_boss_key()):
		return
	if Time.get_ticks_msec() < _tp_cooldown_until:
		return
	var dest = pad.get_meta("tp_to") if pad.has_meta("tp_to") else null
	if not (dest is Dictionary):
		return
	if dest.has("dungeon"):
		var next_dun_id := str(dest.get("dungeon", ""))
		var next_spawn := {
			"f": int(dest.get("f", 0)),
			"x": int(dest.get("x", 0)),
			"y": int(dest.get("y", 0))
		}
		var meta = Design.ids.get(next_dun_id, {})
		var next_name = meta.get("name", "") if meta is Dictionary else ""
		_tp_cooldown_until = Time.get_ticks_msec() + 2000
		AudioManager.play_sfx("click")
		var dun_origin_pos: Vector3 = pad.global_position if pad is Node3D else _player_instance.position
		WorldFx.burst(_stage_instance, dun_origin_pos, Color(0.65, 0.45, 1.0), 16)
		WorldFx.glow_flash(_stage_instance, dun_origin_pos, Color(0.65, 0.45, 1.0), 4.0, 0.45)
		Juice.transition(func() -> void:
			await setup({
				"event_id": next_dun_id,
				"name": next_name,
				"spawn": next_spawn
			})
		)
		return
	var grid: GridDungeonStage = _stage_instance as GridDungeonStage
	if grid == null or not is_instance_valid(_player_instance):
		return
	var dest_floor := int(dest.get("f", 0))
	var pos: Vector3 = grid.cell_to_world(dest_floor, int(dest.get("x", 0)), int(dest.get("y", 0)))
	# (Pulido de mazmorras): el teletransporte solo tenía sonido —
	# ahora también un destello + partículas en el origen y en el destino.
	var origin_pos: Vector3 = pad.global_position if pad is Node3D else _player_instance.position
	WorldFx.burst(_stage_instance, origin_pos, Color(0.55, 0.85, 1.0), 12)
	WorldFx.glow_flash(_stage_instance, origin_pos, Color(0.55, 0.85, 1.0), 3.0, 0.35)
	_player_instance.position = pos
	WorldFx.glow_flash(_stage_instance, pos, Color(0.55, 0.85, 1.0), 3.0, 0.4)
	WorldFx.burst(_stage_instance, pos, Color(0.7, 0.9, 1.0), 12)
	_tp_cooldown_until = Time.get_ticks_msec() + 800
	AudioManager.play_sfx("click")
	# Escalera a otra planta: purgar elementos temporales de la planta anterior y refrescar minimapa.
	if dest_floor != _current_floor:
		purge_dungeon_temp_elements(get_tree())
		_current_floor = dest_floor
		_setup_minimap_floor(_current_floor)


func _on_player_died(cause: String = "") -> void:
	stop_exploration()
	_clean_up_3d()
	var event_id := str(_cell_data.get("event_id", ""))
	if event_id == "dun_inicial":
		_show_prologue_game_over()
	else:
		GlobalState.pending_death_cause = {"cause": "hazard", "hazard_type": cause}
		SceneManager.end_combat(false)


func _show_prologue_game_over() -> void:
	if AudioManager != null:
		AudioManager.play_sfx("defeat")

	# Ocultar la UI anterior para que no se solape
	if has_node("VBox"):
		(get_node("VBox") as CanvasItem).visible = false
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false

	# Crear capa superior dedicada (CanvasLayer)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var game_over_panel := Control.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(game_over_panel)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.05, 1.0)
	game_over_panel.add_child(bg)

	var title_lbl := Label.new()
	title_lbl.text = "GAME OVER"
	title_lbl.add_theme_font_size_override("font_size", 120)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_lbl.offset_top = -420
	title_lbl.offset_bottom = -220
	game_over_panel.add_child(title_lbl)

	var dialog_box := PanelContainer.new()
	dialog_box.add_theme_stylebox_override("panel", UiKit.panel(Color(0.08, 0.08, 0.12, 0.96), Color(0.9, 0.2, 0.2, 0.95), 24, 3))
	dialog_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialog_box.offset_left = 32
	dialog_box.offset_right = -32
	dialog_box.offset_bottom = -50
	dialog_box.offset_top = -660
	game_over_panel.add_child(dialog_box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	var m := UiKit.margins(32, 32, 28, 28)
	m.add_child(vbox)
	dialog_box.add_child(m)

	var sphere_lbl := Label.new()
	sphere_lbl.text = "🔮 Esfera de la Verdad"
	sphere_lbl.add_theme_font_size_override("font_size", 38)
	sphere_lbl.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	vbox.add_child(sphere_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = Locale.pick({
		"es": "¿En serio?\nEn fin... Muriendo incluso antes de empezar...\nMira... paso de ti.",
		"en": "Seriously?\nOh well... Dying before even starting...\nLook... I'm out."
	})
	msg_lbl.add_theme_font_size_override("font_size", 44)
	msg_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(msg_lbl)

	var btn_restart := Button.new()
	btn_restart.text = Locale.pick({"es": "🔄  Volver a empezar", "en": "🔄  Start over"})
	btn_restart.custom_minimum_size = Vector2(440, 100)
	btn_restart.add_theme_font_size_override("font_size", 38)
	btn_restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "hover", "pressed", "focus"]:
		btn_restart.add_theme_stylebox_override(st, UiKit.button_primary(20))
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn_restart.add_theme_color_override(col, UiKit.BG_DEEP)
	btn_restart.pressed.connect(func() -> void:
		if AudioManager != null:
			AudioManager.play_sfx("main_menu_click")
		if SceneManager != null:
			SceneManager.go_to_menu()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu/MainMenu.tscn")
	)
	vbox.add_child(btn_restart)


# ══════════════════════════════════════════════════════════════════════════════
# FEEDBACK DE PELIGROS (viñeta de daño + tinte de agua + sonido + vibración)
# ══════════════════════════════════════════════════════════════════════════════

## Pulso rojo + sonido + vibración al recibir daño de lava/pinchos.
func _on_player_took_damage(cause: String) -> void:
	if _hazard_overlay == null:
		return
	AudioManager.play_sfx("hit")
	Input.vibrate_handheld(120)
	# Pinchos y llamas castigan más fuerte que un tick de lava (cámara + viñeta + empuje).
	var peak: float = 0.45 if (cause == "spikes" or cause == "flame") else 0.30
	var shake_amount: float = 0.20 if (cause == "spikes" or cause == "flame") else 0.12
	if _player_instance != null and is_instance_valid(_player_instance):
		Juice.shake(_player_instance, shake_amount, 0.32 if (cause == "spikes" or cause == "flame") else 0.24)
	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()
	_hazard_overlay.color = Color(0.8, 0.05, 0.05, peak)
	_damage_tween = create_tween()
	_damage_tween.tween_property(_hazard_overlay, "color", _rest_overlay_color(), 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## Tinte azul tenue persistente mientras el jugador está en el agua.
func _on_player_water_changed(_in_water: bool) -> void:
	if _hazard_overlay == null:
		return
	if _damage_tween and _damage_tween.is_valid():
		_damage_tween.kill()
	_damage_tween = create_tween()
	_damage_tween.tween_property(_hazard_overlay, "color", _rest_overlay_color(), 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## Color de reposo de la viñeta: azul tenue si el jugador está en agua, si no transparente.
func _rest_overlay_color() -> Color:
	if _player_instance and is_instance_valid(_player_instance) and _player_instance.is_in_water:
		return Color(0.10, 0.35, 0.75, 0.22)
	return Color(0.8, 0.05, 0.05, 0.0)


var _active_checkpoint_pos: Vector3 = Vector3.ZERO

## Activa un altar de descanso (checkpoint) dentro de la mazmorra.
func set_active_checkpoint(pos: Vector3) -> void:
	_active_checkpoint_pos = pos
	GlobalState.hp = min(GlobalState.max_hp, GlobalState.hp + int(GlobalState.max_hp * 0.5))
	GlobalState.mp = GlobalState.max_mp
	GlobalState.state_updated.emit()
	AudioManager.play_sfx("heal")
	UiKit.toast(self, "✨ ¡Altar de Descanso Activado!", Color(0.2, 0.9, 0.7))


# ══════════════════════════════════════════════════════════════════════════════
# MECÁNICA DUN_NIEVES: DESORIENTACIÓN EN LA VENTISCA BLANCA
# ══════════════════════════════════════════════════════════════════════════════
## Registra las posiciones de cuadrícula de todas las paredes con textura de nieve
## en la planta actual de dun_nieves.
func _cache_snow_walls() -> void:
	_snow_walls_coords.clear()
	if not _is_snow_dungeon:
		return
	var floors: Array = _dungeon.get("floors", [])
	if _current_floor < 0 or _current_floor >= floors.size():
		return
	var fl: Dictionary = floors[_current_floor]
	var cells: Array = fl.get("cells", [])
	var default_wall_tex: String = str(_dungeon.get("tex_wall", ""))
	for y in range(cells.size()):
		var row: Array = cells[y]
		for x in range(row.size()):
			var c = row[x]
			if c is Dictionary and str(c.get("t", "")) == "wall":
				var w_tex: String = str(c.get("wall", default_wall_tex))
				if "snow_wall" in w_tex:
					_snow_walls_coords.append(Vector2i(x, y))


## Comprueba si el jugador se ha alejado más de 5 casillas de cualquier pared de nieve.
func _check_snow_dungeon_lost() -> void:
	if _player_instance == null or _stage_instance == null or _snow_walls_coords.is_empty():
		return

	var cell_sz: float = float(_dungeon.get("cell_size", 4.0))
	var player_pos: Vector3 = _player_instance.global_position
	var gx: float = player_pos.x / cell_sz
	var gy: float = player_pos.z / cell_sz

	# Límite de 5 casillas: comprobamos si hay alguna pared de nieve a una distancia
	# euclídea <= 5.2 casillas del jugador (permitiendo un margen de tolerancia al borde).
	var max_dist_cells: float = 5.2
	var max_dist_sq: float = max_dist_cells * max_dist_cells

	var has_snow_wall_nearby: bool = false
	for w in _snow_walls_coords:
		var dx: float = gx - float(w.x)
		var dy: float = gy - float(w.y)
		var dist_sq: float = dx * dx + dy * dy
		if dist_sq <= max_dist_sq:
			has_snow_wall_nearby = true
			break

	if not has_snow_wall_nearby:
		_trigger_snow_lost()


## Se dispara al perderse en la ventisca: la pantalla se difumina en blanco con
## sonido de niebla, devuelve al jugador al inicio y la Esfera muestra el mensaje.
func _trigger_snow_lost() -> void:
	if _snow_lost_in_progress or not _is_active:
		return
	_snow_lost_in_progress = true

	# 1. Bloquear controles del jugador y detener movimiento
	if _player_instance != null:
		_player_instance.velocity = Vector3.ZERO
		_player_instance.is_active = false
	_left_joy_vec = Vector2.ZERO
	_right_joy_vec = Vector2.ZERO

	# 2. Sonido envolvente de niebla / ventisca helada
	if _snow_sound_player != null:
		_snow_sound_player.volume_db = -24.0
		_snow_sound_player.play()
		var snd_tween := create_tween()
		snd_tween.tween_property(_snow_sound_player, "volume_db", 0.0, 1.2).set_trans(Tween.TRANS_QUAD)

	# 3. Pantalla difuminada blanco (fade in a blanco absoluto)
	if _snow_mist_overlay == null:
		_build_snow_mist_overlay()
	_snow_mist_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	var fade_tween := create_tween()
	fade_tween.tween_property(_snow_mist_overlay, "color:a", 1.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	fade_tween.tween_callback(func() -> void:
		if not is_instance_valid(self) or not _is_active:
			return

		# 4. Reaparición en el punto de comienzo de la mazmorra
		if _player_instance != null:
			_player_instance.global_position = _dungeon_entry_spawn_pos
			_player_instance.velocity = Vector3.ZERO
			_player_instance.rotation = Vector3.ZERO
			var head := _player_instance.get_node_or_null("head")
			if head != null:
				head.rotation = Vector3.ZERO
		_current_floor = _dungeon_entry_floor
		_cache_snow_walls()
		if _minimap != null and _player_instance != null:
			_minimap.update_player(_player_instance.global_position, Vector2.UP)

		# Breve pausa inmersiva envuelto en blanco
		get_tree().create_timer(0.4).timeout.connect(func() -> void:
			if not is_instance_valid(self) or not _is_active:
				return

			# 5. Desvanecer el blanco y calmar el sonido
			var reveal_tween := create_tween()
			reveal_tween.tween_property(_snow_mist_overlay, "color:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
			if _snow_sound_player != null:
				var snd_out := create_tween()
				snd_out.tween_property(_snow_sound_player, "volume_db", -36.0, 0.9)
				snd_out.tween_callback(_snow_sound_player.stop)

			reveal_tween.tween_callback(func() -> void:
				if not is_instance_valid(self) or not _is_active:
					return
				if _player_instance != null:
					_player_instance.is_active = true
				_snow_lost_in_progress = false
				_snow_lost_cooldown = 2.5

				# 6. Mensaje en grande de la Esfera
				if OrbBarksManager != null:
					OrbBarksManager.trigger_important_message(
						Locale.pick({
							"es": "Parece que te perdiste, anda te devuelvo a la entrada.",
							"en": "Looks like you got lost, come on, I'll return you to the entrance."
						})
					)
			)
		)
	)


## Oculta cualquier botón de mapamundi flotante en la UI mientras se explora la mazmorra.
func _hide_world_map_button() -> void:
	var world_view = get_tree().get_first_node_in_group("world_3d")
	if world_view != null and world_view.has_method("hide_clock_and_map"):
		world_view.call("hide_clock_and_map")


# ══════════════════════════════════════════════════════════════════════════════
# EVENTO DEL SALÓN DE LOS RECUERDOS (dun_final_6)
# ══════════════════════════════════════════════════════════════════════════════

var _memory_procession_active: bool = false
var _active_sphere_discourse_advance: Callable = Callable()

func _unhandled_input(event: InputEvent) -> void:
	if _active_sphere_discourse_advance.is_valid():
		if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E)):
			_active_sphere_discourse_advance.call()
			get_viewport().set_input_as_handled()


func _setup_dun_final_6_event() -> void:
	if _dungeon_id != "dun_final_6":
		return

	var grid: GridDungeonStage = _stage_instance as GridDungeonStage
	if grid == null:
		return

	# Si el puente ya fue abierto previamente, construirlo de inmediato sin evento
	if GlobalState.has_world_flag("dun_final_6_bridge_open"):
		_build_memory_bridge(true)
		return

	# Crear trigger en y=25 para iniciar la procesión al avanzar por el pasillo
	var trigger := Area3D.new()
	trigger.name = "MemoryTrigger"
	trigger.collision_mask = 2
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(grid._cell * 5.0, 3.0, grid._cell * 2.0)
	col.shape = box
	trigger.add_child(col)
	trigger.position = grid.cell_to_world(0, 10, 25) + Vector3(0, 1.0, 0)
	_stage_instance.add_child(trigger)

	trigger.body_entered.connect(func(body: Node) -> void:
		if body.name == "player" and not _memory_procession_active and not GlobalState.has_world_flag("dun_final_6_bridge_open"):
			_memory_procession_active = true
			trigger.queue_free()
			_start_memory_procession_sequence()
	)


func _start_memory_procession_sequence() -> void:
	var grid: GridDungeonStage = _stage_instance as GridDungeonStage
	if grid == null or _player_instance == null:
		return

	stop_exploration()

	# Orientar suavemente la vista hacia el Norte (hacia el abismo y el jefe)
	if _player_instance is Node3D:
		var tw_rot := create_tween()
		tw_rot.tween_property(_player_instance as Node3D, "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)

	var memories := _collect_all_npc_memories()

	var left_x: float = grid.cell_to_world(0, 6, 0).x
	var right_x: float = grid.cell_to_world(0, 14, 0).x
	var start_z: float = grid.cell_to_world(0, 0, 14).z
	var end_z: float = grid.cell_to_world(0, 0, 28).z
	var float_y: float = 1.6

	var spawn_timer := Timer.new()
	spawn_timer.wait_time = 1.1
	spawn_timer.one_shot = false
	add_child(spawn_timer)

	var mem_idx: Array[int] = [0]
	var is_left: Array[bool] = [true]
	spawn_timer.timeout.connect(func() -> void:
		if not is_instance_valid(_stage_instance) or not _memory_procession_active or memories.is_empty():
			spawn_timer.stop()
			spawn_timer.queue_free()
			return

		var npc_info = memories[mem_idx[0] % memories.size()]
		mem_idx[0] += 1
		var cur_x := left_x if is_left[0] else right_x
		is_left[0] = not is_left[0]

		var start_p := Vector3(cur_x, float_y, start_z)
		var end_p := Vector3(cur_x, float_y, end_z)
		_spawn_avatar_memory_node(npc_info, start_p, end_p, 9.5)
	)
	spawn_timer.start()

	var discourse: Array[Dictionary] = [
		{
			"es": "¿Los reconoces...? Cada rostro, cada voz que cruzó tu sendero en este viaje...",
			"en": "Do you recognize them...? Every face, every voice that crossed your path in this journey..."
		},
		{
			"es": "No eran meras sombras en el tapiz de la memoria. Fueron los testigos de tus elecciones, el eco de tus dudas...",
			"en": "They were not mere shadows in the tapestry of memory. They were the witnesses of your choices, the echo of your doubts..."
		},
		{
			"es": "...y la prueba viviente de que aún atrapado en la ilusión, algo en ti buscaba la verdad.",
			"en": "...and the living proof that even trapped in illusion, something inside you was seeking the truth."
		},
		{
			"es": "Ahora el velo se rasga. Solo queda un último guardián entre tú y el despertar.",
			"en": "Now the veil tears open. Only one final guardian stands between you and the awakening."
		}
	]

	_show_sphere_discourse(discourse, func() -> void:
		_build_memory_bridge(false)
		GlobalState.set_world_flag("dun_final_6_bridge_open", true)
		_memory_procession_active = false
		get_tree().create_timer(2.2).timeout.connect(func() -> void:
			resume_exploration()
		)
	)


func _collect_all_npc_memories() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}

	# Catálogo canónico de personajes con arte VN oficial (res://assets/vn/npcs/)
	var catalog: Array[Dictionary] = [
		{ "file": "npc_city_sylphrena_mara.png", "es": "Mara de Sylphrena", "en": "Mara of Sylphrena" },
		{ "file": "npc_city_sylphrena_herrero.png", "es": "Herrero de Sylphrena", "en": "Sylphrena Blacksmith" },
		{ "file": "npc_city_sylphrena_church.png", "es": "Sacerdotisa de Sylphrena", "en": "Sylphrena Priestess" },
		{ "file": "npc_city_sylphrena_aldeano.png", "es": "Aldeano de Sylphrena", "en": "Sylphrena Villager" },
		{ "file": "npc_city_sylphrena_shop.png", "es": "Mercader de Sylphrena", "en": "Sylphrena Merchant" },
		{ "file": "npc_city_sylphrena_taberna.png", "es": "Tabernero de Sylphrena", "en": "Sylphrena Barkeep" },
		{ "file": "npc_city_celestia_archmage.png", "es": "Archimago de Celestia", "en": "Archmage of Celestia" },
		{ "file": "npc_city_celestia_sage.png", "es": "Sabia de Celestia", "en": "Sage of Celestia" },
		{ "file": "npc_city_celestia_crier.png", "es": "Pregonero de Celestia", "en": "Celestia Town Crier" },
		{ "file": "npc_city_celestia_palace.png", "es": "Guardia del Palacio", "en": "Palace Royal Guard" },
		{ "file": "npc_city_celestia_shop.png", "es": "Mercader de Celestia", "en": "Celestia Merchant" },
		{ "file": "npc_city_celestia_taberna.png", "es": "Tabernero de Celestia", "en": "Celestia Barkeep" },
		{ "file": "npc_city_gloriam_oasis.png", "es": "Nómada del Oasis", "en": "Oasis Nomad" },
		{ "file": "npc_city_gloriam_residencia.png", "es": "Erudita de Gloriam", "en": "Scholar of Gloriam" },
		{ "file": "npc_city_gloriam_shop.png", "es": "Bazar de Gloriam", "en": "Gloriam Bazaar Trader" },
		{ "file": "npc_city_gloriam_taberna.png", "es": "Tabernero de Gloriam", "en": "Gloriam Barkeep" },
		{ "file": "npc_city_arcanum_lab.png", "es": "Investigador del Laboratorio", "en": "Lab Researcher" },
		{ "file": "npc_city_arcanum_chatarra.png", "es": "Chatarrero de Arcanum", "en": "Arcanum Scavenger" },
		{ "file": "npc_city_arcanum_refugio.png", "es": "Refugiado de Arcanum", "en": "Arcanum Refugee" },
		{ "file": "npc_city_arcanum_shop.png", "es": "Armero Arcano", "en": "Arcane Weaponsmith" },
		{ "file": "npc_city_arcanum_taberna.png", "es": "Cantinero de Arcanum", "en": "Arcanum Barkeep" },
		{ "file": "npc_temple_guerrero.png", "es": "Maestro Guerrero", "en": "Warrior Master" },
		{ "file": "npc_temple_arquero.png", "es": "Maestra Arquera", "en": "Archer Master" },
		{ "file": "npc_temple_sacerdote.png", "es": "Sumo Sacerdote", "en": "High Priest" },
		{ "file": "npc_temple_elementalista.png", "es": "Elementalista Ancestral", "en": "Ancestral Elementalist" },
		{ "file": "npc_temple_tiempo.png", "es": "Cronoturgo del Templo", "en": "Chronoturge" },
		{ "file": "npc_temple_psiquico.png", "es": "Místico Psíquico", "en": "Psychic Mystic" },
		{ "file": "npc_temple_guardian.png", "es": "Guardián de los Senderos", "en": "Guardian of the Paths" },
		{ "file": "npc_world_poi_pradera_cantero_01.png", "es": "Cantero de la Pradera", "en": "Meadow Stonemason" },
		{ "file": "npc_world_poi_pradera_hombre_sombreros.png", "es": "Hombre de los Sombreros", "en": "Man of Hats" },
		{ "file": "npc_world_poi_pradera_mimo_atrapado.png", "es": "Mimo Atrapado", "en": "Trapped Mime" },
		{ "file": "npc_world_poi_pradera_pollo_mistico.png", "es": "Pollo Místico", "en": "Mystic Chicken" },
		{ "file": "npc_world_poi_pradera_puente_mono.png", "es": "Sabio del Puente Mono", "en": "Monkey Bridge Sage" },
		{ "file": "npc_world_poi_pradera_vendedor_aire.png", "es": "Vendedor de Aire", "en": "Air Salesman" },
		{ "file": "npc_world_poi_yelmo_anciana.png", "es": "Anciana del Yelmo", "en": "Elder of the Helm" },
		{ "file": "npc_world_poi_yelmo_recluso.png", "es": "Recluso del Yelmo", "en": "Hermit of the Helm" },
		{ "file": "npc_world_poi_hielo_campana_03.png", "es": "Vigía de las Campanas", "en": "Belfry Watcher" },
		{ "file": "npc_world_poi_hielo_caravana_02.png", "es": "Mercader de la Nieve", "en": "Snow Merchant" },
		{ "file": "npc_world_poi_hielo_refugio_01.png", "es": "Guardián del Refugio", "en": "Shelter Warden" },
		{ "file": "npc_world_poi_celestia_puerto.png", "es": "Capitán del Puerto", "en": "Harbor Captain" },
		{ "file": "npc_world_poi_celestia_tumba_elara.png", "es": "Espíritu de Elara", "en": "Spirit of Elara" },
		{ "file": "npc_world_poi_gloriam_entrenador_caracoles.png", "es": "Entrenador de Caracoles", "en": "Snail Trainer" },
		{ "file": "npc_world_poi_gloriam_puesto_desierto.png", "es": "Vigía de las Arenas", "en": "Dune Scout" },
		{ "file": "npc_centinela_automata.png", "es": "Centinela Arcano", "en": "Arcane Sentinel" },
		{ "file": "npc_world_poi_arcanum_dragon_furioso.png", "es": "Dragón Ancestral", "en": "Ancient Dragon" },
		{ "file": "npc_world_poi_arcanum_huevo_dragon.png", "es": "Custodio del Nido", "en": "Nest Custodian" },
		{ "file": "npc_gaviota.png", "es": "Gaviota Sabia", "en": "Wise Seagull" }
	]

	for item in catalog:
		var file_path := "res://assets/vn/npcs/" + str(item.file)
		if ResourceLoader.exists(file_path):
			seen[item.file] = true
			result.append({
				"id": str(item.file).get_basename(),
				"name": { "es": item.es, "en": item.en },
				"texture_path": file_path
			})

	# Descubrimiento dinámico de cualquier archivo PNG adicional en assets/vn/npcs
	var dir := DirAccess.open("res://assets/vn/npcs")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png") and not seen.has(file_name) and file_name != "npc_default.png":
				var full_path := "res://assets/vn/npcs/" + file_name
				var base_name := file_name.get_basename().replace("npc_", "").replace("city_", "").replace("world_poi_", "").replace("_", " ").capitalize()
				seen[file_name] = true
				result.append({
					"id": file_name.get_basename(),
					"name": base_name,
					"texture_path": full_path
				})
			file_name = dir.get_next()
		dir.list_dir_end()

	result.shuffle()
	return result


func _spawn_avatar_memory_node(npc_data: Dictionary, start_pos: Vector3, end_pos: Vector3, duration: float) -> void:
	if _stage_instance == null or not is_instance_valid(_stage_instance):
		return

	var root := Node3D.new()
	root.position = start_pos
	_stage_instance.add_child(root)

	var tex_path: String = str(npc_data.get("texture_path", ""))
	if tex_path == "" or not ResourceLoader.exists(tex_path):
		tex_path = "res://assets/vn/npcs/npc_city_sylphrena_mara.png"

	var tex = load(tex_path) as Texture2D
	if tex != null:
		var spr := Sprite3D.new()
		spr.texture = tex
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.transparent = true
		spr.pixel_size = 0.0034
		spr.modulate = Color(0.92, 0.96, 1.0, 0.95)
		spr.position = Vector3(0, 0, 0)
		root.add_child(spr)

		# Animación de suave flotación vertical
		var tw_float := spr.create_tween().set_loops()
		tw_float.tween_property(spr, "position:y", 0.12, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_float.tween_property(spr, "position:y", -0.12, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Anillo etéreo de luz en la base
	var ring := MeshInstance3D.new()
	var t_mesh := TorusMesh.new()
	t_mesh.inner_radius = 0.55
	t_mesh.outer_radius = 0.85
	ring.mesh = t_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(0.25, 0.75, 1.0, 0.55)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.2, 0.75, 1.0)
	ring_mat.emission_energy_multiplier = 2.4
	ring.material_override = ring_mat
	ring.position = Vector3(0, -1.35, 0)
	root.add_child(ring)

	# Luz mística que ilumina los bordes del avatar
	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 0.8, 1.0)
	light.light_energy = 0.75
	light.omni_range = 3.5
	root.add_child(light)

	# Nombre del personaje en oro etéreo con contorno nítido
	var raw_name = npc_data.get("name", "")
	var npc_name: String = Locale.pick(raw_name) if raw_name is Dictionary else str(raw_name)
	if npc_name == "":
		npc_name = str(npc_data.get("id", ""))

	var name_lbl := Label3D.new()
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.text = npc_name
	name_lbl.font_size = 28
	name_lbl.outline_size = 5
	name_lbl.position = Vector3(0, -1.55, 0)
	name_lbl.outline_modulate = Color(0.02, 0.05, 0.1, 0.95)
	name_lbl.modulate = Color(1.0, 0.9, 0.65)
	root.add_child(name_lbl)

	# Aparición, desplazamiento por el pasillo y desvanecimiento final
	root.scale = Vector3.ZERO
	var tw_in := root.create_tween()
	tw_in.tween_property(root, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var tw_pos := root.create_tween()
	tw_pos.tween_property(root, "position:z", end_pos.z, duration).set_trans(Tween.TRANS_LINEAR)

	var tw_out := root.create_tween()
	tw_out.tween_interval(maxf(0.1, duration - 1.6))
	tw_out.tween_property(root, "scale", Vector3.ZERO, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw_out.tween_callback(func() -> void:
		if is_instance_valid(root):
			root.queue_free()
	)


func _show_sphere_discourse(lines: Array[Dictionary], on_finished: Callable) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 120
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(root)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -215
	panel.offset_bottom = -32
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var update_responsive := func() -> void:
		if not is_instance_valid(root) or not is_instance_valid(panel):
			return
		var vp_w: float = root.get_viewport_rect().size.x
		var target_w: float = minf(940.0, maxf(320.0, vp_w - 64.0))
		panel.offset_left = -target_w * 0.5
		panel.offset_right = target_w * 0.5
	root.resized.connect(update_responsive)
	update_responsive.call()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.12, 0.94)
	style.border_color = Color(0.3, 0.85, 1.0, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0.1, 0.5, 0.9, 0.35)
	style.shadow_size = 14
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	panel.add_child(hbox)

	var orb_icon := Label.new()
	orb_icon.text = "🔮"
	orb_icon.add_theme_font_size_override("font_size", 42)
	orb_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(orb_icon)

	var tw_orb := orb_icon.create_tween().set_loops()
	tw_orb.tween_property(orb_icon, "modulate", Color(0.55, 0.9, 1.0, 1.0), 1.3).set_trans(Tween.TRANS_SINE)
	tw_orb.tween_property(orb_icon, "modulate", Color(1.0, 1.0, 1.0, 0.8), 1.3).set_trans(Tween.TRANS_SINE)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(vbox)

	var row_top := HBoxContainer.new()
	vbox.add_child(row_top)

	var title := Label.new()
	title.text = Locale.pick({"es": "La Esfera de la Verdad", "en": "The Sphere of Truth"})
	title.add_theme_color_override("font_color", Color(0.4, 0.88, 1.0))
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_top.add_child(title)

	var counter_lbl := Label.new()
	counter_lbl.text = "1 / %d" % lines.size()
	counter_lbl.add_theme_color_override("font_color", Color(0.55, 0.72, 0.88))
	counter_lbl.add_theme_font_size_override("font_size", 14)
	row_top.add_child(counter_lbl)

	var msg := Label.new()
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 17)
	msg.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(msg)

	var row_bottom := HBoxContainer.new()
	row_bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(row_bottom)

	var hint_lbl := Label.new()
	hint_lbl.text = Locale.pick({
		"es": "Espacio / Clic para avanzar",
		"en": "Space / Click to advance"
	})
	hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.85, 0.75))
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_bottom.add_child(hint_lbl)

	var btn_cont := Button.new()
	btn_cont.text = Locale.pick({"es": "Continuar ▶", "en": "Continue ▶"})
	btn_cont.custom_minimum_size = Vector2(130, 32)
	row_bottom.add_child(btn_cont)

	var current_idx: Array[int] = [0]
	var is_typing: Array[bool] = [false]
	var typing_tween: Array[Tween] = [null]
	var advance_action: Array[Callable] = []

	var show_current_line = func(idx: int) -> void:
		if idx >= lines.size():
			_active_sphere_discourse_advance = Callable()
			if typing_tween[0] != null and typing_tween[0].is_valid():
				typing_tween[0].kill()
			if tw_orb != null and tw_orb.is_valid():
				tw_orb.kill()
			var tw_exit := create_tween()
			tw_exit.tween_property(panel, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
			tw_exit.tween_callback(func() -> void:
				if is_instance_valid(canvas):
					canvas.queue_free()
				on_finished.call()
			)
			return

		counter_lbl.text = "%d / %d" % [idx + 1, lines.size()]
		var full_text: String = Locale.pick(lines[idx])
		msg.text = full_text
		msg.visible_ratio = 0.0
		is_typing[0] = true
		btn_cont.text = Locale.pick({"es": "Saltar ⏭", "en": "Skip ⏭"})

		if typing_tween[0] != null and typing_tween[0].is_valid():
			typing_tween[0].kill()

		AudioManager.play_sfx("click")

		# Máquina de escribir poco a poco (~38 caracteres por segundo)
		var duration: float = maxf(0.8, float(full_text.length()) / 38.0)
		var tw := create_tween()
		typing_tween[0] = tw
		tw.tween_property(msg, "visible_ratio", 1.0, duration).set_trans(Tween.TRANS_LINEAR)
		tw.finished.connect(func() -> void:
			is_typing[0] = false
			btn_cont.text = Locale.pick({"es": "Continuar ▶", "en": "Continue ▶"})
		)

	var do_advance = func() -> void:
		if is_typing[0]:
			# Revelar texto de inmediato al pulsar mientras escribe
			if typing_tween[0] != null and typing_tween[0].is_valid():
				typing_tween[0].kill()
			msg.visible_ratio = 1.0
			is_typing[0] = false
			btn_cont.text = Locale.pick({"es": "Continuar ▶", "en": "Continue ▶"})
			AudioManager.play_sfx("click")
		else:
			current_idx[0] += 1
			show_current_line.call(current_idx[0])

	advance_action.append(do_advance)
	_active_sphere_discourse_advance = do_advance

	btn_cont.pressed.connect(func() -> void:
		advance_action[0].call()
	)

	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			advance_action[0].call()
	)

	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			advance_action[0].call()
	)

	# Iniciar primera línea de diálogo
	show_current_line.call(0)


func _build_memory_bridge(instant: bool = false) -> void:
	var grid: GridDungeonStage = _stage_instance as GridDungeonStage
	if grid == null:
		return
	var bridge_root := _stage_instance.get_node_or_null("MemoryBridge") as Node3D
	if bridge_root != null and is_instance_valid(bridge_root):
		return
	bridge_root = Node3D.new()
	bridge_root.name = "MemoryBridge"
	_stage_instance.add_child(bridge_root)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.72, 1.0, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.8, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.roughness = 0.2

	var cell_size := grid._cell
	var slab_h: float = 0.2
	var rows: Array[int] = [16, 15, 14, 13, 12]
	for i in range(rows.size()):
		var ry: int = rows[i]
		var delay: float = 0.0 if instant else (float(i) * 0.22)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if not is_instance_valid(bridge_root):
				return
			if not instant:
				AudioManager.play_sfx("gather")
			for rx in [9, 10, 11]:
				var cx: float = float(rx) * cell_size
				var cz: float = float(ry) * cell_size
				var center_pos := Vector3(cx, -slab_h * 0.5, cz)

				var body := StaticBody3D.new()
				body.position = center_pos
				bridge_root.add_child(body)

				var slab := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(cell_size, slab_h, cell_size)
				slab.mesh = box
				slab.material_override = mat
				body.add_child(slab)

				var col := CollisionShape3D.new()
				var cbox := BoxShape3D.new()
				cbox.size = Vector3(cell_size, slab_h, cell_size)
				col.shape = cbox
				body.add_child(col)

				if not instant:
					WorldFx.burst(_stage_instance, Vector3(cx, 0.1, cz), Color(0.4, 0.85, 1.0), 8)
					WorldFx.glow_flash(_stage_instance, Vector3(cx, 0.1, cz), Color(0.4, 0.85, 1.0), 3.0, 0.35)
		)
