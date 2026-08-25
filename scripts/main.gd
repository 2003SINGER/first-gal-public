extends Node

## FirstGal — Demo production shell (thin).
## Wires the display components together and picks a default world scene.
## It does NOT contain any narrative/smoke-test logic, and does NOT know any
## specific scene file, photo path, or Sxx content. A Demo timeline (built later,
## starting from S01) drives everything through semantic signals.

func _ready() -> void:
	var scene_host := $SceneHost as Control
	var photo_viewer := $PresentationRoot/PhotoViewer as Control
	var sfx_player := $PresentationRoot/SFXPlayer as AudioStreamPlayer

	$SceneController.setup(scene_host)
	$NarrativeBridge.setup($SceneController, photo_viewer, $InteractionController, sfx_player)
	$InteractionController.setup_bridge($NarrativeBridge)
	sfx_player.bus = &"SFX"

	# Neutral default until a Demo timeline tells us where we are.
	$SceneController.change_scene("blank")
	GameSession.attach_runtime($SceneController, $UIRoot, $InteractionController)


func _exit_tree() -> void:
	GameSession.detach_runtime()
