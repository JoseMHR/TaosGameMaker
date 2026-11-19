# AudioManager.gd
# ─────────────────────────────────────────────────────────────────────────────
# GESTOR GLOBAL DE AUDIO — Autoload/Singleton
#
# Administra la reproducción de música de fondo (BGM) y efectos de sonido (SFX).
# Soporta transiciones suaves (crossfade) de música mediante dos reproductores y tweens.
# Los efectos de sonido se reproducen en nodos temporales autoliberados.
# ─────────────────────────────────────────────────────────────────────────────
extends Node

# Pistas de música disponibles
const MUSIC_PATHS = {
	"menu": "res://assets/common/music/bgm_menu.ogg",
	"opening": "res://assets/common/music/bgm_opening.ogg",
	"bgm_opening": "res://assets/common/music/bgm_opening.ogg",
	"intro": "res://assets/common/music/bgm_opening.ogg",
	"orb_room": "res://assets/common/music/bgm_orb_room.ogg",

	# Mapamundi por zonas y biomas
	"world": "res://assets/common/music/bgm_world_zone3_sylphrena.ogg",
	"world_zone1_flooded": "res://assets/common/music/bgm_world_zone1_flooded.ogg",
	"world_zone1_drained": "res://assets/common/music/bgm_world_zone1_drained.ogg",
	"world_dam_opened": "res://assets/common/music/bgm_world_zone1_flooded.ogg",
	"world_zone3": "res://assets/common/music/bgm_world_zone3_sylphrena.ogg",
	"world_zone4": "res://assets/common/music/bgm_world_zone4_celestia.ogg",
	"world_desert": "res://assets/common/music/bgm_world_zone5_gloriam.ogg",
	"world_arcanum": "res://assets/common/music/bgm_world_zona6_arcanum.ogg",
	"world_final": "res://assets/common/music/bgm_world_final.ogg",
	"world_boat": "res://assets/common/music/bgm_world_boat.ogg",
	"world_snow": "res://assets/common/music/bgm_world_zone2_snow.ogg",
	"nevada": "res://assets/common/music/bgm_world_zone2_snow.ogg",

	# Ciudades
	"city_sylphrena": "res://assets/common/music/bgm_city_sylphrena.ogg",
	"city_celestia": "res://assets/common/music/bgm_city_celestia.ogg",
	"city_gloriam": "res://assets/common/music/bgm_city_gloriam.ogg",
	"city_arcanum": "res://assets/common/music/bgm_city_arcanum.ogg",
	"city": "res://assets/common/music/bgm_city_sylphrena.ogg",
	"city_1": "res://assets/common/music/bgm_city_sylphrena.ogg",

	# Combate y Mazmorras
	"combat": "res://assets/common/music/bgm_combat_1.ogg",
	"combat_1": "res://assets/common/music/bgm_combat_1.ogg",
	"combat_2": "res://assets/common/music/bgm_combat_2.ogg",
	"combat_3": "res://assets/common/music/bgm_combat_3.ogg",
	"combat_boss": "res://assets/common/music/bgm_combat_boss.ogg",
	"dungeon": "res://assets/common/music/bgm_dungeon_cave.ogg",
	"dungeon_bandidos": "res://assets/common/music/bgm_dungeon_bandidos.ogg",
	"dungeon_desierto": "res://assets/common/music/bgm_dungeon_desierto.ogg",
	"event_crisis_puerto": "res://assets/common/music/bgm_event_crisis_puerto.ogg",
	"poi_house_cozy": "res://assets/common/music/bgm_poi_house_cozy.ogg",
	"poi_comic": "res://assets/common/music/bgm_poi_comic.ogg",
	"poi_generic": "res://assets/common/music/bgm_poi_generic.ogg",
	"creepy": "res://assets/common/music/bgm_creepy.ogg",
	"cave": "res://assets/common/music/bgm_dungeon_cave.ogg",
	"dungeon_lab": "res://assets/common/music/bgm_dungeon_lab.ogg",
	"dungeon_snow": "res://assets/common/music/bgm_dungeon_snow.ogg",
	"sendero_ancient": "res://assets/common/music/bgm_sendero_ancient.ogg",
	"sendero_sanctuary": "res://assets/common/music/bgm_sendero_sanctuary.ogg",
	"sendero_dark": "res://assets/common/music/bgm_sendero_dark.ogg",
	"ancient_ruins": "res://assets/common/music/bgm_sendero_ancient.ogg",
	"arcanium_lab": "res://assets/common/music/bgm_sendero_sanctuary.ogg",
	"dungeon_dark_spire": "res://assets/common/music/bgm_sendero_dark.ogg",
	"snow_catacomb": "res://assets/common/music/bgm_world_final.ogg",
}

