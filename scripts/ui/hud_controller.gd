extends Control

## In-game HUD display controller

# ============================================================================
# NODES
# ============================================================================

@onready var round_label: Label = $TopBar/RoundLabel
@onready var time_label: Label = $TopBar/TimeLabel
@onready var money_label: Label = $TopBar/MoneyLabel
@onready var gold_label: Label = $BottomBar/GoldLabel
@onready var storage_bar: ProgressBar = $BottomBar/StorageBar
@onready var scan_button: Button = $BottomBar/ScanButton

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	EventBus.session_time_updated.connect(_on_time_updated)
	EventBus.resource_storage_changed.connect(_on_storage_changed)
	EventBus.money_changed.connect(_on_money_changed)

	# Initialize display
	update_round_display()
	update_money_display()

# ============================================================================
# UPDATES
# ============================================================================

func update_round_display() -> void:
	round_label.text = "Round: %d" % GameManager.round_number

func update_money_display() -> void:
	money_label.text = "Money: $%d" % GameManager.player_money

func _on_time_updated(time_remaining: float) -> void:
	var minutes: int = int(time_remaining) / 60
	var seconds: int = int(time_remaining) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]

func _on_storage_changed(current: int, max_capacity: int) -> void:
	gold_label.text = "Gold: %d/%d" % [current, max_capacity]
	storage_bar.max_value = max_capacity
	storage_bar.value = current

func _on_money_changed(new_amount: int) -> void:
	money_label.text = "Money: $%d" % new_amount

# ============================================================================
# SCANNER BUTTON
# ============================================================================

func _process(_delta: float) -> void:
	# Update scan button cooldown display
	var scanner: Node = get_tree().get_first_node_in_group("scanner")
	if scanner and scanner.has_method("get_cooldown_remaining"):
		var cooldown: float = scanner.get_cooldown_remaining()
		if cooldown > 0:
			scan_button.text = "SCAN (%.1fs)" % cooldown
			scan_button.disabled = true
		else:
			scan_button.text = "SCAN [SPACE]"
			scan_button.disabled = false
