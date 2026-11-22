extends SceneTree
## Regresión del parpadeo: el sprite de Elliot no debe dibujarse con la pose del fotograma anterior
## (cambios de golpe, patada, combo, salto y caminata).
# Diagnóstico: detecta frames en los que el dibujo de Elliot usa una transformación
# distinta de la que le corresponde al frame que se muestra (el "parpadeo").
var mismatches: int = 0
var checks: int = 0
var log_lines: Array = []
var observer_node: Node
var player: Node
var level: Node
var current_label: String = ""
var per_label: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

class Observer extends Node:
	var owner_test: SceneTree
	func _ready() -> void:
		process_priority = 1000
	func _process(_d: float) -> void:
		owner_test.observe()

func observe() -> void:
	if player == null or not is_instance_valid(player):
		return
	var anim: AnimatedSprite2D = player.anim
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim.animation):
		return
	var before := [anim.scale, anim.position, anim.animation, anim.frame]
	player._fit_pose()
	var after := [anim.scale, anim.position]
	checks += 1
	if not (before[0].is_equal_approx(after[0]) and before[1].is_equal_approx(after[1])):
		mismatches += 1
		per_label[current_label] = per_label.get(current_label, 0) + 1
		if log_lines.size() < 40:
			log_lines.append("%s anim=%s frame=%d scale %s->%s pos %s->%s" % [current_label, str(before[2]), before[3], str(before[0]), str(after[0]), str(before[1]), str(after[1])])
	# restaura lo que dejó el refit para no alterar el resto de la prueba
	anim.scale = after[0]
	anim.position = after[1]

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func run() -> void:
	root.get_node("GameSession").enabled = false
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("palim-diag-prefs.cfg")
	level = load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	for actor in level.get_children():
		if actor is CharacterBody2D and actor != level.get_node("Elliot"):
			actor.set_physics_process(false)
	player = level.get_node("Elliot")
	observer_node = Observer.new()
	observer_node.owner_test = self
	root.add_child(observer_node)
	await settle(30)
	current_label = "idle"
	await settle(60)
	current_label = "walk"
	player._play_ground_animation("walk")
	await settle(60)
	current_label = "attack_1"
	player.facing = Vector2.RIGHT
	player._do_hit("attack")
	await settle(40)
	current_label = "kick"
	player.buffered_action = ""
	await settle(5)
	player._end_attack()
	player._do_hit("kick")
	await settle(40)
	current_label = "attack_combo"
	player._end_attack()
	player._do_hit("attack")
	await settle(40)
	current_label = "jump"
	player._begin_jump()
	await settle(70)
	current_label = "idle_after_jump"
	await settle(40)
	current_label = "walk_again"
	player._play_ground_animation("walk")
	await settle(40)
	print("ANIMATION_CONTINUITY mismatches=%d of %d checks" % [mismatches, checks])
	quit(1 if mismatches > 0 else 0)
	print("PROBE per_label=%s" % str(per_label))
	for line in log_lines:
		print("PROBE " + line)

