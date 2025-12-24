extends Node
class_name ScannerComponent

## Detects gold deposits within scan radius

# ============================================================================
# EXPORTS
# ============================================================================

@export var scan_radius: float = Config.SCAN_RADIUS
@export var scan_cooldown: float = Config.SCAN_COOLDOWN

# ============================================================================
# REFERENCES
# ============================================================================

var terrain_manager: TerrainManager
var player: CharacterBody2D

# ============================================================================
# STATE
# ============================================================================

var is_ready_to_scan: bool = true
var cooldown_timer: Timer

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	player = get_parent() as CharacterBody2D

	# Find TerrainManager
	await get_tree().process_frame
	terrain_manager = get_tree().get_first_node_in_group("terrain")

	# Setup cooldown timer
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	add_child(cooldown_timer)

# ============================================================================
# SCANNING
# ============================================================================

func _process(_delta: float) -> void:
	# Scan input (Spacebar)
	if Input.is_action_just_pressed("scan"):
		perform_scan()

func perform_scan() -> Array:
	if not is_ready_to_scan or not terrain_manager or not player:
		return []

	# Start cooldown
	is_ready_to_scan = false
	cooldown_timer.start(scan_cooldown)

	# Get player tile position
	var player_pos: Vector2 = player.global_position
	var center_tile: Vector2i = terrain_manager.world_to_tile(player_pos)

	# Calculate radius in tiles
	var radius_tiles: int = int(scan_radius / Config.TILE_SIZE)

	# Check all tiles in radius
	var detected_deposits: Array[Vector2i] = []
	for tile_pos in terrain_manager.gold_deposits.keys():
		var distance: float = center_tile.distance_to(tile_pos)
		if distance <= radius_tiles:
			terrain_manager.gold_deposits[tile_pos].revealed = true
			detected_deposits.append(tile_pos)

	# Emit signal and apply visual feedback
	EventBus.gold_detected.emit(detected_deposits)
	terrain_manager.highlight_gold_tiles(detected_deposits)

	print("[Scanner] Detected %d deposits" % detected_deposits.size())
	return detected_deposits

func _on_cooldown_finished() -> void:
	is_ready_to_scan = true

## Get cooldown remaining (for UI)
func get_cooldown_remaining() -> float:
	return cooldown_timer.time_left if cooldown_timer else 0.0
