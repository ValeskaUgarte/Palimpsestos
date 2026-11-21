extends Control
## JUGADAS GUARDADAS (botón Cargar del menú). Lista cada escena jugable del Cuento I con su título.
## Elegir una escena empieza en su inicio, igual que el mapa. Si hay partida guardada, aparece arriba
## la opción de continuarla. Volver regresa al menú principal.

func _ready() -> void:
	ScenePages.reset()
	var parts: Dictionary = UIKit.parchment(Vector2(1000, 660))
	add_child(parts.root)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	(parts.content as MarginContainer).add_child(box)

	var title: Control = UIKit.banner("Jugadas guardadas", 80)
	if title == null:
		title = UIKit.ink_label("Jugadas guardadas", 30, UIKit.INK_RED)
		(title as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var first: Button = null
	if FileAccess.file_exists(GameSession.save_path):
		var resume := _button("Continuar partida guardada", list)
		resume.pressed.connect(func(): GameSession.continue_game())
		first = resume
	for index in GameSession.PARTS.size():
		var part: Dictionary = GameSession.PARTS[index]
		var button := _button("Escena %d · %s" % [index + 1, part.title], list)
		button.tooltip_text = String(part.sub)
		button.pressed.connect(GameSession.enter_part.bind(index))
		if first == null:
			first = button
		list.add_child(UIKit.ink_label(String(part.sub), 16))

	var back := Button.new()
	back.text = "Volver"
	box.add_child(back)
	if not UIKit.skin_button(back, "btn_volver", 54):
		UIKit.style_plain_button(back)
	back.pressed.connect(func(): ScenePages.travel("res://scenes/main_menu.tscn"))
	if first != null:
		first.grab_focus()

func _button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.style_plain_button(button, 44)
	parent.add_child(button)
	return button
