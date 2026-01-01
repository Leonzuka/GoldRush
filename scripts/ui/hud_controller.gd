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

# FPS counter (created programmatically)
var fps_label: Label

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	EventBus.session_time_updated.connect(_on_time_updated)
	EventBus.resource_storage_changed.connect(_on_storage_changed)
	EventBus.money_changed.connect(_on_money_changed)

	# Create FPS counter
	_create_fps_counter()

	# Setup tooltips
	_setup_tooltips()

	# Initialize display
	update_round_display()
	update_money_display()

## Setup tooltips for UI elements
func _setup_tooltips() -> void:
	scan_button.tooltip_text = "Detectar ouro próximo (Pressione SPACE)\nCooldown: 3 segundos"
	storage_bar.tooltip_text = "Capacidade de armazenamento de ouro\nRetorne ao caminhão quando estiver cheio"

## Create FPS counter label programmatically
func _create_fps_counter() -> void:
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.position = Vector2(10, 10)
	fps_label.add_theme_font_size_override("font_size", 14)
	add_child(fps_label)

# ============================================================================
# UPDATES
# ============================================================================

func update_round_display() -> void:
	round_label.text = "Round: %d" % GameManager.round_number

func update_money_display() -> void:
	money_label.text = "Money: $%d" % GameManager.player_money

func _on_time_updated(time_remaining: float) -> void:
	var total_seconds: int = int(time_remaining)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
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
	# Update FPS counter
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

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
