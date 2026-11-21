extends Node
var bank: PalimFoleyBank = preload("res://resources/audio/foley_bank.tres")
var profile: PalimAmbienceProfile = preload("res://resources/audio/forest.tres")
var _loop: AudioStreamPlayer
var _event: AudioStreamPlayer
var _timer: Timer
var _last_event: int = -1
var _music: Array[AudioStreamPlayer] = []
var _music_gain: Array[float] = [0.0,0.0]
var _music_slot: int = 0
var _music_tween: Tween
var shutting_down: bool = false
func _ready() -> void:
	_loop=AudioStreamPlayer.new()
	_loop.add_to_group("palim_audio_voice")
	_loop.bus="Ambient"
	add_child(_loop)
	_event=AudioStreamPlayer.new()
	_event.add_to_group("palim_audio_voice")
	_event.bus="Ambient"
	add_child(_event)
	for slot in 2:
		var voice := AudioStreamPlayer.new()
		voice.bus = "Music"
		voice.add_to_group("palim_audio_voice")
		add_child(voice)
		_music.append(voice)
	_timer=Timer.new()
	_timer.one_shot=true
	add_child(_timer)
	_timer.timeout.connect(_ambient_event)
func set_profile(value: PalimAmbienceProfile) -> void:
	if shutting_down:return
	if _hush_tween:_hush_tween.kill()
	_duck=1.0
	_loop.stop()
	_timer.stop()
	profile=value
	if profile.loop:
		_loop.stream=profile.loop.duplicate()
		if _loop.stream is AudioStreamWAV:
			_loop.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
			_loop.stream.loop_end=int(_loop.stream.get_length()*_loop.stream.mix_rate)
		_loop.volume_db=profile.volume_db
		_loop.play()
	if not profile.events.is_empty():_schedule()
func _schedule() -> void:
	_timer.start(randf_range(profile.minimum_interval,maxf(profile.minimum_interval,profile.maximum_interval)))
func _ambient_event() -> void:
	if not profile.events.is_empty():
		var index: int = randi_range(0,profile.events.size()-1)
		if profile.events.size()>1 and index==_last_event:index=(index+1)%profile.events.size()
		_last_event=index
		_event.stream=profile.events[index]
		_event.volume_db=profile.volume_db-3+linear_to_db(_duck)
		_event.play()
		_schedule()
var _hush_tween: Tween
var _duck: float = 1.0
func hush(amount: float = 0.25, duration: float = 0.8) -> void:
	if _hush_tween: _hush_tween.kill()
	_hush_tween=create_tween()
	_hush_tween.tween_method(_duck_volume,_duck,clampf(amount,0.01,1.0),0.2)
	_hush_tween.tween_interval(duration)
	_hush_tween.tween_method(_duck_volume,clampf(amount,0.01,1.0),1.0,0.5)
func _duck_volume(value: float) -> void:
	_duck=value
	_loop.volume_db=profile.volume_db+linear_to_db(value)
	_event.volume_db=profile.volume_db-3+linear_to_db(value)
func cue(id: StringName, location: Vector2 = Vector2.INF) -> void:
	if shutting_down:return
	var stream: AudioStream = bank.interactions.get(id)
	if stream == null: return
	var sound
	if location == Vector2.INF:
		sound=AudioStreamPlayer.new()
		sound.process_mode=Node.PROCESS_MODE_ALWAYS
	else:
		sound=AudioStreamPlayer2D.new()
		sound.global_position=location
	sound.bus="UI" if location == Vector2.INF else "SFX"
	sound.stream=stream
	sound.add_to_group("palim_audio_voice")
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func _process(_delta: float) -> void:
	for slot in _music.size():
		if _music[slot].playing:
			_music[slot].volume_db = -16 + linear_to_db(maxf(_music_gain[slot] * _duck,0.0001))

func set_music(stream: AudioStream) -> void:
	if shutting_down: return
	if stream != null and _music[_music_slot].stream == stream: return
	if _music_tween: _music_tween.kill()
	if stream == null:
		for slot in _music.size():
			_music[slot].stop()
			_music[slot].stream = null
			_music_gain[slot] = 0
		return
	var old: int = _music_slot
	_music_slot = (old + 1) % 2
	var incoming: AudioStreamPlayer = _music[_music_slot]
	incoming.stop()
	incoming.stream = stream
	if incoming.stream is AudioStreamWAV:
		incoming.stream = stream.duplicate()
		incoming.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		incoming.stream.loop_end = int(stream.get_length()*stream.mix_rate)
	_music_gain[_music_slot] = 0
	incoming.volume_db = -80
	incoming.play()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_method(_set_music_gain.bind(_music_slot),0.0,1.0,.6)
	_music_tween.tween_method(_set_music_gain.bind(old),_music_gain[old],0.0,.6)
	_music_tween.chain().tween_callback(func():_music[old].stop();_music[old].stream=null)

func _set_music_gain(value: float, slot: int) -> void:
	_music_gain[slot] = value

func shutdown() -> void:
	shutting_down=true
	if _music_tween: _music_tween.kill()
	_timer.stop()
	if _hush_tween:_hush_tween.kill()
	for voice in get_tree().get_nodes_in_group("palim_audio_voice"):
		voice.stop()
		voice.stream=null
