# GameRoot.gd
# Escena principal del juego — contiene HUD, ViewStack y TabBar.
# Escucha las señales de SceneManager para mostrar/ocultar vistas.
class_name GameRoot
extends Control

const TabWorld3DScript = preload("res://scenes/tabs/tab_world_3d/TabWorld3D.gd")

# ─── REFERENCIAS HUD ─────────────────────────────────────────────────────────
@onready var lbl_level: Label    = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxLeft/HBoxBaseLevel/LblLevel
@onready var lbl_base_name: Label = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxLeft/HBoxBaseLevel/LblBaseLevelName
@onready var lbl_job_level: Label = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxLeft/HBoxJobLevel/LblJobLevel
@onready var lbl_class: Label    = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxLeft/HBoxJobLevel/LblClass
var lbl_gold: Label = null       # creado por código, vive en _materials_box

@onready var bar_hp: ProgressBar = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxStats/BarHP
@onready var lbl_hp: Label       = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxStats/BarHP/LblHP
@onready var bar_mp: ProgressBar = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxStats/BarMP
@onready var lbl_mp: Label       = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxStats/BarMP/LblMP
@onready var bar_en: ProgressBar = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxStats/BarEN
@onready var lbl_en: Label       = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxStats/BarEN/LblEN
@onready var bar_xp: ProgressBar     = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxLeft/BarXP
@onready var bar_job_xp: ProgressBar = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxLeft/BarJobXP
@onready var vbox_stats: VBoxContainer = $VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD/VBoxStats

# Fila de iconos de materiales farmeables (madera, piedra, pescado…) bajo el maná.
var _materials_box: HBoxContainer = null
var _items_box: HBoxContainer = null

# ─── REFERENCIAS TAB BAR ─────────────────────────────────────────────────────
@onready var btn_world:     Button = $VBoxMain/PanelTabBar/HBoxTabs/BtnWorld
@onready var btn_character: Button = $VBoxMain/PanelTabBar/HBoxTabs/BtnCharacter
@onready var btn_bag:       Button = $VBoxMain/PanelTabBar/HBoxTabs/BtnBag
@onready var btn_info:      Button = $VBoxMain/PanelTabBar/HBoxTabs/BtnInfo
@onready var btn_opts:      Button = $VBoxMain/PanelTabBar/HBoxTabs/BtnOptions
@onready var panel_tab_bar: PanelContainer = $VBoxMain/PanelTabBar

# ─── REFERENCIAS STACK ───────────────────────────────────────────────────────
@onready var view_stack: Control         = $VBoxMain/ViewStack
@onready var panel_coming_soon: PanelContainer = $ComingSoonOverlay
@onready var lbl_cs_title: Label         = $ComingSoonOverlay/VBoxCS/LblCSTitle
@onready var passive_timer: Timer        = $PassiveTimer

var _radial_menu: RadialMenuOverlay = null

# ─── VISTAS DINÁMICAS ────────────────────────────────────────────────────────
var _views: Dictionary = {}        # Mapa view_name → nodo instanciado
var _active_view: String = "world"
var _city_data: Dictionary = {}    # Datos de la ciudad activa (para back)
var _menu_overlay: Control = null  # Overlay del menú/opciones en juego
var _previous_view_before_combat: String = "world"
# Si subes de nivel (personaje u oficio) DURANTE un combate, el toast
# discreto pasaba inadvertido (la vista de combate lo tapa y el jugador está
# mirando el resultado del combate, no el HUD). Se encolan aquí mientras
# `_active_view == "combat"` y se muestran justo al volver al mapa/mazmorra.
var _pending_levelup_toasts: Array = []
# (Game Feel §3): última HP/MP mostrada, para detectar cambios reales y
# dar un brillo sutil (rojo/verde) solo cuando de verdad suben o bajan, en vez
# de refrescar la barra en frío en cada `state_updated`. -1 = aún sin leer.
var _last_hud_hp: int = -1
var _last_hud_mp: int = -1
# (Game Feel §3/§10): pulso rojo persistente en la barra de HP del HUD
# cuando la vida entra en peligro (≤25%), coherente con el aviso del combate.
var _hud_hp_danger_tween: Tween = null
var _hud_hp_in_danger: bool = false
var _hero_avatar: TextureRect = null   # Avatar de profesión en el HUD
var _hero_avatar_lbl: Label = null
var _btn_radial_menu: Button = null   # Botón ☰ del HUD que abre el menú radial (esquina opuesta a la Esfera)
var _btn_floating_map: Button = null  # Botón 🗺️ del mundo, flotante justo a la izquierda del ☰ (mismo tamaño/forma)
var _hud_profession_modal: PanelContainer = null   # Selector de profesión activa (tarjeta HUD izquierda), igual que en combate
var _hud_professions_grid: GridContainer = null
var _save_indicator: Label = null   # Icono discreto de autoguardado
var _location_bar: PanelContainer = null  # Cabecera compartida "ubicación + volver"
var _location_lbl: Label = null
var _location_return_btn: Button = null
var _hud_center_label: Label = null   # Título de ubicación en el slot central del HUD
var _hud_redesigned: bool = false
var _hud_card_left: PanelContainer = null
var _hud_card_right: PanelContainer = null
var _hud_orb_slot: Control = null
var _hud_vbox_left: VBoxContainer = null
var _hud_hbox_base: HBoxContainer = null
var _hud_hbox_job: HBoxContainer = null

# ─── PELIGRO AMBIENTAL (insolación / congelación) ─────────────────────────────
var _hazard_panel: PanelContainer = null  # Barra bajo el HUD (solo en el mundo)
var _hazard_bar: ProgressBar = null
var _hazard_lbl: Label = null
var _hazard_value: float = 0.0            # 0..1 (1 = muerte)
var _hazard_kind: String = ""             # "heat" | "cold" | ""

# Preload de escenas
const SCENE_CITY      := preload("res://scenes/views/view_city/ViewCity.tscn")
const SCENE_BUILDING  := preload("res://scenes/views/view_building/ViewBuilding.tscn")
const SCENE_DUNGEON   := preload("res://scenes/views/view_dungeon/ViewDungeon.tscn")
const SCENE_COMBAT    := preload("res://scenes/views/view_combat/ViewCombat.tscn")
const SCENE_CHARACTER := preload("res://scenes/tabs/tab_character/TabCharacter.tscn")
const SCENE_BAG       := preload("res://scenes/tabs/tab_bag/TabBag.tscn")
const SCENE_GATHER    := preload("res://scenes/views/view_gather/ViewGather.tscn")
const SCENE_PLACE     := preload("res://scenes/views/view_place/ViewPlace.tscn")
const SCENE_COOK      := preload("res://scenes/views/view_cook/ViewCook.tscn")
const SCENE_TRAINING  := preload("res://scenes/views/view_training/ViewTraining.tscn")
const SCENE_SHOP      := preload("res://scenes/views/view_shop/ViewShop.tscn")
const OPTIONS_SCENE   := preload("res://scenes/ui/options/OptionsMenu.tscn")
const MAIN_MENU_PATH: String = "res://scenes/ui/main_menu/MainMenu.tscn"



# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	if SaveManager != null:
		SaveManager.active = true
	add_to_group("game_root")   # Permite que vistas hijas (mazmorra, etc.) lo localicen
	panel_tab_bar.visible = false
	_build_location_bar()
	_instantiate_views()
	_connect_signals()

	resized.connect(_update_responsive_layout)
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()

	# ── Estilo de los paneles del shell (HUD arriba, navegación abajo) ──
	var tab_bar_style := StyleBoxFlat.new()
	tab_bar_style.bg_color = UiKit.BG_DEEP
	tab_bar_style.border_width_top = 2
	tab_bar_style.border_color = UiKit.BORDER
	panel_tab_bar.add_theme_stylebox_override("panel", tab_bar_style)

	Locale.theme_changed.connect(_on_hud_theme_changed)

	# El botón flotante del menú radial debe ocultarse mientras el sistema
	# narrativo (SceneRunner/NarrativeOverlay o el presenter externo de
	# ViewPlace) tiene un diálogo en pantalla: en ViewPlace taparía el botón
	# "📖 Facetas y Relación" (misma esquina) y, con el mundo bloqueado por el
	# diálogo, tampoco tiene sentido abrir el menú.
	SceneRunner.scene_started.connect(func(_id: String) -> void: _update_radial_button_visibility())
	SceneRunner.scene_finished.connect(func(_id: String) -> void: _update_radial_button_visibility())

	if not GlobalState.seen_intro:
		if Design.has_cinematic("intro"):
			SceneRunner.scene_finished.connect(func(sc_id: String) -> void:
				if sc_id == "intro":
					_enter_orb_room("welcome")
			, CONNECT_ONE_SHOT)
			SceneRunner.start_scene("intro")
		else:
			_enter_orb_room("welcome")
	else:
		_show_view("world")
		_set_active_tab("world")


## Repinta en vivo el HUD superior común (tarjetas de nivel/esfera a la
## izquierda y HP/MP/oro a la derecha) cuando cambia el tema.
## Solo cambia el StyleBox de las tarjetas ya existentes (no reconstruye su
## contenido) para no arriesgar los `@onready`/referencias internas que
## `_setup_redesigned_hud()` cablea una sola vez al arrancar.
func _on_hud_theme_changed(_theme_id: String) -> void:
	var bg := UiKit.theme_color("panel_bg", UiKit.BG_BASE)
	for path in ["VBoxMain/PanelHUD/MarginHUD/VBoxHUDTop/HBoxTopColumns/CardHUDLeft", "VBoxMain/PanelHUD/MarginHUD/VBoxHUDTop/HBoxTopColumns/CardHUDRight"]:
		var card := get_node_or_null(path) as PanelContainer
		if card == null:
			continue
		UiKit.premium_frame(card, {"bg_color": bg, "corner_radius": 14.0, "pad": 0})
	if _btn_radial_menu != null:
		_style_floating_radial_button()
	if _btn_floating_map != null:
		_style_floating_map_button()


## Muestra/oculta la HUD superior (franja negra) y, con ella, recalcula la
## visibilidad del botón ☰ flotante del menú radial — vive fuera de
## `PanelHUD` (ver `_build_floating_radial_button`) así que su visibilidad ya
## no se sincroniza sola con la del panel y hay que hacerlo explícitamente
## aquí (ver `_update_radial_button_visibility`).
func _set_hud_panel_visible(v: bool) -> void:
	$VBoxMain/PanelHUD.visible = v
	_update_radial_button_visibility()


## Recalcula si el botón ☰ del menú radial debe verse: oculto en combate,
## Sala de la Esfera y mazmorras (ninguna tiene sentido para abrir el Hub
## desde ahí, y en mazmorras además no hay HUD superior), y también mientras
## el sistema narrativo (`SceneRunner`) tenga un diálogo activo (ver `_ready`).
func _update_radial_button_visibility() -> void:
	if _btn_radial_menu == null:
		return
	# "city"/"place"/"shop"/etc.: el botón radial queda oculto dentro de
	# ciudades, lugares, tiendas y modales para no superponerse con los botones de la vista.
	var hidden_views: Array[String] = ["combat", "orb_room", "dungeon", "city", "place", "shop", "building", "forge", "encargos", "transport", "training", "cook"]
	var narrative_active: bool = SceneRunner != null and SceneRunner.is_active()
	_btn_radial_menu.visible = not narrative_active and _active_view not in hidden_views


