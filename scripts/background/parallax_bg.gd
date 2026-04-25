extends ParallaxBackground
class_name ParallaxBg

## Sky parallax background for mining scene.
## Picks a background set based on the plot's terrain_seed so each plot
## always shows the same landscape — but different plots look different.

const BG_ROOT := "res://assets/Pixel-Art-Backgrounds/PNG/"
# Keep folder names exactly as they appear on disk
const BG_SETS: Array[String] = [
	"summer 1", "summer 2", "summer 3", "summer 4",
	"summer5",  "summer6",  "summer7",  "summer8",
]
# summer6 has 5 layers; all others have 4
const SETS_WITH_5_LAYERS := ["summer6"]

# Horizontal parallax per layer (x) — y=0 means sky stays fixed vertically
const MOTION_SCALES: Array[Vector2] = [
	Vector2(0.0,  0.0),
	Vector2(0.10, 0.0),
	Vector2(0.24, 0.0),
	Vector2(0.44, 0.0),
	Vector2(0.70, 0.0),
]

# Screen size the backgrounds are designed for
const SCREEN_W := 1280.0
const SCREEN_H := 720.0
# Native layer image size
const IMG_W := 576.0
const IMG_H := 324.0

func _ready() -> void:
	layer = -1  # Render behind world layer
	EventBus.mining_started.connect(_on_mining_started)

func _on_mining_started(plot_data) -> void:
	_clear_layers()
	var set_index: int = plot_data.terrain_seed % BG_SETS.size()
	_build_background(BG_SETS[set_index])

func _clear_layers() -> void:
	for child in get_children():
		child.queue_free()

func _build_background(set_name: String) -> void:
	var count: int = 5 if set_name in SETS_WITH_5_LAYERS else 4
	for i in range(count):
		var path := "%s%s/%d.png" % [BG_ROOT, set_name, i + 1]
		var tex := load(path) as Texture2D
		if not tex:
			push_warning("[ParallaxBg] Could not load: %s" % path)
			continue
		_add_layer(tex, MOTION_SCALES[mini(i, MOTION_SCALES.size() - 1)])

func _add_layer(tex: Texture2D, motion: Vector2) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = motion
	# Tile the layer every screen-width so it wraps seamlessly as camera scrolls
	pl.motion_mirroring = Vector2(SCREEN_W, 0.0)

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(SCREEN_W / IMG_W, SCREEN_H / IMG_H)  # 2.222... fills 1280×720

	pl.add_child(spr)
	add_child(pl)
