extends SceneTree
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	root.get_node("GameSession").enabled=false
	root.get_node("GamePreferences").config_path="/private/tmp/palim-preferences-tests.cfg"
	var level: Node=load("res://scenes/levels/cuento1_escena1.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	for actor in level.get_children():
		if actor is CharacterBody2D:actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	var p=level.get_node("Elliot")
	var foot=p.get_node("Footsteps")
	var audio=root.get_node("AudioLandscape")
	# Clips silenciosos en memoria: prueban selección sin añadir assets ficticios.
	var a:=AudioStreamWAV.new()
	var b:=AudioStreamWAV.new()
	a.data=PackedByteArray([0,0,0,0])
	b.data=PackedByteArray([0,0,0,0])
	audio.bank.forest.assign([a,b])
	p.velocity=Vector2.RIGHT*220
	p._play_ground_animation("walk")
	p.anim.pause()
	p.anim.frame=0
	foot._distance=10
	foot._last_step=-1000
	foot._on_contact()
	var first: AudioStream=foot._sound.stream
	check(first != null,"No emite en contacto")
	foot._distance=10
	foot._last_step=-1000
	foot._on_contact()
	check(foot._sound.stream!=first,"Repite variante consecutiva")
	p.is_jumping=true
	foot._last_step=-1000
	foot._on_contact()
	check(foot._last_step==-1000,"Pasos durante salto")
	p.is_jumping=false
	p.is_attacking=true
	foot._on_contact()
	check(foot._last_step==-1000,"Pasos durante ataque")
	p.is_attacking=false
	p.velocity=Vector2.ZERO
	foot._on_contact()
	check(foot._last_step==-1000,"Pasos detenido")
	var zone: Area2D=load("res://scenes/audio/surface_zone.tscn").instantiate()
	zone.surface_type="wood"
	zone.surface_priority=10
	zone.position=p.ground_position()
	level.add_child(zone)
	audio.bank.wood.assign([b])
	for i in range(3):await physics_frame
	p.velocity=Vector2.RIGHT*220
	foot._distance=10
	foot._last_step=-1000
	foot._on_contact()
	check(foot._sound.stream==b,"Zona no cambia superficie")
	foot._sound.stop()
	foot._sound.stream=null
	audio.bank.forest.clear()
	audio.bank.wood.clear()
	first=null
	a=null
	b=null
	level.queue_free()
	await process_frame
	await process_frame
	print("FOLEY_REGRESSION failures=",failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
