extends CanvasLayer
## Capa de postproceso del trailer: pergamino de título, viñeta, barras, subtítulos, flash y fundido.
## Todo se construye por código para no depender de nada del juego salvo el tema del manuscrito.

const THEME := preload("res://resources/ui/manuscript_theme.tres")
const LOGO := preload("res://assets/ui/palimpsestos_logo.png")
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.62;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= 1.15;
	float d = smoothstep(0.30, 0.82, length(uv));
	COLOR = vec4(0.02, 0.015, 0.01, d * strength);
}
"""

## Alto de las franjas negras: el texto va DENTRO de ellas, así ningún personaje lo tapa.
const TOP_BAR := 0.0
const BOTTOM_BAR := 64.0
var parchment: Control
## Subtítulos de la narración (audio Donde_el_miedo_habitaba.mp3), dentro de la franja de abajo.
var subtitle: Label
var _subtitle_text: String = ""
var logo: TextureRect
var title_lines: Array[Label] = []
var caption: Label
var fade_rect: ColorRect
var flash_rect: ColorRect
var bars: Array[ColorRect] = []
var vignette: ColorRect
var _fade_tween: Tween


func _ready() -> void:
	layer = 10
	_build_parchment()
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = VIGNETTE_SHADER
	vignette.material = mat
	add_child(vignette)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
		var bar_h: float = TOP_BAR if i == 0 else BOTTOM_BAR
		bar.custom_minimum_size = Vector2(0, bar_h)
		bar.size = Vector2(1280, bar_h)
		if i == 1:
			bar.position.y = 720 - bar_h
		add_child(bar)
		bars.append(bar)
	caption = Label.new()
	caption.theme = THEME
	caption.add_theme_font_size_override("font_size", 30)
	caption.add_theme_color_override("font_color", Color(0.93, 0.86, 0.68))
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(0, 590)
	caption.size = Vector2(1280, 50)
	caption.modulate.a = 0.0
	add_child(caption)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	add_child(flash_rect)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color.BLACK
	add_child(fade_rect)
	_build_extras()


func _build_parchment() -> void:
	parchment = Control.new()
	parchment.set_anchors_preset(Control.PRESET_FULL_RECT)
	parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parchment.visible = false
	add_child(parchment)
	var base := ColorRect.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.055, 0.045, 0.035)
	parchment.add_child(base)
	var glow := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.42, 0.31, 0.17, 0.85), Color(0.16, 0.11, 0.07, 0.4), Color(0, 0, 0, 0)])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 512
	gt.height = 512
	glow.texture = gt
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	parchment.add_child(glow)
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.draw.connect(func() -> void:
		var c := Color(0.76, 0.64, 0.4, 0.55)
		frame.draw_rect(Rect2(46, 66, 1188, 588), c, false, 2.0)
		frame.draw_rect(Rect2(58, 78, 1164, 564), Color(c, 0.3), false, 1.0)
		for p in [Vector2(46, 66), Vector2(1234, 66), Vector2(46, 654), Vector2(1234, 654)]:
			frame.draw_circle(p, 5, c))
	parchment.add_child(frame)
	for i in 2:
		var l := Label.new()
		l.theme = THEME
		l.add_theme_font_size_override("font_size", 40)
		l.add_theme_color_override("font_color", Color(0.88, 0.8, 0.6))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0, 250 + i * 70)
		l.size = Vector2(1280, 60)
		l.modulate.a = 0.0
		parchment.add_child(l)
		title_lines.append(l)
	logo = TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(240, 150)
	logo.size = Vector2(800, 267)
	logo.pivot_offset = logo.size * 0.5
	logo.modulate.a = 0.0
	parchment.add_child(logo)


func fade_to(alpha: float, duration: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_ignore_time_scale(true)
	_fade_tween.tween_property(fade_rect, "color:a", alpha, duration)


func flash(color: Color, peak: float, duration: float) -> void:
	flash_rect.color = Color(color, peak)
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(flash_rect, "color:a", 0.0, duration)


## Narración (los textos de la historia del juego): arriba, se escribe letra a letra, se lee y se desvanece.
var narration: Label
## Tarjeta de personaje: retrato grande + nombre + rol, entra deslizándose desde un costado.
var card: Control
var card_image: TextureRect
var card_name: Label
var card_role: Label
## Rótulo de nombre durante las peleas (abajo a la izquierda o a la derecha).
var plate: Control
var plate_name: Label
var plate_role: Label


## Gradación de cine para todo el tráiler (no se ve como el juego): menos saturación, tono sepia, contraste y grano.
const GRADE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 sepia = vec3(l * 1.08, l * 0.94, l * 0.76);
	vec3 graded = mix(c, sepia, 0.55 * amount);
	graded = (graded - 0.5) * (1.0 + 0.18 * amount) + 0.5;
	graded *= vec3(1.04, 0.98, 0.9);
	float grain = (hash(SCREEN_UV * 900.0 + TIME) - 0.5) * 0.06 * amount;
	COLOR = vec4(graded + grain, 1.0);
}
"""
var grade: ColorRect
## Frase de personaje (estilo cine, no el pergamino del juego).
var quote: Label
var quote_name: Label


