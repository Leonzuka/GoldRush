extends Node2D
class_name DrillOverlay

## Draws progressive branching crack lines over a tile being drilled.
##
## Position via refresh() — do not move this node manually.
## progress 0.0 → invisible, 1.0 → fully cracked.

var progress: float = 0.0
var active: bool = false

const _H: float = Config.TILE_SIZE / 2.0  # half-tile = 8 px

# ─────────────────────────────────────────────────────────────────────────────
# Crack paths: each entry is an Array[Vector2] polyline in local tile coords.
# Origin (0,0) = tile center.  Range roughly -H..H.
#
# Group A  → visible at progress >= 0.30   (main crack + two branches)
# Group B  → visible at progress >= 0.62   (counter-crack + branch)
# Group C  → visible at progress >= 0.82   (thin finishing crack)
# ─────────────────────────────────────────────────────────────────────────────

# Group A — main branching crack (upper-right)
const _A0: Array = [Vector2(0,  1), Vector2( 2, -1), Vector2( 5, -3), Vector2( 7, -5)]
const _A1: Array = [Vector2( 2, -1), Vector2( 4,  1), Vector2( 6,  3)]  # branch down
const _A2: Array = [Vector2(0,  1), Vector2(-1,  4), Vector2(-2,  7)]   # tail downward

# Group B — counter crack (lower-left)
const _B0: Array = [Vector2(-1,  0), Vector2(-3, -2), Vector2(-5,  0), Vector2(-6,  3)]
const _B1: Array = [Vector2(-3, -2), Vector2(-2, -5)]  # branch up

# Group C — thin diagonal
const _C0: Array = [Vector2( 1, -1), Vector2( 3, -4), Vector2( 2, -7)]

const _CRACK_COLOR: Color    = Color(0.06, 0.03, 0.0, 0.92)
const _HIGHLIGHT_COLOR: Color = Color(0.9,  0.85, 0.7, 0.30)
const _LINE_WIDTH: float     = 1.6

# ─────────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not active or progress <= 0.0:
		return

	# ── Vignette: dark rectangle that grows with progress ──────────────────
	var rect := Rect2(-_H, -_H, Config.TILE_SIZE, Config.TILE_SIZE)
	draw_rect(rect, Color(0.0, 0.0, 0.0, progress * 0.38))

	# ── Group A ─────────────────────────────────────────────────────────────
	if progress >= 0.30:
		var t: float = _ease_in((progress - 0.30) / 0.32)
		_draw_path(_A0, t)
		_draw_path(_A1, t * 0.85)  # branch slightly delayed
		_draw_path(_A2, t * 0.70)

	# ── Group B ─────────────────────────────────────────────────────────────
	if progress >= 0.62:
		var t: float = _ease_in((progress - 0.62) / 0.20)
		_draw_path(_B0, t)
		_draw_path(_B1, t * 0.80)

	# ── Group C ─────────────────────────────────────────────────────────────
	if progress >= 0.82:
		var t: float = _ease_in((progress - 0.82) / 0.18)
		_draw_path(_C0, t)

## Draw a polyline animated from start to end based on t (0→1).
## Also draws a thin lighter line alongside for a chipped-stone look.
func _draw_path(pts: Array, t: float) -> void:
	if t <= 0.0 or pts.size() < 2:
		return

	# Total length for progress interpolation
	var segments: int = pts.size() - 1
	var total_t_per_seg: float = 1.0 / float(segments)

	for i in segments:
		var seg_start_t: float = i * total_t_per_seg

		if t <= seg_start_t:
			break  # haven't reached this segment yet

		var local_t: float = clampf((t - seg_start_t) / total_t_per_seg, 0.0, 1.0)
		var from_pt: Vector2 = pts[i]
		var to_pt:   Vector2 = (pts[i] as Vector2).lerp(pts[i + 1], local_t)

		# Main crack line (dark)
		draw_line(from_pt, to_pt, _CRACK_COLOR, _LINE_WIDTH, true)

		# Highlight offset (simulates raised edge on one side of the crack)
		var perp: Vector2 = (to_pt - from_pt).normalized().rotated(PI * 0.5)
		draw_line(from_pt + perp, to_pt + perp, _HIGHLIGHT_COLOR, 1.0, true)

## Quadratic ease-in so cracks "snap" in quickly
func _ease_in(t: float) -> float:
	return t * t

## Called every frame from DrillComponent
func refresh(new_progress: float, world_pos: Vector2, is_active: bool) -> void:
	active    = is_active
	progress  = new_progress
	if is_active:
		global_position = world_pos
	queue_redraw()
