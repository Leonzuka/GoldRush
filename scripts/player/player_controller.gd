extends CharacterBody2D

## Player character controller with WASD movement

# ============================================================================
# EXPORTS
# ============================================================================

@export var speed: float = Config.PLAYER_SPEED
@export var gravity: float = Config.PLAYER_GRAVITY

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("player")
	print("[Player] Ready at position: %s" % global_position)

# ============================================================================
# MOVEMENT
# ============================================================================

func _physics_process(delta: float) -> void:
	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y += gravity * delta

	# Horizontal movement (A/D or Arrow keys)
	var input_x: float = Input.get_axis("move_left", "move_right")
	velocity.x = input_x * speed

	move_and_slide()
