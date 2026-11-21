@tool
extends Area2D
@export_enum("forest", "stone", "wood", "dirt", "grass", "wet") var surface_type: String = "forest"
@export var surface_priority: int = 0
func _ready() -> void:
	if Engine.is_editor_hint(): return
	collision_layer = 0
	collision_mask = 2
	add_to_group("foley_surfaces")
