extends Control

## Help dialog showing keyboard shortcuts and game instructions

# ============================================================================
# NODES
# ============================================================================

@onready var close_button_top: Button = $PanelContainer/VBoxContainer/TitleBar/CloseButton
@onready var close_button_bottom: Button = $PanelContainer/VBoxContainer/CloseButtonBottom

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_apply_help_styles()

	# Connect button signals
	close_button_top.pressed.connect(_on_close_pressed)
	close_button_bottom.pressed.connect(_on_close_pressed)

	# Connect to EventBus
	EventBus.help_opened.connect(_on_help_opened)

	# Hide debug section in release builds
	if not OS.is_debug_build():
		var debug_section = $PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/DebugSection
		if debug_section:
			debug_section.visible = false

func _apply_help_styles() -> void:
	var panel: PanelContainer = $PanelContainer
	panel.add_theme_stylebox_override("panel", UITheme.modal_style())

	var title_label: Label = $PanelContainer/VBoxContainer/TitleBar/TitleLabel
	if UITheme.font_heading:
		title_label.add_theme_font_override("font", UITheme.font_heading)
	title_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)

	close_button_top.add_theme_stylebox_override("normal", UITheme.action_button_style())
	close_button_bottom.add_theme_stylebox_override("normal", UITheme.action_button_style())

	# Section headers
	var section_label_paths := [
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/MovementSection/SectionLabel",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/MiningSection/SectionLabel",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/UISection/SectionLabel",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/DebugSection/SectionLabel",
	]
	for path in section_label_paths:
		var lbl := get_node_or_null(path)
		if lbl:
			if UITheme.font_heading:
				lbl.add_theme_font_override("font", UITheme.font_heading)
			lbl.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)

	# Key labels — chip-styled background
	var key_label_paths := [
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/MovementSection/GridContainer/Key1",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/MovementSection/GridContainer/Key2",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/MovementSection/GridContainer/Key3",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/MovementSection/GridContainer/Key4",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/MiningSection/GridContainer/Key1",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/MiningSection/GridContainer/Key2",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/UISection/GridContainer/Key1",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/UISection/GridContainer/Key2",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/DebugSection/GridContainer/Key1",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/DebugSection/GridContainer/Key2",
		"PanelContainer/VBoxContainer/ScrollContainer/VBoxContainer/DebugSection/GridContainer/Key3",
	]
	for path in key_label_paths:
		var lbl := get_node_or_null(path)
		if lbl:
			lbl.add_theme_stylebox_override("normal", UITheme.chip_style(UITheme.COLOR_BG_DEEP))
			lbl.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
			if UITheme.font_body_bold:
				lbl.add_theme_font_override("font", UITheme.font_body_bold)

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Close on ESC or H
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_help"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_help_opened() -> void:
	# Pause game when help opens
	get_tree().paused = true
	visible = true

func _on_close_pressed() -> void:
	# Resume game when help closes
	get_tree().paused = false
	visible = false
	EventBus.help_closed.emit()
