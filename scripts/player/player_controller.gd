extends CharacterBody2D

## Player character controller with WASD movement and dynamic camera

# ============================================================================
# EXPORTS
# ============================================================================

@export var speed: float = Config.PLAYER_SPEED
@export var gravity: float = Config.PLAYER_GRAVITY
@export var jump_velocity: float = Config.PLAYER_JUMP_VELOCITY

# Camera zoom levels
@export var zoom_surface: Vector2 = Vector2(1.2, 1.2)
@export var zoom_underground: Vector2 = Vector2(2.2, 2.2)
@export var zoom_lerp_speed: float = 2.5

# How many tiles below surface to start zooming in
@export var surface_depth_threshold: int = 3

# ============================================================================
# REFERENCES
# ============================================================================

var drill_component: DrillComponent
var camera: Camera2D

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("player")
	drill_component = get_node_or_null("DrillComponent") as DrillComponent
	camera = get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.zoom = zoom_surface
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
# DYNAMIC CAMERA
# ============================================================================

func _update_camera_zoom(delta: float) -> void:
	if not camera:
		return

	# Depth in tiles below surface (surface = y <= 0)
	var depth_tiles: float = global_position.y / Config.TILE_SIZE

	# Normalized 0.0 (surface) → 1.0 (fully underground)
	var t: float = clampf(depth_tiles / float(surface_depth_threshold), 0.0, 1.0)

	var target_zoom: Vector2 = zoom_surface.lerp(zoom_underground, t)
	camera.zoom = camera.zoom.lerp(target_zoom, zoom_lerp_speed * delta)

# ============================================================================
# DRILL RANGE INDICATOR
# ============================================================================

func _process(delta: float) -> void:
	_update_camera_zoom(delta)
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
