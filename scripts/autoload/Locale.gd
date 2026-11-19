# Locale.gd
# Autoload Singleton — Internacionalización (i18n) y ajustes persistentes.
# Gestiona el idioma activo (español / inglés), la persistencia de las
# opciones del usuario (idioma y volumen) en disco, y emite una señal cuando
# el idioma cambia para que todas las interfaces se re-rendericen.
#
# Uso:  Locale.t("menu_new_game")  ->  "Nueva Partida" / "New Game"
#       Locale.t("travel_steps", [3])  ->  formato con argumentos (%d, %s ...)
extends Node

## Emitida cuando el idioma cambia. Las vistas deben reconstruir sus textos.
signal locale_changed

## Emitida cuando cambia cualquier ajuste de audio.
signal audio_changed

## Emitida cuando cambia cualquier ajuste de accesibilidad (motion / fuente / daltonismo).
signal accessibility_changed

# ─── CONSTANTES ───────────────────────────────────────────────────────────────
const SETTINGS_PATH: String = "user://settings.cfg"
const SUPPORTED: Array[String] = ["es", "en", "fr", "it", "de", "zh", "ja"]

# ─── ESTADO ───────────────────────────────────────────────────────────────────
var current: String = "es"
var master_volume: float = 0.9
var sfx_enabled: bool = true

# ─── ACCESIBILIDAD ────────────────────────────────────────────────────────────
## Reduce/elimina animaciones intensas (sacudidas de pantalla, parpadeos).
var reduce_motion: bool = false
## Escala global de la fuente de interfaz (0.8 - 1.6).
var font_scale: float = 1.0
## Activa una paleta apta para daltonismo en los avisos de combate.
var colorblind: bool = false
## Multiplicador de velocidad del texto (typewriter): 0.5 = lento, 2.0 = rápido.
var text_speed: float = 1.0
## Disposición del HUD para ZURDOS: reubica el anillo de habilidades de mazmorra al
## lado izquierdo (por defecto, a la derecha, para diestros).
var left_handed: bool = false
## Identificador del tema de UI seleccionado por el jugador.
var ui_theme_id: String = "default"

# Tabla de traducciones: clave -> { "es": "...", "en": "..." }
var _t: Dictionary = {}


## Señal emitida cuando cambia el tema de UI seleccionado.
signal theme_changed(theme_id: String)


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_build_table()
	_load_settings()
	_apply_audio()
	_apply_font_scale()
	_ensure_main_theme_cjk()
	_apply_theme_font()


## Parchea (una sola vez) el tema principal compartido `main_theme.tres` para
## que su `default_font` (EBGaramond, sin glifos CJK) tenga el fallback CJK.
## Este tema se asigna DIRECTAMENTE como `theme` de varios Controls raíz
## (GameRoot, MainMenu, ViewPlace...), por lo que su fuente tiene prioridad
## sobre la del árbol raíz: sin este parche, el texto en chino/japonés de esas
## pantallas saldría como cajas vacías (tofu).
func _ensure_main_theme_cjk() -> void:
	var main_theme_path := "res://assets/common/main_theme.tres"
	if ResourceLoader.exists(main_theme_path):
		var main_theme := load(main_theme_path) as Theme
		if main_theme != null:
			UiKit.ensure_theme_cjk_fallback(main_theme)
	var garamond := load("res://assets/common/fonts/EBGaramond.ttf") as Font
	if garamond != null:
		UiKit.ensure_font_cjk_fallback(garamond)
	var cinzel := load("res://assets/common/fonts/Cinzel.ttf") as Font
	if cinzel != null:
		UiKit.ensure_font_cjk_fallback(cinzel)


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA — TRADUCCIÓN Y RESOLUCIÓN DE IDIOMA CON FALLBACK
# ══════════════════════════════════════════════════════════════════════════════

## Resuelve un texto localizado aplicando la jerarquía de fallback:
## 1. Idioma activo (current) si existe y no está vacío.
## 2. Inglés ("en") si existe y no está vacío.
## 3. Español ("es") si existe y no está vacío.
## 4. Cualquier otro idioma que contenga texto.
## 5. Cadena vacía si todo está vacío.
func _resolve_fallback(dict: Dictionary) -> String:
	if dict.has(current):
		var val: String = str(dict[current]).strip_edges()
		if val != "":
			return str(dict[current])
	if dict.has("en"):
		var val_en: String = str(dict["en"]).strip_edges()
		if val_en != "":
			return str(dict["en"])
	if dict.has("es"):
		var val_es: String = str(dict["es"]).strip_edges()
		if val_es != "":
			return str(dict["es"])
	for k in dict.keys():
		var val_other: String = str(dict[k]).strip_edges()
		if val_other != "":
			return str(dict[k])
	return ""


## Devuelve la cadena traducida para la clave dada en el idioma actual.
## Si la clave no existe, devuelve la propia clave (útil para detectar olvidos).
## 'subs' permite formatear con % (ej: "%d pasos").
func t(key: String, subs: Array = []) -> String:
	var entry: Dictionary = _t.get(key, {})
	if entry.is_empty():
		return key
	var text: String = _resolve_fallback(entry)
	if text == "":
		text = key
	if subs.is_empty():
		return text
	return text % subs


## Devuelve la variante del idioma actual de un diccionario inline {"es": "...", "en": "..."}.
## Permite que las bases de datos (NpcDatabase / CityDatabase) lleven su texto multi-idioma
## EMBEBIDO, resolviendo con fallback automático (current -> en -> es -> any -> "").
func pick(variants, subs: Array = []) -> String:
	var text: String
	if variants is Dictionary:
		text = _resolve_fallback(variants)
	else:
		text = str(variants)
	if subs.is_empty():
		return text
	return text % subs


## Devuelve true si el idioma indicado está soportado.
func is_supported(code: String) -> bool:
	return SUPPORTED.has(code)


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA — AJUSTES
# ══════════════════════════════════════════════════════════════════════════════

## Cambia el idioma activo, lo persiste y notifica a las interfaces.
func set_locale(code: String) -> void:
	if not is_supported(code) or code == current:
		if code == current:
			return
		code = "es"
	current = code
	_save_settings()
	locale_changed.emit()


## Alterna entre español e inglés (útil para un único botón conmutador).
func toggle_locale() -> void:
	set_locale("en" if current == "es" else "es")


## Ajusta el volumen maestro (0.0 - 1.0), lo aplica y lo persiste.
func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save_settings()
	audio_changed.emit()


func set_sfx_enabled(value: bool) -> void:
	sfx_enabled = value
	_apply_audio()
	_save_settings()
	audio_changed.emit()


## Activa/desactiva la reducción de movimiento, la persiste y avisa a la interfaz.
func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	_save_settings()
	accessibility_changed.emit()


## Ajusta la escala de la fuente (0.8 - 1.6), la persiste y avisa a la interfaz.
func set_font_scale(value: float) -> void:
	font_scale = clampf(value, 0.8, 1.6)
	_apply_font_scale()
	_save_settings()
	accessibility_changed.emit()


## Aplica la escala de fuente como factor de escala de contenido de la ventana raíz.
func _apply_font_scale() -> void:
	var tree := get_tree()
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = font_scale


## Activa/desactiva la paleta apta para daltonismo, la persiste y avisa a la interfaz.
func set_colorblind(value: bool) -> void:
	colorblind = value
	_save_settings()
	accessibility_changed.emit()


## Ajusta la velocidad del texto (typewriter) [0.5 - 2.0], la persiste y avisa.
func set_text_speed(value: float) -> void:
	text_speed = clampf(value, 0.5, 2.0)
	_save_settings()
	accessibility_changed.emit()


## Activa/desactiva la disposición del HUD para zurdos, la persiste y avisa.
func set_left_handed(value: bool) -> void:
	left_handed = value
	_save_settings()
	accessibility_changed.emit()


## Cambia el tema de UI activo, lo persiste y notifica a las interfaces.
## Emite tanto `Locale.theme_changed` (compatibilidad) como
## `GlobalEvents.theme_changed` (bus estandarizado).
func set_ui_theme_id(theme_id: String) -> void:
	if theme_id == ui_theme_id:
		return
	ui_theme_id = theme_id
	_save_settings()
	_apply_theme_font()
	theme_changed.emit(theme_id)
	GlobalEvents.theme_changed.emit(theme_id)


## Aplica la tipografía del tema activo como fuente POR DEFECTO de toda la
## ventana raíz (`Theme.default_font`): cualquier `Label`/`Button`/etc. que no
## tenga ya una fuente propia por `add_theme_font_override(...)` la hereda
## automáticamente — HUD, mapamundi, diálogos, menús... sin tener que tocar
## cada nodo uno a uno.
var _root_theme: Theme = null

func _apply_theme_font() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if _root_theme == null:
		# Reutilizar el Theme ya asignado a la ventana raíz si lo hubiera
		# (para no pisar otros overrides), o crear uno nuevo si no existe.
		_root_theme = tree.root.theme if tree.root.theme != null else Theme.new()
	_root_theme.default_font = UiKit.theme_font()
	tree.root.theme = _root_theme


# ══════════════════════════════════════════════════════════════════════════════
# PERSISTENCIA
# ══════════════════════════════════════════════════════════════════════════════
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var saved_locale: String = cfg.get_value("general", "locale", "es")
	if is_supported(saved_locale):
		current = saved_locale
	master_volume = float(cfg.get_value("audio", "master_volume", master_volume))
	sfx_enabled = bool(cfg.get_value("audio", "sfx_enabled", sfx_enabled))
	reduce_motion = bool(cfg.get_value("accessibility", "reduce_motion", reduce_motion))
	font_scale = float(cfg.get_value("accessibility", "font_scale", font_scale))
	colorblind = bool(cfg.get_value("accessibility", "colorblind", colorblind))
	text_speed = float(cfg.get_value("accessibility", "text_speed", text_speed))
	left_handed = bool(cfg.get_value("accessibility", "left_handed", left_handed))
	ui_theme_id = String(cfg.get_value("general", "ui_theme_id", ui_theme_id))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", current)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.set_value("accessibility", "reduce_motion", reduce_motion)
	cfg.set_value("accessibility", "font_scale", font_scale)
	cfg.set_value("accessibility", "colorblind", colorblind)
	cfg.set_value("accessibility", "text_speed", text_speed)
	cfg.set_value("accessibility", "left_handed", left_handed)
	cfg.set_value("general", "ui_theme_id", ui_theme_id)
	cfg.save(SETTINGS_PATH)


func _apply_audio() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx < 0:
		bus_idx = 0
	var vol_db: float = linear_to_db(master_volume) if master_volume > 0.001 else -80.0
	AudioServer.set_bus_volume_db(bus_idx, vol_db)
	AudioServer.set_bus_mute(bus_idx, not sfx_enabled or master_volume <= 0.001)


