# TabCharacter.gd
# Controlador de la Ficha de Personaje. Muestra Stats + Facetas en una única
# pantalla (2 columnas en apaisado). Profesiones y Equipo son pestañas propias
# de primer nivel del Hub (`TabProfessions.gd`/`TabEquip.gd` vía
# `CharacterHubModal`); el Bestiario vive en la pantalla Información (Menú).
# La barra de sub-pestañas interna es legado oculto (ver `_refresh()`): ya no
# se usa para navegar, siempre se construye la vista unificada.
# UI construida por código.
class_name TabCharacter
extends Control

# ─── REFERENCIAS UI (construida por código) ───────────────────────────────────
var _content: PanelContainer # Host donde se dibuja la sub-vista activa
var _active_scroll: ScrollContainer = null
var _tab_btns: Dictionary = {} # key de sub-tab -> Button
var _tabbar_panel_h: PanelContainer
var _tabbar_panel_v: PanelContainer
var _tabbar_h: HBoxContainer
var _tabbar_v: VBoxContainer
var _landscape_tabs: bool = false

## Profesiones (clases) que el jugador puede activar desde la pestaña Profesiones.
var PROFESSIONS: Array[String] = []

# ─── ESTADO INTERNO ──────────────────────────────────────────────────────────
var _active_subtab: String = "stats"
var _dirty: bool = true
## Secciones cerradas del acordeón de Stats. Por defecto está vacío {} para que TODAS comiencen desplegadas.
var _stats_closed: Dictionary = {}
## Asignación PROVISIONAL de puntos de característica:
## key -> nº de puntos marcados con "+" pero AÚN NO confirmados/aplicados a
## `GlobalState.stats`. Se descarta al reconstruir la vista sin confirmar.
var _pending_stat_alloc: Dictionary = {}
## Profesión que se está INSPECCIONANDO en la subpestaña Profesiones (selector
## horizontal). Es independiente de la profesión ACTIVA (que se activa con su botón).
var _prof_selected: String = ""

const STAT_NAMES: Dictionary = {
	"str": "STR",
	"agi": "AGI",
	"vit": "VIT",
	"int": "INT",
	"dex": "DEX",
	"luk": "LUK"
}

const MARGIN: float = 16.0

## Iconos y colores de cada característica base.
const STAT_ICONS: Dictionary = {
	"str": "💪", "agi": "🏃", "vit": "❤️",
	"int": "🔮", "dex": "🎯", "luk": "🍀",
}

## Qué estadísticas finales potencia cada característica (texto bilingüe inline).
const STAT_INFLUENCE: Dictionary = {
	"str": {"es": "Daño físico · Def. física · Carga", "en": "Phys. dmg · Phys. def · Load"},
	"agi": {"es": "Velocidad · Esquiva", "en": "Speed · Dodge"},
	"vit": {"es": "HP · Def. física · Def. mágica", "en": "HP · Phys. def · Magic def"},
	"int": {"es": "MP · Daño mágico · Def. mágica", "en": "MP · Magic dmg · Magic def"},
	"dex": {"es": "Daño distancia · Puntería · Crít.", "en": "Ranged dmg · Accuracy · Crit"},
	"luk": {"es": "Crítico · Esquiva · Puntería", "en": "Crit · Dodge · Accuracy"},
}


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════
var _is_updating_layout: bool = false


func _ready() -> void:
	PROFESSIONS.clear()
	for k in Design.get_professions().keys():
		PROFESSIONS.append(k)
	_build_shell()
	GlobalState.state_updated.connect(_refresh)
	Locale.locale_changed.connect(_on_locale_changed)
	get_viewport().size_changed.connect(_update_responsive_layout)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			_update_responsive_layout()
			# `_dirty` se marcaba en `_refresh()` cuando `state_updated` llegaba
			# con la pestaña oculta, pero nunca se consumía: los datos quedaban
			# desactualizados hasta el SIGUIENTE `state_updated`.
			if _dirty:
				_refresh()
	)
	_update_responsive_layout()
	call_deferred("_update_responsive_layout")
	_switch_subtab("stats")


## Construye el armazón: fondo, host de contenido y barra de sub-pestañas
## que en horizontal pasa al lateral izquierdo.
func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Antes esta pestaña dibujaba su propio "ModalCard" con
	# borde cian, redundante ahora que vive embebida dentro del panel dorado
	# del Hub (CharacterHubModal._content_panel). Se elimina ese envoltorio y
	# el contenido rellena directamente el marco que ya proporciona el Hub.
	var holder := Control.new()
	holder.name = "Holder"
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(holder)

	# Host de la sub-vista.
	_content = PanelContainer.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.clip_contents = true
	holder.add_child(_content)

	# Sub-pestañas inferiores (vertical).
	_tabbar_panel_h = PanelContainer.new()
	_tabbar_panel_h.name = "TabBarPanelH"
	var bar_style_h := StyleBoxFlat.new()
	bar_style_h.bg_color = UiKit.BG_BASE
	bar_style_h.border_width_top = 2
	bar_style_h.border_color = UiKit.BORDER
	_tabbar_panel_h.add_theme_stylebox_override("panel", bar_style_h)
	holder.add_child(_tabbar_panel_h)

	_tabbar_h = HBoxContainer.new()
	_tabbar_h.name = "TabBarH"
	_tabbar_h.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabbar_h.add_theme_constant_override("separation", 6)
	_tabbar_panel_h.add_child(_tabbar_h)

	# Sub-pestañas laterales (horizontal).
	_tabbar_panel_v = PanelContainer.new()
	_tabbar_panel_v.name = "TabBarPanelV"
	var bar_style_v := StyleBoxFlat.new()
	bar_style_v.bg_color = UiKit.BG_BASE
	bar_style_v.border_width_right = 2
	bar_style_v.border_color = UiKit.BORDER
	_tabbar_panel_v.add_theme_stylebox_override("panel", bar_style_v)
	holder.add_child(_tabbar_panel_v)

	_tabbar_v = VBoxContainer.new()
	_tabbar_v.name = "TabBarV"
	_tabbar_v.alignment = BoxContainer.ALIGNMENT_BEGIN
	_tabbar_v.add_theme_constant_override("separation", 6)
	_tabbar_panel_v.add_child(_tabbar_v)

	_tab_btns.clear()
	for entry in _subtab_defs():
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 34)
		b.text = entry["label"]
		var key: String = entry["key"]
		b.pressed.connect(func() -> void: _switch_subtab(key))
		_tabbar_h.add_child(b)
		_tab_btns[key] = b
	_refresh_v_sidebar()


var _sp_v: Control = null
var _btn_close_v: Button = null

func _refresh_v_sidebar() -> void:
	if _tabbar_v == null:
		return
	for c in _tabbar_v.get_children():
		_tabbar_v.remove_child(c)

	for entry in _subtab_defs():
		var key: String = entry["key"]
		if _tab_btns.has(key):
			var b: Button = _tab_btns[key]
			if b.get_parent() != null:
				b.get_parent().remove_child(b)
			_tabbar_v.add_child(b)

	if _sp_v == null:
		_sp_v = Control.new()
		_sp_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabbar_v.add_child(_sp_v)

	if _btn_close_v == null:
		_btn_close_v = Button.new()
		_btn_close_v.text = "🚪 " + Locale.pick({"es": "Cerrar", "en": "Close"})
		_btn_close_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_btn_close_v.custom_minimum_size = Vector2(0, 64)
		_btn_close_v.add_theme_font_size_override("font_size", 22)
		for st in ["normal", "hover", "pressed", "focus"]:
			_btn_close_v.add_theme_stylebox_override(st, UiKit.button_tonal(UiKit.BAD))
		_btn_close_v.pressed.connect(_on_close_pressed)
	_tabbar_v.add_child(_btn_close_v)


func _on_close_pressed() -> void:
	var n: Node = get_parent()
	while n != null:
		if n is CharacterHubModal:
			n.close()
			return
		n = n.get_parent()
	SceneManager.go_to_world()


