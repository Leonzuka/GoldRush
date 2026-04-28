class_name MobileActionButton
extends Button

## Themed button that injects an InputEventAction while held
##
## Used on the mobile touch overlay so on-screen buttons behave exactly like
## keyboard/gamepad input — the rest of the game keeps reading actions.

@export var action_name: String = ""

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	button_down.connect(_emit.bind(true))
	button_up.connect(_emit.bind(false))
	# Releasing outside the button (finger drag-off) still fires button_up.
	tree_exiting.connect(func(): _emit(false))

func _emit(pressed: bool) -> void:
	if action_name.is_empty():
		return
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = pressed
	Input.parse_input_event(event)
