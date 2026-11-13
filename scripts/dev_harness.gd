extends Node
## 개발용 자동 플레이/스크린샷/밸런스 로그. 실행 인자가 있을 때만 붙는다.
##   --autoplay         : 봇이 이동하고 레벨업 첫 번째 선택지를 고른다
##   --god              : 무적
##   --start=290        : 해당 초부터 시작
##   --weapons=a,b,c    : 무기 추가 장착      --wlevel=5 : 모든 무기 레벨
##   --shots=10,60      : 해당 초에 스크린샷   --shotdir=/path
##   --timescale=3      : 배속                 --quit_after=120 : 해당 초에 요약 출력 후 종료

var world: Node
var shots: Array = []
var shot_dir := "user://shots"
var quit_after := -1.0
var _taken := {}
var _lu_t := 0.0
var _stat_next := 30.0
var _orbit_sign := 1.0
var _quitting := false
var _last_boss_kills := 0
var _last_music := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var d: Dictionary = world.dev
	if d.has("shots"):
		for s in String(d["shots"]).split(","):
			shots.append(float(s))
	shot_dir = String(d.get("shotdir", "user://shots"))
	DirAccess.make_dir_recursive_absolute(shot_dir)
	quit_after = float(d.get("quit_after", -1.0))
	if d.has("timescale"):
		Engine.time_scale = float(d["timescale"])
	if d.has("weapons"):
		for id in String(d["weapons"]).split(","):
			if DB.WEAPONS.has(id) and world.get_weapon(id) == null:
				world.add_weapon(id)
	if d.has("wlevel"):
		for w in world.weapons:
			w.set_level(int(d["wlevel"]))
	if d.has("passives"):
		for id in String(d["passives"]).split(","):
			if DB.PASSIVES.has(id):
				world.passives[id] = int(d.get("plevel", 1))
		world.player.recalc(world.passives, world.mods)
	_stat_next = world.t + 30.0
	var loaded: Array = []
	for k in Audio._music.keys():
		if Audio._music[k] != null:
			loaded.append(k)
	for k in Audio._streams.keys():
		if Audio._streams[k] != null:
			loaded.append(k)
	print("[audio] loaded %d: %s  now playing: %s" % [loaded.size(), ",".join(PackedStringArray(loaded)), Audio._current])

func _process(delta: float) -> void:
	if _quitting:
		return
	var d: Dictionary = world.dev
	if d.has("autoplay") and not world.finished:
		world.player.ai_dir = _bot_dir()
	if world.levelup_panel.is_open():
		if d.has("shot_levelup") and not _taken.has("lu") and _lu_t > 0.35:
			_taken["lu"] = true
			_capture("levelup")
		_lu_t += delta
		if _lu_t > (1.0 if d.has("shot_levelup") and not _taken.has("lu") else 0.4) and d.has("autoplay"):
			_lu_t = 0.0
			world.levelup_panel.choose(0)
	else:
		_lu_t = 0.0
	if d.has("shot_options") and world.t >= float(d["shot_options"]) and not _taken.has("opt"):
		_taken["opt"] = true
		world.pause_menu._show()
		_capture("pause")
		await get_tree().create_timer(0.3, true, false, true).timeout
		world.pause_menu._open_options()
		await get_tree().create_timer(0.3, true, false, true).timeout
		_capture("pause_options")
	for s in shots:
		if world.t >= float(s) and not _taken.has(s):
			_taken[s] = true
			_capture(("t%04d" % int(s)) if is_equal_approx(float(s), roundf(float(s))) else ("t%06.1f" % float(s)))
	if Audio._current != _last_music:
		_last_music = Audio._current
		print("[music] t=%.0f -> %s" % [world.t, _last_music])
	if world.boss_kills != _last_boss_kills:
		_last_boss_kills = world.boss_kills
		print("[boss down] t=%.1f" % world.t)
	if world.t >= _stat_next:
		_stat_next += 30.0
		print(_summary())
	if quit_after > 0.0 and (world.t >= quit_after or (world.finished and get_tree().paused)):
		_quitting = true
		print("[final] ", _summary())
		if world.finished and d.has("shot_result"):
			await get_tree().create_timer(0.6, true, false, true).timeout
			await _capture("result")
		await get_tree().create_timer(0.3, true, false, true).timeout
		get_tree().quit()

func _summary() -> String:
	var hp: float = world.player.hp
	var wl: Array = []
	for w in world.weapons:
		wl.append("%s:%d" % [w.id, w.level])
	var boss := "-"
	if world.boss_ref != null and is_instance_valid(world.boss_ref):
		boss = "%s %.0f%%" % [world.boss_ref.kind, 100.0 * float(world.boss_ref.hp) / float(world.boss_ref.max_hp)]
	return "t=%.0f lv=%d hp=%.0f kills=%d bosses=%d enemies=%d proj=%d gems=%d fps=%d boss=%s weapons=%s passives=%s" % [
		world.t, world.level, hp, world.kills, world.boss_kills, world.enemies.size(), world.projectiles.size(), world._gems,
		Engine.get_frames_per_second(), boss, ",".join(PackedStringArray(wl)), str(world.passives)]

func _bot_dir() -> Vector2:
	var p: Vector2 = world.player.position
	var push := Vector2.ZERO
	var melee := String(world.cdata["start_weapon"]) != "qpcr_beam"
	var keep := 95.0 if melee else 240.0
	for e in world.query(p, keep):
		var d: Vector2 = p - (e as Node2D).position
		var l := maxf(d.length(), 1.0)
		push += d / l * (keep / l) * (3.0 if e.is_boss else 1.0)
	for b in world.ebullets:
		var d: Vector2 = p - (b as Node2D).position
		if d.length() < 120.0:
			push += d.normalized() * 2.0
	var tangent := p.orthogonal().normalized() * _orbit_sign if p.length() > 50.0 else Vector2.RIGHT
	var home := -p.normalized() * clampf((p.length() - 900.0) / 600.0, 0.0, 2.0)
	var gem := Vector2.ZERO
	var best := 400.0 * 400.0
	for pk in world.pickups:
		var dd: float = (pk as Node2D).position.distance_squared_to(p)
		if dd < best:
			best = dd
			gem = ((pk as Node2D).position - p).normalized() * 1.3
	var dir := push * 1.4 + tangent * 0.8 + home + gem
	if dir.length() < 0.05:
		return Vector2.ZERO
	return dir.normalized()

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := shot_dir.path_join(name + ".png")
	img.save_png(path)
	print("[shot] ", path)
