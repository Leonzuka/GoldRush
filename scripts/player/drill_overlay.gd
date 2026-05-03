extends Node2D
class_name DrillOverlay

## Draws progressive impact-style crack lines over a tile being drilled.
##
## Cracks always originate at the tile center and radiate outward, so the
## block reads as fracturing from a strike point rather than being sliced.
## All template points stay within ±_MAX_RADIUS so the crack never bleeds
## outside the tile. Position via refresh() — do not move this node manually.
## progress 0.0 → invisible, 1.0 → fully cracked.

var progress: float = 0.0
var active: bool = false

const _H: float = Config.TILE_SIZE / 2.0   # half-tile (16 px @ TILE_SIZE 32)
# Radial clamp — every crack point must fit inside a circle of this radius so
# free rotation can never push it outside the tile. Margin (_H - radius = 3px)
# absorbs line width/2 (~0.8) + AA fringe (~0.5) + perp highlight offset (0.6).
const _MAX_RADIUS: float = _H - 3.0

# ─────────────────────────────────────────────────────────────────────────────
# Crack variants — each is an array of polylines. EVERY polyline must start
# at (0,0) (impact origin) so the fracture radiates outward from center.
# Sub-branches are added at runtime as splinters off existing arms.
# Coordinates must stay within ±_MAX_RADIUS.
# ─────────────────────────────────────────────────────────────────────────────

const _VARIANTS: Array = [
	# 0 — Three arms, asymmetric splay
	[
		[Vector2(0, 0), Vector2( 4, -3), Vector2( 8, -6), Vector2(10, -8)],
		[Vector2(0, 0), Vector2(-5,  2), Vector2(-9,  5), Vector2(-11, 6)],
		[Vector2(0, 0), Vector2( 2,  5), Vector2( 5, 11)],
	],
	# 1 — Four-arm star, slightly skewed
	[
		[Vector2(0, 0), Vector2( 5, -4), Vector2( 8, -9)],
		[Vector2(0, 0), Vector2(-6, -3), Vector2(-10, -5)],
		[Vector2(0, 0), Vector2( 3,  6), Vector2( 6, 10)],
		[Vector2(0, 0), Vector2(-4,  5), Vector2(-7,  9)],
	],
	# 2 — Diagonal split: two arms on one axis + a kicker
	[
		[Vector2(0, 0), Vector2( 5,  4), Vector2( 8,  7), Vector2( 9,  9)],
		[Vector2(0, 0), Vector2(-5, -4), Vector2(-8, -7), Vector2(-9, -9)],
		[Vector2(0, 0), Vector2( 4, -5), Vector2( 6, -9)],
	],
	# 3 — Y-fork radiating
	[
		[Vector2(0, 0), Vector2(-1, -6), Vector2( 1, -12)],
		[Vector2(0, 0), Vector2( 6,  4), Vector2( 9,  7)],
		[Vector2(0, 0), Vector2(-7,  4), Vector2(-10, 7)],
	],
	# 4 — T-cross (cardinal radiation)
	[
		[Vector2(0, 0), Vector2( 6,  0), Vector2(12,  1)],
		[Vector2(0, 0), Vector2(-6,  1), Vector2(-12, 0)],
		[Vector2(0, 0), Vector2( 1, -6), Vector2( 0, -12)],
	],
	# 5 — Five-arm spider
	[
		[Vector2(0, 0), Vector2( 4, -4), Vector2( 7, -9)],
		[Vector2(0, 0), Vector2(-5, -2), Vector2(-11, -4)],
		[Vector2(0, 0), Vector2( 5,  3), Vector2( 9,  6)],
		[Vector2(0, 0), Vector2(-3,  6), Vector2(-6, 10)],
		[Vector2(0, 0), Vector2( 1, -5), Vector2( 3, -11)],
	],
	# 6 — Curved arms
	[
		[Vector2(0, 0), Vector2( 3, -3), Vector2( 8, -3), Vector2(10, -6)],
		[Vector2(0, 0), Vector2(-3,  2), Vector2(-7,  5), Vector2(-9,  8)],
		[Vector2(0, 0), Vector2( 2,  4), Vector2( 0,  9), Vector2( 4, 12)],
	],
]

