# GoldRush - TODO List

## 🔴 Tarefas Imediatas (Sprint Atual)
- Refatorar a UI/UX completamente Planmode

### Gameplay Core
- [ ] Testar sistema de leilao com multiplos NPCs
- [ ] Validar balanceamento de dificuldade dos plots
- [ ] Add um PinPoint onde os bots estão escolhendo os lots + placeholder/foto do bot durante o Leilao.

### Qualidade de Codigo
- [ ] Remover prints de debug excessivos (plot_tile.gd, isometric_map_controller.gd)
- [ ] Adicionar guards para null em `_process()` do plot_tile.gd (evitar checks todo frame)

### Balanceamento
- [ ] Testar curva de dificuldade: rounds 1-5 devem ser progressivamente mais dificeis
- [ ] Validar que 25-50 depositos por plot gera gameplay de ~2 minutos satisfatorio

## 🟡 Phase 2: Sistema de Mercado

### Precificacao Dinamica
- [ ] Criar classe `MarketSystem` (autoload) com preco base do ouro
- [ ] Implementar algoritmo de random walk para variacao de precos entre rounds
- [ ] Criar HUD de preco do ouro no menu principal e tela de leilao
- [ ] Criar grafico de flutuacao de precos (historico dos ultimos N rounds)

### Compradores
- [ ] Adicionar multiplos compradores (Banco, Joalheiro, Mercado Negro)
- [ ] Cada comprador com multiplicador de preco diferente e preferencias
- [ ] Tela de venda pos-mineracao (escolher para quem vender)

### Eventos de Mercado
- [ ] Criar eventos que afetam o mercado (descobertas, escassez, inflacao)
- [ ] Notificacao visual quando evento de mercado ocorre
- [ ] Sistema de probabilidade de eventos baseado no round atual

---

## 🟢 Phase 3: Sistema de Upgrades

### Loja
- [ ] Criar cena da loja entre rounds (shop_scene.tscn)
- [ ] Interface de preview dos upgrades com custo e efeito
- [ ] Criar formula de escalonamento de custos (exponencial ou linear?)

### Upgrades Disponiveis
- [ ] Upgrade de velocidade da broca (DRILL_SPEED)
- [ ] Upgrade de capacidade de armazenamento (STORAGE_CAPACITY)
- [ ] Upgrade de raio do scanner (SCAN_RADIUS)
- [ ] Upgrade de duracao do tempo de mineracao (ROUND_TIME_LIMIT)
- [ ] Upgrade de alcance da broca (DRILL_REACH)
- [ ] Upgrade de cooldown do scanner (SCAN_COOLDOWN)

### Persistencia
- [ ] Salvar upgrades comprados entre sessoes (save/load)
- [ ] Mostrar upgrades ativos no HUD durante mineracao

---

## 🔵 Phase 4: Polish e Refinamento

### Visual
- [ ] Shader de escavacao suave (ja existe em `shaders/terrain_dig.gdshader`)
- [ ] Assets artisticos pintados a mao (substituir placeholders)
- [ ] Animacoes de transicao entre telas (fade, slide)
- [ ] Indicador visual de progresso de drill (barra de progresso no tile)
- [ ] Efeito de particulas ao cavar bedrock (faiscas de impacto)
- [ ] Parallax background na cena de mineracao (ceu, nuvens)
- [ ] Melhorar sprite do Gold Nugget (atual e um circulo com glow)

### Audio
- [ ] Sons de escavacao (dirt vs stone, variacoes)
- [ ] Som de coleta de ouro (coin pickup satisfatorio)
- [ ] Som do scanner (ping/sonar)
- [ ] Musica de fundo (menu) - loop ambiente
- [ ] Musica de fundo (leilao) - tensao crescente
- [ ] Musica de fundo (mineracao) - ritmo exploratorio
- [ ] Sons de interface (cliques, transicoes, hover)
- [ ] Som de "storage full" warning

### UX
- [ ] Tutorial interativo no primeiro round (highlight areas, setas guia)
- [ ] Tooltips explicativos em todos os botoes
- [x] ~~Feedback visual quando drill esta fora de alcance~~ (Circulo branco = alcance, circulo vermelho + texto quando fora)
- [ ] Indicador de direcao para ouro detectado (seta na borda da tela)

---

## 🟣 Phase 5: Expansao de Conteudo

### Eventos Especiais
- [ ] Gold Rush (ouro temporariamente mais valioso)
- [ ] Desmoronamento (area do mapa fica inacessivel)
- [ ] Descoberta arqueologica (bonus de valor)
- [ ] Tempestade (dificulta movimento)
- [ ] Veio de Ouro (deposito gigante raro com 200+ ouro)

### NPCs e Competicao
- [ ] NPCs mineradores rivais no mapa (disputam ouro em tempo real)
- [ ] Sistema de sabotagem/interacao com rivais
- [ ] Perfis de personalidade dos NPCs (agressivo, conservador, esperto)
- [ ] NPCs com estrategias de leilao visiveis (tells/bluffs)

### Modos de Jogo
- [ ] Modo historia com narrativa (cutscenes simples entre rounds)
- [ ] Modo endless (sem limite de rounds, dificuldade crescente)
- [ ] Modo desafio (objetivos especificos: "colete 300 ouro em 60s")
- [ ] Multiplayer local no leilao (2-4 jogadores)

---

## 💡 Nice to Have (Baixa Prioridade)

- [ ] Sistema de conquistas/achievements
- [ ] Placar global (leaderboard)
- [ ] Estatisticas detalhadas (graficos de performance por round)
- [ ] Steam Workshop integration
- [ ] Localizacao (PT-BR, EN, ES)
- [ ] Controller support (gamepad mapping)
- [ ] Mobile port (touch controls)
- [ ] Sistema de save/load completo (continuar de onde parou)
- [ ] Settings persistentes (volume, resolucao, fullscreen)

---

## 🐛 Bugs Conhecidos

- [x] ~~A lateral do slot do leilao nao renderizava~~ (Adicionado LeftDepthPolygon + DepthBorderLine)
- [ ] Scanner cooldown visual no HUD depende de encontrar node "scanner" por grupo (fragil)
- [ ] `_on_area_input_event` em plot_tile.gd pode conflitar com `_input` (duplo click handling)

## 📝 Ideias Nao Priorizadas

- Sistema de contratos (objetivos opcionais com recompensas: "ache 5 depositos em 30s")
- Sistema de reputacao com os compradores (vender mais para um = melhores precos)
- Minigames durante o leilao (queda de braco, dado, etc)
- Customizacao visual do personagem (chapeus, picaretas, roupas)
- Ferramentas especiais (dinamite abre 3x3, aspirador de ouro coleta a distancia)
- Sistema de mapa mundial (diferentes regioes com biomas e recursos unicos)
- Clima dinamico que afeta mineracao (chuva = lama escorregadia, sol = sede)
- Sistema de fadiga do player (precisa descansar apos X minutos)
- Mercado negro com itens raros e ilegais (risco/recompensa)
- Jornal local com noticias que dao dicas de onde minerar
