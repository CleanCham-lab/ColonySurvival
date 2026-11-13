extends Node2D
## 플레이어 세포. 이동만 직접 하고, 공격은 무기들이 알아서 한다.

const CellArt = preload("res://scripts/run/cell_art.gd")

var world: Node
var cdata: Dictionary
var radius := DB.PLAYER_RADIUS
var base_hp := 100.0
var max_hp := 100.0
var hp := 100.0
var base_speed := 230.0
var speed := 230.0
var armor := 0.0
var damage_mult := 1.0
var cooldown_mult := 1.0
var area_mult := 1.0
var duration_mult := 1.0
var magnet := DB.BASE_MAGNET
var invuln := 0.0
var facing := Vector2.RIGHT
var move_dir := Vector2.ZERO
var ai_dir: Variant = null       # 개발용 자동 플레이가 덮어쓰는 이동 방향
var revives := 0
var phago_counter := 0
var _bob := 0.0
var _hurt_flash := 0.0
var _body: Node2D

func setup(w: Node, cd: Dictionary) -> void:
	world = w
	cdata = cd
	base_hp = float(cd["max_hp"])
	max_hp = base_hp
	hp = max_hp
	base_speed = float(cd["speed"])
	speed = base_speed
	revives = 1 if String(cd["perk"]) == "immortal" else 0

func _ready() -> void:
	_body = Node2D.new()
	add_child(_body)
	_body.draw.connect(_draw_body)
	_body.queue_redraw()

func _draw_body() -> void:
	CellArt.draw_cell(_body, String(cdata["shape"]), radius, cdata["color"], cdata["core"], String(cdata["hat"]))

func _draw() -> void:
	# 발밑 HP 바
	var w := 38.0
	var y := radius + 10.0
	draw_rect(Rect2(-w / 2.0 - 1.0, y - 1.0, w + 2.0, 6.0), Color(0, 0, 0, 0.7))
	var f := clampf(hp / max_hp, 0.0, 1.0)
	var c := DB.C_ALLY if f > 0.35 else DB.C_ENEMY
	draw_rect(Rect2(-w / 2.0, y, w * f, 4.0), c)

## 시약(패시브) 레벨 + 런 배율(연구실 강화·오늘의 조건)로 스탯 다시 계산
func recalc(passives: Dictionary, m: Dictionary = {}) -> void:
	var old_max := max_hp
	max_hp = (base_hp + 20.0 * int(passives.get("fbs", 0)) + float(m.get("hp_add", 0.0))) * float(m.get("hp_mult", 1.0))
	if max_hp > old_max:
		hp += max_hp - old_max
	hp = minf(hp, max_hp)
	damage_mult = (1.0 + 0.10 * int(passives.get("penstrep", 0))) * float(m.get("damage", 1.0))
	cooldown_mult = maxf(0.35, (1.0 - 0.08 * int(passives.get("trypsin", 0))) * float(m.get("cooldown", 1.0)))
	area_mult = (1.0 + 0.10 * int(passives.get("agarose", 0))) * float(m.get("area", 1.0))
	duration_mult = (1.0 + 0.10 * int(passives.get("dmso", 0))) * float(m.get("duration", 1.0))
	armor = 1.0 * int(passives.get("matrigel", 0))
	speed = base_speed * (1.0 + 0.08 * int(passives.get("egf", 0))) * float(m.get("speed", 1.0))
	magnet = DB.BASE_MAGNET * (1.0 + 0.25 * int(passives.get("lipofectamine", 0))) * float(m.get("magnet", 1.0))
	queue_redraw()

func tick(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if ai_dir != null:
		input = ai_dir
	move_dir = input
	if input.length() > 0.1:
		facing = input.normalized()
	position += input * speed * delta
	position = world.resolve_obstacles(position, radius)
	invuln = maxf(0.0, invuln - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	# 걷는 느낌의 말랑한 움직임
	_bob += delta * (10.0 if input.length() > 0.1 else 3.0)
	var sq := 0.06 if input.length() > 0.1 else 0.03
	_body.scale = Vector2(1.0 + sin(_bob) * sq, 1.0 - sin(_bob) * sq)
	if _hurt_flash > 0.0:
		_body.modulate = Color(1.0, 0.45, 0.5)
	elif invuln > 0.0:
		_body.modulate = Color(1, 1, 1, 0.55 + 0.45 * float(int(invuln * 20.0) % 2))
	else:
		_body.modulate = Color(1, 1, 1, 1)

func hurt(amount: float) -> void:
	if invuln > 0.0 or bool(world.dev.get("god", false)):
		return
	var dmg := maxf(1.0, amount - armor)
	hp -= dmg
	invuln = DB.INVULN_TIME
	_hurt_flash = 0.12
	queue_redraw()
	world.on_player_hurt(dmg)

func heal(v: float) -> void:
	hp = minf(max_hp, hp + v)
	queue_redraw()
