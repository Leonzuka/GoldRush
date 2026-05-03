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
var npc_turn_active: bool = false      # True while NPCs are picking (blocks player bids)
var minigame_active: bool = false      # True during RPS minigame
var npc_challenges_done: bool = false  # True after NPC turn; prevents re-running on re-pick
var _in_review_phase: bool = false     # True between NPC turn end and player confirmation

## Emitted by _npc_initiates_challenge when the RPS minigame concludes.
signal _npc_challenge_resolved

# Confirm button shown during review phase (bottom-right corner)
var _proceed_button: Button = null

# FPS counter (created programmatically)
var fps_label: Label

# NPC roster sidebar (created in code, left edge)
var npc_roster: PanelContainer
var npc_entries: Dictionary = {}  # name → {container, avatar, status_lbl, claimed}
var _player_budget_lbl: Label = null

## MinigameRPS script pre-loaded for challenge flow
const MinigameRPSScript = preload("res://scripts/ui/minigame_rps_controller.gd")
const LoanDialogScript = preload("res://scripts/ui/loan_dialog_controller.gd")
const ShopDialogScript = preload("res://scripts/ui/shop_dialog_controller.gd")
const UpgradesStripScript = preload("res://scripts/ui/upgrades_strip.gd")

# Shop button + upgrades strip (created programmatically in TopBar)
var _shop_button: Button = null
var _upgrades_strip: UpgradesStrip = null

# Player card extras (debt label + Bank button created in code)
var _player_debt_lbl: Label = null
var _bank_button: Button = null

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
	_create_shop_button()
	_create_upgrades_strip()

	# Connect signals
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.debt_changed.connect(_on_debt_changed)
	EventBus.npc_stole_plot.connect(_on_npc_stole_plot)
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

## Adds a shop button to the auction TopBar (right of MoneyLabel)
func _create_shop_button() -> void:
	_shop_button = Button.new()
	_shop_button.text = tr("SHOP")
	_shop_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	_shop_button.custom_minimum_size = Vector2(110, 0)
	_shop_button.focus_mode = Control.FOCUS_NONE
	_shop_button.pressed.connect(_on_auction_shop_pressed)
	$UILayer/TopBar.add_child(_shop_button)

## Adds the active-upgrades chip strip in the auction TopBar
func _create_upgrades_strip() -> void:
	_upgrades_strip = UpgradesStripScript.new()
	_upgrades_strip.name = "UpgradesStrip"
	$UILayer/TopBar.add_child(_upgrades_strip)
	# Place between TitleLabel and MoneyLabel
	$UILayer/TopBar.move_child(_upgrades_strip, money_label.get_index())

