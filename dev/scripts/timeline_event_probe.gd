extends Node

## Maintainer aid: `--headless --script res://dev/scripts/timeline_event_probe.gd`
## prints processed Dialogic event indices without modifying a Timeline.

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for timeline_id in [
		"01_return_to_school",
		"02_locker_and_future",
		"03_lunch_and_afternoon",
		"04_memory_and_ending",
	]:
		var timeline = DialogicResourceUtil.get_timeline_resource(timeline_id)
		timeline.process()
		print("=== %s" % timeline_id)
		for index in timeline.events.size():
			var event = timeline.events[index]
			print("%03d %s %s" % [index, event.get_class(), event])
	get_tree().quit()
