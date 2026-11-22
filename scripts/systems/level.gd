extends Node2D

@export var camera_bounds: Rect2 = Rect2(-150, -520, 4800, 1080)
@export_range(0.7, 1.3, 0.01) var camera_zoom: float = 0.92
@export var ambience_profile: PalimAmbienceProfile = preload("res://resources/audio/forest.tres")
@export var camera_horizon_y: float = 0.0
## true = al cargar, los NPC y enemigos se pegan a la franja del camino (WalkablePath).
## false = respeta exactamente la posición que tienen en el editor (recomendado para mover personajes a mano).
## Al jugador (Elliot) siempre se le aplica el camino.
## true = escena de interior (casa): sin marco de follaje, niebla, lluvia ni efectos de bosque.
@export var interior: bool = false
@export var snap_actors_to_path: bool = false
# Niebla por zonas: cada Vector2 es (X inicial, X final) del mundo. Vacío = sin niebla.
@export var fog_zones: PackedVector2Array = PackedVector2Array()
@export var fog_fade: float = 700.0
## Densidad de cada zona de niebla (misma posición que en fog_zones). Las que falten usan fog_density.
@export var fog_zone_densities: PackedFloat32Array = PackedFloat32Array()
@export_range(0.0, 1.0, 0.05) var fog_density: float = 0.5
# Lluvia por zonas: cada Vector2 es (X inicial, X final) del mundo. Vacío = sin lluvia.
@export var rain_zones: PackedVector2Array = PackedVector2Array()
@export var rain_fade: float = 600.0
@export_range(0.0, 1.0, 0.05) var rain_density: float = 0.5

const GROUND_SHADOW: Script = preload("res://scripts/characters/ground_shadow.gd")

@onready var hud: CanvasLayer = $HUD
@onready var player: CharacterBody2D = $Elliot

func _ready() -> void:
	# Escena jugable del Cuento I (ver GameSession.PARTS): recorta el nivel a su tramo.
	var part := GameSession.part_for_scene(self)
	if part >= 0:
		_apply_part(part)
	_prepare_path_collisions()
	_setup_depth_sorting()
	_prepare_atmosphere()
	AudioLandscape.set_profile(ambience_profile)
	var boss := get_node_or_null("Lobo")
	if boss != null and boss.is_in_group("enemy"):
		var boss_ui := CanvasLayer.new()
		boss_ui.set_script(preload("res://scripts/ui/boss_health.gd"))
		boss_ui.boss = boss
		add_child(boss_ui)
	var footsteps := Node.new()
	footsteps.name = "Footsteps"
	footsteps.set_script(load("res://scripts/audio/footsteps.gd"))
	player.add_child(footsteps)
	hud.bind_to_health_component(player.get_node("HealthComponent"))
	var camera := player.get_node("Camera2D") as Camera2D
	if camera.has_method("configure_bounds"):
		camera.call("configure_bounds", camera_bounds, camera_zoom, camera_horizon_y)
	for actor in get_children():
		if actor.is_in_group("enemy"):
			actor.health.died.connect(GameSession.record_defeat.bind(scene_file_path,String(actor.name)))
			# Barra de vida sobre la cabeza de cada enemigo (el guardián conserva su barra grande).
			if not actor.is_in_group("story_boss"):
				var health_bar := Node2D.new()
				health_bar.name = "HealthBar"
				health_bar.set_script(preload("res://scripts/systems/enemy_health_bar.gd"))
				actor.add_child(health_bar)
	# Marco de follaje delante de la pantalla, igual que en la campaña lateral.
	if not interior:
		var frame := CanvasLayer.new()
		frame.name = "ForestFrame"
		frame.set_script(preload("res://scripts/lateral/forest_frame.gd"))
		add_child(frame)
	# Equipo: Elliot y los acompañantes; cambiar con 1-4 o la cruceta (ver party.gd).
	var party := Node.new()
	party.set_script(preload("res://scripts/systems/party.gd"))
	party.name = "Party"
	add_child(party)
	party.setup(self)
	var reached_part := part if part >= 0 else GameSession.first_part_of(scene_file_path)
	GameSession.mark_reached_part(reached_part)
	GameSession.enter_level(self)


