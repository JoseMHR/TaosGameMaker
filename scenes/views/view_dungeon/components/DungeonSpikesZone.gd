# DungeonSpikesZone.gd
extends Area3D

@export var damage_amount: int = 8
var is_active: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func set_active(active: bool) -> void:
	is_active = active
	set_deferred("monitoring", active)
	set_deferred("monitorable", active)

func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if body.has_method("take_damage_spikes"):
		body.take_damage_spikes(damage_amount, global_position)
