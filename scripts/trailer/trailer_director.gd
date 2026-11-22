extends Node2D
## TrailerDirector: linea de tiempo guiada (sin input ni IA) que usa el arte y las escenas reales del juego.
## Se graba con: Godot --write-movie ... res://scenes/trailer/trailer.tscn

const SND := "res://assets/audio/original/%s.wav"
const ELLIOT := preload("res://scenes/characters/player/Elliot.tscn")
const JHON := preload("res://scenes/characters/player/Jhon.tscn")
const THOMAS := preload("res://scenes/characters/player/Thomas.tscn")
const MAMA := preload("res://scenes/characters/npc/NPC_Mama.tscn")
const VECINA := preload("res://scenes/characters/npc/NPC_Vecina.tscn")
const PADRE := preload("res://scenes/characters/npc/NPC_Padre_HyG.tscn")
const MADRE := preload("res://scenes/characters/npc/NPC_Madre_HyG.tscn")
const NINO := preload("res://scenes/characters/pueblo/Nino.tscn")
const PERRO := preload("res://scenes/characters/pueblo/Perro.tscn")
const WOLF1 := preload("res://scenes/characters/enemies/Wolf1.tscn")
const WOLF2 := preload("res://scenes/characters/enemies/Wolf2.tscn")
const RANGER := preload("res://scenes/characters/enemies/RangerWood.tscn")
const LOBO := preload("res://scenes/characters/enemies/Lobo.tscn")
const TEX_VILLAGE := preload("res://assets/escenas/cuento1/escena_a1.png")
const BG_ARENA := preload("res://assets/art/presentation/forest-arena.png")
const BG_FOREGROUND := preload("res://assets/art/presentation/forest-foreground.png")
const BG_WET := preload("res://assets/art/presentation/wetland.png")
const BG_RUINS := preload("res://assets/art/presentation/ruins.png")
const TEX_A12 := preload("res://assets/escenas/cuento1/escena_a12.png")
const TEX_A13 := preload("res://assets/escenas/cuento1/escena_a13.png")
const RUNE := preload("res://scripts/systems/monolith_rune.gd")
const BossWarning := preload("res://scripts/systems/boss_warning.gd")

## Linea del suelo (y del mundo) para los fondos de 1672x941 centrados en el origen.
const GROUND_Y := 175.0

var ov: CanvasLayer
var cam: Camera2D
var world: Node2D
var _music: AudioStreamPlayer
var _cam_tween: Tween


