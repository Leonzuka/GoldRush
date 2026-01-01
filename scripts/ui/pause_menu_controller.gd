extends Control

## Pause menu overlay for mining phase
## Handles pause state and provides access to help/settings

# ============================================================================
# NODES
# ============================================================================

@onready var resume_button: Button = $PanelContainer/VBoxContainer/ResumeButton
@onready var help_button: Button = $PanelContainer/VBoxContainer/HelpButton
@onready var settings_button: Button = $PanelContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $PanelContainer/VBoxContainer/QuitToMenuButton

# ============================================================================
# REFERENCES
# ============================================================================

var help_dialog: Control = null
var settings_menu: Control = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Set process mode to continue running when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	help_button.pressed.connect(_on_help_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Connect to EventBus
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	# Only handle ESC in mining state
	if GameManager.current_state != GameManager.GameState.MINING:
		return

	if event.is_action_pressed("ui_cancel"):  # ESC key
		get_viewport().set_input_as_handled()
		toggle_pause()

# ============================================================================
# PAUSE LOGIC
# ============================================================================

func toggle_pause() -> void:
	if get_tree().paused:
		resume_game()
	else:
		pause_game()

func pause_game() -> void:
	get_tree().paused = true
	visible = true
	EventBus.game_paused.emit()

func resume_game() -> void:
	get_tree().paused = false
	visible = false
	EventBus.game_resumed.emit()

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_resume_pressed() -> void:
	resume_game()

func _on_help_pressed() -> void:
	# Show help dialog (will be instantiated on first access)
	if not help_dialog:
		var help_scene = load("res://scenes/ui/help_dialog.tscn")
		help_dialog = help_scene.instantiate()
		add_child(help_dialog)

	help_dialog.visible = true

func _on_settings_pressed() -> void:
	# Show settings menu
	if not settings_menu:
		var settings_scene = load("res://scenes/ui/settings_menu.tscn")
		settings_menu = settings_scene.instantiate()
		add_child(settings_menu)

	settings_menu.visible = true

func _on_quit_pressed() -> void:
	# Unpause before scene change
	resume_game()
	GameManager.transition_to_state(GameManager.GameState.MAIN_MENU)
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_game_paused() -> void:
	# Additional pause logic if needed
	pass

func _on_game_resumed() -> void:
	# Hide any open dialogs
	if help_dialog:
		help_dialog.visible = false
	if settings_menu:
		settings_menu.visible = false
