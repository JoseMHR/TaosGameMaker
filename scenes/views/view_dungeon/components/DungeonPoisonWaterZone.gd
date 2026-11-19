# DungeonPoisonWaterZone.gd
# ─────────────────────────────────────────────────────────────────────────────
# ZONA DE AGUA ENVENENADA (Ralentización de agua + Daño continuo de veneno)
# ─────────────────────────────────────────────────────────────────────────────
extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_in_water"):
		body.set_in_water(true)
	if body.has_method("set_in_lava"):
		body.set_in_lava(true)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_in_water"):
		body.set_in_water(false)
	if body.has_method("set_in_lava"):
		body.set_in_lava(false)
