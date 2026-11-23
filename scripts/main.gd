extends Node2D

const G := 1.0
const SOFTENING := 12.0
const MIN_ZOOM := 0.07
const MAX_ZOOM := 2.6
const TRAIL_MAX := 240
const TRAIL_INTERVAL := 0.055
const MAX_FRAGMENT_BODIES := 90
const STAR_MASS := 500000.0
const BLACK_HOLE_MASS := 12000000.0
const SYSTEMS := preload("res://scripts/systems.gd")

var SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0, 8.0]

var PALETTE := [
	Color(0.55, 0.78, 1.0),
	Color(1.0, 0.62, 0.4),
	Color(0.62, 0.9, 0.72),
	Color(0.95, 0.85, 0.55),
	Color(0.82, 0.66, 1.0),
	Color(1.0, 0.55, 0.68),
	Color(0.55, 0.92, 0.95),
	Color(0.95, 0.95, 0.9),
]

var STAR_PALETTE := [
	Color(1.0, 0.78, 0.3),
	Color(1.0, 0.58, 0.26),
	Color(1.0, 0.95, 0.72),
	Color(0.68, 0.84, 1.0),
	Color(0.92, 0.72, 1.0),
]

@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var hud = $UI
@onready var music = $SpaceMusic

var bodies: Array[SpaceBody] = []
var speed_index := 2
var paused := false
var spawn_mode := false
var spawn_kind := "planet"
var selected: SpaceBody = null
var current_preset := "solar"
var collisions_enabled := true
var following := false
var show_barycenter := true
var satellite_distance := 24.0
var orbit_eccentricity := 0.0
var visual_mode := "tail"

var _rng := RandomNumberGenerator.new()
var _trail_timer := 0.0
var _hud_timer := 0.0
var _cooling_tweens: Array[Tween] = []

var _touches: Dictionary = {}
var _single_id := -1
var _single_start := Vector2.ZERO
var _single_moved := 0.0
var _panning := false
var _aiming := false
var _aim_start := Vector2.ZERO
var _aim_end := Vector2.ZERO
var _pinching := false
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO
var _pinch_pending := false
var _pinch_start_dist := 0.0
var _pinch_start_mid := Vector2.ZERO

var _mouse_down := false


func _ready() -> void:
	_rng.randomize()
	camera.make_current()
	camera.zoom = Vector2(0.8, 0.8)
	hud.action.connect(_on_action)
	visual_mode = hud.initial_visual_mode()
	satellite_distance = hud.initial_satellite_distance()
	orbit_eccentricity = hud.initial_orbit_eccentricity()
	show_barycenter = hud.initial_barycenter()
	music.set_enabled(hud.initial_music_enabled())
	hud.show_hint("Коснитесь объекта — откроется редактор · «Тело» — создать объект")
	load_preset("solar")
	_refresh_hud()


func _process(delta: float) -> void:
	if not paused:
		_simulate(delta * SPEEDS[speed_index])
		_record_trails(delta)
		_cleanup_far_bodies()

	if following:
		if selected != null and is_instance_valid(selected):
			camera.position = selected.position
		else:
			following = false

	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.2
		_refresh_hud()

	queue_redraw()


func _draw() -> void:
	for b in bodies:
		if b.is_fragment and visual_mode != "orbit":
			continue
		if visual_mode == "tail" and b.trail.size() > 1:
			var screen_w: float = clampf(b.radius * 0.16 * camera.zoom.x, 1.2, 3.0)
			draw_polyline(b.trail, Color(b.color.r, b.color.g, b.color.b, 0.30), screen_w / camera.zoom.x, true)
		elif visual_mode == "orbit":
			_draw_orbit(b)

	if show_barycenter:
		_draw_barycenter()

	if _aiming:
		var invz: float = 1.0 / camera.zoom.x
		var c := Color(0.62, 0.86, 1.0, 0.95)
		draw_line(_aim_start, _aim_end, c, 3.0 * invz, true)
		draw_circle(_aim_start, 12.0 * invz, Color(0.62, 0.86, 1.0, 0.22))
		draw_circle(_aim_start, 5.0 * invz, Color(0.9, 0.97, 1.0, 0.9))
		var d := _aim_end - _aim_start
		if d.length() > 6.0:
			var n := d.normalized()
			var tip := _aim_end
			draw_line(tip, tip - n.rotated(0.5) * 24.0 * invz, c, 3.0 * invz, true)
			draw_line(tip, tip - n.rotated(-0.5) * 24.0 * invz, c, 3.0 * invz, true)


func _draw_orbit(b: SpaceBody) -> void:
	var orbit := _orbit_center_for(b)
	var center: Vector2 = orbit["center"]
	var radius: float = orbit["radius"]
	if radius <= 0.0:
		return
	var c := Color(b.color.r, b.color.g, b.color.b, 0.38 if not b.is_star else 0.28)
	var width: float = maxf(1.0, 1.4 / camera.zoom.x)
	if b.scripted:
		# Звёзды в барицентре рисуем по реальной траектории, а не кругом
		if b.is_star and b.orbit_parent == null and b.trail.size() > 1:
			draw_polyline(b.trail, c, width, true)
			return
		var ecc: float = clampf(b.orbit_eccentricity, 0.0, 0.95)
		if ecc > 0.0001:
			var a: float = radius
			var minor: float = a * sqrt(maxf(0.0, 1.0 - ecc * ecc))
			var peri := Vector2(cos(b.orbit_periapsis), sin(b.orbit_periapsis))
			var ec: Vector2 = center - peri * (a * ecc)
			draw_polyline(_ellipse_points(ec, a, minor, b.orbit_periapsis), c, width, true)
		else:
			draw_arc(center, radius, 0.0, TAU, 128, c, width, true)
		return
	if b.is_star and bool(orbit.get("barycentric", false)):
		if b.trail.size() > 1:
			draw_polyline(b.trail, c, width, true)
		else:
			draw_arc(center, radius, 0.0, TAU, 128, c, width, true)
		return
	var ellipse := _orbit_ellipse_for(b, orbit)
	if not bool(ellipse.get("valid", false)):
		draw_arc(center, radius, 0.0, TAU, 128, c, width, true)
		return
	draw_polyline(_ellipse_points(ellipse["center"], float(ellipse["a"]), float(ellipse["b"]), float(ellipse["angle"])), c, width, true)


func _ellipse_points(center: Vector2, a: float, minor: float, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segments := 96
	for i in segments:
		var t := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(t) * a, sin(t) * minor).rotated(angle))
	pts.append(pts[0])
	return pts


func _orbit_ellipse_for(b: SpaceBody, orbit: Dictionary) -> Dictionary:
	if b.scripted:
		return {}
	var mass: float = float(orbit.get("mass", 0.0))
	if mass <= 0.0:
		return {}
	var focus: Vector2 = orbit["center"]
	var r_vec: Vector2 = b.position - focus
	var r_len: float = r_vec.length()
	if r_len <= 0.001:
		return {}
	var focus_vel: Vector2 = orbit["velocity"]
	var v_vec: Vector2 = b.velocity - focus_vel
	var r_eff: float = sqrt(r_len * r_len + SOFTENING)
	var mu: float = G * mass
	var v2: float = v_vec.length_squared()
	var energy: float = 0.5 * v2 - mu / r_eff
	if energy >= -0.000001:
		return {}
	var a: float = -mu / (2.0 * energy)
	if a <= 0.0 or a > 1000000.0:
		return {}
	var rv: float = r_vec.dot(v_vec)
	var evec: Vector2 = ((v2 - mu / r_eff) * r_vec - rv * v_vec) / mu
	var e: float = evec.length()
	if e < 0.0001 or e >= 1.0:
		return {}
	var minor: float = a * sqrt(maxf(0.0, 1.0 - e * e))
	var edir: Vector2 = evec / e
	var ec: Vector2 = focus - edir * (a * e)
	return {"valid": true, "center": ec, "a": a, "b": minor, "angle": edir.angle(), "e": e}


