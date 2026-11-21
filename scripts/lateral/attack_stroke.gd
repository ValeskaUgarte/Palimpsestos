extends Node2D
var sword: bool = false
var facing_sign: float = 1
var heavy: bool = false
var _elapsed: float = 0
func _ready() -> void: z_index = 9
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > .17: queue_free()
	else: queue_redraw()
func _draw() -> void:
	var t: float = _elapsed/.17
	var points := PackedVector2Array()
	var radius: float = (90 if sword else 43)*(1+t*.12)
	for i in 17:
		var angle: float = lerpf(-1.2,.65,i/16.0)+t*.35
		points.append(Vector2(cos(angle)*radius*facing_sign,sin(angle)*radius))
	for i in range(16,-1,-1):
		var angle: float = lerpf(-1.2,.65,i/16.0)+t*.35
		var taper: float = sin(PI*i/16.0)*(10 if heavy else 5)
		points.append(Vector2(cos(angle)*(radius-taper)*facing_sign,sin(angle)*(radius-taper)))
	draw_colored_polygon(points,Color(.88,.87,.71,(1-t)*.65))
	if heavy:
		var echo := PackedVector2Array()
		for i in 17:
			var angle: float = lerpf(-1.2,.65,i/16.0)+t*.35-.12
			echo.append(Vector2(cos(angle)*(radius+5)*facing_sign,sin(angle)*(radius+5)))
		draw_polyline(echo,Color(.82,.69,.43,(1-t)*.3),1.2,true)
