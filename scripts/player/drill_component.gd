extends Node
class_name DrillComponent

## Handles tile drilling mechanics and gold nugget spawning

# ============================================================================
# EXPORTS
# ============================================================================

@export var drill_speed: float = Config.DRILL_SPEED
@export var drill_reach: float = Config.DRILL_REACH
@export var gold_nugget_scene: PackedScene
@export var rare_collectible_scene: PackedScene

# ============================================================================
# REFERENCES
# ============================================================================

var terrain_manager: TerrainManager
var player: CharacterBody2D

# ============================================================================
# STATE
# ============================================================================

var is_drilling: bool = false
var is_out_of_range: bool = false
var current_target_tile: Vector2i
var drill_progress: float = 0.0

var _bedrock_spark_timer: float = 0.0
const _BEDROCK_SPARK_INTERVAL: float = 0.12

var _drill_overlay: DrillOverlay

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

	if not rare_collectible_scene:
		rare_collectible_scene = load("res://scenes/mining/rare_collectible.tscn")

	# Create crack overlay (lives in scene root so z_index works globally)
	_drill_overlay = DrillOverlay.new()
	_drill_overlay.z_index = 5
	get_tree().root.add_child(_drill_overlay)

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
			is_out_of_range = false
			var target_tile: Vector2i = terrain_manager.world_to_tile(mouse_pos)
			attempt_drill(target_tile, delta)
		else:
			is_out_of_range = true
			reset_drill()
	else:
		is_out_of_range = false
		reset_drill()

## Returns true if there is no solid tile blocking the path to target_tile
func _has_line_of_sight(target_tile: Vector2i) -> bool:
	var to_pos: Vector2 = terrain_manager.tile_to_world(target_tile)
	var space_state = player.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		player.global_position,
		to_pos,
		0xFFFFFFFF,
		[player.get_rid()]
	)
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return true
	# Move slightly past the hit surface to identify which tile was hit
	var direction: Vector2 = (to_pos - player.global_position).normalized()
	var hit_tile: Vector2i = terrain_manager.world_to_tile(result.position + direction * 2.0)
	return hit_tile == target_tile

func attempt_drill(tile_pos: Vector2i, delta: float) -> void:
	# Block drilling through other tiles
	if not _has_line_of_sight(tile_pos):
		reset_drill()
		return

	# Bedrock: spawn impact sparks periodically, don't progress
	if terrain_manager.is_bedrock_tile(tile_pos):
		_bedrock_spark_timer -= delta
		if _bedrock_spark_timer <= 0.0:
			_spawn_bedrock_sparks(tile_pos)
			_bedrock_spark_timer = _BEDROCK_SPARK_INTERVAL
		_drill_overlay.refresh(0.0, Vector2.ZERO, false)
		return

	# Don't show overlay on empty tiles (air / already dug)
	if not terrain_manager.has_solid_tile(tile_pos):
		_drill_overlay.refresh(0.0, Vector2.ZERO, false)
		return

	# Reset progress if targeting new tile
	if current_target_tile != tile_pos:
		current_target_tile = tile_pos
		drill_progress = 0.0

	# Increment drill progress
	drill_progress += drill_speed * delta

	# Update crack overlay
	var tile_world_pos: Vector2 = terrain_manager.tile_to_world(tile_pos)
	_drill_overlay.refresh(minf(drill_progress, 1.0), tile_world_pos, true)

	# Complete drilling when progress >= 1.0
	if drill_progress >= 1.0:
		var result: Dictionary = terrain_manager.dig_tile(tile_pos)
		if result.success:
			_spawn_dig_dust(tile_pos)
			if result.has_gold:
				_spawn_gold_sparks(tile_pos)
				spawn_gold_nugget(tile_pos, result.gold_amount)
			elif result.has_rare:
				_spawn_rare_sparks(tile_pos, result.rare_type)
				spawn_rare_collectible(tile_pos, result.rare_type, result.rare_amount)

		drill_progress = 0.0

func reset_drill() -> void:
	drill_progress = 0.0
	is_drilling = false
	_bedrock_spark_timer = 0.0
	if _drill_overlay:
		_drill_overlay.refresh(0.0, Vector2.ZERO, false)

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

