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
const BossWarning := preload("res://scripts/systems/boss_warning.gd")

## Linea del suelo (y del mundo) para los fondos de 1672x941 centrados en el origen.
const GROUND_Y := 175.0
## Suelo del pueblo (mismo que el camino de la escena 1).
const VILLAGE_FOOT_Y := 275.0
const PORTRAIT_JHON := preload("res://assets/characters/John/Jhon.png")
const PORTRAIT_THOMAS := preload("res://assets/characters/Thomas/Thomas.png")
## Narración: frases de la historia que cuenta el juego (escena 1, nodo NarracionHistoria).
const NARRATION := [
	"Durante siglos, distintas obras literarias fueron transformándose a medida que pasaban de una generación a otra.",
	"Desde el más allá, sus autores observan cómo sus historias son modificadas, suavizadas y transformadas.",
	"Lo que comenzó como una transformación termina convirtiéndose, para ellos, en una aberración.",
	"Los autores observan todo esto y finalmente deciden intervenir.",
	"Un lugar donde el bosque vuelve a ser peligroso, donde las criaturas no están allí para ayudar al protagonista.",
	"Crean entonces un mundo construido a partir de sus relatos, pero no de las versiones que el mundo moderno conoce.",
	"Un mundo creado para recordar que detrás de aquellas historias existía una advertencia.",
	"Historias que contenían mucho más que fantasía: advertencias, peligros, violencia, miedo y consecuencias.",
	"Quieren que los seres humanos vuelvan a experimentar aquello que, según ellos, fue eliminado de sus obras.",
	"Un mundo donde los cuentos recuperan su naturaleza más oscura.",
	"Donde las decisiones pueden tener consecuencias reales.",
]
const SND_PAGE := "page_turn"
const ETHAN := preload("res://scenes/characters/npc/Ethan.tscn")
const CAPERUCITA := preload("res://scenes/characters/npc/Caperucita.tscn")
const STEPHY := preload("res://scenes/characters/npc/Stephy.tscn")
const ABUELITA := preload("res://scenes/characters/npc/Abuelita.tscn")
const WOLF3 := preload("res://scenes/characters/enemies/Wolf3.tscn")
const WOLFWHITE := preload("res://scenes/characters/enemies/WolfWhite.tscn")
const GNOMO := preload("res://scenes/characters/enemies/Gnomo.tscn")
const TEX_CAVE := preload("res://assets/escenas/cuento1/escena_02b_cueva.png")
const TEX_HOUSE := preload("res://assets/escenas/cuento1/escena_02a_casa.png")