const AMBIENT_SFX_PATHS: Dictionary = {
	"wind_cave": "res://assets/common/sfx/sfx_ambient_cave_drip_loop.ogg",
	"wind_snow": "res://assets/common/sfx/sfx_ambient_wind_snow_loop.ogg",
	"hum_arcane": "res://assets/common/sfx/sfx_ambient_arcane_hum_loop.ogg",
	"wind_desert": "res://assets/common/sfx/sfx_ambient_desert_wind_loop.ogg",
	"psychic_drone": "res://assets/common/sfx/sfx_ambient_psychic_drone_loop.ogg",
}

# Efectos de sonido disponibles
const SFX_PATHS = {
	"click": "res://assets/common/sfx/sfx_RetroEventAcute11.wav",
	"main_menu_click": "res://assets/common/sfx/sfx_RetroEventAcute11.wav",
	"hit": "res://assets/common/sfx/sfx_hit.wav",
	"hit_critical": "res://assets/common/sfx/sfx_hit.wav",
	"levelup": "res://assets/common/sfx/sfx_PowerUPStereoUP05.wav",
	"defeat": "res://assets/common/sfx/sfx_defeat.wav",
	"gather": "res://assets/common/sfx/sfx_gather.wav",
	"heal": "res://assets/common/sfx/sfx_heal.ogg",
	"sfx_pop_1": "res://assets/common/sfx/sfx_pop_1.wav",
	"footsteps": "res://assets/common/sfx/sfx_footsteps_walking.wav",
	"tremor": "res://assets/common/sfx/sfx_temblor.ogg",
	"sfx_temblor": "res://assets/common/sfx/sfx_temblor.ogg",
	"skill_onda": "res://assets/common/sfx/sfx_fall_quick.wav",
	"skill_agarre": "res://assets/common/sfx/sfx_jump.wav",
	"skill_tiempo": "res://assets/common/sfx/sfx_power_down.wav",
	"skill_instinto": "res://assets/common/sfx/sfx_power_up_2.wav",
	# Choque metálico pesado del Parry Perfecto (task_reforma_defensa.md, FASE 3).
	"parry_perfect": "res://assets/common/sfx/sfx_power_up_2.wav",
	# Trampolín de mazmorra (idea.md §1.1).
	"bounce_pad": "res://assets/common/sfx/sfx_jump.wav",
	"skill_afinidad": "res://assets/common/sfx/sfx_fall_quick.wav",
	"skill_purificacion": "res://assets/common/sfx/sfx_undesired_effect.wav",
	"skill_kinetic_wave": "res://assets/common/sfx/sfx_fall_quick.wav",
	"skill_psychic_grab": "res://assets/common/sfx/sfx_jump.wav",
	"skill_time_distort": "res://assets/common/sfx/sfx_power_down.wav",
	"skill_explorer_instinct": "res://assets/common/sfx/sfx_power_up_2.wav",
	"skill_elemental_affinity": "res://assets/common/sfx/sfx_fall_quick.wav",
	"skill_restoration": "res://assets/common/sfx/sfx_undesired_effect.wav",
	"build": "res://assets/common/sfx/sfx_pop_1.wav",
	# SFX único y estandarizado del paso de cursor sobre CUALQUIER botón, sin
	# variación de tono: variarlo aquí sonaba a "piano desafinado" al recorrer
	# varios botones consecutivos.
	"hover_cursor": "res://assets/common/sfx/sfx_JDSherbert-UltimateUISFXPack-Cursor-3.wav",
	"snow_mist": "res://assets/common/sfx/sfx_ambient_wind_snow_loop.ogg",
}

