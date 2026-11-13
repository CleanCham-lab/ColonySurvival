extends "res://scripts/run/weapons/weapon_base.gd"
## Nanopore Ring: 몸 주위를 도는 기공. 지속시간 동안 돌고, 쿨다운 동안 쉰다.

var active := 0.0
var angle := 0.0
var _hitcd := {}
var _fade := 0.0

func _ready() -> void:
	material = UIKit.add_mat

func ring_radius() -> float:
	return 95.0 * area()

func tick(delta: float) -> void:
	if active > 0.0:
		active -= delta
		_fade = minf(1.0, _fade + delta * 6.0)
		angle += float(stats.get("speed", 3.0)) * delta
		var n := cnt()
		var rad := ring_radius()
		var now: float = world.t
		for i in n:
			var p: Vector2 = player.position + Vector2.from_angle(angle + TAU * i / n) * rad
			for e in world.query(p, 13.0 * area()):
				var id: int = e.get_instance_id()
				if float(_hitcd.get(id, -1.0)) > now:
					continue
				_hitcd[id] = now + 0.45
				world.damage_enemy(e, dmg(), ((e as Node2D).position - player.position).normalized(), 140.0, color())
		if active <= 0.0:
			timer = cd()
			_hitcd.clear()
		queue_redraw()
	else:
		if _fade > 0.0:
			_fade = maxf(0.0, _fade - delta * 6.0)
			queue_redraw()
		timer -= delta
		if timer <= 0.0:
			active = dur()

func _draw() -> void:
	if _fade <= 0.0:
		return
	var c := color()
	var n := cnt()
	var rad := ring_radius()
	var pr := 11.0 * area()
	for i in n:
		var p := Vector2.from_angle(angle + TAU * i / n) * rad
		UIKit.glow(self, p, pr * 2.8, Color(c.r, c.g, c.b, 0.55 * _fade))
		draw_arc(p, pr, 0.0, TAU, 20, Color(c.r, c.g, c.b, _fade), 3.0, true)
		draw_circle(p, pr * 0.35, Color(0.85, 0.95, 1.0, 0.8 * _fade))
