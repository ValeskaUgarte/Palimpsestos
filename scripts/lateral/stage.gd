extends Node2D
@export var arena: bool = false
@export var production_art: bool = true
@export var exploration_music: AudioStream
@export var exploration_title: String = ""
# Qué mundo es esta escena. -1 = lo decide LateralStory (compatibilidad). Con 0, 1 o 2 la escena
# funciona sola: se puede abrir y probar con F6 desde el editor.
@export_range(-1, 2) var chapter_index: int = -1
@export_enum("auto", "normal", "underworld") var realm_kind: String = "auto"
const WORLD = Rect2(0, 0, 2400, 720)
var actor: Node
var opponent: Node
var _panel: CanvasLayer
var _message: Label
var _rune_step: int = 0
var _runes: Array[Node2D] = []
var _exit_marker: Node2D
var _encounter_marker: Node2D
var _selection: bool = false
var _encounter_declined: bool = false
var _won: bool = false
var _crossing: bool = false
var _pending_encounter: Resource
var _portal_revealed: bool = false
var _side_marker: Node2D
var _baked: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if chapter_index >= 0: LateralStory.chapter = chapter_index
	if realm_kind != "auto": LateralStory.realm = realm_kind
	var index: int = LateralStory.chapter
	var profile: Resource = load(["res://resources/audio/forest.tres","res://resources/audio/forest_edge.tres","res://resources/audio/corrupted_forest.tres"][index])
	AudioLandscape.set_profile(profile)
	var music: AudioStream = LateralStory.encounter().music if arena else exploration_music
	if music == null:
		music = load("res://assets/audio/original/"+("music_boss" if index == 2 else "music_combat")+".wav") if arena else load("res://assets/audio/original/"+["music_forest","music_edge","music_corrupted"][index]+".wav")
	AudioLandscape.set_music(music)
	if not arena and LateralStory.realm == "underworld": AudioLandscape.set_music(preload("res://assets/audio/original/music_corrupted.wav"))
	# El diseño de la escena (fondo, muros, marcadores, enemigos...) ya existe como nodos en el editor.
	# Si está, se usa tal cual; si no, se construye por código como antes.
	_baked = _take_layout(index)
	if not _baked:
		_build_world(index)
	var fighter: String = LateralStory.selected if arena else "elliot"
	_drop_placeholder("Elliot_Inicio")
	actor = _spawn_fighter(fighter, Vector2(900 if arena else LateralStory.return_x, 500), false)
	actor.get_node("Camera2D").configure_bounds(Rect2(480,0,1440,720) if arena else WORLD, .92, 320)
	if arena:
		var camera = actor.get_node("Camera2D")
		camera.fixed_framing = true
		camera.fixed_center = WORLD.get_center()
		camera.global_position = WORLD.get_center()
		camera.reset_smoothing()
		camera.force_update_scroll()
	if not arena:
		if _baked:
			_bind_npcs()
			_bind_markers()
			if index == 0: _bind_runes()
			_bind_companions()
		else:
			_spawn_npcs(index)
			_create_markers(index)
			_create_companions(index)
	var hud = preload("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	hud.bind_to_health_component(actor.health)
	var atmosphere := Node2D.new()
	atmosphere.name = "Atmosphere"
	atmosphere.set_script(preload("res://scripts/systems/forest_atmosphere.gd"))
	add_child(atmosphere)
	if arena: atmosphere.fixed_density = 0.55
	else:
		atmosphere.track = actor
		atmosphere.progress_from = 250.0 if LateralStory.realm != "underworld" else -300.0
		atmosphere.progress_to = 2250.0
	if LateralStory.realm == "underworld":
		atmosphere.fog_color = Color(.5,.18,.21,.075)
		atmosphere.mote_color = Color(1,.3,.16,.45)
	var forest_frame := CanvasLayer.new()
	forest_frame.set_script(preload("res://scripts/lateral/forest_frame.gd"))
	add_child(forest_frame)
	var presentation = preload("res://scenes/ui/chapter_presentation.tscn").instantiate()
	presentation.name = "ChapterPresentation"
	presentation.chapter_title = LateralStory.encounter().title if arena else ( ["El bosque antiguo","Más allá del camino","Las historias olvidadas"][index])
	if not arena and not exploration_title.is_empty(): presentation.chapter_title = exploration_title
	presentation.chapter_subtitle = "La página puede volver a escribirse."
	add_child(presentation)
	var layer := CanvasLayer.new()
	add_child(layer)
	_message = Label.new()
	_message.position = Vector2(22, 665)
	_message.add_theme_constant_override("outline_size",6)
	_message.add_theme_color_override("font_outline_color",Color(.02,.02,.025))
	layer.add_child(_message)
	if arena:
		opponent = _spawn_placeholder_enemy(index == 2)
		opponent.health.died.connect(_victory)
		if index == 2:
			var boss_hud := CanvasLayer.new()
			boss_hud.set_script(preload("res://scripts/ui/boss_health.gd"))
			boss_hud.boss = opponent
			add_child(boss_hud)
		rewrite("El relato contiene el aliento.")
		AudioLandscape.hush(.45,.8)
	elif _baked:
		_bind_enemies(index)
	else:
		_create_enemies(index)
	queue_redraw()

# Diseño de la escena. Dos formas:
#  - Escena plana (scenes/demo/...): Pintura, Suelo, muros, enemigos... cuelgan directo de la raíz.
#  - Escena antigua con grupos Capitulo_1/2/3: se usa solo el del capítulo activo.
func _take_layout(index: int) -> bool:
	var layout: Node = get_node_or_null("Capitulo_%d" % (index + 1))
	if layout == null:
		for child in get_children():
			if String(child.name).begins_with("Capitulo_"):
				layout = child
				break
	if layout != null:
		for child in get_children():
			if String(child.name).begins_with("Capitulo_") and child != layout:
				child.queue_free()
		for piece in layout.get_children():
			piece.reparent(self, false)
		layout.queue_free()
	elif get_node_or_null("Suelo") == null:
		return false
	# Las piezas "Vista" sirven para ver la escena en el editor; en el juego no se dibujan.
	for helper in find_children("Vista*", "", true, false):
		helper.visible = false
	return true

func _drop_placeholder(node_name: String) -> void:
	var node := get_node_or_null(node_name)
	if node != null:
		node.queue_free()

func _bind_npcs() -> void:
	for child in get_children():
		if not child.has_meta("ph_npc"): continue
		child.process_mode = Node.PROCESS_MODE_PAUSABLE
		var lines: Array[String] = []
		for line in child.dialogue_lines:
			if not "PLACEHOLDER" in line: lines.append(line)
		child.dialogue_lines = lines
		# Los NPC nuevos ya no traen el dibujo fijo "Visual" (usan el nodo Motion, que apoya los pies solo).
		var visual := child.get_node_or_null("Visual") as Sprite2D
		if visual != null and visual.texture != null:
			var image: Image = visual.texture.get_image()
			visual.position = Vector2(0,-(image.get_used_rect().end.y - visual.texture.get_height() * .5) * visual.scale.y)
		child.get_node("CollisionShape2D").position = Vector2(0,-100)

func _bind_markers() -> void:
	_side_marker = get_node_or_null("PortalLateral") as Node2D
	_exit_marker = get_node_or_null("PortalSalida") as Node2D
	_encounter_marker = get_node_or_null("MarcadorEncuentro") as Node2D

func _bind_runes() -> void:
	_runes.clear()
	for i in 3:
		var rune := get_node_or_null("Runa%d" % (i + 1)) as Node2D
		if rune != null: _runes.append(rune)
	if not _runes.is_empty(): _refresh_runes()

func _bind_companions() -> void:
	var actor_x: float = actor.position.x
	for child in get_children():
		if not child.has_meta("ph_fighter"): continue
		var id: String = child.get_meta("ph_fighter")
		if id == "elliot": continue
		child.queue_free()
		_spawn_fighter(id, Vector2(maxf(actor_x - (140 if id == "jhon" else 250), 70), 500), true)

# Enemigos colocados en la escena. Si su clave ya está resuelta no reaparecen.
func _bind_enemies(index: int) -> void:
	var resolved: Array = LateralStory.resolved
	for child in get_children():
		if not child.has_meta("ph_enemy"): continue
		var key: String = child.get_meta("ph_enemy")
		var pos: Vector2 = child.position
		var path: String = child.scene_file_path
		child.queue_free()
		if key != "" and key in resolved: continue
		_spawn_placed_enemy(pos, path, key, false)
	var zone := get_node_or_null("ZonaEncuentro")
	if zone != null:
		zone.definition = LateralStory.encounter()
	var boss_sprite := get_node_or_null("LoboEsperando") as AnimatedSprite2D
	if boss_sprite != null:
		if LateralStory.realm == "normal" and index == 2 and not "guardian_2" in resolved:
			boss_sprite.play("idle")
		else:
			boss_sprite.queue_free()
	if LateralStory.completed: _finish_panel()

func _spawn_placed_enemy(pos: Vector2, path: String, key: String, boss: bool) -> Node:
	var enemy = _spawn_enemy(pos, boss, path)
	if key != "":
		enemy.health.died.connect(func():
			LateralStory.resolved.append(key)
			LateralStory.save_game()
		)
	return enemy

func _spawn_placeholder_enemy(boss: bool) -> Node:
	var placeholder := get_node_or_null("Oponente")
	if placeholder == null:
		return _spawn_enemy(Vector2(1400,500), boss)
	var pos: Vector2 = placeholder.position
	var path: String = placeholder.scene_file_path
	placeholder.queue_free()
	return _spawn_enemy(pos, boss, path)

# --- Creación por código (escenas sin diseño en el editor) ---

func _create_markers(index: int) -> void:
	if index < 2:
		_side_marker = Node2D.new()
		_side_marker.set_script(preload("res://scripts/lateral/world_marker.gd"))
		_side_marker.portal = true
		_side_marker.portal_color = Color("ef5362")
		_side_marker.position = Vector2(2200,390)
		add_child(_side_marker)
	_exit_marker = Node2D.new()
	_exit_marker.set_script(preload("res://scripts/lateral/world_marker.gd"))
	_exit_marker.portal = true
	_exit_marker.position = Vector2(1940 if index < 2 else 2130,390)
	add_child(_exit_marker)
	_encounter_marker = Node2D.new()
	_encounter_marker.set_script(preload("res://scripts/lateral/world_marker.gd"))
	_encounter_marker.position = Vector2(1250,420)
	add_child(_encounter_marker)
	if index == 0:
		for i in 3:
			var rune := Node2D.new()
			rune.set_script(preload("res://scripts/lateral/rune_glyph.gd"))
			rune.index = i
			rune.position = Vector2(1600+i*120,420)
			add_child(rune)
			_runes.append(rune)
		_refresh_runes()

func _create_companions(index: int) -> void:
	for id in ["jhon","thomas"]:
		if index >= (1 if id == "jhon" else 2): _spawn_fighter(id, Vector2(maxf(actor.position.x - (140 if id == "jhon" else 250), 70),500), true)

func _create_enemies(index: int) -> void:
	var id: String = "normal_" + str(index)
	if not id in LateralStory.resolved:
		var wolf = _spawn_enemy(Vector2(430,500), false)
		wolf.health.died.connect(func():
			LateralStory.resolved.append(id)
			LateralStory.save_game()
		)
	var zone = preload("res://scenes/lateral/encounter_zone.tscn").instantiate()
	zone.definition = LateralStory.encounter()
	zone.position = Vector2(1250,320)
	add_child(zone)
	_spawn_waves(index)
	if index == 2 and LateralStory.realm == "normal" and not "guardian_2" in LateralStory.resolved: _spawn_boss_display()
	if LateralStory.completed: _finish_panel()
	if LateralStory.realm == "underworld":
		for x in [1550,1800]: _spawn_enemy(Vector2(x,500),false)

func _spawn_npcs(index: int) -> void:
	var roster: Array = [["NPC_Mama",150],["NPC_Vecina",1450],["Ethan",1100]] if index == 0 else ([["Ethan",1100]] if index == 1 else [["Ethan",1100],["Stephy",1550],["Caperucita",1770]])
	for entry in roster:
		var npc = load("res://scenes/characters/npc/" + entry[0] + ".tscn").instantiate()
		npc.position = Vector2(entry[1],500)
		npc.process_mode = Node.PROCESS_MODE_PAUSABLE
		# Preserve the authored lines, omit explicitly unfinished editor placeholders.
		var lines: Array[String] = []
		for line in npc.dialogue_lines:
			if not "PLACEHOLDER" in line: lines.append(line)
		npc.dialogue_lines = lines
		add_child(npc)
		var visual := npc.get_node_or_null("Visual") as Sprite2D
		if visual != null:
			var image: Image = visual.texture.get_image()
			visual.position = Vector2(0,-(image.get_used_rect().end.y - visual.texture.get_height() * .5) * visual.scale.y)
		npc.get_node("CollisionShape2D").position = Vector2(0,-100)

func _spawn_fighter(id: String, point: Vector2, follower: bool) -> Node:
	var data: Resource = load("res://resources/lateral/" + id + ".tres")
	var fighter = load(data.scene).instantiate()
	fighter.set_script(preload("res://scripts/lateral/combatant.gd"))
	fighter.fighter_id = id
	fighter.is_companion = follower
	fighter.companion_follow_offset = Vector2(-140 if id == "jhon" else -250,0)
	fighter.position = point
	fighter.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fighter)
	fighter.add_to_group("lateral_actor")
	fighter.health.current_health = int(LateralStory.party_health.get(id, fighter.health.max_health))
	if fighter.health.current_health <= 0: fighter._on_died()
	return fighter
