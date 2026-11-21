extends CanvasLayer

signal dialogue_finished
var _closed_frame: int = -1

const BOX_BOTTOM_MARGIN:=10.0

func can_start_dialogue() -> bool:
	return not visible and Engine.get_process_frames() != _closed_frame

@onready var box: Control = $DialogueBox
@onready var label: Label = $DialogueBox/Label
@onready var speaker_label: Label = $DialogueBox/Speaker
@onready var portrait: TextureRect = $DialogueBox/Portrait

var queue: Array = []
var _text_reveal: Tween
var _auto_left: float = -1.0

# Retratos por personaje: si una línea trae el nombre de quien habla (campo "speaker" o escrito al
# inicio del texto como "Vecina-Hola"), el retrato se pone solo. Agrega aquí a quien falte.
const PORTRAITS := {
	"elliot": "res://assets/characters/elliot/Elliot.png",
	"ethan": "res://assets/characters/ethan/Ethan.png",
	"thomas": "res://assets/characters/Thomas/Thomas.png",
	"jhon": "res://assets/characters/John/Jhon.png",
	"john": "res://assets/characters/John/Jhon.png",
	"stephy": "res://assets/characters/Stephy/Stephy.png",
	"caperucita": "res://assets/characters/Caperucita/Caperucita.png",
	"mama": "res://assets/npc/MamaCaperusita.png",
	"vecina": "res://assets/npc/VecinaCaperusita.png",
	"mara": "res://assets/characters/Mara/Mara.png",
	"jenny": "res://assets/characters/Jenny/Jenny.png",
	"lobo": "res://assets/enemies/Lobo/Lobo.png",
	"abuelita": "res://assets/npc/AbuelitaCaperusita.png",
	"abuela": "res://assets/npc/AbuelitaCaperusita.png",
	# NPC de la escena 1 (usan su propia imagen como retrato; el niño y la niña no se nombran, solo se muestran).
	"padre": "res://assets/npc/Padre_HyG.png",
	"madre": "res://assets/npc/Madre_HyG.png",
	"niño": "res://assets/npc/Hansel.png",
	"niña": "res://assets/npc/Gretel.png",
	"vieja": "res://assets/npc/Vieja.png",
	"hombre del bosque": "res://assets/enemies/RangerWood/Renger.png",
	# Guardabosque: retrato por generar (assets/characters/RangerWood/RangerWood.png). Mientras no exista, la línea sale sin foto.
	"ranger": "res://assets/characters/RangerWood/RangerWood.png",
	"ranger wood": "res://assets/characters/RangerWood/RangerWood.png",
	"guardabosque": "res://assets/characters/RangerWood/RangerWood.png",
	# Gato gris (retrato por generar: assets/characters/Gato/Gato.png).
	"gato": "res://assets/characters/Gato/Gato.png",
}
const DISPLAY_NAMES := {"mama": "Mamá", "john": "Jhon"}
const _SPEAKER_PREFIX := "^\\s*([A-Za-zÁÉÍÓÚáéíóúÑñ_ ]{2,16}?)\\s*[-–—:]\\s*(\\S.*)$"

static func speaker_key(raw: String) -> String:
	var key := raw.strip_edges().to_lower()
	if key.begins_with("npc_"): key = key.substr(4)
	for pair in [["á","a"],["é","e"],["í","i"],["ó","o"],["ú","u"]]:
		key = key.replace(pair[0], pair[1])
	return key

# Completa speaker/retrato de una línea a partir del texto o del nombre.
func _resolve_entry(entry: Dictionary) -> Dictionary:
	var out: Dictionary = entry.duplicate()
	var text: String = str(out.get("text", ""))
	var speaker: String = str(out.get("speaker", ""))
	var regex := RegEx.new()
	regex.compile(_SPEAKER_PREFIX)
	var found := regex.search(text)
	# Si la línea empieza con "Nombre-", ese personaje es quien habla: su retrato manda sobre el del NPC que abrió la conversación
	# (así, cuando Stephy o Mamá "prestan" la conversación a Caperucita, Elliot, etc., sale la foto de quien dice cada frase).
	var prefixed := false
	if found != null and PORTRAITS.has(speaker_key(found.get_string(1))):
		speaker = found.get_string(1).strip_edges()
		text = found.get_string(2)
		prefixed = true
	var key := speaker_key(speaker)
	if speaker != "":
		speaker = DISPLAY_NAMES.get(key, speaker.trim_prefix("NPC_").capitalize() if speaker.begins_with("NPC_") else speaker)
	if PORTRAITS.has(key) and (prefixed or out.get("portrait", null) == null):
		# Carga segura: si el retrato aún no está en el proyecto, la línea se muestra sin foto en vez de dar error.
		if ResourceLoader.exists(PORTRAITS[key]):
			out["portrait"] = load(PORTRAITS[key])
		elif prefixed:
			out["portrait"] = null  # sin foto propia: mejor ninguna que la de otro personaje
	out["text"] = text
	out["speaker"] = speaker
	return out

