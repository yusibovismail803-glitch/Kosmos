extends AudioStreamPlayer

const MUSIC_PATH := "res://adjuntos/dark_cosmos_ost_60s.wav"
const TARGET_DB := -6.0
const SILENT_DB := -60.0

var enabled := true

var _volume_db := SILENT_DB


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var wav := load(MUSIC_PATH) as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		stream = wav
	volume_db = _volume_db
	if _can_play():
		play()


func set_enabled(value: bool) -> void:
	enabled = value
	if enabled and not playing and _can_play():
		play()


func _can_play() -> bool:
	return DisplayServer.get_name() != "headless"


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
	if not playing and _can_play():
		play()
