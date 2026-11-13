extends Node2D
## 바닥: 배양접시 + 혈구계산판(hemocytometer) 격자 + 초점 밖 세포들 + 배지 방울 + 깨진 커버글라스.
## zone == "hood" 이면 클린벤치(스테인리스 작업대 + 타공 그릴 + 층류 화살표 + 튜브 랙).
## 바닥은 한 번만 그리고, 층류 화살표만 별도 노드에서 천천히 흐른다.

var R := DB.DISH_RADIUS
var droplets: Array = []   # {pos, r}
var shards: Array = []     # {pos, r, pts}
var _blobs: Array = []
var zone := "dish"
var _flow: Node2D
var _flow_t := 0.0

func setup(drops: Array, glass: Array, z := "dish") -> void:
	droplets = drops
	shards = glass
	zone = z

func _ready() -> void:
	z_index = -10
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hs := DB.HOOD_SIZE * 0.5
	for i in 70:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * R * 0.98
		var tint: Color = [Color(0.25, 0.35, 0.75), Color(0.35, 0.3, 0.7), Color(0.2, 0.45, 0.7)][rng.randi() % 3]
		var p := Vector2.from_angle(a) * d
		if zone == "hood":
			p = Vector2(rng.randf_range(-hs.x, hs.x), rng.randf_range(-hs.y, hs.y))
		_blobs.append({"pos": p, "r": rng.randf_range(40.0, 130.0), "c": tint})
	if zone == "hood":
		_flow = Node2D.new()
		_flow.z_index = 1
		_flow.material = UIKit.add_mat
		add_child(_flow)
		_flow.draw.connect(_draw_flow)
	queue_redraw()

func _process(delta: float) -> void:
	if _flow != null:
		_flow_t += delta
		_flow.queue_redraw()

## 층류: 위에서 아래로 흐르는 옅은 화살표 열
func _draw_flow() -> void:
	var hs := DB.HOOD_SIZE * 0.5
	var c := Color(0.55, 0.85, 1.0, 0.10)
	var step := 260.0
	var off := fposmod(_flow_t * DB.HOOD_AIRFLOW.y * 1.8, step)
	var x := -hs.x + 130.0
	while x < hs.x:
		var y := -hs.y + off
		while y < hs.y:
			_flow.draw_polyline(PackedVector2Array([Vector2(x - 22, y - 10), Vector2(x, y + 10), Vector2(x + 22, y - 10)]), c, 3.0, true)
			y += step
		x += 260.0

