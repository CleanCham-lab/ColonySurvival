extends "res://scripts/run/enemy.gd"
## 보스. 모든 공격은 노란 경고 표시(텔레그래프)가 먼저 뜬다.
##  - mold_wreath  : 5분. 포자 고리(틈으로 피하기) + 균사 뻗기(경고선) + HP 50%에 포자낭 소환
##  - krampus_proto: 10분. 3연속 돌진 + 점프 착지 
##  - reviewer2    : 15분(12/25 09:00) 최종 보스. Major Revision / Additional Experiments /
##                   HP 50% Desk Reject / HP 20% Rejection Letters. 처치하면 승리.

var boss_id := ""
var title := ""
var pattern_i := 0
var cooldown := 2.0
var busy := 0.0
var phase2 := false
# 크람푸스용
var kstate := "walk"
var kt := 0.0
var dashes_left := 0
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var phase3 := false
var _alive_t := 0.0

func setup_boss(w: Node, id: String, hp_scale: float) -> void:
	world = w
	boss_id = id
	kind = id
	var d: Dictionary = DB.BOSSES[id]
	max_hp = float(d["hp"]) * hp_scale
	hp = max_hp
	radius = float(d["radius"])
	contact = float(d["damage"])
	speed = float(d["speed"])
	title = String(d["title"])
	is_boss = true
	knock_resist = 0.0
	xp_value = 0
	behavior = "boss"
	shape = "boss"
	col = DB.C_ENEMY_ORANGE if id == "mold_wreath" else (DB.C_ENEMY if id == "reviewer2" else DB.C_ENEMY_MAG)
	cooldown = 2.2

func tick(delta: float, ppos: Vector2) -> void:
	match boss_id:
		"mold_wreath":
			_tick_wreath(delta, ppos)
		"krampus_proto":
			_tick_krampus(delta, ppos)
		"reviewer2":
			_tick_reviewer(delta, ppos)
	position += vel * delta
	flash = maxf(0.0, flash - delta)
	modulate = Color(1.3, 1.3, 1.3, 1.0) if flash > 0.0 else Color(1, 1, 1, 1)
	wobble += delta
	_tick_infection(delta)
	if not phase2 and hp < max_hp * 0.5:
		phase2 = true
		_on_phase2()
	if boss_id == "reviewer2" and not phase3 and hp < max_hp * 0.2:
		phase3 = true
		world.toast("Reviewer #2: \"Reject.\"", DB.C_WARN)
		queue_redraw()

func _on_phase2() -> void:
	match boss_id:
		"mold_wreath":
			world.toast("Mold Wreath가 포자낭을 틔웠다!", DB.C_WARN)
			for i in 4:
				var p: Vector2 = position + Vector2.from_angle(TAU * i / 4.0 + PI / 4.0) * (radius + 70.0)
				world.spawn_enemy_at("spore_pod", p, false)
		"krampus_proto":
			world.toast("크람푸스가 분노했다!", DB.C_WARN)
		"reviewer2":
			world.toast("Reviewer #2: \"추가 실험이 필요합니다.\"", DB.C_WARN)
	queue_redraw()

# ── Mold Wreath ──────────────────────────────────────────────
func _tick_wreath(delta: float, ppos: Vector2) -> void:
	var to := ppos - position
	var dist := to.length()
	var dir := to / dist if dist > 0.001 else Vector2.ZERO
	if dist > 330.0:
		vel = dir * (speed + (dist - 330.0) * 0.6)  # 멀어지면 따라잡는다
	elif dist < 210.0:
		vel = -dir * speed * 0.7
	else:
		vel = vel.move_toward(Vector2.ZERO, 80.0 * delta)
	rotation += delta * (0.45 if phase2 else 0.22)
	busy -= delta
	if busy > 0.0:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if pattern_i % 2 == 0:
		_wreath_ring()
	else:
		_wreath_hyphae(ppos)
	pattern_i += 1
	cooldown = 0.9 if phase2 else 1.6

func _wreath_ring() -> void:
	var waves := 3 if phase2 else 2
	busy = 0.8 + waves * 0.55
	world.telegraphs.add_circle(position, radius + 34.0, 0.8, DB.C_WARN)
	var gap := randf() * TAU
	var turn := 0.75 if randf() < 0.5 else -0.75
	for wv in waves:
		var g := gap + wv * turn
		world.schedule(0.8 + wv * 0.55, _fire_ring.bind(g))

func _fire_ring(gap: float) -> void:
	if dead:
		return
	var n := 30
	for i in n:
		var a := TAU * i / n
		if absf(wrapf(a - gap, -PI, PI)) < 0.45:
			continue
		world.spawn_enemy_bullet(position + Vector2.from_angle(a) * radius * 0.8, Vector2.from_angle(a) * 170.0, 8.0, 12.0, DB.C_ENEMY_ORANGE)

