extends Control

## Auction interface controller for isometric map system

# ============================================================================
# NODES
# ============================================================================

@onready var title_label: Label = $UILayer/TopBar/TitleLabel
@onready var money_label: Label = $UILayer/TopBar/MoneyLabel
@onready var info_panel: PanelContainer = $UILayer/PlotInfoPanel
@onready var plot_name_label: Label = $UILayer/PlotInfoPanel/VBoxContainer/PlotNameLabel
@onready var richness_label: Label = $UILayer/PlotInfoPanel/VBoxContainer/RichnessLabel
@onready var price_label: Label = $UILayer/PlotInfoPanel/VBoxContainer/PriceLabel
@onready var status_label: Label = $UILayer/PlotInfoPanel/VBoxContainer/StatusLabel
@onready var bid_button: Button = $UILayer/PlotInfoPanel/VBoxContainer/BidButton
@onready var info_label: Label = $UILayer/InfoLabel

@onready var map_controller: IsometricMapController = $MapViewport/SubViewport/IsometricMap

# ============================================================================
# DATA
# ============================================================================

var auction_system: AuctionSystem
var selected_plot: PlotData = null
var money_tween: Tween
var displayed_money: int = 0
var npc_turn_active: bool = false  # Player goes first; NPCs run after player picks

# FPS counter (created programmatically)
var fps_label: Label

# NPC roster sidebar (created in code, left edge)
var npc_roster: PanelContainer
var npc_entries: Dictionary = {}  # name → {container, avatar, status_lbl, claimed}

## MinigameRPS script pre-loaded for challenge flow
const MinigameRPSScript = preload("res://scripts/ui/minigame_rps_controller.gd")

# References to code-created labels that need translation refreshes
var _section_lbl: Label = null
var _competitors_header: Label = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("auction_ui")

	# Resize SubViewport to match actual screen resolution to avoid blurry upscaling
	$MapViewport.stretch = false
	var real_size := Vector2i(get_viewport().get_visible_rect().size)
	$MapViewport/SubViewport.size = real_size
	get_tree().root.size_changed.connect(_on_window_resized)

	_apply_auction_styles()
	_create_fps_label()

	# Connect signals
	EventBus.money_changed.connect(_on_money_changed)
	bid_button.pressed.connect(_on_bid_button_pressed)

	# Build permanent NPC roster sidebar
	_create_npc_roster()

	# Create auction system
	auction_system = AuctionSystem.new()
	auction_system.add_to_group("auction_system")
	auction_system.npc_claimed_plot.connect(_on_npc_claimed_plot)
	auction_system.npc_considering_plot.connect(_on_npc_considering_plot)
	auction_system.npc_turn_finished.connect(_on_npc_turn_finished)
	add_child(auction_system)

	# Update UI initial state
	title_label.text = tr("AUCTION_TITLE") % GameManager.round_number
	displayed_money = GameManager.player_money
	money_label.text = "$ %d" % displayed_money

	# CRITICAL: Wait for IsometricMapController to be ready and connected
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame to ensure connection

	# NOW generate plots (map is listening)
	var _plots = auction_system.generate_plots()

	# Player goes first — show the selection prompt immediately
	await get_tree().create_timer(0.5).timeout
	info_label.text = tr("YOUR_TURN_SELECT")

func _process(_delta: float) -> void:
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _create_fps_label() -> void:
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -90
	fps_label.offset_top = 10
	fps_label.offset_right = -10
	fps_label.offset_bottom = 30
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$UILayer.add_child(fps_label)