func _on_auction_shop_pressed() -> void:
	var dlg: ShopDialogController = ShopDialogScript.new()
	dlg.context = "auction"
	add_child(dlg)
	# Auction is turn-based; no need to pause the tree

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
	elif _in_review_phase:
		# Player already committed — can only challenge NPC plots, not pick new ones
		status_label.text = tr("REVIEW_AVAILABLE_PLOT")
		status_label.add_theme_color_override("font_color", Color(0.65, 0.60, 0.50))
		bid_button.disabled = true
		bid_button.text = tr("REVIEW_COMMITTED_BTN")
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

	# Don't let stray clicks fire while a challenge is in progress or player already bid
	if minigame_active or npc_turn_active:
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

	# Lock out further bids AND shop immediately — before any await.
	# Shop must be disabled here to prevent spending money already committed to this bid.
	npc_turn_active = true
	bid_button.disabled = true
	if _shop_button:
		_shop_button.disabled = true

	# Visual feedback
	info_label.text = tr("PLOT_ACQUIRED_MSG") % bid_price
	show_plot_info(selected_plot)  # Refresh panel to show "✓ You own this plot"
	map_controller.refresh_plot_visuals(selected_plot)

	# NPCs react to the player's pick (runs only once per auction)
	if not npc_challenges_done:
		# Step 1: NPCs evaluate the player's plot BEFORE choosing their own.
		# A challenging NPC either wins the plot or falls back to a normal pick.
		await _run_npc_pre_challenge_phase()

		# Step 2: NPCs without a plot now pick from what remains.
		_set_all_npc_status(tr("ANALYZING_MARKET"))
		auction_system.start_npc_turn()
		await auction_system.npc_turn_finished
		npc_challenges_done = true

	# After all NPC picks, enter review phase so player can challenge rivals before mining
	if selected_plot and selected_plot.owner_type == PlotData.OwnerType.PLAYER:
		_enter_review_phase()
	else:
		# Player lost their plot to a pre-challenge — re-enable selection
		npc_turn_active = false
		selected_plot = null
		_show_default_panel_state()
		info_label.text = tr("LOST_PLOT_PICK_AGAIN")
		if _shop_button:
			_shop_button.disabled = false

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_money_changed(new_amount: int) -> void:
	_animate_money_change(new_amount)
	if _player_budget_lbl:
		_player_budget_lbl.text = "$ %d" % new_amount
	_refresh_bank_button()

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
	# Block the auction-end pipeline while the minigame is running. Without this,
	# any pending NPC turn / auction_won emit could race the player's RPS.
	minigame_active = true
	bid_button.disabled = true
	if _shop_button:
		_shop_button.disabled = true

	var npc_agent = auction_system.get_agent_by_name(plot.owner_name) if auction_system else null
	var minigame = MinigameRPSScript.new()
	$UILayer.add_child(minigame)
	minigame.minigame_finished.connect(
		func(player_won: bool, contested_plot: PlotData):
			minigame.queue_free()
			minigame_active = false
			contested_plot.base_price = int(contested_plot.base_price * 1.3)
			if player_won:
				if _in_review_phase:
					# Review phase: swap player's current plot for the won NPC plot
					var old_plot := _get_player_owned_plot()
					if old_plot and old_plot != contested_plot:
						old_plot.owner_type = PlotData.OwnerType.AVAILABLE
						old_plot.owner_name = ""
						map_controller.refresh_plot_visuals(old_plot)
					contested_plot.owner_type = PlotData.OwnerType.PLAYER
					contested_plot.final_bid_price = contested_plot.base_price
					selected_plot = contested_plot
					info_label.text = tr("WON_DUEL_REVIEW")
					map_controller.refresh_plot_visuals(contested_plot)
					show_plot_info(contested_plot)
					# Proceed button is already visible — player confirms when ready
				else:
					# Pre-NPC turn: player won against NPC, now NPCs pick what remains
					contested_plot.owner_type = PlotData.OwnerType.PLAYER
					contested_plot.final_bid_price = contested_plot.base_price
					selected_plot = contested_plot
					info_label.text = tr("WON_DUEL")
					map_controller.refresh_plot_visuals(contested_plot)
					show_plot_info(contested_plot)
					npc_turn_active = true
					_set_all_npc_status(tr("ANALYZING_MARKET"))
					auction_system.start_npc_turn()
					await auction_system.npc_turn_finished
					npc_challenges_done = true
					_enter_review_phase()
			else:
				if _in_review_phase:
					# Player keeps their original plot — restore panel
					var own_plot := _get_player_owned_plot()
					selected_plot = own_plot
					if own_plot:
						show_plot_info(own_plot)
					info_label.text = tr("LOST_DUEL_REVIEW")
				else:
					# NPC retains their plot — let player pick another available plot
					info_label.text = tr("LOST_DUEL") % contested_plot.owner_name
					show_plot_info(contested_plot)
	)
	minigame.start_minigame(plot, plot.owner_name, npc_agent, auction_system)

# ============================================================================
# REVIEW PHASE — player confirms plot or challenges NPCs
# ============================================================================

## Called after all NPCs have picked. Unlocks the map so the player can
## challenge rival plots, then waits for the "Confirm" button.
func _enter_review_phase() -> void:
	_in_review_phase = true
	npc_turn_active = false
	info_label.text = tr("REVIEW_PHASE_HINT")
	_show_proceed_button()

