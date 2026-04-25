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

	_apply_pause_styles()

	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	help_button.pressed.connect(_on_help_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Connect to EventBus
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)

func _apply_pause_styles() -> void:
	var panel: PanelContainer = $PanelContainer
	panel.add_theme_stylebox_override("panel", UITheme.modal_style())

	# Header
	var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
	if UITheme.font_heading:
		title_label.add_theme_font_override("font", UITheme.font_heading)
	title_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)

	# Action buttons
	resume_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	help_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	settings_button.add_theme_stylebox_override("normal", UITheme.action_button_style())

	# Quit button — danger-tinted
	var quit_style := UITheme.action_button_style()
	quit_style.border_color = UITheme.COLOR_DANGER
	quit_button.add_theme_stylebox_override("normal", quit_style)

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
	_play_show_animation()

func resume_game() -> void:
	get_tree().paused = false
	visible = false
	EventBus.game_resumed.emit()

## Scale-in pop animation when pause menu is shown
func _play_show_animation() -> void:
	await get_tree().process_frame  # Ensure layout has run

	var panel: PanelContainer = $PanelContainer
	var panel_size := panel.get_rect().size
	panel.pivot_offset = panel_size / 2.0 if panel_size != Vector2.ZERO else Vector2(125, 150)
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
	EventBus.settings_opened.emit()

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
