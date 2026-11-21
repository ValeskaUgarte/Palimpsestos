extends Node
## EQUIPO JUGABLE del nivel: Elliot (principal) y hasta 3 acompañantes (4 personajes en total).
## - Controlas a UN personaje (el activo, grupo "player"). Los demás siguen como acompañantes (grupo "companion").
## - Cambiar: teclas 1-4 (1 = Elliot, 2-4 = acompañantes en el orden en que se unen) o cruceta izquierda/derecha del mando.
## - Un acompañante se une cuando aparece en pantalla por primera vez; su retrato sale a un costado (centro izquierda).
## - Al cambiar a un personaje, este recibe una curación (SWITCH_HEAL_FRACTION de su vida máxima).
## - Un personaje caído no se puede elegir. Si el personaje activo cae, el control pasa a otro vivo;
##   solo si no queda nadie vivo se muestra la derrota.
## Los cambios de personaje no se permiten mientras alguno de los dos está atacando o saltando.

const MAX_MEMBERS := 4
const SWITCH_HEAL_FRACTION := 0.25
const PORTRAIT_PATHS := {
	"Elliot": "res://assets/characters/elliot/Elliot.png",
	"Jhon": "res://assets/characters/John/Jhon.png",
	"Thomas": "res://assets/characters/Thomas/Thomas.png",
}
const FACE_SIZE := Vector2(62, 62)
## Zona de la cara dentro de la imagen completa (fracciones x, y, ancho, alto). Ajustar si la cara no cae bien.
const FACE_CROP := Rect2(0.2, 0.0, 0.6, 0.3)
const SCREEN_MARGIN := 40.0

var level: Node2D = null
var active: CharacterBody2D = null
## Miembros en orden de unión. members[0] es siempre Elliot (tecla 1).
var members: Array[CharacterBody2D] = []
var _joined: Dictionary = {}          # instance_id -> true cuando el personaje ya se unió
var _camera: Camera2D = null
var _layer: CanvasLayer = null
var _column: VBoxContainer = null
var _cards: Dictionary = {}           # instance_id -> {"root", "frame", "portrait", "key", "bar", "name"}


func setup(scene_root: Node2D) -> void:
	level = scene_root
	add_to_group("party")
	var elliot := level.get_node_or_null("Elliot") as CharacterBody2D
	if elliot == null:
		return
	active = elliot
	members.append(elliot)
	_joined[elliot.get_instance_id()] = true
	_camera = elliot.get_node_or_null("Camera2D") as Camera2D
	for child in level.get_children():
		if child is CharacterBody2D and child != elliot and child.get("is_companion") == true:
			if members.size() < MAX_MEMBERS:
				members.append(child)
	_build_ui()
	_add_card(elliot)
	_refresh_ui()


func _process(_delta: float) -> void:
	_check_joins()
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_switch_input():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var slot := _slot_for_key(key.keycode)
		if slot >= 0 and slot < members.size():
			get_viewport().set_input_as_handled()
			select(members[slot])
		return
	var pad := event as InputEventJoypadButton
	if pad != null and pad.pressed:
		if pad.button_index == JOY_BUTTON_DPAD_LEFT:
			get_viewport().set_input_as_handled()
			_cycle(-1)
		elif pad.button_index == JOY_BUTTON_DPAD_RIGHT:
			get_viewport().set_input_as_handled()
			_cycle(1)
		# L1 = siguiente personaje (la cruceta sigue funcionando; R1/L2 abren el mapa).
		elif pad.button_index == JOY_BUTTON_LEFT_SHOULDER:
			get_viewport().set_input_as_handled()
			_cycle(1)


func _slot_for_key(keycode: Key) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
	return -1


func _can_switch_input() -> bool:
	if level == null or active == null or _joined_count() < 2:
		return false
	if get_tree().paused or DialogueManager.visible or ScenePages.busy:
		return false
	if Mochila.is_open() or Mochila.poster_open():
		return false
	return true


