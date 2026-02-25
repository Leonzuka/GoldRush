# UI Scripts — CLAUDE.md

UI controllers connect EventBus signals to visual updates. They should **never** own gameplay logic — only display state and forward player input to systems.

## Files

| File | Scene | Context |
|------|-------|---------|
| `hud_controller.gd` | `scenes/ui/hud.tscn` | In-game overlay during mining |
| `auction_ui_controller.gd` | `scenes/auction/auction.tscn` | Auction phase root controller |
| `isometric_map_controller.gd` | `scenes/auction/auction.tscn` (SubViewport) | Renders 4×3 isometric plot grid |
| `plot_card.gd` | `scenes/auction/plot_card.tscn` | Individual plot card (legacy/unused?) |
| `plot_tile.gd` | `scenes/auction/plot_tile.tscn` | Isometric tile in the auction map |
| `main_menu_controller.gd` | `scenes/main/main_menu.tscn` | Main menu buttons |
| `pause_menu_controller.gd` | `scenes/ui/pause_menu.tscn` | Pause overlay |
| `settings_menu_controller.gd` | `scenes/ui/settings_menu.tscn` | Settings screen |
| `help_dialog_controller.gd` | `scenes/ui/help_dialog.tscn` | Help overlay |
| `round_end_controller.gd` | `scenes/ui/round_end_panel.tscn` | Post-round summary |

---

## hud_controller.gd

### Node references (all `@onready`)
```gdscript
$TopBar/RoundLabel     # "Round: N"
$TopBar/TimeLabel      # "00:00" countdown
$TopBar/MoneyLabel     # "Money: $N" (animated)
$BottomBar/GoldLabel   # "Gold: N/MAX"
$BottomBar/StorageBar  # ProgressBar
$BottomBar/ScanButton  # Disabled during cooldown
```

### EventBus connections
```gdscript
session_time_updated(time_remaining) → formats MM:SS
resource_storage_changed(current, max) → updates bar + label
money_changed(new_amount) → triggers animated count
```

### Scan button cooldown
Polled every frame via `get_tree().get_first_node_in_group("scanner")`.
Displays `"SCAN (%.1fs)"` when on cooldown, `"SCAN [E]"` when ready.

### Money animation
```gdscript
# Tween from old to new value, duration scales with delta:
duration = clampf(abs(new - old) / 500.0, 0.3, 1.2)
# Color flash: green gain, red loss
# Scale punch: 1.2x → 1.0 with TRANS_ELASTIC
```
Previous tween is killed before starting a new one.

### FPS counter
Created programmatically in `_ready()`, updated every frame. Position: `(10, 10)`, font size 14.

---

## auction_ui_controller.gd

### Node path gotcha
`IsometricMapController` lives inside a SubViewport:
```gdscript
@onready var map_controller = $MapViewport/SubViewport/IsometricMap
```

### Initialization sequence (order matters!)
```gdscript
_ready():
    # 1. Connect signals and show initial UI
    # 2. Wait 2 frames — IsometricMapController must be ready first
    await get_tree().process_frame × 2
    # 3. Generate plots (map is now listening to AuctionSystem.plots_generated)
    auction_system.generate_plots()
    # 4. Wait 1.5s for map to render, then start NPC turn
    await timer(1.5)
    auction_system.start_npc_turn()
    # 5. Wait for NPCs to finish, then unlock player selection
    await timer(NPC_BID_DELAY * NPC_COUNT + 0.5)
```
**Do not reorder this sequence.** Map must receive `plots_generated` before it can render.

### AuctionSystem instantiation
```gdscript
# Created in code, NOT placed in scene
auction_system = AuctionSystem.new()
auction_system.add_to_group("auction_system")
add_child(auction_system)
```

### Bid flow
1. Player clicks a plot tile → `IsometricMapController` calls `show_plot_info(plot)`
2. `show_plot_info()` populates `info_panel` and enables/disables bid button
3. Player presses bid button → plot marked as `PLAYER`, `auction_won` emitted after 1.5s delay

### Money animation
Same pattern as `hud_controller.gd` but shorter max duration (1.0s vs 1.2s). Uses inline lambda instead of separate method.

---

## plot_tile.gd

### Visual states
| State | Border color | Fill | Depth polygon |
|-------|-------------|------|--------------|
| `AVAILABLE` | White | Soil texture | Normal |
| `NPC` owned | Red/orange | Dimmed | Normal |
| `PLAYER` owned | Bright green | Highlighted | Normal |
| Hover | Bright yellow | Slightly lifted | Offset up |

### Important: depth polygon
`plot_tile.tscn` has both `RightDepthPolygon` and `LeftDepthPolygon` (left was missing — added 2026-02-08).
`depth_border_line` must be synced with `border_line` color in **all** visual states.

---

## Pattern: UI reads GameManager, writes via EventBus

```gdscript
# CORRECT — read state
GameManager.player_money
GameManager.round_number
GameManager.can_afford(amount)

# CORRECT — trigger changes
EventBus.auction_won.emit(plot)   # GameManager handles the rest

# WRONG — never do this from UI
GameManager.player_money -= amount  # Use change_money() instead
```