func _apply_auction_styles() -> void:
	# ---- TOP BAR BACKGROUND ----
	var top_bg = ColorRect.new()
	top_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bg.offset_bottom = 64.0
	top_bg.color = Color(0.09, 0.055, 0.02, 0.97)
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bg.z_index = -1
	$UILayer.add_child(top_bg)
	$UILayer.move_child(top_bg, 0)

	# Bottom separator line on top bar
	var top_line = ColorRect.new()
	top_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_line.offset_top = 63.0
	top_line.offset_bottom = 65.0
	top_line.color = Color(UITheme.COLOR_GOLD_PRIMARY, 0.7)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UILayer.add_child(top_line)
	$UILayer.move_child(top_line, 1)

	# ---- TOP BAR LABELS ----
	if UITheme.font_heading:
		title_label.add_theme_font_override("font", UITheme.font_heading)
	title_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_constant_override("outline_size", 1)

	money_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	money_label.add_theme_font_size_override("font_size", 20)

	# ---- RIGHT SIDEBAR (Plot Info Panel) ----
	# Reposition to full-height right sidebar
	info_panel.anchor_left = 1.0
	info_panel.anchor_top = 0.0
	info_panel.anchor_right = 1.0
	info_panel.anchor_bottom = 1.0
	info_panel.offset_left = -264.0
	info_panel.offset_top = 64.0
	info_panel.offset_right = 0.0
	info_panel.offset_bottom = 0.0
	info_panel.visible = true

	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.055, 0.02, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_color = Color(UITheme.COLOR_GOLD_PRIMARY, 0.6)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	info_panel.add_theme_stylebox_override("panel", panel_style)

	# Section header above plot info
	var section_lbl = Label.new()
	section_lbl.text = tr("PLOT_DETAILS")
	_section_lbl = section_lbl
	section_lbl.add_theme_font_size_override("font_size", 11)
	section_lbl.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY.darkened(0.1))
	if UITheme.font_heading:
		section_lbl.add_theme_font_override("font", UITheme.font_heading)
	$UILayer/PlotInfoPanel/VBoxContainer.add_child(section_lbl)
	$UILayer/PlotInfoPanel/VBoxContainer.move_child(section_lbl, 0)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(UITheme.COLOR_GOLD_PRIMARY, 0.4))
	sep.add_theme_constant_override("separation", 12)
	$UILayer/PlotInfoPanel/VBoxContainer.add_child(sep)
	$UILayer/PlotInfoPanel/VBoxContainer.move_child(sep, 1)

	# Plot name label
	if UITheme.font_heading:
		plot_name_label.add_theme_font_override("font", UITheme.font_heading)
	plot_name_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	plot_name_label.add_theme_font_size_override("font_size", 20)
	plot_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Richness
	richness_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	richness_label.add_theme_font_size_override("font_size", 15)

	# Price and status labels
	price_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_WARM)
	price_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_font_size_override("font_size", 13)

	# Bid button — styled with gold action style
	bid_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	bid_button.custom_minimum_size = Vector2(0, 44)

	# Default (no plot selected) state
	_show_default_panel_state()

	# ---- STATUS BAR ----
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	# Give it a dark pill background
	var status_style = StyleBoxFlat.new()
	status_style.bg_color = Color(0.07, 0.04, 0.01, 0.90)
	status_style.set_corner_radius_all(8)
	status_style.border_width_top = 1
	status_style.border_color = Color(UITheme.COLOR_GOLD_PRIMARY, 0.5)
	status_style.content_margin_left = 20
	status_style.content_margin_right = 20
	status_style.content_margin_top = 8
	status_style.content_margin_bottom = 12
	info_label.add_theme_stylebox_override("normal", status_style)
	# Reposition status bar: centered at bottom, with safe margin from edge
	info_label.anchor_left = 0.5
	info_label.anchor_top = 1.0
	info_label.anchor_right = 0.5
	info_label.anchor_bottom = 1.0
	info_label.offset_left = -300.0
	info_label.offset_top = -64.0
	info_label.offset_right = 300.0
	info_label.offset_bottom = -20.0

## Shows default state in plot info panel when no plot is selected
func _show_default_panel_state() -> void:
	plot_name_label.text = tr("NO_PLOT_SELECTED")
	richness_label.text = ""
	price_label.text = ""
	status_label.text = tr("CLICK_TO_VIEW")
	status_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
	bid_button.disabled = true
	bid_button.text = tr("SELECT_PLOT")