func _show_proceed_button() -> void:
	if _proceed_button:
		return
	_proceed_button = Button.new()
	_proceed_button.text = tr("CONFIRM_PLOT_BTN")
	var style: StyleBoxFlat = UITheme.action_button_style()
	style.border_color = UITheme.COLOR_GOLD_BRIGHT
	_proceed_button.add_theme_stylebox_override("normal", style)
	_proceed_button.add_theme_font_size_override("font_size", 16)
	_proceed_button.custom_minimum_size = Vector2(200, 48)
	_proceed_button.anchor_left = 1.0
	_proceed_button.anchor_top = 1.0
	_proceed_button.anchor_right = 1.0
	_proceed_button.anchor_bottom = 1.0
	_proceed_button.offset_left = -220.0
	_proceed_button.offset_top = -84.0
	_proceed_button.offset_right = -20.0
	_proceed_button.offset_bottom = -20.0
	_proceed_button.focus_mode = Control.FOCUS_NONE
	_proceed_button.pressed.connect(_on_proceed_pressed)
	$UILayer.add_child(_proceed_button)

func _on_proceed_pressed() -> void:
	if _proceed_button:
		_proceed_button.queue_free()
		_proceed_button = null
	_in_review_phase = false
	npc_turn_active = true
	if _shop_button:
		_shop_button.disabled = true
	var plot_to_mine := _get_player_owned_plot()
	if plot_to_mine:
		await get_tree().create_timer(0.4).timeout
		EventBus.auction_won.emit(plot_to_mine)

## Finds the plot currently owned by the player in the available_plots pool.
func _get_player_owned_plot() -> PlotData:
	for plot in auction_system.available_plots:
		if plot.owner_type == PlotData.OwnerType.PLAYER:
			return plot
	return null

# ============================================================================
# NPC CHALLENGE PHASE (NPC-initiated)
# ============================================================================

## Before NPCs pick their own plots, each rival evaluates whether the player's
## plot is better than anything still available. If so — and their challenge_chance
## passes — they contest the player first. A loser falls back to a normal pick;
## a winner skips the normal pick (start_npc_turn skips agents with owned_plot).
func _run_npc_pre_challenge_phase() -> void:
	for agent in auction_system.npc_agents:
		# Stop if player lost an earlier challenge (no plot to contest)
		if not selected_plot or selected_plot.owner_type != PlotData.OwnerType.PLAYER:
			break
		# Find the richest plot this agent could afford from the open market
		var best_available_richness: float = 0.0
		for plot in auction_system.available_plots:
			if plot.owner_type == PlotData.OwnerType.AVAILABLE and agent.budget >= plot.base_price:
				best_available_richness = maxf(best_available_richness, plot.gold_richness)
		# Only challenge if the player's plot is notably richer than anything available
		if selected_plot.gold_richness <= best_available_richness * 1.1:
			continue
		if randf() > agent.challenge_chance:
			continue
		# Announce the incoming challenge
		info_label.text = tr("NPC_PRE_CHALLENGE") % agent.agent_name
		_flash_npc_entry(agent.agent_name)
		await get_tree().create_timer(1.2).timeout
		await _npc_initiates_challenge(agent)

## NPC challenges the player for their currently selected plot via RPS.
## Awaits _npc_challenge_resolved (a signal on self) to avoid the GDScript-4
## primitive-capture-by-value bug that breaks while-flag polling in lambdas.
func _npc_initiates_challenge(agent) -> void:
	if not selected_plot or selected_plot.owner_type != PlotData.OwnerType.PLAYER:
		return

	minigame_active = true
	bid_button.disabled = true
	var contested := selected_plot

	var minigame = MinigameRPSScript.new()
	$UILayer.add_child(minigame)
	minigame.minigame_finished.connect(
		func(player_won: bool, result_plot: PlotData):
			minigame.queue_free()
			minigame_active = false
			# Escalate the plot price to reflect it was contested
			result_plot.base_price = int(result_plot.base_price * 1.3)
			if player_won:
				info_label.text = tr("DEFENDED_PLOT") % result_plot.plot_name
				show_plot_info(result_plot)
			else:
				# Release the NPC's old plot back to available pool
				if agent.owned_plot and agent.owned_plot != result_plot:
					var released: PlotData = agent.owned_plot
					released.owner_type = PlotData.OwnerType.AVAILABLE
					released.owner_name = ""
					map_controller.refresh_plot_visuals(released)
				# NPC takes the player's plot
				result_plot.owner_type = PlotData.OwnerType.NPC
				result_plot.owner_name = agent.agent_name
				agent.owned_plot = result_plot
				map_controller.refresh_plot_visuals(result_plot)
				selected_plot = null
				info_label.text = tr("NPC_TOOK_PLOT") % agent.agent_name
			_npc_challenge_resolved.emit()
	)
	minigame.start_minigame(contested, agent.agent_name, agent, auction_system, true)
	await _npc_challenge_resolved

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

	# ---- PLAYER ENTRY (top) ----
	var you_header = Label.new()
	you_header.text = tr("YOU")
	you_header.add_theme_font_size_override("font_size", 11)
	you_header.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	you_header.custom_minimum_size = Vector2(0, 18)
	if UITheme.font_heading:
		you_header.add_theme_font_override("font", UITheme.font_heading)
	vbox.add_child(you_header)

	vbox.add_child(_create_player_card())

	var sep_top = HSeparator.new()
	sep_top.add_theme_color_override("color", Color(UITheme.COLOR_GOLD_PRIMARY, 0.4))
	sep_top.add_theme_constant_override("separation", 8)
	vbox.add_child(sep_top)

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

