extends Control

## Settings menu — thin UI layer over SettingsManager autoload

# ============================================================================
# NODES
# ============================================================================

@onready var window_mode_option: OptionButton  = $PanelContainer/VBoxContainer/DisplaySection/WindowModeContainer/WindowModeOptionButton
@onready var resolution_option: OptionButton   = $PanelContainer/VBoxContainer/DisplaySection/ResolutionContainer/ResolutionOptionButton
@onready var master_slider: HSlider      = $PanelContainer/VBoxContainer/AudioSection/MasterVolumeContainer/MasterSlider
@onready var sfx_slider: HSlider         = $PanelContainer/VBoxContainer/AudioSection/SFXVolumeContainer/SFXSlider
@onready var music_slider: HSlider       = $PanelContainer/VBoxContainer/AudioSection/MusicVolumeContainer/MusicSlider
@onready var master_value_label: Label   = $PanelContainer/VBoxContainer/AudioSection/MasterVolumeContainer/ValueLabel
@onready var sfx_value_label: Label      = $PanelContainer/VBoxContainer/AudioSection/SFXVolumeContainer/ValueLabel
@onready var music_value_label: Label    = $PanelContainer/VBoxContainer/AudioSection/MusicVolumeContainer/ValueLabel
@onready var language_option: OptionButton = $PanelContainer/VBoxContainer/LanguageSection/LanguageContainer/LanguageOptionButton
@onready var reset_button: Button  = $PanelContainer/VBoxContainer/ButtonContainer/ResetDefaultsButton
@onready var close_button: Button  = $PanelContainer/VBoxContainer/ButtonContainer/CloseButton

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_apply_settings_styles()
	_populate_window_mode_options()
	_populate_resolution_options()
	_populate_language_options()
	_sync_ui_to_settings()
	_hide_display_section_on_mobile()

	window_mode_option.item_selected.connect(_on_window_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	language_option.item_selected.connect(_on_language_selected)
	reset_button.pressed.connect(_on_reset_defaults_pressed)
	close_button.pressed.connect(_on_close_pressed)

## Window mode / resolution can't be changed on mobile — hide that whole section
func _hide_display_section_on_mobile() -> void:
	if not OS.has_feature("mobile"):
		return
	var section := get_node_or_null("PanelContainer/VBoxContainer/DisplaySection")
	if section:
		section.visible = false
	var separator := get_node_or_null("PanelContainer/VBoxContainer/HSeparator")
	if separator:
		separator.visible = false

func _populate_window_mode_options() -> void:
	window_mode_option.clear()
	for label in SettingsManager.WINDOW_MODE_LABELS:
		window_mode_option.add_item(label)

func _populate_resolution_options() -> void:
	resolution_option.clear()
	for label in SettingsManager.RESOLUTION_LABELS:
		resolution_option.add_item(label)

func _populate_language_options() -> void:
	language_option.clear()
	for display_name in LocalizationManager.LOCALE_DISPLAY_NAMES:
		language_option.add_item(display_name)

## Push current SettingsManager state into widgets (no signals fired)
func _sync_ui_to_settings() -> void:
	window_mode_option.selected = SettingsManager.window_mode
	resolution_option.selected  = SettingsManager.resolution_index
	resolution_option.disabled  = SettingsManager.window_mode != 0  # Only enabled in Window mode (not fullscreen w/ black bars)

	master_slider.set_value_no_signal(SettingsManager.master_volume)
	sfx_slider.set_value_no_signal(SettingsManager.sfx_volume)
	music_slider.set_value_no_signal(SettingsManager.music_volume)

	master_value_label.text = "%d%%" % SettingsManager.master_volume
	sfx_value_label.text    = "%d%%" % SettingsManager.sfx_volume
	music_value_label.text  = "%d%%" % SettingsManager.music_volume

	language_option.selected = LocalizationManager.current_locale_index()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_window_mode_selected(index: int) -> void:
	SettingsManager.set_window_mode(index)
	# Re-sync: switching to Window may have auto-adjusted resolution_index
	resolution_option.selected = SettingsManager.resolution_index
	resolution_option.disabled = index != 0  # Resolution only matters in Window mode (not fullscreen w/ black bars)

func _on_resolution_selected(index: int) -> void:
	SettingsManager.set_resolution(index)

func _on_master_volume_changed(value: float) -> void:
	master_value_label.text = "%d%%" % value
	SettingsManager.set_master_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	sfx_value_label.text = "%d%%" % value
	SettingsManager.set_sfx_volume(value)

func _on_music_volume_changed(value: float) -> void:
	music_value_label.text = "%d%%" % value
	SettingsManager.set_music_volume(value)

func _on_language_selected(index: int) -> void:
	var locale := LocalizationManager.SUPPORTED_LOCALES[index]
	LocalizationManager.set_locale(locale)

func _on_reset_defaults_pressed() -> void:
	SettingsManager.reset_to_defaults()
	LocalizationManager.set_locale(SettingsManager.DEFAULT_LANGUAGE)
	_sync_ui_to_settings()

func _on_close_pressed() -> void:
	visible = false
	EventBus.settings_closed.emit()

# ============================================================================
# INPUT
# ============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()

# ============================================================================
# STYLES
# ============================================================================

func _apply_settings_styles() -> void:
	var panel: PanelContainer = $PanelContainer
	panel.add_theme_stylebox_override("panel", UITheme.modal_style())

	var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
	if UITheme.font_heading:
		title_label.add_theme_font_override("font", UITheme.font_heading)
	title_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)

	for path in [
		"PanelContainer/VBoxContainer/DisplaySection/SectionLabel",
		"PanelContainer/VBoxContainer/AudioSection/SectionLabel",
		"PanelContainer/VBoxContainer/LanguageSection/SectionLabel",
	]:
		var lbl := get_node_or_null(path)
		if lbl:
			if UITheme.font_heading:
				lbl.add_theme_font_override("font", UITheme.font_heading)
			lbl.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)

	close_button.add_theme_stylebox_override("normal",  UITheme.action_button_style())
	reset_button.add_theme_stylebox_override("normal",  UITheme.action_button_style())
