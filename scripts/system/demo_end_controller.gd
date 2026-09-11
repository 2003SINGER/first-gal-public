extends CanvasLayer

## Explicit demo-ending boundary. It is invoked only by the Timeline's
## `system:demo_end` signal, never inferred from generic timeline_ended events.

var _showing := false

@onready var root: Control = $Root
@onready var replay_button: Button = $Root/Panel/Margin/Layout/Replay
@onready var title_button: Button = $Root/Panel/Margin/Layout/ReturnTitle


func _ready() -> void:
	root.hide()
	replay_button.pressed.connect(_replay)
	title_button.pressed.connect(_return_to_title)


func show_demo_end() -> void:
	if _showing:
		return
	_showing = true
	ExtrasProgress.unlock(&"graduation_day_demo")
	if Dialogic != null:
		Dialogic.paused = true
	root.modulate.a = 0.0
	root.show()
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.45)


func _replay() -> void:
	if Dialogic != null:
		Dialogic.end_timeline(true)
	GameSession.begin_new_game()


func _return_to_title() -> void:
	if Dialogic != null:
		Dialogic.end_timeline(true)
	get_tree().change_scene_to_file("res://scenes/title/title_screen.tscn")
