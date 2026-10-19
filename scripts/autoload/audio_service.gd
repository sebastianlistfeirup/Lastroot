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
## Up to this many variants per cue: <cue>.wav, <cue>_2.wav, <cue>_3.wav ...
const MAX_VARIANTS := 4
## Cues that briefly lower the music, and by how much (dB).
const DUCK := {"heart_hit": -9.0, "boss_arrive": -12.0, "defeat": -10.0, "victory": -8.0}
const MUSIC_DB := -6.0
## Frequent cues get a small random pitch spread (presentation only).
const PITCH_SPREAD := {"hit": 0.06, "attack_bark": 0.05, "attack_spore": 0.05, "attack_enemy": 0.05, "ui_click": 0.04,
	"card_play": 0.04, "poison_tick": 0.08, "thorns": 0.06}

var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_id: String = ""
var _cache: Dictionary = {}
var _last_play: Dictionary = {}
var _next_voice: int = 0
## Presentation-only randomness (variant / pitch choice); never gameplay RNG.
var _rng := RandomNumberGenerator.new()
var _variants: Dictionary = {}  # cue -> [cue ids that exist]
var _duck_tween: Tween


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
	_music.volume_db = MUSIC_DB
	_rng.randomize()
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


## Existing takes of a cue: the cue itself plus <cue>_2 ... <cue>_N.
func variants(cue_id: String) -> Array:
	if not _variants.has(cue_id):
		var out: Array = []
		if cue_path(cue_id) != "":
			out.append(cue_id)
		for i in range(2, MAX_VARIANTS + 1):
			var v: String = "%s_%d" % [cue_id, i]
			if cue_path(v) != "":
				out.append(v)
		_variants[cue_id] = out
	return _variants[cue_id]


## One-shot sound effect. "music_*" ids start that music loop instead (so the
## battle's AudioBridge.play("music_battle") works). Unknown cues are ignored.
func play(cue_id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if cue_id.begins_with("music_"):
		play_music(cue_id)
		return
	var takes: Array = variants(cue_id)
	if takes.is_empty():
		return
	var take: String = takes[_rng.randi() % takes.size()] if takes.size() > 1 else takes[0]
	var s: AudioStream = stream(take)
	if s == null:
		return
	if PITCH_SPREAD.has(cue_id) and pitch == 1.0:
		var sp: float = float(PITCH_SPREAD[cue_id])
		pitch = _rng.randf_range(1.0 - sp, 1.0 + sp)
	if DUCK.has(cue_id):
		duck(float(DUCK[cue_id]), s.get_length())
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


## Lowers the music by `db` for about `hold` seconds, then eases it back.
func duck(db: float, hold: float = 0.6) -> void:
	if _music == null or not _music.playing:
		return
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(_music, "volume_db", MUSIC_DB + db, 0.08)
	_duck_tween.tween_interval(clampf(hold, 0.2, 2.0))
	_duck_tween.tween_property(_music, "volume_db", MUSIC_DB, 0.6)


func is_ducked() -> bool:
	return _music != null and _music.volume_db < MUSIC_DB - 0.5