func _update_responsive_layout() -> void:
	if not is_inside_tree() or _is_updating_layout or _content == null:
		return
	_is_updating_layout = true
	var sz := get_viewport_rect().size
	if sz.x <= 0.0 or sz.y <= 0.0:
		_is_updating_layout = false
		return
	var is_landscape := sz.x > sz.y
	const _TAB_W: float = 170.0
	const _TAB_H: float = 140.0

	for entry in _subtab_defs():
		var key: String = entry["key"]
		var b: Button = _tab_btns.get(key, null) as Button
		if b == null:
			continue
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Icono arriba, texto abajo; botones más anchos y fáciles de pulsar.
		b.text = entry["label"]
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if is_landscape:
			b.custom_minimum_size = Vector2(0, 130)
			b.add_theme_font_size_override("font_size", 30)
		else:
			b.custom_minimum_size = Vector2(0, 120)
			b.add_theme_font_size_override("font_size", 34)

	# Reparentar botones al contenedor activo solo cuando cambia orientación.
	if _landscape_tabs != is_landscape:
		_landscape_tabs = is_landscape
		if is_landscape:
			_refresh_v_sidebar()
		else:
			for entry in _subtab_defs():
				var key: String = entry["key"]
				var b: Button = _tab_btns[key]
				if b.get_parent() != null:
					b.get_parent().remove_child(b)
				_tabbar_h.add_child(b)

	# Barra de sub-pestañas interna: legado redundante — Stats/
	# Facetas ya no son subtabs seleccionables (_build_unified_3col siempre
	# construye ambas columnas) y Profesiones/Equipo son pestañas propias de
	# primer nivel del Hub. Se mantiene oculta siempre; `_content` ocupa todo
	# el área disponible en ambas orientaciones.
	_tabbar_panel_h.visible = false
	_tabbar_panel_v.visible = false

	# Ajuste de modal modesta en la parte DERECHA (dejando la parte izquierda abierta para ver al jugador).
	if is_landscape:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		custom_minimum_size = Vector2.ZERO

		_content.anchor_left = 0.0
		_content.anchor_right = 1.0
		_content.anchor_top = 0.0
		_content.anchor_bottom = 1.0
		_content.offset_left = MARGIN
		_content.offset_right = -MARGIN
		_content.offset_top = MARGIN
		_content.offset_bottom = -MARGIN
	else:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		anchor_left = 0.04
		anchor_right = 0.96
		anchor_top = 0.04
		anchor_bottom = 0.96
		offset_left = 0.0
		offset_right = 0.0
		offset_top = 10.0
		offset_bottom = -10.0
		custom_minimum_size = Vector2.ZERO

		_content.anchor_left = 0.0
		_content.anchor_right = 1.0
		_content.anchor_top = 0.0
		_content.anchor_bottom = 1.0
		_content.offset_left = MARGIN
		_content.offset_right = -MARGIN
		_content.offset_top = MARGIN
		_content.offset_bottom = -MARGIN

	_is_updating_layout = false


## Definición de las sub-pestañas (orden, clave y etiqueta con icono).
## 4 sub-pestañas (una pantalla, una pregunta). Oficios y Mazmorra se
## fusionaron dentro de Profesiones (todo lo ligado a profesión vive junto);
## Bestiario se movió a la pantalla Información (Menú).
func _subtab_defs() -> Array:
	return [
		{"key": "stats", "label": "📊\n" + Locale.t("char_stats")},
		{"key": "prof", "label": "📜\n" + Locale.t("char_professions")},
		{"key": "equip", "label": "🛡️\n" + Locale.t("char_equip")},
		{"key": "facetas", "label": "🎭\n" + Locale.t("char_facets")},
	]


# ══════════════════════════════════════════════════════════════════════════════
# NAVEGACIÓN ENTRE SUB-TABS
# ══════════════════════════════════════════════════════════════════════════════
func _switch_subtab(subtab: String) -> void:
	_active_subtab = subtab
	_refresh()


## Reacciona al cambio de idioma: reconstruye etiquetas de pestañas y contenido.
func _on_locale_changed() -> void:
	for entry in _subtab_defs():
		if _tab_btns.has(entry["key"]):
			(_tab_btns[entry["key"]] as Button).text = entry["label"]
	_refresh()


## Redibuja la barra de sub-pestañas (resaltado) y reconstruye la sub-vista activa.
func _refresh() -> void:
	if not is_visible_in_tree():
		_dirty = true
		return
	_dirty = false
	if _content == null:
		return
	var saved_scroll: int = _active_scroll.scroll_vertical if (_active_scroll != null and is_instance_valid(_active_scroll)) else 0
	if _tabbar_panel_h != null:
		_tabbar_panel_h.visible = false
	if _tabbar_panel_v != null:
		_tabbar_panel_v.visible = false
	for child in _content.get_children():
		child.queue_free()
	var host := _new_scroll_host()
	_build_unified_3col(host)
	if saved_scroll > 0 and _active_scroll != null:
		var target_scroller: ScrollContainer = _active_scroll
		call_deferred("_restore_scroll_vertical", target_scroller, saved_scroll)


func _restore_scroll_vertical(scroller: ScrollContainer, pos: int) -> void:
	if scroller != null and is_instance_valid(scroller):
		scroller.scroll_vertical = pos


## Equipo se extrajo a su propia pestaña de primer nivel del Hub
## (`TabEquip.gd`, vía `CharacterHubModal`) — ya no comparte columna aquí. Esta
## pantalla queda solo con Stats + Facetas (2 columnas en apaisado).
func _build_unified_3col(host: VBoxContainer) -> void:
	_build_points_banner(host)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 14)
	host.add_child(hbox)

	# COLUMNA 1 (60%): ATRIBUTOS + STATS DERIVADAS
	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.size_flags_stretch_ratio = 0.60
	col1.mouse_filter = Control.MOUSE_FILTER_PASS
	col1.add_theme_constant_override("separation", 10)
	hbox.add_child(col1)

	col1.add_child(UiKit.section_header("📊 " + Locale.t("char_stats"), 18))
	_build_core_section(col1)
	_build_combat_section(col1)

	# COLUMNA 2 (40%): FACETAS DE PERSONALIDAD
	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.size_flags_stretch_ratio = 0.40
	col2.mouse_filter = Control.MOUSE_FILTER_PASS
	col2.add_theme_constant_override("separation", 10)
	hbox.add_child(col2)

	_build_facetas(col2)


## Pone `mouse_filter = IGNORE` en `node` y en todos sus descendientes Control
## para que no intercepten toques ni arrastres sobre ScrollContainer.
func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)


## Habilita el desplazamiento vertical por arrastre con ratón o pantalla táctil en ScrollContainer.
func _enable_drag_scroll(scroll: ScrollContainer) -> void:
	var drag_state := {"active": false, "start_y": 0.0, "scroll_start": 0}
	scroll.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT) or ev is InputEventScreenTouch:
			if ev.pressed:
				drag_state["active"] = true
				drag_state["start_y"] = ev.global_position.y
				drag_state["scroll_start"] = scroll.scroll_vertical
			else:
				drag_state["active"] = false
		elif (ev is InputEventMouseMotion or ev is InputEventScreenDrag) and bool(drag_state["active"]):
			var dy: float = ev.global_position.y - float(drag_state["start_y"])
			scroll.scroll_vertical = maxi(0, int(float(drag_state["scroll_start"]) - dy))
	)


## Crea (dentro del host) un ScrollContainer + VBox con margen y devuelve el VBox
## interior listo para recibir el contenido de una sub-vista.
func _new_scroll_host() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	_active_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_enable_drag_scroll(scroll)
	_content.add_child(scroll)
	var margin := UiKit.margins(14, 14, 14, 14)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)
	return vbox


## Símbolo/emoji del avatar según la profesión activa.
func _hero_symbol() -> String:
	return _profession_icon(GlobalState.profession)

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

func _profession_texture(prof: String) -> Texture2D:
	var path: String = PROF_TEXTURES.get(prof, "res://assets/combat/character/prof_av_don_nadie.png")
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

## Icono de una profesión concreta.
func _profession_icon(prof: String) -> String:
	var def = Design.get_profession(prof)
	if not def.is_empty():
		return def.get("icon", "🧝")
	return "🧝"

## Nombre traducido de una profesión (por defecto, la activa).
func _profession_name(prof: String = "") -> String:
	var p: String = prof if prof != "" else GlobalState.profession
	return Locale.translate_profession(p)

## Color de identidad de cada profesión (acentos de clase, técnicas y bordes).
func _profession_color(prof: String) -> Color:
	var def = Design.get_profession(prof)
	if not def.is_empty():
		return Color.from_string(def.get("color", "41a3ff"), Color(0.30, 0.64, 1.0))
	return UiKit.ACCENT


## Separador horizontal sencillo (helper de maquetación).
func _hsep() -> HSeparator:
	return HSeparator.new()