# --- Escenas jugables (tramos) -------------------------------------------------------------
const LEVEL_EXIT_SCRIPT := preload("res://scripts/systems/level_exit.gd")
const KEEP_NODES := ["Walls", "WalkablePath", "Elliot", "HUD", "PauseMenu", "ChapterPresentation", "ChapterExit", "ForestAtmosphere", "ForestForeground", "ForestFrame", "Party", "NarracionHistoria", "Ground"]
const MARGIN := 150.0

# Ajusta este nivel al tramo `index` de GameSession.PARTS: cámara, paredes, inicio de Elliot,
# enemigos y PNJ fuera del tramo (ocultos y desactivados), salidas y título.
func _apply_part(index: int) -> void:
	var part: Dictionary = GameSession.PARTS[index]
	var left: float = part.from
	var right: float = part.to
	camera_bounds = Rect2(left - 40.0, camera_bounds.position.y, (right - left) + 80.0, camera_bounds.size.y)
	var walls := get_node_or_null("Walls")
	if walls != null:
		var wall_left := walls.get_node_or_null("WallLeft") as Node2D
		if wall_left != null:
			wall_left.position.x = left - 20.0
		var wall_right := walls.get_node_or_null("WallRight") as Node2D
		if wall_right != null:
			wall_right.position.x = right + 20.0
	_cull_children(self, left - MARGIN, right + MARGIN)
	var start: float = part.start
	var elliot := get_node_or_null("Elliot") as Node2D
	if elliot != null and not GameSession.resume_requested:
		elliot.global_position.x = start
	# Compañeros: si están fuera del tramo, se colocan detrás de Elliot.
	var spot := 0
	for companion in get_children():
		if not (companion is CharacterBody2D and companion.is_in_group("companion")):
			continue
		if companion.global_position.x < left - 60.0 or companion.global_position.x > right + 60.0:
			companion.global_position.x = start - 110.0 - 45.0 * spot
			spot += 1
	_setup_exits(index, right)
	var presentation := get_node_or_null("ChapterPresentation")
	if presentation != null and presentation.has_method("present_title"):
		presentation.present_title(part.title, part.sub)

func _cull_children(parent: Node, lo: float, hi: float) -> void:
	for child in parent.get_children():
		if child.name in KEEP_NODES or child is CanvasLayer or child is Camera2D or not child is Node2D:
			continue
		if child.is_in_group("companion") or child.is_in_group("party_actor") or child.is_in_group("player"):
			continue
		if _is_container(child):
			_cull_children(child, lo, hi)
			continue
		if child is CollisionObject2D or child.get_script() != null or child.is_in_group("narrative_trigger") or child.is_in_group("enemy"):
			var x: float = (child as Node2D).global_position.x
			if x < lo or x > hi:
				_disable_subtree(child)

# Contenedor sin cuerpo propio (p. ej. RutaCuento): sus hijos se evalúan uno a uno.
func _is_container(node: Node) -> bool:
	if not node is Node2D or node is CollisionObject2D:
		return false
	for child in node.get_children():
		if child is CollisionObject2D or _is_container(child):
			return true
	return false

func _disable_subtree(node: Node) -> void:
	for group_name in ["enemy", "emboscada", "narrative_trigger", "story_boss"]:
		if node.is_in_group(group_name):
			node.remove_from_group(group_name)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_hide_and_disable(node)

func _hide_and_disable(node: Node) -> void:
	if node is Node2D:
		(node as Node2D).visible = false
	if node is CollisionObject2D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is Area2D:
		node.monitoring = false
		node.monitorable = false
	for child in node.get_children():
		_hide_and_disable(child)

# Salidas: al final de cada tramo, la salida lleva al siguiente tramo (sin cambiar de escena si es el mismo archivo).
func _setup_exits(index: int, right: float) -> void:
	var parts: Array = GameSession.PARTS
	var has_next_here: bool = index + 1 < parts.size() and parts[index + 1].level == scene_file_path
	var chapter := get_node_or_null("ChapterExit") as Area2D
	if chapter != null:
		if has_next_here:
			_disable_subtree(chapter)
		else:
			chapter.position.x = right - 40.0
			chapter.next_part = GameSession.first_part_of(String(chapter.next_scene_path))
	if has_next_here:
		var segment_exit := Area2D.new()
		segment_exit.name = "SegmentExit"
		segment_exit.collision_layer = 0
		# Capa 2 = jugador. No se lee de "chapter": _disable_subtree ya le puso la máscara en 0
		# y el SegmentExit nunca detectaba al jugador (no se pasaba a la siguiente parte).
		segment_exit.collision_mask = 2
		segment_exit.set_script(LEVEL_EXIT_SCRIPT)
		segment_exit.next_scene_path = scene_file_path
		segment_exit.next_part = index + 1
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(60, 1200)
		shape.shape = rectangle
		segment_exit.add_child(shape)
		segment_exit.position = Vector2(right - 30.0, 0.0)
		add_child(segment_exit)
	for node in get_children():
		if node is Area2D and node.get_script() == LEVEL_EXIT_SCRIPT and node != chapter and node.name != "SegmentExit":
			if node.process_mode != Node.PROCESS_MODE_DISABLED:
				node.next_part = GameSession.first_part_of(String(node.next_scene_path))