# Vida extra de los oponentes de los demos (ajustable). Arena = combate de práctica; ruta = oleadas del sendero.
const ARENA_HEALTH_MULT := 4.0
const ROUTE_HEALTH_MULT := 2.0
func _spawn_enemy(point: Vector2, boss: bool, scene_path: String = "") -> Node:
	var path: String = scene_path if scene_path != "" else (LateralStory.encounter().enemy_scene if arena else preload("res://resources/lateral/encounters/normal_wolf.tres").enemy_scene)
	var enemy = load(path).instantiate()
	enemy.set_script(preload("res://scripts/lateral/enemy.gd"))
	enemy.boss_encounter = boss
	enemy.position = point
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(enemy)
	# DEMOS: más vida a los oponentes normales para que no caigan de un solo combo (son para practicar).
	if not boss:
		enemy.health.max_health = int(enemy.health.max_health * (ARENA_HEALTH_MULT if arena else ROUTE_HEALTH_MULT))
		enemy.health.current_health = enemy.health.max_health
	if LateralStory.realm == "underworld" and not boss:
		enemy.health.max_health = int(enemy.health.max_health*1.4)
		enemy.health.current_health = enemy.health.max_health
		enemy.attack_damage = int(enemy.attack_damage*1.35)
		enemy.speed *= 1.15
	return enemy
