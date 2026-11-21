extends Node2D

var _time: float = 0.0
func _ready() -> void:
	z_index=0
func _process(delta: float) -> void:
	_time+=delta
	queue_redraw()
func _draw() -> void:
	var flutter: float=sin(_time*.8)*1.2
	var points:=PackedVector2Array([Vector2(-17,-5),Vector2(13,-9+flutter),Vector2(19,5),Vector2(-12,10)])
	draw_colored_polygon(points,Color(.61,.55,.39,.8))
	for line in range(3):
		draw_line(Vector2(-9,-2+line*3),Vector2(6-line*2,-4+line*3),Color(.12,.1,.065,.7),1,true)
