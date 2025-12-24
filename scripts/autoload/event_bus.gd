extends Node

## Global signal hub for loose coupling between systems
## Prevents circular dependencies by centralizing event communication

# ============================================================================
# AUCTION SIGNALS
# ============================================================================

## Emitted when auction phase begins
signal auction_started()

## Emitted when player selects a plot card
## @param plot_id: Unique identifier for the selected plot
signal plot_selected(plot_id: int)

## Emitted when player places a bid
## @param amount: Bid amount in currency
signal bid_placed(amount: int)

## Emitted when auction is won (by player or NPC)
## @param plot_data: PlotData resource containing terrain seed and richness
signal auction_won(plot_data: Resource)

# ============================================================================
# MINING SIGNALS
# ============================================================================

## Emitted when mining phase starts
## @param plot_data: The won plot's data
signal mining_started(plot_data: Resource)

## Emitted when a terrain tile is successfully dug
## @param tile_pos: Grid position of dug tile (Vector2i)
signal tile_dug(tile_pos: Vector2i)

## Emitted when scanner detects gold deposits
## @param deposit_positions: Array of Vector2i tile positions with gold
signal gold_detected(deposit_positions: Array)

## Emitted when player collects a gold nugget
## @param amount: Gold units collected
signal gold_collected(amount: int)

## Emitted when resource storage changes
## @param current: Current gold stored
## @param max_capacity: Maximum storage limit
signal resource_storage_changed(current: int, max_capacity: int)

# ============================================================================
# SESSION SIGNALS
# ============================================================================

## Emitted each frame during mining session
## @param time_remaining: Seconds left in round
signal session_time_updated(time_remaining: float)

## Emitted when mining session ends (timer or storage full)
## @param stats: Dictionary with gold_collected, time_used, efficiency
signal round_ended(stats: Dictionary)

# ============================================================================
# GAME FLOW SIGNALS
# ============================================================================

## Emitted when player money changes
## @param new_amount: Updated total money
signal money_changed(new_amount: int)

## Emitted when game ends (bankruptcy)
signal game_over()

# ============================================================================
# DEBUG SIGNALS
# ============================================================================

## Emitted when debug mode toggles (F12)
signal debug_mode_changed(enabled: bool)

## Emitted to reveal all gold (cheat: F3)
signal debug_reveal_gold()
