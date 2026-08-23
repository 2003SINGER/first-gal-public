extends CanvasLayer

## LockerCleanup
## A self-contained, one-shot cleanup interaction. It owns item presentation and
## decisions only: it neither knows S05 nor starts/resumes Dialogic.
##
## Every item carries branch data so each state has its own text (no single
## reused description):
##   第一次检视文本      inspect_text
##   初次保留文本        keep_text
##   初次舍弃/去向文本   discard_text        ("returned" 物品走"还给她"去向)
##   已保留后被迫重处理  late_discard_text / late_return_text
##
## `photo_pack` is a special item: it is NOT counted toward capacity and has no
## keep/discard. It must be inspected once, either by the player or by the
## finish-time fallback. Inspecting it shows the first-day classroom photo
## inside this panel (S13 echoes the same photo later).
##
## Result:
## {
##   "kept": PackedStringArray,
##   "discarded_initially": PackedStringArray,
##   "discarded_later": PackedStringArray,
##   "returned": PackedStringArray,          # e.g. ye_xiao_pen 还给叶晓
##   "overpacked_once": bool,                # true if the bag ever overflowed
## }

signal finished(result: Dictionary)
signal overflow_requested(result: Dictionary)

const MAX_KEPT := 3

const ITEMS := [
	{
		"id": "sports_day_bib",
		"display_name": "运动会号码布",
		"inspect_text": "一张皱巴巴的运动会号码布。\n号码已经褪得有点看不清了。\n背面还沾着一点不知道哪年的灰。",
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
		"id": "dead_refill",
		"display_name": "没水的笔芯",
		"inspect_text": "柜角滚出来一截黑色笔芯。\n刚才在卷子背面划了两下。\n没水。",
		"keep_label": "留着",
		"keep_text": "……留着干嘛。\n海象还是把它塞进了笔袋。",
		"discard_label": "扔掉",
		"discard_text": "确实没用。\n海象把它丢进旁边的废纸堆。",
		"late_discard_label": "舍弃",
		"late_discard_text": "本来都塞进包了。\n最后还是和别的没用的东西一起留在这里。",
		"discard_result": "discarded",
		"late_discard_result": "discarded_later",
	},
	{
		"id": "ye_xiao_pen",
		"display_name": "叶晓的笔",
		"inspect_text": "笔帽上刻着一个名字。\n叶晓的。\n什么时候混进我这儿来的，谁也说不清。",
		"keep_label": "先收着",
		"keep_text": "海象把它塞进笔袋。",
		"discard_label": "还给她",
		"discard_text": "海象把笔递过去。\n叶晓接过去看了一眼。\n\n“居然还能写。”",
		"late_discard_label": "还是还给她",
		"late_return_text": "海象又把笔拿了出来。\n叶晓：“怎么，想起来了？”\n海象：“腾位置。”\n叶晓：“……哦。”",
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
	{
		"id": "photo_pack",
		"display_name": "一袋照片",
		"is_photo_set": true,
		"inspect_text": "柜子最里面压着一个透明照片袋。\n\n我把它抽出来。\n\n里面是以前洗出来的一叠照片。\n\n第一张是空教室。\n\n黑板还是干净的，桌子也摆得整整齐齐。\n\n照片还有一点歪。\n\n……第一天。\n\n我又往后翻了几张。\n\n最后重新塞回袋子。",
	},
]

@onready var title_label: Label = $Panel/Margin/Layout/Title
@onready var status_label: Label = $Panel/Margin/Layout/Status
@onready var item_list: VBoxContainer = $Panel/Margin/Layout/Body/ItemList
@onready var item_name: Label = $Panel/Margin/Layout/Body/InspectPanel/ItemName
@onready var description: Label = $Panel/Margin/Layout/Body/InspectPanel/Description
@onready var photo_display: TextureRect = $Panel/Margin/Layout/Body/InspectPanel/PhotoDisplay
@onready var keep_button: Button = $Panel/Margin/Layout/Body/InspectPanel/Actions/KeepButton
@onready var discard_button: Button = $Panel/Margin/Layout/Body/InspectPanel/Actions/DiscardButton
@onready var finish_button: Button = $Panel/Margin/Layout/FinishButton

# item_id -> "unseen" | "unresolved" | "kept" | "discarded_initially"
#           | "discarded_later" | "returned" | "returned_late" | "collected"
var states := {}
var selected_id := ""
var resolving_overflow := false
var suspended_for_overflow := false
var overpacked_once := false


func _ready() -> void:
	for item in ITEMS:
		states[item.id] = "unseen" if item.get("is_photo_set", false) else "unresolved"
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
	var item := _item_for_id(item_id)
	if item.get("is_photo_set", false):
		_show_photo_set()
		if states[item_id] == "unseen":
			states[item_id] = "collected"
	else:
		_hide_photo_set()
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
		var late_is_return: bool = item.get("discard_result", "discarded") == "returned"
		states[selected_id] = "returned_late" if late_is_return else "discarded_later"
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
			return str(item.get("late_return_text", item.get("late_discard_text", "")))
		"collected":
			return str(item.get("inspect_text", ""))
	return str(item.get("inspect_text", ""))


func _try_finish() -> void:
	if _has_unresolved():
		status_label.text = "柜子里还有东西没有决定。"
		return
	if not _photo_pack_seen():
		_select_item("photo_pack")
		status_label.text = "柜子最里面还压着一袋照片。"
		return
	if _kept_ids().size() > MAX_KEPT:
		if resolving_overflow:
			status_label.text = "……装不下了。还要腾个位置。"
			_refresh()
			return
		overpacked_once = true
		suspended_for_overflow = true
		overflow_requested.emit(_build_result())
		hide()
		return
	_hide_photo_set()
	finished.emit(_build_result())


# --- Dev-only quick skip ---------------------------------------------------
# During development playtests, pressing Enter or Space fast-forwards the
# cleanup so the flow can be observed without deciding every item. Only active
# in debug builds; a release export never reaches this code path. The skip still
# goes through the normal `finished` emit, so the interaction closes, Dialogic
# resumes, and the downstream Timeline signal fire exactly as if the player had
# finished. Normal buttons are never affected. It refuses to fire while the
# overflow resolution is mid-flight, to avoid corrupting that transient state.
const DEBUG_SKIP_ENABLED := true


func _input(event: InputEvent) -> void:
	if not _debug_skip_allowed():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if key.keycode != KEY_ENTER and key.keycode != KEY_SPACE:
		return
	get_viewport().set_input_as_handled()
	_debug_complete()


func _debug_skip_allowed() -> bool:
	return DEBUG_SKIP_ENABLED and OS.is_debug_build()


func _debug_complete() -> void:
	if not visible:
		return
	if resolving_overflow or suspended_for_overflow:
		return
	# Force every item into a decided, non-overflowing state, then finish.
	var kept_count := 0
	for item in ITEMS:
		if item.get("is_photo_set", false):
			states[item.id] = "collected"
			continue
		var dresult: String = item.get("discard_result", "discarded")
		if dresult == "returned":
			states[item.id] = "returned"
		elif kept_count < MAX_KEPT:
			states[item.id] = "kept"
			kept_count += 1
		else:
			states[item.id] = "discarded_initially"
	_try_finish()


func resume_overflow() -> void:
	if not suspended_for_overflow:
		push_warning("LockerCleanup: resume_overflow() called without a suspended overflow.")
		return
	suspended_for_overflow = false
	resolving_overflow = true
	show()

	if states.get(selected_id, "") != "kept":
		var kept := _kept_ids()
		if not kept.is_empty():
			selected_id = kept[0]

	_hide_photo_set()
	_refresh()


func _refresh() -> void:
	var item := _item_for_id(selected_id)
	if item.is_empty():
		return

	var selected_state: String = states[selected_id]
	item_name.text = str(item.get("display_name", "物品"))
	description.text = _reaction_text(item, selected_state)

	if item.get("is_photo_set", false):
		keep_button.hide()
		discard_button.hide()
		title_label.text = "柜子整理｜一袋照片"
		status_label.text = "照片收着了，不用挑。"
		finish_button.text = "整理完毕"
		return

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
		if button_item.get("is_photo_set", false):
			# The photo bag is mandatory to inspect, but not a checklist item.
			button.text = button_item.display_name
			button.disabled = resolving_overflow
			continue
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


func _show_photo_set() -> void:
	if photo_display == null:
		return
	var nb := _photo_provider()
	if nb != null and nb.has_method("get_photo_texture"):
		photo_display.texture = nb.get_photo_texture("first_day_classroom")
	photo_display.show()


func _hide_photo_set() -> void:
	if photo_display != null:
		photo_display.hide()
		photo_display.texture = null


func _photo_provider() -> Node:
	# The locker is added as a child of InteractionController, which owns the
	# bridge to NarrativeBridge's photo registry.
	var parent := get_parent()
	if parent != null and parent.has_method("get_photo_texture"):
		return parent
	return null


func _has_unresolved() -> bool:
	return _unresolved_count() > 0


func _photo_pack_seen() -> bool:
	return states.get("photo_pack", "unseen") == "collected"


func _unresolved_count() -> int:
	var count := 0
	for item in ITEMS:
		if item.get("is_photo_set", false):
			continue
		if states[item.id] == "unresolved":
			count += 1
	return count


func _kept_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for item in ITEMS:
		if item.get("is_photo_set", false):
			continue
		if states[item.id] == "kept":
			result.append(item.id)
	return result


func _build_result() -> Dictionary:
	var kept := PackedStringArray()
	var discarded_initially := PackedStringArray()
	var discarded_later := PackedStringArray()
	var returned := PackedStringArray()
	for item in ITEMS:
		if item.get("is_photo_set", false):
			continue
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


func _exit_tree() -> void:
	_hide_photo_set()
