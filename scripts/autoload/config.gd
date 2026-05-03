extends Node

## Global configuration constants
## Centralized tunable parameters for game balance

# ============================================================================
# ECONOMY CONSTANTS
# ============================================================================

const STARTING_MONEY: int = 1000
const MIN_PLOT_PRICE: int = 100
const MAX_PLOT_PRICE: int = 500

# ============================================================================
# MINING SESSION CONSTANTS
# ============================================================================

## Round duration tiers — early rounds are short (player has few resources/upgrades),
## later rounds expand to give time for deeper strategy. Always read via
## get_round_time_limit(round_num); never reference these constants directly.
const ROUND_TIME_EARLY: float = 300.0  # rounds 1-3: 5 min
const ROUND_TIME_MID: float   = 600.0  # rounds 4-6: 10 min
const ROUND_TIME_LATE: float  = 900.0  # rounds 7+:  15 min

const STORAGE_CAPACITY: int = 500      # Gold goal threshold (not a hard cap)
const STORAGE_GOAL_BONUS: int = 300    # Money bonus for filling storage
const DRILL_SPEED: float = 3.0         # Tiles per second
const DRILL_REACH: float = 64.0        # Pixels from player (2 tiles @ 32px)

# ============================================================================
# SCANNER CONSTANTS
# ============================================================================

const SCAN_RADIUS: float = 120.0       # Pixels (~50% larger than original 80)
const SCAN_COOLDOWN: float = 3.0       # Seconds between scans

# ============================================================================
# TERRAIN GENERATION CONSTANTS
# ============================================================================

const TERRAIN_WIDTH: int = 100         # Tiles
const TERRAIN_HEIGHT: int = 50         # Tiles
const TILE_SIZE: int = 32              # Pixels

const MIN_GOLD_DEPOSITS: int = 25
const MAX_GOLD_DEPOSITS: int = 50
const MIN_GOLD_AMOUNT: int = 15
const MAX_GOLD_AMOUNT: int = 60

# ============================================================================
# RARE COLLECTIBLE CONSTANTS
# ============================================================================

## Diamond: rare, deep (row 30+), high value
const DIAMOND_COUNT_MIN: int = 2
const DIAMOND_COUNT_MAX: int = 4
const DIAMOND_VALUE_MIN: int = 200
const DIAMOND_VALUE_MAX: int = 400
const DIAMOND_MIN_DEPTH: int = 30    # Tile row

## Relic: very rare, anywhere deep, extreme value
const RELIC_COUNT_MIN: int = 1
const RELIC_COUNT_MAX: int = 2
const RELIC_VALUE_MIN: int = 400
const RELIC_VALUE_MAX: int = 800
const RELIC_MIN_DEPTH: int = 20

## Fossil: visible terrain decoration (not collectible) — always visible to player
const FOSSIL_COUNT_MIN: int = 5
const FOSSIL_COUNT_MAX: int = 10
const FOSSIL_MIN_DEPTH: int = 10    # Row 10+
const FOSSIL_DISPLAY_PX: float = 64.0  # 2×2 tiles (2 * TILE_SIZE)

# ============================================================================
# AUCTION CONSTANTS
# ============================================================================

# Auction map grid
const AUCTION_MAP_COLS: int = 4
const AUCTION_MAP_ROWS: int = 3
const TOTAL_AUCTION_PLOTS: int = 12  # 4×3

# Isometric tile dimensions
const ISO_TILE_WIDTH: int = 128   # Diamond width in pixels
const ISO_TILE_HEIGHT: int = 64   # Diamond height in pixels
const ISO_TILE_DEPTH: int = 32    # Visual depth for 2.5D effect

# NPC configuration
const NPC_COUNT_PER_AUCTION: int = 4
const NPC_BID_DELAY: float = 2.0  # Seconds between NPC actions
const NPC_NAMES: Array[String] = ["Big Bob", "Sly Sally", "Mad Max", "Lily"]
const NPC_COLORS: Dictionary = {
	"Big Bob":   Color(0.9, 0.5, 0.1),
	"Sly Sally": Color(0.6, 0.2, 0.8),
	"Mad Max":   Color(0.9, 0.15, 0.15),
	"Lily":      Color(0.2, 0.75, 0.5),
}

