extends SceneTree
## Flujo REAL de la cueva (escena 2): hablar con la abuela, volver por las salidas, Caperucita habla sola con la física real
## (sin forzar player_in_range) y el acertijo de la cueva abre su panel.
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
const ESCENA2 := "res://scenes/levels/cuento1_escena2.tscn"
var log_lines: Array = []
func _initialize() -> void:
	call_deferred("run")
func say(s: String) -> void:
	print("FLOW ", s)
func settle() -> void:
	await process_frame
	await process_frame
	var pages = root.get_node("ScenePages")
	var deadline := Time.get_ticks_msec() + 6000
	while pages.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
func advance_dialogue(max_frames := 600) -> String:
	var dm = root.get_node("DialogueManager")
	var first := ""
	var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
	for i in max_frames:
		await physics_frame
		if dm.visible:
			if first == "": first = dm.label.text
			dm.label.visible_characters = -1
			dm._unhandled_input(ev)
		elif first != "":
			break
	return first
func load_part(i: int) -> Node:
	var s = root.get_node("GameSession"); s.current_part = i
	var lvl = load(ESCENA2).instantiate(); root.add_child(lvl); current_scene = lvl
	await settle()
	return lvl
func run() -> void:
	var s = root.get_node("GameSession")
	s.enabled = false; s.set_process(false)
	s.save_path = OS.get_temp_dir().path_join("pal-gr-save.json"); s.progress_path = OS.get_temp_dir().path_join("pal-gr-progress.json")
	s.reset_progress()
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("pal-gr-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	# PARTE 6 (casa): llegar a la abuela con física real
	var lvl = await load_part(5)
	var el = lvl.get_node("Elliot")
	var ab = lvl.get_node("Abuelita")
	say("Elliot x=%.0f, Abuelita x=%.0f (auto_start=%s)" % [el.global_position.x, ab.global_position.x, str(ab.auto_start)])
	el.global_position.x = ab.global_position.x - 120.0
	var text: String = await advance_dialogue(900)
	say("Abuelita habla sola al llegar: '%s'" % text.left(50))
	if text == "":
		Input.action_press("interact"); await physics_frame; Input.action_release("interact")
		text = await advance_dialogue(900)
		say("Abuelita tras E: '%s'" % text.left(50))
	check(s.has_flag("abuela_envia_cueva"), "La abuela no envía a volver a la cueva")
	# volver caminando por BackExit
	var back = lvl.get_node_or_null("BackExit")
	check(back != null, "La casa no tiene salida hacia atrás")
	back.travel(); await settle()
	lvl = current_scene
	say("tramo actual %d" % s.current_part)
	lvl.get_node("BackExit").travel(); await settle()
	lvl = current_scene
	say("tramo actual %d" % s.current_part)
	el = lvl.get_node("Elliot")
	var cap = lvl.get_node("Caperucita")
	say("Elliot x=%.0f; Caperucita x=%.0f visible=%s pending=%s" % [el.global_position.x, cap.global_position.x, str(cap.visible), str(cap.followup_pending())])
	var t2: String = await advance_dialogue(600)
	say("Caperucita habla sola: '%s'" % t2.left(60))
	if t2 == "":
		el.global_position.x = cap.global_position.x - 80.0
		t2 = await advance_dialogue(600)
		say("Caperucita tras acercarse: '%s'" % t2.left(60))
	check(t2 != "", "Caperucita no habla al volver (con la física real)")
	check(s.has_flag("caperucita_abre_cueva"), "Caperucita no abre la cueva")
	var riddle = lvl.get_node("CaveRiddle")
	check(riddle._active and riddle._zone.monitoring, "El acertijo de la cueva no se habilita")
	# ir al monolito y presionar E
	el.global_position.x = riddle.global_position.x + riddle.examine_position.x
	for i in 20: await physics_frame
	check(riddle._near, "Junto a la roca el jugador no queda dentro de su zona")
	var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
	Input.parse_input_event(ev)
	for i in 10: await process_frame
	check(riddle._layer != null, "E junto a la roca no abre el panel de anillos")
	print("GRANDMA_REAL failures=", failures)
	quit(1 if failures > 0 else 0)
