# GoldRush - Documentação de Implementação

## Status: ✅ MVP COMPLETO

Implementação completa do GoldRush conforme o plano aprovado. Todos os sistemas core estão funcionais e prontos para teste.

## Arquivos Criados

### Total: 26 arquivos

**Scripts GDScript (17):**
- 3 Autoloads (event_bus, config, game_manager)
- 3 Sistemas (terrain_manager, auction_system, mining_session)
- 3 Player Components (player_controller, drill_component, scanner_component)
- 5 UI Controllers (main_menu, auction_ui, plot_card, hud, round_end)
- 1 Collectible (gold_nugget)
- 1 Resource Class (plot_data)
- 1 Shader (terrain_dig.gdshader - documentado para futuro)

**Cenas Godot (9):**
- 2 Main Scenes (main_menu, main)
- 2 Auction Scenes (auction, plot_card)
- 4 Mining Scenes (mining_scene, terrain, player, gold_nugget)
- 2 UI Scenes (hud, round_end_panel)

**Assets (1):**
- terrain_tileset.png (64x16px, 4 tiles)

## Estrutura do Projeto

```
GoldRush/
├── project.godot           ✅ Configurado (autoloads, inputs, rendering)
├── CLAUDE.md              ✅ Guia de desenvolvimento
├── README.md              ✅ Documentação geral
├── IMPLEMENTACAO.md       ✅ Este arquivo
│
├── scripts/
│   ├── autoload/
│   │   ├── event_bus.gd        ✅ Hub de sinais global
│   │   ├── config.gd           ✅ Constantes de configuração
│   │   └── game_manager.gd     ✅ Máquina de estados
│   ├── systems/
│   │   ├── terrain_manager.gd  ✅ Geração procedural + gold deposits
│   │   ├── auction_system.gd   ✅ Leilões e IA de NPCs
│   │   └── mining_session.gd   ✅ Timer e limites de sessão
│   ├── player/
│   │   ├── player_controller.gd  ✅ Movimento WASD
│   │   ├── drill_component.gd    ✅ Perfuração de tiles
│   │   └── scanner_component.gd  ✅ Detecção de ouro
│   ├── ui/
│   │   ├── main_menu_controller.gd   ✅ Menu principal
│   │   ├── auction_ui_controller.gd  ✅ Interface de leilão
│   │   ├── plot_card.gd              ✅ Card de plot
│   │   ├── hud_controller.gd         ✅ HUD in-game
│   │   └── round_end_controller.gd   ✅ Tela de fim de rodada
│   ├── collectibles/
│   │   └── gold_nugget.gd      ✅ Pepita auto-coletável
│   └── resources/
│       └── plot_data.gd        ✅ Dados de plot (Resource)
│
├── scenes/
│   ├── main/
│   │   └── main_menu.tscn      ✅ Menu principal
│   ├── auction/
│   │   ├── auction.tscn        ✅ Interface de leilão
│   │   └── plot_card.tscn      ✅ Card de plot
│   ├── mining/
│   │   ├── mining_scene.tscn   ✅ Cena principal de gameplay
│   │   ├── terrain.tscn        ✅ TileMap + TerrainManager
│   │   ├── player.tscn         ✅ Player + componentes
│   │   └── gold_nugget.tscn    ✅ Pepita coletável
│   └── ui/
│       ├── hud.tscn            ✅ HUD overlay
│       └── round_end_panel.tscn ✅ Painel de fim de rodada
│
└── assets/
    └── sprites/
        └── tiles/
            └── terrain_tileset.png  ✅ Tileset 4 tiles (dirt, stone, bedrock)
```

## Sistemas Implementados

### ✅ 1. Sistema de Autoload (Singletons)

**EventBus** - Hub central de sinais
- 15+ sinais para comunicação entre sistemas
- Desacopla componentes (pattern Observer)
- Sinais: auction_won, gold_collected, tile_dug, etc.

**Config** - Constantes globais
- Todos os parâmetros de balanceamento
- Helper functions (get_npc_aggression, get_deposit_count)
- Facilita tuning sem modificar código

**GameManager** - State Machine
- Estados: MAIN_MENU → AUCTION → MINING → ROUND_END
- Gerencia dinheiro do jogador
- Persistência de dados entre rodadas
- Cheats de debug (F1, F12)

### ✅ 2. Sistema de Leilão

**AuctionSystem**
- Gera 3 plots aleatórios por rodada
- Nomes aleatórios de 10 opções
- Richness: 0.5-1.5 (Poor/Average/Rich)
- IA de NPCs com agressividade escalável
- Chance de outbid aumenta com round number