func _prepare_path_collisions() -> void:
	var path: Node2D = get_node_or_null("WalkablePath")
	if path == null:
		return
	for actor in get_children():
		if not actor is CharacterBody2D:
			_prepare_npc_interaction(actor)
			continue
		actor.z_index = 1
		var shape_node := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var visual := actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if visual == null:
			visual = actor.get_node_or_null("Visual") as AnimatedSprite2D
		if shape_node == null or visual == null or visual.sprite_frames == null:
			continue
		visual.self_modulate *= Color(0.8,0.88,0.93)
		var frames: SpriteFrames = visual.sprite_frames
		if frames.get_frame_count(visual.animation) == 0:
			continue
		var texture: Texture2D = frames.get_frame_texture(visual.animation, 0)
		if texture == null:
			continue
		# Solo una lectura al cargar: encuentra los pies incluso con padding transparente.
		var image: Image = texture.get_image()
		var bottom_pixel: float = texture.get_height()
		if image != null and not image.is_empty():
			var used: Rect2i = image.get_used_rect()
			if used.has_area():
				bottom_pixel = used.end.y
		# AtlasTexture.get_image() devuelve la región sin sus márgenes de dibujo.
		if texture is AtlasTexture:
			bottom_pixel += texture.margin.position.y
		if texture.has_meta("ground_baseline"):
			bottom_pixel = float(texture.get_meta("ground_baseline"))
		var foot_y: float = visual.position.y + (bottom_pixel - texture.get_height() * 0.5) * visual.scale.y
		var foot_shape := RectangleShape2D.new()
		foot_shape.size = Vector2(64.0, 24.0)
		shape_node.shape = foot_shape
		shape_node.position.y = foot_y - 12.0
		if actor.is_in_group("enemy"):
			shape_node.position.x = visual.position.x
			actor.get_node("Hurtbox").position = Vector2.ZERO
			var body_height: float = clampf(image.get_used_rect().size.y * visual.scale.y * 0.85, 120, 520 if actor.is_in_group("story_boss") else 350)
			var hurt_shape := actor.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D
			var hurt_rectangle := RectangleShape2D.new()
			hurt_rectangle.size = Vector2(170 if actor.is_in_group("story_boss") else 110, body_height)
			hurt_shape.shape = hurt_rectangle
			# La hurtbox sigue la X del cuerpo (no el origen): así cuerpo y zona de golpe nunca se separan,
			# aunque el dibujo se haya movido en el editor.
			hurt_shape.position = Vector2(shape_node.position.x, foot_y - body_height * 0.5)
			var attack_shape := actor.get_node("Hitbox/CollisionShape2D") as CollisionShape2D
			var attack_rectangle := RectangleShape2D.new()
			attack_rectangle.size = Vector2(300 if actor.is_in_group("story_boss") else 130, maxf(body_height * 0.6, 90))
			attack_shape.shape = attack_rectangle
			attack_shape.position = Vector2.ZERO
			actor.get_node("Hitbox").position = Vector2(190 if actor.is_in_group("story_boss") else 75, foot_y - body_height * 0.45)
			actor.get_node("DetectionArea/CollisionShape2D").position = Vector2(0, foot_y - 12)
		if actor.is_in_group("companion"):
			# Las zonas de combate siguen el cuerpo visible, no el padding del atlas.
			actor.get_node("Hurtbox").position = Vector2.ZERO
			var companion_hurt := RectangleShape2D.new()
			companion_hurt.size = Vector2(95, 270)
			var companion_hurt_node := actor.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D
			companion_hurt_node.shape = companion_hurt
			companion_hurt_node.position = Vector2(0, foot_y - 135)
			var companion_hit := RectangleShape2D.new()
			companion_hit.size = Vector2(120, 135)
			var companion_hit_node := actor.get_node("Hitbox/CollisionShape2D") as CollisionShape2D
			companion_hit_node.shape = companion_hit
			companion_hit_node.position = Vector2(0, foot_y - 135)
		var foot: Vector2 = actor.global_position + shape_node.position + Vector2(0, 12)
		if snap_actors_to_path or actor == player:
			var placed: Vector2 = path.call("constrain_foot", foot, 26.0)
			actor.global_position += placed - foot
		var shadow := Node2D.new()
		shadow.name = "GroundShadow"
		shadow.set_script(GROUND_SHADOW)
		shadow.position = Vector2(shape_node.position.x, foot_y)
		shadow.show_behind_parent = true
		actor.add_child(shadow)
		actor.move_child(shadow, 0)