# ============================================================================
# PLOT SELECTION
# ============================================================================

## Called when player selects a plot on the map
func show_plot_info(plot: PlotData) -> void:
	selected_plot = plot
	# Track for Sly Sally's cunning sabotage
	if auction_system:
		auction_system.player_last_viewed_plot = plot

	plot_name_label.text = plot.plot_name
	richness_label.text = "★".repeat(plot.get_star_rating()) + "  " + plot.get_richness_tier()
	price_label.text = tr("STARTING_BID") % plot.base_price

	if plot.owner_type == PlotData.OwnerType.NPC:
		var npc_color = Config.NPC_COLORS.get(plot.owner_name, UITheme.COLOR_DANGER)
		status_label.text = tr("CLAIMED_BY") % plot.owner_name
		status_label.add_theme_color_override("font_color", npc_color)
		bid_button.disabled = false
		bid_button.text = tr("CHALLENGE_NPC") % plot.owner_name
		bid_button.modulate = Color(1.0, 0.75, 0.2)
	elif plot.owner_type == PlotData.OwnerType.PLAYER:
		status_label.text = tr("YOU_OWN_PLOT")
		status_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
		bid_button.disabled = true
		bid_button.text = tr("ACQUIRED")
		bid_button.modulate = Color.WHITE
	elif npc_turn_active:
		status_label.text = tr("RIVALS_CHOOSING")
		status_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
		bid_button.disabled = true
		bid_button.text = tr("WAIT_FOR_RIVALS")
		bid_button.modulate = Color.WHITE
	else:
		status_label.text = tr("AVAILABLE_BID")
		status_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
		bid_button.disabled = not GameManager.can_afford(plot.base_price)
		bid_button.text = tr("PLACE_BID") if not bid_button.disabled else tr("INSUFFICIENT_FUNDS")
		bid_button.modulate = Color.WHITE

# ============================================================================
# BIDDING
# ============================================================================

func _on_bid_button_pressed() -> void:
	if not selected_plot:
		return

	# NPC-owned plot: start the challenge minigame instead of a normal bid
	if selected_plot.owner_type == PlotData.OwnerType.NPC:
		_start_challenge_minigame(selected_plot)
		return

	if not selected_plot.is_biddable():
		return

	var bid_price = selected_plot.base_price

	if not GameManager.can_afford(bid_price):
		info_label.text = tr("INSUFFICIENT_FUNDS_MSG")
		return

	# Claim plot
	selected_plot.owner_type = PlotData.OwnerType.PLAYER
	selected_plot.final_bid_price = bid_price

	# Visual feedback
	info_label.text = tr("PLOT_ACQUIRED_MSG") % bid_price
	show_plot_info(selected_plot)  # Refresh panel to show "✓ You own this plot"
	map_controller.refresh_plot_visuals(selected_plot)

	# NPCs choose their plots — wait for them to finish before heading to the mines
	_set_all_npc_status(tr("ANALYZING_MARKET"))
	auction_system.start_npc_turn()
	await auction_system.npc_turn_finished

	await get_tree().create_timer(0.8).timeout
	EventBus.auction_won.emit(selected_plot)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_money_changed(new_amount: int) -> void:
	_animate_money_change(new_amount)

