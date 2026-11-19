# DungeonClimbZone.gd
# Franja adosada a la cara abierta de un muro escalable (idea.md §1.1). Mismo
# patrón que DungeonIceZone.gd/DungeonWaterZone.gd.
extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_climbing"):
		body.set_climbing(true)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_climbing"):
		body.set_climbing(false)
