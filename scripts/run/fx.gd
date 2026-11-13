extends Node2D
## 짧은 이펙트를 한 노드에서 몰아서 그린다(성능): 사망 번짐, 베기, UV, 균사, 피해 숫자.

const MAX_NUMBERS := 90

var items: Array = []
var numbers: Array = []
var show_numbers := true

func _ready() -> void:
	material = UIKit.add_mat
	z_index = 6
	show_numbers = bool(Save.setting("damage_numbers"))

func _process(delta: float) -> void:
	for it in items:
		it["t"] = float(it["t"]) + delta
	items = items.filter(func(it: Dictionary) -> bool: return float(it["t"]) < float(it["dur"]))
	for n in numbers:
		n["t"] = float(n["t"]) + delta
		n["pos"] = (n["pos"] as Vector2) + Vector2(0, -38.0 * delta)
	numbers = numbers.filter(func(n: Dictionary) -> bool: return float(n["t"]) < 0.6)
	queue_redraw()

func burst(pos: Vector2, c: Color, r: float) -> void:
	items.append({"type": "burst", "pos": pos, "t": 0.0, "dur": 0.38, "c": c, "r": r})

func ring(pos: Vector2, c: Color, r0: float, r1: float, dur: float, width := 3.0) -> void:
	items.append({"type": "ring", "pos": pos, "t": 0.0, "dur": dur, "c": c, "r0": r0, "r1": r1, "w": width})

func slash(pos: Vector2, dir: Vector2, size: float, c: Color) -> void:
	items.append({"type": "slash", "pos": pos, "t": 0.0, "dur": 0.2, "c": c, "r": size, "a": dir.angle()})

func uv(pos: Vector2, r: float, c: Color) -> void:
	items.append({"type": "uv", "pos": pos, "t": 0.0, "dur": 0.3, "c": c, "r": r})

func hyphae(a: Vector2, b: Vector2, c: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var n := 18
	var nrm := (b - a).normalized().orthogonal()
	for i in range(n + 1):
		var t := float(i) / n
		pts.append(a.lerp(b, t) + nrm * sin(t * 37.0) * width * 0.25)
	items.append({"type": "hyphae", "pts": pts, "t": 0.0, "dur": 0.4, "c": c, "w": width})

func uv_band(y: float, h: float, half_w: float) -> void:
	items.append({"type": "uvband", "pos": Vector2(0, y), "t": 0.0, "dur": 0.55, "c": Color(0.7, 0.45, 1.0), "h": h, "w": half_w})

func number(pos: Vector2, v: float, c: Color) -> void:
	if v < 1.0 or not bool(Save.setting("damage_numbers")):
		return
	if numbers.size() >= MAX_NUMBERS:
		numbers.pop_front()
	numbers.append({"pos": pos + Vector2(randf_range(-6, 6), 0), "t": 0.0, "v": int(round(v)), "c": c})

func _draw() -> void:
	for it in items:
		var f: float = float(it["t"]) / float(it["dur"])
		var c: Color = it["c"]
		match String(it["type"]):
			"burst":
				var r: float = float(it["r"])
				var p: Vector2 = it["pos"]
				UIKit.glow(self, p, r * (2.0 + 2.0 * f), Color(c.r, c.g, c.b, 0.5 * (1.0 - f)))
				draw_arc(p, r * (0.8 + 1.6 * f), 0.0, TAU, 24, Color(c.r, c.g, c.b, 0.9 * (1.0 - f)), maxf(1.0, 3.0 * (1.0 - f)), true)
			"ring":
				var rr: float = lerpf(float(it["r0"]), float(it["r1"]), f)
				draw_arc(it["pos"], rr, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.85 * (1.0 - f)), float(it["w"]) * (1.0 - f * 0.5), true)
			"slash":
				var p: Vector2 = it["pos"]
				var a: float = float(it["a"])
				var r: float = float(it["r"])
				var al := 1.0 - f
				draw_arc(p - Vector2.from_angle(a) * r * 0.55, r, a - 1.0, a + 1.0, 20, Color(c.r, c.g, c.b, 0.9 * al), 6.0 * al + 1.0, true)
				draw_arc(p - Vector2.from_angle(a) * r * 0.55, r * 0.86, a - 0.85, a + 0.85, 16, Color(0.9, 1.0, 1.0, 0.7 * al), 2.0, true)
			"uv":
				var p: Vector2 = it["pos"]
				var r: float = float(it["r"])
				var al := 1.0 - f
				draw_line(p + Vector2(0, -420), p, Color(c.r, c.g, c.b, 0.55 * al), 10.0 * al + 2.0)
				draw_line(p + Vector2(0, -420), p, Color(1, 1, 1, 0.8 * al), 2.0)
				UIKit.glow(self, p, r * 2.0, Color(c.r, c.g, c.b, 0.7 * al))
				draw_arc(p, r * (0.6 + 0.6 * f), 0.0, TAU, 28, Color(c.r, c.g, c.b, al), 2.5, true)
			"uvband":
				var p: Vector2 = it["pos"]
				var h: float = float(it["h"])
				var hw: float = float(it["w"])
				var al := 1.0 - f
				draw_rect(Rect2(-hw, p.y - h * 0.5, hw * 2.0, h), Color(c.r, c.g, c.b, 0.45 * al))
				draw_rect(Rect2(-hw, p.y - h * 0.12, hw * 2.0, h * 0.24), Color(1, 1, 1, 0.5 * al))
			"hyphae":
				var al := 1.0 - f
				draw_polyline(it["pts"], Color(c.r, c.g, c.b, 0.9 * al), float(it["w"]) * 0.45 * al + 2.0, true)
				draw_polyline(it["pts"], Color(1.0, 0.9, 0.7, 0.8 * al), 2.0, true)
	for n in numbers:
		var f: float = float(n["t"]) / 0.6
		var c: Color = n["c"]
		var col := Color(lerpf(1.0, c.r, 0.3), lerpf(1.0, c.g, 0.3), lerpf(1.0, c.b, 0.3), 1.0 - f * f)
		var s := str(n["v"])
		UIKit.text(self, (n["pos"] as Vector2) - Vector2(UIKit.text_width(s, 15, true) * 0.5, 0.0), s, 15, col, true)
