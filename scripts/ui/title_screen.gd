extends Control
## 타이틀. 배경에 형광 세포들이 떠다닌다.

signal start_pressed
signal shop_pressed
signal options_pressed
signal quit_pressed

var _sel := 0
var _items: Array = []
var _rects: Array = []
var _t := 0.0
var _cells: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_items = ["시작하기", "연구실", "설정"]
	if not OS.has_feature("web"):
		_items.append("종료")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2412
	for i in 46:
		var kind := rng.randi() % 10
		var c := DB.C_PLAYER
		if kind < 4:
			c = DB.C_ENEMY
		elif kind < 6:
			c = DB.C_GFP
		elif kind < 7:
			c = DB.C_ENEMY_MAG
		_cells.append({"p": Vector2(rng.randf(), rng.randf()), "v": Vector2(rng.randf_range(-0.01, 0.01), rng.randf_range(-0.008, 0.008)), "r": rng.randf_range(6.0, 34.0), "c": c, "ph": rng.randf() * TAU})

func _process(delta: float) -> void:
	_t += delta
	for c in _cells:
		var p: Vector2 = c["p"]
		p += (c["v"] as Vector2) * delta
		c["p"] = Vector2(fposmod(p.x, 1.0), fposmod(p.y, 1.0))
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_sel = (_sel - 1 + _items.size()) % _items.size()
		Audio.play("ui_move")
	elif event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % _items.size()
		Audio.play("ui_move")
	elif event.is_action_pressed("confirm"):
		_activate(_sel)
	else:
		return
	get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(event.position):
				_sel = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(event.position):
				_activate(i)

func _activate(i: int) -> void:
	Audio.play("ui_select")
	match String(_items[i]):
		"시작하기":
			start_pressed.emit()
		"연구실":
			shop_pressed.emit()
		"설정":
			options_pressed.emit()
		"종료":
			quit_pressed.emit()

func _draw() -> void:
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), DB.C_BG)
	for c in _cells:
		var p: Vector2 = (c["p"] as Vector2) * Vector2(W, H)
		var r: float = float(c["r"]) * (1.0 + 0.08 * sin(_t * 1.5 + float(c["ph"])))
		var col: Color = c["c"]
		draw_texture_rect(UIKit.glow_tex, Rect2(p - Vector2(r, r) * 2.5, Vector2(r, r) * 5.0), false, Color(col.r, col.g, col.b, 0.22))
		draw_arc(p, r, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.45), 1.5, true)
	draw_texture_rect(UIKit.vignette_tex, Rect2(0, 0, W, H), false)
	var cy := H * 0.30
	draw_texture_rect(UIKit.glow_tex, Rect2(W / 2.0 - 420, cy - 150, 840, 260), false, Color(0.3, 0.6, 1.0, 0.18))
	UIKit.text(self, Vector2(0, cy), "Colony Survival", 78, Color(0.75, 0.92, 1.0), true, HORIZONTAL_ALIGNMENT_CENTER, W)
	UIKit.text(self, Vector2(0, cy + 46), "Lab Xmas Edition", 26, DB.C_ENEMY, true, HORIZONTAL_ALIGNMENT_CENTER, W)
	UIKit.text(self, Vector2(0, cy + 84), "12월 24일 밤, 모두 퇴근한 배양실. 아침 9시까지 콜로니를 지켜라.", 18, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, W)
	_rects.clear()
	var y := H * 0.52
	for i in _items.size():
		var r := Rect2(W / 2.0 - 160, y, 320, 50)
		_rects.append(r)
		var sel := i == _sel
		if sel:
			draw_texture_rect(UIKit.glow_tex, r.grow(26.0), false, Color(0.3, 0.8, 1.0, 0.18))
		draw_rect(r, Color(0.12, 0.25, 0.45, 0.6) if sel else Color(0.05, 0.07, 0.12, 0.7))
		draw_rect(r, Color(DB.C_ALLY.r, DB.C_ALLY.g, DB.C_ALLY.b, 0.95 if sel else 0.3), false, 2.0 if sel else 1.0)
		UIKit.text(self, Vector2(r.position.x, r.position.y + 33), String(_items[i]), 21, DB.C_TEXT, sel, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += 62.0
	var best := float(Save.data["best_time"])
	if best > 0.0 or int(Save.data["grant"]) > 0:
		var line := "최고 기록  %d:%02d 생존   ·   보유 연구비 %d" % [int(best) / 60, int(best) % 60, int(Save.data["grant"])]
		if float(Save.data["best_endless"]) > 0.0:
			var be := float(Save.data["best_endless"])
			line += "   ·   야근 최장 %d:%02d" % [int(be) / 60, int(be) % 60]
		UIKit.text(self, Vector2(0, H - 74), line, 16, DB.C_GFP, false, HORIZONTAL_ALIGNMENT_CENTER, W)
	UIKit.text(self, Vector2(0, H - 46), "WASD / 방향키 이동   ·   공격은 자동   ·   Esc 일시정지   ·   전체화면 %s" % ("⌘ + Ctrl + F" if OS.get_name() == "macOS" else "F11"), 15, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, W)
	UIKit.text(self, Vector2(0, H - 20), "v%s   ·   Game by Seung-Won Chae (SNUH Laboratory Medicine)" % String(ProjectSettings.get_setting("application/config/version", "")), 13, Color(0.45, 0.5, 0.62), false, HORIZONTAL_ALIGNMENT_CENTER, W)
