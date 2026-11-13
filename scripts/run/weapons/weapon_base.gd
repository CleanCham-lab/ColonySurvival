extends Node2D
## 무기 공통 부모. 각 무기는 fire()만 다르게 구현한다.
## 플레이어의 자식으로 붙기 때문에 position(0,0) = 플레이어 위치.

var world: Node
var player: Node2D
var id := ""
var level := 1
var stats: Dictionary = {}
var evolved := false
var timer := 0.3

func setup(w: Node, p: Node2D, wid: String, lvl: int) -> void:
	world = w
	player = p
	id = wid
	level = lvl
	refresh()

func refresh() -> void:
	stats = DB.weapon_stats(id, level)
	on_refresh()

func on_refresh() -> void:
	pass

func set_level(l: int) -> void:
	level = mini(l, DB.WEAPON_MAX_LEVEL)
	refresh()

func evolve() -> void:
	evolved = true
	refresh()

func display_name() -> String:
	var d: Dictionary = DB.WEAPONS[id]
	if evolved:
		return String(d.get("evolved_name", d["name"]))
	return String(d["name"])

# 플레이어 보정이 들어간 최종 수치
func dmg() -> float:
	return float(stats.get("damage", 0.0)) * player.damage_mult

func cd() -> float:
	return float(stats.get("cooldown", 1.0)) * player.cooldown_mult

func area() -> float:
	return float(stats.get("area", 1.0)) * player.area_mult

func dur() -> float:
	return float(stats.get("duration", 1.0)) * player.duration_mult

func cnt() -> int:
	return int(stats.get("count", 1))

func color() -> Color:
	return (DB.WEAPONS[id] as Dictionary)["color"]

func tick(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		if fire():
			timer = cd()
		else:
			timer = 0.15

## 쐈으면 true (쿨다운 시작), 쏠 대상이 없으면 false
func fire() -> bool:
	return false
