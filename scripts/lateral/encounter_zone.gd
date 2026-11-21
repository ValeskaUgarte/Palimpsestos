extends Area2D
@export var definition: Resource
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and definition != null:
			get_parent().request_encounter(definition)
	)
