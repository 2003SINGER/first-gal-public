extends CanvasLayer

## DeskCleanup
## Small, one-shot inspection interaction for S11. It reuses ItemInspectPanel
## for item name/description display, but has no keep/discard or capacity rules.

signal finished(result: Dictionary)

const ITEMS := [
	{
		"id": "last_book",
		"display_name": "最后一本书",
		"description": "已经翻到最后几页。今天之后，应该不会再放回这张桌子。",
	},
	{
		"id": "crumpled_note",
		"display_name": "桌洞里的皱纸",
		"description": "上面写着：下课小卖部？只是某一天留下的一句话。",
	},
	{
		"id": "ordinary_small_item",
		"display_name": "普通小物件",
		"description": "没有特别的来历，也没有非带走不可的理由。",
	},
	{
		"id": "desk_trace",
		"display_name": "桌面痕迹",
		"description": "擦掉以后，桌面就只剩下一张普通的桌面。",
	},
]

@onready var status_label: Label = $Panel/Margin/Layout/Status
@onready var item_list: VBoxContainer = $Panel/Margin/Layout/Body/ItemList
@onready var inspect_panel: ItemInspectPanel = $Panel/Margin/Layout/Body/InspectPanel
@onready var process_button: Button = $Panel/Margin/Layout/Body/InspectPanel/ProcessButton
@onready var finish_button: Button = $Panel/Margin/Layout/FinishButton

var handled := {}
var selected_id := ""


func _ready() -> void:
	for item in ITEMS:
		handled[item.id] = false
		_add_item_button(item)
	process_button.pressed.connect(_handle_selected)
	finish_button.pressed.connect(_try_finish)
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
	_refresh()


func _handle_selected() -> void:
	if selected_id.is_empty():
		return
	handled[selected_id] = true
	_refresh()


func _try_finish() -> void:
	if _handled_count() < ITEMS.size():
		status_label.text = "桌上还有东西没有处理。"
		return
	var result := {"handled": _handled_ids()}
	finished.emit(result)


func _refresh() -> void:
	var item := _item_for_id(selected_id)
	if item.is_empty():
		return
	inspect_panel.present_item(item)
	process_button.disabled = handled[selected_id]
	process_button.text = "已处理" if handled[selected_id] else "标记处理完成"

	for index in item_list.get_child_count():
		var button := item_list.get_child(index) as Button
		var button_item: Dictionary = ITEMS[index]
		button.text = button_item.display_name + ("  [已处理]" if handled[button_item.id] else "")

	if _handled_count() == ITEMS.size():
		status_label.text = "桌面和桌洞都清好了。"
		finish_button.disabled = false
	else:
		status_label.text = "逐件查看，处理完一个再看下一个。"
		finish_button.disabled = false


func _handled_count() -> int:
	var count := 0
	for item in ITEMS:
		if handled[item.id]:
			count += 1
	return count


func _handled_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for item in ITEMS:
		if handled[item.id]:
			result.append(item.id)
	return result


func _item_for_id(item_id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == item_id:
			return item
	return {}
