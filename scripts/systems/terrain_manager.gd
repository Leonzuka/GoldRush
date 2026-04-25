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

## Rare deposit data (NOT stored in TileMap)
## Key: Vector2i (tile position), Value: Dictionary {type: String, amount: int}
## Types: "diamond", "relic"
var rare_deposits: Dictionary = {}

## Fossil decoration nodes (always visible in terrain, destroyed when tile is dug)
## Key: Vector2i (tile position), Value: Sprite2D node
var fossil_decorations: Dictionary = {}
var fossil_container: Node2D

## Gold indicator visuals for scanner feedback
## Key: Vector2i (tile position), Value: Node2D (indicator)
var gold_indicators: Dictionary = {}
var indicator_container: Node2D

## Bedrock tile positions tracked for visual overlay
var bedrock_tiles: Array[Vector2i] = []

## Tile IDs (matches tileset configuration)
## Using atlas coordinates (x, y) for tiles WITH collision shapes.
## Row 24 and 25 both carry full-square physics polygons for cols 0-5.
const TILE_EMPTY: int = -1
const TILE_BEDROCK_ATLAS: Vector2i = Vector2i(2, 24)  # NOT diggable — used for walls/bottom

# Row 24 only — row 25 tiles have a grass top edge and bleed background when used underground.
# Cols 0-5 in row 24 all have solid full-square physics, so they're safe to mix.
# Col 2 (BEDROCK) is excluded from diggable zones.

# Dirt-zone variants (depth 0-20%)
const DIRT_TILES: Array[Vector2i] = [
	Vector2i(0, 24), Vector2i(3, 24),
]
# Stone-zone variants (depth 20-55%)
const STONE_TILES: Array[Vector2i] = [
	Vector2i(1, 24), Vector2i(4, 24),
]
# Deep-stone variants (depth 55-85%)
const DEEP_TILES: Array[Vector2i] = [
	Vector2i(5, 24), Vector2i(4, 24),
]

# Keep legacy constants so external code still compiles
const TILE_DIRT_ATLAS: Vector2i = Vector2i(0, 24)
const TILE_STONE_ATLAS: Vector2i = Vector2i(1, 24)

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
	rare_deposits.clear()
	bedrock_tiles.clear()

	# Remove old fossil decoration nodes
	for node in fossil_decorations.values():
		node.queue_free()
	fossil_decorations.clear()

	# Generate terrain layers
	_generate_terrain_tiles()

	# Place gold deposits
	var deposit_count: int = Config.get_deposit_count(gold_richness)
	_generate_gold_deposits(deposit_count)

	# Place rare deposits (diamond, relic) and fossil decorations
	_generate_rare_deposits()
	_generate_fossil_decorations()

	# Trigger bedrock visual overlay render
	queue_redraw()

	print("[Terrain] Generated: Seed=%d, Richness=%.2f, Deposits=%d, Rare=%d, Fossils=%d, Bedrock=%d" % [seed_value, gold_richness, deposit_count, rare_deposits.size(), fossil_decorations.size(), bedrock_tiles.size()])

## Surface zone thickness in tile rows.
## y=0            → DIRT_TILES[0] = top-edge grass tile (border of grass layer)
## y=1..SURF_FILL → DIRT_TILES[1] = grass fill tile    (middle of surface layer)
## y>SURF_FILL    → stone/deep/bedrock tiles            (no grass)
const SURF_FILL_ROWS: int = 3

