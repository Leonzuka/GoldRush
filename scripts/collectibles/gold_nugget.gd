extends Area2D

## Auto-collecting gold nugget that moves toward player

# ============================================================================
# PROPERTIES
# ============================================================================

var gold_value: int = 10
var collection_speed: float = 200.0
var player: Node2D = null
var is_collected: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

# ============================================================================
# MOVEMENT
# ============================================================================

func _process(delta: float) -> void:
	if is_collected or not player:
		return

	# Move toward player
	var direction: Vector2 = (player.global_position - global_position).normalized()
	global_position += direction * collection_speed * delta

# ============================================================================
# COLLECTION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return

	if body.is_in_group("player"):
		collect()

func collect() -> void:
	is_collected = true
	EventBus.gold_collected.emit(gold_value)
	queue_free()
