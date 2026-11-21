extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func run() -> void:
	root.get_node("GameSession").enabled=false
	root.get_node("LateralStory").enabled=false
	root.get_node("GamePreferences").config_path="/private/tmp/palim-music-prefs.cfg"
	var audio=root.get_node("AudioLandscape")
	# Existing wind files are stream fixtures, not new music presented to players.
	audio.set_music(load("res://assets/audio/original/wind_01.wav"))
	await create_timer(.7,false,false,true).timeout
	check(audio._music[1].bus=="Music" and audio._music_gain[1]>.95,"Music no llega al bus/ganancia")
	audio.set_music(load("res://assets/audio/original/wind_02.wav"))
	await create_timer(.8,false,false,true).timeout
	check(audio._music[1].stream==null and audio._music_gain[0]>.95,"Crossfade no libera pista anterior")
	audio.hush(.25,.4)
	await create_timer(.25,false,false,true).timeout
	check(audio._music[0].volume_db < -20,"Narrativa no reduce música")
	audio.set_music(null)
	check(audio._music[0].stream==null and not audio._music[0].playing,"Sin asset no queda música antigua")
	print("LATERAL_MUSIC_HOOKS failures=",failures)
	root.get_node("GameSession").quit_game(1 if failures else 0)