# Oleadas a lo largo del sendero: cada grupo derrotado queda registrado y no reaparece.
const WAVES := [
	[[900,"Wolf1"],[1100,"Wolf1"],[1650,"Wolf2"],[1850,"WolfWhite"],[2050,"Gnomo"]],
	[[850,"Wolf2"],[1000,"WolfWhite"],[1150,"Wolf1"],[1600,"Gnomo"],[1780,"Wolf2"],[1960,"WolfWhite"],[2150,"Wolf1"]],
	[[850,"WolfWhite"],[980,"Gnomo"],[1120,"Wolf2"],[1600,"WolfWhite"],[1740,"Gnomo"],[1880,"Wolf1"],[2040,"Wolf2"],[2170,"WolfWhite"]],
]
func _spawn_waves(index: int) -> void:
	var list: Array = WAVES[clampi(index,0,WAVES.size()-1)]
	for i in list.size():
		var key: String = "wave_%s_%d_%d" % [LateralStory.realm,index,i]
		if key in LateralStory.resolved: continue
		var enemy = _spawn_enemy(Vector2(list[i][0],500),false,"res://scenes/characters/enemies/%s.tscn" % list[i][1])
		enemy.health.died.connect(func():
			LateralStory.resolved.append(key)
			LateralStory.save_game()
		)