func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var is_landscape := sz.x > sz.y
	var panel_hud: Control = get_node_or_null("VBoxMain/PanelHUD") as Control
	var margin_hud: MarginContainer = get_node_or_null("VBoxMain/PanelHUD/MarginHUD") as MarginContainer

	if panel_hud != null:
		var empty_sb := StyleBoxEmpty.new()
		panel_hud.add_theme_stylebox_override("panel", empty_sb)

	if margin_hud != null:
		if is_landscape:
			margin_hud.add_theme_constant_override("margin_left", 14)
			margin_hud.add_theme_constant_override("margin_right", 14)
			margin_hud.add_theme_constant_override("margin_top", 8)
			margin_hud.add_theme_constant_override("margin_bottom", 4)
		else:
			margin_hud.add_theme_constant_override("margin_left", 14)
			margin_hud.add_theme_constant_override("margin_right", 14)
			margin_hud.add_theme_constant_override("margin_top", 10)
			margin_hud.add_theme_constant_override("margin_bottom", 10)

	# ── PanelTabBar (pestañas inferiores en esquina inferior izquierda) ──
	if panel_tab_bar != null:
		if is_landscape:
			panel_tab_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			panel_tab_bar.custom_minimum_size = Vector2(460, 48)
			var tab_sb := UiKit.panel(UiKit.BG_DEEP, UiKit.BORDER, 14, 2)
			tab_sb.shadow_color = Color(0, 0, 0, 0.45)
			tab_sb.shadow_size = 8
			panel_tab_bar.add_theme_stylebox_override("panel", tab_sb)
		else:
			panel_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel_tab_bar.custom_minimum_size = Vector2(0, 120)

	# ── Barras de HP/MP: fondo redondeado + relleno con brillo de energía ──
	for bar in [bar_hp, bar_mp]:
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = UiKit.BG_DEEP
		bg_style.set_corner_radius_all(10)
		bg_style.set_border_width_all(1)
		bg_style.border_color = UiKit.BORDER
		bar.add_theme_stylebox_override("background", bg_style)
		bar.custom_minimum_size = Vector2(280, 20)
	bar_hp.add_theme_stylebox_override("fill", UiKit.bar_fill(UiKit.HP, 10))
	bar_mp.add_theme_stylebox_override("fill", UiKit.bar_fill(UiKit.MP, 10))
	bar_xp.add_theme_stylebox_override("fill", UiKit.bar_fill(UiKit.XP, 6))
	bar_job_xp.add_theme_stylebox_override("fill", UiKit.bar_fill(UiKit.ACCENT, 6))

	# ── Avatar de héroe (profesión) a la izquierda del HUD ──
	if _hero_avatar == null:
		_hero_avatar = TextureRect.new()
		_hero_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_hero_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hero_avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_hero_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hero_avatar.custom_minimum_size = Vector2(44, 44)

	# ── Materiales farmeables ──
	if _materials_box == null:
		_materials_box = HBoxContainer.new()
		_materials_box.add_theme_constant_override("separation", 6)
		_materials_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

		_items_box = HBoxContainer.new()
		_items_box.add_theme_constant_override("separation", 6)
		_items_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_materials_box.add_child(_items_box)

		lbl_gold = Label.new()
		lbl_gold.text = "💰 0"
		lbl_gold.add_theme_font_size_override("font_size", 24)
		lbl_gold.add_theme_color_override("font_color", Color(0.97, 0.78, 0.26, 1.0))
		lbl_gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_redesigned_hud()

	# Indicador discreto de autoguardado (esquina inferior derecha, muy pequeño)
	if _save_indicator == null:
		_save_indicator = Label.new()
		_save_indicator.text = "💾"
		_save_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_save_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_save_indicator.add_theme_font_size_override("font_size", 17)
		_save_indicator.modulate.a = 0.0
		_save_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_save_indicator.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		_save_indicator.offset_left = -26
		_save_indicator.offset_top = -26
		_save_indicator.offset_right = -4
		_save_indicator.offset_bottom = -4
		add_child(_save_indicator)
		SaveManager.game_saved.connect(_on_game_saved)

		GlobalEvents.subscribe("item_received", func(payload: Dictionary):
			var item_id := String(payload.get("id", ""))
			var qty := int(payload.get("qty", 1))
			UiKit.show_item_modal(self, item_id, qty)
		)

		# Códice de Curiosidades (Task 2): aviso al descubrir una entrada nueva y,
		# aparte, al completar el códice entero (premio "Erudito de lo Absurdo").
		GlobalEvents.subscribe("lore_discovered", func(payload: Dictionary):
			var cid := String(payload.get("id", ""))
			var entry := Design.get_codex_entry(cid)
			var title_txt := Locale.pick(entry.get("title", {})) if not entry.is_empty() else cid
			_show_meta_toast(
				"🔍 " + Locale.pick({"es": "¡Nueva curiosidad!", "en": "New curiosity!"}),
				title_txt,
				Locale.pick({"es": "Añadida al Códice de Curiosidades", "en": "Added to the Codex of Curiosities"}),
				UiKit.ACCENT_SOFT)
		)
		GlobalEvents.subscribe("codex_completed", func(_payload: Dictionary):
			_show_meta_toast(
				"🏆 " + Locale.pick({"es": "¡Códice completado!", "en": "Codex complete!"}),
				Locale.pick({"es": "Erudito de lo Absurdo", "en": "Scholar of the Absurd"}),
				Locale.pick({"es": "+5% de experiencia permanente", "en": "+5% permanent experience"}),
				UiKit.GOOD)
		)
		# Desuscribir estos 3 listeners si este GameRoot llegara a liberarse
		# (p. ej. recarga de escena): evita que queden lambdas "colgando" en el
		# bus global apuntando a una instancia ya destruida.
		tree_exiting.connect(func() -> void: GlobalEvents.unsubscribe_object(self))

	_refresh_tab_texts()
	_refresh_hud()
	passive_timer.start()

	# ── Cabecera compartida de ubicación ──
	if _location_bar == null:
		_build_location_bar()
		_update_location_bar(_active_view)

	# ── Barra de peligro ambiental (insolación / congelación), bajo el HUD ──
	if _hazard_panel == null:
		_build_hazard_bar()


## Reorganiza el panel superior HUD para formato horizontal en tarjetas de esquinas:
## - CardHUDLeft (esquina sup-izq): Esfera (44x44) + Avatar (44x44) + Niveles/Barras XP alineados.
## - CardHUDRight (esquina sup-der): Barras ampliadas HP/MP (280px) + Oro/Reloj/Mapa/Materiales.
func _setup_redesigned_hud() -> void:
	var panel_hud: PanelContainer = get_node_or_null("VBoxMain/PanelHUD") as PanelContainer
	if panel_hud == null:
		return
	panel_hud.custom_minimum_size = Vector2(0, 0)

	var margin_hud: MarginContainer = get_node_or_null("VBoxMain/PanelHUD/MarginHUD") as MarginContainer
	if margin_hud == null:
		return

	# BOOST VERTICAL: con `window/stretch/aspect=expand` (project.godot) el ancho
	# lógico del viewport apenas cambia al rotar a retrato (solo crece el alto),
	# así que los mismos tamaños en px lógicos quedan muy pequeños en pantalla.
	# Factor alineado con el que ya usa `_refresh_tab_texts` para la barra de
	# pestañas inferior (34/16 ≈ 2.1x). Solo se amplía en retrato; horizontal
	# se queda exactamente igual.
	var sz := get_viewport_rect().size
	var b := 2.1 if sz.y >= sz.x and sz.x > 0.0 else 1.0

	# Idempotencia: si ya se construyó el HUD, solo se reescalan dimensiones y fuentes
	# sin destruir ni recrear nodos (evita Can't add child y fugas de memoria).
	if _hud_redesigned:
		_apply_hud_scale(b)
		_build_floating_radial_button()
		return

	# Extracción SEGURA de nodos persistentes antes de tocar el contenedor antiguo
	var old_hbox: HBoxContainer = get_node_or_null("VBoxMain/PanelHUD/MarginHUD/HBoxMainHUD") as HBoxContainer

	if lbl_level != null and lbl_level.get_parent() != null:
		lbl_level.get_parent().remove_child(lbl_level)
	if lbl_base_name != null and lbl_base_name.get_parent() != null:
		lbl_base_name.get_parent().remove_child(lbl_base_name)
	if bar_xp != null and bar_xp.get_parent() != null:
		bar_xp.get_parent().remove_child(bar_xp)
	if lbl_job_level != null and lbl_job_level.get_parent() != null:
		lbl_job_level.get_parent().remove_child(lbl_job_level)
	if bar_job_xp != null and bar_job_xp.get_parent() != null:
		bar_job_xp.get_parent().remove_child(bar_job_xp)
	if vbox_stats != null and vbox_stats.get_parent() != null:
		vbox_stats.get_parent().remove_child(vbox_stats)
	if _materials_box != null and _materials_box.get_parent() != null:
		_materials_box.get_parent().remove_child(_materials_box)
	if lbl_gold != null and lbl_gold.get_parent() != null:
		lbl_gold.get_parent().remove_child(lbl_gold)
	if _hero_avatar != null and _hero_avatar.get_parent() != null:
		_hero_avatar.get_parent().remove_child(_hero_avatar)

	if old_hbox != null:
		margin_hud.remove_child(old_hbox)
		old_hbox.queue_free()

	var existing_top := margin_hud.get_node_or_null("VBoxHUDTop")
	if existing_top != null:
		margin_hud.remove_child(existing_top)
		existing_top.queue_free()

	# ── TARJETA HUD IZQUIERDA (Esfera + Avatar + XP) ──
	_hud_card_left = PanelContainer.new()
	_hud_card_left.name = "CardHUDLeft"
	_hud_card_left.size_flags_horizontal = 1  # SIZE_FILL para ocupar su zona fija
	UiKit.premium_frame(_hud_card_left, {"bg_color": UiKit.theme_color("panel_bg", UiKit.BG_BASE), "corner_radius": 14.0, "pad": 0})

	var margin_left_card := MarginContainer.new()
	margin_left_card.add_theme_constant_override("margin_left", 8)
	margin_left_card.add_theme_constant_override("margin_right", 12)
	margin_left_card.add_theme_constant_override("margin_top", 6)
	margin_left_card.add_theme_constant_override("margin_bottom", 6)
	_hud_card_left.add_child(margin_left_card)

	var hbox_left_content := HBoxContainer.new()
	hbox_left_content.add_theme_constant_override("separation", 10)
	margin_left_card.add_child(hbox_left_content)

	# Slot para la Esfera de reposo
	_hud_orb_slot = Control.new()
	_hud_orb_slot.name = "OrbSlot"
	_hud_orb_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox_left_content.add_child(_hud_orb_slot)

	# Avatar + nombre de profesión centrados
	var avatar_vbox := VBoxContainer.new()
	avatar_vbox.name = "AvatarVBox"
	avatar_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	avatar_vbox.add_theme_constant_override("separation", 2)
	avatar_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_hero_avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hero_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar_vbox.add_child(_hero_avatar)

	lbl_base_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_base_name.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	avatar_vbox.add_child(lbl_base_name)
	_hero_avatar_lbl = lbl_base_name

	hbox_left_content.add_child(avatar_vbox)

	# Bloque de Niveles y Barras de Experiencia (centrado verticalmente)
	_hud_vbox_left = VBoxContainer.new()
	_hud_vbox_left.name = "VBoxLeft"
	_hud_vbox_left.add_theme_constant_override("separation", 6)
	_hud_vbox_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_vbox_left.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Fila 1: Base Level + BarXP (número alineado a la derecha para coincidir con job)
	_hud_hbox_base = HBoxContainer.new()
	_hud_hbox_base.name = "HBoxBaseLevel"
	_hud_hbox_base.add_theme_constant_override("separation", 0)

	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_hbox_base.add_child(lbl_level)

	var hbox_row1 := HBoxContainer.new()
	hbox_row1.add_theme_constant_override("separation", 8)
	hbox_row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_row1.add_child(_hud_hbox_base)

	bar_xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox_row1.add_child(bar_xp)

	# Fila 2: Job Level + BarJobXP (mismo ancho fijo para alineación exacta)
	_hud_hbox_job = HBoxContainer.new()
	_hud_hbox_job.name = "HBoxJobLevel"
	_hud_hbox_job.add_theme_constant_override("separation", 0)

	lbl_job_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_hbox_job.add_child(lbl_job_level)

	var hbox_row2 := HBoxContainer.new()
	hbox_row2.add_theme_constant_override("separation", 8)
	hbox_row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_row2.add_child(_hud_hbox_job)

	bar_job_xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_job_xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox_row2.add_child(bar_job_xp)

	_hud_vbox_left.add_child(hbox_row1)
	_hud_vbox_left.add_child(hbox_row2)
	hbox_left_content.add_child(_hud_vbox_left)

	# ── TARJETA HUD DERECHA (Stats HP/MP ampliadas + Secundaria) ──
	_hud_card_right = PanelContainer.new()
	_hud_card_right.name = "CardHUDRight"
	_hud_card_right.size_flags_horizontal = 1  # SIZE_FILL para ocupar su zona fija
	UiKit.premium_frame(_hud_card_right, {"bg_color": UiKit.theme_color("panel_bg", UiKit.BG_BASE), "corner_radius": 14.0, "pad": 0})

	var margin_right_card := MarginContainer.new()
	margin_right_card.name = "MarginContainer"
	margin_right_card.add_theme_constant_override("margin_left", 12)
	margin_right_card.add_theme_constant_override("margin_right", 12)
	margin_right_card.add_theme_constant_override("margin_top", 6)
	margin_right_card.add_theme_constant_override("margin_bottom", 6)
	_hud_card_right.add_child(margin_right_card)

	var vbox_right_content := VBoxContainer.new()
	vbox_right_content.name = "VBoxContainer"
	vbox_right_content.add_theme_constant_override("separation", 4)
	margin_right_card.add_child(vbox_right_content)

	# Barras HP y MP con ancho ampliado (320 px) para lectura óptima
	vbox_stats.add_theme_constant_override("separation", 4)
	bar_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_mp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox_right_content.add_child(vbox_stats)

	# Fila secundaria: Oro + Materiales + Reloj/Mapa
	var hbox_secondary := HBoxContainer.new()
	hbox_secondary.name = "HBoxSecondary"
	hbox_secondary.add_theme_constant_override("separation", 8)
	hbox_secondary.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	lbl_gold.clip_text = true
	lbl_gold.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox_secondary.add_child(lbl_gold)

	_materials_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_secondary.add_child(_materials_box)

	var hud_right_slot := HBoxContainer.new()
	hud_right_slot.name = "HUDRightSlot"
	hud_right_slot.add_theme_constant_override("separation", 8)
	hud_right_slot.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox_secondary.add_child(hud_right_slot)

	vbox_right_content.add_child(hbox_secondary)

	# Slot Central para título de ubicación
	var hud_center_slot := HBoxContainer.new()
	hud_center_slot.name = "HUDCenterSlot"
	hud_center_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_center_slot.alignment = BoxContainer.ALIGNMENT_CENTER

	# Overlay clicable sobre TODA la tarjeta (avatar + niveles/XP): abre el
	# mismo selector de profesión activa que se usa durante el combate.
	var card_left_btn := Button.new()
	card_left_btn.flat = true
	card_left_btn.focus_mode = Control.FOCUS_NONE
	card_left_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_left_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card_left_btn.tooltip_text = Locale.pick({"es": "Cambiar profesión activa", "en": "Change active profession"})
	card_left_btn.pressed.connect(func() -> void:
		AudioManager.play_ui("select")
		_open_hud_profession_modal(true)
	)
	_hud_card_left.add_child(card_left_btn)

	# HBox principal que alberga las dos tarjetas en las esquinas
	var hbox_top := HBoxContainer.new()
	hbox_top.name = "HBoxTopColumns"
	hbox_top.add_theme_constant_override("separation", 12)
	hbox_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	hbox_top.add_child(_hud_card_left)
	hbox_top.add_child(hud_center_slot)
	hbox_top.add_child(_hud_card_right)

	var vbox_hud_top := VBoxContainer.new()
	vbox_hud_top.name = "VBoxHUDTop"
	vbox_hud_top.add_theme_constant_override("separation", 4)
	vbox_hud_top.add_child(hbox_top)

	margin_hud.add_child(vbox_hud_top)
	_hud_redesigned = true

	_apply_hud_scale(b)
	_build_floating_radial_button()


