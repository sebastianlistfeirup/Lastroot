extends Node
## Sound cues and music (docs/AUDIO_LEDGER.csv lists every cue). Lookup order:
## assets/audio/final/<cue>.ogg -> final/<cue>.wav -> placeholder/<cue>.wav, so
## dropping a finished file into final/ replaces a placeholder with no code
## change. Presentation only: sound never decides or delays game state.

const FINAL_DIR := "res://assets/audio/final/"
const PLACEHOLDER_DIR := "res://assets/audio/placeholder/"
const BUSES: PackedStringArray = ["Music", "SFX"]
const VOICES := 10
## Same cue at most this often (ms), so rapid events never machine-gun.
const MIN_REPEAT_MS := 45

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_id: String = ""
var _cache: Dictionary = {}
var _last_play: Dictionary = {}
var _next_voice: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	setup_buses()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -6.0
	add_child(_music)
	SettingsService.apply()


static func setup_buses() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")


## Resolved resource path for a cue, or "" when no file exists.
static func cue_path(cue_id: String) -> String:
	for cand: String in [FINAL_DIR + cue_id + ".ogg", FINAL_DIR + cue_id + ".wav", PLACEHOLDER_DIR + cue_id + ".wav"]:
		if ResourceLoader.exists(cand):
			return cand
	return ""


func stream(cue_id: String) -> AudioStream:
	if _cache.has(cue_id):
		return _cache[cue_id]
	var p: String = cue_path(cue_id)
	var s: AudioStream = null
	if p != "":
		s = load(p) as AudioStream
	if s != null and cue_id.begins_with("music_"):
		if s is AudioStreamOggVorbis:
			var o: AudioStreamOggVorbis = (s as AudioStreamOggVorbis).duplicate()
			o.loop = true
			s = o
		elif s is AudioStreamWAV:
			var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate()
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
			s = w
	_cache[cue_id] = s
	return s


func has_cue(cue_id: String) -> bool:
	return stream(cue_id) != null


## One-shot sound effect. Unknown cues are ignored (logged once in debug).
func play(cue_id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = stream(cue_id)
	if s == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play.get(cue_id, -100000)) < MIN_REPEAT_MS:
		return
	_last_play[cue_id] = now
	var p: AudioStreamPlayer = null
	for cand: AudioStreamPlayer in _players:
		if not cand.playing:
			p = cand
			break
	if p == null:  # all busy: steal round-robin
		p = _players[_next_voice % _players.size()]
		_next_voice += 1
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_music(track_id: String) -> void:
	if track_id == _music_id and _music.playing:
		return
	var s: AudioStream = stream(track_id)
	_music_id = track_id
	if s == null:
		_music.stop()
		return
	_music.stream = s
	_music.play()


func stop_music() -> void:
	_music_id = ""
	_music.stop()


func current_music() -> String:
	return _music_id
