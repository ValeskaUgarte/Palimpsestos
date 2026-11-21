extends SceneTree
# Verifica que cada animación del personaje use su escala fija (clip_scale) del Inspector.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures := 0
	for path in ["res://scenes/characters/player/Elliot.tscn", "res://scenes/characters/player/Jhon.tscn", "res://scenes/characters/player/Thomas.tscn"]:
		var hero = load(path).instantiate()
		root.add_child(hero)
		await process_frame
		hero.set_physics_process(false)   # que el controlador no cambie la animación durante la prueba
		var anim: AnimatedSprite2D = hero.get_node("AnimatedSprite2D")
		var table: Dictionary = hero.clip_scale
		for clip in ["idle", "walk", "attack_1", "attack_2", "finisher", "kick", "jump", "hurt"]:
			if not anim.sprite_frames.has_animation(clip) or anim.sprite_frames.get_frame_count(clip) == 0:
				continue
			anim.play(clip)
			anim.frame = 0
			hero._fit_pose()
			var expected: float = float(table[clip]) if table.has(clip) else float(table.get("idle", 1.0))
			var ok := absf(anim.scale.x - expected) < 0.001
			if not ok:
				failures += 1
			print("%-7s %-9s scale=%.4f esperado=%.4f %s" % [hero.name, clip, anim.scale.x, expected, "OK" if ok else "FALLA"])
		hero.queue_free()
		await process_frame
	print("CLIP_SCALE failures=", failures)
	quit(failures)
