# Autoload Singletons — CLAUDE.md

Three global singletons registered in `project.godot`. Accessible anywhere without `get_node`.

## Files

| File | Class | Purpose |
|------|-------|---------|
| `config.gd` | _(no class_name)_ | All tunable constants + helper functions |
| `event_bus.gd` | _(no class_name)_ | All inter-system signals |
| `game_manager.gd` | _(no class_name)_ | State machine + session persistence |

---

## config.gd

**Rule:** Never hardcode numeric values in gameplay scripts. Always reference `Config.CONSTANT`.

### Current values (2026-02-08 balance pass)
```gdscript
STORAGE_CAPACITY = 500       # Was 100, raised to fix "game ends after 2-3 nuggets"
MIN_GOLD_DEPOSITS = 25       # Was 15
MAX_GOLD_DEPOSITS = 50       # Was 30
MIN_GOLD_AMOUNT = 15         # Per tile, was 10
MAX_GOLD_AMOUNT = 60         # Per tile, was 50
```

### Helper functions (not constants)
```gdscript
Config.get_npc_aggression(round_number)  # → float, caps at 0.6
Config.get_deposit_count(richness)        # → int, uses MIN/MAX averages
```

---

## event_bus.gd

**Rule:** All inter-system communication must go through EventBus. No direct node references between systems.

### Signal inventory by category

**Auction**
```gdscript
auction_started()
plot_selected(plot_id: int)
bid_placed(amount: int)
auction_won(plot_data: Resource)  # PlotData — triggers mining scene load
```

**Mining**
```gdscript
mining_started(plot_data: Resource)  # Emitted AFTER scene loads (3 frames delay)
tile_dug(tile_pos: Vector2i)
gold_detected(deposit_positions: Array)  # Array[Vector2i]
gold_collected(amount: int)
resource_storage_changed(current: int, max_capacity: int)
```

**Session**
```gdscript
session_time_updated(time_remaining: float)  # Every frame during mining
round_ended(stats: Dictionary)  # {gold_collected, time_used, efficiency, reason}
```

**Game Flow**
```gdscript
money_changed(new_amount: int)
game_over()
```

**Debug**
```gdscript
debug_mode_changed(enabled: bool)  # F12 toggle
debug_reveal_gold()                 # F3 cheat
```

**UI**
```gdscript
game_paused()
game_resumed()
help_opened()
help_closed()
settings_opened()
settings_closed()
```

---

## game_manager.gd

### State machine
```
MAIN_MENU → AUCTION → MINING → ROUND_END → AUCTION (loop)
```

State stored in `GameManager.current_state` (enum `GameState`).

### Session data (read from anywhere)
```gdscript
GameManager.player_money     # int
GameManager.round_number     # int, starts at 1
GameManager.current_plot     # PlotData or null
GameManager.total_gold_collected  # int, cumulative
GameManager.debug_mode_enabled    # bool
```

### Critical: scene load timing
`start_mining_session()` waits **3 frames** before emitting `mining_started`:
```gdscript
await get_tree().process_frame  # × 3
EventBus.mining_started.emit(plot)
```
This is intentional — listeners in the mining scene need time to register. Do not reduce frame count.

### Money flow
```gdscript
GameManager.change_money(delta)   # Always use this, never set player_money directly
GameManager.can_afford(amount)    # → bool
```
Gold currently has no cash value (no market system yet). `round_ended` stats track gold count only.

### Game over condition
Triggered when `player_money < Config.MIN_PLOT_PRICE` after round ends. Returns to main menu after 3s.

### Input handled here (not in player)
- `F12` → toggle debug mode → emits `debug_mode_changed`
- `F1` → add $1000 (debug builds only)
- `toggle_help` action → emits `help_opened` (only during MINING state)
