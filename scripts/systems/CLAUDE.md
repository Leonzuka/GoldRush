# Core Systems — CLAUDE.md

Three systems that own game logic. None of them should reference UI nodes directly — communicate via EventBus.

## Files

| File | Class | Scene | Group |
|------|-------|-------|-------|
| `terrain_manager.gd` | `TerrainManager` | `terrain.tscn` | `"terrain"` |
| `auction_system.gd` | `AuctionSystem` | _(created in code)_ | `"auction_system"` |
| `mining_session.gd` | `MiningSession` | `mining_scene.tscn` | — |

---

## terrain_manager.gd

### Data model: TileMap + Dictionary hybrid
```gdscript
# VISUAL only — do not query for gameplay data
tilemap: TileMap  # $GroundTileMap

# GAMEPLAY data — gold is hidden here, not in TileMap
gold_deposits: Dictionary
# Key: Vector2i (tile pos)
# Value: {amount: int, richness: float, revealed: bool}

# Scanner highlight overlays
gold_indicators: Dictionary  # Key: Vector2i, Value: ColorRect node
```

### Tile atlas coordinates (source 0)
```gdscript
TILE_DIRT_ATLAS    = Vector2i(0, 24)  # rows 0-20% depth
TILE_STONE_ATLAS   = Vector2i(1, 24)  # rows 20-85% depth
TILE_BEDROCK_ATLAS = Vector2i(2, 24)  # rows 85-100% depth — NOT diggable
```

### Public API
```gdscript
generate_terrain(seed_value: int, gold_richness: float) -> void
    # Called by MiningSession._on_mining_started()

dig_tile(tile_pos: Vector2i) -> Dictionary
    # Returns: {success: bool, has_gold: bool, gold_amount: int}
    # Bedrock returns success=false
    # Emits EventBus.tile_dug on success

world_to_tile(world_pos: Vector2) -> Vector2i
tile_to_world(tile_pos: Vector2i) -> Vector2

highlight_gold_tiles(positions: Array) -> void
    # Creates pulsating ColorRect indicators
    # Called by ScannerComponent after scan
```

### Gold deposit generation
- Clustered, not random individual tiles
- 5 deposits per cluster on average
- **40% shallow** (rows 3–15), **60% deep** (rows 15+)
- Bounds: 5 tiles margin on left/right, 10 tiles from bottom

### Debug overlay (F12)
- `_draw()` draws circles at all `gold_deposits.keys()`
- Yellow = revealed, Orange = unrevealed
- `queue_redraw()` must be called after state changes

---

## auction_system.gd

### Inner class: NPCAuctionAgent
Each auction creates 3 agents (from `Config.NPC_NAMES`). Each agent has:
```gdscript
budget: int          # randi_range(500, 1500)
aggression: float    # 0.2 + round*0.05, clamped 0.2-0.8
preferred_richness: float  # randf_range(0.3, 1.3)
```

`evaluate_plot(plot)` returns 0.0–1.0 score. NPC claims plot only if score > 0.3.

### Plot generation
12 plots in a 4×3 grid (`Config.AUCTION_MAP_COLS × AUCTION_MAP_ROWS`).
```gdscript
PlotData fields set during generation:
  plot_id: int
  grid_position: Vector2i(col, row)
  plot_name: String          # From plot_names pool (10 names)
  terrain_seed: int          # randi()
  gold_richness: float       # randf_range(0.5, 1.5)
  base_price: int            # 100 + richness*300, clamped 100-500
  final_bid_price: int       # = base_price initially
  owner_type: PlotData.OwnerType.AVAILABLE
```

### Bidding flow
```gdscript
# Player bid
process_bid(plot, player_bid, round_number) -> {won: bool, final_price: int, reason: String}
    # Checks GameManager.can_afford()
    # Simulates NPC counter-bid
    # NPC outbid increment: randi_range(50, 150)

# NPC turn (async — uses await timer)
start_npc_turn()  # Sequential NPC actions with NPC_BID_DELAY between
```

### Signals (local — not on EventBus)
```gdscript
plots_generated(plots: Array[PlotData])    # Heard by IsometricMapController
npc_claimed_plot(plot_data, npc_name)      # Heard by AuctionUIController
```

**Note:** `AuctionSystem` is instantiated and added as child by `auction_ui_controller.gd` at runtime, not placed in scene.

---

## mining_session.gd

### Lifecycle
```
EventBus.mining_started → _on_mining_started() → generate_terrain() → start_session()
                                                       ↓
                                               _process() counts time
                                                       ↓
                                        Time limit OR storage full
                                                       ↓
                                            end_session(reason)
                                                       ↓
                                       EventBus.round_ended.emit(stats)
```

### End conditions
| Condition | Reason string |
|-----------|--------------|
| `elapsed_time >= time_limit` | `"Time limit reached"` |
| `gold_collected >= storage_capacity` | `"Storage full"` |

### Stats dictionary emitted with `round_ended`
```gdscript
{
    "gold_collected": int,
    "time_used": float,
    "efficiency": gold_collected / elapsed_time,
    "reason": String
}
```

### Player spawn
`_position_player_at_surface()` places player at:
```gdscript
x = TERRAIN_WIDTH * TILE_SIZE / 2   # Horizontal center
y = -TILE_SIZE * 2                   # 2 tiles above row 0
```
Player must be in group `"player"` for this to work.

### Important: `is_active` guard
All gold collection and session logic is guarded by `is_active`. Signals received after `end_session()` are silently ignored.
