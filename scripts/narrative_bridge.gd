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
##   photo:fade_in:<id>      -> show photo with a short fade
##   photo:fade_out          -> hide photo with a short fade
##   interaction:<id>        -> start a modal gameplay interaction
##   audio:<sfx_id>          -> play a registered one-shot SFX (legacy shorthand)
##   audio:music:<id>|stop   -> Dialogic music channel
##   audio:amb:<id>|stop     -> Dialogic ambience channel
##   audio:sfx:<id>          -> Dialogic one-shot SFX channel
##   transition:<effect>     -> fade_out, fade_in, flash_white
##   chapter:<id>            -> project-owned upper-left chapter title
##   system:demo_end          -> explicit project-owned Demo End flow
##
## We do NOT yet build a custom Dialogic Event. The Alpha20 Signal event is used
## as-is; the whole command is sent as one string and split on ":" here.

var scene_controller: Node = null
var photo_viewer: Control = null
var interaction_controller: Node = null
var transition_controller: Control = null
var audio_bridge: Node = null
var demo_end_controller: Node = null
var chapter_title_overlay: Node = null

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

func setup(sc: Node, pv: Control, ic: Node, tc: Control, ab: Node, dec: Node, cto: Node) -> void:
	scene_controller = sc
	photo_viewer = pv
	interaction_controller = ic
	transition_controller = tc
	audio_bridge = ab
	demo_end_controller = dec
	chapter_title_overlay = cto
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
			elif payload == "fade_out":
				photo_viewer.hide_photo_fade()
			elif payload.begins_with("fade_in:"):
				_show_photo_by_id(payload.trim_prefix("fade_in:"), true)
			else:
				_show_photo_by_id(payload)
		"interaction":
			if interaction_controller != null:
				interaction_controller.start_interaction(payload)
		"audio":
			if audio_bridge != null:
				audio_bridge.handle_command(payload)
		"transition":
			if transition_controller != null:
				transition_controller.play(payload)
		"chapter":
			if chapter_title_overlay != null:
				chapter_title_overlay.show_chapter(payload)
		"system":
			if payload == "demo_end" and demo_end_controller != null:
				demo_end_controller.show_demo_end()
			elif payload != "demo_end":
				push_warning("NarrativeBridge: unknown system command '%s'" % payload)
		_:
			push_warning("NarrativeBridge: unknown command kind '%s'" % kind)


func _show_photo_by_id(photo_id: String, fade := false) -> void:
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
	if fade:
		photo_viewer.show_photo_fade(tex)
	else:
		photo_viewer.show_photo(tex)


func get_photo_texture(photo_id: String) -> Texture2D:
	if not PHOTOS.has(photo_id):
		push_warning("NarrativeBridge: unknown photo_id '%s'" % photo_id)
		return _placeholder_texture(photo_id)
	var resource_path: String = PHOTOS[photo_id]
	var tex: Texture2D = null
	if ResourceLoader.exists(resource_path, "Texture2D"):
		tex = load(resource_path) as Texture2D
	if tex == null:
		tex = _placeholder_texture(photo_id)
		push_warning("NarrativeBridge: photo '%s' texture missing; using placeholder." % photo_id)
	return tex


func _placeholder_texture(_id: String) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.25, 0.6, 1.0))
	return ImageTexture.create_from_image(img)