func _apply_hud_scale(b: float) -> void:
	if _hud_card_left != null:
		_hud_card_left.custom_minimum_size = Vector2(330 * b, 0)
	if _hud_orb_slot != null:
		_hud_orb_slot.custom_minimum_size = Vector2(44 * b, 44 * b)
	if _hero_avatar != null:
		_hero_avatar.custom_minimum_size = Vector2(48 * b, 48 * b)
	if lbl_base_name != null:
		lbl_base_name.add_theme_font_size_override("font_size", roundi(17 * b))
	if _hud_vbox_left != null:
		_hud_vbox_left.custom_minimum_size.x = 300.0 * b
	if _hud_hbox_base != null:
		_hud_hbox_base.custom_minimum_size = Vector2(110 * b, 0)
	if lbl_level != null:
		lbl_level.custom_minimum_size = Vector2(110 * b, 0)
		lbl_level.add_theme_font_size_override("font_size", roundi(26 * b))
	if bar_xp != null:
		bar_xp.custom_minimum_size = Vector2(170 * b, 14 * b)
	if _hud_hbox_job != null:
		_hud_hbox_job.custom_minimum_size = Vector2(110 * b, 0)
	if lbl_job_level != null:
		lbl_job_level.custom_minimum_size = Vector2(110 * b, 0)
		lbl_job_level.add_theme_font_size_override("font_size", roundi(26 * b))
	if bar_job_xp != null:
		bar_job_xp.custom_minimum_size = Vector2(170 * b, 14 * b)
	if _hud_card_right != null:
		_hud_card_right.custom_minimum_size = Vector2(360 * b, 0)
	if vbox_stats != null:
		vbox_stats.custom_minimum_size.x = 320.0 * b
	if bar_hp != null:
		bar_hp.custom_minimum_size = Vector2(320 * b, 22 * b)
	if bar_mp != null:
		bar_mp.custom_minimum_size = Vector2(320 * b, 22 * b)
	if lbl_hp != null:
		lbl_hp.add_theme_font_size_override("font_size", roundi(24 * b))
	if lbl_mp != null:
		lbl_mp.add_theme_font_size_override("font_size", roundi(24 * b))
	if lbl_gold != null:
		lbl_gold.add_theme_font_size_override("font_size", roundi(24 * b))
		lbl_gold.custom_minimum_size.x = 110 * b


## Botón "☰" que abre el menú radial, FLOTANTE sobre el mundo — vive fuera de
## `PanelHUD` (la franja negra superior), igual que el widget de la Esfera
## (`OrbCompanionOverlay`, esquina opuesta): antes ocupaba una fila extra
## dentro de la HUD y la agrandaba innecesariamente. Idempotente: crea el
## botón una sola vez y solo reposiciona/retinta en llamadas posteriores
## (orientación/tema).
func _build_floating_radial_button() -> void:
	if _btn_radial_menu == null:
		_btn_radial_menu = Button.new()
		_btn_radial_menu.name = "BtnRadialMenu"
		_btn_radial_menu.text = ""
		_btn_radial_menu.focus_mode = Control.FOCUS_NONE
		_btn_radial_menu.tooltip_text = Locale.pick({"es": "Menú", "en": "Menu"})
		_btn_radial_menu.pressed.connect(_toggle_radial_menu)
		_btn_radial_menu.draw.connect(_draw_radial_hamburger)
		add_child(_btn_radial_menu)

	var sz := get_viewport_rect().size
	var is_landscape := sz.x > sz.y
	var b := 1.0 if is_landscape else 2.1
	# Mismo tamaño base (120px) que `OrbCompanionOverlay._orb_container`, para
	# que ambos widgets flotantes (Esfera a la izquierda, Menú a la derecha)
	# se vean equilibrados en pantalla.
	var side: float = 120.0 * b

	_btn_radial_menu.custom_minimum_size = Vector2(side, side)
	_btn_radial_menu.add_theme_font_size_override("font_size", roundi(48 * b))

	# Misma Y fija que `OrbCompanionOverlay._rest_pos` (esquina opuesta:
	# derecha en vez de izquierda), para simetría visual entre ambos widgets.
	var rest_y: float = 140.0 if is_landscape else 280.0
	_btn_radial_menu.anchor_left = 1.0
	_btn_radial_menu.anchor_right = 1.0
	_btn_radial_menu.anchor_top = 0.0
	_btn_radial_menu.anchor_bottom = 0.0
	_btn_radial_menu.offset_right = -24.0
	_btn_radial_menu.offset_left = -24.0 - side
	_btn_radial_menu.offset_top = rest_y
	_btn_radial_menu.offset_bottom = rest_y + side

	_style_floating_radial_button()


## Repinta el botón flotante del menú radial con el tema activo (borde/fondo
## de marca, coherente con el resto de superficies — ver `UiKit.theme_color`).
func _style_floating_radial_button() -> void:
	if _btn_radial_menu == null:
		return
	var sz := get_viewport_rect().size
	var b := 1.0 if sz.x > sz.y else 2.1
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UiKit.theme_color("panel_glass", UiKit.BG_BASE)
	btn_style.border_color = UiKit.theme_color("accent", UiKit.ACCENT)
	btn_style.set_border_width_all(2)
	# Esquina redondeada estándar (14px), NO circular: antes 60px (mitad del
	# lado) lo hacía un círculo perfecto, desentonando con el resto de tarjetas
	# rectangulares del UI Kit (ver task_bugs_observados.md §1.4).
	btn_style.set_corner_radius_all(roundi(14 * b))
	btn_style.shadow_color = Color(0, 0, 0, 0.5)
	btn_style.shadow_size = 6
	for st in ["normal", "hover", "pressed", "focus"]:
		_btn_radial_menu.add_theme_stylebox_override(st, btn_style)
	_btn_radial_menu.add_theme_color_override("font_color", UiKit.theme_color("text", UiKit.TEXT))
	_btn_radial_menu.queue_redraw()


func _draw_radial_hamburger() -> void:
	if _btn_radial_menu == null or not is_instance_valid(_btn_radial_menu):
		return
	var sz := _btn_radial_menu.size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var line_w: float = roundf(sz.x * 0.44)
	var line_h: float = maxf(3.0, roundf(sz.y * 0.055))
	var start_x: float = roundf((sz.x - line_w) * 0.5)
	var center_y: float = roundf(sz.y * 0.5)
	var spacing: float = roundf(sz.y * 0.16)
	var col: Color = UiKit.theme_color("text", UiKit.TEXT)
	_btn_radial_menu.draw_rect(Rect2(start_x, center_y - spacing - line_h * 0.5, line_w, line_h), col, true)
	_btn_radial_menu.draw_rect(Rect2(start_x, center_y - line_h * 0.5, line_w, line_h), col, true)
	_btn_radial_menu.draw_rect(Rect2(start_x, center_y + spacing - line_h * 0.5, line_w, line_h), col, true)


## Botón "🗺️" del mapamundi (niebla de guerra), FLOTANTE justo a la izquierda
## del ☰ del menú radial, con EXACTAMENTE su mismo tamaño y forma (antes vivía
## apretado entre la hora y los items a recoger, dentro de la HUD, difícil de
## pulsar con el dedo). Reutiliza la MISMA instancia de `TabWorld3D._btn_map`
## (conserva su lógica de apertura del minimapa), solo la reposiciona.
func _build_floating_map_button() -> void:
	var world_view = _views.get("world")
	if world_view == null or _btn_radial_menu == null:
		return
	var btn: Button = world_view.ensure_map_button()
	if btn == null:
		return
	if _btn_floating_map != btn:
		_btn_floating_map = btn
	if _btn_floating_map.get_parent() != self:
		if _btn_floating_map.get_parent() != null:
			_btn_floating_map.get_parent().remove_child(_btn_floating_map)
		add_child(_btn_floating_map)

	var sz := get_viewport_rect().size
	var is_landscape := sz.x > sz.y
	var b := 1.0 if is_landscape else 2.1
	var side: float = 120.0 * b
	var gap: float = 16.0 * b

	_btn_floating_map.custom_minimum_size = Vector2(side, side)
	_btn_floating_map.add_theme_font_size_override("font_size", roundi(48 * b))

	var rest_y: float = 140.0 if is_landscape else 280.0
	_btn_floating_map.anchor_left = 1.0
	_btn_floating_map.anchor_right = 1.0
	_btn_floating_map.anchor_top = 0.0
	_btn_floating_map.anchor_bottom = 0.0
	_btn_floating_map.offset_right = _btn_radial_menu.offset_left - gap
	_btn_floating_map.offset_left = _btn_radial_menu.offset_left - gap - side
	_btn_floating_map.offset_top = rest_y
	_btn_floating_map.offset_bottom = rest_y + side

	_style_floating_map_button()
	_btn_floating_map.visible = (_active_view in ["world", "character", "bag", "info", "cook"])


## Repinta el botón flotante del mapa con el MISMO estilo que el botón ☰ del
## menú radial (ver `_style_floating_radial_button`), para que ambos widgets
## se vean como un único par coherente en la esquina superior derecha.
func _style_floating_map_button() -> void:
	if _btn_floating_map == null:
		return
	var sz := get_viewport_rect().size
	var b := 1.0 if sz.x > sz.y else 2.1
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UiKit.theme_color("panel_glass", UiKit.BG_BASE)
	btn_style.border_color = UiKit.theme_color("accent", UiKit.ACCENT)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(roundi(14 * b))
	btn_style.shadow_color = Color(0, 0, 0, 0.5)
	btn_style.shadow_size = 6
	for st in ["normal", "hover", "pressed", "focus"]:
		_btn_floating_map.add_theme_stylebox_override(st, btn_style)
	_btn_floating_map.add_theme_color_override("font_color", UiKit.theme_color("text", UiKit.TEXT))


## Mismas 7 profesiones/orden que `ViewCombat.PROFESSIONS_7`.
const HUD_PROFESSIONS_7: Array[String] = ["Don Nadie", "Guerrero", "Arquero", "Elementalista", "Sacerdote", "Psíquico", "Tiempo"]

## Construye (una sola vez) el modal de selección de profesión activa que se
## abre al pulsar la tarjeta HUD izquierda (avatar + niveles/XP) — mismo
## aspecto que `ViewCombat._setup_profession_modal`, pero cambiando la
## profesión al instante (fuera de combate no hay turno/PA que gastar).
func _build_hud_profession_modal() -> void:
	if _hud_profession_modal != null and is_instance_valid(_hud_profession_modal):
		return

	_hud_profession_modal = PanelContainer.new()
	_hud_profession_modal.visible = false
	_hud_profession_modal.z_index = 110
	_hud_profession_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_profession_modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var modal_bg := StyleBoxFlat.new()
	modal_bg.bg_color = Color(0.02, 0.01, 0.04, 0.85)
	_hud_profession_modal.add_theme_stylebox_override("panel", modal_bg)

	var modal_center := CenterContainer.new()
	modal_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_profession_modal.add_child(modal_center)

	var modal_box := PanelContainer.new()
	modal_box.custom_minimum_size = Vector2(850, 500)
	var modal_box_style := StyleBoxFlat.new()
	modal_box_style.bg_color = UiKit.theme_color("panel_bg", Color(0.04, 0.03, 0.08, 0.97))
	modal_box_style.set_corner_radius_all(18)
	modal_box_style.set_border_width_all(3)
	modal_box_style.border_color = UiKit.theme_color("accent", UiKit.COLOR_GOLD_PRIMARY)
	modal_box_style.shadow_color = Color(UiKit.COLOR_GOLD_PRIMARY.r, UiKit.COLOR_GOLD_PRIMARY.g, UiKit.COLOR_GOLD_PRIMARY.b, 0.55)
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
	lbl_modal_title.text = Locale.pick({"es": "Cambiar Profesión Activa", "en": "Change Active Profession"})
	lbl_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_modal_title.add_theme_font_size_override("font_size", 24)
	lbl_modal_title.add_theme_color_override("font_color", UiKit.theme_color("accent", UiKit.COLOR_GOLD_PRIMARY))
	modal_vbox.add_child(lbl_modal_title)

	_hud_professions_grid = GridContainer.new()
	_hud_professions_grid.columns = 1
	_hud_professions_grid.add_theme_constant_override("h_separation", 10)
	_hud_professions_grid.add_theme_constant_override("v_separation", 14)
	_hud_professions_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_professions_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_vbox.add_child(_hud_professions_grid)

	var btn_cancel_prof := Button.new()
	btn_cancel_prof.text = Locale.pick({"es": "Cancelar", "en": "Cancel"})
	btn_cancel_prof.custom_minimum_size = Vector2(180, 48)
	btn_cancel_prof.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_cancel_prof.focus_mode = Control.FOCUS_NONE
	btn_cancel_prof.pressed.connect(func(): _open_hud_profession_modal(false))
	modal_vbox.add_child(btn_cancel_prof)

	add_child(_hud_profession_modal)


## Rellena el grid de las 7 profesiones (misma disposición 1+3+3 filas que en
## combate), marcando bloqueadas/activa.
func _setup_hud_profession_modal() -> void:
	if _hud_professions_grid == null:
		return
	for child in _hud_professions_grid.get_children():
		child.queue_free()

	_hud_professions_grid.columns = 1
	var unlocked := GlobalState.unlocked_professions

	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_professions_grid.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 16)
	row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_professions_grid.add_child(row2)

	var row3 := HBoxContainer.new()
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	row3.add_theme_constant_override("separation", 16)
	row3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_professions_grid.add_child(row3)

	for prof in HUD_PROFESSIONS_7:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 100) if prof == "Don Nadie" else Vector2(180, 100)
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
		var path: String = PROF_TEXTURES.get(prof, "res://assets/combat/character/prof_av_don_nadie.png")
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
			btn.pressed.connect(func(): _on_hud_profession_selected(target_prof))
			btn.tooltip_text = Locale.pick({"es": "Cambiar a %s", "en": "Switch to %s"}) % Locale.translate_profession(prof)
		else:
			btn.disabled = true
			btn.modulate = Color(0.3, 0.3, 0.3, 0.6)
			btn.tooltip_text = Locale.pick({"es": "Bloqueado", "en": "Locked"})

		var is_active := prof.to_lower() == GlobalState.profession.to_lower()
		if is_active:
			var active_style := StyleBoxFlat.new()
			active_style.bg_color = Color(0.18, 0.14, 0.04, 0.95)
			active_style.set_corner_radius_all(10)
			active_style.set_border_width_all(3)
			active_style.border_color = UiKit.COLOR_GOLD_PRIMARY
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_stylebox_override("disabled", active_style)
			btn.add_theme_stylebox_override("hover", active_style)

		if prof == "Don Nadie":
			row1.add_child(btn)
		elif prof in ["Guerrero", "Arquero", "Elementalista"]:
			row2.add_child(btn)
		else:
			row3.add_child(btn)


