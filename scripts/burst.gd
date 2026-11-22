class_name SpaceBurst
extends Node2D

var color := Color.WHITE
var size := 10.0
var duration := 0.7
var kind := "ring"

var _t := 0.0


func _ready() -> void:
	z_index = 3


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / duration, 0.0, 1.0)
	var a := 1.0 - p
	match kind:
		"supernova":
			var r := size * (0.8 + p * 7.0)
			draw_circle(Vector2.ZERO, size * (1.4 - p * 0.6), Color(1.0, 0.95, 0.85, a * 0.45))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1.0, 0.75, 0.35, a * 0.95), 2.0 + (1.0 - p) * 8.0, true)
			draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 64, Color(1.0, 0.45, 0.2, a * 0.7), 1.5 + (1.0 - p) * 5.0, true)
			draw_arc(Vector2.ZERO, r * 1.18, 0.0, TAU, 64, Color(1.0, 0.9, 0.7, a * 0.35), 1.0 + (1.0 - p) * 3.0, true)
		_:
			var r := size * (0.6 + p * 3.4)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color.r, color.g, color.b, a * 0.9), 1.0 + (1.0 - p) * 4.0, true)
			draw_circle(Vector2.ZERO, size * 0.9 * (1.0 - p), Color(color.r, color.g, color.b, a * 0.5))
