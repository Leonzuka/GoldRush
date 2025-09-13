extends CharacterBody2D

# Movimento
const SPEED = 200.0
const JUMP_VELOCITY = -300.0

# Escavação
var is_digging = false
var dig_target_pos: Vector2i
var dig_progress: float = 0.0

# Referências
@onready var dig_timer = $DigTimer
@onready var dig_indicator = $DigIndicator
@onready var game_manager = get_node("../../GameManager")
@onready var terrain_manager = get_node("../TerrainManager")

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	# Configurar para funcionar sempre (necessário para movimento e escavação)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Debug: imprimir informações iniciais
	print("Player iniciado na posição: ", global_position)
	print("Gravity: ", gravity)

func _physics_process(delta):
	handle_gravity(delta)
	handle_movement()
	handle_digging()
	move_and_slide()

func handle_gravity(delta):
	# Aplicar gravidade se não estiver no chão
	if not is_on_floor():
		velocity.y += gravity * delta
		# Debug reduzido: só mostrar quando cai muito
		if velocity.y > 200:  # Apenas quando cai muito rápido
			var player_tile_pos = terrain_manager.world_to_tile_pos(global_position)
			print("Player caindo rápido em tile: ", player_tile_pos, " | Vel Y: ", velocity.y)
	else:
		# Zerar velocidade vertical quando no chão
		if velocity.y > 0:  # Só zerar se estava caindo
			velocity.y = 0

func handle_movement():
	# Pular
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Movimento horizontal
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func handle_digging():
	# Verificar se está tentando cavar
	if Input.is_action_pressed("dig"):
		try_dig()
	elif Input.is_action_just_released("dig"):
		stop_digging()

func try_dig():
	# Determinar posição de escavação baseada na posição do mouse
	var mouse_pos = get_global_mouse_position()
	var target_tile_pos = terrain_manager.world_to_tile_pos(mouse_pos)
	var player_tile_pos = terrain_manager.world_to_tile_pos(global_position)
	
	# Verificar se o tile alvo está próximo do player (distância máxima de 2 tiles)
	var distance = player_tile_pos.distance_to(Vector2(target_tile_pos))
	if distance > 2.0:  # Distância máxima de 2 tiles
		stop_digging()
		return
	
	# Verificar se há um bloco para cavar
	if not terrain_manager.has_block_at(target_tile_pos):
		stop_digging()
		return
	
	# Verificar se o bloco pode ser escavado (não grama)
	if not terrain_manager.can_dig_at(target_tile_pos):
		stop_digging()
		return
	
	# Se já está cavando este bloco, continuar
	if is_digging and dig_target_pos == target_tile_pos:
		return
	
	# Começar a cavar novo bloco
	start_digging(target_tile_pos)

func start_digging(target_pos: Vector2i):
	# Debug reduzido
	is_digging = true
	dig_target_pos = target_pos
	dig_progress = 0.0
	
	# Configurar timer baseado na dificuldade e upgrades
	var base_dig_time = terrain_manager.get_dig_difficulty(target_pos)
	var dig_speed_multiplier = game_manager.get_dig_speed()
	var actual_dig_time = base_dig_time / dig_speed_multiplier
	
	# Garantir que o tempo seja sempre válido
	if actual_dig_time <= 0:
		actual_dig_time = 0.1  # Mínimo de 0.1 segundos
	
	dig_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	dig_timer.wait_time = actual_dig_time
	dig_timer.start()
	print("Timer iniciado com tempo: ", actual_dig_time)
	
	# Mostrar indicador visual
	dig_indicator.visible = true
	update_dig_indicator()

func stop_digging():
	is_digging = false
	dig_timer.stop()
	dig_indicator.visible = false
	dig_progress = 0.0

func update_dig_indicator():
	if not is_digging:
		return
	
	# Atualizar posição do indicador para o tile alvo
	var target_world_pos = terrain_manager.map_to_local(dig_target_pos)
	dig_indicator.global_position = target_world_pos

func _on_dig_timer_timeout():
	if is_digging:
		complete_dig()

func complete_dig():
	# Realizar a escavação
	var dig_result = terrain_manager.dig_block(dig_target_pos)
	
	if dig_result.success:
		# Se encontrou ouro, adicionar ao inventário
		if dig_result.has_gold:
			var gold_collected = game_manager.add_gold(1)
			if gold_collected:
				print("💰 Ouro coletado!")
		
		# Forçar atualização da física após escavar
		await get_tree().process_frame
		
		# Debug: verificar se player deveria cair
		if not is_on_floor():
			print("Player deveria cair após escavação")
		
		# Verificar se está na superfície para venda automática
		check_surface_sale()
	
	stop_digging()

func check_surface_sale():
	var player_tile_pos = terrain_manager.world_to_tile_pos(global_position)
	
	# Se está na superfície (y = 0 ou 1) e tem ouro, mostrar opção de venda
	if player_tile_pos.y <= 1 and game_manager.player_gold > 0:
		# Aqui você pode adicionar lógica para mostrar botão de venda ou vender automaticamente
		if Input.is_action_just_pressed("sell"):  # Botão separado para vender
			game_manager.sell_all_gold()

func _input(event):
	# Debug: mostrar posição atual quando pressionar D
	if event.is_action_pressed("ui_right"):
		var player_tile_pos = terrain_manager.world_to_tile_pos(global_position)
		var tile_below = Vector2i(player_tile_pos.x, player_tile_pos.y + 1)
		var has_ground = terrain_manager.has_block_at(tile_below)
		print("Player em tile: ", player_tile_pos, " | Tile abaixo: ", tile_below, " | Tem chão: ", has_ground, " | is_on_floor(): ", is_on_floor())
	
	# Abrir/fechar loja quando na superfície
	if event.is_action_pressed("open_shop"):
		var player_tile_pos = terrain_manager.world_to_tile_pos(global_position)
		if player_tile_pos.y <= 1:  # Na superfície
			game_manager.toggle_shop()
