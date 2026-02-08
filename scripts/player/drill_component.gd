extends Node
class_name DrillComponent

## Handles tile drilling mechanics and gold nugget spawning

# ============================================================================
# EXPORTS
# ============================================================================

@export var drill_speed: float = Config.DRILL_SPEED
@export var drill_reach: float = Config.DRILL_REACH
@export var gold_nugget_scene: PackedScene

# ============================================================================
# REFERENCES
# ============================================================================

var terrain_manager: TerrainManager
var player: CharacterBody2D

# ============================================================================
# STATE
# ============================================================================

var is_drilling: bool = false
var current_target_tile: Vector2i
var drill_progress: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	player = get_parent() as CharacterBody2D

	# Find TerrainManager in scene
	await get_tree().process_frame
	terrain_manager = get_tree().get_first_node_in_group("terrain")

	if not gold_nugget_scene:
		gold_nugget_scene = load("res://scenes/mining/gold_nugget.tscn")

# ============================================================================
# DRILLING
# ============================================================================

func _process(delta: float) -> void:
	if not terrain_manager or not player:
		return

	# Check for drill input (left mouse button)
	if Input.is_action_pressed("drill"):
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var camera: Camera2D = get_viewport().get_camera_2d()
		if camera:
			mouse_pos = camera.get_screen_center_position() + (mouse_pos - get_viewport().get_visible_rect().size / 2) / camera.zoom

		var player_pos: Vector2 = player.global_position

		# Check reach distance
		if player_pos.distance_to(mouse_pos) <= drill_reach:
			var target_tile: Vector2i = terrain_manager.world_to_tile(mouse_pos)
			attempt_drill(target_tile, delta)
		else:
			reset_drill()
	else:
		reset_drill()

func attempt_drill(tile_pos: Vector2i, delta: float) -> void:
	# Reset progress if targeting new tile
	if current_target_tile != tile_pos:
		current_target_tile = tile_pos
		drill_progress = 0.0

	# Increment drill progress
	drill_progress += drill_speed * delta

	# Complete drilling when progress >= 1.0
	if drill_progress >= 1.0:
		var result: Dictionary = terrain_manager.dig_tile(tile_pos)
		if result.success:
			_spawn_dig_dust(tile_pos)
			if result.has_gold:
				spawn_gold_nugget(tile_pos, result.gold_amount)

		drill_progress = 0.0

func reset_drill() -> void:
	drill_progress = 0.0
	is_drilling = false

# ============================================================================
# GOLD NUGGET SPAWNING
# ============================================================================

func spawn_gold_nugget(tile_pos: Vector2i, amount: int) -> void:
	if not gold_nugget_scene:
		return

	var nugget: Node = gold_nugget_scene.instantiate()
	nugget.gold_value = amount
	nugget.global_position = terrain_manager.tile_to_world(tile_pos)

	# Add to scene (find GoldNuggetContainer or root)
	var container: Node = get_tree().get_first_node_in_group("nugget_container")
	if container:
		container.add_child(nugget)
	else:
		get_tree().root.add_child(nugget)

# ============================================================================
# EFFECTS
# ============================================================================

## Spawn dust particles at the dug tile position
func _spawn_dig_dust(tile_pos: Vector2i) -> void:
	var dust := CPUParticles2D.new()
	dust.emitting = true
	dust.amount = 12
	dust.lifetime = 0.6
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.direction = Vector2(0, -1)
	dust.spread = 60.0
	dust.initial_velocity_min = 20.0
	dust.initial_velocity_max = 50.0
	dust.gravity = Vector2(0, 40)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.0
	dust.color = Color(0.65, 0.5, 0.3, 0.8)
	dust.global_position = terrain_manager.tile_to_world(tile_pos)
	dust.finished.connect(dust.queue_free)
	get_tree().root.add_child(dust)