# ─────────────────────────────────────────────────────────────────────────────
# Per-tile randomized state — regenerated on each new tile
# ─────────────────────────────────────────────────────────────────────────────

var _arms: Array = []                  # Main paths radiating from origin
var _splinters: Array = []             # Late short branches off arms
var _arm_thresholds: Array[float] = [] # Threshold per arm (when it appears)
var _splinter_thresholds: Array[float] = []
var _line_width: float = 1.4
var _crack_rotation: float = 0.0
var _flip_x: bool = false
var _flip_y: bool = false

var _rng := RandomNumberGenerator.new()
var _last_active_pos: Vector2 = Vector2.INF

const _CRACK_COLOR: Color     = Color(0.04, 0.02, 0.0, 0.92)
const _HIGHLIGHT_COLOR: Color = Color(0.95, 0.88, 0.7, 0.22)

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_rng.randomize()
	_generate_crack_variant()

## Generates a new randomized crack variant for the current tile.
func _generate_crack_variant() -> void:
	_crack_rotation = _rng.randf_range(0.0, TAU)
	_flip_x = _rng.randf() < 0.5
	_flip_y = _rng.randf() < 0.5

	var variant_idx: int = _rng.randi_range(0, _VARIANTS.size() - 1)
	var template: Array = _VARIANTS[variant_idx]
	var jitter: float = 0.9

	# Build main arms (always start at 0,0 — origin is never jittered)
	_arms = []
	for path: Array in template:
		_arms.append(_jitter_path(path, jitter))

	# Stagger arm reveal: first arm appears almost immediately, last around 60%
	_arm_thresholds = []
	var n: int = _arms.size()
	var denom: float = max(1.0, float(n - 1))
	for i in n:
		var base: float = lerpf(0.05, 0.55, float(i) / denom)
		_arm_thresholds.append(clampf(base + _rng.randf_range(-0.03, 0.03), 0.0, 0.9))

	# Add 1–3 short splinters near the end of random arms (late-stage chipping)
	_splinters = []
	_splinter_thresholds = []
	var splinter_count: int = _rng.randi_range(1, 3)
	for s in splinter_count:
		var arm: Array = _arms[_rng.randi_range(0, _arms.size() - 1)]
		if arm.size() < 2:
			continue
		# Anchor the splinter at a mid-to-far point on the arm
		var anchor_idx: int = _rng.randi_range(max(1, arm.size() - 2), arm.size() - 1)
		var anchor: Vector2 = arm[anchor_idx]
		var prev: Vector2 = arm[anchor_idx - 1]
		var dir: Vector2 = (anchor - prev)
		if dir.length_squared() < 0.0001:
			continue
		var off_dir: Vector2 = dir.normalized().rotated(_rng.randf_range(0.6, 1.2) * (1.0 if _rng.randf() < 0.5 else -1.0))
		var tip: Vector2 = anchor + off_dir * _rng.randf_range(2.5, 5.0)
		tip = _radial_clamp(tip)
		_splinters.append([anchor, tip])
		_splinter_thresholds.append(_rng.randf_range(0.65, 0.88))

	_line_width = _rng.randf_range(1.1, 1.6)

func _jitter_path(base: Array, amount: float) -> Array:
	var sx: float = -1.0 if _flip_x else 1.0
	var sy: float = -1.0 if _flip_y else 1.0
	var result: Array = []
	for i in base.size():
		var pt: Vector2 = base[i]
		var jittered: Vector2
		if i == 0:
			# Origin is never jittered — keeps the impact point exact
			jittered = pt
		else:
			jittered = Vector2(
				pt.x * sx + _rng.randf_range(-amount, amount),
				pt.y * sy + _rng.randf_range(-amount, amount)
			)
			jittered = _radial_clamp(jittered)
		result.append(jittered)
	return result

