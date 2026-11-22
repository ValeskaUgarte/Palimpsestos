extends Area2D

@export var dialogue_lines: Array[String] = ["¡Hola, viajero!"]
@export var portrait: Texture2D  # el idle del personaje: aparece al lado del pergamino cuando habla
@export var repeatable: bool = false  # true = se puede volver a hablar con él las veces que quieras (pistas)
@export var speaker_label: String = ""  # nombre que se muestra en el pergamino (vacío = el nombre del nodo)
## true = la conversación empieza sola al acercarte (no hace falta pulsar E). Cada vez que entras al área se habla una vez.
@export var auto_start: bool = true
## Se emite cada vez que termina de hablar contigo (útil para destrabar cosas de la escena).
signal conversation_finished
## Se emite justo cuando empieza a hablar contigo (el nodo Motion la usa para reproducir la animación "talk").
signal conversation_started
var player_in_range: bool = false
var _talking: bool = false
var _completed: bool = false
var _started_this_visit: bool = false

var _cached_key: String = ""

func _dialogue_key() -> String:
	# Se calcula una sola vez: _process lo consultaba cada cuadro (join + sha256 por NPC).
	if _cached_key == "":
		_cached_key = "dialogue:" + scene_file_path + ":" + "\n".join(dialogue_lines).sha256_text()
	return _cached_key

func _on_dialogue_finished() -> void:
	if not _talking: return
	_talking = false
	_completed = not repeatable
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
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		_started_this_visit = false

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		if _talking and not DialogueManager.visible:
			_talking = false
			conversation_finished.emit()

func _process(_delta: float) -> void:
	# El "not DialogueManager.visible" es clave: sin este chequeo, si te quedas
	# parado dentro del área del NPC, cada vez que apretabas E para AVANZAR el
	# diálogo, este script también detectaba ese mismo E y volvía a llamar
	# show_dialogue(), reiniciando la conversación desde la primera línea.
	# Por eso sentías que tenías que apretar E "para siempre" sin avanzar.
	if _completed or dialogue_lines.is_empty(): return
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == LateralStory.world_scene() and _dialogue_key() in LateralStory.resolved: return
	if not player_in_range or not DialogueManager.can_start_dialogue(): return
	var pressed := Input.is_action_just_pressed("interact")
	var automatic := auto_start and not _started_this_visit
	if pressed or automatic:
		_started_this_visit = true
		_talking = true
		conversation_started.emit()
		DialogueManager.show_dialogue(dialogue_lines, speaker_label if speaker_label != "" else String(name), portrait)
