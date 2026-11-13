extends "res://scripts/run/weapons/weapon_base.gd"
## CRISPR Lance: HP가 가장 높은 적을 노리는 고위력 창.
## 진화(Pen-Strep) → Prime Editor: HP 15% 이하 일반 적 즉사, 보스·엘리트 피해 +50%.

func fire() -> bool:
	var targets: Array = world.strongest_enemies(player.position, 720.0, cnt())
	if targets.is_empty():
		return false
	var spd := float(stats.get("speed", 1150.0))
	for t in targets:
		var dir: Vector2 = ((t as Node2D).position - player.position).normalized()
		var p: Node2D = world.spawn_projectile({
			"pos": player.position + dir * 16.0, "vel": dir * spd, "speed": spd,
			"damage": dmg(), "pierce": int(stats.get("pierce", 0)), "radius": 10.0 * area(),
			"life": 1.0, "style": "lance", "color": color(), "knockback": 60.0,
		})
		if evolved:
			p.execute_below = 0.15
			p.boss_bonus = 1.5
	return true