## Builds the circular avatar Control with a given texture and color.
## Pass flip=true for NPC sprites that face right and need mirroring toward the map.
func _build_avatar(tex: Texture2D, color: Color, flip: bool = true) -> Control:
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
	# Store style as metadata so callers can animate the border color
	avatar.set_meta("bg_style", avatar_style)

	if tex:
		var avatar_tex := TextureRect.new()
		avatar_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		avatar_tex.texture = tex
		avatar_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		avatar_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		avatar_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Circle clip shader; NPC sprites face right so they need horizontal flip
		var u_x := "1.0 - UV.x" if flip else "UV.x"
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tif (length(uv) > 0.5) { discard; }\n\tCOLOR = texture(TEXTURE, vec2(%s, UV.y));\n}" % u_x
		var mat := ShaderMaterial.new()
		mat.shader = shader
		avatar_tex.material = mat
		avatar.add_child(avatar_tex)
	else:
		var initial_lbl := Label.new()
		initial_lbl.text = "?"
		initial_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		initial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		initial_lbl.add_theme_font_size_override("font_size", 22)
		initial_lbl.add_theme_color_override("font_color", color.lightened(0.4))
		initial_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(initial_lbl)

	return avatar

## Builds the player card shown at the top of the roster
func _create_player_card() -> PanelContainer:
	var color := Color(1.0, 0.85, 0.2)

	var container = PanelContainer.new()
	var entry_style = StyleBoxFlat.new()
	entry_style.bg_color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.08, 0.9)
	entry_style.set_corner_radius_all(8)
	entry_style.border_width_left = 3
	entry_style.border_color = Color(color.r, color.g, color.b, 0.7)
	entry_style.content_margin_left = 10
	entry_style.content_margin_right = 10
	entry_style.content_margin_top = 10
	entry_style.content_margin_bottom = 10
	container.add_theme_stylebox_override("panel", entry_style)
	container.clip_contents = false

	# Outer VBox: [avatar row] + [bank button]
	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	container.add_child(outer_vbox)

	# Top row: avatar + name/money column
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	outer_vbox.add_child(hbox)

	var tex: Texture2D = load("res://assets/sprites/Prota/Prota_profile.png") as Texture2D
	var avatar := _build_avatar(tex, color, false)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(avatar)

	var info_col = VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 4)
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(info_col)

	var name_lbl = Label.new()
	name_lbl.text = tr("PLAYER_YOU")
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", color.lightened(0.3))
	if UITheme.font_heading:
		name_lbl.add_theme_font_override("font", UITheme.font_heading)
	info_col.add_child(name_lbl)

	var budget_lbl = Label.new()
	budget_lbl.text = "$ %d" % GameManager.player_money
	budget_lbl.add_theme_font_size_override("font_size", 13)
	budget_lbl.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)
	info_col.add_child(budget_lbl)
	_player_budget_lbl = budget_lbl

	# Debt label — only visible when player has a loan
	_player_debt_lbl = Label.new()
	_player_debt_lbl.add_theme_font_size_override("font_size", 11)
	_player_debt_lbl.add_theme_color_override("font_color", UITheme.COLOR_DANGER)
	info_col.add_child(_player_debt_lbl)
	_refresh_debt_label(GameManager.current_debt)

	# Bank button — full-width row below avatar + info
	_bank_button = Button.new()
	_bank_button.text = "Bank"
	_bank_button.add_theme_stylebox_override("normal", UITheme.action_button_style())
	_bank_button.custom_minimum_size = Vector2(0, 32)
	_bank_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bank_button.pressed.connect(_on_bank_pressed)
	outer_vbox.add_child(_bank_button)
	_refresh_bank_button()

	return container

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

	# Avatar — circular portrait, flipped to face the map (same direction as NPCs look)
	var img_path: String = Config.NPC_IMAGES.get(npc_name, "")
	var tex: Texture2D = load(img_path) as Texture2D if not img_path.is_empty() else null
	var avatar := _build_avatar(tex, color)

	# Fallback initial letter when no image
	if not tex:
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

	# Store entry for later updates (avatar_style accessed via avatar.get_meta("bg_style"))
	npc_entries[npc_name] = {
		"container": container,
		"entry_style": entry_style,
		"avatar": avatar,
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

	var avatar_style: StyleBoxFlat = entry["avatar"].get_meta("bg_style") as StyleBoxFlat

	if active:
		# Bright highlight when actively considering
		entry["status_lbl"].add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
		entry["entry_style"].bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 1.0)
		entry["entry_style"].border_color = Color(color.r, color.g, color.b, 1.0)
		if avatar_style:
			avatar_style.border_color = UITheme.COLOR_GOLD_BRIGHT
		# Pulse tween on avatar
		var tween = entry["container"].create_tween().set_loops(4)
		tween.tween_property(entry["avatar"], "modulate", Color(1.3, 1.2, 1.0), 0.3).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(entry["avatar"], "modulate", Color.WHITE, 0.3).set_ease(Tween.EASE_IN_OUT)
	elif claimed:
		# Dimmed when done
		entry["status_lbl"].add_theme_color_override("font_color", Color(0.50, 0.75, 0.50))
		entry["entry_style"].bg_color = Color(color.r * 0.10, color.g * 0.10, color.b * 0.10, 0.7)
		entry["entry_style"].border_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.4)
		if avatar_style:
			avatar_style.border_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.6)
		entry["avatar"].modulate = Color(0.7, 0.7, 0.7)
	else:
		entry["status_lbl"].add_theme_color_override("font_color", Color(0.55, 0.50, 0.42))
		entry["entry_style"].bg_color = Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.8)
		entry["entry_style"].border_color = Color(color.r, color.g, color.b, 0.5)
		if avatar_style:
			avatar_style.border_color = Color(color.r, color.g, color.b, 0.8)
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