func _orbit_center_for(b: SpaceBody) -> Dictionary:
	if b.orbit_parent != null and is_instance_valid(b.orbit_parent):
		return {
			"center": b.orbit_parent.position,
			"velocity": b.orbit_parent.velocity,
			"mass": b.orbit_parent.mass,
			"radius": b.orbit_radius,
			"barycentric": false,
		}
	var bary := _star_barycenter()
	var bary_center: Vector2 = bary["center"]
	var bary_vel: Vector2 = bary["velocity"]
	var bary_mass: float = float(bary["mass"])
	var bary_count: int = int(bary["count"])
	if b.is_star:
		if bary_count >= 2 and b.orbit_radius > 0.0:
			return {
				"center": bary_center,
				"velocity": bary_vel,
				"mass": bary_mass,
				"radius": b.orbit_radius,
				"barycentric": true,
			}
		if bary_count >= 2:
			return {
				"center": bary_center,
				"velocity": bary_vel,
				"mass": bary_mass,
				"radius": b.position.distance_to(bary_center),
				"barycentric": true,
			}
		return {
			"center": Vector2.ZERO,
			"velocity": Vector2.ZERO,
			"mass": 0.0,
			"radius": 0.0,
			"barycentric": false,
		}
	if bary_count >= 2:
		return {
			"center": bary_center,
			"velocity": bary_vel,
			"mass": bary_mass,
			"radius": b.position.distance_to(bary_center),
		}
	var star := _nearest_star(b)
	if star != null:
		return {
			"center": star.position,
			"velocity": star.velocity,
			"mass": star.mass,
			"radius": b.position.distance_to(star.position),
			"barycentric": false,
		}
	return {
		"center": Vector2.ZERO,
		"velocity": Vector2.ZERO,
		"mass": 0.0,
		"radius": 0.0,
		"barycentric": false,
	}


func _draw_barycenter() -> void:
	var bary := _star_barycenter()
	if int(bary["count"]) < 2:
		return
	var center: Vector2 = bary["center"]
	var invz: float = 1.0 / camera.zoom.x
	var c := Color(1.0, 0.86, 0.58, 0.85)
	draw_circle(center, 3.0 * invz, c)
	draw_line(center - Vector2(10.0, 0.0) * invz, center + Vector2(10.0, 0.0) * invz, c, 1.2 * invz, true)
	draw_line(center - Vector2(0.0, 10.0) * invz, center + Vector2(0.0, 10.0) * invz, c, 1.2 * invz, true)
	draw_arc(center, 8.0 * invz, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.45), 1.2 * invz, true)
	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, center + Vector2(14.0, -12.0) * invz, "Барицентр", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, int(13.0 * invz)), c)


func _star_barycenter() -> Dictionary:
	var center := Vector2.ZERO
	var vel := Vector2.ZERO
	var total := 0.0
	var count := 0
	for s in bodies:
		if s.is_star and not s.scripted:
			center += s.position * s.mass
			vel += s.velocity * s.mass
			total += s.mass
			count += 1
	if total <= 0.0:
		return {"center": Vector2.ZERO, "velocity": Vector2.ZERO, "mass": 0.0, "count": 0}
	return {"center": center / total, "velocity": vel / total, "mass": total, "count": count}


