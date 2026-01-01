extends Node
class_name MiningSession

## Manages mining session timer, storage limits, and round end conditions

# ============================================================================
# EXPORTS
# ============================================================================

@export var time_limit: float = Config.ROUND_TIME_LIMIT
@export var storage_capacity: int = Config.STORAGE_CAPACITY

# ============================================================================
# STATE
# ============================================================================

var elapsed_time: float = 0.0
var gold_collected: int = 0
var is_active: bool = false

# Reference to terrain manager
var terrain_manager: TerrainManager = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[MiningSession] _ready() called")
	EventBus.gold_collected.connect(_on_gold_collected)
	EventBus.mining_started.connect(_on_mining_started)
	print("[MiningSession] Connected to signals, waiting for mining_started event")

# ============================================================================
# SESSION MANAGEMENT
# ============================================================================

func start_session() -> void:
	print("[MiningSession] start_session() called")
	elapsed_time = 0.0
	gold_collected = 0
	is_active = true
	EventBus.resource_storage_changed.emit(0, storage_capacity)
	print("[MiningSession] Session started - timer active")

func _process(delta: float) -> void:
	if not is_active:
		return

	elapsed_time += delta
	var time_remaining: float = time_limit - elapsed_time
	EventBus.session_time_updated.emit(time_remaining)

	# Check time limit
	if elapsed_time >= time_limit:
		end_session("Time limit reached")

func end_session(reason: String = "Unknown") -> void:
	if not is_active:
		return

	is_active = false

	var stats: Dictionary = {
		"gold_collected": gold_collected,
		"time_used": elapsed_time,
		"efficiency": gold_collected / max(elapsed_time, 0.1),
		"reason": reason
	}

	print("[Session] Ended: %s | Gold: %d | Time: %.1fs" % [reason, gold_collected, elapsed_time])
	EventBus.round_ended.emit(stats)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_gold_collected(amount: int) -> void:
	if not is_active:
		return

	# Clamp to storage capacity
	var space_available: int = storage_capacity - gold_collected
	var actual_amount: int = min(amount, space_available)

	gold_collected += actual_amount
	EventBus.resource_storage_changed.emit(gold_collected, storage_capacity)

	# Check storage full
	if gold_collected >= storage_capacity:
		end_session("Storage full")

func _on_mining_started(plot_data: Resource) -> void:
	print("[MiningSession] Mining started with plot: %s (seed=%d, richness=%.2f)" % [plot_data.plot_name, plot_data.terrain_seed, plot_data.gold_richness])

	# Find TerrainManager (it's in the same scene as us)
	if not terrain_manager:
		terrain_manager = get_tree().get_first_node_in_group("terrain")
		if terrain_manager:
			print("[MiningSession] Found TerrainManager: %s" % terrain_manager.name)
		else:
			# Try waiting a frame and search again
			await get_tree().process_frame
			terrain_manager = get_tree().get_first_node_in_group("terrain")
			if terrain_manager:
				print("[MiningSession] Found TerrainManager after delay: %s" % terrain_manager.name)

	# Generate terrain using plot data
	if terrain_manager:
		terrain_manager.generate_terrain(plot_data.terrain_seed, plot_data.gold_richness)
	else:
		push_error("[MiningSession] Cannot generate terrain - TerrainManager not found!")
		print("[MiningSession] Nodes in scene: %s" % get_tree().get_nodes_in_group("terrain"))

	# Position player at surface level
	_position_player_at_surface()

	start_session()

## Position player at the top of the terrain
func _position_player_at_surface() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Spawn player at top-center of terrain, slightly above first row
		var spawn_x = Config.TERRAIN_WIDTH * Config.TILE_SIZE / 2.0  # Center horizontally
		var spawn_y = -Config.TILE_SIZE * 2  # 2 tiles above the top
		player.global_position = Vector2(spawn_x, spawn_y)
		print("[MiningSession] Player positioned at (%d, %d)" % [spawn_x, spawn_y])
	else:
		push_warning("[MiningSession] Player not found in scene")
