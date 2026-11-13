extends CanvasLayer
## 게임 중 HUD: ATP(경험치) 바, 게임 시계, HP, 무기/시약 아이콘, 처치 수, 보스 HP, 알림.

const Icons = preload("res://scripts/ui/icons.gd")

var world: Node
var _c: Control
var _toasts: Array = []
var _gift: Array = []
var _gift_t := 0.0

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_c = Control.new()
	_c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_c)
	_c.draw.connect(_draw_hud)

func _process(delta: float) -> void:
	for tt in _toasts:
		tt["t"] = float(tt["t"]) + delta
	_toasts = _toasts.filter(func(tt: Dictionary) -> bool: return float(tt["t"]) < 3.2)
	_gift_t = maxf(0.0, _gift_t - delta)
	_c.queue_redraw()

func toast(msg: String, c: Color) -> void:
	_toasts.append({"msg": msg, "c": c, "t": 0.0})
	if _toasts.size() > 3:
		_toasts.pop_front()

func show_gift(lines: Array) -> void:
	_gift = lines
	_gift_t = 4.0

static func icon(ci: CanvasItem, r: Rect2, id: String, col: Color, lvl: int, max_lvl: int, evolved := false) -> void:
	ci.draw_rect(r, Color(0.03, 0.04, 0.08, 0.9))
	ci.draw_rect(r, Color(col.r, col.g, col.b, 0.85 if not evolved else 1.0), false, 2.0 if not evolved else 3.0)
	if evolved:
		ci.draw_rect(r.grow(3.0), Color(DB.C_WARN.r, DB.C_WARN.g, DB.C_WARN.b, 0.7), false, 1.5)
	var pad := 8.0 if max_lvl > 0 else 0.0
	Icons.draw(ci, id, r.get_center() - Vector2(0, pad * 0.35), (r.size.y - pad) * 0.78, col)
	if max_lvl > 0:
		var pw := (r.size.x - 6.0) / max_lvl
		for i in max_lvl:
			var pc := col if i < lvl else Color(0.25, 0.28, 0.35)
			ci.draw_rect(Rect2(r.position.x + 3.0 + i * pw, r.end.y - 6.0, pw - 1.5, 3.0), pc)

