extends RefCounted
## 무기·시약 아이콘. 그림 파일 없이 코드로 그리는 형광 픽토그램.
## draw(ci, id, 중심, 크기, 색) — HUD, 레벨업 카드, 일시정지 메뉴에서 공용.

static func draw(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	var r := s * 0.5
	var w := maxf(1.5, s * 0.06)
	UIKit.glow(ci, c, r * 1.35, Color(col.r, col.g, col.b, 0.22))
	match id:
		# ── 무기 ──
		"qpcr_beam":
			_qpcr(ci, c, r, col, w)
		"gel_cutter":
			_gel(ci, c, r, col, w)
		"crispr_lance":
			_scissors(ci, c, r, col, w)
		"lentiviral_orb":
			_virus(ci, c, r, col, w)
		"nanopore_ring":
			_nanopore(ci, c, r, col, w)
		"lysozyme_field":
			_lysozyme(ci, c, r, col, w)
		"etoh_splash":
			_droplet(ci, c, r, col, w)
		"uv_flash":
			_bolt(ci, c, r, col)
		"antibody_chain":
			_antibody(ci, c, r, col, w)
		"centrifuge_wave":
			_rotor(ci, c, r, col, w)
		# ── 시약 ──
		"fbs":
			_heart(ci, c, r, col)
		"penstrep":
			_pill(ci, c, r, col, w)
		"trypsin":
			_clock(ci, c, r, col, w)
		"agarose":
			_expand(ci, c, r, col, w)
		"dmso":
			_hourglass(ci, c, r, col, w)
		"matrigel":
			_shield(ci, c, r, col, w)
		"egf":
			_speed(ci, c, r, col, w)
		"lipofectamine":
			_magnet(ci, c, r, col, w)
		"cocoa":
			_mug(ci, c, r, col, w)
		_:
			ci.draw_circle(c, r * 0.4, col)

static func _a(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, a)

# qPCR: 증폭 곡선(S자) + 축 + 역치선
static func _qpcr(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	var o := c + Vector2(-0.7, 0.7) * r
	ci.draw_line(o, c + Vector2(-0.7, -0.75) * r, _a(col, 0.45), w * 0.7)
	ci.draw_line(o, c + Vector2(0.78, 0.7) * r, _a(col, 0.45), w * 0.7)
	ci.draw_line(c + Vector2(-0.65, 0.05) * r, c + Vector2(0.75, 0.05) * r, _a(col, 0.3), w * 0.5)
	var pts := PackedVector2Array()
	for i in 24:
		var x := lerpf(-0.65, 0.72, i / 23.0)
		var y := 0.6 - 1.25 / (1.0 + exp(-(x - 0.1) * 9.0))
		pts.append(c + Vector2(x, y) * r)
	ci.draw_polyline(pts, col, w * 1.4, true)

# Gel Cutter: 겔 레인과 밴드 + 사선 칼날
static func _gel(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	var g := Rect2(c + Vector2(-0.62, -0.72) * r, Vector2(1.24, 1.44) * r)
	ci.draw_rect(g, _a(col, 0.14))
	ci.draw_rect(g, _a(col, 0.55), false, w * 0.7)
	var bands := [[-0.35, -0.3], [-0.35, 0.2], [0.0, -0.1], [0.0, 0.45], [0.35, -0.42], [0.35, 0.05]]
	for b in bands:
		var bx: float = float(b[0])
		var by: float = float(b[1])
		ci.draw_line(c + Vector2(bx - 0.14, by) * r, c + Vector2(bx + 0.14, by) * r, col, w * 1.1)
	ci.draw_line(c + Vector2(-0.85, 0.85) * r, c + Vector2(0.88, -0.88) * r, Color(0.92, 1.0, 1.0, 0.95), w * 1.3, true)

# CRISPR: 분자 가위
static func _scissors(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	var piv := c + Vector2(0.05, 0.0) * r
	ci.draw_colored_polygon(PackedVector2Array([piv + Vector2(-0.12, 0.1) * r, c + Vector2(0.86, -0.5) * r, piv + Vector2(0.14, 0.12) * r]), col)
	ci.draw_colored_polygon(PackedVector2Array([piv + Vector2(-0.1, -0.12) * r, c + Vector2(0.5, -0.86) * r, piv + Vector2(0.12, -0.1) * r]), col.lightened(0.3))
	ci.draw_line(piv, c + Vector2(-0.38, 0.3) * r, col, w * 1.8, true)
	ci.draw_line(piv, c + Vector2(-0.1, 0.45) * r, col, w * 1.8, true)
	ci.draw_arc(c + Vector2(-0.55, 0.45) * r, r * 0.26, 0.0, TAU, 18, col, w * 1.6, true)
	ci.draw_arc(c + Vector2(-0.12, 0.7) * r, r * 0.24, 0.0, TAU, 18, col, w * 1.6, true)
	ci.draw_circle(piv, r * 0.09, Color(1, 1, 1, 0.9))

# Lentivirus: 스파이크 단백질이 달린 바이러스 입자
static func _virus(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	for i in 10:
		var d := Vector2.from_angle(TAU * i / 10.0)
		ci.draw_line(c + d * r * 0.45, c + d * r * 0.72, col, w, true)
		ci.draw_circle(c + d * r * 0.76, r * 0.08, col)
	ci.draw_circle(c, r * 0.45, _a(col, 0.25))
	ci.draw_arc(c, r * 0.45, 0.0, TAU, 24, col, w * 1.1, true)
	var rna := PackedVector2Array()
	for i in 9:
		rna.append(c + Vector2(lerpf(-0.25, 0.25, i / 8.0), sin(i * 1.4) * 0.1) * r)
	ci.draw_polyline(rna, Color(0.9, 1.0, 1.0, 0.9), w * 0.8, true)

# Nanopore: 중심 둘레를 도는 기공(도넛) 3개
static func _nanopore(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_arc(c, r * 0.55, 0.0, TAU, 32, _a(col, 0.3), w * 0.6, true)
	ci.draw_circle(c, r * 0.14, _a(col, 0.6))
	for i in 3:
		var p := c + Vector2.from_angle(TAU * i / 3.0 - PI / 2.0) * r * 0.55
		ci.draw_arc(p, r * 0.2, 0.0, TAU, 16, col, w * 1.2, true)
		ci.draw_circle(p, r * 0.06, Color(0.9, 0.95, 1.0, 0.9))

# Lysozyme: 균을 먹는 효소(팩맨) + 효소 장
static func _lysozyme(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_arc(c, r * 0.8, 0.0, TAU, 32, _a(col, 0.35), w * 0.7, true)
	var pts := PackedVector2Array([c + Vector2(-0.12, 0) * r])
	for i in 21:
		var a := lerpf(0.55, TAU - 0.55, i / 20.0)
		pts.append(c + Vector2(-0.12, 0) * r + Vector2.from_angle(a) * r * 0.45)
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c + Vector2(-0.15, -0.22) * r, r * 0.06, Color(0.03, 0.04, 0.09))
	var rod := Rect2(c + Vector2(0.38, -0.08) * r, Vector2(0.36, 0.16) * r)
	ci.draw_rect(rod, Color(1.0, 0.35, 0.4, 0.9))

# 70% EtOH: 물방울 + 웅덩이
static func _droplet(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_set_transform(c + Vector2(0, 0.66) * r, 0.0, Vector2(1.0, 0.32))
	ci.draw_circle(Vector2.ZERO, r * 0.7, _a(col, 0.25))
	ci.draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 28, _a(col, 0.7), w * 1.5, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var dc := c + Vector2(0, 0.05) * r
	var pts := PackedVector2Array([c + Vector2(0, -0.8) * r])
	for i in 17:
		var a := lerpf(-PI / 6.0, PI + PI / 6.0, i / 16.0)
		pts.append(dc + Vector2(cos(a), sin(a)) * r * 0.4)
	ci.draw_colored_polygon(pts, _a(col, 0.85))
	ci.draw_circle(dc + Vector2(-0.14, -0.08) * r, r * 0.08, Color(1, 1, 1, 0.85))

# UV: 번개
static func _bolt(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(0.18, -0.88), Vector2(-0.48, 0.12), Vector2(-0.06, 0.12), Vector2(-0.22, 0.88), Vector2(0.48, -0.16), Vector2(0.06, -0.16)])
	for i in pts.size():
		pts[i] = c + pts[i] * r
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.6), 1.2, true)

# Antibody: Y자 항체
static func _antibody(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	var j := c + Vector2(0, 0.05) * r
	ci.draw_line(j, c + Vector2(0, 0.8) * r, col, w * 2.0, true)
	ci.draw_line(j, c + Vector2(-0.58, -0.62) * r, col, w * 2.0, true)
	ci.draw_line(j, c + Vector2(0.58, -0.62) * r, col, w * 2.0, true)
	ci.draw_line(c + Vector2(-0.38, 0.0) * r, c + Vector2(-0.8, -0.45) * r, col.lightened(0.3), w * 1.3, true)
	ci.draw_line(c + Vector2(0.38, 0.0) * r, c + Vector2(0.8, -0.45) * r, col.lightened(0.3), w * 1.3, true)
	ci.draw_circle(c + Vector2(-0.62, -0.66) * r, r * 0.1, Color(1, 1, 1, 0.9))
	ci.draw_circle(c + Vector2(0.62, -0.66) * r, r * 0.1, Color(1, 1, 1, 0.9))

# Centrifuge: 로터 + 회전 화살
static func _rotor(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_circle(c, r * 0.58, _a(col, 0.18))
	ci.draw_arc(c, r * 0.58, 0.0, TAU, 32, col, w, true)
	for i in 6:
		ci.draw_circle(c + Vector2.from_angle(TAU * i / 6.0) * r * 0.38, r * 0.09, col)
	ci.draw_circle(c, r * 0.1, Color(1, 1, 1, 0.85))
	ci.draw_arc(c, r * 0.82, -PI * 0.9, -PI * 0.35, 12, _a(col, 0.8), w, true)
	ci.draw_arc(c, r * 0.82, PI * 0.1, PI * 0.65, 12, _a(col, 0.8), w, true)

# FBS: 하트(HP)
static func _heart(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y + 2.0) / 17.0 * r * 0.85)
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c + Vector2(-0.3, -0.25) * r, r * 0.1, Color(1, 1, 1, 0.7))

# Pen-Strep: 항생제 캡슐 + 타격 별(피해)
static func _pill(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_set_transform(c + Vector2(-0.1, 0.1) * r, -PI / 4.0, Vector2.ONE)
	var hl := r * 0.48
	var hw := r * 0.27
	ci.draw_rect(Rect2(-hl, -hw, hl, hw * 2.0), col)
	ci.draw_rect(Rect2(0, -hw, hl, hw * 2.0), Color(0.95, 0.97, 1.0))
	ci.draw_circle(Vector2(-hl, 0), hw, col)
	ci.draw_circle(Vector2(hl, 0), hw, Color(0.95, 0.97, 1.0))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sc := c + Vector2(0.48, -0.48) * r
	for i in 4:
		var d := Vector2.from_angle(PI / 4.0 + i * PI / 2.0)
		ci.draw_line(sc - d * r * 0.25, sc + d * r * 0.25, DB.C_WARN, w, true)

# Trypsin: 시계(쿨다운)
static func _clock(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_circle(c, r * 0.62, _a(col, 0.18))
	ci.draw_arc(c, r * 0.62, 0.0, TAU, 32, col, w * 1.2, true)
	ci.draw_line(c, c + Vector2(0, -0.42) * r, col, w * 1.3, true)
	ci.draw_line(c, c + Vector2(0.3, 0.12) * r, col, w * 1.3, true)
	ci.draw_arc(c, r * 0.84, -PI * 0.85, -PI * 0.15, 12, Color(1, 1, 1, 0.7), w, true)
	var tip := c + Vector2.from_angle(-PI * 0.15) * r * 0.84
	ci.draw_line(tip, tip + Vector2(-0.16, -0.06) * r, Color(1, 1, 1, 0.7), w, true)
	ci.draw_line(tip, tip + Vector2(-0.02, -0.18) * r, Color(1, 1, 1, 0.7), w, true)

# Agarose: 바깥으로 퍼지는 화살표(범위)
static func _expand(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_rect(Rect2(c - Vector2(0.18, 0.18) * r, Vector2(0.36, 0.36) * r), col)
	for i in 4:
		var d := Vector2.from_angle(PI / 4.0 + i * PI / 2.0)
		var a := c + d * r * 0.35
		var b := c + d * r * 0.82
		ci.draw_line(a, b, col, w * 1.2, true)
		ci.draw_line(b, b - d.rotated(0.6) * r * 0.22, col, w * 1.2, true)
		ci.draw_line(b, b - d.rotated(-0.6) * r * 0.22, col, w * 1.2, true)

# DMSO: 모래시계(지속시간)
static func _hourglass(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_line(c + Vector2(-0.5, -0.78) * r, c + Vector2(0.5, -0.78) * r, col, w * 1.4)
	ci.draw_line(c + Vector2(-0.5, 0.78) * r, c + Vector2(0.5, 0.78) * r, col, w * 1.4)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-0.4, -0.75) * r, c + Vector2(0.4, -0.75) * r, c + Vector2(0.05, 0.0) * r, c + Vector2(0.4, 0.75) * r, c + Vector2(-0.4, 0.75) * r, c + Vector2(-0.05, 0.0) * r, c + Vector2(-0.4, -0.75) * r]), col, w, true)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.3, 0.7) * r, c + Vector2(0.3, 0.7) * r, c + Vector2(0.0, 0.32) * r]), _a(col, 0.8))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.18, -0.45) * r, c + Vector2(0.18, -0.45) * r, c + Vector2(0.0, -0.18) * r]), _a(col, 0.8))

