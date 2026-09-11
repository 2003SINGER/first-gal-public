extends Node

## Permanent, project-owned collection progress.
##
## This is deliberately separate from story saves: unlocking a recollection is
## a player-library fact, not a runtime narrative state.  It survives deleted
## save slots and is never read by Timelines for branching.

const PATH := "user://extras_progress.cfg"

var _unlocked: Dictionary = {}


func _ready() -> void:
	_load()


func is_unlocked(entry_id: StringName) -> bool:
	return _unlocked.has(entry_id)


func unlock(entry_id: StringName) -> void:
	if _unlocked.has(entry_id):
		return
	_unlocked[entry_id] = true
	_save()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for entry_id in config.get_value("unlocked", "ids", PackedStringArray()):
		_unlocked[StringName(str(entry_id))] = true


func _save() -> void:
	var config := ConfigFile.new()
	var ids := PackedStringArray()
	for entry_id in _unlocked:
		ids.append(str(entry_id))
	config.set_value("unlocked", "ids", ids)
	var error := config.save(PATH)
	if error != OK:
		push_error("ExtrasProgress: could not save unlock progress (%s)." % error_string(error))