## Fill TileMap with layered terrain using depth-based tile variety.
## Only row 24 tiles used — row 25 tiles have transparent edges that bleed
## the parallax background when placed underground.
func _generate_terrain_tiles() -> void:
	for y in range(terrain_height):
		for x in range(terrain_width):
			var depth_factor: float = float(y) / terrain_height
			var tile_atlas: Vector2i

			if x == 0 or x == terrain_width - 1:
				# Side walls: always bedrock
				tile_atlas = TILE_BEDROCK_ATLAS
			elif y == 0:
				# Top surface row: border/edge grass tile
				tile_atlas = DIRT_TILES[0]
			elif y <= SURF_FILL_ROWS:
				# Surface fill rows: interior grass tile (middle of surface zone)
				tile_atlas = DIRT_TILES[1]
			elif depth_factor < 0.55:
				# Underground — NO GRASS tiles from here down
				tile_atlas = STONE_TILES[randi() % STONE_TILES.size()]
			elif depth_factor < 0.85:
				tile_atlas = DEEP_TILES[randi() % DEEP_TILES.size()]
			else:
				tile_atlas = TILE_BEDROCK_ATLAS

			tilemap.set_cell(0, Vector2i(x, y), 0, tile_atlas)

			if tile_atlas == TILE_BEDROCK_ATLAS:
				bedrock_tiles.append(Vector2i(x, y))

## Generate clustered gold deposits
func _generate_gold_deposits(count: int) -> void:
	var clusters: int = max(1, int(count / 5.0))  # 5 deposits per cluster average

	for i in range(clusters):
		# Weighted depth: ~40% shallow (rows 3-15), ~60% deeper (rows 15+)
		var min_y: int = 3 if randf() < 0.4 else 15
		var cluster_center: Vector2i = Vector2i(
			randi_range(5, terrain_width - 5),
			randi_range(min_y, terrain_height - 10)
		)

		var cluster_size: int = randi_range(3, 8)
		_create_gold_cluster(cluster_center, cluster_size)

## Generate rare deposits (diamond, relic) scattered across the terrain
func _generate_rare_deposits() -> void:
	var rare_types: Array[Dictionary] = [
		{
			"type": "diamond",
			"count_min": Config.DIAMOND_COUNT_MIN,
			"count_max": Config.DIAMOND_COUNT_MAX,
			"value_min": Config.DIAMOND_VALUE_MIN,
			"value_max": Config.DIAMOND_VALUE_MAX,
			"min_depth": Config.DIAMOND_MIN_DEPTH,
		},
		{
			"type": "relic",
			"count_min": Config.RELIC_COUNT_MIN,
			"count_max": Config.RELIC_COUNT_MAX,
			"value_min": Config.RELIC_VALUE_MIN,
			"value_max": Config.RELIC_VALUE_MAX,
			"min_depth": Config.RELIC_MIN_DEPTH,
		},
	]

	for entry in rare_types:
		var count: int = randi_range(entry.count_min, entry.count_max)
		for i in range(count):
			_place_rare_deposit(entry.type, entry.min_depth, entry.value_min, entry.value_max)

## Spawn Fossil.png sprites as visible terrain decorations (not collectible).
## Each fossil occupies a 2×2 tile block; all 4 tiles point to the same sprite.
## Destroying any of the 4 tiles removes the entire fossil.
func _generate_fossil_decorations() -> void:
	var fossil_texture: Texture2D = load("res://assets/sprites/Fossil.png")
	if not fossil_texture:
		return

	var tex_size: Vector2 = fossil_texture.get_size()
	var display: float = Config.FOSSIL_DISPLAY_PX
	var count: int = randi_range(Config.FOSSIL_COUNT_MIN, Config.FOSSIL_COUNT_MAX)

	for _i in range(count):
		for _attempt in range(30):
			# Pick the top-left corner of the 2×2 block
			var pos := Vector2i(
				randi_range(3, terrain_width - 5),
				randi_range(Config.FOSSIL_MIN_DEPTH, terrain_height - 10)
			)

			# Build the 4 tile positions of the block
			var block: Array[Vector2i] = [
				pos,
				pos + Vector2i(1, 0),
				pos + Vector2i(0, 1),
				pos + Vector2i(1, 1),
			]

			# All 4 tiles must be solid, diggable, and unoccupied
			var valid := true
			for tile in block:
				if gold_deposits.has(tile) or rare_deposits.has(tile) or fossil_decorations.has(tile):
					valid = false
					break
				var atlas: Vector2i = tilemap.get_cell_atlas_coords(0, tile)
				if atlas == TILE_BEDROCK_ATLAS or tilemap.get_cell_source_id(0, tile) == TILE_EMPTY:
					valid = false
					break
			if not valid:
				continue

			# Sprite is centered on the 2×2 block (half-tile offset from top-left center)
			var sprite := Sprite2D.new()
			sprite.texture = fossil_texture
			sprite.scale = Vector2(display / tex_size.x, display / tex_size.y)
			sprite.position = tilemap.map_to_local(pos) + Vector2(Config.TILE_SIZE * 0.5, Config.TILE_SIZE * 0.5)
			sprite.z_index = 3
			fossil_container.add_child(sprite)

			# Register all 4 tile positions → same sprite
			for tile in block:
				fossil_decorations[tile] = sprite

			break  # Placed — move to next fossil

