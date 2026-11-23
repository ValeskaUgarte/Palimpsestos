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

var _triggered: bool = false
var _pending: bool = false  # Elliot entró a la zona pero el cuadro de diálogo estaba ocupado
var _session_key: String = ""

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

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not (_triggered and one_shot):
		_pending = true

func _physics_process(_delta: float) -> void:
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
