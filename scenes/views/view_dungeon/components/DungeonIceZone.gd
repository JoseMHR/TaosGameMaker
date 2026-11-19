# DungeonIceZone.gd
# Suelo de hielo deslizante (idea.md §1.2). Mismo patrón que DungeonWaterZone.gd.
extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_on_ice"):
		body.set_on_ice(true)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_on_ice"):
		body.set_on_ice(false)
