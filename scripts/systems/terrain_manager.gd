extends Node2D
class_name TerrainManager

## Manages terrain generation, gold deposits, and tile manipulation
## Uses TileMap for rendering + Dictionary for hidden gold data

# ============================================================================
# EXPORTS
# ============================================================================

@export var terrain_width: int = Config.TERRAIN_WIDTH
@export var terrain_height: int = Config.TERRAIN_HEIGHT

# ============================================================================
# NODES
# ============================================================================

@onready var tilemap: TileMap = $GroundTileMap

# ============================================================================
# DATA
# ============================================================================

## Hidden gold deposit data (NOT stored in TileMap)
## Key: Vector2i (tile position), Value: Dictionary {amount, richness, revealed}
var gold_deposits: Dictionary = {}

## Tile IDs (matches tileset configuration)
const TILE_EMPTY: int = -1
const TILE_DIRT: int = 0
const TILE_STONE: int = 1
const TILE_BEDROCK: int = 2

# ============================================================================
# GENERATION
# ============================================================================

## Generate procedural terrain with hidden gold deposits
## @param seed_value: Random seed for deterministic generation
## @param gold_richness: Multiplier for deposit count (0.5-1.5)
func generate_terrain(seed_value: int, gold_richness: float) -> void:
	# Set random seed for reproducibility
	seed(seed_value)

	# Clear existing data
	tilemap.clear()
	gold_deposits.clear()

	# Generate terrain layers
	_generate_terrain_tiles()

	# Place gold deposits
	var deposit_count: int = Config.get_deposit_count(gold_richness)
	_generate_gold_deposits(deposit_count)

	print("[Terrain] Generated: Seed=%d, Richness=%.2f, Deposits=%d" % [seed_value, gold_richness, deposit_count])

## Fill TileMap with layered terrain
func _generate_terrain_tiles() -> void:
	for y in range(terrain_height):
		for x in range(terrain_width):
			var depth_factor: float = float(y) / terrain_height
			var tile_id: int

			# Stratified layers based on depth
			if depth_factor < 0.2:
				tile_id = TILE_DIRT
			elif depth_factor < 0.85:
				tile_id = TILE_STONE
			else:
				tile_id = TILE_BEDROCK

			# Add some noise for variation
			if randf() < 0.1:
				tile_id = min(tile_id + 1, TILE_BEDROCK)

			tilemap.set_cell(0, Vector2i(x, y), 0, Vector2i(tile_id, 0))

## Generate clustered gold deposits
func _generate_gold_deposits(count: int) -> void:
	var clusters: int = max(1, int(count / 5.0))  # 5 deposits per cluster average

	for i in range(clusters):
		var cluster_center: Vector2i = Vector2i(
			randi_range(5, terrain_width - 5),
			randi_range(10, terrain_height - 10)  # Avoid surface
		)

		var cluster_size: int = randi_range(3, 8)
		_create_gold_cluster(cluster_center, cluster_size)

## Create gold deposits in cluster pattern
func _create_gold_cluster(center: Vector2i, size: int) -> void:
	for i in range(size):
		var offset: Vector2i = Vector2i(
			randi_range(-4, 4),
			randi_range(-4, 4)
		)
		var pos: Vector2i = center + offset

		# Ensure within bounds and not already occupied
		if pos.x < 0 or pos.x >= terrain_width or pos.y < 0 or pos.y >= terrain_height:
			continue
		if gold_deposits.has(pos):
			continue

		# Create deposit
		gold_deposits[pos] = {
			"amount": randi_range(Config.MIN_GOLD_AMOUNT, Config.MAX_GOLD_AMOUNT),
			"richness": randf_range(0.8, 1.2),
			"revealed": false
		}

# ============================================================================
# DIGGING
# ============================================================================

## Attempt to dig a tile at grid position
## @param tile_pos: Grid position (Vector2i)
## @return Dictionary: {success: bool, has_gold: bool, gold_amount: int}
func dig_tile(tile_pos: Vector2i) -> Dictionary:
	var tile_id: int = tilemap.get_cell_source_id(0, tile_pos)

	# Check if tile is diggable
	if tile_id == TILE_EMPTY or tile_id == TILE_BEDROCK:
		return {success = false, has_gold = false, gold_amount = 0}

	# Remove tile
	tilemap.set_cell(0, tile_pos, -1, Vector2i(-1, -1))

	# Check for gold
	var result: Dictionary = {success = true, has_gold = false, gold_amount = 0}
	if gold_deposits.has(tile_pos):
		var deposit: Dictionary = gold_deposits[tile_pos]
		result.has_gold = true
		result.gold_amount = deposit.amount
		gold_deposits.erase(tile_pos)

	EventBus.tile_dug.emit(tile_pos)
	return result

# ============================================================================
# UTILITY
# ============================================================================

## Convert world position to tile grid position
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(to_local(world_pos))

## Convert tile grid position to world position (center)
func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return to_global(tilemap.map_to_local(tile_pos))

## Highlight revealed gold deposits (visual feedback)
func highlight_gold_tiles(positions: Array) -> void:
	for pos in positions:
		if pos is Vector2i:
			# Yellow tint for revealed gold
			tilemap.set_cell(0, pos, 0, Vector2i(tilemap.get_cell_atlas_coords(0, pos)), 0)

# ============================================================================
# DEBUG
# ============================================================================

func _ready() -> void:
	EventBus.debug_mode_changed.connect(_on_debug_mode_changed)
	EventBus.debug_reveal_gold.connect(_reveal_all_gold)

var debug_mode: bool = false

func _on_debug_mode_changed(enabled: bool) -> void:
	debug_mode = enabled
	queue_redraw()

func _reveal_all_gold() -> void:
	for pos in gold_deposits.keys():
		gold_deposits[pos].revealed = true
	queue_redraw()

func _draw() -> void:
	if not debug_mode:
		return

	# Draw circles at all gold deposit positions
	for pos in gold_deposits.keys():
		var world_pos: Vector2 = tile_to_world(pos)
		var local_pos: Vector2 = to_local(world_pos)
		var color: Color = Color.YELLOW if gold_deposits[pos].revealed else Color.ORANGE
		draw_circle(local_pos, 8, color)