## Barra de progreso GRUESA con etiqueta superpuesta (helper reutilizable).
func _labeled_bar(value: int, maxv: int, color: Color, text: String, height: int = 36) -> Control:
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, maxv)
	bar.value = value
	bar.custom_minimum_size = Vector2(0, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.style_progress(bar, color, int(height / 2.0))
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", UiKit.TEXT)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(lbl)
	return bar


# ══════════════════════════════════════════════════════════════════════════════
# 1. SUB-VISTA: STATS  (características, combate, profesiones u oficios)
# ══════════════════════════════════════════════════════════════════════════════
## Suma de puntos marcados con "+" que aún no se han confirmado.
func _pending_points_total() -> int:
	var total := 0
	for v in _pending_stat_alloc.values():
		total += int(v)
	return total


## Puntos de característica que quedarían libres tras aplicar lo provisional.
func _remaining_stat_points() -> int:
	return GlobalState.stat_points - _pending_points_total()


## Cabecera con los puntos de característica disponibles, bien visible, para
## que quede claro cuántos quedan por repartir. Se muestra también mientras
## hay puntos YA marcados de forma provisional (esperando "Confirmar"),
## reflejando en el número los que quedarían LIBRES tras aplicarlos. Antes
## esta cabecera vivía en `_build_stats()`, una función que ya no se llamaba
## desde ningún sitio — el layout realmente activo es `_build_unified_3col()`
## — así que el jugador nunca llegaba a verla.
func _build_points_banner(host: VBoxContainer) -> void:
	if GlobalState.stat_points <= 0 and _pending_points_total() <= 0 and not GlobalState.debug_mode:
		return
	var pts_banner := PanelContainer.new()
	pts_banner.mouse_filter = Control.MOUSE_FILTER_PASS
	var pts_style := StyleBoxFlat.new()
	pts_style.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.16)
	pts_style.set_border_width_all(2)
	pts_style.border_color = UiKit.ACCENT
	pts_style.set_corner_radius_all(12)
	pts_style.content_margin_left = 16
	pts_style.content_margin_right = 16
	pts_style.content_margin_top = 10
	pts_style.content_margin_bottom = 10
	pts_banner.add_theme_stylebox_override("panel", pts_style)

	var remaining := _remaining_stat_points()
	var pts_lbl := Label.new()
	pts_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts_lbl.add_theme_font_size_override("font_size", 24)
	pts_lbl.add_theme_color_override("font_color", UiKit.ACCENT)

	if GlobalState.debug_mode:
		var banner_hb := HBoxContainer.new()
		banner_hb.add_theme_constant_override("separation", 12)
		banner_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		pts_banner.add_child(banner_hb)

		var btn_lvl_down := Button.new()
		btn_lvl_down.text = "-Nv"
		btn_lvl_down.tooltip_text = "Modo Debug: Reducir nivel (-1) y reajustar puntos"
		btn_lvl_down.custom_minimum_size = Vector2(72, 44)
		btn_lvl_down.add_theme_font_size_override("font_size", 22)
		UiKit.premium_button(btn_lvl_down, {"corner_radius": 8.0, "border_width": 1.5})
		btn_lvl_down.pressed.connect(func() -> void:
			if GlobalState.level > 1:
				GlobalState.debug_remove_level()
				_refresh()
		)
		banner_hb.add_child(btn_lvl_down)

		if _pending_points_total() > 0:
			pts_lbl.text = "🛠️ Nv.%d · ✨ Puntos: %d (provisional)" % [GlobalState.level, remaining]
		else:
			pts_lbl.text = "🛠️ Nv.%d · ✨ Puntos Disponibles: %d" % [GlobalState.level, remaining]
		banner_hb.add_child(pts_lbl)

		var btn_lvl_up := Button.new()
		btn_lvl_up.text = "+Nv"
		btn_lvl_up.tooltip_text = "Modo Debug: Aumentar nivel (+1) y ganar puntos de stats"
		btn_lvl_up.custom_minimum_size = Vector2(72, 44)
		btn_lvl_up.add_theme_font_size_override("font_size", 22)
		UiKit.premium_button(btn_lvl_up, {"corner_radius": 8.0, "border_width": 1.5})
		btn_lvl_up.pressed.connect(func() -> void:
			GlobalState.debug_add_level()
			_refresh()
		)
		banner_hb.add_child(btn_lvl_up)
	else:
		if _pending_points_total() > 0:
			pts_lbl.text = Locale.pick({
				"es": "✨ Puntos Disponibles: %d  (provisional, sin confirmar)" % remaining,
				"en": "✨ Available Points: %d  (provisional, unconfirmed)" % remaining,
			})
		else:
			pts_lbl.text = Locale.pick({
				"es": "✨ Puntos Disponibles: %d" % remaining,
				"en": "✨ Available Points: %d" % remaining,
			})
		pts_banner.add_child(pts_lbl)

	if not GlobalState.debug_mode:
		_ignore_mouse_recursive(pts_banner)

	host.add_child(pts_banner)


func _build_stats(host: VBoxContainer) -> void:
	_build_points_banner(host)

	# Secciones plegables tipo acordeón: todas desplegadas por defecto.
	# En apaisado se distribuyen en dos columnas; en vertical en una sola.
	var is_landscape := get_viewport_rect().size.x > get_viewport_rect().size.y
	if is_landscape:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 12)
		host.add_child(hbox)

		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left.add_theme_constant_override("separation", 10)
		hbox.add_child(left)

		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 10)
		hbox.add_child(right)

		_accordion_section(left, "core", "💠", Locale.t("stats_core_title"), _build_core_section)
		_accordion_section(left, "combat", "⚔️", Locale.t("stats_derived_title"), _build_combat_section)
		_accordion_section(right, "profs", "📜", Locale.t("char_professions_status"), _build_professions_section)
		_accordion_section(right, "oficios", "⛏️", Locale.t("char_oficios_title"), _build_oficios_section)
	else:
		_accordion_section(host, "core", "💠", Locale.t("stats_core_title"), _build_core_section)
		_accordion_section(host, "combat", "⚔️", Locale.t("stats_derived_title"), _build_combat_section)
		_accordion_section(host, "profs", "📜", Locale.t("char_professions_status"), _build_professions_section)
		_accordion_section(host, "oficios", "⛏️", Locale.t("char_oficios_title"), _build_oficios_section)


## Sección plegable del acordeón de Stats: cabecera pulsable (con ▾/▸) que abre esta
## y cierra las demás. Si está abierta, invoca `body_builder` para rellenar su cuerpo.
func _accordion_section(host: VBoxContainer, id: String, icon: String, title: String, body_builder: Callable) -> void:
	var is_open: bool = not _stats_closed.has(id)
	var header := Button.new()
	header.custom_minimum_size = Vector2(0, 72)
	header.add_theme_font_size_override("font_size", 30)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for st in ["normal", "hover", "pressed", "focus"]:
		header.add_theme_stylebox_override(st, UiKit.button_tonal(UiKit.ACCENT, 12))
	header.add_theme_color_override("font_color", UiKit.ACCENT_SOFT if is_open else UiKit.TEXT)
	header.text = "%s  %s   %s" % [icon, title, ("▾" if is_open else "▸")]
	header.pressed.connect(func() -> void:
		if _stats_closed.has(id):
			_stats_closed.erase(id)
		else:
			_stats_closed[id] = true
		_refresh()
	)
	host.add_child(header)
	if is_open:
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 10)
		host.add_child(body)
		body_builder.call(body)


## Cuerpo "Características base": rejilla 2×3 de atributos + botón de reinicio.
func _build_core_section(body: VBoxContainer) -> void:
	var core_grid := GridContainer.new()
	core_grid.columns = 2
	core_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_grid.add_theme_constant_override("h_separation", 14)
	core_grid.add_theme_constant_override("v_separation", 14)
	for key in STAT_NAMES:
		core_grid.add_child(_make_core_stat_card(key))
	body.add_child(core_grid)
	body.add_child(_make_reset_button())


## Cuerpo "Estadísticas de combate": rejilla 3 columnas de derivadas (3x4).
func _build_combat_section(body: VBoxContainer) -> void:
	var derived_grid := GridContainer.new()
	derived_grid.columns = 3
	derived_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derived_grid.add_theme_constant_override("h_separation", 10)
	derived_grid.add_theme_constant_override("v_separation", 10)
	for d in _derived_list():
		derived_grid.add_child(_make_derived_card(d))
	body.add_child(derived_grid)


