extends Control

## Main menu UI controller with "Golden Age Prospector" styling

# ============================================================================
# NODES
# ============================================================================

@onready var content_panel: PanelContainer = $CenterContainer/ContentPanel
@onready var title_label: Label = $CenterContainer/ContentPanel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/ContentPanel/VBoxContainer/SubtitleLabel
@onready var continue_button: Button = $CenterContainer/ContentPanel/VBoxContainer/ContinueButton
@onready var start_button: Button = $CenterContainer/ContentPanel/VBoxContainer/StartButton
@onready var settings_button: Button = $CenterContainer/ContentPanel/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/ContentPanel/VBoxContainer/QuitButton
@onready var version_label: Label = $VersionLabel

@onready var debug_panel: PanelContainer = $DebugPanel
@onready var mine_normal_button: Button = $DebugPanel/VBox/MineNormalButton
@onready var mine_rich_button: Button = $DebugPanel/VBox/MineRichButton
@onready var mine_poor_button: Button = $DebugPanel/VBox/MinePoorButton
@onready var add_money_button: Button = $DebugPanel/VBox/AddMoneyButton
@onready var debug_header: Label = $DebugPanel/VBox/DebugHeader

# ============================================================================
# REFERENCES
# ============================================================================

var settings_menu: Control = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_apply_styles()

	var has_save: bool = GameManager.has_save()
	continue_button.visible = has_save
	continue_button.pressed.connect(_on_continue_pressed)
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	if OS.is_debug_build():
		_setup_debug_panel()

	_play_entry_animation()

func _setup_debug_panel() -> void:
	debug_panel.visible = true
	mine_normal_button.pressed.connect(func(): GameManager.debug_start_mining(1.0))
	mine_rich_button.pressed.connect(func(): GameManager.debug_start_mining(1.5))
	mine_poor_button.pressed.connect(func(): GameManager.debug_start_mining(0.5))
	add_money_button.pressed.connect(_on_debug_add_money)

	# Style the debug panel distinctly
	var debug_style := StyleBoxFlat.new()
	debug_style.bg_color = Color(0.05, 0.05, 0.15, 0.85)
	debug_style.border_width_left = 2
	debug_style.border_width_right = 2
	debug_style.border_width_top = 2
	debug_style.border_width_bottom = 2
	debug_style.border_color = Color(0.3, 0.3, 1.0, 0.8)
	debug_style.corner_radius_top_left = 6
	debug_style.corner_radius_top_right = 6
	debug_style.corner_radius_bottom_left = 6
	debug_style.corner_radius_bottom_right = 6
	debug_style.content_margin_left = 8
	debug_style.content_margin_right = 8
	debug_style.content_margin_top = 8
	debug_style.content_margin_bottom = 8
	debug_panel.add_theme_stylebox_override("panel", debug_style)

	debug_header.add_theme_color_override("font_color", Color(0.5, 0.5, 1.0))

	for btn: Button in [mine_normal_button, mine_rich_button, mine_poor_button]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.1, 0.15, 0.35)
		s.border_width_left = 1; s.border_width_right = 1
		s.border_width_top = 1; s.border_width_bottom = 1
		s.border_color = Color(0.3, 0.4, 0.8)
		s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
		s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
		s.content_margin_left = 8; s.content_margin_right = 8
		s.content_margin_top = 4; s.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", s)

	var money_style := StyleBoxFlat.new()
	money_style.bg_color = Color(0.1, 0.25, 0.1)
	money_style.border_width_left = 1; money_style.border_width_right = 1
	money_style.border_width_top = 1; money_style.border_width_bottom = 1
	money_style.border_color = Color(0.2, 0.6, 0.2)
	money_style.corner_radius_top_left = 4; money_style.corner_radius_top_right = 4
	money_style.corner_radius_bottom_left = 4; money_style.corner_radius_bottom_right = 4
	money_style.content_margin_left = 8; money_style.content_margin_right = 8
	money_style.content_margin_top = 4; money_style.content_margin_bottom = 4
	add_money_button.add_theme_stylebox_override("normal", money_style)
	add_money_button.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))

func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			debug_panel.visible = !debug_panel.visible

func _apply_styles() -> void:
	content_panel.add_theme_stylebox_override("panel", UITheme.modal_style())

	# Title font
	if UITheme.font_display:
		title_label.add_theme_font_override("font", UITheme.font_display)
	title_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)

	# Subtitle font
	if UITheme.font_heading:
		subtitle_label.add_theme_font_override("font", UITheme.font_heading)
	subtitle_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

	# Version label
	version_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)

	# Continue button — gold-tinted to highlight it as the primary action
	var continue_style := UITheme.action_button_style()
	continue_style.border_color = UITheme.COLOR_GOLD_BRIGHT
	continue_button.add_theme_stylebox_override("normal", continue_style)
	continue_button.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)

	# Standard action buttons
	start_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	settings_button.add_theme_stylebox_override("normal", UITheme.action_button_style())

	# Quit button — danger-tinted border
	var quit_style := UITheme.action_button_style()
	quit_style.border_color = UITheme.COLOR_DANGER
	quit_button.add_theme_stylebox_override("normal", quit_style)

func _on_debug_add_money() -> void:
	GameManager.player_money += 5000
	print("[Debug] Added $5000 — total: $%d" % GameManager.player_money)
	add_money_button.text = "+ $5000  ✓"
	await get_tree().create_timer(1.0).timeout
	add_money_button.text = "+ $5000"

func _play_entry_animation() -> void:
	var buttons: Array[Button] = []
	if continue_button.visible:
		buttons.append(continue_button)
	buttons.append_array([start_button, settings_button, quit_button])

	# Hide all buttons initially
	for btn in buttons:
		btn.modulate.a = 0.0

	# Wait one frame for VBoxContainer to finish initial layout
	await get_tree().process_frame

	# Apply downward offset after layout is done
	for btn in buttons:
		btn.position.y += 24.0

	# Animate each button in with staggered delay
	for i in buttons.size():
		var btn: Button = buttons[i]
		var target_y: float = btn.position.y - 24.0
		var delay: float = 0.10 + i * 0.10

		var alpha_tween := create_tween()
		alpha_tween.tween_interval(delay)
		alpha_tween.tween_property(btn, "modulate:a", 1.0, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		var pos_tween := create_tween()
		pos_tween.tween_interval(delay)
		pos_tween.tween_property(btn, "position:y", target_y, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_continue_pressed() -> void:
	GameManager.continue_game()

func _on_start_pressed() -> void:
	GameManager.start_new_game()

func _on_settings_pressed() -> void:
	if not settings_menu:
		var settings_scene = load("res://scenes/ui/settings_menu.tscn")
		settings_menu = settings_scene.instantiate()
		add_child(settings_menu)

	settings_menu.visible = true
	EventBus.settings_opened.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
