extends Node2D
class_name IsometricMapController

## Controller for isometric auction map
## Manages plot tile instantiation, camera, and input routing

@export var plot_tile_scene: PackedScene  # Assign plot_tile.tscn in Inspector

@onready var camera: Camera2D = $Camera2D
@onready var plot_grid: Node2D = $PlotGrid

var plot_tiles: Dictionary = {}  # Key: Vector2i grid_pos, Value: PlotTile
var auction_system: AuctionSystem
var ui_controller: Control  # Reference to AuctionUIController

func _ready() -> void:
	await get_tree().process_frame

	auction_system = get_tree().get_first_node_in_group("auction_system")
	ui_controller = get_tree().get_first_node_in_group("auction_ui")

	if OS.is_debug_build():
		print("[IsometricMap] Found auction_system: %s" % (auction_system != null))
		print("[IsometricMap] Found ui_controller: %s" % (ui_controller != null))
		print("[IsometricMap] plot_tile_scene assigned: %s" % (plot_tile_scene != null))

	if auction_system:
		auction_system.plots_generated.connect(_on_plots_generated)
		auction_system.npc_considering_plot.connect(_on_npc_considering_plot)
		auction_system.npc_claimed_plot.connect(_on_npc_claimed_plot_map)
	else:
		push_error("[IsometricMap] AuctionSystem not found!")

## Instantiates plot tiles in isometric grid
func _on_plots_generated(plots: Array) -> void:
	if OS.is_debug_build():
		print("[IsometricMap] Generating %d plots..." % plots.size())
	_clear_map()

	for plot in plots:
		if not plot_tile_scene:
			push_error("PlotTile scene not assigned to IsometricMapController!")
			return

		var tile: PlotTile = plot_tile_scene.instantiate()

		# CRITICAL: Set plot_data BEFORE adding to tree (before _ready() is called)
		tile.plot_data = plot

		# Convert grid position to isometric coordinates
		var iso_pos = _grid_to_iso(plot.grid_position)
		tile.position = iso_pos

		# NOW add to tree (this calls _ready())
		plot_grid.add_child(tile)

		# Connect signals
		tile.clicked.connect(_on_plot_clicked)

		plot_tiles[plot.grid_position] = tile

		if OS.is_debug_build():
			print("[IsometricMap] Created tile %d (%s) at grid(%d,%d) iso(%.1f,%.1f)" % [
				plot.plot_id, plot.plot_name, plot.grid_position.x, plot.grid_position.y, iso_pos.x, iso_pos.y
			])

	_center_camera()

	# Force redraw
	queue_redraw()
	for tile in plot_tiles.values():
		tile.queue_redraw()

## Clears all plot tiles from map
func _clear_map() -> void:
	for child in plot_grid.get_children():
		child.queue_free()
	plot_tiles.clear()

## Converts grid coordinates (col, row) to isometric screen position
func _grid_to_iso(grid_pos: Vector2i) -> Vector2:
	var hw = Config.ISO_TILE_WIDTH / 2.0
	var hh = Config.ISO_TILE_HEIGHT / 2.0

	var x = (grid_pos.x - grid_pos.y) * hw
	var y = (grid_pos.x + grid_pos.y) * hh

	return Vector2(x, y)

## Centers camera on middle of grid
func _center_camera() -> void:
	# Center between first and last tile for better framing
	var center = Vector2i(Config.AUCTION_MAP_COLS / 2, Config.AUCTION_MAP_ROWS / 2)
	camera.position = _grid_to_iso(center)
	camera.zoom = Vector2(0.8, 0.8)  # Zoom out to see all tiles
	camera.enabled = true
	camera.make_current()

	if OS.is_debug_build():
		print("[IsometricMap] Camera centered at grid(%d,%d) = iso(%v)" % [
			center.x, center.y, camera.position
		])

## Propagates plot click to UI controller
func _on_plot_clicked(tile: PlotTile) -> void:
	if ui_controller:
		if ui_controller.has_method("show_plot_info"):
			ui_controller.show_plot_info(tile.plot_data)
		else:
			push_error("[IsometricMap] ui_controller doesn't have show_plot_info method!")
	else:
		push_error("[IsometricMap] ui_controller is null!")

## Refreshes visual state of a specific plot
func refresh_plot_visuals(plot: PlotData) -> void:
	var tile = plot_tiles.get(plot.grid_position)
	if tile:
		tile.update_visual_state()

## Shows pin on the tile an NPC is eyeing, clears all others
func _on_npc_considering_plot(plot: PlotData, npc_name: String) -> void:
	for tile in plot_tiles.values():
		tile.hide_npc_pin()
	var target_tile = plot_tiles.get(plot.grid_position)
	if target_tile:
		target_tile.show_npc_pin(npc_name)

## Hides pin once NPC has committed to a plot
func _on_npc_claimed_plot_map(plot: PlotData, _npc_name: String) -> void:
	var tile = plot_tiles.get(plot.grid_position)
	if tile:
		tile.hide_npc_pin()