## Cuerpo "Estado de profesiones": nivel/EXP de TODAS las profesiones desbloqueadas.
func _build_professions_section(body: VBoxContainer) -> void:
	body.add_child(_build_professions_summary())


## Cuerpo "Estado de oficios": oficios de recolección descubiertos y barra de progreso.
func _build_oficios_section(body: VBoxContainer) -> void:
	_build_oficio(body)


func _simulated_stat(stat_name: String) -> int:
	return GlobalState.get_stat_with_bonuses(stat_name) + int(_pending_stat_alloc.get(stat_name, 0))


## Lista de estadísticas de combate derivadas (datos para las tarjetas).
func _derived_list() -> Array[Dictionary]:
	var sim_vit := _simulated_stat("vit")
	var sim_int := _simulated_stat("int")
	var sim_str := _simulated_stat("str")
	var sim_dex := _simulated_stat("dex")
	var sim_agi := _simulated_stat("agi")
	var sim_luk := _simulated_stat("luk")

	# HP
	var sim_hp := GameConfig.HP_BASE + sim_vit * GameConfig.HP_PER_VIT + GlobalState.level * GameConfig.HP_PER_LEVEL
	var diff_hp := sim_hp - GlobalState.max_hp

	# MP
	var sim_mp := GameConfig.MP_BASE + sim_int * GameConfig.MP_PER_INT + GlobalState.level * GameConfig.MP_PER_LEVEL
	var diff_mp := sim_mp - GlobalState.max_mp

	# Daño Físico
	var sim_phys := int(sim_str * GameConfig.PHYS_DMG_FROM_STR + sim_dex * GameConfig.PHYS_DMG_FROM_DEX + GlobalState.level * GameConfig.PHYS_DMG_FROM_LEVEL) + GlobalState.get_equip_combat("phys_damage")
	if GlobalState.has_food_buff("strength"):
		sim_phys = int(sim_phys * GameConfig.FOOD_BUFF_STRENGTH_MULT)
	var diff_phys := sim_phys - GlobalState.get_phys_damage()

	# Daño Mágico
	var sim_mag := int(sim_int * GameConfig.MAG_DMG_FROM_INT + GlobalState.level * GameConfig.MAG_DMG_FROM_LEVEL) + GlobalState.get_equip_combat("mag_damage")
	var diff_mag := sim_mag - GlobalState.get_mag_damage()

	# Daño Distancia
	var sim_rng := int(sim_dex * GameConfig.RANGE_DMG_FROM_DEX + sim_str * GameConfig.RANGE_DMG_FROM_STR) + GlobalState.get_equip_combat("range_damage")
	var diff_rng := sim_rng - GlobalState.get_range_damage()

	# Velocidad
	var sim_spd := int(sim_agi * GameConfig.SPEED_FROM_AGI)
	var diff_spd := sim_spd - GlobalState.get_speed()

	# Def Física
	var sim_pdef := int(sim_vit * GameConfig.PDEF_FROM_VIT + sim_str * GameConfig.PDEF_FROM_STR + GlobalState.level * GameConfig.PDEF_FROM_LEVEL) + GlobalState.get_equip_combat("phys_defense")
	if GlobalState.has_food_buff("vigor"):
		sim_pdef = int(sim_pdef * GameConfig.FOOD_BUFF_VIGOR_MULT)
	var diff_pdef := sim_pdef - GlobalState.get_phys_defense()

	# Def Mágica
	var sim_mdef := int(sim_int * GameConfig.MDEF_FROM_INT + sim_vit * GameConfig.MDEF_FROM_VIT + GlobalState.level * GameConfig.MDEF_FROM_LEVEL) + GlobalState.get_equip_combat("mag_defense")
	var diff_mdef := sim_mdef - GlobalState.get_mag_defense()

	# Crítico
	var sim_crit := int(clampf(GameConfig.CRIT_BASE + sim_luk * GameConfig.CRIT_FROM_LUK + sim_dex * GameConfig.CRIT_FROM_DEX, 0.0, GameConfig.CRIT_MAX))
	var diff_crit := sim_crit - int(GlobalState.get_crit())

	# Esquiva
	var sim_dodge := int(clampf(GameConfig.DODGE_BASE + sim_agi * GameConfig.DODGE_FROM_AGI + sim_luk * GameConfig.DODGE_FROM_LUK, 0.0, GameConfig.DODGE_MAX))
	var diff_dodge := sim_dodge - int(GlobalState.get_dodge())

	# Puntería
	var sim_hit := int(clampf(GameConfig.ACCURACY_BASE + sim_dex * GameConfig.ACC_FROM_DEX + sim_luk * GameConfig.ACC_FROM_LUK, 0.0, GameConfig.ACCURACY_MAX))
	var diff_hit := sim_hit - int(GlobalState.get_accuracy())

	# Carga
	var sim_cap := GameConfig.CARRY_BASE + sim_str * GameConfig.CARRY_PER_STR
	var diff_cap := sim_cap - GlobalState.get_carry_weight()

	return [
		{"key": "derived_hp", "value": str(GlobalState.max_hp), "diff": diff_hp, "color": UiKit.HP},
		{"key": "derived_mp", "value": str(GlobalState.max_mp), "diff": diff_mp, "color": UiKit.MP},
		{"key": "derived_phys", "value": str(GlobalState.get_phys_damage()), "diff": diff_phys, "color": UiKit.PHYS},
		{"key": "derived_mag", "value": str(GlobalState.get_mag_damage()), "diff": diff_mag, "color": UiKit.MAGIC},
		{"key": "derived_rng", "value": str(GlobalState.get_range_damage()), "diff": diff_rng, "color": UiKit.RANGED},
		{"key": "derived_spd", "value": str(GlobalState.get_speed()), "diff": diff_spd, "color": UiKit.GOOD},
		{"key": "derived_pdef", "value": str(GlobalState.get_phys_defense()), "diff": diff_pdef, "color": UiKit.DEF_PHYS},
		{"key": "derived_mdef", "value": str(GlobalState.get_mag_defense()), "diff": diff_mdef, "color": UiKit.DEF_MAGIC},
		{"key": "derived_crit", "value": "%d%%" % int(GlobalState.get_crit()), "diff": diff_crit, "is_pct": true, "color": UiKit.BAD},
		{"key": "derived_dodge", "value": "%d%%" % int(GlobalState.get_dodge()), "diff": diff_dodge, "is_pct": true, "color": UiKit.RANGED},
		{"key": "derived_hit", "value": "%d%%" % int(GlobalState.get_accuracy()), "diff": diff_hit, "is_pct": true, "color": UiKit.ACCENT},
		{"key": "derived_cap", "value": str(GlobalState.get_carry_weight()), "diff": diff_cap, "color": UiKit.ACCENT_SOFT},
	]


## Resumen (solo lectura) de las profesiones desbloqueadas con su nivel/EXP.
## "Don Nadie" se mantiene como fila completa arriba; el resto se organiza en 2 columnas para ahorrar espacio.
func _build_professions_summary() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var unlocked: Array = []
	for p in GlobalState.unlocked_professions:
		unlocked.append(p)
	if unlocked.is_empty():
		var hint := Label.new()
		hint.text = Locale.t("char_no_unlocked_profs")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 17)
		hint.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		box.add_child(hint)
		return box

	# 1. Don Nadie (novice / base): Fila única arriba a ancho completo si está desbloqueada
	var base_prof := ""
	for candidate in ["Don Nadie", "novice", "ninguna"]:
		if candidate in unlocked:
			base_prof = candidate
			break

	if base_prof != "":
		box.add_child(_make_profession_summary_row(base_prof))
		unlocked.erase(base_prof)

	# 2. El resto de profesiones: Rejilla de 2 columnas (pares perfectos sin tarjeta descolgada)
	if not unlocked.is_empty():
		var prof_grid := GridContainer.new()
		prof_grid.columns = 2
		prof_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prof_grid.add_theme_constant_override("h_separation", 10)
		prof_grid.add_theme_constant_override("v_separation", 10)
		for p in unlocked:
			prof_grid.add_child(_make_profession_summary_card(String(p)))
		box.add_child(prof_grid)

	return box


