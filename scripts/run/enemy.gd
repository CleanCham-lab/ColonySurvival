extends Node2D
## 오염원(적). 보스는 boss.gd가 이 스크립트를 상속한다.
## 이동/충돌은 World가 한 번에 돌린다(성능).

const CellArt = preload("res://scripts/run/cell_art.gd")

var world: Node
var kind := ""
var hp := 10.0
var max_hp := 10.0
var speed := 80.0
var contact := 8.0
var radius := 12.0
var xp_value := 1
var col := Color(1.0, 0.3, 0.4)
var shape := "dot"
var behavior := "chase"
var armor_mult := 1.0
var is_elite := false
var is_boss := false
var dead := false
var flash := 0.0
var knock_vel := Vector2.ZERO
var knock_resist := 1.0
var vel := Vector2.ZERO
var split_kind := ""
var split_count := 0
# 감염(Lentiviral Orb)
var infected := 0.0
var infect_dps := 0.0
var infect_spread := 0
var infect_pandemic := false
var infect_dur := 4.0
var _infect_acc := 0.0
var _infect_tick := 0.5
var _infect_glow: Sprite2D
# 행동 상태
var state := 0
var state_t := 0.0
var aim_dir := Vector2.RIGHT
var wobble := 0.0
var _seed := 0

func setup(w: Node, k: String, hp_scale: float, dmg_scale: float, elite := false) -> void:
	world = w
	kind = k
	var d: Dictionary = DB.ENEMIES[k]
	max_hp = float(d["hp"]) * hp_scale
	speed = float(d["speed"]) * randf_range(0.9, 1.1)
	contact = float(d["damage"]) * dmg_scale
	radius = float(d["radius"])
	xp_value = int(d["xp"])
	col = DB.enemy_color(k)
	shape = String(d["shape"])
	behavior = String(d["behavior"])
	armor_mult = float(d.get("armor_mult", 1.0))
	split_kind = String(d.get("split", ""))
	split_count = int(d.get("split_count", 0))
	if kind == "biofilm":
		knock_resist = 0.35
	if elite:
		is_elite = true
		max_hp *= DB.ELITE_HP_MULT
		radius *= DB.ELITE_SCALE
		contact *= 1.5
		xp_value *= 8
		knock_resist = 0.25
	hp = max_hp
	wobble = randf() * TAU
	state_t = randf_range(0.6, 2.2)
	_seed = randi()

func _ready() -> void:
	material = UIKit.add_mat
	queue_redraw()

# ── 매 프레임 (World가 호출) ─────────────────────────────────
func tick(delta: float, ppos: Vector2) -> void:
	var to := ppos - position
	var dist := to.length()
	var dir := to / dist if dist > 0.001 else Vector2.ZERO
	match behavior:
		"chase":
			vel = dir * speed
		"dash":
			_tick_dash(delta, dir, dist)
		"turret":
			_tick_turret(delta, dir, dist)
		_:
			vel = Vector2.ZERO
	position += (vel + knock_vel) * delta
	knock_vel = knock_vel.move_toward(Vector2.ZERO, 1100.0 * delta)
	_update_visual(delta)
	_tick_infection(delta)

func _tick_dash(delta: float, dir: Vector2, dist: float) -> void:
	state_t -= delta
	match state:
		0:
			vel = dir * speed
			if dist < 340.0 and state_t <= 0.0:
				state = 1
				state_t = 0.6
				aim_dir = dir
				world.telegraphs.add_line(position, position + aim_dir * 400.0, radius * 1.4, 0.6, DB.C_WARN)
		1:
			vel = Vector2.ZERO
			if state_t <= 0.0:
				state = 2
				state_t = 0.42
		2:
			vel = aim_dir * speed * 5.0
			if state_t <= 0.0:
				state = 0
				state_t = 1.6

func _tick_turret(delta: float, dir: Vector2, dist: float) -> void:
	vel = dir * speed if dist > 360.0 else Vector2.ZERO
	state_t -= delta
	if state == 0 and state_t <= 0.5:
		state = 1
	if state_t <= 0.0:
		var n := 14 if is_elite else 8
		var off := randf() * TAU
		for i in n:
			var a := off + TAU * i / n
			world.spawn_enemy_bullet(position + Vector2.from_angle(a) * radius, Vector2.from_angle(a) * 150.0, 6.0, contact * 0.8, DB.C_ENEMY_ORANGE)
		state = 0
		state_t = 3.2

func _update_visual(delta: float) -> void:
	wobble += delta * 3.0
	flash = maxf(0.0, flash - delta)
	match shape:
		"rod", "phage":
			if vel.length_squared() > 4.0:
				rotation = lerp_angle(rotation, vel.angle(), minf(1.0, delta * 8.0))
		"pod":
			var s := 1.0 + (0.18 * absf(sin(wobble * 4.0)) if state == 1 else 0.04 * sin(wobble))
			scale = Vector2(s, s)
		"dot", "yeast", "blob":
			rotation += delta * 0.4
	if flash > 0.0:
		modulate = Color(2.4, 2.4, 2.4, 1.0)
	else:
		modulate = Color(1, 1, 1, 1)

