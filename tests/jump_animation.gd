extends SceneTree
# Salto: cada personaje usa SU clip 'jump' (o idle si está vacío) durante todo el vuelo, también como compañero,
# el ápice ronda 130 px y el compañero cruza un obstáculo saltando.

var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	root.get_node("GameSession").enabled = false
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("palim-preferences-tests.cfg")
	var level = load("res://scenes/levels/cuento1_escena3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for actor in level.get_children():
		if actor.is_in_group("enemy"):
			actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	var elliot = level.get_node("Elliot")
	check(elliot.jump_impulse * elliot.jump_impulse / (2.0 * elliot.jump_gravity) > 120.0, "El apex teórico debe rondar 130 px")
	for name in ["Elliot", "Jhon", "Thomas"]:
		var p = level.get_node(name)
		if name != "Elliot":
			p.set_physics_process(true)
		var expected: StringName = &"jump" if SpriteFit.has_clip(p.anim.sprite_frames, &"jump") else &"idle"
		p._begin_jump()
		check(p.is_jumping, name + ": no salta")
		var apex := 0.0
		var wrong := 0
		var ticks := 0
		while p.is_jumping and ticks < 200:
			await physics_frame
			ticks += 1
			apex = maxf(apex, p.jump_height)
			if p.is_jumping and (p.anim.animation != expected or not p.anim.visible):
				wrong += 1
		check(wrong == 0, "%s: %d ticks sin el clip %s (animación %s)" % [name, wrong, expected, p.anim.animation])
		check(apex > 120.0 and apex < 140.0, "%s: ápice %.1f fuera de 120-140" % [name, apex])
		check(ticks > 40 and ticks < 62, "%s: vuelo de %d ticks (esperado ~50)" % [name, ticks])
		check(p.anim.scale.length() > 0.1 and p.anim.visible, name + ": sprite oculto o sin escala tras saltar")
		print("%s clip=%s ápice=%.1f ticks=%d frames_jump=%d" % [name, expected, apex, ticks, p.anim.sprite_frames.get_frame_count("jump")])
	# El compañero Jhon cruza un obstáculo (clear_height 45) saltando mientras Elliot camina.
	var jhon = level.get_node("Jhon")
	jhon.global_position = Vector2(250, 280)
	elliot.global_position = Vector2(450, 280)
	var obstacle = (load("res://scenes/props/JumpObstacle.tscn") as PackedScene).instantiate()
	level.add_child(obstacle)
	obstacle.global_position = Vector2(340, 284)
	obstacle.clear_height = 45.0
	var jumped := false
	Input.action_press("move_right")
	for i in 240:
		await physics_frame
		if jhon.is_jumping:
			jumped = true
	Input.action_release("move_right")
	check(jumped, "Jhon no saltó el obstáculo")
	check(jhon.global_position.x > obstacle.global_position.x + 30.0, "Jhon quedó atascado (x=%.1f)" % jhon.global_position.x)
	print("failures=", failures)
	quit(failures)
