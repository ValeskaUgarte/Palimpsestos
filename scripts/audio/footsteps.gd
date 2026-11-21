extends Node
var _actor: CharacterBody2D
var _sprite: AnimatedSprite2D
var _previous: Vector2
var _distance: float = 0.0
var _last_step: int = -1000
var _last_variant: int = -1
var _sound: AudioStreamPlayer2D
func _ready() -> void:
	_actor = get_parent() as CharacterBody2D
	_sprite = _actor.get_node("AnimatedSprite2D")
	_previous = _actor.ground_position()
	_sound = AudioStreamPlayer2D.new()
	_sound.add_to_group("palim_audio_voice")
	_sound.bus = "SFX"
	_sound.max_distance = 900
	_sound.volume_db = -15
	# El reproductor pertenece al componente: no queda huérfano si el actor
	# desaparece antes de ejecutar un add_child diferido.
	add_child(_sound)
	_sprite.frame_changed.connect(_on_contact)
func _physics_process(_delta: float) -> void:
	var point: Vector2 = _actor.ground_position()
	var moved: float = point.distance_to(_previous)
	_previous = point
	if not _eligible() or moved > 50:
		_distance = 0
		return
	_distance += moved
	# Distancia como respaldo solo para ciclos sin los ocho contactos revisados.
	if not _sprite.sprite_frames.has_meta("walk_contact_frames") and _sprite.sprite_frames.get_frame_count("walk") != 8 and _distance >= 62:
		_play_step()
func _eligible() -> bool:
	return not AudioLandscape.shutting_down and not _actor.is_attacking and not _actor.is_jumping and _actor.health.current_health > 0 and _sprite.animation == "walk" and _actor.velocity.length_squared() > 4
func _on_contact() -> void:
	if not _eligible(): return
	var contacts: PackedInt32Array = _sprite.sprite_frames.get_meta("walk_contact_frames",PackedInt32Array([0,4]) if _sprite.sprite_frames.get_frame_count("walk") == 8 else PackedInt32Array())
	if _sprite.frame in contacts and _distance > 3:
		_play_step()
func _play_step() -> void:
	if Time.get_ticks_msec()-_last_step < 180: return
	_last_step = Time.get_ticks_msec()
	_distance = 0
	var surface: String = AudioLandscape.profile.surface_type
	var priority: int = -2147483648
	for zone in get_tree().get_nodes_in_group("foley_surfaces"):
		if zone.overlaps_body(_actor) and zone.surface_priority > priority:
			surface = zone.surface_type
			priority = zone.surface_priority
	var sounds: Array[AudioStream] = AudioLandscape.bank.steps(surface)
	if sounds.is_empty() or not _sound.is_inside_tree(): return
	var index: int = randi_range(0,sounds.size()-1)
	if sounds.size()>1 and index==_last_variant: index=(index+1)%sounds.size()
	_last_variant=index
	_sound.global_position=_actor.ground_position()
	_sound.stream=sounds[index]
	_sound.pitch_scale=randf_range(0.97,1.03)
	_sound.volume_db=randf_range(-16,-14)
	_sound.play()
