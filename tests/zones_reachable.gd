extends SceneTree
## Todas las zonas interactivas (NPC, carteles, disparadores) deben poder activarse con el jugador caminando por la línea del suelo.
## Caso real que lo motivó: Caperucita (escena 2) tenía la zona más arriba que los pies de Elliot y nunca hablaba al volver.
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Area2D and (c.collision_mask & 2) != 0 and c.monitoring and c.get_node_or_null("CollisionShape2D") != null and c.name != "Hitbox" and c.name != "DetectionArea" and c.name != "Hurtbox":
			out.append(c)
		collect(c, out)
func run() -> void:
	var s = root.get_node("GameSession")
	s.enabled = false; s.set_process(false)
	s.save_path = OS.get_temp_dir().path_join("ra-save.json"); s.progress_path = OS.get_temp_dir().path_join("ra-progress.json")
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("ra-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	for path in ["res://scenes/levels/cuento1_escena1.tscn","res://scenes/levels/cuento1_escena2.tscn","res://scenes/levels/cuento1_escena3.tscn","res://scenes/levels/cuento1_escena4.tscn"]:
		s.reset_progress(); s.current_part = -1
		var lvl = load(path).instantiate(); root.add_child(lvl); current_scene = lvl
		for i in 6: await process_frame
		var el = lvl.get_node("Elliot"); el.set_physics_process(false)
		var areas := []
		collect(lvl, areas)
		var bad := 0
		for a in areas:
			# Se saltan las zonas que ya se dispararon durante la propia prueba (apagan su monitoring) o que salieron del árbol.
			if a.get_script() == null or not is_instance_valid(a) or not a.is_inside_tree() or not a.monitoring: continue
			var cs := a.get_node("CollisionShape2D") as CollisionShape2D
			var path_node = lvl.get_node_or_null("WalkablePath")
			var foot_y: float = el.ground_position().y
			var gx: float = cs.global_position.x
			el.global_position.x = gx
			if path_node != null:
				var cc: Vector2 = path_node.constrain_foot(Vector2(gx, foot_y), 26.0)
				el.global_position.y += cc.y - foot_y
			for i in 3: await physics_frame
			var geo: bool = false
			if a.has_method("_geometric_in_range"): geo = a._geometric_in_range()
			elif a.has_method("_geometric_inside"): geo = a._geometric_inside()
			if not (el in a.get_overlapping_bodies()) and not geo:
				bad += 1
				failures += 1
				push_error("%s: la zona %s (%s) no se puede activar caminando (zona_y=%d, pies_y=%d)" % [path.get_file().get_basename(), String(a.name), a.get_script().resource_path.get_file(), int(cs.global_position.y), int(el.get_node("CollisionShape2D").global_position.y)])
		lvl.queue_free(); await process_frame
	print("ZONES_REACHABLE failures=", failures)
	quit(1 if failures > 0 else 0)
