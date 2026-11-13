extends Node
## 효과음/BGM. 소리는 전부 tools/make_audio.py로 새로 합성한 오리지널.
##   음악: title / run / boss (루프)  ·  징글: victory / defeat
##   효과음: ui_move, ui_select, hurt, pickup, levelup, enemy_die, gift, boss_warn, heal, boss_hit_big

const SFX := ["ui_move", "ui_select", "hurt", "pickup", "levelup", "enemy_die", "gift", "boss_warn", "heal", "boss_hit_big"]
const MUSIC := ["title", "run", "boss"]
const STINGERS := ["victory", "defeat"]
const POOL_SIZE := 12
const FADE := 0.8

var _streams := {}
var _music := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current := ""
var _stinger: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in SFX:
		_streams[k] = _try_load("res://assets/audio/%s.wav" % k)
	for k in MUSIC + STINGERS:
		var s: Variant = _try_load("res://assets/audio/%s.ogg" % k)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = k in MUSIC
		_music[k] = s
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_stinger = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)
	add_child(_stinger)

func _try_load(path: String) -> Variant:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _vol(kind: String) -> float:
	return clampf(float(Save.setting("master")) * float(Save.setting(kind)), 0.0, 1.0)

func _db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))

## 효과음. volume은 0~1, pitch_var는 무작위 음높이 폭, min_gap은 같은 소리 최소 간격(초)
func play(name: String, volume := 1.0, pitch_var := 0.0, min_gap := 0.04) -> void:
	var s: Variant = _streams.get(name)
	if not (s is AudioStream):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(name, -10.0)) < min_gap:
		return
	_last_played[name] = now
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = _db(_vol("sfx") * volume)
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

## 배경음악 전환(크로스페이드). 같은 곡이면 그대로 둔다.
func play_music(track := "title") -> void:
	if track == _current:
		return
	var s: Variant = _music.get(track)
	if not (s is AudioStream):
		return
	_current = track
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_music_a.stream = s
	_music_a.volume_db = -60.0
	_music_a.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_music_a, "volume_db", _db(_vol("music")), FADE)
	if _music_b.playing:
		tw.tween_property(_music_b, "volume_db", -60.0, FADE)
		tw.chain().tween_callback(_music_b.stop)

func stop_music() -> void:
	_current = ""
	var tw := create_tween()
	tw.set_parallel(true)
	for p in [_music_a, _music_b]:
		if p.playing:
			tw.tween_property(p, "volume_db", -60.0, 0.5)
	tw.chain().tween_callback(func() -> void:
		_music_a.stop()
		_music_b.stop())

## 결과 징글: 음악을 멈추고 한 번 재생
func play_stinger(name: String) -> void:
	var s: Variant = _music.get(name)
	if not (s is AudioStream):
		return
	stop_music()
	_stinger.stream = s
	_stinger.volume_db = _db(_vol("music") * 1.2)
	_stinger.play()

func apply_volume() -> void:
	if _current != "" and _music_a:
		_music_a.volume_db = _db(_vol("music"))
