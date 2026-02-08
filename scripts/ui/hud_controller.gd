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

# Money counting animation
var displayed_money: int = 0
var target_money: int = 0
var money_tween: Tween

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
	displayed_money = GameManager.player_money
	target_money = displayed_money
	money_label.text = "Money: $%d" % displayed_money

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
	_animate_money_change(new_amount)

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

# ============================================================================
# MONEY ANIMATION
# ============================================================================

## Animate money counter from current displayed value to new target
func _animate_money_change(new_amount: int) -> void:
	var old_amount := displayed_money
	target_money = new_amount
	var gained := new_amount > old_amount

	# Kill previous tween if still running
	if money_tween and money_tween.is_valid():
		money_tween.kill()
		displayed_money = target_money

	# Duration scales with difference (min 0.3s, max 1.2s)
	var diff := absf(float(new_amount - old_amount))
	var duration := clampf(diff / 500.0, 0.3, 1.2)

	money_tween = create_tween()
	money_tween.tween_method(_update_money_text, float(old_amount), float(new_amount), duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Color flash: green for gain, red for loss
	var flash_color := Color(0.3, 1.0, 0.3) if gained else Color(1.0, 0.3, 0.3)
	var scale_tween := create_tween()
	scale_tween.tween_property(money_label, "modulate", flash_color, 0.1)
	scale_tween.tween_property(money_label, "modulate", Color.WHITE, 0.4)

	# Scale punch effect
	var punch_tween := create_tween()
	punch_tween.tween_property(money_label, "scale", Vector2(1.2, 1.2), 0.1)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	punch_tween.tween_property(money_label, "scale", Vector2.ONE, 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

## Callback for money counting tween - updates label each frame
func _update_money_text(value: float) -> void:
	displayed_money = int(value)
	money_label.text = "Money: $%d" % displayed_money