# Mapa SEMÁNTICO de eventos de UI → sonido concreto. Permite que toda la interfaz
# use un vocabulario consistente ("confirm"/"cancel"/"error"/"reward"...) sin que
# cada vista tenga que conocer el nombre del asset. Reutiliza los SFX existentes.
const UI_SFX := {
	"confirm": "click",
	"cancel":  "click",
	"select":  "click",
	"error":   "hit",
	"reward":  "levelup",
	"success": "heal",
	"pickup":  "gather",
}

# Mapa de pistas EN RUNTIME: arranca con MUSIC_PATHS y admite altas data-driven
# desde ambience.json (Design.register vía register_music_paths).
var _music_paths: Dictionary = MUSIC_PATHS.duplicate(true)

# Variables de música
var _music_player_1: AudioStreamPlayer
var _music_player_2: AudioStreamPlayer
var _active_player: AudioStreamPlayer = null
var _current_track_id: String = ""
var _crossfade_tween: Tween = null

# Historial de música (para regresar al tema anterior tras un combate/mazmorra)
var _music_stack: Array[String] = []

# TASK 3 FASE C: canal de ambiente en bucle, INDEPENDIENTE de la música (puede
# sonar viento/goteo a la vez que suena la música de la mazmorra). Bucle
# manual vía la señal `finished` (no depende de que el `.import` del audio
# tenga marcado "loop"), así funciona con cualquier .wav/.ogg/.ogg existente.
var _ambient_paths: Dictionary = AMBIENT_SFX_PATHS.duplicate(true)
var _ambient_player: AudioStreamPlayer
var _current_ambient_id: String = ""
var _ambient_fade_tween: Tween = null

func _ready() -> void:
	# Configurar reproductor 1
	_music_player_1 = AudioStreamPlayer.new()
	_music_player_1.bus = "Master"
	add_child(_music_player_1)
	
	# Configurar reproductor 2
	_music_player_2 = AudioStreamPlayer.new()
	_music_player_2.bus = "Master"
	add_child(_music_player_2)

	# Reproductor del canal de ambiente en bucle (Fase C, Task 3).
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	add_child(_ambient_player)
	_ambient_player.finished.connect(_on_ambient_finished)

	# Vincular sonido de hover a todos los botones existentes y futuros.
	_bind_existing_button_sounds(get_tree().root)
	get_tree().node_added.connect(_on_node_added_for_sound)


## Vincula el sonido de hover a todos los BaseButton del árbol raíz.
func _bind_existing_button_sounds(root: Node) -> void:
	for c: Node in root.get_children():
		_bind_existing_button_sounds(c)
	if root is BaseButton:
		_bind_button_sound(root as BaseButton)


## Se llama cada vez que un nodo entra al árbol de escena.
func _on_node_added_for_sound(node: Node) -> void:
	if node is BaseButton:
		_bind_button_sound(node as BaseButton)


var _last_hover_time_ms: int = 0
const HOVER_COOLDOWN_MS: int = 65

## Conecta mouse_entered de un BaseButton al SFX "select" (una sola vez).
func _bind_button_sound(btn: BaseButton) -> void:
	if btn.has_meta("_uikit_sound_bound"):
		return
	btn.set_meta("_uikit_sound_bound", true)
	btn.mouse_entered.connect(_on_button_hover)


func _on_button_hover() -> void:
	if Locale.sfx_enabled:
		var now := Time.get_ticks_msec()
		if now - _last_hover_time_ms < HOVER_COOLDOWN_MS:
			return
		_last_hover_time_ms = now
		play_sfx("hover_cursor", 0.0)


## Registra/actualiza pistas de música data-driven (id -> ruta res://). Las altas
## se fusionan con MUSIC_PATHS; permite añadir temas por región sin tocar código.
func register_music_paths(paths: Dictionary) -> void:
	for id in paths.keys():
		var p := String(paths[id])
		if p != "":
			_music_paths[String(id)] = p


func has_music_track(track_id: String) -> bool:
	return _music_paths.has(track_id)


var _saved_playback_positions: Dictionary = {}

