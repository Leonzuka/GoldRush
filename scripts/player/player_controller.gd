extends CharacterBody2D

## Player character controller with WASD movement, dynamic camera, and idle/run animation

# ============================================================================
# EXPORTS
# ============================================================================

@export var speed: float = Config.PLAYER_SPEED
@export var gravity: float = Config.PLAYER_GRAVITY
@export var jump_velocity: float = Config.PLAYER_JUMP_VELOCITY

# Camera zoom levels
@export var zoom_surface: Vector2 = Vector2(1.2, 1.2)
@export var zoom_underground: Vector2 = Vector2(1.8, 1.8)
@export var zoom_lerp_speed: float = 2.5

# How many tiles below surface to start zooming in
@export var surface_depth_threshold: int = 3

# Animation speed
@export var run_fps: float = 24.0
@export var idle_fps: float = 12.0

# ============================================================================
# TEXTURES
# ============================================================================

const RUN_TEXTURE: Texture2D = preload("res://assets/sprites/Prota/spritesheet-table-9x9-Running_Backgroundrecorted.png")
const IDLE_TEXTURE: Texture2D = preload("res://assets/sprites/Prota/IDLE(7x6).png")

# ============================================================================
# REFERENCES
# ============================================================================

var drill_component: DrillComponent
var camera: Camera2D
var sprite: Sprite2D

# ============================================================================
# ANIMATION STATE
# ============================================================================

const RUN_HFRAMES: int = 9
const RUN_VFRAMES: int = 9
const RUN_TOTAL_FRAMES: int = 75
const RUN_START_FRAME: int = 4

const IDLE_HFRAMES: int = 7
const IDLE_VFRAMES: int = 6
const IDLE_TOTAL_FRAMES: int = 40  # 7 * 6 = 42, minus 2 empty frames at end

var _anim_timer: float = 0.0
var _current_frame: int = 0
var _facing_right: bool = true
var _current_anim: String = ""

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	add_to_group("player")
	drill_component = get_node_or_null("DrillComponent") as DrillComponent
	camera = get_node_or_null("Camera2D") as Camera2D
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if camera:
		camera.zoom = zoom_surface
	_set_animation("idle")
	print("[Player] Ready at position: %s" % global_position)

# ============================================================================
# MOVEMENT
# ============================================================================

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = -jump_velocity

	var input_x: float = Input.get_axis("move_left", "move_right")
	velocity.x = input_x * speed

	move_and_slide()
	_update_animation(delta)

# ============================================================================
# ANIMATION
# ============================================================================

func _set_animation(anim: String) -> void:
	if _current_anim == anim or not sprite:
		return
	_current_anim = anim
	_anim_timer = 0.0
	if anim == "idle":
		sprite.texture = IDLE_TEXTURE
		sprite.hframes = IDLE_HFRAMES
		sprite.vframes = IDLE_VFRAMES
		_current_frame = 0
	else:
		sprite.texture = RUN_TEXTURE
		sprite.hframes = RUN_HFRAMES
		sprite.vframes = RUN_VFRAMES
		_current_frame = RUN_START_FRAME
	sprite.frame = _current_frame

func _update_animation(delta: float) -> void:
	if not sprite:
		return

	var moving: bool = abs(velocity.x) > 10.0

	if velocity.x > 10.0:
		_facing_right = true
	elif velocity.x < -10.0:
		_facing_right = false

	# Sprite faces right by default — flip when going left
	sprite.flip_h = not _facing_right

	if moving:
		_set_animation("run")
		_anim_timer += delta
		if _anim_timer >= 1.0 / run_fps:
			_anim_timer -= 1.0 / run_fps
			_current_frame += 1
			if _current_frame >= RUN_TOTAL_FRAMES:
				_current_frame = RUN_START_FRAME
		sprite.frame = _current_frame
	else:
		_set_animation("idle")
		_anim_timer += delta
		if _anim_timer >= 1.0 / idle_fps:
			_anim_timer -= 1.0 / idle_fps
			_current_frame += 1
			if _current_frame >= IDLE_TOTAL_FRAMES:
				_current_frame = 0
		sprite.frame = _current_frame

# ============================================================================
# DYNAMIC CAMERA
# ============================================================================

func _update_camera_zoom(delta: float) -> void:
	if not camera:
		return

	var depth_tiles: float = global_position.y / Config.TILE_SIZE
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
