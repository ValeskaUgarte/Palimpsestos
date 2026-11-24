extends Area2D

## Para texto de NARRADOR (las acotaciones del guion, ej: "Elliot abre la
## puerta y mira alrededor...") que no viene de un personaje con el que hablas,
## sino que simplemente aparece cuando Elliot camina hasta cierto punto del
## nivel.
##
## CÓMO USARLO:
## 1) Duplica este nodo (o crea un Area2D nuevo con este script) en el nivel,
##    donde quieras que aparezca el texto.
## 2) Ponle un CollisionShape2D como hijo (del tamaño de la zona que lo activa).
## 3) Rellena "lines" en el Inspector con el texto del guion, una entrada del
##    array por pantalla de texto (igual que "dialogue_lines" en los NPC).
## 4) Listo. Cuando Elliot entra, el texto aparece solo. Se avanza con E igual
##    que cualquier diálogo, y por defecto solo se dispara una vez.

@export var lines: Array[String] = ["..."]
@export var speaker: String = ""  # déjalo vacío para texto de narrador puro
@export var portrait: Texture2D # opcional: retrato al lado del pergamino
@export var one_shot: bool = true
## Imagen que se muestra grande mientras dura la conversación, igual que los anuncios de los tableros (ej. la foto familiar).
@export var poster: Texture2D
## Bandera de GameSession que se pone al terminar la conversación (ej. "thomas_se_une").
@export var sets_flag: String = ""

## Conversación con VARIOS personajes (ej: Elliot y Ethan hablando por turnos,
## tal cual el guion). Si "conversation_speakers"/"conversation_lines" tienen
## contenido, se usan en vez de "lines"/"speaker" de arriba. Deben tener el
## mismo largo: la línea N la dice el personaje N.
## "conversation_portraits" es opcional; si lo dejas más corto que las líneas,
## se repite el último retrato dado (útil cuando el mismo personaje habla
## varias líneas seguidas).
@export var conversation_speakers: Array[String] = []
@export var conversation_lines: Array[String] = []
@export var conversation_portraits: Array[Texture2D] = []

## Solo se dispara si existe esta bandera de GameSession (vacío = siempre). Ej. comentar algo después de una conversación.
@export var requires_flag: String = ""

## ENCUENTRO CON UN ENEMIGO FUERTE (Ranger, lobo gigante, el Lobo...):
##  - encounter_enemy: el enemigo queda dormido (no persigue ni ataca) hasta que termina esta conversación; entonces
##    despierta y se lanza corriendo hacia el jugador.
##  - Mientras dura la conversación el jugador no se mueve (lock_player).
##  - La cámara va a focus_node (por defecto, el enemigo) durante las primeras focus_first_lines líneas y cada vez que
##    habla alguien de focus_speakers (ej. "Ranger"); con el resto de líneas vuelve al jugador. Rápido: corte y diálogo.
@export var encounter_enemy: NodePath
@export var focus_node: NodePath
@export var focus_speakers: Array[String] = []
@export var focus_first_lines: int = 0
@export var lock_player: bool = false

var _triggered: bool = false
var _pending: bool = false  # Elliot entró a la zona pero el cuadro de diálogo estaba ocupado
var _session_key: String = ""
var _cutscene: bool = false
var _line_total: int = 0
var _focus_cam: Camera2D = null
var _focus_y: float = 0.0
var _focused_on: Node2D = null
var _locked: Array = []

# Clave de sesión: escena + nombre del nodo + hash del texto. Así la narración no se repite al recargar el tramo.
func _text_for_key() -> String:
	return "
".join(conversation_lines) if conversation_lines.size() > 0 else "
".join(lines)

func _ready() -> void:
	add_to_group("narrative_trigger")
	var level_path := GameSession.level_path_of(self)
	if level_path != "":
		_session_key = "trigger|" + GameSession.dialogue_key(level_path, String(name), _text_for_key())
		if one_shot and GameSession.dialogue_seen(_session_key):
			_triggered = true
	body_entered.connect(_on_body_entered)
	# El enemigo del encuentro duerme hasta que termine la conversación (si ya se vio, pelea normal).
	if not (_triggered and one_shot):
		var enemy := get_node_or_null(encounter_enemy)
		if enemy != null and "dormant" in enemy:
			enemy.dormant = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not (_triggered and one_shot) and (requires_flag == "" or GameSession.has_flag(requires_flag)):
		_pending = true

func _physics_process(_delta: float) -> void:
	if _cutscene:
		_update_focus()
		return
	if requires_flag != "" and not GameSession.has_flag(requires_flag):
		_pending = false
		return
	if not _pending:
		# El jugador camina siempre por la misma línea del suelo: si la zona quedó colocada más arriba, el solapamiento
		# físico nunca ocurre (ej. S3_LoboAmenaza). Con este chequeo por geometría basta con estar a su altura horizontal.
		if not (_triggered and one_shot) and _geometric_inside():
			_pending = true
		else:
			return
	if not _player_inside():
		_pending = false
		return
	if not DialogueManager.can_start_dialogue():
		return  # hay otro diálogo abierto: se reintenta en el siguiente cuadro
	_pending = false
	_triggered = true
	if _session_key != "" and one_shot:
		GameSession.mark_dialogue_seen(_session_key)
	_show()

func _player_inside() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return _geometric_inside()

