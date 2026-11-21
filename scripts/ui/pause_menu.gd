extends CanvasLayer

func _ready() -> void:
	layer = 30
	visible = false
	var settings := Button.new()
	settings.text="Comodidad y controles"
	$VBoxContainer.add_child(settings)
	$VBoxContainer.move_child(settings,2)
	settings.pressed.connect(func():add_child(preload("res://scripts/ui/preferences_panel.gd").new()))
	var menu: VBoxContainer = $VBoxContainer
	menu.offset_top = -200; menu.offset_bottom = 200
	menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	var title_label: Label = $VBoxContainer/Title
	var banner: Control = UIKit.banner(title_label.text, 110)
	if banner != null:
		title_label.visible = false
		menu.add_child(banner)
		menu.move_child(banner, 0)
	for button in [$VBoxContainer/ResumeButton, settings, $VBoxContainer/QuitButton]:
		UIKit.skin_by_text(button, 56)
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _input(event: InputEvent) -> void:
	var player=get_tree().current_scene.get_node_or_null("Elliot") if get_tree().current_scene else null
	if (player and player.get("_dead") == true) or not get_tree().get_nodes_in_group("preferences_panel").is_empty():return
	if event.is_action_pressed("pause"):
		if visible:
			_on_resume_pressed()
		else:
			visible=true
			get_tree().paused=true
			$VBoxContainer/ResumeButton.grab_focus()

func _on_resume_pressed() -> void:
	var player=get_tree().current_scene.get_node_or_null("Elliot")
	if player:player._await_action_release=true
	visible = false
	get_tree().paused = false

func _on_quit_pressed() -> void:
	GameSession.checkpoint(get_tree().current_scene)
	ScenePages.travel("res://scenes/main_menu.tscn")
