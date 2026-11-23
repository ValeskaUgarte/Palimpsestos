extends SceneTree
## Escena 3: Thomas espera junto a la foto familiar; al llegar Elliot se muestra la foto como un anuncio, hay una conversación corta
## con Jhon y Elliot y Thomas se une. Ethan está donde ocurre su diálogo y habla (animación talk).
var failures: int = 0
var poster_seen: bool = false
const ESC := "res://scenes/levels/cuento1_escena3.tscn"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func finish_dialogue(max_frames := 1200) -> Array:
	var dm = root.get_node("DialogueManager")
	var lines: Array = []
	var last := ""
	var gap := 0
	for i in max_frames:
		await physics_frame
		if dm.visible:
			gap = 0
			if root.get_node("Mochila").poster_open():
				poster_seen = true
			if dm.label.text != last:
				last = dm.label.text
				lines.append(last)
			dm.label.visible_characters = -1
			var press := InputEventAction.new(); press.action = "interact"; press.pressed = true
			Input.parse_input_event(press)
			await process_frame
			var rel := InputEventAction.new(); rel.action = "interact"; rel.pressed = false
			Input.parse_input_event(rel)
		elif not lines.is_empty():
			gap += 1
			if gap > 30:
				break
	return lines

func run() -> void:
	var s = root.get_node("GameSession")
	s.enabled = false
	s.set_process(false)
	s.save_path = OS.get_temp_dir().path_join("pal-tp-save.json")
	s.progress_path = OS.get_temp_dir().path_join("pal-tp-progress.json")
	s.reset_progress()
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("pal-tp-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	s.current_part = 6
	var level = (load(ESC) as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	for i in 10:
		await process_frame
	var elliot = level.get_node("Elliot")
	var thomas = level.get_node("Thomas")
	var party = root.get_node("Party") if root.has_node("Party") else null
	# Thomas espera junto a la foto (no sale a buscar a Elliot desde lejos).
	check(absf(thomas.global_position.x - 2860.0) < 8.0, "Thomas no espera junto a la foto (x=%.0f)" % thomas.global_position.x)
	check(thomas.companion_wait_for_flag == "thomas_se_une", "Thomas no espera su encuentro")
	check(not s.has_flag("thomas_se_une"), "Estado inicial sucio")
	# Elliot llega a la zona de la foto con la física real.
	elliot.global_position.x = 2560.0
	var lines := await finish_dialogue()
	check(lines.size() == 5, "La conversación de la foto debe tener 5 líneas (tiene %d)" % lines.size())
	check(s.has_flag("thomas_se_une"), "Al terminar la conversación Thomas no se une")
	check(poster_seen, "La foto no se mostró como un anuncio durante la conversación")
	await create_timer(0.5, true, false, true).timeout
	check(not root.get_node("Mochila").poster_open(), "La foto sigue en pantalla al terminar")
	var x0: float = thomas.global_position.x
	Input.action_press("move_left")
	for i in 90:
		await physics_frame
	Input.action_release("move_left")
	check(absf(thomas.global_position.x - x0) > 20.0, "Thomas no sigue al grupo tras unirse (x=%.0f)" % thomas.global_position.x)
	# Ethan: está donde ocurre su diálogo y habla.
	var ethan = level.get_node("Ethan")
	var intro = level.get_node("ThomasIntro")
	check(absf(ethan.global_position.x - intro.global_position.x) < 260.0, "Ethan no está donde ocurre su diálogo (ethan x=%.0f, diálogo x=%.0f)" % [ethan.global_position.x, intro.global_position.x])
	elliot.global_position.x = intro.global_position.x
	var l2 := await finish_dialogue(1800)
	check(l2.size() == 7, "La conversación de Thomas y Ethan debe tener 7 líneas (tiene %d)" % l2.size())
	elliot.global_position.x = intro.global_position.x
	for i in 20:
		await process_frame
	check(ethan.get_node("Motion").animation == &"talk", "Ethan no usa la animación talk (usa %s)" % str(ethan.get_node("Motion").animation))
	print("THOMAS_PHOTO failures=", failures)
	quit(1 if failures > 0 else 0)
