extends CanvasLayer
## Narración de la historia: texto que se escribe solo mientras Elliot camina.
## Parte A: arranca sola al empezar la escena y se lee COMPLETA (no se corta con el encuentro con Ethan).
## Parte B: empieza cuando terminó la A Y ya ocurrió la conversación con Ethan. También se lee completa.
## Durante cualquier diálogo el pergamino se oculta y el reloj se detiene; al terminar el diálogo sigue donde iba.
## Parte C: empieza cuando Elliot llega al cruce de caminos (cruce_x), después de la parte B. También se lee completa.
## No pausa el juego. Se muestra en un pergamino pequeño en la esquina para no estorbar.
##
## AJUSTAR TIEMPOS (todo se cambia desde el Inspector del nodo NarracionHistoria):
##   start_delay        -> segundos de espera antes de la parte A
##   chars_per_second   -> velocidad a la que se "escribe" el texto (más alto = más rápido)
##   read_chars_per_second -> velocidad de lectura tras escribir (más alto = el párrafo se queda menos tiempo)
##   min_hold           -> segundos mínimos que se queda un párrafo ya escrito
##   gap_between        -> pausa entre un párrafo y el siguiente
##   part_b_delay       -> espera extra antes de empezar la parte B

@export var start_delay: float = 2.5
@export var encounter_path: NodePath = ^"../EthanEncuentro"
@export var chars_per_second: float = 60.0
@export var read_chars_per_second: float = 45.0
@export var min_hold: float = 0.8
@export var gap_between: float = 0.5
@export var part_b_delay: float = 1.0
## Posición (x) del cruce de caminos donde arranca la parte C.
@export var cruce_x: float = 8000.0
@export var panel_width: float = 440.0

const PART_A: Array[String] = [
	"Durante siglos, distintas obras literarias fueron transformándose a medida que pasaban de una generación a otra, relatos que originalmente no fueron concebidos como simples cuentos infantiles terminaron convirtiéndose, con el paso del tiempo, en versiones mucho más inocentes de sí mismos.",
	"Autores como Charles Perrault, Giambattista Basile, Hans Christian Andersen y los hermanos Jacob y Wilhelm Grimm escribieron historias que contenían mucho más que fantasía, en ellas existían advertencias, peligros, violencia, miedo y consecuencias, Caperucita Roja, La Bella Durmiente, Cenicienta, La Sirenita, Hansel y Gretel y muchas otras obras fueron creadas en contextos y épocas muy diferentes a las versiones que posteriormente llegarían al público moderno.",
	"Desde el más allá, sus autores observan durante generaciones cómo sus historias son modificadas, suavizadas y transformadas hasta perder aquello que alguna vez quisieron transmitirse toco la esencia, se manipulo el contexto, hasta llegar a ser una burla sus etnias y característica que las hacían apreciadas por el público y la época en la que estaban dirigidas.",
]
const PART_B: Array[String] = [
	"Lo que comenzó como una transformación termina convirtiéndose, para ellos, en una aberración.",
	"Sus historias fueron despojadas de aquello que las hacía advertencias, el miedo fue reemplazado por seguridad, el peligro dejó de tener consecuencias, lo oscuro y la realidad que vivían aquellos tiempos fue ocultado para convertir aquellas obras en relatos destinados principalmente a entretener.",
	"Los autores observan todo esto y finalmente deciden intervenir, no pretenden simplemente recuperar sus historias originales, quieren que los seres humanos vuelvan a experimentar aquello que, según ellos, fue eliminado de sus obras.",
]

const PART_C: Array[String] = [
	"Crean entonces un mundo construido a partir de sus relatos, pero no de las versiones que el mundo moderno conoce.",
	"Es un mundo donde los cuentos recuperan su naturaleza más oscura, un lugar donde el bosque vuelve a ser peligroso, donde las criaturas no están allí para ayudar al protagonista y donde las decisiones pueden tener consecuencias reales, la realidad de no todo lo que brilla es oro y tus decisiones y actos pueden llevarte a descubrir que eres dueño de tu propio destino.",
	"Un mundo creado para recordar que detrás de aquellas historias existía una advertencia.",
]


