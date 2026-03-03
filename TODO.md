# GoldRush - TODO List

## 🔴 Tarefas Imediatas (Sprint Atual)
- Terras indisponíveis quando um NPC escolhe - add um minigame
- Melhorar a lógica dos NPCs (com personalidade nas escolhas,etc)
- Acelera um pouco a escolhas dos NPC no Leilão após o 1 leilão (deixar normal)

### Gameplay Core & Balanceamento
- [ ] Validar balanceamento de dificuldade dos plots
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
- [ ] Salvar upgrades comprados entre sessoes (save/load)?
- [ ] Mostrar upgrades ativos no HUD durante mineracao

---

## 🔵 Phase 4: Polish e Refinamento

### Visual
- [ ] Assets artisticos (substituir placeholders)
- [ ] Parallax background na cena de mineracao (ceu, nuvens)
- [ ] Melhorar sprite do Gold Nugget

### Audio
- [ ] Sons de escavacao (dirt vs stone vs bedrock, variacoes)
- [ ] Som de coleta de ouro (coin pickup satisfatorio)
- [ ] Musica de fundo (menu) - loop ambiente
- [ ] Musica de fundo (leilao) - tensao crescente
- [ ] Musica de fundo (mineracao) - ritmo exploratorio
- [ ] Sons de interface (cliques, transicoes, hover)
- [ ] Som de "storage full" warning

### UX
- [ ] Tutorial interativo no primeiro round (highlight areas, setas guia)
- [ ] Tooltips explicativos em todos os botoes

## 🟣 Phase 5: Expansao de Conteudo

### Eventos Especiais
- [ ] Gold Rush (ouro temporariamente mais valioso)
- [ ] Desmoronamento (area do mapa fica inacessivel)?
- [ ] Descoberta arqueologica (bonus de valor)
- [ ] Ouro dos tolos?

### NPCs e Competicao
- [ ] Sistema de sabotagem/interacao com rivais
- [ ] Perfis de personalidade dos NPCs (agressivo, conservador, esperto)

### Modos de Jogo
- [ ] Modo historia com narrativa (cutscenes simples entre rounds)
- [ ] Modo desafio (objetivos especificos: "colete 300 ouro em 60s")

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

## 📝 Ideias Nao Priorizadas

- Sistema de contratos (objetivos opcionais com recompensas: "ache 5 depositos em 30s")
- Sistema de reputacao com os compradores (vender mais para um = melhores precos)
- Minigames durante o leilao (queda de braco, dado, etc)
- Customizacao visual do personagem (chapeus, picaretas, roupas)
- Ferramentas especiais (dinamite abre 3x3, aspirador de ouro coleta a distancia)
- Sistema de fadiga do player (precisa descansar apos X segundos)
- Mercado negro com itens raros e ilegais (risco/recompensa)
