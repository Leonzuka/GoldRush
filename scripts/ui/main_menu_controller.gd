extends Control

## Main menu UI controller

# ============================================================================
# NODES
# ============================================================================

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

# ============================================================================
# REFERENCES
# ============================================================================

var settings_menu: Control = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_start_pressed() -> void:
	GameManager.start_new_game()

func _on_settings_pressed() -> void:
	if not settings_menu:
		var settings_scene = load("res://scenes/ui/settings_menu.tscn")
		settings_menu = settings_scene.instantiate()
		add_child(settings_menu)

	settings_menu.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()
