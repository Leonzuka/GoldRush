@tool
extends Node2D

# Terrain Editor for visual map editing in Godot editor
# This allows you to paint terrain visually and save it for the game

@onready var tile_map_layer = $TileMapLayer
@onready var camera = $Camera2D
@onready var current_tile_label = $UI/CurrentTileLabel

# Tile types matching the original system
enum TileType {
	GRASS = 0,
	DIRT = 1,
	STONE = 2
}

var current_tile_type = TileType.GRASS
var tile_names = ["Grass", "Dirt", "Stone"]

# World dimensions (same as original)
const WORLD_WIDTH = 80
const WORLD_HEIGHT = 50

var is_painting = false
var is_erasing = false

func _ready():
	# Setup tileset programatically
	setup_tileset()

	# Center camera on the world
	var world_center = Vector2(WORLD_WIDTH * 16, WORLD_HEIGHT * 16)  # 16 = half tile size
	camera.position = world_center

	update_current_tile_label()
	print("Terrain Editor ready! Use mouse to paint terrain.")
	print("Controls:")
	print("- Left Click: Paint | Right Click: Erase")
	print("- 1,2,3: Select tile type | S: Save | L: Load | G: Generate")

func setup_tileset():
	# Criar tileset programaticamente para o editor
	var tileset = TileSet.new()
	tile_map_layer.tile_set = tileset

	# Adicionar camada de física
	tileset.add_physics_layer()

	# Tentar carregar textura externa, senão criar interna
	var texture = try_load_external_texture()
	if not texture:
		texture = create_atlas_texture()

	# Source para os tiles
	var source = TileSetAtlasSource.new()
	source.texture = texture
	tileset.add_source(source, 0)

	# Configurar os tiles no atlas
	source.texture_region_size = Vector2i(32, 32)

	# Criar tiles para cada tipo
	source.create_tile(Vector2i(0, 0))  # Grama - sem colisão
	source.create_tile(Vector2i(1, 0))  # Terra - com colisão
	source.create_tile(Vector2i(2, 0))  # Pedra - com colisão

	# Configurar colisão para terra e pedra
	setup_tile_collision(source, Vector2i(1, 0))
	setup_tile_collision(source, Vector2i(2, 0))

	print("Tileset configurado para editor")

func try_load_external_texture() -> Texture2D:
	var texture_path = "res://terrain_tiles.png"
	if FileAccess.file_exists(texture_path):
		var texture = load(texture_path)
		if texture:
			print("Textura externa carregada para editor: ", texture_path)
			return texture
	print("Usando texturas internas para editor")
	return null

func create_atlas_texture() -> ImageTexture:
	# Criar uma textura atlas 96x32 (3 tiles de 32x32)
	var atlas_image = Image.create(96, 32, false, Image.FORMAT_RGB8)

	# Grama (verde) - posição (0,0)
	for x in range(32):
		for y in range(32):
			atlas_image.set_pixel(x, y, Color.GREEN)

	# Terra (marrom) - posição (32,0)
	for x in range(32, 64):
		for y in range(32):
			atlas_image.set_pixel(x, y, Color(0.6, 0.4, 0.2))

	# Pedra (cinza) - posição (64,0)
	for x in range(64, 96):
		for y in range(32):
			atlas_image.set_pixel(x, y, Color.GRAY)

	var texture = ImageTexture.new()
	texture.set_image(atlas_image)
	return texture

func setup_tile_collision(source: TileSetAtlasSource, atlas_coords: Vector2i):
	var tile_data = source.get_tile_data(atlas_coords, 0)
	tile_data.add_collision_polygon(0)

	var collision_polygon = PackedVector2Array()
	collision_polygon.push_back(Vector2(-16, -16))
	collision_polygon.push_back(Vector2(16, -16))
	collision_polygon.push_back(Vector2(16, 16))
	collision_polygon.push_back(Vector2(-16, 16))

	tile_data.set_collision_polygon_points(0, 0, collision_polygon)

func _input(event):
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		cycle_tile_type(-1)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		cycle_tile_type(1)
	elif event is InputEventKey and event.pressed:
		handle_key_input(event)

func handle_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		is_painting = event.pressed
		if event.pressed:
			paint_tile_at_mouse()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		is_erasing = event.pressed
		if event.pressed:
			erase_tile_at_mouse()

