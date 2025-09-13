# Godot 4.4 TileMapLayer Documentation

## Overview

No Godot 4.3+, o nó `TileMap` foi deprecado e substituído pelo sistema `TileMapLayer`. Esta mudança traz melhor organização, API mais simples e segue melhor os padrões de design do Godot.

## Diferenças Principais

### Antes (TileMap - Deprecado)
```gdscript
# Um único nó TileMap com múltiplas camadas
extends TileMap

func _ready():
    # Trabalhar com camadas através de índices
    set_cell(0, Vector2i(x, y), source_id, atlas_coords)  # Layer 0
    set_cell(1, Vector2i(x, y), source_id, atlas_coords)  # Layer 1
```

### Depois (TileMapLayer - Atual)
```gdscript
# Múltiplos nós TileMapLayer, um para cada camada
extends TileMapLayer

func _ready():
    # Cada TileMapLayer é independente
    set_cell(Vector2i(x, y), source_id, atlas_coords)
    # Sem especificação de layer - cada nó é uma camada
```

## Migração

### 1. Estrutura de Nós
```
# Antes:
World/
  └── TileMap (com múltiplas layers)

# Depois:  
World/
  ├── BackgroundLayer (TileMapLayer)
  ├── TerrainLayer (TileMapLayer)
  └── ForegroundLayer (TileMapLayer)
```

### 2. Script Changes
```gdscript
# ANTES - TileMap (Deprecado)
extends TileMap

func dig_block(pos: Vector2i):
    set_cell(0, pos, -1)  # Layer 0

func get_cell_type(pos: Vector2i):
    return get_cell_source_id(0, pos)

# DEPOIS - TileMapLayer (Atual)
extends TileMapLayer

func dig_block(pos: Vector2i):
    set_cell(pos, -1)  # Sem layer parameter

func get_cell_type(pos: Vector2i):
    return get_cell_source_id(pos)
```

## API Principal do TileMapLayer

### Métodos Principais
```gdscript
# Definir célula
set_cell(coords: Vector2i, source_id: int = -1, atlas_coords: Vector2i = Vector2i(-1, -1), alternative_tile: int = 0)

# Obter informações da célula
get_cell_source_id(coords: Vector2i) -> int
get_cell_atlas_coords(coords: Vector2i) -> Vector2i
get_cell_alternative_tile(coords: Vector2i) -> int

# Conversões de coordenadas
local_to_map(local_position: Vector2) -> Vector2i
map_to_local(map_position: Vector2i) -> Vector2

# Limpeza
erase_cell(coords: Vector2i)
clear()
```

### Propriedades Importantes
```gdscript
# TileSet resource
tile_set: TileSet

# Habilitado/Desabilitado
enabled: bool

# Modulate e transparência
modulate: Color
self_modulate: Color
```

## Vantagens do TileMapLayer

1. **Organização Clara**: Cada layer é um nó separado
2. **API Simplificada**: Sem parâmetro de layer nos métodos
3. **Melhor Performance**: Cada layer pode ser otimizada independentemente
4. **Inspector Limpo**: Menos confusão nas propriedades
5. **Compatibilidade**: Segue padrões do Godot (um nó, uma responsabilidade)

## Exemplo Completo

```gdscript
# TerrainManager.gd - Nova implementação
extends TileMapLayer

const WORLD_WIDTH = 80
const WORLD_HEIGHT = 50

func _ready():
    setup_tileset()
    generate_terrain()

func setup_tileset():
    var tileset = TileSet.new()
    var source = TileSetAtlasSource.new()
    
    # Configurar atlas texture
    source.texture = create_terrain_texture()
    source.texture_region_size = Vector2i(32, 32)
    
    # Adicionar tiles
    source.create_tile(Vector2i(0, 0))  # Grass
    source.create_tile(Vector2i(1, 0))  # Dirt  
    source.create_tile(Vector2i(2, 0))  # Stone
    
    tileset.add_source(source, 0)
    tile_set = tileset

func generate_terrain():
    for x in range(WORLD_WIDTH):
        for y in range(WORLD_HEIGHT):
            var tile_type = get_tile_type(x, y)
            if tile_type >= 0:
                set_cell(Vector2i(x, y), 0, Vector2i(tile_type, 0))

func dig_block(pos: Vector2i) -> Dictionary:
    var result = {"success": false, "has_gold": false}
    
    # Verificar se existe bloco
    if get_cell_source_id(pos) == -1:
        return result
    
    # Remover bloco
    erase_cell(pos)
    result.success = true
    
    return result
```

## Conversão Automática

No Godot Editor, você pode converter TileMap existente:
1. Selecione o nó TileMap
2. Abra o painel inferior do TileMap
3. Clique no ícone de ferramentas no canto superior direito
4. Escolha "Convert to TileMapLayer nodes"

## Compatibilidade

- **Godot 4.0-4.2**: TileMap disponível
- **Godot 4.3+**: TileMap deprecado, use TileMapLayer
- **Godot 4.4**: TileMapLayer é o padrão recomendado