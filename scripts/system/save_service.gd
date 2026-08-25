extends Node

## Project-owned save facade. Each slot is one inspectable JSON file. Dialogic
## subsystem state is represented as a Godot Variant string *inside* that JSON,
## so JSON still owns the slot while Vector/PackedArray values remain lossless.
## Timelines never call this service.

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 10
const AUTO_SLOT := "autosave"


func _ready() -> void:
	var error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("SaveService: cannot create %s (%s)." % [SAVE_DIR, error_string(error)])


func manual_slot_name(index: int) -> String:
	return "save_%02d" % clampi(index, 1, SLOT_COUNT)


func save_slot(slot_name: String, scene_id: String, extra_state: Dictionary = {}) -> Error:
	if not _is_valid_slot(slot_name):
		return ERR_INVALID_PARAMETER
	if Dialogic == null:
		return ERR_UNAVAILABLE

	var state := Dialogic.get_full_state()
	var metadata := {
		"format_version": 1,
		"slot": slot_name,
		"saved_at": Time.get_datetime_string_from_system(),
		"scene": scene_id,
		"timeline": state.timeline,
		"event_index": state.event_index,
		"variables": _json_safe(Dialogic.VAR.var_storage),
		"extra_state": _json_safe(extra_state),
		"dialogic_state": {
			"timeline": state.timeline,
			"event_index": state.event_index,
			"subsystems_variant": var_to_str(state.subsystems),
		},
	}

	var json_file := FileAccess.open(_metadata_path(slot_name), FileAccess.WRITE)
	if json_file == null:
		return FileAccess.get_open_error()
	json_file.store_string(JSON.stringify(metadata, "\t"))
	json_file.close()
	if FileAccess.file_exists(_state_path(slot_name)):
		var stale_sidecar_error := DirAccess.remove_absolute(_state_path(slot_name))
		if stale_sidecar_error != OK:
			return stale_sidecar_error

	return OK


func load_slot(slot_name: String) -> Dictionary:
	var metadata := get_metadata(slot_name)
	if metadata.is_empty():
		return {}

	var state := _read_json_state(metadata)
	if state == null:
		# Compatibility with the short-lived pre-JSON implementation. New slots
		# never create this sidecar, but an existing test/user slot still opens.
		state = _read_legacy_state(slot_name)
	if state == null:
		return {}
	return {"metadata": metadata, "dialogic_state": state}


func get_metadata(slot_name: String) -> Dictionary:
	var json_file := FileAccess.open(_metadata_path(slot_name), FileAccess.READ)
	if json_file == null:
		return {}
	var parsed: Variant = JSON.parse_string(json_file.get_as_text())
	json_file.close()
	return parsed if parsed is Dictionary else {}


func has_slot(slot_name: String) -> bool:
	return FileAccess.file_exists(_metadata_path(slot_name))


func get_manual_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for index in range(1, SLOT_COUNT + 1):
		var slot_name := manual_slot_name(index)
		slots.append({
			"slot": slot_name,
			"metadata": get_metadata(slot_name),
			"exists": has_slot(slot_name),
		})
	return slots


func delete_slot(slot_name: String) -> Error:
	if not _is_valid_slot(slot_name):
		return ERR_INVALID_PARAMETER
	var metadata_error := DirAccess.remove_absolute(_metadata_path(slot_name))
	# Remove the obsolete pre-JSON sidecar if one exists; no new slot creates it.
	var state_error := DirAccess.remove_absolute(_state_path(slot_name))
	if metadata_error not in [OK, ERR_FILE_NOT_FOUND]:
		return metadata_error
	if state_error not in [OK, ERR_FILE_NOT_FOUND]:
		return state_error
	return OK


func _is_valid_slot(slot_name: String) -> bool:
	return slot_name == AUTO_SLOT or slot_name.begins_with("save_")


func _metadata_path(slot_name: String) -> String:
	return SAVE_DIR.path_join(slot_name + ".json")


func _state_path(slot_name: String) -> String:
	return SAVE_DIR.path_join(slot_name + ".dialogic_state")


func _read_json_state(metadata: Dictionary) -> DialogicSaveState:
	var raw_state: Variant = metadata.get("dialogic_state")
	if not raw_state is Dictionary:
		return null
	var raw_subsystems: Variant = raw_state.get("subsystems_variant", "")
	if not raw_subsystems is String:
		return null
	var decoded: Variant = str_to_var(raw_subsystems)
	if not decoded is Dictionary:
		return null

	var subsystems: Dictionary[String, Dictionary] = {}
	for subsystem_name in decoded:
		if decoded[subsystem_name] is Dictionary:
			subsystems[str(subsystem_name)] = decoded[subsystem_name]
	var state := DialogicSaveState.new()
	state.timeline = str(raw_state.get("timeline", ""))
	state.event_index = int(raw_state.get("event_index", -1))
	state.subsystems = subsystems
	return state


func _read_legacy_state(slot_name: String) -> DialogicSaveState:
	var state_file := FileAccess.open(_state_path(slot_name), FileAccess.READ)
	if state_file == null:
		return null
	var legacy_state: Variant = state_file.get_var(true)
	state_file.close()
	return legacy_state as DialogicSaveState


func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_ARRAY:
			var array: Array = []
			for entry in value:
				array.append(_json_safe(entry))
			return array
		TYPE_DICTIONARY:
			var dictionary := {}
			for key in value:
				dictionary[str(key)] = _json_safe(value[key])
			return dictionary
		_:
			return str(value)
