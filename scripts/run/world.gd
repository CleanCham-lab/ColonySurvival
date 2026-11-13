extends Node2D
## 한 판(런)의 모든 것: 시간, 스폰 디렉터, 충돌, 드롭, 레벨업, 보스, 종료.

signal run_finished(result: Dictionary)
signal quit_to_title

const Player = preload("res://scripts/run/player.gd")
const Enemy = preload("res://scripts/run/enemy.gd")
const Boss = preload("res://scripts/run/boss.gd")
const Projectile = preload("res://scripts/run/projectile.gd")
const EnemyBullet = preload("res://scripts/run/enemy_bullet.gd")
const Pickup = preload("res://scripts/run/pickup.gd")
const Zone = preload("res://scripts/run/zone.gd")
const Background = preload("res://scripts/run/background.gd")
const FX = preload("res://scripts/run/fx.gd")
const Telegraphs = preload("res://scripts/run/telegraphs.gd")
const HUD = preload("res://scripts/ui/hud.gd")
const LevelUpPanel = preload("res://scripts/ui/level_up_panel.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const DevHarness = preload("res://scripts/dev_harness.gd")

const WEAPON_SCRIPTS := {
	"qpcr_beam": preload("res://scripts/run/weapons/qpcr_beam.gd"),
	"gel_cutter": preload("res://scripts/run/weapons/gel_cutter.gd"),
	"crispr_lance": preload("res://scripts/run/weapons/crispr_lance.gd"),
	"lentiviral_orb": preload("res://scripts/run/weapons/lentiviral_orb.gd"),
	"nanopore_ring": preload("res://scripts/run/weapons/nanopore_ring.gd"),
	"lysozyme_field": preload("res://scripts/run/weapons/lysozyme_field.gd"),
	"etoh_splash": preload("res://scripts/run/weapons/etoh_splash.gd"),
	"uv_flash": preload("res://scripts/run/weapons/uv_flash.gd"),
	"antibody_chain": preload("res://scripts/run/weapons/antibody_chain.gd"),
	"centrifuge_wave": preload("res://scripts/run/weapons/centrifuge_wave.gd"),
}

const CELL := 80.0
const QUERY_PAD := 72.0
const MAX_GEMS := 450

var char_id := "hek293t"
var cdata: Dictionary
var dev: Dictionary = {}
var mode := "normal"
var zone := "dish"
var difficulty := "normal"
var diff: Dictionary = {}
var mods: Dictionary = {}
var daily: Dictionary = {}
var max_weapons := DB.MAX_WEAPONS
var _xp_frac := 0.0
var _endless_next := 1200.0
var _endless_idx := 0
var _uv_timer := 45.0
var _uv_warned := false
var t := 0.0
var finished := false
var player: Node2D
var camera: Camera2D
var fx: Node2D
var telegraphs: Node2D
var background: Node2D
var hud: CanvasLayer
var levelup_panel: CanvasLayer
var pause_menu: CanvasLayer

var _layer_pickups: Node2D
var _layer_enemies: Node2D
var _layer_proj: Node2D
var _layer_ebullets: Node2D
var _layer_zones: Node2D

var enemies: Array = []
var projectiles: Array = []
var ebullets: Array = []
var pickups: Array = []
var zones: Array = []
var droplets: Array = []
var shards: Array = []
var _grid := {}
var _spawn_queue: Array = []
var _scheduled: Array = []

var spawn_timer := 1.0
var event_idx := 0
var tipbox_timer := 25.0
var kills := 0
var boss_kills := 0
var level := 1
var xp := 0
var xp_next := 10
var pending_levelups := 0
var rerolls := DB.BASE_REROLLS
var weapons: Array = []
var passives: Dictionary = {}
var boss_ref: Node2D = null
var _boss_queue: Array = []
var papers: Array = []
var _shake := 0.0
var _gems := 0

## cfg: {"char", "mode", "zone", "difficulty", "dev"}
func setup(cfg: Dictionary) -> void:
	char_id = String(cfg.get("char", "hek293t"))
	cdata = DB.CHARACTERS[char_id]
	dev = cfg.get("dev", {})
	mode = String(cfg.get("mode", "normal"))
	zone = String(cfg.get("zone", "dish"))
	difficulty = String(cfg.get("difficulty", "normal"))
	diff = DB.DIFFICULTY.get(difficulty, DB.DIFFICULTY["normal"])
	if mode == "daily":
		daily = DB.daily_for(DB.today_key())
	mods = _compute_mods()

## 연구실 상점 강화 + 오늘의 실험 조건을 하나의 배율 표로 합친다
func _compute_mods() -> Dictionary:
	var m := {"hp_add": 0.0, "hp_mult": 1.0, "damage": 1.0, "cooldown": 1.0, "speed": 1.0, "magnet": 1.0, "area": 1.0,
		"duration": 1.0, "proj_speed": 1.0, "pierce": 0, "xp": 1.0, "enemy_hp": 1.0, "enemy_speed": 1.0, "spawn_extra": 0, "weapon_slots": 0}
	m["hp_add"] = 10.0 * Save.upgrade("culture")
	m["damage"] = 1.0 + 0.05 * Save.upgrade("reagent")
	m["cooldown"] = 1.0 - 0.03 * Save.upgrade("pipette")
	m["speed"] = 1.0 + 0.04 * Save.upgrade("shoes")
	m["magnet"] = 1.0 + 0.10 * Save.upgrade("magnet")
	m["xp"] = 1.0 + 0.08 * Save.upgrade("growth")
	if not daily.is_empty():
		for src in [daily["buff"], daily["debuff"]]:
			for k in (src as Dictionary).keys():
				if k == "name" or not m.has(k):
					continue
				if k in ["hp_add", "pierce", "spawn_extra", "weapon_slots"]:
					m[k] = m[k] + src[k]
				else:
					m[k] = float(m[k]) * float(src[k])
	return m

func _ready() -> void:
	if dev.has("seed"):
		seed(int(dev["seed"]))
	xp_next = DB.xp_to_next(level)
	_build_map()
	background = Background.new()
	background.setup(droplets, shards, zone)
	add_child(background)
	_layer_zones = _layer("Zones", -1)
	_layer_pickups = _layer("Pickups", 0)
	_layer_enemies = _layer("Enemies", 1)
	player = Player.new()
	player.setup(self, cdata)
	player.revives += Save.upgrade("backup")
	rerolls = DB.BASE_REROLLS + Save.upgrade("notebook")
	max_weapons = DB.MAX_WEAPONS + int(mods["weapon_slots"])
	player.z_index = 2
	add_child(player)
	_layer_proj = _layer("Projectiles", 3)
	telegraphs = Telegraphs.new()
	add_child(telegraphs)
	_layer_ebullets = _layer("EnemyBullets", 5)
	fx = FX.new()
	add_child(fx)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	# 현미경 시야 비네팅
	var vig := CanvasLayer.new()
	vig.layer = 1
	add_child(vig)
	var tr := TextureRect.new()
	tr.texture = UIKit.vignette_tex
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.add_child(tr)
	hud = HUD.new()
	hud.world = self
	add_child(hud)
	levelup_panel = LevelUpPanel.new()
	levelup_panel.world = self
	add_child(levelup_panel)
	pause_menu = PauseMenu.new()
	pause_menu.world = self
	add_child(pause_menu)
	add_weapon(String(cdata["start_weapon"]))
	player.recalc(passives, mods)
	if dev.has("start"):
		t = float(dev["start"])
		while event_idx < DB.EVENTS.size() and float((DB.EVENTS[event_idx] as Dictionary)["t"]) < t:
			event_idx += 1
	if dev.size() > 0:
		var h := DevHarness.new()
		h.world = self
		add_child(h)
	match mode:
		"endless":
			toast("야근 모드 — 끝은 없다. 얼마나 버틸까?", DB.C_TEXT)
		"daily":
			toast("오늘의 실험 조건: %s / %s" % [daily["buff"]["name"], daily["debuff"]["name"]], DB.C_TEXT)
		_:
			toast("12월 24일 18:00 — 모두 퇴근했다. 아침 9시까지 버텨라.", DB.C_TEXT)
	if zone == "hood":
		toast("클린벤치 — 층류가 아래로 밀어낸다", DB.C_ALLY)

func _layer(n: String, z: int) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.z_index = z
	add_child(l)
	return l

func _build_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(dev.get("seed", randi()))
	if zone == "hood":
		_build_hood(rng)
		return
	for i in 5:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(500.0, DB.DISH_RADIUS - 300.0)
		droplets.append({"pos": p, "r": rng.randf_range(70.0, 100.0)})
	for i in 6:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(450.0, DB.DISH_RADIUS - 250.0)
		var r := rng.randf_range(38.0, 62.0)
		var pts := PackedVector2Array()
		var n := rng.randi_range(4, 6)
		var a0 := rng.randf() * TAU
		for k in n:
			pts.append(p + Vector2.from_angle(a0 + TAU * k / n + rng.randf_range(-0.25, 0.25)) * r * rng.randf_range(0.8, 1.25))
		shards.append({"pos": p, "r": r, "pts": pts})

func _build_hood(rng: RandomNumberGenerator) -> void:
	var hs := DB.HOOD_SIZE * 0.5
	for i in 3:
		droplets.append({"pos": Vector2(rng.randf_range(-hs.x + 300, hs.x - 300), rng.randf_range(-hs.y + 300, hs.y - 300)), "r": rng.randf_range(60.0, 85.0)})
	# 튜브 랙·팁 박스 같은 장비(통과 불가)
	for i in 7:
		var p := Vector2(rng.randf_range(-hs.x + 350, hs.x - 350), rng.randf_range(-hs.y + 350, hs.y - 350))
		if p.length() < 300.0:
			p += Vector2(400, 0)
		var w := rng.randf_range(70.0, 120.0)
		var h := rng.randf_range(45.0, 70.0)
		var pts := PackedVector2Array([p + Vector2(-w, -h) * 0.5, p + Vector2(w, -h) * 0.5, p + Vector2(w, h) * 0.5, p + Vector2(-w, h) * 0.5])
		shards.append({"pos": p, "r": (w + h) * 0.32, "pts": pts, "rack": true})

func in_bounds(p: Vector2, margin := 0.0) -> bool:
	if zone == "hood":
		var hs := DB.HOOD_SIZE * 0.5 - Vector2(margin, margin)
		return absf(p.x) < hs.x and absf(p.y) < hs.y
	return p.length() < DB.DISH_RADIUS - margin

func clamp_bounds(p: Vector2, margin := 0.0) -> Vector2:
	if zone == "hood":
		var hs := DB.HOOD_SIZE * 0.5 - Vector2(margin, margin)
		return Vector2(clampf(p.x, -hs.x, hs.x), clampf(p.y, -hs.y, hs.y))
	var lim := DB.DISH_RADIUS - margin
	if p.length() > lim:
		return p.normalized() * lim
	return p

# ── 메인 루프 ────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if finished:
		return
	t += delta
	_run_scheduled(delta)
	_cleanup()
	_update_director(delta)
	_rebuild_grid()
	player.tick(delta)
	if zone == "hood":
		_tick_hood(delta)
	_tick_droplets(delta)
	for w in weapons:
		w.tick(delta)
	_update_enemies(delta)
	for p in projectiles:
		if not p.dead:
			p.tick(delta, self)
	for b in ebullets:
		if not b.dead:
			b.tick(delta, player)
	for z in zones:
		if not z.dead:
			z.tick(delta, self)
	_update_pickups(delta)
	_flush_spawn_queue()
	_update_camera(delta)
	_check_end()

func _cleanup() -> void:
	enemies = _sweep(enemies)
	projectiles = _sweep(projectiles)
	ebullets = _sweep(ebullets)
	zones = _sweep(zones)
	pickups = _sweep(pickups)

func _sweep(arr: Array) -> Array:
	var keep: Array = []
	for o in arr:
		if o.dead:
			o.queue_free()
		else:
			keep.append(o)
	return keep

func schedule(delay: float, cb: Callable) -> void:
	_scheduled.append({"t": delay, "cb": cb})

func _run_scheduled(delta: float) -> void:
	if _scheduled.is_empty():
		return
	var due: Array = []
	var keep: Array = []
	for s in _scheduled:
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0:
			due.append(s)
		else:
			keep.append(s)
	_scheduled = keep
	for s in due:
		var cb: Callable = s["cb"]
		if cb.is_valid():
			cb.call()

# ── 스폰 디렉터 ──────────────────────────────────────────────
func _update_director(delta: float) -> void:
	while event_idx < DB.EVENTS.size() and t >= float((DB.EVENTS[event_idx] as Dictionary)["t"]):
		_fire_event(DB.EVENTS[event_idx])
		event_idx += 1
	if mode == "endless" and t >= _endless_next:
		var bid: String = DB.ENDLESS_BOSS_CYCLE[_endless_idx % DB.ENDLESS_BOSS_CYCLE.size()]
		_endless_idx += 1
		_endless_next += 300.0
		toast("야근 %d회차 — %s가 더 강해져 돌아왔다" % [_endless_idx, DB.BOSSES[bid]["name"]], DB.C_WARN)
		if _alive_boss() != null:
			_boss_queue.append(bid)
		else:
			spawn_boss(bid)
	var wave := DB.wave_at(t)
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var overtime := maxf(0.0, (t - DB.RUN_LENGTH) / 60.0)
		spawn_timer = float(wave["interval"]) / float(diff["spawn"]) * maxf(0.55, 1.0 - overtime * 0.03)
		var cap := mini(int(float(wave["max"]) * float(diff["spawn"])), 340)
		if mode != "endless" and t >= DB.RUN_LENGTH:
			# 최종 심사: 보스에 집중할 수 있게 잡몹을 확 줄인다
			cap = mini(cap, 60)
			spawn_timer *= 2.0
		var alive := enemies.size()
		var pool: Dictionary = wave["pool"]
		for i in int(wave["batch"]) + int(mods["spawn_extra"]):
			if alive >= cap:
				break
			spawn_enemy_at(_pick_weighted(pool), _spawn_pos(), false)
			alive += 1
	tipbox_timer -= delta
	if tipbox_timer <= 0.0:
		tipbox_timer = randf_range(35.0, 50.0)
		var p := player.position + Vector2.from_angle(randf() * TAU) * randf_range(250.0, 450.0)
		if in_bounds(p, 80.0):
			spawn_enemy_at("tipbox", p, false)

func _fire_event(ev: Dictionary) -> void:
	var msg := String(ev.get("toast", ""))
	if msg != "":
		toast(msg, DB.C_WARN)
	match String(ev["type"]):
		"elite":
			spawn_enemy_at(String(ev["kind"]), _spawn_pos(), true)
		"ring":
			var n := int(ev["count"])
			for i in n:
				var p := player.position + Vector2.from_angle(TAU * i / n) * 430.0
				_spawn_queue.append({"kind": String(ev["kind"]), "pos": clamp_bounds(p, 30.0), "elite": false})
		"burst":
			var c := _spawn_pos()
			for i in int(ev["count"]):
				_spawn_queue.append({"kind": String(ev["kind"]), "pos": clamp_bounds(c + Vector2(randf_range(-120, 120), randf_range(-120, 120)), 30.0), "elite": false})
		"boss":
			if _alive_boss() != null:
				_boss_queue.append(String(ev["kind"]))  # 앞 보스가 살아 있으면 처치 후 등장
			else:
				spawn_boss(String(ev["kind"]))

func _alive_boss() -> Node2D:
	for e in enemies:
		if e.is_boss and not e.dead:
			return e
	return null

func _pick_weighted(pool: Dictionary) -> String:
	var total := 0.0
	for k in pool.keys():
		total += float(pool[k])
	var r := randf() * total
	for k in pool.keys():
		r -= float(pool[k])
		if r <= 0.0:
			return String(k)
	return String(pool.keys()[0])

func _view_half() -> Vector2:
	return get_viewport_rect().size * 0.5 / camera.zoom

func _spawn_pos() -> Vector2:
	var half := _view_half()
	var ring := half.length() + 60.0
	var moving: bool = player.move_dir.length() > 0.3
	for i in 10:
		var ang := randf() * TAU
		# 절반은 이동 방향 앞쪽에 스폰 → 원을 그리며 도망만 다니는 플레이를 막는다
		if moving and randf() < 0.5:
			ang = player.move_dir.angle() + randf_range(-0.9, 0.9)
		var p := player.position + Vector2.from_angle(ang) * ring
		if in_bounds(p, 40.0):
			return p
	return clamp_bounds(player.position + Vector2.from_angle(randf() * TAU) * ring, 40.0)

func spawn_enemy_at(kind: String, pos: Vector2, elite: bool) -> Node2D:
	var minute := t / 60.0
	var e := Enemy.new()
	var hp_scale := (1.0 + DB.HP_SCALE_PER_MIN * minute) * float(diff["enemy_hp"]) * float(mods["enemy_hp"])
	var dmg_scale := (1.0 + DB.DMG_SCALE_PER_MIN * minute) * float(diff["enemy_dmg"])
	e.setup(self, kind, hp_scale, dmg_scale, elite)
	e.speed *= float(mods["enemy_speed"])
	e.position = pos
	_layer_enemies.add_child(e)
	enemies.append(e)
	return e

func spawn_boss(id: String) -> void:
	var b := Boss.new()
	var hp_scale := float(diff["boss_hp"]) * float(mods["enemy_hp"])
	if mode == "endless" and t > DB.RUN_LENGTH + 10.0:
		hp_scale *= 1.0 + 0.6 * _endless_idx
	b.setup_boss(self, id, hp_scale)
	if dev.has("boss_hp"):  # 개발용: 보스를 HP 일부만 남긴 채로 등장(후반 패턴 확인)
		b.hp = b.max_hp * float(dev["boss_hp"])
	b.contact *= float(diff["enemy_dmg"])
	var dir := Vector2.from_angle(randf() * TAU)
	b.position = clamp_bounds(player.position + dir * 330.0, 120.0)
	_layer_enemies.add_child(b)
	enemies.append(b)
	boss_ref = b
	if id == "reviewer2" and mode != "endless":
		_quiet_dish()
	shake(8.0)
	Audio.play("boss_warn")
	Audio.play_music("boss")

## 최종 심사 시작: 화면의 잡몹이 모두 사라지고(경험치는 일부 남김) 보스만 남는다
func _quiet_dish() -> void:
	var view := _view_half().length() + 200.0
	var n := 0
	for e in enemies:
		if e.dead or e.is_boss:
			continue
		e.dead = true
		e.visible = false
		if n < 70 and e.position.distance_to(player.position) < view:
			fx.burst(e.position, e.col, float(e.radius))
			n += 1
		if e.xp_value > 0 and randf() < 0.35:
			_drop(e.position, "gem", int(e.xp_value))
	for b in ebullets:
		b.dead = true
	fx.ring(player.position, DB.C_WARN, 30.0, 900.0, 1.0, 6.0)
	toast("최종 심사 시작 — 모든 배양이 숨을 죽였다", DB.C_WARN)

func _flush_spawn_queue() -> void:
	if _spawn_queue.is_empty():
		return
	var q := _spawn_queue
	_spawn_queue = []
	for s in q:
		spawn_enemy_at(String(s["kind"]), s["pos"], bool(s["elite"]))

# ── 공간 해시 / 질의 ─────────────────────────────────────────
func _rebuild_grid() -> void:
	_grid.clear()
	for e in enemies:
		if e.dead:
			continue
		var k := Vector2i(floori(e.position.x / CELL), floori(e.position.y / CELL))
		if _grid.has(k):
			(_grid[k] as Array).append(e)
		else:
			_grid[k] = [e]

func query(pos: Vector2, radius: float) -> Array:
	var out: Array = []
	var x0 := floori((pos.x - radius - QUERY_PAD) / CELL)
	var x1 := floori((pos.x + radius + QUERY_PAD) / CELL)
	var y0 := floori((pos.y - radius - QUERY_PAD) / CELL)
	var y1 := floori((pos.y + radius + QUERY_PAD) / CELL)
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var k := Vector2i(cx, cy)
			if not _grid.has(k):
				continue
			for e in _grid[k]:
				if e.dead:
					continue
				var rr: float = radius + e.radius
				if e.position.distance_squared_to(pos) <= rr * rr:
					out.append(e)
	return out

func nearest_enemy(pos: Vector2, max_range: float, exclude: Dictionary) -> Variant:
	var best: Variant = null
	var bd := max_range * max_range
	for e in query(pos, max_range):
		if e.kind == "tipbox" or exclude.has(e.get_instance_id()):
			continue
		var d: float = e.position.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = e
	return best

func nearest_enemies(pos: Vector2, max_range: float, n: int) -> Array:
	var cands: Array = []
	for e in query(pos, max_range):
		if e.kind == "tipbox":
			continue
		cands.append([e.position.distance_squared_to(pos), e])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for i in mini(n, cands.size()):
		out.append(cands[i][1])
	return out

func strongest_enemies(pos: Vector2, max_range: float, n: int) -> Array:
	var cands: Array = []
	for e in query(pos, max_range):
		if e.kind == "tipbox":
			continue
		cands.append(e)
	cands.sort_custom(func(a: Node2D, b: Node2D) -> bool: return float(a.hp) > float(b.hp))
	return cands.slice(0, n)

func enemies_in_view() -> Array:
	var half := _view_half()
	var out: Array = []
	var c := camera.position
	for e in enemies:
		if e.dead or e.kind == "tipbox":
			continue
		var d: Vector2 = e.position - c
		if absf(d.x) < half.x and absf(d.y) < half.y:
			out.append(e)
	return out

# ── 적 갱신 ──────────────────────────────────────────────────
func _update_enemies(delta: float) -> void:
	var ppos := player.position
	var pr: float = player.radius
	for e in enemies:
		if e.dead:
			continue
		e.tick(delta, ppos)
		if e.dead:
			continue
		# 겹침 방지(최대 6개 이웃만 확인)
		if not e.is_boss and e.behavior != "static":
			var k := Vector2i(floori(e.position.x / CELL), floori(e.position.y / CELL))
			var checked := 0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var kk := Vector2i(k.x + dx, k.y + dy)
					if not _grid.has(kk):
						continue
					for o in _grid[kk]:
						if o == e or o.dead:
							continue
						var dvec: Vector2 = e.position - o.position
						var min_d: float = (e.radius + o.radius) * 0.9
						var dist2 := dvec.length_squared()
						if dist2 < min_d * min_d and dist2 > 0.0001:
							var dist := sqrt(dist2)
							e.position += dvec / dist * (min_d - dist) * (0.9 if o.is_boss else 0.5)
						checked += 1
						if checked >= 6:
							break
					if checked >= 6:
						break
				if checked >= 6:
					break
		e.position = resolve_obstacles(e.position, e.radius, true)
		# 접촉 피해
		if e.contact > 0.0:
			var rr: float = e.radius + pr * 0.85
			if e.position.distance_squared_to(ppos) < rr * rr:
				player.hurt(e.contact)

func resolve_obstacles(p: Vector2, r: float, soft := false) -> Vector2:
	for s in shards:
		var sp: Vector2 = s["pos"]
		if s.has("rack"):
			var pts: PackedVector2Array = s["pts"]
			var he: Vector2 = (pts[2] - pts[0]) * 0.5 + Vector2(r, r)
			var q := p - sp
			if absf(q.x) < he.x and absf(q.y) < he.y:
				var px := he.x - absf(q.x)
				var py := he.y - absf(q.y)
				if px < py:
					p.x = sp.x + signf(q.x if q.x != 0.0 else 1.0) * he.x
				else:
					p.y = sp.y + signf(q.y if q.y != 0.0 else 1.0) * he.y
			continue
		var sr: float = float(s["r"]) * 0.9 + r
		var d := p - sp
		var l2 := d.length_squared()
		if l2 < sr * sr and l2 > 0.0001:
			p = sp + d / sqrt(l2) * sr
	return clamp_bounds(p, r)

## 클린벤치: 층류 드리프트 + 주기적인 UV 램프
func _tick_hood(delta: float) -> void:
	var drift := DB.HOOD_AIRFLOW * delta
	player.position = clamp_bounds(player.position + drift, player.radius)
	for e in enemies:
		if not e.dead and not e.is_boss and e.behavior != "static":
			e.position += drift
	for b in ebullets:
		b.position += drift
	_uv_timer -= delta
	if _uv_timer <= 0.0:
		_uv_timer = randf_range(36.0, 48.0)
		var hs := DB.HOOD_SIZE * 0.5
		var band := 230.0
		var y := clampf(player.position.y + randf_range(-110.0, 110.0), -hs.y + band * 0.5, hs.y - band * 0.5)
		toast("UV 램프 점등! 경고 띠에서 벗어나라 (적도 맞는다)" if not _uv_warned else "UV 램프 점등!", DB.C_WARN)
		_uv_warned = true
		Audio.play("boss_warn", 0.5)
		telegraphs.add_line(Vector2(-hs.x, y), Vector2(hs.x, y), band, 1.7, DB.C_WARN, _uv_strike.bind(y, band))

func _uv_strike(y: float, band: float) -> void:
	var hs := DB.HOOD_SIZE * 0.5
	fx.uv_band(y, band, hs.x)
	shake(6.0)
	if absf(player.position.y - y) < band * 0.5:
		player.hurt(22.0)
	for e in enemies:
		if e.dead or absf(e.position.y - y) >= band * 0.5:
			continue
		var dmg: float = maxf(30.0, float(e.max_hp) * 0.45) if not e.is_boss else float(e.max_hp) * 0.025
		damage_enemy(e, dmg, Vector2.ZERO, 0.0, Color(0.75, 0.5, 1.0))

func _tick_droplets(delta: float) -> void:
	for d in droplets:
		if player.position.distance_to(d["pos"]) < float(d["r"]):
			player.heal(3.0 * delta)
			return

# ── 피해 / 처치 ──────────────────────────────────────────────
func damage_enemy(e: Node2D, amount: float, dir: Vector2, knock: float, c: Color) -> void:
	if e.dead:
		return
	var dmg: float = amount * float(e.armor_mult)
	e.hp -= dmg
	e.flash = 0.07
	if knock > 0.0 and dir != Vector2.ZERO:
		e.knock_vel += dir.normalized() * knock * float(e.knock_resist)
	fx.number(e.position + Vector2(0, -float(e.radius) - 6.0), dmg, c)
	if e.hp <= 0.0:
		_kill_enemy(e)

func _kill_enemy(e: Node2D) -> void:
	e.dead = true
	e.visible = false
	var c: Color = e.col
	fx.burst(e.position, DB.C_ENEMY if e.kind != "tipbox" else Color(0.6, 0.8, 1.0), float(e.radius))
	if e.kind == "tipbox":
		_drop(e.position, "cocoa" if randf() < 0.65 else "vortex", 1)
		return
	kills += 1
	Audio.play("enemy_die", 0.5, 0.25, 0.05)
	if e.is_boss:
		boss_kills += 1
		boss_ref = _alive_boss()
		Audio.play("boss_hit_big")
		if boss_ref == null:
			Audio.play_music("run")
		telegraphs.clear()
		_scheduled.clear()
		if boss_ref == null and not _boss_queue.is_empty():
			var nxt: String = _boss_queue.pop_front()
			schedule(4.0, func() -> void: spawn_boss(nxt))
			toast("…무언가 더 큰 것이 다가온다", DB.C_WARN)
		_drop(e.position, "gift", 3)
		if e.kind == "reviewer2" and mode != "endless":
			toast("Accepted with minor revisions — 논문 승인!", DB.C_GFP)
			schedule(1.8, func() -> void: _finish(true))
		fx.ring(e.position, c, 20.0, 420.0, 0.8, 8.0)
		shake(14.0)
		toast("%s 처치! 선물상자가 떨어졌다" % String(DB.BOSSES[e.kind]["name"]), DB.C_GFP)
		for b in ebullets:
			b.dead = true
		return
	if e.is_elite:
		_drop(e.position, "gift", 1)
	elif e.xp_value > 0:
		_drop(e.position, "gem", int(e.xp_value))
	# 감염 전파
	if e.infected > 0.0 and e.infect_spread > 0:
		var next_spread: int = e.infect_spread if e.infect_pandemic else e.infect_spread - 1
		var n := 0
		for o in nearest_enemies(e.position, 200.0, e.infect_spread + 3):
			if o.dead or o.infected > 0.0:
				continue
			o.infect(e.infect_dps, maxf(2.5, float(e.infect_dur)), next_spread, e.infect_pandemic)
			fx.ring(o.position, DB.C_ALLY, 4.0, 26.0, 0.3, 2.0)
			n += 1
			if n >= e.infect_spread:
				break
	# 분열(효모)
	if e.split_kind != "":
		for i in int(e.split_count):
			_spawn_queue.append({"kind": e.split_kind, "pos": e.position + Vector2.from_angle(randf() * TAU) * 12.0, "elite": false})
	# 대식세포 포식
	if String(cdata["perk"]) == "phagocytosis":
		player.phago_counter += 1
		if player.phago_counter >= 10:
			player.phago_counter = 0
			player.heal(1.0)

func _drop(pos: Vector2, kind: String, value: int) -> void:
	if kind == "gem" and _gems >= MAX_GEMS:
		# 너무 많으면 가장 오래된 ATP에 합친다
		for p in pickups:
			if p.kind == "gem" and not p.dead and not p.attracted:
				p.value += value
				if p.value >= 5 and p.radius < 7.0:
					p.setup("gem", p.value)
					p.queue_redraw()
				return
	var pk := Pickup.new()
	pk.setup(kind, value)
	pk.position = pos
	_layer_pickups.add_child(pk)
	pickups.append(pk)
	if kind == "gem":
		_gems += 1

func spawn_projectile(cfg: Dictionary) -> Node2D:
	var p := Projectile.new()
	p.position = cfg["pos"]
	p.vel = (cfg["vel"] as Vector2) * float(mods.get("proj_speed", 1.0))
	var psm := float(mods.get("proj_speed", 1.0))
	p.speed = float(cfg.get("speed", 600.0)) * psm
	p.damage = float(cfg.get("damage", 10.0))
	p.pierce = int(cfg.get("pierce", 0)) + int(mods.get("pierce", 0))
	p.radius = float(cfg.get("radius", 6.0))
	p.life = float(cfg.get("life", 1.0))
	p.style = String(cfg.get("style", "beam"))
	p.col = cfg.get("color", DB.C_ALLY)
	p.homing = float(cfg.get("homing", 0.0))
	p.bounces = int(cfg.get("bounces", 0))
	p.knockback = float(cfg.get("knockback", 0.0))
	p.length = float(cfg.get("length", 26.0))
	_layer_proj.add_child(p)
	projectiles.append(p)
	return p

func spawn_enemy_bullet(pos: Vector2, vel: Vector2, r: float, dmg: float, c: Color) -> void:
	var b := EnemyBullet.new()
	b.position = pos
	b.vel = vel
	b.radius = r
	b.damage = dmg
	b.col = c
	_layer_ebullets.add_child(b)
	ebullets.append(b)

func spawn_zone(pos: Vector2, r: float, dmg: float, duration: float, c: Color) -> void:
	var z := Zone.new()
	z.position = pos
	z.r = r
	z.dmg = dmg
	z.life = duration
	z.total = duration
	z.col = c
	_layer_zones.add_child(z)
	zones.append(z)

func hazard_line(a: Vector2, b: Vector2, width: float, dmg: float, c: Color) -> void:
	fx.hyphae(a, b, c, width)
	var p := player.position
	var ab := b - a
	var f := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var closest := a + ab * f
	if p.distance_to(closest) < width * 0.5 + float(player.radius) * 0.7:
		player.hurt(dmg)

func hazard_circle(pos: Vector2, r: float, dmg: float, c: Color) -> void:
	fx.ring(pos, c, r * 0.3, r * 1.1, 0.4, 6.0)
	if player.position.distance_to(pos) < r + float(player.radius) * 0.7:
		player.hurt(dmg)

# ── 줍기 / 경험치 / 레벨업 ───────────────────────────────────
func _update_pickups(delta: float) -> void:
	for p in pickups:
		if p.dead:
			continue
		if p.tick(delta, player):
			p.dead = true
			_collect(p)

func _collect(p: Node2D) -> void:
	match String(p.kind):
		"gem":
			_gems -= 1
			Audio.play("pickup", 0.5, 0.18, 0.035)
			add_xp(int(p.value))
		"cocoa":
			player.heal(30.0)
			Audio.play("heal")
			fx.ring(player.position, DB.C_GFP, 10.0, 60.0, 0.4, 3.0)
			toast("핫코코아 — HP +30", DB.C_GFP)
		"vortex":
			Audio.play("gift", 0.6)
			for q in pickups:
				if q.kind == "gem":
					q.attracted = true
			toast("볼텍스 — ATP를 전부 끌어당긴다", DB.C_GFP)
		"gift":
			Audio.play("gift")
			open_gift(int(p.value))

func add_xp(v: int) -> void:
	_xp_frac += v * float(mods["xp"])
	var gain := int(_xp_frac)
	_xp_frac -= gain
	xp += gain
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = DB.xp_to_next(level)
		pending_levelups += 1
	if pending_levelups > 0 and not levelup_panel.is_open():
		_open_levelup()

func _open_levelup() -> void:
	var opts := build_options(3)
	if opts.is_empty():
		pending_levelups = 0
		return
	Audio.play("levelup")
	get_tree().paused = true
	levelup_panel.open(opts, rerolls)

func on_levelup_chosen(opt: Dictionary) -> void:
	apply_option(opt)
	pending_levelups -= 1
	if pending_levelups > 0:
		var opts := build_options(3)
		if not opts.is_empty():
			levelup_panel.open(opts, rerolls)
			return
		pending_levelups = 0
	levelup_panel.close()
	get_tree().paused = false

func on_reroll() -> void:
	if rerolls <= 0:
		return
	rerolls -= 1
	levelup_panel.open(build_options(3), rerolls)

func get_weapon(id: String) -> Node2D:
	for w in weapons:
		if w.id == id:
			return w
	return null

func add_weapon(id: String) -> void:
	var w: Node2D = WEAPON_SCRIPTS[id].new()
	var lvl := 2 if String(cdata["perk"]) == "transfection" and weapons.size() > 0 else 1
	w.setup(self, player, id, lvl)
	player.add_child(w)
	weapons.append(w)

func build_options(n: int) -> Array:
	var pool: Array = []
	for id in DB.WEAPON_ORDER:
		var w := get_weapon(id)
		var d: Dictionary = DB.WEAPONS[id]
		if w != null:
			if w.level < DB.WEAPON_MAX_LEVEL:
				pool.append({"type": "weapon_up", "id": id, "w": 1.0, "title": d["name"], "short": d["short"], "color": d["color"],
					"tag": "Lv %d → %d" % [w.level, w.level + 1], "desc": DB.weapon_level_text(id, w.level + 1)})
		elif weapons.size() < max_weapons:
			var start := 2 if String(cdata["perk"]) == "transfection" else 1
			pool.append({"type": "weapon_new", "id": id, "w": 0.9, "title": d["name"], "short": d["short"], "color": d["color"],
				"tag": "NEW" + (" · Lv2" if start == 2 else ""), "desc": String(d["desc"])})
	for id in DB.PASSIVE_ORDER:
		var lv := int(passives.get(id, 0))
		var pd: Dictionary = DB.PASSIVES[id]
		if lv > 0 and lv < DB.PASSIVE_MAX_LEVEL:
			pool.append({"type": "passive", "id": id, "w": 0.8, "title": pd["name"], "short": pd["short"], "color": DB.C_GFP,
				"tag": "Lv %d → %d" % [lv, lv + 1], "desc": String(pd["text"])})
		elif lv == 0 and passives.size() < DB.MAX_PASSIVES:
			pool.append({"type": "passive", "id": id, "w": 0.7, "title": pd["name"], "short": pd["short"], "color": DB.C_GFP,
				"tag": "NEW 시약", "desc": String(pd["text"])})
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var total := 0.0
		for o in pool:
			total += float(o["w"])
		var r := randf() * total
		var pick := 0
		for i in pool.size():
			r -= float((pool[i] as Dictionary)["w"])
			if r <= 0.0:
				pick = i
				break
		out.append(pool[pick])
		pool.remove_at(pick)
	if out.is_empty():
		out.append({"type": "heal", "id": "cocoa", "title": "Hot Cocoa", "short": "HC", "color": DB.C_GFP, "tag": "회복", "desc": "HP 30 회복"})
	return out

func apply_option(opt: Dictionary) -> void:
	var id := String(opt.get("id", ""))
	match String(opt["type"]):
		"weapon_new":
			add_weapon(id)
		"weapon_up":
			var w := get_weapon(id)
			if w:
				w.set_level(w.level + 1)
		"passive":
			passives[id] = int(passives.get(id, 0)) + 1
			if id == "fbs":
				player.heal(20.0)
		"heal":
			player.heal(30.0)
	player.recalc(passives, mods)

## 선물상자: 진화 가능한 무기가 있으면 먼저 진화, 남은 수만큼 무작위 강화.
func open_gift(count: int) -> void:
	var got: Array = []
	for w in weapons:
		if count <= 0:
			break
		var d: Dictionary = DB.WEAPONS[w.id]
		if not w.evolved and w.level >= DB.WEAPON_MAX_LEVEL and d.has("evolve_with") and int(passives.get(String(d["evolve_with"]), 0)) > 0:
			w.evolve()
			papers.append(String(d["evolved_name"]))
			got.append("논문 게재! %s → %s" % [d["name"], d["evolved_name"]])
			count -= 1
	for i in count:
		var opts := build_options(1)
		if opts.is_empty():
			break
		var o: Dictionary = opts[0]
		apply_option(o)
		got.append("%s  %s" % [o["title"], o["tag"]])
	if got.is_empty():
		player.heal(40.0)
		got.append("HP 40 회복")
	hud.show_gift(got)
	fx.ring(player.position, DB.C_GFP, 10.0, 160.0, 0.6, 5.0)

# ── 피격 / 종료 ──────────────────────────────────────────────
func on_player_hurt(dmg: float) -> void:
	Audio.play("hurt", 0.8, 0.1, 0.08)
	shake(4.0)
	fx.number(player.position + Vector2(0, -26), dmg, DB.C_ENEMY)

func _check_end() -> void:
	if player.hp <= 0.0:
		if player.revives > 0:
			player.revives -= 1
			player.hp = player.max_hp * 0.5
			player.invuln = 2.0
			for e in query(player.position, 260.0):
				if not e.is_boss:
					e.knock_vel += (e.position - player.position).normalized() * 700.0
			fx.ring(player.position, DB.C_ALLY, 10.0, 260.0, 0.6, 6.0)
			toast("불멸화 발동 — HeLa는 죽지 않는다" if String(cdata["perk"]) == "immortal" else "백업 스톡 해동 — 부활!", DB.C_ALLY)
			return
		_finish(false)

func _finish(victory: bool) -> void:
	if finished:
		return
	finished = true
	var wl: Array = []
	for w in weapons:
		wl.append("%s Lv%d" % [w.display_name(), w.level])
	var pl: Array = []
	for k in passives.keys():
		pl.append("%s Lv%d" % [DB.PASSIVES[k]["name"], passives[k]])
	var result := {
		"victory": victory, "time": t, "level": level, "kills": kills,
		"boss_kills": boss_kills, "char_id": char_id, "weapons": wl, "passives": pl, "papers": papers,
		"mode": mode, "zone": zone, "difficulty": difficulty, "daily_key": String(daily.get("date", "")),
	}
	Audio.play_stinger("victory" if victory else "defeat")
	Engine.time_scale = 0.35
	await get_tree().create_timer(1.1, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().paused = true
	run_finished.emit(result)

## 설정에서 색각 모드를 바꾸면 이미 화면에 있는 것들 색도 바꾼다
func refresh_palette() -> void:
	for e in enemies:
		if e.dead:
			continue
		if e.is_boss:
			var bid := String(e.boss_id)
			e.col = DB.C_ENEMY_ORANGE if bid == "mold_wreath" else (DB.C_ENEMY if bid == "reviewer2" else DB.C_ENEMY_MAG)
		else:
			e.col = DB.enemy_color(String(e.kind))
		e.queue_redraw()
	for p in pickups:
		if not p.dead:
			p.setup(String(p.kind), int(p.value))
			p.queue_redraw()
	player.queue_redraw()
	background.queue_redraw()

func toast(msg: String, c: Color) -> void:
	if hud:
		hud.toast(msg, c)

func shake(amount: float) -> void:
	if bool(Save.setting("shake")):
		_shake = maxf(_shake, amount)

func _update_camera(delta: float) -> void:
	camera.position = camera.position.lerp(player.position, 1.0 - exp(-10.0 * delta))
	if _shake > 0.0:
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - 40.0 * delta)
	else:
		camera.offset = Vector2.ZERO
