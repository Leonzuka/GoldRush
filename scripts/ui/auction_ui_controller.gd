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

# NPC avatar panel (created in code)
var npc_panel: PanelContainer
var npc_avatar_label: Label
var npc_name_label: Label
var npc_status_label: Label
var npc_panel_tween: Tween

# NPC avatar colors matching their personality
const NPC_COLORS: Dictionary = {
	"Big Bob":   Color(0.9, 0.5, 0.1),
	"Sly Sally": Color(0.6, 0.2, 0.8),
	"Mad Max":   Color(0.9, 0.15, 0.15),
}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("auction_ui")

	_apply_auction_styles()

	# Connect signals
	EventBus.money_changed.connect(_on_money_changed)
	bid_button.pressed.connect(_on_bid_button_pressed)

	# Build NPC avatar panel
	_create_npc_panel()

	# Create auction system
	auction_system = AuctionSystem.new()
	auction_system.add_to_group("auction_system")
	auction_system.npc_claimed_plot.connect(_on_npc_claimed_plot)
	auction_system.npc_considering_plot.connect(_on_npc_considering_plot)
	auction_system.npc_turn_finished.connect(_on_npc_turn_finished)
	add_child(auction_system)

	# Update UI initial state
	title_label.text = "Land Auction - Round %d" % GameManager.round_number
	displayed_money = GameManager.player_money
	money_label.text = "Budget: $%d" % displayed_money
	info_panel.visible = false

	# CRITICAL: Wait for IsometricMapController to be ready and connected
	print("[AuctionUI] Waiting for map controller to connect...")
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame to ensure connection

	# NOW generate plots (map is listening)
	print("[AuctionUI] Generating plots...")
	var plots = auction_system.generate_plots()

	# Wait for map to load, then start NPC turn
	await get_tree().create_timer(1.5).timeout
	info_label.text = "NPCs are choosing their plots..."
	auction_system.start_npc_turn()
	# "Your turn!" message is set by _on_npc_turn_finished when all NPCs finish

func _apply_auction_styles() -> void:
	# Info panel — modal style
	info_panel.add_theme_stylebox_override("panel", UITheme.modal_style())

	# Title labels with heading font
	if UITheme.font_heading:
		title_label.add_theme_font_override("font", UITheme.font_heading)
		plot_name_label.add_theme_font_override("font", UITheme.font_heading)
	title_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	plot_name_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	plot_name_label.add_theme_font_size_override("font_size", 20)

	# Richness accent color
	richness_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_PRIMARY)

	# Bid button
	bid_button.add_theme_stylebox_override("normal", UITheme.action_button_style())

# ============================================================================
# PLOT SELECTION
# ============================================================================

## Called when player selects a plot on the map
func show_plot_info(plot: PlotData) -> void:
	selected_plot = plot
	info_panel.visible = true

	plot_name_label.text = plot.plot_name
	richness_label.text = "★".repeat(plot.get_star_rating()) + " " + plot.get_richness_tier()
	price_label.text = "Starting Bid: $%d" % plot.base_price

	if plot.owner_type == PlotData.OwnerType.NPC:
		status_label.text = "Owned by: %s" % plot.owner_name
		bid_button.disabled = true
		bid_button.text = "Unavailable"
	else:
		status_label.text = "Available"
		bid_button.disabled = not GameManager.can_afford(plot.base_price)
		bid_button.text = "Place Bid" if not bid_button.disabled else "No Funds"

# ============================================================================
# BIDDING
# ============================================================================

func _on_bid_button_pressed() -> void:
	if not selected_plot or not selected_plot.is_biddable():
		return

	var bid_price = selected_plot.base_price

	if not GameManager.can_afford(bid_price):
		info_label.text = "Insufficient funds!"
		return

	# Claim plot
	selected_plot.owner_type = PlotData.OwnerType.PLAYER
	selected_plot.final_bid_price = bid_price

	# Visual feedback
	info_label.text = "Plot acquired for $%d!" % bid_price
	info_panel.visible = false
	map_controller.refresh_plot_visuals(selected_plot)

	# Transition to mining
	await get_tree().create_timer(1.5).timeout
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
		money_label.text = "Budget: $%d" % displayed_money
	, float(old_amount), float(new_amount), duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	var flash_color := Color(0.3, 1.0, 0.3) if gained else Color(1.0, 0.3, 0.3)
	var color_tween := create_tween()
	color_tween.tween_property(money_label, "modulate", flash_color, 0.1)
	color_tween.tween_property(money_label, "modulate", Color.WHITE, 0.4)