# Matrigel: 방패(방어)
static func _shield(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array([Vector2(0, -0.82), Vector2(0.62, -0.55), Vector2(0.55, 0.15), Vector2(0, 0.85), Vector2(-0.55, 0.15), Vector2(-0.62, -0.55)])
	for i in pts.size():
		pts[i] = c + pts[i] * r
	ci.draw_colored_polygon(pts, _a(col, 0.3))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), col, w * 1.3, true)
	ci.draw_line(c + Vector2(0, -0.55) * r, c + Vector2(0, 0.55) * r, _a(col, 0.8), w)
	ci.draw_line(c + Vector2(-0.38, -0.15) * r, c + Vector2(0.38, -0.15) * r, _a(col, 0.8), w)

# EGF: 겹화살(속도)
static func _speed(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	for k in 2:
		var x := -0.3 + k * 0.42
		ci.draw_polyline(PackedVector2Array([c + Vector2(x - 0.2, -0.5) * r, c + Vector2(x + 0.2, 0.0) * r, c + Vector2(x - 0.2, 0.5) * r]), col, w * 1.8, true)
	for k in 3:
		var y := -0.3 + k * 0.3
		ci.draw_line(c + Vector2(-0.88, y) * r, c + Vector2(-0.58, y) * r, _a(col, 0.55), w * 0.8)

# Lipofectamine: 자석(획득 반경)
static func _magnet(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	var cc := c + Vector2(0, 0.08) * r
	ci.draw_arc(cc, r * 0.45, 0.0, PI, 16, col, r * 0.28)
	ci.draw_line(cc + Vector2(-0.45, 0) * r, cc + Vector2(-0.45, -0.55) * r, col, r * 0.28)
	ci.draw_line(cc + Vector2(0.45, 0) * r, cc + Vector2(0.45, -0.55) * r, col, r * 0.28)
	ci.draw_rect(Rect2(cc + Vector2(-0.59, -0.75) * r, Vector2(0.28, 0.22) * r), Color(0.95, 0.97, 1.0))
	ci.draw_rect(Rect2(cc + Vector2(0.31, -0.75) * r, Vector2(0.28, 0.22) * r), Color(0.95, 0.97, 1.0))

# 핫코코아
static func _mug(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-0.5, -0.3) * r, Vector2(0.8, 0.85) * r), Color(0.95, 0.9, 0.85))
	ci.draw_rect(Rect2(c + Vector2(-0.42, -0.22) * r, Vector2(0.64, 0.2) * r), Color(0.5, 0.28, 0.18))
	ci.draw_arc(c + Vector2(0.32, 0.12) * r, r * 0.2, -PI / 2.0, PI / 2.0, 8, Color(0.95, 0.9, 0.85), w * 1.3, true)
	for i in 3:
		var x := -0.35 + i * 0.25
		ci.draw_line(c + Vector2(x, -0.45) * r, c + Vector2(x + 0.06, -0.75) * r, _a(col, 0.6), w, true)
