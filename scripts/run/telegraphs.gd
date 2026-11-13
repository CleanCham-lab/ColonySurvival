extends Node2D
## 경고 표시(노랑). 시간이 차면 콜백(실제 공격)을 부른다.

var items: Array = []

func _ready() -> void:
	z_index = 4

func add_line(a: Vector2, b: Vector2, width: float, dur: float, c: Color, cb: Callable = Callable()) -> void:
	items.append({"type": "line", "a": a, "b": b, "w": width, "t": 0.0, "dur": dur, "c": c, "cb": cb})

func add_circle(pos: Vector2, r: float, dur: float, c: Color, cb: Callable = Callable()) -> void:
	items.append({"type": "circle", "pos": pos, "r": r, "t": 0.0, "dur": dur, "c": c, "cb": cb})

## Major Revision 표시: 원 + X
func add_x(pos: Vector2, r: float, dur: float, c: Color, cb: Callable = Callable()) -> void:
	items.append({"type": "circle", "pos": pos, "r": r, "t": 0.0, "dur": dur, "c": c, "cb": cb, "x": true})

func clear() -> void:
	items.clear()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if items.is_empty():
		return
	var done: Array = []
	var keep: Array = []
	for it in items:
		it["t"] = float(it["t"]) + delta
		if float(it["t"]) >= float(it["dur"]):
			done.append(it)
		else:
			keep.append(it)
	items = keep
	for it in done:
		var cb: Callable = it["cb"]
		if cb.is_valid():
			cb.call()
	queue_redraw()

func _draw() -> void:
	for it in items:
		var f: float = clampf(float(it["t"]) / float(it["dur"]), 0.0, 1.0)
		var c: Color = it["c"]
		var blink := 0.65 + 0.35 * sin(float(it["t"]) * 30.0) if f > 0.7 else 1.0
		match String(it["type"]):
			"line":
				var a: Vector2 = it["a"]
				var b: Vector2 = it["b"]
				var w: float = float(it["w"])
				var d := b - a
				draw_set_transform(a, d.angle(), Vector2.ONE)
				draw_rect(Rect2(0, -w / 2.0, d.length(), w), Color(c.r, c.g, c.b, 0.10 * blink))
				draw_rect(Rect2(0, -w / 2.0, d.length() * f, w), Color(c.r, c.g, c.b, 0.22 * blink))
				draw_line(Vector2(0, -w / 2.0), Vector2(d.length(), -w / 2.0), Color(c.r, c.g, c.b, 0.8 * blink), 1.5)
				draw_line(Vector2(0, w / 2.0), Vector2(d.length(), w / 2.0), Color(c.r, c.g, c.b, 0.8 * blink), 1.5)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"circle":
				var p: Vector2 = it["pos"]
				var r: float = float(it["r"])
				draw_circle(p, r, Color(c.r, c.g, c.b, 0.10 * blink))
				draw_circle(p, r * f, Color(c.r, c.g, c.b, 0.20 * blink))
				draw_arc(p, r, 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.9 * blink), 2.0, true)
				if bool(it.get("x", false)):
					var e := DB.C_ENEMY
					draw_line(p + Vector2(-r, -r) * 0.6, p + Vector2(r, r) * 0.6, Color(e.r, e.g, e.b, 0.9 * blink), 5.0)
					draw_line(p + Vector2(-r, r) * 0.6, p + Vector2(r, -r) * 0.6, Color(e.r, e.g, e.b, 0.9 * blink), 5.0)
