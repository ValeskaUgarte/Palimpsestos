extends SceneTree
## Casa de la abuelita (escena 2, tramo 6): se puede VOLVER atrás hasta Caperucita, los compañeros aparecen junto a Elliot
## en cada cambio de tramo y, tras hablar con la abuela y volver con Caperucita, su segunda conversación salta una sola vez
## y habilita el acertijo de la cueva (anillos) hasta resolverlo.
var failures: int = 0
const ESCENA2 := "res://scenes/levels/cuento1_escena2.tscn"
const HOUSE_PART := 5

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	await process_frame
	await process_frame
	var pages = root.get_node("ScenePages")
	var deadline := Time.get_ticks_msec() + 5000
	while pages.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame

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

func talk(npc: Node) -> String:
	var dialogue = root.get_node("DialogueManager")
	npc.player_in_range = true
	npc._started_this_visit = false
	npc._process(0)
	var first: String = dialogue.label.text if dialogue.visible else ""
	await finish_dialogue()
	npc.player_in_range = false
	return first

func load_part(index: int) -> Node:
	var session = root.get_node("GameSession")
	session.current_part = index
	var level = load(ESCENA2).instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	await process_frame
	return level

func companion_ok(level: Node, label: String, elliot_x: float, dir: float) -> void:
	var session = root.get_node("GameSession")
	var part: Dictionary = session.PARTS[session.current_part]
	var jhon = level.get_node("Jhon")
	var path = level.get_node("WalkablePath")
	var elliot = level.get_node("Elliot")
	var foot: Vector2 = jhon.ground_position()
	check(foot.x >= float(part.from) + 39.0 and foot.x <= float(part.to) - 39.0, "%s: Jhon dentro de la pared del tramo (x=%.0f)" % [label, foot.x])
	check(absf(foot.x - elliot_x) < 260.0 and absf(foot.x - elliot_x) > 40.0, "%s: Jhon no está junto a Elliot (dx=%.0f)" % [label, foot.x - elliot_x])
	check((foot.x - elliot.ground_position().x) * dir < 0.0, "%s: Jhon no queda detrás de Elliot" % label)
	var snapped: Vector2 = path.constrain_foot(foot, 26.0)
	check(snapped.distance_to(foot) < 2.0, "%s: Jhon fuera del camino (y=%.0f)" % [label, foot.y])

