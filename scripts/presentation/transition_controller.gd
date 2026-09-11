extends Control

## Small presentation boundary for timeline-level transitions. It deliberately
## has only the effects the project currently needs; scene ownership remains in
## SceneController and photo ownership remains in PhotoViewer.

@onready var veil: ColorRect = $Veil

var _playing := false
var _active_tween: Tween = null


func _ready() -> void:
	veil.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or _active_tween == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
			# Finish the currently running non-interactive presentation beat on the
			# next frame; dialogue input remains unaffected outside transitions.
			_active_tween.set_speed_scale(1000.0)
			get_viewport().set_input_as_handled()


func play(effect: String) -> void:
	if _playing:
		push_warning("TransitionController: ignored overlapping effect '%s'." % effect)
		return
	_play(effect)


func _play(effect: String) -> void:
	_playing = true
	var was_paused := Dialogic != null and Dialogic.paused
	if Dialogic != null and not was_paused:
		Dialogic.paused = true

	match effect:
		"fade_out":
			await _fade_to(Color.BLACK, 0.35)
		"fade_in":
			await _fade_from(Color.BLACK, 0.35)
		"flash_white":
			await _flash(Color.WHITE)
		_:
			push_warning("TransitionController: unknown effect '%s'." % effect)

	if Dialogic != null and not was_paused:
		Dialogic.paused = false
	_playing = false


func _fade_to(target: Color, duration: float) -> void:
	veil.color = Color(target, 0.0)
	veil.show()
	_active_tween = create_tween()
	_active_tween.tween_property(veil, "color:a", 1.0, duration)
	await _active_tween.finished
	_active_tween = null


func _fade_from(source: Color, duration: float) -> void:
	veil.color = Color(source, 1.0)
	veil.show()
	_active_tween = create_tween()
	_active_tween.tween_property(veil, "color:a", 0.0, duration)
	await _active_tween.finished
	_active_tween = null
	veil.hide()


func _flash(flash_color: Color) -> void:
	veil.color = Color(flash_color, 0.0)
	veil.show()
	_active_tween = create_tween()
	_active_tween.tween_property(veil, "color:a", 0.9, 0.06)
	_active_tween.tween_property(veil, "color:a", 0.0, 0.20)
	await _active_tween.finished
	_active_tween = null
	veil.hide()
