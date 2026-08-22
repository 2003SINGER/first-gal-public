extends Node

## InteractionController
## Thin owner for modal gameplay interactions. It maps a semantic interaction id
## to an interaction scene, pauses Dialogic while that interaction is open, and
## exposes the last result for the current Demo-shell lifetime.
##
## It does not know S05, a Timeline, or which dialogue follows completion.

signal interaction_finished(interaction_id: String, result: Dictionary)

const LOCKER_CLEANUP_SCENE := preload("res://scenes/interaction/locker_cleanup.tscn")
const DESK_CLEANUP_SCENE := preload("res://scenes/interaction/desk_cleanup.tscn")

var active_interaction: Node = null
var last_locker_result: Dictionary = {}
var locker_items_kept := PackedStringArray()
var locker_items_discarded_initially := PackedStringArray()
var locker_items_discarded_later := PackedStringArray()
var locker_items_returned := PackedStringArray()
var last_desk_result: Dictionary = {}
var narrative_bridge: Node = null


func setup_bridge(nb: Node) -> void:
	narrative_bridge = nb


func get_photo_texture(photo_id: String) -> Texture2D:
	if narrative_bridge != null and narrative_bridge.has_method("get_photo_texture"):
		return narrative_bridge.get_photo_texture(photo_id)
	push_warning("InteractionController: no narrative_bridge wired; cannot fetch photo '%s'" % photo_id)
	return null


func start_interaction(interaction_id: String) -> void:
	if active_interaction != null and is_instance_valid(active_interaction):
		push_warning("InteractionController: '%s' requested while another interaction is active." % interaction_id)
		return

	match interaction_id:
		"locker_cleanup":
			active_interaction = LOCKER_CLEANUP_SCENE.instantiate()
			active_interaction.finished.connect(_on_locker_cleanup_finished)
			add_child(active_interaction)
			Dialogic.paused = true
		"desk_cleanup":
			active_interaction = DESK_CLEANUP_SCENE.instantiate()
			active_interaction.finished.connect(_on_desk_cleanup_finished)
			add_child(active_interaction)
			Dialogic.paused = true
		_:
			push_warning("InteractionController: unknown interaction '%s'" % interaction_id)


func _on_locker_cleanup_finished(result: Dictionary) -> void:
	last_locker_result = result
	locker_items_kept = result.get("kept", PackedStringArray())
	locker_items_discarded_initially = result.get("discarded_initially", PackedStringArray())
	locker_items_discarded_later = result.get("discarded_later", PackedStringArray())
	locker_items_returned = result.get("returned", PackedStringArray())
	# Write the objective outcome so S05 dialogue can branch on what the player
	# actually did, instead of always assuming an overpacked bag.
	Dialogic.VAR.var_storage["locker_overpacked"] = 1 if result.get("overpacked_once", false) else 0
	_finish_interaction("locker_cleanup", result)


func _on_desk_cleanup_finished(result: Dictionary) -> void:
	last_desk_result = result
	_finish_interaction("desk_cleanup", result)


func _finish_interaction(interaction_id: String, result: Dictionary) -> void:
	var completed_interaction := active_interaction
	active_interaction = null
	if completed_interaction != null and is_instance_valid(completed_interaction):
		completed_interaction.queue_free()
	interaction_finished.emit(interaction_id, result)
	# Signal Event has already finished. Dialogic's next event waits on this
	# resume, so the following Timeline text cannot run underneath the modal UI.
	Dialogic.paused = false
