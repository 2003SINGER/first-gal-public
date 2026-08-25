extends Node2D

## Replaceable title presentation shell. World contains only placeholders today;
## future art replaces those nodes while the camera and menu contract stay put.

@onready var camera: Camera2D = $Camera2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var menu_ui: Control = $CanvasLayer/MenuUI
@onready var load_panel: Panel = $CanvasLayer/MenuUI/LoadPanel
@onready var settings_panel: Panel = $CanvasLayer/MenuUI/SettingsPanel
@onready var slot_list: VBoxContainer = $CanvasLayer/MenuUI/LoadPanel/Margin/Layout/SlotList
@onready var bgm_slider: HSlider = $CanvasLayer/MenuUI/SettingsPanel/Margin/Layout/BGM
@onready var se_slider: HSlider = $CanvasLayer/MenuUI/SettingsPanel/Margin/Layout/SE
@onready var text_speed_slider: HSlider = $CanvasLayer/MenuUI/SettingsPanel/Margin/Layout/TextSpeed
@onready var fullscreen_toggle: CheckButton = $CanvasLayer/MenuUI/SettingsPanel/Margin/Layout/Fullscreen


func _ready() -> void:
	menu_ui.hide()
	load_panel.hide()
	settings_panel.hide()
	$CanvasLayer/MenuUI/Start.pressed.connect(GameSession.begin_new_game)
	$CanvasLayer/MenuUI/Load.pressed.connect(_open_load)
	$CanvasLayer/MenuUI/Settings.pressed.connect(_open_settings)
	$CanvasLayer/MenuUI/Quit.pressed.connect(get_tree().quit)
	$CanvasLayer/MenuUI/LoadPanel/Margin/Layout/Back.pressed.connect(_close_subpanel)
	$CanvasLayer/MenuUI/SettingsPanel/Margin/Layout/Back.pressed.connect(_close_subpanel)
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
		menu_ui.show()


func _open_load() -> void:
	load_panel.show()
	settings_panel.hide()
	_refresh_slots()


func _open_settings() -> void:
	settings_panel.show()
	load_panel.hide()
	bgm_slider.set_value_no_signal(float(GameSettings.get_value(&"bgm_volume")))
	se_slider.set_value_no_signal(float(GameSettings.get_value(&"se_volume")))
	text_speed_slider.set_value_no_signal(float(GameSettings.get_value(&"text_speed")))
	fullscreen_toggle.set_pressed_no_signal(bool(GameSettings.get_value(&"fullscreen")))


func _close_subpanel() -> void:
	load_panel.hide()
	settings_panel.hide()


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
