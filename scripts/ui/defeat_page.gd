extends CanvasLayer
func _ready() -> void:
	layer=90
	process_mode=Node.PROCESS_MODE_ALWAYS
	var dim:=ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color=Color(.01,.015,.02,.86)
	add_child(dim)
	var box:=VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left=-260;box.offset_right=260;box.offset_top=-200;box.offset_bottom=150
	box.add_theme_constant_override("separation",18)
	add_child(box)
	var label:=UIKit.banner("La página se ha borrado", 190.0)
	box.add_child(label)
	var retry:=Button.new()
	retry.text="Volver al último recuerdo"
	UIKit.skin_by_text(retry, 64.0)
	box.add_child(retry)
	retry.pressed.connect(func():
		if not GameSession.continue_game():GameSession.new_game()
	)
	var menu:=Button.new()
	menu.text="Cerrar el cuento"
	UIKit.skin_by_text(menu, 64.0)
	box.add_child(menu)
	menu.pressed.connect(func():ScenePages.travel("res://scenes/main_menu.tscn"))
	retry.grab_focus()
	get_tree().paused=true
