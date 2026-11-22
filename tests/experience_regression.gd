extends SceneTree
var failures: int = 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func until(predicate: Callable,timeout: float) -> bool:
	var deadline=Time.get_ticks_msec()+int(timeout*1000)
	while Time.get_ticks_msec()<deadline:
		if predicate.call():return true
		await physics_frame
	return false
func run() -> void:
	var session=root.get_node("GameSession")
	var preferences=root.get_node("GamePreferences")
	session.enabled=false
	session.set_process(false)
	session.save_path=OS.get_temp_dir().path_join("palim-experience-save.json")
	preferences.config_path=OS.get_temp_dir().path_join("palim-experience-preferences.cfg")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(session.save_path+suffix):DirAccess.remove_absolute(session.save_path+suffix)
	var level=load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	for actor in level.get_children():
		if actor is CharacterBody2D:actor.set_physics_process(false)
	var player=level.get_node("Elliot")
	Input.action_press("move_right")
	player._physics_process(1.0/60)
	check(player.velocity.x>0 and player.velocity.x<player.speed,"Arranque no acelera gradualmente")
	for i in 12:player._physics_process(1.0/60)
	check(is_equal_approx(player.velocity.x,player.speed),"Velocidad base alterada")
	Input.action_release("move_right")
	for i in 8:player._physics_process(1.0/60)
	check(player.velocity.length()<0.1,"Frenado deja deriva")
	Input.action_press("move_right",0.5)
	for i in 12:player._physics_process(1.0/60)
	check(is_equal_approx(player.velocity.x,player.speed*0.5),"Stick pierde intensidad analógica")
	Input.action_release("move_right")
	Input.action_press("move_up")
	player._physics_process(1.0/60)
	check(player.facing==Vector2.RIGHT,"Caminar en profundidad desvía el golpe verticalmente")
	Input.action_release("move_up")
	Input.action_press("jump")
	level.get_node("PauseMenu")._on_resume_pressed()
	player._physics_process(1.0/60)
	check(not player.is_jumping,"Aceptar UI con salto dispara salto al reanudar")
	Input.action_release("jump")
	player._physics_process(1.0/60)
	var audio=root.get_node("AudioLandscape")
	paused=true
	audio.cue(&"ui_accept")
	var ui_voice=audio.get_child(audio.get_child_count()-1)
	check(ui_voice.process_mode==Node.PROCESS_MODE_ALWAYS,"UI de pausa no reproduce audio inmediatamente")
	paused=false
	check(audio.bank.forest.size()==4 and audio.bank.stone.size()==4,"Banco de pasos incompleto")
	for stream in audio.bank.forest+audio.bank.stone+audio.bank.wood+audio.bank.wet:
		check(stream is AudioStream and stream.get_length()>0,"Paso inexistente o vacío")
	for cue in ["impact","finisher","door_open","page_turn"]:
		check(audio.bank.interactions.get(cue)!=null,"Falta cue "+cue)
	preferences.set_volume("SFX",0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"Volumen cero no silencia")
	preferences.set_volume("SFX",0.8)
	preferences.shake=0.3
	check(preferences.save()==OK,"Preferencias no se guardan")
	var config=ConfigFile.new()
	check(config.load(preferences.config_path)==OK and is_equal_approx(config.get_value("comfort","shake"),0.3),"Preferencias no persisten")
	preferences.bind_key("move_left",KEY_D)
	check(preferences.key_label("move_left")=="D" and preferences.key_label("move_right")=="A","Remapeo crea teclas duplicadas")
	preferences.bind_key("move_left",KEY_A)
	var controller_found=false
	for event in InputMap.action_get_events("jump"):
		if event is InputEventJoypadButton:controller_found=true
	check(controller_found,"Remapeo elimina mando")
	player.health.current_health=321
	player.global_position+=Vector2(900,0)-player.ground_position()+Vector2(0,player.ground_position().y)
	var survivor_name: String=""
	for actor in level.get_children():
		if actor.is_in_group("enemy") and actor.name!=&"RangerWood":
			survivor_name=String(actor.name);actor.health.current_health=17;break
	player.present_interaction(player.ground_position()+Vector2(30,0))
	check(player.anim.animation==&"interact", "No hay gesto de interacción")
	var drawn_foot=player.anim.global_position.y+696*player.anim.scale.y
	check(absf(drawn_foot-player.ground_position().y)<.1,"Gesto desplaza pies")
	session.record_defeat(level.scene_file_path,"RangerWood")
	level.get_node("Monolito")._solved=true
	session.enabled=true
	check(session.checkpoint(level)==OK,"Checkpoint no escribe")
	check(session.checkpoint(level)==OK,"Checkpoint no reemplaza/crea backup")
	check(session.read_save(),"Checkpoint no carga")
	var file=FileAccess.open(session.save_path,FileAccess.WRITE)
	file.store_string("{partida rota");file.close()
	check(session.read_save(),"Backup no recupera partida corrupta")
	session.enabled=false
	session.resume_requested=true
	level.free()
	level=load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(level);current_scene=level
	for actor in level.get_children():
		if actor is CharacterBody2D:actor.set_physics_process(false)
	await process_frame
	player=level.get_node("Elliot")
	check(player.health.current_health==321,"Restauración pierde salud")
	check(absf(player.ground_position().x-900)<2,"Restauración pierde posición")
	check(level.get_node(survivor_name).health.current_health==17,"Enemigo vivo pierde salud al cargar")
	check(not level.has_node("RangerWood"),"Enemigo derrotado reaparece")
	check(level.get_node("Monolito")._solved and level.get_node("StoryPortal")._active,"Puzzle resuelto no restaura portal")
	level.free()
	level=load("res://scenes/levels/cuento1_escena3.tscn").instantiate()
	root.add_child(level);current_scene=level
	for actor in level.get_children():
		if actor is CharacterBody2D:actor.set_physics_process(false)
	var boss=level.get_node("Lobo")
	var exit=level.get_node("ChapterExit")
	exit.travel()
	check(not exit._triggered,"Salida permite saltarse al guardián")
	boss._attack()
	await create_timer(0.2).timeout
	check(boss.hitbox_shape.disabled and boss.visual.frame in [0,1],"Boss impacta sin anticipación")
	await create_timer(0.4).timeout
	check(not boss.hitbox_shape.disabled and boss.visual.frame==2,"Boss no sincroniza contacto")
	await create_timer(1.8).timeout
	check(boss.can_attack and boss._charge_pattern and boss.hitbox_shape.disabled,"Boss no recupera/alterna patrón")
	boss._attack()
	check(await until(func():return not boss.hitbox_shape.disabled,2.0),"Acometida no abre ventana")
	check(boss._charging and boss.visual.frame==2,"Segundo patrón no es acometida")
	boss.health.current_health=50
	boss._physics_process(1.0/60)
	check(boss._phase_two and boss.knockback.x!=0 and boss.knockback.y==0,"Acometida/fase altera suelo o no avanza")
	await create_timer(1.8).timeout
	level.queue_free()
	await process_frame
	await process_frame
	print("EXPERIENCE_REGRESSION failures=",failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
