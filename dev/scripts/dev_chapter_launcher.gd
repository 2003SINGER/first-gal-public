extends Node

## Debug-build-only production launcher. It starts the real main shell and uses
## Dialogic's supported event-index entry point, so Timeline source stays free
## of development labels. Update the small index table after structural edits;
## `timeline_event_probe.gd` prints the current processed indices.

const CHAPTERS := {
	"S01": {"timeline": "01_return_to_school", "index": 7, "scene": "blank"},
	"S05": {"timeline": "02_locker_and_future", "index": 7, "scene": "school_corridor"},
	"S11": {"timeline": "03_lunch_and_afternoon", "index": 144, "scene": "classroom_afternoon"},
	"S14": {"timeline": "04_memory_and_ending", "index": 24, "scene": "classroom_late_afternoon"},
	"S17": {"timeline": "04_memory_and_ending", "index": 101, "scene": "classroom_late_afternoon"},
}

@onready var runtime: Node = $FirstGal
@onready var status_label: Label = $DevUI/Panel/Margin/Layout/Status


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	for chapter_id in CHAPTERS:
		var button: Button = get_node("DevUI/Panel/Margin/Layout/Chapters/%s" % chapter_id)
		button.pressed.connect(jump_to.bind(chapter_id))
	call_deferred("_boot")


func _boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	jump_to("S01")


func _process(_delta: float) -> void:
	if not OS.is_debug_build() or not is_instance_valid(runtime):
		return
	var scene_id: String = str(runtime.get_node("SceneController").get("current_scene_id"))
	var timeline: String = "-"
	var event_index: int = -1
	if Dialogic.current_timeline != null:
		timeline = Dialogic.current_timeline.resource_path.get_file()
		event_index = Dialogic.current_event_idx
	var interaction: Variant = runtime.get_node("InteractionController").get("active_interaction")
	status_label.text = "scene: %s\ntimeline: %s  event: %d\ninteraction: %s" % [scene_id, timeline, event_index, "active" if interaction != null else "none"]


func jump_to(chapter_id: String) -> void:
	if not CHAPTERS.has(chapter_id):
		return
	var target: Dictionary = CHAPTERS[chapter_id]
	var target_scene: String = str(target.get("scene", "blank"))
	var target_timeline: String = str(target.get("timeline", ""))
	var target_index: int = int(target.get("index", 0))
	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)
	await Dialogic.clear()
	runtime.get_node("SceneController").change_scene(target_scene)
	Dialogic.start(target_timeline, target_index)