## Radial clamp — keeps the point inside a circle of _MAX_RADIUS regardless
## of free rotation, so cracks can't bleed past the tile edge.
func _radial_clamp(p: Vector2) -> Vector2:
	var len_sq: float = p.length_squared()
	if len_sq <= _MAX_RADIUS * _MAX_RADIUS:
		return p
	return p * (_MAX_RADIUS / sqrt(len_sq))

# ─────────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not active or progress <= 0.0:
		return

	# Vignette drawn in tile space (no rotation — covers the full square)
	var rect := Rect2(-_H, -_H, Config.TILE_SIZE, Config.TILE_SIZE)
	draw_rect(rect, Color(0.0, 0.0, 0.0, progress * 0.38))

	# Apply per-tile rotation for all crack drawing
	draw_set_transform(Vector2.ZERO, _crack_rotation)

	# Main radiating arms
	for i in _arms.size():
		var thresh: float = _arm_thresholds[i]
		if progress < thresh:
			continue
		var span: float = clampf(0.55 - thresh * 0.4, 0.18, 0.55)
		var t: float = _ease_out(clampf((progress - thresh) / span, 0.0, 1.0))
		_draw_path(_arms[i], t, _line_width)

	# Late splinters
	for i in _splinters.size():
		var thresh: float = _splinter_thresholds[i]
		if progress < thresh:
			continue
		var t: float = _ease_out(clampf((progress - thresh) / 0.18, 0.0, 1.0))
		_draw_path(_splinters[i], t, _line_width * 0.75)

	# Impact dot at the origin — small dark speck that grows slightly
	var dot_radius: float = lerpf(0.6, 1.4, clampf(progress, 0.0, 1.0))
	draw_circle(Vector2.ZERO, dot_radius, _CRACK_COLOR)

	draw_set_transform(Vector2.ZERO)

## Draw a polyline animated from start to end based on t (0→1).
## Also draws a thin lighter line alongside for a chipped-stone look.
func _draw_path(pts: Array, t: float, width: float) -> void:
	if t <= 0.0 or pts.size() < 2:
		return

	var segments: int = pts.size() - 1
	var total_t_per_seg: float = 1.0 / float(segments)

	for i in segments:
		var seg_start_t: float = i * total_t_per_seg
		if t <= seg_start_t:
			break

		var local_t: float = clampf((t - seg_start_t) / total_t_per_seg, 0.0, 1.0)
		var from_pt: Vector2 = pts[i]
		var to_pt: Vector2   = (pts[i] as Vector2).lerp(pts[i + 1], local_t)

		# Taper: segments closer to origin are slightly wider than the tip
		var taper: float = lerpf(1.0, 0.65, float(i) / float(segments))
		draw_line(from_pt, to_pt, _CRACK_COLOR, width * taper, true)

		var dir: Vector2 = to_pt - from_pt
		if dir.length_squared() > 0.0001:
			var perp: Vector2 = dir.normalized().rotated(PI * 0.5) * 0.6
			draw_line(from_pt + perp, to_pt + perp, _HIGHLIGHT_COLOR, 0.5, true)

## Quadratic ease-out so cracks shoot out fast and settle
func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

## Called every frame from DrillComponent
func refresh(new_progress: float, world_pos: Vector2, is_active: bool) -> void:
	# Regenerate crack variant when drilling starts on a new tile
	if is_active and world_pos != _last_active_pos:
		_generate_crack_variant()
		_last_active_pos = world_pos
	elif not is_active:
		_last_active_pos = Vector2.INF

	active   = is_active
	progress = new_progress
	if is_active:
		global_position = world_pos
	queue_redraw()
