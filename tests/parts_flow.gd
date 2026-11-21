extends SceneTree
## Recorrido de las escenas jugables del Cuento I (GameSession.PARTS): cada tramo tiene su cámara,
## su inicio, sus enemigos/PNJ y su salida hacia el siguiente tramo; y los menús de mapa y Jugadas guardadas cargan.
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	await process_frame
	await process_frame
	var pages = root.get_node("ScenePages")
	var deadline := Time.get_ticks_msec() + 5000
	while pages.busy and Time.get_ticks_msec() < deadline:
		await process_frame
func run() -> void:
	var session = root.get_node("GameSession")
	session.enabled = false
	session.set_process(false)
	session.save_path = "/private/tmp/palim-parts-save.json"
	root.get_node("GamePreferences").config_path = "/private/tmp/palim-parts-prefs.cfg"
	var parts: Array = session.PARTS
	for index in parts.size():
		var part: Dictionary = parts[index]
		session.current_part = index
		var level = load(part.level).instantiate()
		root.add_child(level)
		current_scene = level
		var lo: float = part.from
		var hi: float = part.to
		var bounds: Rect2 = level.camera_bounds
		check(absf(bounds.position.x - (lo - 40.0)) < 1.0 and absf(bounds.end.x - (hi + 40.0)) < 1.0, "Escena %d: cámara fuera de su tramo" % (index + 1))
		var elliot = level.get_node("Elliot")
		check(absf(elliot.global_position.x - float(part.start)) < 40.0 or session.resume_requested, "Escena %d: Elliot no empieza en su inicio (x=%.0f)" % [index + 1, elliot.global_position.x])
		check(elliot.global_position.x >= lo and elliot.global_position.x <= hi, "Escena %d: Elliot fuera del tramo" % (index + 1))
		for enemy in get_nodes_in_group("enemy"):
			if level.is_ancestor_of(enemy):
				var x: float = enemy.global_position.x
				check(x >= lo - 150.0 and x <= hi + 150.0, "Escena %d: enemigo %s fuera del tramo" % [index + 1, enemy.name])
		var last_of_scene: bool = not (index + 1 < parts.size() and parts[index + 1].level == part.level)
		var expected_next: int = index + 1 if not last_of_scene else (session.first_part_of(String(level.get_node("ChapterExit").next_scene_path)) if level.has_node("ChapterExit") else -1)
		var exit_found := false
		for child in level.get_children():
			if child is Area2D and child.get_script() != null and "next_part" in child and child.process_mode != Node.PROCESS_MODE_DISABLED and child.monitoring:
				if child.next_part == expected_next:
					exit_found = true
				elif child.name == "SegmentExit" or child.name == "ChapterExit" or child.name == "ExitCueva":
					check(false, "Escena %d: salida %s lleva a %d y debía ir a %d" % [index + 1, child.name, child.next_part, expected_next])
		check(exit_found, "Escena %d: no hay salida hacia el tramo %d" % [index + 1, expected_next])
		check(session.part_for_scene(level) == index, "Escena %d: no reconoce su tramo" % (index + 1))
		level.queue_free()
		await settle()
	# Mapa y Jugadas guardadas
	session.current_part = -1
	var map = load("res://scenes/ui/map_screen.tscn").instantiate()
	root.add_child(map)
	current_scene = map
	await settle()
	check(map._points.size() == parts.size(), "El mapa no tiene un punto por escena")
	var saved = load("res://scenes/ui/saved_plays_menu.tscn").instantiate()
	root.add_child(saved)
	current_scene = saved
	await settle()
	var buttons := 0
	for node in saved.find_children("*", "Button", true, false):
		buttons += 1
	check(buttons >= parts.size() + 1, "Jugadas guardadas no muestra todas las escenas")
	print("PARTS_FLOW failures=", failures)
	session.quit_game(1 if failures else 0)
