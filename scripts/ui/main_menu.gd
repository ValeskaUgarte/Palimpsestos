extends Control

@onready var load_toast: Label = $LoadToast

func _ready() -> void:
	ScenePages.reset()
	AudioLandscape.set_music(null)
	# Primera impresión sin retrasar ni bloquear los botones.
	var first := find_child("PlayButton",true,false) as Control
	if first:first.grab_focus()
	$Logo.modulate.a = 0.0
	$Tagline.modulate.a = 0.0
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property($Logo, "modulate:a", 1.0, 0.75)
	reveal.tween_property($Tagline, "modulate:a", 1.0, 0.8).set_delay(0.2)

# Demo de combate (opcional): los tres botones son nodos de main_menu.tscn > DemoCombate.
# Se pueden mover o editar en el editor. Las escenas de la demo están en scenes/demo/.
func _on_demo_new_pressed() -> void:
	LateralStory.new_game()

func _on_demo_continue_pressed() -> void:
	if not LateralStory.continue_game(): _toast("No hay una demo de combate guardada.")

func _on_demo_import_pressed() -> void:
	if not LateralStory.import_legacy_checkpoint(): _toast("No se pudo importar el checkpoint anterior.")

func _toast(message: String) -> void:
	load_toast.text = message
	load_toast.show()
	await get_tree().create_timer(2).timeout
	if is_instance_valid(load_toast): load_toast.hide()

func _on_play_pressed() -> void:
	# "Iniciar partida" siempre abre la historia: Cuento I y sus escenas.
	GameSession.new_game()

func _on_load_pressed() -> void:
	ScenePages.travel("res://scenes/ui/saved_plays_menu.tscn")

func _on_config_pressed() -> void:
	ScenePages.travel("res://scenes/ui/settings_menu.tscn")

func _on_map_pressed() -> void:
	ScenePages.travel("res://scenes/ui/map_screen.tscn")

func _on_credits_pressed() -> void:
	ScenePages.travel("res://scenes/ui/credits_menu.tscn")

func _on_quit_pressed() -> void:
	GameSession.quit_game()
