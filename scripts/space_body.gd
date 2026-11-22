class_name SpaceBody
extends Node2D

var mass := 1.0
var radius := 6.0
var velocity := Vector2.ZERO
var color := Color.WHITE
var body_name := "Объект"
var is_star := false
var is_black_hole := false
var is_fragment := false
var is_dwarf := false
var selected := false
var tidal_immune := 0.0
var ring_inner_ratio := 0.0
var ring_outer_ratio := 0.0
var ring_color := Color(0.9, 0.85, 0.7, 0.5)
var ring_tilt := 0.0
var trail := PackedVector2Array()
var scripted := false
var collides_scripted := false
var orbit_parent = null
var orbit_center := Vector2.ZERO
var orbit_radius := 0.0
var orbit_eccentricity := 0.0
var orbit_periapsis := 0.0
var orbit_angle := 0.0
var orbit_speed := 0.0


func _ready() -> void:
	z_index = 2
	queue_redraw()


func _draw() -> void:
	if not is_star and ring_outer_ratio > 0.0:
		_draw_rings()
	if is_black_hole:
		var glow := Color(1.0, 0.62, 0.30)
		draw_circle(Vector2.ZERO, radius * 3.2, Color(glow.r, glow.g, glow.b, 0.05))
		draw_circle(Vector2.ZERO, radius * 2.2, Color(glow.r, glow.g, glow.b, 0.10))
		draw_arc(Vector2.ZERO, radius * 1.75, 0.0, TAU, 56, Color(glow.r, glow.g, glow.b, 0.30), maxf(1.0, radius * 0.10), true)
		draw_arc(Vector2.ZERO, radius * 1.32, 0.0, TAU, 56, Color(glow.r, glow.g, glow.b, 0.78), maxf(1.5, radius * 0.20), true)
		draw_circle(Vector2.ZERO, radius, Color(0.012, 0.010, 0.018))
		draw_arc(Vector2.ZERO, radius * 1.03, 0.0, TAU, 48, Color(1.0, 0.90, 0.70, 0.95), maxf(1.0, radius * 0.07), true)
	elif is_star:
		draw_circle(Vector2.ZERO, radius * 3.0, Color(color.r, color.g, color.b, 0.05))
		draw_circle(Vector2.ZERO, radius * 2.0, Color(color.r, color.g, color.b, 0.10))
		draw_circle(Vector2.ZERO, radius * 1.45, Color(color.r, color.g, color.b, 0.20))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2(-radius * 0.28, -radius * 0.28), radius * 0.55, color.lightened(0.22))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, color.lightened(0.38), maxf(1.0, radius * 0.09), true)
	else:
		draw_circle(Vector2.ZERO, radius * 2.1, Color(color.r, color.g, color.b, 0.10))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2(-radius * 0.28, -radius * 0.28), radius * 0.55, color.lightened(0.22))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, color.lightened(0.38), maxf(1.0, radius * 0.09), true)

	if selected:
		draw_arc(Vector2.ZERO, radius * 1.75, 0.0, TAU, 48, Color(0.75, 0.9, 1.0, 0.95), maxf(1.5, radius * 0.07), true)


func _draw_rings() -> void:
	var segments := 80
	var inner := radius * ring_inner_ratio
	var outer := radius * ring_outer_ratio
	var squash := 0.30
	var bands := 6
	for k in bands:
		var f := float(k) / float(bands - 1)
		var rr := lerpf(inner, outer, f)
		var alpha := ring_color.a * (0.45 + 0.55 * sin(f * PI))
		var pts := PackedVector2Array()
		for i in segments + 1:
			var t := TAU * float(i) / float(segments)
			pts.append(Vector2(cos(t) * rr, sin(t) * rr * squash).rotated(ring_tilt))
		draw_polyline(pts, Color(ring_color.r, ring_color.g, ring_color.b, alpha), maxf(1.0, radius * 0.09), true)
