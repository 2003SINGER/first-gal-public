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
##   "returned": PackedStringArray,          # e.g. ye_xiao_pen given back
##   "overpacked_once": bool,                # true if the bag ever overflowed
## }

signal finished(result: Dictionary)

const MAX_KEPT := 3

const ITEMS := [
	{
		"id": "sports_day_bib",
		"display_name": "运动会号码布",
		"inspect_text": "高二运动会。\n号码已经褪得有点看不清了。\n\n朋友：“你跑第几？”\n海象：“倒数第二。”\n朋友：“那最后一个呢？”\n海象：“摔了。”",
		"keep_label": "留着",
		"keep_text": "折两下，塞进侧袋。\n反正也不占地方。",
		"discard_label": "扔掉",
		"discard_text": "都皱成这样了。\n海象把它扔进旁边的废纸堆。",
		"late_discard_label": "舍弃",
		"late_discard_text": "确实不占地方。\n但能塞进去的东西也就这么多。",
		"discard_result": "discarded",
		"late_discard_result": "discarded_later",
	},
	{
		"id": "old_workbook",
		"display_name": "旧练习册",
		"inspect_text": "一本已经做完很久的练习册。\n翻到中间，有人拿红笔在一道题旁边写着：\n\n“别睡了。”\n\n海象：“字还挺丑。”",
		"keep_label": "带走",
		"keep_text": "海象翻回封面，把它压进包底。",
		"discard_label": "扔废纸",
		"discard_text": "做过的题倒是都还在。\n应该也不会再看第二遍了。",
		"late_discard_label": "舍弃",
		"late_discard_text": "本来都塞进包了。\n最后还是和其他做完的题一起留在这里。",
		"discard_result": "discarded",
		"late_discard_result": "discarded_later",
	},
	{
		"id": "ye_xiao_pen",
		"display_name": "叶晓的笔",
		"inspect_text": "笔帽上有叶晓的名字。\n\n海象：“你的？”\n叶晓：“你现在才发现？”\n海象：“什么时候到我这儿的？”\n叶晓：“不知道。我早当丢了。”",
		"keep_label": "先收着",
		"keep_text": "“反正都放这么久了。”\n\n海象把它塞进笔袋。",
		"discard_label": "还给她",
		"discard_text": "海象把笔递过去。\n叶晓接过去看了一眼。\n\n“居然还能写。”",
		"late_discard_label": "还是还给她",
		"late_discard_text": "海象又把笔拿了出来。\n叶晓：“怎么，想起来了？”\n海象：“腾位置。”\n叶晓：“……哦。”",
		"discard_result": "returned",
		"late_discard_result": "returned",
	},
	{
		"id": "freshman_map",
		"display_name": "入学报到折页",
		"inspect_text": "折痕已经快把纸分成几块了。\n\n背面还写着班级和教室号。\n\n海象：第一次来学校，好像就是拿着这个找楼的。",
		"keep_label": "留着",
		"keep_text": "明明路线早就记熟了。\n海象还是把它折回原来的样子。",
		"discard_label": "扔掉",
		"discard_text": "现在倒是闭着眼都知道怎么走了。",
		"late_discard_label": "舍弃",
		"late_discard_text": "海象展开看了一眼，又重新折好。\n\n最后还是放进了废纸堆。",
		"discard_result": "discarded",
		"late_discard_result": "discarded_later",
	},
	{
		"id": "broken_ruler",
		"display_name": "断尺",
		"inspect_text": "一把只剩十二厘米的透明尺。\n\n断口还挺整齐。\n\n海象：……这为什么还在？",
		"keep_label": "留着？",
		"keep_text": "海象看了两秒。\n\n还是塞进去了。",
		"discard_label": "扔掉",
		"discard_text": "这次没什么好犹豫的。",
		"late_discard_label": "舍弃",
		"late_discard_text": "我刚才到底为什么会想留这个？",
		"discard_result": "discarded",
		"late_discard_result": "discarded_later",
	},
]