# El Lobo se ve esperando en el claro; al llegar a él se entra a la zona de batalla.
func _spawn_boss_display() -> void:
	var frames: SpriteFrames = load("res://assets/enemies/Lobo/lobo-actions.tres")
	var sprite := AnimatedSprite2D.new()
	sprite.name = "LoboEsperando"
	sprite.sprite_frames = frames
	sprite.scale = Vector2(1.9,1.9)
	# El arte del Lobo mira a la IZQUIERDA y el jugador llega desde la izquierda: sin voltear queda de frente (antes estaba de espaldas).
	sprite.flip_h = true  # las hojas actuales del Lobo miran a la derecha; el jugador llega por la izquierda
	var baseline: float = float(frames.get_frame_texture("idle",0).get_meta("pose_art_baseline",200.0))
	sprite.position = Vector2(1500,500 - baseline*sprite.scale.y)
	sprite.z_index = 1
	add_child(sprite)
	sprite.play("idle")
func _build_world(index: int) -> void:
	var texture: Texture2D = load("res://assets/escenarioCaperusita00" + str(index+1) + ".jpg")
	var painting := Sprite2D.new()
	painting.texture = texture
	painting.position = WORLD.get_center()
	painting.scale = Vector2.ONE * maxf(WORLD.size.x / texture.get_width(), WORLD.size.y / texture.get_height())
	if production_art and not arena:
		painting.texture = _environment_texture(index)
		painting.scale = Vector2.ONE * maxf(WORLD.size.x/painting.texture.get_width(),WORLD.size.y/painting.texture.get_height())
		painting.position.y = 500 - painting.texture.get_height()*.19*painting.scale.y
	if arena:
		painting.texture = _environment_texture(index)
		painting.scale = Vector2(1440.0/painting.texture.get_width(),720.0/painting.texture.get_height())
	painting.z_index = -10
	var forest_grade := ShaderMaterial.new()
	forest_grade.shader = preload("res://assets/shaders/forest_presentation.gdshader")
	forest_grade.set_shader_parameter("tone",[Vector3(1,1,1),Vector3(.97,1.02,1.03),Vector3(.94,.88,1.05)][index])
	if LateralStory.realm == "underworld": forest_grade.set_shader_parameter("tone",Vector3(1.1,.68,.72))
	painting.material = forest_grade
	add_child(painting)
	_add_solid(Rect2(0,500,2400,220))
	_add_solid(Rect2(-40,-100,40,900))
	_add_solid(Rect2(2400,-100,40,900))
	if arena:
		_add_solid(Rect2(760,-100,40,900))
		_add_solid(Rect2(1650,-100,40,900))
	if not arena:
		_add_solid(Rect2(560,450,240,50))
		_add_solid(Rect2(820,415,240,85))