func _build_extras() -> void:
	grade = ColorRect.new()
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gmat := ShaderMaterial.new()
	gmat.shader = Shader.new()
	gmat.shader.code = GRADE_SHADER
	grade.material = gmat
	add_child(grade)
	move_child(grade, 0)
	subtitle = Label.new()
	subtitle.theme = THEME
	subtitle.add_theme_font_size_override("font_size", 25)
	subtitle.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(90, 720 - BOTTOM_BAR + 8)
	subtitle.size = Vector2(1100, BOTTOM_BAR - 16)
	subtitle.modulate.a = 0.0
	add_child(subtitle)
	quote = Label.new()
	quote.theme = THEME
	quote.add_theme_font_size_override("font_size", 27)
	quote.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8))
	quote.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 1.0))
	quote.add_theme_constant_override("outline_size", 9)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.position = Vector2(140, 470)
	quote.size = Vector2(1000, 110)
	quote.modulate.a = 0.0
	add_child(quote)
	quote_name = Label.new()
	quote_name.theme = THEME
	quote_name.add_theme_font_size_override("font_size", 20)
	quote_name.add_theme_color_override("font_color", Color(0.85, 0.66, 0.36))
	quote_name.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 1.0))
	quote_name.add_theme_constant_override("outline_size", 6)
	quote_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_name.position = Vector2(140, 582)
	quote_name.size = Vector2(1000, 30)
	quote_name.modulate.a = 0.0
	add_child(quote_name)
	narration = Label.new()
	narration.theme = THEME
	narration.add_theme_font_size_override("font_size", 25)
	narration.add_theme_color_override("font_color", Color(0.97, 0.92, 0.78))
	narration.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 0.95))
	narration.add_theme_constant_override("outline_size", 7)
	narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narration.position = Vector2(120, 70)
	narration.size = Vector2(1040, 120)
	narration.modulate.a = 0.0
	add_child(narration)
	move_child(narration, flash_rect.get_index())

	card = Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = Vector2(480, 640)
	card.modulate.a = 0.0
	add_child(card)
	move_child(card, flash_rect.get_index())
	var glow := ColorRect.new()
	glow.color = Color(0.0, 0.0, 0.0, 0.0)
	card.add_child(glow)
	card_image = TextureRect.new()
	card_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_image.position = Vector2(0, 0)
	card_image.size = Vector2(480, 440)
	card.add_child(card_image)
	card_name = Label.new()
	card_name.theme = THEME
	card_name.add_theme_font_size_override("font_size", 58)
	card_name.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62))
	card_name.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 1.0))
	card_name.add_theme_constant_override("outline_size", 9)
	card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_name.position = Vector2(0, 392)
	card_name.size = Vector2(480, 70)
	card.add_child(card_name)
	card_role = Label.new()
	card_role.theme = THEME
	card_role.add_theme_font_size_override("font_size", 22)
	card_role.add_theme_color_override("font_color", Color(0.9, 0.84, 0.72))
	card_role.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 1.0))
	card_role.add_theme_constant_override("outline_size", 6)
	card_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_role.position = Vector2(0, 458)
	card_role.size = Vector2(480, 36)
	card.add_child(card_role)

	plate = Control.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size = Vector2(520, 110)
	plate.modulate.a = 0.0
	add_child(plate)
	move_child(plate, flash_rect.get_index())
	var line := ColorRect.new()
	line.color = Color(0.85, 0.66, 0.36, 0.9)
	line.position = Vector2(0, 66)
	line.size = Vector2(360, 3)
	plate.add_child(line)
	plate_name = Label.new()
	plate_name.theme = THEME
	plate_name.add_theme_font_size_override("font_size", 46)
	plate_name.add_theme_color_override("font_color", Color(0.96, 0.88, 0.66))
	plate_name.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 1.0))
	plate_name.add_theme_constant_override("outline_size", 8)
	plate_name.position = Vector2(0, 6)
	plate_name.size = Vector2(520, 60)
	plate.add_child(plate_name)
	plate_role = Label.new()
	plate_role.theme = THEME
	plate_role.add_theme_font_size_override("font_size", 21)
	plate_role.add_theme_color_override("font_color", Color(0.9, 0.84, 0.72))
	plate_role.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.0, 1.0))
	plate_role.add_theme_constant_override("outline_size", 6)
	plate_role.position = Vector2(0, 72)
	plate_role.size = Vector2(520, 32)
	plate.add_child(plate_role)


