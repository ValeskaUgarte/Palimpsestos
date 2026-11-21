extends SceneTree
# Verifica que el hablante y su retrato salgan solos y que el diálogo avance en automático.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var failures := 0
	var dm = root.get_node("DialogueManager")
	var cases := [
		["Vecina-Dame la receta", "Vecina", "Dame la receta", true],
		["Mamá- ¿Joven, tiene lápiz?", "Mamá", "¿Joven, tiene lápiz?", true],
		["Elliot-No señoras, disculpen", "Elliot", "No señoras, disculpen", true],
		["Mi abuelita... - dice y llora.", "", "Mi abuelita... - dice y llora.", false],
	]
	for c in cases:
		var r: Dictionary = dm._resolve_entry({"text": c[0], "speaker": "", "portrait": null})
		if r.speaker != c[1] or r.text != c[2] or (r.portrait != null) != c[3]:
			failures += 1; print("FAIL ", c[0], " -> ", r)
	var named: Dictionary = dm._resolve_entry({"text": "Hola", "speaker": "NPC_Mama", "portrait": null})
	if named.speaker != "Mamá" or named.portrait == null: failures += 1; print("FAIL NPC_Mama ", named)
	root.get_node("GamePreferences").auto_dialogue = true
	dm.show_conversation([{"text": "Uno", "speaker": "Ethan"}, {"text": "Dos", "speaker": "Elliot"}])
	for i in 600:
		await process_frame
		if not dm.visible: break
	await create_timer(0.1).timeout
	if dm.visible and dm.label.text != "Dos": print("(avanzó a la segunda línea)")
	for i in 1200:
		await process_frame
		if not dm.visible: break
	if dm.visible: failures += 1; print("FAIL el diálogo automático no terminó")
	print("dialogue_speakers failures=", failures)
	quit(failures)
