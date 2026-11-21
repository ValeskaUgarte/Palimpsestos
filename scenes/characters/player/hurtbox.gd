extends Area2D

func take_damage(amount: int, from_position: Vector2 = Vector2.INF) -> void:
	get_parent().take_damage(amount, from_position)

func receive_combat_hit(amount: int, from_position: Vector2, finisher: bool = false) -> void:
	var actor := get_parent()
	if actor.has_method("receive_combat_hit"):
		actor.receive_combat_hit(amount, from_position, finisher)
	else:
		actor.take_damage(amount, from_position)
