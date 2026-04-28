# GoldRush - TODO List

## 🔴 Tarefas Imediatas
### Visual
- Deixar o Menu Inicial mais estilizado com Ouro e Engrenagens
- Aumentar o radar em +- 50% (número inteiro) 
- Emprestimo para deixar o jogo mais dinâmico
- Sistema de contratos (objetivos opcionais com recompensas: "ache 5 depositos em 30s" recompensa maior acesso a crédito ou +ouro na conta)

### Gameplay Core & Balanceamento
- [ ] Validar balanceamento de dificuldade dos plots
- [ ] Testar curva de dificuldade: rounds 1-5 devem ficar progressivamente mais dificeis
- [ ] Validar que 25-50 depositos por plot gera gameplay de ~5 minutos satisfatorio

## 🟡 Phase 2: Sistema de Mercado

### Precificacao Dinamica
- [ ] Criar classe `MarketSystem` (autoload) com preco base do ouro
- Add dois compradores de oures em cada borda do mapa eles terão
- [ ] Implementar algoritmo para variacao de precos entre rounds
- [ ] Criar grafico de flutuacao de precos (historico dos ultimos N rounds)

### Compradores
- [ ] Adicionar multiplos compradores (Banco, Joalheiro, Mercado Negro)
- [ ] Cada comprador com multiplicador de preco diferente e preferencias

### Eventos de Mercado
- [ ] Criar eventos que afetam o mercado (descobertas, escassez, inflacao)
- [ ] Notificacao visual quando os preços mudam

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

## 🔵 Phase 4: Polish e Refinamento

### Audio
- [ ] Sons de escavacao (dirt vs stone vs bedrock, variacoes)
- [ ] Musica de fundo (menu) - loop ambiente
- [ ] Musica de fundo (leilao) - tensao crescente
- [ ] Musica de fundo (mineracao) - ritmo exploratorio
- [ ] Sons de interface (cliques, transicoes, hover)
- [ ] Som de "bag full" warning

### UX
- [ ] Tutorial interativo no primeiro round (highlight areas, setas guia)

## 🟣 Phase 5: Expansao de Conteudo

### Eventos Especiais
- [ ] Gold Rush (ouro temporariamente mais valioso)
- [ ] Desmoronamento (area do mapa fica inacessivel)?
- [ ] Descoberta arqueologica (bonus de valor)
- [ ] Ouro dos tolos?

### Modos de Jogo
- [ ] Modo historia com narrativa (cutscenes simples entre rounds)

## 💡 Nice to Have (Baixa Prioridade)

- [ ] Sistema de conquistas/achievements
- [ ] Steam Workshop integration
- [ ] Controller support (gamepad mapping)
- [~] Mobile port (touch controls) — base feita; pendente:
  - [ ] Configurar export preset para Android (precisa do Android SDK localmente)
  - [ ] Testar APK em dispositivo real (orientation lock, latencia de toque)
  - [ ] Joystick virtual com multi-toque (hoje só botões esquerda/direita)
  - [ ] Pinch-to-zoom no mapa de leilão
  - [ ] Botão de drill dedicado (atualmente: tocar no terreno)

## 📝 Ideias Secundárias
- Customizacao visual do personagem (chapeus, picaretas, roupas)
- Ferramentas especiais (dinamite abre 3x3, aspirador de ouro coleta a distancia)
- Sistema de fadiga do player (precisa descansar apos X segundos)
- Texto cortando na parte de baixo no modo tela cheia.