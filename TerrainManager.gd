extends TileMapLayer

# Constantes para tipos de blocos
enum BlockType {
	GRASS = 0,
	DIRT = 1,
	STONE = 2,
	EMPTY = -1
}

# Configurações do mundo
const WORLD_WIDTH = 80
const WORLD_HEIGHT = 50
const SURFACE_LAYER = 0
const DIRT_LAYERS = 10
const STONE_START_LAYER = 11

# Probabilidade de ouro por camada
var gold_probability = {
	0: 0.0,    # Superfície - sem ouro
	1: 0.05,   # Camadas de terra - 5% chance
	2: 0.08,   # 8% chance
	3: 0.12,   # 12% chance
	4: 0.15,   # 15% chance
	5: 0.18,   # 18% chance
	6: 0.22,   # 22% chance
	7: 0.25,   # 25% chance
	8: 0.28,   # 28% chance
	9: 0.30,   # 30% chance
	10: 0.32,  # 32% chance
}

# Dicionário para armazenar blocos com ouro
var blocks_with_gold = {}

# Referência ao TileSet (será criado programaticamente)
var custom_tileset: TileSet

func _ready():
	setup_tileset()
	generate_world()
	print("Terreno gerado: ", WORLD_WIDTH, "x", WORLD_HEIGHT, " tiles")

func setup_tileset():
	custom_tileset = TileSet.new()
	tile_set = custom_tileset
	
	# Adicionar camada de física ao TileSet ANTES de configurar tiles
	custom_tileset.add_physics_layer()
	
	# Criar texturas para diferentes tipos de bloco
	var atlas_texture = create_atlas_texture()
	
	# Source para os tiles
	var source = TileSetAtlasSource.new()
	source.texture = atlas_texture
	custom_tileset.add_source(source, 0)
	
	# Configurar os tiles no atlas
	source.texture_region_size = Vector2i(32, 32)
	
	# Criar tiles para cada tipo
	# Tile 0: Grama (verde) - atlas coords (0,0) - SEM colisão (apenas visual)
	source.create_tile(Vector2i(0, 0))
	# Grama não tem colisão!
	
	# Tile 1: Terra (marrom) - atlas coords (1,0) - COM colisão
	source.create_tile(Vector2i(1, 0))
	setup_tile_collision(source, Vector2i(1, 0))
	
	# Tile 2: Pedra (cinza) - atlas coords (2,0) - COM colisão
	source.create_tile(Vector2i(2, 0))
	setup_tile_collision(source, Vector2i(2, 0))

func setup_tile_collision(source: TileSetAtlasSource, atlas_coords: Vector2i):
	# Configurar colisão para o tile
	var tile_data = source.get_tile_data(atlas_coords, 0)
	
	# Adicionar polígono de colisão na camada 0
	tile_data.add_collision_polygon(0)
	
	# Criar um retângulo de colisão cobrindo todo o tile
	# Coordenadas locais: -16 a +16 (centro do tile)
	var collision_polygon = PackedVector2Array()
	collision_polygon.push_back(Vector2(-16, -16))   # Canto superior esquerdo
	collision_polygon.push_back(Vector2(16, -16))    # Canto superior direito
	collision_polygon.push_back(Vector2(16, 16))     # Canto inferior direito  
	collision_polygon.push_back(Vector2(-16, 16))    # Canto inferior esquerdo
	
	tile_data.set_collision_polygon_points(0, 0, collision_polygon)
	
	# Debug detalhado da colisão
	print("Colisão configurada para tile: ", atlas_coords)
	print("  - Polígonos de colisão: ", tile_data.get_collision_polygons_count(0))
	if tile_data.get_collision_polygons_count(0) > 0:
		print("  - Pontos do polígono: ", tile_data.get_collision_polygon_points(0, 0))

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

func generate_world():
	var tiles_placed = 0
	var grass_count = 0
	var dirt_count = 0 
	var stone_count = 0
	
	for x in range(WORLD_WIDTH):
		for y in range(WORLD_HEIGHT):
			var block_type = get_block_type_for_position(x, y)
			
			# Debug: contar tipos de bloco
			match block_type:
				BlockType.GRASS:
					grass_count += 1
				BlockType.DIRT:
					dirt_count += 1
				BlockType.STONE:
					stone_count += 1
			
			if block_type != BlockType.EMPTY:
				set_cell(Vector2i(x, y), 0, Vector2i(block_type, 0))
				tiles_placed += 1
				
				# Verificar se este bloco deve ter ouro
				if should_have_gold(x, y):
					blocks_with_gold[Vector2i(x, y)] = true
	
	print("Tiles colocados: ", tiles_placed)
	print("Grama: ", grass_count, " | Terra: ", dirt_count, " | Pedra: ", stone_count)
	# Debug: verificar alguns tiles específicos com seus tipos
	print("Tile (12, 0): source=", get_cell_source_id(Vector2i(12, 0)), " atlas=", get_cell_atlas_coords(Vector2i(12, 0)))
	print("Tile (12, 1): source=", get_cell_source_id(Vector2i(12, 1)), " atlas=", get_cell_atlas_coords(Vector2i(12, 1)))
	print("Tile (12, 5): source=", get_cell_source_id(Vector2i(12, 5)), " atlas=", get_cell_atlas_coords(Vector2i(12, 5)))

