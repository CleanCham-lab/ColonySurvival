extends "res://scripts/run/weapons/weapon_base.gd"
## UV Flash: 화면 안 무작위 적에게 자외선 섬광.

func fire() -> bool:
	var cands: Array = world.enemies_in_view()
	if cands.is_empty():
		return false
	cands.shuffle()
	var r := 46.0 * area()
	for i in mini(cnt(), cands.size()):
		var pos: Vector2 = (cands[i] as Node2D).position
		for e in world.query(pos, r):
			world.damage_enemy(e, dmg(), Vector2.ZERO, 0.0, color())
		world.fx.uv(pos, r, color())
	return true