## Fila-resumen de una profesión: icono, nombre, progreso (si activa) y estado.
func _make_profession_summary_row(prof: String) -> PanelContainer:
	var active: bool = GlobalState.profession == prof
	var col := _profession_color(prof)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(col if active else UiKit.BORDER, 14, 12))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)
	var tex := _profession_texture(prof)
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(44, 44)
		img.size = Vector2(44, 44)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(img)
	else:
		var icon := Label.new()
		icon.text = _profession_icon(prof)
		icon.add_theme_font_size_override("font_size", 30)
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)
	var name_lbl := Label.new()
	name_lbl.text = _profession_name(prof)
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	vb.add_child(name_lbl)
	# Nivel + barra de EXP de CADA profesión
	var prog: Dictionary = GlobalState.get_profession_progress(prof)
	var lvl: int = int(prog.get("level", 1))
	var jxp: int = int(prog.get("xp", 0))
	var jneed: int = int(prog.get("xp_needed", 100))
	vb.add_child(_labeled_bar(jxp, jneed, col if active else UiKit.TEXT_DIM,
		"%s  ·  %d / %d" % [Locale.t("hud_job_level", [lvl]), jxp, jneed], 36))
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.chip(col))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cm := UiKit.margins(14, 14, 6, 6)
	chip.add_child(cm)
	var chip_lbl := Label.new()
	chip_lbl.text = Locale.t("char_prof_active") if active else Locale.t("char_prof_inactive")
	chip_lbl.add_theme_font_size_override("font_size", 22)
	chip_lbl.add_theme_color_override("font_color", col if active else UiKit.TEXT_DIM)
	cm.add_child(chip_lbl)
	hb.add_child(chip)
	_ignore_mouse_recursive(card)
	return card


## Tarjeta compacta para la rejilla 2-columnas de profesiones secundarias.
func _make_profession_summary_card(prof: String) -> PanelContainer:
	var active: bool = GlobalState.profession == prof
	var col := _profession_color(prof)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 100)
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(col if active else UiKit.BORDER, 12, 10))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)

	var tex := _profession_texture(prof)
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(44, 44)
		img.size = Vector2(44, 44)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(img)
	else:
		var icon := Label.new()
		icon.text = _profession_icon(prof)
		icon.add_theme_font_size_override("font_size", 30)
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(icon)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = _profession_name(prof)
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", col if active else UiKit.TEXT)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name_lbl)

	var prog: Dictionary = GlobalState.get_profession_progress(prof)
	var lvl: int = int(prog.get("level", 1))
	var jxp: int = int(prog.get("xp", 0))
	var jneed: int = int(prog.get("xp_needed", 100))

	vb.add_child(_labeled_bar(jxp, jneed, col if active else UiKit.TEXT_DIM,
		"%s · %d/%d" % [Locale.t("hud_job_level", [lvl]), jxp, jneed], 28))

	_ignore_mouse_recursive(card)
	return card


## Tarjeta de una característica base: icono, nombre+valor, influencia y botones -/+.
func _make_core_stat_card(key: String) -> PanelContainer:
	var committed_val: int = int(GlobalState.stats.get(key, 5))
	var pending: int = int(_pending_stat_alloc.get(key, 0))
	# El valor mostrado incluye lo PROVISIONAL (aún sin confirmar) como
	# vista previa — pero los bonos derivados solo cuentan lo YA aplicado en
	# `GlobalState`, ya que `recalculate_derived_stats()` no se ha llamado
	# todavía para estos puntos.
	var base_val: int = committed_val + pending
	var total_val: int = GlobalState.get_stat_with_bonuses(key) + pending
	var bonus: int = total_val - base_val

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", UiKit.card(false, 12, 10))

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_lbl.text = STAT_ICONS.get(key, "▫️")
	icon_lbl.add_theme_font_size_override("font_size", 44)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.text = "%s   %d%s" % [Locale.t("stat_" + key), base_val, ("  (+%d)" % bonus) if bonus != 0 else ""]
	name_lbl.add_theme_font_size_override("font_size", 34)
	name_lbl.add_theme_color_override("font_color", UiKit.ACCENT if pending > 0 else UiKit.TEXT)
	vbox.add_child(name_lbl)

	var inf_lbl := Label.new()
	inf_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inf_lbl.text = Locale.pick(STAT_INFLUENCE.get(key, ""))
	inf_lbl.add_theme_font_size_override("font_size", 16)
	inf_lbl.add_theme_color_override("font_color", Color(UiKit.TEXT_FAINT.r, UiKit.TEXT_FAINT.g, UiKit.TEXT_FAINT.b, 0.7))
	vbox.add_child(inf_lbl)

	var btn_box := HBoxContainer.new()
	btn_box.mouse_filter = Control.MOUSE_FILTER_PASS
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 6)
	hbox.add_child(btn_box)

	# Botón "-" para restar puntos provisionales asignados en esta sesión antes de confirmar
	var can_minus: bool = pending > 0
	var btn_minus := Button.new()
	btn_minus.text = "-"
	btn_minus.custom_minimum_size = Vector2(56, 56)
	btn_minus.add_theme_font_size_override("font_size", 34)
	btn_minus.disabled = not can_minus
	var minus_style := StyleBoxFlat.new()
	minus_style.set_corner_radius_all(14)
	minus_style.set_content_margin_all(2)
	if can_minus:
		minus_style.bg_color = Color("381d22")
		minus_style.border_color = Color("e06c75")
		minus_style.set_border_width_all(2)
		btn_minus.add_theme_color_override("font_color", Color("ff8888"))
		btn_minus.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		minus_style.bg_color = Color("141720")
		btn_minus.add_theme_color_override("font_color", Color(0.35, 0.38, 0.45))
	for st in ["normal", "hover", "pressed", "disabled"]:
		btn_minus.add_theme_stylebox_override(st, minus_style)

	btn_minus.pressed.connect(func() -> void:
		var cur := int(_pending_stat_alloc.get(key, 0))
		if cur > 0:
			if cur == 1:
				_pending_stat_alloc.erase(key)
			else:
				_pending_stat_alloc[key] = cur - 1
			_refresh()
	)
	btn_box.add_child(btn_minus)

	var btn_plus := Button.new()
	btn_plus.text = "+"
	btn_plus.custom_minimum_size = Vector2(56, 56)
	btn_plus.add_theme_font_size_override("font_size", 34)
	var has_points: bool = _remaining_stat_points() > 0
	btn_plus.disabled = not has_points
	var plus_style := StyleBoxFlat.new()
	plus_style.bg_color = UiKit.ACCENT if has_points else Color("141720")
	plus_style.set_corner_radius_all(14)
	plus_style.set_content_margin_all(2)
	for st in ["normal", "hover", "pressed", "disabled"]:
		btn_plus.add_theme_stylebox_override(st, plus_style)
	if has_points:
		btn_plus.add_theme_color_override("font_color", Color("000000"))
		btn_plus.add_theme_color_override("font_hover_color", Color("ffffff"))
	else:
		btn_plus.add_theme_color_override("font_color", Color(0.35, 0.38, 0.45))

	btn_plus.pressed.connect(func() -> void:
		if _remaining_stat_points() > 0:
			_pending_stat_alloc[key] = int(_pending_stat_alloc.get(key, 0)) + 1
			_refresh()
	)
	btn_box.add_child(btn_plus)
	return card


## Botón para reiniciar las características (sumidero de oro que devuelve los
## puntos) — o, mientras haya puntos PROVISIONALES sin confirmar, se
## sustituye por "Cancelar" + "Confirmar".
func _make_reset_button() -> Control:
	if _pending_points_total() > 0:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var btn_cancel := Button.new()
		btn_cancel.text = Locale.pick({"es": "Cancelar", "en": "Cancel"})
		btn_cancel.custom_minimum_size = Vector2(0, 72)
		btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_cancel.add_theme_font_size_override("font_size", 28)
		btn_cancel.pressed.connect(func() -> void:
			_pending_stat_alloc.clear()
			_refresh()
		)
		row.add_child(btn_cancel)

		var btn_confirm := Button.new()
		btn_confirm.text = Locale.pick({"es": "Confirmar", "en": "Confirm"})
		btn_confirm.custom_minimum_size = Vector2(0, 72)
		btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_confirm.add_theme_font_size_override("font_size", 28)
		var confirm_style := StyleBoxFlat.new()
		confirm_style.bg_color = UiKit.ACCENT
		confirm_style.set_corner_radius_all(12)
		for st in ["normal", "hover", "pressed"]:
			btn_confirm.add_theme_stylebox_override(st, confirm_style)
		btn_confirm.add_theme_color_override("font_color", Color("000000"))
		btn_confirm.pressed.connect(_confirm_pending_stat_alloc)
		row.add_child(btn_confirm)
		return row

	var btn := Button.new()
	btn.text = Locale.t("stat_reset_cost", [GameConfig.STAT_RESET_COST_GOLD])
	btn.custom_minimum_size = Vector2(0, 72)
	btn.add_theme_font_size_override("font_size", 28)
	btn.disabled = not GlobalState.can_reset_stats()
	btn.pressed.connect(_show_reset_confirm)
	return btn


