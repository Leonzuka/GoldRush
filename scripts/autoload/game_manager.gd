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
var debug_mode_enabled: bool = false

## Loan state — at most one active loan at a time. Interest is applied
## exactly once per round, in show_round_end(), before the bankruptcy check.
var current_debt: int = 0
var loan_round_taken: int = -1

const SAVE_PATH: String = "user://savegame.cfg"

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	# Connect to relevant signals
	EventBus.auction_won.connect(_on_auction_won)
	EventBus.round_ended.connect(_on_round_ended)
	EventBus.storage_goal_reached.connect(_on_storage_goal_reached)

func _input(event: InputEvent) -> void:
	# Debug mode toggle
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		debug_mode_enabled = !debug_mode_enabled
		EventBus.debug_mode_changed.emit(debug_mode_enabled)
		print("[Debug] Mode: %s" % ("ON" if debug_mode_enabled else "OFF"))

	# Cheat: Add money (dev only)
	if OS.is_debug_build() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			change_money(1000)
			print("[CHEAT] Added $1000")

	# Toggle help dialog (H key during mining)
	if event.is_action_pressed("toggle_help") and current_state == GameState.MINING:
		EventBus.help_opened.emit()

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
	current_debt = 0
	loan_round_taken = -1
	UpgradeManager.reset()
	_delete_save()
	EventBus.debt_changed.emit(0)

	transition_to_state(GameState.AUCTION)
	transition_to_auction()

## Continue from saved game
func continue_game() -> void:
	if not has_save():
		start_new_game()
		return
	load_game()
	transition_to_state(GameState.AUCTION)
	transition_to_auction()

## DEBUG: Skip auction and jump directly to mining with a generated plot
func debug_start_mining(richness: float = 1.0) -> void:
	player_money = Config.STARTING_MONEY
	round_number = 1
	total_gold_collected = 0
	session_history.clear()

	var plot := PlotData.new()
	plot.plot_id = 0
	plot.plot_name = "[DEBUG] Plot"
	plot.terrain_seed = randi()
	plot.gold_richness = richness
	plot.base_price = 0
	plot.final_bid_price = 0
	plot.owner_type = PlotData.OwnerType.PLAYER

	print("[Debug] Skipping auction — richness=%.1f seed=%d" % [richness, plot.terrain_seed])
	start_mining_session(plot)

## Transition to auction phase
func transition_to_auction() -> void:
	current_state = GameState.AUCTION
	save_game()
	await SceneTransition.transition_out(SceneTransition.Type.FADE)
	get_tree().change_scene_to_file("res://scenes/auction/auction.tscn")
	await get_tree().process_frame
	SceneTransition.transition_in(SceneTransition.Type.FADE)

## Start mining session with won plot
func start_mining_session(plot: Resource) -> void:
	current_plot = plot
	current_state = GameState.MINING
	print("[GameManager] Starting mining session with plot: %s" % plot.plot_name)

	await SceneTransition.transition_out(SceneTransition.Type.FADE)
	get_tree().change_scene_to_file("res://scenes/mining/mining_scene.tscn")

	# Wait for scene to load and all nodes to be ready (3 frames minimum)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for safety
	print("[GameManager] Scene loaded, emitting mining_started signal")
	EventBus.mining_started.emit(plot)

	SceneTransition.transition_in(SceneTransition.Type.FADE)

## Transition to round end summary
func show_round_end() -> void:
	current_state = GameState.ROUND_END
	# Wait for player to dismiss the round end panel
	await EventBus.round_end_confirmed

	# Apply loan interest exactly once at round close, before the bankruptcy check.
	# Skip the round in which the loan was taken so the player isn't charged twice.
	_apply_loan_interest()

	# Bankruptcy: even selling everything (cash + a min-priced plot) couldn't cover the debt.
	if player_money + Config.MIN_PLOT_PRICE - current_debt < 0:
		game_over()
	elif player_money < Config.MIN_PLOT_PRICE and current_debt == 0:
		# Classic bankruptcy: can't afford the cheapest plot and no credit available
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
# LOAN MANAGEMENT
# ============================================================================

## Player can take a loan only when no active debt exists (one loan at a time)
func can_take_loan() -> bool:
	return current_debt == 0

## Maximum loan amount available this round
func get_max_loan() -> int:
	return Config.get_max_loan(round_number)