func _wreath_hyphae(ppos: Vector2) -> void:
	var n := 5 if phase2 else 3
	var base := (ppos - position).angle()
	var step := deg_to_rad(20.0)
	busy = 1.3
	var w: Node = world
	for i in n:
		var a := base + (i - (n - 1) / 2.0) * step
		var from := position
		var to := position + Vector2.from_angle(a) * 900.0
		world.telegraphs.add_line(from, to, 34.0, 1.0, DB.C_WARN, func() -> void: w.hazard_line(from, to, 34.0, 16.0, DB.C_ENEMY_ORANGE))

# ── Krampus Phage ───────────────────────────────
func _tick_krampus(delta: float, ppos: Vector2) -> void:
	var to := ppos - position
	var dist := to.length()
	var dir := to / dist if dist > 0.001 else Vector2.ZERO
	kt -= delta
	match kstate:
		"walk":
			vel = dir * (speed + maxf(0.0, dist - 400.0) * 0.5)
			if vel.length_squared() > 1.0:
				rotation = lerp_angle(rotation, vel.angle(), minf(1.0, delta * 4.0))
			if kt <= 0.0:
				if pattern_i % 2 == 0:
					dashes_left = 4 if phase2 else 3
					_k_aim(ppos)
				else:
					_k_leap(ppos)
				pattern_i += 1
		"aim":
			vel = Vector2.ZERO
			rotation = lerp_angle(rotation, aim_dir.angle(), minf(1.0, delta * 10.0))
			if kt <= 0.0:
				kstate = "dash"
				kt = 0.45
		"dash":
			vel = aim_dir * 1150.0
			if kt <= 0.0:
				dashes_left -= 1
				if dashes_left > 0:
					_k_aim(ppos)
				else:
					kstate = "walk"
					kt = 2.0 if phase2 else 2.8
		"leap":
			vel = Vector2.ZERO
			var f := clampf(1.0 - kt / 1.1, 0.0, 1.0)
			position = leap_from.lerp(leap_to, f)
			var s := 1.0 + sin(f * PI) * 0.6
			scale = Vector2(s, s)
			if kt <= 0.0:
				scale = Vector2.ONE
				_k_land()
				kstate = "walk"
				kt = 2.0 if phase2 else 2.8

func _k_aim(ppos: Vector2) -> void:
	kstate = "aim"
	kt = 0.55 if phase2 else 0.7
	aim_dir = (ppos - position).normalized()
	world.telegraphs.add_line(position, position + aim_dir * 520.0, radius * 1.8, kt, DB.C_WARN)

func _k_leap(ppos: Vector2) -> void:
	kstate = "leap"
	kt = 1.1
	leap_from = position
	leap_to = ppos
	world.telegraphs.add_circle(ppos, 150.0, 1.1, DB.C_WARN)

func _k_land() -> void:
	world.hazard_circle(position, 150.0, 24.0, DB.C_ENEMY_MAG)
	var n := 16
	for i in n:
		var a := TAU * i / n
		world.spawn_enemy_bullet(position, Vector2.from_angle(a) * 200.0, 7.0, 12.0, DB.C_ENEMY_MAG)
	for i in (4 if phase2 else 2):
		world.spawn_enemy_at("phage", position + Vector2.from_angle(randf() * TAU) * 90.0, false)
	world.shake(10.0)

# ── Reviewer #2 (최종) ────────────────────────────────────────
func _tick_reviewer(delta: float, ppos: Vector2) -> void:
	_alive_t += delta
	var to := ppos - position
	var dist := to.length()
	var dir := to / dist if dist > 0.001 else Vector2.ZERO
	if dist > 320.0:
		vel = dir * (speed + (dist - 320.0) * 0.6)
	elif dist < 220.0:
		vel = -dir * speed
	else:
		vel = dir.orthogonal() * speed * 0.6  # 옆으로 맴돈다
	rotation = sin(_alive_t * 1.3) * 0.12
	busy -= delta
	if busy > 0.0:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var plan: Array = ["major", "experiments"]
	if phase3:
		plan = ["letters", "desk", "major"]
	elif phase2:
		plan = ["major", "desk", "experiments"]
	var p: String = plan[pattern_i % plan.size()]
	pattern_i += 1
	match p:
		"major":
			_rv_major(ppos)
		"experiments":
			_rv_experiments()
		"desk":
			_rv_desk(ppos)
		"letters":
			_rv_letters()
	cooldown = 0.8 if phase3 else (1.0 if phase2 else 1.4)