func _ready() -> void:
	# La mochila real pausa el arbol al abrirse: el trailer sigue corriendo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	ov = $Overlay
	world = Node2D.new()
	add_child(world)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func sfx(sound: String, db: float = 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load(SND % sound)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func music(sound: String, db: float = -4.0) -> void:
	var old := _music
	if old:
		var t := create_tween().set_ignore_time_scale(true)
		t.tween_property(old, "volume_db", -60.0, 1.2)
		t.tween_callback(old.queue_free)
	_music = AudioStreamPlayer.new()
	_music.stream = load(SND % sound)
	_music.volume_db = -60.0
	add_child(_music)
	_music.play()
	create_tween().set_ignore_time_scale(true).tween_property(_music, "volume_db", db, 1.0)


func move_cam(from_pos: Vector2, to_pos: Vector2, from_zoom: float, to_zoom: float, dur: float, ease_type := Tween.EASE_IN_OUT) -> void:
	if _cam_tween:
		_cam_tween.kill()
	cam.position_smoothing_enabled = false
	cam.position = from_pos
	cam.zoom = Vector2.ONE * from_zoom
	cam.reset_smoothing()
	var t := create_tween().set_ignore_time_scale(true).set_parallel(true)
	_cam_tween = t
	t.set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	t.tween_property(cam, "position", to_pos, dur)
	t.tween_property(cam, "zoom", Vector2.ONE * to_zoom, dur)


func clear_world() -> void:
	for c in world.get_children():
		c.free()


func add_bg(tex: Texture2D, scale_f: float = 1.0, tint := Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * scale_f
	s.modulate = tint
	s.z_index = -100
	world.add_child(s)
	return s


func clip_len(frames: SpriteFrames, clip: StringName) -> float:
	if frames == null or not frames.has_animation(clip):
		return 0.5
	return float(frames.get_frame_count(clip)) / maxf(frames.get_animation_speed(clip), 0.01)


# --- actores reales, con IA y fisica apagadas ---------------------------------------------
func spawn(scene: PackedScene, foot: Vector2) -> Node2D:
	var a: Node2D = scene.instantiate()
	world.add_child(a)
	a.set_physics_process(false)
	if a.has_node("Camera2D"):
		a.get_node("Camera2D").enabled = false
	if a.has_node("DetectionArea"):
		a.get_node("DetectionArea").monitoring = false
	a.global_position += foot - a.call("ground_position")
	cam.make_current()
	return a


func hero(scene: PackedScene, foot: Vector2) -> Node2D:
	var h := spawn(scene, foot)
	h.z_index = int(foot.y)
	hero_play(h, &"idle")
	return h


func hero_play(h: Node2D, clip: StringName) -> float:
	if clip == &"walk" and h.anim.sprite_frames.has_animation(&"walk"):
		h.anim.sprite_frames.set_animation_loop(&"walk", true)  # en memoria: la caminata siempre en bucle
	h.call("_play_ground_animation", clip)
	h.anim.speed_scale = 1.0
	return clip_len(h.anim.sprite_frames, h.anim.animation)


func foe(scene: PackedScene, foot: Vector2, halfw := 90.0, face_left := true) -> Node2D:
	var e := spawn(scene, foot)
	e.set_meta("halfw", halfw)
	e.set("_facing_sign", -1.0 if face_left else 1.0)
	e.z_index = int(foot.y)
	e.call("_play_animation", &"idle")
	return e


func foe_play(e: Node2D, clip: StringName) -> float:
	e.call("_play_animation", clip)
	return clip_len(e.visual.sprite_frames, e.visual.animation)


func impact_point(e: Node2D, dx := 0.0) -> Vector2:
	# Punto de contacto: la cara del enemigo que mira al heroe.
	return e.call("ground_position") + Vector2(dx - float(e.get_meta("halfw", 90.0)), -150)


func strike(h: Node2D, e: Node2D, clip: StringName, strength: float, kill := false) -> void:
	var dur := hero_play(h, clip)
	sfx("swing", -6.0)
	await wait(dur * 0.5)
	CombatFX.hit_impact(impact_point(e, 10), strength, Vector2.RIGHT)
	sfx("impact_heavy" if strength > 1.2 else "impact", -2.0)
	if kill:
		sfx("finisher")
		var d := foe_play(e, &"death")
		CombatFX.death_burst(impact_point(e), 1.3)
		await wait(dur * 0.5)
		hero_play(h, &"idle")
		await wait(maxf(d - dur * 0.5, 0.2) + 0.3)
		create_tween().set_ignore_time_scale(true).tween_property(e, "modulate:a", 0.0, 0.5)
	else:
		var hd := foe_play(e, &"hurt")
		var t := create_tween().set_ignore_time_scale(true)
		t.tween_property(e, "global_position:x", e.global_position.x + 28, 0.2)
		await wait(dur * 0.5)
		hero_play(h, &"idle")
		await wait(maxf(0.0, hd - dur * 0.5) * 0.5)
		foe_play(e, &"idle")


# --- guion --------------------------------------------------------------------------------
func _run() -> void:
	var only := OS.get_cmdline_user_args()
	if only.size() > 0:
		# Depuracion: "-- puzzle" graba solo ese plano.
		for n in only.size() - 1:
			await call("shot_" + only[n])
		call("shot_" + only[only.size() - 1])
		for i in 12:
			await wait(0.4)
			print("cam ", cam.position, " cur=", get_viewport().get_camera_2d().get_path(), " ", get_viewport().get_camera_2d().get_screen_center_position())
		get_tree().quit()
		return
	await shot_title()
	await shot_village()
	await shot_journey()
	await shot_puzzle()
	await shot_inventory()
	await shot_combat()
	await shot_boss()
	await shot_end()
	await wait(0.5)
	get_tree().quit()


func shot_title() -> void:
	clear_world()
	ov.parchment.visible = true
	music("music_forest", -5.0)
	sfx("page_turn", -4.0)
	var lines := ["Bajo cada historia...", "hay otra historia."]
	ov.fade_to(0.0, 0.8)
	for i in 2:
		ov.title_lines[i].text = lines[i]
		create_tween().set_ignore_time_scale(true).tween_property(ov.title_lines[i], "modulate:a", 1.0, 0.9)
		await wait(1.3)
	await wait(0.6)
	for l in ov.title_lines:
		create_tween().set_ignore_time_scale(true).tween_property(l, "modulate:a", 0.0, 0.6)
	await wait(0.8)
	sfx("page_turn", -2.0)
	ov.logo.scale = Vector2.ONE * 0.9
	var t := create_tween().set_ignore_time_scale(true).set_parallel(true)
	t.tween_property(ov.logo, "modulate:a", 1.0, 1.2)
	t.tween_property(ov.logo, "scale", Vector2.ONE * 1.05, 4.0)
	await wait(1.5)
	ov.title_lines[0].position.y = 450
	ov.title_lines[0].add_theme_font_size_override("font_size", 28)
	ov.title_lines[0].text = "un manuscrito"
	create_tween().set_ignore_time_scale(true).tween_property(ov.title_lines[0], "modulate:a", 1.0, 1.0)
	await wait(2.6)
	ov.fade_to(1.0, 0.5)
	await wait(0.6)
	ov.parchment.visible = false


func shot_village() -> void:
	clear_world()
	ov.show_caption("Un pueblo donde todos callan algo.", 3.2)
	var sky := ColorRect.new()
	sky.color = Color(0.17, 0.15, 0.13)
	sky.size = Vector2(9000, 1400)
	sky.position = Vector2(-2500, -900)
	sky.z_index = -200
	world.add_child(sky)
	var bg := Sprite2D.new()
	bg.texture = TEX_VILLAGE
	bg.position = Vector2(2473.7, -31.2)
	bg.scale = Vector2(3.71, 3.665)
	bg.z_index = -100
	world.add_child(bg)
	# Las dos vecinas conversando (mismos ajustes de la escena 1).
	var mama: Node2D = MAMA.instantiate()
	var m: AnimatedSprite2D = mama.get_node("Motion")
	m.position = Vector2(321.29, -43.0)
	m.scale = Vector2.ONE * 0.2242
	m.standing_height = 305.0
	m.foot_position = Vector2(318.49, 116.63)
	m.always_talk = true
	m.face_player = false
	m.idle_face_direction = -1.0
	mama.position = Vector2(-746, 193)
	var vec: Node2D = VECINA.instantiate()
	var v: AnimatedSprite2D = vec.get_node("Motion")
	v.position = Vector2(-52.7, -52.0)
	v.scale = Vector2.ONE * 0.2269
	v.always_talk = true
	v.face_player = false
	v.idle_face_direction = 1.0
	vec.position = Vector2(-840, 211)  # igual que la escena 1: las dos vecinas bien separadas
	var padre: Node2D = PADRE.instantiate()
	padre.position = Vector2(1250, 120)
	var madre: Node2D = MADRE.instantiate()
	madre.position = Vector2(1340, 135)
	var pm: Node = padre.get_node("Motion")
	var mm: Node = madre.get_node("Motion")
	pm.set("always_talk", true)
	pm.set("face_player", false)
	pm.set("idle_face_direction", 1.0)
	mm.set("always_talk", true)
	mm.set("face_player", false)
	mm.set("idle_face_direction", -1.0)
	padre.modulate = Color(0.8, 0.88, 0.93)
	madre.modulate = Color(0.8, 0.88, 0.93)
	for n in [mama, vec, padre, madre]:
		world.add_child(n)
	var nino: Node2D = NINO.instantiate()
	nino.position = Vector2(100, 238)
	nino.set("x_min", -400.0)
	nino.set("x_max", 400.0)
	nino.set("speed", 110.0)
	world.add_child(nino)
	nino.get_node("Sprite").scale = Vector2.ONE * 0.6
	var perro: Node2D = PERRO.instantiate()
	perro.position = Vector2(-100, 312)
	perro.set("x_min", -400.0)
	perro.set("x_max", 400.0)
	world.add_child(perro)
	cam.make_current()
	ov.fade_to(0.0, 0.6)
	move_cam(Vector2(-640, 10), Vector2(1050, 10), 1.0, 1.08, 9.0)
	await wait(8.4)
	ov.fade_to(1.0, 0.5)
	await wait(0.6)


func shot_journey() -> void:
	clear_world()
	add_bg(BG_ARENA, 1.2)
	ov.show_caption("Perdidos en un mundo familiar pero desconocido.", 3.0)
	var foot_y := GROUND_Y * 1.2 + 25.0
	var el := hero(ELLIOT, Vector2(-700, foot_y + 18))
	var jh := hero(JHON, Vector2(-860, foot_y - 10))
	var th := hero(THOMAS, Vector2(-1000, foot_y + 40))
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	for h in [el, jh, th]:
		hero_play(h, &"walk")
		tw.tween_property(h, "global_position:x", h.global_position.x + 1150, 8.4)
	ov.fade_to(0.0, 0.6)
	move_cam(Vector2(-350, 0), Vector2(250, 0), 0.95, 1.0, 8.6, Tween.EASE_OUT)
	await wait(7.9)
	ov.fade_to(1.0, 0.5)
	await wait(0.6)


func walk_to(h: Node2D, x: float, dur: float) -> void:
	hero_play(h, &"walk")
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(h, "global_position:x", x, dur)
	await wait(dur)
	hero_play(h, &"idle")


func shot_puzzle() -> void:
	clear_world()
	var sky := ColorRect.new()
	sky.color = Color(0.1, 0.1, 0.12)
	sky.size = Vector2(9000, 1400)
	sky.position = Vector2(12500, -900)
	sky.z_index = -200
	world.add_child(sky)
	var bg := Sprite2D.new()
	bg.texture = TEX_A13
	bg.position = Vector2(16225.1, -44.1)
	bg.scale = Vector2.ONE * 3.4177
	bg.z_index = -100
	world.add_child(bg)
	# Las tres runas reales del monolito (monolith_rune.gd), activadas en orden.
	var runes: Array[Area2D] = []
	for i in 3:
		var r := Area2D.new()
		r.set("rune_id", i + 1)
		r.set_script(RUNE)
		r.set("rune_id", i + 1)
		r.position = Vector2(16410 + i * 160, 270)
		r.z_index = 200
		world.add_child(r)
		r.set_physics_process(false)
		runes.append(r)
	var el := hero(ELLIOT, Vector2(16250, 292))
	ov.fade_to(0.0, 0.5)
	move_cam(Vector2(16420, -10), Vector2(16590, -10), 1.0, 1.1, 6.4)
	await wait(0.6)
	for i in 3:
		await walk_to(el, runes[i].position.x - 70, 0.9)
		var d := hero_play(el, &"interact")
		await wait(d * 0.5)
		runes[i].call("set_accepted", true)
		var imp := Node2D.new()
		imp.set_script(preload("res://scripts/systems/ink_impact.gd"))
		imp.set("direction", Vector2.UP)
		imp.set("strength", 0.7)
		add_child(imp)
		imp.global_position = runes[i].global_position + Vector2(0, -190)
		await wait(maxf(d * 0.5, 0.3))
		hero_play(el, &"idle")
	sfx("puzzle_complete")
	ov.flash(Color(0.6, 0.95, 0.85), 0.45, 0.9)
	await wait(1.0)
	ov.fade_to(1.0, 0.4)
	await wait(0.5)


func shot_inventory() -> void:
	clear_world()
	var sky := ColorRect.new()
	sky.color = Color(0.1, 0.1, 0.12)
	sky.size = Vector2(9000, 1400)
	sky.position = Vector2(5000, -900)
	sky.z_index = -200
	world.add_child(sky)
	var bg := Sprite2D.new()
	bg.texture = TEX_A12
	bg.position = Vector2(9488.7, -22.3)
	bg.scale = Vector2.ONE * 3.8389
	bg.z_index = -100
	world.add_child(bg)
	var saved: Dictionary = GameSession.progress.duplicate(true)
	var item := Sprite2D.new()
	item.texture = load("res://assets/ui/diario/item_pastel.png")
	item.scale = Vector2.ONE * (90.0 / item.texture.get_height())
	item.position = Vector2(9640, 250)
	item.z_index = 400
	world.add_child(item)
	var el := hero(ELLIOT, Vector2(9330, 285))
	ov.fade_to(0.0, 0.4)
	move_cam(Vector2(9480, -10), Vector2(9560, -10), 1.0, 1.1, 5.0)
	await walk_to(el, 9615, 1.5)
	var d := hero_play(el, &"interact")
	await wait(d * 0.5)
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(item, "position:y", 130.0, 0.5)
	tw.tween_property(item, "modulate:a", 0.0, 0.5)
	sfx("clue")
	GameSession.progress["items"]["pastel"] = 1
	Mochila.show_found("pastel", true, 1)
	await wait(1.4)
	hero_play(el, &"idle")
	for id in ["vino", "flores", "pluma", "pocion", "pan"]:
		GameSession.progress["items"][id] = 1
	Mochila.call("_open")
	sfx("page_turn", -3.0)
	await wait(2.4)
	Mochila.call("_close")
	Mochila.call("_hide_toast")
	GameSession.progress = saved
	ov.fade_to(1.0, 0.3)
	await wait(0.4)


func shot_combat() -> void:
	music("music_combat", -4.0)
	# Golpe A: combo de Elliot contra el lobo.
	clear_world()
	add_bg(BG_ARENA, 1.0)
	ov.show_caption("Lo escrito no se rinde sin resistencia.", 3.5)
	var el := hero(ELLIOT, Vector2(-160, GROUND_Y + 30))
	var wolf := foe(WOLF1, Vector2(10, GROUND_Y + 30), 100.0)
	ov.fade_to(0.0, 0.3)
	move_cam(Vector2(-40, 20), Vector2(0, 30), 1.12, 1.0, 4.4)
	await wait(0.5)
	await strike(el, wolf, &"attack_1", 0.8)
	await strike(el, wolf, &"attack_2", 1.0)
	await strike(el, wolf, &"kick", 1.1)
	await strike(el, wolf, &"finisher", 1.8, true)
	await wait(0.2)
	ov.fade_to(1.0, 0.2)
	await wait(0.25)
	# Golpe B: el guardabosques del pantano.
	clear_world()
	add_bg(BG_WET, 1.0)
	el = hero(ELLIOT, Vector2(-160, GROUND_Y + 30))
	var gn := foe(RANGER, Vector2(-10, GROUND_Y + 30), 80.0)
	ov.fade_to(0.0, 0.2)
	move_cam(Vector2(60, 10), Vector2(-30, 30), 1.15, 1.0, 3.6)
	await wait(0.4)
	await strike(el, gn, &"kick", 1.0)
	await strike(el, gn, &"attack_1", 0.9)
	await strike(el, gn, &"finisher", 1.8, true)
	ov.fade_to(1.0, 0.2)
	await wait(0.25)
	# Golpe C: Jhon y Thomas contra un lobo.
	clear_world()
	add_bg(BG_RUINS, 1.0)
	var jh := hero(JHON, Vector2(-160, GROUND_Y + 25))
	var th := hero(THOMAS, Vector2(-215, GROUND_Y + 50))
	var rg := foe(WOLF2, Vector2(10, GROUND_Y + 30), 100.0)
	ov.fade_to(0.0, 0.2)
	move_cam(Vector2(-120, 20), Vector2(0, 30), 1.0, 1.08, 3.8)
	await wait(0.4)
	await strike(jh, rg, &"attack", 0.9)
	await strike(th, rg, &"attack", 1.0)
	await strike(jh, rg, &"kick", 1.1)
	await strike(th, rg, &"attack", 1.8, true)
	ov.fade_to(1.0, 0.3)
	await wait(0.4)


func shot_boss() -> void:
	music("music_boss", -3.0)
	clear_world()
	var bg := add_bg(BG_RUINS, 1.0, Color(0.35, 0.3, 0.4))
	var lobo := foe(LOBO, Vector2(210, GROUND_Y + 40), 110.0)
	lobo.modulate = Color(0.04, 0.03, 0.05)
	var el := hero(ELLIOT, Vector2(30, GROUND_Y + 32))
	var jh := hero(JHON, Vector2(-40, GROUND_Y + 8))
	var th := hero(THOMAS, Vector2(-170, GROUND_Y + 60))
	ov.fade_to(0.0, 0.8)
	move_cam(Vector2(-250, 20), Vector2(-60, 20), 1.0, 1.0, 3.0)
	await wait(1.8)
	# Aviso del jefe: destello y la silueta se revela.
	sfx("corruption", 0.0)
	ov.flash(Color(1, 0.25, 0.15), 0.7, 0.5)
	var warn := Node2D.new()
	warn.set_script(BossWarning)
	warn.set("charge", true)
	warn.set("direction", -1.0)
	lobo.add_child(warn)
	warn.position = Vector2(-60, -100)
	warn.queue_redraw()
	create_tween().set_ignore_time_scale(true).tween_property(lobo, "modulate", Color.WHITE, 0.5)
	create_tween().set_ignore_time_scale(true).tween_property(bg, "modulate", Color(0.55, 0.42, 0.45), 0.6)
	var d := foe_play(lobo, &"attack")
	move_cam(cam.position, Vector2(40, -10), 1.0, 1.25, 2.6)
	ov.show_caption("Todo cuento guarda un instante sin regreso.", 3.0)
	await wait(1.0)
	ov.flash(Color(1, 0.25, 0.15), 0.5, 0.3)
	await wait(maxf(d - 0.4, 1.0))
	warn.queue_free()
	foe_play(lobo, &"idle")
	move_cam(cam.position, Vector2(-40, 10), 1.25, 1.0, 1.6)
	await wait(0.8)
	await strike(jh, lobo, &"attack", 1.0)
	await strike(el, lobo, &"attack_1", 1.2)
	# Ultimo golpe: remate con todo.
	var dur := hero_play(el, &"finisher")
	sfx("swing")
	await wait(dur * 0.5)
	CombatFX.hit_impact(impact_point(lobo, 10), 2.0, Vector2.RIGHT)
	sfx("impact_heavy")
	sfx("finisher")
	ov.flash(Color.WHITE, 0.85, 0.45)
	foe_play(lobo, &"hurt")
	move_cam(cam.position, Vector2(80, 0), 1.0, 1.35, 1.2, Tween.EASE_OUT)
	await wait(1.4)
	ov.fade_to(1.0, 0.6)
	await wait(0.8)
	th.visible = th.visible


func shot_end() -> void:
	clear_world()
	music("music_forest", -4.0)
	ov.parchment.visible = true
	ov.logo.scale = Vector2.ONE * 0.95
	ov.logo.modulate.a = 0.0
	ov.title_lines[0].modulate.a = 0.0
	ov.title_lines[0].position.y = 440
	ov.title_lines[0].add_theme_font_size_override("font_size", 36)
	ov.title_lines[0].text = "La página puede volver a escribirse."
	ov.title_lines[1].modulate.a = 0.0
	ov.title_lines[1].position.y = 500
	ov.title_lines[1].add_theme_font_size_override("font_size", 26)
	ov.title_lines[1].text = "Próximamente"
	sfx("page_turn")
	ov.fade_to(0.0, 0.8)
	var t := create_tween().set_ignore_time_scale(true).set_parallel(true)
	t.tween_property(ov.logo, "modulate:a", 1.0, 1.0)
	t.tween_property(ov.logo, "scale", Vector2.ONE * 1.04, 5.0)
	await wait(1.4)
	create_tween().set_ignore_time_scale(true).tween_property(ov.title_lines[0], "modulate:a", 1.0, 1.0)
	await wait(1.6)
	create_tween().set_ignore_time_scale(true).tween_property(ov.title_lines[1], "modulate:a", 0.85, 1.0)
	await wait(2.0)
	ov.fade_to(1.0, 1.2)
	if _music:
		create_tween().set_ignore_time_scale(true).tween_property(_music, "volume_db", -60.0, 1.2)
	await wait(1.4)
