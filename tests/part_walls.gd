extends SceneTree
## Los muros izquierdo y derecho de cada tramo deben quedar justo en sus bordes (from-20 / to+20), contando el desplazamiento de su forma.
## Si el muro derecho queda antes de la salida del tramo, el jugador no puede pasar a la parte siguiente (pasaba en la escena 3).
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func shape_x(wall: Node) -> float:
	for child in wall.get_children():
		if child is CollisionShape2D:
			return (child as CollisionShape2D).global_position.x
	return (wall as Node2D).global_position.x

func run() -> void:
	var session = root.get_node("GameSession")
	session.enabled = false
	session.set_process(false)
	session.save_path = OS.get_temp_dir().path_join("pal-pw-save.json")
	session.progress_path = OS.get_temp_dir().path_join("pal-pw-progress.json")
	session.reset_progress()
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("pal-pw-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	for index in session.PARTS.size():
		var part: Dictionary = session.PARTS[index]
		session.current_part = index
		var level = (load(part.level) as PackedScene).instantiate()
		root.add_child(level)
		current_scene = level
		await process_frame
		await process_frame
		var walls = level.get_node_or_null("Walls")
		if walls != null:
			var left_x: float = shape_x(walls.get_node("WallLeft"))
			var right_x: float = shape_x(walls.get_node("WallRight"))
			check(absf(left_x - (float(part.from) - 20.0)) < 40.0, "Parte %d: muro izquierdo en x=%.0f (esperado %.0f)" % [index, left_x, float(part.from) - 20.0])
			check(absf(right_x - (float(part.to) + 20.0)) < 40.0, "Parte %d: muro derecho en x=%.0f (esperado %.0f)" % [index, right_x, float(part.to) + 20.0])
		level.queue_free()
		await process_frame
	print("PART_WALLS failures=", failures)
	quit(1 if failures > 0 else 0)
