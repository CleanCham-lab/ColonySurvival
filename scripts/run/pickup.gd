extends Node2D
## 주울 것(초록): ATP(경험치), 핫코코아(회복), 볼텍스(자석), 선물상자(강화/진화).

var kind := "gem"
var value := 1
var col := DB.C_GFP
var radius := 6.0
var attracted := false
var dead := false
var vel := Vector2.ZERO
var _t := 0.0

func setup(k: String, v := 1) -> void:
	kind = k
	value = v
	match kind:
		"gem":
			if value >= 25:
				col = DB.C_GFP.lerp(Color(1, 1, 1), 0.35)
				radius = 9.0
			elif value >= 5:
				col = DB.C_GFP.lerp(Color(1, 1, 1), 0.18)
				radius = 7.0
			else:
				col = DB.C_GFP
				radius = 5.0
		"cocoa":
			col = Color(1.0, 0.85, 0.6)
			radius = 12.0
		"vortex":
			col = DB.C_GFP
			radius = 12.0
		"gift":
			col = DB.C_GFP
			radius = 16.0
	_t = randf() * TAU

func _ready() -> void:
	material = UIKit.add_mat
	queue_redraw()

## 플레이어에게 닿으면 true
func tick(delta: float, player: Node2D) -> bool:
	_t += delta
	var to := player.position - position
	var d := to.length()
	if not attracted:
		var grab: float = player.magnet if kind == "gem" else player.radius + radius + 8.0
		if d < grab:
			attracted = true
	if attracted:
		vel = vel.move_toward(to.normalized() * 760.0, 2600.0 * delta)
		position += vel * delta
		if d < player.radius + radius:
			return true
	if kind != "gem":
		scale = Vector2.ONE * (1.0 + 0.08 * sin(_t * 4.0))
	return false

func _draw() -> void:
	var c := col
	match kind:
		"gem":
			UIKit.glow(self, Vector2.ZERO, radius * 3.0, Color(c.r, c.g, c.b, 0.55))
			var pts := PackedVector2Array([Vector2(0, -radius), Vector2(radius * 0.8, 0), Vector2(0, radius), Vector2(-radius * 0.8, 0)])
			draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.75))
			draw_circle(Vector2(0, -radius * 0.2), radius * 0.25, Color(0.9, 1.0, 0.9, 0.9))
		"cocoa":
			UIKit.glow(self, Vector2.ZERO, 40.0, Color(1.0, 0.75, 0.45, 0.45))
			draw_rect(Rect2(-9, -6, 16, 16), Color(0.95, 0.9, 0.85, 0.9))
			draw_rect(Rect2(-7, -4, 12, 4), Color(0.55, 0.3, 0.2, 0.9))
			draw_arc(Vector2(8, 2), 5.0, -PI / 2.0, PI / 2.0, 8, Color(0.95, 0.9, 0.85, 0.9), 2.0, true)
			for i in 3:
				draw_line(Vector2(-5 + i * 5, -9), Vector2(-3 + i * 5, -16), Color(1, 1, 1, 0.5), 1.5, true)
		"vortex":
			UIKit.glow(self, Vector2.ZERO, 44.0, Color(c.r, c.g, c.b, 0.5))
			var sp := PackedVector2Array()
			for i in 30:
				var t := i / 29.0
				sp.append(Vector2.from_angle(t * TAU * 2.0) * (2.0 + t * 11.0))
			draw_polyline(sp, c, 2.0, true)
		"gift":
			UIKit.glow(self, Vector2.ZERO, 60.0, Color(c.r, c.g, c.b, 0.55))
			var r := radius
			draw_rect(Rect2(-r, -r * 0.7, r * 2.0, r * 1.6), Color(c.r * 0.6, c.g * 0.75, c.b * 0.6, 0.85))
			draw_rect(Rect2(-r * 1.1, -r * 0.95, r * 2.2, r * 0.4), Color(c.r * 0.85, c.g * 0.9, c.b * 0.75, 0.95))
			var red := Color(1.0, 0.25, 0.35) if DB.palette == "default" else Color(0.95, 0.95, 1.0)
			draw_rect(Rect2(-r * 0.18, -r * 0.95, r * 0.36, r * 1.85), red)
			draw_circle(Vector2(-r * 0.35, -r * 1.1), r * 0.3, red)
			draw_circle(Vector2(r * 0.35, -r * 1.1), r * 0.3, red)
