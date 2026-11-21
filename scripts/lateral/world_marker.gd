extends Node2D
@export var portal: bool = false
@export var portal_color: Color = Color("69c8ff")
var entry_flash: float = 0.0
var _clock: float = 0.0
func _process(delta: float) -> void:
	if portal:
		_clock += delta
		queue_redraw()

var _caption: Label
var _state: String = ""
var _ready_to_use: bool = false
var _nearby: bool = false
func _ready() -> void:
	z_index = 11
	_caption = Label.new()
	_caption.position = Vector2(-150,-210 if portal else -85)
	_caption.size = Vector2(300,65)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("font_size",16)
	_caption.add_theme_color_override("font_outline_color",Color("10171b"))
	_caption.add_theme_constant_override("outline_size",5)
	add_child(_caption)
func refresh(text: String, usable: bool, close: bool) -> void:
	if text == _state and usable == _ready_to_use and close == _nearby: return
	_state = text; _ready_to_use = usable; _nearby = close
	_caption.text = text
	queue_redraw()
func _draw() -> void:
	var color := portal_color if _ready_to_use else Color("9b829f")
	if portal:
		var center := Vector2(0,-18)
		var pulse: float = 1.0 + sin(_clock*1.8)*.025
		for layer in 12:
			var radius: float = 1.0-layer/13.0
			var oval := PackedVector2Array()
			for n in 65:
				var angle: float = TAU*n/64.0
				oval.append(center+Vector2(cos(angle)*65,sin(angle)*123)*radius*pulse)
			draw_colored_polygon(oval,Color(color,.025+entry_flash*.06))
		for ring in 3:
			var rim := PackedVector2Array()
			for n in 81:
				var angle: float = TAU*n/80.0
				var ripple: float = sin(angle*7+_clock*(1.5+ring*.2))*2
				rim.append(center+Vector2(cos(angle)*(65+ring*5+ripple),sin(angle)*(123+ring*4+ripple))*pulse)
			draw_polyline(rim,Color(color,.7-ring*.2),2+entry_flash*3,true)
		for mark in 12:
			var angle: float = TAU*mark/12.0+_clock*.14
			var point := center+Vector2(cos(angle)*79,sin(angle)*140)
			draw_circle(point,1.6,color)
			draw_line(point,point+Vector2(cos(angle),sin(angle))*5,Color(color,.5),1,true)
		for mote in 10:
			var phase: float = fmod(_clock*.15+mote*.1,1.0)
			var point := center+Vector2(sin(mote*2.3+_clock)*40,100-phase*210)
			draw_circle(point,1.5,Color(color,sin(phase*PI)*.7))
		if entry_flash > 0:
			draw_circle(center,170*entry_flash,Color(color,entry_flash*.2))

	else:
		draw_circle(Vector2.ZERO,31,Color("111d24"))
		draw_arc(Vector2.ZERO,34,-PI*.8,PI*.8,48,color,1.6,true)
		draw_polyline(PackedVector2Array([Vector2(-13,14),Vector2(0,-17),Vector2(13,14)]),color,2,true)
		draw_line(Vector2(0,-7),Vector2(0,8),color,2,true)
		draw_circle(Vector2(0,15),1.5,color)