func spawn_rare_collectible(tile_pos: Vector2i, type: String, amount: int) -> void:
	if not rare_collectible_scene:
		return

	var collectible: Node = rare_collectible_scene.instantiate()
	collectible.collectible_type = type
	collectible.collectible_value = amount
	collectible.global_position = terrain_manager.tile_to_world(tile_pos)

	var container: Node = get_tree().get_first_node_in_group("nugget_container")
	if container:
		container.add_child(collectible)
	else:
		get_tree().root.add_child(collectible)

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

## Spawn golden spark particles when gold is found
func _spawn_gold_sparks(tile_pos: Vector2i) -> void:
	var sparks := CPUParticles2D.new()
	sparks.emitting = true
	sparks.amount = 16
	sparks.lifetime = 0.8
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.direction = Vector2(0, -1)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 40.0
	sparks.initial_velocity_max = 90.0
	sparks.gravity = Vector2(0, 60)
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.5
	sparks.color_ramp = _create_gold_gradient()
	sparks.global_position = terrain_manager.tile_to_world(tile_pos)
	sparks.finished.connect(sparks.queue_free)
	get_tree().root.add_child(sparks)

## Spawn bright impact sparks when trying to drill bedrock
func _spawn_bedrock_sparks(tile_pos: Vector2i) -> void:
	var sparks := CPUParticles2D.new()
	sparks.emitting = true
	sparks.amount = 8
	sparks.lifetime = 0.35
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = Vector2(0, -1)
	sparks.spread = 65.0
	sparks.initial_velocity_min = 50.0
	sparks.initial_velocity_max = 110.0
	sparks.gravity = Vector2(0, 90)
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	sparks.color_ramp = _create_bedrock_spark_gradient()
	sparks.global_position = terrain_manager.tile_to_world(tile_pos)
	sparks.finished.connect(sparks.queue_free)
	get_tree().root.add_child(sparks)

## Spawn colored sparks when a rare item is found
func _spawn_rare_sparks(tile_pos: Vector2i, type: String) -> void:
	var sparks := CPUParticles2D.new()
	sparks.emitting = true
	sparks.amount = 24
	sparks.lifetime = 1.0
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.direction = Vector2(0, -1)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 50.0
	sparks.initial_velocity_max = 110.0
	sparks.gravity = Vector2(0, 60)
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.color_ramp = _create_rare_gradient(type)
	sparks.global_position = terrain_manager.tile_to_world(tile_pos)
	sparks.finished.connect(sparks.queue_free)
	get_tree().root.add_child(sparks)

## Create a type-specific gradient for rare item spark particles
func _create_rare_gradient(type: String) -> Gradient:
	var gradient := Gradient.new()
	match type:
		"diamond":
			gradient.set_offset(0, 0.0)
			gradient.set_color(0, Color(0.6, 0.95, 1.0, 1.0))    # Icy cyan
			gradient.add_point(0.4, Color(0.3, 0.75, 1.0, 0.9))  # Blue
			gradient.set_offset(2, 1.0)
			gradient.set_color(2, Color(0.1, 0.3, 0.8, 0.0))     # Fade deep blue
		"relic":
			gradient.set_offset(0, 0.0)
			gradient.set_color(0, Color(1.0, 0.8, 1.0, 1.0))     # Pale magenta
			gradient.add_point(0.4, Color(0.85, 0.2, 1.0, 0.9))  # Purple
			gradient.set_offset(2, 1.0)
			gradient.set_color(2, Color(0.5, 0.0, 0.6, 0.0))     # Fade dark purple
		_:
			gradient.set_offset(0, 0.0)
			gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
			gradient.set_offset(1, 1.0)
			gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	return gradient

## Create a gold-colored gradient for spark particles
func _create_gold_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 0.95, 0.4, 1.0))  # Bright gold
	gradient.add_point(0.4, Color(1.0, 0.75, 0.1, 0.9))  # Rich gold
	gradient.set_offset(2, 1.0)
	gradient.set_color(2, Color(0.9, 0.5, 0.0, 0.0))  # Fade to transparent orange
	return gradient

## Create a white-orange gradient for bedrock impact sparks
func _create_bedrock_spark_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 1.0, 0.95, 1.0))  # Near-white hot
	gradient.add_point(0.35, Color(1.0, 0.7, 0.15, 1.0))  # Orange
	gradient.set_offset(2, 1.0)
	gradient.set_color(2, Color(0.6, 0.2, 0.0, 0.0))  # Fade out
	return gradient
