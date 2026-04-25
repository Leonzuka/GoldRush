extends Control

## Main menu UI controller with "Golden Age Prospector" styling

# ============================================================================
# NODES
# ============================================================================

@onready var content_panel: PanelContainer = $CenterContainer/ContentPanel
@onready var title_label: Label = $CenterContainer/ContentPanel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/ContentPanel/VBoxContainer/SubtitleLabel
@onready var start_button: Button = $CenterContainer/ContentPanel/VBoxContainer/StartButton
@onready var settings_button: Button = $CenterContainer/ContentPanel/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/ContentPanel/VBoxContainer/QuitButton
@onready var version_label: Label = $VersionLabel

# ============================================================================
# REFERENCES
# ============================================================================

var settings_menu: Control = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_apply_styles()

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	_play_entry_animation()

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

	# Standard action buttons
	start_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	settings_button.add_theme_stylebox_override("normal", UITheme.action_button_style())

	# Quit button — danger-tinted border
	var quit_style := UITheme.action_button_style()
	quit_style.border_color = UITheme.COLOR_DANGER
	quit_button.add_theme_stylebox_override("normal", quit_style)

func _play_entry_animation() -> void:
	var buttons: Array[Button] = [start_button, settings_button, quit_button]
	var delays := [0.15, 0.25, 0.35]

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

		var alpha_tween := create_tween()
		alpha_tween.tween_interval(delays[i])
		alpha_tween.tween_property(btn, "modulate:a", 1.0, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		var pos_tween := create_tween()
		pos_tween.tween_interval(delays[i])
		pos_tween.tween_property(btn, "position:y", target_y, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
	EventBus.settings_opened.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
