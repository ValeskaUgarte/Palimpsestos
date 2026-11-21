extends Node2D
var charge: bool = false
var direction: float = 1.0
func _draw() -> void:
	var color:=Color(.73,.55,.29,.65)
	var length: float=210 if charge else 100
	draw_line(Vector2.ZERO,Vector2(direction*length,0),color,2,true)
	for marker in range(1,5):
		var x: float=direction*length*marker/5
		draw_line(Vector2(x-4,-6),Vector2(x+4,6),color,1.5,true)
	if charge:draw_arc(Vector2(direction*length,0),12,0,TAU,18,color,1.5,true)