## Take out a loan, increasing cash and recording debt
func take_loan(amount: int) -> void:
	if not can_take_loan():
		push_warning("[Loan] Cannot take loan — debt already active ($%d)" % current_debt)
		return
	var capped: int = clampi(amount, 1, get_max_loan())
	current_debt = capped
	loan_round_taken = round_number
	change_money(capped)
	EventBus.loan_taken.emit(capped, current_debt)
	EventBus.debt_changed.emit(current_debt)
	print("[Loan] Taken: $%d (round %d)" % [capped, round_number])

## Repay debt up to available cash; partial repayment allowed
func repay_debt(amount: int) -> void:
	if current_debt <= 0:
		return
	var pay: int = clampi(amount, 0, mini(current_debt, player_money))
	if pay <= 0:
		return
	change_money(-pay)
	current_debt -= pay
	if current_debt == 0:
		loan_round_taken = -1
	EventBus.debt_changed.emit(current_debt)
	print("[Loan] Repaid: $%d (remaining $%d)" % [pay, current_debt])

## Apply loan interest at round close (single source of truth — called only by show_round_end)
func _apply_loan_interest() -> void:
	if current_debt <= 0:
		return
	# Don't charge interest on the round the loan was taken
	if loan_round_taken == round_number:
		return
	var interest: int = int(ceil(float(current_debt) * Config.LOAN_INTEREST_RATE))
	current_debt += interest
	EventBus.loan_interest_applied.emit(interest, current_debt)
	EventBus.debt_changed.emit(current_debt)
	print("[Loan] Interest applied: +$%d (debt now $%d)" % [interest, current_debt])

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_storage_goal_reached() -> void:
	# Money is awarded at round end, not immediately — see _on_round_ended.
	pass

func _on_auction_won(plot_data: Resource) -> void:
	# Deduct bid amount (stored in plot_data.final_bid_price)
	change_money(-plot_data.final_bid_price)
	start_mining_session(plot_data)

func _on_round_ended(stats: Dictionary) -> void:
	var gold_earned: int = stats.get("gold_collected", 0)
	total_gold_collected += gold_earned

	# Convert gold to money at round end (1 gold unit = $1, already scaled by gold_value upgrade)
	change_money(gold_earned)
	print("[GameManager] Gold sold: +$%d" % gold_earned)

	# Storage goal bonus — awarded here, not mid-round
	if stats.get("storage_goal_reached", false):
		change_money(Config.STORAGE_GOAL_BONUS)
		print("[GameManager] Storage goal bonus: +$%d" % Config.STORAGE_GOAL_BONUS)

	session_history.append({
		"round": round_number,
		"plot_name": current_plot.plot_name if current_plot else "Unknown",
		"gold_collected": gold_earned,
		"time_used": stats.get("time_used", 0.0)
	})

	show_round_end()

# ============================================================================
# GAME OVER
# ============================================================================

func game_over() -> void:
	EventBus.game_over.emit()
	print("GAME OVER - Bankruptcy!")
	print("Total Rounds: %d" % round_number)
	print("Total Gold Collected: %d" % total_gold_collected)

	await SceneTransition.transition_out(SceneTransition.Type.FADE)
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
	await get_tree().process_frame
	SceneTransition.transition_in(SceneTransition.Type.FADE)

# ============================================================================
# PERSISTENCE
# ============================================================================

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "player_money", player_money)
	cfg.set_value("session", "round_number", round_number)
	cfg.set_value("session", "total_gold_collected", total_gold_collected)
	cfg.set_value("session", "current_debt", current_debt)
	cfg.set_value("session", "loan_round_taken", loan_round_taken)
	var err: int = cfg.save(SAVE_PATH)
	if err != OK:
		push_error("[GameManager] Save failed: %d" % err)
	else:
		print("[GameManager] Game saved (round %d, $%d)" % [round_number, player_money])

func load_game() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(SAVE_PATH)
	if err != OK:
		push_error("[GameManager] Load failed: %d" % err)
		return
	player_money = int(cfg.get_value("session", "player_money", Config.STARTING_MONEY))
	round_number = int(cfg.get_value("session", "round_number", 1))
	total_gold_collected = int(cfg.get_value("session", "total_gold_collected", 0))
	current_debt = int(cfg.get_value("session", "current_debt", 0))
	loan_round_taken = int(cfg.get_value("session", "loan_round_taken", -1))
	session_history.clear()
	current_plot = null
	UpgradeManager.load_from_disk()
	EventBus.money_changed.emit(player_money)
	EventBus.debt_changed.emit(current_debt)
	print("[GameManager] Game loaded (round %d, $%d)" % [round_number, player_money])

func _delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var abs_path: String = ProjectSettings.globalize_path(SAVE_PATH)
		DirAccess.remove_absolute(abs_path)
