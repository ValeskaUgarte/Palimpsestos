extends SceneTree
# Caminar sube el cansancio despacio (solo quedarse quieto recupera; ver energy_recovery.gd).
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gs = root.get_node("GameSession")
	var ps = root.get_node("PlayerStatus")
	gs.enabled = false
	var scene = load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var dm = root.get_node("DialogueManager")
	var hero = get_first_node_in_group("player")
	print("dialogo abierto al inicio: ", dm.visible)
	dm.visible = false   # cerrar el diálogo de apertura
	hero.set_physics_process(false)
	gs.progress["status"] = {"fatiga": 50.0, "miedo": 0.0, "sellos": {}}
	var start: float = ps.fatigue()
	for i in 300:   # ~5 s a 60 fps
		hero.velocity = Vector2(160, 0)
		await physics_frame
		if i % 60 == 0: print("t=", i, " fatiga=", ps.fatigue(), " dialogo=", dm.visible)
	var end: float = ps.fatigue()
	var mid: float = ps.fatigue()
	print("still=", ps.get("_still_time"), " since_attack=", ps.get("_since_attack"), " fight=", ps.get("_fight_time"), " vel=", hero.velocity, " combo_temp=", ps.get("combo_temp_left"))
	print("process_frames_ok")
	print("hero=", hero.name, " is_attacking=", hero.get("is_attacking"), " is_jumping=", hero.get("is_jumping"))
	print("cansancio inicio=%.2f fin=%.2f cambio=%.2f en 5 s (esperado ~ +4.0)" % [start, end, end - start])
	var walk_ok := absf((end - start) - 4.0) < 1.0
	print("caminar 5 s: cambio=%.2f esperado=+4.00 %s" % [end - start, "OK" if walk_ok else "FALLA"])
	quit(0 if walk_ok else 1)
