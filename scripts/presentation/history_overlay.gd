extends Control

## Development-only dialogue history overlay.
## Uses Dialogic's built-in simple history instead of scraping visible labels.

const MAX_VISIBLE_ENTRIES := 80

@onready var history_log: VBoxContainer = %HistoryLog
@onready var history_box: ScrollContainer = %HistoryBox

var _history_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var history = DialogicUtil.autoload().get(&"History")
	if history != null and not history.simple_history_changed.is_connected(_on_history_changed):
		history.simple_history_changed.connect(_on_history_changed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_H:
				toggle_history()
				get_viewport().set_input_as_handled()
				return
			if _history_open and key_event.keycode == KEY_ESCAPE:
				close_history()
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not _history_open:
				open_history()
			get_viewport().set_input_as_handled()

func toggle_history() -> void:
	if _history_open:
		close_history()
	else:
		open_history()

func open_history() -> void:
	_history_open = true
	DialogicUtil.autoload().paused = true
	_refresh_history()
	show()
	call_deferred("_scroll_to_bottom")

func close_history() -> void:
	_history_open = false
	DialogicUtil.autoload().paused = false
	hide()

func _on_history_changed() -> void:
	if _history_open:
		_refresh_history()
		call_deferred("_scroll_to_bottom")

func _refresh_history() -> void:
	for child in history_log.get_children():
		child.queue_free()

	var history = DialogicUtil.autoload().get(&"History")
	if history == null:
		return

	var entries: Array = history.get_simple_history()
	var start_index := maxi(0, entries.size() - MAX_VISIBLE_ENTRIES)
	for index in range(start_index, entries.size()):
		var info: Dictionary = entries[index]
		if info.get("event_type", "") != "Text":
			continue
		var row := RichTextLabel.new()
		row.bbcode_enabled = true
		row.fit_content = true
		row.scroll_active = false
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 34)
		row.add_theme_font_size_override("normal_font_size", 24)
		row.add_theme_color_override("default_color", Color("#eeeeee"))
		var text := str(info.get("text", ""))
		var character := str(info.get("character", ""))
		if character.is_empty():
			row.text = "旁白：" + text
		else:
			row.text = "[color=#a9c7ff]" + character + "：[/color]" + text
		history_log.add_child(row)

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	history_box.scroll_vertical = history_box.get_v_scroll_bar().max_value
