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

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	EventBus.gold_collected.connect(_on_gold_collected)
	EventBus.mining_started.connect(_on_mining_started)
	start_session()

# ============================================================================
# SESSION MANAGEMENT
# ============================================================================

func start_session() -> void:
	elapsed_time = 0.0
	gold_collected = 0
	is_active = true
	EventBus.resource_storage_changed.emit(0, storage_capacity)

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
	start_session()
