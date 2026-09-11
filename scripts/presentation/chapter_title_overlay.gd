extends CanvasLayer

## A small project presentation layer for story-scale chapter titles.
## Dialogic owns dialogue/timeline playback; it has no chapter-title component.

const TITLES := {
	"before_goodbye": "再见之前",
	"after_the_end": "结束之后",
}

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Title

var _tween: Tween = null


func _ready() -> void:
	root.hide()


func show_chapter(chapter_id: String) -> void:
	if not TITLES.has(chapter_id):
		push_warning("ChapterTitleOverlay: unknown chapter '%s'." % chapter_id)
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	title_label.text = str(TITLES[chapter_id])
	root.modulate.a = 0.0
	root.show()
	_tween = create_tween()
	_tween.tween_property(root, "modulate:a", 1.0, 0.32)
	_tween.tween_interval(1.7)
	_tween.tween_property(root, "modulate:a", 0.0, 0.45)
	_tween.tween_callback(root.hide)
