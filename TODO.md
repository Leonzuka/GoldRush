# GoldRush - TODO List
- OBS: Save automatico ao entrar no leilão
- Sistema de contratos (objetivos opcionais com recompensas: "ache 5 depositos em 30s" recompensa: maior acesso a crédito ou +Extra na conta ou +10% por ouro encontrado)

## 🔵 Polish e Refinamento

### Audio
- [ ] Add som ao escolher um terreno.
- [ ] Sons de escavacao (dirt vs stone vs bedrock, variacoes)
- [ ] Musica de fundo (menu) - loop ambiente
- [ ] Musica de fundo (leilao) - tensao crescente
- [ ] Musica de fundo (mineracao) - ritmo exploratorio
- [ ] Sons de interface (cliques, transicoes, hover)
- [ ] Som de "bag full" warning

### UX
- [ ] Tutorial interativo no primeiro round (highlight areas, setas guia)

## 🟣 Expansao de Conteudo

### Eventos Especiais
- [ ] Gold Rush (ouro temporariamente mais valioso)
- [ ] Desmoronamento (area do mapa fica inacessivel)?
- [ ] Descoberta arqueologica (bonus de valor)
- [ ] Ouro dos tolos?




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

## 📝 Ideias Secundárias/FUTURO
- Melhorar o texto dentro no jogo
- Deixar o Menu Inicial mais estilizado com Ouro e Engrenagens??
- Ferramentas especiais (dinamite abre 3x3, aspirador de ouro coleta a distancia)

## 🟡 Sistema de Mercado igual Turmoil??
### Precificacao Dinamica
- [ ] Criar classe `MarketSystem` (autoload) com preco base do ouro
- Add dois compradores de oures em cada borda do mapa?
- [ ] Implementar algoritmo para variacao de precos entre rounds
- [ ] Criar grafico de flutuacao de precos (historico dos ultimos N rounds)
### Compradores
- [ ] Adicionar multiplos compradores (Banco, Joalheiro, Mercado Negro)
- [ ] Cada comprador com multiplicador de preco diferente e preferencias
### Eventos de Mercado
- [ ] Criar eventos que afetam o mercado (descobertas, escassez, inflacao)
- [ ] Notificacao visual quando os preços mudam?
