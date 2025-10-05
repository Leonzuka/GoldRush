extends TileMapLayer

# Block type constants
enum BlockType {
	GRASS = 0,
	DIRT = 1,
	STONE = 2,
	EMPTY = -1
}

# Dictionary to store blocks with gold (generated at runtime when digging)
var blocks_with_gold = {}

# Tileset reference
var custom_tileset: TileSet

func _ready():
	setup_tileset()
	load_terrain()

func setup_tileset():
	custom_tileset = TileSet.new()
	tile_set = custom_tileset

	# Add physics layer to TileSet BEFORE setting up tiles
	custom_tileset.add_physics_layer()

	# Try to load external texture, otherwise create atlas
	var texture = try_load_external_texture()
	if not texture:
		texture = create_atlas_texture()

	# Create source for tiles
	var source = TileSetAtlasSource.new()
	source.texture = texture
	custom_tileset.add_source(source, 0)

	# Configure tiles in atlas
	source.texture_region_size = Vector2i(32, 32)

	# Create tiles for each type
	# Tile 0: Grass (green) - atlas coords (0,0) - NO collision (visual only)
	source.create_tile(Vector2i(0, 0))

	# Tile 1: Dirt (brown) - atlas coords (1,0) - WITH collision
	source.create_tile(Vector2i(1, 0))
	setup_tile_collision(source, Vector2i(1, 0))

	# Tile 2: Stone (gray) - atlas coords (2,0) - WITH collision
	source.create_tile(Vector2i(2, 0))
	setup_tile_collision(source, Vector2i(2, 0))

	print("Tileset configured")

func setup_tile_collision(source: TileSetAtlasSource, atlas_coords: Vector2i):
	var tile_data = source.get_tile_data(atlas_coords, 0)
	tile_data.add_collision_polygon(0)

	# Create collision rectangle covering entire tile
	# Local coordinates: -16 to +16 (tile center)
	var collision_polygon = PackedVector2Array()
	collision_polygon.push_back(Vector2(-16, -16))
	collision_polygon.push_back(Vector2(16, -16))
	collision_polygon.push_back(Vector2(16, 16))
	collision_polygon.push_back(Vector2(-16, 16))

	tile_data.set_collision_polygon_points(0, 0, collision_polygon)

func try_load_external_texture() -> Texture2D:
	var texture_path = "res://terrain_tiles.png"
	if FileAccess.file_exists(texture_path):
		var texture = load(texture_path)
		if texture:
			print("External texture loaded: ", texture_path)
			return texture
		else:
			print("Failed to load texture: ", texture_path)
	else:
		print("External texture not found: ", texture_path)

	return null

func create_atlas_texture() -> ImageTexture:
	# Create atlas texture 96x32 (3 tiles of 32x32)
	var atlas_image = Image.create(96, 32, false, Image.FORMAT_RGB8)

	# Grass (green) - position (0,0)
	for x in range(32):
		for y in range(32):
			atlas_image.set_pixel(x, y, Color.GREEN)

	# Dirt (brown) - position (32,0)
	for x in range(32, 64):
		for y in range(32):
			atlas_image.set_pixel(x, y, Color(0.6, 0.4, 0.2))

	# Stone (gray) - position (64,0)
	for x in range(64, 96):
		for y in range(32):
			atlas_image.set_pixel(x, y, Color.GRAY)

	var texture = ImageTexture.new()
	texture.set_image(atlas_image)
	return texture

func load_terrain():
	# Load terrain from visual editor JSON file
	var terrain_file_path = "res://terrain_data.json"
	var file = FileAccess.open(terrain_file_path, FileAccess.READ)

	if not file:
		print("Terrain file not found: ", terrain_file_path)
		print("Please use TerrainEditor.tscn to create your terrain first!")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		print("Error parsing terrain data")
		return

	var terrain_data = json.data
	load_terrain_from_data(terrain_data)