func _nearest_star(b: SpaceBody) -> SpaceBody:
	var best: SpaceBody = null
	var best_d := INF
	for s in bodies:
		if s == b or not s.is_star:
			continue
		var d := b.position.distance_squared_to(s.position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _simulate(dt: float) -> void:
	if dt <= 0.0 or bodies.size() < 2:
		return
	for b in bodies:
		if b.tidal_immune > 0.0:
			b.tidal_immune = maxf(0.0, b.tidal_immune - dt)
	var n := bodies.size()
	var max_steps := 26
	if n > 120:
		max_steps = 6
	elif n > 70:
		max_steps = 10
	elif n > 40:
		max_steps = 16
	var steps: int = clampi(int(ceil(dt / 0.009)), 1, max_steps)
	var h: float = dt / float(steps)
	for s in steps:
		_step(h)
		_update_scripted(h)
		_resolve_collisions()
	_check_disruptions()


func _update_scripted(dt: float) -> void:
	var ab_center := Vector2.ZERO
	var ab_vel := Vector2.ZERO
	var ab_mass := 0.0
	for s in bodies:
		if s.is_star and not s.scripted:
			ab_center += s.position * s.mass
			ab_vel += s.velocity * s.mass
			ab_mass += s.mass
	if ab_mass > 0.0:
		ab_center /= ab_mass
		ab_vel /= ab_mass
	for b in bodies:
		if not b.scripted:
			continue
		b.orbit_angle = fmod(b.orbit_angle + b.orbit_speed * dt, TAU)
		var center := b.orbit_center
		var base_vel := Vector2.ZERO
		if b.orbit_parent != null:
			if not is_instance_valid(b.orbit_parent):
				continue
			center = b.orbit_parent.position
			base_vel = b.orbit_parent.velocity
		elif ab_mass > 0.0:
			center = ab_center
			base_vel = ab_vel
		var state := _scripted_orbit_state(b.orbit_radius, b.orbit_eccentricity, b.orbit_periapsis, b.orbit_angle, b.orbit_speed)
		var rel_pos: Vector2 = state["pos"]
		var rel_vel: Vector2 = state["vel"]
		b.position = center + rel_pos
		b.velocity = base_vel + rel_vel


func _eccentric_anomaly(mean_anomaly: float, e: float) -> float:
	var mean := fposmod(mean_anomaly, TAU)
	var E := mean + e * sin(mean)
	for i in 24:
		var f := E - e * sin(E) - mean
		var fp := 1.0 - e * cos(E)
		if absf(fp) < 0.000001:
			break
		var d := f / fp
		E -= d
		if absf(d) < 0.000000001:
			break
	return E


func _scripted_orbit_state(a: float, e: float, periapsis: float, mean_anomaly: float, mean_motion: float) -> Dictionary:
	var E := _eccentric_anomaly(mean_anomaly, e)
	var cos_e := cos(E)
	var sin_e := sin(E)
	var minor := a * sqrt(maxf(0.0, 1.0 - e * e))
	var pos := Vector2(a * (cos_e - e), minor * sin_e).rotated(periapsis)
	var e_dot := mean_motion / maxf(0.000001, 1.0 - e * cos_e)
	var vel := Vector2(-a * sin_e, minor * cos_e).rotated(periapsis) * e_dot
	return {"pos": pos, "vel": vel}


func _step(h: float) -> void:
	var n := bodies.size()
	var acc: Array[Vector2] = []
	acc.resize(n)
	for i in n:
		acc[i] = Vector2.ZERO

	for i in range(n):
		var bi := bodies[i]
		if bi.scripted:
			continue
		var ai := Vector2.ZERO
		for j in range(i + 1, n):
			var bj := bodies[j]
			if bj.scripted:
				continue
			var d := bj.position - bi.position
			var d2 := d.length_squared() + SOFTENING
			var inv := G / (d2 * sqrt(d2))
			ai += d * (inv * bj.mass)
			acc[j] += -d * (inv * bi.mass)
		acc[i] += ai

	for i in n:
		var b := bodies[i]
		if b.scripted:
			continue
		b.velocity += acc[i] * h
		b.position += b.velocity * h


func _resolve_collisions() -> void:
	var merged := true
	while merged:
		merged = false
		var n := bodies.size()
		for i in range(n):
			for j in range(i + 1, n):
				var a := bodies[i]
				var b := bodies[j]
				var star_collision := a.is_star and b.is_star
				if not star_collision:
					if a.scripted and b.scripted:
						if not a.collides_scripted and not b.collides_scripted:
							continue
					elif (a.scripted and not a.collides_scripted) or (b.scripted and not b.collides_scripted):
						continue
				var limit := (a.radius + b.radius) * 0.9
				if a.position.distance_squared_to(b.position) < limit * limit:
					_merge(a, b)
					merged = true
					break
			if merged:
				break


func _check_disruptions() -> void:
	if not collisions_enabled:
		return
	if bodies.size() >= MAX_FRAGMENT_BODIES:
		return
	for raw in bodies.duplicate():
		var b: SpaceBody = raw
		if not bodies.has(b) or b.is_star or b.is_fragment or b.mass < 15.0 or b.tidal_immune > 0.0 or b.scripted:
			continue
		for s in bodies:
			if s == b or not s.is_star or s.mass < b.mass * 40.0 or s.scripted:
				continue
			var d: float = b.position.distance_to(s.position)
			if d < s.radius * 3.0 and d > s.radius * 0.8:
				_disrupt(b, s)
				break


func _supernova_merge(a: SpaceBody, b: SpaceBody) -> void:
	var total := a.mass + b.mass
	var pos := (a.position * a.mass + b.position * b.mass) / total
	var vel := (a.velocity * a.mass + b.velocity * b.mass) / total
	var flash_size := maxf(a.radius, b.radius) * 2.2
	_burst(pos, Color(1.0, 0.85, 0.55), flash_size, "supernova", 1.3)
	var massive := a.mass > 5000000.0 and b.mass > 5000000.0
	bodies.erase(a)
	bodies.erase(b)
	if selected == a or selected == b:
		_select(null)
		following = false
	a.visible = false
	b.visible = false
	a.queue_free()
	b.queue_free()
	if massive:
		_spawn_nebula(pos, vel, flash_size * 2.4)
	var bh_mass := maxf(total * 0.35, BLACK_HOLE_MASS)
	var bh := _create_body(pos, vel, bh_mass, 0.0, Color(0.05, 0.04, 0.08), "Чёрная дыра", true)
	bh.is_black_hole = true
	_apply_mass_kind(bh)
	_refresh_scripted_orbits(bh)
	bh.queue_redraw()
	if massive:
		hud.show_hint("Сверхновая: образовалась туманность и чёрная дыра")
	else:
		hud.show_hint("Сверхновая: столкновение звёзд породило чёрную дыру")


func _spawn_nebula(pos: Vector2, vel: Vector2, size: float) -> void:
	var neb := SpaceBurst.new()
	neb.position = pos
	neb.color = Color(0.7, 0.45, 1.0, 0.55)
	neb.size = size
	neb.kind = "nebula"
	neb.duration = 8.0
	world.add_child(neb)
	# медленно дрейфующая туманность
	var tw := create_tween()
	tw.tween_property(neb, "position", pos + vel.normalized() * 8.0, 8.0)


func _planetary_merge(a: SpaceBody, b: SpaceBody) -> void:
	var big := a
	var small := b
	if b.mass > a.mass:
		big = b
		small = a
	var total := a.mass + b.mass
	var pos := (a.position * a.mass + b.position * b.mass) / total
	var vel := (a.velocity * a.mass + b.velocity * b.mass) / total
	var base_color: Color = big.color.lerp(small.color, small.mass / total)
	# Разогрев ~500-1000C
	var impact_c := _rng.randf_range(500.0, 1000.0)
	var impact_k := impact_c + 273.15
	var heat_t := clampf((impact_c - 500.0) / 500.0, 0.0, 1.0)
	var hot_color := base_color.lerp(Color(1.0, 0.28, 0.08), lerpf(0.65, 0.9, heat_t))

	var frag_count := clampi(int(round(2.0 + total / 1800.0)), 2, 5)
	var frag_total_mass := total * 0.08
	var frag_mass := frag_total_mass / float(frag_count)
	var frag_radius := clampf(sqrt(frag_mass) * 0.35, 1.6, 3.2)
	var normal := (small.position - big.position)
	if normal.length_squared() < 0.001:
		normal = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
	normal = normal.normalized()
	var tangent := Vector2(-normal.y, normal.x)

	for i in frag_count:
		var spread := _rng.randf_range(-0.8, 0.8)
		var dir := (normal.rotated(spread) + tangent * _rng.randf_range(-0.4, 0.4)).normalized()
		var off := dir * (maxf(big.radius, small.radius) * 0.9 + _rng.randf_range(4.0, 12.0))
		var fvel := vel + dir * _rng.randf_range(12.0, 34.0)
		var frag_hot := hot_color.lerp(Color(1.0, 0.55, 0.15), _rng.randf_range(0.0, 0.35))
		var frag := _create_body(pos + off, fvel, frag_mass, frag_radius * _rng.randf_range(0.85, 1.15), frag_hot, "Осколок")
		frag.is_fragment = true
		frag.tidal_immune = 5.0
		frag.orbit_parent = null
		frag.surface_temp_k = impact_k * _rng.randf_range(0.85, 1.0)
		_start_planet_cooling(frag, frag_hot, base_color.lightened(_rng.randf_range(0.0, 0.2)), 3.0, frag.surface_temp_k)

	var remnant_mass := total - frag_total_mass
	var remnant := _create_body(pos, vel, remnant_mass, sqrt(maxf(1.0, remnant_mass)) * 0.5, hot_color, big.body_name)
	remnant.is_dwarf = big.is_dwarf or small.is_dwarf
	remnant.ring_inner_ratio = 0.0
	remnant.ring_outer_ratio = 0.0
	remnant.surface_temp_k = impact_k
	_apply_mass_kind(remnant)
	remnant.queue_redraw()
	_start_planet_cooling(remnant, hot_color, base_color, 5.0, impact_k)

	bodies.erase(a)
	bodies.erase(b)
	if selected == a or selected == b:
		_select(remnant)
	a.visible = false
	b.visible = false
	a.queue_free()
	b.queue_free()
	_burst(pos, hot_color, maxf(big.radius, small.radius) * 1.2, "ring", 0.9)
	hud.show_hint("Столкновение планет: образовалась новая планета и мелкие обломки")


func _start_planet_cooling(b: SpaceBody, hot_color: Color, target_color: Color, dur: float = 4.0, start_temp_k: float = -1.0) -> void:
	var body_ref: WeakRef = weakref(b)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var obj: Object = body_ref.get_ref()
		if obj != null and is_instance_valid(obj):
			var sb := obj as SpaceBody
			if sb != null:
				sb.color = hot_color.lerp(target_color, t)
				if start_temp_k > 0.0:
					sb.surface_temp_k = lerpf(start_temp_k, -1.0, t)
				sb.queue_redraw()
	, 0.0, 1.0, dur)
	_cooling_tweens.append(tw)
	tw.finished.connect(func():
		_cooling_tweens.erase(tw)
		if start_temp_k > 0.0:
			var obj: Object = body_ref.get_ref()
			if obj != null and is_instance_valid(obj):
				var sb := obj as SpaceBody
				if sb != null:
					sb.surface_temp_k = -1.0
	)
	if paused:
		tw.pause()


func _sync_cooling_pause() -> void:
	for tw in _cooling_tweens:
		if tw != null and tw.is_valid():
			if paused:
				tw.pause()
			else:
				tw.play()


func _disrupt(b: SpaceBody, star: SpaceBody) -> void:
	var count := 5
	var frag_mass: float = maxf(2.0, b.mass / float(count))
	var base := b.position
	var to_star := (star.position - base).normalized()
	var tangent := Vector2(-to_star.y, to_star.x)
	var frag_radius: float = maxf(2.0, b.radius * 0.5)
	for i in count:
		var ang := TAU * float(i) / float(count)
		var off := Vector2(cos(ang), sin(ang)) * (b.radius * 1.3 + 8.0)
		var outward := off.normalized()
		var shear := tangent * sin(ang * 2.0) * 6.0
		var vel := b.velocity + outward * _rng.randf_range(8.0, 20.0) + to_star * 6.0 + shear
		var frag := _create_body(base + off, vel, frag_mass, frag_radius * _rng.randf_range(0.75, 1.15), b.color.lightened(_rng.randf_range(-0.08, 0.18)), "Осколок")
		frag.is_fragment = true
		frag.orbit_parent = star
		frag.orbit_radius = frag.position.distance_to(star.position)
		frag.tidal_immune = 999999.0
	bodies.erase(b)
	if selected == b:
		_select(null)
		following = false
	b.visible = false
	b.queue_free()
	_burst(base, b.color, b.radius * 1.6)
	var host := "чёрной дыре" if star.is_black_hole else "звезде"
	hud.show_hint("Приливной разрыв: %s подошёл слишком близко к %s" % [b.body_name, host])


func _merge(a: SpaceBody, b: SpaceBody) -> void:
	var big := a
	var small := b
	if b.mass > a.mass:
		big = b
		small = a
	if big.is_star and small.is_star:
		_supernova_merge(big, small)
		return
	if not big.is_star and not small.is_star:
		_planetary_merge(big, small)
		return

	var total := a.mass + b.mass
	var pos := (a.position * a.mass + b.position * b.mass) / total
	var vel := (a.velocity * a.mass + b.velocity * b.mass) / total

	big.position = pos
	big.velocity = vel
	big.mass = total
	big.radius = sqrt(a.radius * a.radius + b.radius * b.radius)
	big.is_star = big.is_star or small.is_star
	big.is_black_hole = big.is_black_hole or small.is_black_hole
	_apply_mass_kind(big)
	_refresh_scripted_orbits(big)
	big.queue_redraw()

	bodies.erase(small)
	if selected == small:
		_select(big)
	small.visible = false
	small.queue_free()
	_burst(pos, big.color, big.radius)


