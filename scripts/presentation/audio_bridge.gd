extends Node

## Timeline audio vocabulary stays semantic. Dialogic owns the actual channel
## players and serialisable audio state, while this bridge owns resource ids and
## the project's fixed channel policy.

const MUSIC := {
	# "opening": "res://assets/audio/bgm/opening.ogg",
}

const AMBIENCE := {
	# "classroom_day": "res://assets/audio/amb/classroom_day.ogg",
}

const SFX := {
	"camera_shutter": "res://assets/audio/sfx/camera_shutter.ogg",
	"school_bell_muffled": "res://assets/audio/sfx/school_bell_muffled.ogg",
	"rain_short": "res://assets/audio/sfx/rain_short.ogg",
}


func handle_command(payload: String) -> void:
	var parts := payload.split(":", true)
	if parts.size() == 1:
		_play_sfx(parts[0]) # Existing audio:<sfx_id> Timeline contract.
		return
	var channel := parts[0]
	var action := parts[1]
	match channel:
		"music":
			_update_channel("music", MUSIC, action)
		"amb":
			_update_channel("amb", AMBIENCE, action)
		"sfx":
			_play_sfx(action)
		_:
			push_warning("AudioBridge: unknown audio channel '%s'." % channel)


func _update_channel(channel: String, registry: Dictionary, track_id: String) -> void:
	if track_id == "stop":
		Dialogic.Audio.update_audio(channel, "", {"fade_length": 0.5})
		return
	if not registry.has(track_id):
		push_warning("AudioBridge: unknown %s track '%s'." % [channel, track_id])
		return
	var path: String = registry[track_id]
	if not ResourceLoader.exists(path):
		push_warning("AudioBridge: missing %s track '%s' at %s." % [channel, track_id, path])
		return
	Dialogic.Audio.update_audio(channel, path, {
		"audio_bus": "BGM",
		"fade_length": 0.75,
		"loop": true,
	})


func _play_sfx(sfx_id: String) -> void:
	if not SFX.has(sfx_id):
		push_warning("AudioBridge: unknown sfx_id '%s'." % sfx_id)
		return
	var path: String = SFX[sfx_id]
	if not ResourceLoader.exists(path):
		push_warning("AudioBridge: missing sfx '%s' at %s." % [sfx_id, path])
		return
	Dialogic.Audio.update_audio("", path, {"audio_bus": "SFX", "loop": false})