func load_terrain_from_data(terrain_data: Dictionary):
	clear()

	var tiles_loaded = 0
	for pos_string in terrain_data.keys():
		var cell_pos = str_to_var(pos_string)
		var tile_type = terrain_data[pos_string]

		# Set cell with source_id=0 and atlas_coords based on type
		set_cell(cell_pos, 0, Vector2i(tile_type, 0))
		tiles_loaded += 1

	print("Terrain loaded: ", tiles_loaded, " tiles")
	notify_runtime_tile_data_update()

func dig_block(world_pos: Vector2i) -> Dictionary:
	var result = {"success": false, "has_gold": false, "block_type": BlockType.EMPTY}

	# Check if block exists at this position
	var cell_data = get_cell_source_id(world_pos)
	if cell_data == -1:
		return result

	# Get block type
	var atlas_coords = get_cell_atlas_coords(world_pos)
	var block_type = BlockType.EMPTY
	if atlas_coords != Vector2i(-1, -1):
		block_type = atlas_coords.x

	# DO NOT allow digging grass directly
	if block_type == BlockType.GRASS:
		return result

	# Generate gold chance when digging (runtime, not pre-generated)
	var has_gold = calculate_gold_chance(world_pos)

	# Remove block
	erase_cell(world_pos)

	# If digging dirt at layer 1, check if there's grass above to remove
	if block_type == BlockType.DIRT and world_pos.y == 1:
		var grass_pos = Vector2i(world_pos.x, 0)
		var grass_cell = get_cell_source_id(grass_pos)
		if grass_cell != -1:
			var grass_atlas = get_cell_atlas_coords(grass_pos)
			if grass_atlas.x == BlockType.GRASS:
				erase_cell(grass_pos)

	# Force collision update
	notify_runtime_tile_data_update()

	result.success = true
	result.has_gold = has_gold
	result.block_type = block_type

	return result

func calculate_gold_chance(world_pos: Vector2i) -> bool:
	# Gold probability by depth
	var y = world_pos.y

	# Surface (layer 0) - no gold
	if y == 0:
		return false

	# Dirt layers (1-10) - 5% to 32% increasing with depth
	var probability = 0.0
	if y >= 1 and y <= 10:
		probability = 0.05 + (y - 1) * 0.03  # 5% at y=1, up to 32% at y=10
	# Stone layers (11+) - 40% chance
	elif y > 10:
		probability = 0.40

	# Use position as seed for determinism
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(world_pos)

	return rng.randf() < probability

func world_to_tile_pos(world_position: Vector2) -> Vector2i:
	var local_pos = to_local(world_position)
	var tile_pos = local_to_map(local_pos)
	return tile_pos

func get_dig_difficulty(world_pos: Vector2i) -> float:
	var cell_data = get_cell_source_id(world_pos)
	if cell_data == -1:
		return 0.0

	var atlas_coords = get_cell_atlas_coords(world_pos)
	var block_type = BlockType.EMPTY
	if atlas_coords != Vector2i(-1, -1):
		block_type = atlas_coords.x

	match block_type:
		BlockType.GRASS:
			return 0.0  # Grass cannot be dug
		BlockType.DIRT:
			return 1.0  # 1 second base time
		BlockType.STONE:
			return 2.0  # 2 seconds base time
		_:
			return 0.0

func has_block_at(world_pos: Vector2i) -> bool:
	return get_cell_source_id(world_pos) != -1

func can_dig_at(world_pos: Vector2i) -> bool:
	if not has_block_at(world_pos):
		return false

	var atlas_coords = get_cell_atlas_coords(world_pos)
	if atlas_coords == Vector2i(-1, -1):
		return false

	var block_type = atlas_coords.x

	# DO NOT allow digging grass (visual only)
	if block_type == BlockType.GRASS:
		return false

	# Allow digging dirt and stone
	return block_type == BlockType.DIRT or block_type == BlockType.STONE
