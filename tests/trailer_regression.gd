extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func wait_real(seconds: float) -> void:
	await create_timer(seconds, false, false, true).timeout
func run() -> void:
	root.get_node("GameSession").enabled=false
	root.get_node("GamePreferences").config_path="/private/tmp/palim-preferences-tests.cfg"
	for bus in ["Master","Music","SFX","Ambient","UI"]:
		check(AudioServer.get_bus_index(bus)>=0,"Falta bus "+bus)
	for scene in ["main_menu","ui/settings_menu","ui/map_screen","ui/credits_menu"]:
		var ui: Node=load("res://scenes/"+scene+".tscn").instantiate()
		root.add_child(ui)
		await process_frame
		ui.queue_free()
		await process_frame
	var level: Node=load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	for a in level.get_children():
		if a.is_in_group("enemy"): a.set_physics_process(false)
	await physics_frame
	await physics_frame
	var p=level.get_node("Elliot")
	var foot_y: float=p.ground_position().y
	check(p.anim.sprite_frames.get_frame_count("walk")>=8,"Marcha de Elliot incompleta")
	Input.action_press("move_right")
	for i in range(40):await physics_frame
	Input.action_release("move_right")
	check(absf(p.ground_position().y-foot_y)<0.1,"Caminar altera altura del suelo")
	var max_height: float=0
	p._begin_jump()
	for i in range(50):
		await physics_frame
		max_height=maxf(max_height,p.jump_height)
	check(max_height>75 and max_height<85 and not p.is_jumping,"Salto/aterrizaje incorrecto")
	p.take_damage(1,p.ground_position()+Vector2(80,180))
	check(p.knockback.y==0,"Impacto vertical")
	for i in range(40):await physics_frame
	check(absf(p.ground_position().y-foot_y)<0.1,"Impacto desplaza profundidad")
	var enemy=level.get_node("RangerWood")
	enemy.global_position+=p.ground_position()+Vector2(80,0)-enemy.ground_position()
	var before: int=enemy.health.current_health
	p.facing=Vector2.RIGHT
	p._do_hit("attack")
	await wait_real(0.18)
	check(enemy.health.current_health==before,"Daño antes de la pose de contacto")
	await wait_real(0.4)
	check(enemy.health.current_health==before-p.punch_damage,"Golpe perdido o repetido")
	await wait_real(0.5)
	check(not p.is_attacking and p.hitbox_shape.disabled,"Ataque no recupera")
	p.set_physics_process(false)
	var puzzle=level.get_node("Monolito")
	for rune in puzzle.runes:
		p.global_position+=rune.global_position+Vector2(0,10)-p.ground_position()
		for i in range(4):await physics_frame
	check(puzzle._solved,"Secuencia física no resuelve el puzzle")
	await wait_real(0.9)
	check(not level.has_node("PuzzleGate"),"La barrera ya no existe")
	check(level.get_node("StoryPortal")._active,"Portal no se revela")
	var dm=root.get_node("DialogueManager")
	while dm.visible:dm._next_line()
	Input.action_press("interact")
	puzzle._process(0)
	Input.action_release("interact")
	await wait_real(1.8)
	check(current_scene.scene_file_path=="res://scenes/levels/cuento1_escena2.tscn","Portal no viaja")
	check(not root.get_node("ScenePages").busy,"Transición no termina")
	current_scene.get_node("ChapterExit")._on_body_entered(current_scene.get_node("Elliot"))
	await wait_real(1.8)
	check(current_scene.scene_file_path=="res://scenes/levels/cuento1_escena3.tscn","Salida siguiente no viaja")
	print("TRAILER_REGRESSION failures=",failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
