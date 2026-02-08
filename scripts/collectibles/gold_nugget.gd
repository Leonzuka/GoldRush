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

	# Pulsating scale animation for golden shine effect
	var tween := create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.4).set_trans(Tween.TRANS_SINE)

# ============================================================================
# MOVEMENT
# ============================================================================

func _process(delta: float) -> void:
	if is_collected or not player:
		return

	# Move toward player
	var direction: Vector2 = (player.global_position - global_position).normalized()
	global_position += direction * collection_speed * delta

	# Redraw glow each frame (position changes)
	queue_redraw()

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

	# Quick shrink animation before freeing
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func _draw() -> void:
	# Soft golden glow behind the nugget
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.85, 0.2, 0.3))
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.9, 0.4, 0.4))