## Animate money counter with counting effect and color flash
func _animate_money_change(new_amount: int) -> void:
	var old_amount := displayed_money
	var gained := new_amount > old_amount

	if money_tween and money_tween.is_valid():
		money_tween.kill()

	var diff := absf(float(new_amount - old_amount))
	var duration := clampf(diff / 500.0, 0.3, 1.0)

	money_tween = create_tween()
	money_tween.tween_method(func(v: float):
		displayed_money = int(v)
		money_label.text = "$ %d" % displayed_money
	, float(old_amount), float(new_amount), duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	var flash_color := Color(0.3, 1.0, 0.3) if gained else Color(1.0, 0.3, 0.3)
	var color_tween := create_tween()
	color_tween.tween_property(money_label, "modulate", flash_color, 0.1)
	color_tween.tween_property(money_label, "modulate", Color.WHITE, 0.4)

func _on_npc_claimed_plot(plot: PlotData, npc_name: String) -> void:
	info_label.text = tr("NPC_CLAIMED_MSG") % [npc_name, plot.plot_name]
	map_controller.refresh_plot_visuals(plot)
	_set_npc_status(npc_name, tr("CLAIMED_PLOT") % plot.plot_name, false, true)

func _on_npc_considering_plot(plot: PlotData, npc_name: String) -> void:
	info_label.text = tr("NPC_EYEING_MSG") % [npc_name, plot.plot_name]
	_set_npc_status(npc_name, tr("EYEING_PLOT") % plot.plot_name, true, false)

func _on_npc_turn_finished() -> void:
	npc_turn_active = false
	_set_all_npc_status(tr("DONE_FOR_NOW"))
	_deactivate_all_npc_entries()
	# If player hasn't picked yet, unlock bidding; otherwise keep the transition message
	if selected_plot and selected_plot.owner_type != PlotData.OwnerType.PLAYER:
		info_label.text = tr("YOUR_TURN_SELECT")
		show_plot_info(selected_plot)

# ============================================================================
# CHALLENGE MINIGAME
# ============================================================================

func _start_challenge_minigame(plot: PlotData) -> void:
	var npc_agent = auction_system.get_agent_by_name(plot.owner_name) if auction_system else null
	var minigame = MinigameRPSScript.new()
	$UILayer.add_child(minigame)
	minigame.minigame_finished.connect(
		func(player_won: bool, contested_plot: PlotData):
			minigame.queue_free()
			if player_won:
				contested_plot.owner_type = PlotData.OwnerType.PLAYER
				contested_plot.final_bid_price = contested_plot.base_price
				info_label.text = tr("WON_DUEL")
				map_controller.refresh_plot_visuals(contested_plot)
				show_plot_info(contested_plot)
				# NPCs pick in the background; transition immediately
				auction_system.start_npc_turn()
				await get_tree().create_timer(1.5).timeout
				EventBus.auction_won.emit(contested_plot)
			else:
				# NPC retains the plot — mark it blocked so no retry
				info_label.text = tr("LOST_DUEL") % contested_plot.owner_name
				show_plot_info(contested_plot)
	)
	minigame.start_minigame(plot, plot.owner_name, npc_agent, auction_system)

# ============================================================================
# NPC ROSTER SIDEBAR
# ============================================================================

## Builds the permanent left sidebar showing all NPC competitors
func _create_npc_roster() -> void:
	npc_roster = PanelContainer.new()
	npc_roster.anchor_left = 0.0
	npc_roster.anchor_top = 0.0
	npc_roster.anchor_right = 0.0
	npc_roster.anchor_bottom = 1.0
	npc_roster.offset_left = 0.0
	npc_roster.offset_top = 64.0
	npc_roster.offset_right = 240.0
	npc_roster.offset_bottom = 0.0

	var roster_style = StyleBoxFlat.new()
	roster_style.bg_color = Color(0.09, 0.055, 0.02, 0.95)
	roster_style.border_width_right = 2
	roster_style.border_color = Color(UITheme.COLOR_GOLD_PRIMARY, 0.6)
	roster_style.content_margin_left = 14
	roster_style.content_margin_right = 14
	roster_style.content_margin_top = 18
	roster_style.content_margin_bottom = 24
	npc_roster.add_theme_stylebox_override("panel", roster_style)
	# Allow label text to draw slightly outside the panel rect in fullscreen;
	# the panel background still renders correctly without clipping.
	npc_roster.clip_contents = false

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	npc_roster.add_child(vbox)

	# Section header
	var header = Label.new()
	header.text = tr("COMPETITORS")
	_competitors_header = header
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	header.custom_minimum_size = Vector2(0, 18)
	if UITheme.font_heading:
		header.add_theme_font_override("font", UITheme.font_heading)
	vbox.add_child(header)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(UITheme.COLOR_GOLD_PRIMARY, 0.4))
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	# NPC entries
	for npc_name in Config.NPC_NAMES:
		_create_npc_entry(npc_name)
		vbox.add_child(npc_entries[npc_name]["container"])

	$UILayer.add_child(npc_roster)

