extends Node

## Thin project-side ADV control policy. Dialogic still owns text rendering,
## history data and automatic progression; this node merely gives the game one
## input/UI boundary for AUTO, Ctrl-SKIP, LOG and textbox hiding.

signal auto_changed(enabled: bool)
signal skip_changed(enabled: bool)
signal textbox_hidden_changed(hidden: bool)

var _textbox_hidden := false
var _ctrl_skip_active := false
var _history_open := false


func _ready() -> void:
	if Dialogic == null:
		return
	Dialogic.Inputs.auto_skip.disable_on_unread_text = true
	Dialogic.Inputs.auto_skip.disable_on_user_input = false
	Dialogic.Inputs.auto_skip.enable_on_visited = false
	Dialogic.Inputs.auto_skip.toggled.connect(_on_skip_toggled)
	Dialogic.Inputs.auto_advance.toggled.connect(_on_auto_toggled)


func _unhandled_input(event: InputEvent) -> void:
	if not _can_control_adv():
		return
	if event.is_action_pressed(InputManager.ADV_AUTO):
		toggle_auto()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(InputManager.ADV_LOG):
		open_log()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(InputManager.ADV_HIDE):
		toggle_textbox()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_CTRL and not key_event.echo:
			if key_event.pressed:
				_ctrl_skip_active = true
				set_skip(true)
			else:
				_ctrl_skip_active = false
				set_skip(false)
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# History pauses Dialogic, so close it before GameSession can interpret Esc
	# as an in-game menu request.
	if _history_open and event.is_action_pressed(InputManager.CANCEL):
		close_log()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Dialogic's stock History "Return" button resumes Dialogic directly rather
	# than emitting close_requested. Detect that route without modifying Dialogic.
	if _history_open and Dialogic != null and not Dialogic.paused:
		_history_open = false


func toggle_auto() -> void:
	if not _can_control_adv():
		return
	Dialogic.Inputs.auto_advance.enabled_until_user_input = not Dialogic.Inputs.auto_advance.is_enabled()


func toggle_skip() -> void:
	if not _can_control_adv():
		return
	set_skip(not Dialogic.Inputs.auto_skip.enabled)


func set_skip(enabled: bool) -> void:
	if Dialogic == null:
		return
	Dialogic.Inputs.auto_skip.enabled = enabled


func open_log() -> void:
	if not _can_control_adv():
		return
	_history_open = true
	Dialogic.History.open_history()


func close_log() -> void:
	if Dialogic == null:
		return
	_history_open = false
	Dialogic.History.close_history()


func toggle_textbox() -> void:
	if not _can_control_adv():
		return
	_textbox_hidden = not _textbox_hidden
	Dialogic.Text.textbox_update_visibility(not _textbox_hidden)
	textbox_hidden_changed.emit(_textbox_hidden)


func is_auto_enabled() -> bool:
	return Dialogic != null and Dialogic.Inputs.auto_advance.is_enabled()


func is_skip_enabled() -> bool:
	return Dialogic != null and Dialogic.Inputs.auto_skip.enabled


func is_textbox_hidden() -> bool:
	return _textbox_hidden


func _can_control_adv() -> bool:
	return Dialogic != null and GameSession != null and GameSession.is_in_game and not GameSession.is_system_menu_open


func _on_auto_toggled(enabled: bool) -> void:
	auto_changed.emit(enabled)


func _on_skip_toggled(enabled: bool) -> void:
	if not enabled:
		_ctrl_skip_active = false
	skip_changed.emit(enabled)
