extends Control
## Configuración de audio sobre pergamino.

const ROWS := [
	["Música", "Music", "icon_music"],
	["Efectos (SFX)", "SFX", "icon_speaker"],
	["Ambiente", "Ambient", "icon_map"],
	["Interfaz", "UI", "icon_monitor"],
]

# Los valores se cargan sin emitir escrituras ni desactivar un bus silenciado.
var _initializing: bool = true

func _ready() -> void:
	var parts: Dictionary = UIKit.parchment(Vector2(1000, 660))
	add_child(parts.root)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	(parts.content as MarginContainer).add_child(box)

	var title: Control = UIKit.banner("Configuración", 80)
	if title == null:
		title = UIKit.ink_label("Configuración", 30, UIKit.INK_RED)
		(title as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var first_slider: HSlider = null
	for row in ROWS:
		var slider: HSlider = _add_row(box, row[0], row[1], row[2])
		if first_slider == null:
			first_slider = slider

	var advanced := Button.new()
	advanced.text = "Comodidad y controles"
	box.add_child(advanced)
	if not UIKit.skin_button(advanced, "btn_comodidad", 56):
		UIKit.style_plain_button(advanced)
	advanced.pressed.connect(func(): add_child(preload("res://scripts/ui/preferences_panel.gd").new()))

	var back := Button.new()
	back.text = "Volver"
	box.add_child(back)
	if not UIKit.skin_button(back, "btn_volver", 54):
		UIKit.style_plain_button(back)
	back.pressed.connect(_on_back_pressed)

	_initializing = false
	if first_slider:
		first_slider.grab_focus()

func _add_row(parent: VBoxContainer, label_text: String, bus: String, icon_key: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var icon: TextureRect = UIKit.plaque(icon_key, 46)
	if icon == null:
		icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(46, 46)
	row.add_child(icon)
	var label := UIKit.ink_label(label_text, 21)
	label.custom_minimum_size.x = 170
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 0.8
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.style_slider(slider)
	row.add_child(slider)
	var percent := UIKit.ink_label("", 19)
	percent.custom_minimum_size.x = 56
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(percent)
	var index: int = AudioServer.get_bus_index(bus)
	if index != -1:
		slider.value = 0.0 if AudioServer.is_bus_mute(index) else db_to_linear(AudioServer.get_bus_volume_db(index))
	percent.text = "%d%%" % roundi(slider.value * 100.0)
	slider.value_changed.connect(func(value: float):
		percent.text = "%d%%" % roundi(value * 100.0)
		if _initializing:
			return
		GamePreferences.set_volume(bus, value)
	)
	return slider

func _on_back_pressed() -> void:
	ScenePages.travel("res://scenes/main_menu.tscn")
