extends Node2D
class_name PlotTile

## Individual isometric plot tile for auction map
## Handles rendering, visual states, and player interaction

signal clicked(plot_tile: PlotTile)
signal hovered(plot_tile: PlotTile)

@export var plot_data: PlotData:
	set(value):
		plot_data = value
		if is_node_ready():
			update_visual_state()

@onready var ground_polygon: Polygon2D = $GroundPolygon
@onready var depth_polygon: Polygon2D = $DepthPolygon
@onready var border_line: Line2D = $BorderLine
@onready var owner_flag: Sprite2D = $OwnerFlag
@onready var area: Area2D = $Area2D
@onready var collision: CollisionPolygon2D = $Area2D/CollisionPolygon2D

var is_hovered: bool = false

func _input(event: InputEvent) -> void:
	if not plot_data:
		return

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if mouse is within our collision shape
			var local_pos = area.get_local_mouse_position()

			if _point_in_polygon(local_pos, collision.polygon):
				print("[PlotTile] Click INSIDE polygon on " + plot_data.plot_name + "!")
				print("[PlotTile] is_biddable: " + str(plot_data.is_biddable()) + ", owner: " + PlotData.OwnerType.keys()[plot_data.owner_type])

				if plot_data.is_biddable():
					print("[PlotTile] Emitting clicked signal!")
					clicked.emit(self)
					get_viewport().set_input_as_handled()
				else:
					print("[PlotTile] Plot is NOT biddable, not emitting signal")

func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	# Simple point-in-polygon test
	var inside = false
	var j = polygon.size() - 1

	for i in range(polygon.size()):
		if ((polygon[i].y > point.y) != (polygon[j].y > point.y)) and \
		   (point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x):
			inside = !inside
		j = i

	return inside

func _ready() -> void:
	# Setup immediately - no deferred calls
	_setup_geometry()
	_setup_input()

	# Load Gold Mine sprite (now using .jpeg extension)
	_setup_mine_sprite()

	if plot_data:
		update_visual_state()
		print("[PlotTile] Ready: " + plot_data.plot_name + " at position " + str(position))

	# Debug: Verify Area2D configuration
	print("[PlotTile] Area2D pickable: " + str(area.input_pickable) + ", monitoring: " + str(area.monitoring))
	print("[PlotTile] CollisionPolygon2D points: " + str(collision.polygon.size()))

	# Enable processing for hover detection
	set_process(true)

func _process(_delta: float) -> void:
	if not plot_data or not plot_data.is_biddable():
		if is_hovered:
			is_hovered = false
			update_visual_state()
		return

	# Check if mouse is hovering over this tile
	var local_pos = area.get_local_mouse_position()
	var mouse_over = _point_in_polygon(local_pos, collision.polygon)

	if mouse_over != is_hovered:
		is_hovered = mouse_over
		if is_hovered:
			print("[PlotTile] Mouse entered " + plot_data.plot_name)
			hovered.emit(self)
		else:
			print("[PlotTile] Mouse exited " + plot_data.plot_name)
		update_visual_state()

## Setup Gold Mine sprite to fill the isometric tile
func _setup_mine_sprite() -> void:
	var sprite_path = "res://assets/sprites/Gold_Mine.jpeg"
	var texture = load(sprite_path)

	if texture:
		owner_flag.texture = texture

		# Calculate scale to fill the isometric diamond
		# Tile is 128x64 diamond, we want sprite to fill it
		var tile_width = Config.ISO_TILE_WIDTH  # 128
		var tile_height = Config.ISO_TILE_HEIGHT  # 64

		# Get texture size
		var tex_size = texture.get_size()

		# Scale to fill the entire tile rectangle
		# Multiply by 1.2 to make sprite fit nicely within the isometric space
		var full_size = (tile_width + Config.ISO_TILE_DEPTH) * 1.2  # 160 * 1.2 = 192
		var scale_factor = full_size / max(tex_size.x, tex_size.y)

		owner_flag.scale = Vector2(scale_factor, scale_factor)
		owner_flag.position = Vector2(0, Config.ISO_TILE_DEPTH / 2)  # Offset down to cover depth
		owner_flag.visible = false  # Hidden until owned

		print("[PlotTile] Gold Mine sprite loaded: scale=%.2f" % scale_factor)
	else:
		push_error("[PlotTile] Failed to load Gold_Mine.jpeg")

