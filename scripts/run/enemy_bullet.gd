extends Node2D
## 적 탄환(포자 등). 빨강/주황 = 피할 것.

var vel := Vector2.ZERO
var radius := 7.0
var damage := 10.0
var life := 6.0
var col := Color(1.0, 0.55, 0.22)
var dead := false

func _ready() -> void:
	material = UIKit.add_mat
	queue_redraw()

func tick(delta: float, player: Node2D) -> void:
	life -= delta
	if life <= 0.0:
		dead = true
		return
	position += vel * delta
	rotation += delta * 4.0
	if position.distance_squared_to(player.position) < pow(radius + player.radius * 0.8, 2.0):
		player.hurt(damage)
		dead = true

func _draw() -> void:
	var c := col
	UIKit.glow(self, Vector2.ZERO, radius * 3.2, Color(c.r, c.g, c.b, 0.6))
	draw_circle(Vector2.ZERO, radius, Color(c.r, c.g, c.b, 0.55))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 14, Color(c.r, c.g, c.b, 1.0), 1.6, true)
	draw_circle(Vector2(radius * 0.25, -radius * 0.25), radius * 0.35, Color(1.0, 0.9, 0.7, 0.9))
