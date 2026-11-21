extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func wait_travel() -> void:
	for i in 200:
		if not root.get_node("ScenePages").busy: return
		await create_timer(.02,true,false,true).timeout
	check(false,"Transición no termina")
func run() -> void:
	root.get_node("GameSession").enabled = false
	root.get_node("GamePreferences").config_path = "/private/tmp/palim-lateral-campaign-prefs.cfg"
	root.get_node("AudioLandscape").shutdown()
	var flow = root.get_node("LateralStory")
	flow.save_path = "/private/tmp/palim-lateral-campaign-test.json"
	flow.set_process(false)
	flow.chapter = 0; flow.selected = "elliot"; flow.encounter_id = ""; flow.resolved = []; flow.party_health = {}; flow.return_x = 300; flow.completed = false
	var world = load(flow.WORLD).instantiate()
	root.add_child(world); current_scene = world
	world.set_process(false)
	for i in 5: await physics_frame
	var p = world.actor
	var wolf = get_first_node_in_group("enemy")
	wolf.set_physics_process(false)
	p.set_physics_process(false)
	check(p.is_on_floor(),"Controlado no está apoyado")
	check(p.get_node("Hurtbox/CollisionShape2D").position.y == -125,"Hurtbox no sigue cuerpo lateral")
	wolf.position = p.position + Vector2(95,0)
	var before: int = wolf.health.current_health
	p.facing = Vector2.RIGHT
	p._do_hit("attack")
	p.anim.pause();p.anim.frame=int(p.anim.sprite_frames.get_frame_count(p.anim.animation)*0.56);p._on_attack_pose()
	for i in 4: await physics_frame
	check(wolf.health.current_health == before - p.punch_damage,"Contacto lateral real pierde daño")
	p._on_hitbox_area_entered(wolf.hurtbox)
	check(wolf.health.current_health == before - p.punch_damage,"Contacto lateral duplica daño")
	p._end_attack()
	p.take_damage(1,p.position-Vector2(50,200))
	check(p.velocity.y >= 0 and p.jump_height == 0,"Daño provoca elevación artificial")
	await create_timer(.2,true,false,true).timeout
	# Rune error, correct order and persistence use actual interaction events.
	var interact := InputEventAction.new();interact.action="interact";interact.pressed=true
	p.position=Vector2(1720,500)
	world._unhandled_input(interact)
	check(world._rune_step==0,"Error de runa no reinicia secuencia")
	for x in [1600,1720,1840]:
		p.position=Vector2(x,500)
		world._unhandled_input(interact)
		if x == 1600:
			p.position=Vector2(1660,500)
			world._unhandled_input(interact)
			check(world._rune_step==1,"Zona solapada pierde avance o lee dos runas")
			p.position=Vector2(1840,500)
			world._unhandled_input(interact)
			check(world._rune_step==1,"Leer fuera de orden borra progreso")
	check("runes_0" in flow.resolved,"Puzzle lateral no completa")
	check(world._runes.size()==3 and world._runes[2].active,"Runas leídas no muestran estado activo")
	world._refresh_world_markers()
	check(not world._exit_marker._ready_to_use and world._encounter_marker.visible,"Salida abierta antes de vencer encuentro")
	flow.resolved.append("guardian_0")
	world._refresh_world_markers()
	check(world._exit_marker._ready_to_use and not world._encounter_marker.visible,"Marcadores no reflejan encuentro completado")
	p.position=Vector2(1940,500)
	world._process(0)
	world._cross_page("normal")
	await create_timer(.55,true,false,true).timeout
	check(flow.chapter==1,"Runas completas no permiten pasar al siguiente mundo")
	await wait_travel()
	world=current_scene;world.set_process(false)
	world.request_encounter(load("res://resources/lateral/encounters/normal_wolf.tres"))
	check(world._pending_encounter==null,"NORMAL solicita arena")
	flow.capture_party()
	check(flow.save_game() and flow._read(flow.save_path).version == 2,"Guardado lateral no válido")
	flow.save_game()
	var corrupt = FileAccess.open(flow.save_path,FileAccess.WRITE);corrupt.store_string("broken");corrupt.close()
	check(flow.continue_game(),"Respaldo lateral no recupera")
	await wait_travel()
	flow.chapter = 2; flow.encounter_id = "guardian_2"; flow.selected = "jhon"; flow.party_health = {"elliot":900,"jhon":800,"thomas":700}
	root.get_node("ScenePages").travel(flow.ARENA)
	await wait_travel()
	var arena = current_scene
	arena.set_process(false)
	check(arena.actor.fighter_id == "jhon" and arena.actor.health.current_health == 800,"Selección no conserva identidad/salud")
	check(get_nodes_in_group("player").size() == 1 and get_nodes_in_group("companion").is_empty(),"Compañeros entran a romper arena")
	check(arena.actor.speed > 160 and arena.actor.attack_1_profile.hitbox_size.x > 88,"Jhon es solo skin")
	check(arena.opponent.boss_encounter,"Boss no usa patrones")
	arena.opponent.set_physics_process(false)
	arena.opponent.health.current_health = 50
	arena.opponent._physics_process(.01)
	check(arena.opponent._phase_two,"Boss no entra a fase 2")
	flow.victory()
	await wait_travel()
	var returned = current_scene
	returned.set_process(false)
	check("guardian_2" in flow.resolved and flow.encounter_id == "","Victoria no se registra")
	check(returned.actor.fighter_id == "elliot" and returned.actor.health.current_health == 900,"Regreso altera salud del no elegido")
	check(flow.party_health.jhon == 800,"Regreso pierde salud de elegido")
	check(get_nodes_in_group("companion").size() == 2,"Seguidores no vuelven al mundo")
	flow.resolved.erase("guardian_2")
	returned._choose_fighter("guardian_2")
	check(paused,"Selección no detiene combate")
	var chosen: Button
	for button in returned._panel.find_children("*","Button",true,false):
		if button.text.begins_with("THOMAS"): chosen=button
	check(chosen!=null,"Thomas no figura en selección")
	chosen.pressed.emit()
	await wait_travel()
	arena = current_scene
	arena.set_process(false)
	check(arena.actor.fighter_id == "thomas" and arena.actor.speed < load("res://resources/lateral/elliot.tres").speed and arena.actor.attack_1_profile.impact_strength > load("res://resources/combat/attack_1.tres").impact_strength,"Thomas carece de peso propio")
	for i in 3: await physics_frame
	arena.actor._do_hit("attack")
	for i in 20:
		await physics_frame
		var clip_key: String = String(arena.actor.anim.animation)+":"+str(arena.actor.anim.frame)
		var feet: float = arena.actor.anim.position.y + float(arena.actor._foot_offsets.get(clip_key,0))*arena.actor.anim.scale.y
		check(absf(feet)<.01,"Thomas se eleva visualmente al atacar")
		check(arena.actor.velocity.y>=0,"Thomas recibe impulso vertical al atacar")
	arena.actor._end_attack()
	arena.actor.take_damage(10000)
	await process_frame
	check(paused and arena.actor._dead and not arena.actor.is_attacking,"Derrota no pausa/cierra ataque")
	flow.retry()
	await wait_travel()
	check(current_scene.actor.fighter_id=="thomas" and current_scene.actor.health.current_health==700,"Retry no restaura salud de entrada")
	paused = false
	current_scene.queue_free();await process_frame
	print("LATERAL_CAMPAIGN failures=",failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