func _draw_hud() -> void:
	if world == null or world.player == null:
		return
	var W := _c.size.x
	var H := _c.size.y
	# ── ATP 바 (맨 위)
	_c.draw_rect(Rect2(0, 0, W, 12), Color(0.02, 0.05, 0.03, 0.9))
	var f := clampf(float(world.xp) / float(world.xp_next), 0.0, 1.0)
	_c.draw_rect(Rect2(0, 0, W * f, 12), DB.C_GFP)
	_c.draw_rect(Rect2(0, 12, W, 1), Color(DB.C_GFP.r, DB.C_GFP.g, DB.C_GFP.b, 0.35))
	UIKit.text(_c, Vector2(W - 120, 34), "Lv %d" % world.level, 20, DB.C_GFP, true, HORIZONTAL_ALIGNMENT_RIGHT, 100)
	# ── 시계
	UIKit.text(_c, Vector2(0, 50), DB.game_clock_text(world.t), 30, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_CENTER, W)
	var left := maxf(0.0, DB.RUN_LENGTH - world.t)
	var sub := "패시지 %d  ·  아침까지 %d:%02d" % [DB.passage_of(world.t), int(left) / 60, int(left) % 60]
	var sub_c := DB.C_TEXT_DIM
	if world.mode == "endless":
		var bt := float(Save.data["best_endless"])
		sub = "야근 모드  ·  %d:%02d 버팀" % [int(world.t) / 60, int(world.t) % 60]
		if bt > 0.0:
			sub += "  ·  최고 %d:%02d" % [int(bt) / 60, int(bt) % 60]
		if world.t > bt and bt > 0.0:
			sub_c = DB.C_WARN
	elif world.t >= DB.RUN_LENGTH:
		sub = "최종 심사 중 — Reviewer #2를 쓰러뜨려라"
		sub_c = DB.C_WARN
	UIKit.text(_c, Vector2(0, 72), sub, 15, sub_c, false, HORIZONTAL_ALIGNMENT_CENTER, W)
	# ── HP
	var p: Node2D = world.player
	var hpf := clampf(p.hp / p.max_hp, 0.0, 1.0)
	_c.draw_rect(Rect2(20, 26, 220, 14), Color(0.05, 0.06, 0.1, 0.9))
	_c.draw_rect(Rect2(20, 26, 220 * hpf, 14), DB.C_ALLY if hpf > 0.35 else DB.C_ENEMY)
	_c.draw_rect(Rect2(20, 26, 220, 14), Color(1, 1, 1, 0.25), false, 1.0)
	UIKit.text(_c, Vector2(20, 60), "%s  HP %d / %d" % [String(world.cdata["name"]), int(ceil(p.hp)), int(p.max_hp)], 15, DB.C_TEXT, true)
	# ── 무기 / 시약 아이콘
	var x := 20.0
	for w in world.weapons:
		var d: Dictionary = DB.WEAPONS[w.id]
		icon(_c, Rect2(x, 74, 44, 44), String(w.id), d["color"], w.level, DB.WEAPON_MAX_LEVEL, w.evolved)
		x += 50.0
	x = 20.0
	for k in world.passives.keys():
		var pd: Dictionary = DB.PASSIVES[k]
		icon(_c, Rect2(x, 126, 36, 36), String(k), DB.C_GFP, int(world.passives[k]), DB.PASSIVE_MAX_LEVEL)
		x += 42.0
	# ── 처치 수
	UIKit.text(_c, Vector2(W - 220, 60), "처치 %d" % world.kills, 18, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	var tags: Array = []
	if world.zone != "dish":
		tags.append(String(DB.ZONES[world.zone]["name"]))
	if world.difficulty != "normal":
		tags.append(String(DB.DIFFICULTY[world.difficulty]["name"]))
	if not tags.is_empty():
		UIKit.text(_c, Vector2(W - 320, 82), " · ".join(PackedStringArray(tags)), 14, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_RIGHT, 300)
	if world.mode == "daily" and not world.daily.is_empty():
		UIKit.text(_c, Vector2(W - 420, 104), "▲ " + String(world.daily["buff"]["name"]), 14, DB.C_GFP, false, HORIZONTAL_ALIGNMENT_RIGHT, 400)
		UIKit.text(_c, Vector2(W - 420, 124), "▼ " + String(world.daily["debuff"]["name"]), 14, DB.C_ENEMY, false, HORIZONTAL_ALIGNMENT_RIGHT, 400)
	# ── 보스 HP
	var b: Variant = world.boss_ref
	if b != null and is_instance_valid(b) and not b.dead:
		var bw := minf(620.0, W - 80.0)
		var bx := (W - bw) / 2.0
		var by := 96.0
		var bf := clampf(float(b.hp) / float(b.max_hp), 0.0, 1.0)
		_c.draw_rect(Rect2(bx, by, bw, 12), Color(0.08, 0.02, 0.03, 0.9))
		_c.draw_rect(Rect2(bx, by, bw * bf, 12), DB.C_ENEMY)
		_c.draw_rect(Rect2(bx + bw * 0.5 - 1, by - 2, 2, 16), Color(1, 1, 1, 0.4))
		var bd: Dictionary = DB.BOSSES[b.kind]
		UIKit.text(_c, Vector2(0, by + 32), "%s  ·  %s" % [bd["name"], bd["title"]], 16, DB.C_ENEMY, true, HORIZONTAL_ALIGNMENT_CENTER, W)
	# ── 알림
	var ty := H * 0.30
	for tt in _toasts:
		var a: float = clampf(3.2 - float(tt["t"]), 0.0, 1.0) * clampf(float(tt["t"]) * 5.0, 0.0, 1.0)
		var c: Color = tt["c"]
		UIKit.text(_c, Vector2(0, ty), String(tt["msg"]), 22, Color(c.r, c.g, c.b, a), true, HORIZONTAL_ALIGNMENT_CENTER, W)
		ty += 32.0
	# ── 선물상자 결과
	if _gift_t > 0.0 and not _gift.is_empty():
		var a := clampf(_gift_t, 0.0, 1.0)
		var gh := 46.0 + 26.0 * _gift.size()
		var r := Rect2(W / 2.0 - 240, H * 0.58, 480, gh)
		UIKit.panel_box(_c, r, Color(0.02, 0.06, 0.04, 0.88 * a), Color(DB.C_GFP.r, DB.C_GFP.g, DB.C_GFP.b, a))
		UIKit.text(_c, Vector2(r.position.x, r.position.y + 30), "선물상자 개봉!", 20, Color(DB.C_GFP.r, DB.C_GFP.g, DB.C_GFP.b, a), true, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var yy := r.position.y + 58
		for line in _gift:
			UIKit.text(_c, Vector2(r.position.x, yy), String(line), 17, Color(1, 1, 1, a), false, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			yy += 26.0
