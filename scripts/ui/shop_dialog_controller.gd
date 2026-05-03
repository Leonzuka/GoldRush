extends Control
class_name ShopDialogController

## Modal shop overlay used both during mining and at auction time.
## Built entirely in code (matches loan_dialog_controller.gd pattern).
## Emits closed() when dismissed; caller is responsible for queue_free()
## happens automatically in _on_close_pressed().

signal closed()

const UpgradeCardScript = preload("res://scripts/ui/upgrade_card.gd")

## Caller sets this before adding to scene tree.
## "mining" — opened from HUD during a round
## "auction" — opened from auction TopBar
var context: String = "mining"

var _money_label: Label
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
	panel.custom_minimum_size = Vector2(780, 560)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	_build_header(vbox)
	vbox.add_child(HSeparator.new())
	_build_grid(vbox)
	vbox.add_child(HSeparator.new())
	_build_footer(vbox)

	EventBus.money_changed.connect(_on_money_changed)
	EventBus.shop_opened.emit()

func _build_header(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	parent.add_child(hbox)

	var title := Label.new()
	title.text = tr("SHOP_TITLE")
	title.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 24)
	if UITheme.font_display:
		title.add_theme_font_override("font", UITheme.font_display)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	_money_label = Label.new()
	_money_label.text = "$ %d" % GameManager.player_money
	_money_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	_money_label.add_theme_font_size_override("font_size", 20)
	if UITheme.font_body_bold:
		_money_label.add_theme_font_override("font", UITheme.font_body_bold)
	hbox.add_child(_money_label)

func _build_grid(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(grid)

	for id in Config.UPGRADE_DEFINITIONS.keys():
		var card: UpgradeCard = UpgradeCardScript.new()
		card.upgrade_id = id
		grid.add_child(card)

func _build_footer(parent: VBoxContainer) -> void:
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(btn_row)

	_close_button = Button.new()
	_close_button.text = tr("Close")
	var close_style: StyleBoxFlat = UITheme.action_button_style()
	close_style.border_color = UITheme.COLOR_DANGER
	_close_button.add_theme_stylebox_override("normal", close_style)
	_close_button.custom_minimum_size = Vector2(160, 40)
	_close_button.pressed.connect(_on_close_pressed)
	btn_row.add_child(_close_button)

func _on_money_changed(new_amount: int) -> void:
	if _money_label:
		_money_label.text = "$ %d" % new_amount

func _on_close_pressed() -> void:
	EventBus.shop_closed.emit()
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
