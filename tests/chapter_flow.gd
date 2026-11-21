extends SceneTree
var failures: int = 0
func _initialize():call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures+=1;push_error(message)
func settle() -> void:
	await process_frame
	await process_frame
	var pages=root.get_node("ScenePages")
	var deadline=Time.get_ticks_msec()+5000
	while pages.busy and Time.get_ticks_msec()<deadline:await process_frame
func run() -> void:
	var session=root.get_node("GameSession")
	session.enabled=false;session.set_process(false)
	session.save_path="/private/tmp/palim-flow-save.json"
	root.get_node("GamePreferences").config_path="/private/tmp/palim-flow-preferences.cfg"
	var level=load("res://scenes/levels/cuento1_escena3.tscn").instantiate()
	root.add_child(level);current_scene=level
	for actor in level.get_children():
		if actor is CharacterBody2D:actor.set_physics_process(false)
	var p=level.get_node("Elliot")
	var boss=level.get_node("Lobo")
	var ally=get_first_node_in_group("companion")
	check(ally!=null,"Falta compañero en escena 3")
	if ally:ally.health.current_health=31
	boss.health.current_health=75
	session.enabled=true
	check(session.checkpoint(level)==OK,"No guarda arena")
	check(session.read_save(),"No carga arena")
	session.enabled=false;session.resume_requested=true
	level.queue_free();await process_frame
	level=load("res://scenes/levels/cuento1_escena3.tscn").instantiate()
	root.add_child(level);current_scene=level
	for actor in level.get_children():
		if actor is CharacterBody2D:actor.set_physics_process(false)
	p=level.get_node("Elliot");boss=level.get_node("Lobo");ally=get_first_node_in_group("companion")
	check(boss.health.current_health==75 and ally.health.current_health==31,"Recarga altera salud del combate/compañero")
	p._begin_jump();p.take_damage(10000)
	await process_frame;await process_frame
	check(paused and p._dead and not p.is_jumping and p.hitbox_shape.disabled,"Derrota no detiene correctamente el combate")
	var pause_event=InputEventAction.new();pause_event.action="pause";pause_event.pressed=true
	level.get_node("PauseMenu")._input(pause_event)
	check(paused,"Pausa reanuda combate estando muerto")
	paused=false
	p.health.current_health=1000;p._dead=false
	boss.take_damage(10000)
	await create_timer(1.4).timeout
	level.get_node("ChapterExit").travel()
	await settle()
	# Al vencer al lobo la salida lleva ahora a la escena 4 (casa de la abuelita); el cierre del capítulo es al final de esa escena.
	check(current_scene.scene_file_path=="res://scenes/levels/cuento1_escena4.tscn","Victoria no pasa a la escena 4")
	session.enabled=true;session.complete_chapter()
	check(session.read_save() and session._data.completed,"No persiste final de capítulo")
	check(session.continue_game(),"No continúa capítulo terminado")
	await settle()
	check(current_scene.scene_file_path=="res://scenes/levels/chapter_end.tscn","Continuar final reinicia boss")
	print("CHAPTER_FLOW failures=",failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
