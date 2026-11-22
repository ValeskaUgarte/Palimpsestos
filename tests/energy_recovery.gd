extends SceneTree
# Energía (barra 'Energía' del HUD = 100 - cansancio): se gasta con el esfuerzo y se recupera quieto.

var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var gs = root.get_node("GameSession")
	var ps = root.get_node("PlayerStatus")
	gs.enabled = false
	var scene = load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	root.get_node("DialogueManager").visible = false
	var hero = get_first_node_in_group("player")
	hero.set_physics_process(false)
	hero.velocity = Vector2.ZERO
	# 1) Descansado: energía llena.
	gs.progress["status"] = {"fatiga": 0.0, "miedo": 0.0}
	check(is_equal_approx(ps.energy(), 100.0), "Energía inicial debe ser 100")
	# 2) Peleando 6 s, la energía baja bastante.
	hero.is_attacking = true
	await _seconds(6.0)
	hero.is_attacking = false
	var after_fight: float = ps.energy()
	# Ventana amplia: el tiempo real de la prueba varía según la máquina (cuadros por segundo).
	check(after_fight < 60.0, "Pelear 6 s debe gastar energía (queda %.1f)" % after_fight)
	# 3) Efectos: agotado = más lento y más débil.
	gs.progress["status"] = {"fatiga": 90.0, "miedo": 0.0}
	check(ps.speed_multiplier(hero) < 0.8, "Agotado debe frenar")
	check(ps.damage_out(20, hero, false) < 20, "Agotado debe pegar más flojo")
	# 4) Quieto: de energía vacía a llena en 8-10 s.
	gs.progress["status"] = {"fatiga": 100.0, "miedo": 0.0}
	hero.velocity = Vector2.ZERO
	await _seconds(4.0)
	var mid: float = ps.energy()
	check(mid > 15.0 and mid < 80.0, "A los 4 s quieto debe llevar un tramo intermedio de la barra (lleva %.1f)" % mid)
	await _seconds(6.0)
	check(ps.energy() >= 99.0, "Tras 10 s quieto debe estar llena (lleva %.1f)" % ps.energy())
	# 5) Caminando NO recupera (sube despacio); atacar corta el descanso.
	gs.progress["status"] = {"fatiga": 50.0, "miedo": 0.0}
	for i in 120:
		hero.velocity = Vector2(160, 0)
		await process_frame
	check(ps.energy() < 50.0, "Caminar no debe recuperar energía (%.1f)" % ps.energy())
	hero.velocity = Vector2.ZERO
	var before: float = ps.energy()
	hero.is_attacking = true
	await _seconds(1.0)
	hero.is_attacking = false
	check(ps.energy() < before, "Atacar no debe recuperar")
	# 6) La barra del HUD muestra energía (llena = descansado).
	await _seconds(1.3)  # pasa la pausa de pelea (FIGHT_GRACE)
	gs.progress["status"] = {"fatiga": 0.0, "miedo": 0.0}
	await _seconds(0.3)
	var hud = scene.get_node_or_null("HUD")
	if hud != null and hud._fatigue_bar != null:
		check(hud._fatigue_bar.value >= 99.0, "La barra debe estar llena si está descansado (%.1f, fatiga %.1f)" % [hud._fatigue_bar.value, ps.fatigue()])
		gs.progress["status"] = {"fatiga": 100.0, "miedo": 0.0}
		hero.is_attacking = true
		await process_frame
		await process_frame
		hero.is_attacking = false
		check(hud._fatigue_bar.value < 5.0, "La barra debe estar vacía si está agotado (%.1f)" % hud._fatigue_bar.value)
	else:
		push_warning("sin HUD en la escena")
	print("failures=", failures)
	quit(failures)

func _seconds(t: float) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < t:
		await process_frame
