extends SceneTree
## Los diálogos AUTOMÁTICOS (NPC con auto_start y narraciones/conversaciones de StoryTrigger) no se repiten al recargar el
## tramo: lo ya visto se guarda en la sesión (GameSession.progress["seen"], clave = escena + nodo + hash del texto).
## Los NPC repetibles siguen disponibles con E, pero ya no empiezan solos. Una partida nueva lo olvida todo.
var failures: int = 0
const ESCENA2 := "res://scenes/levels/cuento1_escena2.tscn"
const ESCENA3 := "res://scenes/levels/cuento1_escena3.tscn"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func finish_dialogue() -> void:
	var dialogue = root.get_node("DialogueManager")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	for i in 40:
		if not dialogue.visible:
			break
		dialogue.label.visible_characters = -1
		dialogue._unhandled_input(event)
		await process_frame
	await process_frame
	await process_frame

func load_level(part: int, path: String = ESCENA2) -> Node:
	var session = root.get_node("GameSession")
	session.current_part = part
	var level = load(path).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	await process_frame
	return level

func unload(level: Node) -> void:
	level.queue_free()
	await process_frame
	await process_frame

# true si el NPC empieza a hablar solo al entrar en su zona (sin pulsar E).
func auto_talks(npc: Node) -> bool:
	var dialogue = root.get_node("DialogueManager")
	npc.player_in_range = true
	npc._started_this_visit = false
	npc._process(0)
	var talked: bool = dialogue.visible
	if talked:
		await finish_dialogue()
	npc.player_in_range = false
	return talked

# true si, pulsando E dentro de su zona, el NPC habla.
func talks_on_demand(npc: Node) -> bool:
	var dialogue = root.get_node("DialogueManager")
	npc.player_in_range = true
	npc._started_this_visit = true
	await process_frame
	Input.action_press("interact")
	npc._process(0)
	Input.action_release("interact")
	var talked: bool = dialogue.visible
	if talked:
		await finish_dialogue()
	npc.player_in_range = false
	return talked

func walk_into(level: Node, trigger: Node) -> bool:
	var dialogue = root.get_node("DialogueManager")
	var elliot = level.get_node("Elliot")
	elliot.global_position.x = trigger.global_position.x
	for i in 6:
		await physics_frame
		if dialogue.visible:
			break
	var shown: bool = dialogue.visible
	if shown:
		await finish_dialogue()
	return shown

func run() -> void:
	var session = root.get_node("GameSession")
	session.enabled = true
	session.set_process(false)
	session.save_path = OS.get_temp_dir().path_join("palim-norepeat-save.json")
	session.progress_path = OS.get_temp_dir().path_join("palim-norepeat-progress.json")
	session.reset_progress()
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("palim-norepeat-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	# --- Primera visita al tramo 4 (escena 2, "Dos caminos"): todo se dice una vez.
	var level = await load_level(3)
	var ethan = level.get_node("Ethan")
	var trigger = level.get_node("S2_EncuentroJhon")
	check(ethan.repeatable and ethan.auto_start, "Ethan debería ser repetible con auto_start (pista)")
	check(await auto_talks(ethan), "Ethan no habla solo la primera vez")
	check(await walk_into(level, trigger), "La conversación del encuentro no salta la primera vez")
	check(trigger._triggered, "El disparador no queda marcado")
	# --- Recarga del tramo: ni NPC ni disparador se repiten solos.
	await unload(level)
	level = await load_level(3)
	ethan = level.get_node("Ethan")
	trigger = level.get_node("S2_EncuentroJhon")
	check(trigger._triggered, "El disparador visto no se recuerda al recargar")
	check(not await auto_talks(ethan), "Ethan vuelve a hablar solo tras recargar el tramo")
	check(not await walk_into(level, trigger), "La conversación del encuentro se repite al recargar")
	# Un NPC repetible sigue hablando a demanda con E.
	check(await talks_on_demand(ethan), "Ethan (repetible) ya no habla con E")
	# --- Un NPC NO repetible (Stephy, escena 3) tampoco se repite del todo.
	await unload(level)
	level = await load_level(7, ESCENA3)
	var stephy = level.get_node("Stephy")
	check(not stephy.repeatable, "Stephy debería ser no repetible")
	check(await auto_talks(stephy), "Stephy no habla sola la primera vez")
	await unload(level)
	level = await load_level(7, ESCENA3)
	stephy = level.get_node("Stephy")
	check(not await auto_talks(stephy), "Stephy vuelve a hablar sola")
	check(not await talks_on_demand(stephy), "Stephy repite una conversación ya hecha")
	# --- Persistencia: va al fichero de progreso y se recupera al continuar.
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(session.progress_path))
	check(saved.has("seen") and (saved["seen"] as Dictionary).size() >= 3, "El progreso guardado no incluye los diálogos vistos")
	var remembered: int = session.progress["seen"].size()
	session.progress["seen"] = {}
	session.load_progress()
	check(session.progress["seen"].size() == remembered, "Continuar no recupera los diálogos vistos")
	# --- Partida nueva: se olvida todo y vuelven a salir.
	await unload(level)
	session.reset_progress()
	check(session.progress["seen"].is_empty(), "Partida nueva conserva diálogos vistos")
	level = await load_level(3)
	check(not level.get_node("S2_EncuentroJhon")._triggered, "Partida nueva conserva el disparador visto")
	check(await auto_talks(level.get_node("Ethan")), "Partida nueva: Ethan no vuelve a hablar")
	await unload(level)
	session.reset_progress()
	print("DIALOGUE_NO_REPEAT failures=", failures)
	session.quit_game(1 if failures else 0)
