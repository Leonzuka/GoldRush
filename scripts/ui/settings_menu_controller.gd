extends Control

## Settings menu for audio, video, and game options
## Persists settings to user://settings.cfg

# ============================================================================
# NODES
# ============================================================================

@onready var fullscreen_checkbox: CheckButton = $PanelContainer/VBoxContainer/DisplaySection/FullscreenCheckbox
@onready var master_slider: HSlider = $PanelContainer/VBoxContainer/AudioSection/MasterVolumeContainer/MasterSlider
@onready var sfx_slider: HSlider = $PanelContainer/VBoxContainer/AudioSection/SFXVolumeContainer/SFXSlider
@onready var music_slider: HSlider = $PanelContainer/VBoxContainer/AudioSection/MusicVolumeContainer/MusicSlider
@onready var master_value_label: Label = $PanelContainer/VBoxContainer/AudioSection/MasterVolumeContainer/ValueLabel
@onready var sfx_value_label: Label = $PanelContainer/VBoxContainer/AudioSection/SFXVolumeContainer/ValueLabel
@onready var music_value_label: Label = $PanelContainer/VBoxContainer/AudioSection/MusicVolumeContainer/ValueLabel
@onready var reset_button: Button = $PanelContainer/VBoxContainer/ButtonContainer/ResetDefaultsButton
@onready var close_button: Button = $PanelContainer/VBoxContainer/ButtonContainer/CloseButton

# ============================================================================
# SETTINGS STATE
# ============================================================================

const SETTINGS_PATH: String = "user://settings.cfg"

var config: ConfigFile = ConfigFile.new()

# Default values
const DEFAULT_FULLSCREEN: bool = true
const DEFAULT_MASTER_VOLUME: float = 100.0
const DEFAULT_SFX_VOLUME: float = 100.0
const DEFAULT_MUSIC_VOLUME: float = 80.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect signals
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	master_slider.value_changed.connect(_on_master_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	reset_button.pressed.connect(_on_reset_defaults_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# Load and apply settings
	load_settings()

# ============================================================================
# SETTINGS PERSISTENCE
# ============================================================================

func load_settings() -> void:
	var err = config.load(SETTINGS_PATH)

	if err != OK:
		print("[Settings] No settings file found, using defaults")
		apply_defaults()
		return

	# Load display settings
	var fullscreen = config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN)
	fullscreen_checkbox.button_pressed = fullscreen
	apply_fullscreen(fullscreen)

	# Load audio settings
	var master_vol = config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)
	var sfx_vol = config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
	var music_vol = config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)

	master_slider.value = master_vol
	sfx_slider.value = sfx_vol
	music_slider.value = music_vol

	apply_audio_settings(master_vol, sfx_vol, music_vol)

func save_settings() -> void:
	# Save display settings
	config.set_value("display", "fullscreen", fullscreen_checkbox.button_pressed)

	# Save audio settings
	config.set_value("audio", "master_volume", master_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	config.set_value("audio", "music_volume", music_slider.value)

	var err = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("[Settings] Failed to save settings: %d" % err)
	else:
		print("[Settings] Settings saved successfully")

func apply_defaults() -> void:
	fullscreen_checkbox.button_pressed = DEFAULT_FULLSCREEN
	master_slider.value = DEFAULT_MASTER_VOLUME
	sfx_slider.value = DEFAULT_SFX_VOLUME
	music_slider.value = DEFAULT_MUSIC_VOLUME

	apply_fullscreen(DEFAULT_FULLSCREEN)
	apply_audio_settings(DEFAULT_MASTER_VOLUME, DEFAULT_SFX_VOLUME, DEFAULT_MUSIC_VOLUME)

# ============================================================================
# DISPLAY SETTINGS
# ============================================================================

func _on_fullscreen_toggled(enabled: bool) -> void:
	apply_fullscreen(enabled)
	save_settings()

func apply_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# ============================================================================
# AUDIO SETTINGS
# ============================================================================

func _on_master_volume_changed(value: float) -> void:
	master_value_label.text = "%d%%" % value
	apply_master_volume(value)
	save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	sfx_value_label.text = "%d%%" % value
	apply_sfx_volume(value)
	save_settings()

func _on_music_volume_changed(value: float) -> void:
	music_value_label.text = "%d%%" % value
	apply_music_volume(value)
	save_settings()

func apply_audio_settings(master: float, sfx: float, music: float) -> void:
	apply_master_volume(master)
	apply_sfx_volume(sfx)
	apply_music_volume(music)

	# Update labels
	master_value_label.text = "%d%%" % master
	sfx_value_label.text = "%d%%" % sfx
	music_value_label.text = "%d%%" % music

func apply_master_volume(value: float) -> void:
	# Convert 0-100 to dB (-80 to 0)
	var db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)

func apply_sfx_volume(value: float) -> void:
	var db = linear_to_db(value / 100.0)
	var bus_index = AudioServer.get_bus_index("SFX")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, db)

func apply_music_volume(value: float) -> void:
	var db = linear_to_db(value / 100.0)
	var bus_index = AudioServer.get_bus_index("Music")
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, db)

func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0  # Effective mute
	return 20.0 * log(linear) / log(10.0)

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_reset_defaults_pressed() -> void:
	apply_defaults()
	save_settings()

func _on_close_pressed() -> void:
	visible = false
	EventBus.settings_closed.emit()

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()