## Abre/cierra (con el mismo "pop" que en combate) el selector de profesión.
func _open_hud_profession_modal(p_show: bool) -> void:
	_build_hud_profession_modal()
	if p_show:
		_setup_hud_profession_modal()
		_hud_profession_modal.visible = true
		_hud_profession_modal.modulate.a = 0.0
		_hud_profession_modal.scale = Vector2(0.8, 0.8)
		_hud_profession_modal.pivot_offset = _hud_profession_modal.size * 0.5
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_hud_profession_modal, "modulate:a", 1.0, 0.2)
		tw.tween_property(_hud_profession_modal, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_hud_profession_modal, "modulate:a", 0.0, 0.15)
		tw.finished.connect(func(): _hud_profession_modal.visible = false)


## Cambia la profesión activa al instante (sin turno que gastar, a diferencia
## de `CombatTabsUI.change_class_during_combat`) y cierra el selector. El
## avatar/HUD se refresca solo vía `GlobalState.state_updated` → `_refresh_hud`.
func _on_hud_profession_selected(prof_id: String) -> void:
	if GlobalState.profession != prof_id:
		AudioManager.play_sfx("click")
		GlobalState.set_profession(prof_id)
	_open_hud_profession_modal(false)


func _instantiate_views() -> void:
	# El mundo es la vista 3D top-down (TabWorld3D), construida íntegramente por código.
	var world_view: Control = TabWorld3DScript.new()
	world_view.visible = false
	view_stack.add_child(world_view)
	world_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_views["world"] = world_view

	var scenes: Dictionary = {
		"city":      SCENE_CITY,
		"building":  SCENE_BUILDING,
		"dungeon":   SCENE_DUNGEON,
		"combat":    SCENE_COMBAT,
		"character": SCENE_CHARACTER,
		"bag":       SCENE_BAG,
		"gather":    SCENE_GATHER,
		"place":     SCENE_PLACE,
		"cook":      SCENE_COOK,
		"training":  SCENE_TRAINING,
		"shop":      SCENE_SHOP,
	}
	for key in scenes:
		var instance: Control = scenes[key].instantiate() as Control
		instance.visible = false
		view_stack.add_child(instance)
		# Hacer que cada vista ocupe todo el ViewStack
		instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_views[key] = instance

	# Vistas construidas por código (sin .tscn): Información, Tablón de Encargos, Forja, Transportista y Sala de la Esfera.
	for pair in [["info", TabInfo.new()], ["encargos", ViewEncargos.new()], ["forge", ViewForge.new()], ["transport", ViewTransport.new()], ["orb_room", ViewOrbRoom.new()]]:
		var code_view: Control = pair[1]
		code_view.visible = false
		view_stack.add_child(code_view)
		code_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_views[pair[0]] = code_view

	# La Sala de la Esfera avisa cuando el jugador cierra su diálogo.
	(_views["orb_room"] as ViewOrbRoom).orb_finished.connect(_on_orb_finished)


func _connect_signals() -> void:
	# SceneManager
	SceneManager.navigate_to.connect(_on_navigate_to)
	SceneManager.tab_switched.connect(_on_tab_switched)
	SceneManager.combat_started.connect(_on_combat_started)
	SceneManager.combat_ended.connect(_on_combat_ended)

	# GlobalState
	GlobalState.state_updated.connect(_refresh_hud)

	# Al reabrir la presa, el valle se transforma: reconstruimos el mundo 3D.
	QuestManager.dam_opened.connect(_on_dam_opened)

	# Meta-progresión: logros y tutoriales data-driven. Sus
	# avisos se muestran como toasts flotantes sobre el HUD.
	MetaManager.achievement_unlocked.connect(_on_achievement_unlocked)
	MetaManager.tutorial_step.connect(_on_tutorial_step)

	# (Game Feel): subir de nivel (personaje u oficio) debe sentirse
	# importante, no solo un número que cambia: reutiliza el mismo toast.
	GlobalState.leveled_up.connect(_on_leveled_up)
	GlobalState.job_leveled_up.connect(_on_job_leveled_up)
	# Subida de nivel de OFICIO DE FARMEO (leñador/minero/pesca/…): aviso
	# discreto aparte (task_arreglosPendientes.md §1), no el modal de
	# personaje/clase, para no interrumpir la recolección.
	GlobalState.skill_leveled_up.connect(_on_skill_leveled_up)

	# Idioma
	Locale.locale_changed.connect(_on_locale_changed)

	# Tab buttons
	btn_world.pressed.connect(func() -> void:     SceneManager.switch_tab("world"))
	btn_character.pressed.connect(func() -> void: SceneManager.switch_tab("character"))
	btn_bag.pressed.connect(func() -> void:       SceneManager.switch_tab("bag"))
	btn_info.pressed.connect(func() -> void:      SceneManager.switch_tab("info"))
	btn_opts.pressed.connect(func() -> void:      SceneManager.switch_tab("options"))


# ══════════════════════════════════════════════════════════════════════════════
# META-PROGRESIÓN: TOASTS DE LOGROS Y TUTORIALES
# ══════════════════════════════════════════════════════════════════════════════
## Aviso de logro desbloqueado (icono + nombre + descripción).
func _on_achievement_unlocked(data: Dictionary) -> void:
	var title := "%s  %s" % [String(data.get("icon", "🏆")), String(data.get("name", ""))]
	var sub := String(data.get("desc", ""))
	_show_meta_toast("🏆 " + Locale.pick({"es": "¡Logro desbloqueado!", "en": "Achievement unlocked!"}),
		title, sub, Color(1.0, 0.82, 0.30))
	AudioManager.play_sfx("levelup")


## Aviso de paso de tutorial (texto guía).
func _on_tutorial_step(data: Dictionary) -> void:
	var head := "💡 %s (%d/%d)" % [
		Locale.pick({"es": "Tutorial", "en": "Tutorial"}),
		int(data.get("index", 0)) + 1, int(data.get("total", 1))]
	_show_meta_toast(head, String(data.get("text", "")), "", Color(0.55, 0.85, 1.0))


## Aviso de subida de NIVEL DE PERSONAJE.
func _on_leveled_up(new_level: int) -> void:
	if GlobalState.debug_mode:
		return
	_announce_levelup({"type": "base", "level": new_level, "prof": GlobalState.profession})


## Aviso de subida de NIVEL DE OFICIO/PROFESIÓN activa.
func _on_job_leveled_up(profession: String, new_level: int) -> void:
	if GlobalState.debug_mode:
		return
	_announce_levelup({"type": "job", "level": new_level, "prof": profession})


## Aviso DISCRETO de subida de nivel de un OFICIO DE FARMEO (leñador/minero/
## pesca/agricultor/ganadero — sistema APARTE de las profesiones de combate,
## ver docs/task_arreglosPendientes.md §0). A diferencia de _on_leveled_up/
## _on_job_leveled_up (que abren el modal celebratorio de nivel de personaje/
## clase), reutiliza el toast flotante sutil: la recolección no debe
## interrumpirse con un modal a pantalla completa.
func _on_skill_leveled_up(skill_key: String, new_level: int) -> void:
	if GlobalState.debug_mode:
		return
	var skill_name := Locale.t("skill_" + skill_key)
	var bonus_text := ""
	if new_level >= GameConfig.GATHER_LEVEL_AMOUNT_MAX_THRESHOLD:
		bonus_text = Locale.pick({
			"es": "¡Nivel máximo! Recolección x%d por toque." % GameConfig.GATHER_LEVEL_AMOUNT_MAX,
			"en": "Max level! Gathering x%d per tap." % GameConfig.GATHER_LEVEL_AMOUNT_MAX})
	elif new_level >= GameConfig.GATHER_LEVEL_AMOUNT_THRESHOLD:
		bonus_text = Locale.pick({
			"es": "Recolección x%d por toque desbloqueada." % GameConfig.GATHER_LEVEL_AMOUNT_MULTIPLIER,
			"en": "Gathering x%d per tap unlocked." % GameConfig.GATHER_LEVEL_AMOUNT_MULTIPLIER})
	else:
		bonus_text = Locale.pick({"es": "Velocidad de recolección aumentada.", "en": "Gathering speed increased."})
	var level_text := Locale.pick({"es": "Nivel %d" % new_level, "en": "Level %d" % new_level})

	AudioManager.play_sfx("levelup")

	var modal_title := "⭐ " + Locale.pick({"es": "¡OFICIO MEJORADO!", "en": "PROFESSION LEVELED UP!"})
	var modal_body := Locale.pick({
		"es": "• ¡Has subido al %s en %s!\n\n✨ %s" % [level_text, skill_name, bonus_text],
		"en": "• Reached %s in %s!\n\n✨ %s" % [level_text, skill_name, bonus_text]
	})
	UiKit.alert(self, modal_title, modal_body, Locale.pick({"es": "¡Genial!", "en": "Awesome!"}))


## Muestra o encola la subida de nivel para procesarla tras el combate.
func _announce_levelup(event_data: Dictionary) -> void:
	if GlobalState.debug_mode:
		return
	if _active_view == "combat":
		_pending_levelup_toasts.append(event_data)
		return
	_show_levelup_flow([event_data])


## Vacía la cola de avisos de subida de nivel acumulados durante el combate,
## mostrándolos en una modal limpia con sonido y comprobación de habilidades nuevas.
func _flush_pending_levelup_toasts() -> void:
	if _pending_levelup_toasts.is_empty() or GlobalState.debug_mode:
		_pending_levelup_toasts.clear()
		return
	var pending := _pending_levelup_toasts.duplicate()
	_pending_levelup_toasts.clear()
	_show_levelup_flow(pending)


## Muestra la modal destacada de subida de nivel + segunda modal si desbloqueó habilidad.
func _show_levelup_flow(events: Array) -> void:
	if events.is_empty() or GlobalState.debug_mode:
		return

	var base_lvl := -1
	var job_lvl := -1
	var prof_name := GlobalState.profession

	for ev in events:
		if String(ev.get("type", "")) == "base":
			base_lvl = int(ev.get("level", -1))
		elif String(ev.get("type", "")) == "job":
			job_lvl = int(ev.get("level", -1))
			prof_name = String(ev.get("prof", prof_name))

	var title_text := Locale.pick({"es": "⭐ ¡ENHORABUENA! HAS SUBIDO DE NIVEL", "en": "⭐ CONGRATULATIONS! LEVEL UP"})
	var body_lines: Array = []

	if base_lvl > 0:
		body_lines.append(Locale.pick({
			"es": "• Has subido al Nivel Base %d (+%d puntos de característica)." % [base_lvl, GameConfig.STAT_POINTS_PER_LEVEL],
			"en": "• Reached Base Level %d (+%d attribute points)." % [base_lvl, GameConfig.STAT_POINTS_PER_LEVEL]
		}))

	if job_lvl > 0:
		var p_label := _profession_name_str(prof_name)
		body_lines.append(Locale.pick({
			"es": "• Has subido al Nivel %d de oficio en %s." % [job_lvl, p_label],
			"en": "• Reached Job Level %d in %s." % [job_lvl, p_label]
		}))

	if body_lines.is_empty():
		return

	var body_text: String = "\n\n".join(body_lines)
	AudioManager.play_sfx("levelup")

	# Buscar si este nivel de oficio desbloqueó alguna nueva habilidad
	var newly_unlocked_skill: Dictionary = {}
	if job_lvl > 0:
		var skills: Array = Design.get_profession_skills(prof_name)
		for sk in skills:
			if int(sk.get("level", 1)) == job_lvl:
				newly_unlocked_skill = sk
				break

	var on_accept_first := func() -> void:
		if not newly_unlocked_skill.is_empty():
			var sk_name = newly_unlocked_skill.get("name", "")
			var sk_name_str: String = Locale.pick(sk_name) if sk_name is Dictionary else String(sk_name)
			var p_label := _profession_name_str(prof_name)
			UiKit.alert(
				self,
				Locale.pick({"es": "✨ ¡NUEVA HABILIDAD APRENDIDA!", "en": "✨ NEW SKILL UNLOCKED!"}),
				Locale.pick({
					"es": "¡Enhorabuena! Has aprendido la habilidad '%s' de la profesión %s." % [sk_name_str, p_label],
					"en": "Congratulations! You learned the skill '%s' for %s." % [sk_name_str, p_label]
				}),
				Locale.pick({"es": "¡Genial!", "en": "Awesome!"}),
				func() -> void:
					if OrbBarksManager != null:
						OrbBarksManager.check_skill_overflow_milestone()
			)
		else:
			if OrbBarksManager != null:
				OrbBarksManager.check_skill_overflow_milestone()

	UiKit.alert(self, title_text, body_text, Locale.pick({"es": "¡Genial!", "en": "Awesome!"}), on_accept_first)


func _profession_name_str(prof: String) -> String:
	var def := Design.get_profession(prof)
	var d_name = def.get("name", prof)
	return Locale.pick(d_name) if d_name is Dictionary else String(d_name)


## Icono discreto de "partida guardada": aparece, se posa un instante y se
## desvanece solo. Nunca bloquea ni interrumpe.
func _on_game_saved() -> void:
	if _save_indicator == null:
		return
	_save_indicator.modulate.a = 0.0
	var tw := _save_indicator.create_tween()
	tw.tween_property(_save_indicator, "modulate:a", 0.9, 0.2)
	tw.tween_interval(0.6)
	tw.tween_property(_save_indicator, "modulate:a", 0.0, 0.5)


## Toast flotante superior con encabezado + título + subtítulo; se desvanece solo.
## No bloquea la entrada (mouse_filter IGNORE). La anchura se FIJA de forma explícita
## (adaptada al viewport, con tope) y la altura crece con el contenido: así el aviso
## NUNCA ocupa toda la ventana (incidencia reportada en pruebas).
func _show_meta_toast(head: String, title: String, sub: String, accent: Color) -> void:
	# Anchura fija y acotada: ~62% del ancho del viewport, entre 320 y 560 px.
	var vw := get_viewport_rect().size.x
	var w := clampf(vw * 0.62, 320.0, 560.0)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.10, 0.95)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	# Anclado arriba-centro con offsets EXPLÍCITOS (anchura pinada = w). Sin depender
	# de custom_minimum_size ni de grow, que con labels autowrap dan tamaños erráticos.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = 90.0
	panel.offset_bottom = 90.0
	panel.grow_vertical = Control.GROW_DIRECTION_END

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)

	var lbl_head := Label.new()
	lbl_head.text = head
	lbl_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_head.add_theme_font_size_override("font_size", 17)
	lbl_head.add_theme_color_override("font_color", accent)
	vb.add_child(lbl_head)

	var lbl_title := Label.new()
	lbl_title.text = title
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	vb.add_child(lbl_title)

	if sub != "":
		var lbl_sub := Label.new()
		lbl_sub.text = sub
		lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl_sub.add_theme_font_size_override("font_size", 15)
		lbl_sub.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
		vb.add_child(lbl_sub)

	add_child(panel)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(panel, "offset_top", 90.0, 0.3).from(74.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "offset_bottom", 90.0, 0.3).from(74.0)
	tw.set_parallel(false)
	tw.tween_interval(3.4)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)


