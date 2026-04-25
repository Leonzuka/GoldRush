extends Node

## SettingsManager — persistent settings autoload
##
## Loaded first so audio/display are applied before any scene renders.
## Saves to user://settings.cfg on every change.

# ============================================================================
# CONSTANTS
# ============================================================================

const SETTINGS_PATH: String = "user://settings.cfg"

## 0 = Window  1 = FullScreen  2 = Windowed FullScreen  3 = Fullscreen (Black Bars)
const DEFAULT_WINDOW_MODE: int = 1
const DEFAULT_MASTER_VOLUME: float = 100.0
const DEFAULT_SFX_VOLUME: float = 100.0
const DEFAULT_MUSIC_VOLUME: float = 80.0
const DEFAULT_RESOLUTION_INDEX: int = 1  # 1920×1080
const DEFAULT_LANGUAGE: String = "en"

const WINDOW_MODE_LABELS: Array[String] = [
	"Window",
	"FullScreen",
	"Windowed FullScreen",
	"Fullscreen (Black Bars)",
]

## Maps WINDOW_MODE index → DisplayServer.WindowMode constant
## Index 3 uses WINDOWED + full-screen-sized window + keep aspect ratio (black bars)
const WINDOW_MODE_DS: Array[int] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_FULLSCREEN,  # borderless / windowed-fullscreen
	DisplayServer.WINDOW_MODE_WINDOWED,    # black bars: windowed but fills screen
]

## Ordered list of supported window resolutions (windowed mode only)
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const RESOLUTION_LABELS: Array[String] = [
	"1280 × 720",
	"1920 × 1080",
	"2560 × 1440",
	"3840 × 2160",
]

# ============================================================================
# CURRENT VALUES (read-only from other scripts)
# ============================================================================

var window_mode: int = DEFAULT_WINDOW_MODE
var resolution_index: int = DEFAULT_RESOLUTION_INDEX
var master_volume: float = DEFAULT_MASTER_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var language: String = DEFAULT_LANGUAGE

# ============================================================================
# INTERNAL
# ============================================================================

var _config: ConfigFile = ConfigFile.new()

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	load_and_apply()

## Load settings from disk and apply immediately.
## Falls back to defaults if file is missing or corrupt.
func load_and_apply() -> void:
	var err = _config.load(SETTINGS_PATH)
	if err != OK:
		print("[Settings] No file found — applying defaults")
		_apply_defaults_silent()
		return

	window_mode      = _config.get_value("display",  "window_mode",       DEFAULT_WINDOW_MODE)
	resolution_index = _config.get_value("display",  "resolution_index",  DEFAULT_RESOLUTION_INDEX)
	master_volume    = _config.get_value("audio",    "master_volume",     DEFAULT_MASTER_VOLUME)
	sfx_volume       = _config.get_value("audio",    "sfx_volume",        DEFAULT_SFX_VOLUME)
	music_volume     = _config.get_value("audio",    "music_volume",      DEFAULT_MUSIC_VOLUME)
	language         = _config.get_value("general",  "language",          DEFAULT_LANGUAGE)

	_apply_all()
	print("[Settings] Loaded — window_mode=%d res=%d master=%.0f sfx=%.0f music=%.0f lang=%s" % [
		window_mode, resolution_index, master_volume, sfx_volume, music_volume, language
	])

# ============================================================================
# PUBLIC SETTERS (each saves immediately)
# ============================================================================

func set_window_mode(mode_index: int) -> void:
	window_mode = clampi(mode_index, 0, WINDOW_MODE_DS.size() - 1)
	# Switching to windowed: auto-pick a smaller resolution if current one fills the screen
	if window_mode == 0:
		_clamp_resolution_to_screen()
	_apply_window_mode(window_mode)
	save()

## Ensures the selected resolution fits on-screen with room for the title bar.
## Drops to the largest resolution strictly smaller than the monitor.
func _clamp_resolution_to_screen() -> void:
	var screen: Vector2i = DisplayServer.screen_get_size()
	var res: Vector2i = RESOLUTIONS[resolution_index]
	if res.x >= screen.x or res.y >= screen.y:
		# Find the largest resolution that comfortably fits
		resolution_index = 0  # Fallback to smallest
		for i in range(RESOLUTIONS.size() - 1, -1, -1):
			var r: Vector2i = RESOLUTIONS[i]
			if r.x < screen.x and r.y < screen.y:
				resolution_index = i
				break