func handle_mouse_motion(event: InputEventMouseMotion):
	if is_painting:
		paint_tile_at_mouse()
	elif is_erasing:
		erase_tile_at_mouse()

func handle_key_input(event: InputEventKey):
	match event.keycode:
		KEY_1:
			set_current_tile_type(TileType.GRASS)
		KEY_2:
			set_current_tile_type(TileType.DIRT)
		KEY_3:
			set_current_tile_type(TileType.STONE)
		KEY_S:
			save_terrain()
		KEY_L:
			load_default_terrain()
		KEY_G:
			generate_procedural_terrain()

func paint_tile_at_mouse():
	var mouse_pos = get_global_mouse_position()
	var tile_pos = tile_map_layer.local_to_map(tile_map_layer.to_local(mouse_pos))

	# Check bounds
	if tile_pos.x >= 0 and tile_pos.x < WORLD_WIDTH and tile_pos.y >= 0 and tile_pos.y < WORLD_HEIGHT:
		tile_map_layer.set_cell(tile_pos, 0, Vector2i(current_tile_type, 0))

func erase_tile_at_mouse():
	var mouse_pos = get_global_mouse_position()
	var tile_pos = tile_map_layer.local_to_map(tile_map_layer.to_local(mouse_pos))

	# Check bounds
	if tile_pos.x >= 0 and tile_pos.x < WORLD_WIDTH and tile_pos.y >= 0 and tile_pos.y < WORLD_HEIGHT:
		tile_map_layer.erase_cell(tile_pos)

func cycle_tile_type(direction: int):
	current_tile_type = (current_tile_type + direction) % len(TileType.values())
	if current_tile_type < 0:
		current_tile_type = len(TileType.values()) - 1
	update_current_tile_label()

func set_current_tile_type(tile_type: TileType):
	current_tile_type = tile_type
	update_current_tile_label()

func update_current_tile_label():
	if current_tile_label:
		current_tile_label.text = "Current: %s (%d)" % [tile_names[current_tile_type], current_tile_type]

func save_terrain():
	print("Saving terrain to terrain_data.tres...")

	# Create a resource to store terrain data
	var terrain_data = {}

	# Get all used cells
	var used_cells = tile_map_layer.get_used_cells()

	for cell_pos in used_cells:
		var atlas_coords = tile_map_layer.get_cell_atlas_coords(cell_pos)
		if atlas_coords != Vector2i(-1, -1):
			terrain_data[var_to_str(cell_pos)] = atlas_coords.x

	# Save to file
	var file = FileAccess.open("res://terrain_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(terrain_data))
		file.close()
		print("Terrain saved successfully!")
		print("Found %d tiles to save" % used_cells.size())
	else:
		print("Failed to save terrain data")

func load_default_terrain():
	print("Loading default terrain...")

	var file = FileAccess.open("res://terrain_data.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			var terrain_data = json.data

			# Clear existing terrain
			tile_map_layer.clear()

			# Load terrain data
			for pos_string in terrain_data.keys():
				var cell_pos = str_to_var(pos_string)
				var tile_type = terrain_data[pos_string]
				tile_map_layer.set_cell(cell_pos, 0, Vector2i(tile_type, 0))

			print("Terrain loaded successfully!")
			print("Loaded %d tiles" % terrain_data.size())
		else:
			print("Failed to parse terrain data")
	else:
		print("No terrain data file found - generating procedural terrain instead")
		generate_procedural_terrain()

func generate_procedural_terrain():
	print("Generating procedural terrain (same as original)...")

	# Clear existing terrain
	tile_map_layer.clear()

	# Generate terrain using original logic
	for x in range(WORLD_WIDTH):
		for y in range(WORLD_HEIGHT):
			var block_type = get_block_type_for_position(x, y)
			if block_type != -1:  # -1 = empty/air
				tile_map_layer.set_cell(Vector2i(x, y), 0, Vector2i(block_type, 0))

	print("Procedural terrain generated!")

func get_block_type_for_position(x: int, y: int) -> int:
	# Same logic as original TerrainManager
	const DIRT_LAYERS = 10

	if y == 0:
		return TileType.GRASS
	elif y <= DIRT_LAYERS:
		return TileType.DIRT
	else:
		return TileType.STONE