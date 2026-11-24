extends Area2D

func take_damage(amount: int, from_position: Vector2 = Vector2.INF, heavy: bool = false) -> void:
	var actor := get_parent()
	# Golpe fuerte (puede derribar): solo los personajes que saben caer lo reciben como tal.
	if heavy and actor.has_method("take_heavy_hit"):
		actor.take_heavy_hit(amount, from_position)
	else:
		actor.take_damage(amount, from_position)

func receive_combat_hit(amount: int, from_position: Vector2, finisher: bool = false) -> void:
	var actor := get_parent()
	if actor.has_method("receive_combat_hit"):
		actor.receive_combat_hit(amount, from_position, finisher)
	else:
		actor.take_damage(amount, from_position)
