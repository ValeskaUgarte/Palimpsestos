extends SceneTree

var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	root.get_node("GameSession").enabled=false
	root.get_node("GamePreferences").config_path="/private/tmp/palim-preferences-tests.cfg"
	var level = load("res://scenes/levels/cuento1_escena3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for actor in level.get_children():
		if actor is CharacterBody2D:
			actor.set_physics_process(false)
	await physics_frame
	for character in ["Jhon", "Thomas"]:
		var ally = level.get_node(character)
		check(ally.anim.sprite_frames.get_frame_count("walk") >= 8, character + ": marcha incompleta")
		check(ally.anim.sprite_frames.get_frame_count("attack") >= 4, character + ": ataque incompleto")
		ally.facing = Vector2.RIGHT
		ally._do_hit("attack")
		await physics_frame
		check(ally.hitbox_shape.disabled, character + ": contacto anticipado")
		ally.anim.frame = 2
		ally.anim.pause()
		await physics_frame
		await physics_frame
		check(not ally.hitbox_shape.disabled, character + ": contacto no abre")
		ally.take_damage(1, ally.ground_position() - Vector2(50, 0))
		check(ally.is_attacking and ally.anim.animation == &"attack", character + ": daño interrumpe ataque dejando estado abierto")
		ally._end_attack()
		ally._play_ground_animation("idle")
		ally.take_damage(1)
		check(ally.anim.animation == &"hurt", character + ": falta reacción al daño")
		ally._physics_process(0.4)
		check(ally.anim.animation == &"idle" and not ally.is_attacking, character + ": no recupera reposo")
		await create_timer(0.15).timeout
		check(ally.anim.modulate == Color.WHITE, character + ": flash no se recupera")
		ally._do_hit("kick")
		await create_timer(0.6).timeout
		check(not ally.is_attacking and ally.hitbox_shape.disabled, character + ": patada no termina")
	level.queue_free()
	await process_frame
	print("COMPANION_COMBAT failures=", failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
