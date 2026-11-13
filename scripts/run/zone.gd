extends Node2D
## 70% EtOH 장판. 위에 있는 적에게 일정 간격으로 피해.

var r := 60.0
var dmg := 5.0
var life := 2.5
var total := 2.5
var tick_every := 0.4
var col := Color(0.55, 0.85, 1.0)
var dead := false
var _tick := 0.0

func _ready() -> void:
	material = UIKit.add_mat
	z_index = -1
	queue_redraw()

func tick(delta: float, world: Node) -> void:
	life -= delta
	if life <= 0.0:
		dead = true
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_every
		for e in world.query(position, r):
			world.damage_enemy(e, dmg, Vector2.ZERO, 0.0, col)
	modulate.a = clampf(life / 0.4, 0.0, 1.0) * clampf((total - life) / 0.12, 0.0, 1.0)

func _draw() -> void:
	var c := col
	UIKit.glow(self, Vector2.ZERO, r * 1.5, Color(c.r, c.g, c.b, 0.18))
	draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.12))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.7), 2.0, true)
	draw_arc(Vector2.ZERO, r * 0.66, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.3), 1.2, true)
	draw_arc(Vector2.ZERO, r * 0.33, 0.0, TAU, 24, Color(c.r, c.g, c.b, 0.2), 1.0, true)
