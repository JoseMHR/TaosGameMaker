# WeatherOverlay.gd
# ─────────────────────────────────────────────────────────────────────────────
# CAPA DE CLIMA DATA-DRIVEN
#
# CanvasLayer ligero que dibuja partículas de clima (nieve, lluvia, arena…) sobre
# el mundo 3D. NO conoce climas concretos: recibe una definición data-driven desde
# `ambience.json` (vía Design.get_weather_def) y configura un CPUParticles2D que
# emite desde una franja superior a lo ancho de la pantalla.
#
# Definición de clima (todos los campos con valores por defecto sensatos):
#   { "color": "#rrggbb", "count": int, "speed": float (px/s hacia abajo),
#     "size": float (px), "drift": float (px/s lateral), "angle": float (grados),
#     "intensity": float (multiplica count/speed; 1.0 = base),
#     "ambient_color": "#rrggbb" (tinte de pantalla), "ambient_alpha": float [0,1],
#     "sound": "res://.../loop.ogg" (ambiente en bucle), "sound_db": float (volumen) }
# Un clima "none"/"" o def vacía OCULTA la capa (partículas + tinte + sonido).
# ─────────────────────────────────────────────────────────────────────────────
class_name WeatherOverlay
extends CanvasLayer

var _particles: CPUParticles2D
# Tinte de pantalla data-driven (niebla/calor/atardecer del clima).
var _tint: ColorRect
# Reproductor de ambiente en bucle (viento, lluvia…), propio de la capa para no
# acoplarse al AudioManager (que gestiona música/SFX puntuales).
var _ambient: AudioStreamPlayer
var _ambient_path: String = ""
var _current_id: String = ""


func _ready() -> void:
	layer = 5   # por encima del viewport 3D, por debajo del HUD/diálogos
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.local_coords = false
	_particles.lifetime = 6.0
	_particles.preprocess = 2.0
	add_child(_particles)

	# Tinte de pantalla a ancho completo (bajo las partículas), oculto por defecto.
	_tint = ColorRect.new()
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.color = Color(0, 0, 0, 0)
	_tint.z_index = -1
	add_child(_tint)

	# Ambiente en bucle (se crea vacío; se asigna el stream al aplicar el clima).
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Master"
	add_child(_ambient)

	get_viewport().size_changed.connect(_layout_emitter)
	_layout_emitter()


## Coloca el emisor como una franja horizontal sobre el borde superior de la vista.
func _layout_emitter() -> void:
	if _particles == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_particles.position = Vector2(vp.x * 0.5, -20.0)
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(vp.x * 0.5 + 40.0, 4.0)


## Aplica una definición de clima (o la oculta si está vacía). `weather_id` evita
## reconfigurar si no cambia. Idempotente.
func apply(weather_id: String, def: Dictionary) -> void:
	if weather_id == _current_id:
		return
	_current_id = weather_id
	if def.is_empty():
		_particles.emitting = false
		_apply_tint({})
		_apply_sound({})
		return

	# Tinte ambiental y sonido son ortogonales a las partículas: un clima puede
	# tener solo tinte (calima), solo sonido (viento) o ambos.
	_apply_tint(def)
	_apply_sound(def)

	var vp := get_viewport().get_visible_rect().size
	# `intensity` escala densidad y velocidad de forma uniforme (data-driven).
	var intensity := maxf(0.0, float(def.get("intensity", 1.0)))
	var col := _parse_color(String(def.get("color", "#ffffff")))
	var count := int(round(int(def.get("count", 120)) * intensity))
	var speed := float(def.get("speed", 120.0)) * maxf(0.25, intensity)
	var drift := float(def.get("drift", 20.0))
	var psize := float(def.get("size", 3.0))
	var angle := float(def.get("angle", 0.0))

	# Sin partículas (p. ej. clima solo-tinte/solo-sonido): ocultamos el emisor.
	if count <= 0:
		_particles.emitting = false
		return

	_particles.amount = maxi(1, count)
	_particles.color = col
	# Cae hacia abajo (+Y) con deriva lateral opcional. gravity 0: velocidad constante.
	_particles.gravity = Vector2.ZERO
	_particles.direction = Vector2(sin(deg_to_rad(angle)) + (drift / maxf(speed, 1.0)), 1.0).normalized()
	_particles.spread = 8.0
	_particles.initial_velocity_min = speed * 0.8
	_particles.initial_velocity_max = speed * 1.2
	_particles.scale_amount_min = psize
	_particles.scale_amount_max = psize * 1.4
	# Vida suficiente para cruzar toda la altura visible.
	_particles.lifetime = maxf(2.0, (vp.y + 80.0) / maxf(speed, 1.0))
	_layout_emitter()
	_particles.restart()
	_particles.emitting = true


## Aplica (o limpia) el tinte de pantalla del clima. Def vacía = transparente.
func _apply_tint(def: Dictionary) -> void:
	if _tint == null:
		return
	if def.is_empty() or not def.has("ambient_color"):
		_tint.color = Color(0, 0, 0, 0)
		return
	var c := _parse_color(String(def.get("ambient_color", "#ffffff")))
	c.a = clampf(float(def.get("ambient_alpha", 0.12)), 0.0, 1.0)
	_tint.color = c


## Aplica (o detiene) el ambiente en bucle del clima. Def vacía o sin `sound` =
## silencio. Evita recargar el stream si la ruta no cambia (idempotente).
func _apply_sound(def: Dictionary) -> void:
	if _ambient == null:
		return
	var path := String(def.get("sound", ""))
	if path == "":
		_ambient.stop()
		_ambient_path = ""
		return
	if path != _ambient_path:
		if not ResourceLoader.exists(path):
			_ambient.stop()
			_ambient_path = ""
			return
		var stream := load(path)
		if stream is AudioStream:
			if "loop" in stream:
				stream.loop = true
			_ambient.stream = stream
			_ambient_path = path
		else:
			_ambient.stop()
			_ambient_path = ""
			return
	_ambient.volume_db = float(def.get("sound_db", -12.0))
	if not _ambient.playing:
		_ambient.play()


func _parse_color(s: String) -> Color:
	if s.begins_with("#"):
		return Color.html(s)
	return Color(1, 1, 1)
