# Auction Scene — CLAUDE.md

## Scene files

| Scene | Root node | Purpose |
|-------|-----------|---------|
| `auction.tscn` | Control | Root — auction UI + isometric map |
| `plot_card.tscn` | PanelContainer | Legacy card layout (may be unused) |
| `plot_tile.tscn` | Node2D | Isometric diamond tile for each plot |

---

## auction.tscn node hierarchy

```
Auction (Control)
├── UILayer (CanvasLayer)
│   ├── TopBar
│   │   ├── TitleLabel
│   │   └── MoneyLabel
│   ├── PlotInfoPanel (PanelContainer)  ← hidden until plot selected
│   │   └── VBoxContainer
│   │       ├── PlotNameLabel
│   │       ├── RichnessLabel
│   │       ├── PriceLabel
│   │       ├── StatusLabel
│   │       └── BidButton
│   └── InfoLabel                       ← status messages ("NPCs choosing...")
├── MapViewport (SubViewportContainer)
│   └── SubViewport
│       └── IsometricMap (Node2D)       ← IsometricMapController script
└── [auction_ui_controller.gd on root]
```

---

## IsometricMapController

Renders 12 `plot_tile.tscn` instances in a 4×3 isometric grid.

### Coordinate system
```
Isometric tile center offset from grid origin:
  x = (col - row) * ISO_TILE_WIDTH / 2
  y = (col + row) * ISO_TILE_HEIGHT / 2
```
Constants: `ISO_TILE_WIDTH=128`, `ISO_TILE_HEIGHT=64`.

### Listens to
```gdscript
auction_system.plots_generated(plots)  # Creates all tile instances
auction_system.npc_claimed_plot(plot, npc_name)  # Updates tile visuals
```

### Called by AuctionUIController
```gdscript
map_controller.refresh_plot_visuals(plot)  # After player bids or NPC claims
```

### Input handling
Plot tiles emit their selection to `AuctionUIController.show_plot_info(plot)` when clicked.

---

## PlotData resource

Defined in `resources/plot_data.gd`. Key fields used by auction scene:

```gdscript
plot_id: int
grid_position: Vector2i       # col, row in 4×3 grid
plot_name: String
gold_richness: float          # 0.5–1.5
base_price: int               # 100–500
final_bid_price: int          # = base_price until player wins
owner_type: PlotData.OwnerType  # AVAILABLE | NPC | PLAYER
owner_name: String            # NPC name if owned by NPC

# Helper methods
plot.is_biddable() -> bool    # owner_type == AVAILABLE
plot.get_star_rating() -> int # 1-5 based on richness
plot.get_richness_tier() -> String  # "Poor" / "Average" / "Rich" etc.
```

---

## Auction timing constants (from Config)

```gdscript
NPC_BID_DELAY = 0.8           # Seconds between NPC actions
NPC_COUNT_PER_AUCTION = 3
# AuctionUIController waits: NPC_BID_DELAY * NPC_COUNT + 0.5 = 2.9s
```

---

## plot_tile.gd visual states

Four visual states controlled by `owner_type`:

| State | When | Border color | Depth color |
|-------|------|-------------|------------|
| AVAILABLE | Default | White | Normal |
| HOVER | Mouse over | Bright yellow | Slightly elevated |
| NPC | NPC claimed | Red/orange | Dimmed |
| PLAYER | Player won | Bright green | Highlighted |

**Critical:** `depth_border_line` must be updated alongside `border_line` in every state transition. Missing left depth polygon was a bug fixed 2026-02-08 — `LeftDepthPolygon` node is now required in `plot_tile.tscn`.
