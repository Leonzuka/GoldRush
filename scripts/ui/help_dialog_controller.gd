extends Control

## Help dialog showing keyboard shortcuts and game instructions

# ============================================================================
# NODES
# ============================================================================

@onready var close_button_top: Button = $PanelContainer/VBoxContainer/TitleBar/CloseButton
@onready var close_button_bottom: Button = $PanelContainer/VBoxContainer/CloseButtonBottom

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals
	close_button_top.pressed.connect(_on_close_pressed)
	close_button_bottom.pressed.connect(_on_close_pressed)

	# Connect to EventBus
	EventBus.help_opened.connect(_on_help_opened)

	# Hide debug section in release builds
	if not OS.is_debug_build():
		var debug_section = $PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/DebugSection
		if debug_section:
			debug_section.visible = false

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Close on ESC or H
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_help"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_help_opened() -> void:
	# Pause game when help opens
	get_tree().paused = true
	visible = true

func _on_close_pressed() -> void:
	# Resume game when help closes
	get_tree().paused = false
	visible = false
	EventBus.help_closed.emit()