var ov: CanvasLayer
var cam: Camera2D
var world: Node2D
var _music: AudioStreamPlayer
## Voz de la narración (la misma historia que NarracionHistoria en la escena 1) y su reloj.
const NARRATION_AUDIO := preload("res://assets/audio/narracion/Donde_el_miedo_habitaba.mp3")
var _voice: AudioStreamPlayer
var _narr_on: bool = false
var _narr_t: float = 0.0
## Subtítulos: [inicio, fin, texto] en segundos del audio. Si el narrador va adelantado o atrasado, se corrigen estos tiempos.
const NARRATION_SUBS := [
	[0.35, 7.98, "Durante siglos, distintas obras literarias fueron transformándose a medida que pasaban de una generación a otra,"],
	[8.05, 15.21, "relatos que originalmente no fueron concebidos como simples cuentos infantiles terminaron convirtiéndose,"],
	[15.27, 20.04, "con el paso del tiempo, en versiones mucho más inocentes de sí mismos."],
	[20.04, 23.52, "Autores como Charles Perrault, Giambattista Basile,"],
	[23.59, 27.68, "Hans Christian Andersen y los hermanos Jacob y Wilhelm Grimm"],
	[27.68, 31.76, "escribieron historias que contenían mucho más que fantasía,"],
	[31.83, 38.10, "en ellas existían advertencias, peligros, violencia, miedo y consecuencias, Caperucita Roja,"],
	[38.17, 41.17, "La Bella Durmiente, Cenicienta, La Sirenita,"],
	[41.24, 46.48, "Hansel y Gretel y muchas otras obras fueron creadas en contextos y épocas muy"],
	[46.48, 51.66, "diferentes a las versiones que posteriormente llegarían al público moderno."],
	[51.66, 58.20, "Desde el más allá, sus autores observan durante generaciones cómo sus historias son modificadas,"],
	[58.27, 65.22, "suavizadas y transformadas hasta perder aquello que alguna vez quisieron transmitirse toco la esencia,"],
	[65.29, 70.81, "se manipulo el contexto, hasta llegar a ser una burla sus etnias y característica"],
	[70.81, 76.33, "que las hacían apreciadas por el público y la época en la que estaban dirigidas."],
	[76.33, 82.67, "Lo que comenzó como una transformación termina convirtiéndose, para ellos, en una aberración."],
	[82.67, 90.16, "Sus historias fueron despojadas de aquello que las hacía advertencias, el miedo fue reemplazado por seguridad,"],
	[90.23, 92.89, "el peligro dejó de tener consecuencias,"],
	[92.96, 97.70, "lo oscuro y la realidad que vivían aquellos tiempos fue ocultado para"],
	[97.70, 102.93, "convertir aquellas obras en relatos destinados principalmente a entretener."],
	[102.93, 107.31, "Los autores observan todo esto y finalmente deciden intervenir,"],
	[107.38, 111.55, "no pretenden simplemente recuperar sus historias originales,"],
	[111.62, 118.98, "quieren que los seres humanos vuelvan a experimentar aquello que, según ellos, fue eliminado de sus obras."],
	[118.98, 123.08, "Crean entonces un mundo construido a partir de sus relatos,"],
	[123.15, 126.83, "pero no de las versiones que el mundo moderno conoce."],
	[126.83, 131.35, "Es un mundo donde los cuentos recuperan su naturaleza más oscura,"],
	[131.42, 134.75, "un lugar donde el bosque vuelve a ser peligroso,"],
	[134.82, 139.06, "donde las criaturas no están allí para ayudar al protagonista"],
	[139.06, 143.09, "y donde las decisiones pueden tener consecuencias reales,"],
	[143.16, 147.88, "la realidad de no todo lo que brilla es oro y tus decisiones y actos"],
	[147.88, 152.40, "pueden llevarte a descubrir que eres dueño de tu propio destino."],
	[152.40, 159.10, "Un mundo creado para recordar que detrás de aquellas historias existía una advertencia."],
]

const SHOW_SUBTITLES := false
## Segundo de la narración en que termina cada plano (los planos se estiran hasta ahí).
const SHOT_END := {
	"departure": 30.0,
	"posters": 50.5,
	"authors": 76.0,
	"reveals": 102.6,
	"combat": 119.0,
	"ranger": 131.2,
	"horde": 143.0,
	"boss": 152.2,
	"end": 163.6,
}
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


func _process(delta: float) -> void:
	if not _narr_on:
		return
	_narr_t += delta
	var text := ""
	for cue in NARRATION_SUBS:
		if _narr_t >= float(cue[0]) and _narr_t < float(cue[1]) + 0.25:
			text = cue[2]
			break
	# Sin subtítulos: la narración se escucha sola (los tiempos quedan en NARRATION_SUBS por si se quieren volver a mostrar).
	if SHOW_SUBTITLES:
		ov.set_subtitle(text)


func start_narration() -> void:
	_voice = AudioStreamPlayer.new()
	_voice.stream = NARRATION_AUDIO
	_voice.volume_db = 0.0
	add_child(_voice)
	_voice.play()
	_narr_t = 0.0
	_narr_on = true
	if _music:
		create_tween().set_ignore_time_scale(true).tween_property(_music, "volume_db", -18.0, 1.0)


## Espera hasta el segundo t de la narración (si el plano ya pasó ese punto, no espera).
func until(t: float) -> void:
	while _narr_on and _narr_t < t:
		await get_tree().process_frame


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
	create_tween().set_ignore_time_scale(true).tween_property(_music, "volume_db", db - (13.0 if _narr_on else 0.0), 1.0)


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
	var length: float = clip_len(h.anim.sprite_frames, h.anim.animation)
	# Golpes con hojas muy largas (patada de Jhon, golpe de Thomas): se aceleran como en el juego.
	if clip != &"walk" and clip != &"idle" and clip != &"run" and length > 1.2:
		h.anim.speed_scale = length / 0.9
		length = 0.9
	return length


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
	# Punto de contacto: la cara del enemigo que mira al heroe (según hacia dónde mira).
	var side: float = float(e.get("_facing_sign")) if e.get("_facing_sign") != null else -1.0
	return e.call("ground_position") + Vector2((float(e.get_meta("halfw", 90.0)) - dx) * side, -150)


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
		var push: float = 28.0 if e.global_position.x >= h.global_position.x else -28.0
		t.tween_property(e, "global_position:x", e.global_position.x + push, 0.2)
		await wait(dur * 0.5)
		hero_play(h, &"idle")
		await wait(maxf(0.0, hd - dur * 0.5) * 0.5)
		foe_play(e, &"idle")