func _tick_infection(delta: float) -> void:
	if infected <= 0.0:
		return
	infected -= delta
	_infect_acc += infect_dps * delta
	_infect_tick -= delta
	if _infect_tick <= 0.0:
		_infect_tick = 0.5
		if _infect_acc > 0.0:
			var a := _infect_acc
			_infect_acc = 0.0
			world.damage_enemy(self, a, Vector2.ZERO, 0.0, DB.C_ALLY)
	if infected <= 0.0 and _infect_glow:
		_infect_glow.visible = false

func infect(dps: float, duration: float, spread: int, pandemic: bool) -> void:
	infected = maxf(infected, duration)
	infect_dur = duration
	infect_dps = maxf(infect_dps, dps)
	infect_spread = maxi(infect_spread, spread)
	infect_pandemic = infect_pandemic or pandemic
	if _infect_glow == null:
		_infect_glow = Sprite2D.new()
		_infect_glow.texture = UIKit.glow_tex
		_infect_glow.modulate = Color(0.3, 0.95, 1.0, 0.75)
		var s := radius * 2.6 / 128.0
		_infect_glow.scale = Vector2(s, s)
		add_child(_infect_glow)
	_infect_glow.visible = true

# ── 그리기 ───────────────────────────────────────────────────
func _draw() -> void:
	var r := radius
	var c := col
	var fill := Color(c.r, c.g, c.b, 0.48)
	var line := Color(c.r, c.g, c.b, 1.0)
	UIKit.glow(self, Vector2.ZERO, r * 3.0, Color(c.r, c.g, c.b, 0.62))
	match shape:
		"dot":
			draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.85))
			draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1.0, 0.85, 0.9, 0.55))
		"rod":
			var cap := CellArt.capsule_points(r * 0.75, r * 0.55)
			draw_colored_polygon(cap, fill)
			draw_polyline(CellArt.closed(cap), line, 2.6, true)
			draw_circle(Vector2(r * 0.15, 0), r * 0.22, Color(1.0, 0.85, 0.8, 0.5))
			var fl := PackedVector2Array()
			for i in 9:
				fl.append(Vector2(-r * 1.3 - i * r * 0.22, sin(i * 1.3) * r * 0.25))
			draw_polyline(fl, Color(c.r, c.g, c.b, 0.6), 1.2, true)
		"yeast":
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.84))
			draw_circle(Vector2.ZERO, r, fill)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, line, 2.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(Vector2(r * 0.8, -r * 0.55), r * 0.4, fill)
			draw_arc(Vector2(r * 0.8, -r * 0.55), r * 0.4, 0.0, TAU, 16, line, 1.6, true)
			draw_circle(Vector2(-r * 0.15, r * 0.1), r * 0.3, Color(1.0, 0.8, 0.6, 0.45))
		"phage":
			var head := PackedVector2Array()
			for i in 6:
				head.append(Vector2(r * 0.45, 0) + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * r * 0.62)
			draw_colored_polygon(head, fill)
			draw_polyline(CellArt.closed(head), line, 2.0, true)
			draw_line(Vector2(-r * 0.15, 0), Vector2(-r * 1.0, 0), line, r * 0.22)
			for s in [-1.0, 1.0]:
				draw_line(Vector2(-r * 1.0, 0), Vector2(-r * 1.45, s * r * 0.75), line, 1.4, true)
				draw_line(Vector2(-r * 1.0, 0), Vector2(-r * 1.15, s * r * 0.95), line, 1.4, true)
			draw_circle(Vector2(r * 0.45, 0), r * 0.22, Color(1.0, 0.7, 0.95, 0.6))
		"pod":
			draw_line(Vector2(0, r * 0.3), Vector2(0, r * 1.2), Color(c.r, c.g, c.b, 0.6), 3.0)
			draw_circle(Vector2.ZERO, r * 0.7, fill)
			draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 24, line, 2.0, true)
			for i in 12:
				var p := Vector2.from_angle(TAU * i / 12.0) * r * 0.95
				draw_circle(p, r * 0.2, Color(1.0, 0.82, 0.35, 0.8))
		"blob":
			var pts := CellArt.smooth_closed(CellArt.blob_points(r, 9, _seed, 0.28), 4)
			draw_colored_polygon(pts, fill)
			draw_polyline(CellArt.closed(pts), line, 2.4, true)
			var rng := RandomNumberGenerator.new()
			rng.seed = _seed
			for i in 7:
				draw_circle(Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * r, r * 0.12, Color(1.0, 0.55, 0.6, 0.55))
		"tipbox":
			var rect := Rect2(-r * 1.2, -r * 0.8, r * 2.4, r * 1.6)
			draw_rect(rect, Color(0.35, 0.55, 0.9, 0.25))
			draw_rect(rect, Color(0.6, 0.8, 1.0, 0.9), false, 2.0)
			for ix in 5:
				for iy in 3:
					draw_circle(Vector2(-r * 0.9 + ix * r * 0.45, -r * 0.45 + iy * r * 0.45), r * 0.1, Color(0.8, 0.9, 1.0, 0.8))
	if is_elite:
		UIKit.glow(self, Vector2.ZERO, r * 3.4, Color(DB.C_WARN.r, DB.C_WARN.g, DB.C_WARN.b, 0.22))
		draw_arc(Vector2.ZERO, r * 1.3, 0.0, TAU, 40, DB.C_WARN, 2.5, true)
