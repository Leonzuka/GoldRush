extends Node

## Central game state machine and session data manager
## Orchestrates scene transitions and persistence

# ============================================================================
# ENUMS
# ============================================================================

enum GameState {
	MAIN_MENU,
	AUCTION,
	MINING,
	ROUND_END
}

# ============================================================================
# SESSION DATA
# ============================================================================

var current_state: GameState = GameState.MAIN_MENU
var player_money: int = Config.STARTING_MONEY
var round_number: int = 1
var current_plot: Resource = null  # PlotData
var total_gold_collected: int = 0
var session_history: Array[Dictionary] = []  # Stats per round

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect to relevant signals
	EventBus.auction_won.connect(_on_auction_won)
	EventBus.round_ended.connect(_on_round_ended)

func _input(event: InputEvent) -> void:
	# Debug mode toggle
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		var debug_mode: bool = !ProjectSettings.get_setting("debug/gdscript/warnings/enable", false)
		EventBus.debug_mode_changed.emit(debug_mode)

	# Cheat: Add money (dev only)
	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			change_money(1000)
			print("[CHEAT] Added $1000")

# ============================================================================
# STATE TRANSITIONS
# ============================================================================

## Initialize new game session
func start_new_game() -> void:
	player_money = Config.STARTING_MONEY
	round_number = 1
	total_gold_collected = 0
	session_history.clear()
	current_plot = null

	transition_to_state(GameState.AUCTION)
	transition_to_auction()

## Transition to auction phase
func transition_to_auction() -> void:
	current_state = GameState.AUCTION
	EventBus.auction_started.emit()
	get_tree().change_scene_to_file("res://scenes/auction/auction.tscn")

## Start mining session with won plot
func start_mining_session(plot: Resource) -> void:
	current_plot = plot
	current_state = GameState.MINING
	print("[GameManager] Starting mining session with plot: %s" % plot.plot_name)
	get_tree().change_scene_to_file("res://scenes/mining/mining_scene.tscn")

	# Wait for scene to load and all nodes to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for safety
	print("[GameManager] Scene loaded, emitting mining_started signal")
	EventBus.mining_started.emit(plot)

## Transition to round end summary
func show_round_end(stats: Dictionary) -> void:
	current_state = GameState.ROUND_END
	# For MVP, immediately transition back to auction
	# Future: Show summary panel
	await get_tree().create_timer(0.5).timeout

	if player_money < Config.MIN_PLOT_PRICE:
		game_over()
	else:
		round_number += 1
		transition_to_auction()

## Transition helper
func transition_to_state(new_state: GameState) -> void:
	current_state = new_state

# ============================================================================
# MONEY MANAGEMENT
# ============================================================================

## Update player money and emit signal
## @param delta: Amount to add (positive) or subtract (negative)
func change_money(delta: int) -> void:
	player_money += delta
	EventBus.money_changed.emit(player_money)

## Check if player can afford amount
func can_afford(amount: int) -> bool:
	return player_money >= amount

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_auction_won(plot_data: Resource) -> void:
	# Deduct bid amount (stored in plot_data.final_bid_price)
	change_money(-plot_data.final_bid_price)
	start_mining_session(plot_data)

func _on_round_ended(stats: Dictionary) -> void:
	# Add gold collected to total
	var gold_earned: int = stats.get("gold_collected", 0)
	total_gold_collected += gold_earned

	# For MVP: Gold has no cash value yet (no market)
	# Future: Calculate earnings based on market price

	# Store round stats
	session_history.append({
		"round": round_number,
		"plot_name": current_plot.plot_name if current_plot else "Unknown",
		"gold_collected": gold_earned,
		"time_used": stats.get("time_used", 0.0)
	})

	show_round_end(stats)

# ============================================================================
# GAME OVER
# ============================================================================

func game_over() -> void:
	EventBus.game_over.emit()
	# Show game over screen
	print("GAME OVER - Bankruptcy!")
	print("Total Rounds: %d" % round_number)
	print("Total Gold Collected: %d" % total_gold_collected)

	# Return to main menu
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