## Place a single rare deposit at a valid random tile
func _place_rare_deposit(type: String, min_depth: int, value_min: int, value_max: int) -> void:
	# Try up to 20 random positions to find a valid diggable tile
	for _attempt in range(20):
		var pos := Vector2i(
			randi_range(5, terrain_width - 5),
			randi_range(min_depth, terrain_height - 8)
		)

		# Skip if occupied by gold, another rare, or not a diggable tile
		if gold_deposits.has(pos) or rare_deposits.has(pos):
			continue
		var tile_atlas: Vector2i = tilemap.get_cell_atlas_coords(0, pos)
		if tile_atlas == TILE_BEDROCK_ATLAS:
			continue
		if tilemap.get_cell_source_id(0, pos) == TILE_EMPTY:
			continue

		rare_deposits[pos] = {
			"type": type,
			"amount": randi_range(value_min, value_max),
		}
		return  # Placed successfully

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

		# Don't place gold in bedrock tiles (side walls, bottom layer)
		var tile_atlas: Vector2i = tilemap.get_cell_atlas_coords(0, pos)
		if tile_atlas == TILE_BEDROCK_ATLAS:
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
	var tile_source: int = tilemap.get_cell_source_id(0, tile_pos)
	var tile_atlas: Vector2i = tilemap.get_cell_atlas_coords(0, tile_pos)

	# Check if tile exists and is diggable
	if tile_source == TILE_EMPTY:
		return {success = false, has_gold = false, gold_amount = 0}

	# Bedrock is not diggable (but this shouldn't happen often as it's deep)
	if tile_atlas == TILE_BEDROCK_ATLAS:
		return {success = false, has_gold = false, gold_amount = 0}

	# Remove tile
	tilemap.set_cell(0, tile_pos, -1, Vector2i(-1, -1))

	# Check for gold
	var result: Dictionary = {
		success = true,
		has_gold = false, gold_amount = 0,
		has_rare = false, rare_type = "", rare_amount = 0,
	}
	if gold_deposits.has(tile_pos):
		var deposit: Dictionary = gold_deposits[tile_pos]
		result.has_gold = true
		result.gold_amount = deposit.amount
		gold_deposits.erase(tile_pos)

	# Check for rare deposit (mutually exclusive with gold — rare takes priority)
	if not result.has_gold and rare_deposits.has(tile_pos):
		var rare: Dictionary = rare_deposits[tile_pos]
		result.has_rare = true
		result.rare_type = rare.type
		result.rare_amount = rare.amount
		rare_deposits.erase(tile_pos)

	# Remove gold indicator if exists
	if gold_indicators.has(tile_pos):
		gold_indicators[tile_pos].queue_free()
		gold_indicators.erase(tile_pos)

	# Remove fossil decoration if exists — clears all 4 tiles of the 2×2 block
	if fossil_decorations.has(tile_pos):
		var fossil_sprite: Node = fossil_decorations[tile_pos]
		var to_remove: Array[Vector2i] = []
		for fpos in fossil_decorations.keys():
			if fossil_decorations[fpos] == fossil_sprite:
				to_remove.append(fpos)
		for fpos in to_remove:
			fossil_decorations.erase(fpos)
		fossil_sprite.queue_free()

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

## Returns true if the tile at the given position is bedrock (not diggable)
func is_bedrock_tile(tile_pos: Vector2i) -> bool:
	return tilemap.get_cell_atlas_coords(0, tile_pos) == TILE_BEDROCK_ATLAS

