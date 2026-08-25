extends Node

## Headless integration check for the project-owned Gal shell.

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := preload("res://scenes/main.tscn").instantiate()
	add_child(runtime)
	for _frame in 12:
		await get_tree().process_frame
	if not GameSession.is_in_game:
		push_error("System smoke: runtime was not attached.")
		get_tree().quit(1)
		return
	# This is the exact initialization path used after TitleScreen switches into
	# main.tscn. Calling it here keeps the smoke runner alive to observe result.
	GameSession._pending_new_game = true
	await GameSession._start_pending_request()
	for _frame in 12:
		await get_tree().process_frame
	if Dialogic.current_timeline == null:
		push_error("System smoke: Demo timeline did not start.")
		get_tree().quit(1)
		return
	if not SaveService.has_slot(SaveService.AUTO_SLOT):
		push_error("System smoke: new-game autosave was not created.")
		get_tree().quit(1)
		return
	Dialogic.VAR.var_storage["system_smoke_marker"] = "before_load"
	var save_error := GameSession.save_manual_slot(10)
	if save_error != OK or not SaveService.has_slot("save_10"):
		push_error("System smoke: manual save failed.")
		get_tree().quit(1)
		return
	var metadata := SaveService.get_metadata("save_10")
	if str(metadata.get("timeline", "")).is_empty() or str(metadata.get("scene", "")).is_empty():
		push_error("System smoke: metadata lacks timeline or scene.")
		get_tree().quit(1)
		return
	if not metadata.has("dialogic_state") or FileAccess.file_exists("user://saves/save_10.dialogic_state"):
		push_error("System smoke: new save is not a self-contained JSON slot.")
		get_tree().quit(1)
		return
	var ui := runtime.get_node("UIRoot")
	ui.open_save()
	await get_tree().process_frame
	if not ui.root.visible or ui.slot_list.get_child_count() != SaveService.SLOT_COUNT:
		push_error("System smoke: in-game save UI did not build ten slots.")
		get_tree().quit(1)
		return
	ui.close()
	var saved_text_speed := float(GameSettings.get_value(&"text_speed"))
	GameSettings.set_value(&"text_speed", saved_text_speed)
	var settings_file := ConfigFile.new()
	if settings_file.load(GameSettings.CONFIG_PATH) != OK or not is_equal_approx(float(settings_file.get_value(GameSettings.SECTION, "text_speed", -1.0)), saved_text_speed):
		push_error("System smoke: settings did not persist through ConfigFile.")
		get_tree().quit(1)
		return
	if AudioServer.get_bus_index(&"BGM") < 0 or AudioServer.get_bus_index(&"SFX") < 0 or not is_equal_approx(float(Dialogic.Settings.get_setting(&"text_speed", -1.0)), saved_text_speed):
		push_error("System smoke: settings were not applied to runtime services.")
		get_tree().quit(1)
		return
	for action in [InputManager.CONFIRM, InputManager.CANCEL, InputManager.MENU, InputManager.SAVE, InputManager.LOAD]:
		if not InputMap.has_action(action):
			push_error("System smoke: missing input action %s." % action)
			get_tree().quit(1)
			return
	runtime.get_node("SceneController").change_scene("school_gate")
	for _frame in 4:
		await get_tree().process_frame
	var autosave_metadata := SaveService.get_metadata(SaveService.AUTO_SLOT)
	if autosave_metadata.get("scene", "") != "school_gate":
		push_error("System smoke: scene-change autosave was not updated.")
		get_tree().quit(1)
		return
	Dialogic.VAR.var_storage["system_smoke_marker"] = "after_save"
	await GameSession.load_manual_slot(10)
	for _frame in 12:
		await get_tree().process_frame
	if Dialogic.current_timeline == null:
		push_error("System smoke: Dialogic did not restore.")
		get_tree().quit(1)
		return
	if runtime.get_node("SceneController").current_scene_id != str(metadata.get("scene", "")):
		push_error("System smoke: saved world scene did not restore.")
		get_tree().quit(1)
		return
	if Dialogic.VAR.var_storage.get("system_smoke_marker", "") != "before_load":
		push_error("System smoke: Dialogic variables did not restore.")
		get_tree().quit(1)
		return
	var title := preload("res://scenes/title/title_screen.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	title.animation_player.advance(7.0)
	if not title.menu_ui.visible:
		push_error("System smoke: title menu did not appear after intro animation.")
		get_tree().quit(1)
		return
	if not title.get_node("CanvasLayer/MenuUI/Start").pressed.is_connected(GameSession.begin_new_game):
		push_error("System smoke: title Start Game is not wired to GameSession.")
		get_tree().quit(1)
		return
	title._open_load()
	if title.slot_list.get_child_count() != SaveService.SLOT_COUNT:
		push_error("System smoke: title load UI did not build ten slots.")
		get_tree().quit(1)
		return
	print("SYSTEM_SMOKE_OK timeline=%s scene=%s" % [metadata["timeline"], metadata["scene"]])
	get_tree().quit(0)
