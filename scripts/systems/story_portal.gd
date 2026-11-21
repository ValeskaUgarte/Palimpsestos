extends Node2D
var _strength: float = 0
var _clock: float = 0
var _active: bool = false
func _ready() -> void:
	z_index=0
	get_parent().move_child.call_deferred(self,2)
	set_process(false)
func activate() -> void:
	_active=true
	set_process(true)
	var tween:=create_tween()
	tween.tween_method(_reveal,0.0,1.0,0.8)
func _reveal(value: float) -> void:
	_strength=value
	queue_redraw()
func _process(delta: float) -> void:
	_clock+=delta
	queue_redraw()
func _draw() -> void:
	var center:=Vector2(0,-160)
	var color:=Color(0.65,0.88,0.79,_strength*0.7)
	for i in range(3):
		draw_arc(center,126+i*4,0,TAU,80,Color(color,color.a*(0.17 if i!=1 else 0.7)),1.5,true)
	for symbol in range(16):
		var angle: float = symbol*TAU/16+sin(_clock*0.15)*0.015
		var outward := Vector2(cos(angle),sin(angle))
		var tangent := outward.orthogonal()
		var point: Vector2 = center+outward*128
		draw_line(point-outward*9,point+outward*9,color,1.5,true)
		draw_line(point,point+tangent*7+outward*5,color,1.5,true)
		if symbol%3==0:draw_line(point,point-tangent*6-outward*4,color,1.5,true)
