extends PanelContainer

## Individual plot card UI component

# ============================================================================
# SIGNALS
# ============================================================================

signal bid_pressed()

# ============================================================================
# NODES
# ============================================================================

@onready var plot_name_label: Label = $VBoxContainer/PlotNameLabel
@onready var preview_rect: ColorRect = $VBoxContainer/PreviewRect
@onready var richness_label: Label = $VBoxContainer/RichnessLabel
@onready var price_label: Label = $VBoxContainer/PriceLabel
@onready var bid_button: Button = $VBoxContainer/BidButton

# ============================================================================
# DATA
# ============================================================================

var plot_data: PlotData

# ============================================================================
# SETUP
# ============================================================================

func _ready() -> void:
	bid_button.pressed.connect(_on_bid_button_pressed)

func setup(plot: PlotData) -> void:
	plot_data = plot

	plot_name_label.text = plot.plot_name
	richness_label.text = "★".repeat(plot.get_star_rating()) + " " + plot.get_richness_tier()
	price_label.text = "Starting Bid: $%d" % plot.base_price

	# Color preview based on richness
	var richness_color: Color = Color.BROWN.lerp(Color.GOLD, plot.gold_richness)
	preview_rect.color = richness_color

# ============================================================================
# INTERACTIONS
# ============================================================================

func _on_bid_button_pressed() -> void:
	bid_pressed.emit()
