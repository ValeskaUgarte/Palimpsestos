extends Sprite2D
## Reproduce en bucle los frames de un spritesheet (region_rect) con la posición ya alineada por frame.

@export var rects: Array[Rect2] = []
@export var offsets: Array[Vector2] = []
@export var fps: float = 12.0

var _clock: float = 0.0


func _process(delta: float) -> void:
	if rects.is_empty():
		return
	_clock += delta
	var index: int = int(_clock * fps) % rects.size()
	region_rect = rects[index]
	if index < offsets.size():
		position = offsets[index]
