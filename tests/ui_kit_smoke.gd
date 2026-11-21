extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, msg: String) -> void:
	if not ok: failures += 1; push_error(msg)
func run() -> void:
	root.get_node("GameSession").enabled=false
	root.get_node("LateralStory").enabled=false
	for path in ["res://scenes/main_menu.tscn","res://scenes/ui/settings_menu.tscn","res://scenes/ui/credits_menu.tscn"]:
		var ui: Node = load(path).instantiate()
		root.add_child(ui)
		for i in 5: await process_frame
		check(ui.get_child_count() > 2, path+" vacío")
		if path.ends_with("credits_menu.tscn"):
			await create_timer(1.0,true,false,true).timeout
			check(ui._scroll.scroll_vertical > 0, "Créditos no se desplazan")
		if path.ends_with("settings_menu.tscn"):
			var panel = load("res://scripts/ui/preferences_panel.gd").new()
			ui.add_child(panel)
			for i in 5: await process_frame
			check(panel.get_tree().get_nodes_in_group("preferences_panel").size()==1,"Panel de comodidad no existe")
		ui.queue_free()
		await process_frame
	var level: Node = load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(level); current_scene = level
	for i in 4: await physics_frame
	check(level.get_node_or_null("ForestFrame") != null, "Falta el marco en el cuento")
	var pause = level.get_node("PauseMenu")
	check(pause.get_node("VBoxContainer").get_child(0) is TextureRect, "Pausa sin banner")
	level.queue_free()
	await process_frame
	# lateral: rechazar el encuentro no debe reabrirlo
	var flow = root.get_node("LateralStory")
	flow.new_game()
	for i in 40:
		await create_timer(0.25,true,false,true).timeout
		if current_scene != null and current_scene.has_method("request_encounter"): break
	var world = current_scene
	check(get_nodes_in_group("enemy").size() >= 5, "No aparecen las oleadas de enemigos")
	world.set_process(false)
	var enc = load("res://resources/lateral/encounters/forest.tres")
	world.request_encounter(enc)
	check(world._pending_encounter != null, "El encuentro no se solicita")
	world._open_encounter(enc.encounter_id)
	check(paused, "Panel no pausa")
	world._decline_encounter()
	check(not paused and world._pending_encounter == null, "Rechazar no libera")
	world.request_encounter(enc)
	check(world._pending_encounter == null, "El encuentro vuelve a interrumpir")
	print("UI_SMOKE failures=", failures)
	quit(failures)
