extends Node

## Current Demo runner.
## Starts the continuous production slice: S01 → S02 → S03 → S04 → S05 → S06
## → S07 → S08 → S09 → S10 → S11 → S12.
## main.tscn remains a neutral shell and is intentionally not changed to start this.
## Open res://dev/scenes/demo_current_runner.tscn and press F6.

func _ready() -> void:
	Dialogic.start("res://dialogic/timelines/01_return_to_school.dtl")