## Reproduce una pista de música con un desvanecimiento (crossfade) suave.
func play_music(track_id: String, fade_time: float = 0.5, start_pos: float = 0.0) -> void:
	if track_id == "world" and GlobalState.get("dam_opened") == true:
		track_id = "world_dam_opened"

	if not _music_paths.has(track_id):
		push_warning("AudioManager: pista de música no encontrada: " + track_id)
		return
		
	if _current_track_id == track_id:
		return
		
	_current_track_id = track_id
	var stream: AudioStream = load(_music_paths[track_id])
	if stream == null:
		push_error("AudioManager: No se pudo cargar el archivo de música para: " + track_id)
		return
		
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if stream.loop_end <= 0:
			stream.loop_end = int(stream.get_length() * stream.mix_rate)

	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	var target_player: AudioStreamPlayer = _music_player_2 if _active_player == _music_player_1 else _music_player_1
	var old_player: AudioStreamPlayer = _active_player
	
	target_player.stream = stream
	target_player.volume_db = -80.0
	target_player.play(start_pos)
	
	_active_player = target_player
	
	_crossfade_tween = create_tween()
	_crossfade_tween.tween_method(_apply_crossfade.bind(old_player, target_player), 0.0, 1.0, fade_time)
	if old_player:
		_crossfade_tween.tween_callback(old_player.stop)


## Aplica una mezcla de potencia constante entre `old_p` (sale) y `new_p` (entra)
## para un progreso `t` en [0,1]. Convierte la ganancia lineal a dB (mín. -80).
func _apply_crossfade(t: float, old_p: AudioStreamPlayer, new_p: AudioStreamPlayer) -> void:
	var new_gain := sin(t * PI * 0.5)
	var old_gain := cos(t * PI * 0.5)
	if new_p != null:
		new_p.volume_db = linear_to_db(new_gain) if new_gain > 0.0001 else -80.0
	if old_p != null and old_p.playing:
		old_p.volume_db = linear_to_db(old_gain) if old_gain > 0.0001 else -80.0


## Guarda la música actual en la pila y cambia a una nueva pista.
func push_music(track_id: String, fade_time: float = 0.5) -> void:
	if _current_track_id != "":
		_music_stack.append(_current_track_id)
		if _active_player != null and _active_player.playing:
			_saved_playback_positions[_current_track_id] = _active_player.get_playback_position()
	play_music(track_id, fade_time)


var _saved_ambient_id: String = ""

## CONTEXTO MUSICAL DE COMBATE: apila la pista adecuada según el enfrentamiento.
func push_combat_music(is_boss: bool = false) -> void:
	if _current_ambient_id != "":
		_saved_ambient_id = _current_ambient_id
		stop_ambient_loop(0.4)
	var track := "combat"
	if is_boss:
		track = "combat_boss"
	else:
		var normal_tracks: Array[String] = ["combat_1", "combat_2", "combat_3"]
		track = normal_tracks[randi() % normal_tracks.size()]
	push_music(track, 0.5)


## Recupera la música anterior de la pila y vuelve a reproducirla desde su punto previo.
func pop_music(fade_time: float = 0.5) -> void:
	if _saved_ambient_id != "":
		play_ambient_loop(_saved_ambient_id, 0.8)
		_saved_ambient_id = ""
	if _music_stack.is_empty():
		return
	var prev_track = _music_stack.pop_back()
	var pos: float = float(_saved_playback_positions.get(prev_track, 0.0))
	play_music(prev_track, fade_time, pos)


## Limpia la pila de música.
func clear_stack() -> void:
	_music_stack.clear()


## Detiene la música de fondo con un desvanecimiento (fade out).
func stop_music(fade_time: float = 1.0) -> void:
	_current_track_id = ""
	if _active_player and _active_player.playing:
		var old_player = _active_player
		_active_player = null
		var tween = create_tween()
		tween.tween_property(old_player, "volume_db", -80.0, fade_time)
		tween.tween_callback(old_player.stop)


# ══════════════════════════════════════════════════════════════════════════════
# TASK 3 FASE C — CANAL DE AMBIENTE EN BUCLE (independiente de la música)
# ══════════════════════════════════════════════════════════════════════════════
## Registra/actualiza pistas de ambiente en bucle data-driven (id -> ruta
## res://). Mismo patrón que `register_music_paths`. Uso típico: cargar desde
## `data/ambience.json` un campo `ambient_sfx_loop` por mazmorra/región.
func register_ambient_paths(paths: Dictionary) -> void:
	for id in paths.keys():
		var p := String(paths[id])
		if p != "":
			_ambient_paths[String(id)] = p