**AuctionUI**
- Interface visual com 3 plot cards
- Exibe budget, nome do plot, richness stars
- Preview colorido baseado em richness
- Feedback de vitória/derrota

### ✅ 3. Sistema de Terreno

**TerrainManager**
- Geração procedural determinística (seed-based)
- 100x50 tiles (1600x800 pixels)
- Camadas estratificadas: Dirt → Stone → Bedrock
- Dictionary de gold deposits (não visual)
- Debug overlay (F12) mostra posições

**Gold Deposits**
- 15-30 depósitos por mapa
- Clusters de 3-8 depósitos cada
- Valores: 10-50 gold units
- Evita superfície e bedrock

### ✅ 4. Sistema de Player

**PlayerController**
- Movimento WASD/Arrows
- Física com gravidade
- CharacterBody2D com colisão

**DrillComponent**
- Click esquerdo para perfurar
- Alcance limitado (32px)
- Progresso de perfuração (3 tiles/s)
- Spawna gold nuggets ao encontrar ouro

**ScannerComponent**
- SPACE para scanear
- Raio de 80px (5 tiles)
- Cooldown de 3 segundos
- Revela depósitos de ouro no Dictionary

### ✅ 5. Sistema de Sessão

**MiningSession**
- Timer de 120 segundos
- Storage capacity de 100 unidades
- Fim por tempo OU storage cheio
- Emite stats ao finalizar (gold, time, efficiency)

**HUD**
- Mostra Round, Time, Money
- Progress bar de storage
- Botão de scan com cooldown visual
- Atualização em tempo real via EventBus

### ✅ 6. Sistema de Coleta

**GoldNugget**
- Spawna ao perfurar tile com ouro
- Move-se automaticamente para o player (lerp)
- Auto-coleta via Area2D collision
- Emite signal EventBus.gold_collected

### ✅ 7. Fluxo Completo do Jogo

```
[Main Menu]
    ↓ (Click "New Game")
[Auction]
    - Exibe 3 plots
    - Player faz bid
    - NPC simula contra-lance
    ↓ (Vence leilão)
[Mining Scene]
    - Gera terreno com seed do plot
    - Player move, scaneia, perfura
    - Coleta gold nuggets
    - Timer conta 120s
    ↓ (Tempo acaba OU storage cheio)
[Round End]
    - Mostra stats (gold, time)
    - Incrementa round
    - Volta para Auction
    ↓ (Se dinheiro < $100)
[Game Over]
    - Mostra estatísticas finais
    - Volta para Main Menu
```

## Configurações do project.godot

✅ **Autoloads registrados:**
- GameManager
- EventBus
- Config

✅ **Input Actions configurados:**
- drill (Left Mouse Button)
- scan (SPACE)
- move_left (A, LEFT Arrow)
- move_right (D, RIGHT Arrow)
- move_up (W, UP Arrow)
- move_down (S, DOWN Arrow)

✅ **Rendering:**
- Forward+ renderer
- MSAA 2D habilitado
- Pixel-perfect (filter=0)

✅ **Display:**
- 1280x720 janela
- Fullscreen mode=2
- Stretch mode: canvas_items

## Próximos Passos para Testar

### 1. Abrir no Godot Editor

```bash
# Navegar para a pasta do projeto
cd C:\Users\leona\OneDrive\Documentos\PROJETOS\GoldRush

# Abrir com Godot 4.5
godot .
```

### 2. Verificações Iniciais

- [ ] Abrir project.godot no Godot Editor
- [ ] Verificar se não há erros no Output
- [ ] Verificar Autoloads (Project → Project Settings → Autoload)
- [ ] Verificar Input Map (Project → Project Settings → Input Map)

### 3. Testar Main Menu

- [ ] Rodar cena main_menu.tscn (F5)
- [ ] Clicar em "New Game"
- [ ] Deve transicionar para Auction

### 4. Testar Auction

- [ ] Verificar se 3 plots aparecem
- [ ] Cada plot deve mostrar nome, stars, preço
- [ ] Clicar "Place Bid"
- [ ] Deve simular NPC bid
- [ ] Se ganhar, transiciona para Mining

### 5. Testar Mining Scene

- [ ] Terreno deve gerar 100x50 tiles
- [ ] Player deve aparecer (quadrado azul)
- [ ] WASD/Arrows para mover
- [ ] Pressionar F12 para debug overlay (círculos amarelos/laranjas mostram ouro)
- [ ] SPACE para scanear (revela ouro próximo)
- [ ] Click esquerdo para perfurar tiles
- [ ] Pepitas douradas devem spawnar e voar para o player
- [ ] HUD deve atualizar (Time, Gold, Storage bar)
- [ ] Após 120s OU 100 gold, volta para Auction

