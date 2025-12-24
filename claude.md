# Claude Code - GoldRush Project Guide

This document provides AI assistants (like Claude) with comprehensive context about the GoldRush project structure, conventions, and implementation details.

## Project Overview

**GoldRush** is a 2D mining game inspired by Turmoil, built with Godot 4.5. It features:
- Land auction system with NPC AI competitors
- Procedural terrain generation with hidden gold deposits
- Real-time mining with drill and scanner mechanics
- Round-based progression with resource management

**Technology Stack:**
- Engine: Godot 4.5
- Language: GDScript
- Rendering: Forward+ (desktop-first)
- Architecture: Signal-driven, component-based

## Code Style & Conventions

### Naming Conventions

```gdscript
# Files: snake_case
terrain_manager.gd
plot_card.tscn

# Classes: PascalCase
class_name TerrainManager
class_name PlotData

# Variables/Functions: snake_case
var gold_deposits: Dictionary
func dig_tile(tile_pos: Vector2i) -> Dictionary

# Constants: UPPER_SNAKE_CASE
const STARTING_MONEY: int = 1000
const TILE_SIZE: int = 16

# Signals: snake_case (past tense or noun)
signal gold_collected(amount: int)
signal auction_won(plot_data: Resource)

# Private functions: prefix with underscore
func _generate_terrain_tiles() -> void
```

### Documentation Standards

```gdscript
## Brief one-line description of class/function
##
## Detailed explanation spanning multiple lines if needed.
## Describe behavior, side effects, and important details.
##
## @param param_name: Description of parameter
## @return: Description of return value (if applicable)

class_name TerrainManager
extends Node2D

## Generates procedural terrain with hidden gold deposits
##
## Uses a seeded RNG to ensure deterministic generation.
## The same seed will always produce identical terrain.
##
## @param seed_value: Random seed for terrain generation
## @param gold_richness: Multiplier for gold deposit count (0.5-1.5)
func generate_terrain(seed_value: int, gold_richness: float) -> void:
	# Implementation here
	pass
```

### Signal Connection Pattern

```gdscript
# Prefer explicit function connections for complex logic
func _ready() -> void:
	EventBus.gold_collected.connect(_on_gold_collected)
	EventBus.auction_won.connect(_on_auction_won)

func _on_gold_collected(amount: int) -> void:
	# Complex logic here
	pass

# Use lambdas only for simple one-liners
EventBus.money_changed.connect(func(amount): money_label.text = "$%d" % amount)
```

### Type Hints

Always use type hints for better IDE support and error prevention:

```gdscript
# Variables
var player_money: int = 1000
var current_plot: PlotData = null
var gold_deposits: Dictionary = {}  # Key: Vector2i, Value: Dictionary

# Function parameters and return types
func dig_tile(tile_pos: Vector2i) -> Dictionary:
	return {success: true, has_gold: false}

# Arrays with type hints (Godot 4+)
var available_plots: Array[PlotData] = []
var detected_deposits: Array[Vector2i] = []
```

## Project Architecture

### Core Systems

```
┌─────────────────────────────────────────────────────┐
│                   GAME MANAGER                      │
│  (Autoload: Orchestrates game flow)                │
│  - State machine: MENU → AUCTION → MINING → END    │
│  - Session persistence (money, round, stats)        │
└─────────────────┬───────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
┌───────────────┐   ┌───────────────┐
│  EVENT BUS    │   │    CONFIG     │
│  (Signals)    │   │  (Constants)  │
└───────────────┘   └───────────────┘
        │
┌───────┴──────────────────────────────────┐
│                                           │
▼                                           ▼
AUCTION SYSTEM                      MINING SYSTEMS
- Plot generation                   - TerrainManager (gen, digging)
- NPC AI bidding                    - MiningSession (timer, storage)
- PlotData resources                - Player (movement, components)
                                    - DrillComponent
                                    - ScannerComponent
```

### Signal Flow (EventBus Pattern)

All inter-system communication uses EventBus signals to prevent tight coupling:

```gdscript
# Example: Gold collection flow
DrillComponent.spawn_gold_nugget()
    → GoldNugget spawned
    → Player collides with nugget
    → GoldNugget.collect()
        → EventBus.gold_collected.emit(amount)
            → MiningSession._on_gold_collected()
                → Updates storage, checks limit
                → EventBus.resource_storage_changed.emit()
                    → HUD updates display
```

