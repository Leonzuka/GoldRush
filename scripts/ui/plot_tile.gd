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
@onready var owner_flag: AnimatedSprite2D = $OwnerFlag
@onready var area: Area2D = $Area2D
@onready var collision: CollisionPolygon2D = $Area2D/CollisionPolygon2D

static var _mine_frames: SpriteFrames = null
static var _preload_started: bool = false

## Kick off background loading of all 140 mine frames.
## Call this as early as possible (e.g. IsometricMapController._ready())
## so frames are ready by the time tiles are actually owned and displayed.
static func request_preload() -> void:
	if _preload_started:
		return
	_preload_started = true
	for i in range(1, 141):
		var path = "res://assets/sprites/gold_mine_animated/without ground/gold_mine%04d.png" % i
		ResourceLoader.load_threaded_request(path, "Texture2D", false, ResourceLoader.CACHE_MODE_REUSE)

const NPC_IMAGES: Dictionary = {
	"Big Bob":   "res://assets/sprites/NPC's/BigBob.png",
	"Sly Sally": "res://assets/sprites/NPC's/SlySally.png",
	"Mad Max":   "res://assets/sprites/NPC's/MadMAx.png",
}

var is_hovered: bool = false
var hover_tween: Tween
var pulse_tween: Tween
var pin_tween: Tween
var npc_pin: PanelContainer
var npc_pin_style: StyleBoxFlat
var npc_pin_avatar: TextureRect
var npc_pin_label: Label
var name_label: Label

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
	_setup_name_label()

	# Load Gold Mine sprite (now using .jpeg extension)
	_setup_mine_sprite()

	if plot_data:
		update_visual_state()
		if OS.is_debug_build():
			print("[PlotTile] Ready: " + plot_data.plot_name + " at position " + str(position))

	if OS.is_debug_build():
		print("[PlotTile] Area2D pickable: " + str(area.input_pickable) + ", monitoring: " + str(area.monitoring))
		print("[PlotTile] CollisionPolygon2D points: " + str(collision.polygon.size()))

## Setup Gold Mine animated sprite to fill the isometric tile
## Builds a shared SpriteFrames once (static) and reuses across all PlotTile instances
func _setup_mine_sprite() -> void:
	if _mine_frames == null:
		_mine_frames = SpriteFrames.new()
		# SpriteFrames.new() already provides "default" animation in Godot 4
		_mine_frames.set_animation_loop("default", true)
		_mine_frames.set_animation_speed("default", 24.0)

		for i in range(1, 141):
			var path = "res://assets/sprites/gold_mine_animated/without ground/gold_mine%04d.png" % i
			# Use threaded get if preload was requested, otherwise fall back to sync load
			var texture: Texture2D
			if _preload_started:
				texture = ResourceLoader.load_threaded_get(path)
			else:
				texture = load(path)
			if texture:
				_mine_frames.add_frame("default", texture)

		if OS.is_debug_build():
			print("[PlotTile] Gold Mine frames loaded: %d" % _mine_frames.get_frame_count("default"))

	owner_flag.sprite_frames = _mine_frames

	# Frames are 1920×1080 — scale down to fit the isometric diamond (128×64)
	const FRAME_W: float = 1920.0
	const FRAME_H: float = 1080.0
	var scale_x = Config.ISO_TILE_WIDTH * 1 / FRAME_W
	var scale_y = Config.ISO_TILE_HEIGHT * 1 / FRAME_H
	owner_flag.scale = Vector2.ONE * min(scale_x, scale_y)
	owner_flag.position = Vector2.ZERO
	owner_flag.visible = false

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

## Creates a small hover label showing the plot name on the ground face
func _setup_name_label() -> void:
	name_label = Label.new()
	name_label.z_index = 5
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-35, 22)
	name_label.custom_minimum_size = Vector2(70, 0)
	name_label.add_theme_font_size_override("font_size", 7)
	name_label.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.01, 0.82)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	name_label.add_theme_stylebox_override("normal", style)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	add_child(name_label)

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
			owner_flag.visible = false
			if is_hovered:
				_animate_hover_in()
				if name_label:
					name_label.text = plot_data.plot_name
					name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
					name_label.visible = true
			else:
				_animate_hover_out()
				if name_label:
					name_label.visible = false

		PlotData.OwnerType.NPC:
			is_hovered = false
			modulate = Color(0.6, 0.6, 0.7)
			scale = Vector2.ONE
			var npc_border_color: Color = Config.NPC_COLORS.get(plot_data.owner_name, UITheme.COLOR_DANGER)
			border_line.width = 2.0
			border_line.default_color = npc_border_color
			depth_border_line.width = 2.0
			depth_border_line.default_color = npc_border_color
			owner_flag.visible = true
			owner_flag.modulate = Color.WHITE
			owner_flag.play("default")
			if name_label:
				name_label.text = plot_data.plot_name
				name_label.add_theme_color_override("font_color", Color(0.75, 0.50, 0.50))
				name_label.visible = true

		PlotData.OwnerType.PLAYER:
			is_hovered = false
			modulate = Color(1.1, 1.0, 0.8)
			scale = Vector2.ONE
			border_line.width = 3.0
			border_line.default_color = UITheme.COLOR_GOLD_BRIGHT
			depth_border_line.width = 3.0
			depth_border_line.default_color = UITheme.COLOR_GOLD_BRIGHT
			owner_flag.visible = true
			owner_flag.modulate = Color.WHITE
			owner_flag.play("default")
			if name_label:
				name_label.text = "✓ " + plot_data.plot_name
				name_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
				name_label.visible = true