func _on_npc_claimed_plot(plot: PlotData, npc_name: String) -> void:
	info_label.text = "%s claimed %s" % [npc_name, plot.plot_name]
	map_controller.refresh_plot_visuals(plot)

func _on_npc_considering_plot(plot: PlotData, npc_name: String) -> void:
	_show_npc_panel(npc_name, plot.plot_name)

func _on_npc_turn_finished() -> void:
	_hide_npc_panel()
	info_label.text = "Your turn! Select an available plot."

# ============================================================================
# NPC AVATAR PANEL
# ============================================================================

## Builds the NPC avatar floating panel (bottom-left of screen)
func _create_npc_panel() -> void:
	npc_panel = PanelContainer.new()
	npc_panel.visible = false
	npc_panel.custom_minimum_size = Vector2(200, 80)
	npc_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	npc_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	npc_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	npc_panel.add_theme_stylebox_override("panel", UITheme.npc_panel_style())

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	npc_panel.add_child(hbox)

	# Avatar circle (Label styled as a colored circle)
	npc_avatar_label = Label.new()
	npc_avatar_label.custom_minimum_size = Vector2(52, 52)
	npc_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	npc_avatar_label.add_theme_font_size_override("font_size", 22)

	var avatar_style = StyleBoxFlat.new()
	avatar_style.bg_color = UITheme.COLOR_SURFACE_LIGHT
	avatar_style.set_corner_radius_all(26)
	avatar_style.set_border_width_all(2)
	avatar_style.border_color = Color(UITheme.COLOR_GOLD_PRIMARY.r, UITheme.COLOR_GOLD_PRIMARY.g, UITheme.COLOR_GOLD_PRIMARY.b, 0.8)
	npc_avatar_label.add_theme_stylebox_override("normal", avatar_style)
	hbox.add_child(npc_avatar_label)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	npc_name_label = Label.new()
	npc_name_label.add_theme_font_size_override("font_size", 13)
	npc_name_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	vbox.add_child(npc_name_label)

	npc_status_label = Label.new()
	npc_status_label.add_theme_font_size_override("font_size", 11)
	npc_status_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_MUTED)
	npc_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	npc_status_label.custom_minimum_size = Vector2(120, 0)
	vbox.add_child(npc_status_label)

	$UILayer.add_child(npc_panel)

## Shows the NPC avatar panel with a slide-in animation
func _show_npc_panel(npc_name: String, plot_name: String) -> void:
	var color = NPC_COLORS.get(npc_name, Color(0.4, 0.6, 0.9))
	var initials = _get_initials(npc_name)

	npc_name_label.text = npc_name
	npc_status_label.text = "Eyeing \"%s\"..." % plot_name
	npc_avatar_label.text = initials
	npc_avatar_label.add_theme_color_override("font_color", color.lightened(0.3))

	# Tint avatar border with NPC color
	var avatar_style = npc_avatar_label.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	avatar_style.border_color = color
	npc_avatar_label.add_theme_stylebox_override("normal", avatar_style)

	if npc_panel_tween and npc_panel_tween.is_valid():
		npc_panel_tween.kill()

	# Reset anchor position, then slide in from below
	npc_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	npc_panel.position.y += 20
	npc_panel.visible = true
	npc_panel.modulate = Color(1, 1, 1, 0)

	var target_y = npc_panel.position.y - 20
	npc_panel_tween = create_tween().set_parallel(true)
	npc_panel_tween.tween_property(npc_panel, "modulate", Color.WHITE, 0.25).set_ease(Tween.EASE_OUT)
	npc_panel_tween.tween_property(npc_panel, "position:y", target_y, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## Hides the NPC avatar panel with a fade-out
func _hide_npc_panel() -> void:
	if not npc_panel or not npc_panel.visible:
		return

	if npc_panel_tween and npc_panel_tween.is_valid():
		npc_panel_tween.kill()

	npc_panel_tween = create_tween()
	npc_panel_tween.tween_property(npc_panel, "modulate", Color(1, 1, 1, 0), 0.3).set_ease(Tween.EASE_IN)
	npc_panel_tween.tween_callback(func(): npc_panel.visible = false)

## Returns the initials of an NPC name (e.g. "Big Bob" → "BB")
func _get_initials(npc_name: String) -> String:
	var parts = npc_name.split(" ")
	var result = ""
	for part in parts:
		if part.length() > 0:
			result += part[0].to_upper()
	return result