## El enemigo cae al suelo (cuadros de "death" hasta la mitad), se queda un momento y se levanta (los mismos cuadros al revés).
func foe_knockdown(e: Node2D, hold := 0.7) -> void:
	var frames: SpriteFrames = e.visual.sprite_frames
	if not frames.has_animation(&"death") or frames.get_frame_count(&"death") == 0:
		return
	var target: int = frames.get_frame_count(&"death") / 2
	if frames is CharacterFrames and (frames as CharacterFrames).knockdown_frame >= 0:
		target = (frames as CharacterFrames).knockdown_frame
	foe_play(e, &"death")
	e.visual.speed_scale = 1.7
	var push := create_tween().set_ignore_time_scale(true)
	push.tween_property(e, "global_position:x", e.global_position.x + 70, 0.35).set_ease(Tween.EASE_OUT)
	for i in 120:
		await get_tree().process_frame
		if e.visual.frame >= target:
			break
	e.visual.pause()
	await wait(hold)
	e.visual.speed_scale = 1.9
	e.visual.play_backwards(&"death")
	for i in 120:
		await get_tree().process_frame
		if e.visual.frame <= 0:
			break
	e.visual.speed_scale = 1.0
	foe_play(e, &"idle")


## Golpe fuerte del enemigo, anunciado con un destello amarillo; el héroe lo para con el bloqueo.
func heavy_blocked(h: Node2D, e: Node2D) -> void:
	e.visual.modulate = Color(1.0, 0.85, 0.35)
	sfx("swing", -4.0)
	foe_play(e, &"attack")
	e.visual.pause()
	e.visual.frame = 0
	hero_play(h, &"block")
	await wait(0.35)
	e.visual.frame = 1
	await wait(0.3)
	e.visual.frame = 2
	e.visual.modulate = Color.WHITE
	CombatFX.hit_impact(h.call("ground_position") + Vector2(60, -170), 0.7, Vector2.LEFT)
	sfx("impact", -1.0)
	var back := create_tween().set_ignore_time_scale(true)
	back.tween_property(h, "global_position:x", h.global_position.x - 40, 0.2)
	await wait(0.35)
	foe_play(e, &"idle")
	hero_play(h, &"idle")


## Escena de la caminata: el líder avanza y la cámara lo sigue; los que se suman corren hasta su lugar detrás de él.
var _walkers: Array = []   # [{node, offset, joined}]


func walk_along(leader: Node2D, speed: float, duration: float, cam_lead: float = 160.0) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		var delta: float = get_process_delta_time()
		elapsed += delta
		leader.global_position.x += speed * delta
		for w in _walkers:
			var node: Node2D = w["node"]
			var target: float = leader.global_position.x - float(w["offset"])
			var gap: float = target - node.global_position.x
			if gap > 24.0:
				# Viene atrás: corre para alcanzar al grupo.
				node.global_position.x += minf(gap, speed * 2.4 * delta)
				if not w["running"]:
					w["running"] = true
					hero_play(node, &"run")
					if not node.anim.sprite_frames.has_animation(&"run") or node.anim.sprite_frames.get_frame_count(&"run") == 0:
						node.anim.speed_scale = 1.7
			else:
				node.global_position.x = target
				if w["running"]:
					w["running"] = false
					hero_play(node, &"walk")
		cam.position.x = leader.global_position.x + cam_lead



# --- ayudantes de los planos de historia -----------------------------------------------------
## Fondo panorámico de un nivel, con la misma posición y escala que en el juego.
func level_bg(tex: Texture2D, pos: Vector2, scale_v: Vector2, sky := Color(0.1, 0.1, 0.12)) -> void:
	var sky_rect := ColorRect.new()
	sky_rect.color = sky
	sky_rect.size = Vector2(12000, 1600)
	sky_rect.position = Vector2(pos.x - 6000, -1000)
	sky_rect.z_index = -200
	world.add_child(sky_rect)
	var bg := Sprite2D.new()
	bg.texture = tex
	bg.position = pos
	bg.scale = scale_v
	bg.z_index = -100
	world.add_child(bg)