func _burst(pos: Vector2, color: Color, size: float, kind: String = "ring", dur: float = 0.7) -> void:
	var fx := SpaceBurst.new()
	fx.position = pos
	fx.color = color
	fx.size = size
	fx.kind = kind
	fx.duration = dur
	world.add_child(fx)


func _record_trails(delta: float) -> void:
	_trail_timer += delta
	if _trail_timer < TRAIL_INTERVAL:
		return
	_trail_timer = 0.0
	for b in bodies:
		if b.velocity.length() < 0.4 and not b.is_star:
			continue
		b.trail.append(b.position)
		if b.trail.size() > TRAIL_MAX:
			b.trail.remove_at(0)


func _cleanup_far_bodies() -> void:
	for b in bodies.duplicate():
		if b.scripted:
			continue
		if b.position.length_squared() > 900000000.0:
			bodies.erase(b)
			if selected == b:
				_select(null)
			b.visible = false
			b.queue_free()


func _on_action(action: String) -> void:
	if action.begins_with("sat_dist:"):
		satellite_distance = clampf(float(action.substr(9)), 12.0, 160.0)
		return
	if action.begins_with("ecc:"):
		orbit_eccentricity = clampf(float(action.substr(4)), 0.0, 0.75)
		return
	if action.begins_with("barycenter:"):
		show_barycenter = action.ends_with("1")
		hud.show_hint("Барицентр " + ("включён" if show_barycenter else "выключен"))
		return
	if action.begins_with("music:"):
		music.set_enabled(action.ends_with("1"))
		return
	if action.begins_with("visual:"):
		visual_mode = action.substr(7)
		hud.set_visual_mode(visual_mode)
		queue_redraw()
		var label := "хвост"
		if visual_mode == "orbit":
			label = "орбита"
		elif visual_mode == "none":
			label = "ничего"
		hud.show_hint("Вид: %s" % label)
		return
	match action:
		"pause":
			paused = not paused
			_sync_cooling_pause()
		"speed_down":
			speed_index = maxi(0, speed_index - 1)
		"speed_up":
			speed_index = mini(SPEEDS.size() - 1, speed_index + 1)
		"spawn":
			hud.open_spawn_menu()
		"spawn:planet":
			_set_spawn_kind("planet")
		"spawn:star":
			_set_spawn_kind("star")
		"spawn:asteroid":
			_set_spawn_kind("asteroid")
		"spawn:off":
			spawn_mode = false
			_aiming = false
			hud.show_hint("Создание выключено: снова доступен обзор.")
		"scenes":
			hud.toggle_scenes()
		"center":
			_center_view()
		"reset":
			load_preset(current_preset)
		"satellite":
			_add_satellite()
		"mass_up":
			_change_mass(1.6)
		"mass_down":
			_change_mass(1.0 / 1.6)
		"recolor":
			_recolor_selected()
		"follow":
			following = not following
		"delete":
			_delete_selected()
		"deselect":
			_select(null)
		_:
			if action.begins_with("preset:"):
				load_preset(action.substr(7))
	_refresh_hud()


func _refresh_hud() -> void:
	hud.set_paused(paused)
	hud.set_speed(SPEEDS[speed_index])
	hud.set_spawn(spawn_mode, _spawn_label())
	hud.set_info(_info_text())
	var has_sel := selected != null and is_instance_valid(selected)
	hud.set_selection(has_sel, selected.body_name if has_sel else "", following, selected.is_star if has_sel else false)
	hud.set_visual_mode(visual_mode)


func _set_spawn_kind(kind: String) -> void:
	spawn_kind = kind
	spawn_mode = true
	_aiming = false
	hud.show_hint("Создание: %s. Коснитесь для орбиты (вытянутость %d%%), или ведите палец." % [_spawn_label(), roundi(orbit_eccentricity * 100.0)])


func _spawn_label() -> String:
	match spawn_kind:
		"star":
			return "Звезда"
		"asteroid":
			return "Астероид"
		_:
			return "Планета"


func _info_text() -> String:
	var t := "Объектов: %d    Время: ×%s" % [bodies.size(), _fmt_speed(SPEEDS[speed_index])]
	if paused:
		t += "    ПАУЗА"
	if following:
		t += "    СЛЕЖЕНИЕ"
	if selected != null and is_instance_valid(selected):
		t += "\n%s · %s · масса %s · скорость %s" % [
			selected.body_name,
			_body_kind_label(selected),
			_fmt_number(selected.mass),
			_fmt_number(selected.velocity.length()),
		]
		if not selected.is_star:
			var star := _nearest_star(selected)
			if star != null:
				var d := selected.position.distance_to(star.position)
				t += "\nДо звезды: %s · T ≈ %s" % [_fmt_number(d), _fmt_temp(_temperature_at(star, d))]
			else:
				t += "\nДо звезды: — · T ≈ 3 K"
			if selected.surface_temp_k > 0.0:
				t += "\nНагрев: ~%.0f°C" % (selected.surface_temp_k - 273.15)
	else:
		t += "\nКоснитесь объекта, чтобы выбрать его"
	return t


func _fmt_speed(v: float) -> String:
	if absf(v - roundf(v)) < 0.001:
		return str(int(roundf(v)))
	return "%.2f" % v


func _fmt_number(v: float) -> String:
	if v >= 1000000000000.0:
		return "%.1f трлн" % (v / 1000000000000.0)
	if v >= 1000000000.0:
		return "%.1f млрд" % (v / 1000000000.0)
	if v >= 1000000.0:
		return "%.1f млн" % (v / 1000000.0)
	if v >= 1000.0:
		return "%.1f тыс" % (v / 1000.0)
	return "%.0f" % v


func _temperature_at(star: SpaceBody, d: float) -> float:
	if star == null or star.is_black_hole:
		return 3.0
	return 288.0 * pow(star.mass / 6000000.0, 0.25) * sqrt(520.0 / maxf(d, 1.0))


func _fmt_temp(t: float) -> String:
	if t >= 1000.0:
		return "%.0f K" % t
	return "%.0f K (%.0f °C)" % [t, t - 273.15]


func _body_kind_label(b: SpaceBody) -> String:
	if b.is_black_hole:
		return "чёрная дыра"
	if b.is_star:
		return "звезда"
	if b.is_fragment:
		return "осколок"
	if b.is_dwarf:
		return "карликовая планета"
	return "планета"


func _select(b: SpaceBody) -> void:
	if selected != null and is_instance_valid(selected):
		selected.selected = false
		selected.queue_redraw()
	selected = b
	if selected != null and is_instance_valid(selected):
		selected.selected = true
		selected.queue_redraw()


func _clear() -> void:
	for tw in _cooling_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_cooling_tweens.clear()
	for b in bodies:
		b.visible = false
		b.queue_free()
	bodies.clear()
	selected = null


func _create_body(pos: Vector2, vel: Vector2, mass: float, radius: float, color: Color, body_name: String, is_star := false) -> SpaceBody:
	var b := SpaceBody.new()
	b.position = pos
	b.velocity = vel
	b.mass = mass
	b.radius = radius
	b.color = color
	b.body_name = body_name
	b.is_star = is_star
	world.add_child(b)
	bodies.append(b)
	return b


func _radius_for_mass(mass: float) -> float:
	return clampf(3.5 + pow(mass, 0.34) * 0.55, 4.0, 16.0)


func load_preset(id: String) -> void:
	current_preset = id
	collisions_enabled = true
	following = false
	_clear()
	_trail_timer = 0.0
	match id:
		"binary":
			_preset_binary()
		"ring":
			_preset_ring()
		"collision":
			_preset_collision()
		"comet":
			_preset_comet()
		"tidal":
			_preset_tidal()
		"empty":
			_preset_empty()
		_:
			if id.begins_with("sys_"):
				_preset_system_by_id(id)
			else:
				current_preset = "solar"
				_preset_solar()
	_center_view()