## Creates isometric diamond geometry for the tile
func _setup_geometry() -> void:
	var hw = Config.ISO_TILE_WIDTH / 2.0
	var hh = Config.ISO_TILE_HEIGHT / 2.0
	var depth = Config.ISO_TILE_DEPTH

	print("[PlotTile] Setup geometry: hw=%.1f, hh=%.1f, depth=%.1f" % [hw, hh, depth])

	# Ground face (top diamond)
	var diamond = PackedVector2Array([
		Vector2(0, -hh),      # Top
		Vector2(hw, 0),       # Right
		Vector2(0, hh),       # Bottom
		Vector2(-hw, 0)       # Left
	])
	ground_polygon.polygon = diamond
	collision.polygon = diamond

	# Depth face (2.5D side effect) - Right side
	depth_polygon.polygon = PackedVector2Array([
		Vector2(0, hh),              # Bottom point of diamond
		Vector2(hw, 0),              # Right point of diamond
		Vector2(hw, 0 + depth),      # Right point + depth
		Vector2(0, hh + depth)       # Bottom point + depth
	])

	# Border outline
	border_line.points = PackedVector2Array([
		Vector2(0, -hh),
		Vector2(hw, 0),
		Vector2(0, hh),
		Vector2(-hw, 0),
		Vector2(0, -hh)  # Close the loop
	])

	print("[PlotTile] Geometry set: ground=%d points, border=%d points" % [
		ground_polygon.polygon.size(), border_line.points.size()
	])

## Sets up input detection
func _setup_input() -> void:
	# Explicitly configure Area2D for input
	area.input_pickable = true
	area.monitoring = false  # We don't need collision detection
	area.monitorable = false

	# Connect signals
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)

	print("[PlotTile] Input setup complete, signals connected")

## Updates visual appearance based on plot state
func update_visual_state() -> void:
	if not plot_data:
		print("[PlotTile] update_visual_state called but plot_data is null!")
		return

	# Base color from richness
	var base_color = plot_data.get_richness_color()
	ground_polygon.color = base_color
	depth_polygon.color = base_color.darkened(0.4)

	print("[PlotTile] Visual updated for " + plot_data.plot_name + ": color=" + str(base_color) + ", owner=" + PlotData.OwnerType.keys()[plot_data.owner_type])

	# State-based modulation
	match plot_data.owner_type:
		PlotData.OwnerType.AVAILABLE:
			if is_hovered:
				modulate = Color(1.15, 1.15, 1.15)
				border_line.width = 2.5
				border_line.default_color = Color.WHITE
			else:
				modulate = Color.WHITE
				border_line.width = 1.5
				border_line.default_color = Color(0.3, 0.3, 0.3)
			owner_flag.visible = false

		PlotData.OwnerType.NPC:
			modulate = Color(0.6, 0.6, 0.7)
			border_line.width = 2.0
			border_line.default_color = Color(0.8, 0.3, 0.3)  # Red
			owner_flag.visible = true
			owner_flag.modulate = Color(0.8, 0.3, 0.3, 0.8)  # Red tint for NPC

		PlotData.OwnerType.PLAYER:
			modulate = Color(0.7, 0.9, 1.2)
			border_line.width = 3.0
			border_line.default_color = Color(0.2, 0.6, 1.0)  # Blue
			owner_flag.visible = true
			owner_flag.modulate = Color(0.2, 0.6, 1.0, 0.8)  # Blue tint for player

func _on_area_input_event(_viewport, event, _shape_idx):
	print("[PlotTile] Input event: %s" % event)
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if plot_data and plot_data.is_biddable():
				print("[PlotTile] Clicked on %s!" % plot_data.plot_name)
				clicked.emit(self)
			elif plot_data:
				print("[PlotTile] Clicked but not biddable (owner: %s)" % plot_data.owner_name)

func _on_mouse_entered() -> void:
	print("[PlotTile] Mouse entered")
	if plot_data and plot_data.is_biddable():
		is_hovered = true
		hovered.emit(self)
		update_visual_state()

func _on_mouse_exited() -> void:
	print("[PlotTile] Mouse exited")
	is_hovered = false
	update_visual_state()