func _draw() -> void:
	if zone == "hood":
		_draw_hood()
		return
	# 접시 바닥
	draw_circle(Vector2.ZERO, R, Color(0.035, 0.045, 0.075))
	for b in _blobs:
		var c: Color = b["c"]
		var r: float = float(b["r"])
		draw_texture_rect(UIKit.soft_tex, Rect2((b["pos"] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c.r, c.g, c.b, 0.16))
	# 혈구계산판 격자: 600px 큰 칸(3중선) / 150px 중간 칸 / 중앙 큰 칸은 30px 잔격자
	var fine := Color(DB.C_GRID.r, DB.C_GRID.g, DB.C_GRID.b, 0.07)
	var mid := Color(DB.C_GRID.r, DB.C_GRID.g, DB.C_GRID.b, 0.14)
	var big := Color(DB.C_GRID.r, DB.C_GRID.g, DB.C_GRID.b, 0.26)
	var x := -R
	while x <= R:
		var h := sqrt(maxf(0.0, R * R - x * x))
		var is_big := is_zero_approx(fposmod(x, 600.0))
		if is_big:
			for o in [-5.0, 0.0, 5.0]:
				draw_line(Vector2(x + o, -h), Vector2(x + o, h), big, 1.0)
				draw_line(Vector2(-h, x + o), Vector2(h, x + o), big, 1.0)
		else:
			draw_line(Vector2(x, -h), Vector2(x, h), mid, 1.0)
			draw_line(Vector2(-h, x), Vector2(h, x), mid, 1.0)
		x += 150.0
	var c0 := -300.0
	var cx := c0
	while cx <= 300.0:
		draw_line(Vector2(cx, -300), Vector2(cx, 300), fine, 1.0)
		draw_line(Vector2(-300, cx), Vector2(300, cx), fine, 1.0)
		cx += 30.0
	# 배지 방울(회복)
	for d in droplets:
		var p: Vector2 = d["pos"]
		var r: float = float(d["r"])
		var g := DB.C_GFP
		draw_texture_rect(UIKit.glow_tex, Rect2(p - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(g.r, g.g, g.b, 0.18))
		draw_circle(p, r, Color(g.r, g.g, g.b, 0.10))
		draw_arc(p, r, 0.0, TAU, 48, Color(g.r, g.g, g.b, 0.55), 2.0, true)
		draw_arc(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, PI, PI * 1.6, 10, Color(0.8, 1.0, 0.9, 0.35), 2.0, true)
	# 깨진 커버글라스(통과 불가)
	for s in shards:
		var pts: PackedVector2Array = s["pts"]
		draw_colored_polygon(pts, Color(0.55, 0.7, 0.95, 0.10))
		var cl := pts.duplicate()
		cl.append(pts[0])
		draw_polyline(cl, Color(0.75, 0.88, 1.0, 0.6), 2.0, true)
	# 접시 벽
	for i in 3:
		draw_arc(Vector2.ZERO, R + i * 6.0, 0.0, TAU, 256, Color(0.45, 0.65, 1.0, 0.35 - i * 0.1), 3.0 - i, true)
	draw_arc(Vector2.ZERO, R + 60.0, 0.0, TAU, 256, Color(0.0, 0.0, 0.0, 1.0), 100.0)

# ── 클린벤치 ────────────────────────────────────────────────
func _draw_hood() -> void:
	var hs := DB.HOOD_SIZE * 0.5
	var rect := Rect2(-hs, hs * 2.0)
	# 바깥 어둠
	draw_rect(rect.grow(1400.0), Color(0, 0, 0, 1))
	# 스테인리스 작업대
	draw_rect(rect, Color(0.05, 0.06, 0.08))
	for b in _blobs:
		var c: Color = b["c"]
		var r: float = float(b["r"])
		draw_texture_rect(UIKit.soft_tex, Rect2((b["pos"] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c.r * 0.7, c.g * 0.8, c.b, 0.10))
	# 브러시드 스틸 결
	var y := -hs.y
	var i := 0
	while y < hs.y:
		draw_line(Vector2(-hs.x, y), Vector2(hs.x, y), Color(0.6, 0.7, 0.85, 0.035 if i % 3 else 0.06), 1.0)
		y += 18.0
		i += 1
	# 패널 이음매
	var px := -hs.x
	while px <= hs.x:
		draw_line(Vector2(px, -hs.y), Vector2(px, hs.y), Color(0.55, 0.7, 0.95, 0.16), 2.0)
		px += 920.0
	# 앞쪽 타공 그릴(아래쪽 = 배기)
	var gy := hs.y - 170.0
	draw_rect(Rect2(-hs.x, gy, hs.x * 2.0, 170.0), Color(0.02, 0.025, 0.035))
	var gx := -hs.x + 20.0
	while gx < hs.x:
		var hy := gy + 20.0
		while hy < hs.y - 10.0:
			draw_circle(Vector2(gx, hy), 4.0, Color(0.0, 0.0, 0.0, 1.0))
			draw_arc(Vector2(gx, hy), 5.0, PI * 1.1, PI * 1.9, 4, Color(0.55, 0.7, 0.9, 0.18), 1.0)
			hy += 24.0
		gx += 24.0
	# 뒤쪽 HEPA 필터 (위쪽 = 공기 유입)
	draw_rect(Rect2(-hs.x, -hs.y, hs.x * 2.0, 120.0), Color(0.06, 0.08, 0.11))
	var fx_ := -hs.x
	while fx_ < hs.x:
		draw_line(Vector2(fx_, -hs.y), Vector2(fx_, -hs.y + 120.0), Color(0.6, 0.8, 1.0, 0.10), 1.0)
		fx_ += 14.0
	draw_line(Vector2(-hs.x, -hs.y + 120.0), Vector2(hs.x, -hs.y + 120.0), Color(0.6, 0.85, 1.0, 0.35), 2.0)
	# 배지 방울(회복)
	for d in droplets:
		var p: Vector2 = d["pos"]
		var r: float = float(d["r"])
		var g := DB.C_GFP
		draw_texture_rect(UIKit.glow_tex, Rect2(p - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(g.r, g.g, g.b, 0.18))
		draw_circle(p, r, Color(g.r, g.g, g.b, 0.10))
		draw_arc(p, r, 0.0, TAU, 48, Color(g.r, g.g, g.b, 0.55), 2.0, true)
	# 튜브 랙(통과 불가)
	for s in shards:
		var pts: PackedVector2Array = s["pts"]
		var r0 := Rect2(pts[0], pts[2] - pts[0])
		draw_rect(r0, Color(0.10, 0.13, 0.2, 0.95))
		draw_rect(r0, Color(0.6, 0.78, 1.0, 0.7), false, 2.0)
		var cols := maxi(2, int(r0.size.x / 24.0))
		var rows := maxi(1, int(r0.size.y / 24.0))
		for cx in cols:
			for cy in rows:
				var cc := r0.position + Vector2((cx + 0.5) * r0.size.x / cols, (cy + 0.5) * r0.size.y / rows)
				var tube := Color(0.95, 0.6, 0.25, 0.55) if (cx + cy) % 3 == 0 else Color(0.5, 0.65, 0.9, 0.35)
				draw_circle(cc, 7.0, tube)
				draw_arc(cc, 8.0, 0.0, TAU, 12, Color(0.8, 0.9, 1.0, 0.4), 1.0, true)
	# 테두리(측면 유리)
	for k in 3:
		draw_rect(rect.grow(k * 6.0), Color(0.45, 0.65, 1.0, 0.35 - k * 0.1), false, 3.0 - k)
