extends Area2D

## Auto-collecting gold nugget that moves toward player

# ============================================================================
# PROPERTIES
# ============================================================================

var gold_value: int = 10
var collection_speed: float = 65.0
var player: Node2D = null
var is_collected: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

## Target display size in pixels for the Gold.png sprite
const DISPLAY_PX: float = 12.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Auto-scale Gold.png sprite to DISPLAY_PX regardless of source resolution
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite and sprite.texture:
		var tex_size: Vector2 = sprite.texture.get_size()
		sprite.scale = Vector2(DISPLAY_PX / tex_size.x, DISPLAY_PX / tex_size.y)

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
