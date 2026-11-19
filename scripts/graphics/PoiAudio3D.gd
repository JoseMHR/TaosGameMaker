class_name PoiAudio3D
extends AudioStreamPlayer3D
## REPRODUCTOR DE AUDIO POSICIONAL 3D OPTIMIZADO PARA POIS (Móvil / 60 FPS)
## ─────────────────────────────────────────────────────────────────────────────
## Configuración de atenuación según perfil de rendimiento y consistencia espacial:
## - Attenuation Model: Logarithmic (ATTENUATION_LOGARITHMIC = 2).
## - Max Distance: 12.0 metros (se silencia suavemente fuera del POI).
## - Unit Size: 2.0 metros (volumen pleno en las casillas contiguas).
## - Auto-culling: pausa la reproducción cuando la distancia a la cámara excede max_distance.
## ─────────────────────────────────────────────────────────────────────────────

@export var loop_stream: AudioStream = null
@export var auto_start: bool = true


func _ready() -> void:
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	max_distance = 12.0
	unit_size = 2.0
	bus = "Master"
	doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED

	if loop_stream != null and stream == null:
		stream = loop_stream

	if auto_start and stream != null and not playing:
		play()
