extends Node

## NarrativeBridge
## The single bridge between Dialogic and the Godot display system.
## It listens to Dialogic.signal_event (one Variant argument) and turns the
## semantic command string into concrete calls. It does NOT know which file a
## scene or photo maps to — that is owned by SceneController / the photo registry.
##
## Supported commands (emitted from Dialogic Signal events, argument_type = STRING):
##   scene:<id>              -> SceneController.change_scene(<id>)
##   photo:<id>              -> show registered photo
##   photo:hide              -> hide photo
##   interaction:<id>        -> start a modal gameplay interaction
##   audio:<sfx_id>          -> play a registered one-shot SFX (missing file -> warning)
##
## We do NOT yet build a custom Dialogic Event. The Alpha20 Signal event is used
## as-is; the whole command is sent as one string and split on ":" here.

var scene_controller: Node = null
var photo_viewer: Control = null
var interaction_controller: Node = null
var sfx_player: AudioStreamPlayer = null

# Semantic photo id -> texture path. Add real entries as art lands.
# Missing files fall back to a generated placeholder so the system never crashes
# on absent art (placeholder also makes the smoke test visibly "work").
const PHOTOS := {
	"first_day_classroom": "res://assets/photos/classroom/first_day_classroom.png",
	"memory_school_start": "res://assets/photos/memory/memory_school_start.png",
	"memory_rain": "res://assets/photos/memory/memory_rain.png",
	"memory_classroom": "res://assets/photos/memory/memory_classroom.png",
	"memory_friends": "res://assets/photos/memory/memory_friends.png",
	"memory_ye_xiao": "res://assets/photos/memory/memory_ye_xiao.png",
	"memory_exam": "res://assets/photos/memory/memory_exam.png",
	"final_classroom_photo": "res://assets/photos/classroom/final_classroom_photo.png",
	"graduation_selfie": "res://assets/photos/ending/graduation_selfie.png",
}

# One-shot SFX registry. Files live under res://assets/audio/sfx/. If a file is
# missing we only warn (same placeholder philosophy as photos) — never crash.
const SFX := {
	"camera_shutter": "res://assets/audio/sfx/camera_shutter.ogg",
	"school_bell_muffled": "res://assets/audio/sfx/school_bell_muffled.ogg",
	"rain_short": "res://assets/audio/sfx/rain_short.ogg",
}


func setup(sc: Node, pv: Control, ic: Node, sp: AudioStreamPlayer) -> void:
	scene_controller = sc
	photo_viewer = pv
	interaction_controller = ic
	sfx_player = sp
	if Dialogic != null and Dialogic.has_signal("signal_event"):
		Dialogic.signal_event.connect(_on_dialogic_signal)


func _on_dialogic_signal(argument: Variant) -> void:
	var command := str(argument)
	var parts := command.split(":", true, 1)
	if parts.size() < 2:
		push_warning("NarrativeBridge: ignoring non-semantic signal '%s'" % command)
		return

	var kind := parts[0]
	var payload := parts[1]

	match kind:
		"scene":
			if scene_controller != null:
				scene_controller.change_scene(payload)
		"photo":
			if payload == "hide":
				photo_viewer.hide_photo()
			else:
				_show_photo_by_id(payload)
		"interaction":
			if interaction_controller != null:
				interaction_controller.start_interaction(payload)
		"audio":
			_play_sfx(payload)
		_:
			push_warning("NarrativeBridge: unknown command kind '%s'" % kind)


func _show_photo_by_id(photo_id: String) -> void:
	if not PHOTOS.has(photo_id):
		push_warning("NarrativeBridge: unknown photo_id '%s'" % photo_id)
		return
	var resource_path: String = PHOTOS[photo_id]
	var tex: Texture2D = null
	if ResourceLoader.exists(resource_path, "Texture2D"):
		tex = load(resource_path) as Texture2D
	if tex == null:
		tex = _placeholder_texture(photo_id)
		push_warning("NarrativeBridge: photo '%s' texture missing; using placeholder." % photo_id)
	photo_viewer.show_photo(tex)


func _play_sfx(sfx_id: String) -> void:
	if sfx_player == null:
		return
	if not SFX.has(sfx_id):
		push_warning("NarrativeBridge: unknown sfx_id '%s'" % sfx_id)
		return

	var path: String = SFX[sfx_id]
	if not ResourceLoader.exists(path):
		push_warning("NarrativeBridge: missing sfx '%s' at %s" % [sfx_id, path])
		return

	sfx_player.stream = load(path)
	sfx_player.play()


func _placeholder_texture(_id: String) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.25, 0.6, 1.0))
	return ImageTexture.create_from_image(img)
