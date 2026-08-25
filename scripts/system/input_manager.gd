extends Node

## Project-owned input map. Gameplay and UI consume these action names rather
## than scattering physical keys through timelines or scene scripts.

const CONFIRM := &"confirm"
const CANCEL := &"cancel"
const MENU := &"menu"
const SAVE := &"save"
const LOAD := &"load"


func _ready() -> void:
	_add_key(CONFIRM, KEY_ENTER)
	_add_key(CONFIRM, KEY_SPACE)
	_add_key(CANCEL, KEY_ESCAPE)
	_add_key(MENU, KEY_ESCAPE)
	_add_key(SAVE, KEY_F5)
	_add_key(LOAD, KEY_F7)


func _add_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).keycode == keycode:
			return
	InputMap.action_add_event(action, event)