## Creates a single NPC entry row for the roster
func _create_npc_entry(npc_name: String) -> Dictionary:
	var color = Config.NPC_COLORS.get(npc_name, Color(0.4, 0.6, 0.9))

	# Outer container with rounded background
	var container = PanelContainer.new()
	var entry_style = StyleBoxFlat.new()
	entry_style.bg_color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.8)
	entry_style.set_corner_radius_all(8)
	entry_style.border_width_left = 3
	entry_style.border_color = Color(color.r, color.g, color.b, 0.5)
	entry_style.content_margin_left = 10
	entry_style.content_margin_right = 10
	entry_style.content_margin_top = 10
	entry_style.content_margin_bottom = 14
	container.add_theme_stylebox_override("panel", entry_style)
	# Allow font rendering in fullscreen (non-integer scale factors) to draw
	# past the card rect without being clipped. The card background renders
	# independently, so this has no visual side-effect.
	container.clip_contents = false

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	container.add_child(hbox)

	# Avatar — circular portrait with NPC image (48×48)
	var avatar_style = StyleBoxFlat.new()
	avatar_style.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 1.0)
	avatar_style.set_corner_radius_all(24)
	avatar_style.set_border_width_all(2)
	avatar_style.border_color = Color(color.r, color.g, color.b, 0.8)

	var avatar_bg = Panel.new()
	avatar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_bg.add_theme_stylebox_override("panel", avatar_style)

	var avatar = Control.new()
	avatar.custom_minimum_size = Vector2(48, 48)
	avatar.add_child(avatar_bg)

	var img_path: String = Config.NPC_IMAGES.get(npc_name, "")
	var tex: Texture2D = load(img_path) as Texture2D if not img_path.is_empty() else null
	if tex:
		var avatar_tex := TextureRect.new()
		avatar_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		avatar_tex.texture = tex
		avatar_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		avatar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		avatar_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Shader clips the square image to a circle
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tif (length(uv) > 0.5) { discard; }\n\tCOLOR = texture(TEXTURE, UV);\n}"
		var mat := ShaderMaterial.new()
		mat.shader = shader
		avatar_tex.material = mat
		avatar.add_child(avatar_tex)
	else:
		# Procedural fallback: initial letter centered in the circle
		var initial_lbl := Label.new()
		initial_lbl.text = npc_name[0].to_upper() if npc_name.length() > 0 else "?"
		initial_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		initial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial_lbl.add_theme_font_size_override("font_size", 22)
		initial_lbl.add_theme_color_override("font_color", color.lightened(0.4))
		initial_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(initial_lbl)

	hbox.add_child(avatar)

	# Name + status column
	var info_col = VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 3)
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_col)

	var name_lbl = Label.new()
	name_lbl.text = npc_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", color.lightened(0.4))
	if UITheme.font_heading:
		name_lbl.add_theme_font_override("font", UITheme.font_heading)
	info_col.add_child(name_lbl)

	var status_lbl = Label.new()
	status_lbl.text = tr("WAITING")
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(0.55, 0.50, 0.42))
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.custom_minimum_size = Vector2(120, 22)
	info_col.add_child(status_lbl)

	# Store entry for later updates
	npc_entries[npc_name] = {
		"container": container,
		"entry_style": entry_style,
		"avatar": avatar,
		"avatar_style": avatar_style,
		"status_lbl": status_lbl,
		"color": color,
	}

	return npc_entries[npc_name]

