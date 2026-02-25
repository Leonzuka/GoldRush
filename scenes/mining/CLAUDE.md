# Mining Scene — CLAUDE.md

## Scene files

| Scene | Root node | Purpose |
|-------|-----------|---------|
| `mining_scene.tscn` | Node2D | Root container — holds all mining subscenes |
| `terrain.tscn` | Node2D | TileMap + TerrainManager script |
| `player.tscn` | CharacterBody2D | Player with DrillComponent + ScannerComponent |
| `gold_nugget.tscn` | Area2D | Collectible instantiated at runtime |

---

## Node hierarchy in mining_scene.tscn

```
MiningScene (Node2D)
├── Terrain (terrain.tscn instance)
│   ├── GroundTileMap (TileMap)        — layer 0, physics layer 1
│   └── [TerrainManager script]
├── Player (player.tscn instance)
│   ├── [player_controller.gd]
│   ├── DrillComponent (Node)
│   └── ScannerComponent (Node)
├── GoldNuggetContainer (Node2D)       — group: "nugget_container"
├── HUD (hud.tscn instance)
├── PauseMenu (pause_menu.tscn)
├── HelpDialog (help_dialog.tscn)
├── Camera2D
└── MiningSession (Node)               — [mining_session.gd]
```

---

## Group requirements

| Group | Who sets it | Who reads it |
|-------|------------|-------------|
| `"terrain"` | `TerrainManager._ready()` | DrillComponent, ScannerComponent, MiningSession |
| `"player"` | `player_controller._ready()` | GoldNugget, MiningSession |
| `"scanner"` | `ScannerComponent._ready()` | HUDController (for cooldown display) |
| `"nugget_container"` | Set in scene editor | DrillComponent |

**If nuggets aren't appearing:** verify `GoldNuggetContainer` has group `"nugget_container"` set in scene editor.

---

## Scene load sequence

GameManager emits `mining_started` **3 frames after** `change_scene_to_file`. Systems that need terrain generated must listen to `EventBus.mining_started`, not `_ready()`.

```gdscript
# WRONG — terrain not generated yet
func _ready() -> void:
    do_something_with_terrain()

# CORRECT — terrain is ready
func _ready() -> void:
    EventBus.mining_started.connect(_on_mining_started)

func _on_mining_started(plot_data):
    do_something_with_terrain()
```

---

## Physics layers

| Layer | Name | Used by |
|-------|------|---------|
| 1 | Terrain | TileMap collision shapes, Player collision mask |
| 2 | Player | Player body layer |
| 3 | Nuggets | GoldNugget area layer (detects player body) |

Player mask must include layer 1 (terrain) to not fall through ground.

---

## Camera

`Camera2D` should follow the player. Clamp limits to terrain bounds:
```gdscript
# Prevent camera from showing outside terrain
limit_left = 0
limit_top = -TILE_SIZE * 4     # A bit above surface
limit_right = TERRAIN_WIDTH * TILE_SIZE
limit_bottom = TERRAIN_HEIGHT * TILE_SIZE
```

---

## gold_nugget.tscn structure

```
GoldNugget (Area2D)
├── CollisionShape2D  (CircleShape, radius ~6)
└── Sprite2D          (gold nugget art)
```
Physics: Area2D on layer 3, mask includes layer 2 (player body).
Script `gold_nugget.gd` draws soft glow via `_draw()` on top of sprite.
