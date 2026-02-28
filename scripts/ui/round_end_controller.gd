extends Control

## Round end summary panel with animated stats reveal

# ============================================================================
# NODES
# ============================================================================

@onready var results_panel: PanelContainer = $CenterContainer/ResultsPanel
@onready var header_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/HeaderLabel
@onready var gold_value_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/StatsContainer/GoldRow/GoldValueLabel
@onready var time_value_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/StatsContainer/TimeRow/TimeValueLabel
@onready var grade_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/GradeContainer/GradeLabel
@onready var grade_value_label: Label = $CenterContainer/ResultsPanel/VBoxContainer/GradeContainer/GradeValueLabel
@onready var continue_button: Button = $CenterContainer/ResultsPanel/VBoxContainer/ContinueButton

# ============================================================================
# STATE
# ============================================================================

var session_stats: Dictionary = {}

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
	gold_value_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	time_value_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)

	continue_button.add_theme_stylebox_override("normal", UITheme.action_button_style())

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_round_ended(stats: Dictionary) -> void:
	session_stats = stats

	header_label.text = "ROUND %d COMPLETE" % GameManager.round_number
	time_value_label.text = "%.1fs" % stats.time_used
	gold_value_label.text = "0"

	# Reset animated elements to invisible
	grade_value_label.modulate.a = 0.0
	grade_value_label.scale = Vector2(0.3, 0.3)
	grade_label.modulate.a = 0.0
	continue_button.modulate.a = 0.0
	results_panel.modulate.a = 0.0

	visible = true

	# Wait for CenterContainer layout before animating position
	await get_tree().process_frame

	# Entry: slide up 40px + fade in
	results_panel.position.y += 40.0
	var entry_tween := create_tween().set_parallel(true)
	entry_tween.tween_property(results_panel, "modulate:a", 1.0, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entry_tween.tween_property(results_panel, "position:y", results_panel.position.y - 40.0, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Gold counter: tween 0 → final (starts after 0.4s)
	await get_tree().create_timer(0.4).timeout
	_animate_gold_counter(stats.gold_collected)

	# Grade reveal: after gold counter (0.8s) + 0.3s buffer
	await get_tree().create_timer(1.2).timeout
	_reveal_grade(stats)

	# Continue button: after grade pop (0.5s)
	await get_tree().create_timer(0.5).timeout
	var btn_tween := create_tween()
	btn_tween.tween_property(continue_button, "modulate:a", 1.0, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _animate_gold_counter(final_gold: int) -> void:
	var gold_tween := create_tween()
	gold_tween.tween_method(_update_gold_text, 0.0, float(final_gold), 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _update_gold_text(value: float) -> void:
	gold_value_label.text = "%d" % int(value)

func _reveal_grade(stats: Dictionary) -> void:
	var efficiency: float = stats.get("efficiency", 0.0)
	var grade := _get_grade(efficiency)
	var grade_color := _get_grade_color(grade)

	grade_value_label.text = grade
	grade_value_label.add_theme_color_override("font_color", grade_color)

	var grade_tween := create_tween().set_parallel(true)
	grade_tween.tween_property(grade_value_label, "modulate:a", 1.0, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	grade_tween.tween_property(grade_value_label, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var label_tween := create_tween()
	label_tween.tween_property(grade_label, "modulate:a", 1.0, 0.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _get_grade(efficiency: float) -> String:
	if efficiency >= 0.9: return "S"
	elif efficiency >= 0.7: return "A"
	elif efficiency >= 0.5: return "B"
	elif efficiency >= 0.3: return "C"
	else: return "D"

func _get_grade_color(grade: String) -> Color:
	match grade:
		"S": return UITheme.COLOR_GOLD_BRIGHT
		"A": return Color(0.4, 1.0, 0.5)
		"B": return Color(0.4, 0.7, 1.0)
		"C": return Color(1.0, 0.7, 0.3)
		_:   return UITheme.COLOR_DANGER

func _on_continue_pressed() -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_tween.tween_callback(func():
		visible = false
		modulate.a = 1.0
	)
	# GameManager will handle transition back to auction
