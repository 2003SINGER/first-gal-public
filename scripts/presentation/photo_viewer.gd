extends Control

## PhotoViewer
## Minimal photo presentation surface. Lives under PresentationRoot (a normal
## Control in the main SceneTree), NOT a CanvasLayer. This keeps it below the
## Dialogic dialogue layer so dialogue text renders on top of a shown photo,
## and input always reaches Dialogic.
##
## Overlay / Dim / Photo are all mouse_filter = IGNORE so they never capture
## pointer input (the old CanvasLayer + STOP-filter design ate Dialogic clicks).

@onready var overlay: Control = $Overlay
@onready var photo: TextureRect = $Overlay/Photo


func _ready() -> void:
	overlay.hide()


func show_photo(texture: Texture2D) -> void:
	photo.texture = texture
	overlay.show()


func hide_photo() -> void:
	overlay.hide()
	photo.texture = null


func show_photo_fade(texture: Texture2D, duration := 0.22) -> void:
	photo.texture = texture
	overlay.modulate.a = 0.0
	overlay.show()
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, duration)
	await tween.finished


func hide_photo_fade(duration := 0.22) -> void:
	if not overlay.visible:
		return
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, duration)
	await tween.finished
	overlay.hide()
	overlay.modulate.a = 1.0
	photo.texture = null