func run() -> void:
	var session = root.get_node("GameSession")
	session.enabled = false
	session.set_process(false)
	session.save_path = OS.get_temp_dir().path_join("palim-grandma-save.json")
	session.progress_path = OS.get_temp_dir().path_join("palim-grandma-progress.json")
	session.reset_progress()
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("palim-grandma-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	# 1) Tramo de la casa: salida hacia atrás y compañero junto a Elliot.
	var level = await load_part(HOUSE_PART)
	var part: Dictionary = session.PARTS[HOUSE_PART]
	var back = level.get_node_or_null("BackExit")
	check(back != null, "La casa de la abuelita no tiene salida hacia atrás")
	check(back != null and back.next_part == HOUSE_PART - 1 and (back.collision_mask & 2) != 0, "BackExit mal configurada")
	var elliot = level.get_node("Elliot")
	check(absf(elliot.global_position.x - float(part.start)) < 40.0, "Elliot no empieza en el inicio de la casa")
	check(float(part.start) - float(part.from) >= 200.0, "El inicio no deja espacio a los compañeros")
	companion_ok(level, "Casa (llegada)", elliot.ground_position().x, 1.0)
	# 2) Hablar con la abuela y comprobar que el acertijo aún NO responde.
	var abuelita = level.get_node("Abuelita")
	check(not session.has_flag("abuela_envia_cueva"), "Estado inicial sucio (abuela)")
	await talk(abuelita)
	check(session.has_flag("abuela_envia_cueva"), "Hablar con la abuela no la marca como enviada a la cueva")
	check(not session.has_flag("caperucita_abre_cueva"), "Caperucita no debería haber hablado aún")
	# 3) Volver CAMINANDO hacia la izquierda (física real): casa -> rastro de flores -> dos caminos.
	var pages = root.get_node("ScenePages")
	Input.action_press("move_left")
	for i in 900:
		await physics_frame
		if pages.busy or current_scene != level:
			break
	Input.action_release("move_left")
	var walked: bool = pages.busy or current_scene != level
	check(walked, "Caminar a la izquierda en la casa no cruza al tramo anterior (x=%.0f)" % elliot.global_position.x)
	if not walked:
		back.travel()
	await settle()
	level = current_scene
	check(session.current_part == HOUSE_PART - 1, "Salir por la izquierda no lleva al tramo anterior (%d)" % session.current_part)
	var part4: Dictionary = session.PARTS[HOUSE_PART - 1]
	elliot = level.get_node("Elliot")
	check(absf(elliot.global_position.x - (float(part4.to) - 260.0)) < 40.0, "Al volver, Elliot no aparece junto a la salida derecha (x=%.0f)" % elliot.global_position.x)
	check(level.get_node_or_null("BackExit") != null and level.get_node_or_null("SegmentExit") != null, "Faltan salidas en el tramo 5")
	companion_ok(level, "Rastro (vuelta)", elliot.ground_position().x, -1.0)
	level.get_node("BackExit").travel()
	await settle()
	level = current_scene
	check(session.current_part == HOUSE_PART - 2, "No se puede seguir volviendo hasta Caperucita (%d)" % session.current_part)
	elliot = level.get_node("Elliot")
	check(level.get_node_or_null("BackExit") == null, "El primer tramo de la escena no debe tener salida atrás")
	companion_ok(level, "Dos caminos (vuelta)", elliot.ground_position().x, -1.0)
	# 4) Caperucita: segunda conversación, una sola vez.
	var caperucita = level.get_node("Caperucita")
	var riddle = level.get_node("CaveRiddle")
	check(caperucita.followup_pending(), "La segunda conversación de Caperucita no está pendiente tras hablar con la abuela")
	check(not riddle._active and not riddle._zone.monitoring, "El acertijo no debe responder antes de hablar con Caperucita")
	var first: String = await talk(caperucita)
	check(first == caperucita.followup_lines[0].split("-", true, 1)[1] or first == caperucita.followup_lines[0], "Caperucita no dice su conversación nueva (dijo: %s)" % first)
	check(session.has_flag("caperucita_abre_cueva"), "La conversación no pone la bandera de la cueva")
	check(not caperucita.followup_pending(), "La segunda conversación sigue pendiente")
	check(riddle._active and riddle._zone.monitoring, "El acertijo de la cueva no se habilita")
	# No salta sola otra vez (sí se puede repetir con E: es repetible).
	var again: String = await talk(caperucita)
	check(again == "", "Caperucita vuelve a hablar sola (dijo: %s)" % again)
	# 5) El acertijo está disponible: E junto a la roca abre el panel; la salida se abre al resolver.
	var exit_cave = level.get_node("ExitCueva")
	check(not exit_cave.monitoring, "La cueva está abierta antes de resolver")
	riddle._on_zone_entered(level.get_node("Elliot"))
	check(riddle._near, "La roca no detecta a Elliot")
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	riddle._unhandled_input(interact)
	check(riddle._layer != null, "E junto a la roca no abre el panel de anillos")
	riddle._close_panel()
	riddle._solve()
	check(session.has_flag("cueva_resuelta"), "Resolver no marca la cueva")
	await create_timer(2.4).timeout
	check(exit_cave.monitoring, "Resolver no abre la salida de la cueva")
	# Pasa a la escena 3 con el compañero (no se queda atrás).
	level.queue_free()
	await process_frame
	session.reset_progress()
	print("GRANDMA_RETURN failures=", failures)
	session.quit_game(1 if failures else 0)