## Aplica de golpe todos los puntos marcados provisionalmente con "+" a
## `GlobalState.stats`, descuenta `GlobalState.stat_points` y recalcula
## derivadas UNA sola vez (en vez de en cada pulsación de "+").
func _confirm_pending_stat_alloc() -> void:
	if _pending_points_total() <= 0:
		return
	for key in _pending_stat_alloc.keys():
		var amount: int = int(_pending_stat_alloc[key])
		if amount <= 0:
			continue
		GlobalState.stats[key] = int(GlobalState.stats.get(key, 5)) + amount
		GlobalState.stat_points -= amount
	_pending_stat_alloc.clear()
	GlobalState.recalculate_derived_stats()
	GlobalState.state_updated.emit()
	SaveManager.request_autosave()
	_refresh()


## Diálogo de confirmación antes de reiniciar (cuesta oro).
func _show_reset_confirm() -> void:
	var on_ok := func() -> void:
		if GlobalState.reset_stats():
			SaveManager.request_autosave()
	UiKit.confirm(
		self,
		Locale.t("stat_reset_confirm_title"),
		Locale.t("stat_reset_confirm_body", [GameConfig.STAT_RESET_COST_GOLD]),
		Locale.t("menu_confirm"),
		Locale.t("menu_cancel"),
		on_ok
	)


## Tarjeta de una estadística de combate: barra de acento + nombre + valor (con ganancia simulada si hay puntos provisionales).
func _make_derived_card(d: Dictionary) -> PanelContainer:
	var col: Color = d["color"]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 110)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiKit.card(false, 12, 8))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	var accent := ColorRect.new()
	accent.color = col
	accent.custom_minimum_size = Vector2(5, 0)
	accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(accent)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = Locale.t(d["key"])
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var val_row := HBoxContainer.new()
	val_row.add_theme_constant_override("separation", 2)
	val_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(val_row)

	var val_lbl := Label.new()
	val_lbl.text = d["value"]
	val_lbl.add_theme_font_size_override("font_size", 44)
	val_lbl.add_theme_color_override("font_color", col)
	val_row.add_child(val_lbl)

	var diff: int = int(d.get("diff", 0))
	if diff > 0:
		var diff_lbl := Label.new()
		diff_lbl.text = ("+%d%%" % diff) if d.get("is_pct", false) else ("+%d" % diff)
		diff_lbl.add_theme_font_size_override("font_size", 34)
		diff_lbl.add_theme_color_override("font_color", UiKit.GOOD)
		diff_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		val_row.add_child(diff_lbl)

	_ignore_mouse_recursive(card)
	return card


# ══════════════════════════════════════════════════════════════════════════════
# SUB-VISTA: HABILIDADES DE EXPLORACIÓN
#   Las 6 habilidades permanentes ligadas a profesiones. Sustituyen por completo
#   al antiguo sistema de tres almas (Sarah/Taos/Yui), ya retirado. NO son las
#   habilidades de COMBATE por turnos (ver Profesiones).
# ══════════════════════════════════════════════════════════════════════════════
func _build_dungeon_skills(host: VBoxContainer) -> void:
	host.add_child(UiKit.section_header("🗺️  " + Locale.t("char_exploration_skills"), 22))
	# En 2 columnas para aprovechar el ancho (sin subtítulo aclaratorio).
	host.add_child(_two_column_grid(ExplorationSkills.all_ids(), _build_exploration_skill_card))


## Ficha de una habilidad de exploración: nombre, profesión que la enseña y
## métricas de uso. Si aún no está desbloqueada se muestra atenuada y con candado.
func _build_exploration_skill_card(id: String) -> PanelContainer:
	var s: Dictionary = ExplorationSkills.get_skill(id)
	var unlocked := ExplorationSkills.is_unlocked(id)
	var col: Color = s.get("color", Color(0.6, 0.6, 0.7))
	if not unlocked:
		col = Color(col.r, col.g, col.b, 0.5)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(col, 14, 14))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	# Cabecera: nombre + estado (candado / desbloqueada).
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var name_lbl := Label.new()
	name_lbl.text = ExplorationSkills.display_name(id)
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", col if unlocked else UiKit.TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_lbl)
	var state_lbl := Label.new()
	state_lbl.text = Locale.pick({"es": "🔒 Bloqueada", "en": "🔒 Locked"}) if not unlocked \
		else Locale.pick({"es": "Desbloqueada", "en": "Unlocked"})
	state_lbl.add_theme_font_size_override("font_size", 22)
	state_lbl.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
	state_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(state_lbl)
	vb.add_child(head)

	# Profesión que la enseña (oculta tras ❓ si está bloqueada).
	var prof_lbl := Label.new()
	var prof_text: String = String(s.get("profession", "—")) if unlocked else "❓"
	prof_lbl.text = "%s: %s" % [Locale.pick({"es": "Profesión", "en": "Profession"}), prof_text]
	prof_lbl.add_theme_font_size_override("font_size", 22)
	prof_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	vb.add_child(prof_lbl)

	# Métricas de uso: energía · enfriamiento · alcance.
	var stats_lbl := Label.new()
	stats_lbl.text = "⚡ %d   ·   ⏱ %.1fs   ·   ◎ %.0fm" % [int(s.get("energy", 0)), float(s.get("cooldown", 0.0)), float(s.get("range", 0.0))]
	stats_lbl.add_theme_font_size_override("font_size", 22)
	stats_lbl.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
	vb.add_child(stats_lbl)
	_ignore_mouse_recursive(card)
	return card


# ══════════════════════════════════════════════════════════════════════════════
# 2. PESTAÑA: FACETAS DE PERSONALIDAD
# ══════════════════════════════════════════════════════════════════════════════
const FACET_MAX: int = 10 # Rango de cada faceta: -FACET_MAX .. +FACET_MAX

func _build_facetas(host: VBoxContainer) -> void:
	host.add_child(UiKit.section_header("🎭  " + Locale.t("char_facets"), 22))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_theme_constant_override("separation", 16)
	host.add_child(col)
	var list: Array[Dictionary] = [
		{"key": "valor", "icon": "🛡️", "color": Color("ff9f43")},
		{"key": "bondad", "icon": "💚", "color": Color("10ac84")},
		{"key": "aspecto", "icon": "🎭", "color": Color("9b59b6")},
		{"key": "inteligencia", "icon": "🧠", "color": Color("41a3ff")},
		{"key": "cordura", "icon": "🌀", "color": Color("a855f7")},
	]
	for f in list:
		col.add_child(_make_facet_card(f))


## Tarjeta de una faceta: nombre + valor, barra centrada y descriptor.
func _make_facet_card(f: Dictionary) -> PanelContainer:
	var val: int = GlobalState.facetas.get(f["key"], 0)
	var f_color: Color = f.get("color", UiKit.ACCENT)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 148)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(f_color, 16, 16))

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)

	var name_lbl := Label.new()
	name_lbl.text = "%s  %s" % [f["icon"], Locale.t("facet_" + f["key"])]
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_lbl)

	var val_col: Color = Color("6c7d9b")
	if val > 0:
		val_col = Color("00d2ff")
	elif val < 0:
		val_col = Color("ff4b5c")

	var val_lbl := Label.new()
	val_lbl.text = "%+d" % val
	val_lbl.add_theme_font_size_override("font_size", 32)
	val_lbl.add_theme_color_override("font_color", val_col if val != 0 else UiKit.TEXT_DIM)
	head.add_child(val_lbl)
	row.add_child(head)

	row.add_child(_make_center_bar(val, FACET_MAX))

	var bucket: int = 0
	if val > 0:
		bucket = int(float(val + 1) / 2.0)
	elif val < 0:
		bucket = int(float(val - 1) / 2.0)
	var descriptor := Label.new()
	descriptor.text = Locale.t("facet_label_" + String(f["key"]) + "_" + str(bucket))
	descriptor.add_theme_font_size_override("font_size", 21)
	descriptor.add_theme_color_override("font_color", val_col if val != 0 else UiKit.TEXT_DIM)
	descriptor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(descriptor)
	_ignore_mouse_recursive(card)
	return card


