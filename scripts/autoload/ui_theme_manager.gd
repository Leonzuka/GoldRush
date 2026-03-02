extends Node

## UITheme — Global theme manager singleton
## Builds and applies a cohesive "Golden Age Prospector" theme to all UI.
## Must be registered BEFORE GameManager in project.godot autoloads.

# ============================================================================
# COLOR PALETTE
# ============================================================================

const COLOR_BG_DEEP       := Color(0.102, 0.051, 0.024)  # #1A0D06 — Background fills
const COLOR_BG_SURFACE    := Color(0.176, 0.082, 0.031)  # #2D1508 — Panel backgrounds
const COLOR_SURFACE_LIGHT := Color(0.420, 0.188, 0.063)  # #6B3010 — Button hover, avatar bg
const COLOR_GOLD_PRIMARY  := Color(0.784, 0.573, 0.165)  # #C8922A — Borders, accents
const COLOR_GOLD_BRIGHT   := Color(0.941, 0.753, 0.376)  # #F0C060 — Title text, highlights
const COLOR_TEXT_WARM     := Color(0.961, 0.871, 0.702)  # #F5DEB3 — Body text (wheat)
const COLOR_TEXT_MUTED    := Color(0.753, 0.627, 0.376)  # #C0A060 — Secondary labels
const COLOR_DANGER        := Color(0.545, 0.125, 0.125)  # #8B2020 — Quit button, NPC loss
const COLOR_SUCCESS       := Color(0.165, 0.420, 0.125)  # #2A6B20 — Money gain flash
const COLOR_BORDER_GOLD   := Color(0.545, 0.412, 0.078)  # #8B6914 — Panel borders

# ============================================================================
# FONTS
# ============================================================================

var font_display: FontFile = null    # CinzelDecorative-Bold.ttf
var font_heading: FontFile = null    # Cinzel-Regular.ttf
var font_body: FontFile = null       # Lato-Regular.ttf
var font_body_bold: FontFile = null  # Lato-Bold.ttf

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_load_fonts()
	var theme := _build_theme()
	get_tree().root.theme = theme

func _load_fonts() -> void:
	var paths := {
		"display":    "res://assets/fonts/CinzelDecorative-Bold.ttf",
		"heading":    "res://assets/fonts/Cinzel-Regular.ttf",
		"body":       "res://assets/fonts/Lato-Regular.ttf",
		"body_bold":  "res://assets/fonts/Lato-Bold.ttf",
	}

	for key in paths:
		var path: String = paths[key]
		if ResourceLoader.exists(path):
			var f := load(path) as FontFile
			match key:
				"display":   font_display   = f
				"heading":   font_heading   = f
				"body":      font_body      = f
				"body_bold": font_body_bold = f
		else:
			push_warning("[UITheme] %s not found! Using system font." % path)

# ============================================================================
# THEME BUILDER
# ============================================================================

func _build_theme() -> Theme:
	var theme := Theme.new()

	# Default font and size
	if font_body:
		theme.default_font = font_body
	theme.default_font_size = 16

	# --- Label ---
	theme.set_color("font_color", "Label", COLOR_TEXT_WARM)
	if font_body:
		theme.set_font("font", "Label", font_body)
	theme.set_font_size("font_size", "Label", 16)

	# --- Button ---
	theme.set_color("font_color", "Button", COLOR_TEXT_WARM)
	theme.set_color("font_hover_color", "Button", COLOR_GOLD_BRIGHT)
	theme.set_color("font_pressed_color", "Button", COLOR_GOLD_PRIMARY)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT_MUTED)
	if font_body_bold:
		theme.set_font("font", "Button", font_body_bold)
	theme.set_font_size("font_size", "Button", 16)
	theme.set_stylebox("normal", "Button", action_button_style())
	theme.set_stylebox("hover", "Button", _button_hover_style())
	theme.set_stylebox("pressed", "Button", _button_pressed_style())
	theme.set_stylebox("disabled", "Button", _button_disabled_style())
	theme.set_stylebox("focus", "Button", action_button_style())

	# --- PanelContainer ---
	theme.set_stylebox("panel", "PanelContainer", panel_style())

	# --- ProgressBar ---
	theme.set_stylebox("background", "ProgressBar", _progress_bg_style())
	theme.set_stylebox("fill", "ProgressBar", _progress_fill_style())

	# --- HSeparator ---
	var sep_style := StyleBoxLine.new()
	sep_style.color = COLOR_BORDER_GOLD
	sep_style.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep_style)

	# --- VSeparator ---
	var vsep_style := StyleBoxLine.new()
	vsep_style.color = COLOR_BORDER_GOLD
	vsep_style.thickness = 1
	vsep_style.vertical = true
	theme.set_stylebox("separator", "VSeparator", vsep_style)

	return theme

# ============================================================================
# PUBLIC FACTORY METHODS
# ============================================================================

## Standard panel — dark surface with thin gold border
func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_BG_SURFACE
	s.border_color = COLOR_BORDER_GOLD
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	s.shadow_size = 4
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

## Modal / dialog panel — wider border, larger shadow
func modal_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_BG_SURFACE
	s.border_color = COLOR_BORDER_GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	s.shadow_size = 8
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s

## Compact chip — for HUD elements
func chip_style(bg: Color = COLOR_BG_SURFACE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = COLOR_BORDER_GOLD
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

## Primary action button style
func action_button_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_BG_SURFACE
	s.border_color = COLOR_GOLD_PRIMARY
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

## NPC avatar floating panel
func npc_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(COLOR_BG_DEEP.r, COLOR_BG_DEEP.g, COLOR_BG_DEEP.b, 0.92)
	s.border_color = COLOR_GOLD_PRIMARY
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

# ============================================================================
# INTERNAL STYLE HELPERS
# ============================================================================

func _button_hover_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_SURFACE_LIGHT
	s.border_color = COLOR_GOLD_PRIMARY
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _button_pressed_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_BG_DEEP
	s.border_color = COLOR_GOLD_PRIMARY
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10  # +2px coin-press feel
	s.content_margin_bottom = 6
	return s

func _button_disabled_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(COLOR_BG_SURFACE.r, COLOR_BG_SURFACE.g, COLOR_BG_SURFACE.b, 0.5)
	s.border_color = Color(COLOR_BORDER_GOLD.r, COLOR_BORDER_GOLD.g, COLOR_BORDER_GOLD.b, 0.4)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _progress_bg_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(COLOR_BG_DEEP.r, COLOR_BG_DEEP.g, COLOR_BG_DEEP.b, 0.8)
	s.border_color = COLOR_BORDER_GOLD
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	return s

func _progress_fill_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = COLOR_GOLD_PRIMARY
	s.shadow_color = Color(COLOR_GOLD_BRIGHT.r, COLOR_GOLD_BRIGHT.g, COLOR_GOLD_BRIGHT.b, 0.4)
	s.shadow_size = 2
	s.set_corner_radius_all(3)
	return s
