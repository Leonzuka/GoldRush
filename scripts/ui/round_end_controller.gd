extends Control

## Round end summary panel with animated stats reveal

# ============================================================================
# NODES
# ============================================================================

@onready var results_panel: PanelContainer = $CenterContainer/ResultsPanel
@onready var header_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/HeaderLabel
@onready var gold_value_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/StatsContainer/GoldRow/GoldValueLabel
@onready var storage_value_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/StatsContainer/StorageRow/StorageValueLabel
@onready var time_value_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/StatsContainer/TimeRow/TimeValueLabel
@onready var reason_value_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/StatsContainer/ReasonRow/ReasonValueLabel
@onready var grade_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/GradeContainer/GradeInfoVBox/GradeLabel
@onready var grade_desc_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/GradeContainer/GradeInfoVBox/GradeDescLabel
@onready var grade_value_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/GradeContainer/GradeValueLabel
@onready var continue_button: Button = $CenterContainer/ResultsPanel/VBoxContainer/ContinueButton

# ============================================================================
# STATE
# ============================================================================

var session_stats: Dictionary = {}
var _pulse_tween: Tween = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	EventBus.round_ended.connect(_on_round_ended)
	continue_button.pressed.connect(_on_continue_pressed)
	_apply_styles()

func _apply_styles() -> void:
	results_panel.add_theme_stylebox_override("panel", UITheme.modal_style())

	if UITheme.font_display:
		header_label.add_theme_font_override("font", UITheme.font_display)
		grade_value_label.add_theme_font_override("font", UITheme.font_display)
	header_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)

	grade_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	grade_desc_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	gold_value_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	time_value_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)
	storage_value_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)

	continue_button.add_theme_stylebox_override("normal", UITheme.action_button_style())

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_round_ended(stats: Dictionary) -> void:
	session_stats = stats

	var goal_reached: bool = stats.gold_collected >= Config.STORAGE_CAPACITY

	header_label.text = "ROUND %d COMPLETE" % GameManager.round_number
	time_value_label.text = "%.1fs / %.0fs" % [stats.time_used, Config.ROUND_TIME_LIMIT]
	storage_value_label.text = "Goal Reached! +$%d" % Config.STORAGE_GOAL_BONUS if goal_reached else "Not reached"
	storage_value_label.add_theme_color_override("font_color",
		UITheme.COLOR_GOLD_BRIGHT if goal_reached else UITheme.COLOR_TEXT_MUTED)
	gold_value_label.text = "0"

	# Set reason label
	match stats.get("reason", ""):
		"Player ended":
			reason_value_label.text = "Ended Early"
			reason_value_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
		_:
			reason_value_label.text = "Time's Up"
			reason_value_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))

	# Reset animated elements
	grade_value_label.modulate.a = 0.0
	grade_value_label.scale = Vector2(0.2, 0.2)
	grade_label.modulate.a = 0.0
	grade_desc_label.modulate.a = 0.0
	continue_button.modulate.a = 0.0
	results_panel.modulate.a = 0.0

	visible = true

	# Wait for layout
	await get_tree().process_frame

	# Entry: slide up + fade in
	results_panel.position.y += 50.0
	var entry_tween := create_tween().set_parallel(true)
	entry_tween.tween_property(results_panel, "modulate:a", 1.0, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entry_tween.tween_property(results_panel, "position:y", results_panel.position.y - 50.0, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Gold counter: starts after 0.5s
	await get_tree().create_timer(0.5).timeout
	_animate_gold_counter(stats.gold_collected)

	# Grade reveal: after gold counter (1.0s) + 0.6s buffer
	await get_tree().create_timer(1.6).timeout
	_reveal_grade(stats)

	# Continue button: after grade pop animation + 1.5s delay
	await get_tree().create_timer(1.5).timeout
	var btn_tween := create_tween()
	btn_tween.tween_property(continue_button, "modulate:a", 1.0, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await btn_tween.finished

	# Pulsing scale animation on button to draw attention
	_start_button_pulse()

func _animate_gold_counter(final_gold: int) -> void:
	var gold_tween := create_tween()
	gold_tween.tween_method(_update_gold_text, 0.0, float(final_gold), 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _update_gold_text(value: float) -> void:
	gold_value_label.text = "%d" % int(value)

func _reveal_grade(stats: Dictionary) -> void:
	# Normalize efficiency as percentage of storage filled
	var efficiency: float = float(stats.gold_collected) / float(Config.STORAGE_CAPACITY)
	var grade := _get_grade(efficiency)
	var grade_color := _get_grade_color(grade)
	var grade_desc := _get_grade_desc(grade)

	grade_value_label.text = grade
	grade_value_label.add_theme_color_override("font_color", grade_color)
	grade_desc_label.text = grade_desc

	var grade_tween := create_tween().set_parallel(true)
	grade_tween.tween_property(grade_value_label, "modulate:a", 1.0, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grade_tween.tween_property(grade_value_label, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var label_tween := create_tween().set_parallel(true)
	label_tween.tween_property(grade_label, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	label_tween.tween_property(grade_desc_label, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _start_button_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(continue_button, "modulate:a", 0.65, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(continue_button, "modulate:a", 1.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _get_grade(efficiency: float) -> String:
	if efficiency >= 0.8: return "S"
	elif efficiency >= 0.6: return "A"
	elif efficiency >= 0.4: return "B"
	elif efficiency >= 0.2: return "C"
	else: return "D"

func _get_grade_color(grade: String) -> Color:
	match grade:
		"S": return UITheme.COLOR_GOLD_BRIGHT
		"A": return Color(0.4, 1.0, 0.5)
		"B": return Color(0.4, 0.7, 1.0)
		"C": return Color(1.0, 0.7, 0.3)
		_:   return UITheme.COLOR_DANGER

func _get_grade_desc(grade: String) -> String:
	match grade:
		"S": return "Extraordinary!"
		"A": return "Impressive work"
		"B": return "Solid effort"
		"C": return "Could do better"
		_:   return "Back to the mines..."

# ============================================================================
# BUTTON HANDLER
# ============================================================================

func _on_continue_pressed() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null

	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_tween.tween_callback(func():
		visible = false
		modulate.a = 1.0
		EventBus.round_end_confirmed.emit()
	)