# ══════════════════════════════════════════════════════════════════════════════
# HANDLERS DE SEÑALES DE SCENEMANAGER
# ══════════════════════════════════════════════════════════════════════════════
func _on_navigate_to(view_name: String, data: Dictionary) -> void:
	match view_name:
		"world":
			Juice.transition(
				func() -> void:
					_show_view("world")
					_set_active_tab("world")
					panel_tab_bar.visible = false
					_set_hud_panel_visible(true)
					_set_world_modal(false)
					if _hub_modal != null and is_instance_valid(_hub_modal) and _hub_modal.visible:
						_hub_modal.visible = false
					var world_view = _views.get("world")
					if world_view != null and is_instance_valid(world_view) and world_view.has_method("_nudge_player_off_solid_cell"):
						var here: CellResource = GlobalState.hexagons_db.get(GlobalState.player_pos, null) as CellResource
						if here != null and here.is_solid() and here.opens_view() != "dungeon" and here.type != "dungeon" and (not here.portal is Dictionary or here.portal.is_empty()):
							world_view._nudge_player_off_solid_cell(GlobalState.player_pos)
					var z_mus: String = Design.get_zone_music_at(GlobalState.player_pos)
					if z_mus != "":
						AudioManager.play_music(z_mus)

					if GlobalState.pending_unlocked_profession_celebration != "":
						var prof_to_celebrate: String = GlobalState.pending_unlocked_profession_celebration
						GlobalState.pending_unlocked_profession_celebration = ""
						UiKit.show_profession_unlocked_modal(self, prof_to_celebrate)
					elif OrbBarksManager != null:
						OrbBarksManager.check_overworld_milestones(),
				0.2,
				0.24,
				Locale.pick({"es": "Cargando Mapamundi...", "en": "Loading World..."}),
				Locale.pick({"es": "Construyendo terreno...", "en": "Building terrain..."})
			)

		"orb_room":
			Juice.transition(
				func() -> void:
					_enter_orb_room(String(data.get("context", "welcome"))),
				0.2,
				0.24,
				Locale.pick({"es": "Entrando en la Sala de la Esfera...", "en": "Entering the Sphere Room..."}),
				Locale.pick({"es": "Conectando con la Esfera...", "en": "Connecting with the Sphere..."})
			)

		"city":
			Juice.transition(
				func() -> void:
					_city_data = data
					var city_view := _views.get("city", null) as ViewCity
					if city_view != null and is_instance_valid(city_view):
						city_view.setup(data)
					_show_view("city")
					panel_tab_bar.visible = false,
				0.2,
				0.24,
				Locale.pick({"es": "Entrando en la Ciudad...", "en": "Entering City..."}),
				Locale.pick({"es": "Cargando distritos...", "en": "Loading districts..."})
			)

		"city_back":
			Juice.transition(
				func() -> void:
					_show_view("city")
					panel_tab_bar.visible = false,
				0.16,
				0.2
			)

		"building":
			Juice.transition(
				func() -> void:
					var building_view := _views.get("building", null) as ViewBuilding
					if building_view != null and is_instance_valid(building_view):
						building_view.setup(data if (data.has("poi_id") or data.has("event_id")) else data.get("key", "tavern"))
					_show_view("building")
					panel_tab_bar.visible = false,
				0.18,
				0.22
			)

		"dungeon":
			Juice.transition(
				func() -> void:
					var dungeon_view := _views.get("dungeon", null) as ViewDungeon
					if dungeon_view != null and is_instance_valid(dungeon_view):
						await dungeon_view.setup(data)
					_show_view("dungeon")
					panel_tab_bar.visible = false,
				0.22,
				0.26,
				Locale.pick({"es": "Cargando Mazmorra...", "en": "Loading Dungeon..."}),
				Locale.pick({"es": "Generando escenario 3D y texturas...", "en": "Generating 3D stage & textures..."})
			)

		"gather":
			Juice.transition(func() -> void:
				var gather_view := _views.get("gather", null) as ViewGather
				if gather_view != null and is_instance_valid(gather_view):
					gather_view.setup(data)
				_show_view("gather")
				panel_tab_bar.visible = false
			)

		"place":
			Juice.transition(func() -> void:
				var place_view := _views.get("place", null) as ViewPlace
				if place_view != null and is_instance_valid(place_view):
					place_view.setup(data)
				_show_view("place")
				panel_tab_bar.visible = false
			)

		"cook":
			Juice.transition(func() -> void:
				var cook_view := _views.get("cook", null) as ViewCook
				if cook_view != null and is_instance_valid(cook_view):
					cook_view.setup(data)
				_show_view("cook")
				panel_tab_bar.visible = false
			)

		"training":
			Juice.transition(func() -> void:
				_show_view("training")
				panel_tab_bar.visible = false
			)

		"encargos":
			Juice.transition(func() -> void:
				var enc_view := _views.get("encargos", null) as ViewEncargos
				if enc_view != null and is_instance_valid(enc_view):
					enc_view.setup(data)
				_show_view("encargos")
				panel_tab_bar.visible = false
			)

		"forge":
			Juice.transition(func() -> void:
				var forge_view := _views.get("forge", null) as ViewForge
				if forge_view != null and is_instance_valid(forge_view):
					forge_view.setup(data)
				_show_view("forge")
				panel_tab_bar.visible = false
			)

		"shop":
			Juice.transition(func() -> void:
				var shop_view := _views.get("shop", null) as ViewShop
				if shop_view != null and is_instance_valid(shop_view):
					shop_view.setup(data)
				_show_view("shop")
				panel_tab_bar.visible = false
			)

		"transport":
			Juice.transition(func() -> void:
				var transport_view := _views.get("transport", null) as ViewTransport
				if transport_view != null and is_instance_valid(transport_view):
					transport_view.setup(data)
				_show_view("transport")
				panel_tab_bar.visible = false
			)


func _on_tab_switched(tab_name: String) -> void:
	AudioManager.play_sfx("click")
	match tab_name:
		"world", "character", "bag", "info", "encargos", "forge":
			if tab_name == "encargos":
				var enc: ViewEncargos = _views.get("encargos", null) as ViewEncargos
				if enc != null and is_instance_valid(enc):
					enc.setup({})
			elif tab_name == "forge":
				var frg: ViewForge = _views.get("forge", null) as ViewForge
				if frg != null and is_instance_valid(frg):
					frg.setup({})
			_show_view(tab_name)
			_set_active_tab(tab_name)
			panel_tab_bar.visible = false
			if _views.has(tab_name):
				Juice.view_in(_views[tab_name])
		"options":
			_open_menu()


# ══════════════════════════════════════════════════════════════════════════════
# SALA DE LA ESFERA  (despertar inicial y reproche al morir)
# ══════════════════════════════════════════════════════════════════════════════
## Entra en la Sala de la Esfera ocultando TODO el shell (HUD, pestañas, cabecera
## y barra de peligro) y reproduce el diálogo del contexto dado.
func _enter_orb_room(context: String) -> void:
	_show_view("orb_room")
	panel_tab_bar.visible = false
	_set_hud_panel_visible(false)
	if _location_bar:
		_location_bar.visible = false
	if _hazard_panel:
		_hazard_panel.visible = false
	(_views["orb_room"] as ViewOrbRoom).play(context)


## Al cerrar el diálogo de la sala: la bienvenida arranca la partida en dun_inicial;
## la muerte reaparece junto a la base con 1 de vida y 1 de maná.
func _on_orb_finished(context: String) -> void:
	_set_hud_panel_visible(true)
	if context == "welcome":
		GlobalState.seen_intro = true
		SceneManager.go_to_dungeon({
			"event_id": "dun_inicial",
			"name": Locale.pick({"es": "La cueva de la Esfera", "en": "The Sphere Cave"}),
			"portal": {}
		})
	elif context == "death":
		GlobalState.hp = 1
		GlobalState.mp = 1
		GlobalState.state_updated.emit()
		var tab_world = _views.get("world")
		if tab_world:
			tab_world.teleport_player_to(GlobalState.get_base_coord())
		SceneManager.go_to_world()


# ══════════════════════════════════════════════════════════════════════════════
# REAPERTURA DE LA PRESA  (el valle de yelmo se transforma)
# ══════════════════════════════════════════════════════════════════════════════
## Los datos del valle ya están transformados (QuestManager.open_dam). Reconstruimos
## el mundo 3D para reflejarlo y mostramos un breve destello de transición.
## La presa se reabre desde un token de escena, así que `dam_opened` puede emitirse
## mientras el diálogo sigue abierto. En ese caso diferimos la cinemática hasta que
## la escena termine (scene_finished): debe verse ya de vuelta en el mapamundi.
func _on_dam_opened() -> void:
	if SceneRunner.is_active():
		SceneRunner.scene_finished.connect(_run_dam_cinematic, CONNECT_ONE_SHOT)
	else:
		_run_dam_cinematic()


## Lanza la cinemática de reapertura de la presa y, al terminar, reconstruye el
## mundo 3D con un destello de transición. `_scene_id` sólo llega cuando se invoca
## como callback de SceneRunner.scene_finished (se ignora).
func _run_dam_cinematic(_scene_id: String = "") -> void:
	# Asegurar que el mapamundi sea la vista activa y visible
	_show_view("world")
	_set_active_tab("world")
	panel_tab_bar.visible = false
	_set_hud_panel_visible(true)
	_set_world_modal(false)

	var world_view = _views.get("world")
	# Esperar 0.35s para que cualquier fade de salida del diálogo (Juice.transition)
	# haya terminado y el jugador vea claramente la cinemática en el mapamundi.
	get_tree().create_timer(0.35).timeout.connect(func():
		if world_view != null and is_instance_valid(world_view) and world_view.has_method("run_dam_opened_cinematic"):
			world_view.run_dam_opened_cinematic(func():
				_recreate_world_view()
				_flash_transition()
			)
		else:
			_recreate_world_view()
			_flash_transition()
	)


## Actualiza la vista del mundo 3D reconstruyendo sus tiles/marcadores (ya con el valle transformado)
## de forma in-place sin destruir la instancia ni provocar errores de RenderTarget en SubViewport.
func _recreate_world_view() -> void:
	var world_view = _views.get("world")
	if world_view != null and is_instance_valid(world_view) and world_view.has_method("_rebuild_tiles"):
		world_view.call("_rebuild_tiles")
	else:
		var old: Control = _views.get("world") as Control
		if old != null and is_instance_valid(old):
			if old.has_method("release_clock_and_map"):
				old.call("release_clock_and_map")
			old.queue_free()
		var new_world: Control = TabWorld3DScript.new()
		view_stack.add_child(new_world)
		view_stack.move_child(new_world, 0)
		new_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_views["world"] = new_world
	_show_view("world")
	_set_active_tab("world")