## NPC de la historia, quieto y sin conversación propia (las frases las dice el tráiler).
func npc(scene: PackedScene, pos: Vector2, face: float) -> Node2D:
	var n: Node2D = scene.instantiate()
	n.set("dialogue_lines", [] as Array[String])
	n.set("auto_start", false)
	n.position = pos
	var motion := n.get_node_or_null("Motion")
	if motion != null:
		motion.set("wander_range", 0.0)
		motion.set("face_player", false)
		motion.set("idle_face_direction", face)
	world.add_child(n)
	return n


## El grupo (Elliot delante, Jhon y Thomas detrás) caminando hacia x; se detiene ahí.
func group_walk(el: Node2D, followers: Array, to_x: float, speed: float = 150.0) -> void:
	_walkers.clear()
	for i in followers.size():
		_walkers.append({"node": followers[i], "offset": 170.0 * (i + 1), "running": false})
		hero_play(followers[i], &"walk")
	hero_play(el, &"walk")
	await walk_along(el, speed, maxf(to_x - el.global_position.x, 0.0) / speed)
	for f in [el] + followers:
		hero_play(f, &"idle")
	_walkers.clear()


func party_at(x: float, foot_y: float) -> Array:
	var el := hero(ELLIOT, Vector2(x, foot_y + 14))
	var jh := hero(JHON, Vector2(x - 170, foot_y - 6))
	var th := hero(THOMAS, Vector2(x - 340, foot_y + 30))
	return [el, jh, th]


# --- Carteles del pueblo: periódico y desapariciones -----------------------------------------
func shot_posters() -> void:
	clear_world()
	ov.parchment.visible = true
	for l in ov.title_lines:
		l.modulate.a = 0.0
	ov.logo.modulate.a = 0.0
	ov.fade_to(0.0, 0.5)
	await wait(1.0)
	var posters := [
		[load("res://assets/ui/tableros/periodico.png"), "Cuidado con los lobos del camino.", 300.0, -5.0],
		[load("res://assets/ui/tableros/persona_perdida.png"), "No vuelve desde la última luna.", 560.0, 4.0],
		[load("res://assets/ui/tableros/desaparecida.png"), "Hallado en el río: un zapato pequeño y rojo.", 800.0, -3.0],
		[load("res://assets/ui/tableros/se_busca_caperucita.png"), "Los que hablan con desconocidos tardan en volver.", 1010.0, 6.0],
		[load("res://assets/ui/tableros/nina_perdida.png"), "Cada semana, un cartel nuevo.", 660.0, -8.0],
	]
	for item in posters:
		sfx(SND_PAGE, -4.0)
		ov.pin_poster(item[0], item[2], item[3])
		await wait(3.0)
	await until(SHOT_END["posters"] - 2.0)
	ov.flash(Color(0.5, 0.0, 0.0), 0.3, 0.6)
	sfx("corruption", -8.0)
	await wait(0.9)
	ov.clear_posters()
	ov.fade_to(1.0, 0.5)
	await wait(0.6)
	ov.parchment.visible = false


## Presentación de un personaje: aparece en penumbra (silueta), se ilumina, la cámara se acerca y dice su frase.
func reveal(node: Node2D, bg: Texture2D, tint: Color, portrait: Texture2D, title: String, role: String, line: String, card_right := true, end_t: float = 0.0) -> void:
	clear_world()
	add_bg(bg, 1.05, tint * Color(0.35, 0.35, 0.4))
	world.add_child(node)
	node.modulate = Color(0.02, 0.02, 0.03)
	var focus: Vector2 = node.global_position + Vector2(0, -120)
	ov.fade_to(0.0, 0.4)
	move_cam(focus + Vector2(-90, 10), focus, 1.0, 1.35, maxf(3.6, end_t - _narr_t))
	await wait(0.5)
	var light := create_tween().set_ignore_time_scale(true).set_parallel(true)
	light.tween_property(node, "modulate", Color.WHITE, 0.9)
	var bg_node: Node2D = world.get_child(0)
	light.tween_property(bg_node, "modulate", tint, 1.2)
	sfx("rune_activate", -8.0)
	ov.show_card(portrait, title, role, card_right, 2.6)
	await wait(0.9)
	ov.say_quote(title.capitalize(), line, 1.8, -1 if card_right else 1)
	await wait(2.6)
	await until(end_t - 0.4)
	ov.fade_to(1.0, 0.35)
	await wait(0.4)


