extends Area2D

@export var dialogue_lines: Array[String] = ["¡Hola, viajero!"]
@export var portrait: Texture2D  # el idle del personaje: aparece al lado del pergamino cuando habla
@export var repeatable: bool = false  # true = se puede volver a hablar con él las veces que quieras (pistas)
@export var speaker_label: String = ""  # nombre que se muestra en el pergamino (vacío = el nombre del nodo)
## true = la conversación empieza sola al acercarte (no hace falta pulsar E). Cada vez que entras al área se habla una vez.
@export var auto_start: bool = true
## SEGUNDA CONVERSACIÓN (evento): cuando exista la bandera "followup_requires_flag" (GameSession) y aún no exista
## "followup_sets_flag", el NPC habla con estas líneas en vez de las normales, empezando solo al acercarte (una única vez).
## Al terminar pone "followup_sets_flag". Ejemplo: Caperucita, al volver de hablar con la abuelita.
@export var followup_lines: Array[String] = []
@export var followup_requires_flag: String = ""
@export var followup_sets_flag: String = ""
## Margen vertical (px) de la zona de conversación: el personaje camina siempre sobre la misma línea del suelo, así que la
## zona no necesita llegar exactamente a sus pies; basta con estar a su altura horizontal.
## (Caperucita en la escena 2 tenía la zona demasiado arriba y nunca hablaba al acercarse.)
@export var interaction_vertical_slack: float = 320.0
var _geo_in_range: bool = false
## Se emite cada vez que termina de hablar contigo (útil para destrabar cosas de la escena).
signal conversation_finished
## Se emite justo cuando empieza a hablar contigo (el nodo Motion la usa para reproducir la animación "talk").
signal conversation_started
var player_in_range: bool = false
var _talking: bool = false
var _completed: bool = false
var _started_this_visit: bool = false

var _cached_key: String = ""
## Ya se habló con él en esta partida (recordado en GameSession): no vuelve a empezar solo al recargar el tramo.
var _auto_done: bool = false
var _followup_talking: bool = false

func followup_pending() -> bool:
	if followup_lines.is_empty() or followup_sets_flag == "":
		return false
	if followup_requires_flag != "" and not GameSession.has_flag(followup_requires_flag):
		return false
	return not GameSession.has_flag(followup_sets_flag)
var _session_key: String = ""

# Clave de sesión: ruta de la escena del nivel + nombre del nodo + hash del texto.
func _session_dialogue_key() -> String:
	if _session_key == "":
		var level_path := ""
		var node: Node = get_parent()
		while node != null:
			if node.scene_file_path in GameSession.LEVELS:
				level_path = node.scene_file_path
				break
			node = node.get_parent()
		if level_path == "":
			return ""
		_session_key = "npc|" + GameSession.dialogue_key(level_path, String(name), "
".join(dialogue_lines))
	return _session_key

func _dialogue_key() -> String:
	# Se calcula una sola vez: _process lo consultaba cada cuadro (join + sha256 por NPC).
	if _cached_key == "":
		_cached_key = "dialogue:" + scene_file_path + ":" + "\n".join(dialogue_lines).sha256_text()
	return _cached_key

func _on_dialogue_finished() -> void:
	if not _talking: return
	_talking = false
	var was_followup := _followup_talking
	_followup_talking = false
	if was_followup:
		GameSession.set_flag(followup_sets_flag)
	else:
		_completed = not repeatable
	# La conversación nueva sustituye a la primera: tampoco ésta vuelve a empezar sola.
	_auto_done = true
	var session_key := _session_dialogue_key()
	if session_key != "":
		GameSession.mark_dialogue_seen(session_key)
	conversation_finished.emit()
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == LateralStory.world_scene():
		var key = _dialogue_key()
		if not key in LateralStory.resolved:
			LateralStory.resolved.append(key)
			LateralStory.capture_party()
			LateralStory.save_game()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var session_key := _session_dialogue_key()
	if session_key != "" and GameSession.dialogue_seen(session_key):
		# Repetible: sigue disponible con E, pero ya no empieza sola. No repetible: ya está hecho.
		_auto_done = true
		_completed = not repeatable
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_started_this_visit = false

# ¿Está el jugador dentro de la zona de conversación? Se calcula por geometría (x exacta, y con margen) en vez de depender
# solo del solapamiento físico del Area2D, que exige que los pies toquen la zona.
func _geometric_in_range() -> bool:
	if not is_inside_tree():
		return false
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or cs.shape == null or cs.disabled or not monitoring:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return false
	var foot := player.get_node_or_null("CollisionShape2D") as Node2D
	var point: Vector2 = foot.global_position if foot != null else player.global_position
	var scale := cs.global_scale.abs()
	var half := Vector2.ZERO
	if cs.shape is CircleShape2D:
		var radius: float = (cs.shape as CircleShape2D).radius * maxf(scale.x, scale.y)
		half = Vector2(radius, radius)
	elif cs.shape is RectangleShape2D:
		half = (cs.shape as RectangleShape2D).size * 0.5 * scale
	else:
		return false
	return absf(point.x - cs.global_position.x) <= half.x and absf(point.y - cs.global_position.y) <= half.y + interaction_vertical_slack

func _on_body_exited(body: Node2D) -> void:
	if _geo_in_range:
		return  # la geometría manda: sigue dentro aunque los pies ya no toquen la zona
	if body.is_in_group("player"):
		player_in_range = false
		if _talking and not DialogueManager.visible:
			_talking = false
			conversation_finished.emit()

func _process(_delta: float) -> void:
	var inside := _geometric_in_range()
	if inside and not _geo_in_range:
		_geo_in_range = true
		player_in_range = true
		_started_this_visit = false
	elif not inside and _geo_in_range:
		_geo_in_range = false
		player_in_range = false
		if _talking and not DialogueManager.visible:
			_talking = false
			conversation_finished.emit()
	# El "not DialogueManager.visible" es clave: sin este chequeo, si te quedas
	# parado dentro del área del NPC, cada vez que apretabas E para AVANZAR el
	# diálogo, este script también detectaba ese mismo E y volvía a llamar
	# show_dialogue(), reiniciando la conversación desde la primera línea.
	# Por eso sentías que tenías que apretar E "para siempre" sin avanzar.
	var followup := followup_pending()
	if (_completed and not followup) or dialogue_lines.is_empty(): return
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == LateralStory.world_scene() and _dialogue_key() in LateralStory.resolved and not followup: return
	if not player_in_range or not DialogueManager.can_start_dialogue(): return
	var pressed := Input.is_action_just_pressed("interact")
	var automatic := auto_start and not _started_this_visit and (followup or not _auto_done)
	if pressed or automatic:
		_started_this_visit = true
		_talking = true
		_followup_talking = followup
		conversation_started.emit()
		DialogueManager.show_dialogue(followup_lines if followup else dialogue_lines, speaker_label if speaker_label != "" else String(name), portrait)
