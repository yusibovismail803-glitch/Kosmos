extends Node2D

var _stars: Array = []
var _nebulae: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 987654321
	get_viewport().size_changed.connect(_regenerate)
	_regenerate()


func _regenerate() -> void:
	_stars.clear()
	_nebulae.clear()
	var sz := get_viewport_rect().size
	if sz.x < 1.0 or sz.y < 1.0:
		return
	var area := sz.x * sz.y
	var count: int = clampi(int(area / 5200.0), 220, 1100)
	var cols := [
		Color(1.0, 1.0, 1.0),
		Color(0.72, 0.82, 1.0),
		Color(1.0, 0.9, 0.76),
		Color(0.8, 0.9, 1.0),
	]
	for i in count:
		var p := Vector2(_rng.randf() * sz.x, _rng.randf() * sz.y)
		var r := _rng.randf_range(0.5, 1.9)
		var a := _rng.randf_range(0.18, 0.9)
		var c: Color = cols[_rng.randi() % cols.size()]
		_stars.append([p, r, Color(c.r, c.g, c.b, a)])
	for i in 6:
		var p := Vector2(_rng.randf() * sz.x, _rng.randf() * sz.y)
		var r := _rng.randf_range(220.0, 640.0)
		var c := Color(
			_rng.randf_range(0.2, 0.5),
			_rng.randf_range(0.2, 0.45),
			_rng.randf_range(0.5, 0.9),
			_rng.randf_range(0.018, 0.045)
		)
		_nebulae.append([p, r, c])
	queue_redraw()


func _draw() -> void:
	for n in _nebulae:
		var np: Vector2 = n[0]
		var nr: float = n[1]
		var nc: Color = n[2]
		draw_circle(np, nr, nc)
	for s in _stars:
		var sp: Vector2 = s[0]
		var sr: float = s[1]
		var sc: Color = s[2]
		draw_circle(sp, sr, sc)
