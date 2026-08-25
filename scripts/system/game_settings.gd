extends Node

## Slot-independent player settings. This service owns persistence in
## user://settings.cfg; it never stores settings in a game save.

signal changed(key: StringName, value: Variant)

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "gameplay"
const DEFAULTS := {
	"bgm_volume": 0.8,
	"se_volume": 0.8,
	"text_speed": 1.0,
	"fullscreen": false,
}

var values: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	_ensure_audio_bus(&"BGM")
	_ensure_audio_bus(&"SFX")
	_load()
	_apply_all()


func get_value(key: StringName) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: StringName, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("GameSettings: unknown setting '%s'." % key)
		return
	values[key] = value
	_apply(key)
	_save()
	changed.emit(key, value)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for key in DEFAULTS:
		values[key] = config.get_value(SECTION, key, DEFAULTS[key])


func _save() -> void:
	var config := ConfigFile.new()
	for key in DEFAULTS:
		config.set_value(SECTION, key, values[key])
	var error := config.save(CONFIG_PATH)
	if error != OK:
		push_error("GameSettings: failed to save %s (%s)." % [CONFIG_PATH, error_string(error)])


func _apply_all() -> void:
	for key in DEFAULTS:
		_apply(key)


func _apply(key: StringName) -> void:
	match key:
		"bgm_volume":
			_set_bus_volume(&"BGM", float(values[key]))
		"se_volume":
			_set_bus_volume(&"SFX", float(values[key]))
		"text_speed":
			_apply_text_speed(float(values[key]))
		"fullscreen":
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN
				if bool(values[key])
				else DisplayServer.WINDOW_MODE_WINDOWED
			)


func _ensure_audio_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


func _set_bus_volume(bus_name: StringName, linear_value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var clamped := clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped, 0.0001)))
	AudioServer.set_bus_mute(index, is_zero_approx(clamped))


func _apply_text_speed(speed: float) -> void:
	if Dialogic == null or Dialogic.Settings == null:
		return
	# Dialogic's Settings subsystem persists only its own plugin settings. The
	# project setting remains our authority; this updates active text immediately.
	Dialogic.Settings.set(&"text_speed", clampf(speed, 0.1, 3.0))