## Returns true if there is a solid (non-empty) tile at the given position
func has_solid_tile(tile_pos: Vector2i) -> bool:
	return tilemap.get_cell_source_id(0, tile_pos) != TILE_EMPTY

## Highlight revealed gold deposits (visual feedback)
func highlight_gold_tiles(positions: Array) -> void:
	for pos in positions:
		if pos is Vector2i and not gold_indicators.has(pos):
			var indicator := ColorRect.new()
			indicator.size = Vector2(Config.TILE_SIZE, Config.TILE_SIZE)
			indicator.color = Color(1.0, 0.84, 0.0, 0.5)  # Golden semi-transparent
			indicator.position = tilemap.map_to_local(pos) - Vector2(Config.TILE_SIZE / 2.0, Config.TILE_SIZE / 2.0)
			indicator.z_index = 5
			indicator_container.add_child(indicator)
			gold_indicators[pos] = indicator

			# Pulsating animation — bind tween to indicator so it's freed with it
			var tween := indicator.create_tween().set_loops()
			tween.tween_property(indicator, "color:a", 0.2, 0.5)
			tween.tween_property(indicator, "color:a", 0.5, 0.5)

			# Auto-remove after 1 second
			get_tree().create_timer(1.0).timeout.connect(func():
				if gold_indicators.has(pos):
					gold_indicators[pos].queue_free()
					gold_indicators.erase(pos)
			)

# ============================================================================
# DEBUG
# ============================================================================

func _ready() -> void:
	add_to_group("terrain")
	print("[TerrainManager] Ready! Added to 'terrain' group")
	EventBus.debug_mode_changed.connect(_on_debug_mode_changed)
	EventBus.debug_reveal_gold.connect(_reveal_all_gold)

	# Create container for gold indicators
	indicator_container = Node2D.new()
	indicator_container.name = "GoldIndicators"
	add_child(indicator_container)

	# Create container for fossil decoration sprites
	fossil_container = Node2D.new()
	fossil_container.name = "FossilDecorations"
	add_child(fossil_container)

var debug_mode: bool = false

func _on_debug_mode_changed(enabled: bool) -> void:
	debug_mode = enabled
	queue_redraw()

func _reveal_all_gold() -> void:
	var all_positions: Array[Vector2i] = []
	for pos in gold_deposits.keys():
		gold_deposits[pos].revealed = true
		all_positions.append(pos)

	# Emit signal and highlight tiles (same as scanner)
	EventBus.gold_detected.emit(all_positions)
	highlight_gold_tiles(all_positions)

	queue_redraw()
	print("[Debug] Revealed all %d gold deposits" % all_positions.size())

func _draw() -> void:
	# Always draw bedrock overlay so players can see unbreakable tiles
	var half := Config.TILE_SIZE * 0.5
	var bedrock_fill := Color(0.08, 0.04, 0.16, 0.55)   # Dark purple overlay
	var bedrock_line := Color(0.55, 0.35, 0.75, 0.7)    # Bright purple X marks

	for pos in bedrock_tiles:
		var lp: Vector2 = tilemap.map_to_local(pos)
		var tl := lp + Vector2(-half, -half)
		var br := lp + Vector2(half, half)
		var top_right := lp + Vector2(half, -half)
		var bl := lp + Vector2(-half, half)
		draw_rect(Rect2(tl, Vector2(Config.TILE_SIZE, Config.TILE_SIZE)), bedrock_fill)
		draw_line(tl, br, bedrock_line, 1.0)
		draw_line(top_right, bl, bedrock_line, 1.0)

	if not debug_mode:
		return

	# Debug: draw circles at all gold deposit positions
	for pos in gold_deposits.keys():
		var world_pos: Vector2 = tile_to_world(pos)
		var local_pos: Vector2 = to_local(world_pos)
		var color: Color = Color.YELLOW if gold_deposits[pos].revealed else Color.ORANGE
		draw_circle(local_pos, 8, color)
