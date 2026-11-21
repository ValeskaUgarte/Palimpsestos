extends "res://scripts/lateral/stage.gd"
@export_enum("wetland", "ruins") var route_kind: String = "wetland"
var route_id: String
func _environment_texture(_index: int) -> Texture2D:
	return preload("res://assets/art/presentation/wetland.png") if route_kind == "wetland" else preload("res://assets/art/presentation/ruins.png")
func _spawn_npcs(_index: int) -> void:
	pass
func _ready() -> void:
	exploration_title = "El sendero anegado" if route_kind == "wetland" else "Las ruinas del relato"
	var origin: float = LateralStory.return_x
	LateralStory.return_x = 300
	super._ready()
	LateralStory.return_x = origin
	route_id = "route_"+route_kind
	for node in get_children():
		if node is Area2D and node.get_script() == preload("res://scripts/lateral/encounter_zone.gd"):
			node.queue_free()
		elif node.is_in_group("enemy") and not _baked:
			node.queue_free()
	if is_instance_valid(_encounter_marker): _encounter_marker.hide()
	if is_instance_valid(_side_marker): _side_marker.hide()
	for rune in _runes: rune.queue_free()
	_runes.clear()
	_pending_encounter = null
	if not _baked:
		for x in ([850,1350,1850] if route_kind == "wetland" else [950,1550]):
			_spawn_enemy(Vector2(x,500),false)
	var title: String = "El sendero anegado" if route_kind == "wetland" else "Las ruinas del relato"
	get_node("ChapterPresentation").chapter_title = title
	get_node("ChapterPresentation").rewrite(title+" · Vence a los guardianes y encuentra la salida.")
	var profile = AudioLandscape.profile.duplicate()
	profile.surface_type = "wet" if route_kind == "wetland" else "stone"
	profile.volume_db = -19
	AudioLandscape.set_profile(profile)
	AudioLandscape.set_music(load("res://assets/audio/original/music_edge.wav") if route_kind == "wetland" else load("res://assets/audio/original/music_ruins.wav"))
func request_encounter(_definition: Resource) -> void:
	pass
func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or get_tree().paused or ScenePages.busy or actor._dead: return
	var remaining: int = 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.get_parent() == self and not enemy._dead and not enemy.is_queued_for_deletion(): remaining += 1
	_message.text = "RUTA · Guardianes: %d · A/D caminar · ESPACIO saltar · J/K combate · ESC pausa" % remaining
	_exit_marker.refresh("REGRESAR AL SENDERO\n"+("Camina hacia la derecha →" if remaining == 0 else "Quedan %d guardianes" % remaining),remaining == 0,actor.position.x>2000)
	if actor.position.x > 2160:
		if remaining > 0: actor.position.x = 2100
		else: _return_from_route()
func _return_from_route() -> void:
	if _crossing: return
	_crossing = true
	if not route_id in LateralStory.resolved:
		LateralStory.resolved.append(route_id)
		actor.health.current_health = mini(actor.health.max_health,actor.health.current_health+120)
		actor.health.health_changed.emit(actor.health.current_health,actor.health.max_health)
	LateralStory.capture_party()
	LateralStory.save_game()
	ScenePages.travel(LateralStory.world_scene())
