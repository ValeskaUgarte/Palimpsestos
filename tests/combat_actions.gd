extends SceneTree
## Acciones de combate nuevas: bloqueo (menos daño), caída por golpe fuerte y levantarse, correr, enemigo dormido que
## despierta y embiste (encuentros), y tamaño parejo entre animaciones (CharacterFrames.character_height).
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func visible_height(sprite: AnimatedSprite2D) -> float:
	var m: Dictionary = SpriteFit.metrics(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame))
	return float(int(m["bottom"]) - int(m["top"])) * sprite.scale.y

func run() -> void:
	var s = root.get_node("GameSession")
	s.enabled = false
	s.set_process(false)
	s.save_path = OS.get_temp_dir().path_join("pal-ca-save.json")
	s.progress_path = OS.get_temp_dir().path_join("pal-ca-progress.json")
	s.reset_progress()
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("pal-ca-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	s.current_part = -1
	var level = load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for i in 8:
		await process_frame
	var p = level.get_node("Elliot")
	var e = level.get_node("RangerWood")

	# Tamaño parejo: todas las animaciones del Ranger miden lo mismo (su primer cuadro = character_height).
	var cf: CharacterFrames = e.visual.sprite_frames as CharacterFrames
	check(cf != null and cf.character_height > 0.0, "El Ranger no usa CharacterFrames")
	var heights: Array = []
	for clip in [&"idle", &"walk", &"attack", &"hurt"]:
		e._play_animation(clip)
		e.visual.pause()
		e.visual.frame = 0
		e._apply_frame_alignment()
		heights.append(visible_height(e.visual))
	for h in heights:
		check(absf(h - cf.character_height) < 2.0, "Ranger: animación con alto distinto (%.1f, esperado %.1f)" % [h, cf.character_height])

	# Bloqueo: de frente pasa solo una parte del daño y no derriba.
	p.facing = Vector2.RIGHT
	p.is_blocking = true
	var hp: int = p.health.current_health
	p.take_heavy_hit(40, p.ground_position() + Vector2(100, 0))
	check(hp - p.health.current_health <= int(ceil(40 * p.block_damage_factor)) + 1, "El bloqueo no reduce el daño")
	check(not p.is_knocked_down(), "Un golpe bloqueado derriba")
	p.is_blocking = false

	# Golpe fuerte sin bloquear: cae, se queda en el suelo y se levanta.
	hp = p.health.current_health
	p.take_heavy_hit(10, p.ground_position() + Vector2(100, 0))
	check(p.is_knocked_down(), "El golpe fuerte no derriba")
	check(p.knockback.x < 0.0, "La caída no empuja hacia atrás")
	var phases := {}
	for i in 240:
		await physics_frame
		phases[p._knockdown_phase] = true
		if not p.is_knocked_down():
			break
	check(phases.has(2) and phases.has(3), "La caída no pasa por 'en el suelo' y 'levantándose'")
	check(not p.is_knocked_down(), "No se levanta tras la caída")

	# Correr: más rápido que caminar.
	Input.action_press("move_right")
	for i in 40:
		await physics_frame
	var walk_speed: float = absf(p._locomotion.x)
	Input.action_press("run")
	for i in 40:
		await physics_frame
	var run_speed: float = absf(p._locomotion.x)
	Input.action_release("run")
	Input.action_release("move_right")
	check(run_speed > walk_speed * 1.4, "Correr no es más rápido (caminar %.0f, correr %.0f)" % [walk_speed, run_speed])

	# Enemigo dormido: no persigue hasta engage(); luego corre hacia el jugador.
	e.dormant = true
	e.player = null
	e.global_position = p.global_position + Vector2(700, 0)
	for i in 30:
		await physics_frame
	check(e.player == null, "Un enemigo dormido persigue al jugador")
	var gap: float = absf(e.global_position.x - p.global_position.x)
	e.engage(p)
	for i in 30:
		await physics_frame
	check(absf(e.global_position.x - p.global_position.x) < gap - 60.0, "engage() no lanza al enemigo hacia el jugador")

	# El Ranger de la escena 1 (cuerpo corrido en el editor) tiene que poder golpear al jugador.
	e.heavy_attack_chance = 0.0
	var before: int = p.health.current_health
	for i in 600:
		await physics_frame
		if p.health.current_health < before:
			break
	check(p.health.current_health < before, "El Ranger no logra golpear al jugador")

	print("COMBAT_ACTIONS failures=", failures)
	quit(1 if failures > 0 else 0)