func _prepare_npc_interaction(actor: Node) -> void:
	if not actor is Area2D:
		return
	var visual := actor.get_node_or_null("Visual") as Sprite2D
	var collision := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	# NPC sin dibujo fijo (Mamá, Vecina...): solo existe el nodo Motion. Profundidad, tinte y sombra como el resto.
	if visual == null:
		var only_motion := actor.get_node_or_null("Motion") as AnimatedSprite2D
		if only_motion != null and collision != null:
			actor.z_index = 1
			only_motion.self_modulate *= Color(0.8,0.88,0.93)
			var motion_shadow := Node2D.new()
			motion_shadow.name = "GroundShadow"
			motion_shadow.set_script(GROUND_SHADOW)
			var foot_pos = only_motion.get("foot_position")
			motion_shadow.position = foot_pos if foot_pos is Vector2 else Vector2.ZERO
			motion_shadow.show_behind_parent = true
			actor.add_child(motion_shadow)
			actor.move_child(motion_shadow, 0)
		return
	if visual == null or collision == null or visual.texture == null:
		return
	# Usa los píxeles visibles del retrato, no el borde de su lienzo.
	var image: Image = visual.texture.get_image()
	if image == null or image.is_empty():
		return
	var used: Rect2i = image.get_used_rect()
	if not used.has_area():
		return
	# NPC con dibujo fijo (Mamá, Vecina): se respeta exactamente lo que colocaste en el editor (tamaño, sitio y pies).
	# Antes el dibujo se recolocaba para que los pies cayeran en el origen del NPC: por eso quedaba volando.
	# Los NPC con animaciones (nodo Motion) siguen usando el sistema de siempre.
	var motion := actor.get_node_or_null("Motion") as AnimatedSprite2D
	var motion_has_art: bool = motion != null and motion.sprite_frames != null and SpriteFit.resolve_clip(motion.sprite_frames, &"idle", false) != &""
	if not motion_has_art:
		actor.z_index = 1
		visual.self_modulate *= Color(0.8,0.88,0.93)
		var feet_y: float = visual.position.y + (float(used.end.y) - visual.texture.get_height() * 0.5) * visual.scale.y
		var fixed_path := get_node_or_null("WalkablePath")
		if fixed_path and snap_actors_to_path:
			actor.global_position = fixed_path.constrain_foot(actor.global_position, 24.0)
		var fixed_shadow := Node2D.new()
		fixed_shadow.name = "GroundShadow"
		fixed_shadow.set_script(GROUND_SHADOW)
		fixed_shadow.position = Vector2(visual.position.x, feet_y)
		fixed_shadow.show_behind_parent = true
		actor.add_child(fixed_shadow)
		actor.move_child(fixed_shadow, 0)
		return
	actor.z_index = 1
	visual.self_modulate *= Color(0.8,0.88,0.93)
	var height: float = 360.0 if actor.name == "Ethan" else (340.0 if actor.name == "Abuelita" else 320.0)
	visual.scale = Vector2.ONE * height / used.size.y
	var foot_y: float = visual.position.y + (used.end.y - visual.texture.get_height() * 0.5) * visual.scale.y
	visual.position.y -= foot_y
	var path := get_node_or_null("WalkablePath")
	if path and snap_actors_to_path:
		actor.global_position = path.constrain_foot(actor.global_position, 24.0)
	collision.position = Vector2(visual.position.x, -12)
	var shadow := Node2D.new()
	shadow.name = "GroundShadow"
	shadow.set_script(GROUND_SHADOW)
	shadow.position = Vector2(visual.position.x, 0)
	shadow.show_behind_parent = true
	actor.add_child(shadow)
	actor.move_child(shadow, 0)


