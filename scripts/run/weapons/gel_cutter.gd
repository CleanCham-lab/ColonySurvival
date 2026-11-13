extends "res://scripts/run/weapons/weapon_base.gd"
## Gel Cutter: 가까운 적 쪽으로 넓게 베기(없으면 바라보는 방향). Lv2부터 앞뒤 양방향.

func fire() -> bool:
	var reach := 80.0 * area()
	var dir: Vector2 = player.facing
	var near: Variant = world.nearest_enemy(player.position, reach * 1.6, {})
	if near != null:
		dir = ((near as Node2D).position - player.position).normalized()
	var dirs: Array = [dir]
	if cnt() >= 2:
		dirs.append(-dir)
	for d in dirs:
		var center: Vector2 = player.position + d * reach * 0.75
		for e in world.query(center, reach * 0.75):
			world.damage_enemy(e, dmg(), d, 120.0, color())
		world.fx.slash(center, d, reach, color())
	return true
