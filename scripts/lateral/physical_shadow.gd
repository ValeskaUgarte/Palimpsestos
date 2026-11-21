extends Node2D
func _ready() -> void:
	show_behind_parent = true
func _physics_process(_delta: float) -> void:
	var actor = get_parent()
	var ray := PhysicsRayQueryParameters2D.create(actor.global_position+Vector2(0,-2),actor.global_position+Vector2(0,450),1)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	visible = not hit.is_empty()
	if not visible: return
	var height: float = maxf(hit.position.y - actor.global_position.y,0)
	position.y = height
	scale = Vector2.ONE * lerpf(1,.65,clampf(height/150,0,1))
	modulate.a = lerpf(.65,.2,clampf(height/150,0,1))
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.17))
	draw_circle(Vector2.ZERO,38,Color(.015,.013,.012,.55))
