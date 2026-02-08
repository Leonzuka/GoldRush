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

const ROUND_TIME_LIMIT: float = 120.0  # 2 minutes
const STORAGE_CAPACITY: int = 100      # Gold units
const DRILL_SPEED: float = 3.0         # Tiles per second
const DRILL_REACH: float = 32.0        # Pixels from player

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
const TILE_SIZE: int = 16              # Pixels

const MIN_GOLD_DEPOSITS: int = 25
const MAX_GOLD_DEPOSITS: int = 50
const MIN_GOLD_AMOUNT: int = 15
const MAX_GOLD_AMOUNT: int = 60

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
const NPC_COUNT_PER_AUCTION: int = 3
const NPC_BID_DELAY: float = 0.8  # Seconds between NPC actions
const NPC_NAMES: Array[String] = ["Big Bob", "Sly Sally", "Mad Max"]

# Legacy NPC aggression (kept for compatibility)
const NPC_BASE_AGGRESSION: float = 0.2  # 20% chance to outbid
const NPC_AGGRESSION_SCALING: float = 0.05  # +5% per round

# ============================================================================
# PLAYER CONSTANTS
# ============================================================================

const PLAYER_SPEED: float = 150.0
const PLAYER_GRAVITY: float = 980.0

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