## Major Revision: 바닥에 빨간 X 표시 → 1.1초 뒤 폭발
func _rv_major(ppos: Vector2) -> void:
	var n := 10 if phase2 else 7
	busy = 1.3
	var w: Node = world
	var dmg := 18.0 * (contact / 26.0)
	for i in n:
		var p: Vector2 = ppos if i == 0 else ppos + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 280.0)
		p = world.clamp_bounds(p, 40.0)
		world.telegraphs.add_x(p, 70.0, 1.1, DB.C_WARN, func() -> void: w.hazard_circle(p, 70.0, dmg, DB.C_ENEMY))
	world.toast("Major Revision", DB.C_ENEMY)

## Additional Experiments Required: 포자 고리 + 쫄몹 소환
func _rv_experiments() -> void:
	busy = 1.6
	world.telegraphs.add_circle(position, radius + 30.0, 0.7, DB.C_WARN)
	var gap := randf() * TAU
	world.schedule(0.7, _rv_ring.bind(gap))
	world.schedule(1.2, _rv_ring.bind(gap + 0.8))
	for i in (4 if phase2 else 3):
		world.spawn_enemy_at("phage", position + Vector2.from_angle(TAU * i / 4.0) * (radius + 60.0), false)

func _rv_ring(gap: float) -> void:
	if dead:
		return
	var n := 32
	for i in n:
		var a := TAU * i / n
		if absf(wrapf(a - gap, -PI, PI)) < 0.42:
			continue
		world.spawn_enemy_bullet(position + Vector2.from_angle(a) * radius * 0.8, Vector2.from_angle(a) * 180.0, 8.0, 13.0, DB.C_ENEMY)

## Desk Reject: 화면을 가로지르는 벽 4줄, 각각 한 곳만 빈틈
func _rv_desk(ppos: Vector2) -> void:
	busy = 2.6
	var d := Vector2.from_angle(randf() * TAU)
	var along := d.orthogonal()
	var w: Node = world
	var dmg := 22.0 * (contact / 26.0)
	var k := 0
	for off in [-270.0, -90.0, 90.0, 270.0]:
		var center: Vector2 = ppos + d * off
		var gap_at := randf_range(-220.0, 220.0)
		var gap_half := 80.0
		var a0: Vector2 = center + along * -1200.0
		var a1: Vector2 = center + along * (gap_at - gap_half)
		var b0: Vector2 = center + along * (gap_at + gap_half)
		var b1: Vector2 = center + along * 1200.0
		var dur := 1.1 + k * 0.35
		world.telegraphs.add_line(a0, a1, 46.0, dur, DB.C_WARN, func() -> void: w.hazard_line(a0, a1, 46.0, dmg, DB.C_ENEMY))
		world.telegraphs.add_line(b0, b1, 46.0, dur, DB.C_WARN, func() -> void: w.hazard_line(b0, b1, 46.0, dmg, DB.C_ENEMY))
		k += 1
	world.toast("Desk Reject — 빈틈으로!", DB.C_ENEMY)

## Rejection Letters: 나선 탄막
func _rv_letters() -> void:
	busy = 2.8
	world.toast("Rejection Letters", DB.C_ENEMY)
	var base := randf() * TAU
	for i in 34:
		world.schedule(0.3 + i * 0.075, _rv_letter_shot.bind(base + i * 0.33))

func _rv_letter_shot(a: float) -> void:
	if dead:
		return
	for k in 3:
		var aa := a + TAU * k / 3.0
		world.spawn_enemy_bullet(position + Vector2.from_angle(aa) * radius, Vector2.from_angle(aa) * 210.0, 7.0, 11.0, DB.C_ENEMY)

# ── 그리기 ───────────────────────────────────────────────────
func _draw() -> void:
	match boss_id:
		"mold_wreath":
			_draw_wreath()
		"reviewer2":
			_draw_reviewer()
		_:
			_draw_krampus()

