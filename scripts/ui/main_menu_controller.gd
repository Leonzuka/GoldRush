extends Control

## Main menu UI controller

# ============================================================================
# NODES
# ============================================================================

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_start_pressed() -> void:
	GameManager.start_new_game()

func _on_quit_pressed() -> void:
	get_tree().quit()