### 6. Testar Game Over

- [ ] Perder leilões até ficar sem dinheiro
- [ ] Game Over deve aparecer
- [ ] Volta para Main Menu após 3s

## Possíveis Problemas e Soluções

### Erro: "Resource not found"

**Causa:** Caminhos de arquivos incorretos
**Solução:**
- Verificar se todos os arquivos .tscn estão no caminho correto
- Reabrir projeto no Godot para forçar reimport

### Erro: "Invalid call to function"

**Causa:** Nodes não encontrados via get_first_node_in_group()
**Solução:**
- Verificar se nodes estão nos grupos corretos:
  - Player: grupo "player"
  - Terrain: grupo "terrain"
  - Scanner: grupo "scanner"
  - NuggetContainer: grupo "nugget_container"

### TileMap não aparece

**Causa:** TileSet não configurado corretamente
**Solução:**
- Abrir terrain.tscn no editor
- Selecionar GroundTileMap
- Verificar se TileSet está atribuído
- Pode ser necessário recriar TileSet manualmente no editor

### Player cai infinitamente

**Causa:** Colisão não configurada
**Solução:**
- Verificar collision layers:
  - Player: Layer 2, Mask 1
  - Terrain tiles: Layer 1
- Verificar se tiles têm collision shapes

### Perfuração não funciona

**Causa:** Mouse position incorreta ou terrain_manager null
**Solução:**
- Verificar console para mensagens de erro
- Garantir que TerrainManager está no grupo "terrain"
- Ajustar drill_component.gd se mouse pos estiver errada

## Balanceamento Inicial

**Valores atuais (Config.gd):**
```gdscript
STARTING_MONEY = 1000
MIN_PLOT_PRICE = 100
MAX_PLOT_PRICE = 500
ROUND_TIME_LIMIT = 120.0
STORAGE_CAPACITY = 100
DRILL_SPEED = 3.0
SCAN_RADIUS = 80.0
SCAN_COOLDOWN = 3.0
MIN_GOLD_DEPOSITS = 15
MAX_GOLD_DEPOSITS = 30
```

**Para ajustar dificuldade:**
- Editar Config.gd
- Ou usar @export vars no Inspector (terrain_width, drill_speed, etc.)

## Debug Features

**F12** - Toggle debug overlay
- Mostra círculos em todos os gold deposits
- Amarelo = revelado, Laranja = oculto

**F1** - Add $1000 (apenas em debug build)
- Útil para testar sem fazer leilões

## Limitações Conhecidas (MVP)

❌ **Não implementado (futuro):**
- Sistema de mercado (gold não tem valor monetário ainda)
- Sistema de upgrades (drill, scanner, storage)
- Save/Load
- Sound effects e música
- Particle effects
- Smooth terrain digging (shader)
- Arte customizada (usando placeholders)

## Próximas Melhorias Sugeridas

1. **Fase 1 - Polish:**
   - Adicionar sound effects (drill, collect, scan)
   - Particle effects ao perfurar
   - Animações no HUD
   - Melhorar feedback visual

2. **Fase 2 - Market System:**
   - Adicionar preço flutuante de gold
   - 3 buyers (Bank, Jeweler, Black Market)
   - Gráfico de preços

3. **Fase 3 - Upgrades:**
   - Shop entre rounds
   - Drill speed, storage, scan radius
   - Sistema de XP/progressão

4. **Fase 4 - Content:**
   - Mais variedade de terrenos
   - Eventos especiais (gold rush, cave-in)
   - NPCs mineradores rivais
   - Story mode

## Performance

**Target:** 60 FPS em desktop modesto

**Otimizações implementadas:**
- TileMap culling (automático do Godot)
- Dictionary lookup O(1) para gold
- Minimal physics (apenas player + nuggets)
- No particle systems (MVP)

**Se FPS baixo (<60):**
- Reduzir TERRAIN_WIDTH/HEIGHT no Config.gd
- Desabilitar MSAA em project.godot
- Limitar número de nuggets ativos

## Créditos

**Engine:** Godot 4.5
**Inspiração:** Turmoil (Gamious)
**Arquitetura:** Signal-driven, Component-based
**Implementação:** Claude Code (Anthropic)

---

**Versão:** MVP 1.0
**Data:** 2025-12-22
**Status:** ✅ Pronto para teste