## Construye una barra que se rellena DESDE EL CENTRO (valor 0) hacia la izquierda
## (valores negativos, rojo) o la derecha (valores positivos, azul). Usa anclas
## fraccionarias para escalar con el ancho disponible.
func _make_center_bar(val: int, max_abs: int) -> Control:
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size = Vector2(0, 32)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Fondo redondeado a todo lo ancho.
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UiKit.bar_bg(12))
	bar.add_child(bg)

	# Relleno anclado al centro, creciendo según el signo del valor.
	var ratio: float = clampf(float(absi(val)) / float(maxi(1, max_abs)), 0.0, 1.0)
	if ratio > 0.001:
		var fill := Panel.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill_col: Color = Color("00d2ff") if val >= 0 else Color("ff4b5c")
		fill.add_theme_stylebox_override("panel", UiKit.bar_fill(fill_col, 12))
		fill.anchor_top = 0.0
		fill.anchor_bottom = 1.0
		if val >= 0:
			fill.anchor_left = 0.5
			fill.anchor_right = 0.5 + 0.5 * ratio
		else:
			fill.anchor_left = 0.5 - 0.5 * ratio
			fill.anchor_right = 0.5
		fill.offset_left = 0
		fill.offset_right = 0
		fill.offset_top = 0
		fill.offset_bottom = 0
		bar.add_child(fill)

	# Marca central bien destacada (el "0").
	var tick := ColorRect.new()
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tick.color = Color(1, 1, 1, 0.75)
	tick.anchor_left = 0.5
	tick.anchor_right = 0.5
	tick.anchor_top = 0.0
	tick.anchor_bottom = 1.0
	tick.offset_left = -1.5
	tick.offset_right = 1.5
	bar.add_child(tick)

	return bar


# ══════════════════════════════════════════════════════════════════════════════
# 4. SUB-VISTA: OFICIOS  (recolección con barras gruesas y llamativas)
# ══════════════════════════════════════════════════════════════════════════════
func _build_oficio(host: VBoxContainer) -> void:
	host.add_child(UiKit.section_header("⛏️  " + Locale.t("char_oficios_title"), 22))
	var any := false
	var undiscovered_count := 0
	for s in _oficios():
		# Los oficios de recolección aún no descubiertos (nunca se ha
		# recolectado ese recurso) NO se listan como ficha activa.
		var res_id := String(GameConfig.GATHER_RESOURCES.get(s["key"], {}).get("id", ""))
		if res_id != "" and not GlobalState.resources_discovered.get(res_id, false):
			undiscovered_count += 1
			continue
		any = true
		host.add_child(_make_skill_card(s))

	if undiscovered_count > 0:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 64)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UiKit.card(false, 14, 12))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		card.add_child(hb)

		var icon_lbl := Label.new()
		icon_lbl.text = "❓"
		icon_lbl.add_theme_font_size_override("font_size", 26)
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(icon_lbl)

		var text_lbl := Label.new()
		text_lbl.text = Locale.pick({
			"es": "Sigue jugando para descubrir más oficios de recolección.",
			"en": "Keep playing to discover more gathering professions.",
		})
		text_lbl.add_theme_font_size_override("font_size", 24)
		text_lbl.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(text_lbl)

		host.add_child(card)
	elif not any:
		var hint := Label.new()
		hint.text = Locale.pick({
			"es": "Aún no has descubierto ningún oficio de recolección. Explora el mundo y recolecta recursos.",
			"en": "You haven't discovered any gathering profession yet. Explore the world and gather resources.",
		})
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 22)
		hint.add_theme_color_override("font_color", UiKit.TEXT_FAINT)
		host.add_child(hint)


## Oficios de recolección disponibles (clave, icono y color de identidad).
func _oficios() -> Array[Dictionary]:
	return [
		{"key": "lenador", "icon": "🪵", "color": Color("c08457")},
		{"key": "minero", "icon": "🪨", "color": Color("93a1b5")},
		{"key": "pesca", "icon": "🐟", "color": UiKit.MP},
		{"key": "agricultor", "icon": "🌾", "color": Color("e0b93a")},
		{"key": "ganadero", "icon": "🥛", "color": Color("cfd8e3")},
		{"key": "cazador", "icon": "🍖", "color": Color("b5573c")},
		{"key": "cocinero", "icon": "🍳", "color": Color("f2a65a")},
	]


## Tarjeta de un oficio: insignia grande, nivel, barra de XP GRUESA y recurso.
func _make_skill_card(s: Dictionary) -> PanelContainer:
	var key: String = s["key"]
	var col: Color = s["color"]
	var sd: Dictionary = GlobalState.skills.get(key, {"level": 1, "xp": 0, "xp_needed": 50})
	var lvl: int = int(sd.get("level", 1))
	var xp: int = int(sd.get("xp", 0))
	var needed: int = int(sd.get("xp_needed", 50))
	var pct: int = int(round(100.0 * float(xp) / float(maxi(1, needed))))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.card_tinted(col, 18, 16))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	vb.add_child(head)

	var badge := UiKit.avatar(s["icon"], 64, col)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(badge)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	head.add_child(info)
	var name_lbl := Label.new()
	name_lbl.text = Locale.t("skill_" + key)
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", UiKit.TEXT)
	info.add_child(name_lbl)
	var res: Dictionary = GameConfig.GATHER_RESOURCES.get(key, {})
	if not res.is_empty():
		var owned: int = int(GlobalState.get_item(res["id"]).get("quantity", 0))
		var cap := Label.new()
		cap.text = "%s %s  ·  %s" % [res["icon"], Locale.t(res["loc"]), Locale.t("gather_owned", [owned])]
		cap.add_theme_font_size_override("font_size", 22)
		cap.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		info.add_child(cap)

	var lvl_badge := PanelContainer.new()
	lvl_badge.add_theme_stylebox_override("panel", UiKit.chip(col))
	lvl_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lm := UiKit.margins(14, 14, 6, 6)
	lvl_badge.add_child(lm)
	var lvl_lbl := Label.new()
	lvl_lbl.text = "Nv %d" % lvl
	lvl_lbl.add_theme_font_size_override("font_size", 24)
	lvl_lbl.add_theme_color_override("font_color", col)
	lm.add_child(lvl_lbl)
	head.add_child(lvl_badge)

	# Barra GRUESA (32px) con progreso superpuesto — bien visible y llamativa.
	vb.add_child(_labeled_bar(xp, needed, col, "%d / %d  ·  %d%%" % [xp, needed, pct], 32))
	_ignore_mouse_recursive(card)
	return card


# ══════════════════════════════════════════════════════════════════════════════
# 5. SUB-VISTA: PROFESIONES  (elegir clase activa + técnicas)
# ══════════════════════════════════════════════════════════════════════════════
func _build_profesiones(host: VBoxContainer) -> void:
	host.add_child(UiKit.section_header("📜  " + Locale.t("char_professions"), 22))

	# Selector compacto: una fila con los iconos de TODAS las profesiones (elige la
	# que quieres inspeccionar) + una fila con el botón para activarla. Ahorra mucho
	# espacio frente a la antigua lista vertical de tarjetas grandes.
	if _prof_selected == "" or not (_prof_selected in PROFESSIONS):
		_prof_selected = GlobalState.profession if GlobalState.profession in PROFESSIONS else (PROFESSIONS[0] if not PROFESSIONS.is_empty() else "")

	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 8)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for prof in PROFESSIONS:
		picker.add_child(_make_profession_icon_button(prof))
	host.add_child(picker)

	# Fila con el botón de activar la profesión seleccionada (o su estado).
	host.add_child(_make_profession_activate_button(_prof_selected))

	host.add_child(_hsep())

	# Técnicas de la profesión SELECCIONADA: muestra las desbloqueadas + solo la primera bloqueada como "???"
	var tech_title := "✨  " + Locale.t("char_techniques") + Locale.pick({"es": " (Máx. 4 activas)", "en": " (Max. 4 active)"})
	host.add_child(UiKit.section_header(tech_title, 19))
	var all_techs: Array = Design.get_profession_skills(_prof_selected)
	var visible_techs: Array = []
	var first_locked_found := false
	var sel_lvl: int = int(GlobalState.get_profession_progress(_prof_selected).get("level", 1))

	for t in all_techs:
		var req_lvl: int = int(t.get("level", 1))
		if sel_lvl >= req_lvl:
			visible_techs.append(t)
		elif not first_locked_found:
			first_locked_found = true
			visible_techs.append(t)

	host.add_child(_two_column_grid(visible_techs, _make_technique_card))

	# Poder de EXPLORACIÓN (verbos permanentes de mazmorras).
	host.add_child(_hsep())
	_build_dungeon_skills(host)