func set_resolution(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	if window_mode == 0:  # Only applies in windowed
		_apply_resolution(resolution_index)
	save()

func set_master_volume(value: float) -> void:
	master_volume = value
	_apply_master_volume(value)
	save()

func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	_apply_sfx_volume(value)
	save()

func set_music_volume(value: float) -> void:
	music_volume = value
	_apply_music_volume(value)
	save()

## Persist language choice — locale is applied by LocalizationManager
func set_language(locale: String) -> void:
	language = locale
	save()

func reset_to_defaults() -> void:
	window_mode      = DEFAULT_WINDOW_MODE
	resolution_index = DEFAULT_RESOLUTION_INDEX
	master_volume    = DEFAULT_MASTER_VOLUME
	sfx_volume       = DEFAULT_SFX_VOLUME
	music_volume     = DEFAULT_MUSIC_VOLUME
	language         = DEFAULT_LANGUAGE
	_apply_all()
	save()

# ============================================================================
# PERSISTENCE
# ============================================================================

func save() -> void:
	_config.set_value("display",  "window_mode",      window_mode)
	_config.set_value("display",  "resolution_index", resolution_index)
	_config.set_value("audio",    "master_volume",    master_volume)
	_config.set_value("audio",    "sfx_volume",       sfx_volume)
	_config.set_value("audio",    "music_volume",     music_volume)
	_config.set_value("general",  "language",         language)

	var err = _config.save(SETTINGS_PATH)
	if err != OK:
		push_error("[Settings] Failed to save: %d" % err)

# ============================================================================
# APPLY HELPERS (private)
# ============================================================================

func _apply_all() -> void:
	_apply_window_mode(window_mode)
	if window_mode == 0:
		_apply_resolution(resolution_index)
	_apply_master_volume(master_volume)
	_apply_sfx_volume(sfx_volume)
	_apply_music_volume(music_volume)

## Apply defaults without saving (used on first run before file exists)
func _apply_defaults_silent() -> void:
	window_mode      = DEFAULT_WINDOW_MODE
	resolution_index = DEFAULT_RESOLUTION_INDEX
	master_volume    = DEFAULT_MASTER_VOLUME
	sfx_volume       = DEFAULT_SFX_VOLUME
	music_volume     = DEFAULT_MUSIC_VOLUME
	_apply_all()

func _apply_window_mode(mode_index: int) -> void:
	var ds_mode: int = WINDOW_MODE_DS[clampi(mode_index, 0, WINDOW_MODE_DS.size() - 1)]
	DisplayServer.window_set_mode(ds_mode)
	if mode_index == 3:
		# Fullscreen (Black Bars): fill screen with window, keep native aspect centered
		# content_scale_size tells Godot the "native" 1280x720 to scale from — required for black bars
		var screen: Vector2i = DisplayServer.screen_get_size()
		DisplayServer.window_set_size(screen)
		DisplayServer.window_set_position(Vector2i.ZERO)
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_tree().root.content_scale_size = Vector2i(1280, 720)
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	else:
		# Restore default: expand to fill (no black bars)
		get_tree().root.content_scale_size = Vector2i(0, 0)  # 0,0 = use window size
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		if mode_index == 0:
			_apply_resolution(resolution_index)

func _apply_resolution(index: int) -> void:
	var res: Vector2i = RESOLUTIONS[clampi(index, 0, RESOLUTIONS.size() - 1)]
	DisplayServer.window_set_size(res)
	# Center on primary monitor, but keep title bar on-screen (y >= 30)
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	@warning_ignore("integer_division")
	var win_pos: Vector2i = (screen_size - res) / 2
	win_pos.y = maxi(win_pos.y, 30)
	DisplayServer.window_set_position(win_pos)

func _apply_master_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), _to_db(value))

func _apply_sfx_volume(value: float) -> void:
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, _to_db(value))

func _apply_music_volume(value: float) -> void:
	var idx: int = AudioServer.get_bus_index("Music")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, _to_db(value))

func _to_db(linear_pct: float) -> float:
	var linear: float = linear_pct / 100.0
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
