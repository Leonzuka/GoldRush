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

const ROUND_TIME_LIMIT: float = 300.0  # 5 minutes
const STORAGE_CAPACITY: int = 500      # Gold goal threshold (not a hard cap)
const STORAGE_GOAL_BONUS: int = 300    # Money bonus for filling storage
const DRILL_SPEED: float = 3.0         # Tiles per second
const DRILL_REACH: float = 64.0        # Pixels from player (2 tiles @ 32px)

# ============================================================================
# SCANNER CONSTANTS
# ============================================================================

const SCAN_RADIUS: float = 80.0        # Pixels
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