# ══════════════════════════════════════════════════════════════════════════════
# TABLA DE TRADUCCIONES
# ══════════════════════════════════════════════════════════════════════════════
func _build_table() -> void:
	_t = {
		# ── Menú principal ──────────────────────────────────────────────────
		"app_title":        {"es": "Ecos de la Verdad", "en": "Echoes of Truth", "fr": "Échos de la Vérité", "it": "Echi della Verità", "de": "Echos der Wahrheit", "zh": "真理的回响", "ja": "真実の残響"},
		"app_subtitle":     {"es": "Basado en la novela El secreto de Lázaro", "en": "Based on the novel The Secret of Lazarus", "fr": "Basé sur le roman Le secret de Lazare", "it": "Basato sul romanzo Il segreto di Lazzaro", "de": "Basierend auf dem Roman Das Geheimnis von Lazarus", "zh": "改编自小说《拉撒路的秘密》", "ja": "小説『ラザロの秘密』に基づく"},

		# ── Pantalla de inicio / Splash ──────────────────────────────────────
		"splash_powered_by":     {"es": "CREADO CON", "en": "CREATED WITH", "fr": "CRÉÉ AVEC", "it": "CREATO CON", "de": "ERSTELLT MIT", "zh": "开发引擎与框架", "ja": "開発ツール"},
		"splash_engine_title":   {"es": "Taos Game Maker", "en": "Taos Game Maker"},
		"splash_engine_tagline": {"es": "Framework & Suite de Desarrollo RPG 3D", "en": "Data-Driven 3D RPG Studio & Framework", "fr": "Framework et Suite de Développement RPG 3D", "it": "Framework e Suite di Sviluppo GDR 3D", "de": "Framework & Entwicklungs-Suite für 3D-RPGs", "zh": "数据驱动 3D RPG 工作室与框架", "ja": "データ駆動型 3D RPG スタジオ＆フレームワーク"},
		"splash_lore_badge":     {"es": "UNIVERSO NARRATIVO", "en": "ORIGINAL LORE & STORY", "fr": "UNIVERS NARRATIF", "it": "UNIVERSO NARRATIVO", "de": "NARRATIVES UNIVERSUM", "zh": "故事背景", "ja": "原作ストーリー"},
		"splash_book_prefix":    {"es": "Basado en la novela", "en": "Based on the novel", "fr": "Basé sur le roman", "it": "Basato sul romanzo", "de": "Basierend auf dem Roman", "zh": "改编自小说", "ja": "原作小説"},
		"splash_book_title":     {"es": "El secreto de Lázaro", "en": "The Secret of Lazarus", "fr": "Le secret de Lazare", "it": "Il segreto di Lazzaro", "de": "Das Geheimnis von Lazarus", "zh": "《拉撒路的秘密》", "ja": "『拉撒路的秘密』"},
		"splash_author":         {"es": "de José Manuel Heredia Reyes", "en": "by José Manuel Heredia Reyes", "fr": "par José Manuel Heredia Reyes", "it": "di José Manuel Heredia Reyes", "de": "von José Manuel Heredia Reyes", "zh": "何塞·曼努埃尔·埃雷迪亚·雷耶斯 著", "ja": "ホセ・マヌエル・エレディア・レジェス 著"},
		"splash_skip_hint":      {"es": "Pulsa Espacio, Intro, Escape o un botón del mando para saltar", "en": "Press Space, Enter, Escape or a gamepad button to skip", "fr": "Appuyez sur Espace, Entrée, Échap ou une touche manette pour passer", "it": "Premi Spazio, Invio, Esc o un tasto del controller per saltare", "de": "Leertaste, Eingabe, Esc oder Gamepad-Taste drücken zum Überspringen", "zh": "按空格键、回车键、Esc 键或手柄按键跳过", "ja": "Space、Enter、Esc、またはゲームパッドのボタンでスキップ"},
		"menu_new_game":    {"es": "Nueva Partida", "en": "New Game", "fr": "Nouvelle partie", "it": "Nuova partita", "de": "Neues Spiel", "zh": "新游戏", "ja": "ニューゲーム"},
		"menu_debug_mode":  {"es": "Modo Depuración", "en": "Debug Mode", "fr": "Mode débogage", "it": "Modalità debug", "de": "Debug-Modus", "zh": "调试模式", "ja": "デバッグモード"},
		"menu_test_room":   {"es": "Sala de Pruebas", "en": "Test Area", "fr": "Zone de test", "it": "Area di prova", "de": "Testbereich", "zh": "测试区", "ja": "テストエリア"},
		"menu_continue":    {"es": "Continuar", "en": "Continue", "fr": "Continuer", "it": "Continua", "de": "Fortsetzen", "zh": "继续", "ja": "つづきから"},
		"menu_options":     {"es": "Opciones", "en": "Options", "fr": "Options", "it": "Opzioni", "de": "Optionen", "zh": "选项", "ja": "設定"},
		"menu_credits":     {"es": "Créditos", "en": "Credits", "fr": "Crédits", "it": "Crediti", "de": "Abspann", "zh": "制作人员", "ja": "クレジット"},
		"menu_quit":        {"es": "Salir del Juego", "en": "Quit Game", "fr": "Quitter le jeu", "it": "Esci dal gioco", "de": "Spiel beenden", "zh": "退出游戏", "ja": "ゲームを終了"},
		"menu_back":        {"es": "Volver", "en": "Back", "fr": "Retour", "it": "Indietro", "de": "Zurück", "zh": "返回", "ja": "もどる"},
		"menu_new_game_confirm_title": {"es": "¿Empezar de nuevo?", "en": "Start over?", "fr": "Recommencer ?", "it": "Ricominciare?", "de": "Neu anfangen?", "zh": "重新开始？", "ja": "最初からやり直す？"},
		"menu_new_game_confirm_body":  {"es": "Se borrará tu progreso guardado y comenzarás desde el principio.", "en": "Your saved progress will be erased and you will start from the beginning.", "fr": "Ta progression sauvegardée sera effacée et tu recommenceras depuis le début.", "it": "I tuoi progressi salvati verranno cancellati e ricomincerai dall'inizio.", "de": "Dein gespeicherter Fortschritt wird gelöscht und du beginnst von vorn.", "zh": "你保存的进度将被清除，你将从头开始。", "ja": "セーブした進行状況は消去され、最初からやり直しになります。"},
		"menu_confirm":     {"es": "Confirmar", "en": "Confirm", "fr": "Confirmer", "it": "Conferma", "de": "Bestätigen", "zh": "确认", "ja": "決定"},

		# ── Viajes y confirmaciones del mapa ─────────────────────────────────
		"world_travel_confirm": {"es": "⚔️  Confirmar Viaje", "en": "⚔️  Confirm Travel", "fr": "⚔️  Confirmer le voyage", "it": "⚔️  Conferma viaggio", "de": "⚔️  Reise bestätigen", "zh": "⚔️  确认前往", "ja": "⚔️  移動を確定"},
		"world_cancel":         {"es": "❌  Cancelar", "en": "❌  Cancel", "fr": "❌  Annuler", "it": "❌  Annulla", "de": "❌  Abbrechen", "zh": "❌  取消", "ja": "❌  キャンセル"},
		"world_travel":         {"es": "✅  Viajar", "en": "✅  Travel", "fr": "✅  Voyager", "it": "✅  Viaggia", "de": "✅  Reisen", "zh": "✅  前往", "ja": "✅  移動する"},
		"world_distance":       {"es": "Distancia: %d paso%s", "en": "Distance: %d step%s", "fr": "Distance : %d pas%s", "it": "Distanza: %d passo%s", "de": "Entfernung: %d Schritt%s", "zh": "距离：%d 步%s", "ja": "距離：%d 歩%s"},

		# ── HUD Superior Base/Job ───────────────────────────────────────────
		"hud_base_level":  {"es": "NV %d", "en": "LV %d", "fr": "NV %d", "it": "LV %d", "de": "LV %d", "zh": "等级 %d", "ja": "LV %d"},
		"hud_base_label":  {"es": "Base", "en": "Base", "fr": "Base", "it": "Base", "de": "Basis", "zh": "基础", "ja": "ベース"},
		"hud_job_level":   {"es": "JB %d", "en": "JB %d", "fr": "JB %d", "it": "JB %d", "de": "JB %d", "zh": "职业 %d", "ja": "JB %d"},

		# ── Requisitos de técnicas ──────────────────────────────────────────
		"tech_locked_level": {"es": "Requiere Nivel de Trabajo %d", "en": "Requires Job Level %d", "fr": "Requiert le niveau de métier %d", "it": "Richiede livello di lavoro %d", "de": "Erfordert Job-Stufe %d", "zh": "需要职业等级 %d", "ja": "ジョブレベル %d が必要"},

		# ── Descripciones de Facetas de Personalidad ──────────────────────────
		"facet_neutral": {"es": "Neutral", "en": "Neutral", "fr": "Neutre", "it": "Neutrale", "de": "Neutral", "zh": "中立", "ja": "中立"},
		
		# Valor
		"facet_label_valor_-5": {"es": "Cobarde", "en": "Cowardly", "fr": "Lâche", "it": "Codardo", "de": "Feige", "zh": "懦弱", "ja": "臆病"},
		"facet_label_valor_-4": {"es": "Asustadizo", "en": "Timid", "fr": "Craintif", "it": "Timoroso", "de": "Ängstlich", "zh": "胆小", "ja": "おびえがち"},
		"facet_label_valor_-3": {"es": "Temeroso", "en": "Fearful", "fr": "Peureux", "it": "Pauroso", "de": "Furchtsam", "zh": "畏惧", "ja": "恐がり"},
		"facet_label_valor_-2": {"es": "Prudente", "en": "Prudent", "fr": "Prudent", "it": "Prudente", "de": "Umsichtig", "zh": "谨慎", "ja": "慎重"},
		"facet_label_valor_-1": {"es": "Cauteloso", "en": "Cautious", "fr": "Précautionneux", "it": "Cauto", "de": "Vorsichtig", "zh": "小心", "ja": "用心深い"},
		"facet_label_valor_0":  {"es": "Neutral", "en": "Neutral", "fr": "Neutre", "it": "Neutrale", "de": "Neutral", "zh": "中立", "ja": "中立"},
		"facet_label_valor_1":  {"es": "Decidido", "en": "Resolute", "fr": "Résolu", "it": "Deciso", "de": "Entschlossen", "zh": "果断", "ja": "決断力がある"},
		"facet_label_valor_2":  {"es": "Valiente", "en": "Brave", "fr": "Courageux", "it": "Coraggioso", "de": "Mutig", "zh": "勇敢", "ja": "勇敢"},
		"facet_label_valor_3":  {"es": "Audaz", "en": "Bold", "fr": "Audacieux", "it": "Audace", "de": "Kühn", "zh": "大胆", "ja": "大胆"},
		"facet_label_valor_4":  {"es": "Intrépido", "en": "Fearless", "fr": "Intrépide", "it": "Intrepido", "de": "Furchtlos", "zh": "无畏", "ja": "恐れ知らず"},
		"facet_label_valor_5":  {"es": "Heroico", "en": "Heroic", "fr": "Héroïque", "it": "Eroico", "de": "Heldenhaft", "zh": "英勇", "ja": "英雄的"},
		
		# Bondad
		"facet_label_bondad_-5": {"es": "Cruel", "en": "Cruel", "fr": "Cruel", "it": "Crudele", "de": "Grausam", "zh": "残忍", "ja": "残酷"},
		"facet_label_bondad_-4": {"es": "Hostil", "en": "Hostile", "fr": "Hostile", "it": "Ostile", "de": "Feindselig", "zh": "敌意", "ja": "敵対的"},
		"facet_label_bondad_-3": {"es": "Frío", "en": "Cold", "fr": "Froid", "it": "Freddo", "de": "Kalt", "zh": "冷漠", "ja": "冷淡"},
		"facet_label_bondad_-2": {"es": "Borde", "en": "Rude", "fr": "Grossier", "it": "Sgarbato", "de": "Schroff", "zh": "粗鲁", "ja": "無礼"},
		"facet_label_bondad_-1": {"es": "Desatento", "en": "Thoughtless", "fr": "Négligent", "it": "Sbadato", "de": "Gedankenlos", "zh": "漫不经心", "ja": "無頓着"},
		"facet_label_bondad_0":  {"es": "Neutral", "en": "Neutral", "fr": "Neutre", "it": "Neutrale", "de": "Neutral", "zh": "中立", "ja": "中立"},
		"facet_label_bondad_1":  {"es": "Simpático", "en": "Friendly", "fr": "Sympathique", "it": "Simpatico", "de": "Freundlich", "zh": "友善", "ja": "気さく"},
		"facet_label_bondad_2":  {"es": "Agradable", "en": "Kind", "fr": "Aimable", "it": "Gentile", "de": "Nett", "zh": "亲切", "ja": "親切"},
		"facet_label_bondad_3":  {"es": "Atento", "en": "Helpful", "fr": "Attentionné", "it": "Premuroso", "de": "Hilfsbereit", "zh": "体贴", "ja": "気配り上手"},
		"facet_label_bondad_4":  {"es": "Cálido", "en": "Warm", "fr": "Chaleureux", "it": "Caloroso", "de": "Herzlich", "zh": "温暖", "ja": "温かい"},
		"facet_label_bondad_5":  {"es": "Altruista", "en": "Altruistic", "fr": "Altruiste", "it": "Altruista", "de": "Selbstlos", "zh": "无私", "ja": "利他的"},
		
		# Aspecto
		"facet_label_aspecto_-5": {"es": "Repulsivo", "en": "Repulsive", "fr": "Repoussant", "it": "Ripugnante", "de": "Abstoßend", "zh": "令人厌恶", "ja": "不快"},
		"facet_label_aspecto_-4": {"es": "Antipático", "en": "Unfriendly", "fr": "Antipathique", "it": "Antipatico", "de": "Unfreundlich", "zh": "不友好", "ja": "無愛想"},
		"facet_label_aspecto_-3": {"es": "Seco", "en": "Blunt", "fr": "Sec", "it": "Brusco", "de": "Barsch", "zh": "生硬", "ja": "そっけない"},
		"facet_label_aspecto_-2": {"es": "Tosco", "en": "Coarse", "fr": "Grossier", "it": "Rozzo", "de": "Grob", "zh": "粗俗", "ja": "粗野"},
		"facet_label_aspecto_-1": {"es": "Huraño", "en": "Aloof", "fr": "Renfermé", "it": "Scontroso", "de": "Reserviert", "zh": "孤僻", "ja": "とっつきにくい"},
		"facet_label_aspecto_0":  {"es": "Neutral", "en": "Neutral", "fr": "Neutre", "it": "Neutrale", "de": "Neutral", "zh": "中立", "ja": "中立"},
		"facet_label_aspecto_1":  {"es": "Atractivo", "en": "Attractive", "fr": "Attirant", "it": "Attraente", "de": "Attraktiv", "zh": "有魅力", "ja": "魅力的"},
		"facet_label_aspecto_2":  {"es": "Atrayente", "en": "Appealing", "fr": "Séduisant", "it": "Accattivante", "de": "Ansprechend", "zh": "讨喜", "ja": "好ましい"},
		"facet_label_aspecto_3":  {"es": "Carismático", "en": "Charismatic", "fr": "Charismatique", "it": "Carismatico", "de": "Charismatisch", "zh": "具魅力", "ja": "カリスマ的"},
		"facet_label_aspecto_4":  {"es": "Encantador", "en": "Charming", "fr": "Charmant", "it": "Affascinante", "de": "Charmant", "zh": "迷人", "ja": "魅惑的"},
		"facet_label_aspecto_5":  {"es": "Fascinante", "en": "Alluring", "fr": "Fascinant", "it": "Seducente", "de": "Betörend", "zh": "令人着迷", "ja": "魅了的"},
		
		# Inteligencia
		"facet_label_inteligencia_-5": {"es": "Inculto", "en": "Uneducated", "fr": "Inculte", "it": "Incolto", "de": "Ungebildet", "zh": "无知", "ja": "無教養"},
		"facet_label_inteligencia_-4": {"es": "Obtuso", "en": "Obtuse", "fr": "Obtus", "it": "Ottuso", "de": "Beschränkt", "zh": "迟钝", "ja": "鈍い"},
		"facet_label_inteligencia_-3": {"es": "Torpe", "en": "Clumsy", "fr": "Maladroit", "it": "Maldestro", "de": "Ungeschickt", "zh": "笨拙", "ja": "不器用"},
		"facet_label_inteligencia_-2": {"es": "Simplón", "en": "Simple", "fr": "Simplet", "it": "Sempliciotto", "de": "Einfältig", "zh": "头脑简单", "ja": "単純"},
		"facet_label_inteligencia_-1": {"es": "Despistado", "en": "Absentminded", "fr": "Distrait", "it": "Distratto", "de": "Zerstreut", "zh": "迷糊", "ja": "うっかり"},
		"facet_label_inteligencia_0":  {"es": "Neutral", "en": "Neutral", "fr": "Neutre", "it": "Neutrale", "de": "Neutral", "zh": "中立", "ja": "中立"},
		"facet_label_inteligencia_1":  {"es": "Perspicaz", "en": "Insightful", "fr": "Perspicace", "it": "Perspicace", "de": "Scharfsinnig", "zh": "敏锐", "ja": "洞察力がある"},
		"facet_label_inteligencia_2":  {"es": "Listo", "en": "Smart", "fr": "Malin", "it": "Sveglio", "de": "Klug", "zh": "聪明", "ja": "賢い"},
		"facet_label_inteligencia_3":  {"es": "Analítico", "en": "Analytical", "fr": "Analytique", "it": "Analitico", "de": "Analytisch", "zh": "善于分析", "ja": "分析的"},
		"facet_label_inteligencia_4":  {"es": "Brillante", "en": "Brilliant", "fr": "Brillant", "it": "Brillante", "de": "Brillant", "zh": "才华横溢", "ja": "優秀"},
		"facet_label_inteligencia_5":  {"es": "Genial", "en": "Genius", "fr": "Génie", "it": "Geniale", "de": "Genial", "zh": "天才", "ja": "天才"},
		
		# Cordura
		"facet_label_cordura_-5": {"es": "Desquiciado", "en": "Unhinged", "fr": "Dérangé", "it": "Squilibrato", "de": "Verrückt", "zh": "精神错乱", "ja": "錯乱"},
		"facet_label_cordura_-4": {"es": "Delirante", "en": "Delusional", "fr": "Délirant", "it": "Delirante", "de": "Wahnhaft", "zh": "妄想", "ja": "妄想的"},
		"facet_label_cordura_-3": {"es": "Paranoico", "en": "Paranoid", "fr": "Paranoïaque", "it": "Paranoico", "de": "Paranoid", "zh": "偏执", "ja": "被害妄想"},
		"facet_label_cordura_-2": {"es": "Inestable", "en": "Unstable", "fr": "Instable", "it": "Instabile", "de": "Instabil", "zh": "不稳定", "ja": "不安定"},
		"facet_label_cordura_-1": {"es": "Turbado", "en": "Disturbed", "fr": "Troublé", "it": "Turbato", "de": "Verstört", "zh": "心神不宁", "ja": "動揺"},
		"facet_label_cordura_0":  {"es": "Neutral", "en": "Neutral", "fr": "Neutre", "it": "Neutrale", "de": "Neutral", "zh": "中立", "ja": "中立"},
		"facet_label_cordura_1":  {"es": "Lúcido", "en": "Lucid", "fr": "Lucide", "it": "Lucido", "de": "Klar", "zh": "清醒", "ja": "明晰"},
		"facet_label_cordura_2":  {"es": "Templado", "en": "Calm", "fr": "Posé", "it": "Temperato", "de": "Gelassen", "zh": "沉着", "ja": "落ち着き"},
		"facet_label_cordura_3":  {"es": "Sereno", "en": "Serene", "fr": "Serein", "it": "Sereno", "de": "Heiter", "zh": "平静", "ja": "穏やか"},
		"facet_label_cordura_4":  {"es": "Inquebrantable", "en": "Unshakeable", "fr": "Inébranlable", "it": "Incrollabile", "de": "Unerschütterlich", "zh": "坚定不移", "ja": "不動"},
		"facet_label_cordura_5":  {"es": "Cuerdo", "en": "Sane", "fr": "Sain d'esprit", "it": "Sano di mente", "de": "Zurechnungsfähig", "zh": "理智", "ja": "正気"},

		# ── Nombres de celdas ────────────────────────────────────────────────
		"cell_base_de_operaciones":  {"es": "Base de Operaciones", "en": "Base of Operations", "fr": "Base d'opérations", "it": "Base operativa", "de": "Operationsbasis", "zh": "行动基地", "ja": "作戦拠点"},
		"cell_templo_del_sable":     {"es": "Templo del Sable", "en": "Temple of the Blade", "fr": "Temple de la Lame", "it": "Tempio della Lama", "de": "Tempel der Klinge", "zh": "剑之神殿", "ja": "剣の神殿"},
		"cell_templo_de_la_magia":   {"es": "Templo de la Magia", "en": "Temple of Magic", "fr": "Temple de la Magie", "it": "Tempio della Magia", "de": "Tempel der Magie", "zh": "魔法神殿", "ja": "魔法の神殿"},
		"cell_llanura_arida":        {"es": "Llanura Árida", "en": "Arid Plain", "fr": "Plaine aride", "it": "Pianura arida", "de": "Dürre Ebene", "zh": "干旱平原", "ja": "乾いた平原"},
		"cell_ciudad_imperial":      {"es": "Ciudad Imperial", "en": "Imperial City", "fr": "Cité impériale", "it": "Città imperiale", "de": "Kaiserstadt", "zh": "帝都", "ja": "帝都"},
		"cell_cueva_oscura":         {"es": "Cueva Oscura", "en": "Dark Cave", "fr": "Grotte sombre", "it": "Caverna oscura", "de": "Dunkle Höhle", "zh": "黑暗洞窟", "ja": "暗い洞窟"},
		"cell_puente_del_mono":      {"es": "Puente del Mono", "en": "Monkey Bridge", "fr": "Pont du Singe", "it": "Ponte della Scimmia", "de": "Affenbrücke", "zh": "猴子桥", "ja": "サルの橋"},
		"cell_pueblo_del_desierto":  {"es": "Pueblo del Desierto", "en": "Desert Town", "fr": "Village du Désert", "it": "Villaggio del Deserto", "de": "Wüstenstadt", "zh": "沙漠小镇", "ja": "砂漠の町"},
		"cell_santuario_antiguo":    {"es": "Santuario Antiguo", "en": "Ancient Shrine", "fr": "Sanctuaire ancien", "it": "Santuario antico", "de": "Uralter Schrein", "zh": "古老神社", "ja": "古代の神殿"},
		"cell_cantera_de_piedra":    {"es": "Cantera de Piedra", "en": "Stone Quarry", "fr": "Carrière de pierre", "it": "Cava di pietra", "de": "Steinbruch", "zh": "石采场", "ja": "石切り場"},
		"cell_zona_de_pesca":        {"es": "Zona de Pesca", "en": "Fishing Spot", "fr": "Coin de pêche", "it": "Zona di pesca", "de": "Angelplatz", "zh": "钓鱼点", "ja": "釣り場"},
		"cell_bosque_de_robles":     {"es": "Bosque de Robles", "en": "Oak Forest", "fr": "Forêt de chênes", "it": "Bosco di querce", "de": "Eichenwald", "zh": "橡树林", "ja": "樫の森"},
		"cell_sendero":              {"es": "Sendero", "en": "Path", "fr": "Sentier", "it": "Sentiero", "de": "Pfad", "zh": "小径", "ja": "小道"},
		"cell_agua":                 {"es": "Agua", "en": "Water", "fr": "Eau", "it": "Acqua", "de": "Wasser", "zh": "水域", "ja": "水域"},
		"cell_montana":              {"es": "Montaña", "en": "Mountain", "fr": "Montagne", "it": "Montagna", "de": "Berg", "zh": "山岭", "ja": "山"},

		# ── Descripciones de celdas ──────────────────────────────────────────
		"cell_desc_base_de_operaciones": {"es": "Tu campamento base para descansar y cocinar.", "en": "Your base camp to rest and cook.", "fr": "Ton camp de base pour te reposer et cuisiner.", "it": "Il tuo campo base per riposare e cucinare.", "de": "Dein Basislager zum Rasten und Kochen.", "zh": "你用来休息和烹饪的大本营。", "ja": "休息し料理するための拠点。"},
		"cell_desc_templo_del_sable":     {"es": "Un templo antiguo consagrado al arte de la espada.", "en": "An ancient temple dedicated to the art of the blade.", "fr": "Un temple ancien voué à l'art de l'épée.", "it": "Un antico tempio dedicato all'arte della spada.", "de": "Ein uralter Tempel, der Kunst des Schwertes geweiht.", "zh": "一座供奉剑术的古老神殿。", "ja": "剣の技に捧げられた古代の神殿。"},
		"cell_desc_templo_de_la_magia":   {"es": "Un santuario flotante imbuido de energía arcana.", "en": "A floating sanctuary imbued with arcane energy.", "fr": "Un sanctuaire flottant imprégné d'énergie arcanique.", "it": "Un santuario fluttuante intriso di energia arcana.", "de": "Ein schwebendes Heiligtum, erfüllt von arkaner Energie.", "zh": "一座充满奥术能量的浮空圣所。", "ja": "秘術のエネルギーを帯びた浮遊する聖域。"},
		"cell_desc_llanura_arida":        {"es": "Una llanura de arena reseca y sol abrasador.", "en": "A plain of parched sand and scorching sun.", "fr": "Une plaine de sable desséché sous un soleil brûlant.", "it": "Una pianura di sabbia riarsa e sole cocente.", "de": "Eine Ebene aus ausgedörrtem Sand und sengender Sonne.", "zh": "一片干裂的沙地，阳光灼人。", "ja": "乾き切った砂と焦げつく太陽の平原。"},
		"cell_desc_ciudad_imperial":      {"es": "La gran capital del imperio, próspera y resguardada.", "en": "The grand capital of the empire, prosperous and protected.", "fr": "La grande capitale de l'empire, prospère et protégée.", "it": "La grande capitale dell'impero, prospera e protetta.", "de": "Die große Hauptstadt des Reiches, wohlhabend und geschützt.", "zh": "帝国的宏伟首都，繁荣而受护。", "ja": "繁栄し守られた、帝国の大いなる首都。"},
		"cell_desc_cueva_oscura":         {"es": "Una gruta sombría donde habitan criaturas peligrosas.", "en": "A dark cave inhabited by dangerous creatures.", "fr": "Une grotte sombre habitée par des créatures dangereuses.", "it": "Una grotta oscura abitata da creature pericolose.", "de": "Eine dunkle Höhle, bewohnt von gefährlichen Kreaturen.", "zh": "一个栖息着危险生物的阴暗洞窟。", "ja": "危険な生き物が棲む薄暗い洞窟。"},
		"cell_desc_puente_del_mono":      {"es": "Un puente custodiado por un mono que adora las bananas.", "en": "A bridge guarded by a monkey who loves bananas.", "fr": "Un pont gardé par un singe qui adore les bananes.", "it": "Un ponte sorvegliato da una scimmia che adora le banane.", "de": "Eine Brücke, bewacht von einem Affen, der Bananen liebt.", "zh": "一座由爱吃香蕉的猴子看守的桥。", "ja": "バナナ大好きなサルが守る橋。"},
		"cell_desc_pueblo_del_desierto":  {"es": "Un asentamiento mercante rodeado de dunas infinitas.", "en": "A merchant settlement surrounded by endless dunes.", "fr": "Un comptoir marchand entouré de dunes infinies.", "it": "Un insediamento mercantile circondato da dune infinite.", "de": "Eine Händlersiedlung, umgeben von endlosen Dünen.", "zh": "一个被无尽沙丘环绕的商人定居点。", "ja": "果てしない砂丘に囲まれた商人の集落。"},
		"cell_desc_santuario_antiguo":    {"es": "Un santuario olvidado. Una calma extraña invade el lugar...", "en": "A forgotten shrine. A strange calm fills the place...", "fr": "Un sanctuaire oublié. Un calme étrange emplit les lieux...", "it": "Un santuario dimenticato. Una strana calma pervade il luogo...", "de": "Ein vergessener Schrein. Eine seltsame Ruhe erfüllt den Ort...", "zh": "一座被遗忘的神社。一股奇异的宁静弥漫此地……", "ja": "忘れ去られた神殿。奇妙な静けさがこの場を満たす……"},
		"cell_desc_cantera_de_piedra":    {"es": "Una zona rocosa donde extraer piedra para la base.", "en": "A rocky area to extract stone for the base.", "fr": "Une zone rocheuse pour extraire de la pierre pour la base.", "it": "Una zona rocciosa dove estrarre pietra per la base.", "de": "Ein felsiges Gebiet, um Stein für die Basis abzubauen.", "zh": "一片山岩地带，可为基地开采石材。", "ja": "拠点用の石を採取できる岩場。"},
		"cell_desc_zona_de_pesca":        {"es": "Un remanso de agua dulce ideal para lanzar la caña.", "en": "A fresh water spot ideal for casting your line.", "fr": "Un point d'eau douce idéal pour lancer sa ligne.", "it": "Uno specchio d'acqua dolce ideale per lanciare la lenza.", "de": "Ein Süßwasserplatz, ideal zum Auswerfen der Angel.", "zh": "一处适合下线垂钓的淡水水潭。", "ja": "糸を垂らすのに最適な淀みの深み。"},
		"cell_desc_bosque_de_robles":     {"es": "Un denso bosque lleno de árboles altos.", "en": "A dense forest filled with tall trees.", "fr": "Une forêt dense remplie de grands arbres.", "it": "Una fitta foresta piena di alberi alti.", "de": "Ein dichter Wald voller hoher Bäume.", "zh": "一片高树林立的茂密森林。", "ja": "背の高い木々が密生する森。"},
		"cell_desc_sendero":              {"es": "Un sendero de tierra firme para avanzar.", "en": "A dirt path to travel on.", "fr": "Un sentier de terre ferme pour avancer.", "it": "Un sentiero di terra battuta per procedere.", "de": "Ein fester Erdpfad zum Vorankommen.", "zh": "一条可供前行的土路。", "ja": "進むための固い土の道。"},
		"cell_desc_agua":                 {"es": "Agua profunda imposible de cruzar a pie.", "en": "Deep water, impossible to cross on foot.", "fr": "Eau profonde, impossible à traverser à pied.", "it": "Acqua profonda, impossibile da attraversare a piedi.", "de": "Tiefes Wasser, zu Fuß nicht zu überqueren.", "zh": "无法步行渡过的深水。", "ja": "歩いては渡れない深い水。"},
		"cell_desc_montana":              {"es": "Una cordillera empinada que bloquea el paso.", "en": "A steep mountain range blocking the way.", "fr": "Une chaîne de montagnes escarpée qui bloque le passage.", "it": "Una ripida catena montuosa che blocca il passaggio.", "de": "Eine steile Bergkette, die den Weg versperrt.", "zh": "一道陡峭的山脉，阻断了去路。", "ja": "行く手を塞ぐ急峻な山脈。"},
		"menu_cancel":      {"es": "Cancelar", "en": "Cancel", "fr": "Annuler", "it": "Annulla", "de": "Abbrechen", "zh": "取消", "ja": "キャンセル"},
		"menu_no_save":     {"es": "No hay partida guardada", "en": "No saved game", "fr": "Aucune partie sauvegardée", "it": "Nessuna partita salvata", "de": "Kein gespeichertes Spiel", "zh": "没有已保存的游戏", "ja": "セーブデータがありません"},

		# ── Opciones ────────────────────────────────────────────────────────
		"options_title":    {"es": "⚙️  Opciones", "en": "⚙️  Options", "fr": "⚙️  Options", "it": "⚙️  Opzioni", "de": "⚙️  Optionen", "zh": "⚙️  选项", "ja": "⚙️  設定"},
		"options_language": {"es": "Idioma", "en": "Language", "fr": "Langue", "it": "Lingua", "de": "Sprache", "zh": "语言", "ja": "言語"},
		"options_lang_es":  {"es": "Español", "en": "Spanish", "fr": "Espagnol", "it": "Spagnolo", "de": "Spanisch", "zh": "西班牙语", "ja": "スペイン語"},
		"options_lang_en":  {"es": "Inglés", "en": "English", "fr": "Anglais", "it": "Inglese", "de": "Englisch", "zh": "英语", "ja": "英語"},
		"options_lang_fr":  {"es": "Francés", "en": "French", "fr": "Français", "it": "Francese", "de": "Französisch", "zh": "法语", "ja": "フランス語"},
		"options_lang_it":  {"es": "Italiano", "en": "Italian", "fr": "Italien", "it": "Italiano", "de": "Italienisch", "zh": "意大利语", "ja": "イタリア語"},
		"options_lang_de":  {"es": "Alemán", "en": "German", "fr": "Allemand", "it": "Tedesco", "de": "Deutsch", "zh": "德语", "ja": "ドイツ語"},
		"options_lang_zh":  {"es": "Chino", "en": "Chinese", "fr": "Chinois", "it": "Cinese", "de": "Chinesisch", "zh": "中文", "ja": "中国語"},
		"options_lang_ja":  {"es": "Japonés", "en": "Japanese", "fr": "Japonais", "it": "Giapponese", "de": "Japanisch", "zh": "日语", "ja": "日本語"},
		"options_language_changed": {"es": "Idioma cambiado a %s", "en": "Language changed to %s", "fr": "Langue changée en %s", "it": "Lingua cambiata in %s", "de": "Sprache geändert zu %s", "zh": "语言已切换为 %s", "ja": "言語を %s に変更しました"},
		"options_volume":   {"es": "Volumen", "en": "Volume", "fr": "Volume", "it": "Volume", "de": "Lautstärke", "zh": "音量", "ja": "音量"},
		"options_sound":    {"es": "Sonido", "en": "Sound", "fr": "Son", "it": "Audio", "de": "Ton", "zh": "声音", "ja": "サウンド"},
		"options_on":       {"es": "Activado", "en": "On", "fr": "Activé", "it": "Attivo", "de": "An", "zh": "开", "ja": "オン"},
		"options_off":      {"es": "Desactivado", "en": "Off", "fr": "Désactivé", "it": "Disattivo", "de": "Aus", "zh": "关", "ja": "オフ"},
		"options_to_title": {"es": "🏠  Guardar y Salir al Menú", "en": "🏠  Save & Quit to Menu", "fr": "🏠  Sauvegarder et quitter vers le menu", "it": "🏠  Salva ed esci al menu", "de": "🏠  Speichern und zum Menü", "zh": "🏠  保存并返回菜单", "ja": "🏠  セーブしてメニューへ"},

		# ── Créditos ────────────────────────────────────────────────────────
		"credits_title":    {"es": "📜  Créditos", "en": "📜  Credits", "fr": "📜  Crédits", "it": "📜  Crediti", "de": "📜  Abspann", "zh": "📜  制作人员", "ja": "📜  クレジット"},
		"credits_made_by":  {"es": "Desarrollado por", "en": "Developed by", "fr": "Développé par", "it": "Sviluppato da", "de": "Entwickelt von", "zh": "开发者", "ja": "開発"},
		"credits_author":   {"es": "JoseMHR", "en": "JoseMHR", "fr": "JoseMHR", "it": "JoseMHR", "de": "JoseMHR", "zh": "JoseMHR", "ja": "JoseMHR"},
		"credits_engine":   {"es": "Hecho con Godot 4.7", "en": "Made with Godot 4.7", "fr": "Réalisé avec Godot 4.7", "it": "Realizzato con Godot 4.7", "de": "Erstellt mit Godot 4.7", "zh": "使用 Godot 4.7 制作", "ja": "Godot 4.7 で制作"},
		"credits_thanks":   {"es": "Un proyecto indie en construcción.\n¡Gracias por jugar!", "en": "An indie project in progress.\nThanks for playing!", "fr": "Un projet indé en cours.\nMerci d'avoir joué !", "it": "Un progetto indie in corso.\nGrazie per aver giocato!", "de": "Ein Indie-Projekt in Arbeit.\nDanke fürs Spielen!", "zh": "一个仍在开发中的独立项目。\n感谢游玩！", "ja": "制作中のインディープロジェクト。\n遊んでくれてありがとう！"},

		# ── Barra de pestañas (TabBar) ──────────────────────────────────────
		"tab_world":     {"es": "🗺️\nMundo", "en": "🗺️\nWorld", "fr": "🗺️\nMonde", "it": "🗺️\nMondo", "de": "🗺️\nWelt", "zh": "🗺️\n世界", "ja": "🗺️\nワールド"},
		"tab_character": {"es": "👤\nPersonaje", "en": "👤\nHero", "fr": "👤\nHéros", "it": "👤\nEroe", "de": "👤\nHeld", "zh": "👤\n角色", "ja": "👤\nキャラ"},
		"tab_bag":       {"es": "🎒\nBolsa", "en": "🎒\nBag", "fr": "🎒\nSac", "it": "🎒\nBorsa", "de": "🎒\nTasche", "zh": "🎒\n背包", "ja": "🎒\nバッグ"},
		"tab_info":      {"es": "ℹ️\nInfo", "en": "ℹ️\nInfo", "fr": "ℹ️\nInfo", "it": "ℹ️\nInfo", "de": "ℹ️\nInfo", "zh": "ℹ️\n信息", "ja": "ℹ️\n情報"},
		"tab_options":   {"es": "⚙️\nMenú", "en": "⚙️\nMenu", "fr": "⚙️\nMenu", "it": "⚙️\nMenu", "de": "⚙️\nMenü", "zh": "⚙️\n菜单", "ja": "⚙️\nメニュー"},

		# ── Cabecera de ubicación (dónde estás + volver al mundo) ────────────
		"loc_return_world": {"es": "🗺️  Volver al Mundo", "en": "🗺️  Back to World", "fr": "🗺️  Retour au monde", "it": "🗺️  Torna al mondo", "de": "🗺️  Zurück zur Welt", "zh": "🗺️  返回世界", "ja": "🗺️  ワールドへ戻る"},
		"loc_base":        {"es": "🏠  Tu Base", "en": "🏠  Your Base", "fr": "🏠  Ta base", "it": "🏠  La tua base", "de": "🏠  Deine Basis", "zh": "🏠  你的基地", "ja": "🏠  あなたの拠点"},
		"loc_character":   {"es": "👤  Personaje", "en": "👤  Hero", "fr": "👤  Héros", "it": "👤  Eroe", "de": "👤  Held", "zh": "👤  角色", "ja": "👤  キャラクター"},
		"loc_bag":         {"es": "🎒  Bolsa", "en": "🎒  Bag", "fr": "🎒  Sac", "it": "🎒  Borsa", "de": "🎒  Tasche", "zh": "🎒  背包", "ja": "🎒  バッグ"},
		"loc_city":        {"es": "🏰  Ciudad", "en": "🏰  City", "fr": "🏰  Cité", "it": "🏰  Città", "de": "🏰  Stadt", "zh": "🏰  城市", "ja": "🏰  街"},
		"loc_building":    {"es": "🚪  Edificio", "en": "🚪  Building", "fr": "🚪  Bâtiment", "it": "🚪  Edificio", "de": "🚪  Gebäude", "zh": "🚪  建筑", "ja": "🚪  建物"},
		"loc_dungeon":     {"es": "⚔️  Mazmorra", "en": "⚔️  Dungeon", "fr": "⚔️  Donjon", "it": "⚔️  Dungeon", "de": "⚔️  Verlies", "zh": "⚔️  地牢", "ja": "⚔️  ダンジョン"},
		"loc_gather":      {"es": "⛏️  Recolección", "en": "⛏️  Gathering", "fr": "⛏️  Récolte", "it": "⛏️  Raccolta", "de": "⛏️  Sammeln", "zh": "⛏️  采集", "ja": "⛏️  採取"},
		"loc_place":       {"es": "🚶  Lugar", "en": "🚶  Place", "fr": "🚶  Lieu", "it": "🚶  Luogo", "de": "🚶  Ort", "zh": "🚶  地点", "ja": "🚶  場所"},
		"loc_cook":        {"es": "🍳  Cocina", "en": "🍳  Kitchen", "fr": "🍳  Cuisine", "it": "🍳  Cucina", "de": "🍳  Küche", "zh": "🍳  厨房", "ja": "🍳  調理場"},
		"loc_training":    {"es": "🎯  Entrenamiento", "en": "🎯  Training", "fr": "🎯  Entraînement", "it": "🎯  Allenamento", "de": "🎯  Training", "zh": "🎯  训练", "ja": "🎯  トレーニング"},
		"loc_encargos":    {"es": "📋  Tablón de Encargos", "en": "📋  Job Board", "fr": "📋  Tableau des missions", "it": "📋  Bacheca incarichi", "de": "📋  Auftragstafel", "zh": "📋  委托板", "ja": "📋  依頼掲示板"},
		"loc_forge":       {"es": "🔨  Forja", "en": "🔨  Forge", "fr": "🔨  Forge", "it": "🔨  Fucina", "de": "🔨  Schmiede", "zh": "🔨  锻造", "ja": "🔨  鍛冶"},
		"loc_shop":        {"es": "🛒  Tienda", "en": "🛒  Shop", "fr": "🛒  Boutique", "it": "🛒  Negozio", "de": "🛒  Laden", "zh": "🛒  商店", "ja": "🛒  ショップ"},

		# ── HUD ─────────────────────────────────────────────────────────────
		"hud_level":  {"es": "NV %d", "en": "LV %d", "fr": "NV %d", "it": "LV %d", "de": "LV %d", "zh": "等级 %d", "ja": "LV %d"},

		# ── Mundo / viaje ───────────────────────────────────────────────────
		"world_enter_city":    {"es": "🏰  Entrar a la Ciudad", "en": "🏰  Enter the City", "fr": "🏰  Entrer dans la cité", "it": "🏰  Entra in città", "de": "🏰  Stadt betreten", "zh": "🏰  进入城市", "ja": "🏰  街に入る"},
		"world_enter_dungeon": {"es": "⚔️  Explorar Mazmorra", "en": "⚔️  Explore Dungeon", "fr": "⚔️  Explorer le donjon", "it": "⚔️  Esplora il dungeon", "de": "⚔️  Verlies erkunden", "zh": "⚔️  探索地牢", "ja": "⚔️  ダンジョンを探索"},
		"world_enter_gather":  {"es": "⛏️  Recolectar Aquí", "en": "⛏️  Gather Here", "fr": "⛏️  Récolter ici", "it": "⛏️  Raccogli qui", "de": "⛏️  Hier sammeln", "zh": "⛏️  在此采集", "ja": "⛏️  ここで採取"},
		"world_enter_place":   {"es": "🔍  Visitar Lugar", "en": "🔍  Visit Place", "fr": "🔍  Visiter le lieu", "it": "🔍  Visita il luogo", "de": "🔍  Ort besuchen", "zh": "🔍  参观地点", "ja": "🔍  場所を訪れる"},
		"world_enter_base":    {"es": "⛺  Entrar a la Base", "en": "⛺  Enter the Base", "fr": "⛺  Entrer dans la base", "it": "⛺  Entra nella base", "de": "⛺  Basis betreten", "zh": "⛺  进入基地", "ja": "⛺  拠点に入る"},
		"world_cross_bridge":  {"es": "🌉  Cruzar Puente", "en": "🌉  Cross Bridge", "fr": "🌉  Traverser le pont", "it": "🌉  Attraversa il ponte", "de": "🌉  Brücke überqueren", "zh": "🌉  过桥", "ja": "🌉  橋を渡る"},
		"world_use_banana":    {"es": "🍌  Usar Plátano Adormecedor", "en": "🍌  Use Soporific Banana", "fr": "🍌  Utiliser la banane soporifique", "it": "🍌  Usa la banana soporifera", "de": "🍌  Schlafbanane benutzen", "zh": "🍌  使用催眠香蕉", "ja": "🍌  眠りバナナを使う"},
		"world_bridge_locked": {"es": "🐒  Puente Bloqueado (Mono Guardián)", "en": "🐒  Bridge Blocked (Guardian Monkey)", "fr": "🐒  Pont bloqué (Singe gardien)", "it": "🐒  Ponte bloccato (Scimmia guardiana)", "de": "🐒  Brücke blockiert (Wächteraffe)", "zh": "🐒  桥被封锁（守卫猴）", "ja": "🐒  橋は封鎖中（守衛のサル）"},
		"world_travel_to":     {"es": "Viajar a", "en": "Travel to", "fr": "Voyager vers", "it": "Viaggia verso", "de": "Reisen nach", "zh": "前往", "ja": "目的地："},
		"boat_boarded":        {"es": "⛵ ¡Has abordado el barco!", "en": "⛵ You've boarded the boat!", "fr": "⛵ Tu es monté à bord du bateau !", "it": "⛵ Sei salito sulla barca!", "de": "⛵ Du bist an Bord gegangen!", "zh": "⛵ 你已登上船！", "ja": "⛵ 船に乗り込んだ！"},
		"boat_sailing":        {"es": "Navegando", "en": "Sailing", "fr": "Navigation", "it": "In navigazione", "de": "Segeln", "zh": "航行中", "ja": "航行中"},
		"boat_sailing_hint":   {"es": "El barco solo puede tocar costa o mar", "en": "The boat can only touch coast or open sea", "fr": "Le bateau ne peut toucher que la côte ou la mer", "it": "La barca può toccare solo costa o mare aperto", "de": "Das Boot kann nur Küste oder offenes Meer berühren", "zh": "船只能靠岸或入海", "ja": "船は海岸か外海にしか触れられない"},
		"boat_disembark":      {"es": "🏖️  Desembarcar", "en": "🏖️  Disembark", "fr": "🏖️  Débarquer", "it": "🏖️  Sbarca", "de": "🏖️  Von Bord gehen", "zh": "🏖️  上岸", "ja": "🏖️  上陸する"},
		"boat_no_landing":     {"es": "No hay tierra cerca para desembarcar.", "en": "No nearby land to disembark.", "fr": "Aucune terre proche pour débarquer.", "it": "Nessuna terra vicina per sbarcare.", "de": "Kein Land in der Nähe zum Anlegen.", "zh": "附近没有可供上岸的陆地。", "ja": "上陸できる陸地が近くにない。"},
		"boat_locked_hint":    {"es": "⚓  El barco está anclado. Aún no tienes permiso para zarpar.", "en": "⚓  The boat is anchored. You don't have permission to sail yet.", "fr": "⚓  Le bateau est ancré. Tu n'as pas encore l'autorisation d'appareiller.", "it": "⚓  La barca è ancorata. Non hai ancora il permesso di salpare.", "de": "⚓  Das Boot ankert. Du hast noch keine Erlaubnis auszulaufen.", "zh": "⚓  船已抛锚。你还没有出海的许可。", "ja": "⚓  船は錨を下ろしている。まだ出航の許可がない。"},
		"hazard_heat":         {"es": "☀️  Insolación", "en": "☀️  Heatstroke", "fr": "☀️  Insolation", "it": "☀️  Colpo di calore", "de": "☀️  Hitzschlag", "zh": "☀️  中暑", "ja": "☀️  熱射病"},
		"hazard_cold":         {"es": "❄️  Congelación", "en": "❄️  Freezing", "fr": "❄️  Gel", "it": "❄️  Congelamento", "de": "❄️  Erfrieren", "zh": "❄️  冻伤", "ja": "❄️  凍傷"},
		"world_traveling":     {"es": "Viajando…", "en": "Traveling…", "fr": "Voyage en cours…", "it": "In viaggio…", "de": "Unterwegs…", "zh": "旅行中…", "ja": "移動中…"},

		# ── Base ────────────────────────────────────────────────────────────
		"base_title":        {"es": "🏠  Tu Base", "en": "🏠  Your Base", "fr": "🏠  Ta base", "it": "🏠  La tua base", "de": "🏠  Deine Basis", "zh": "🏠  你的基地", "ja": "🏠  あなたの拠点"},
		"base_empty":        {"es": "Tu base está vacía.\nRecolecta recursos en el mundo para desbloquear construcciones.", "en": "Your base is empty.\nGather resources in the world to unlock buildings.", "fr": "Ta base est vide.\nRécolte des ressources dans le monde pour débloquer des bâtiments.", "it": "La tua base è vuota.\nRaccogli risorse nel mondo per sbloccare costruzioni.", "de": "Deine Basis ist leer.\nSammle Ressourcen in der Welt, um Gebäude freizuschalten.", "zh": "你的基地空空如也。\n在世界中采集资源以解锁建筑。", "ja": "拠点は空っぽだ。\n世界で資源を集めて建物を解放しよう。"},
		"base_buildings":    {"es": "Construcciones", "en": "Buildings", "fr": "Bâtiments", "it": "Costruzioni", "de": "Gebäude", "zh": "建筑", "ja": "建物"},
		"base_dummy":        {"es": "Muñeco de Entrenamiento", "en": "Training Dummy", "fr": "Mannequin d'entraînement", "it": "Manichino d'allenamento", "de": "Trainingspuppe", "zh": "训练假人", "ja": "訓練用人形"},
		"base_dummy_desc":   {"es": "Entrena para ganar experiencia (idle + clicker).", "en": "Train to gain experience (idle + clicker).", "fr": "Entraîne-toi pour gagner de l'expérience (idle + clicker).", "it": "Allenati per guadagnare esperienza (idle + clicker).", "de": "Trainiere, um Erfahrung zu sammeln (Idle + Clicker).", "zh": "训练以获得经验（放置 + 点击）。", "ja": "訓練して経験値を稼ぐ（放置＋クリッカー）。"},
		"base_campfire":     {"es": "Hoguera", "en": "Campfire", "fr": "Feu de camp", "it": "Falò", "de": "Lagerfeuer", "zh": "篝火", "ja": "焚き火"},
		"base_campfire_desc":{"es": "Regenera tu vida lentamente mientras estás en la base.", "en": "Slowly regenerates your health while at the base.", "fr": "Régénère lentement ta vie lorsque tu es à la base.", "it": "Rigenera lentamente la tua vita mentre sei alla base.", "de": "Regeneriert langsam deine Gesundheit, während du in der Basis bist.", "zh": "在基地时缓慢回复你的生命。", "ja": "拠点にいる間、体力をゆっくり回復する。"},
		"base_kitchen":      {"es": "Cocina", "en": "Kitchen", "fr": "Cuisine", "it": "Cucina", "de": "Küche", "zh": "厨房", "ja": "台所"},
		"base_kitchen_desc": {"es": "Cocina ingredientes para crear consumibles.", "en": "Cook ingredients into consumables.", "fr": "Cuisine des ingrédients pour créer des consommables.", "it": "Cucina ingredienti per creare consumabili.", "de": "Koche Zutaten zu Verbrauchsgegenständen.", "zh": "烹饪食材以制作消耗品。", "ja": "食材を調理して消耗品を作る。"},
		"base_build":        {"es": "Construir", "en": "Build", "fr": "Construire", "it": "Costruisci", "de": "Bauen", "zh": "建造", "ja": "建設"},
		"base_built":        {"es": "Construida", "en": "Built", "fr": "Construit", "it": "Costruito", "de": "Gebaut", "zh": "已建造", "ja": "建設済み"},
		"base_locked":       {"es": "🔒 Bloqueada", "en": "🔒 Locked", "fr": "🔒 Verrouillé", "it": "🔒 Bloccato", "de": "🔒 Gesperrt", "zh": "🔒 已锁定", "ja": "🔒 ロック中"},
		"base_unlock_hint":  {"es": "Recolecta %s para desbloquear", "en": "Gather %s to unlock", "fr": "Récolte %s pour débloquer", "it": "Raccogli %s per sbloccare", "de": "Sammle %s zum Freischalten", "zh": "采集 %s 以解锁", "ja": "%s を集めて解放"},
		"base_enter_cook":   {"es": "🍳  Cocinar", "en": "🍳  Cook", "fr": "🍳  Cuisiner", "it": "🍳  Cucina", "de": "🍳  Kochen", "zh": "🍳  烹饪", "ja": "🍳  調理する"},
		"base_enter_train":  {"es": "🎯  Entrenar", "en": "🎯  Train", "fr": "🎯  S'entraîner", "it": "🎯  Allenati", "de": "🎯  Trainieren", "zh": "🎯  训练", "ja": "🎯  訓練する"},
		"base_enter_board":  {"es": "📋  Ver Encargos", "en": "📋  View Jobs", "fr": "📋  Voir les missions", "it": "📋  Vedi incarichi", "de": "📋  Aufträge ansehen", "zh": "📋  查看委托", "ja": "📋  依頼を見る"},
		"base_enter_forge":  {"es": "🔨  Forjar", "en": "🔨  Forge", "fr": "🔨  Forger", "it": "🔨  Forgia", "de": "🔨  Schmieden", "zh": "🔨  锻造", "ja": "🔨  鍛造する"},
		"base_passive_on":   {"es": "Efecto pasivo activo", "en": "Passive effect active", "fr": "Effet passif actif", "it": "Effetto passivo attivo", "de": "Passiver Effekt aktiv", "zh": "被动效果已启用", "ja": "パッシブ効果発動中"},
		"base_board":        {"es": "Tablón de Encargos", "en": "Job Board", "fr": "Tableau des missions", "it": "Bacheca incarichi", "de": "Auftragstafel", "zh": "委托板", "ja": "依頼掲示板"},
		"base_board_desc":   {"es": "Acepta encargos repetibles para ganar oro y experiencia.", "en": "Take repeatable jobs to earn gold and experience.", "fr": "Accepte des missions répétables pour gagner or et expérience.", "it": "Accetta incarichi ripetibili per guadagnare oro ed esperienza.", "de": "Nimm wiederholbare Aufträge an, um Gold und Erfahrung zu verdienen.", "zh": "接受可重复的委托以赚取金币和经验。", "ja": "繰り返し可能な依頼を受けて金と経験値を稼ごう。"},
		"base_forge":        {"es": "Forja", "en": "Forge", "fr": "Forge", "it": "Fucina", "de": "Schmiede", "zh": "锻造", "ja": "鍛冶"},
		"base_forge_desc":   {"es": "Fabrica equipo y reforja la rareza del que ya tienes.", "en": "Craft gear and reforge the rarity of what you own.", "fr": "Fabrique de l'équipement et reforge la rareté de ce que tu possèdes.", "it": "Crea equipaggiamento e riforgia la rarità di ciò che possiedi.", "de": "Fertige Ausrüstung und schmiede die Seltenheit vorhandener Stücke neu.", "zh": "制作装备，并重铸你已有装备的稀有度。", "ja": "装備を作り、手持ちの装備のレア度を鍛え直す。"},

		# ── Personaje ───────────────────────────────────────────────────────
		"char_stats":    {"es": "Stats", "en": "Stats", "fr": "Stats", "it": "Statistiche", "de": "Werte", "zh": "属性", "ja": "ステータス"},
		"char_facets":   {"es": "Facetas", "en": "Facets", "fr": "Facettes", "it": "Sfaccettature", "de": "Facetten", "zh": "个性", "ja": "個性"},
		"char_equip":    {"es": "Equipo", "en": "Gear", "fr": "Équipement", "it": "Equipaggiamento", "de": "Ausrüstung", "zh": "装备", "ja": "装備"},
		"char_oficio":   {"es": "Oficios", "en": "Trades", "fr": "Métiers", "it": "Mestieri", "de": "Handwerke", "zh": "行业", "ja": "生業"},
		"char_professions": {"es": "Profesiones", "en": "Professions", "fr": "Professions", "it": "Professioni", "de": "Berufe", "zh": "职业", "ja": "職業"},
		"char_dungeon_skills": {"es": "Mazmorra", "en": "Dungeon", "fr": "Donjon", "it": "Dungeon", "de": "Verlies", "zh": "地牢", "ja": "ダンジョン"},
		"dungeon_skills_intro": {"es": "Poderes de EXPLORACIÓN permanentes, ligados a las profesiones. No confundir con las habilidades de combate por turnos.", "en": "Permanent EXPLORATION powers, tied to professions. Not to be confused with turn-based combat skills.", "fr": "Pouvoirs d'EXPLORATION permanents, liés aux professions. À ne pas confondre avec les compétences de combat au tour par tour.", "it": "Poteri di ESPLORAZIONE permanenti, legati alle professioni. Da non confondere con le abilità di combattimento a turni.", "de": "Permanente ERKUNDUNGS-Kräfte, an Berufe gebunden. Nicht mit rundenbasierten Kampffähigkeiten zu verwechseln.", "zh": "与职业绑定的永久探索能力。不要与回合制战斗技能混淆。", "ja": "職業に紐づく永続的な探索能力。ターン制の戦闘スキルと混同しないこと。"},
		"char_bestiary": {"es": "Bestiario", "en": "Bestiary", "fr": "Bestiaire", "it": "Bestiario", "de": "Bestiarium", "zh": "怪物图鉴", "ja": "モンスター図鑑"},
		"bestiary_intro": {"es": "Conocimiento de los enemigos que has enfrentado. Combate a las criaturas para descubrir sus debilidades y resistencias.", "en": "Knowledge of the enemies you have faced. Fight creatures to uncover their weaknesses and resistances.", "fr": "Connaissance des ennemis affrontés. Combats les créatures pour découvrir leurs faiblesses et résistances.", "it": "Conoscenza dei nemici affrontati. Combatti le creature per scoprirne debolezze e resistenze.", "de": "Wissen über die Feinde, denen du begegnet bist. Bekämpfe Kreaturen, um ihre Schwächen und Resistenzen zu entdecken.", "zh": "关于你遇到过的敌人的知识。与生物战斗以发现它们的弱点与抗性。", "ja": "対峙した敵に関する知識。生き物と戦って弱点と耐性を見抜こう。"},
		"bestiary_progress": {"es": "Descubiertos: %d / %d", "en": "Discovered: %d / %d", "fr": "Découverts : %d / %d", "it": "Scoperti: %d / %d", "de": "Entdeckt: %d / %d", "zh": "已发现：%d / %d", "ja": "発見済み：%d / %d"},
		"bestiary_kills": {"es": "Bajas: %d", "en": "Kills: %d", "fr": "Victimes : %d", "it": "Uccisioni: %d", "de": "Abschieße: %d", "zh": "击杀：%d", "ja": "撃破数：%d"},
		"bestiary_weak": {"es": "Débil a:", "en": "Weak to:", "fr": "Faible contre :", "it": "Debole a:", "de": "Schwach gegen:", "zh": "弱于：", "ja": "弱点："},
		"bestiary_resist": {"es": "Resiste:", "en": "Resists:", "fr": "Résiste à :", "it": "Resiste a:", "de": "Resistent gegen:", "zh": "抗性：", "ja": "耐性："},
		"bestiary_unknown_reaction": {"es": "Sin debilidades descubiertas.", "en": "No weaknesses discovered yet.", "fr": "Aucune faiblesse découverte.", "it": "Nessuna debolezza scoperta.", "de": "Noch keine Schwächen entdeckt.", "zh": "尚未发现弱点。", "ja": "弱点はまだ見つかっていない。"},
		"bestiary_empty": {"es": "Aún no has enfrentado a ningún enemigo.", "en": "You haven't faced any enemy yet.", "fr": "Tu n'as encore affronté aucun ennemi.", "it": "Non hai ancora affrontato alcun nemico.", "de": "Du hast noch keinen Feind bekämpft.", "zh": "你还没有遇到任何敌人。", "ja": "まだ一体も敵に遇っていない。"},
		"bestiary_unknown_name": {"es": "??? (sin descubrir)", "en": "??? (undiscovered)", "fr": "??? (non découvert)", "it": "??? (non scoperto)", "de": "??? (unentdeckt)", "zh": "???（未发现）", "ja": "???（未発見）"},
		"char_points":   {"es": "Puntos Disponibles: %d", "en": "Available Points: %d", "fr": "Points disponibles : %d", "it": "Punti disponibili: %d", "de": "Verfügbare Punkte: %d", "zh": "可用点数：%d", "ja": "利用可能ポイント：%d"},
		"char_exp":      {"es": "EXP: %d/%d", "en": "EXP: %d/%d", "fr": "EXP : %d/%d", "it": "EXP: %d/%d", "de": "EXP: %d/%d", "zh": "经验：%d/%d", "ja": "EXP：%d/%d"},
		"char_base_level":       {"es": "Nivel Base", "en": "Base Level", "fr": "Niveau de base", "it": "Livello base", "de": "Basisstufe", "zh": "基础等级", "ja": "ベースレベル"},
		"char_no_profession":    {"es": "Sin profesión activa", "en": "No active profession", "fr": "Aucune profession active", "it": "Nessuna professione attiva", "de": "Kein aktiver Beruf", "zh": "无激活的职业", "ja": "有効な職業なし"},
		"char_no_profession_hint": {"es": "Sin profesión activa.\nDesbloquea una clase en los templos del mapa.", "en": "No active profession.\nUnlock a class at the temples on the map.", "fr": "Aucune profession active.\nDébloque une classe dans les temples de la carte.", "it": "Nessuna professione attiva.\nSblocca una classe nei templi sulla mappa.", "de": "Kein aktiver Beruf.\nSchalte eine Klasse in den Tempeln der Karte frei.", "zh": "无激活的职业。\n在地图上的神殿解锁一个职业。", "ja": "有効な職業がない。\nマップの神殿でクラスを解放しよう。"},
		"char_professions_owned": {"es": "Profesiones Desbloqueadas", "en": "Unlocked Professions", "fr": "Professions débloquées", "it": "Professioni sbloccate", "de": "Freigeschaltete Berufe", "zh": "已解锁职业", "ja": "解放済み職業"},
		"char_professions_status": {"es": "Estado de profesiones", "en": "Profession status", "fr": "État des professions", "it": "Stato professioni", "de": "Berufsstatus", "zh": "职业状态", "ja": "職業の状態"},
		"char_exploration_skills": {"es": "Habilidades de exploración", "en": "Exploration skills", "fr": "Compétences d'exploration", "it": "Abilità di esplorazione", "de": "Erkundungsfähigkeiten", "zh": "探索技能", "ja": "探索スキル"},
		"char_no_unlocked_profs": {"es": "Aún no has desbloqueado ninguna profesión.", "en": "You haven't unlocked any profession yet.", "fr": "Tu n'as encore débloqué aucune profession.", "it": "Non hai ancora sbloccato alcuna professione.", "de": "Du hast noch keinen Beruf freigeschaltet.", "zh": "你还没有解锁任何职业。", "ja": "まだどの職業も解放していない。"},
		"char_prof_active":      {"es": "Activa", "en": "Active", "fr": "Active", "it": "Attiva", "de": "Aktiv", "zh": "激活", "ja": "アクティブ"},
		"char_prof_inactive":    {"es": "Desbloqueada", "en": "Unlocked", "fr": "Débloquée", "it": "Sbloccata", "de": "Freigeschaltet", "zh": "已解锁", "ja": "解放済み"},
		"char_prof_locked":      {"es": "Bloqueada", "en": "Locked", "fr": "Verrouillée", "it": "Bloccata", "de": "Gesperrt", "zh": "已锁定", "ja": "ロック中"},
		"char_prof_switch":      {"es": "Activar", "en": "Activate", "fr": "Activer", "it": "Attiva", "de": "Aktivieren", "zh": "激活", "ja": "有効化"},
		"char_techniques":       {"es": "Técnicas", "en": "Techniques", "fr": "Techniques", "it": "Tecniche", "de": "Techniken", "zh": "技能", "ja": "技"},
		"char_oficios_title":    {"es": "Oficios de Recolección", "en": "Gathering Trades", "fr": "Métiers de récolte", "it": "Mestieri di raccolta", "de": "Sammelhandwerke", "zh": "采集行业", "ja": "採取の生業"},
		"equip_choose_slot":     {"es": "Selecciona una ranura para ver alternativas", "en": "Select a slot to see alternatives", "fr": "Sélectionne un emplacement pour voir les alternatives", "it": "Seleziona uno slot per vedere le alternative", "de": "Wähle einen Slot, um Alternativen zu sehen", "zh": "选择一个栏位以查看替代选项", "ja": "スロットを選んで代替を見る"},
		"equip_available":       {"es": "Alternativas para %s", "en": "Alternatives for %s", "fr": "Alternatives pour %s", "it": "Alternative per %s", "de": "Alternativen für %s", "zh": "%s 的替代选项", "ja": "%s の代替"},
		"equip_current":         {"es": "Equipado", "en": "Equipped", "fr": "Équipé", "it": "Equipaggiato", "de": "Ausgerüstet", "zh": "已装备", "ja": "装備中"},
		"equip_do":              {"es": "Equipar", "en": "Equip", "fr": "Équiper", "it": "Equipaggia", "de": "Ausrüsten", "zh": "装备", "ja": "装備する"},
		"equip_no_change":       {"es": "Sin cambios de estadísticas", "en": "No stat changes", "fr": "Aucun changement de stats", "it": "Nessuna modifica alle statistiche", "de": "Keine Wertänderungen", "zh": "属性无变化", "ja": "ステータス変化なし"},
		"delta_pdmg":            {"es": "DAÑO F", "en": "P.DMG", "fr": "DÉG.P", "it": "DAN.F", "de": "P.SCH", "zh": "物伤", "ja": "物ダメ"},
		"delta_mdmg":            {"es": "DAÑO M", "en": "M.DMG", "fr": "DÉG.M", "it": "DAN.M", "de": "M.SCH", "zh": "魔伤", "ja": "魔ダメ"},
		"delta_rdmg":            {"es": "DAÑO D", "en": "R.DMG", "fr": "DÉG.D", "it": "DAN.D", "de": "F.SCH", "zh": "远伤", "ja": "遠ダメ"},
		"delta_pdef":            {"es": "DEF.F", "en": "P.DEF", "fr": "DÉF.P", "it": "DIF.F", "de": "P.VER", "zh": "物防", "ja": "物防"},
		"delta_mdef":            {"es": "DEF.M", "en": "M.DEF", "fr": "DÉF.M", "it": "DIF.M", "de": "M.VER", "zh": "魔防", "ja": "魔防"},
		"stat_str": {"es": "STR", "en": "STR"},
		"stat_agi": {"es": "AGI", "en": "AGI"},
		"stat_vit": {"es": "VIT", "en": "VIT"},
		"stat_int": {"es": "INT", "en": "INT"},
		"stat_dex": {"es": "DEX", "en": "DEX"},
		"stat_luk": {"es": "LUK", "en": "LUK"},
		"derived_hp":   {"es": "❤️  HP Máximo", "en": "❤️  Max HP", "fr": "❤️  PV max", "it": "❤️  HP max", "de": "❤️  Max. LP", "zh": "❤️  最大生命", "ja": "❤️  最大HP"},
		"derived_mp":   {"es": "💙  MP Máximo", "en": "💙  Max MP", "fr": "💙  PM max", "it": "💙  MP max", "de": "💙  Max. MP", "zh": "💙  最大魔法", "ja": "💙  最大MP"},
		"derived_phys": {"es": "🗡️  Daño Físico", "en": "🗡️  Physical Dmg", "fr": "🗡️  Dégâts physiques", "it": "🗡️  Danno fisico", "de": "🗡️  Physischer Schaden", "zh": "🗡️  物理伤害", "ja": "🗡️  物理ダメージ"},
		"derived_mag":  {"es": "🔮  Daño Mágico", "en": "🔮  Magic Dmg", "fr": "🔮  Dégâts magiques", "it": "🔮  Danno magico", "de": "🔮  Magischer Schaden", "zh": "🔮  魔法伤害", "ja": "🔮  魔法ダメージ"},
		"derived_rng":  {"es": "🏹  Daño Distancia", "en": "🏹  Ranged Dmg", "fr": "🏹  Dégâts à distance", "it": "🏹  Danno a distanza", "de": "🏹  Fernkampfschaden", "zh": "🏹  远程伤害", "ja": "🏹  遠距離ダメージ"},
		"derived_spd":  {"es": "🏃  Velocidad", "en": "🏃  Speed", "fr": "🏃  Vitesse", "it": "🏃  Velocità", "de": "🏃  Tempo", "zh": "🏃  速度", "ja": "🏃  速さ"},
		"derived_pdef": {"es": "🛡️  Defensa Física", "en": "🛡️  Phys. Defense", "fr": "🛡️  Défense physique", "it": "🛡️  Difesa fisica", "de": "🛡️  Physische Verteidigung", "zh": "🛡️  物理防御", "ja": "🛡️  物理防御"},
		"derived_mdef": {"es": "✨  Defensa Mágica", "en": "✨  Magic Defense", "fr": "✨  Défense magique", "it": "✨  Difesa magica", "de": "✨  Magische Verteidigung", "zh": "✨  魔法防御", "ja": "✨  魔法防御"},
		"derived_dodge":{"es": "💨  Esquiva", "en": "💨  Dodge", "fr": "💨  Esquive", "it": "💨  Schivata", "de": "💨  Ausweichen", "zh": "💨  闪避", "ja": "💨  回避"},
		"derived_crit": {"es": "💥  Crítico", "en": "💥  Crit", "fr": "💥  Critique", "it": "💥  Critico", "de": "💥  Krit", "zh": "💥  暴击", "ja": "💥  クリティカル"},
		"derived_acc":  {"es": "🎯  Puntería", "en": "🎯  Accuracy", "fr": "🎯  Précision", "it": "🎯  Precisione", "de": "🎯  Genauigkeit", "zh": "🎯  命中", "ja": "🎯  命中"},
		"derived_hit":  {"es": "🎯  Puntería", "en": "🎯  Accuracy", "fr": "🎯  Précision", "it": "🎯  Precisione", "de": "🎯  Genauigkeit", "zh": "🎯  命中", "ja": "🎯  命中"},
		"derived_carry":{"es": "🎒  Carga Máx.", "en": "🎒  Max Load", "fr": "🎒  Charge max", "it": "🎒  Carico max", "de": "🎒  Max. Traglast", "zh": "🎒  最大负重", "ja": "🎒  最大積載"},
		"derived_cap":  {"es": "🎒  Carga Máx.", "en": "🎒  Max Load", "fr": "🎒  Charge max", "it": "🎒  Carico max", "de": "🎒  Max. Traglast", "zh": "🎒  最大负重", "ja": "🎒  最大積載"},
		"stats_core_title":    {"es": "Características", "en": "Attributes", "fr": "Attributs", "it": "Attributi", "de": "Attribute", "zh": "属性", "ja": "能力値"},
		"stats_derived_title": {"es": "Estadísticas de Combate", "en": "Combat Stats", "fr": "Stats de combat", "it": "Statistiche di combattimento", "de": "Kampfwerte", "zh": "战斗属性", "ja": "戦闘ステータス"},
		"facet_valor":        {"es": "Valor", "en": "Courage", "fr": "Courage", "it": "Coraggio", "de": "Mut", "zh": "勇气", "ja": "勇気"},
		"facet_bondad":       {"es": "Bondad", "en": "Goodness", "fr": "Bonté", "it": "Bontà", "de": "Güte", "zh": "善良", "ja": "善良さ"},
		"facet_aspecto":      {"es": "Aspecto", "en": "Appearance", "fr": "Apparence", "it": "Aspetto", "de": "Erscheinung", "zh": "外貌", "ja": "見た目"},
		"facet_inteligencia": {"es": "Inteligencia", "en": "Intelligence", "fr": "Intelligence", "it": "Intelligenza", "de": "Intelligenz", "zh": "智力", "ja": "知性"},
		"facet_cordura":      {"es": "Cordura", "en": "Sanity", "fr": "Santé mentale", "it": "Sanità mentale", "de": "Verstand", "zh": "理智", "ja": "正気"},
		"vn_info_title":      {"es": "Información de Diálogo", "en": "Dialogue Info", "fr": "Infos de dialogue", "it": "Info dialogo", "de": "Dialoginfo", "zh": "对话信息", "ja": "会話情報"},
		"vn_affinity_label":  {"es": "Relación", "en": "Relationship", "fr": "Relation", "it": "Relazione", "de": "Beziehung", "zh": "关系", "ja": "関係"},
		"vn_facets_label":    {"es": "Facetas del Protagonista", "en": "Hero Facets", "fr": "Facettes du héros", "it": "Sfaccettature dell'eroe", "de": "Heldenfacetten", "zh": "主角个性", "ja": "主人公の個性"},
		"vn_requires_facet":  {"es": "Requiere %s %d", "en": "Requires %s %d", "fr": "Requiert %s %d", "it": "Richiede %s %d", "de": "Erfordert %s %d", "zh": "需要 %s %d", "ja": "%s %d が必要"},
		"equip_helmet":    {"es": "Casco", "en": "Helmet", "fr": "Casque", "it": "Elmo", "de": "Helm", "zh": "头盔", "ja": "兜"},
		"equip_weapon":    {"es": "Arma", "en": "Weapon", "fr": "Arme", "it": "Arma", "de": "Waffe", "zh": "武器", "ja": "武器"},
		"equip_shield":    {"es": "Arma Secundaria", "en": "Off-hand", "fr": "Main secondaire", "it": "Mano secondaria", "de": "Nebenhand", "zh": "副手", "ja": "オフハンド"},
		"equip_armor":     {"es": "Armadura", "en": "Armor", "fr": "Armure", "it": "Armatura", "de": "Rüstung", "zh": "护甲", "ja": "防具"},
		"equip_shoes":     {"es": "Zapatos", "en": "Boots", "fr": "Bottes", "it": "Stivali", "de": "Stiefel", "zh": "鞋子", "ja": "靴"},
		"equip_accessory": {"es": "Accesorio", "en": "Accessory", "fr": "Accessoire", "it": "Accessorio", "de": "Zubehör", "zh": "饰品", "ja": "アクセサリー"},
		"equip_unequip":   {"es": "❌  Desequipar (%s)", "en": "❌  Unequip (%s)", "fr": "❌  Retirer (%s)", "it": "❌  Rimuovi (%s)", "de": "❌  Ablegen (%s)", "zh": "❌  卸下 (%s)", "ja": "❌  外す (%s)"},
		"equip_none_slot": {"es": "No tienes equipo para este slot en la bolsa.", "en": "You have no gear for this slot in your bag.", "fr": "Tu n'as aucun équipement pour cet emplacement dans ton sac.", "it": "Non hai equipaggiamento per questo slot nella borsa.", "de": "Du hast keine Ausrüstung für diesen Slot in der Tasche.", "zh": "背包里没有适合这个栏位的装备。", "ja": "バッグにこのスロット用の装備がない。"},
		"skill_lenador":    {"es": "Leñador", "en": "Lumberjack", "fr": "Bûcheron", "it": "Boscaiolo", "de": "Holzfäller", "zh": "伐木工", "ja": "木こり"},
		"skill_minero":     {"es": "Minero", "en": "Miner", "fr": "Mineur", "it": "Minatore", "de": "Bergmann", "zh": "矿工", "ja": "採掘"},
		"skill_pesca":      {"es": "Pesca", "en": "Fishing", "fr": "Pêche", "it": "Pesca", "de": "Angeln", "zh": "钓鱼", "ja": "釣り"},
		"skill_agricultor": {"es": "Agricultor", "en": "Farmer", "fr": "Agriculteur", "it": "Agricoltore", "de": "Bauer", "zh": "农夫", "ja": "農夫"},
		"skill_ganadero":   {"es": "Ganadero", "en": "Rancher", "fr": "Éleveur", "it": "Allevatore", "de": "Viehzüchter", "zh": "牧场主", "ja": "牧畜家"},
		"skill_cazador":    {"es": "Cazador", "en": "Hunter", "fr": "Chasseur", "it": "Cacciatore", "de": "Jäger", "zh": "猎人", "ja": "狩人"},
		"skill_cocinero":   {"es": "Cocinero", "en": "Chef", "fr": "Cuisinier", "it": "Cuoco", "de": "Koch", "zh": "厨师", "ja": "料理人"},
		"skill_level":   {"es": "Nivel %d  (%d/%d XP)", "en": "Level %d  (%d/%d XP)", "fr": "Niveau %d  (%d/%d XP)", "it": "Livello %d  (%d/%d XP)", "de": "Stufe %d  (%d/%d XP)", "zh": "等级 %d  (%d/%d XP)", "ja": "レベル %d  (%d/%d XP)"},
		"class_mago":     {"es": "Mago", "en": "Mage", "fr": "Mage", "it": "Mago", "de": "Magier", "zh": "法师", "ja": "魔法使い"},
		"class_guerrero": {"es": "Guerrero", "en": "Warrior", "fr": "Guerrier", "it": "Guerriero", "de": "Krieger", "zh": "战士", "ja": "戦士"},
		"class_arquera":  {"es": "Arquero", "en": "Archer", "fr": "Archer", "it": "Arciere", "de": "Bogenschütze", "zh": "弓箭手", "ja": "弓使い"},
		"class_arquero":  {"es": "Arquero", "en": "Archer", "fr": "Archer", "it": "Arciere", "de": "Bogenschütze", "zh": "弓箭手", "ja": "弓使い"},
		"class_tiempo":   {"es": "Tiempo", "en": "Time Mage", "fr": "Mage du temps", "it": "Mago del tempo", "de": "Zeitmagier", "zh": "时间法师", "ja": "時間魔法士"},
		"class_psiquica": {"es": "Psíquico", "en": "Psychic", "fr": "Psychiste", "it": "Psichico", "de": "Psioniker", "zh": "灵能者", "ja": "サイキック"},
		"class_psiquico": {"es": "Psíquico", "en": "Psychic", "fr": "Psychiste", "it": "Psichico", "de": "Psioniker", "zh": "灵能者", "ja": "サイキック"},
		"class_elementalista": {"es": "Elementalista", "en": "Elementalist", "fr": "Élémentaliste", "it": "Elementalista", "de": "Elementarmagier", "zh": "元素师", "ja": "エレメンタリスト"},
		"class_sacerdote": {"es": "Sacerdote", "en": "Priest", "fr": "Prêtre", "it": "Sacerdote", "de": "Priester", "zh": "祭司", "ja": "司祭"},
		"class_curandera": {"es": "Sacerdote", "en": "Priest", "fr": "Prêtre", "it": "Sacerdote", "de": "Priester", "zh": "祭司", "ja": "司祭"},
		"class_ninguna":  {"es": "Ninguna", "en": "None", "fr": "Aucune", "it": "Nessuna", "de": "Keine", "zh": "无", "ja": "なし"},
		"class_don_nadie": {"es": "Don Nadie", "en": "Nobody", "fr": "Monsieur Personne", "it": "Signor Nessuno", "de": "Niemand", "zh": "无名小卒", "ja": "どこの馬の骨"},

		# ── Bolsa ───────────────────────────────────────────────────────────
		"bag_title":       {"es": "🎒  Bolsa", "en": "🎒  Bag", "fr": "🎒  Sac", "it": "🎒  Borsa", "de": "🎒  Tasche", "zh": "🎒  背包", "ja": "🎒  バッグ"},
		"bag_important":   {"es": "Importante", "en": "Important", "fr": "Important", "it": "Importante", "de": "Wichtig", "zh": "重要", "ja": "重要"},
		"bag_consumable":  {"es": "Consumibles", "en": "Consumables", "fr": "Consommables", "it": "Consumabili", "de": "Verbrauchbar", "zh": "消耗品", "ja": "消耗品"},
		"bag_equipment":   {"es": "Equipo", "en": "Gear", "fr": "Équipement", "it": "Equipaggiamento", "de": "Ausrüstung", "zh": "装备", "ja": "装備"},
		"bag_material":    {"es": "Materiales", "en": "Materials", "fr": "Matériaux", "it": "Materiali", "de": "Materialien", "zh": "材料", "ja": "素材"},
		"bag_empty":       {"es": "Esta sección está vacía.", "en": "This section is empty.", "fr": "Cette section est vide.", "it": "Questa sezione è vuota.", "de": "Dieser Bereich ist leer.", "zh": "此分类为空。", "ja": "このセクションは空です。"},
		"bag_use":         {"es": "Usar", "en": "Use", "fr": "Utiliser", "it": "Usa", "de": "Benutzen", "zh": "使用", "ja": "使う"},

		# ── Recolección (Farmeo) ────────────────────────────────────────────
		"gather_found_lenador": {"es": "¡Has encontrado un lugar para talar madera!", "en": "You found a place to chop wood!", "fr": "Tu as trouvé un endroit pour couper du bois !", "it": "Hai trovato un posto dove tagliare legna!", "de": "Du hast einen Platz zum Holzfällen gefunden!", "zh": "你找到了一处可以砍伐木材的地方！", "ja": "木を切る場所を見つけた！"},
		"gather_found_minero":  {"es": "¡Has encontrado una veta de mineral!", "en": "You found an ore vein!", "fr": "Tu as trouvé un filon de minerai !", "it": "Hai trovato una vena di minerale!", "de": "Du hast eine Erzader gefunden!", "zh": "你找到了一条矿脉！", "ja": "鉱脈を見つけた！"},
		"gather_found_pesca":   {"es": "¡Has encontrado un buen sitio para pescar!", "en": "You found a good fishing spot!", "fr": "Tu as trouvé un bon coin de pêche !", "it": "Hai trovato un buon posto per pescare!", "de": "Du hast einen guten Angelplatz gefunden!", "zh": "你找到了一个好钓点！", "ja": "よい釣り場を見つけた！"},
		"gather_found_arboles": {"es": "¡Unos árboles marchitos! Dan poca madera, pero sirve.", "en": "Some withered trees! Little wood, but it'll do.", "fr": "Des arbres flétris ! Peu de bois, mais ça ira.", "it": "Alcuni alberi avvizziti! Poco legno, ma va bene.", "de": "Ein paar verdorrte Bäume! Wenig Holz, aber es reicht.", "zh": "一些枯萎的树！木材不多，但够用。", "ja": "枯れかけた木々だ！木材は少ないが、まあ使える。"},
		"gather_found_oro":     {"es": "¡Una veta dorada! Puedes extraer mineral de oro.", "en": "A golden vein! You can mine gold ore.", "fr": "Un filon doré ! Tu peux extraire du minerai d'or.", "it": "Una vena dorata! Puoi estrarre minerale d'oro.", "de": "Eine goldene Ader! Du kannst Golderz abbauen.", "zh": "一条金矿脉！你可以开采金矿石。", "ja": "金の鉱脈だ！金鉱石を採掘できる。"},
		"gather_found_ganado":  {"es": "¡Ganado pastando! Puedes ordeñarlo para obtener leche fresca.", "en": "Grazing livestock! You can milk it for fresh milk.", "fr": "Du bétail qui paît ! Tu peux le traire pour du lait frais.", "it": "Bestiame al pascolo! Puoi mungerlo per latte fresco.", "de": "Weidendes Vieh! Du kannst es für frische Milch melken.", "zh": "正在吃草的牲畜！你可以挤出新鲜牛奶。", "ja": "放牧中の家畜だ！乳を搾って新鮮なミルクが取れる。"},
		"gather_found_cazador": {"es": "¡Una granja de cerdos! Puedes obtener carne fresca.", "en": "A pig farm! You can get fresh meat.", "fr": "Une ferme de cochons ! Tu peux obtenir de la viande fraîche.", "it": "Un allevamento di maiali! Puoi ottenere carne fresca.", "de": "Eine Schweinefarm! Du kannst frisches Fleisch bekommen.", "zh": "一座猪场！你可以获得新鲜的肉。", "ja": "豚の農場だ！新鮮な肉が手に入る。"},
		"gather_tap":           {"es": "Toca la pantalla para recolectar", "en": "Tap the screen to gather", "fr": "Touche l'écran pour récolter", "it": "Tocca lo schermo per raccogliere", "de": "Tippe auf den Bildschirm zum Sammeln", "zh": "点击屏幕进行采集", "ja": "画面をタップして採取"},
		"gather_got":           {"es": "+1 %s", "en": "+1 %s", "fr": "+1 %s", "it": "+1 %s", "de": "+1 %s", "zh": "+1 %s", "ja": "+1 %s"},
		"gather_skill_up":      {"es": "¡%s sube a nivel %d!", "en": "%s reaches level %d!", "fr": "%s passe au niveau %d !", "it": "%s sale al livello %d!", "de": "%s erreicht Stufe %d!", "zh": "%s 升到了 %d 级！", "ja": "%s がレベル %d に上がった！"},
		"gather_leave":         {"es": "← Volver al Mapa", "en": "← Back to Map", "fr": "← Retour à la carte", "it": "← Torna alla mappa", "de": "← Zurück zur Karte", "zh": "← 返回地图", "ja": "← マップへ戻る"},
		"gather_total":         {"es": "Recolectado: %d", "en": "Gathered: %d", "fr": "Récolté : %d", "it": "Raccolto: %d", "de": "Gesammelt: %d", "zh": "已采集：%d", "ja": "採取数：%d"},
		"gather_node":          {"es": "Reserva del nodo: %d/%d", "en": "Node reserve: %d/%d", "fr": "Réserve du nœud : %d/%d", "it": "Riserva del nodo: %d/%d", "de": "Knotenvorrat: %d/%d", "zh": "节点储量：%d/%d", "ja": "ノード残量：%d/%d"},
		"gather_depleted":      {"es": "Nodo agotado", "en": "Node depleted", "fr": "Nœud épuisé", "it": "Nodo esaurito", "de": "Knoten erschöpft", "zh": "节点已枯竭", "ja": "ノード枯渇"},
		"gather_depleted_hint": {"es": "Se regenera con el tiempo. Vuelve más tarde.", "en": "It regenerates over time. Come back later.", "fr": "Il se régénère avec le temps. Reviens plus tard.", "it": "Si rigenera col tempo. Torna più tardi.", "de": "Er regeneriert sich mit der Zeit. Komm später wieder.", "zh": "它会随时间恢复。稍后再来。", "ja": "時間とともに回復する。後でまた来よう。"},
		"res_wood":             {"es": "Madera", "en": "Wood", "fr": "Bois", "it": "Legno", "de": "Holz", "zh": "木材", "ja": "木材"},
		"res_stone":            {"es": "Piedra", "en": "Stone", "fr": "Pierre", "it": "Pietra", "de": "Stein", "zh": "石头", "ja": "石"},
		"res_fish":             {"es": "Pescado", "en": "Fish", "fr": "Poisson", "it": "Pesce", "de": "Fisch", "zh": "鱼", "ja": "魚"},
		"res_wheat":            {"es": "Trigo", "en": "Wheat", "fr": "Blé", "it": "Grano", "de": "Weizen", "zh": "小麦", "ja": "小麦"},
		"res_milk":             {"es": "Leche", "en": "Milk", "fr": "Lait", "it": "Latte", "de": "Milch", "zh": "牛奶", "ja": "ミルク"},
		"res_carne":            {"es": "Carne", "en": "Meat", "fr": "Viande", "it": "Carne", "de": "Fleisch", "zh": "肉", "ja": "肉"},
		"res_gold_ore":         {"es": "Mineral de Oro", "en": "Gold Ore", "fr": "Minerai d'or", "it": "Minerale d'oro", "de": "Golderz", "zh": "金矿石", "ja": "金鉱石"},
		"gather_owned":         {"es": "En la bolsa: %d", "en": "In bag: %d", "fr": "Dans le sac : %d", "it": "Nella borsa: %d", "de": "In der Tasche: %d", "zh": "背包中：%d", "ja": "バッグ内：%d"},

		# ── Lugar ───────────────────────────────────────────────────────────
		"place_leave":   {"es": "← Volver al Mapa", "en": "← Back to Map", "fr": "← Retour à la carte", "it": "← Torna alla mappa", "de": "← Zurück zur Karte", "zh": "← 返回地图", "ja": "← マップへ戻る"},
		"place_continue":{"es": "Continuar", "en": "Continue", "fr": "Continuer", "it": "Continua", "de": "Weiter", "zh": "继续", "ja": "つづける"},

		# ── Ciudad / edificios ──────────────────────────────────────────────
		"city_exit":      {"es": "Salir al Mapa", "en": "Exit to Map", "fr": "Sortir vers la carte", "it": "Esci sulla mappa", "de": "Zur Karte verlassen", "zh": "退出到地图", "ja": "マップへ出る"},
		"building_back":  {"es": "← Regresar", "en": "← Back", "fr": "← Retour", "it": "← Indietro", "de": "← Zurück", "zh": "← 返回", "ja": "← もどる"},

		# ── Mazmorra ────────────────────────────────────────────────────────
		"dungeon_leave":   {"es": "Huir", "en": "Flee", "fr": "Fuir", "it": "Fuggi", "de": "Fliehen", "zh": "逃跑", "ja": "逃げる"},
		"dungeon_boss":    {"es": "⚠️  ¡El Jefe Final ha aparecido!", "en": "⚠️  The Final Boss has appeared!", "fr": "⚠️  Le boss final est apparu !", "it": "⚠️  È apparso il boss finale!", "de": "⚠️  Der Endboss ist erschienen!", "zh": "⚠️  最终boss出现了！", "ja": "⚠️  ラスボスが現れた！"},
		"dungeon_ambush":  {"es": "💀  ¡Un monstruo te ha interceptado!", "en": "💀  A monster intercepts you!", "fr": "💀  Un monstre t'a intercepté !", "it": "💀  Un mostro ti ha intercettato!", "de": "💀  Ein Monster fängt dich ab!", "zh": "💀  一只怪物拦住了你！", "ja": "💀  モンスターに待ち伏せされた！"},

		# ── Combate ─────────────────────────────────────────────────────────
		"combat_turn":     {"es": "Turno %d", "en": "Turn %d", "fr": "Tour %d", "it": "Turno %d", "de": "Runde %d", "zh": "回合 %d", "ja": "ターン %d"},
		"combat_flee":     {"es": "Huir", "en": "Flee", "fr": "Fuir", "it": "Fuggi", "de": "Fliehen", "zh": "逃跑", "ja": "逃げる"},
		"combat_victory":  {"es": "🏆  ¡VICTORIA!", "en": "🏆  VICTORY!", "fr": "🏆  VICTOIRE !", "it": "🏆  VITTORIA!", "de": "🏆  SIEG!", "zh": "🏆  胜利！", "ja": "🏆  勝利！"},
		"combat_defeat":   {"es": "💀  DERROTA", "en": "💀  DEFEAT", "fr": "💀  DÉFAITE", "it": "💀  SCONFITTA", "de": "💀  NIEDERLAGE", "zh": "💀  战败", "ja": "💀  敗北"},
		"combat_continue": {"es": "Continuar", "en": "Continue", "fr": "Continuer", "it": "Continua", "de": "Weiter", "zh": "继续", "ja": "つづける"},
		"combat_reward":   {"es": "+%d XP     +%d 🪙 oro", "en": "+%d XP     +%d 🪙 gold", "fr": "+%d XP     +%d 🪙 or", "it": "+%d XP     +%d 🪙 oro", "de": "+%d XP     +%d 🪙 Gold", "zh": "+%d 经验     +%d 🪙 金币", "ja": "+%d EXP     +%d 🪙 ゴールド"},
		"combat_fallen":   {"es": "El héroe ha caído en combate…", "en": "The hero has fallen in battle…", "fr": "Le héros est tombé au combat…", "it": "L'eroe è caduto in battaglia…", "de": "Der Held ist im Kampf gefallen…", "zh": "英雄在战斗中倒下了……", "ja": "英雄は戦いで倒れた……"},
		"combat_miss":     {"es": "¡FALLO!", "en": "MISS!", "fr": "RATÉ !", "it": "MANCATO!", "de": "DANEBEN!", "zh": "未命中！", "ja": "ミス！"},
		"combat_dodge":    {"es": "¡ESQUIVA!", "en": "DODGE!", "fr": "ESQUIVE !", "it": "SCHIVATA!", "de": "AUSWEICHEN!", "zh": "闪避！", "ja": "回避！"},
		"combat_crit":     {"es": "¡CRÍTICO!", "en": "CRIT!", "fr": "CRITIQUE !", "it": "CRITICO!", "de": "KRITISCH!", "zh": "暴击！", "ja": "クリティカル！"},

		# ── Cocina ──────────────────────────────────────────────────────────
		"cook_title":   {"es": "🍳  Cocina", "en": "🍳  Kitchen", "fr": "🍳  Cuisine", "it": "🍳  Cucina", "de": "🍳  Küche", "zh": "🍳  厨房", "ja": "🍳  台所"},
		"cook_empty":   {"es": "No tienes ingredientes cocinables.\n¡Pesca para conseguir pescado!", "en": "You have no cookable ingredients.\nGo fishing to get fish!", "fr": "Tu n'as aucun ingrédient cuisinable.\nVa pêcher pour obtenir du poisson !", "it": "Non hai ingredienti cucinabili.\nVai a pescare per ottenere pesce!", "de": "Du hast keine kochbaren Zutaten.\nGeh angeln, um Fisch zu bekommen!", "zh": "你没有可烹饪的食材。\n去钓鱼来获得鱼吧！", "ja": "調理できる食材がない。\n釣りをして魚を手に入れよう！"},
		"cook_hint":    {"es": "Toca un ingrediente para cocinarlo", "en": "Tap an ingredient to cook it", "fr": "Touche un ingrédient pour le cuisiner", "it": "Tocca un ingrediente per cucinarlo", "de": "Tippe auf eine Zutat, um sie zu kochen", "zh": "点击食材将其烹饪", "ja": "食材をタップして調理"},
		"cook_do":      {"es": "Cocinar", "en": "Cook", "fr": "Cuisiner", "it": "Cucina", "de": "Kochen", "zh": "烹饪", "ja": "調理する"},
		"cook_makes":   {"es": "→ %s  (❤️+%d  💧+%d)", "en": "→ %s  (❤️+%d  💧+%d)", "fr": "→ %s  (❤️+%d  💧+%d)", "it": "→ %s  (❤️+%d  💧+%d)", "de": "→ %s  (❤️+%d  💧+%d)", "zh": "→ %s  (❤️+%d  💧+%d)", "ja": "→ %s  (❤️+%d  💧+%d)"},
		"cook_result":  {"es": "¡Has cocinado %s!", "en": "You cooked %s!", "fr": "Tu as cuisiné %s !", "it": "Hai cucinato %s!", "de": "Du hast %s gekocht!", "zh": "你烹饪了 %s！", "ja": "%s を調理した！"},
		"cook_leave":   {"es": "← Volver a la Base", "en": "← Back to Base", "fr": "← Retour à la base", "it": "← Torna alla base", "de": "← Zurück zur Basis", "zh": "← 返回基地", "ja": "← 拠点へ戻る"},

		# ── Entrenamiento (Muñeco) ──────────────────────────────────────────
		"train_title":  {"es": "🎯  Entrenamiento", "en": "🎯  Training", "fr": "🎯  Entraînement", "it": "🎯  Allenamento", "de": "🎯  Training", "zh": "🎯  训练", "ja": "🎯  トレーニング"},
		"train_tap":    {"es": "Entrena para ganar experiencia de base y de todas tus profesiones.", "en": "Train to gain base and profession experience.", "fr": "Entraîne-toi pour gagner de l'expérience de base et de profession.", "it": "Allenati per guadagnare esperienza base e di professione.", "de": "Trainiere, um Basis- und Berufserfahrung zu sammeln.", "zh": "训练以获得基础和职业经验。", "ja": "訓練してベースと職業の経験値を稼ぐ。"},
		"train_idle":   {"es": "+%d XP de base y de cada profesión desbloqueada", "en": "+%d XP to base level and every unlocked profession", "fr": "+%d XP au niveau de base et à chaque profession débloquée", "it": "+%d XP al livello base e a ogni professione sbloccata", "de": "+%d XP auf Basisstufe und jeden freigeschalteten Beruf", "zh": "为基础等级和每个已解锁职业 +%d 经验", "ja": "ベースレベルと解放済み全職業に +%d EXP"},
		"train_button": {"es": "💪 Entrenar", "en": "💪 Train", "fr": "💪 S'entraîner", "it": "💪 Allenati", "de": "💪 Trainieren", "zh": "💪 训练", "ja": "💪 訓練する"},
		"train_gain":   {"es": "+%d XP", "en": "+%d XP", "fr": "+%d XP", "it": "+%d XP", "de": "+%d XP", "zh": "+%d 经验", "ja": "+%d EXP"},
		"train_leave":  {"es": "← Volver a la Base", "en": "← Back to Base", "fr": "← Retour à la base", "it": "← Torna alla base", "de": "← Zurück zur Basis", "zh": "← 返回基地", "ja": "← 拠点へ戻る"},

		# ── Tienda ──────────────────────────────────────────────────────────
		"shop_title":   {"es": "🛒  Tienda del Mercader", "en": "🛒  Merchant's Shop", "fr": "🛒  Boutique du marchand", "it": "🛒  Negozio del mercante", "de": "🛒  Händlerladen", "zh": "🛒  商人的商店", "ja": "🛒  商人の店"},
		"shop_buy":     {"es": "Comprar", "en": "Buy", "fr": "Acheter", "it": "Compra", "de": "Kaufen", "zh": "购买", "ja": "購入"},
		"shop_bought":  {"es": "¡Has comprado %s!", "en": "You bought %s!", "fr": "Tu as acheté %s !", "it": "Hai comprato %s!", "de": "Du hast %s gekauft!", "zh": "你购买了 %s！", "ja": "%s を購入した！"},
		"shop_no_gold": {"es": "Oro insuficiente", "en": "Not enough gold", "fr": "Or insuffisant", "it": "Oro insufficiente", "de": "Nicht genug Gold", "zh": "金币不足", "ja": "ゴールドが足りない"},
		"shop_owned":   {"es": "Tienes: %d", "en": "Owned: %d", "fr": "Possédé : %d", "it": "Posseduti: %d", "de": "Besessen: %d", "zh": "拥有：%d", "ja": "所持：%d"},
		"shop_leave":   {"es": "🚪 Volver a la Ciudad", "en": "🚪 Back to City", "fr": "🚪 Retour à la cité", "it": "🚪 Torna in città", "de": "🚪 Zurück zur Stadt", "zh": "🚪 返回城市", "ja": "🚪 街へ戻る"},

		# ── Tienda de ciudad (mosaico) ──────────────────────────────────────
		# Los nombres de casas/NPC NO viven aquí: los lleva NpcDatabase (bilingüe inline).
		"city_shop_name":  {"es": "Tienda del Mercader", "en": "Merchant's Shop", "fr": "Boutique du marchand", "it": "Negozio del mercante", "de": "Händlerladen", "zh": "商人的商店", "ja": "商人の店"},
		"city_shop_desc":  {"es": "Equipo y consumibles", "en": "Gear and consumables", "fr": "Équipement et consommables", "it": "Equipaggiamento e consumabili", "de": "Ausrüstung und Verbrauchsgüter", "zh": "装备与消耗品", "ja": "装備と消耗品"},

		# ── Ítems (nombres) ─────────────────────────────────────────────────
		"item_potion":        {"es": "Poción Menor", "en": "Minor Potion", "fr": "Potion mineure", "it": "Pozione minore", "de": "Kleiner Trank", "zh": "下级药水", "ja": "下級ポーション"},
		"item_cooked_fish":   {"es": "Pescado Cocinado", "en": "Cooked Fish", "fr": "Poisson cuit", "it": "Pesce cotto", "de": "Gebratener Fisch", "zh": "烤鱼", "ja": "焼き魚"},
		"item_steel_sword":   {"es": "Espada de Acero", "en": "Steel Sword", "fr": "Épée en acier", "it": "Spada d'acciaio", "de": "Stahlschwert", "zh": "钢剑", "ja": "鋼の剣"},
		"item_tower_shield":  {"es": "Escudo Torre", "en": "Tower Shield", "fr": "Bouclier tour", "it": "Scudo torre", "de": "Turmschild", "zh": "塔盾", "ja": "タワーシールド"},
		"item_plate_armor":   {"es": "Armadura de Placas", "en": "Plate Armor", "fr": "Armure de plaques", "it": "Armatura a piastre", "de": "Plattenrüstung", "zh": "板甲", "ja": "プレートアーマー"},
		"item_knight_helmet": {"es": "Yelmo de Caballero", "en": "Knight's Helmet", "fr": "Heaume de chevalier", "it": "Elmo del cavaliere", "de": "Ritterhelm", "zh": "骑士头盔", "ja": "騎士の兜"},
		"item_swift_boots":   {"es": "Botas Veloces", "en": "Swift Boots", "fr": "Bottes rapides", "it": "Stivali veloci", "de": "Flinke Stiefel", "zh": "神速之靴", "ja": "疾風の靴"},
		"item_ruby_ring":     {"es": "Anillo de Rubí", "en": "Ruby Ring", "fr": "Anneau de rubis", "it": "Anello di rubino", "de": "Rubinring", "zh": "红宝石戒指", "ja": "ルビーの指輪"},

		# ── Combate: profundidad (elementos, estados, combos, botín) ─────────
		"combat_weak":        {"es": "¡DÉBIL!", "en": "WEAK!", "fr": "FAIBLE !", "it": "DEBOLE!", "de": "SCHWACH!", "zh": "弱点！", "ja": "弱点！"},
		"combat_resist":      {"es": "RESISTE", "en": "RESIST", "fr": "RÉSISTE", "it": "RESISTE", "de": "RESISTENT", "zh": "抗性", "ja": "耐性"},
		"combat_combo":       {"es": "¡COMBO!", "en": "COMBO!", "fr": "COMBO !", "it": "COMBO!", "de": "COMBO!", "zh": "连击！", "ja": "コンボ！"},
		"combat_charged":     {"es": "¡CARGA!", "en": "CHARGED!", "fr": "CHARGÉ !", "it": "CARICO!", "de": "AUFGELADEN!", "zh": "蓄力！", "ja": "チャージ！"},
		"combat_you":         {"es": "Tú", "en": "You", "fr": "Toi", "it": "Tu", "de": "Du", "zh": "你", "ja": "あなた"},
		"combat_info_type":   {"es": "Tipo", "en": "Type", "fr": "Type", "it": "Tipo", "de": "Typ", "zh": "类型", "ja": "タイプ"},
		"combat_info_weak":   {"es": "Débil a", "en": "Weak to", "fr": "Faible contre", "it": "Debole a", "de": "Schwach gegen", "zh": "弱于", "ja": "弱点"},
		"combat_info_resist": {"es": "Resiste", "en": "Resists", "fr": "Résiste à", "it": "Resiste a", "de": "Resistent gegen", "zh": "抗性", "ja": "耐性"},
		"combat_info_def":    {"es": "DEF", "en": "DEF", "fr": "DÉF", "it": "DIF", "de": "VER", "zh": "防御", "ja": "防御"},
		"combat_loot":        {"es": "Botín:", "en": "Loot:", "fr": "Butin :", "it": "Bottino:", "de": "Beute:", "zh": "战利品：", "ja": "戦利品："},

		# ── Elementos ───────────────────────────────────────────────────────
		"elem_fire":      {"es": "Fuego", "en": "Fire", "fr": "Feu", "it": "Fuoco", "de": "Feuer", "zh": "火", "ja": "炎"},
		"elem_ice":       {"es": "Hielo", "en": "Ice", "fr": "Glace", "it": "Ghiaccio", "de": "Eis", "zh": "冰", "ja": "氷"},
		"elem_lightning": {"es": "Rayo", "en": "Lightning", "fr": "Foudre", "it": "Fulmine", "de": "Blitz", "zh": "雷", "ja": "雷"},
		"elem_poison":    {"es": "Veneno", "en": "Poison", "fr": "Poison", "it": "Veleno", "de": "Gift", "zh": "毒", "ja": "毒"},
		"elem_water":     {"es": "Agua", "en": "Water", "fr": "Eau", "it": "Acqua", "de": "Wasser", "zh": "水", "ja": "水"},
		"elem_wind":      {"es": "Viento", "en": "Wind", "fr": "Vent", "it": "Vento", "de": "Wind", "zh": "风", "ja": "風"},
		"elem_earth":     {"es": "Tierra", "en": "Earth", "fr": "Terre", "it": "Terra", "de": "Erde", "zh": "土", "ja": "土"},
		"elem_holy":      {"es": "Sagrado", "en": "Holy", "fr": "Sacré", "it": "Sacro", "de": "Heilig", "zh": "神圣", "ja": "聖"},
		"elem_physical":  {"es": "Físico", "en": "Physical", "fr": "Physique", "it": "Fisico", "de": "Physisch", "zh": "物理", "ja": "物理"},
		"elem_ranged":    {"es": "Distancia", "en": "Ranged", "fr": "À distance", "it": "Distanza", "de": "Fernkampf", "zh": "远程", "ja": "遠距離"},
		"elem_magic":     {"es": "Mágico", "en": "Magic", "fr": "Magique", "it": "Magico", "de": "Magisch", "zh": "魔法", "ja": "魔法"},
		"elem_dark":      {"es": "Oscuro", "en": "Dark", "fr": "Ombre", "it": "Oscuro", "de": "Dunkel", "zh": "暗影", "ja": "闇"},
		"elem_time":      {"es": "Temporal", "en": "Time", "fr": "Temporel", "it": "Temporale", "de": "Zeitlich", "zh": "时间", "ja": "時間"},
		"elem_psychic":   {"es": "Psíquico", "en": "Psychic", "fr": "Psychique", "it": "Psichico", "de": "Psychisch", "zh": "心灵", "ja": "精神"},
		"elem_none":      {"es": "Neutro", "en": "Neutral", "fr": "Neutre", "it": "Neutro", "de": "Neutral", "zh": "无属性", "ja": "無属性"},

		# ── Estados alterados ───────────────────────────────────────────────
		"status_poison": {"es": "Envenenado", "en": "Poisoned", "fr": "Empoisonné", "it": "Avvelenato", "de": "Vergiftet", "zh": "中毒", "ja": "毒"},
		"status_bleed":  {"es": "Sangrando", "en": "Bleeding", "fr": "Saignement", "it": "Sanguinamento", "de": "Blutung", "zh": "流血", "ja": "出血"},
		"status_burn":   {"es": "Quemado", "en": "Burning", "fr": "Brûlure", "it": "Bruciatura", "de": "Verbrennung", "zh": "灼烧", "ja": "火傷"},
		"status_stun":   {"es": "Aturdido", "en": "Stunned", "fr": "Étourdi", "it": "Stordito", "de": "Betäubt", "zh": "眩晕", "ja": "スタン"},
		"status_slow":   {"es": "Ralentizado", "en": "Slowed", "fr": "Ralenti", "it": "Rallentato", "de": "Verlangsamt", "zh": "减速", "ja": "遅延"},
		"status_pdef_down": {"es": "DEF Física -10%", "en": "Phys DEF -10%", "fr": "DÉF Phys. -10%", "it": "DIF Fisica -10%", "de": "Phys. VER -10%", "zh": "物防 -10%", "ja": "物防 -10%"},
		"status_barrera": {"es": "Barrera Física", "en": "Physical Barrier", "fr": "Barrière physique", "it": "Barriera fisica", "de": "Physische Barriere", "zh": "物理屏障", "ja": "物理バリア"},
		"status_barrera_ii": {"es": "Barrera Reforzada", "en": "Reinforced Barrier", "fr": "Barrière renforcée", "it": "Barriera rinforzata", "de": "Verstärkte Barriere", "zh": "强化屏障", "ja": "強化バリア"},
		"status_escudo": {"es": "Escudo Mágico", "en": "Magic Shield", "fr": "Bouclier magique", "it": "Scudo magico", "de": "Magischer Schild", "zh": "魔法护盾", "ja": "魔法シールド"},
		"status_concentracion": {"es": "Concentración", "en": "Concentration", "fr": "Concentration", "it": "Concentrazione", "de": "Konzentration", "zh": "专注", "ja": "集中"},
		"status_muro_ii": {"es": "Muro Absoluto", "en": "Absolute Wall", "fr": "Mur absolu", "it": "Muro assoluto", "de": "Absolute Mauer", "zh": "绝对屏障", "ja": "絶対の壁"},
		"status_esconderse": {"es": "Escondido", "en": "Hidden", "fr": "Caché", "it": "Nascosto", "de": "Versteckt", "zh": "隐匿", "ja": "隠密"},
		"status_prisa": {"es": "Prisa", "en": "Haste", "fr": "Hâte", "it": "Fretta", "de": "Eile", "zh": "加速", "ja": "ヘイスト"},
		"status_prisa_ii": {"es": "Prisa Superior", "en": "Greater Haste", "fr": "Hâte supérieure", "it": "Fretta superiore", "de": "Größere Eile", "zh": "高级加速", "ja": "上位ヘイスト"},
		"status_esquiva_temporal": {"es": "Esquiva Temporal", "en": "Temporal Dodge", "fr": "Esquive temporelle", "it": "Schivata temporale", "de": "Zeitliches Ausweichen", "zh": "时间闪避", "ja": "時間回避"},
		"status_burbuja_temporal": {"es": "Burbuja Temporal", "en": "Time Bubble", "fr": "Bulle temporelle", "it": "Bolla temporale", "de": "Zeitblase", "zh": "时间泡泡", "ja": "時間の泡"},
		"status_distorsion": {"es": "Distorsión", "en": "Distortion", "fr": "Distorsion", "it": "Distorsione", "de": "Verzerrung", "zh": "扭曲", "ja": "歪曲"},
		"status_confusion": {"es": "Confusión", "en": "Confused", "fr": "Confusion", "it": "Confusione", "de": "Verwirrung", "zh": "混乱", "ja": "混乱"},
		"status_illusion": {"es": "Ilusión", "en": "Illusion", "fr": "Illusion", "it": "Illusione", "de": "Illusion", "zh": "幻象", "ja": "幻影"},
		"status_fuerza_mental": {"es": "Fuerza Mental", "en": "Mental Strength", "fr": "Force mentale", "it": "Forza mentale", "de": "Geistesstärke", "zh": "精神力量", "ja": "精神力"},
		"status_silence": {"es": "Silencio Mental", "en": "Mental Silence", "fr": "Silence mental", "it": "Silenzio mentale", "de": "Geistige Stille", "zh": "精神沉默", "ja": "精神沈黙"},
		"status_mente_serena": {"es": "Mente Serena", "en": "Serene Mind", "fr": "Esprit serein", "it": "Mente serena", "de": "Ruhiger Geist", "zh": "宁静之心", "ja": "平穏な心"},
		"status_fuerza_interior": {"es": "Fuerza Interior", "en": "Inner Strength", "fr": "Force intérieure", "it": "Forza interiore", "de": "Innere Stärke", "zh": "内在力量", "ja": "内なる力"},
		"status_chrono_lock": {"es": "Cerrojo Temporal", "en": "Chrono Lock", "fr": "Verrou temporel", "it": "Blocco temporale", "de": "Chrono-Sperre", "zh": "时空锁定", "ja": "クロノロック"},
		"status_mdef_down": {"es": "DEF Mágica -25%", "en": "Magic DEF -25%", "fr": "DÉF Mag. -25%", "it": "DIF Magica -25%", "de": "Mag. VER -25%", "zh": "魔防 -25%", "ja": "魔防 -25%"},
		"status_atk_down": {"es": "Ataque Reducido", "en": "Attack Down", "fr": "Attaque réduite", "it": "Attacco ridotto", "de": "Angriff gesenkt", "zh": "攻击下降", "ja": "攻撃低下"},
		"status_counter_stance": {"es": "Contraataque", "en": "Counter Stance", "fr": "Posture de contre", "it": "Posa di contrattacco", "de": "Konterhaltung", "zh": "反击姿态", "ja": "カウンター構え"},
		"status_berserk": {"es": "Berserk", "en": "Berserk", "fr": "Berserk", "it": "Furia", "de": "Berserker", "zh": "狂暴", "ja": "バーサーク"},
		"status_focus": {"es": "Foco", "en": "Focus", "fr": "Focalisation", "it": "Focus", "de": "Fokus", "zh": "聚焦", "ja": "集中"},
		"status_blessing": {"es": "Bendición", "en": "Blessing", "fr": "Bénédiction", "it": "Benedizione", "de": "Segen", "zh": "祝福", "ja": "祝福"},
		"status_crit_up": {"es": "Crítico Elevado", "en": "Crit Up", "fr": "Critique augmenté", "it": "Critico aumentato", "de": "Krit erhöht", "zh": "暴击提升", "ja": "クリティカル上昇"},
		"status_guaranteed_crit": {"es": "Crítico Garantizado", "en": "Guaranteed Crit", "fr": "Critique garanti", "it": "Critico garantito", "de": "Garantierter Krit", "zh": "必定暴击", "ja": "クリティカル確定"},
		"status_regen": {"es": "Regeneración", "en": "Regeneration", "fr": "Régénération", "it": "Rigenerazione", "de": "Regeneration", "zh": "回复", "ja": "リジェネ"},

		# ── Rareza del botín ────────────────────────────────────────────────
		"rarity_common":    {"es": "Común", "en": "Common", "fr": "Commun", "it": "Comune", "de": "Gewöhnlich", "zh": "普通", "ja": "コモン"},
		"rarity_uncommon":  {"es": "Infrecuente", "en": "Uncommon", "fr": "Peu commun", "it": "Non comune", "de": "Ungewöhnlich", "zh": "罕见", "ja": "アンコモン"},
		"rarity_rare":      {"es": "Raro", "en": "Rare", "fr": "Rare", "it": "Raro", "de": "Selten", "zh": "稀有", "ja": "レア"},
		"rarity_epic":      {"es": "Épico", "en": "Epic", "fr": "Épique", "it": "Epico", "de": "Episch", "zh": "史诗", "ja": "エピック"},
		"rarity_legendary": {"es": "Legendario", "en": "Legendary", "fr": "Légendaire", "it": "Leggendario", "de": "Legendär", "zh": "传说", "ja": "レジェンダリー"},

		# ── Equipo soltado por enemigos ─────────────────────────────────────
		"loot_rusty_dagger": {"es": "Daga Oxidada", "en": "Rusty Dagger", "fr": "Dague rouillée", "it": "Pugnale arrugginito", "de": "Rostiger Dolch", "zh": "锈蚀匕首", "ja": "錆びた短剣"},
		"loot_wood_buckler": {"es": "Rodela de Madera", "en": "Wooden Buckler", "fr": "Rondache en bois", "it": "Brocchiere di legno", "de": "Holzbuckler", "zh": "木制圆盾", "ja": "木の小盾"},
		"loot_hunters_bow":  {"es": "Arco de Cazador", "en": "Hunter's Bow", "fr": "Arc de chasseur", "it": "Arco del cacciatore", "de": "Jägerbogen", "zh": "猎人之弓", "ja": "狩人の弓"},
		"loot_mage_pendant": {"es": "Colgante de Mago", "en": "Mage Pendant", "fr": "Pendentif de mage", "it": "Ciondolo del mago", "de": "Magieramulett", "zh": "法师坠饰", "ja": "魔導士のペンダント"},
		"loot_iron_greaves": {"es": "Grebas de Hierro", "en": "Iron Greaves", "fr": "Jambières de fer", "it": "Gambali di ferro", "de": "Eiserne Beinschienen", "zh": "铁护胫", "ja": "鉄のグリーヴ"},
		"loot_dragon_helm":  {"es": "Yelmo de Dragón", "en": "Dragon Helm", "fr": "Heaume de dragon", "it": "Elmo del drago", "de": "Drachenhelm", "zh": "巨龙头盔", "ja": "竜の兜"},
		"loot_flame_blade":  {"es": "Hoja Llameante", "en": "Flame Blade", "fr": "Lame ardente", "it": "Lama fiammeggiante", "de": "Flammenklinge", "zh": "烈焰之刃", "ja": "炎の刃"},

		# ── Forja: recetas y UI ─────────────────────────────────────────────
		"forge_iron_sword":  {"es": "Espada de Hierro", "en": "Iron Sword", "fr": "Épée de fer", "it": "Spada di ferro", "de": "Eisenschwert", "zh": "铁剑", "ja": "鉄の剣"},
		"forge_iron_shield": {"es": "Escudo de Hierro", "en": "Iron Shield", "fr": "Bouclier de fer", "it": "Scudo di ferro", "de": "Eisenschild", "zh": "铁盾", "ja": "鉄の盾"},
		"forge_oak_bow":     {"es": "Arco de Roble", "en": "Oak Bow", "fr": "Arc en chêne", "it": "Arco di quercia", "de": "Eichenbogen", "zh": "橡木弓", "ja": "樫の弓"},
		"forge_title":       {"es": "🔨  Forja", "en": "🔨  Forge", "fr": "🔨  Forge", "it": "🔨  Fucina", "de": "🔨  Schmiede", "zh": "🔨  锻造", "ja": "🔨  鍛冶"},
		"forge_tab_craft":   {"es": "Forjar", "en": "Craft", "fr": "Fabriquer", "it": "Crea", "de": "Fertigen", "zh": "制作", "ja": "製作"},
		"forge_tab_reforge": {"es": "Reforjar", "en": "Reforge", "fr": "Reforger", "it": "Riforgia", "de": "Umschmieden", "zh": "重铸", "ja": "打ち直し"},
		"forge_craft_btn":   {"es": "Forjar (%d 🪙)", "en": "Forge (%d 🪙)", "fr": "Forger (%d 🪙)", "it": "Forgia (%d 🪙)", "de": "Schmieden (%d 🪙)", "zh": "锻造 (%d 🪙)", "ja": "鍛造 (%d 🪙)"},
		"forge_reforge_btn": {"es": "Reforjar (%d 🪙)", "en": "Reforge (%d 🪙)", "fr": "Reforger (%d 🪙)", "it": "Riforgia (%d 🪙)", "de": "Umschmieden (%d 🪙)", "zh": "重铸 (%d 🪙)", "ja": "打ち直し (%d 🪙)"},
		"forge_made":        {"es": "¡Has forjado %s!", "en": "You forged %s!", "fr": "Tu as forgé %s !", "it": "Hai forgiato %s!", "de": "Du hast %s geschmiedet!", "zh": "你锻造了 %s！", "ja": "%s を鍛造した！"},
		"forge_reforged":    {"es": "Reforjado: %s", "en": "Reforged: %s", "fr": "Reforgé : %s", "it": "Riforgiato: %s", "de": "Umgeschmiedet: %s", "zh": "已重铸：%s", "ja": "打ち直し：%s"},
		"forge_no_gold":     {"es": "Oro insuficiente", "en": "Not enough gold", "fr": "Or insuffisant", "it": "Oro insufficiente", "de": "Nicht genug Gold", "zh": "金币不足", "ja": "ゴールドが足りない"},
		"forge_no_res":      {"es": "Recursos insuficientes", "en": "Not enough resources", "fr": "Ressources insuffisantes", "it": "Risorse insufficienti", "de": "Nicht genug Ressourcen", "zh": "资源不足", "ja": "資源が足りない"},
		"forge_leave":       {"es": "← Salir de la Forja", "en": "← Leave Forge", "fr": "← Quitter la forge", "it": "← Esci dalla fucina", "de": "← Schmiede verlassen", "zh": "← 离开锻造", "ja": "← 鍛冶を出る"},
		"forge_empty_gear":  {"es": "No tienes equipo para reforjar.", "en": "No gear to reforge.", "fr": "Aucun équipement à reforger.", "it": "Nessun equipaggiamento da riforgiare.", "de": "Keine Ausrüstung zum Umschmieden.", "zh": "没有可重铸的装备。", "ja": "打ち直せる装備がない。"},
		"forge_pick_gear":   {"es": "Elige un equipo para reforjar:", "en": "Choose gear to reforge:", "fr": "Choisis un équipement à reforger :", "it": "Scegli un equipaggiamento da riforgiare:", "de": "Wähle Ausrüstung zum Umschmieden:", "zh": "选择要重铸的装备：", "ja": "打ち直す装備を選ぶ："},

		# ── Refinamiento de equipo (+0 a +10) ────────────────────────────────
		"forge_title_city":     {"es": "🔨  Herrero", "en": "🔨  Blacksmith", "fr": "🔨  Forgeron", "it": "🔨  Fabbro", "de": "🔨  Schmied", "zh": "🔨  铁匠", "ja": "🔨  鍛冶屋"},
		"forge_tab_refine":     {"es": "Refinar", "en": "Refine", "fr": "Affiner", "it": "Raffina", "de": "Verfeinern", "zh": "强化", "ja": "精錬"},
		"forge_via_city_hint":  {"es": "El herrero refina tu equipo a cambio de ORO.", "en": "The blacksmith refines your gear for GOLD.", "fr": "Le forgeron affine ton équipement contre de l'OR.", "it": "Il fabbro raffina il tuo equipaggiamento in cambio di ORO.", "de": "Der Schmied verfeinert deine Ausrüstung gegen GOLD.", "zh": "铁匠用金币强化你的装备。", "ja": "鍛冶屋はゴールドで装備を精錬する。"},
		"forge_via_anvil_hint": {"es": "Tu yunque refina el equipo a cambio de RECURSOS.", "en": "Your anvil refines gear for RESOURCES.", "fr": "Ton enclume affine l'équipement contre des RESSOURCES.", "it": "La tua incudine raffina l'equipaggiamento in cambio di RISORSE.", "de": "Dein Amboss verfeinert Ausrüstung gegen RESSOURCEN.", "zh": "你的铁砧用资源强化装备。", "ja": "あなたの金床は資源で装備を精錬する。"},
		"forge_refine_empty":   {"es": "No tienes equipo para refinar.", "en": "No gear to refine.", "fr": "Aucun équipement à affiner.", "it": "Nessun equipaggiamento da raffinare.", "de": "Keine Ausrüstung zum Verfeinern.", "zh": "没有可强化的装备。", "ja": "精錬できる装備がない。"},
		"forge_refine_max":     {"es": "Nivel máximo", "en": "Max level", "fr": "Niveau max", "it": "Livello massimo", "de": "Maximalstufe", "zh": "已达最高等级", "ja": "最大レベル"},
		"forge_refine_btn":     {"es": "Refinar", "en": "Refine", "fr": "Affiner", "it": "Raffina", "de": "Verfeinern", "zh": "强化", "ja": "精錬"},
		"forge_refine_risk":    {"es": "Éxito %d%%  ·  Igual %d%%  ·  Retrocede %d%%", "en": "Success %d%%  ·  Same %d%%  ·  Backfire %d%%", "fr": "Succès %d%%  ·  Inchangé %d%%  ·  Échec %d%%", "it": "Successo %d%%  ·  Invariato %d%%  ·  Ritorno %d%%", "de": "Erfolg %d%%  ·  Gleich %d%%  ·  Rückschlag %d%%", "zh": "成功 %d%%  ·  不变 %d%%  ·  倒退 %d%%", "ja": "成功 %d%%  ·  維持 %d%%  ·  失敗 %d%%"},
		"forge_refine_success": {"es": "¡%s ahora es +%d!", "en": "%s is now +%d!", "fr": "%s est maintenant +%d !", "it": "%s ora è +%d!", "de": "%s ist jetzt +%d!", "zh": "%s 现在是 +%d！", "ja": "%s が +%d になった！"},
		"forge_refine_stay":    {"es": "%s se mantuvo en +%d.", "en": "%s stayed at +%d.", "fr": "%s est resté à +%d.", "it": "%s è rimasto a +%d.", "de": "%s blieb bei +%d.", "zh": "%s 保持在 +%d。", "ja": "%s は +%d のままだった。"},
		"forge_refine_backfire":{"es": "%s retrocedió a +%d.", "en": "%s dropped to +%d.", "fr": "%s est retombé à +%d.", "it": "%s è sceso a +%d.", "de": "%s fiel auf +%d.", "zh": "%s 倒退到了 +%d。", "ja": "%s は +%d に下がった。"},

		# ── Encargos: títulos y tablón ──────────────────────────────────────
		"enc_gather_wood":  {"es": "Provisión de Madera", "en": "Wood Supply", "fr": "Approvisionnement en bois", "it": "Rifornimento di legno", "de": "Holzlieferung", "zh": "木材供应", "ja": "木材の調達"},
		"enc_gather_stone": {"es": "Pedido de Cantera", "en": "Quarry Order", "fr": "Commande de carrière", "it": "Ordine di cava", "de": "Steinbruch-Auftrag", "zh": "石材订单", "ja": "採石の注文"},
		"enc_fisher":       {"es": "Pesca del Día", "en": "Catch of the Day", "fr": "Pêche du jour", "it": "Pescato del giorno", "de": "Fang des Tages", "zh": "今日渔获", "ja": "本日の漁獲"},
		"enc_hunt":         {"es": "Cacería", "en": "The Hunt", "fr": "La chasse", "it": "La caccia", "de": "Die Jagd", "zh": "狩猎", "ja": "狩り"},
		"enc_wanderer":     {"es": "Trotamundos", "en": "Wanderer", "fr": "Globe-trotter", "it": "Giramondo", "de": "Wanderer", "zh": "流浪者", "ja": "放浪者"},
		"enc_gloriam_herbs": {"es": "Oro de las Dunas", "en": "Dune Gold", "fr": "Or des dunes", "it": "Oro delle dune", "de": "Dünengold", "zh": "沙丘之金", "ja": "砂丘の金"},
		"enc_gloriam_scorpions": {"es": "Amenaza de las Dunas", "en": "Dune Threat", "fr": "Menace des dunes", "it": "Minaccia delle dune", "de": "Dünenbedrohung", "zh": "沙丘威胁", "ja": "砂丘の脅威"},
		"enc_gloriam_trade": {"es": "Ronda Comercial", "en": "Trade Route Patrol", "fr": "Patrouille commerciale", "it": "Ronda commerciale", "de": "Handelsrundgang", "zh": "商路巡逻", "ja": "交易路の巡回"},
		"enc_arcanum_salvage": {"es": "Recuperación de Chatarra", "en": "Scrap Recovery", "fr": "Récupération de ferraille", "it": "Recupero rottami", "de": "Schrottbergung", "zh": "废铁回收", "ja": "スクラップ回収"},
		"enc_arcanum_automata": {"es": "Purga de Autómatas", "en": "Automata Purge", "fr": "Purge des automates", "it": "Purga degli automi", "de": "Automaten-Säuberung", "zh": "自动机械清除", "ja": "オートマトン駆除"},
		"enc_arcanum_patrol": {"es": "Vigilancia de la Metrópolis", "en": "Metropolis Watch", "fr": "Surveillance de la métropole", "it": "Sorveglianza della metropoli", "de": "Metropolen-Wache", "zh": "都市巡守", "ja": "大都市の見回り"},
		"enc_board_title":  {"es": "📋  Tablón de Encargos", "en": "📋  Job Board", "fr": "📋  Tableau des missions", "it": "📋  Bacheca incarichi", "de": "📋  Auftragstafel", "zh": "📋  委托板", "ja": "📋  依頼掲示板"},
		"enc_board_title_base": {"es": "📋  Encargos Aceptados", "en": "📋  Accepted Jobs", "fr": "📋  Missions acceptées", "it": "📋  Incarichi accettati", "de": "📋  Angenommene Aufträge", "zh": "📋  已接受的委托", "ja": "📋  受注済みの依頼"},
		"enc_available":    {"es": "Disponibles", "en": "Available", "fr": "Disponibles", "it": "Disponibili", "de": "Verfügbar", "zh": "可接受", "ja": "受注可能"},
		"enc_active":       {"es": "Activos", "en": "Active", "fr": "Actifs", "it": "Attivi", "de": "Aktiv", "zh": "进行中", "ja": "進行中"},
		"enc_accept":       {"es": "✅ Aceptar Encargo", "en": "✅ Accept Job", "fr": "✅ Accepter la mission", "it": "✅ Accetta incarico", "de": "✅ Auftrag annehmen", "zh": "✅ 接受委托", "ja": "✅ 依頼を受ける"},
		"enc_claim":        {"es": "Reclamar", "en": "Claim", "fr": "Réclamer", "it": "Riscuoti", "de": "Einfordern", "zh": "领取", "ja": "受け取る"},
		"enc_read":         {"es": "Leer", "en": "Read", "fr": "Lire", "it": "Leggi", "de": "Lesen", "zh": "阅读", "ja": "読む"},
		"enc_cancel":       {"es": "Cancelar", "en": "Cancel", "fr": "Annuler", "it": "Annulla", "de": "Abbrechen", "zh": "取消", "ja": "キャンセル"},
		"enc_requirement":  {"es": "Objetivo: %s %d de %s", "en": "Objective: %s %d %s", "fr": "Objectif : %s %d %s", "it": "Obiettivo: %s %d %s", "de": "Ziel: %s %d %s", "zh": "目标：%s %d %s", "ja": "目標：%s %d %s"},
		"enc_flavor_gather": {"es": "Necesito que alguien de confianza reúna estos recursos para la ciudad.", "en": "I need someone reliable to gather these resources for the town.", "fr": "J'ai besoin de quelqu'un de fiable pour récolter ces ressources pour la ville.", "it": "Mi serve qualcuno di fidato che raccolga queste risorse per la città.", "de": "Ich brauche jemanden Zuverlässigen, der diese Ressourcen für die Stadt sammelt.", "zh": "我需要一个可靠的人为城镇采集这些资源。", "ja": "町のためにこれらの資源を集めてくれる信頼できる者が必要だ。"},
		"enc_flavor_kill":  {"es": "Hay criaturas hostigando la zona. Ocúpate de unas cuantas.", "en": "Hostile creatures are troubling the area. Deal with a few of them.", "fr": "Des créatures hostiles harcèlent la région. Occupe-toi d'en quelques-unes.", "it": "Creature ostili tormentano la zona. Occupati di alcune di esse.", "de": "Feindliche Kreaturen stören die Gegend. Kümmere dich um ein paar davon.", "zh": "有敌对生物在骚扰这片区域。解决掉其中几个。", "ja": "敵対的な生き物が周辺を荒らしている。何体か片付けてくれ。"},
		"enc_flavor_visit": {"es": "Necesito que alguien haga una ronda por la ciudad y confirme que todo va bien.", "en": "I need someone to make the rounds in town and confirm everything is fine.", "fr": "J'ai besoin de quelqu'un pour faire une ronde en ville et confirmer que tout va bien.", "it": "Mi serve qualcuno che faccia un giro in città e confermi che va tutto bene.", "de": "Ich brauche jemanden, der in der Stadt die Runde macht und bestätigt, dass alles in Ordnung ist.", "zh": "我需要一个人在城镇里巡逻一圈，确认一切安好。", "ja": "誰かに町を見回ってもらい、異常がないか確認してほしい。"},
		"enc_progress":     {"es": "%d / %d", "en": "%d / %d", "fr": "%d / %d", "it": "%d / %d", "de": "%d / %d", "zh": "%d / %d", "ja": "%d / %d"},
		"enc_reward":       {"es": "Recompensa: %d 🪙  ·  %d XP", "en": "Reward: %d 🪙  ·  %d XP", "fr": "Récompense : %d 🪙  ·  %d XP", "it": "Ricompensa: %d 🪙  ·  %d XP", "de": "Belohnung: %d 🪙  ·  %d XP", "zh": "奖励：%d 🪙  ·  %d XP", "ja": "報酬：%d 🪙  ·  %d XP"},
		"enc_full":         {"es": "Tablón lleno (máx. %d activos)", "en": "Board full (max %d active)", "fr": "Tableau plein (max %d actifs)", "it": "Bacheca piena (max %d attivi)", "de": "Tafel voll (max. %d aktiv)", "zh": "委托板已满（最多 %d 个进行中）", "ja": "掲示板が一杯（最大 %d 件）"},
		"enc_empty":        {"es": "No hay encargos disponibles ahora.", "en": "No jobs available right now.", "fr": "Aucune mission disponible pour le moment.", "it": "Nessun incarico disponibile al momento.", "de": "Derzeit keine Aufträge verfügbar.", "zh": "目前没有可接的委托。", "ja": "今は受けられる依頼がない。"},
		"enc_base_empty":   {"es": "No tienes encargos aceptados. Visita el tablón de una ciudad.", "en": "No accepted jobs. Visit a city's board.", "fr": "Aucune mission acceptée. Visite le tableau d'une ville.", "it": "Nessun incarico accettato. Visita la bacheca di una città.", "de": "Keine angenommenen Aufträge. Besuche die Tafel einer Stadt.", "zh": "没有已接受的委托。去城市的委托板看看。", "ja": "受注済みの依頼がない。街の掲示板を訪ねよう。"},
		"enc_done":         {"es": "¡Encargo completado! +%d 🪙, +%d XP", "en": "Job complete! +%d 🪙, +%d XP", "fr": "Mission terminée ! +%d 🪙, +%d XP", "it": "Incarico completato! +%d 🪙, +%d XP", "de": "Auftrag erledigt! +%d 🪙, +%d XP", "zh": "委托完成！+%d 🪙，+%d XP", "ja": "依頼完了！+%d 🪙、+%d XP"},
		"enc_leave":        {"es": "← Salir", "en": "← Leave", "fr": "← Quitter", "it": "← Esci", "de": "← Verlassen", "zh": "← 离开", "ja": "← 出る"},
		"enc_type_gather":  {"es": "Recolectar", "en": "Gather", "fr": "Récolter", "it": "Raccogli", "de": "Sammeln", "zh": "采集", "ja": "採取"},
		"enc_type_kill":    {"es": "Combatir", "en": "Combat", "fr": "Combattre", "it": "Combatti", "de": "Kämpfen", "zh": "战斗", "ja": "戦闘"},
		"enc_type_visit":   {"es": "Explorar", "en": "Explore", "fr": "Explorer", "it": "Esplora", "de": "Erkunden", "zh": "探索", "ja": "探索"},

		# ── Mejora de construcciones ────────────────────────────────────────
		"build_level":        {"es": "Nivel %d", "en": "Level %d", "fr": "Niveau %d", "it": "Livello %d", "de": "Stufe %d", "zh": "等级 %d", "ja": "レベル %d"},
		"build_max":          {"es": "Nivel máximo", "en": "Max level", "fr": "Niveau max", "it": "Livello massimo", "de": "Maximalstufe", "zh": "已达最高等级", "ja": "最大レベル"},
		"build_upgrade":      {"es": "Mejorar", "en": "Upgrade", "fr": "Améliorer", "it": "Potenzia", "de": "Verbessern", "zh": "升级", "ja": "アップグレード"},
		"build_upgrade_cost": {"es": "Mejorar  (%d 🪙)", "en": "Upgrade  (%d 🪙)", "fr": "Améliorer  (%d 🪙)", "it": "Potenzia  (%d 🪙)", "de": "Verbessern  (%d 🪙)", "zh": "升级  (%d 🪙)", "ja": "アップグレード  (%d 🪙)"},
		"build_upgraded":     {"es": "¡%s mejorada a nivel %d!", "en": "%s upgraded to level %d!", "fr": "%s amélioré au niveau %d !", "it": "%s potenziato al livello %d!", "de": "%s auf Stufe %d verbessert!", "zh": "%s 已升级到 %d 级！", "ja": "%s をレベル %d にアップグレード！"},
		"build_need_res":     {"es": "Faltan recursos para mejorar", "en": "Not enough resources to upgrade", "fr": "Ressources insuffisantes pour améliorer", "it": "Risorse insufficienti per potenziare", "de": "Nicht genug Ressourcen zum Verbessern", "zh": "资源不足无法升级", "ja": "アップグレードに必要な資源が足りない"},

		# ── Progreso offline ────────────────────────────────────────────────
		"offline_title":    {"es": "¡Bienvenido de nuevo!", "en": "Welcome back!", "fr": "Bon retour !", "it": "Bentornato!", "de": "Willkommen zurück!", "zh": "欢迎回来！", "ja": "おかえり！"},
		"offline_away":     {"es": "Estuviste fuera %s.", "en": "You were away %s.", "fr": "Tu es parti %s.", "it": "Sei stato via %s.", "de": "Du warst %s weg.", "zh": "你离开了 %s。", "ja": "%s 間離れていた。"},
		"offline_gathered": {"es": "Mientras tanto recolectaste:", "en": "Meanwhile you gathered:", "fr": "Pendant ce temps, tu as récolté :", "it": "Nel frattempo hai raccolto:", "de": "In der Zwischenzeit hast du gesammelt:", "zh": "其间你采集了：", "ja": "その間に採取したもの："},
		"offline_nothing":  {"es": "Tus nodos siguen llenos. ¡A explorar!", "en": "Your nodes are still full. Go explore!", "fr": "Tes nœuds sont encore pleins. Va explorer !", "it": "I tuoi nodi sono ancora pieni. Vai a esplorare!", "de": "Deine Knoten sind noch voll. Geh erkunden!", "zh": "你的节点仍然满的。去探索吧！", "ja": "ノードはまだ満タンだ。探索に行こう！"},
		"offline_collect":  {"es": "Recoger", "en": "Collect", "fr": "Récupérer", "it": "Raccogli", "de": "Einsammeln", "zh": "收取", "ja": "受け取る"},
		"offline_hours":    {"es": "%dh %dm", "en": "%dh %dm", "fr": "%dh %dm", "it": "%dh %dm", "de": "%dh %dm", "zh": "%d小时 %d分", "ja": "%d時間 %d分"},
		"offline_minutes":  {"es": "%dm", "en": "%dm", "fr": "%dm", "it": "%dm", "de": "%dm", "zh": "%d分", "ja": "%d分"},

		# ── Accesibilidad (opciones) ────────────────────────────────────────
		"opt_accessibility": {"es": "Accesibilidad", "en": "Accessibility", "fr": "Accessibilité", "it": "Accessibilità", "de": "Barrierefreiheit", "zh": "无障碍", "ja": "アクセシビリティ"},
		"opt_reduce_motion": {"es": "Reducir movimiento", "en": "Reduce motion", "fr": "Réduire les animations", "it": "Riduci il movimento", "de": "Bewegung reduzieren", "zh": "减少动效", "ja": "モーションを抑える"},
		"opt_font_scale":    {"es": "Tamaño de fuente: %d%%", "en": "Font size: %d%%", "fr": "Taille de police : %d%%", "it": "Dimensione carattere: %d%%", "de": "Schriftgröße: %d%%", "zh": "字体大小：%d%%", "ja": "フォントサイズ：%d%%"},
		"opt_colorblind":    {"es": "Modo daltónico", "en": "Colorblind mode", "fr": "Mode daltonien", "it": "Modalità daltonici", "de": "Farbenblind-Modus", "zh": "色弱模式", "ja": "色覚サポート"},
		"opt_text_speed":    {"es": "Velocidad de texto: %d%%", "en": "Text speed: %d%%", "fr": "Vitesse du texte : %d%%", "it": "Velocità testo: %d%%", "de": "Textgeschwindigkeit: %d%%", "zh": "文本速度：%d%%", "ja": "テキスト速度：%d%%"},
		"opt_left_handed":   {"es": "HUD para zurdos", "en": "Left-handed HUD", "fr": "HUD pour gaucher", "it": "HUD per mancini", "de": "Linkshänder-HUD", "zh": "左手 HUD", "ja": "左利き用HUD"},
		"opt_theme":         {"es": "Tema de interfaz", "en": "UI theme", "fr": "Thème d'interface", "it": "Tema interfaccia", "de": "UI-Design", "zh": "界面主题", "ja": "UIテーマ"},
		"theme_default":     {"es": "Azul / Dorado", "en": "Blue / Gold", "fr": "Bleu / Or", "it": "Blu / Oro", "de": "Blau / Gold", "zh": "蓝金", "ja": "ブルー／ゴールド"},
		"theme_crimson":     {"es": "Carmesí", "en": "Crimson", "fr": "Cramoisi", "it": "Cremisi", "de": "Karmesin", "zh": "绛红", "ja": "クリムゾン"},
		"theme_happyflower": {"es": "Happy Flower", "en": "Happy Flower", "fr": "Happy Flower", "it": "Happy Flower", "de": "Happy Flower", "zh": "快乐花朵", "ja": "ハッピーフラワー"},
		"theme_void":        {"es": "Vacío", "en": "Void", "fr": "Néant", "it": "Vuoto", "de": "Leere", "zh": "虚空", "ja": "虚無"},
		"theme_emerald":     {"es": "Esmeralda", "en": "Emerald", "fr": "Émeraude", "it": "Smeraldo", "de": "Smaragd", "zh": "翡翠", "ja": "エメラルド"},
		"theme_solari":      {"es": "Solari", "en": "Solari", "fr": "Solari", "it": "Solari", "de": "Solari", "zh": "索拉里", "ja": "ソラリ"},
		"theme_cyber":       {"es": "Cíber / Arcano", "en": "Cyber / Arcane", "fr": "Cyber / Arcane", "it": "Cyber / Arcano", "de": "Cyber / Arkan", "zh": "赛博／奥术", "ja": "サイバー／アーカン"},
		"theme_astral":      {"es": "Astral", "en": "Astral", "fr": "Astral", "it": "Astrale", "de": "Astral", "zh": "星辰", "ja": "アストラル"},

		# ── Información (hub de consulta: Bestiario/Mazmorras/Logros/Diario/Enciclopedia) ──
		"info_title":              {"es": "Información", "en": "Information", "fr": "Informations", "it": "Informazioni", "de": "Informationen", "zh": "信息", "ja": "情報"},
		"info_soon":               {"es": "Próximamente", "en": "Coming soon", "fr": "Bientôt disponible", "it": "Prossimamente", "de": "Demnächst", "zh": "敬请期待", "ja": "近日公開"},
		"info_bestiary_sub":       {"es": "Enemigos, debilidades y bajas", "en": "Enemies, weaknesses and kills", "fr": "Ennemis, faiblesses et victimes", "it": "Nemici, debolezze e uccisioni", "de": "Feinde, Schwächen und Abschieße", "zh": "敌人、弱点与击杀", "ja": "敵・弱点・撃破数"},
		"info_dungeons":           {"es": "Mazmorras", "en": "Dungeons", "fr": "Donjons", "it": "Dungeon", "de": "Verliese", "zh": "地牢", "ja": "ダンジョン"},
		"info_dungeons_sub":       {"es": "Completadas, pendientes y progreso", "en": "Completed, pending and progress", "fr": "Terminés, en attente et progression", "it": "Completati, in sospeso e progresso", "de": "Abgeschlossen, ausstehend und Fortschritt", "zh": "已完成、待处理与进度", "ja": "完了・未完了・進捗"},
		"info_achievements":       {"es": "Logros", "en": "Achievements", "fr": "Succès", "it": "Obiettivi", "de": "Erfolge", "zh": "成就", "ja": "実績"},
		"info_achievements_sub":   {"es": "Hitos y recompensas conseguidas", "en": "Milestones and earned rewards", "fr": "Jalons et récompenses obtenues", "it": "Traguardi e ricompense ottenute", "de": "Meilensteine und erhaltene Belohnungen", "zh": "里程碑与已获奖励", "ja": "マイルストーンと獲得報酬"},
		"info_journal":            {"es": "Diario", "en": "Journal", "fr": "Journal", "it": "Diario", "de": "Tagebuch", "zh": "日志", "ja": "日誌"},
		"info_journal_sub":        {"es": "Objetivos y decisiones tomadas", "en": "Objectives and decisions made", "fr": "Objectifs et décisions prises", "it": "Obiettivi e decisioni prese", "de": "Ziele und getroffene Entscheidungen", "zh": "目标与所做的决定", "ja": "目標と下した決断"},
		"info_codex":              {"es": "Curiosidades", "en": "Curiosities", "fr": "Curiosités", "it": "Curiosità", "de": "Kuriositäten", "zh": "趣闻", "ja": "豆知識"},
		"info_codex_sub":          {"es": "Códice de lo absurdo y lo asombroso", "en": "Codex of the absurd and the amazing", "fr": "Codex de l'absurde et de l'étonnant", "it": "Codice dell'assurdo e del sorprendente", "de": "Kodex des Absurden und Erstaunlichen", "zh": "荒诞与惊奇之典籍", "ja": "不条理と驚異のコーデックス"},
		"info_relations":          {"es": "Relaciones", "en": "Relationships", "fr": "Relations", "it": "Relazioni", "de": "Beziehungen", "zh": "关系", "ja": "人間関係"},
		"info_relations_sub":      {"es": "Afinidad con los habitantes", "en": "Affinity with inhabitants", "fr": "Affinité avec les habitants", "it": "Affinità con gli abitanti", "de": "Zuneigung zu den Bewohnern", "zh": "与居民的好感度", "ja": "住民との親密度"},
		"info_encyclopedia":       {"es": "Enciclopedia", "en": "Encyclopedia", "fr": "Encyclopédie", "it": "Enciclopedia", "de": "Enzyklopädie", "zh": "百科", "ja": "百科事典"},
		"info_encyclopedia_sub":   {"es": "El saber del mundo (en construcción)", "en": "World lore (under construction)", "fr": "Le savoir du monde (en construction)", "it": "Il sapere del mondo (in costruzione)", "de": "Weltwissen (im Aufbau)", "zh": "世界设定（建设中）", "ja": "世界の知識（建設中）"},

		# ── Mazmorras (listado en Información) ──
		"dungeons_progress":       {"es": "Completadas: %d / %d  (%d%%)", "en": "Completed: %d / %d  (%d%%)", "fr": "Terminés : %d / %d  (%d%%)", "it": "Completati: %d / %d  (%d%%)", "de": "Abgeschlossen: %d / %d  (%d%%)", "zh": "已完成：%d / %d  (%d%%)", "ja": "完了：%d / %d  (%d%%)"},
		"dungeons_completed":      {"es": "Completada", "en": "Completed", "fr": "Terminé", "it": "Completato", "de": "Abgeschlossen", "zh": "已完成", "ja": "完了"},
		"dungeons_pending":        {"es": "Pendiente", "en": "Pending", "fr": "En attente", "it": "In sospeso", "de": "Ausstehend", "zh": "待处理", "ja": "未完了"},
		"dungeons_floors":         {"es": "%d plantas", "en": "%d floors", "fr": "%d étages", "it": "%d piani", "de": "%d Ebenen", "zh": "%d 层", "ja": "%d 階"},
		"dungeons_empty":          {"es": "Aún no hay mazmorras registradas.", "en": "No dungeons recorded yet.", "fr": "Aucun donjon enregistré pour l'instant.", "it": "Nessun dungeon registrato finora.", "de": "Noch keine Verliese erfasst.", "zh": "尚未记录任何地牢。", "ja": "まだダンジョンの記録がない。"},

		# ── Enciclopedia (secciones futuras, arquitectura preparada) ──
		"encyclopedia_intro":      {"es": "El saber del mundo se irá desvelando aquí a medida que juegas.", "en": "The world's lore will be revealed here as you play.", "fr": "Le savoir du monde se dévoilera ici au fil de ta partie.", "it": "Il sapere del mondo si svelerà qui man mano che giochi.", "de": "Das Wissen der Welt wird hier enthüllt, während du spielst.", "zh": "随着你的游玩，世界的设定将在此逐渐揭晓。", "ja": "プレイするにつれ、世界の知識がここに明かされていく。"},
		"ency_items":              {"es": "Objetos", "en": "Items", "fr": "Objets", "it": "Oggetti", "de": "Gegenstände", "zh": "物品", "ja": "アイテム"},
		"encyclopedia_unknown_item": {"es": "???", "en": "???", "fr": "???", "it": "???", "de": "???", "zh": "???", "ja": "???"},
		"ency_lore":               {"es": "Lore", "en": "Lore", "fr": "Lore", "it": "Lore", "de": "Überlieferung", "zh": "设定", "ja": "設定"},
		"ency_characters":         {"es": "Personajes", "en": "Characters", "fr": "Personnages", "it": "Personaggi", "de": "Charaktere", "zh": "角色", "ja": "キャラクター"},
		"ency_cities":             {"es": "Ciudades", "en": "Cities", "fr": "Cités", "it": "Città", "de": "Städte", "zh": "城市", "ja": "都市"},
		"ency_professions":        {"es": "Profesiones", "en": "Professions", "fr": "Professions", "it": "Professioni", "de": "Berufe", "zh": "职业", "ja": "職業"},
		"ency_concepts":           {"es": "Conceptos", "en": "Concepts", "fr": "Concepts", "it": "Concetti", "de": "Konzepte", "zh": "概念", "ja": "概念"},
		"ency_timeline":           {"es": "Cronología", "en": "Timeline", "fr": "Chronologie", "it": "Cronologia", "de": "Zeitleiste", "zh": "年表", "ja": "年表"},

		# ── Reinicio de características ───────────────────────────────────────
		"stat_reset":              {"es": "Reiniciar puntos", "en": "Reset points", "fr": "Réinitialiser les points", "it": "Reimposta punti", "de": "Punkte zurücksetzen", "zh": "重置点数", "ja": "ポイントをリセット"},
		"stat_reset_cost":         {"es": "Reiniciar  (%d 🪙)", "en": "Reset  (%d 🪙)", "fr": "Réinitialiser  (%d 🪙)", "it": "Reimposta  (%d 🪙)", "de": "Zurücksetzen  (%d 🪙)", "zh": "重置  (%d 🪙)", "ja": "リセット  (%d 🪙)"},
		"stat_reset_confirm_title":{"es": "¿Reiniciar características?", "en": "Reset attributes?", "fr": "Réinitialiser les attributs ?", "it": "Reimpostare gli attributi?", "de": "Attribute zurücksetzen?", "zh": "重置属性？", "ja": "能力値をリセット？"},
		"stat_reset_confirm_body": {"es": "Recuperarás todos los puntos gastados a cambio de %d de oro.", "en": "You'll refund all spent points for %d gold.", "fr": "Tu récupéreras tous les points dépensés contre %d d'or.", "it": "Recupererai tutti i punti spesi in cambio di %d d'oro.", "de": "Du erhältst alle ausgegebenen Punkte für %d Gold zurück.", "zh": "你将花费 %d 金币取回所有已花费的点数。", "ja": "%d ゴールドと引き換えに、使ったポイントをすべて戻す。"},
		"stat_reset_done":         {"es": "Características reiniciadas", "en": "Attributes reset", "fr": "Attributs réinitialisés", "it": "Attributi reimpostati", "de": "Attribute zurückgesetzt", "zh": "属性已重置", "ja": "能力値をリセットした"},
		"stat_reset_no_gold":      {"es": "Oro insuficiente para reiniciar", "en": "Not enough gold to reset", "fr": "Or insuffisant pour réinitialiser", "it": "Oro insufficiente per reimpostare", "de": "Nicht genug Gold zum Zurücksetzen", "zh": "金币不足无法重置", "ja": "リセットに必要なゴールドが足りない"},

		# ── Genéricos ───────────────────────────────────────────────────────
		"saved":      {"es": "Partida guardada", "en": "Game saved", "fr": "Partie sauvegardée", "it": "Partita salvata", "de": "Spiel gespeichert", "zh": "游戏已保存", "ja": "ゲームをセーブした"},
		"loading":    {"es": "Cargando…", "en": "Loading…", "fr": "Chargement…", "it": "Caricamento…", "de": "Lädt…", "zh": "加载中…", "ja": "読み込み中…"},
	}


func has_key(key: String) -> bool:
	return _t.has(key)


func translate_cell_name(cell_name: String) -> String:
	var key := "cell_" + cell_name.to_lower().replace(" ", "_").replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ñ", "n")
	if has_key(key):
		return t(key)
	var td := Design.tr_cell_name(cell_name)
	return td if td != "" else cell_name


func translate_cell_desc(cell_name: String, default_desc: String) -> String:
	var key := "cell_desc_" + cell_name.to_lower().replace(" ", "_").replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ñ", "n")
	if has_key(key):
		return t(key)
	var td := Design.tr_cell_desc(cell_name)
	return td if td != "" else default_desc


## Traduce el nombre canónico de una profesión (p. ej. "Don Nadie" -> "Nobody", "Guerrero" -> "Warrior")
func translate_profession(prof: String) -> String:
	if prof == "":
		return ""
	if Design != null:
		var def: Dictionary = Design.get_profession(prof)
		if not def.is_empty() and def.has("name"):
			return pick(def["name"])
	var key := "class_" + prof.to_lower().replace(" ", "_").replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ñ", "n")
	if has_key(key):
		return t(key)
	return prof