func _preset_solar() -> void:
	collisions_enabled = false
	var sun := _create_body(Vector2.ZERO, Vector2.ZERO, 6000000.0, 46.0, Color(1.0, 0.78, 0.3), "Солнце", true)
	var planets := [
		{"r": 280.0, "mass": 90.0, "rad": 5.0, "color": Color(0.72, 0.68, 0.6), "name": "Меркурий"},
		{"r": 390.0, "mass": 420.0, "rad": 7.5, "color": Color(0.95, 0.72, 0.42), "name": "Венера"},
		{"r": 520.0, "mass": 6000.0, "rad": 8.0, "color": Color(0.45, 0.72, 1.0), "name": "Земля"},
		{"r": 660.0, "mass": 260.0, "rad": 6.0, "color": Color(0.92, 0.45, 0.32), "name": "Марс"},
		{"r": 950.0, "mass": 10000.0, "rad": 15.0, "color": Color(0.93, 0.82, 0.6), "name": "Юпитер"},
		{"r": 1250.0, "mass": 4000.0, "rad": 13.0, "color": Color(0.95, 0.9, 0.66), "name": "Сатурн"},
		{"r": 1500.0, "mass": 3000.0, "rad": 11.0, "color": Color(0.55, 0.88, 0.9), "name": "Уран"},
		{"r": 1750.0, "mass": 2800.0, "rad": 11.0, "color": Color(0.45, 0.6, 1.0), "name": "Нептун"},
	]
	var dwarfs := [
		{"r": 800.0, "mass": 40.0, "rad": 3.0, "color": Color(0.62, 0.6, 0.55), "name": "Церера"},
		{"r": 2050.0, "mass": 80.0, "rad": 3.8, "color": Color(0.78, 0.68, 0.58), "name": "Плутон"},
		{"r": 2250.0, "mass": 70.0, "rad": 4.2, "color": Color(0.88, 0.9, 0.94), "name": "Хаумея"},
		{"r": 2450.0, "mass": 55.0, "rad": 3.6, "color": Color(0.72, 0.56, 0.48), "name": "Макемаке"},
		{"r": 2800.0, "mass": 90.0, "rad": 4.0, "color": Color(0.86, 0.88, 0.95), "name": "Эрида"},
		{"r": 11670.0, "mass": 60.0, "rad": 3.6, "color": Color(0.82, 0.48, 0.42), "name": "Седна", "e": 0.85, "peri": 0.0, "m0": 0.0},
	]
	var made := {}
	for p in planets:
		var b: SpaceBody = _orbit_body(sun, float(p["r"]), float(p["mass"]), float(p["rad"]), p["color"], p["name"])
		_script_orbit(b, sun, float(p["r"]))
		made[p["name"]] = b
	for p in dwarfs:
		var d: SpaceBody = _orbit_body(sun, float(p["r"]), float(p["mass"]), float(p["rad"]), p["color"], p["name"])
		d.is_dwarf = true
		var ecc := float(p.get("e", 0.0))
		if ecc > 0.0:
			_script_orbit(d, sun, float(p["r"]), ecc, float(p.get("peri", 0.0)), float(p.get("m0", 0.0)))
		else:
			_script_orbit(d, sun, float(p["r"]))
		made[p["name"]] = d
	_set_ring(made["Юпитер"], 1.35, 2.05, Color(0.85, 0.78, 0.62, 0.18), -0.25)
	_set_ring(made["Сатурн"], 1.35, 2.55, Color(0.96, 0.86, 0.62, 0.68), -0.38)
	_set_ring(made["Уран"], 1.45, 2.05, Color(0.62, 0.85, 0.9, 0.32), 0.55)
	_set_ring(made["Нептун"], 1.5, 2.15, Color(0.55, 0.7, 1.0, 0.26), 0.18)
	_set_ring(made["Хаумея"], 1.45, 2.2, Color(0.8, 0.9, 1.0, 0.45), -0.22)
	_add_scripted_moon(made["Земля"], 15.0, 8.0, 3.0, Color(0.8, 0.82, 0.85), "Луна")
	_add_scripted_moon(made["Юпитер"], 26.0, 12.0, 3.5, Color(0.85, 0.75, 0.6), "Ио")
	_add_scripted_moon(made["Юпитер"], 38.0, 7.0, 2.6, Color(0.9, 0.9, 0.95), "Европа")
	_add_scripted_moon(made["Юпитер"], 50.0, 10.0, 3.8, Color(0.72, 0.68, 0.62), "Ганимед")
	_add_scripted_moon(made["Юпитер"], 62.0, 6.0, 3.3, Color(0.58, 0.52, 0.46), "Каллисто")
	_add_scripted_moon(made["Сатурн"], 30.0, 9.0, 3.0, Color(0.8, 0.86, 0.9), "Титан")
	_add_scripted_moon(made["Сатурн"], 44.0, 4.0, 2.5, Color(0.78, 0.80, 0.82), "Рея")
	_add_scripted_moon(made["Сатурн"], 56.0, 3.0, 2.2, Color(0.92, 0.94, 0.96), "Энцелад")
	_add_scripted_moon(made["Уран"], 24.0, 4.0, 2.6, Color(0.72, 0.78, 0.82), "Титания")
	_add_scripted_moon(made["Уран"], 34.0, 3.5, 2.4, Color(0.62, 0.66, 0.72), "Оберон")
	_add_scripted_moon(made["Нептун"], 28.0, 4.5, 2.6, Color(0.78, 0.82, 0.88), "Тритон")
	_add_scripted_moon(made["Нептун"], 44.0, 2.5, 2.0, Color(0.66, 0.70, 0.76), "Нереида")


func _preset_binary() -> void:
	var m := 2400000.0
	var d := 420.0
	var v := sqrt(G * m / (2.0 * d))
	var star_a := _create_body(Vector2(-d * 0.5, 0.0), Vector2(0.0, v), m, 32.0, Color(1.0, 0.72, 0.36), "Звезда A", true)
	var star_b := _create_body(Vector2(d * 0.5, 0.0), Vector2(0.0, -v), m, 32.0, Color(0.6, 0.82, 1.0), "Звезда B", true)
	star_a.orbit_radius = d * 0.5
	star_b.orbit_radius = d * 0.5
	var total := m * 2.0
	for r_value in [820.0, 1080.0]:
		var r: float = r_value
		var ang := _rng.randf_range(0.0, TAU)
		var pos := Vector2(cos(ang), sin(ang)) * r
		var speed := sqrt(G * total / r)
		_create_body(pos, Vector2(-sin(ang), cos(ang)) * speed, 1500.0, 10.0, Color(0.62, 0.92, 0.78), "Планета")


func _preset_ring() -> void:
	var sun := _create_body(Vector2.ZERO, Vector2.ZERO, 5400000.0, 40.0, Color(1.0, 0.8, 0.34), "Солнце", true)
	for i in 70:
		var ang := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(360.0, 520.0)
		var pos := Vector2(cos(ang), sin(ang)) * r
		var speed := sqrt(G * sun.mass / r) * _rng.randf_range(0.98, 1.02)
		var vel := Vector2(-sin(ang), cos(ang)) * speed
		var mass := _rng.randf_range(4.0, 18.0)
		var col: Color = PALETTE[_rng.randi() % PALETTE.size()]
		_create_body(pos, vel, mass, _rng.randf_range(2.0, 3.6), col, "Астероид")
	var ang2 := _rng.randf_range(0.0, TAU)
	var r2 := 720.0
	var pos2 := Vector2(cos(ang2), sin(ang2)) * r2
	_create_body(pos2, Vector2(-sin(ang2), cos(ang2)) * sqrt(G * sun.mass / r2), 1800.0, 11.0, Color(0.55, 0.85, 1.0), "Планета")


