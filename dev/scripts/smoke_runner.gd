extends Node

## Display Smoke Test runner.
## Reuses the REAL production shell (res://scenes/main.tscn) so the test exercises
## the actual SceneController / NarrativeBridge / PhotoViewer. It only starts the
## smoke timeline; all behaviour is driven by semantic signals, exactly like the
## future Sxx timelines will be. This is NOT part of the Demo content.

func _ready() -> void:
	Dialogic.start("res://dev/timelines/display_smoke_test.dtl")
