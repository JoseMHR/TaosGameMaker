# SaveManager.gd
# Autoload Singleton — Sistema de guardado y carga de la partida.
# Serializa el estado global (GlobalState) a un archivo JSON en 'user://' y
# permite continuar exactamente por donde se dejó. También gestiona el guardado
# automático con un pequeño retardo (debounce) para no escribir en cada cambio.
extends Node

## Emitida tras guardar correctamente.
signal game_saved
## Emitida tras cargar correctamente.
signal game_loaded

const SAVE_PATH: String = "user://savegame.json"

# Debounce del autoguardado
var _autosave_timer: Timer
var _dirty: bool = false
## Solo se autoguarda cuando hay una partida en curso (evita crear un guardado
## espurio mientras estamos en el menú principal).
var active: bool = false

# ─── GUARDADO EN HILO SECUNDARIO ──────────────────────────────────────────────
## Task id del WorkerThreadPool en vuelo (-1 si no hay ninguno). Antes de
## cualquier escritura SÍNCRONA (menú "Guardar y Salir", cierre/pausa de la
## app) se espera a que termine, para no correr dos escrituras a la vez sobre
## el mismo fichero.
var _async_task_id: int = -1


# ══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	# Timer para agrupar guardados frecuentes en uno solo.
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = 1.5
	_autosave_timer.one_shot = true
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)

	# Cualquier cambio en el estado marca la partida como "sucia".
	if GlobalState.has_signal("state_updated"):
		GlobalState.state_updated.connect(_on_state_updated)


# ══════════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════════

## Devuelve true si existe un archivo de guardado válido.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Devuelve true si estamos dentro de una mazmorra (donde el autoguardado está desactivado).
func is_in_dungeon() -> bool:
	if SceneManager != null:
		if SceneManager.current_view_name == "dungeon":
			return true
		if SceneManager.in_combat and SceneManager.previous_view_before_combat == "dungeon":
			return true
	return false


## Guarda la partida de inmediato. Devuelve true si tuvo éxito.
## El Modo Debug y la Sala de Tests NUNCA se guardan.
## Tampoco se guarda si la partida no está activa (antes del mapamundi) o si se está en una mazmorra.
func save_game() -> bool:
	if GlobalState.debug_mode or GlobalState.is_test_room or is_in_dungeon():
		return false
	if not active:
		return false
	_await_pending_async_save()
	var data: Dictionary = GlobalState.to_dict()
	var json_text: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveManager] No se pudo abrir el archivo para guardar.")
		return false
	file.store_string(json_text)
	file.close()
	_dirty = false
	game_saved.emit()
	return true


## Si hay un guardado en segundo plano en vuelo (ver `_on_autosave_timeout`),
## espera a que termine antes de proseguir con una escritura síncrona — evita
## que dos escrituras concurrentes pisen el mismo fichero.
func _await_pending_async_save() -> void:
	if _async_task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_async_task_id)
		_async_task_id = -1


## Carga la partida desde disco al GlobalState. Devuelve true si tuvo éxito.
func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_warning("[SaveManager] Archivo de guardado corrupto.")
		return false

	GlobalState.from_dict(parsed)
	active = true
	game_loaded.emit()
	return true


## Borra el guardado (usado al iniciar una partida nueva).
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		# Fallback por si la ruta global no resuelve en algunas plataformas.
		if FileAccess.file_exists(SAVE_PATH):
			var dir := DirAccess.open("user://")
			if dir:
				dir.remove("savegame.json")
	_dirty = false
	active = false


## Solicita un autoguardado (con retardo). Llamar tras eventos importantes.
func request_autosave() -> void:
	if GlobalState.debug_mode or GlobalState.is_test_room or is_in_dungeon():
		return
	if not active:
		return
	_dirty = true
	if _autosave_timer and _autosave_timer.is_inside_tree():
		_autosave_timer.start()


# ══════════════════════════════════════════════════════════════════════════════
# INTERNOS
# ══════════════════════════════════════════════════════════════════════════════
func _on_state_updated() -> void:
	request_autosave()


func _on_autosave_timeout() -> void:
	if not _dirty:
		return
	if GlobalState.debug_mode or GlobalState.is_test_room or is_in_dungeon() or not active:
		return
	_await_pending_async_save()
	# GlobalState.to_dict() lee estado vivo: debe ejecutarse en el hilo
	# principal. Solo el volcado a texto + la escritura en disco (lo realmente
	# costoso) se delegan al hilo de fondo.
	var data: Dictionary = GlobalState.to_dict()
	_dirty = false
	_async_task_id = WorkerThreadPool.add_task(func() -> void:
		var json_text: String = JSON.stringify(data, "\t")
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file == null:
			push_warning("[SaveManager] No se pudo abrir el archivo para el autoguardado en hilo.")
			return
		file.store_string(json_text)
		file.close()
	)
	game_saved.emit()


## Guarda al pausar/cerrar la app (importante en móviles).
func _notification(what: int) -> void:
	if not active or is_in_dungeon():
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_game()