func _environment_texture(index: int) -> Texture2D:
	return [preload("res://assets/art/presentation/forest-arena.png"),preload("res://assets/art/presentation/wetland.png"),preload("res://assets/art/presentation/ruins.png")][index]
func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or get_tree().paused or ScenePages.busy or _won or _crossing: return
	if arena:
		_message.text = "J / clic: ataque · K: patada · SPACE: salto · ESC: pausa"
		return
	var index: int = LateralStory.chapter
	var id: String = LateralStory.encounter().encounter_id
	_message.text = "A/D o ←/→ · SPACE: salto · J: ataque · K: patada · E: leer · ESC: pausa"
	_refresh_runes()
	_refresh_world_markers()
	if index == 0 and not "runes_0" in LateralStory.resolved:
		var nearest: int = _rune_in_range()
		if nearest >= 0:
			_message.text = "RUNA %d · Pulsa E o haz clic en el signo · Orden: 1 → 2 → 3 · Leídas: %d/3" % [nearest+1,_rune_step]
	if _pending_encounter != null and not id in LateralStory.resolved and not _selection and actor.is_on_floor():
		_open_encounter(id)
	if not _can_leave() and actor.position.x > 2300: actor.position.x = 2300

func _can_leave() -> bool:
	if not LateralStory.encounter().encounter_id in LateralStory.resolved: return false
	if LateralStory.chapter == 0 and not "runes_0" in LateralStory.resolved: return false
	if LateralStory.realm == "underworld":
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy.get_parent() == self and not enemy._dead: return false
	return true