func _ready() -> void:
	label.add_theme_font_size_override("font_size",int(19 * GamePreferences.text_scale))
	# Sin recuadro oscuro tras el nombre: el nombre va en tinta marrón directamente sobre el pergamino.
	speaker_label.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	speaker_label.add_theme_color_override("font_color",Color(0.3,0.16,0.08))
	speaker_label.add_theme_color_override("font_outline_color",Color(0.95,0.9,0.78,0.9))
	visible = false

# --- Uso simple (un solo personaje hablando, ej. un NPC que saludas) ---
# speaker_name es opcional; si no se pasa, no se muestra el nombre.
# portrait_texture es el idle del personaje: aparece al lado del pergamino.
func show_dialogue(lines: Array, speaker_name: String = "", portrait_texture: Texture2D = null) -> void:
	label.add_theme_font_size_override("font_size",int(19 * GamePreferences.text_scale))
	var entries: Array = []
	for line in lines:
		entries.append({"text": line, "speaker": speaker_name, "portrait": portrait_texture})
	show_conversation(entries)

# --- Uso avanzado: conversación con VARIOS personajes hablando por turnos ---
# (esto es lo que hay que usar para reproducir el guion tal cual, con las
# respuestas de Elliot incluidas y el retrato cambiando según quién habla).
# "entries" es un Array de Dictionary: [{"text":"...", "speaker":"Elliot",
# "portrait": preload("res://...")}, {"text":"...", "speaker":"Jhon", ...}, ...]
func show_conversation(entries: Array) -> void:
	if not can_start_dialogue(): return
	label.add_theme_font_size_override("font_size",int(19 * GamePreferences.text_scale))
	queue = entries.duplicate()
	visible = true
	box.modulate.a = 0.0
	create_tween().tween_property(box, "modulate:a", 1.0, 0.15)
	AudioLandscape.cue(&"dialogue")
	_next_line()

func _next_line() -> void:
	if queue.is_empty():
		visible = false
		_closed_frame = Engine.get_process_frames()
		if _text_reveal: _text_reveal.kill()
		dialogue_finished.emit()
		return
	var entry = _resolve_entry(queue.pop_front())
	if _text_reveal: _text_reveal.kill()
	label.text = entry.get("text", "")
	_fit_text()
	label.visible_characters = 0
	_text_reveal = create_tween()
	_text_reveal.tween_property(label, "visible_characters", label.text.length(), minf(label.text.length() / 110.0, 0.8))
	# Diálogo automático: avanza solo tras un tiempo de lectura corto (más rápido que antes).
	_auto_left = clampf(0.7 + label.text.length() * 0.022, 1.0, 4.0) + minf(label.text.length() / 120.0, 0.6)
	speaker_label.text = entry.get("speaker", "")
	var tex = entry.get("portrait", null)
	portrait.texture = tex
	if tex is Texture2D:
		var image: Image = tex.get_image()
		if image != null:
			var used: Rect2i = image.get_used_rect()
			if used.has_area():
				var head_height: int = maxi(int(used.size.y * 0.34), 1)
				var head_width: int = mini(used.size.x, head_height)
				var crop := AtlasTexture.new()
				crop.atlas = tex
				crop.region = Rect2(used.position.x + (used.size.x - head_width) / 2, used.position.y, head_width, head_height)
				portrait.texture = crop
	portrait.visible = tex != null

func _process(delta: float) -> void:
	if not visible or _auto_left < 0.0 or not GamePreferences.auto_dialogue: return
	if label.visible_characters >= 0 and label.visible_characters < label.text.length(): return
	_auto_left -= delta
	if _auto_left <= 0.0:
		_auto_left = -1.0
		_next_line()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("interact") and not event.is_echo():
		if label.visible_characters >= 0 and label.visible_characters < label.text.length():
			if _text_reveal: _text_reveal.kill()
			label.visible_characters = -1
		else:
			_next_line()
		get_viewport().set_input_as_handled()

func _fit_text() -> void:
	var font=label.get_theme_font("font")
	var font_size=label.get_theme_font_size("font_size")
	# Alto del texto según las líneas que ocupa (interlineado más justo que antes: +3 en vez de +4).
	var height: float=maxf(30,label.get_line_count()*(font.get_height(font_size)+3))
	label.offset_bottom=label.offset_top+height
	var hint: Label=$DialogueBox/ContinueHint
	hint.text="["+GamePreferences.hint_label("interact")+"] "+("adelantar · automático ▾" if GamePreferences.auto_dialogue else "continuar ▾")
	hint.offset_top=label.offset_bottom+4
	hint.offset_bottom=hint.offset_top+22
	# PERGAMINO MÁS BAJO: el alto mínimo pasó de 210 a 140 para que no tape el movimiento del personaje.
	# Si el texto es largo, el pergamino crece solo lo necesario.
	box.offset_top=-(maxf(140,hint.offset_bottom+18)+BOX_BOTTOM_MARGIN)
	box.offset_bottom=-BOX_BOTTOM_MARGIN
