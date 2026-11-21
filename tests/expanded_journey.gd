extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func run() -> void:
	root.get_node("GameSession").enabled=false
	root.get_node("GamePreferences").config_path="/private/tmp/palim-expanded-prefs.cfg"
	var flow=root.get_node("LateralStory")
	flow.enabled=false;flow.chapter=2;flow.return_x=390;flow.party_health={};flow.resolved=[];flow.completed=false;flow.encounter_id=""
	var audio=root.get_node("AudioLandscape")
	for name in ["forest","edge","corrupted","combat","boss","ruins"]:
		var stream=load("res://assets/audio/original/music_"+name+".wav")
		check(stream.get_length()>15,"Tema incompleto "+name)
	for kind in ["wetland","ruins"]:
		var scene=load("res://scenes/demo/rutas/ruta_"+("pantano" if kind=="wetland" else "ruinas")+".tscn").instantiate()
		root.add_child(scene);current_scene=scene
		scene.set_process(false)
		for enemy in get_nodes_in_group("enemy"): enemy.set_physics_process(false)
		for i in 5:await physics_frame
		check(flow.return_x==390,"Ruta destruye punto de regreso")
		check(audio.profile.surface_type==("wet" if kind=="wetland" else "stone"),"Superficie de ruta incorrecta")
		check(audio._music[audio._music_slot].playing,"Música no reproduce")
		check(audio._music[audio._music_slot].stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Tema no repite")
		check(scene.actor.speed==205,"Velocidad nueva no se aplica")
		var fighters=get_nodes_in_group("lateral_actor")
		check(fighters.size()==3,"Faltan compañeros en ruta")
		for fighter in fighters:
			var component: Node
			for child in fighter.get_children():
				if child.get_script()==load("res://scripts/audio/footsteps.gd"):component=child
			check(component != null,"Falta foley en "+fighter.fighter_id)
			fighter.set_physics_process(false)
			fighter.is_jumping=false;fighter.is_attacking=false;fighter.velocity=Vector2(100,0)
			fighter._play_ground_animation("walk");fighter.anim.pause();fighter.anim.frame=0
			component._distance=10;component._last_step=-1000;component._on_contact()
			check(component._sound.stream != null,"Compañero no produce pasos")
			component._sound.stop();component._sound.stream=null
		# Followers must physically jump a low ledge rather than stall forever.
		scene.actor.position=Vector2(800,450)
		var follower=fighters[1]
		follower.position=Vector2(520,500);follower.velocity=Vector2.ZERO
		follower.set_physics_process(true)
		var saw_jump: bool = false
		for i in 12:
			await physics_frame
			saw_jump = saw_jump or follower.is_jumping
		check(saw_jump,"Compañero no supera plataforma")
		scene.queue_free();await process_frame
	# Completion is idempotent and keeps the main story intact.
	var scene=load("res://scenes/demo/rutas/ruta_ruinas.tscn").instantiate()
	root.add_child(scene);current_scene=scene;scene.set_process(false)
	scene.actor.health.current_health=700
	for enemy in get_nodes_in_group("enemy"):enemy.set_physics_process(false)
	scene._return_from_route()
	scene._return_from_route()
	check(flow.resolved.count("route_ruins")==1,"Ruta repite recompensa")
	check(flow.party_health.elliot==820,"Recompensa de ruta no se guarda")
	check(flow.chapter==2 and flow.return_x==390,"Ruta modifica capítulo principal")
	await create_timer(1).timeout
	print("EXPANDED_JOURNEY failures=",failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