func has_ambient_track(id: String) -> bool:
	return _ambient_paths.has(id)


## Arranca (o cambia) el ambiente en bucle con un fundido de entrada. Si `id`
## ya está sonando, no hace nada. Si `id` no está registrado, no hace nada
## (silencioso: el canal es opcional y no debe interrumpir el flujo del juego
## por un audio todavía no aportado — ver `AMBIENT_SFX_PATHS`).
func play_ambient_loop(id: String, fade_time: float = 1.0, target_volume_db: float = -6.0) -> void:
	if id == "" or id == _current_ambient_id:
		return
	if not _ambient_paths.has(id):
		return
	var stream: AudioStream = load(String(_ambient_paths[id]))
	if stream == null:
		return
	_current_ambient_id = id
	if _ambient_fade_tween != null and _ambient_fade_tween.is_valid():
		_ambient_fade_tween.kill()
	_ambient_player.stream = stream
	_ambient_player.volume_db = -80.0
	_ambient_player.play()
	_ambient_fade_tween = create_tween()
	_ambient_fade_tween.tween_property(_ambient_player, "volume_db", target_volume_db, fade_time)


## Detiene el ambiente en bucle actual con un fundido de salida.
func stop_ambient_loop(fade_time: float = 1.0) -> void:
	_current_ambient_id = ""
	if not _ambient_player.playing:
		return
	if _ambient_fade_tween != null and _ambient_fade_tween.is_valid():
		_ambient_fade_tween.kill()
	_ambient_fade_tween = create_tween()
	_ambient_fade_tween.tween_property(_ambient_player, "volume_db", -80.0, fade_time)
	_ambient_fade_tween.tween_callback(_ambient_player.stop)


## Bucle MANUAL: al terminar el stream, si sigue siendo el ambiente activo, se
## relanza desde el principio. Evita depender de flags de loop del `.import`
## (funciona igual con un .wav corto que con un .ogg largo).
func _on_ambient_finished() -> void:
	if _current_ambient_id != "" and _ambient_paths.has(_current_ambient_id):
		_ambient_player.play()


## Reproduce un efecto de sonido en un canal temporal con modulación de tono.
func play_sfx(sfx_id: String, pitch_range: float = 0.08) -> void:
	if not Locale.sfx_enabled or sfx_id == "":
		return
	var path: String = SFX_PATHS.get(sfx_id, "")
	if path == "":
		if sfx_id in ["click", "select", "confirm", "cancel", "ui_click"]:
			path = SFX_PATHS.get("click", "")
		else:
			return
		
	var stream: AudioStream = load(path)
	if stream == null:
		return
		
	if stream is AudioStreamOggVorbis:
		stream.loop = false
		
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = stream
	sfx_player.bus = "Master"
	if pitch_range > 0.0:
		sfx_player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	add_child(sfx_player)
	sfx_player.play()
	
	sfx_player.finished.connect(sfx_player.queue_free)


## Reproduce un SFX SEMÁNTICO de interfaz ("confirm", "cancel", "error",
## "reward", "success", "pickup", "select"). Mapea a un sonido concreto vía
## UI_SFX, de modo que toda la UI suene coherente sin acoplarse a nombres de
## assets. Si el evento no está mapeado, cae a "click".
func play_ui(kind: String) -> void:
	var id: String = UI_SFX.get(kind, "click")
	play_sfx(id)

## Reproduce la banda sonora específica de una ciudad según su ID.
func play_city_music(city_id: String = "", fade_time: float = 0.5) -> void:
	var clean := city_id.to_lower().strip_edges()
	if clean.begins_with("city_"):
		clean = clean.substr(5)
	match clean:
		"sylphrena", "sylp":
			play_music("city_sylphrena", fade_time)
		"celestia":
			play_music("city_celestia", fade_time)
		"gloriam":
			play_music("city_gloriam", fade_time)
		"arcanum":
			play_music("city_arcanum", fade_time)
		_:
			play_music("city", fade_time)