**Key Signals:**
- `auction_won(plot_data)` - Triggers mining scene load
- `gold_collected(amount)` - Updates storage
- `tile_dug(tile_pos)` - Visual feedback trigger
- `gold_detected(positions)` - Scanner result
- `round_ended(stats)` - Session complete
- `money_changed(amount)` - UI update

### Data Flow

```
PlotData (Resource)
    ↓
AuctionSystem.generate_plots()
    ↓
AuctionUI displays plot cards
    ↓
Player selects plot → NPC simulation
    ↓
EventBus.auction_won.emit(plot)
    ↓
GameManager.start_mining_session(plot)
    ↓
TerrainManager.generate_terrain(plot.seed, plot.richness)
    ↓
Fills TileMap + gold_deposits Dictionary
    ↓
Player drills, scanner detects, collects gold
    ↓
MiningSession.end_session()
    ↓
EventBus.round_ended.emit(stats)
    ↓
GameManager.end_round() → Back to auction
```

## File Organization

### Scene Structure

```
scenes/
├── main/
│   ├── main.tscn              # Entry point (scene switcher)
│   └── main_menu.tscn         # Title screen
│
├── auction/
│   ├── auction.tscn           # Auction interface
│   └── plot_card.tscn         # Reusable plot UI component
│
├── mining/
│   ├── mining_scene.tscn      # Main gameplay (root container)
│   ├── terrain.tscn           # TileMap + TerrainManager
│   ├── player.tscn            # Player CharacterBody2D
│   └── gold_nugget.tscn       # Collectible resource
│
└── ui/
    ├── hud.tscn               # In-game HUD overlay
    └── round_end_panel.tscn   # Summary screen (future)
```

### Script Organization

```
scripts/
├── autoload/                  # Singleton systems
│   ├── game_manager.gd        # State machine, persistence
│   ├── event_bus.gd           # Global signal hub
│   └── config.gd              # Game constants
│
├── systems/                   # Core gameplay systems
│   ├── terrain_manager.gd     # Terrain gen, digging
│   ├── auction_system.gd      # Plot gen, NPC AI
│   └── mining_session.gd      # Timer, storage, round end
│
├── player/                    # Player components
│   ├── player_controller.gd   # Movement, input
│   ├── drill_component.gd     # Drilling mechanics
│   └── scanner_component.gd   # Gold detection
│
├── ui/                        # UI controllers
│   ├── hud_controller.gd      # HUD updates
│   ├── auction_ui_controller.gd
│   ├── main_menu_controller.gd
│   └── plot_card.gd           # Plot card behavior
│
└── collectibles/
    └── gold_nugget.gd         # Auto-collect nugget
```

## Key Technical Decisions

### 1. Terrain System: TileMap + Dictionary Hybrid

**Why not store gold in TileMap?**
- Gold is *hidden* data, not visual
- TileMap is for rendering, not data storage
- Allows flexible detection (scanner reveals without visual change)
- Easy to modify/balance gold amounts independently

**Implementation:**
```gdscript
# terrain_manager.gd
var gold_deposits: Dictionary = {}  # Key: Vector2i, Value: {amount, richness, revealed}

# TileMap stores ONLY visual tiles
@onready var tilemap: TileMap = $GroundTileMap

# Synchronization:
# - Generation: Fill both TileMap and gold_deposits
# - Digging: Check gold_deposits[tile_pos] when tile removed
# - Scanner: Iterate gold_deposits.keys() in radius
```

### 2. Scanner Detection: Area2D vs. Raycast

**Choice:** Area2D with CircleShape2D

**Rationale:**
- Simpler implementation (no loop over raycasts)
- Natural "scan radius" concept
- Godot's Area2D is optimized for overlap checks
- Easy to visualize for player (show scan circle)

**Implementation:**
```gdscript
# scanner_component.gd
func perform_scan() -> Array[Vector2i]:
	var center_tile = terrain_manager.world_to_tile(player.global_position)
	var radius_tiles = int(scan_radius / Config.TILE_SIZE)

	var detected: Array[Vector2i] = []
	for tile_pos in terrain_manager.gold_deposits.keys():
		if center_tile.distance_to(tile_pos) <= radius_tiles:
			terrain_manager.gold_deposits[tile_pos].revealed = true
			detected.append(tile_pos)

	return detected
```

### 3. Gold Collection: Lerp Movement