func _cross_page(destination: String = "normal") -> void:
	if _crossing: return
	_crossing = true
	get_tree().paused = true
	AudioLandscape.cue(&"page_turn")
	var tween := create_tween()
	var portal: Node2D = _side_marker if destination == "underworld" and is_instance_valid(_side_marker) else _exit_marker
	tween.tween_property(portal,"entry_flash",1.0,.45).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(actor.anim,"modulate:a",0.0,.45)
	await tween.finished
	LateralStory.capture_party()
	if LateralStory.chapter < 2:
		LateralStory.chapter += 1
		LateralStory.realm = destination
		LateralStory.return_x = 300
		LateralStory.save_game()
		ScenePages.travel(LateralStory.world_scene())
	else:
		LateralStory.completed = true
		LateralStory.save_game()
		_finish_panel()

func _input(event: InputEvent) -> void:
	# Portal interaction wins before nearby NPCs poll E in their process.
	if arena or not is_instance_valid(actor) or ScenePages.busy or get_tree().paused: return
	if event.is_action_pressed("interact") and not event.is_echo() and _can_leave():
		if absf(actor.position.x-_exit_marker.position.x)<70 or (is_instance_valid(_side_marker) and absf(actor.position.x-_side_marker.position.x)<70):
			_unhandled_input(event)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _selection and not actor._dead:
		if get_tree().paused and is_instance_valid(_panel):
			_panel.queue_free(); get_tree().paused = false; actor._await_action_release = true
		else: _pause_panel()
		get_viewport().set_input_as_handled()
	if arena or get_tree().paused or ScenePages.busy or DialogueManager.visible or actor._dead: return
	if event.is_action_pressed("interact") and not event.is_echo():
		if _can_leave() and actor.is_on_floor():
			if is_instance_valid(_side_marker) and absf(actor.position.x-_side_marker.position.x)<70:
				_cross_page("underworld")
				get_viewport().set_input_as_handled()
				return
			if absf(actor.position.x-_exit_marker.position.x)<70:
				_cross_page("normal")
				get_viewport().set_input_as_handled()
				return
		var nearest: int = _rune_in_range()
		if nearest >= 0:
			_read_rune(nearest)
			get_viewport().set_input_as_handled()
			return
		var pending_id: String = LateralStory.encounter().encounter_id
		if _encounter_declined and not _selection and not pending_id in LateralStory.resolved and absf(actor.position.x-1250) < 170 and actor.is_on_floor():
			_encounter_declined = false
			_open_encounter(pending_id)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i in _runes.size():
			if get_global_mouse_position().distance_to(_runes[i].position) < 44:
				actor._await_action_release = true
				if _rune_in_range() == i: _read_rune(i)
				else: rewrite("Acércate a esta runa para leerla. Pulsa E o haz clic en el signo.")
				get_viewport().set_input_as_handled()
				break

func _rune_in_range() -> int:
	if arena or LateralStory.chapter != 0 or "runes_0" in LateralStory.resolved or not actor.is_on_floor(): return -1
	var nearest: int = -1
	var distance: float = 85
	for i in 3:
		var separation: float = absf(actor.position.x-(1600+i*120))
		if separation < distance:
			distance = separation
			nearest = i
	return nearest