## Update the debt label visibility/text on the player card
func _refresh_debt_label(debt: int) -> void:
	if not _player_debt_lbl:
		return
	if debt > 0:
		_player_debt_lbl.text = "Debt: $ %d" % debt
		_player_debt_lbl.visible = true
	else:
		_player_debt_lbl.text = ""
		_player_debt_lbl.visible = false

## Bank is always available during auction; emphasize it when the player is strapped or in debt.
func _refresh_bank_button() -> void:
	if not _bank_button:
		return
	_bank_button.visible = true
	var strapped: bool = GameManager.player_money < Config.MIN_PLOT_PRICE * 2
	var has_debt: bool = GameManager.current_debt > 0
	# Highlight gold when actionable, dim when not
	_bank_button.modulate = Color(1.0, 0.95, 0.6) if (strapped or has_debt) else Color.WHITE

func _on_debt_changed(debt: int) -> void:
	_refresh_debt_label(debt)
	_refresh_bank_button()

func _on_bank_pressed() -> void:
	var dialog: Control = LoanDialogScript.new()
	$UILayer.add_child(dialog)

func _on_npc_stole_plot(plot: PlotData, thief: String, victim: String) -> void:
	info_label.text = "%s stole %s from %s!" % [thief, plot.plot_name, victim]
	if map_controller:
		map_controller.refresh_plot_visuals(plot)
	# Update roster: thief now owns the plot (active flash), victim loses it
	_set_npc_status(thief, "Stole %s" % plot.plot_name, false, true)
	_set_npc_status(victim, "Lost their plot!", false, false)
	_flash_npc_entry(victim)
	_flash_npc_entry(thief)

## Returns the initials of an NPC name (e.g. "Big Bob" → "BB")
func _get_initials(npc_name: String) -> String:
	var parts = npc_name.split(" ")
	var result = ""
	for part in parts:
		if part.length() > 0:
			result += part[0].to_upper()
	return result
