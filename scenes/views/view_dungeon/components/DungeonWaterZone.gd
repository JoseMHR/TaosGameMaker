# DungeonWaterZone.gd
extends Area3D

## Corriente de agua direccional (idea.md §1.2): vector de arrastre continuo
## aplicado a quien entra en la zona, en unidades/segundo. `Vector3.ZERO`
## (por defecto) mantiene el comportamiento de charco de agua normal, sin
## arrastre — para activar la corriente, asignar este vector desde la celda de
## mazmorra (`current_direction`) al construir la pieza.
@export var current_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_in_water"):
		body.set_in_water(true)
	if current_direction != Vector3.ZERO and body.has_method("add_water_current"):
		body.add_water_current(current_direction)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_in_water"):
		body.set_in_water(false)
	if current_direction != Vector3.ZERO and body.has_method("remove_water_current"):
		body.remove_water_current(current_direction)
