extends SceneTree
# Equipo jugable (scripts/systems/party.gd) en la escena 3: Elliot, Jhon y Thomas.
var failures: int = 0
var checked: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.get_node("GameSession").enabled = false
	root.get_node("AudioLandscape").shutdown()
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("palim-party-prefs.cfg")
	# Las introducciones de la escena (texto de los autores) ya vistas: un diálogo abierto bloquea el cambio de personaje.
	root.get_node("GameSession").set_flag("inicio:escena3")
	root.get_node("GameSession").set_flag("autores_inicio:escena3")
	var level = load("res://scenes/levels/cuento1_escena3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	await process_frame
	var party = level.get_node("Party")
	var elliot = level.get_node("Elliot")
	var jhon = level.get_node("Jhon")
	var thomas = level.get_node("Thomas")
	check(party.members.size() == 3, "Equipo debe tener 3 miembros en escena 3")
	check(party.active == elliot and elliot.is_in_group("player"), "Empieza controlando a Elliot")
	check(party.is_joined(jhon), "Jhon ya está en pantalla y se une al inicio")
	check(not party.is_joined(thomas), "Thomas aún no está en pantalla")
	# Thomas espera junto a la foto: aunque aparezca en pantalla NO se une hasta que termina su conversación.
	# A la derecha de Thomas y fuera de las zonas de conversación (S3_FotoAviso / S3_Aullido), para no abrir un diálogo que bloquee el cambio.
	elliot.global_position = Vector2(thomas.global_position.x - 40.0, elliot.global_position.y)
	for i in 90:
		await process_frame
	check(not party.is_joined(thomas), "Thomas no debe unirse antes de su encuentro")
	# Terminado el encuentro (bandera) se une al aparecer en pantalla.
	root.get_node("GameSession").set_flag("thomas_se_une")
	for i in 90:
		await process_frame
	check(party.is_joined(thomas), "Thomas se une tras su encuentro")
	# Tecla 2 -> Jhon.
	party._unhandled_input(_key(KEY_2))
	check(party.active == jhon, "Tecla 2 cambia a Jhon")
	check(jhon.is_in_group("player") and not jhon.is_companion, "Jhon pasa a ser el controlado")
	check(elliot.is_in_group("companion") and elliot.is_companion, "Elliot pasa a acompañante")
	check(party._camera.get_parent() != elliot, "La cámara ya no cuelga de Elliot")
	var cam = party._camera
	check(cam.get_parent() == jhon and cam.is_current(), "La cámara sigue al personaje activo")
	check(level.get_node("ForestAtmosphere").get("track") == jhon, "La neblina sigue al activo")
	# Curación al cambiar: Elliot herido, vuelve a ser activo y se cura 25%.
	var elliot_health = elliot.get_node("HealthComponent")
	elliot_health.current_health = 500
	party._unhandled_input(_key(KEY_1))
	check(party.active == elliot, "Tecla 1 vuelve a Elliot")
	check(elliot_health.current_health == 500 + roundi(elliot_health.max_health * party.SWITCH_HEAL_FRACTION), "Al cambiar se cura el 25% de la vida máxima")
	# Personaje caído: no se puede elegir.
	thomas.get_node("HealthComponent").take_damage(99999)
	await process_frame
	check(not party.is_alive(thomas), "Thomas cae")
	check(party.select(thomas) == false, "Un personaje caído no se puede elegir")
	party._unhandled_input(_key(KEY_3))
	check(party.active == elliot, "Tecla de un caído no cambia el control")
	# Activo cae: el control pasa a otro vivo, sin derrota.
	party.select(jhon)
	check(party.active == jhon, "Cambio a Jhon antes de la caída")
	jhon.get_node("HealthComponent").take_damage(99999)
	await process_frame
	await process_frame
	check(party.active == elliot and elliot.is_in_group("player"), "Al caer el activo, pasa el control a Elliot")
	check(not jhon.is_in_group("player") and not party.is_alive(jhon), "Jhon caído ya no controla")
	# Con todos caídos no hay cambio posible.
	elliot.get_node("HealthComponent").take_damage(99999)
	await process_frame
	check(not party.is_alive(elliot), "Elliot cae al final")
	print("PARTY_SWITCH checked=%d failures=%d" % [checked, failures])
	quit(1 if failures > 0 else 0)
func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event
