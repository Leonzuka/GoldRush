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

const ShopDialogScript = preload("res://scripts/ui/shop_dialog_controller.gd")
const UpgradesStripScript = preload("res://scripts/ui/upgrades_strip.gd")

# Shop button + upgrades strip (created programmatically)
var shop_button: Button
var upgrades_strip: UpgradesStrip

# FPS counter (created programmatically)
var fps_label: Label

# Speed control (created programmatically)
var speed_button: Button
var _is_fast_speed: bool = false

# Mining session active flag — End Early only shows during an active session
var _mining_active: bool = false
var _last_storage_pct: float = 0.0
var _last_time_pct: float = 1.0  # 1.0 = full time remaining
const _END_EARLY_STORAGE_THRESHOLD: float = 0.85
const _END_EARLY_TIME_THRESHOLD: float = 0.20

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
	EventBus.mining_started.connect(_on_mining_started)
	EventBus.round_ended.connect(_on_round_ended)
	EventBus.game_paused.connect(_on_game_paused)

	end_button.pressed.connect(func(): EventBus.end_mining_requested.emit())
	# End Early starts hidden — surfaces only when storage is near full or time is running out
	end_button.visible = false

	# Create FPS counter
	_create_fps_counter()

	# Create speed toggle (1x / 2x)
	_create_speed_button()

	# Create shop button + upgrades strip
	_create_shop_button()
	_create_upgrades_strip()

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
	scan_button.tooltip_text = tr("SCAN_TOOLTIP")
	storage_bar.tooltip_text = tr("GOLD_TOOLTIP") % [Config.STORAGE_CAPACITY, Config.STORAGE_GOAL_BONUS]
	end_button.tooltip_text  = tr("END_EARLY_TOOLTIP")

## Create speed toggle button (1x / 2x). Inserted into BottomBar before EndButton.
func _create_speed_button() -> void:
	speed_button = Button.new()
	speed_button.name = "SpeedButton"
	speed_button.text = "1x"
	speed_button.tooltip_text = tr("SPEED_TOOLTIP") if tr("SPEED_TOOLTIP") != "SPEED_TOOLTIP" else "Toggle game speed"
	speed_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	speed_button.custom_minimum_size = Vector2(56, 0)
	speed_button.focus_mode = Control.FOCUS_NONE
	speed_button.pressed.connect(_on_speed_toggled)
	# Insert before EndButton so the layout reads: [Gold | StorageBar | Scan | Speed | End]
	$BottomBar.add_child(speed_button)
	$BottomBar.move_child(speed_button, end_button.get_index())

## Create shop button. Inserted into BottomBar before SpeedButton.
func _create_shop_button() -> void:
	shop_button = Button.new()
	shop_button.name = "ShopButton"
	shop_button.text = tr("SHOP")
	shop_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	shop_button.custom_minimum_size = Vector2(90, 40)
	shop_button.focus_mode = Control.FOCUS_NONE
	shop_button.pressed.connect(_on_shop_pressed)
	$BottomBar.add_child(shop_button)
	# Place shop button right after StorageBar, before ScanButton
	$BottomBar.move_child(shop_button, scan_button.get_index())

## Create upgrades strip in TopBar (right side, after MoneyChip)
func _create_upgrades_strip() -> void:
	upgrades_strip = UpgradesStripScript.new()
	upgrades_strip.name = "UpgradesStrip"
	$TopBar.add_child(upgrades_strip)

func _on_shop_pressed() -> void:
	if get_tree().paused:
		return
	var dlg: ShopDialogController = ShopDialogScript.new()
	dlg.context = "mining"
	add_child(dlg)
	get_tree().paused = true
	$TopBar/MoneyChip.visible = false
	dlg.closed.connect(_on_shop_closed)

func _on_shop_closed() -> void:
	get_tree().paused = false
	$TopBar/MoneyChip.visible = true
	update_money_display()

func _on_speed_toggled() -> void:
	# Pausing should override speed; ignore presses while paused
	if get_tree().paused:
		return
	_is_fast_speed = not _is_fast_speed
	Engine.time_scale = 2.0 if _is_fast_speed else 1.0
	speed_button.text = "2x" if _is_fast_speed else "1x"

## Reset to normal speed without flipping the toggle state visually mid-pause.
func _reset_time_scale() -> void:
	_is_fast_speed = false
	Engine.time_scale = 1.0
	if speed_button:
		speed_button.text = "1x"

func _on_mining_started(_plot) -> void:
	_mining_active = true
	_last_storage_pct = 0.0
	_last_time_pct = 1.0
	end_button.visible = false
	_reset_time_scale()

func _on_round_ended(_stats) -> void:
	_mining_active = false
	end_button.visible = false
	_reset_time_scale()

func _on_game_paused() -> void:
	# Don't keep accelerated time bleeding into the pause overlay's tweens
	_reset_time_scale()

## Always reset time scale when the HUD leaves the tree — prevents leakage
## of 2x speed into the auction or main menu scenes.
func _exit_tree() -> void:
	Engine.time_scale = 1.0

## Recompute End Early visibility based on session state + storage/time thresholds.
func _refresh_end_early_visibility() -> void:
	if not _mining_active:
		end_button.visible = false
		return
	var storage_close: bool = _last_storage_pct >= _END_EARLY_STORAGE_THRESHOLD
	var time_low: bool = _last_time_pct <= _END_EARLY_TIME_THRESHOLD
	end_button.visible = storage_close or time_low

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
	round_label.text = tr("ROUND_LABEL") % GameManager.round_number

func update_money_display() -> void:
	displayed_money = GameManager.player_money
	target_money = displayed_money
	money_label.text = "$ %d" % displayed_money

func _on_time_updated(time_remaining: float) -> void:
	var total_seconds: int = int(time_remaining)
	var minutes: int = int(total_seconds / 60.0)
	var seconds: int = total_seconds % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]

	var time_limit: float = Config.get_round_time_limit(GameManager.round_number)
	_last_time_pct = clampf(time_remaining / max(time_limit, 0.1), 0.0, 1.0)
	_refresh_end_early_visibility()

func _on_storage_changed(current: int, max_capacity: int) -> void:
	if current >= max_capacity:
		gold_label.text = "%d ★" % current
		storage_bar.value = max_capacity
	else:
		gold_label.text = "%d/%d" % [current, max_capacity]
		storage_bar.max_value = max_capacity
		storage_bar.value = current

	_last_storage_pct = float(current) / max(float(max_capacity), 1.0)
	_refresh_end_early_visibility()

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
			scan_button.text = tr("SCAN_COOLDOWN") % _scanner_cooldown
		else:
			scan_button.text = tr("SCAN_READY")
			scan_button.disabled = false

# ============================================================================
# SCANNER COOLDOWN
# ============================================================================

func _on_scanner_cooldown_changed(remaining: float) -> void:
	_scanner_cooldown = remaining
	if remaining > 0.0:
		scan_button.disabled = true
		scan_button.text = tr("SCAN_COOLDOWN") % remaining
	else:
		scan_button.disabled = false
		scan_button.text = tr("SCAN_READY")

# ============================================================================
# TRANSLATION
# ============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not round_label:
			return
		update_round_display()
		_setup_tooltips()
		if _scanner_cooldown <= 0.0:
			scan_button.text = tr("SCAN_READY")

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