## Destello azulado breve superpuesto (cosmético, no bloquea la entrada).
func _flash_transition() -> void:
	var fade := ColorRect.new()
	fade.color = Color(0.22, 0.45, 0.75, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.55, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(fade, "color:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tw.tween_callback(fade.queue_free)


func _on_combat_started(enemy_data: Dictionary) -> void:
	_previous_view_before_combat = _active_view
	# Fundido a negro unificado para evitar el "corte seco" al entrar en combate.
	Juice.transition(func() -> void:
		var combat_view := _views.get("combat", null) as ViewCombat
		if combat_view == null:
			for child in view_stack.get_children():
				if child is ViewCombat:
					combat_view = child as ViewCombat
					_views["combat"] = combat_view
					break
		if combat_view != null:
			combat_view.start_combat(enemy_data)
		_show_view("combat")
		panel_tab_bar.visible = false
	)


## `fled` unifica la huida con la victoria para la navegación de vuelta (misma
## comprobación `_previous_view_before_combat`), sin los efectos propios de
## victoria/derrota (sin sonido de derrota, sin ir a la Sala de la Esfera).
func _on_combat_ended(victory: bool, fled: bool = false) -> void:
	Engine.time_scale = 1.0
	# Volver al mapa o a la mazmorra según el resultado, con fundido de por medio.
	if victory or fled:
		AudioManager.pop_music()
		if _previous_view_before_combat == "dungeon":
			Juice.transition(func() -> void:
				_show_view("dungeon")
				panel_tab_bar.visible = false
				var dungeon_view := _views["dungeon"] as ViewDungeon
				if dungeon_view:
					dungeon_view.resume_exploration()
			)
		else:
			SceneManager.go_to_world()
	else:
		# Derrota: pasamos por la Sala de la Esfera, que al cerrarse reaparece al
		# jugador junto a la base con 1 de vida y 1 de maná.
		AudioManager.play_sfx("defeat")
		AudioManager.clear_stack()
		AudioManager.play_music("world")
		SceneManager.go_to_orb_room("death")



# ══════════════════════════════════════════════════════════════════════════════
# ATAJAR INPUTS GLOBALES Y ATACAR HOTKEYS (C, I, J, K, M, TAB, ESC)
# ══════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	_handle_global_hotkeys(event)
	# NOTA (bug reportado): `Node._input()` se ejecuta ANTES que el despacho de
	# GUI a los Controls (`_gui_input`/`pressed`). Marcar aquí como
	# "manejado" CUALQUIER clic/touch mientras el menú de Opciones está
	# abierto impedía que sus PROPIOS botones (p. ej. "Guardar y Salir" o los
	# de Tema) llegaran nunca a recibir el clic — no solo bloqueaba clics que
	# cayeran "detrás", en el mundo. Es innecesario además: `_menu_overlay`
	# cubre toda la pantalla con `mouse_filter = STOP`, así que la fase de GUI
	# ya impide por sí sola que ningún clic llegue al mundo/3D de detrás.


func _shortcut_input(event: InputEvent) -> void:
	_handle_global_hotkeys(event)


func _unhandled_key_input(event: InputEvent) -> void:
	_handle_global_hotkeys(event)


func _is_radial_hotkey(event: InputEvent) -> bool:
	if not (event is InputEventKey or event is InputEventAction):
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventKey:
		var k := event as InputEventKey
		# Tecla TAB
		if k.keycode == KEY_TAB or k.physical_keycode == KEY_TAB or k.key_label == KEY_TAB:
			return true
		# Tecla "º" / "ª" / Section / QuoteLeft (debajo de ESC en teclados españoles e internacionales)
		if k.keycode == KEY_SECTION or k.physical_keycode == KEY_SECTION or k.key_label == KEY_SECTION:
			return true
		if k.keycode == KEY_QUOTELEFT or k.physical_keycode == KEY_QUOTELEFT or k.key_label == KEY_QUOTELEFT:
			return true
		if k.unicode == 186 or k.unicode == 170 or k.unicode == 96:
			return true
	if event.is_action_pressed("ui_focus_next", false) or (InputMap.has_action("ui_tab") and event.is_action_pressed("ui_tab", false)):
		return true
	return false


func _handle_global_hotkeys(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventAction):
		return
	if not event.is_pressed() or event.is_echo():
		return

	var is_key := event is InputEventKey
	var key_event: InputEventKey = event as InputEventKey if is_key else null
	var keycode := key_event.keycode if key_event != null else 0
	var phys_code := key_event.physical_keycode if key_event != null else 0
	var is_esc := (is_key and (keycode == KEY_ESCAPE or phys_code == KEY_ESCAPE)) or event.is_action_pressed("ui_cancel", false)
	var is_tab := _is_radial_hotkey(event)

	var options_open := _menu_overlay != null and is_instance_valid(_menu_overlay)
	var radial_open := is_radial_menu_open()

	if options_open:
		if is_esc or is_tab:
			get_viewport().set_input_as_handled()
			_handle_escape_key()
		return

	if radial_open:
		if is_tab or is_esc:
			get_viewport().set_input_as_handled()
			_handle_escape_key()
		return

	var floating_views: Array[String] = ["character", "bag", "info", "encargos", "forge", "cook", "place", "city", "building", "shop"]
	var has_view_open := _active_view in floating_views

	# Si ya hay una vista o menú modal abierto, TAB / "º" cierra la vista (igual que ESC o botón Cerrar).
	if has_view_open and is_tab:
		get_viewport().set_input_as_handled()
		_handle_escape_key()
		return

	var is_bag := is_key and (keycode == KEY_I or phys_code == KEY_I or keycode == KEY_B or phys_code == KEY_B)
	var is_char := is_key and (keycode == KEY_C or phys_code == KEY_C)
	var is_journal := is_key and (keycode == KEY_J or phys_code == KEY_J)
	var is_forge := is_key and (keycode == KEY_K or phys_code == KEY_K)
	var is_world := is_key and (keycode == KEY_M or phys_code == KEY_M)

	if is_tab:
		get_viewport().set_input_as_handled()
		_toggle_radial_menu()
	elif is_bag:
		get_viewport().set_input_as_handled()
		_toggle_floating_view("bag")
	elif is_char:
		get_viewport().set_input_as_handled()
		_toggle_floating_view("character")
	elif is_journal:
		get_viewport().set_input_as_handled()
		_toggle_floating_view("info")
	elif is_forge:
		get_viewport().set_input_as_handled()
		_toggle_floating_view("forge")
	elif is_world:
		get_viewport().set_input_as_handled()
		SceneManager.go_to_world()
	elif is_esc:
		get_viewport().set_input_as_handled()
		_handle_escape_key()


func is_radial_menu_open() -> bool:
	return _radial_menu != null and is_instance_valid(_radial_menu) and _radial_menu.is_open()


func _toggle_radial_menu() -> void:
	if _radial_menu == null or not is_instance_valid(_radial_menu):
		_radial_menu = RadialMenuOverlay.new()
		_radial_menu.action_selected.connect(_on_radial_action_selected)
		_radial_menu.closed.connect(_on_radial_menu_closed)
		add_child(_radial_menu)
	_radial_menu.toggle()
	GlobalState.is_movement_locked = _radial_menu.is_open()
	if _radial_menu.is_open():
		_set_world_modal(true)


func _on_radial_menu_closed() -> void:
	# El cierre del radial es async (tween de ~150ms): si el jugador eligió una
	# opción, `_on_radial_action_selected` ya abrió el Hub (y bloqueó el
	# movimiento) ANTES de que este callback llegue. No pisar ese bloqueo.
	if _hub_modal != null and is_instance_valid(_hub_modal) and _hub_modal.visible:
		return
	GlobalState.is_movement_locked = false
	if _menu_overlay != null and is_instance_valid(_menu_overlay):
		_set_world_modal(true)
	else:
		var floating_views: Array[String] = ["character", "bag", "info", "cook"]
		_set_world_modal(_active_view in floating_views)


var _hub_modal: CharacterHubModal = null

func _get_or_create_hub_modal() -> CharacterHubModal:
	if _hub_modal == null or not is_instance_valid(_hub_modal):
		_hub_modal = CharacterHubModal.new()
		_hub_modal.name = "CharacterHubModal"
		_hub_modal.request_standalone_options.connect(_on_hub_wants_standalone_options)
		_hub_modal.closed.connect(_on_hub_modal_closed)
		add_child(_hub_modal)
	return _hub_modal


func _on_hub_modal_closed() -> void:
	_set_world_modal(false)


## El Hub (radial → Opciones, o su propia pestaña "⚙️ Opciones") ya no embebe
## una copia de `OptionsMenu` — pide EL MISMO menú grande/autosuficiente que
## abre ESC (`_open_menu()`), para que el tema, "Guardar y Salir" y el resto
## de botones se comporten siempre igual sin importar por dónde se entre.
func _on_hub_wants_standalone_options() -> void:
	if _hub_modal != null and is_instance_valid(_hub_modal):
		_hub_modal.close()
	_open_menu()


func _on_radial_action_selected(act_id: String) -> void:
	if act_id == "options":
		_open_menu()
		return
	var hub := _get_or_create_hub_modal()
	_set_world_modal(true)
	match act_id:
		"character", "equip", "bag", "professions", "journal":
			hub.open_at_tab(act_id)
		"world":
			SceneManager.go_to_world()
		_:
			hub.open_at_tab("character")


## Abre el CharacterHubModal en la pestaña indicada SIN cambiar la vista activa.
## Útil para contextos como la mazmorra, donde switch_tab("character") sacaría
## al jugador del dungeon. El modal flota encima de la vista actual (dungeon,
## combate, ciudad…) igual que al usar el menú radial del mapamundi.
## tab_id: "character" | "equip" | "bag" | "professions" | "journal"
func open_hub_modal_tab(tab_id: String = "character") -> void:
	var hub := _get_or_create_hub_modal()
	GlobalState.is_movement_locked = true
	hub.open_at_tab(tab_id)


func open_character_subtab(subtab_key: String) -> void:
	_show_view("character")
	var char_view := _views.get("character") as TabCharacter
	if char_view != null and char_view.has_method("_switch_subtab"):
		char_view.call("_switch_subtab", subtab_key)


func _toggle_floating_view(view_name: String) -> void:
	var hub := _get_or_create_hub_modal()
	var tab_map := {
		"character": "character",
		"stats": "character",
		"equip": "equip",
		"facetas": "character",
		"bag": "bag",
		"info": "journal",
		"journal": "journal",
		"encargos": "journal",
		"forge": "professions",
		"professions": "professions"
	}
	var target_tab: String = tab_map.get(view_name, "character")
	if hub.visible and hub._active_tab == target_tab:
		hub.close()
	else:
		hub.open_at_tab(target_tab)


func _handle_escape_key() -> void:
	if _hub_modal != null and is_instance_valid(_hub_modal) and _hub_modal.visible:
		_hub_modal.close()
		return
	if _menu_overlay != null and is_instance_valid(_menu_overlay):
		if _menu_overlay.has_method("close"):
			_menu_overlay.close()
		else:
			_close_menu()
		return
	if _radial_menu != null and is_instance_valid(_radial_menu) and _radial_menu.visible:
		_radial_menu.close()
		return
	if _active_view == "encargos":
		_set_world_modal(false)
		var enc_view = _views.get("encargos")
		if enc_view != null and enc_view.has_method("_on_leave_pressed"):
			enc_view.call("_on_leave_pressed")
		else:
			SceneManager.go_to_world()
		return
	if _active_view == "forge":
		_set_world_modal(false)
		var forge_view = _views.get("forge")
		if forge_view != null and forge_view.has_method("_on_leave_pressed"):
			forge_view.call("_on_leave_pressed")
		elif forge_view != null and forge_view.has_method("_on_leave"):
			forge_view.call("_on_leave")
		else:
			SceneManager.go_to_world()
		return
	if _active_view == "shop":
		_set_world_modal(false)
		var shop_view = _views.get("shop")
		if shop_view != null and shop_view.has_method("_on_leave_pressed"):
			shop_view.call("_on_leave_pressed")
		else:
			SceneManager.back_to_city()
		return
	if _active_view == "place" or _active_view == "building":
		_set_world_modal(false)
		var place_view = _views.get("place")
		if place_view != null and place_view.has_method("_leave"):
			place_view.call("_leave")
		else:
			SceneManager.go_to_world()
		return
	if _active_view == "combat" or SceneManager.in_combat:
		var combat_view = _views.get("combat")
		if combat_view != null and combat_view.has_method("toggle_pause"):
			combat_view.call("toggle_pause")
			return

	if _active_view == "transport":
		_set_world_modal(false)
		var trans_view = _views.get("transport")
		if trans_view != null and trans_view.has_method("_on_leave_pressed"):
			trans_view.call("_on_leave_pressed")
		else:
			SceneManager.back_to_city()
		return

	if _active_view == "city":
		_set_world_modal(false)
		SceneManager.go_to_world()
		return
	var floating_views: Array[String] = ["character", "bag", "info", "cook"]
	if _active_view in floating_views:
		SceneManager.go_to_world()
		return
	if SceneRunner != null and SceneRunner.is_active():
		_set_world_modal(false)
		SceneRunner.stop()
		return
	_open_menu()


# ══════════════════════════════════════════════════════════════════════════════
# GESTIÓN DE VISTAS (WINDOWED & DOCKING UI)
# ══════════════════════════════════════════════════════════════════════════════
func _show_view(view_name: String) -> void:
	var floating_views: Array[String] = ["character", "bag", "info", "cook"]
	# Garantizar que el mapa del mundo quede SIEMPRE en el fondo de la pila (índice 0)
	var world_node := _views.get("world", null) as Control
	if world_node != null and is_instance_valid(world_node) and world_node.get_parent() == view_stack:
		view_stack.move_child(world_node, 0)

	for key in _views:
		if view_name in floating_views:
			# Si abrimos una ventana flotante, el mapa 3D permanece VISIBLE en el fondo
			if key == "world":
				_views[key].visible = true
			else:
				_views[key].visible = (key == view_name)
		else:
			_views[key].visible = (key == view_name)
		if key == view_name:
			_views[key].modulate = Color.WHITE

	# Garantizar que la vista activa quede SIEMPRE al frente de la pila (en la cima del z-order)
	var target_view := _views.get(view_name, null) as Control
	if target_view != null and is_instance_valid(target_view) and target_view.get_parent() == view_stack:
		view_stack.move_child(target_view, -1)
	# OPTIMIZACIÓN MÓVIL: suspender el procesamiento de las vistas que
	# quedan en segundo plano (ocultas) y reactivarlo en las visibles. Evita gastar
	# CPU/GPU en bucles _process/_physics_process/_input de vistas no visibles.
	# "world" permanece visible bajo ventanas flotantes, por lo que sigue activa.
	for key in _views:
		var view_node: Node = _views[key]
		var is_vis: bool = view_node.visible
		view_node.set_process(is_vis)
		view_node.set_physics_process(is_vis)
		view_node.set_process_input(is_vis)
		view_node.set_process_unhandled_input(is_vis)
		view_node.set_process_unhandled_key_input(is_vis)
	_active_view = view_name
	# Avisar al mapamundi para que bloquee input y ajuste el encuadre en horizontal.
	var world_view = _views.get("world")
	if world_view != null and world_view.has_method("set_modal_mode"):
		world_view.call("set_modal_mode", view_name in floating_views)
	if SceneManager != null:
		SceneManager.current_view_name = view_name
		SceneManager.view_changed.emit(view_name)
	panel_coming_soon.visible = false
	_update_location_bar(view_name)
	_set_hud_panel_visible(view_name != "combat" and view_name != "orb_room")
	_update_hud_center_and_right_slots(view_name)
	if bar_en:
		bar_en.visible = false
	if _materials_box:
		_materials_box.visible = (view_name != "dungeon")
	_update_radial_button_visibility()
	if view_name == "world" or view_name == "dungeon":
		_flush_pending_levelup_toasts()


## Refresca dinámicamente el título del centro del HUD superior.
func refresh_hud_location_title() -> void:
	_update_hud_center_and_right_slots(_active_view)


func _update_hud_center_and_right_slots(view_name: String) -> void:
	var center_slot: HBoxContainer = get_node_or_null("VBoxMain/PanelHUD/MarginHUD/VBoxHUDTop/HBoxTopColumns/HUDCenterSlot") as HBoxContainer
	var right_slot: HBoxContainer = get_node_or_null("VBoxMain/PanelHUD/MarginHUD/VBoxHUDTop/HBoxTopColumns/CardHUDRight/MarginContainer/VBoxContainer/HBoxSecondary/HUDRightSlot") as HBoxContainer
	if right_slot == null:
		right_slot = get_node_or_null("VBoxMain/PanelHUD/MarginHUD/VBoxHUDTop/HBoxTopColumns/HUDRightSlot") as HBoxContainer

	if center_slot != null:
		if _hud_center_label == null:
			_hud_center_label = Label.new()
			_hud_center_label.name = "HUDCenterLabel"
			_hud_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_hud_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_hud_center_label.add_theme_font_size_override("font_size", 44)
			_hud_center_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
			UiKit.apply_heading(_hud_center_label)
			center_slot.add_child(_hud_center_label)

		var title_text: String = ""
		if view_name == "dungeon":
			var dun_view: Control = _views.get("dungeon", null) as Control
			if dun_view != null and dun_view.has_method("get_dungeon_name"):
				title_text = String(dun_view.call("get_dungeon_name"))
			if title_text.is_empty():
				title_text = Locale.t("loc_dungeon")
		elif view_name == "world":
			var world_view: Control = _views.get("world", null) as Control
			if world_view != null and world_view.has_method("get_active_location_title"):
				title_text = String(world_view.call("get_active_location_title"))
		elif view_name == "place":
			var place_view: Control = _views.get("place", null) as Control
			if place_view != null and place_view.has_method("get_location_name"):
				title_text = String(place_view.call("get_location_name"))
			if title_text.is_empty():
				title_text = Locale.t("loc_place")
		elif view_name == "building":
			var b_view: Control = _views.get("building", null) as Control
			if b_view != null and b_view.has_method("get_location_name"):
				title_text = String(b_view.call("get_location_name"))
			if title_text.is_empty():
				title_text = Locale.t("loc_building")
		elif view_name in ["city", "transport", "encargos", "forge", "shop"]:
			var v: Control = _views.get(view_name, null) as Control
			if v != null and v.has_method("get_location_name"):
				title_text = String(v.call("get_location_name"))
		elif view_name != "combat" and view_name != "orb_room":
			title_text = Locale.t("loc_" + view_name)
			if title_text.begins_with("LOC_"):
				title_text = ""

		_hud_center_label.text = title_text
		_hud_center_label.visible = not title_text.is_empty()

	var show_clock_and_map: bool = view_name in ["world", "character", "bag", "info", "cook"]
	if right_slot != null:
		var world_view = _views.get("world")
		if show_clock_and_map:
			if world_view != null:
				world_view.attach_clock_and_map_to_slot(right_slot)
		elif world_view != null:
			# Sin esto, el reloj del mundo se quedaba colgando bajo el
			# HUD de HP/MP/Oro en vistas que no lo usan (p. ej. mazmorra), ya
			# que las vistas nunca se destruyen.
			world_view.hide_clock_and_map()
	# Botón de mapa flotante (junto al ☰): mismas vistas que antes lo mostraban
	# dockeado en `HUDRightSlot`, pero ahora como botón flotante independiente.
	if _btn_floating_map == null and show_clock_and_map:
		_build_floating_map_button()
	if _btn_floating_map != null:
		_btn_floating_map.visible = show_clock_and_map


# ══════════════════════════════════════════════════════════════════════════════
# CABECERA COMPARTIDA DE UBICACIÓN  ("dónde estás" + botón de volver al mundo)
#   Vive entre el HUD y el ViewStack. Se muestra en TODAS las vistas excepto el
#   propio mundo y el combate, dando una navegación consistente hacia el mapa.
# ══════════════════════════════════════════════════════════════════════════════
func _build_location_bar() -> void:
	_location_bar = PanelContainer.new()
	_location_bar.visible = false
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = UiKit.BG_BASE
	bar_style.border_width_bottom = 1
	bar_style.border_color = UiKit.BORDER
	_location_bar.add_theme_stylebox_override("panel", bar_style)

	var margin := UiKit.margins(18, 14, 8, 8)
	_location_bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	_location_lbl = Label.new()
	_location_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_location_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_location_lbl.add_theme_font_size_override("font_size", 34)
	_location_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	hbox.add_child(_location_lbl)

	_location_return_btn = Button.new()
	_location_return_btn.text = Locale.t("loc_return_world")
	_location_return_btn.custom_minimum_size = Vector2(0, 54)
	_location_return_btn.add_theme_font_size_override("font_size", 26)
	for st in ["normal", "hover", "pressed", "focus"]:
		_location_return_btn.add_theme_stylebox_override(st, UiKit.button_tonal(UiKit.ACCENT))
	_location_return_btn.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
	_location_return_btn.add_theme_color_override("font_hover_color", UiKit.ACCENT_SOFT)
	_location_return_btn.pressed.connect(func() -> void: SceneManager.go_to_world())
	hbox.add_child(_location_return_btn)

	var main := $VBoxMain as VBoxContainer
	main.add_child(_location_bar)
	main.move_child(_location_bar, 1)  # entre PanelHUD (0) y ViewStack


## Actualiza la cabecera de ubicación: la oculta en mundo/combate y, en el resto,
## muestra el nombre localizado de la vista actual.
func _update_location_bar(_view_name: String) -> void:
	if _location_bar == null:
		return
	# Las vistas individuales ya implementan sus propias cabeceras locales personalizadas.
	# Ocultamos la barra global en todas ellas para evitar cabeceras dobles.
	_location_bar.visible = false


## Título localizado de una vista para la cabecera de ubicación.
func _location_title(view_name: String) -> String:
	return Locale.t("loc_" + view_name)


# ══════════════════════════════════════════════════════════════════════════════
# PELIGRO AMBIENTAL  (insolación en desierto · congelación en nieve)
#   Una barra bajo el HUD se llena mientras pisas un bioma peligroso en el mundo.
#   Si llega al máximo, el héroe muere y reaparece en la base con 1 de vida.
# ══════════════════════════════════════════════════════════════════════════════
func _build_hazard_bar() -> void:
	_hazard_panel = PanelContainer.new()
	_hazard_panel.visible = false
	var st := StyleBoxFlat.new()
	st.bg_color = UiKit.BG_BASE
	st.border_width_bottom = 1
	st.border_color = UiKit.BORDER
	_hazard_panel.add_theme_stylebox_override("panel", st)

	var m := UiKit.margins(18, 18, 6, 8)
	_hazard_panel.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	m.add_child(row)

	_hazard_lbl = Label.new()
	_hazard_lbl.add_theme_font_size_override("font_size", 22)
	_hazard_lbl.custom_minimum_size = Vector2(180, 0)
	_hazard_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_hazard_lbl)

	_hazard_bar = ProgressBar.new()
	_hazard_bar.show_percentage = false
	_hazard_bar.min_value = 0.0
	_hazard_bar.max_value = 1.0
	_hazard_bar.custom_minimum_size = Vector2(0, 22)
	_hazard_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hazard_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = UiKit.BG_DEEP
	bg.set_corner_radius_all(11)
	bg.set_border_width_all(1)
	bg.border_color = UiKit.BORDER
	_hazard_bar.add_theme_stylebox_override("background", bg)
	row.add_child(_hazard_bar)

	var main := $VBoxMain as VBoxContainer
	main.add_child(_hazard_panel)
	main.move_child(_hazard_panel, 1)  # Justo debajo del HUD (índice 0)


## Acumula/decae el peligro cada frame según el terreno pisado en el mundo.
## El peligro ("heat"/"cold"/"") es 100% DATA-DRIVEN (Design.terrain_hazard,
## campo `hazard` de data/world_terrains/<code>.json): ya no hay una regla
## especial de "rodeado de desierto" cableada — si un terreno debe ser inocuo
## en sus bordes (playas/oasis), basta con darle su PROPIO código sin `hazard`
## (p. ej. "arena" separado de "desierto", ver ).
func _process(delta: float) -> void:
	var kind := ""
	if _active_view == "world":
		var cell: CellResource = GlobalState.hexagons_db.get(GlobalState.player_pos, null) as CellResource
		if cell:
			kind = Design.terrain_hazard(cell.terrain)

	if kind != "":
		_hazard_kind = kind
		_hazard_value += (delta / GameConfig.HAZARD_FILL_SECONDS) * _hazard_fill_mult(kind)
		if _hazard_value >= 1.0:
			_hazard_value = 0.0
			_refresh_hazard_bar()
			_player_died_from_hazard()
			return
	else:
		_hazard_value = maxf(0.0, _hazard_value - delta / GameConfig.HAZARD_DECAY_SECONDS)
	_refresh_hazard_bar()


## Multiplicador de velocidad de llenado de la barra de peligro según el
## equipo activo (p. ej. "Ropaje Nómada"/"Amuleto Solar" reducen un 30% cada
## uno, de forma acumulativa, la velocidad con la que sube la insolación al
## pisar desierto). Cualidad data-driven `heat_hazard_reduction` (traits de
## EquipmentResource), solo aplica cuando `kind == "heat"`.
func _hazard_fill_mult(kind: String) -> float:
	if kind != "heat":
		return 1.0
	var reduction := 0.0
	for eq_slot in GlobalState.equipped.keys():
		var eq_res: EquipmentResource = GlobalState.equipped[eq_slot]
		if eq_res != null:
			for trait_entry in eq_res.active_traits():
				if String(trait_entry.get("type", "")) == "heat_hazard_reduction":
					reduction += float(trait_entry.get("value", 0.0))
	return clampf(1.0 - reduction, 0.0, 1.0)


## Refresca la barra de peligro (color según insolación/congelación) y su visibilidad.
func _refresh_hazard_bar() -> void:
	if _hazard_panel == null:
		return
	var show_bar: bool = _hazard_value > 0.001
	_hazard_panel.visible = show_bar
	if not show_bar:
		return
	_hazard_bar.value = _hazard_value
	var fill_col: Color = Color(0.90, 0.24, 0.14) if _hazard_kind == "heat" else Color(0.62, 0.82, 1.0)
	_hazard_bar.add_theme_stylebox_override("fill", UiKit.bar_fill(fill_col, 11))
	_hazard_lbl.text = Locale.t("hazard_heat") if _hazard_kind == "heat" else Locale.t("hazard_cold")
	_hazard_lbl.add_theme_color_override("font_color", fill_col)


## Muerte por peligro ambiental: pasa por la Sala de la Esfera y reaparece junto
## a la base con 1 de vida y 1 de maná (mismo flujo que la derrota en combate).
func _player_died_from_hazard() -> void:
	GlobalState.pending_death_cause = {"cause": "hazard", "hazard_type": _hazard_kind}
	AudioManager.play_sfx("defeat")
	AudioManager.clear_stack()
	AudioManager.play_music("world")
	SceneManager.go_to_orb_room("death")


const PROF_TEXTURES := {
	"Don Nadie": "res://assets/combat/character/prof_av_don_nadie.png",
	"Guerrero": "res://assets/combat/character/prof_av_guerrero.png",
	"Arquero": "res://assets/combat/character/prof_av_arquero.png",
	"Tiempo": "res://assets/combat/character/prof_av_tiempo.png",
	"Psíquico": "res://assets/combat/character/prof_av_psiquico.png",
	"Psiquico": "res://assets/combat/character/prof_av_psiquico.png",
	"Elementalista": "res://assets/combat/character/prof_av_elementalista.png",
	"Sacerdote": "res://assets/combat/character/prof_av_sacerdote.png",
}

# ══════════════════════════════════════════════════════════════════════════════
# HUD
# ══════════════════════════════════════════════════════════════════════════════
func _refresh_hud() -> void:
	# Nivel base
	lbl_level.text     = Locale.t("hud_base_level", [GlobalState.level])
	if _hero_avatar_lbl != null:
		_hero_avatar_lbl.text = _profession_label()
	
	# Nivel de profesión (job)
	var job_prog: Dictionary = GlobalState.get_profession_progress(GlobalState.profession)
	lbl_job_level.text = Locale.t("hud_job_level", [int(job_prog.get("level", GlobalState.job_level))])
		
	if lbl_gold:
		lbl_gold.text = "💰 %d" % GlobalState.gold
	
	bar_hp.max_value = GlobalState.max_hp
	bar_hp.value = GlobalState.hp
	if GlobalState.is_poisoned:
		lbl_hp.text = "☣️ HP: %d/%d" % [GlobalState.hp, GlobalState.max_hp]
		lbl_hp.add_theme_color_override("font_color", Color("39ff14"))
		bar_hp.add_theme_stylebox_override("fill", UiKit.bar_fill(Color("39ff14"), 10))
	else:
		lbl_hp.text = "HP: %d/%d" % [GlobalState.hp, GlobalState.max_hp]
		lbl_hp.remove_theme_color_override("font_color")
		bar_hp.add_theme_stylebox_override("fill", UiKit.bar_fill(UiKit.HP, 10))

	bar_mp.max_value = GlobalState.max_mp
	bar_mp.value = GlobalState.mp
	lbl_mp.text = "MP: %d/%d" % [GlobalState.mp, GlobalState.max_mp]

	# (Game Feel §3): las barras de HP/MP deben sentirse vivas — un
	# brillo sutil (rojo al bajar, verde al subir) SOLO cuando el valor cambia
	# de verdad, no en cada refresco en frío del HUD.
	if _last_hud_hp != -1 and GlobalState.hp != _last_hud_hp:
		Juice.flash(bar_hp, UiKit.GOOD if GlobalState.hp > _last_hud_hp else UiKit.HP, 0.35)
	if _last_hud_mp != -1 and GlobalState.mp != _last_hud_mp:
		Juice.flash(bar_mp, UiKit.MP.lightened(0.4) if GlobalState.mp > _last_hud_mp else UiKit.MP, 0.35)
	_last_hud_hp = GlobalState.hp
	_last_hud_mp = GlobalState.mp

	# /§10: pulso rojo persistente cuando la vida está en peligro (≤25%),
	# igual que en combate. Se detiene solo al recuperar vida por encima del umbral.
	var hp_danger: bool = GlobalState.max_hp > 0 and float(GlobalState.hp) / float(GlobalState.max_hp) <= 0.25 and GlobalState.hp > 0
	if hp_danger and not _hud_hp_in_danger:
		_start_hud_hp_danger()
	elif not hp_danger and _hud_hp_in_danger:
		_stop_hud_hp_danger()
	_hud_hp_in_danger = hp_danger

	_refresh_materials_row()

	# Energía de habilidades de mazmorra (barra verde)
	bar_en.max_value = GlobalState.max_energy
	bar_en.value = GlobalState.energy
	lbl_en.text = "EN: %d/%d" % [int(GlobalState.energy), GlobalState.max_energy]
	
	# Barras de experiencia
	bar_xp.max_value = GlobalState.xp_needed
	bar_xp.value     = GlobalState.xp
	
	bar_job_xp.max_value = int(job_prog.get("xp_needed", GlobalState.job_xp_needed))
	bar_job_xp.value     = int(job_prog.get("xp", GlobalState.job_xp))

	if _hero_avatar is TextureRect:
		var prof_name: String = String(GlobalState.profession)
		var prof_tex_path: String = PROF_TEXTURES.get(prof_name, "res://assets/combat/character/prof_av_don_nadie.png")
		var tex := UiKit.load_texture_safe(prof_tex_path)
		if tex:
			_hero_avatar.texture = tex


## Arranca el pulso rojo de peligro en la barra de HP del HUD (vida ≤25%).
func _start_hud_hp_danger() -> void:
	if bar_hp == null or Locale.reduce_motion:
		return
	if _hud_hp_danger_tween != null and _hud_hp_danger_tween.is_valid():
		_hud_hp_danger_tween.kill()
	_hud_hp_danger_tween = bar_hp.create_tween().set_loops()
	_hud_hp_danger_tween.tween_property(bar_hp, "modulate", Color(1.6, 0.55, 0.55), 0.45).set_trans(Tween.TRANS_SINE)
	_hud_hp_danger_tween.tween_property(bar_hp, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)


## Detiene el pulso de peligro y restaura el color normal de la barra de HP.
func _stop_hud_hp_danger() -> void:
	if _hud_hp_danger_tween != null and _hud_hp_danger_tween.is_valid():
		_hud_hp_danger_tween.kill()
		_hud_hp_danger_tween = null
	if bar_hp != null:
		bar_hp.modulate = Color.WHITE


## Reconstruye la fila de materiales farmeables: por cada recurso recolectable
## que poseemos, muestra su icono + cantidad en tarjetas alineadas a la IZQUIERDA.
func _refresh_materials_row() -> void:
	if _items_box == null:
		return
	for child in _items_box.get_children():
		child.queue_free()
	for skill in GameConfig.GATHER_RESOURCES:
		var r: Dictionary = GameConfig.GATHER_RESOURCES[skill]
		var rid: String = String(r["id"])
		var owned: int = int(GlobalState.get_item(rid).get("quantity", 0))
		if owned <= 0:
			continue
		var qty_txt: String = "99+" if owned > 99 else str(owned)
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = UiKit.BG_DEEP
		st.set_corner_radius_all(8)
		st.set_content_margin_all(4)
		st.content_margin_left = 10
		st.content_margin_right = 10
		st.border_width_bottom = 1
		st.border_color = UiKit.BORDER
		chip.add_theme_stylebox_override("panel", st)

		var lbl := Label.new()
		lbl.text = "%s %s" % [String(r["icon"]), qty_txt]
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", UiKit.TEXT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(lbl)
		_items_box.add_child(chip)

	# Mostrar buffs temporales de comida activos
	for buff_key in GlobalState.food_buffs:
		if GlobalState.has_food_buff(buff_key):
			var rem: int = max(0, int(GlobalState.food_buffs[buff_key]) - GlobalState._now_unix())
			var chip := PanelContainer.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.18, 0.14, 0.05, 0.95)
			st.border_color = UiKit.COLOR_GOLD_PRIMARY
			st.set_border_width_all(1)
			st.set_corner_radius_all(8)
			st.set_content_margin_all(4)
			st.content_margin_left = 10
			st.content_margin_right = 10
			chip.add_theme_stylebox_override("panel", st)

			var lbl := Label.new()
			lbl.text = "🍲 %s (%dm)" % [buff_key.capitalize(), int(ceil(rem / 60.0))]
			lbl.add_theme_font_size_override("font_size", 24)
			lbl.add_theme_color_override("font_color", UiKit.COLOR_GOLD_PRIMARY)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(lbl)
			_items_box.add_child(chip)