## Updates a single NPC's status in the roster
## active = currently deliberating (highlighted), claimed = done for this round
func _set_npc_status(npc_name: String, status_text: String, active: bool, claimed: bool) -> void:
	var entry = npc_entries.get(npc_name)
	if not entry:
		return

	entry["status_lbl"].text = status_text
	var color: Color = entry["color"]

	if active:
		# Bright highlight when actively considering
		entry["status_lbl"].add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
		entry["entry_style"].bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 1.0)
		entry["entry_style"].border_color = Color(color.r, color.g, color.b, 1.0)
		entry["avatar_style"].border_color = UITheme.COLOR_GOLD_BRIGHT
		# Pulse tween on avatar
		var tween = entry["container"].create_tween().set_loops(4)
		tween.tween_property(entry["avatar"], "modulate", Color(1.3, 1.2, 1.0), 0.3).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(entry["avatar"], "modulate", Color.WHITE, 0.3).set_ease(Tween.EASE_IN_OUT)
	elif claimed:
		# Dimmed when done
		entry["status_lbl"].add_theme_color_override("font_color", Color(0.50, 0.75, 0.50))
		entry["entry_style"].bg_color = Color(color.r * 0.10, color.g * 0.10, color.b * 0.10, 0.7)
		entry["entry_style"].border_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.4)
		entry["avatar_style"].border_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.6)
		entry["avatar"].modulate = Color(0.7, 0.7, 0.7)
	else:
		entry["status_lbl"].add_theme_color_override("font_color", Color(0.55, 0.50, 0.42))
		entry["entry_style"].bg_color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.8)
		entry["entry_style"].border_color = Color(color.r, color.g, color.b, 0.5)
		entry["avatar_style"].border_color = Color(color.r, color.g, color.b, 0.8)
		entry["avatar"].modulate = Color.WHITE

## Sets all NPCs to the same status text (idle/reset)
func _set_all_npc_status(status_text: String) -> void:
	for npc_name in npc_entries.keys():
		var entry = npc_entries[npc_name]
		entry["status_lbl"].text = status_text

## Deactivates all NPC visual highlights
func _deactivate_all_npc_entries() -> void:
	for npc_name in npc_entries.keys():
		var entry = npc_entries[npc_name]
		var color: Color = entry["color"]
		entry["status_lbl"].add_theme_color_override("font_color", Color(0.55, 0.50, 0.42))
		entry["entry_style"].bg_color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.8)
		entry["entry_style"].border_color = Color(color.r, color.g, color.b, 0.5)

func _on_window_resized() -> void:
	var new_size := Vector2i(get_viewport().get_visible_rect().size)
	$MapViewport/SubViewport.size = new_size

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not title_label:
			return
		title_label.text = tr("AUCTION_TITLE") % GameManager.round_number
		if _section_lbl:
			_section_lbl.text = tr("PLOT_DETAILS")
		if _competitors_header:
			_competitors_header.text = tr("COMPETITORS")
		if selected_plot:
			show_plot_info(selected_plot)
		else:
			_show_default_panel_state()

## Briefly flashes the NPC roster entry to draw attention to an event
func _flash_npc_entry(npc_name: String) -> void:
	var entry = npc_entries.get(npc_name)
	if not entry:
		return
	var tween = entry["container"].create_tween()
	tween.tween_property(entry["container"], "modulate", Color(1.5, 0.6, 0.6), 0.15)
	tween.tween_property(entry["container"], "modulate", Color.WHITE, 0.5)

## Returns the initials of an NPC name (e.g. "Big Bob" → "BB")
func _get_initials(npc_name: String) -> String:
	var parts = npc_name.split(" ")
	var result = ""
	for part in parts:
		if part.length() > 0:
			result += part[0].to_upper()
	return result