func _refresh_world_markers() -> void:
	var unlocked: bool = _can_leave()
	var next: int = LateralStory.chapter+2
	_exit_marker.refresh(("MUNDO %d" % next if LateralStory.chapter < 2 else "FIN DEL CAPÍTULO")+"\n"+("E · atravesar" if unlocked else "La historia retiene el paso"),unlocked,absf(actor.position.x-_exit_marker.position.x)<85)
	if is_instance_valid(_side_marker):
		_side_marker.refresh("INFRAMUNDO %d\n" % next+("E · atravesar" if unlocked else "La historia retiene el paso"),unlocked,absf(actor.position.x-_side_marker.position.x)<85)
	if not _portal_revealed:
		_exit_marker.visible = unlocked
		if is_instance_valid(_side_marker): _side_marker.visible = unlocked
		if unlocked:
			_portal_revealed = true
			var tween := create_tween().set_parallel(true)
			for portal in [_exit_marker,_side_marker]:
				if not is_instance_valid(portal): continue
				portal.scale = Vector2(.1,.02)
				portal.modulate.a = 0
				tween.tween_property(portal,"scale",Vector2.ONE,.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_property(portal,"modulate:a",1.0,.45)
			AudioLandscape.cue(&"door_open",Vector2(2070,500))
	var beaten: bool = LateralStory.encounter().encounter_id in LateralStory.resolved
	_encounter_marker.visible = not beaten
	if not beaten: _encounter_marker.refresh("ENCUENTRO\n"+("E · desafiar" if _encounter_declined else "Acércate al claro"),_encounter_declined,absf(actor.position.x-1250)<160)

func _refresh_runes() -> void:
	var nearest: int = _rune_in_range()
	for i in _runes.size():
		_runes[i].refresh(i < _rune_step or "runes_0" in LateralStory.resolved, i == nearest)

func _read_rune(index: int) -> void:
	if "runes_0" in LateralStory.resolved: return
	# Re-reading a lit sign never destroys already acquired progress.
	if index < _rune_step: return
	if index != _rune_step:
		AudioLandscape.cue(&"rune_error",_runes[index].position)
		rewrite("Empieza por la runa %d. Lee los signos de izquierda a derecha." % (_rune_step+1))
		return
	_rune_step += 1
	actor.present_interaction(_runes[index].position)
	AudioLandscape.cue(&"rune_activate",_runes[index].position)
	if _rune_step == 3:
		LateralStory.resolved.append("runes_0")
		LateralStory.capture_party()
		LateralStory.save_game()
		AudioLandscape.cue(&"puzzle_complete",actor.position)
		rewrite("Tres runas leídas. El siguiente mundo está a la derecha del sendero.")
	else: rewrite("Runa %d leída · %d/3. Continúa hacia la derecha." % [index+1,_rune_step])
	_refresh_runes()

func request_encounter(definition: Resource) -> void:
	if definition.mode == 0:
		# NORMAL actors fight in the world; no scene transition is requested.
		return
	if definition.encounter_id in LateralStory.resolved or _selection or _encounter_declined: return
	_pending_encounter = definition

func _new_panel(title: String) -> VBoxContainer:
	get_tree().paused = true
	_panel = CanvasLayer.new(); _panel.layer = 40; _panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_panel)
	_panel.add_child(UIKit.dim(.88))
	var box := VBoxContainer.new(); box.set_anchors_and_offsets_preset(Control.PRESET_CENTER); box.offset_left=-250;box.offset_right=250;box.offset_top=-190;box.offset_bottom=190;box.add_theme_constant_override("separation",16);_panel.add_child(box)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var banner: Control = UIKit.banner(title, 120)
	if banner != null:
		box.add_child(banner)
		return box
	var label := Label.new();label.text=title;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;box.add_child(label)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",Color("86d7db"))
	label.add_theme_font_size_override("font_size",23)
	return box