## Símbolo del avatar del HUD según la profesión activa.
func _hero_symbol() -> String:
	var def = Design.get_profession(GlobalState.profession)
	if not def.is_empty():
		return def.get("icon", "🧝")
	return "🧝"


## Devuelve el nombre de la profesión traducido para el HUD.
func _profession_label() -> String:
	var def = Design.get_profession(GlobalState.profession)
	if not def.is_empty():
		return Locale.pick(def.get("name", {}))
	return GlobalState.profession


## Traduce los textos de la barra de pestañas inferior.
func _refresh_tab_texts() -> void:
	var sz := get_viewport_rect().size
	var is_landscape := sz.x > sz.y
	if is_landscape:
		btn_world.text     = "🗺️ " + Locale.t("tab_world")
		btn_character.text = "👤 " + Locale.t("tab_character")
		btn_bag.text       = "🎒 " + Locale.t("tab_bag")
		btn_info.text      = "📜 " + Locale.t("tab_info")
		btn_opts.text      = "⚙️ " + Locale.t("tab_options")
		for b in [btn_world, btn_character, btn_bag, btn_info, btn_opts]:
			b.add_theme_font_size_override("font_size", 19)
	else:
		btn_world.text     = "🗺️\n" + Locale.t("tab_world")
		btn_character.text = "👤\n" + Locale.t("tab_character")
		btn_bag.text       = "🎒\n" + Locale.t("tab_bag")
		btn_info.text      = "📜\n" + Locale.t("tab_info")
		btn_opts.text      = "⚙️\n" + Locale.t("tab_options")
		for b in [btn_world, btn_character, btn_bag, btn_info, btn_opts]:
			b.add_theme_font_size_override("font_size", 40)


