extends "res://scripts/run/weapons/weapon_base.gd"
## Lentiviral Orb: 느린 유도탄. 맞은 적을 감염(지속 피해)시키고, 감염된 적이 죽으면 주변으로 번진다.
## 진화(Lipofectamine) → Pandemic Vector: 전파가 줄어들지 않고 끝없이 번진다.

func fire() -> bool:
	var t: Variant = world.nearest_enemy(player.position, 650.0, {})
	if t == null:
		return false
	var spread := int(stats.get("spread", 2)) + (3 if evolved else 0)
	var dot: float = float(stats.get("dot", 6.0)) * float(player.damage_mult)
	var d := dur()
	var pandemic := evolved
	var spd := float(stats.get("speed", 260.0))
	var base_ang: float = ((t as Node2D).position - player.position).angle()
	var n := cnt()
	for i in n:
		var a := base_ang + (i - (n - 1) / 2.0) * 0.6
		var p: Node2D = world.spawn_projectile({
			"pos": player.position, "vel": Vector2.from_angle(a) * spd, "speed": spd,
			"damage": dmg(), "pierce": int(stats.get("pierce", 2)), "radius": 12.0 * area(),
			"life": 4.0, "style": "orb", "color": color(), "homing": 3.2,
		})
		p.target = t
		p.on_hit = func(e: Node2D) -> void: e.infect(dot, d, spread, pandemic)
	return true
