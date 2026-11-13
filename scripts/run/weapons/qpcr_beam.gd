extends "res://scripts/run/weapons/weapon_base.gd"
## qPCR Beam: 가장 가까운 적 방향으로 관통 빔. 진화(DMSO) → Real-time Thermocycler: 회전 빔.

var _spin := 0.0

func on_refresh() -> void:
	if evolved:
		stats["cooldown"] = 0.16
		stats["pierce"] = 99

func fire() -> bool:
	if evolved:
		var n := 6
		for i in n:
			_beam(Vector2.from_angle(_spin + TAU * i / n), dmg() * 0.55, 99)
		_spin += 0.33
		return true
	var targets: Array = world.nearest_enemies(player.position, 620.0, cnt())
	if targets.is_empty():
		return false
	for i in cnt():
		var t: Node2D = targets[i % targets.size()]
		var dir: Vector2 = (t.position - player.position).normalized()
		if i >= targets.size():
			dir = dir.rotated(randf_range(-0.3, 0.3))
		_beam(dir, dmg(), int(stats.get("pierce", 0)))
	return true

func _beam(dir: Vector2, d: float, pierce: int) -> void:
	var spd := float(stats.get("speed", 950.0))
	world.spawn_projectile({
		"pos": player.position + dir * 18.0, "vel": dir * spd, "speed": spd,
		"damage": d, "pierce": pierce, "radius": 7.0 * area(),
		"life": float(stats.get("duration", 0.9)), "style": "beam", "color": color(), "length": 34.0,
	})