func _button(box: VBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text; box.add_child(button); button.pressed.connect(callback)
	UIKit.skin_by_text(button, 58)
	return button
func _pause_panel() -> void:
	var box = _new_panel("Un margen de silencio")
	_button(box,"Continuar",func():_panel.queue_free();get_tree().paused=false;actor._await_action_release=true).grab_focus()
	_button(box,"Comodidad y controles",func():_panel.add_child(preload("res://scripts/ui/preferences_panel.gd").new()))
	_button(box,"Guardar y volver al menú",func():LateralStory.capture_party();LateralStory.save_game();ScenePages.travel("res://scenes/main_menu.tscn"))
func _open_encounter(id: String) -> void:
	LateralStory.return_x = 1390
	_selection = true
	if LateralStory.encounter().selection_allowed: _choose_fighter(id)
	else: _present_encounter(id)
# El combate es opcional: al rechazarlo, el sendero queda libre y no vuelve a
# interrumpir. Se reabre con E junto al marcador del encuentro.
func _decline_encounter() -> void:
	_encounter_declined = true
	_selection = false
	_pending_encounter = null
	if is_instance_valid(_panel): _panel.queue_free()
	get_tree().paused = false
	actor._await_action_release = true
	rewrite("El claro seguirá ahí. Pulsa E junto al encuentro cuando quieras.")
func _present_encounter(id: String) -> void:
	var box = _new_panel("Una presencia corrompida bloquea el relato")
	_button(box,"Entrar en el claro",func():actor._await_action_release=true;LateralStory.enter_arena(id,"elliot")).grab_focus()
	_button(box,"Volver al sendero",_decline_encounter)
func _choose_fighter(id: String) -> void:
	LateralStory.capture_party()
	var box = _new_panel("EL LOBO · Elige quién escribirá este combate")
	for fighter in ["elliot","jhon","thomas"]:
		var data: Resource = load("res://resources/lateral/" + fighter + ".tres")
		var button = _button(box,data.display_name + " · " + data.style,func():LateralStory.enter_arena(id,fighter))
		button.disabled = LateralStory.party_health.get(fighter,1000) <= 0
		if fighter == "elliot": button.grab_focus()
	_button(box,"Volver al sendero",_decline_encounter)
func _victory() -> void:
	if actor._dead: return
	_won = true
	rewrite("El nombre de la bestia se borra. La página permanece.")
	AudioLandscape.hush(.2,1)
	await get_tree().create_timer(.8,false).timeout
	if actor._dead: return
	var box = _new_panel("El relato puede continuar")
	_button(box,"Regresar al sendero",func():LateralStory.victory()).grab_focus()
func defeat() -> void:
	var box = _new_panel("La página se ha borrado")
	_button(box,"Reintentar desde la entrada",func():LateralStory.retry()).grab_focus()
	_button(box,"Volver al menú",func():ScenePages.travel("res://scenes/main_menu.tscn"))
func _finish_panel() -> void:
	_won = true
	var box = _new_panel("FIN DEL CAPÍTULO · No todo lo escrito permanece")
	_button(box,"Cerrar esta página",func():ScenePages.travel("res://scenes/main_menu.tscn")).grab_focus()
func rewrite(text: String) -> void:
	var presentation = get_node_or_null("ChapterPresentation")
	if presentation: presentation.rewrite(text)
	var atmosphere = get_node_or_null("Atmosphere")
	if atmosphere: atmosphere.rewrite()
func present_boss_phase() -> void:
	rewrite("Una segunda versión despierta.")
	var atmosphere = get_node_or_null("Atmosphere")
	if atmosphere:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(atmosphere,"fog_color",Color(.56,.42,.58,.065),.65)
		tween.tween_property(atmosphere,"mote_color",Color(.94,.64,.43,.42),.65)
func _draw() -> void:
	if arena: return
	var texture: Texture2D = load("res://assets/escenarioCaperusita00" + str(LateralStory.chapter+1) + ".jpg")
	if production_art: texture = _environment_texture(LateralStory.chapter)
	var soil_region := Rect2(0, texture.get_height() * .73, texture.get_width(), texture.get_height() * .27)
	if production_art: soil_region = Rect2(0,texture.get_height()*.67,texture.get_width(),texture.get_height()*.12)
	if not production_art:
		draw_texture_rect_region(texture, Rect2(0,500,2400,220), soil_region, Color(.6,.58,.53))
		draw_line(Vector2(0,500),Vector2(2400,500),Color(.41,.34,.22),3)
	if not arena:
		for rect in [Rect2(560,450,240,50),Rect2(820,415,240,85)]:
			var outline := PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(.97,.72),Vector2(.76,.94),Vector2(.44,.88),Vector2(.14,1),Vector2(0,.74)])
			var points := PackedVector2Array()
			var uv := PackedVector2Array()
			for point in outline:
				points.append(rect.position+point*rect.size)
				uv.append((soil_region.position+point*soil_region.size)/texture.get_size())
			draw_polygon(points,PackedColorArray([Color(.72,.70,.63)]),uv,texture)
			for patch in 12:
				draw_circle(rect.position+Vector2(10+patch*19,1),3+(patch%3),Color(.13,.19,.12,.8))
