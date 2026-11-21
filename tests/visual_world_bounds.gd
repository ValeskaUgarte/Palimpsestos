extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func painting_rect(sprite: Sprite2D) -> Rect2:
	var local: Rect2 = sprite.get_rect()
	return Rect2(sprite.to_global(local.position), local.size * sprite.global_scale)
func run() -> void:
	root.get_node("GameSession").enabled = false
	# Geometry-only fixture: avoid cycling live looping audio while inspecting scenes.
	root.get_node("AudioLandscape").shutdown()
	root.get_node("GamePreferences").config_path = "/private/tmp/palim-bounds-prefs.cfg"
	for name in ["cuento1_escena1", "cuento1_escena2", "cuento1_escena3"]:
		var scene = load("res://scenes/levels/" + name + ".tscn").instantiate()
		root.add_child(scene)
		current_scene = scene
		for actor in scene.get_children():
			if actor is CharacterBody2D: actor.set_physics_process(false)
		var bounds: Rect2 = scene.camera_bounds
		if name == "cuento1_escena2":
			# Escena 2: dos pinturas seguidas (cueva + casa) unidas con un fade.
			var cave: Rect2 = painting_rect(scene.get_node("Escena_02b_Cueva"))
			var house: Rect2 = painting_rect(scene.get_node("Escena_02a_Casa"))
			check(cave.end.x > house.position.x + house.size.x * 0.003, "Solapamiento insuficiente para fade")
			check(bounds.position.x >= cave.position.x and bounds.end.x <= house.end.x, "Límites X fuera del arte")
			check(bounds.position.y >= maxf(cave.position.y, house.position.y) and bounds.end.y <= minf(cave.end.y, house.end.y), "Límites Y fuera de ambos fondos")
			scene.queue_free()
			await process_frame
			continue
		var sprite = scene.get_node("Ground/EscenarioCaperusita00" + name.right(1))
		var art: Rect2 = painting_rect(sprite)
		if name == "cuento1_escena1":
			var extension: Rect2 = painting_rect(scene.get_node("EscenarioCaperusita002"))
			check(art.end.x > extension.position.x + extension.size.x * 0.03, "Solapamiento insuficiente para fade")
			check(bounds.position.x >= art.position.x and bounds.end.x <= extension.end.x, "Límites X fuera del arte")
			check(bounds.position.y >= maxf(art.position.y, extension.position.y) and bounds.end.y <= minf(art.end.y, extension.end.y), "Límites Y fuera de ambos fondos")
		else:
			check(art.encloses(bounds), name + ": cámara incluye relleno sin pintura")
		scene.queue_free()
		await process_frame
	print("VISUAL_WORLD_BOUNDS failures=", failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
