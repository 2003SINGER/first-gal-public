extends Node

## Development runner for the first production slice.
## It intentionally reuses res://scenes/main.tscn and starts the continuous
## story unit 01_return_to_school (S01 → S02 → S03). main.gd stays narrative-agnostic.
## Open res://dev/scenes/s01_s03_runner.tscn and press F6 to play this slice.

func _ready() -> void:
	Dialogic.start("res://dialogic/timelines/01_return_to_school.dtl")