func _joined_count() -> int:
	var count := 0
	for member in members:
		if _joined.has(member.get_instance_id()):
			count += 1
	return count


func is_alive(member: CharacterBody2D) -> bool:
	return member != null and is_instance_valid(member) and member.health.current_health > 0


func is_joined(member: CharacterBody2D) -> bool:
	return _joined.has(member.get_instance_id())


## Cambia el control a "member". Devuelve true si el cambio se hizo.
func select(member: CharacterBody2D) -> bool:
	if member == null or member == active or not is_joined(member) or not is_alive(member):
		return false
	if not _is_free(active) or not _is_free(member):
		return false
	_swap_to(member)
	return true


func _cycle(step: int) -> void:
	var joined_members: Array[CharacterBody2D] = []
	for member in members:
		if is_joined(member) and is_alive(member):
			joined_members.append(member)
	if joined_members.size() < 2:
		return
	var index := joined_members.find(active)
	var next := joined_members[posmod(index + step, joined_members.size())]
	select(next)


func _is_free(actor: CharacterBody2D) -> bool:
	return not actor.is_attacking and not actor.is_jumping


## Llamado por player.gd cuando el personaje activo muere. Devuelve true si el control pasó a otro.
func on_active_died(dead: CharacterBody2D) -> bool:
	if dead != active:
		return true
	var next: CharacterBody2D = null
	for member in members:
		if member != dead and is_joined(member) and is_alive(member):
			next = member
			break
	if next == null:
		return false
	_swap_to(next, true)
	return true


func _swap_to(new_active: CharacterBody2D, forced: bool = false) -> void:
	var old := active
	# 1) El que estaba activo pasa a acompañante y sigue al nuevo.
	old.remove_from_group("player")
	old.add_to_group("companion")
	old.is_companion = true
	old.follow_target_path = old.get_path_to(new_active)
	old.velocity = Vector2.ZERO
	old._locomotion = Vector2.ZERO
	old.knockback = Vector2.ZERO
	if old.is_attacking or old.is_jumping:
		old.is_attacking = false
		old.is_jumping = false
		old.jump_height = 0.0
		old._contact_active = false
		old.hitbox_shape.set_deferred("disabled", true)
	# 2) El nuevo pasa a ser el controlado.
	new_active.is_companion = false
	new_active.remove_from_group("companion")
	new_active.add_to_group("player")
	new_active.velocity = Vector2.ZERO
	new_active._locomotion = Vector2.ZERO
	new_active.knockback = Vector2.ZERO
	new_active.buffered_action = ""
	new_active.combo_step = 0
	new_active.combo_timer = 0.0
	active = new_active
	for member in members:
		if member != new_active and member.is_companion and is_alive(member):
			member.follow_target_path = member.get_path_to(new_active)
	# 3) Cámara, pasos, neblina, enemigos y HUD siguen al nuevo.
	_move_camera_to(new_active)
	var footsteps := old.get_node_or_null("Footsteps")
	if footsteps != null:
		footsteps.reparent(new_active, false)
		footsteps.set("_actor", new_active)
	var atmosphere := level.get_node_or_null("ForestAtmosphere")
	if atmosphere != null:
		atmosphere.set("track", new_active)
	_retarget_enemies(old, new_active)
	_bind_hud(old, new_active)
	# 4) Curación al entrar en combate con él.
	if not forced:
		_heal(new_active)
	AudioLandscape.cue(&"ui_accept", new_active.ground_position())
	_refresh_ui()


func _move_camera_to(body: CharacterBody2D) -> void:
	if _camera == null:
		return
	_camera.reparent(body, false)
	_camera.position = _camera.get("framing_offset")
	_camera.set("_body", body)
	_camera.set("_health", body.get_node_or_null("HealthComponent"))
	_camera.set("_last_body_position", body.global_position)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	_camera.make_current()


