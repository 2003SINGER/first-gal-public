extends Node

## SceneController
## Owns the "current world scene". Timeline only ever sends semantic ids
## (scene:school_gate); this class maps id -> PackedScene and swaps the child
## of SceneHost. No paths, no SceneTree knowledge leak into the timeline.
##
## The registry is intentionally a hard-coded Dictionary for now. Do NOT build a
## JSON manifest / ResourceCatalog / database yet — that is premature.

signal scene_changed(scene_id: String)

var scene_host: Control = null

const SCENES := {
	"blank": preload("res://scenes/world/blank.tscn"),
	"school_gate": preload("res://scenes/world/school_gate.tscn"),
	"school_corridor": preload("res://scenes/world/school_corridor.tscn"),
	"classroom": preload("res://scenes/world/classroom.tscn"),
	"classroom_morning": preload("res://scenes/world/classroom_morning.tscn"),
	"graduation_ceremony": preload("res://scenes/world/graduation_ceremony.tscn"),
	"lunch_route": preload("res://scenes/world/lunch_route.tscn"),
	"lunch": preload("res://scenes/world/lunch.tscn"),
	"classroom_afternoon": preload("res://scenes/world/classroom_afternoon.tscn"),
	"classroom_quiet": preload("res://scenes/world/classroom_quiet.tscn"),
	"classroom_late_afternoon": preload("res://scenes/world/classroom_late_afternoon.tscn"),
}

var current_scene: Node = null
var current_scene_id := ""


func setup(host: Control) -> void:
	scene_host = host


func change_scene(scene_id: String) -> void:
	if not SCENES.has(scene_id):
		push_warning("SceneController: unknown scene_id '%s' (known: %s)" % [scene_id, SCENES.keys()])
		return
	if scene_host == null:
		push_error("SceneController: scene_host not set; call setup() first.")
		return

	if current_scene != null and is_instance_valid(current_scene):
		scene_host.remove_child(current_scene)
		current_scene.queue_free()
		current_scene = null

	var packed: PackedScene = SCENES[scene_id]
	current_scene = packed.instantiate()
	scene_host.add_child(current_scene)
	current_scene_id = scene_id
	scene_changed.emit(scene_id)