func story_npc(scene: PackedScene, x: float, face: float, talk := true) -> Node2D:
	var n: Node2D = scene.instantiate()
	n.set("dialogue_lines", [] as Array[String])
	n.set("auto_start", false)
	n.position = Vector2(x, GROUND_Y + 60)
	var motion := n.get_node_or_null("Motion")
	if motion != null:
		motion.set("wander_range", 0.0)
		motion.set("face_player", false)
		motion.set("idle_face_direction", face)
		motion.set("always_talk", talk)
		motion.set("listen_distance", 0.0)
	return n


func shot_reveals() -> void:
	music("music_edge", -5.0)
	var t0: float = SHOT_END["authors"]
	var step: float = (SHOT_END["reveals"] - t0) / 4.0
	await reveal(story_npc(ETHAN, 120, -1.0), BG_ARENA, Color(0.75, 0.8, 0.95), load("res://assets/characters/ethan/Ethan.png"), "ETHAN", "Mira desde lejos", "Aquí nadie llega por casualidad.", true, t0 + step)
	await reveal(story_npc(CAPERUCITA, -60, 1.0), BG_WET, Color(1.0, 0.75, 0.75), load("res://assets/characters/Caperucita/Caperucita.png"), "CAPERUCITA", "Conoce su cuento de memoria", "Todos conocen mi cuento. Nadie conoce el final.", true, t0 + step * 2.0)
	await reveal(story_npc(STEPHY, 80, -1.0), BG_RUINS, Color(0.8, 0.85, 1.0), load("res://assets/characters/Stephy/Stephy.png"), "STEPHY", "No quiere ser vista", "No mires atrás. Él siempre está más cerca.", false, t0 + step * 3.0)
	await reveal(story_npc(ABUELITA, 0, -1.0), BG_RUINS, Color(1.0, 0.7, 0.6), load("res://assets/npc/AbuelitaCaperusita.png"), "LA ABUELITA", "Espera con la mesa servida", "Pasen... la cena ya está lista.", true, SHOT_END["reveals"])
	ov.flash(Color(0.5, 0.0, 0.0), 0.35, 0.6)
	sfx("corruption", -6.0)


# --- Los autores: desde el más allá, raspan y reescriben sus historias ---------------------------
func shot_authors() -> void:
	clear_world()
	add_bg(BG_RUINS, 1.1, Color(0.32, 0.26, 0.4))
	var table := Sprite2D.new()
	table.texture = load("res://assets/ui/pack_gotico/mesa.png")
	table.position = Vector2(0, 150)
	table.scale = Vector2.ONE * 1.15
	world.add_child(table)
	var top_y: float = table.position.y - 378.0 * 1.15 * 0.5 + 30.0
	var props := [
		["res://assets/ui/pack_gotico/obj_pergamino.png", -250.0, 0.42],
		["res://assets/ui/pack_gotico/obj_papiro.png", -110.0, 0.4],
		["res://assets/ui/pack_gotico/obj_tinta.png", 230.0, 0.38],
	]
	for item in props:
		var sp := Sprite2D.new()
		sp.texture = load(item[0])
		sp.scale = Vector2.ONE * item[2]
		sp.position = Vector2(item[1], top_y - sp.texture.get_height() * item[2] * 0.5)
		world.add_child(sp)
	# La pluma escribe y el raspador borra: un palimpsesto.
	var quill := Sprite2D.new()
	quill.texture = load("res://assets/ui/pack_gotico/obj_cana.png")
	quill.scale = Vector2.ONE * 0.42
	quill.position = Vector2(60, top_y - 120)
	quill.rotation_degrees = 18.0
	world.add_child(quill)
	var scraper := Sprite2D.new()
	scraper.texture = load("res://assets/ui/pack_gotico/obj_raspador.png")
	scraper.scale = Vector2.ONE * 0.4
	scraper.position = Vector2(-60, top_y - 100)
	scraper.rotation_degrees = -25.0
	world.add_child(scraper)
	var write := create_tween().set_ignore_time_scale(true).set_loops()
	write.tween_property(quill, "position", quill.position + Vector2(40, 8), 0.7).set_trans(Tween.TRANS_SINE)
	write.tween_property(quill, "position", quill.position, 0.7).set_trans(Tween.TRANS_SINE)
	var scrape := create_tween().set_ignore_time_scale(true).set_loops()
	scrape.tween_property(scraper, "position:x", scraper.position.x - 50.0, 0.45).set_trans(Tween.TRANS_SINE)
	scrape.tween_property(scraper, "position:x", scraper.position.x + 10.0, 0.45).set_trans(Tween.TRANS_SINE)
	# Velas que titilan sobre el altar.
	var glow := ColorRect.new()
	glow.color = Color(1.0, 0.6, 0.25, 0.0)
	glow.size = Vector2(3000, 2000)
	glow.position = Vector2(-1500, -1000)
	glow.z_index = 50
	world.add_child(glow)
	var flicker := create_tween().set_ignore_time_scale(true).set_loops()
	flicker.tween_property(glow, "color:a", 0.07, 0.35)
	flicker.tween_property(glow, "color:a", 0.02, 0.5)
	cam.position_smoothing_enabled = false
	ov.fade_to(0.0, 0.8)
	var dur: float = maxf(SHOT_END["authors"] - _narr_t, 4.0)
	move_cam(Vector2(0, -60), Vector2(0, -20), 0.85, 1.25, dur)
	sfx(SND_PAGE, -6.0)
	# "...hasta llegar a ser una burla": la tinta se vuelve roja.
	await until(66.5)
	ov.flash(Color(0.55, 0.0, 0.0), 0.4, 0.8)
	sfx("corruption", -8.0)
	await until(SHOT_END["authors"] - 0.6)
	write.kill()
	scrape.kill()
	flicker.kill()
	ov.fade_to(1.0, 0.5)
	await wait(0.6)