func _retarget_enemies(old: CharacterBody2D, new_active: CharacterBody2D) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not ("player" in enemy):
			continue
		var detection := enemy.get_node_or_null("DetectionArea") as Area2D
		var sees_new := detection != null and new_active in detection.get_overlapping_bodies()
		if sees_new:
			enemy.player = new_active
		elif enemy.player == old or enemy.player == new_active:
			enemy.player = null


func _bind_hud(old: CharacterBody2D, new_active: CharacterBody2D) -> void:
	var hud := level.get_node_or_null("HUD")
	if hud == null or not hud.has_method("bind_to_health_component"):
		return
	var old_health: Node = old.get_node_or_null("HealthComponent")
	if old_health != null and old_health.health_changed.is_connected(hud.update_health):
		old_health.health_changed.disconnect(hud.update_health)
	hud.bind_to_health_component(new_active.get_node("HealthComponent"))


func _heal(member: CharacterBody2D) -> void:
	var health: Node = member.get_node_or_null("HealthComponent")
	if health == null or health.current_health <= 0:
		return
	var amount := roundi(health.max_health * SWITCH_HEAL_FRACTION)
	health.current_health = mini(health.max_health, health.current_health + amount)
	health.health_changed.emit(health.current_health, health.max_health)


# --- Unión a la historia: un acompañante se une la primera vez que aparece en pantalla.
func _check_joins() -> void:
	if _camera == null:
		return
	var center: Vector2 = _camera.get_screen_center_position()
	var half: Vector2 = get_viewport().get_visible_rect().size / _camera.zoom * 0.5
	for member in members:
		if is_joined(member) or member == members[0]:
			continue
		var pos: Vector2 = member.global_position
		if absf(pos.x - center.x) <= half.x + SCREEN_MARGIN:
			_joined[member.get_instance_id()] = true
			_add_card(member)


# --- Retratos a un costado de la pantalla.
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "PartyPortraits"
	_layer.layer = 1
	add_child(_layer)
	_column = VBoxContainer.new()
	_column.name = "Retratos"
	_column.add_theme_constant_override("separation", 6)
	# Centrado verticalmente en el costado izquierdo.
	_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_column.offset_left = 24.0
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_column)


func _add_card(member: CharacterBody2D) -> void:
	var key := String(member.name)
	# Solo la cara, sin recuadro: se recorta la parte de arriba del retrato (la cabeza).
	var root := Control.new()
	root.custom_minimum_size = FACE_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if PORTRAIT_PATHS.has(key) and ResourceLoader.exists(PORTRAIT_PATHS[key]):
		var full := load(PORTRAIT_PATHS[key]) as Texture2D
		var face := AtlasTexture.new()
		face.atlas = full
		face.region = Rect2(full.get_width() * FACE_CROP.position.x, full.get_height() * FACE_CROP.position.y, full.get_width() * FACE_CROP.size.x, full.get_height() * FACE_CROP.size.y)
		portrait.texture = face
	root.add_child(portrait)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(FACE_SIZE.x, 5)
	bar.size = Vector2(FACE_SIZE.x, 5)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -5
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	_column.add_child(root)
	_cards[member.get_instance_id()] = {"root": root, "portrait": portrait, "bar": bar, "member": member}


func _refresh_ui() -> void:
	if _column == null:
		return
	_column.visible = _joined_count() >= 2
	for member in members:
		var id := member.get_instance_id()
		if not _cards.has(id):
			continue
		var card: Dictionary = _cards[id]
		var health: Node = member.get_node_or_null("HealthComponent")
		var alive := is_alive(member)
		var is_active := member == active
		# El activo se marca con el color de su cara; los demás quedan algo apagados.
		(card["root"] as Control).modulate = Color.WHITE if is_active else Color(0.8, 0.8, 0.8, 1)
		(card["portrait"] as TextureRect).modulate = Color.WHITE if alive else Color(0.25, 0.25, 0.28, 1.0)
		var bar: ProgressBar = card["bar"]
		if health != null:
			bar.max_value = health.max_health
			bar.value = health.current_health
		if not alive:
			(card["root"] as Control).modulate = Color(0.45, 0.45, 0.48, 0.8)
