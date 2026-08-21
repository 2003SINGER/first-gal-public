extends CanvasLayer

## LockerCleanup
## A self-contained, one-shot cleanup interaction. It owns item presentation and
## decisions only: it neither knows S05 nor starts/resumes Dialogic.
##
## Result:
## {
##   "kept": PackedStringArray,
##   "discarded_initially": PackedStringArray,
##   "discarded_later": PackedStringArray,
##   "overpacked_once": bool,   # true if the bag ever overflowed (capacity exceeded -> second discard)
## }

signal finished(result: Dictionary)

const MAX_KEPT := 3

const ITEMS := [
	{
		"id": "sports_day_bib",
		"display_name": "运动会号码布",
		"description": "高二运动会。号码已经有点褪色了。",
	},
	{
		"id": "old_workbook",
		"display_name": "旧练习册",
		"description": "翻到中间，有人用红笔写着：别睡了。",
	},
	{
		"id": "ye_xiao_pen",
		"display_name": "叶晓的笔",
		"description": "……她的？怎么会在我这里放到现在。",
	},
	{
		"id": "keychain_piece",
		"display_name": "断掉的钥匙扣",
		"description": "没什么用，也想不起什么时候塞进来的。",
	},
	{
		"id": "used_paper",
		"display_name": "揉皱的草稿纸",
		"description": "大半页是早就不会再看的演算。",
	},
]

@onready var title_label: Label = $Panel/Margin/Layout/Title
@onready var status_label: Label = $Panel/Margin/Layout/Status
@onready var item_list: VBoxContainer = $Panel/Margin/Layout/Body/ItemList
@onready var inspect_panel: ItemInspectPanel = $Panel/Margin/Layout/Body/InspectPanel
@onready var item_name: Label = $Panel/Margin/Layout/Body/InspectPanel/ItemName
@onready var description: Label = $Panel/Margin/Layout/Body/InspectPanel/Description
@onready var keep_button: Button = $Panel/Margin/Layout/Body/InspectPanel/Actions/KeepButton
@onready var discard_button: Button = $Panel/Margin/Layout/Body/InspectPanel/Actions/DiscardButton
@onready var finish_button: Button = $Panel/Margin/Layout/FinishButton

var states := {} # item_id -> "unresolved" | "kept" | "discarded_initially" | "discarded_later"
var selected_id := ""
var resolving_overflow := false
var overpacked_once := false


func _ready() -> void:
	for item in ITEMS:
		states[item.id] = "unresolved"
		_add_item_button(item)
	keep_button.pressed.connect(_keep_selected)
	discard_button.pressed.connect(_discard_selected)
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


func _keep_selected() -> void:
	if selected_id.is_empty() or resolving_overflow:
		return
	states[selected_id] = "kept"
	_refresh()


func _discard_selected() -> void:
	if selected_id.is_empty():
		return
	if resolving_overflow:
		states[selected_id] = "discarded_later"
	else:
		states[selected_id] = "discarded_initially"
	_refresh()


func _try_finish() -> void:
	if _has_unresolved():
		status_label.text = "柜子里还有东西没有决定。"
		return
	if _kept_ids().size() > MAX_KEPT:
		resolving_overflow = true
		overpacked_once = true
		status_label.text = "……装不下了。腾个位置。"
		_refresh()
		return
	finished.emit(_build_result())


func _refresh() -> void:
	var item := _item_for_id(selected_id)
	if item.is_empty():
		return

	inspect_panel.present_item(item)
	description.text = item.description

	var selected_state: String = states[selected_id]
	if resolving_overflow:
		title_label.text = "柜子整理｜腾个位置"
		keep_button.hide()
		discard_button.show()
		discard_button.text = "舍弃此物"
		if selected_state != "kept":
			discard_button.disabled = true
			description.text = "%s\n\n它已经被放进包里。现在要腾位置，只能从保留物里选。" % item.description
		else:
			discard_button.disabled = false
	else:
		title_label.text = "柜子整理"
		keep_button.show()
		keep_button.disabled = selected_state == "kept"
		discard_button.show()
		discard_button.text = "舍弃"
		discard_button.disabled = selected_state.begins_with("discarded")

	for index in item_list.get_child_count():
		var button := item_list.get_child(index) as Button
		var button_item: Dictionary = ITEMS[index]
		var state: String = states[button_item.id]
		var suffix := ""
		match state:
			"kept": suffix = "  [保留]"
			"discarded_initially": suffix = "  [舍弃]"
			"discarded_later": suffix = "  [后舍弃]"
		button.text = button_item.display_name + suffix
		button.disabled = resolving_overflow and state != "kept"

	if not resolving_overflow:
		var unresolved := _unresolved_count()
		if unresolved > 0:
			status_label.text = "逐件看看，再决定带走还是舍弃。"
		else:
			status_label.text = "都整理好了。确认后看看包还能不能装下。"
		finish_button.text = "整理完毕"
	else:
		var kept_count := _kept_ids().size()
		status_label.text = "……装不下了。还要腾出 %d 件。" % max(0, kept_count - MAX_KEPT)
		finish_button.text = "确认整理"


func _has_unresolved() -> bool:
	return _unresolved_count() > 0


func _unresolved_count() -> int:
	var count := 0
	for item in ITEMS:
		if states[item.id] == "unresolved":
			count += 1
	return count


func _kept_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for item in ITEMS:
		if states[item.id] == "kept":
			result.append(item.id)
	return result


func _build_result() -> Dictionary:
	var kept := PackedStringArray()
	var discarded_initially := PackedStringArray()
	var discarded_later := PackedStringArray()
	for item in ITEMS:
		match states[item.id]:
			"kept": kept.append(item.id)
			"discarded_initially": discarded_initially.append(item.id)
			"discarded_later": discarded_later.append(item.id)
	return {
		"kept": kept,
		"discarded_initially": discarded_initially,
		"discarded_later": discarded_later,
		"overpacked_once": overpacked_once,
	}


func _item_for_id(item_id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == item_id:
			return item
	return {}