## Coloca los elementos de `items` en un GridContainer de 2 columnas, construyendo
## cada tarjeta con `make_card` (que recibe el elemento y devuelve un Control).
func _two_column_grid(items: Array, make_card: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for it in items:
		var card: Control = make_card.call(it)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
	return grid


## Botón-icono compacto de una profesión para el selector horizontal. Resalta la
## seleccionada; muestra 🔒 si está bloqueada. Al pulsar, cambia la selección
## (solo cambia lo que se INSPECCIONA; activar es un botón aparte).
func _make_profession_icon_button(prof: String) -> Button:
	var unlocked: bool = prof in GlobalState.unlocked_professions
	var active: bool = GlobalState.profession == prof
	var selected: bool = _prof_selected == prof
	var col := _profession_color(prof)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 108)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.tooltip_text = _profession_name(prof)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(16)
	style.set_content_margin_all(4)
	style.bg_color = Color(col.r, col.g, col.b, 0.22 if selected else 0.06)
	style.border_color = col if selected else Color(col.r, col.g, col.b, 0.35)
	style.set_border_width_all(3 if selected else 1)
	if active:
		style.border_width_bottom = 6
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, style)

	var tex := _profession_texture(prof)
	if tex != null and unlocked:
		var center_box := CenterContainer.new()
		center_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(64, 64)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_box.add_child(img)
		btn.add_child(center_box)
	else:
		btn.add_theme_font_size_override("font_size", 42)
		btn.text = _profession_icon(prof) if unlocked else "🔒"

	btn.pressed.connect(func() -> void:
		_prof_selected = prof
		_refresh()
	)
	return btn


## Botón ancho para ACTIVAR la profesión seleccionada. Muestra su nombre y estado:
## activa (deshabilitado), desbloqueada (activable) o bloqueada (deshabilitado).
func _make_profession_activate_button(prof: String) -> Button:
	var unlocked: bool = prof in GlobalState.unlocked_professions
	var active: bool = GlobalState.profession == prof
	var col := _profession_color(prof)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 88)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = active or not unlocked
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(16)
	style.set_content_margin_all(8)
	style.bg_color = Color(col.r, col.g, col.b, 0.20 if active else 0.10)
	style.border_color = col if (active or unlocked) else Color(col.r, col.g, col.b, 0.4)
	style.set_border_width_all(2)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, style)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tex := _profession_texture(prof)
	if tex != null and unlocked:
		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(54, 54)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(img)
	else:
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.add_theme_font_size_override("font_size", 30)
		hb.add_child(lock_lbl)

	var status: String = Locale.t("char_prof_active") if active else (Locale.t("char_prof_switch") if unlocked else Locale.t("char_prof_locked"))
	var txt_lbl := Label.new()
	txt_lbl.text = "%s  ·  %s" % [_profession_name(prof), status]
	txt_lbl.add_theme_font_size_override("font_size", 28)
	txt_lbl.add_theme_color_override("font_color", col if active else (UiKit.TEXT if unlocked else UiKit.TEXT_FAINT))
	hb.add_child(txt_lbl)

	btn.add_child(hb)

	if unlocked and not active:
		btn.pressed.connect(func() -> void:
			GlobalState.set_profession(prof)
			AudioManager.play_ui("reward")
			UiKit.pop(btn, 1.12, 0.18)
			var skill_id := ExplorationSkills.unlock_for_profession(prof)
			if skill_id != "":
				AudioManager.play_ui("success")
				UiKit.toast(self, Locale.pick({
					"es": "🌟 %s aprendida (%s)" % [ExplorationSkills.display_name(skill_id), _profession_name(prof)],
					"en": "🌟 %s learned (%s)" % [ExplorationSkills.display_name(skill_id), _profession_name(prof)]
				}), UiKit.ACCENT_SOFT)
			UiKit.toast(self, Locale.pick({"es": "👑 Ahora eres %s" % _profession_name(prof), "en": "👑 You are now a %s" % _profession_name(prof)}), col)
		)
	return btn


## Tarjeta de una técnica: icono/imagen, nombre, descripción y equipable (máx. 4 activas).
func _make_technique_card(t: Dictionary) -> PanelContainer:
	var t_id := String(t.get("id", ""))
	var req_lvl: int = int(t.get("level", 1))
	var sel_lvl: int = int(GlobalState.get_profession_progress(_prof_selected).get("level", 1))
	var is_unlocked: bool = sel_lvl >= req_lvl
	var active_ids := GlobalState.get_active_combat_skills(_prof_selected)
	var is_active: bool = is_unlocked and active_ids.has(t_id)

	var pc := _profession_color(_prof_selected)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiKit.SURFACE if is_unlocked else UiKit.BG_DEEP
	if is_active:
		style.bg_color = Color(UiKit.GOOD.r, UiKit.GOOD.g, UiKit.GOOD.b, 0.14)
		style.border_color = UiKit.GOOD
		style.set_border_width_all(2)
	else:
		style.border_color = Color(pc.r, pc.g, pc.b, 0.4) if is_unlocked else UiKit.BORDER
		style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", style)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)

	var tex := UiKit.load_texture_safe("res://assets/combat/skills/%s.png" % t_id)
	if tex != null and is_unlocked:
		var img_frame := PanelContainer.new()
		var f_style := StyleBoxFlat.new()
		f_style.bg_color = Color(0, 0, 0, 0.45)
		f_style.set_corner_radius_all(8)
		f_style.set_border_width_all(1)
		f_style.border_color = pc.lightened(0.2)
		img_frame.add_theme_stylebox_override("panel", f_style)
		img_frame.custom_minimum_size = Vector2(42, 42)
		img_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(36, 36)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img_frame.add_child(img)
		hb.add_child(img_frame)
	else:
		var icon := Label.new()
		icon.text = "🔒" if not is_unlocked else String(t.get("icon", "✨"))
		icon.add_theme_font_size_override("font_size", 28)
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hb.add_child(icon)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	hb.add_child(vb)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	vb.add_child(name_row)

	var name_lbl := Label.new()
	var t_name = t.get("name", "")
	var t_name_str: String = Locale.pick(t_name) if t_name is Dictionary else String(t_name)
	name_lbl.text = t_name_str if is_unlocked else "???"
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", UiKit.TEXT if is_unlocked else UiKit.TEXT_FAINT)
	name_row.add_child(name_lbl)

	if is_active:
		var badge := Label.new()
		badge.text = "☑ " + Locale.pick({"es": "Activa", "en": "Active"})
		badge.add_theme_font_size_override("font_size", 22)
		badge.add_theme_color_override("font_color", UiKit.GOOD)
		name_row.add_child(badge)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_unlocked:
		var d_val = t.get("desc", {})
		desc.text = Locale.pick(d_val) if d_val is Dictionary else String(d_val)
		desc.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	else:
		desc.text = Locale.t("tech_locked_level", [req_lvl])
		desc.add_theme_color_override("font_color", UiKit.HP)
	desc.add_theme_font_size_override("font_size", 24)
	vb.add_child(desc)

	var cost := Label.new()
	cost.text = "%d MP" % int(t.get("cost", 0)) if is_unlocked else ""
	cost.add_theme_font_size_override("font_size", 26)
	cost.add_theme_color_override("font_color", UiKit.MP)
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(cost)

	# Si está desbloqueada, permitir pulsar sobre la tarjeta para equipar / desequipar como activa (máx. 4)
	if is_unlocked:
		card.gui_input.connect(func(event: InputEvent) -> void:
			if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
				var ok := GlobalState.toggle_active_combat_skill(_prof_selected, t_id)
				if not ok:
					if active_ids.size() >= 4:
						UiKit.toast(self, Locale.pick({"es": "⚠️ Máximo 4 habilidades activas. Desequipa una primero.", "en": "⚠️ Max 4 active skills. Unequip one first."}), UiKit.WARN)
					else:
						UiKit.toast(self, Locale.pick({"es": "⚠️ Debes mantener al menos 1 habilidad activa.", "en": "⚠️ Must keep at least 1 active skill."}), UiKit.WARN)
				else:
					AudioManager.play_sfx("click")
					_refresh()
		)

	return card
