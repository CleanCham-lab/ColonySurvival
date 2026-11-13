extends "res://scripts/run/weapons/weapon_base.gd"
## Lysozyme Field: 주변 적을 계속 녹이는 효소 장.

var pulse := 0.0

func _ready() -> void:
	material = UIKit.add_mat
	z_index = -1

func field_radius() -> float:
	return 72.0 * area()

func fire() -> bool:
	var r := field_radius()
	for e in world.query(player.position, r):
		world.damage_enemy(e, dmg(), ((e as Node2D).position - player.position).normalized(), float(stats.get("knockback", 30.0)), color())
	pulse = 1.0
	return true

func tick(delta: float) -> void:
	super.tick(delta)
	pulse = maxf(0.0, pulse - delta * 4.0)
	queue_redraw()

func _draw() -> void:
	var r := field_radius()
	var c := color()
	UIKit.glow(self, Vector2.ZERO, r * 1.25, Color(c.r, c.g, c.b, 0.10 + 0.10 * pulse))
	draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.05 + 0.05 * pulse))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(c.r, c.g, c.b, 0.30 + 0.45 * pulse), 2.0, true)
