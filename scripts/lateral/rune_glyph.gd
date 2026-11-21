extends Node2D
@export var index: int = 0
var active: bool = false
var nearby: bool = false
var _caption: Label
func _ready() -> void:
	z_index = 12
	_caption = Label.new()
	_caption.position = Vector2(-90,-92)
	_caption.size = Vector2(180,30)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("font_size",16)
	_caption.add_theme_color_override("font_outline_color",Color("10171b"))
	_caption.add_theme_constant_override("outline_size",5)
	add_child(_caption)
	refresh(false,false)
func refresh(lit: bool, close: bool) -> void:
	if _caption and active == lit and nearby == close and _caption.text != "": return
	active = lit; nearby = close
	if _caption:
		_caption.text = "✓ LEÍDA" if active else ("E · LEER" if nearby else "RUNA " + str(index+1))
	queue_redraw()
func _draw() -> void:
	var ink := Color("f1d49c") if active else Color("86d7db")
	for ring in 3:
		draw_circle(Vector2.ZERO,44-ring*3,Color(ink,.035 if not nearby else .07))
	draw_circle(Vector2.ZERO,34,Color("111d24"))
	draw_arc(Vector2.ZERO,34,-PI*.85,PI*.85,48,Color(ink,.8),1.6,true)
	draw_arc(Vector2.ZERO,26,PI*.15,PI*.85,24,Color(ink,.4),1,true)
	draw_line(Vector2(0,35),Vector2(0,45),ink,2,true)
	draw_polyline(PackedVector2Array([Vector2(0,-20),Vector2(14,0),Vector2(0,20),Vector2(-14,0),Vector2(0,-20)]),ink,2,true)
	for mark in index+1:
		var y: float = -6+mark*6
		draw_line(Vector2(-7,y),Vector2(7,y),ink,1.5,true)
	if nearby: draw_arc(Vector2.ZERO,39,0,TAU,60,Color(ink,.65),1,true)
