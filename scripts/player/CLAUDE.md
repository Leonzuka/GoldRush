# Player Scripts — CLAUDE.md

Three scripts on the player scene (`scenes/mining/player.tscn`). All extend `Node` except the root.

## Files

| File | Class | Node type | Group |
|------|-------|-----------|-------|
| `player_controller.gd` | — | `CharacterBody2D` | `"player"` |
| `drill_component.gd` | `DrillComponent` | `Node` (child of player) | — |
| `scanner_component.gd` | `ScannerComponent` | `Node` (child of player) | `"scanner"` |

---

## player_controller.gd

### Movement
- `CharacterBody2D` with gravity + `move_and_slide()`
- **Horizontal:** `move_left` / `move_right` actions (A/D or arrows)
- **Jump:** `jump` action (Space), only when `is_on_floor()`
- Values from Config: `PLAYER_SPEED=150`, `PLAYER_GRAVITY=980`, `PLAYER_JUMP_VELOCITY=350`

### Drill range visual (`_draw()`)
Drawn directly on the player node — no extra node needed.
- Only visible when `drill` action is held
- White circle when in range, **red circle + text** when out of range
- Reads `drill_component.is_out_of_range` and `drill_component.drill_reach`

### Node access pattern
```gdscript
drill_component = get_node_or_null("DrillComponent") as DrillComponent
```
Uses `get_node_or_null` (not `$`) to avoid crash if component is missing.

---

## drill_component.gd

### How drilling works
1. Player holds `drill` action (left mouse button)
2. Mouse world position calculated from camera offset
3. If distance to mouse > `drill_reach` (48px = 3 tiles): sets `is_out_of_range = true`
4. Otherwise: increments `drill_progress += drill_speed * delta`
5. At `drill_progress >= 1.0`: calls `terrain_manager.dig_tile(tile_pos)`
6. Progress resets to 0.0 on tile change or release

### Camera-aware mouse position
```gdscript
var camera: Camera2D = get_viewport().get_camera_2d()
mouse_pos = camera.get_screen_center_position() + (mouse_pos - viewport_size / 2) / camera.zoom
```
Required because viewport coords ≠ world coords when camera is zoomed/moved.

### Gold nugget spawning
```gdscript
spawn_gold_nugget(tile_pos, amount)
# Finds "nugget_container" group first, falls back to scene root
# gold_nugget_scene is auto-loaded if not set in Inspector:
#   load("res://scenes/mining/gold_nugget.tscn")
```

### Effects (no scene files — pure code)
Both use `CPUParticles2D` created in code, with `one_shot = true` and `finished.connect(queue_free)`.

| Effect | Trigger | Key params |
|--------|---------|-----------|
| Dig dust | Every successful dig | Brown, 12 particles, upward burst |
| Gold sparks | Only when `has_gold = true` | Gold gradient, 16 particles, spread 180° |

Gold gradient: bright gold `(1,0.95,0.4)` → rich gold `(1,0.75,0.1)` → transparent orange.

### TerrainManager reference
Fetched with `await get_tree().process_frame` then `get_first_node_in_group("terrain")`. Must not be cached before that frame.

---

## scanner_component.gd

### Scan trigger
- `scan` action (Spacebar) via `is_action_just_pressed` in `_process`
- Guarded by `is_ready_to_scan` cooldown flag

### Scan algorithm
```gdscript
center_tile = terrain_manager.world_to_tile(player.global_position)
radius_tiles = int(scan_radius / Config.TILE_SIZE)  # 80 / 16 = 5 tiles

for tile_pos in terrain_manager.gold_deposits.keys():
    if center_tile.distance_to(tile_pos) <= radius_tiles:
        terrain_manager.gold_deposits[tile_pos].revealed = true
        detected.append(tile_pos)
```
Iterates the gold dictionary directly — O(n) on deposit count, not terrain size.

### After scan
1. `EventBus.gold_detected.emit(detected_deposits)`
2. `terrain_manager.highlight_gold_tiles(detected_deposits)` — creates golden ColorRect overlays
3. Spawns `scan_effect.gd` as `Node2D` added to current scene

### Cooldown
```gdscript
# Internal Timer node, one_shot
cooldown_timer.start(scan_cooldown)  # 3.0s default

# HUD reads this:
get_cooldown_remaining() -> float  # → cooldown_timer.time_left
```

### Debug: F3 reveal all gold
Detected via `is_physical_key_pressed(KEY_F3)` with edge detection (`f3_was_pressed` flag).
Emits `EventBus.debug_reveal_gold` which TerrainManager listens to.

### Group registration
`add_to_group("scanner")` — used by `hud_controller.gd` to find and query `get_cooldown_remaining()`.
