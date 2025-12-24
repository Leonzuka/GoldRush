extends Resource
class_name PlotData

## Data structure for land plot properties
## Used by auction system and terrain generation

## Ownership types for auction plots
enum OwnerType { AVAILABLE, NPC, PLAYER }

@export var plot_id: int = 0
@export var plot_name: String = "Unnamed Plot"
@export var terrain_seed: int = 0
@export var gold_richness: float = 1.0  # Multiplier: 0.5-1.5
@export var base_price: int = 100
@export var final_bid_price: int = 100  # Updated after auction

## Preview texture (optional, for future minimap)
@export var preview_texture: Texture2D = null

## Grid positioning for isometric map
@export var grid_position: Vector2i = Vector2i.ZERO  # (col, row)

## Ownership tracking
@export var owner_type: OwnerType = OwnerType.AVAILABLE
@export var owner_name: String = ""  # NPC name if owned by NPC

## Get difficulty tier (for UI display)
func get_richness_tier() -> String:
	if gold_richness < 0.7:
		return "Poor"
	elif gold_richness < 1.2:
		return "Average"
	else:
		return "Rich"

## Get star rating (1-3 stars)
func get_star_rating() -> int:
	if gold_richness < 0.7:
		return 1
	elif gold_richness < 1.2:
		return 2
	else:
		return 3

## Get richness color for visual representation
## Returns color gradient from brown (poor) to gold (rich)
func get_richness_color() -> Color:
	var base_color = Color(0.35, 0.25, 0.15)  # Dark brown
	var rich_color = Color(1.0, 0.84, 0.0)    # Gold
	var t = clamp(gold_richness, 0.0, 1.5) / 1.5
	return base_color.lerp(rich_color, t)

## Check if plot can receive bids
func is_biddable() -> bool:
	return owner_type == OwnerType.AVAILABLE