@onready var title_label: Label = $Panel/Margin/Layout/Title
@onready var status_label: Label = $Panel/Margin/Layout/Status
@onready var item_list: VBoxContainer = $Panel/Margin/Layout/Body/ItemList
@onready var item_name: Label = $Panel/Margin/Layout/Body/InspectPanel/ItemName
@onready var description: Label = $Panel/Margin/Layout/Body/InspectPanel/Description
@onready var keep_button: Button = $Panel/Margin/Layout/Body/InspectPanel/Actions/KeepButton
@onready var discard_button: Button = $Panel/Margin/Layout/Body/InspectPanel/Actions/DiscardButton
@onready var finish_button: Button = $Panel/Margin/Layout/FinishButton

# item_id -> "unresolved" | "kept" | "discarded_initially"
#           | "discarded_later" | "returned" | "returned_late"
var states := {}
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
	var item := _item_for_id(selected_id)
	if resolving_overflow:
		var late_result: String = item.get("late_discard_result", "discarded_later")
		states[selected_id] = "returned_late" if late_result == "returned" else "discarded_later"
	else:
		var dresult: String = item.get("discard_result", "discarded")
		states[selected_id] = "returned" if dresult == "returned" else "discarded_initially"
	_refresh()


func _reaction_text(item: Dictionary, state: String) -> String:
	match state:
		"unresolved":
			return str(item.get("inspect_text", ""))
		"kept":
			return str(item.get("keep_text", ""))
		"discarded_initially":
			return str(item.get("discard_text", ""))
		"discarded_later":
			return str(item.get("late_discard_text", ""))
		"returned":
			return str(item.get("discard_text", ""))
		"returned_late":
			return str(item.get("late_discard_text", ""))
	return str(item.get("inspect_text", ""))


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

	var selected_state: String = states[selected_id]
	item_name.text = str(item.get("display_name", "物品"))
	description.text = _reaction_text(item, selected_state)

	if resolving_overflow:
		title_label.text = "柜子整理｜腾个位置"
		keep_button.hide()
		discard_button.show()
		discard_button.text = str(item.get("late_discard_label", "舍弃"))
		discard_button.disabled = selected_state != "kept"
	else:
		title_label.text = "柜子整理"
		keep_button.show()
		keep_button.text = str(item.get("keep_label", "保留"))
		keep_button.disabled = selected_state == "kept"
		discard_button.show()
		discard_button.text = str(item.get("discard_label", "舍弃"))
		discard_button.disabled = selected_state in ["discarded_initially", "discarded_later", "returned", "returned_late"]

	for index in item_list.get_child_count():
		var button := item_list.get_child(index) as Button
		var button_item: Dictionary = ITEMS[index]
		var state: String = states[button_item.id]
		var suffix := ""
		match state:
			"kept": suffix = "  [保留]"
			"discarded_initially": suffix = "  [舍弃]"
			"discarded_later": suffix = "  [后舍弃]"
			"returned", "returned_late": suffix = "  [已还]"
		button.text = button_item.display_name + suffix
		button.disabled = resolving_overflow and state != "kept"

	if not resolving_overflow:
		var unresolved := _unresolved_count()
		if unresolved > 0:
			status_label.text = "柜子里还剩几样东西没决定。"
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
	var returned := PackedStringArray()
	for item in ITEMS:
		match states[item.id]:
			"kept": kept.append(item.id)
			"discarded_initially": discarded_initially.append(item.id)
			"discarded_later": discarded_later.append(item.id)
			"returned", "returned_late": returned.append(item.id)
	return {
		"kept": kept,
		"discarded_initially": discarded_initially,
		"discarded_later": discarded_later,
		"returned": returned,
		"overpacked_once": overpacked_once,
	}


func _item_for_id(item_id: String) -> Dictionary:
	for item in ITEMS:
		if item.id == item_id:
			return item
	return {}
