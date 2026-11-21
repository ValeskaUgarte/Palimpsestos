extends Node2D

var _clock: float = 0.0
var _camera: Camera2D

func _ready() -> void:
	z_index=4

func _process(delta: float) -> void:
	_clock+=delta
	_camera=get_viewport().get_camera_2d()
	queue_redraw()

func _draw() -> void:
	if _camera==null:return
	var half: Vector2=get_viewport_rect().size/_camera.zoom*.5
	var center: Vector2=_camera.get_screen_center_position()
	var first: int=int(floor((center.x-half.x)/390.0))
	var last: int=int(ceil((center.x+half.x)/390.0))
	# Plantas próximas, bajas y ancladas al mundo. No desplaza la pintura de fondo.
	for index in range(first,last+1):
		var base:=Vector2(index*390+110,390)
		for frond in range(5):
			var side: float=frond-2
			var length: float=48+12*((index+frond+100)%3)
			var tip:=Vector2(side*24+sin(_clock*.65+index+frond)*3,-length)
			var stem:=PackedVector2Array([base,base+tip*.45+Vector2(side*4,0),base+tip])
			draw_polyline(stem,Color(0.025,0.045,0.045,.85),3,true)
			for leaf in range(1,5):
				var t: float=leaf/5.0
				var point: Vector2=base+tip*t
				var width: float=(1-t)*19
				draw_line(point,point+Vector2(width,-9),Color(.035,.06,.055,.83),3,true)
				draw_line(point,point+Vector2(-width,-8),Color(.025,.05,.045,.83),3,true)
