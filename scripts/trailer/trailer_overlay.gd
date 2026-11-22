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

var parchment: Control
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
		bar.custom_minimum_size = Vector2(0, 54)
		bar.size = Vector2(1280, 54)
		if i == 1:
			bar.position.y = 720 - 54
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


func show_caption(text: String, hold: float) -> void:
	caption.text = text
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(caption, "modulate:a", 1.0, 0.5)
	t.tween_interval(hold)
	t.tween_property(caption, "modulate:a", 0.0, 0.5)
