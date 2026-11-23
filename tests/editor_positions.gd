extends SceneTree
## Las posiciones puestas a mano en el editor se respetan en el primer tramo de cada escena (nada recoloca a Elliot ni a los
## aliados). En un tramo que empieza a mitad de la escena sí se coloca solo (la posición del editor no corresponde ahí).
var failures: int = 0
const ESCENA2 := "res://scenes/levels/cuento1_escena2.tscn"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func load_level(part: int, move_actors: bool) -> Node:
	var session = root.get_node("GameSession")
	session.current_part = part
	var level: Node = (load(ESCENA2) as PackedScene).instantiate()
	if move_actors:
		level.get_node("Elliot").position.x = 1200.0
		level.get_node("Jhon").position.x = 1000.0
	root.add_child(level)
	current_scene = level
	await process_frame
	await process_frame
	await process_frame
	return level

func run() -> void:
	var session = root.get_node("GameSession")
	session.enabled = false
	session.set_process(false)
	session.save_path = OS.get_temp_dir().path_join("pal-ep-save.json")
	session.progress_path = OS.get_temp_dir().path_join("pal-ep-progress.json")
	session.reset_progress()
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("pal-ep-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	# Primer tramo de la escena 2: manda el editor.
	var level = await load_level(3, true)
	check(absf(level.get_node("Elliot").global_position.x - 1200.0) < 2.0, "Elliot fue recolocado en el primer tramo (x=%.0f)" % level.get_node("Elliot").global_position.x)
	# Tolerancia amplia: el aliado camina hacia Elliot por su IA de seguimiento; lo que no debe pasar es que lo coloquen "teletransportado" junto a Elliot.
	check(absf(level.get_node("Jhon").global_position.x - 1000.0) < 150.0, "Jhon fue recolocado en el primer tramo (x=%.0f)" % level.get_node("Jhon").global_position.x)
	level.queue_free()
	await process_frame
	# Tramo a mitad de escena: colocación automática (junto al inicio del tramo).
	level = await load_level(4, true)
	var part: Dictionary = session.PARTS[4]
	check(absf(level.get_node("Elliot").global_position.x - float(part.start)) < 40.0, "En un tramo intermedio Elliot debe empezar en el inicio del tramo (x=%.0f)" % level.get_node("Elliot").global_position.x)
	# Con auto_place_party activado, también en el primer tramo.
	level.queue_free()
	await process_frame
	session.current_part = 3
	var forced: Node = (load(ESCENA2) as PackedScene).instantiate()
	forced.auto_place_party = true
	forced.get_node("Elliot").position.x = 1200.0
	root.add_child(forced)
	current_scene = forced
	await process_frame
	await process_frame
	check(absf(forced.get_node("Elliot").global_position.x - float(session.PARTS[3].start)) < 40.0, "auto_place_party=true debe colocar a Elliot en el inicio del tramo")
	print("EDITOR_POSITIONS failures=", failures)
	quit(1 if failures > 0 else 0)
