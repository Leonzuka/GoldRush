extends Node

## Global signal hub for loose coupling between systems
## Prevents circular dependencies by centralizing event communication

# ============================================================================
# AUCTION SIGNALS
# ============================================================================

## Emitted when auction is won (by player or NPC)
## @param plot_data: PlotData resource containing terrain seed and richness
@warning_ignore("unused_signal")
signal auction_won(plot_data: Resource)

# ============================================================================
# MINING SIGNALS
# ============================================================================

## Emitted when mining phase starts
## @param plot_data: The won plot's data
@warning_ignore("unused_signal")
signal mining_started(plot_data: Resource)

## Emitted when a terrain tile is successfully dug
## @param tile_pos: Grid position of dug tile (Vector2i)
signal tile_dug(tile_pos: Vector2i)

## Emitted when scanner detects gold deposits
## @param deposit_positions: Array of Vector2i tile positions with gold
signal gold_detected(deposit_positions: Array)

## Emitted when scanner cooldown changes (scan start or end)
## @param remaining: Seconds remaining; 0.0 means ready to scan
signal scanner_cooldown_changed(remaining: float)

## Emitted when player collects a gold nugget
## @param amount: Gold units collected
signal gold_collected(amount: int)

## Emitted when player collects a rare item (diamond, fossil, relic)
## @param collectible_type: "diamond", "fossil", or "relic"
## @param amount: Gold-equivalent value of the rare item
signal rare_collected(collectible_type: String, amount: int)

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

## Emitted when player clicks Continue on the round end panel
signal round_end_confirmed()

## Emitted when player first fills the storage goal (one-time per session)
signal storage_goal_reached()

## Emitted when player presses the "End Mining" button in HUD
signal end_mining_requested()

# ============================================================================
# GAME FLOW SIGNALS
# ============================================================================

## Emitted when player money changes
## @param new_amount: Updated total money
signal money_changed(new_amount: int)

## Emitted when game ends (bankruptcy)
signal game_over()

# ============================================================================
# LOAN SIGNALS
# ============================================================================

## Emitted when a new loan is taken
@warning_ignore("unused_signal")
signal loan_taken(amount: int, total_debt: int)

## Emitted at round end after interest is applied
@warning_ignore("unused_signal")
signal loan_interest_applied(interest: int, total_debt: int)

## Emitted whenever debt changes (loan, repay, interest)
@warning_ignore("unused_signal")
signal debt_changed(total_debt: int)

# ============================================================================
# AUCTION STEAL SIGNALS
# ============================================================================

## Emitted when an aggressive/cunning NPC steals a plot from another NPC
@warning_ignore("unused_signal")
signal npc_stole_plot(plot_data: Resource, thief_name: String, victim_name: String)

# ============================================================================
# DEBUG SIGNALS
# ============================================================================

## Emitted when debug mode toggles (F12)
signal debug_mode_changed(enabled: bool)

## Emitted to reveal all gold (cheat: F3)
signal debug_reveal_gold()

# ============================================================================
# UI SIGNALS
# ============================================================================

## Emitted when game is paused (ESC during mining)
@warning_ignore("unused_signal")
signal game_paused()

## Emitted when game is resumed from pause
@warning_ignore("unused_signal")
signal game_resumed()

## Emitted when help dialog is opened
@warning_ignore("unused_signal")
signal help_opened()

## Emitted when help dialog is closed
@warning_ignore("unused_signal")
signal help_closed()

## Emitted when settings menu is opened
@warning_ignore("unused_signal")
signal settings_opened()

## Emitted when settings menu is closed
@warning_ignore("unused_signal")
signal settings_closed()

# ============================================================================
# UPGRADE SIGNALS
# ============================================================================

## Emitted when an upgrade is purchased
## @param upgrade_id: The upgrade identifier (e.g., "drill_speed")
## @param new_level: The level after purchase
@warning_ignore("unused_signal")
signal upgrade_purchased(upgrade_id: String, new_level: int)

## Emitted whenever any upgrade modifier changes (purchase or reset)
@warning_ignore("unused_signal")
signal upgrades_changed()

## Emitted when shop dialog opens
@warning_ignore("unused_signal")
signal shop_opened()

## Emitted when shop dialog closes
@warning_ignore("unused_signal")
signal shop_closed()
