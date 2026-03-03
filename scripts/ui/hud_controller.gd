extends Control

## In-game HUD display controller

# ============================================================================
# NODES
# ============================================================================

@onready var round_label: Label = $TopBar/RoundChip/RoundLabel
@onready var time_label: Label = $TopBar/TimeChip/TimeLabel
@onready var money_label: Label = $TopBar/MoneyChip/MoneyLabel
@onready var gold_label: Label = $BottomBar/GoldChip/GoldRow/GoldLabel
@onready var storage_bar: ProgressBar = $BottomBar/StorageBar
@onready var scan_button: Button = $BottomBar/ScanButton
@onready var end_button: Button = $BottomBar/EndButton

# FPS counter (created programmatically)
var fps_label: Label

# Money counting animation
var displayed_money: int = 0
var target_money: int = 0
var money_tween: Tween

# Scanner cooldown (local countdown driven by EventBus signal)
var _scanner_cooldown: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_apply_styles()

	EventBus.session_time_updated.connect(_on_time_updated)
	EventBus.resource_storage_changed.connect(_on_storage_changed)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.scanner_cooldown_changed.connect(_on_scanner_cooldown_changed)
	EventBus.storage_goal_reached.connect(_on_storage_goal_reached)

	end_button.pressed.connect(func(): EventBus.end_mining_requested.emit())

	# Create FPS counter
	_create_fps_counter()

	# Setup tooltips
	_setup_tooltips()

	# Initialize display
	update_round_display()
	update_money_display()

func _apply_styles() -> void:
	# Chip containers
	$TopBar/RoundChip.add_theme_stylebox_override("panel", UITheme.chip_style())
	$TopBar/TimeChip.add_theme_stylebox_override("panel", UITheme.chip_style())
	$TopBar/MoneyChip.add_theme_stylebox_override("panel", UITheme.chip_style())
	$BottomBar/GoldChip.add_theme_stylebox_override("panel", UITheme.chip_style())

	# Scan button
	scan_button.add_theme_stylebox_override("normal", UITheme.action_button_style())

	# End Early button
	end_button.add_theme_stylebox_override("normal", UITheme.action_button_style())

	# Bold font on time label
	if UITheme.font_body_bold:
		time_label.add_theme_font_override("font", UITheme.font_body_bold)
		money_label.add_theme_font_override("font", UITheme.font_body_bold)

## Setup tooltips for UI elements
func _setup_tooltips() -> void:
	scan_button.tooltip_text = "Detect nearby gold (Press E)\nCooldown: 3 seconds"
	storage_bar.tooltip_text = "Gold collected this round\nFill to %d for a $%d bonus!" % [Config.STORAGE_CAPACITY, Config.STORAGE_GOAL_BONUS]
	end_button.tooltip_text = "End mining early and go to results"

## Create FPS counter label programmatically
func _create_fps_counter() -> void:
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -90
	fps_label.offset_top = 10
	fps_label.offset_right = -10
	fps_label.offset_bottom = 30
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(fps_label)

# ============================================================================
# UPDATES
# ============================================================================

func update_round_display() -> void:
	round_label.text = "Round: %d" % GameManager.round_number

func update_money_display() -> void:
	displayed_money = GameManager.player_money
	target_money = displayed_money
	money_label.text = "$ %d" % displayed_money

func _on_time_updated(time_remaining: float) -> void:
	var total_seconds: int = int(time_remaining)
	var minutes: int = int(total_seconds / 60.0)
	var seconds: int = total_seconds % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]

func _on_storage_changed(current: int, max_capacity: int) -> void:
	if current >= max_capacity:
		gold_label.text = "%d ★" % current
		storage_bar.value = max_capacity
	else:
		gold_label.text = "%d/%d" % [current, max_capacity]
		storage_bar.max_value = max_capacity
		storage_bar.value = current

func _on_storage_goal_reached() -> void:
	# Flash gold label gold color to celebrate the bonus
	var flash := create_tween()
	flash.tween_property(gold_label, "modulate", UITheme.COLOR_GOLD_BRIGHT, 0.1)
	flash.tween_property(gold_label, "modulate", Color.WHITE, 0.5)

	# Scale punch
	var punch := create_tween()
	punch.tween_property(gold_label, "scale", Vector2(1.3, 1.3), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(gold_label, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_money_changed(new_amount: int) -> void:
	_animate_money_change(new_amount)

# ============================================================================
# SCANNER BUTTON
# ============================================================================

func _process(delta: float) -> void:
	# Update FPS counter
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# Decrement local scanner cooldown countdown
	if _scanner_cooldown > 0.0:
		_scanner_cooldown = maxf(_scanner_cooldown - delta, 0.0)
		if _scanner_cooldown > 0.0:
			scan_button.text = "SCAN (%.1fs)" % _scanner_cooldown
		else:
			scan_button.text = "SCAN [E]"
			scan_button.disabled = false

# ============================================================================
# SCANNER COOLDOWN
# ============================================================================

func _on_scanner_cooldown_changed(remaining: float) -> void:
	_scanner_cooldown = remaining
	if remaining > 0.0:
		scan_button.disabled = true
		scan_button.text = "SCAN (%.1fs)" % remaining
	else:
		scan_button.disabled = false
		scan_button.text = "SCAN [E]"

# ============================================================================
# MONEY ANIMATION  — DO NOT MODIFY
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
	money_tween.tween_method(_update_money_text, float(old_amount), float(new_amount), duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Color flash: green for gain, red for loss
	var flash_color := Color(0.3, 1.0, 0.3) if gained else Color(1.0, 0.3, 0.3)
	var scale_tween := create_tween()
	scale_tween.tween_property(money_label, "modulate", flash_color, 0.1)
	scale_tween.tween_property(money_label, "modulate", Color.WHITE, 0.4)

	# Scale punch effect
	var punch_tween := create_tween()
	punch_tween.tween_property(money_label, "scale", Vector2(1.2, 1.2), 0.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	punch_tween.tween_property(money_label, "scale", Vector2.ONE, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

## Callback for money counting tween — updates label each frame
func _update_money_text(value: float) -> void:
	displayed_money = int(value)
	money_label.text = "$ %d" % displayed_money
