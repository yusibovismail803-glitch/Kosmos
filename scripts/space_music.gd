extends AudioStreamPlayer

const MIX_RATE := 22050
const LOOP_SECONDS := 16.0
const TARGET_DB := -6.0
const SILENT_DB := -60.0

var enabled := true

var _volume_db := SILENT_DB


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stream = _make_galaxy_loop()
	volume_db = _volume_db
	play()


func set_enabled(value: bool) -> void:
	enabled = value
	if enabled and not playing:
		play()


func _exit_tree() -> void:
	stop()
	stream = null


func _process(delta: float) -> void:
	var target_db := TARGET_DB if enabled else SILENT_DB
	_volume_db = lerpf(_volume_db, target_db, clampf(delta * 1.6, 0.0, 1.0))
	volume_db = _volume_db
	if not enabled:
		if _volume_db < SILENT_DB + 4.0 and playing:
			stop()
		return
	if not playing:
		play()


func _make_galaxy_loop() -> AudioStreamWAV:
	var frames := int(MIX_RATE * LOOP_SECONDS)
	var data := PackedByteArray()
	data.resize(frames * 4)
	var step := 1.0 / float(MIX_RATE)
	var phases := [0.0, 0.0, 0.0, 0.0]
	var air_a := 0.0
	var air_b := 0.0
	var left_phase := 0.0
	var right_phase := 0.0
	var freqs := [32.75, 65.4375, 77.8125, 98.0]
	var amps := [0.24, 0.18, 0.14, 0.09]
	for i in frames:
		var t := float(i) * step
		var breath := 0.5 + 0.5 * sin(TAU * t * 0.0625)
		var pulse := 0.5 + 0.5 * sin(TAU * t * 0.125)
		var drift := sin(TAU * t * 0.1875)
		var sample := 0.0
		for v in freqs.size():
			phases[v] += TAU * (freqs[v] + drift * (0.12 + v * 0.05)) * step
			sample += sin(phases[v]) * amps[v] * (0.72 + 0.28 * breath)
		air_a += TAU * (155.5625 + drift * 0.2) * step
		air_b += TAU * (233.0625 + drift * 0.3) * step
		sample += sin(air_a) * 0.028 * (0.35 + 0.65 * breath)
		sample += sin(air_b) * 0.016 * (0.3 + 0.7 * pulse)
		sample += sin(TAU * t * 0.25) * 0.02
		left_phase += TAU * 0.03125 * step
		right_phase += TAU * 0.046875 * step
		var left := sample + sin(left_phase) * 0.055 * pulse
		var right := sample + sin(right_phase) * 0.055 * breath
		left = tanh(left * 1.5) * 0.9
		right = tanh(right * 1.5) * 0.9
		data.encode_s16(i * 4, int(clampf(left, -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 4 + 2, int(clampf(right, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = true
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav
