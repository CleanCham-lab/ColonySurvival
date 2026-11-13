extends "res://scripts/run/weapons/weapon_base.gd"
## Antibody Chain: 적 사이를 튕기며 연쇄로 붙는 항체.

func fire() -> bool:
	var targets: Array = world.nearest_enemies(player.position, 600.0, cnt())
	if targets.is_empty():
		return false
	var spd := float(stats.get("speed", 820.0))
	for i in cnt():
		var t: Node2D = targets[i % targets.size()]
		var dir: Vector2 = (t.position - player.position).normalized()
		var p: Node2D = world.spawn_projectile({
			"pos": player.position + dir * 14.0, "vel": dir * spd, "speed": spd,
			"damage": dmg(), "pierce": 0, "radius": 9.0 * area(), "life": 1.2,
			"style": "antibody", "color": color(), "bounces": int(stats.get("bounces", 3)),
		})
		p.target = t
	return true
