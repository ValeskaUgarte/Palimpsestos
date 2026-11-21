extends CanvasLayer

var boss: Node
var _panel: VBoxContainer
var _bar: TextureProgressBar
func _ready() -> void:
	layer=4
	_panel=VBoxContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left=-240;_panel.offset_right=240
	_panel.offset_top=-80;_panel.offset_bottom=-30
	add_child(_panel)
	var name_label:=Label.new()
	name_label.text="EL LOBO · Guardián de la historia"
	name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size",17)
	_panel.add_child(name_label)
	var frame := Control.new()
	frame.custom_minimum_size=Vector2(480,37)
	_panel.add_child(frame)
	var atlas:=AtlasTexture.new()
	atlas.atlas=load("res://assets/ui/botones.png")
	atlas.region=Rect2(1067,402,204,37)
	var border:=NinePatchRect.new()
	border.texture=atlas
	border.patch_margin_left=8;border.patch_margin_right=40
	border.patch_margin_top=12;border.patch_margin_bottom=12
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(border)
	_bar=TextureProgressBar.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar.offset_left=11;_bar.offset_right=-40
	_bar.offset_top=12;_bar.offset_bottom=-12
	var fill:=AtlasTexture.new()
	fill.atlas=atlas.atlas
	fill.region=Rect2(1072,414,159,13)
	_bar.texture_under=fill
	_bar.texture_progress=fill
	_bar.tint_under=Color(.18,.15,.14)
	_bar.nine_patch_stretch=true
	frame.add_child(_bar)
	# Valor en números sobre la barra ("700 / 1000"), igual que la barra de los enemigos.
	var value_label:=Label.new()
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value_label.offset_left=11;value_label.offset_right=-40
	value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size",14)
	value_label.add_theme_color_override("font_outline_color",Color(.02,.015,.01))
	value_label.add_theme_constant_override("outline_size",4)
	value_label.text="%d / %d"%[boss.health.current_health,boss.health.max_health]
	frame.add_child(value_label)
	boss.health.health_changed.connect(func(value: int,maximum: int):_bar.max_value=maximum;_bar.value=value;value_label.text="%d / %d"%[value,maximum])
	boss.health.died.connect(func():hide())
	_bar.max_value=boss.health.max_health;_bar.value=boss.health.current_health
	hide()
func _process(_delta: float) -> void:
	if not is_instance_valid(boss) or boss._dead:
		hide();return
	var player=get_tree().get_first_node_in_group("player")
	if player:visible=not DialogueManager.visible and player.ground_position().distance_to(boss.ground_position())<850
