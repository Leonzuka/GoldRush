extends Node

## UpgradeManager — Owns upgrade levels, computed modifiers, and disk persistence.
##
## Modifiers are recomputed on every purchase / load / reset and read fresh by
## consumers (DrillComponent, ScannerComponent, MiningSession, etc.). Persistence
## is per-campaign — wiped by GameManager.start_new_game() via reset().

const SAVE_PATH: String = "user://upgrades.cfg"

# ============================================================================
# STATE
# ============================================================================

## upgrade_id (String) → level (int)
var levels: Dictionary = {}

# ============================================================================
# COMPUTED MODIFIERS (default no-op)
# ============================================================================

var drill_speed_multiplier: float = 1.0
var drill_reach_multiplier: float = 1.0
var scan_radius_multiplier: float = 1.0
var scan_cooldown_multiplier: float = 1.0  # < 1.0 means faster scans
var move_speed_multiplier: float = 1.0
var gold_value_multiplier: float = 1.0
var storage_capacity_bonus: int = 0
var session_time_bonus: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_init_levels()
	load_from_disk()
	_recompute()

func _init_levels() -> void:
	for id in Config.UPGRADE_DEFINITIONS.keys():
		levels[id] = 0

# ============================================================================
# QUERIES
# ============================================================================

func get_level(id: String) -> int:
	return levels.get(id, 0)

func get_max_level(id: String) -> int:
	var def: Dictionary = Config.UPGRADE_DEFINITIONS.get(id, {})
	return def.get("max_level", 0)

func is_maxed(id: String) -> bool:
	return get_level(id) >= get_max_level(id)

## Cost to buy the next level. Returns -1 when maxed.
func get_current_cost(id: String) -> int:
	if is_maxed(id):
		return -1
	var def: Dictionary = Config.UPGRADE_DEFINITIONS[id]
	var lvl: int = get_level(id)
	return int(round(float(def["base_cost"]) * pow(Config.UPGRADE_COST_GROWTH, lvl)))

func can_purchase(id: String) -> bool:
	if is_maxed(id):
		return false
	return GameManager.can_afford(get_current_cost(id))

# ============================================================================
# MUTATIONS
# ============================================================================

## Purchase the next level of an upgrade. Returns true on success.
func purchase(id: String) -> bool:
	if not can_purchase(id):
		return false
	var cost: int = get_current_cost(id)
	GameManager.change_money(-cost)
	levels[id] = get_level(id) + 1
	_recompute()
	save_to_disk()
	EventBus.upgrade_purchased.emit(id, levels[id])
	EventBus.upgrades_changed.emit()
	print("[Upgrades] Purchased %s → Lv %d ($%d)" % [id, levels[id], cost])
	return true

## Reset all upgrades to level 0 and remove the save file (called on New Game).
func reset() -> void:
	_init_levels()
	_recompute()
	if FileAccess.file_exists(SAVE_PATH):
		var abs_path: String = ProjectSettings.globalize_path(SAVE_PATH)
		var err: int = DirAccess.remove_absolute(abs_path)
		if err != OK:
			push_warning("[Upgrades] Could not delete save file: %d" % err)
	EventBus.upgrades_changed.emit()
	print("[Upgrades] Reset all levels")

# ============================================================================
# RECOMPUTATION
# ============================================================================

func _recompute() -> void:
	drill_speed_multiplier   = _compute_multiplier("drill_speed")
	drill_reach_multiplier   = _compute_multiplier("drill_reach")
	scan_radius_multiplier   = _compute_multiplier("scan_radius")
	scan_cooldown_multiplier = _compute_multiplier("scan_cooldown")
	move_speed_multiplier    = _compute_multiplier("move_speed")
	gold_value_multiplier    = _compute_multiplier("gold_value")
	storage_capacity_bonus   = _compute_additive_int("storage")
	session_time_bonus       = float(_compute_additive_int("session_time"))

func _compute_multiplier(id: String) -> float:
	var def: Dictionary = Config.UPGRADE_DEFINITIONS.get(id, {})
	var lvl: int = get_level(id)
	var per: float = def.get("effect_per_level", 0.0)
	match def.get("effect_kind", "multiplier"):
		"multiplier_inverse":
			return maxf(0.25, 1.0 - per * lvl)
		_:
			return 1.0 + per * lvl

func _compute_additive_int(id: String) -> int:
	var def: Dictionary = Config.UPGRADE_DEFINITIONS.get(id, {})
	var lvl: int = get_level(id)
	var per: float = def.get("effect_per_level", 0.0)
	return int(round(per * lvl))

# ============================================================================
# PERSISTENCE
# ============================================================================

func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	for id in levels.keys():
		cfg.set_value("levels", id, levels[id])
	var err: int = cfg.save(SAVE_PATH)
	if err != OK:
		push_error("[Upgrades] Save failed: %d" % err)

func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(SAVE_PATH)
	if err != OK:
		return
	for id in Config.UPGRADE_DEFINITIONS.keys():
		levels[id] = int(cfg.get_value("levels", id, 0))