# --- Pelea en grupo: los tres contra la manada ------------------------------------------------
func shot_horde() -> void:
	music("music_combat", -4.0)
	clear_world()
	add_bg(BG_ARENA, 1.0, Color(0.55, 0.55, 0.7))
	# Tres duelos a la vez, bien separados: Jhon a la izquierda, Elliot al centro y Thomas a la derecha.
	var el := hero(ELLIOT, Vector2(-80, GROUND_Y + 30))
	var w1 := foe(WOLFWHITE, Vector2(110, GROUND_Y + 30), 95.0)
	var jh := hero(JHON, Vector2(-430, GROUND_Y + 14))
	jh.anim.flip_h = true
	var w2 := foe(WOLF3, Vector2(-640, GROUND_Y + 14), 95.0, false)
	var th := hero(THOMAS, Vector2(330, GROUND_Y + 44))
	var gn := foe(GNOMO, Vector2(500, GROUND_Y + 44), 70.0)
	ov.fade_to(0.0, 0.3)
	move_cam(Vector2(-120, 10), Vector2(-90, 20), 0.82, 0.9, 6.0)
	await wait(0.4)
	# Los tres pelean a la vez.
	strike(jh, w2, &"attack", 1.0)
	strike(th, gn, &"attack", 1.1)
	await strike(el, w1, &"attack_1", 0.9)
	strike(jh, w2, &"kick", 1.2, true)
	await strike(el, w1, &"attack_2", 1.0)
	await heavy_blocked(el, w1)
	strike(th, gn, &"kick", 1.6, true)
	await strike(el, w1, &"finisher", 1.8, true)
	ov.flash(Color.WHITE, 0.4, 0.3)
	# Los tres quedan en guardia mientras la cámara se abre sobre el bosque.
	for h in [el, jh, th]:
		hero_play(h, &"block")
	move_cam(cam.position, Vector2(-90, -20), cam.zoom.x, 0.8, maxf(SHOT_END["horde"] - _narr_t, 1.0))
	await until(SHOT_END["horde"] - 0.4)
	ov.fade_to(1.0, 0.3)
	await wait(0.4)


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
	start_narration()
	await shot_departure()
	await shot_posters()
	await shot_authors()
	await shot_reveals()
	await shot_combat()
	await shot_ranger()
	await shot_horde()
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


