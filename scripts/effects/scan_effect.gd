extends Node2D
class_name ScanEffect

## Visual effect for scanner - expanding circle that fades out

var radius: float = 0.0
var max_radius: float = 80.0
var expand_speed: float = 160.0

func _process(delta: float) -> void:
	radius += expand_speed * delta
	if radius >= max_radius:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var alpha: float = 1.0 - (radius / max_radius)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.2, 0.8, 1.0, alpha * 0.6), 3.0)
