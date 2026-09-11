extends Node2D

## Replaceable title presentation shell. World contains only placeholders today;
## future art replaces those nodes while the camera and menu contract stay put.

@onready var camera: Camera2D = $Camera2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var menu_ui: Control = $CanvasLayer/MenuUI
@onready var continue_button: Button = $CanvasLayer/MenuUI/Continue
@onready var load_panel: Panel = $CanvasLayer/MenuUI/LoadPanel
@onready var settings_panel: Panel = $CanvasLayer/MenuUI/SettingsPanel
@onready var extras_panel: Panel = $CanvasLayer/MenuUI/ExtrasPanel
@onready var demo_recollection_button: Button = $CanvasLayer/MenuUI/ExtrasPanel/Margin/Layout/DemoRecollection
@onready var slot_list: VBoxContainer = $CanvasLayer/MenuUI/LoadPanel/Margin/Layout/SlotList
@onready var bgm_slider: HSlider = $CanvasLayer/MenuUI/SettingsPanel/Margin/Layout/BGM
@onready var se_slider: HSlider = $CanvasLayer/MenuUI/SettingsPanel/Margin/Layout/SE
@onready var text_speed_slider: HSlider = $CanvasLayer/MenuUI/SettingsPanel/Margin/Layout/TextSpeed
@onready var fullscreen_toggle: CheckButton = $CanvasLayer/MenuUI/SettingsPanel/Margin/Layout/Fullscreen

var _intro_finished := false


func _ready() -> void:
	menu_ui.hide()
	load_panel.hide()
	settings_panel.hide()
	extras_panel.hide()
	continue_button.visible = SaveService.has_slot(SaveService.AUTO_SLOT)
	continue_button.pressed.connect(_continue_game)
	$CanvasLayer/MenuUI/Start.pressed.connect(GameSession.begin_new_game)
	$CanvasLayer/MenuUI/Load.pressed.connect(_open_load)
	$CanvasLayer/MenuUI/Settings.pressed.connect(_open_settings)
	$CanvasLayer/MenuUI/Extras.pressed.connect(_open_extras)
	$CanvasLayer/MenuUI/Quit.pressed.connect(get_tree().quit)
	$CanvasLayer/MenuUI/LoadPanel/Margin/Layout/Back.pressed.connect(_close_subpanel)
	$CanvasLayer/MenuUI/SettingsPanel/Margin/Layout/Back.pressed.connect(_close_subpanel)
	$CanvasLayer/MenuUI/ExtrasPanel/Margin/Layout/Back.pressed.connect(_close_subpanel)
	$CanvasLayer/MenuUI/ExtrasPanel/Margin/Layout/TitleAnimation.pressed.connect(_replay_title_animation)
	demo_recollection_button.pressed.connect(_open_demo_recollection)
	bgm_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_value(&"bgm_volume", value))
	se_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_value(&"se_volume", value))
	text_speed_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_value(&"text_speed", value))
	fullscreen_toggle.toggled.connect(func(value: bool) -> void: GameSettings.set_value(&"fullscreen", value))
	_build_intro_animation()
	animation_player.animation_finished.connect(_on_intro_finished)
	animation_player.play(&"intro")


func _build_intro_animation() -> void:
	var animation := Animation.new()
	animation.length = 6.5
	var zoom_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(zoom_track, NodePath("Camera2D:zoom"))
	animation.track_insert_key(zoom_track, 0.0, Vector2(2.45, 2.45))
	animation.track_insert_key(zoom_track, 6.5, Vector2.ONE)
	var position_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(position_track, NodePath("Camera2D:position"))
	animation.track_insert_key(position_track, 0.0, Vector2(1110, 560))
	animation.track_insert_key(position_track, 6.5, Vector2(960, 540))
	var library := AnimationLibrary.new()
	library.add_animation(&"intro", animation)
	animation_player.add_animation_library(&"", library)


func _on_intro_finished(name: StringName) -> void:
	if name == &"intro":
		_finish_intro()


func _unhandled_input(event: InputEvent) -> void:
	if _intro_finished:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			_skip_intro()
			get_viewport().set_input_as_handled()


func _skip_intro() -> void:
	if _intro_finished:
		return
	animation_player.stop()
	# Do not rely on AnimationPlayer.seek() retaining a dynamically-created
	# track sample after stop; write the final title composition explicitly.
	camera.zoom = Vector2.ONE
	camera.position = Vector2(960, 540)
	_finish_intro()


func _finish_intro() -> void:
	if _intro_finished:
		return
	_intro_finished = true
	menu_ui.show()


func _continue_game() -> void:
	GameSession.begin_load_game(SaveService.AUTO_SLOT)


func _open_load() -> void:
	load_panel.show()
	settings_panel.hide()
	_refresh_slots()


func _open_settings() -> void:
	settings_panel.show()
	load_panel.hide()
	extras_panel.hide()
	bgm_slider.set_value_no_signal(float(GameSettings.get_value(&"bgm_volume")))
	se_slider.set_value_no_signal(float(GameSettings.get_value(&"se_volume")))
	text_speed_slider.set_value_no_signal(float(GameSettings.get_value(&"text_speed")))
	fullscreen_toggle.set_pressed_no_signal(bool(GameSettings.get_value(&"fullscreen")))


func _open_extras() -> void:
	extras_panel.show()
	load_panel.hide()
	settings_panel.hide()
	var unlocked := ExtrasProgress.is_unlocked(&"graduation_day_demo")
	demo_recollection_button.disabled = not unlocked
	demo_recollection_button.text = "毕业日 Demo 回忆" if unlocked else "毕业日 Demo 回忆（通关后解锁）"


func _close_subpanel() -> void:
	load_panel.hide()
	settings_panel.hide()
	extras_panel.hide()


func _replay_title_animation() -> void:
	_close_subpanel()
	menu_ui.hide()
	_intro_finished = false
	camera.zoom = Vector2(2.45, 2.45)
	camera.position = Vector2(1110, 560)
	animation_player.play(&"intro")


func _open_demo_recollection() -> void:
	if not ExtrasProgress.is_unlocked(&"graduation_day_demo"):
		return
	GameSession.begin_recollection(&"graduation_day_demo")


func _refresh_slots() -> void:
	for child in slot_list.get_children():
		child.queue_free()
	for entry in SaveService.get_manual_slots():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 42)
		var metadata: Dictionary = entry.get("metadata", {})
		button.text = str(entry.get("slot", ""))
		if bool(entry.get("exists", false)):
			button.text += "  %s  |  %s" % [
				metadata.get("saved_at", "未知时间"),
				metadata.get("scene", "未知场景"),
			]
		else:
			button.text += "  空"
		var slot_name := str(entry.get("slot", ""))
		button.pressed.connect(_load_slot.bind(slot_name))
		slot_list.add_child(button)


func _load_slot(slot_name: String) -> void:
	if not SaveService.has_slot(slot_name):
		return
	GameSession.begin_load_game(slot_name)
