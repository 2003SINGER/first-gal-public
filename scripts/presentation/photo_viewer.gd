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
