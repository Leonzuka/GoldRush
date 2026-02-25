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
@onready var left_depth_polygon: Polygon2D = $LeftDepthPolygon
@onready var depth_border_line: Line2D = $DepthBorderLine
@onready var border_line: Line2D = $BorderLine
@onready var owner_flag: Sprite2D = $OwnerFlag
@onready var area: Area2D = $Area2D
@onready var collision: CollisionPolygon2D = $Area2D/CollisionPolygon2D

var is_hovered: bool = false
var hover_tween: Tween
var pulse_tween: Tween
var pin_tween: Tween
var npc_pin: Label

func _input(event: InputEvent) -> void:
	if not plot_data:
		return

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos = area.get_local_mouse_position()
			if _point_in_polygon(local_pos, collision.polygon):
				if plot_data.is_biddable():
					clicked.emit(self)
					get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not plot_data:
		return

	var local_pos = area.get_local_mouse_position()
	var mouse_over = _point_in_polygon(local_pos, collision.polygon)

	if mouse_over != is_hovered:
		is_hovered = mouse_over
		if is_hovered:
			hovered.emit(self)
		update_visual_state()

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
	_setup_npc_pin()

	# Load Gold Mine sprite (now using .jpeg extension)
	_setup_mine_sprite()

	if plot_data:
		update_visual_state()
		if OS.is_debug_build():
			print("[PlotTile] Ready: " + plot_data.plot_name + " at position " + str(position))

	if OS.is_debug_build():
		print("[PlotTile] Area2D pickable: " + str(area.input_pickable) + ", monitoring: " + str(area.monitoring))
		print("[PlotTile] CollisionPolygon2D points: " + str(collision.polygon.size()))

## Setup Gold Mine sprite to fill the isometric tile
func _setup_mine_sprite() -> void:
	var sprite_path = "res://assets/sprites/Gold_Mine.jpeg"
	var texture = load(sprite_path)

	if texture:
		owner_flag.texture = texture

		# Scale sprite to fit inside the isometric diamond (128x64)
		var tex_size = texture.get_size()
		var scale_x = Config.ISO_TILE_WIDTH * 0.7 / tex_size.x
		var scale_y = Config.ISO_TILE_HEIGHT * 0.9 / tex_size.y
		var scale_factor = min(scale_x, scale_y)

		owner_flag.scale = Vector2(scale_factor, scale_factor)
		owner_flag.position = Vector2.ZERO  # Centered on the diamond
		owner_flag.visible = false  # Hidden until owned

		if OS.is_debug_build():
			print("[PlotTile] Gold Mine sprite loaded: scale=%.2f" % scale_factor)
	else:
		push_error("[PlotTile] Failed to load Gold_Mine.jpeg")

## Creates isometric diamond geometry for the tile
func _setup_geometry() -> void:
	var hw = Config.ISO_TILE_WIDTH / 2.0
	var hh = Config.ISO_TILE_HEIGHT / 2.0
	var depth = Config.ISO_TILE_DEPTH

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

	# Depth face (2.5D side effect) - Left side
	left_depth_polygon.polygon = PackedVector2Array([
		Vector2(-hw, 0),             # Left point of diamond
		Vector2(0, hh),              # Bottom point of diamond
		Vector2(0, hh + depth),      # Bottom point + depth
		Vector2(-hw, 0 + depth)      # Left point + depth
	])

	# Border outline for depth sides
	depth_border_line.points = PackedVector2Array([
		Vector2(-hw, 0),             # Left point
		Vector2(-hw, 0 + depth),     # Left point + depth
		Vector2(0, hh + depth),      # Bottom point + depth
		Vector2(hw, 0 + depth),      # Right point + depth
		Vector2(hw, 0)               # Right point
	])

	# Border outline (top diamond)
	border_line.points = PackedVector2Array([
		Vector2(0, -hh),
		Vector2(hw, 0),
		Vector2(0, hh),
		Vector2(-hw, 0),
		Vector2(0, -hh)  # Close the loop
	])

## Sets up input detection
func _setup_input() -> void:
	# Explicitly configure Area2D for input
	area.input_pickable = true
	area.monitoring = false  # We don't need collision detection
	area.monitorable = false

	# Connect signals
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)

