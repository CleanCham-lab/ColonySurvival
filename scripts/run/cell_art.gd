extends RefCounted
## 셀 캐릭터 그리기 (플레이어 / 캐릭터 선택 화면 공용).
## 형광현미경 느낌: 반투명 막 + 밝은 외곽선 + 핵(DAPI) + 번짐.

static func circle_points(r: float, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.from_angle(TAU * i / n) * r)
	return pts

static func blob_points(r: float, n: int, seed_val: int, jitter: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.from_angle(TAU * i / n) * r * (1.0 + rng.randf_range(-jitter, jitter)))
	return pts

## 닫힌 Catmull-Rom 곡선으로 매끈하게
static func smooth_closed(pts: PackedVector2Array, sub := 5) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		for s in sub:
			var t := float(s) / sub
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out

static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	if c.size() > 0:
		c.append(c[0])
	return c

static func amoeba_points(r: float, lobes := 3, phase := 0.6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 36
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + 0.38 * pow(maxf(0.0, sin(lobes * a + phase)), 2.0)
		pts.append(Vector2.from_angle(a) * r * k)
	return pts

static func body_points(shape: String, r: float) -> PackedVector2Array:
	match shape:
		"spread":
			return smooth_closed(blob_points(r * 1.12, 7, 11, 0.30), 5)
		"amoeba":
			return amoeba_points(r * 0.95)
		_:
			return circle_points(r, 32)

static func draw_cell(ci: CanvasItem, shape: String, r: float, col: Color, core: Color, hat: String) -> void:
	UIKit.glow(ci, Vector2.ZERO, r * 3.4, Color(col.r, col.g, col.b, 0.50))
	var body := body_points(shape, r)
	ci.draw_colored_polygon(body, Color(col.r * 0.5, col.g * 0.5, col.b * 0.6, 0.85))
	ci.draw_colored_polygon(body, Color(col.r, col.g, col.b, 0.22))
	ci.draw_polyline(closed(body), Color(col.r, col.g, col.b, 1.0), 2.2, true)
	# 핵 (DAPI)
	var nuc := Vector2(0, r * 0.06)
	UIKit.glow(ci, nuc, r * 1.1, Color(core.r, core.g, core.b, 0.55))
	ci.draw_circle(nuc, r * 0.52, Color(core.r, core.g, core.b, 0.95))
	ci.draw_circle(nuc + Vector2(r * 0.18, r * 0.16), r * 0.12, Color(0.75, 0.82, 1.0, 0.45))
	# 얼굴
	var ink := Color(0.03, 0.04, 0.09)
	ci.draw_circle(Vector2(-r * 0.22, -r * 0.02), r * 0.10, ink)
	ci.draw_circle(Vector2(r * 0.22, -r * 0.02), r * 0.10, ink)
	ci.draw_circle(Vector2(-r * 0.19, -r * 0.06), r * 0.035, Color(1, 1, 1, 0.9))
	ci.draw_circle(Vector2(r * 0.25, -r * 0.06), r * 0.035, Color(1, 1, 1, 0.9))
	ci.draw_arc(Vector2(0, r * 0.12), r * 0.16, 0.35, PI - 0.35, 10, ink, maxf(1.2, r * 0.07), true)
	match hat:
		"santa":
			_santa_hat(ci, r)
		"antlers":
			_antlers(ci, r)
		"elf":
			_elf_hat(ci, r)

static func _santa_hat(ci: CanvasItem, r: float) -> void:
	var o := Vector2(0, r * 0.18)  # 모자를 세포 위에 살짝 걸치게
	var red := Color(0.95, 0.20, 0.28)
	var tip := Vector2(r * 0.75, -r * 2.15) + o
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.78, -r * 0.82) + o, Vector2(r * 0.80, -r * 0.82) + o, Vector2(r * 0.42, -r * 1.55) + o, tip]), red)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.78, -r * 0.82) + o, Vector2(r * 0.42, -r * 1.55) + o, tip]), red.darkened(0.15))
	ci.draw_rect(Rect2(Vector2(-r * 0.95, -r * 1.0) + o, Vector2(r * 1.9, r * 0.34)), Color(0.96, 0.96, 1.0))
	ci.draw_circle(Vector2(-r * 0.95, -r * 0.83) + o, r * 0.17, Color(0.96, 0.96, 1.0))
	ci.draw_circle(Vector2(r * 0.95, -r * 0.83) + o, r * 0.17, Color(0.96, 0.96, 1.0))
	ci.draw_circle(tip, r * 0.22, Color(0.98, 0.98, 1.0))

static func _antlers(ci: CanvasItem, r: float) -> void:
	var c := Color(0.92, 0.72, 0.45)
	var w := maxf(2.0, r * 0.13)
	for s in [-1.0, 1.0]:
		var base := Vector2(s * r * 0.45, -r * 0.82)
		var top := base + Vector2(s * r * 0.55, -r * 1.05)
		ci.draw_line(base, top, c, w, true)
		ci.draw_line(base + (top - base) * 0.45, base + (top - base) * 0.45 + Vector2(-s * r * 0.15, -r * 0.45), c, w * 0.85, true)
		ci.draw_line(base + (top - base) * 0.75, top + Vector2(s * r * 0.35, -r * 0.05), c, w * 0.85, true)
	# 루돌프 코
	UIKit.glow(ci, Vector2(0, r * 0.1), r * 0.55, Color(1.0, 0.25, 0.3, 0.6))
	ci.draw_circle(Vector2(0, r * 0.1), r * 0.12, Color(1.0, 0.3, 0.35))

static func _elf_hat(ci: CanvasItem, r: float) -> void:
	var g := Color(0.20, 0.62, 0.42)
	var tip := Vector2(r * 1.75, -r * 1.55)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.80, -r * 0.78), Vector2(r * 0.78, -r * 0.86), tip]), g)
	ci.draw_rect(Rect2(-r * 0.9, -r * 0.98, r * 1.8, r * 0.26), Color(0.85, 0.20, 0.28))
	UIKit.glow(ci, tip, r * 0.7, Color(1.0, 0.85, 0.3, 0.6))
	ci.draw_circle(tip, r * 0.2, Color(1.0, 0.86, 0.35))

## 꼬리(이동 방향 반대)로 늘어지는 작은 캡슐
static func capsule_points(half_len: float, half_w: float, seg := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(seg + 1):
		var a := -PI / 2.0 + PI * i / seg
		pts.append(Vector2(half_len, 0) + Vector2.from_angle(a) * half_w)
	for i in range(seg + 1):
		var a := PI / 2.0 + PI * i / seg
		pts.append(Vector2(-half_len, 0) + Vector2.from_angle(a) * half_w)
	return pts