func _prepare_atmosphere() -> void:
	if interior:
		return
	var shader: Shader = load("res://assets/shaders/forest_atmosphere.gdshader")
	var targets: Array[Node] = get_node("Ground").get_children()
	var second := get_node_or_null("EscenarioCaperusita002")
	if second != null:
		targets.append(second)
	for target in targets:
		if target is Sprite2D:
			# La segunda pintura conserva el material de unión; color de noche por modulate.
			if target.material != null:
				target.modulate = Color(0.58, 0.7, 0.78)
			else:
				var material := ShaderMaterial.new()
				material.shader = shader
				target.material = material
	var atmosphere := Node2D.new()
	atmosphere.name = "ForestAtmosphere"
	atmosphere.set_script(load("res://scripts/systems/forest_atmosphere.gd"))
	if "escena3" in scene_file_path:
		atmosphere.fog_color = Color(0.34,0.43,0.41,0.05)
		atmosphere.mote_color = Color(0.73,0.79,0.65,0.25)
	atmosphere.set("track", player)
	atmosphere.set("progress_from", camera_bounds.position.x + camera_bounds.size.x * 0.12)
	atmosphere.set("progress_to", camera_bounds.end.x - camera_bounds.size.x * 0.06)
	atmosphere.set("fog_zones", fog_zones)
	atmosphere.set("fog_fade", fog_fade)
	atmosphere.set("fog_zone_densities", fog_zone_densities)
	atmosphere.set("fog_density", fog_density)
	atmosphere.set("rain_zones", rain_zones)
	atmosphere.set("rain_fade", rain_fade)
	atmosphere.set("rain_density", rain_density)
	add_child(atmosphere)
	var foreground := Node2D.new()
	foreground.name = "ForestForeground"
	foreground.set_script(preload("res://scripts/systems/forest_foreground.gd"))
	add_child(foreground)
	for item in get_children():
		if item.get_script() == preload("res://scripts/systems/clue_sign.gd"):
			var trace := Node2D.new()
			trace.set_script(preload("res://scripts/systems/memory_trace.gd"))
			trace.position = Vector2(-45,0)
			item.add_child(trace)
	var portal := get_node_or_null("StoryPortal")
	var puzzle := get_node_or_null("Monolito")
	if portal and puzzle and puzzle._solved: portal.activate()


# --- Profundidad: delante / detrás según dónde apoyan los pies -------------------------------------
# Todos los personajes, NPC, aldeanos y animales comparten z_index 1; dentro de ese nivel se dibuja primero
# el que tiene los pies más arriba (más lejos) y al final el que los tiene más abajo (más cerca).
# Así Elliot pasa por detrás de un aldeano que está más abajo, y por delante del que está más arriba.
var _depth_nodes: Array[Node2D] = []


func _setup_depth_sorting() -> void:
	for child in get_children():
		if not child is Node2D:
			continue
		var is_walker: bool = child.get_script() != null and String(child.get_script().resource_path).ends_with("ambient_walker.gd")
		var is_npc: bool = child is Area2D and child.get_node_or_null("Motion") != null
		if child is CharacterBody2D or is_walker or is_npc:
			child.z_index = 1
			_depth_nodes.append(child)


func _depth_foot_y(node: Node2D) -> float:
	if node.has_method("ground_position"):
		return node.ground_position().y
	var motion := node.get_node_or_null("Motion")
	if motion != null and motion.get("foot_position") is Vector2:
		return node.global_position.y + (motion.get("foot_position") as Vector2).y
	return node.global_position.y


func _process(_delta: float) -> void:
	if _depth_nodes.size() < 2:
		return
	var live: Array[Node2D] = []
	for node in _depth_nodes:
		if is_instance_valid(node) and node.get_parent() == self:
			live.append(node)
	var slots: Array[int] = []
	for node in live:
		slots.append(node.get_index())
	slots.sort()
	var ordered: Array[Node2D] = live.duplicate()
	ordered.sort_custom(func(a: Node2D, b: Node2D) -> bool: return _depth_foot_y(a) < _depth_foot_y(b))
	for i in ordered.size():
		if ordered[i].get_index() != slots[i]:
			move_child(ordered[i], slots[i])
