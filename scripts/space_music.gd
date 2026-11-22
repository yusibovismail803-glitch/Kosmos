extends AudioStreamPlayer

const MIX_RATE := 11025.0
const BUFFER_SECONDS := 0.25

var enabled := true

var _time := 0.0
var _phase_a := 0.0
var _phase_b := 0.0
var _phase_c := 0.0
var _phase_d := 0.0
var _volume_db := -60.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = BUFFER_SECONDS
	stream = generator
	volume_db = _volume_db
	play()


func set_enabled(value: bool) -> void:
	enabled = value
	if enabled and not playing:
		play()


func _process(delta: float) -> void:
	var target_db := -20.0 if enabled else -60.0
	_volume_db = lerpf(_volume_db, target_db, clampf(delta * 2.0, 0.0, 1.0))
	volume_db = _volume_db
	if not enabled:
		if _volume_db < -55.0 and playing:
			stop()
		return
	if not playing:
		play()
	var playback := get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var frames: int = playback.get_frames_available()
	if frames <= 0:
		return
	var step := 1.0 / MIX_RATE
	for i in frames:
		_time += step
		var drift := sin(_time * TAU * 0.021)
		var swell := 0.5 + 0.5 * sin(_time * TAU * 0.013)
		_phase_a += TAU * (55.0 + drift * 1.5) * step
		_phase_b += TAU * (82.41 + drift * 2.0) * step
		_phase_c += TAU * (110.0 + drift * 2.5) * step
		_phase_d += TAU * (164.81 + drift * 3.0) * step
		var sample := sin(_phase_a) * 0.30
		sample += sin(_phase_b) * 0.20 * swell
		sample += sin(_phase_c) * 0.14
		sample += sin(_phase_d) * 0.07 * (1.0 - swell)
		sample += sin(_time * TAU * 0.37) * 0.025 * swell
		sample = clampf(sample, -1.0, 1.0)
		playback.push_frame(Vector2(sample, sample))