## Animate tile when mouse hovers over it
func _animate_hover_in() -> void:
	hover_tween = create_tween().set_parallel(true)
	hover_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	hover_tween.tween_property(self, "modulate", Color(1.25, 1.2, 1.1), 0.15)
	border_line.width = 3.0
	border_line.default_color = UITheme.COLOR_GOLD_BRIGHT
	depth_border_line.width = 3.0
	depth_border_line.default_color = UITheme.COLOR_GOLD_BRIGHT

	# Start pulsating border glow
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(border_line, "default_color", UITheme.COLOR_GOLD_PRIMARY, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(border_line, "default_color", UITheme.COLOR_GOLD_BRIGHT, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

## Animate tile back to normal when mouse leaves
func _animate_hover_out() -> void:
	hover_tween = create_tween().set_parallel(true)
	hover_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	hover_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	hover_tween.tween_property(border_line, "width", 1.5, 0.2)
	hover_tween.tween_property(border_line, "default_color", UITheme.COLOR_BORDER_GOLD.darkened(0.5), 0.2)
	hover_tween.tween_property(depth_border_line, "default_color", UITheme.COLOR_BORDER_GOLD.darkened(0.5), 0.2)

func _on_mouse_entered() -> void:
	if plot_data and plot_data.is_biddable():
		is_hovered = true
		hovered.emit(self)
		update_visual_state()

func _on_mouse_exited() -> void:
	is_hovered = false
	update_visual_state()

## Creates the NPC pinpoint panel positioned above the tile
func _setup_npc_pin() -> void:
	npc_pin = PanelContainer.new()
	npc_pin.visible = false
	npc_pin.z_index = 10
	# Center the 130px-wide pin horizontally over the tile's top vertex
	# Tile top vertex is at (0, -ISO_TILE_HEIGHT/2) = (0, -32)
	# Pin sits 8px above that, pinning bottom edge at -40 for a ~30px tall container
	npc_pin.position = Vector2(-65, -float(Config.ISO_TILE_HEIGHT) / 2.0 - 38.0)
	npc_pin.custom_minimum_size = Vector2(130, 30)

	npc_pin_style = StyleBoxFlat.new()
	npc_pin_style.bg_color = Color(UITheme.COLOR_BG_DEEP.r, UITheme.COLOR_BG_DEEP.g, UITheme.COLOR_BG_DEEP.b, 0.90)
	npc_pin_style.border_color = UITheme.COLOR_GOLD_PRIMARY  # updated per-NPC in show_npc_pin()
	npc_pin_style.set_border_width_all(2)
	npc_pin_style.set_corner_radius_all(6)
	npc_pin_style.content_margin_left = 5
	npc_pin_style.content_margin_right = 8
	npc_pin_style.content_margin_top = 4
	npc_pin_style.content_margin_bottom = 4
	npc_pin.add_theme_stylebox_override("panel", npc_pin_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	npc_pin.add_child(hbox)

	# NPC avatar portrait (circle-clipped via shader)
	npc_pin_avatar = TextureRect.new()
	npc_pin_avatar.custom_minimum_size = Vector2(22, 22)
	npc_pin_avatar.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	npc_pin_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	npc_pin_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pin_shader := Shader.new()
	pin_shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tif (length(uv) > 0.5) { discard; }\n\tCOLOR = texture(TEXTURE, UV);\n}"
	var pin_mat := ShaderMaterial.new()
	pin_mat.shader = pin_shader
	npc_pin_avatar.material = pin_mat
	hbox.add_child(npc_pin_avatar)

	# NPC name text
	npc_pin_label = Label.new()
	npc_pin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	npc_pin_label.add_theme_color_override("font_color", UITheme.COLOR_GOLD_BRIGHT)
	npc_pin_label.add_theme_font_size_override("font_size", 11)
	npc_pin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(npc_pin_label)

	add_child(npc_pin)

## Shows the NPC pinpoint marker with an animated pop-in
func show_npc_pin(npc_name: String) -> void:
	npc_pin_label.text = npc_name
	var img_path: String = NPC_IMAGES.get(npc_name, "")
	if img_path:
		var tex := load(img_path) as Texture2D
		if tex:
			npc_pin_avatar.texture = tex
	# Tint border and label with the NPC's personal color
	var npc_color: Color = Config.NPC_COLORS.get(npc_name, UITheme.COLOR_GOLD_PRIMARY)
	npc_pin_style.border_color = npc_color
	npc_pin_label.add_theme_color_override("font_color", npc_color.lightened(0.3))
	npc_pin.visible = true
	npc_pin.scale = Vector2(0.3, 0.3)
	npc_pin.pivot_offset = Vector2(65.0, 15.0)
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
