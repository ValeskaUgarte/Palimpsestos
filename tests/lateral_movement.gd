extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
func ticks(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	root.get_node("GameSession").enabled = false
	root.get_node("GamePreferences").config_path = "/private/tmp/palim-lateral-prefs.cfg"
	var scene = load("res://scenes/prototypes/lateral_movement.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var p = scene.get_node("Elliot")
	await ticks(5)
	check(p.is_on_floor() and absf(p.position.y - 500) < 1, "Suelo físico no sostiene cuerpo")
	Input.action_press("move_up")
	Input.action_press("move_down")
	await ticks(12)
	check(absf(p.position.y - 500) < 1, "W/S modifican altura")
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_press("move_right")
	await ticks(12)
	check(p.position.x > 310, "Movimiento lateral no responde")
	Input.action_release("move_right")
	await ticks(12)
	Input.action_press("jump")
	var min_y: float = 500
	for i in 60:
		await physics_frame
		min_y = minf(min_y, p.position.y)
	check(min_y < 430 and min_y > 400, "Altura de salto físico fuera del rango nominal")
	check(p.is_on_floor(), "Mantener salto produce autojump o no aterriza")
	Input.action_release("jump")
	await ticks(3)
	Input.action_press("jump")
	await ticks(4)
	Input.action_release("jump")
	var short_y: float = p.position.y
	for i in 60:
		await physics_frame
		short_y = minf(short_y, p.position.y)
	check(short_y > min_y + 15, "Soltar Space no acorta salto")
	# Walk off an elevated ledge, then tap within coyote time.
	p.position = Vector2(740, 450)
	p.velocity = Vector2.ZERO
	await ticks(5)
	check(p.is_on_floor(), "Plataforma no sostiene cuerpo")
	p.position.x = 520
	await ticks(2)
	Input.action_press("jump")
	await ticks(2)
	check(p.velocity.y < 0 and p.last_jump_used_coyote, "Coyote no admite salto tras abandonar borde")
	Input.action_release("jump")
	await ticks(60)
	# Input slightly before floor contact is consumed once at landing.
	p.position = Vector2(400, 450)
	p.velocity = Vector2(0, 200)
	await ticks(3)
	p._coyote_left = 0
	var landings: int = p.landing_count
	Input.action_press("jump")
	await ticks(1)
	Input.action_release("jump")
	await ticks(7)
	check(p.landing_count > landings and p.velocity.y < 0, "Jump buffer no se consume al aterrizar")
	await ticks(60)
	p.position = Vector2(1930, 500)
	p.velocity = Vector2.ZERO
	await ticks(5)
	Input.action_press("jump")
	var ceiling_y: float = 500
	for i in 40:
		await physics_frame
		ceiling_y = minf(ceiling_y, p.position.y)
	check(ceiling_y >= 469, "Cuerpo atraviesa techo físico")
	Input.action_release("jump")
	await ticks(15)
	check(p.is_on_floor() and p.jump_height == 0, "Salto doble: físico + desplazamiento visual")
	var saved: Vector2 = p.position
	paused = true
	await create_timer(0.1, true, false, true).timeout
	check(p.position == saved, "Pausa no detiene física")
	paused = false
	var camera = p.get_node("Camera2D")
	check(camera.zoom.y * 700 >= root.size.y, "Cámara permite ver fuera verticalmente")
	scene.queue_free()
	await process_frame
	print("LATERAL_MOVEMENT failures=", failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