## Reacciona al cambio de idioma global.
func _on_locale_changed() -> void:
	_refresh_tab_texts()
	_refresh_hud()
	if _location_return_btn != null:
		_location_return_btn.text = Locale.t("loc_return_world")
	_update_location_bar(_active_view)


# ══════════════════════════════════════════════════════════════════════════════
# MENÚ / OPCIONES EN JUEGO
# ══════════════════════════════════════════════════════════════════════════════
func _set_world_modal(active: bool) -> void:
	GlobalState.is_movement_locked = active
	var world_view = _views.get("world")
	if world_view != null and world_view.has_method("set_modal_mode"):
		world_view.call("set_modal_mode", active)
	var dungeon_view = _views.get("dungeon")
	if dungeon_view != null:
		if active and dungeon_view.has_method("stop_exploration"):
			dungeon_view.call("stop_exploration")
		elif not active and dungeon_view.has_method("resume_exploration"):
			dungeon_view.call("resume_exploration")
	if _btn_floating_map != null:
		var show_map: bool = (_active_view in ["world", "character", "bag", "info", "cook"]) and not active
		_btn_floating_map.visible = show_map


func _open_menu() -> void:
	if _menu_overlay != null and is_instance_valid(_menu_overlay):
		return
	var menu := OPTIONS_SCENE.instantiate() as OptionsMenu
	menu.show_main_menu_button = true
	_menu_overlay = menu
	add_child(menu)
	menu.closed.connect(_close_menu)
	menu.main_menu_requested.connect(_on_return_to_main_menu)
	# Mantener resaltada la pestaña previa (el menú es un overlay temporal).
	_set_active_tab(_active_view if _active_view in ["world", "character", "bag", "info"] else "world")
	_set_world_modal(true)


func _close_menu() -> void:
	if _menu_overlay != null and is_instance_valid(_menu_overlay):
		_menu_overlay.queue_free()
	_menu_overlay = null
	var floating_views: Array[String] = ["character", "bag", "info", "cook"]
	_set_world_modal(_active_view in floating_views)


func _on_return_to_main_menu() -> void:
	# Si se pide "Guardar y Salir" estando dentro de una mazmorra, abandonarla
	# primero (SaveManager.save_game() se niega a guardar mientras
	# is_in_dungeon() es true) para que el progreso se persista de verdad.
	if SaveManager.is_in_dungeon():
		SceneManager.current_view_name = "world"
		SceneManager.current_tab_name = "world"
	# Comprobar el resultado real del guardado. Si por cualquier motivo
	# (debug/test room/partida no activa/error de disco) `save_game()`
	# devuelve `false`, no salir en silencio: pedir confirmación explícita de
	# si se desea abandonar SIN guardar antes de cambiar de escena.
	var saved_ok: bool = SaveManager.save_game()
	if saved_ok:
		get_tree().change_scene_to_file(MAIN_MENU_PATH)
		return
	UiKit.confirm(
		self,
		Locale.pick({"es": "No se pudo guardar", "en": "Could not save"}),
		Locale.pick({
			"es": "No ha sido posible guardar la partida. ¿Deseas salir al Menú Principal SIN guardar?",
			"en": "The game could not be saved. Do you want to exit to the Main Menu WITHOUT saving?"
		}),
		Locale.pick({"es": "Salir sin guardar", "en": "Exit without saving"}),
		Locale.pick({"es": "Cancelar", "en": "Cancel"}),
		func() -> void: get_tree().change_scene_to_file(MAIN_MENU_PATH)
	)


# ══════════════════════════════════════════════════════════════════════════════
# TAB BAR — Resaltado del tab activo
# ══════════════════════════════════════════════════════════════════════════════
func _set_active_tab(tab: String) -> void:
	if SceneManager != null:
		SceneManager.current_tab_name = tab
	var all_btns: Array[Button] = [btn_world, btn_character, btn_bag, btn_info, btn_opts]
	var tab_keys: Array[String] = ["world", "character", "bag", "info", "options"]

	# Pestaña activa: cápsula tonal ámbar con barra superior de acento + brillo.
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.16)
	active_style.set_corner_radius_all(16)
	active_style.border_width_top = 3
	active_style.border_color = UiKit.ACCENT
	active_style.content_margin_top = 14
	active_style.content_margin_bottom = 14
	active_style.shadow_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.18)
	active_style.shadow_size = 8

	for i in range(all_btns.size()):
		var b := all_btns[i]
		if tab_keys[i] == tab:
			b.add_theme_color_override("font_color", UiKit.ACCENT_SOFT)
			b.add_theme_color_override("font_hover_color", UiKit.ACCENT_SOFT)
			b.add_theme_color_override("font_focus_color", UiKit.ACCENT_SOFT)
			b.add_theme_color_override("font_pressed_color", UiKit.ACCENT)
			for st in ["normal", "hover", "focus", "pressed"]:
				b.add_theme_stylebox_override(st, active_style)
			if b.size.x > 1.0:
				UiKit.pop(b, 1.06, 0.18)
		else:
			b.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
			b.add_theme_color_override("font_hover_color", UiKit.ACCENT_SOFT)
			b.add_theme_color_override("font_focus_color", UiKit.TEXT_FAINT)
			b.add_theme_color_override("font_pressed_color", UiKit.ACCENT)
			for st in ["normal", "hover", "focus", "pressed"]:
				b.add_theme_stylebox_override(st, StyleBoxEmpty.new())


# ══════════════════════════════════════════════════════════════════════════════
# REGENERACIÓN PASIVA (tick de PassiveTimer = 1 s; en el mundo, junto a la Hoguera)
# ══════════════════════════════════════════════════════════════════════════════
func _on_passive_timer_timeout() -> void:
	# La HOGUERA ya NO regenera vida/maná pasivamente por estar junto a ella o
	# construirla (filosofía /): la única forma de curarse es COMER
	# comida cocinada (ver GlobalState.eat_food / CampEatMenu). Sin efecto por ahora.
	pass


# ══════════════════════════════════════════════════════════════════════════════
# OVERLAY "PRÓXIMAMENTE" — botón cerrar
# ══════════════════════════════════════════════════════════════════════════════
func _on_btn_close_cs_pressed() -> void:
	SceneManager.switch_tab("world")


# ══════════════════════════════════════════════════════════════════════════════
# PROGRESO OFFLINE — al volver tras cerrar la app, recolectas algo automáticamente
# ══════════════════════════════════════════════════════════════════════════════
func _check_offline_progress() -> void:
	var summary: Dictionary = GlobalState.apply_offline_progress()
	var gains: Dictionary = summary.get("gains", {})
	if summary.is_empty() or gains.is_empty():
		return
	_show_offline_popup(int(summary.get("seconds", 0)), gains)


func _show_offline_popup(seconds: int, gains: Dictionary) -> void:
	var root := UiKit.overlay(self)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.BG_BASE, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.5), 22, 2))
	center.add_child(panel)

	var margin := UiKit.margins(40, 40, 34, 34)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = Locale.t("offline_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.97, 0.78, 0.26, 1.0))
	vbox.add_child(title)

	var away := Label.new()
	away.text = Locale.t("offline_away", [_format_offline_time(seconds)])
	away.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	away.add_theme_font_size_override("font_size", 23)
	away.add_theme_color_override("font_color", Color(0.78, 0.8, 0.88, 1.0))
	vbox.add_child(away)

	var gathered := Label.new()
	gathered.text = Locale.t("offline_gathered")
	gathered.add_theme_font_size_override("font_size", 20)
	gathered.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7, 1.0))
	vbox.add_child(gathered)

	for rid in gains.keys():
		var info: Dictionary = _res_display(String(rid))
		var g := Label.new()
		g.text = "%s  +%d  %s" % [info["icon"], int(gains[rid]), info["name"]]
		g.add_theme_font_size_override("font_size", 26)
		g.add_theme_color_override("font_color", Color(0.6, 0.95, 0.55, 1.0))
		vbox.add_child(g)

	var btn := Button.new()
	btn.text = Locale.t("offline_collect")
	btn.custom_minimum_size = Vector2(0, 64)
	btn.add_theme_font_size_override("font_size", 26)
	btn.pressed.connect(func() -> void: root.queue_free())
	vbox.add_child(btn)


## Formatea segundos como "%dh %dm" o "%dm".
func _format_offline_time(seconds: int) -> String:
	var h: int = int(float(seconds) / 3600.0)
	var m: int = int(float(seconds % 3600) / 60.0)
	if h > 0:
		return Locale.t("offline_hours", [h, m])
	return Locale.t("offline_minutes", [maxi(1, m)])


## Icono + nombre traducido de un recurso por su id (busca en GATHER_RESOURCES).
func _res_display(res_id: String) -> Dictionary:
	for skill in GameConfig.GATHER_RESOURCES:
		var r: Dictionary = GameConfig.GATHER_RESOURCES[skill]
		if r["id"] == res_id:
			return {"name": Locale.t(r["loc"]), "icon": r["icon"]}
	return {"name": res_id, "icon": "📦"}
