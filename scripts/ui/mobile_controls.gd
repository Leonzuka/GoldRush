extends CanvasLayer

## Mobile touch overlay — visible only on touch devices
##
## Provides on-screen buttons for movement, jump, scan and pause.
## Drilling is performed by tapping the terrain (mouse-from-touch emulation).

const FORCE_SHOW_DEBUG: bool = false  # Flip to true to preview the overlay on desktop

@onready var pause_button: Button = $TopBar/PauseButton
@onready var scan_button: Button = $TopBar/ScanButton
@onready var left_button: Button = $MoveCluster/LeftButton
@onready var right_button: Button = $MoveCluster/RightButton
@onready var jump_button: Button = $ActionCluster/JumpButton

func _ready() -> void:
	visible = _should_show()
	if not visible:
		return

	_apply_styles()
	pause_button.pressed.connect(_on_pause_pressed)

	# Hide overlay during pause / round-end / settings — the game is no longer mining
	EventBus.game_paused.connect(_set_overlay_visible.bind(false))
	EventBus.game_resumed.connect(_set_overlay_visible.bind(true))
	EventBus.round_ended.connect(func(_stats): _set_overlay_visible(false))

func _should_show() -> bool:
	if FORCE_SHOW_DEBUG:
		return true
	return OS.has_feature("mobile")

func _set_overlay_visible(value: bool) -> void:
	if not _should_show():
		visible = false
		return
	visible = value

func _apply_styles() -> void:
	for btn in [pause_button, scan_button, left_button, right_button, jump_button]:
		btn.add_theme_stylebox_override("normal", UITheme.action_button_style())
		btn.modulate.a = 0.85

func _on_pause_pressed() -> void:
	var pause_menu: Control = get_tree().root.find_child("PauseMenu", true, false)
	if pause_menu and pause_menu.has_method("toggle_pause"):
		pause_menu.toggle_pause()