func _preset_collision() -> void:
	var ma := 1800000.0
	var a := _create_body(Vector2(-620.0, -60.0), Vector2(26.0, 0.0), ma, 30.0, Color(1.0, 0.68, 0.32), "Звезда A", true)
	var b := _create_body(Vector2(620.0, 60.0), Vector2(-26.0, 0.0), ma, 30.0, Color(0.55, 0.8, 1.0), "Звезда B", true)
	for i in 12:
		var ang := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(70.0, 190.0)
		var off := Vector2(cos(ang), sin(ang)) * r
		var sp := sqrt(G * ma / r)
		var debris_a := _create_body(a.position + off, a.velocity + Vector2(-sin(ang), cos(ang)) * sp, _rng.randf_range(20.0, 160.0), _rng.randf_range(3.0, 6.0), PALETTE[i % PALETTE.size()], "Осколок")
		debris_a.is_fragment = true
		debris_a.orbit_parent = a
		debris_a.orbit_radius = r
	for i in 12:
		var ang := _rng.randf_range(0.0, TAU)
		var r := _rng.randf_range(70.0, 190.0)
		var off := Vector2(cos(ang), sin(ang)) * r
		var sp := sqrt(G * ma / r)
		var debris_b := _create_body(b.position + off, b.velocity + Vector2(-sin(ang), cos(ang)) * sp, _rng.randf_range(20.0, 160.0), _rng.randf_range(3.0, 6.0), PALETTE[(i + 3) % PALETTE.size()], "Осколок")
		debris_b.is_fragment = true
		debris_b.orbit_parent = b
		debris_b.orbit_radius = r


func _preset_comet() -> void:
	var sun := _create_body(Vector2.ZERO, Vector2.ZERO, 6000000.0, 46.0, Color(1.0, 0.78, 0.3), "Солнце", true)
	_orbit_body(sun, 360.0, 420.0, 7.0, Color(0.5, 0.75, 1.0), "Океанида")
	_orbit_body(sun, 620.0, 300.0, 6.0, Color(0.92, 0.45, 0.32), "Марс")
	var ang := _rng.randf_range(0.0, TAU)
	var r := 1200.0
	var pos := Vector2(cos(ang), sin(ang)) * r
	var speed := sqrt(G * sun.mass / r) * 0.5
	_create_body(pos, Vector2(-sin(ang), cos(ang)) * speed, 8.0, 3.0, Color(0.75, 0.92, 1.0), "Комета")


func _preset_tidal() -> void:
	var sun := _create_body(Vector2.ZERO, Vector2.ZERO, 6000000.0, 46.0, Color(1.0, 0.78, 0.3), "Солнце", true)
	_orbit_body(sun, 320.0, 500.0, 8.0, Color(0.45, 0.72, 1.0), "Земля")
	_orbit_body(sun, 700.0, 300.0, 6.0, Color(0.92, 0.45, 0.32), "Марс")
	var r := 980.0
	var speed := sqrt(G * sun.mass / r) * 0.45
	_create_body(Vector2(r, 0.0), Vector2(0.0, speed), 900.0, 11.0, Color(0.85, 0.7, 0.95), "Гигант")
	hud.show_hint("«Гигант» упадёт на звезду и разорвётся — включи скорость ×8")


func _preset_empty() -> void:
	_create_body(Vector2.ZERO, Vector2.ZERO, 6000000.0, 46.0, Color(1.0, 0.78, 0.3), "Солнце", true)


func _preset_system_by_id(id: String) -> void:
	for sys in SYSTEMS.LIST:
		if str(sys["id"]) == id:
			_preset_system(sys)
			return
	current_preset = "solar"
	_preset_solar()


func _star_radius(mass: float) -> float:
	return clampf(26.0 + pow(mass, 0.24) * 0.5, 30.0, 60.0)


func _preset_system(sys: Dictionary) -> void:
	_rng.seed = int(sys.get("seed", 1))
	var kind := str(sys.get("kind", "single"))
	var m1 := float(sys.get("m1", 6.0)) * 1000000.0
	var m2 := float(sys.get("m2", 0.0)) * 1000000.0
	var total := m1 + m2
	var nm := str(sys.get("name", "Система"))
	var rad1 := float(sys.get("rad1", _star_radius(m1)))
	var col1 := Color.html(str(sys.get("c1", "#ffc85a")))
	var planets: Array[SpaceBody] = []
	var inner := float(sys.get("inner", 300.0))
	var step := float(sys.get("step", 180.0))
	var count := int(sys.get("count", 3))
	var scripted_planets := bool(sys.get("scripted", false))
	if kind == "binary":
		var d := float(sys.get("sep", 420.0))
		var rad2 := float(sys.get("rad2", _star_radius(m2)))
		var col2 := Color.html(str(sys.get("c2", "#9ec8ff")))
		var vrel := sqrt(G * total / d)
		var r1 := d * m2 / total
		var r2 := d * m1 / total
		var star_a := _create_body(Vector2(-r1, 0.0), Vector2(0.0, vrel * m2 / total), m1, rad1, col1, nm + " A", true)
		var star_b := _create_body(Vector2(r2, 0.0), Vector2(0.0, -vrel * m1 / total), m2, rad2, col2, nm + " B", true)
		star_a.orbit_radius = r1
		star_b.orbit_radius = r2
		inner = maxf(inner, d * 1.5 + 220.0)
		inner = maxf(inner, d * 0.5 + rad1 + rad2 + 160.0)
		for i in count:
			var r := inner + step * i
			var ang := _rng.randf_range(0.0, TAU)
			var pos := Vector2(cos(ang), sin(ang)) * r
			var vel := Vector2(-sin(ang), cos(ang)) * sqrt(G * total / r)
			var mass := _rng.randf_range(150.0, 3200.0)
			var rad := _rng.randf_range(5.5, 11.5)
			var col := Color.html(str(SYSTEMS.PLANET_COLORS[i % SYSTEMS.PLANET_COLORS.size()]))
			planets.append(_create_body(pos, vel, mass, rad, col, "%s %s" % [nm, String.chr(98 + i)]))
	else:
		var star := _create_body(Vector2.ZERO, Vector2.ZERO, m1, rad1, col1, nm, true)
		inner = maxf(inner, rad1 * 2.5 + 60.0)
		for i in count:
			var r := inner + step * i
			var mass := _rng.randf_range(150.0, 3200.0)
			var rad := _rng.randf_range(5.5, 11.5)
			var col := Color.html(str(SYSTEMS.PLANET_COLORS[i % SYSTEMS.PLANET_COLORS.size()]))
			var pb := _orbit_body(star, r, mass, rad, col, "%s %s" % [nm, String.chr(98 + i)])
			if scripted_planets:
				pb.scripted = true
				pb.orbit_parent = star
				pb.orbit_radius = r
				pb.orbit_angle = (pb.position - star.position).angle()
				pb.orbit_speed = _circular_speed(m1, r) / r
			planets.append(pb)
	if sys.has("third_m"):
		var m3 := float(sys.get("third_m", 1.0)) * 1000000.0
		var sep3 := float(sys.get("third_sep", 1900.0))
		var total3 := total + m3
		var vrel := sqrt(G * total3 / sep3)
		var offset := Vector2(-sep3 * m3 / total3, 0.0)
		var voffset := Vector2(0.0, -vrel * m3 / total3)
		for b in bodies:
			b.position += offset
			b.velocity += voffset
		var rad3 := float(sys.get("third_rad", _star_radius(m3)))
		var col3 := Color.html(str(sys.get("third_c", "#ff7a5a")))
		var pos3 := Vector2(sep3 * total / total3, 0.0)
		var vel3 := Vector2(0.0, vrel * total / total3)
		var third := _create_body(pos3, vel3, m3, rad3, col3, "Проксима Центавра", true)
		third.scripted = true
		third.orbit_radius = sep3
		third.orbit_angle = 0.0
		third.orbit_speed = sqrt(G * total3 / (sep3 * sep3 * sep3))
		var third_count := int(sys.get("third_planets", 1))
		for j in third_count:
			var pr := 150.0 + 80.0 * j
			var pm := _rng.randf_range(80.0, 400.0)
			var prad := _rng.randf_range(4.0, 6.5)
			var pcol := Color.html(str(SYSTEMS.PLANET_COLORS[(j + 2) % SYSTEMS.PLANET_COLORS.size()]))
			var ang := _rng.randf_range(0.0, TAU)
			var ppos := pos3 + Vector2(cos(ang), sin(ang)) * pr
			var pspeed := _circular_speed(m3, pr)
			var pvel := vel3 + Vector2(-sin(ang), cos(ang)) * pspeed
			var pb := _create_body(ppos, pvel, pm, prad, pcol, "Проксима " + String.chr(98 + j))
			pb.scripted = true
			pb.orbit_parent = third
			pb.orbit_radius = pr
			pb.orbit_angle = ang
			pb.orbit_speed = pspeed / pr
	var moons := int(sys.get("moons", 0))
	for mi in moons:
		if planets.is_empty():
			break
		var parent: SpaceBody = planets[mi % planets.size()]
		var md := maxf(parent.radius * 2.4, 14.0)
		_add_scripted_moon(parent, md, 4.0, 2.4, Color(0.85, 0.86, 0.9), "Луна")


