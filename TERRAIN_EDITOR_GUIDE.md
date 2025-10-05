# Terrain Editor Guide

## Overview
O GoldRush agora possui um sistema de edição visual de terreno que permite criar e editar mapas diretamente no editor do Godot antes de executar o jogo.

## Files Created
1. `terrain_tiles.png` - Textura com tiles visuais (grama, terra, pedra)
2. `terrain_tileset.tres` - Resource TileSet editável no Godot
3. `TerrainEditor.tscn` - Cena dedicada para editar terreno
4. `TerrainEditorScript.gd` - Script do editor com controles
5. `create_tileset_texture.gd` - Script para gerar texturas (executar uma vez)

## How to Use

### Step 1: Edit Terrain Visually (Ready to use!)
1. Abra a cena `TerrainEditor.tscn` no Godot
2. Use os controles do mouse para pintar o terreno:
   - **Left Click**: Pintar tile selecionado
   - **Right Click**: Apagar tile
   - **Mouse Wheel**: Trocar tipo de tile
   - **1/2/3**: Selecionar Grama/Terra/Pedra
   - **S**: Salvar terreno
   - **L**: Carregar terreno salvo
   - **G**: Gerar terreno procedural

### Step 2: Save and Use in Game
1. Após editar, pressione **S** para salvar
2. O terreno será salvo em `terrain_data.json`
3. Execute `Main.tscn` - o jogo carregará seu terreno customizado automaticamente

### Optional: Enhanced Graphics
Para melhorar as texturas visuais:
1. Execute `create_tileset_texture.gd` no Godot (Tools > Execute Script)
2. Isso criará `terrain_tiles.png` com texturas detalhadas
3. Reinicie o editor - as texturas melhoradas serão usadas automaticamente

## Configuration
No `TerrainManager.gd`, você pode controlar o modo:
- `use_prebuilt_terrain = true`: Usa terreno editado visualmente
- `use_prebuilt_terrain = false`: Gera terreno proceduralmente

## Benefits
✅ **Visual Editing**: Veja o terreno enquanto edita
✅ **Real-time Preview**: Não precisa rodar o jogo para ver mudanças
✅ **Hybrid System**: Combine areas editadas à mão com geração procedural
✅ **Backwards Compatible**: Sistema antigo ainda funciona como fallback
✅ **Mobile Optimized**: Mantém performance e otimizações originais

## Tips
- Grama (verde) é apenas visual - jogadores não podem cavar
- Terra (marrom) é fácil de cavar - 1 segundo base
- Pedra (cinza) é difícil de cavar - 2 segundos base
- O sistema de ouro funciona igual ao original (baseado em profundidade)
- Use o TerrainEditor para fazer mapas únicos ou bases para geração procedural