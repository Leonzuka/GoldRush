extends Node

signal gold_changed(amount: int, capacity: int)
signal money_changed(amount: int)

var player_gold: int = 0
var player_money: int = 0
var gold_capacity: int = 10

# Upgrades
var pickaxe_level: int = 1
var bag_level: int = 1  
var lantern_level: int = 1

# Upgrade costs
var pickaxe_cost: int = 50
var bag_cost: int = 75
var lantern_cost: int = 100

# Upgrade effects
var dig_speed_multiplier: float = 1.0
var vision_radius: float = 100.0

@onready var hud_gold_label = $"../UI/HUD/GoldLabel"
@onready var hud_money_label = $"../UI/HUD/MoneyLabel"
@onready var shop_panel = $"../UI/Shop"

func _ready():
	update_hud()
	calculate_upgrade_effects()

func add_gold(amount: int) -> bool:
	if player_gold < gold_capacity:
		var space_available = gold_capacity - player_gold
		var gold_to_add = min(amount, space_available)
		player_gold += gold_to_add
		gold_changed.emit(player_gold, gold_capacity)
		update_hud()
		return true
	return false

func sell_all_gold():
	var gold_value = player_gold * 10  # $10 por pepita
	player_money += gold_value
	player_gold = 0
	money_changed.emit(player_money)
	gold_changed.emit(player_gold, gold_capacity)
	update_hud()

func buy_upgrade(upgrade_type: String) -> bool:
	var cost = 0
	
	match upgrade_type:
		"pickaxe":
			cost = pickaxe_cost
			if player_money >= cost:
				player_money -= cost
				pickaxe_level += 1
				pickaxe_cost = int(pickaxe_cost * 1.5)
				calculate_upgrade_effects()
				update_hud()
				return true
		"bag":
			cost = bag_cost
			if player_money >= cost:
				player_money -= cost
				bag_level += 1
				bag_cost = int(bag_cost * 1.5)
				gold_capacity += 5
				calculate_upgrade_effects()
				update_hud()
				return true
		"lantern":
			cost = lantern_cost
			if player_money >= cost:
				player_money -= cost
				lantern_level += 1
				lantern_cost = int(lantern_cost * 1.5)
				calculate_upgrade_effects()
				update_hud()
				return true
	
	return false

func calculate_upgrade_effects():
	dig_speed_multiplier = 1.0 + (pickaxe_level - 1) * 0.3
	vision_radius = 100.0 + (lantern_level - 1) * 50.0

func update_hud():
	if hud_gold_label:
		hud_gold_label.text = "Ouro: %d/%d" % [player_gold, gold_capacity]
	if hud_money_label:
		hud_money_label.text = "Dinheiro: $%d" % player_money

func toggle_shop():
	shop_panel.visible = !shop_panel.visible
	print("Loja toggled. Visível: ", shop_panel.visible)
	
	# Pausar o jogo quando a loja estiver aberta
	if shop_panel.visible:
		get_tree().paused = true
	else:
		get_tree().paused = false

func get_dig_speed() -> float:
	return dig_speed_multiplier

func get_vision_radius() -> float:
	return vision_radius