## Updates visual appearance based on plot state
func update_visual_state() -> void:
	if not plot_data:
		return

	# Base color from richness
	var base_color = plot_data.get_richness_color()
	ground_polygon.color = base_color
	depth_polygon.color = base_color.darkened(0.4)
	left_depth_polygon.color = base_color.darkened(0.55)

	# Kill any running hover tweens
	if hover_tween and hover_tween.is_valid():
		hover_tween.kill()
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()

	# State-based modulation
	match plot_data.owner_type:
		PlotData.OwnerType.AVAILABLE:
			if is_hovered:
				_animate_hover_in()
			else:
				_animate_hover_out()
			owner_flag.visible = false

		PlotData.OwnerType.NPC:
			is_hovered = false
			modulate = Color(0.6, 0.6, 0.7)
			scale = Vector2.ONE
			border_line.width = 2.0
			border_line.default_color = Color(0.8, 0.3, 0.3)
			depth_border_line.width = 2.0
			depth_border_line.default_color = Color(0.8, 0.3, 0.3)
			owner_flag.visible = true
			owner_flag.modulate = Color(0.8, 0.3, 0.3, 0.8)

		PlotData.OwnerType.PLAYER:
			is_hovered = false
			modulate = Color(0.7, 0.9, 1.2)
			scale = Vector2.ONE
			border_line.width = 3.0
			border_line.default_color = Color(0.2, 0.6, 1.0)
			depth_border_line.width = 3.0
			depth_border_line.default_color = Color(0.2, 0.6, 1.0)
			owner_flag.visible = true
			owner_flag.modulate = Color(0.2, 0.6, 1.0, 0.8)

## Animate tile when mouse hovers over it
func _animate_hover_in() -> void:
	hover_tween = create_tween().set_parallel(true)
	hover_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	hover_tween.tween_property(self, "modulate", Color(1.25, 1.2, 1.1), 0.15)
	border_line.width = 3.0
	border_line.default_color = Color(1.0, 0.9, 0.5)
	depth_border_line.width = 3.0
	depth_border_line.default_color = Color(1.0, 0.9, 0.5)

	# Start pulsating border glow
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(border_line, "default_color", Color(1.0, 0.85, 0.3), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(border_line, "default_color", Color(1.0, 0.95, 0.7), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## Animate tile back to normal when mouse leaves
func _animate_hover_out() -> void:
	hover_tween = create_tween().set_parallel(true)
	hover_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	hover_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	hover_tween.tween_property(border_line, "width", 1.5, 0.2)
	hover_tween.tween_property(border_line, "default_color", Color(0.3, 0.3, 0.3), 0.2)
	hover_tween.tween_property(depth_border_line, "default_color", Color(0.3, 0.3, 0.3), 0.2)

func _on_mouse_entered() -> void:
	if plot_data and plot_data.is_biddable():
		is_hovered = true
		hovered.emit(self)
		update_visual_state()

func _on_mouse_exited() -> void:
	is_hovered = false
	update_visual_state()

## Creates the NPC pinpoint label positioned above the tile
func _setup_npc_pin() -> void:
	npc_pin = Label.new()
	npc_pin.visible = false
	npc_pin.z_index = 10
	npc_pin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_pin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	npc_pin.position = Vector2(-50, -Config.ISO_TILE_HEIGHT - 28)
	npc_pin.custom_minimum_size = Vector2(100, 28)

	# Style the pin background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.border_color = Color(1.0, 0.6, 0.1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	npc_pin.add_theme_stylebox_override("normal", style)
	npc_pin.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	npc_pin.add_theme_font_size_override("font_size", 11)

	add_child(npc_pin)

## Shows the NPC pinpoint marker with an animated pop-in
func show_npc_pin(npc_name: String) -> void:
	npc_pin.text = "📍 %s" % npc_name
	npc_pin.visible = true
	npc_pin.scale = Vector2(0.3, 0.3)
	npc_pin.modulate = Color(1, 1, 1, 0)

	if pin_tween and pin_tween.is_valid():
		pin_tween.kill()

	pin_tween = create_tween().set_parallel(true)
	pin_tween.tween_property(npc_pin, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	pin_tween.tween_property(npc_pin, "modulate", Color.WHITE, 0.2)

## Hides the NPC pinpoint marker with a fade-out
func hide_npc_pin() -> void:
	if not npc_pin or not npc_pin.visible:
		return

	if pin_tween and pin_tween.is_valid():
		pin_tween.kill()

	pin_tween = create_tween()
	pin_tween.tween_property(npc_pin, "modulate", Color(1, 1, 1, 0), 0.15)
	pin_tween.tween_callback(func(): npc_pin.visible = false)
