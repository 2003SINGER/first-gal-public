extends Node

## Coordinates title -> game transitions and owns the running session boundary.
## It does not contain narrative content, inventory, relationship state, or
## Timeline-specific branching.

const GAME_SCENE := "res://scenes/main.tscn"
const DEMO_TIMELINE := "res://dialogic/timelines/01_return_to_school.dtl"

var is_in_game := false
var is_system_menu_open := false
var _scene_controller: Node = null
var _system_ui: Node = null
var _interaction_controller: Node = null
var _pending_new_game := false
var _pending_load_slot := ""
var _loading := false


func begin_new_game() -> void:
	_pending_new_game = true
	_pending_load_slot = ""
	get_tree().change_scene_to_file(GAME_SCENE)


func begin_load_game(slot_name: String) -> void:
	if not SaveService.has_slot(slot_name):
		push_warning("GameSession: requested missing slot '%s'." % slot_name)
		return
	_pending_new_game = false
	_pending_load_slot = slot_name
	get_tree().change_scene_to_file(GAME_SCENE)


func attach_runtime(scene_controller: Node, system_ui: Node, interaction_controller: Node) -> void:
	is_in_game = true
	_scene_controller = scene_controller
	_system_ui = system_ui
	_interaction_controller = interaction_controller
	if _scene_controller.has_signal("scene_changed") and not _scene_controller.scene_changed.is_connected(_on_scene_changed):
		_scene_controller.scene_changed.connect(_on_scene_changed)
	if _system_ui != null and _system_ui.has_method("setup"):
		_system_ui.setup(self)
	call_deferred("_start_pending_request")


func detach_runtime() -> void:
	is_in_game = false
	is_system_menu_open = false
	_scene_controller = null
	_system_ui = null
	_interaction_controller = null


func _start_pending_request() -> void:
	if not is_in_game:
		return
	if not _pending_load_slot.is_empty():
		var slot := _pending_load_slot
		_pending_load_slot = ""
		await _load_running_slot(slot)
		return
	if _pending_new_game:
		_pending_new_game = false
		await Dialogic.clear()
		Dialogic.start(DEMO_TIMELINE)
		call_deferred("_write_autosave")


func _unhandled_input(event: InputEvent) -> void:
	if not is_in_game or _loading:
		return
	if event.is_action_pressed(InputManager.MENU):
		if _system_ui != null and _system_ui.has_method("toggle_menu"):
			_system_ui.toggle_menu()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputManager.SAVE) and not is_system_menu_open:
		var error := save_manual_slot(1)
		if error == OK:
			_show_message("已保存至 01 槽")
		elif error == ERR_BUSY:
			_show_message("当前整理中，暂不能保存")
		else:
			_show_message("保存失败")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputManager.LOAD) and not is_system_menu_open:
		if _system_ui != null and _system_ui.has_method("open_load"):
			_system_ui.open_load()
			get_viewport().set_input_as_handled()


func set_system_menu_open(open: bool) -> void:
	is_system_menu_open = open
	if Dialogic != null:
		Dialogic.paused = open


func save_manual_slot(index: int) -> Error:
	return _save_slot(SaveService.manual_slot_name(index))


func load_manual_slot(index: int) -> void:
	if not is_in_game:
		begin_load_game(SaveService.manual_slot_name(index))
		return
	await _load_running_slot(SaveService.manual_slot_name(index))


func _save_slot(slot_name: String) -> Error:
	if _scene_controller == null:
		return ERR_UNAVAILABLE
	if _interaction_controller != null and _interaction_controller.get("active_interaction") != null:
		# Locker and desk panels are deliberately one-shot modal states. Their
		# unfinished local decisions are not part of the base save contract yet.
		return ERR_BUSY
	var scene_id := ""
	if "current_scene_id" in _scene_controller:
		scene_id = str(_scene_controller.current_scene_id)
	return SaveService.save_slot(slot_name, scene_id)


func _write_autosave() -> void:
	if not is_in_game or _loading:
		return
	var error := _save_slot(SaveService.AUTO_SLOT)
	if error != OK:
		push_warning("GameSession: autosave failed (%s)." % error_string(error))


func _on_scene_changed(_scene_id: String) -> void:
	call_deferred("_write_autosave")


func _load_running_slot(slot_name: String) -> void:
	var loaded := SaveService.load_slot(slot_name)
	if loaded.is_empty():
		_show_message("该存档不可读取")
		return
	_loading = true
	set_system_menu_open(false)
	var metadata: Dictionary = loaded.get("metadata", {})
	var scene_id := str(metadata.get("scene", "blank"))
	if _scene_controller != null:
		_scene_controller.change_scene(scene_id)
	await get_tree().process_frame
	await Dialogic.load_full_state(loaded.get("dialogic_state"))
	_loading = false
	if _system_ui != null and _system_ui.has_method("close"):
		_system_ui.close()
	_show_message("已读取存档")


func _show_message(text: String) -> void:
	if _system_ui != null and _system_ui.has_method("show_message"):
		_system_ui.show_message(text)
