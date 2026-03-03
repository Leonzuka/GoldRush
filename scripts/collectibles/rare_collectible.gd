extends Area2D

## Rare collectible (Diamond or Relic) that moves toward the player
##
## Spawned by DrillComponent when a rare deposit tile is dug.
## collectible_type and collectible_value must be set before adding to scene.

# ============================================================================
# CONFIGURATION
# ============================================================================

## Types: "diamond" or "relic"
const SPRITE_PATHS: Dictionary = {
	"diamond": "res://assets/sprites/Diomond.png",
	"relic":   "res://assets/sprites/Relic.png",
}

## Outer glow color per type
const GLOW_OUTER: Dictionary = {
	"diamond": Color(0.4, 0.9, 1.0, 0.35),
	"relic":   Color(0.8, 0.3, 1.0, 0.35),
}

## Inner glow color per type
const GLOW_INNER: Dictionary = {
	"diamond": Color(0.7, 0.97, 1.0, 0.55),
	"relic":   Color(0.95, 0.55, 1.0, 0.55),
}

## Display size in pixels (sprite is scaled to this, independent of source resolution)
const DISPLAY_PX: float = 14.0

# ============================================================================
# PROPERTIES
# ============================================================================

var collectible_type: String = "diamond"
var collectible_value: int = 200
var collection_speed: float = 65.0
var player: Node2D = null
var is_collected: bool = false

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Load sprite texture and auto-scale to DISPLAY_PX
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite and SPRITE_PATHS.has(collectible_type):
		sprite.texture = load(SPRITE_PATHS[collectible_type])
		if sprite.texture:
			var tex_size: Vector2 = sprite.texture.get_size()
			sprite.scale = Vector2(DISPLAY_PX / tex_size.x, DISPLAY_PX / tex_size.y)

	# Find player (wait one frame for scene tree to settle)
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

	# Pulsating scale animation — rarer items pulse faster
	var pulse_time: float = 0.35 if collectible_type == "relic" else 0.45
	var tween := create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), pulse_time).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), pulse_time).set_trans(Tween.TRANS_SINE)

# ============================================================================
# MOVEMENT
# ============================================================================

func _process(delta: float) -> void:
	if is_collected or not player:
		return

	var direction: Vector2 = (player.global_position - global_position).normalized()
	global_position += direction * collection_speed * delta
	queue_redraw()

# ============================================================================
# COLLECTION
# ============================================================================

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body.is_in_group("player"):
		collect()

func collect() -> void:
	is_collected = true
	EventBus.rare_collected.emit(collectible_type, collectible_value)

	# Pop-and-shrink animation before freeing
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.07).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func _draw() -> void:
	var outer: Color = GLOW_OUTER.get(collectible_type, Color(1, 1, 1, 0.3))
	var inner: Color = GLOW_INNER.get(collectible_type, Color(1, 1, 1, 0.5))
	draw_circle(Vector2.ZERO, 13.0, outer)
	draw_circle(Vector2.ZERO, 8.0, inner)