## NPC portrait image paths (used by auction UI and minigame)
const NPC_IMAGES: Dictionary = {
	"Big Bob":   "res://assets/sprites/NPC's/BigBob.png",
	"Sly Sally": "res://assets/sprites/NPC's/SlySally.png",
	"Mad Max":   "res://assets/sprites/NPC's/MadMAx.png",
	"Lily":      "res://assets/sprites/NPC's/Lily.png",
}

## Fixed personality profiles per NPC — used by NPCAuctionAgent
const NPC_PROFILES: Dictionary = {
	"Big Bob": {
		"personality": "conservative",
		"budget_min": 400,  "budget_max": 900,
		"richness_bias": 0.65,
		"claim_threshold": 0.25,
		"rps_weights": [0.5, 0.3, 0.2],   # Favors Rock
		"sabotage_chance": 0.05,
		"challenge_chance": 0.2,
	},
	"Sly Sally": {
		"personality": "cunning",
		"budget_min": 700,  "budget_max": 1400,
		"richness_bias": 1.15,
		"claim_threshold": 0.35,
		"rps_weights": [0.15, 0.35, 0.5],  # Favors Scissors
		"sabotage_chance": 0.35,
		"challenge_chance": 0.5,
	},
	"Mad Max": {
		"personality": "aggressive",
		"budget_min": 900,  "budget_max": 1800,
		"richness_bias": 1.35,
		"claim_threshold": 0.2,
		"rps_weights": [0.65, 0.2, 0.15],  # Favors Rock (brute)
		"sabotage_chance": 0.4,
		"challenge_chance": 0.9,
	},
	"Lily": {
		"personality": "smart",
		"budget_min": 750,  "budget_max": 1500,
		"richness_bias": 1.0,
		"claim_threshold": 0.3,
		"rps_weights": [0.33, 0.34, 0.33],  # Adapts to player history
		"sabotage_chance": 0.2,
		"challenge_chance": 0.55,
	},
}

# Legacy NPC aggression (kept for compatibility)
const NPC_BASE_AGGRESSION: float = 0.2  # 20% chance to outbid
const NPC_AGGRESSION_SCALING: float = 0.05  # +5% per round

## Steal phase: aggressive/cunning NPCs may steal a plot from a weaker NPC
## by paying STEAL_MULTIPLIER_MIN..MAX × the current price.
const STEAL_MULTIPLIER_MIN: float = 1.2
const STEAL_MULTIPLIER_MAX: float = 1.5

# ============================================================================
# LOAN SYSTEM
# ============================================================================

const LOAN_INTEREST_RATE: float = 0.10  # 10% per round
const LOAN_BASE_AMOUNT: int = 1000      # Base amount used by get_max_loan()
const LOAN_HARD_CAP: int = 5000         # Absolute ceiling regardless of round

# ============================================================================
# PLAYER CONSTANTS
# ============================================================================

const PLAYER_SPEED: float = 150.0
const PLAYER_GRAVITY: float = 980.0
const PLAYER_JUMP_VELOCITY: float = 350.0

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Get NPC bidding aggression for current round
func get_npc_aggression(round_number: int) -> float:
	return min(NPC_BASE_AGGRESSION + (round_number * NPC_AGGRESSION_SCALING), 0.6)

## Get number of gold deposits for plot richness
func get_deposit_count(richness: float) -> int:
	var base_count: float = float(MIN_GOLD_DEPOSITS + MAX_GOLD_DEPOSITS) / 2.0
	return int(base_count * richness)

## Round duration in seconds — short early rounds, longer mid/late.
## Adds UpgradeManager.session_time_bonus so the time-extension upgrade
## flows through every consumer of this helper.
func get_round_time_limit(round_num: int) -> float:
	var base: float
	if round_num <= 3:
		base = ROUND_TIME_EARLY
	elif round_num <= 6:
		base = ROUND_TIME_MID
	else:
		base = ROUND_TIME_LATE
	return base + UpgradeManager.session_time_bonus

## Plot price multiplier — plots get more expensive each round
func get_plot_price_multiplier(round_num: int) -> float:
	return 1.0 + float(round_num - 1) * 0.15