func shot_departure() -> void:
	clear_world()
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
	_walkers.clear()
	# Elliot sale del pueblo caminando; la narración del juego acompaña la salida.
	var el := hero(ELLIOT, Vector2(-520, VILLAGE_FOOT_Y + 14))
	hero_play(el, &"walk")
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2.ONE * 1.02
	cam.position = Vector2(el.global_position.x + 160.0, 10)
	ov.fade_to(0.0, 0.8)
	await walk_along(el, 150.0, 5.6)
	await walk_along(el, 150.0, 4.4)
	# Se suma Jhon: su retrato en grande y entra corriendo desde atrás.
	ov.show_card(PORTRAIT_JHON, "JHON", "Un hombre de números, perdido entre cuentos", true, 2.6)
	await walk_along(el, 150.0, 0.8)
	var jh := hero(JHON, Vector2(cam.position.x - 820.0, VILLAGE_FOOT_Y - 6))
	_walkers.append({"node": jh, "offset": 170.0, "running": false})
	await walk_along(el, 150.0, 3.6)
	# Se suma Thomas.
	ov.show_card(PORTRAIT_THOMAS, "THOMAS", "Busca a la familia de una vieja foto", false, 2.6)
	await walk_along(el, 150.0, 0.8)
	var th := hero(THOMAS, Vector2(cam.position.x - 820.0, VILLAGE_FOOT_Y + 34))
	_walkers.append({"node": th, "offset": 330.0, "running": false})
	await walk_along(el, 150.0, 3.6)
	await walk_along(el, 150.0, maxf(SHOT_END["departure"] - 0.7 - _narr_t, 0.5))
	ov.fade_to(1.0, 0.6)
	await walk_along(el, 150.0, 0.7)
	_walkers.clear()


func walk_to(h: Node2D, x: float, dur: float) -> void:
	hero_play(h, &"walk")
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(h, "global_position:x", x, dur)
	await wait(dur)
	hero_play(h, &"idle")


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
	# Golpe A: Elliot contra un lobo. Combo, golpe fuerte del lobo bloqueado y remate.
	clear_world()
	add_bg(BG_ARENA, 1.0)
	var el := hero(ELLIOT, Vector2(-160, GROUND_Y + 30))
	var wolf := foe(WOLF1, Vector2(10, GROUND_Y + 30), 100.0)
	ov.fade_to(0.0, 0.3)
	ov.show_plate("ELLIOT", "Llegó a la página equivocada", false, 2.2)
	move_cam(Vector2(-40, 20), Vector2(0, 30), 1.12, 1.0, 5.4)
	await wait(0.5)
	await strike(el, wolf, &"attack_1", 0.8)
	await strike(el, wolf, &"attack_2", 1.0)
	await heavy_blocked(el, wolf)
	await strike(el, wolf, &"kick", 1.1)
	await strike(el, wolf, &"finisher", 1.8, true)
	await wait(0.2)
	ov.fade_to(1.0, 0.2)
	await wait(0.25)
	# Golpe B: Jhon llega corriendo y Thomas derriba al lobo oscuro.
	clear_world()
	add_bg(BG_RUINS, 1.0)
	var jh := hero(JHON, Vector2(-620, GROUND_Y + 25))
	var th := hero(THOMAS, Vector2(-230, GROUND_Y + 50))
	var rg := foe(WOLF2, Vector2(10, GROUND_Y + 30), 100.0)
	ov.fade_to(0.0, 0.2)
	move_cam(Vector2(-200, 20), Vector2(0, 30), 1.0, 1.08, 4.8)
	ov.show_plate("JHON", "Corre, patea y no pregunta", false, 1.8)
	hero_play(jh, &"run")
	var dash := create_tween().set_ignore_time_scale(true)
	dash.tween_property(jh, "global_position:x", -170.0, 0.8)
	await wait(0.8)
	hero_play(jh, &"idle")
	await strike(jh, rg, &"kick", 1.1)
	ov.show_plate("THOMAS", "Golpea primero", true, 1.8)
	await strike(th, rg, &"attack", 1.3)
	await foe_knockdown(rg, 0.6)
	await strike(jh, rg, &"attack", 1.8, true)
	hero_play(jh, &"idle")
	await until(SHOT_END["combat"] - 0.4)
	ov.fade_to(1.0, 0.3)
	await wait(0.4)


