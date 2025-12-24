extends Control

## Round end summary screen controller

# ============================================================================
# NODES
# ============================================================================

@onready var summary_label: Label = $PanelContainer/VBoxContainer/SummaryLabel
@onready var gold_label: Label = $PanelContainer/VBoxContainer/GoldLabel
@onready var time_label: Label = $PanelContainer/VBoxContainer/TimeLabel
@onready var continue_button: Button = $PanelContainer/VBoxContainer/ContinueButton

# ============================================================================
# DATA
# ============================================================================

var session_stats: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	EventBus.round_ended.connect(_on_round_ended)
	continue_button.pressed.connect(_on_continue_pressed)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_round_ended(stats: Dictionary) -> void:
	session_stats = stats

	summary_label.text = "Round %d Complete!" % GameManager.round_number
	gold_label.text = "Gold Collected: %d" % stats.gold_collected
	time_label.text = "Time Used: %.1fs" % stats.time_used

	visible = true

func _on_continue_pressed() -> void:
	visible = false
	# GameManager will handle transition back to auction