func _draw_reviewer() -> void:
	var R := radius
	var c := col
	var hot := 1.4 if phase3 else (1.2 if phase2 else 1.0)
	UIKit.glow(self, Vector2.ZERO, R * 3.2, Color(c.r, c.g, c.b, 0.42 * hot))
	# 잉크 얼룩
	var blob := CellArt.smooth_closed(CellArt.blob_points(R, 11, 222, 0.22), 4)
	draw_colored_polygon(blob, Color(c.r * 0.5, c.g * 0.2, c.b * 0.25, 0.85))
	draw_colored_polygon(blob, Color(c.r, c.g, c.b, 0.22 * hot))
	draw_polyline(CellArt.closed(blob), Color(c.r, c.g, c.b, 1.0), 3.0, true)
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		draw_circle(Vector2.from_angle(a) * R * 1.15, R * 0.08, Color(c.r, c.g, c.b, 0.8))
	# 빨간 펜촉
	var nib := PackedVector2Array([Vector2(R * 0.55, -R * 0.95), Vector2(R * 1.05, -R * 0.45), Vector2(R * 0.2, R * 0.25), Vector2(R * 0.05, R * 0.1)])
	draw_colored_polygon(nib, Color(0.95, 0.92, 0.9, 0.95))
	draw_line(Vector2(R * 0.12, R * 0.17), Vector2(R * 0.7, -R * 0.6), Color(c.r, c.g, c.b), 2.0, true)
	draw_circle(Vector2(R * 0.12, R * 0.17), R * 0.07, c)
	# "#2"
	UIKit.text(self, Vector2(-R * 0.75, R * 0.32), "#2", int(R * 0.95), Color(1.0, 0.95, 0.95), true)
	if phase3:
		draw_arc(Vector2.ZERO, R * 1.35, 0.0, TAU, 48, DB.C_WARN, 3.0, true)

func _draw_wreath() -> void:
	var R := radius
	var c := col
	var hot := 1.25 if phase2 else 1.0
	UIKit.glow(self, Vector2.ZERO, R * 3.0, Color(c.r, c.g, c.b, 0.35 * hot))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# 균사 콜로니가 고리 모양으로 뭉친 화환
	for i in 16:
		var a := TAU * i / 16.0
		var p := Vector2.from_angle(a) * R * 0.8
		var rr := R * rng.randf_range(0.26, 0.36)
		draw_circle(p, rr, Color(c.r, c.g * 0.8, c.b, 0.22 * hot))
		draw_arc(p, rr, 0.0, TAU, 18, Color(c.r, c.g, c.b, 0.75), 1.6, true)
		# 균사 털
		for j in 3:
			var ha := a + rng.randf_range(-1.2, 1.2)
			draw_line(p, p + Vector2.from_angle(ha) * rr * 1.5, Color(c.r, c.g, c.b, 0.35), 1.0, true)
	# 장식(포자낭 = 노랑, mCherry = 빨강)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var p := Vector2.from_angle(a) * R * 0.86
		var oc := DB.C_WARN if i % 2 == 0 else DB.C_ENEMY
		UIKit.glow(self, p, R * 0.35, Color(oc.r, oc.g, oc.b, 0.6))
		draw_circle(p, R * 0.09, oc)
	# 리본
	var bow := Vector2(0, R * 0.95)
	var red := Color(1.0, 0.22, 0.32)
	draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(-R * 0.42, -R * 0.22), bow + Vector2(-R * 0.42, R * 0.22)]), red)
	draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(R * 0.42, -R * 0.22), bow + Vector2(R * 0.42, R * 0.22)]), red)
	draw_line(bow, bow + Vector2(-R * 0.18, R * 0.5), red, 4.0, true)
	draw_line(bow, bow + Vector2(R * 0.18, R * 0.5), red, 4.0, true)
	draw_circle(bow, R * 0.1, Color(1.0, 0.45, 0.5))

func _draw_krampus() -> void:
	var r := radius
	var c := col
	var line := Color(c.r, c.g, c.b, 1.0)
	var fill := Color(c.r, c.g, c.b, 0.28)
	UIKit.glow(self, Vector2.ZERO, r * 3.0, Color(c.r, c.g, c.b, 0.4))
	var head := PackedVector2Array()
	for i in 6:
		head.append(Vector2(r * 0.45, 0) + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * r * 0.7)
	draw_colored_polygon(head, fill)
	draw_polyline(CellArt.closed(head), line, 3.0, true)
	draw_line(Vector2(-r * 0.2, 0), Vector2(-r * 1.1, 0), line, r * 0.25)
	for s in [-1.0, 1.0]:
		for k in 3:
			var base := Vector2(-r * 1.1, 0)
			draw_line(base, base + Vector2(-r * (0.2 + 0.25 * k), s * r * (0.7 + 0.15 * k)), line, 2.0, true)
	# 뿔
	var horn := Color(0.75, 0.25, 0.35)
	for s in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 8:
			var t := i / 7.0
			pts.append(Vector2(r * (0.6 + 0.5 * t), s * (r * 0.45 + r * 0.9 * t - r * 0.5 * t * t)))
		draw_polyline(pts, horn, 5.0 - 0.0, true)
	draw_circle(Vector2(r * 0.55, -r * 0.18), r * 0.1, DB.C_WARN)
	draw_circle(Vector2(r * 0.55, r * 0.18), r * 0.1, DB.C_WARN)
