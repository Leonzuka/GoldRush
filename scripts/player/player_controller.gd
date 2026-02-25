extends CharacterBody2D

## Player character controller with WASD movement

# ============================================================================
# EXPORTS
# ============================================================================

@export var speed: float = Config.PLAYER_SPEED
@export var gravity: float = Config.PLAYER_GRAVITY
@export var jump_velocity: float = Config.PLAYER_JUMP_VELOCITY

# ============================================================================
# REFERENCES
# ============================================================================

var drill_component: DrillComponent

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("player")
	drill_component = get_node_or_null("DrillComponent") as DrillComponent
	print("[Player] Ready at position: %s" % global_position)

# ============================================================================
# MOVEMENT
# ============================================================================

func _physics_process(delta: float) -> void:
	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y += gravity * delta

	# Jump (Space)
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = -jump_velocity

	# Horizontal movement (A/D or Arrow keys)
	var input_x: float = Input.get_axis("move_left", "move_right")
	velocity.x = input_x * speed

	move_and_slide()

# ============================================================================
# DRILL RANGE INDICATOR
# ============================================================================

func _process(_delta: float) -> void:
	if drill_component:
		queue_redraw()

func _draw() -> void:
	if not drill_component:
		return
	if not Input.is_action_pressed("drill"):
		return

	var reach: float = drill_component.drill_reach
	if drill_component.is_out_of_range:
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 36, Color(1.0, 0.2, 0.2, 0.7), 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-44, -reach - 6), "Out of range", HORIZONTAL_ALIGNMENT_CENTER, 88, 11, Color(1.0, 0.3, 0.3, 0.9))
	else:
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.25), 1.5)
