extends CanvasLayer

## Functional in-game shell. It is deliberately generic: no Timeline names,
## story choices, or relationship data appear here.

var session: Node = null
var mode := ""

@onready var root: Control = $Root
@onready var menu_panel: Panel = $Root/Menu
@onready var save_load_panel: Panel = $Root/SaveLoad
@onready var settings_panel: Panel = $Root/Settings
@onready var slot_list: VBoxContainer = $Root/SaveLoad/Margin/Layout/SlotList
@onready var save_load_title: Label = $Root/SaveLoad/Margin/Layout/Title
@onready var message: Label = $Root/SystemMessage
@onready var bgm_slider: HSlider = $Root/Settings/Margin/Layout/BGM
@onready var se_slider: HSlider = $Root/Settings/Margin/Layout/SE
@onready var text_speed_slider: HSlider = $Root/Settings/Margin/Layout/TextSpeed
@onready var fullscreen_toggle: CheckButton = $Root/Settings/Margin/Layout/Fullscreen


func _ready() -> void:
	root.hide()
	menu_panel.show()
	save_load_panel.hide()
	settings_panel.hide()
	$Root/Menu/Margin/Layout/Resume.pressed.connect(close)
	$Root/Menu/Margin/Layout/Save.pressed.connect(open_save)
	$Root/Menu/Margin/Layout/Load.pressed.connect(open_load)
	$Root/Menu/Margin/Layout/Settings.pressed.connect(open_settings)
	$Root/Menu/Margin/Layout/Title.pressed.connect(_return_to_title)
	$Root/SaveLoad/Margin/Layout/Back.pressed.connect(open_menu)
	$Root/Settings/Margin/Layout/Back.pressed.connect(open_menu)
	bgm_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_value(&"bgm_volume", value))
	se_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_value(&"se_volume", value))
	text_speed_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_value(&"text_speed", value))
	fullscreen_toggle.toggled.connect(func(value: bool) -> void: GameSettings.set_value(&"fullscreen", value))


func setup(owner: Node) -> void:
	session = owner


func toggle_menu() -> void:
	if root.visible:
		close()
	else:
		open_menu()


func open_menu() -> void:
	mode = ""
	root.show()
	menu_panel.show()
	save_load_panel.hide()
	settings_panel.hide()
	if session != null:
		session.set_system_menu_open(true)


func open_save() -> void:
	mode = "save"
	_open_save_load_panel("保存游戏")


func open_load() -> void:
	mode = "load"
	_open_save_load_panel("读取存档")


func _open_save_load_panel(title: String) -> void:
	root.show()
	menu_panel.hide()
	settings_panel.hide()
	save_load_panel.show()
	save_load_title.text = title
	_refresh_slots()
	if session != null:
		session.set_system_menu_open(true)


func open_settings() -> void:
	root.show()
	menu_panel.hide()
	save_load_panel.hide()
	settings_panel.show()
	bgm_slider.set_value_no_signal(float(GameSettings.get_value(&"bgm_volume")))
	se_slider.set_value_no_signal(float(GameSettings.get_value(&"se_volume")))
	text_speed_slider.set_value_no_signal(float(GameSettings.get_value(&"text_speed")))
	fullscreen_toggle.set_pressed_no_signal(bool(GameSettings.get_value(&"fullscreen")))
	if session != null:
		session.set_system_menu_open(true)


func close() -> void:
	root.hide()
	if session != null:
		session.set_system_menu_open(false)


func show_message(text: String) -> void:
	message.text = text
	message.show()
	var timer := get_tree().create_timer(1.8)
	timer.timeout.connect(message.hide)


func _refresh_slots() -> void:
	for child in slot_list.get_children():
		child.queue_free()
	for entry in SaveService.get_manual_slots():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 42)
		var metadata: Dictionary = entry.get("metadata", {})
		var label := str(entry.get("slot", ""))
		if bool(entry.get("exists", false)):
			label += "  %s  |  %s" % [
				metadata.get("saved_at", "未知时间"),
				metadata.get("scene", "未知场景"),
			]
		else:
			label += "  空"
		button.text = label
		var slot_name := str(entry.get("slot", ""))
		button.pressed.connect(_choose_slot.bind(slot_name))
		slot_list.add_child(button)


func _choose_slot(slot_name: String) -> void:
	if session == null:
		return
	if mode == "save":
		var index := int(slot_name.trim_prefix("save_"))
		var error: Error = session.save_manual_slot(index)
		if error == OK:
			show_message("已保存")
		elif error == ERR_BUSY:
			show_message("当前整理中，暂不能保存")
		else:
			show_message("保存失败")
		_refresh_slots()
		return
	if mode == "load":
		if not SaveService.has_slot(slot_name):
			show_message("这是空存档")
			return
		var index := int(slot_name.trim_prefix("save_"))
		await session.load_manual_slot(index)
		close()


func _return_to_title() -> void:
	if Dialogic != null:
		Dialogic.end_timeline(true)
	get_tree().change_scene_to_file("res://scenes/title/title_screen.tscn")
