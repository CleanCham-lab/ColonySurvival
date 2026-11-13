extends "res://scripts/run/weapons/weapon_base.gd"
## Centrifuge Wave: 원형 충격파로 밀어낸다.
## 진화(Matrigel) → Ultracentrifuge: 끌어당긴 뒤 두 배 피해의 충격파.

var waves: Array = []

func _ready() -> void:
	material = UIKit.add_mat

func fire() -> bool:
	var max_r := 210.0 * area()
	var d := dmg() * (2.0 if evolved else 1.0)
	var delay := 0.0
	if evolved:
		for e in world.query(player.position, max_r * 1.3):
			if not e.is_boss:
				e.knock_vel += (player.position - (e as Node2D).position).normalized() * 420.0 * float(e.knock_resist)
		world.fx.ring(player.position, color(), max_r * 1.3, 20.0, 0.35, 4.0)
		delay = 0.35
		world.schedule(delay, _start_wave.bind(max_r, d))
	else:
		_start_wave(max_r, d)
	if cnt() >= 2:
		world.schedule(delay + 0.3, _start_wave.bind(max_r, d))
	return true

func _start_wave(max_r: float, d: float) -> void:
	waves.append({"r": 12.0, "max": max_r, "hit": {}, "d": d})

func tick(delta: float) -> void:
	super.tick(delta)
	if waves.is_empty():
		return
	var kb := float(stats.get("knockback", 260.0))
	for w in waves:
		w["r"] = float(w["r"]) + 640.0 * delta
		var hit: Dictionary = w["hit"]
		for e in world.query(player.position, float(w["r"])):
			var id: int = e.get_instance_id()
			if hit.has(id):
				continue
			hit[id] = true
			world.damage_enemy(e, float(w["d"]), ((e as Node2D).position - player.position).normalized(), kb, color())
	waves = waves.filter(func(w: Dictionary) -> bool: return float(w["r"]) < float(w["max"]))
	queue_redraw()

func _draw() -> void:
	var c := color()
	for w in waves:
		var f: float = float(w["r"]) / float(w["max"])
		draw_arc(Vector2.ZERO, float(w["r"]), 0.0, TAU, 72, Color(c.r, c.g, c.b, 0.9 * (1.0 - f)), 5.0 * (1.0 - f) + 1.0, true)
		draw_arc(Vector2.ZERO, float(w["r"]) * 0.94, 0.0, TAU, 72, Color(c.r, c.g, c.b, 0.3 * (1.0 - f)), 8.0, true)
