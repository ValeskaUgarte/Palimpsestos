extends Node2D
# A short, bounded puff attached to the contact point, never the camera.
var _age: float = 0
func _ready() -> void: z_index = 4
func _process(delta: float) -> void:
	_age += delta
	if _age >= .35: queue_free()
	else: queue_redraw()
func _draw() -> void:
	var t: float = _age/.35
	for i in 7:
		var side: float = (i-3)/3.0
		var point := Vector2(side*(12+27*t),-3-sin(t*PI)*(4+absf(side)*6))
		draw_circle(point,3*(1-t),Color(.59,.57,.43,(1-t)*.22))
	for i in 3:
		var point := Vector2((i-1)*20*t,-sin(t*PI)*12)
		draw_line(point,point+Vector2(3,1),Color(.72,.67,.45,(1-t)*.35),1,true)
