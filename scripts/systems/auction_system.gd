extends Node
class_name AuctionSystem

## Manages plot generation, bidding logic, and NPC AI

# ============================================================================
# NPC AUCTION AGENT
# ============================================================================

## NPC agent for autonomous plot selection
class NPCAuctionAgent:
	var agent_name: String
	var budget: int
	var aggression: float  # 0.0-1.0
	var preferred_richness: float  # Bias for rich/poor plots
	var owned_plot: PlotData = null

	func _init(name: String, round: int):
		agent_name = name
		budget = randi_range(500, 1500)
		aggression = 0.2 + (round * 0.05)  # Scales with round
		aggression = clamp(aggression, 0.2, 0.8)
		preferred_richness = randf_range(0.3, 1.3)

	## Calculate interest score for a plot (0.0-1.0)
	func evaluate_plot(plot: PlotData) -> float:
		if not plot.is_biddable():
			return 0.0

		# Can't afford check
		if budget < plot.base_price:
			return 0.0

		# Richness match score
		var richness_match = 1.0 - abs(plot.gold_richness - preferred_richness)

		# Affordability factor
		var afford_factor = 1.0 - (float(plot.base_price) / budget)

		return (richness_match * 0.6 + afford_factor * 0.4) * aggression

# ============================================================================
# SIGNALS
# ============================================================================

signal plots_generated(plots: Array[PlotData])
signal npc_claimed_plot(plot_data: PlotData, npc_name: String)

# ============================================================================
# DATA
# ============================================================================

var available_plots: Array[PlotData] = []
var npc_agents: Array[NPCAuctionAgent] = []
var plot_names: Array[String] = [
	"Sunset Valley", "Golden Hills", "Copper Creek",
	"Silver Ridge", "Fortune Flats", "Nugget Gorge",
	"Prospector's Peak", "Eureka Basin", "Lucky Strike",
	"El Dorado Plains"
]

# ============================================================================
# PLOT GENERATION
# ============================================================================

## Generate random plots for auction in grid layout
## @return Array of PlotData resources
func generate_plots() -> Array[PlotData]:
	available_plots.clear()

	var plot_idx = 0
	for row in range(Config.AUCTION_MAP_ROWS):
		for col in range(Config.AUCTION_MAP_COLS):
			var plot: PlotData = PlotData.new()
			plot.plot_id = plot_idx
			plot.grid_position = Vector2i(col, row)
			plot.plot_name = plot_names[randi() % plot_names.size()]
			plot.terrain_seed = randi()
			plot.gold_richness = randf_range(0.5, 1.5)

			# Price based on richness
			plot.base_price = int(100 + (plot.gold_richness * 300))
			plot.base_price = clampi(plot.base_price, Config.MIN_PLOT_PRICE, Config.MAX_PLOT_PRICE)

			plot.final_bid_price = plot.base_price
			plot.owner_type = PlotData.OwnerType.AVAILABLE

			available_plots.append(plot)
			plot_idx += 1

	_create_npc_agents()

	print("[AuctionSystem] Emitting plots_generated signal with %d plots" % available_plots.size())
	plots_generated.emit(available_plots)
	return available_plots

# ============================================================================
# BIDDING
# ============================================================================

## Simulate NPC bidding on a plot
## @param current_bid: Current highest bid
## @param plot: The plot being bid on
## @param round_number: Current game round (affects aggression)
## @return New bid amount (same as current if NPC doesn't outbid)
func simulate_npc_bid(current_bid: int, plot: PlotData, round_number: int) -> int:
	var aggression: float = Config.get_npc_aggression(round_number)

	# Higher richness = more NPC interest
	var richness_factor: float = plot.gold_richness * 0.3
	var outbid_chance: float = aggression + richness_factor

	if randf() < outbid_chance:
		var increment: int = randi_range(50, 150)
		return current_bid + increment

	return current_bid

## Process player bid on plot
## @param plot: Selected plot
## @param player_bid: Amount player is willing to pay
## @param round_number: Current round
## @return Dictionary: {won: bool, final_price: int}
func process_bid(plot: PlotData, player_bid: int, round_number: int) -> Dictionary:
	if not GameManager.can_afford(player_bid):
		return {won = false, final_price = player_bid, reason = "Insufficient funds"}

	# Simulate NPC counter-bid
	var npc_bid: int = simulate_npc_bid(player_bid, plot, round_number)

	if npc_bid > player_bid:
		return {won = false, final_price = npc_bid, reason = "Outbid by NPC"}

	# Player wins
	plot.final_bid_price = player_bid
	return {won = true, final_price = player_bid, reason = "Auction won!"}

# ============================================================================
# NPC TURN SYSTEM
# ============================================================================

## Create NPC agents for the auction
func _create_npc_agents() -> void:
	npc_agents.clear()
	for i in range(Config.NPC_COUNT_PER_AUCTION):
		var agent = NPCAuctionAgent.new(Config.NPC_NAMES[i], GameManager.round_number)
		npc_agents.append(agent)

## NPCs select plots in sequence with visual delay
func start_npc_turn() -> void:
	for agent in npc_agents:
		if agent.owned_plot:
			continue  # Already owns a plot

		# Find best available plot
		var best_plot: PlotData = null
		var best_score: float = -1.0

		for plot in available_plots:
			var score = agent.evaluate_plot(plot)
			if score > best_score:
				best_score = score
				best_plot = plot

		# Claim plot if score exceeds threshold
		if best_plot and best_score > 0.3:
			_npc_claim_plot(agent, best_plot)
			await get_tree().create_timer(Config.NPC_BID_DELAY).timeout

## NPC claims a plot
func _npc_claim_plot(agent: NPCAuctionAgent, plot: PlotData) -> void:
	plot.owner_type = PlotData.OwnerType.NPC
	plot.owner_name = agent.agent_name
	plot.final_bid_price = plot.base_price
	agent.owned_plot = plot

	npc_claimed_plot.emit(plot, agent.agent_name)
	print("[Auction] %s reivindicou %s por $%d" % [agent.agent_name, plot.plot_name, plot.base_price])
