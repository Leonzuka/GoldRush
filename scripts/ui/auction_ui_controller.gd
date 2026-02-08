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

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("auction_ui")

	# Connect signals
	EventBus.money_changed.connect(_on_money_changed)
	bid_button.pressed.connect(_on_bid_button_pressed)

	# Create auction system
	auction_system = AuctionSystem.new()
	auction_system.add_to_group("auction_system")
	auction_system.npc_claimed_plot.connect(_on_npc_claimed_plot)
	add_child(auction_system)

	# Update UI initial state
	title_label.text = "Leilão de Terras - Rodada %d" % GameManager.round_number
	displayed_money = GameManager.player_money
	money_label.text = "Orçamento: $%d" % displayed_money
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
	info_label.text = "NPCs estão escolhendo seus terrenos..."
	auction_system.start_npc_turn()

	# Wait for NPCs to finish (NPC_BID_DELAY * NPC_COUNT_PER_AUCTION)
	await get_tree().create_timer(Config.NPC_BID_DELAY * Config.NPC_COUNT_PER_AUCTION + 0.5).timeout
	info_label.text = "Sua vez! Selecione um terreno disponível."

# ============================================================================
# PLOT SELECTION
# ============================================================================

## Called when player selects a plot on the map
func show_plot_info(plot: PlotData) -> void:
	selected_plot = plot
	info_panel.visible = true

	plot_name_label.text = plot.plot_name
	richness_label.text = "★".repeat(plot.get_star_rating()) + " " + plot.get_richness_tier()
	price_label.text = "Lance inicial: $%d" % plot.base_price

	if plot.owner_type == PlotData.OwnerType.NPC:
		status_label.text = "Pertence a: %s" % plot.owner_name
		bid_button.disabled = true
		bid_button.text = "Indisponível"
	else:
		status_label.text = "Disponível"
		bid_button.disabled = not GameManager.can_afford(plot.base_price)
		bid_button.text = "Fazer Lance" if not bid_button.disabled else "Sem Fundos"

# ============================================================================
# BIDDING
# ============================================================================

func _on_bid_button_pressed() -> void:
	if not selected_plot or not selected_plot.is_biddable():
		return

	var bid_price = selected_plot.base_price

	if not GameManager.can_afford(bid_price):
		info_label.text = "Fundos insuficientes!"
		return

	# Claim plot
	selected_plot.owner_type = PlotData.OwnerType.PLAYER
	selected_plot.final_bid_price = bid_price

	# Visual feedback
	info_label.text = "Terreno adquirido por $%d!" % bid_price
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
		money_label.text = "Orçamento: $%d" % displayed_money
	, float(old_amount), float(new_amount), duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	var flash_color := Color(0.3, 1.0, 0.3) if gained else Color(1.0, 0.3, 0.3)
	var color_tween := create_tween()
	color_tween.tween_property(money_label, "modulate", flash_color, 0.1)
	color_tween.tween_property(money_label, "modulate", Color.WHITE, 0.4)

func _on_npc_claimed_plot(plot: PlotData, npc_name: String) -> void:
	"""Visual feedback when NPC claims a plot"""
	info_label.text = "%s reivindicou %s" % [npc_name, plot.plot_name]
	map_controller.refresh_plot_visuals(plot)
