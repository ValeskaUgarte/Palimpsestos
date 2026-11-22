extends SceneTree

var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("GameSession").enabled=false
	root.get_node("GamePreferences").config_path=OS.get_temp_dir().path_join("palim-preferences-tests.cfg")
	for character in ["Jhon", "Thomas"]:
		var actor = load("res://scenes/characters/player/" + character + ".tscn").instantiate()
		actor.is_companion = true
		root.add_child(actor)
		actor.set_physics_process(false)
		for animation in actor.anim.sprite_frames.get_animation_names():
			if actor.anim.sprite_frames.get_frame_count(animation) == 0:
				continue
			actor._play_ground_animation(animation)
			var drawn_foot: float = actor.anim.global_position.y + 200.0 * actor.anim.scale.y
			if absf(drawn_foot - actor.ground_position().y) > 0.1:
				failures += 1
				push_error(character + ": pies desplazados en " + String(animation))
			for frame in actor.anim.sprite_frames.get_frame_count(animation):
				var texture: AtlasTexture = actor.anim.sprite_frames.get_frame_texture(animation, frame)
				if absf(texture.margin.position.y + texture.region.size.y - 800.0) > 0.1:
					failures += 1
					push_error(character + ": frame desalineado en " + String(animation))
		actor.queue_free()
		await process_frame
	print("COMPANION_PRESENTATION failures=", failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