## El Ranger: la cámara lo muestra gritando, se lanza, golpe fuerte bloqueado, combo y cae (y se levanta).
func shot_ranger() -> void:
	clear_world()
	add_bg(BG_WET, 1.0)
	var el := hero(ELLIOT, Vector2(-330, GROUND_Y + 30))
	var rg := foe(RANGER, Vector2(320, GROUND_Y + 30), 90.0)
	ov.fade_to(0.0, 0.3)
	move_cam(Vector2(330, -20), Vector2(320, -30), 1.25, 1.3, 1.8)
	await wait(0.4)
	sfx("impact_heavy", -3.0)
	rg.call("taunt")
	ov.say_quote("Ranger Wood", "¡Este bosque no perdona a los de afuera!", 1.4, -1)
	ov.show_plate("RANGER WOOD", "El guardabosque", true, 2.2)
	await wait(2.0)
	move_cam(cam.position, Vector2(-10, 20), 1.3, 1.0, 1.0, Tween.EASE_OUT)
	foe_play(rg, &"walk")
	rg.visual.speed_scale = 1.7
	var charge := create_tween().set_ignore_time_scale(true)
	charge.tween_property(rg, "global_position:x", rg.global_position.x - 370.0, 0.9)
	await wait(0.9)
	rg.visual.speed_scale = 1.0
	foe_play(rg, &"idle")
	await heavy_blocked(el, rg)
	await strike(el, rg, &"attack_1", 0.9)
	await strike(el, rg, &"kick", 1.1)
	# Remate: el Ranger cae al suelo y se vuelve a levantar.
	var dur := hero_play(el, &"finisher")
	sfx("swing")
	await wait(dur * 0.5)
	CombatFX.hit_impact(impact_point(rg, 10), 1.8, Vector2.RIGHT)
	sfx("impact_heavy")
	ov.flash(Color.WHITE, 0.5, 0.3)
	await foe_knockdown(rg, 0.8)
	hero_play(el, &"idle")
	rg.call("taunt")
	await wait(0.6)
	await until(SHOT_END["ranger"] - 0.5)
	ov.fade_to(1.0, 0.4)
	await wait(0.5)


func shot_boss() -> void:
	music("music_boss", -3.0)
	clear_world()
	var bg := add_bg(BG_RUINS, 1.0, Color(0.35, 0.3, 0.4))
	var lobo := foe(LOBO, Vector2(330, GROUND_Y + 40), 150.0)
	lobo.modulate = Color(0.04, 0.03, 0.05)
	var el := hero(ELLIOT, Vector2(30, GROUND_Y + 32))
	var jh := hero(JHON, Vector2(-40, GROUND_Y + 8))
	var th := hero(THOMAS, Vector2(-170, GROUND_Y + 60))
	ov.fade_to(0.0, 0.8)
	move_cam(Vector2(-250, 20), Vector2(-60, 20), 1.0, 1.0, 3.0)
	await wait(0.6)
	ov.say_quote("El Lobo", "Siempre llego primero.", 1.4, -1)
	await wait(1.4)
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
	ov.show_plate("EL LOBO", "Siempre llega primero", true, 2.6)
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
	await until(SHOT_END["boss"] - 0.6)
	ov.fade_to(1.0, 0.6)
	await wait(0.8)
	th.visible = th.visible


func shot_end() -> void:
	clear_world()
	music("music_forest", -4.0)
	ov.parchment.visible = true
	ov.logo.scale = Vector2.ONE * 0.95
	ov.logo.modulate.a = 0.0
	for l in ov.title_lines:
		l.modulate.a = 0.0
	ov.title_lines[1].position.y = 470
	ov.title_lines[1].add_theme_font_size_override("font_size", 30)
	ov.title_lines[1].text = "Próximamente"
	sfx("page_turn")
	ov.fade_to(0.0, 0.8)
	var t := create_tween().set_ignore_time_scale(true).set_parallel(true)
	t.tween_property(ov.logo, "modulate:a", 1.0, 1.4)
	t.tween_property(ov.logo, "scale", Vector2.ONE * 1.05, 9.0)
	await until(SHOT_END["end"] - 3.2)
	create_tween().set_ignore_time_scale(true).tween_property(ov.title_lines[1], "modulate:a", 0.9, 1.0)
	await until(SHOT_END["end"])
	_narr_on = false
	ov.set_subtitle("")
	await wait(1.2)
	ov.fade_to(1.0, 1.4)
	if _music:
		create_tween().set_ignore_time_scale(true).tween_property(_music, "volume_db", -60.0, 1.4)
	await wait(1.6)
