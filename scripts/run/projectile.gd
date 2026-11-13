extends Node2D
## 아군 투사체(빔, 창, 구슬, 항체). 이동·충돌은 World가 tick()으로 호출.

var vel := Vector2.ZERO
var speed := 600.0
var damage := 10.0
var pierce := 0
var radius := 6.0
var life := 1.0
var style := "beam"
var col := Color(0.35, 0.95, 1.0)
var homing := 0.0
var target: Variant = null
var bounces := 0
var bounce_range := 260.0
var knockback := 0.0
var boss_bonus := 1.0
var execute_below := 0.0
var on_hit: Callable = Callable()
var dead := false
var length := 26.0
var _hit := {}
var _spin := 0.0

func _ready() -> void:
	material = UIKit.add_mat
	rotation = vel.angle()
	queue_redraw()

func tick(delta: float, world: Node) -> void:
	life -= delta
	if life <= 0.0:
		dead = true
		return
	if homing > 0.0:
		if target == null or not is_instance_valid(target) or bool(target.dead):
			target = world.nearest_enemy(position, 600.0, _hit)
		if target != null:
			var tp: Vector2 = target.position
			var want := (tp - position).angle()
			var ang := vel.angle()
			var diff := wrapf(want - ang, -PI, PI)
			ang += clampf(diff, -homing * delta, homing * delta)
			vel = Vector2.from_angle(ang) * speed
	position += vel * delta
	rotation = vel.angle()
	if style == "orb":
		_spin += delta * 6.0
		scale = Vector2.ONE * (1.0 + 0.08 * sin(_spin))
	for e in world.query(position, radius):
		var id: int = e.get_instance_id()
		if _hit.has(id):
			continue
		_hit[id] = true
		var dmg := damage
		if e.is_boss or e.is_elite:
			dmg *= boss_bonus
		if on_hit.is_valid():
			on_hit.call(e)
		world.damage_enemy(e, dmg, vel.normalized(), knockback, col)
		if execute_below > 0.0 and not e.is_boss and not e.dead and e.hp < e.max_hp * execute_below:
			world.damage_enemy(e, e.hp + 1.0, Vector2.ZERO, 0.0, col)
		if bounces > 0:
			var nxt: Node2D = world.nearest_enemy(position, bounce_range, _hit)
			if nxt == null:
				dead = true
				return
			bounces -= 1
			target = nxt
			vel = (nxt.position - position).normalized() * speed
			life = maxf(life, 0.7)
			return
		if pierce > 0:
			pierce -= 1
		else:
			dead = true
			return

func _draw() -> void:
	var c := col
	match style:
		"beam":
			UIKit.glow(self, Vector2(-length * 0.4, 0), length * 0.9, Color(c.r, c.g, c.b, 0.45))
			draw_line(Vector2(-length, 0), Vector2(0, 0), Color(c.r, c.g, c.b, 0.9), 4.0, true)
			draw_line(Vector2(-length * 0.8, 0), Vector2(0, 0), Color(0.9, 1.0, 1.0, 0.95), 1.6, true)
		"lance":
			UIKit.glow(self, Vector2(-8, 0), 34.0, Color(c.r, c.g, c.b, 0.5))
			draw_colored_polygon(PackedVector2Array([Vector2(14, 0), Vector2(-26, -5), Vector2(-20, 0), Vector2(-26, 5)]), Color(c.r, c.g, c.b, 0.9))
			draw_line(Vector2(-24, 0), Vector2(12, 0), Color(1, 1, 1, 0.9), 1.5, true)
		"orb":
			UIKit.glow(self, Vector2.ZERO, 30.0, Color(c.r, c.g, c.b, 0.55))
			draw_circle(Vector2.ZERO, 8.0, Color(c.r, c.g, c.b, 0.35))
			draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 20, Color(c.r, c.g, c.b, 1.0), 2.0, true)
			for i in 6:
				var p := Vector2.from_angle(TAU * i / 6.0) * 8.0
				draw_line(p, p * 1.45, Color(c.r, c.g, c.b, 0.9), 1.5, true)
			draw_circle(Vector2.ZERO, 3.0, Color(0.9, 1.0, 1.0, 0.9))
		"antibody":
			UIKit.glow(self, Vector2.ZERO, 22.0, Color(c.r, c.g, c.b, 0.5))
			draw_line(Vector2(-9, 0), Vector2(1, 0), c, 2.5, true)
			draw_line(Vector2(1, 0), Vector2(8, -6), c, 2.5, true)
			draw_line(Vector2(1, 0), Vector2(8, 6), c, 2.5, true)
			draw_circle(Vector2(8, -6), 2.0, Color(1, 1, 1, 0.9))
			draw_circle(Vector2(8, 6), 2.0, Color(1, 1, 1, 0.9))
		_:
			UIKit.glow(self, Vector2.ZERO, radius * 3.0, Color(c.r, c.g, c.b, 0.5))
			draw_circle(Vector2.ZERO, radius, c)
