extends SceneTree
## Encuentro con el Ranger (escena 1): dormido hasta el diálogo, la cámara lo muestra cuando grita, el jugador no se mueve
## durante la conversación, al terminar se lanza a pelear; al caer aparece la poción y Elliot se detiene a beberla.
var failures: int = 0
var saw_focus_cam: bool = false
var saw_locked: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func press_interact() -> void:
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)

# Avanza el diálogo abierto hasta que se cierra (y espera a que se abra si aún no lo hizo).
func finish_dialogue(elliot: Node, max_frames := 900) -> void:
	var dm = root.get_node("DialogueManager")
	var opened := false
	for i in max_frames:
		await physics_frame
		if dm.visible:
			opened = true
			if root.get_viewport().get_camera_2d() != null and root.get_viewport().get_camera_2d().name == "EncounterCamera":
				saw_focus_cam = true
			if elliot.input_locked:
				saw_locked = true
			dm.label.visible_characters = -1
			if OS.get_cmdline_user_args().has("--debug") and i % 6 == 0:
				print("DLG ", dm.label.text.left(50), " locked=", elliot.input_locked, " cam=", root.get_viewport().get_camera_2d().name)
			if i % 6 == 0:
				await press_interact()
		elif opened:
			return

func run() -> void:
	var s = root.get_node("GameSession")
	s.enabled = false
	s.set_process(false)
	s.save_path = OS.get_temp_dir().path_join("pal-enc-save.json")
	s.progress_path = OS.get_temp_dir().path_join("pal-enc-progress.json")
	s.reset_progress()
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("pal-enc-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	s.current_part = 0
	var level = load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for i in 10:
		await process_frame
	var elliot = level.get_node("Elliot")
	var ranger = level.get_node("RangerWood")
	check(ranger.dormant, "El Ranger no espera dormido su encuentro")
	# La narración de apertura sale sola al empezar: se deja terminar antes de ir al encuentro.
	await finish_dialogue(elliot, 240)
	saw_locked = false
	saw_focus_cam = false
	# Llega a la zona del grito.
	var trigger = level.get_node("Conv_HombreBosque")
	elliot.global_position.x = trigger.global_position.x
	await finish_dialogue(elliot)
	check(saw_locked, "El jugador se mueve durante el grito del Ranger")
	check(saw_focus_cam, "La cámara no muestra al Ranger cuando grita")
	await physics_frame
	check(not elliot.input_locked, "El jugador queda bloqueado tras el diálogo")
	check(not ranger.dormant and ranger.player == elliot, "El Ranger no despierta para pelear")
	check(root.get_viewport().get_camera_2d() == elliot.get_node("Camera2D"), "La cámara no vuelve a Elliot")
	# Derrota y poción.
	elliot.health.take_damage(300)
	var hurt_hp: int = elliot.health.current_health
	ranger.health.take_damage(99999)
	# Últimas palabras y comentario de la poción: se avanza hasta que Elliot empieza a beber.
	var dm = root.get_node("DialogueManager")
	var locked_on_potion := false
	var drank := false
	for i in 2400:
		await physics_frame
		if dm.visible:
			dm.label.visible_characters = -1
			if "pócima" in dm.label.text and elliot.input_locked:
				locked_on_potion = true
			if i % 6 == 0:
				await press_interact()
		if elliot._drink_time > 0.0:
			drank = true
			check(elliot.input_locked, "Elliot puede moverse mientras bebe")
		elif drank:
			break
	check(locked_on_potion, "Elliot no se detiene al encontrar la poción")
	check(drank, "Elliot no bebe la poción")
	await physics_frame
	check(elliot.health.current_health > hurt_hp, "La poción no recupera vida")
	check(not elliot.input_locked, "Elliot queda bloqueado después de beber")
	print("ENCOUNTERS failures=", failures)
	quit(1 if failures > 0 else 0)