func _center_view() -> void:
	if bodies.is_empty():
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(0.8, 0.8)
		return
	var minp := bodies[0].position
	var maxp := bodies[0].position
	for b in bodies:
		minp = Vector2(minf(minp.x, b.position.x), minf(minp.y, b.position.y))
		maxp = Vector2(maxf(maxp.x, b.position.x), maxf(maxp.y, b.position.y))
	var center := (minp + maxp) * 0.5
	var size := Vector2(maxf(maxp.x - minp.x, 120.0), maxf(maxp.y - minp.y, 120.0))
	var vp := get_viewport_rect().size
	var z: float = minf(vp.x / size.x, vp.y / size.y) * 0.72
	camera.position = center
	z = clampf(z, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(z, z)


func screen_to_world(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return camera.position + (p - vp * 0.5) / camera.zoom.x


func _apply_zoom(factor: float, pivot: Vector2) -> void:
	var before := screen_to_world(pivot)
	var z: float = clampf(camera.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(z, z)
	var after := screen_to_world(pivot)
	camera.position += before - after


func _spawn_at(pos: Vector2) -> SpaceBody:
	return _spawn_body(pos, Vector2.ZERO)


func _spawn_with_velocity(pos: Vector2, vel: Vector2) -> SpaceBody:
	return _spawn_body(pos, vel)


func _spawn_body(pos: Vector2, vel: Vector2) -> SpaceBody:
	match spawn_kind:
		"star":
			var star_mass := _rng.randf_range(3000000.0, 8000000.0)
			var star_rad := clampf(26.0 + pow(star_mass, 0.24) * 0.5, 30.0, 60.0)
			var star_col: Color = STAR_PALETTE[_rng.randi() % STAR_PALETTE.size()]
			return _create_body(pos, vel, star_mass, star_rad, star_col, "Звезда", true)
		"asteroid":
			var rock_mass := _rng.randf_range(4.0, 30.0)
			var rock_col: Color = PALETTE[_rng.randi() % PALETTE.size()]
			return _create_body(pos, vel, rock_mass, _rng.randf_range(2.0, 4.0), rock_col, "Астероид")
		_:
			var mass := _rng.randf_range(250.0, 1400.0)
			var col: Color = PALETTE[_rng.randi() % PALETTE.size()]
			return _create_body(pos, vel, mass, _radius_for_mass(mass), col, "Планета")


func _dominant_body_at(pos: Vector2) -> SpaceBody:
	var best: SpaceBody = null
	var best_score := -INF
	for b in bodies:
		var d := maxf(pos.distance_to(b.position), b.radius * 1.5)
		var score := b.mass / (d * d)
		if score > best_score:
			best_score = score
			best = b
	return best


func _spawn_orbital(pos: Vector2) -> void:
	var heavy := _dominant_body_at(pos)
	if heavy == null:
		_spawn_at(pos)
		return
	var to := pos - heavy.position
	var d := maxf(to.length(), heavy.radius * 1.4)
	var ecc := clampf(orbit_eccentricity, 0.0, 0.75)
	var speed := _circular_speed(heavy.mass, d) * sqrt(1.0 + ecc)
	var tangent := Vector2(-to.y, to.x).normalized() * speed
	if _rng.randf() < 0.5:
		tangent = -tangent
	_spawn_with_velocity(pos, heavy.velocity + tangent)


func _add_satellite() -> void:
	if selected == null or not is_instance_valid(selected):
		return
	var parent := selected
	var dist: float = maxf(satellite_distance, parent.radius * 1.5)
	var mass: float = clampf(parent.mass * 0.012, 2.0, 60.0)
	var rad: float = maxf(2.0, _radius_for_mass(mass) * 0.7)
	var col: Color = PALETTE[_rng.randi() % PALETTE.size()]
	var is_planet := parent.is_star
	var nm := "Планета" if is_planet else "Спутник"
	var moon := _add_scripted_moon(parent, dist, mass, rad, col, nm)
	moon.collides_scripted = true
	_select(moon)
	var kind_word := "планетой" if is_planet else "спутником"
	hud.show_hint("%s стал %s объекта «%s» на расстоянии %.0f" % [nm, kind_word, parent.body_name, dist])


func _change_mass(factor: float) -> void:
	if selected == null or not is_instance_valid(selected):
		return
	var b := selected
	var before := _body_kind_label(b)
	var next_mass := clampf(b.mass * factor, 1.0, 1000000000000.0)
	if b.scripted and next_mass < STAR_MASS:
		b.scripted = false
	b.mass = next_mass
	_apply_mass_kind(b)
	_refresh_scripted_orbits(b)
	b.queue_redraw()
	var after := _body_kind_label(b)
	if after != before:
		match after:
			"чёрная дыра":
				hud.show_hint("%s коллапсировал в чёрную дыру" % b.body_name)
			"звезда":
				hud.show_hint("%s стал звездой" % b.body_name)
			_:
				hud.show_hint("%s остыл до планеты" % b.body_name)
	_refresh_hud()


func _apply_mass_kind(b: SpaceBody) -> void:
	var was_label := _body_kind_label(b)
	var was_star := b.is_star
	var was_black_hole := b.is_black_hole
	if b.mass >= BLACK_HOLE_MASS:
		b.is_star = true
		b.is_black_hole = true
		b.is_dwarf = false
		b.radius = clampf(10.0 + pow(b.mass, 0.14) * 1.1, 12.0, 30.0)
	elif b.mass >= STAR_MASS:
		b.is_star = true
		b.is_black_hole = false
		b.is_dwarf = false
		b.radius = _star_radius(b.mass)
	else:
		b.is_star = false
		b.is_black_hole = false
		b.radius = _radius_for_mass(b.mass)
	if b.scripted and ((b.is_black_hole and not was_black_hole) or (b.is_star and not was_star)):
		b.scripted = false
		b.orbit_parent = null
	var after_label := _body_kind_label(b)
	if after_label != was_label:
		_rename_body_for_kind(b, after_label)


func _rename_body_for_kind(b: SpaceBody, kind: String) -> void:
	var prefixes := ["Карликовая планета ", "Чёрная дыра ", "Черная дыра ", "Звезда ", "Планета ", "Осколок ", "Астероид ", "Комета ", "Карликовая планета", "Чёрная дыра", "Черная дыра", "Звезда", "Планета", "Осколок", "Астероид", "Комета"]
	var base := b.body_name
	for p in prefixes:
		if base.begins_with(p):
			base = base.substr(p.length())
			break
	var title: String
	match kind:
		"чёрная дыра":
			title = "Чёрная дыра"
		"звезда":
			title = "Звезда"
		"планета":
			title = "Планета"
		"карликовая планета":
			title = "Карликовая планета"
		"осколок":
			title = "Осколок"
		_:
			title = kind.capitalize()
	b.body_name = title if base.strip_edges().is_empty() else "%s %s" % [title, base]


func _refresh_scripted_orbits(changed: SpaceBody) -> void:
	var total_star_mass := 0.0
	for s in bodies:
		if s.is_star:
			total_star_mass += s.mass
	# Обновить собственную орбиту изменённого тела (например, Проксима вокруг барицентра)
	if changed.scripted and changed.orbit_radius > 0.0:
		if is_instance_valid(changed.orbit_parent):
			changed.orbit_speed = _circular_speed(changed.orbit_parent.mass, changed.orbit_radius) / changed.orbit_radius
		elif changed.is_star:
			changed.orbit_speed = sqrt(G * total_star_mass / pow(changed.orbit_radius, 3.0))
	for s in bodies:
		if not s.scripted or s == changed or s.orbit_radius <= 0.0:
			continue
		if s.orbit_parent == changed:
			if changed.is_star and not s.is_star:
				continue
			s.orbit_speed = _circular_speed(changed.mass, s.orbit_radius) / s.orbit_radius
		elif changed.is_star and s.is_star and s.orbit_parent == null:
			s.orbit_speed = sqrt(G * total_star_mass / pow(s.orbit_radius, 3.0))


func _recolor_selected() -> void:
	if selected == null or not is_instance_valid(selected):
		return
	var next: Color = selected.color
	for i in 4:
		next = PALETTE[_rng.randi() % PALETTE.size()]
		if next != selected.color:
			break
	selected.color = next
	selected.queue_redraw()


func _delete_selected() -> void:
	if selected == null or not is_instance_valid(selected):
		return
	var b := selected
	bodies.erase(b)
	_select(null)
	following = false
	_burst(b.position, b.color, b.radius * 1.2)
	b.visible = false
	b.queue_free()


func _orbit_body(center: SpaceBody, dist: float, mass: float, rad: float, col: Color, nm: String) -> SpaceBody:
	var ang := _rng.randf_range(0.0, TAU)
	var pos := center.position + Vector2(cos(ang), sin(ang)) * dist
	var speed := _circular_speed(center.mass, dist)
	var vel := center.velocity + Vector2(-sin(ang), cos(ang)) * speed
	return _create_body(pos, vel, mass, rad, col, nm)


func _circular_speed(center_mass: float, dist: float) -> float:
	var d2 := dist * dist
	return sqrt(G * center_mass * d2 / pow(d2 + SOFTENING, 1.5))


func _add_moon(parent: SpaceBody, dist: float, mass: float, rad: float, col: Color, nm: String) -> SpaceBody:
	return _orbit_body(parent, dist, mass, rad, col, nm)


func _add_scripted_moon(parent: SpaceBody, dist: float, mass: float, rad: float, col: Color, nm: String) -> SpaceBody:
	var moon := _add_moon(parent, dist, mass, rad, col, nm)
	_script_orbit(moon, parent, dist)
	return moon


func _script_orbit(b: SpaceBody, parent: SpaceBody, dist: float, e: float = 0.0, periapsis: float = 0.0, mean_anomaly: float = NAN) -> void:
	b.scripted = true
	b.orbit_parent = parent
	b.orbit_radius = dist
	b.orbit_eccentricity = clampf(e, 0.0, 0.95)
	b.orbit_periapsis = periapsis
	b.orbit_speed = _circular_speed(parent.mass, dist) / dist
	if b.orbit_eccentricity > 0.0001:
		b.orbit_angle = 0.0 if is_nan(mean_anomaly) else mean_anomaly
		var state := _scripted_orbit_state(dist, b.orbit_eccentricity, periapsis, b.orbit_angle, b.orbit_speed)
		var rel_pos: Vector2 = state["pos"]
		var rel_vel: Vector2 = state["vel"]
		b.position = parent.position + rel_pos
		b.velocity = parent.velocity + rel_vel
	else:
		b.orbit_angle = (b.position - parent.position).angle()


func _set_ring(b: SpaceBody, inner: float, outer: float, color: Color, tilt: float) -> void:
	b.ring_inner_ratio = maxf(inner, 1.02)
	b.ring_outer_ratio = maxf(outer, b.ring_inner_ratio + 0.05)
	b.ring_color = color
	b.ring_tilt = tilt
	b.queue_redraw()


func _finish_aim() -> void:
	var drag := _aim_end - _aim_start
	var drag_screen := drag * camera.zoom.x
	if drag_screen.length() < 14.0:
		_spawn_orbital(_aim_start)
	else:
		var heavy := _dominant_body_at(_aim_start)
		var dir := drag.normalized()
		if heavy == null:
			var vel := dir * minf(drag_screen.length() * 0.55, 200.0)
			_spawn_with_velocity(_aim_start, vel)
		else:
			var d := maxf(_aim_start.distance_to(heavy.position), heavy.radius * 1.4)
			var v_circ := _circular_speed(heavy.mass, d)
			var strength := clampf(drag_screen.length() / 200.0, 0.0, 1.3)
			_spawn_with_velocity(_aim_start, heavy.velocity + dir * v_circ * strength)
	_aiming = false


func _tap_select(p: Vector2) -> void:
	var w := screen_to_world(p)
	var best: SpaceBody = null
	var best_d := INF
	for b in bodies:
		var d := b.position.distance_to(w)
		if d <= maxf(b.radius + 16.0 / camera.zoom.x, b.radius * 1.7) and d < best_d:
			best_d = d
			best = b
	_select(best)


func _touch_points() -> Array:
	var pts: Array = []
	for k in _touches:
		pts.append(_touches[k])
	return pts


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
		if _touches.size() == 1:
			_single_id = e.index
			_single_start = e.position
			_single_moved = 0.0
			_pinching = false
			_pinch_pending = false
			if spawn_mode:
				_panning = false
				_aiming = true
				_aim_start = screen_to_world(e.position)
				_aim_end = _aim_start
			else:
				_panning = true
				_aiming = false
		elif _touches.size() == 2:
			_aiming = false
			_pinching = false
			_pinch_pending = true
			_pinch_dist = 0.0
			_pinch_mid = Vector2.ZERO
			_panning = true
			var pts := _touch_points()
			if pts.size() >= 2:
				var p1: Vector2 = pts[0]
				var p2: Vector2 = pts[1]
				_pinch_start_dist = p1.distance_to(p2)
				_pinch_start_mid = (p1 + p2) * 0.5
	else:
		_touches.erase(e.index)
		if _pinch_pending:
			_pinch_pending = false
			_pinch_dist = 0.0
			if _touches.size() == 1:
				_single_id = int(_touches.keys()[0])
				_single_start = _touches[_single_id]
				_single_moved = 100.0
				_panning = true
				_aiming = false
			elif _touches.size() == 0:
				_panning = false
				_aiming = false
				_single_id = -1
			return
		if _pinching:
			_pinch_dist = 0.0
			if _touches.size() < 2:
				_pinching = false
			if _touches.size() == 1:
				_single_id = int(_touches.keys()[0])
				_single_start = _touches[_single_id]
				_single_moved = 100.0
				_panning = true
				_aiming = false
			return
		if _touches.size() == 0:
			if _aiming and e.index == _single_id:
				_finish_aim()
			elif _panning and e.index == _single_id and _single_moved < 14.0:
				_tap_select(e.position)
			_panning = false
			_aiming = false
			_single_id = -1


func _on_drag(e: InputEventScreenDrag) -> void:
	_touches[e.index] = e.position
	if _pinch_pending and _touches.size() >= 2:
		var pts := _touch_points()
		var p1: Vector2 = pts[0]
		var p2: Vector2 = pts[1]
		var d := p1.distance_to(p2)
		var m := (p1 + p2) * 0.5
		if absf(d - _pinch_start_dist) > 28.0 or (m - _pinch_start_mid).length() > 28.0:
			_pinching = true
			_pinch_pending = false
			_panning = false
			_aiming = false
			_pinch_dist = d
			_pinch_mid = m
			_single_id = -1
			return
		if e.index == _single_id and _panning:
			camera.position -= e.relative / camera.zoom.x
		return
	if _pinching and _touches.size() >= 2:
		var pts := _touch_points()
		var p1: Vector2 = pts[0]
		var p2: Vector2 = pts[1]
		var d := p1.distance_to(p2)
		var m := (p1 + p2) * 0.5
		if _pinch_dist > 0.0:
			_apply_zoom(d / _pinch_dist, m)
			camera.position -= (m - _pinch_mid) / camera.zoom.x
		_pinch_dist = d
		_pinch_mid = m
		queue_redraw()
		return
	if e.index != _single_id:
		return
	_single_moved += e.relative.length()
	if _aiming:
		_aim_end = screen_to_world(e.position)
		queue_redraw()
	elif _panning:
		camera.position -= e.relative / camera.zoom.x


func _unhandled_input(event) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_zoom(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_zoom(1.0 / 1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = event.pressed
			if event.pressed:
				_single_id = -2
				_single_start = event.position
				_single_moved = 0.0
				if spawn_mode:
					_aiming = true
					_aim_start = screen_to_world(event.position)
					_aim_end = _aim_start
				else:
					_panning = true
			else:
				if _aiming:
					_finish_aim()
				elif _panning and _single_moved < 14.0:
					_tap_select(event.position)
				_panning = false
				_aiming = false
	elif event is InputEventMouseMotion and _mouse_down:
		_single_moved += event.relative.length()
		if _aiming:
			_aim_end = screen_to_world(event.position)
			queue_redraw()
		elif _panning:
			camera.position -= event.relative / camera.zoom.x
