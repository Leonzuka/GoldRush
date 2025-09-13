extends CanvasLayer

# Referências aos elementos da UI
@onready var hud = $HUD
@onready var gold_label = $HUD/GoldLabel
@onready var money_label = $HUD/MoneyLabel
@onready var shop_panel = $Shop
@onready var close_button = $Shop/CloseButton

# Referência ao GameManager
@onready var game_manager = get_node("../GameManager")

func _ready():
	# Configurar para funcionar quando o jogo está pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Conectar sinais do GameManager
	game_manager.gold_changed.connect(_on_gold_changed)
	game_manager.money_changed.connect(_on_money_changed)
	
	# Conectar botão de fechar loja
	close_button.pressed.connect(_on_close_shop_pressed)
	
	# Criar botões de upgrade na loja
	create_shop_buttons()
	
	# Inicializar UI
	update_display()

func create_shop_buttons():
	# Container para os botões
	var button_container = VBoxContainer.new()
	button_container.name = "UpgradeButtons"
	shop_panel.add_child(button_container)
	button_container.position = Vector2(20, 60)
	button_container.size = Vector2(360, 200)
	
	# Botão de upgrade da picareta
	var pickaxe_button = Button.new()
	pickaxe_button.text = "Upgrade Picareta - $%d" % game_manager.pickaxe_cost
	pickaxe_button.name = "PickaxeButton"
	pickaxe_button.pressed.connect(_on_pickaxe_upgrade_pressed)
	button_container.add_child(pickaxe_button)
	
	# Botão de upgrade do saco
	var bag_button = Button.new()
	bag_button.text = "Upgrade Saco - $%d" % game_manager.bag_cost
	bag_button.name = "BagButton" 
	bag_button.pressed.connect(_on_bag_upgrade_pressed)
	button_container.add_child(bag_button)
	
	# Botão de upgrade da lanterna
	var lantern_button = Button.new()
	lantern_button.text = "Upgrade Lanterna - $%d" % game_manager.lantern_cost
	lantern_button.name = "LanternButton"
	lantern_button.pressed.connect(_on_lantern_upgrade_pressed)
	button_container.add_child(lantern_button)
	
	# Botão de venda de ouro
	var sell_button = Button.new()
	sell_button.text = "Vender Todo Ouro"
	sell_button.name = "SellButton"
	sell_button.pressed.connect(_on_sell_gold_pressed)
	button_container.add_child(sell_button)

func update_display():
	# Atualizar textos da HUD
	gold_label.text = "Ouro: %d/%d" % [game_manager.player_gold, game_manager.gold_capacity]
	money_label.text = "Dinheiro: $%d" % game_manager.player_money
	
	# Atualizar botões da loja se existirem
	update_shop_buttons()

func update_shop_buttons():
	var button_container = shop_panel.get_node("UpgradeButtons")
	if not button_container:
		return
	
	# Atualizar textos e estados dos botões
	var pickaxe_button = button_container.get_node("PickaxeButton")
	var bag_button = button_container.get_node("BagButton")
	var lantern_button = button_container.get_node("LanternButton")
	var sell_button = button_container.get_node("SellButton")
	
	if pickaxe_button:
		pickaxe_button.text = "Upgrade Picareta (Nível %d) - $%d" % [game_manager.pickaxe_level, game_manager.pickaxe_cost]
		pickaxe_button.disabled = game_manager.player_money < game_manager.pickaxe_cost
	
	if bag_button:
		bag_button.text = "Upgrade Saco (Nível %d) - $%d" % [game_manager.bag_level, game_manager.bag_cost]
		bag_button.disabled = game_manager.player_money < game_manager.bag_cost
	
	if lantern_button:
		lantern_button.text = "Upgrade Lanterna (Nível %d) - $%d" % [game_manager.lantern_level, game_manager.lantern_cost]
		lantern_button.disabled = game_manager.player_money < game_manager.lantern_cost
	
	if sell_button:
		sell_button.text = "Vender Todo Ouro (%d pepitas)" % game_manager.player_gold
		sell_button.disabled = game_manager.player_gold == 0

func _on_gold_changed(amount: int, capacity: int):
	update_display()

func _on_money_changed(amount: int):
	update_display()

func _on_close_shop_pressed():
	print("Botão X da loja pressionado")
	game_manager.toggle_shop()

func _on_pickaxe_upgrade_pressed():
	if game_manager.buy_upgrade("pickaxe"):
		update_display()
		print("Picareta melhorada! Velocidade de escavação aumentada.")

func _on_bag_upgrade_pressed():
	if game_manager.buy_upgrade("bag"):
		update_display()
		print("Saco melhorado! Capacidade aumentada.")

func _on_lantern_upgrade_pressed():
	if game_manager.buy_upgrade("lantern"):
		update_display()
		print("Lanterna melhorada! Visão aumentada.")

func _on_sell_gold_pressed():
	if game_manager.player_gold > 0:
		var gold_amount = game_manager.player_gold
		var gold_value = gold_amount * 10
		game_manager.sell_all_gold()
		print("Vendeu %d pepitas de ouro por $%d!" % [gold_amount, gold_value])

func show_notification(message: String):
	# Criar label temporário para notificação
	var notification = Label.new()
	notification.text = message
	notification.position = Vector2(400, 300)
	notification.modulate = Color.YELLOW
	add_child(notification)
	
	# Criar tween para fazer a notificação desaparecer
	var tween = create_tween()
	tween.tween_property(notification, "modulate:a", 0.0, 2.0)
	tween.tween_callback(notification.queue_free)
