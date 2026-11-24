extends SceneTree
## Saltar de escena desde el mapa en plena pelea (enemigo a mitad de su golpe, Elliot recién derribado) no debe dar errores:
## los ataques y esperas pendientes se cancelan solos al salir la escena del árbol. También vuelve la velocidad normal.
var errors_before: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var s = root.get_node("GameSession")
	s.enabled = false
	s.set_process(false)
	s.save_path = OS.get_temp_dir().path_join("pal-jump-save.json")
	s.progress_path = OS.get_temp_dir().path_join("pal-jump-progress.json")
	s.reset_progress()
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("pal-jump-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	var failures := 0
	for jump in [3, 6, 8]:
		s.current_part = 0
		var lvl = load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
		root.add_child(lvl)
		current_scene = lvl
		for i in 10:
			await process_frame
		var el = lvl.get_node("Elliot")
		var e = lvl.get_node("RangerWood")
		el.global_position.x = e.ground_position().x - 300.0
		e.engage(el)
		# Espera a que el Ranger esté a mitad de su golpe.
		for i in 600:
			await physics_frame
			if e.is_attacking:
				break
		await create_timer(0.1).timeout
		Engine.time_scale = 0.55   # como si estuviera en la transición de derrota
		# Como el mapa: se abre encima del juego (pausa) y desde ahí se salta a otra escena.
		var hud = lvl.get_node_or_null("HUD")
		if jump == 6 and hud != null and hud.has_method("_on_map_pressed"):
			hud._on_map_pressed()
		await create_timer(0.3, true).timeout
		s.enter_part(jump)
		var pages = root.get_node("ScenePages")
		for i in 600:
			await process_frame
			if not pages.busy and current_scene != lvl and current_scene != null:
				break
		for i in 120:
			await physics_frame
		if not is_equal_approx(Engine.time_scale, 1.0):
			failures += 1
			push_error("La escena nueva quedó en cámara lenta")
		if current_scene == lvl or current_scene == null:
			failures += 1
			push_error("No se pudo saltar a la escena %d" % jump)
		if current_scene != null:
			current_scene.queue_free()
		await process_frame
	print("SCENE_JUMP_MIDCOMBAT failures=", failures)
	quit(1 if failures > 0 else 0)
