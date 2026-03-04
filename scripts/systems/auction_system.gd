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
	var aggression: float  # 0.0-1.0, scales with round
	var personality: String
	var richness_bias: float
	var claim_threshold: float
	var rps_weights: Array        # [rock_w, paper_w, scissors_w]
	var sabotage_chance: float
	var challenge_chance: float
	var owned_plot: PlotData = null

	func _init(name: String, round_num: int):
		agent_name = name
		var profile = Config.NPC_PROFILES.get(name, {})
		budget = randi_range(
			profile.get("budget_min", 500),
			profile.get("budget_max", 1500)
		)
		personality = profile.get("personality", "balanced")
		richness_bias = profile.get("richness_bias", 1.0)
		claim_threshold = profile.get("claim_threshold", 0.3)
		rps_weights = profile.get("rps_weights", [0.33, 0.34, 0.33])
		sabotage_chance = profile.get("sabotage_chance", 0.1)
		challenge_chance = profile.get("challenge_chance", 0.5)
		aggression = clamp(0.2 + (round_num * 0.05), 0.2, 0.8)

	## Calculate interest score for a plot (0.0-1.0) based on personality
	## @param player_last_viewed: passed so Cunning can target the player's interest
	func evaluate_plot(plot: PlotData, player_last_viewed: PlotData = null) -> float:
		if not plot.is_biddable():
			return 0.0
		if budget < plot.base_price:
			return 0.0

		var richness_match: float = clamp(1.0 - abs(plot.gold_richness - richness_bias), 0.0, 1.0)
		var afford_factor: float = 1.0 - (float(plot.base_price) / float(budget))

		match personality:
			"conservative":
				var score = richness_match * 0.4 + afford_factor * 0.6
				if float(plot.base_price) < float(budget) * 0.5:
					score += 0.1
				return score
			"aggressive":
				if plot.gold_richness > 1.2:
					return richness_match * 0.95  # Ignore affordability for rich plots
				return richness_match * 0.8 + afford_factor * 0.2
			"cunning":
				var score = richness_match * 0.6 + afford_factor * 0.4
				if player_last_viewed != null and plot == player_last_viewed:
					score += 0.25  # Targets whatever the player is interested in
				return score
			"smart":
				return richness_match * 0.55 + afford_factor * 0.45
			_:
				return richness_match * 0.6 + afford_factor * 0.4

	## Pick an RPS move; Smart personality counter-plays the player's last choice
	## @param player_history: Array of player's past choices ["rock", "paper", ...]
	func get_rps_choice(player_history: Array) -> String:
		if personality == "smart" and player_history.size() >= 2:
			var last = player_history[-1]
			var counter := {"rock": "paper", "paper": "scissors", "scissors": "rock"}
			return counter.get(last, "rock")
		# Weighted random based on rps_weights [rock, paper, scissors]
		var roll := randf()
		if roll < rps_weights[0]:
			return "rock"
		elif roll < rps_weights[0] + rps_weights[1]:
			return "paper"
		else:
			return "scissors"

# ============================================================================
# SIGNALS
# ============================================================================

signal plots_generated(plots: Array[PlotData])
signal npc_claimed_plot(plot_data: PlotData, npc_name: String)
signal npc_considering_plot(plot_data: PlotData, npc_name: String)
signal npc_turn_finished()

# ============================================================================
# DATA
# ============================================================================

var available_plots: Array[PlotData] = []
var npc_agents: Array[NPCAuctionAgent] = []

## Updated by auction_ui_controller when player views a plot (for Cunning sabotage)
var player_last_viewed_plot: PlotData = null

## Tracks player's RPS choices so Lily can counter-learn
var player_rps_history: Array = []

var plot_names: Array[String] = [
	"Sunset Valley", "Golden Hills", "Copper Creek",
	"Silver Ridge", "Fortune Flats", "Nugget Gorge",
	"Prospector's Peak", "Eureka Basin", "Lucky Strike",
	"El Dorado Plains", "Jackpot Ridge", "Thunder Gulch",
	"Diamond Hollow", "Old Dutch Mine"
]

# ============================================================================
# PLOT GENERATION
# ============================================================================

## Generate random plots for auction in grid layout
## @return Array of PlotData resources
func generate_plots() -> Array[PlotData]:
	available_plots.clear()

	# Shuffle names so each plot gets a unique one (pool has 14, need 12)
	var shuffled_names = plot_names.duplicate()
	shuffled_names.shuffle()

	var plot_idx = 0
	for row in range(Config.AUCTION_MAP_ROWS):
		for col in range(Config.AUCTION_MAP_COLS):
			var plot: PlotData = PlotData.new()
			plot.plot_id = plot_idx
			plot.grid_position = Vector2i(col, row)
			plot.plot_name = shuffled_names[plot_idx % shuffled_names.size()]
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
# BIDDING (legacy path — used for available-plot bids)
# ============================================================================

## Simulate NPC bidding on a plot
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
## @return Dictionary: {won: bool, final_price: int, reason: String}
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

## NPCs select plots in sequence with visual delay, then run sabotage events
func start_npc_turn() -> void:
	for agent in npc_agents:
		if agent.owned_plot:
			continue  # Already owns a plot

		# Find best available plot using personality-weighted evaluation
		var best_plot: PlotData = null
		var best_score: float = -1.0

		for plot in available_plots:
			var score = agent.evaluate_plot(plot, player_last_viewed_plot)
			if score > best_score:
				best_score = score
				best_plot = plot

		# Claim plot only if score meets this agent's threshold
		if best_plot and best_score > agent.claim_threshold:
			npc_considering_plot.emit(best_plot, agent.agent_name)
			await get_tree().create_timer(Config.NPC_BID_DELAY * 0.65).timeout
			_npc_claim_plot(agent, best_plot)
			await get_tree().create_timer(Config.NPC_BID_DELAY * 0.35).timeout

	# Small delay ensures the signal is never emitted synchronously before callers can await it
	await get_tree().process_frame
	npc_turn_finished.emit()

## NPC claims a plot, updating ownership and emitting signal
func _npc_claim_plot(agent: NPCAuctionAgent, plot: PlotData) -> void:
	plot.owner_type = PlotData.OwnerType.NPC
	plot.owner_name = agent.agent_name
	plot.final_bid_price = plot.base_price
	agent.owned_plot = plot

	npc_claimed_plot.emit(plot, agent.agent_name)
	print("[Auction] %s claimed %s for $%d" % [agent.agent_name, plot.plot_name, plot.base_price])

## Returns the NPCAuctionAgent with the given name, or null
func get_agent_by_name(search_name: String) -> NPCAuctionAgent:
	for agent in npc_agents:
		if agent.agent_name == search_name:
			return agent
	return null
