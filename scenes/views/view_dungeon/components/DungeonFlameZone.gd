# DungeonFlameZone.gd
# Zona de peligro de llama encendida: al entrar un cuerpo, le inflige daño de fuego
# y lo repele hacia atrás impidiendo atravesar la casilla encendida (mismo efecto que los pinchos).
extends Area3D

@export var damage_amount: int = 8

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage_flame"):
		body.take_damage_flame(damage_amount, global_position)
	elif body.has_method("take_damage_spikes"):
		body.take_damage_spikes(damage_amount, global_position)
