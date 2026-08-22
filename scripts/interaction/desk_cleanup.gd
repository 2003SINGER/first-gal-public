extends CanvasLayer

## DeskCleanup
## Small, one-shot inspection interaction for S11. It reuses the shared item
## inspection display, but has no keep/discard or capacity rules.
##
## Inspecting an item marks it seen (no "process" button, no [已处理] tag).
## Once everything has been looked at, the "收拾好了" button becomes clickable
## and the Timeline performs the actual desk-clearing as a staged beat.

signal finished(result: Dictionary)

const ITEMS := [
	{
		"id": "last_book",
		"display_name": "最后一本书",
		"inspect_text": "已经翻到最后几页。\n\n书角卷得挺厉害。\n\n我翻了一下，又合上。",
	},
	{
		"id": "crumpled_note",
		"display_name": "皱纸",
		"inspect_text": "“下课小卖部？”\n\n纸已经揉得发软。\n\n……哪天的来着。",
	},
]

@onready var status_label: Label = $Panel/Margin/Layout/Status
@onready var item_list: VBoxContainer = $Panel/Margin/Layout/Body/ItemList
@onready var item_name: Label = $Panel/Margin/Layout/Body/InspectPanel/ItemName
@onready var description: Label = $Panel/Margin/Layout/Body/InspectPanel/Description
@onready var finish_button: Button = $Panel/Margin/Layout/FinishButton

var seen := {}
var selected_id := ""


func _ready() -> void:
	for item in ITEMS:
		seen[item.id] = false
		_add_item_button(item)
	_select_item(ITEMS[0].id)
	_refresh()


func _add_item_button(item: Dictionary) -> void:
	var button := Button.new()
	button.name = "%sButton" % item.id
	button.text = item.display_name
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(300, 48)
	button.pressed.connect(_select_item.bind(item.id))
	item_list.add_child(button)


func _select_item(item_id: String) -> void:
	selected_id = item_id
	seen[item_id] = true   # merely opening an item counts as having looked at it
	_refresh()


func _try_finish() -> void:
	if _seen_count() < ITEMS.size():
		status_label.text = "桌洞里还有东西没看。"
		return
	var result := {"seen": _seen_ids()}
	finished.emit(result)


func _refresh() -> void:
	var item := _item_for_id(selected_id)
	if item.is_empty():
		return
	item_name.text = str(item.get("display_name", "物品"))
	description.text = str(item.get("inspect_text", ""))

	for index in item_list.get_child_count():
		var button := item_list.get_child(index) as Button
		var button_item: Dictionary = ITEMS[index]
		button.text = button_item.display_name

	status_label.text = ""
	finish_button.disabled = _seen_count() != ITEMS.size()


func _seen_count() -> int:
	var count := 0
	for item in ITEMS:
		if seen[item.id]:
			count += 1
	return count


func _seen_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for item in ITEMS:
		if seen[item.id]:
			result.append(item.id)
	return result


func _item_for_id(item_id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == item_id:
			return item
	return {}