## Narración: se escribe en `type_time` segundos, se mantiene `hold` y se desvanece.
func narrate(text: String, hold: float, type_time: float = -1.0) -> void:
	return  # La narración ahora es la voz del mp3, con subtítulos abajo (set_subtitle).
	narration.text = text
	narration.visible_ratio = 0.0
	if type_time < 0.0:
		type_time = clampf(text.length() / 48.0, 0.8, 3.2)
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(narration, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(narration, "visible_ratio", 1.0, type_time)
	t.tween_interval(hold)
	t.tween_property(narration, "modulate:a", 0.0, 0.6)


## Tarjeta grande de personaje (retrato, nombre y rol). from_right = entra por la derecha.
func show_card(texture: Texture2D, title: String, role: String, from_right: bool = true, hold: float = 2.4) -> void:
	card_image.texture = texture
	card_name.text = title
	card_role.text = role
	var rest_x: float = 1280.0 - 500.0 if from_right else 20.0
	card.position = Vector2(rest_x + (160.0 if from_right else -160.0), TOP_BAR + 6.0)
	card.modulate.a = 0.0
	var t := create_tween().set_ignore_time_scale(true)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "position:x", rest_x, 0.7)
	t.parallel().tween_property(card, "modulate:a", 1.0, 0.5)
	t.tween_interval(hold)
	t.tween_property(card, "modulate:a", 0.0, 0.5)


## Rótulo con el nombre de quien pelea. on_right = esquina inferior derecha.
func show_plate(title: String, role: String, on_right: bool = false, hold: float = 1.8) -> void:
	plate_name.text = title
	plate_role.text = role
	plate_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if on_right else HORIZONTAL_ALIGNMENT_LEFT
	plate_role.horizontal_alignment = plate_name.horizontal_alignment
	var line := plate.get_child(0) as ColorRect
	line.position.x = 520.0 - line.size.x if on_right else 0.0
	var rest_x: float = 1280.0 - 520.0 - 70.0 if on_right else 70.0
	plate.position = Vector2(rest_x + (60.0 if on_right else -60.0), TOP_BAR + 10.0)
	plate.modulate.a = 0.0
	var t := create_tween().set_ignore_time_scale(true)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(plate, "position:x", rest_x, 0.45)
	t.parallel().tween_property(plate, "modulate:a", 1.0, 0.35)
	t.tween_interval(hold)
	t.tween_property(plate, "modulate:a", 0.0, 0.4)


## Frase grande de un personaje, con su nombre debajo (en vez del pergamino de diálogo del juego).
## Frase de un personaje dentro de la franja de arriba (side se mantiene por compatibilidad: siempre va centrada).
func say_quote(who: String, text: String, hold: float = 2.2, _side: int = 0) -> void:
	# Una sola línea dentro de la franja de abajo: «frase» — Nombre.
	quote.position = Vector2(60, 720 - BOTTOM_BAR + 10)
	quote.size = Vector2(1160, BOTTOM_BAR - 20)
	quote.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quote_name.modulate.a = 0.0
	quote.text = "«" + text + "»   — " + who
	quote_name.text = "— " + who
	quote.visible_ratio = 0.0
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(quote, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(quote, "visible_ratio", 1.0, clampf(text.length() / 40.0, 0.5, 1.6))
	t.tween_interval(hold)
	t.tween_property(quote, "modulate:a", 0.0, 0.5)
	t.parallel().tween_property(quote_name, "modulate:a", 0.0, 0.5)


## Cambia el subtítulo de la narración con un fundido corto ("" lo oculta).
func set_subtitle(text: String) -> void:
	if text == _subtitle_text:
		return
	_subtitle_text = text
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(subtitle, "modulate:a", 0.0, 0.12)
	t.tween_callback(func() -> void: subtitle.text = text)
	if text != "":
		t.tween_property(subtitle, "modulate:a", 1.0, 0.18)


var _posters: Array[TextureRect] = []


## Clava un cartel (periódico, desaparecida...) en pantalla: entra girando un poco y se queda hasta clear_posters().
func pin_poster(texture: Texture2D, center_x: float, degrees: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var h: float = 400.0
	var w: float = h * float(texture.get_width()) / maxf(float(texture.get_height()), 1.0)
	r.size = Vector2(w, h)
	r.pivot_offset = r.size * 0.5
	r.position = Vector2(center_x - w * 0.5, 120.0 + 60.0)
	r.rotation_degrees = degrees * 3.0
	r.modulate.a = 0.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	move_child(r, caption.get_index())
	_posters.append(r)
	var t := create_tween().set_ignore_time_scale(true).set_parallel(true)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(r, "position:y", 120.0, 0.45)
	t.tween_property(r, "rotation_degrees", degrees, 0.45)
	t.tween_property(r, "modulate:a", 1.0, 0.25)
	return r


func clear_posters() -> void:
	for r in _posters:
		var t := create_tween().set_ignore_time_scale(true)
		t.tween_property(r, "modulate:a", 0.0, 0.4)
		t.tween_callback(r.queue_free)
	_posters.clear()


func show_caption(text: String, hold: float) -> void:
	caption.text = text
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(caption, "modulate:a", 1.0, 0.5)
	t.tween_interval(hold)
	t.tween_property(caption, "modulate:a", 0.0, 0.5)