var _panel: PanelContainer
var _label: Label
var _stage: int = 0  # 0 espera inicial · 1 parte A · 2 esperando encuentro · 3 parte B · 4 esperando el cruce · 5 parte C · 6 fin
var _wait: float = 0.0
var _parts: Array = []
var _index: int = 0
var _phase: int = 0  # 0 inactivo · 1 escribiendo · 2 leyendo · 3 desvaneciendo · 4 pausa entre párrafos
var _clock: float = 0.0
var _text: String = ""
var _hold: float = 0.0
var _alpha: float = 0.0

const FADE_IN := 0.4
const FADE_OUT := 0.5

func _ready() -> void:
	layer = 20
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -(panel_width + 18.0)
	_panel.offset_right = -18.0
	# Bajado para no quedar encima de los botones Mochila/Mapa (y de la tarjeta del objeto): se lee completo.
	_panel.offset_top = 96.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	# Sin pergamino: solo el texto de la historia, con contorno oscuro para leerse sobre el escenario.
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = panel_width - 40.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", int(15 * GamePreferences.text_scale))
	_label.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 0.95))
	_label.add_theme_constant_override("outline_size", 6)
	_panel.add_child(_label)
	add_child(_panel)

func _process(delta: float) -> void:
	if ScenePages.busy:
		return
	# Con un diálogo abierto el pergamino se esconde y el reloj se congela.
	var talking: bool = DialogueManager.visible
	_panel.visible = not talking
	if talking:
		return
	match _stage:
		0:
			_wait += delta
			if _wait >= start_delay:
				_start(PART_A, 1)
		1:
			if _advance(delta):
				_stage = 2
				_wait = 0.0
		2:
			if _encounter_started():
				_wait += delta
				if _wait >= part_b_delay:
					_start(PART_B, 3)
		3:
			if _advance(delta):
				_stage = 4
		4:
			# Espera a que Elliot llegue al cruce de caminos.
			if _player_x() >= cruce_x:
				_start(PART_C, 5)
		5:
			if _advance(delta):
				_stage = 6

func _start(parts: Array, stage: int) -> void:
	_parts = parts
	_index = 0
	_stage = stage
	_begin_paragraph()

func _begin_paragraph() -> void:
	_text = _parts[_index]
	_label.text = _text
	_label.visible_characters = 0
	_clock = 0.0
	_phase = 1
	_hold = min_hold + _text.length() / maxf(read_chars_per_second, 1.0)

# Avanza el párrafo actual. Devuelve true cuando ya no quedan párrafos.
func _advance(delta: float) -> bool:
	_clock += delta
	match _phase:
		1:
			_alpha = minf(_clock / FADE_IN, 1.0)
			var shown: int = int(_clock * chars_per_second)
			_label.visible_characters = mini(shown, _text.length())
			if shown >= _text.length():
				_phase = 2
				_clock = 0.0
		2:
			_alpha = 1.0
			if _clock >= _hold:
				_phase = 3
				_clock = 0.0
		3:
			_alpha = 1.0 - minf(_clock / FADE_OUT, 1.0)
			if _clock >= FADE_OUT:
				_phase = 4
				_clock = 0.0
		4:
			_alpha = 0.0
			if _clock >= gap_between:
				_index += 1
				if _index >= _parts.size():
					_phase = 0
					return true
				_begin_paragraph()
	_panel.modulate.a = _alpha
	return false

func _encounter_started() -> bool:
	var encounter := get_node_or_null(encounter_path)
	return encounter != null and encounter.get("_triggered") == true


# Posición horizontal de Elliot (devuelve un valor muy bajo si aún no existe).
func _player_x() -> float:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player.global_position.x if player != null else -100000.0