**Why not pathfinding?**
- Overkill for simple "move to player" behavior
- Lerp is performant and visually smooth
- Nuggets don't need to avoid terrain (pass through)

**Implementation:**
```gdscript
# gold_nugget.gd
func _process(delta: float) -> void:
	if is_collected or not player:
		return

	# Smooth movement toward player
	var target = player.global_position
	global_position = global_position.lerp(target, 5.0 * delta)
```

### 4. EventBus vs. Direct References

**Choice:** Global EventBus singleton

**Rationale:**
- Decouples systems (TerrainManager doesn't know about HUD)
- Easy to add new listeners (e.g., particle manager)
- Prevents circular dependencies
- Godot's signal system is performant

**Trade-off:** Harder to trace signal flow in debugger, but benefits outweigh.

## Common Patterns

### Finding Nodes Safely

```gdscript
# Problem: Node might not exist yet in _ready()
func _ready() -> void:
	# WRONG: May be null
	terrain_manager = get_tree().get_first_node_in_group("terrain")

	# CORRECT: Wait one frame for scene tree to populate
	await get_tree().process_frame
	terrain_manager = get_tree().get_first_node_in_group("terrain")

	if not terrain_manager:
		push_error("TerrainManager not found in scene!")
		return
```

### Creating Timers

```gdscript
# Use built-in Timer node for cooldowns
var cooldown_timer: Timer

func _ready() -> void:
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	add_child(cooldown_timer)

func start_cooldown(duration: float) -> void:
	cooldown_timer.start(duration)

func _on_cooldown_finished() -> void:
	# Ready to perform action again
	pass
```

### Exporting Variables for Inspector

```gdscript
# Make variables adjustable in editor
@export var drill_speed: float = 3.0
@export var scan_radius: float = 80.0
@export_range(1, 10) var difficulty_level: int = 1
@export_file("*.tscn") var gold_nugget_scene_path: String

# Scene references (drag & drop in Inspector)
@export var gold_nugget_scene: PackedScene
```

## Debugging Tips

### Debug Overlay (F12)

```gdscript
# terrain_manager.gd
var debug_mode: bool = false

func _ready() -> void:
	EventBus.debug_mode_changed.connect(_on_debug_mode_changed)

func _on_debug_mode_changed(enabled: bool) -> void:
	debug_mode = enabled
	queue_redraw()  # Trigger _draw()

func _draw() -> void:
	if not debug_mode:
		return

	# Draw circles at all gold positions
	for pos in gold_deposits.keys():
		var world_pos = tile_to_world(pos)
		var local_pos = to_local(world_pos)
		var color = Color.YELLOW if gold_deposits[pos].revealed else Color.ORANGE
		draw_circle(local_pos, 8, color)
```

### Print Debugging

```gdscript
# Use structured print messages
print("[TerrainManager] Generated: Seed=%d, Deposits=%d" % [seed_value, gold_deposits.size()])
print("[Scanner] Detected %d gold deposits" % detected.size())
print("[Session] Ended: %s | Gold: %d | Time: %.1fs" % [reason, gold_collected, elapsed_time])
```

### Profiling Performance

```gdscript
# Monitor → Debugger → Profiler in Godot editor
# Or add FPS counter to HUD
func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
```

## Common Issues & Solutions

### Issue: TileMap Collision Not Working

**Symptoms:** Player falls through terrain

**Solutions:**
1. Check TileMap physics layer enabled (Layer 1)
2. Verify terrain tiles have collision shapes in TileSet editor
3. Ensure player collision mask includes terrain layer (Layer 1)

### Issue: Signals Not Firing

**Symptoms:** UI doesn't update, systems don't respond

**Solutions:**
1. Verify signal name spelling (exact match required)
2. Check connection in `_ready()`: `EventBus.signal_name.connect(func)`
3. Ensure emitter calls `EventBus.signal_name.emit(params)`
4. Use debugger breakpoints in signal handlers

### Issue: Null Reference Errors

**Symptoms:** `Attempt to call function on null instance`

**Solutions:**
1. Use `await get_tree().process_frame` before `get_first_node_in_group()`
2. Check node exists: `if not node: return`
3. Verify node added to correct group (right-click → Groups)
4. Ensure scene is fully loaded before accessing children

### Issue: Gold Nuggets Not Spawning

**Symptoms:** Drill works, tiles removed, but no nuggets

**Solutions:**
1. Check `gold_nugget_scene` is assigned in Inspector
2. Verify nugget container exists in scene tree
3. Ensure `dig_tile()` returns `has_gold: true`
4. Check nugget spawns at correct world position
5. Verify nugget collision layers/masks correct

## Performance Optimization

### Target: 60 FPS on Modest Desktop

**Optimization Strategies:**

1. **TileMap Culling:** Godot handles automatically, but clamp camera to terrain bounds

2. **Object Pooling (Future):** Reuse gold nuggets instead of instantiate/free every time
   ```gdscript
   var nugget_pool: Array[GoldNugget] = []

   func get_nugget() -> GoldNugget:
       if nugget_pool.is_empty():
           return gold_nugget_scene.instantiate()
       return nugget_pool.pop_back()

   func return_nugget(nugget: GoldNugget) -> void:
       nugget.visible = false
       nugget_pool.append(nugget)
   ```

3. **Limit Active Particles:** Max 10-20 particles per emitter

4. **Use `queue_free()` Instead of `free()`:** Deferred deletion prevents mid-frame crashes

5. **Avoid Per-Frame Iteration:** Cache results, use timers for periodic checks

## Testing Checklist

When implementing new features, verify:

- [ ] No errors in Output panel
- [ ] 60 FPS maintained during gameplay
- [ ] All signals connected and firing
- [ ] Null checks for node references
- [ ] Nodes added to correct Godot groups
- [ ] Physics layers/masks configured correctly
- [ ] Type hints on all variables/functions
- [ ] Documentation comments on public APIs
- [ ] Debug print statements removed (or guarded)

## Future Enhancements (Roadmap)

### Phase 2: Market System
- Dynamic gold pricing with market graphs
- Multiple buyers (Bank, Jeweler, Black Market)
- Price fluctuation algorithm (random walk with events)

### Phase 3: Upgrades
- Shop scene between rounds
- Drill speed, storage capacity, scan radius upgrades
- Cost scaling formula

### Phase 4: Polish
- Shader-based smooth digging (see `shaders/terrain_dig.gdshader`)
- Particle effects (dust, sparks, gold shine)
- Sound effects and music integration
- Hand-painted art assets

### Phase 5: Content
- Special events (gold rushes, cave-ins)
- Rival NPC miners in mining phase
- Story mode with narrative
- Multiplayer auction (local/online)

## Quick Reference

### Important File Paths

```
Config Constants:        scripts/autoload/config.gd
EventBus Signals:        scripts/autoload/event_bus.gd
Game State Machine:      scripts/autoload/game_manager.gd
Terrain System:          scripts/systems/terrain_manager.gd
Auction Logic:           scripts/systems/auction_system.gd
Session Timer:           scripts/systems/mining_session.gd
Player Movement:         scripts/player/player_controller.gd
Drilling:                scripts/player/drill_component.gd
Scanner:                 scripts/player/scanner_component.gd
PlotData Resource:       resources/plot_data.gd
```

### Key Constants (Config.gd)

```gdscript
STARTING_MONEY = 1000
ROUND_TIME_LIMIT = 120.0  # seconds
STORAGE_CAPACITY = 100    # gold units
DRILL_SPEED = 3.0         # tiles/second
SCAN_RADIUS = 80.0        # pixels
SCAN_COOLDOWN = 3.0       # seconds
TERRAIN_WIDTH = 100       # tiles
TERRAIN_HEIGHT = 50       # tiles
```

### Debug Commands

```
F12 - Toggle debug overlay (show gold positions)
F1  - Add $1000 (dev build only)
F3  - Reveal all gold (future implementation)
```

## Contributing Guidelines

When adding new features:

1. **Follow naming conventions** (see Code Style section)
2. **Use EventBus for system communication** (avoid direct references)
3. **Add `@export` variables for tunable parameters**
4. **Document public functions with `##` comments**
5. **Test with debug mode (F12) enabled**
6. **Profile performance** (target 60 FPS)
7. **Update this document** if adding new systems/patterns

## Contact & Support

For questions about this codebase:
- Check the comprehensive plan file: `.claude/plans/unified-doodling-rabin.md`
- Review EventBus signals for system communication
- Use debug overlay (F12) to visualize game state
- Read inline code comments in critical systems

---

**Last Updated:** 2025-12-21
**Project Version:** 0.1.0 MVP
**Godot Version:** 4.5+
