extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.get_node("GameSession").enabled = false
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("palim-combat-base-prefs.cfg")
	var level = load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for actor in level.get_children():
		if actor is CharacterBody2D: actor.set_physics_process(false)
	var p = level.get_node("Elliot")
	var e = level.get_node("RangerWood")
	var victim = e.get_node("Hurtbox")
	var frames: SpriteFrames = p.anim.sprite_frames.duplicate(true)
	p.anim.sprite_frames = frames
	# A production-sized test clip: changing pose count needs no player code change.
	if frames.has_animation(&"attack_1"):
		frames.remove_animation(&"attack_1")   # Elliot ya trae su clip real; la prueba lo reemplaza por uno de 10 poses
	frames.add_animation(&"attack_1")
	frames.set_animation_loop(&"attack_1", false)
	frames.set_animation_speed(&"attack_1", 20)
	for i in 10: frames.add_frame(&"attack_1", frames.get_frame_texture(&"attack", mini(i / 3, 3)))
	p._do_hit("attack")
	p.anim.pause()
	p.anim.set_frame_and_progress(4, 0)
	p._on_attack_pose()
	await physics_frame
	check(p.attack_phase == &"windup" and p.hitbox_shape.disabled, "10 poses: contacto antes del marcador")
	p.anim.set_frame_and_progress(5, 0)
	p._on_attack_pose()
	await physics_frame
	await physics_frame
	check(p.attack_phase == &"contact" and not p.hitbox_shape.disabled, "10 poses: contacto no abre")
	var before: int = e.health.current_health
	p._on_hitbox_area_entered(victim)
	p._on_hitbox_area_entered(victim)
	check(e.health.current_health == before - p.punch_damage, "Ventana golpea dos veces al mismo objetivo")
	# Closing and reopening the window must not reset per-attack target protection.
	p.anim.set_frame_and_progress(8, 0)
	p._on_attack_pose()
	await physics_frame
	check(p.attack_phase == &"recovery" and p.hitbox_shape.disabled, "Recuperación sigue causando daño")
	p.anim.set_frame_and_progress(5, 0)
	p._on_attack_pose()
	await physics_frame
	p._on_hitbox_area_entered(victim)
	check(e.health.current_health == before - p.punch_damage, "Reentrada repite daño")
	p._end_attack()
	p.facing = Vector2.LEFT
	p._do_hit("attack")
	p.anim.pause()
	check(p.hitbox.position.x < p.get_node("CollisionShape2D").position.x, "Hitbox izquierda incorrecta")
	check(p._attack_profile == p.attack_2_profile, "Segundo ataque no usa su perfil")
	p._end_attack()
	p._do_hit("attack")
	p.anim.pause()
	check(p.active_hit_finisher and p._attack_profile == p.finisher_profile, "Tercer ataque no es finisher")
	check(p.active_hit_damage == p.punch_damage + p.combo_damage_bonus, "Balance del finisher alterado")
	check(p._attack_profile.advance_pixels > p.attack_1_profile.advance_pixels, "Finisher carece de avance propio")
	p._end_attack()
	p.facing = Vector2.RIGHT
	p._do_hit("kick")
	p.anim.pause()
	check(p.hitbox_shape.shape.size.x > p.attack_1_profile.hitbox_size.x, "Patada no tiene alcance propio")
	check(p.active_hit_damage == p.kick_damage, "Daño patada cambiado")
	var foot: Vector2 = p.ground_position()
	# Avance entre 15% y contact_end del clip: se elige el fotograma según la cantidad real de poses de la patada.
	p.anim.set_frame_and_progress(int(p.anim.sprite_frames.get_frame_count(p.anim.animation) * 0.3), 0)
	p._physics_process(0.016)
	check(p.ground_position().x > foot.x and is_equal_approx(p.ground_position().y, foot.y), "Avance no es lateral sobre suelo")
	p._end_attack()
	# Actual physics overlap: already inside the area when contact opens.
	p.combo_step = 0
	p._do_hit("attack")
	p.anim.pause()
	e.global_position += p.hitbox_shape.global_position - victim.get_node("CollisionShape2D").global_position
	before = e.health.current_health
	await physics_frame
	await physics_frame
	check(e.health.current_health == before, "Superposición en anticipación causa daño")
	p.anim.set_frame_and_progress(5, 0)
	p._on_attack_pose()
	await physics_frame
	await physics_frame
	await physics_frame
	check(e.health.current_health == before - p.punch_damage, "Contacto físico inicial no registra impacto")
	p._physics_process(0.001)
	check(e.health.current_health == before - p.punch_damage, "Polling duplica contacto físico")
	p._end_attack()
	# The same opponent on the wrong side must not be struck.
	p.facing = Vector2.LEFT
	p._do_hit("attack")
	p.anim.pause()
	before = e.health.current_health
	p.anim.set_frame_and_progress(2, 0)
	p._on_attack_pose()
	await physics_frame
	await physics_frame
	await physics_frame
	p._physics_process(0.001)
	check(e.health.current_health == before, "Golpe izquierdo alcanza enemigo a la derecha")
	p._end_attack()
	# Empty attack clips keep windup and recover, instead of opening a permanent hitbox.
	var saved_frames: SpriteFrames = p.anim.sprite_frames
	var empty_frames := SpriteFrames.new()
	empty_frames.add_animation("idle")
	empty_frames.add_frame("idle", frames.get_frame_texture("idle", 0))
	p.anim.sprite_frames = empty_frames
	p.combo_step = 0
	p._do_hit("attack")
	check(p._fallback_attack and not p._contact_active, "Fallback abre golpe inmediatamente")
	p._physics_process(0.51)
	check(not p.is_attacking and p.hitbox_shape.disabled, "Fallback no recupera control")
	p.anim.sprite_frames = saved_frames
	# Weighted durations must determine the marker, not frame_index/count.
	frames.set_frame(&"attack_1", 0, frames.get_frame_texture(&"attack_1", 0), 5.0)
	p.combo_step = 0
	p._do_hit("attack")
	p.anim.pause()
	p.anim.set_frame_and_progress(3, 0)
	p._on_attack_pose()
	check(p.attack_phase == &"contact", "Duraciones ponderadas ignoradas")
	p._end_attack()
	await create_timer(0.2, false, false, true).timeout
	p.take_damage(1, p.ground_position() - Vector2(30, 150))
	check(p._hurt_presentation_time > 0 and p._damage_recoil != 0, "Elliot sin reacción al daño")
	check(p.knockback.y == 0 and p.jump_height == 0, "Daño eleva Elliot")
	p._physics_process(0.2)
	check(p._hurt_presentation_time == 0, "Hurt no devuelve control")
	p.combo_step = 0
	p._do_hit("attack")
	var phase = p.attack_phase
	var frame: int = p.anim.frame
	paused = true
	await create_timer(0.1, true, false, true).timeout
	check(p.anim.frame == frame and p.attack_phase == phase, "Pausa avanza ataque")
	paused = false
	p._end_attack()
	for cue in [&"attack_swing", &"attack_hit", &"kick_swing", &"kick_hit", &"finisher_hit", &"player_hurt"]:
		check(root.get_node("AudioLandscape").bank.interactions.has(cue), "Hook audio ausente: " + String(cue))
	p.take_damage(10000)
	await process_frame
	await physics_frame
	check(p._dead and not p.is_attacking and p.hitbox_shape.disabled and p.jump_height == 0, "Muerte conserva ofensiva/altura")
	paused = false
	level.queue_free()
	await process_frame
	print("ELLIOT_COMBAT_BASE failures=", failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
