extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	root.get_node("GameSession").enabled = false
	root.get_node("GamePreferences").config_path = OS.get_temp_dir().path_join("palim-dialogue-prefs.cfg")
	root.get_node("AudioLandscape").shutdown()
	var flow = root.get_node("LateralStory")
	flow.save_path = OS.get_temp_dir().path_join("palim-dialogue-once.json")
	flow.set_process(false)
	flow.chapter = 0; flow.resolved = []; flow.party_health = {}; flow.entry_health = {}
	flow.selected = "elliot"; flow.encounter_id = ""; flow.completed = false
	var world = load(flow.WORLD).instantiate()
	root.add_child(world); current_scene = world
	world.set_process(false)
	await process_frame
	var npc = world.get_node("Ethan")
	npc.set_process(false)
	npc.player_in_range = true
	var dialogue = root.get_node("DialogueManager")
	Input.action_press("interact")
	npc._process(0)
	check(dialogue.visible and dialogue.label.text == npc.dialogue_lines[0],"Ethan no inicia su diálogo")
	Input.action_release("interact")
	dialogue.label.visible_characters = -1
	var event = InputEventAction.new()
	event.action = "interact"; event.pressed = true
	dialogue._unhandled_input(event)
	Input.action_press("interact")
	npc._process(0)
	check(not dialogue.visible and npc._completed,"La pulsación final reabre la conversación")
	check(not dialogue.can_start_dialogue(),"Otro NPC puede usar la pulsación final")
	Input.action_release("interact")
	check(npc._dialogue_key() in flow._read(flow.save_path).get("resolved",[]),"El diálogo terminado no queda guardado")
	world.actor.position = Vector2(1120,500)
	var previous_x: float = world.actor.position.x
	Input.action_press("move_right")
	for i in 8: await physics_frame
	Input.action_release("move_right")
	check(world.actor.position.x > previous_x,"El diálogo terminado mantiene bloqueado el movimiento")
	var key: String = npc._dialogue_key()
	npc.queue_free(); await process_frame
	var restored = load("res://scenes/characters/npc/Ethan.tscn").instantiate()
	world.add_child(restored)
	restored.set_process(false); restored.player_in_range = true
	flow.resolved = flow._read(flow.save_path).get("resolved",[])
	Input.action_press("interact"); restored._process(0); Input.action_release("interact")
	check(restored._dialogue_key() == key and not dialogue.visible,"NPC recreado repite diálogo guardado")
	flow.resolved = []
	await process_frame
	Input.action_press("interact"); restored._process(0); Input.action_release("interact")
	check(dialogue.visible,"Una partida nueva pierde su conversación")
	dialogue.label.visible_characters = -1; dialogue._unhandled_input(event)
	world.queue_free(); await process_frame
	print("DIALOGUE_ONCE failures=",failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