## Margen vertical (px) de la zona respecto a los pies del jugador.
@export var vertical_slack: float = 320.0

func _geometric_inside() -> bool:
	if not is_inside_tree() or not monitoring:
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not is_instance_valid(player):
		return false
	var foot := player.get_node_or_null("CollisionShape2D") as Node2D
	var point: Vector2 = foot.global_position if foot != null else player.global_position
	for child in get_children():
		var cs := child as CollisionShape2D
		if cs == null or cs.disabled or cs.shape == null:
			continue
		var scale := cs.global_scale.abs()
		var half := Vector2.ZERO
		if cs.shape is CircleShape2D:
			var radius: float = (cs.shape as CircleShape2D).radius * maxf(scale.x, scale.y)
			half = Vector2(radius, radius)
		elif cs.shape is RectangleShape2D:
			half = (cs.shape as RectangleShape2D).size * 0.5 * scale
		else:
			continue
		if absf(point.x - cs.global_position.x) <= half.x and absf(point.y - cs.global_position.y) <= half.y + vertical_slack:
			return true
	return false

func _show() -> void:
	if poster != null:
		Mochila.show_poster_texture(poster)
	var encounter := String(encounter_enemy) != ""
	_cutscene = encounter or lock_player or String(focus_node) != ""
	if poster != null or sets_flag != "" or _cutscene:
		DialogueManager.dialogue_finished.connect(_on_shown_finished, CONNECT_ONE_SHOT)
	if _cutscene:
		_line_total = conversation_lines.size() if conversation_lines.size() > 0 else lines.size()
		if encounter or lock_player:
			for actor in get_tree().get_nodes_in_group("player"):
				if "input_locked" in actor:
					actor.input_locked = true
					_locked.append(actor)
	if conversation_lines.size() > 0:
		var entries: Array = []
		var last_portrait: Texture2D = null
		for i in range(conversation_lines.size()):
			var spk: String = conversation_speakers[i] if i < conversation_speakers.size() else ""
			if i < conversation_portraits.size():
				last_portrait = conversation_portraits[i]
			entries.append({"text": conversation_lines[i], "speaker": spk, "portrait": last_portrait})
		DialogueManager.show_conversation(entries)
	else:
		DialogueManager.show_dialogue(lines, speaker, portrait)

# Fin de la conversación: se cierra la imagen y se pone la bandera.
func _on_shown_finished() -> void:
	if poster != null:
		Mochila.hide_poster()
	if sets_flag != "":
		GameSession.set_flag(sets_flag)
	if _cutscene:
		_cutscene = false
		_release_focus()
		for actor in _locked:
			if is_instance_valid(actor):
				actor.input_locked = false
		_locked.clear()
		var enemy := get_node_or_null(encounter_enemy)
		if enemy != null and enemy.has_method("engage"):
			enemy.engage(get_tree().get_first_node_in_group("player"))


# --- Cámara del encuentro -----------------------------------------------------------------------------
func _focus_target() -> Node2D:
	var node := get_node_or_null(focus_node) as Node2D
	if node == null:
		node = get_node_or_null(encounter_enemy) as Node2D
	return node


# Línea que se muestra ahora (0, 1, 2...) y si la cámara debe ir al enemigo/personaje enfocado.
func _update_focus() -> void:
	if not DialogueManager.visible:
		return
	var target := _focus_target()
	if target == null:
		return
	var index: int = _line_total - DialogueManager.queue.size() - 1
	var wanted: bool = index < focus_first_lines
	if not wanted and DialogueManager.current_speaker_key != "":
		for speaker_name in focus_speakers:
			if DialogueManager.speaker_key(speaker_name) == DialogueManager.current_speaker_key:
				wanted = true
				break
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var aim: Node2D = target if wanted else player
	if aim == null:
		return
	if _focus_cam == null:
		if not wanted:
			return
		var current := get_viewport().get_camera_2d()
		_focus_cam = Camera2D.new()
		_focus_cam.name = "EncounterCamera"
		if current != null:
			_focus_cam.zoom = current.zoom
			_focus_cam.limit_left = current.limit_left
			_focus_cam.limit_right = current.limit_right
			_focus_cam.limit_top = current.limit_top
			_focus_cam.limit_bottom = current.limit_bottom
		_focus_cam.position_smoothing_enabled = true
		_focus_cam.position_smoothing_speed = 5.0
		get_tree().current_scene.add_child(_focus_cam)
		_focus_cam.global_position = current.get_screen_center_position() if current != null else player.global_position
		# Misma altura que la cámara del juego: solo se desplaza en horizontal (en la cueva, bajar la vista dejaba ver
		# la zona sin fondo).
		_focus_y = _focus_cam.global_position.y
		_focus_cam.reset_smoothing()
		_focus_cam.make_current()
	if aim != _focused_on:
		_focused_on = aim
		# Al pasar al enemigo, grita (sacudón del dibujo).
		if wanted and aim.has_method("taunt"):
			aim.taunt()
	var point: Vector2 = aim.ground_position() if aim.has_method("ground_position") else aim.global_position
	_focus_cam.global_position = Vector2(point.x, _focus_y)


func _release_focus() -> void:
	_focused_on = null
	if _focus_cam == null:
		return
	var cam := _focus_cam
	_focus_cam = null
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var own := player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	if own != null:
		own.make_current()
	cam.queue_free()
