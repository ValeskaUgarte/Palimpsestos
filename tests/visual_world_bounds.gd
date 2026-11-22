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
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("palim-bounds-prefs.cfg")
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
		if name == "cuento1_escena1":
			# Escena 1: tres pinturas seguidas (a1, a12, a13) unidas con fades.
			var arts: Array[Rect2] = []
			for painting in ["Escena_a1", "Escena_a12", "Escena_a13"]:
				arts.append(painting_rect(scene.get_node(painting)))
			var top: float = -INF
			var bottom: float = INF
			for i in arts.size():
				top = maxf(top, arts[i].position.y)
				bottom = minf(bottom, arts[i].end.y)
				if i > 0:
					check(arts[i - 1].end.x > arts[i].position.x + arts[i].size.x * 0.003, "Solapamiento insuficiente para fade")
			check(bounds.position.x >= arts[0].position.x and bounds.end.x <= arts[2].end.x, "Límites X fuera del arte")
			# La cámara bloquea la vertical en el horizonte: lo visible (no el rectángulo de límites) debe caer sobre pintura.
			var view: Vector2 = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
			var zoom: float = maxf(maxf(scene.camera_zoom, view.x / bounds.size.x), view.y / bounds.size.y)
			var half_height: float = view.y / zoom * 0.5
			check(scene.camera_horizon_y - half_height >= top and scene.camera_horizon_y + half_height <= bottom, "Vista Y fuera de todos los fondos")
		else:
			var art: Rect2 = painting_rect(scene.get_node("Ground/EscenarioCaperusita003"))
			check(art.encloses(bounds), name + ": cámara incluye relleno sin pintura")
		scene.queue_free()
		await process_frame
	print("VISUAL_WORLD_BOUNDS failures=", failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