## NPC budget multiplier — NPCs scale their war chest with the player's progression
func get_npc_budget_multiplier(round_num: int) -> float:
	return 1.0 + float(round_num - 1) * 0.20

## Maximum loan available this round (scales with progression, capped)
func get_max_loan(round_num: int) -> int:
	return mini(int(LOAN_BASE_AMOUNT * (1.0 + round_num * 0.5)), LOAN_HARD_CAP)

# ============================================================================
# UI COLOR CONSTANTS (mirrors UITheme palette for code without UITheme dep)
# ============================================================================

const UI_COLOR_BG_DEEP       := Color(0.102, 0.051, 0.024)  # #1A0D06
const UI_COLOR_BG_SURFACE    := Color(0.176, 0.082, 0.031)  # #2D1508
const UI_COLOR_SURFACE_LIGHT := Color(0.420, 0.188, 0.063)  # #6B3010
const UI_COLOR_GOLD_PRIMARY  := Color(0.784, 0.573, 0.165)  # #C8922A
const UI_COLOR_GOLD_BRIGHT   := Color(0.941, 0.753, 0.376)  # #F0C060
const UI_COLOR_TEXT_WARM     := Color(0.961, 0.871, 0.702)  # #F5DEB3
const UI_COLOR_TEXT_MUTED    := Color(0.753, 0.627, 0.376)  # #C0A060
const UI_COLOR_DANGER        := Color(0.545, 0.125, 0.125)  # #8B2020
const UI_COLOR_SUCCESS       := Color(0.165, 0.420, 0.125)  # #2A6B20
const UI_COLOR_BORDER_GOLD   := Color(0.545, 0.412, 0.078)  # #8B6914

# ============================================================================
# UPGRADE DEFINITIONS
# ============================================================================

## Cost growth per level: cost = base_cost * pow(GROWTH, current_level)
const UPGRADE_COST_GROWTH: float = 1.6

## Upgrade catalog. Keys iterate in declaration order (used to lay out the shop grid).
##
## effect_kind:
##   "multiplier"          → modifier = 1.0 + effect_per_level * level (e.g. drill speed +20%/lv)
##   "multiplier_inverse"  → modifier = max(0.25, 1.0 - effect_per_level * level) (e.g. cooldown -15%/lv)
##   "additive"            → bonus = effect_per_level * level (e.g. +200 storage/lv)
const UPGRADE_DEFINITIONS: Dictionary = {
	"drill_speed":   { "label": "UPGRADE_DRILL_SPEED",   "icon": "🔨",
						"base_cost": 200, "max_level": 5,
						"effect_per_level": 0.20, "effect_kind": "multiplier" },
	"storage":       { "label": "UPGRADE_STORAGE",        "icon": "📦",
						"base_cost": 250, "max_level": 5,
						"effect_per_level": 200, "effect_kind": "additive" },
	"scan_radius":   { "label": "UPGRADE_SCAN_RADIUS",    "icon": "📡",
						"base_cost": 220, "max_level": 5,
						"effect_per_level": 0.25, "effect_kind": "multiplier" },
	"drill_reach":   { "label": "UPGRADE_DRILL_REACH",    "icon": "🪝",
						"base_cost": 180, "max_level": 4,
						"effect_per_level": 0.25, "effect_kind": "multiplier" },
	"scan_cooldown": { "label": "UPGRADE_SCAN_COOLDOWN",  "icon": "⏱",
						"base_cost": 240, "max_level": 5,
						"effect_per_level": 0.15, "effect_kind": "multiplier_inverse" },
	"move_speed":    { "label": "UPGRADE_MOVE_SPEED",     "icon": "👟",
						"base_cost": 160, "max_level": 4,
						"effect_per_level": 0.15, "effect_kind": "multiplier" },
	"session_time":  { "label": "UPGRADE_SESSION_TIME",   "icon": "⏳",
						"base_cost": 280, "max_level": 4,
						"effect_per_level": 30, "effect_kind": "additive" },
	"gold_value":    { "label": "UPGRADE_GOLD_VALUE",     "icon": "💰",
						"base_cost": 350, "max_level": 5,
						"effect_per_level": 0.20, "effect_kind": "multiplier" },
}
