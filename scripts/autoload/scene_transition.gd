extends CanvasLayer

## Screen transition system with fade and slide effects.
##
## Registered as autoload "SceneTransition" before GameManager.
## All methods are coroutines — use `await SceneTransition.transition_out()`.
##
## Usage pattern:
##   await SceneTransition.transition_out()
##   get_tree().change_scene_to_file(path)
##   await get_tree().process_frame
##   SceneTransition.transition_in()  # fire-and-forget or await

# ============================================================================
# ENUMS
# ============================================================================

enum Type {
	FADE,
	SLIDE_LEFT,
	SLIDE_RIGHT,
	SLIDE_UP,
	SLIDE_DOWN,
}

# ============================================================================
# STATE
# ============================================================================

var _overlay: ColorRect
var _is_transitioning: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	layer = 100  # Render on top of everything

	_overlay = ColorRect.new()
	_overlay.name = "TransitionOverlay"
	_overlay.color = Color.BLACK
	_overlay.color.a = 0.0
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

# ============================================================================
# PUBLIC API
# ============================================================================

## Animate the screen out (cover with overlay).
## Call this BEFORE changing scenes.
##
## @param type: Transition style (FADE, SLIDE_LEFT, etc.)
## @param duration: Animation duration in seconds
func transition_out(type: Type = Type.FADE, duration: float = 0.35) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input

	match type:
		Type.FADE:
			await _fade_to_black(duration)

		Type.SLIDE_LEFT:
			await _slide_in_from(Vector2(_get_viewport_size().x, 0.0), duration)

		Type.SLIDE_RIGHT:
			await _slide_in_from(Vector2(-_get_viewport_size().x, 0.0), duration)

		Type.SLIDE_UP:
			await _slide_in_from(Vector2(0.0, _get_viewport_size().y), duration)

		Type.SLIDE_DOWN:
			await _slide_in_from(Vector2(0.0, -_get_viewport_size().y), duration)


## Animate the screen back in (reveal new scene).
## Call this AFTER the new scene has loaded.
##
## @param type: Must match the type used in transition_out
## @param duration: Animation duration in seconds
func transition_in(type: Type = Type.FADE, duration: float = 0.35) -> void:
	match type:
		Type.FADE:
			await _fade_from_black(duration)

		Type.SLIDE_LEFT:
			await _slide_out_to(Vector2(-_get_viewport_size().x, 0.0), duration)

		Type.SLIDE_RIGHT:
			await _slide_out_to(Vector2(_get_viewport_size().x, 0.0), duration)

		Type.SLIDE_UP:
			await _slide_out_to(Vector2(0.0, -_get_viewport_size().y), duration)

		Type.SLIDE_DOWN:
			await _slide_out_to(Vector2(0.0, _get_viewport_size().y), duration)

	_overlay.position = Vector2.ZERO
	_overlay.color.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false

# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _get_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _fade_to_black(duration: float) -> void:
	_overlay.position = Vector2.ZERO
	_overlay.color.a = 0.0
	var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_overlay, "color:a", 1.0, duration)
	await tween.finished


func _fade_from_black(duration: float) -> void:
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_overlay, "color:a", 0.0, duration)
	await tween.finished


func _slide_in_from(start_pos: Vector2, duration: float) -> void:
	_overlay.color.a = 1.0
	_overlay.position = start_pos
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_overlay, "position", Vector2.ZERO, duration)
	await tween.finished


func _slide_out_to(end_pos: Vector2, duration: float) -> void:
	_overlay.position = Vector2.ZERO
	_overlay.color.a = 1.0
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_overlay, "position", end_pos, duration)
	await tween.finished