func get_block_type_for_position(x: int, y: int) -> BlockType:
	var block_type: BlockType
	if y == 0:
		block_type = BlockType.GRASS
	elif y <= DIRT_LAYERS:
		block_type = BlockType.DIRT
	else:
		block_type = BlockType.STONE
	
	# Debug para alguns tiles específicos (desabilitado)
	# if x == 12 and (y <= 5):
	#	print("Tile (", x, ", ", y, "): type=", block_type, " | DIRT_LAYERS=", DIRT_LAYERS)
	
	return block_type

func should_have_gold(x: int, y: int) -> bool:
	# Grama (superfície) não tem ouro
	if y == 0:
		return false
	
	# Usar probabilidade baseada na camada
	var layer = min(y, 10)  # Máximo layer 10 para probabilidade
	var probability = gold_probability.get(layer, 0.40)  # Camadas mais profundas têm 40% de chance
	
	# Usar posição como semente para determinismo
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(x, y))
	
	return rng.randf() < probability

func dig_block(world_pos: Vector2i) -> Dictionary:
	var result = {"success": false, "has_gold": false, "block_type": BlockType.EMPTY}
	
	# Verificar se existe um bloco nesta posição
	var cell_data = get_cell_source_id(world_pos)
	if cell_data == -1:  # Não há bloco aqui
		return result
	
	# Verificar o tipo do bloco
	var atlas_coords = get_cell_atlas_coords(world_pos)
	var block_type = BlockType.EMPTY
	if atlas_coords != Vector2i(-1, -1):
		block_type = atlas_coords.x
	
	# NÃO permitir escavar grama diretamente
	if block_type == BlockType.GRASS:
		return result
	
	# Verificar se tem ouro
	var has_gold = blocks_with_gold.has(world_pos)
	
	# Remover o bloco
	erase_cell(world_pos)
	
	# Se escavou terra (layer 1), verificar se há grama acima para remover
	if block_type == BlockType.DIRT and world_pos.y == 1:
		var grass_pos = Vector2i(world_pos.x, 0)  # Posição da grama acima
		var grass_cell = get_cell_source_id(grass_pos)
		if grass_cell != -1:
			var grass_atlas = get_cell_atlas_coords(grass_pos)
			if grass_atlas.x == BlockType.GRASS:
				erase_cell(grass_pos)  # Remover a grama
				print("Grama removida em ", grass_pos, " após escavar terra abaixo")
	
	# Forçar atualização da colisão usando método correto
	notify_runtime_tile_data_update()
	
	# Remover do dicionário de ouro se existir
	if has_gold:
		blocks_with_gold.erase(world_pos)
	
	result.success = true
	result.has_gold = has_gold
	result.block_type = block_type
	
	# Debug com verificação de colisão
	var cell_after = get_cell_source_id(world_pos)
	print("Bloco escavado em ", world_pos, " | Ouro: ", has_gold, " | Cell após: ", cell_after)
	return result

func world_to_tile_pos(world_position: Vector2) -> Vector2i:
	# Converter posição global para posição local do TileMapLayer
	var local_pos = to_local(world_position)
	var tile_pos = local_to_map(local_pos)
	
	# Debug detalhado da conversão (desabilitado para performance)
	# print("  Conversão: world=", world_position, " -> local=", local_pos, " -> tile=", tile_pos)
	
	return tile_pos

func get_dig_difficulty(world_pos: Vector2i) -> float:
	var cell_data = get_cell_source_id(world_pos)
	if cell_data == -1:
		return 0.0
	
	var atlas_coords = get_cell_atlas_coords(world_pos)
	var block_type = BlockType.EMPTY
	if atlas_coords != Vector2i(-1, -1):
		block_type = atlas_coords.x
	
	# Debug da dificuldade (desabilitado para reduzir spam)
	# print("Dig difficulty para bloco tipo ", block_type, " na posição ", world_pos)
	match block_type:
		BlockType.GRASS:
			return 0.0  # Grama não pode ser escavada
		BlockType.DIRT:
			return 1.0  # 1 segundo base
		BlockType.STONE:
			return 2.0  # 2 segundos base
		_:
			return 0.0

func has_block_at(world_pos: Vector2i) -> bool:
	return get_cell_source_id(world_pos) != -1

func can_dig_at(world_pos: Vector2i) -> bool:
	# Verificar se existe um bloco
	if not has_block_at(world_pos):
		return false
	
	# Verificar o tipo do bloco
	var atlas_coords = get_cell_atlas_coords(world_pos)
	if atlas_coords == Vector2i(-1, -1):
		return false
	
	var block_type = atlas_coords.x
	
	# NÃO permitir cavar grama (apenas visual)
	if block_type == BlockType.GRASS:
		return false
	
	# Permitir cavar terra e pedra
	return block_type == BlockType.DIRT or block_type == BlockType.STONE
