extends "res://scripts/run/weapons/weapon_base.gd"
## 70% EtOH Splash: 근처 적 위치에 장판을 깐다.

func fire() -> bool:
	var cands: Array = world.nearest_enemies(player.position, 420.0, 12)
	var r := 58.0 * area()
	for i in cnt():
		var pos: Vector2
		if cands.size() > 0:
			pos = (cands[randi() % cands.size()] as Node2D).position
		else:
			pos = player.position + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 200.0)
		world.spawn_zone(pos, r, dmg(), dur(), color())
		world.fx.ring(pos, color(), 10.0, r, 0.25, 3.0)
	return true
