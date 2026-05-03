extends Control
class_name LoanDialogController

## Modal for taking and repaying loans.
##
## Built entirely in code (no .tscn) — same pattern used by the NPC roster and
## FPS label. Instantiated by AuctionUIController when the player presses Bank.
## Emits closed() when dismissed; caller is responsible for queue_free().

signal closed()

var _amount_slider: HSlider
var _amount_label: Label
var _balance_label: Label
var _debt_label: Label
var _take_button: Button
var _repay_button: Button
var _close_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100

	# Backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.modal_style())
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = tr("LOAN_TITLE")
	header.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	header.add_theme_font_size_override("font_size", 22)
	if UITheme.font_heading:
		header.add_theme_font_override("font", UITheme.font_heading)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	vbox.add_child(HSeparator.new())

	# Status rows
	_balance_label = _make_status_row(vbox, tr("LOAN_BALANCE"), "$ %d" % GameManager.player_money)
	_debt_label = _make_status_row(vbox, tr("LOAN_DEBT"), _format_debt(GameManager.current_debt))

	vbox.add_child(HSeparator.new())

	# Amount slider
	var amount_header := Label.new()
	amount_header.text = tr("LOAN_AMOUNT")
	amount_header.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)
	vbox.add_child(amount_header)

	_amount_slider = HSlider.new()
	_amount_slider.min_value = 100
	_amount_slider.max_value = GameManager.get_max_loan()
	_amount_slider.step = 100
	_amount_slider.value = mini(1000, GameManager.get_max_loan())
	_amount_slider.custom_minimum_size = Vector2(0, 28)
	_amount_slider.value_changed.connect(_on_amount_changed)
	vbox.add_child(_amount_slider)

	_amount_label = Label.new()
	_amount_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	_amount_label.add_theme_font_size_override("font_size", 18)
	_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_amount_label)
	_on_amount_changed(_amount_slider.value)

	var note := Label.new()
	note.text = tr("LOAN_INTEREST") % int(Config.LOAN_INTEREST_RATE * 100)
	note.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	note.add_theme_font_size_override("font_size", 12)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(note)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_take_button = Button.new()
	_take_button.text = tr("LOAN_TAKE")
	_take_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	_take_button.custom_minimum_size = Vector2(140, 40)
	_take_button.pressed.connect(_on_take_pressed)
	btn_row.add_child(_take_button)

	_repay_button = Button.new()
	_repay_button.text = tr("LOAN_REPAY")
	_repay_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	_repay_button.custom_minimum_size = Vector2(140, 40)
	_repay_button.pressed.connect(_on_repay_pressed)
	btn_row.add_child(_repay_button)

	_close_button = Button.new()
	_close_button.text = tr("Close")
	var close_style := UITheme.action_button_style()
	close_style.border_color = UITheme.COLOR_DANGER
	_close_button.add_theme_stylebox_override("normal", close_style)
	_close_button.custom_minimum_size = Vector2(100, 40)
	_close_button.pressed.connect(_on_close_pressed)
	btn_row.add_child(_close_button)

	EventBus.debt_changed.connect(_refresh)
	EventBus.money_changed.connect(_on_money_changed)
	_refresh(GameManager.current_debt)

func _make_status_row(parent: VBoxContainer, label_text: String, value_text: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	row.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)
	row.add_child(val)
	return val

func _format_debt(debt: int) -> String:
	return "$ %d" % debt if debt > 0 else "—"

func _on_amount_changed(value: float) -> void:
	_amount_label.text = "$ %d" % int(value)

func _on_money_changed(_new_amount: int) -> void:
	if _balance_label:
		_balance_label.text = "$ %d" % GameManager.player_money

func _refresh(debt: int) -> void:
	if _debt_label:
		_debt_label.text = _format_debt(debt)
		_debt_label.add_theme_color_override("font_color",
			UITheme.COLOR_DANGER if debt > 0 else UITheme.COLOR_TEXT_WARM)

	var can_loan: bool = GameManager.can_take_loan()
	_take_button.disabled = not can_loan
	_take_button.tooltip_text = tr("LOAN_ACTIVE_TOOLTIP") if not can_loan else ""

	var can_repay: bool = debt > 0 and GameManager.player_money > 0
	_repay_button.disabled = not can_repay

	# Slider may need to refresh max if round changed externally
	_amount_slider.editable = can_loan
	_amount_slider.max_value = GameManager.get_max_loan()
	if _amount_slider.value > _amount_slider.max_value:
		_amount_slider.value = _amount_slider.max_value

func _on_take_pressed() -> void:
	GameManager.take_loan(int(_amount_slider.value))
	_on_close_pressed()

func _on_repay_pressed() -> void:
	GameManager.repay_debt(GameManager.current_debt)

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
