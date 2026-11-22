class_name SpaceBurst
extends Node2D

var color := Color.WHITE
var size := 10.0
var duration := 0.7

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
	var r := size * (0.6 + p * 3.4)
	var a := 1.0 - p
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color.r, color.g, color.b, a * 0.9), 1.0 + (1.0 - p) * 4.0, true)
	draw_circle(Vector2.ZERO, size * 0.9 * (1.0 - p), Color(color.r, color.g, color.b, a * 0.5))
