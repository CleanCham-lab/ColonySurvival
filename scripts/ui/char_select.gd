extends Control
## 캐릭터(셀라인) 선택.

signal chosen(char_id: String)
signal back

const CellArt = preload("res://scripts/run/cell_art.gd")

var _sel := 0
var _rects: Array = []
var _t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var n := DB.CHARACTER_ORDER.size()
	if event.is_action_pressed("move_left"):
		_sel = (_sel - 1 + n) % n
		Audio.play("ui_move")
	elif event.is_action_pressed("move_right"):
		_sel = (_sel + 1) % n
		Audio.play("ui_move")
	elif event.is_action_pressed("confirm"):
		_pick(_sel)
	elif event.is_action_pressed("back") or event.is_action_pressed("pause"):
		Audio.play("ui_move")
		back.emit()
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
				_pick(i)

func _pick(i: int) -> void:
	var cid: String = DB.CHARACTER_ORDER[i]
	if not Save.is_unlocked(cid):
		Audio.play("hurt", 0.4)
		return
	Audio.play("ui_select")
	chosen.emit(cid)

func _draw() -> void:
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), DB.C_BG)
	draw_texture_rect(UIKit.vignette_tex, Rect2(0, 0, W, H), false)
	UIKit.text(self, Vector2(0, 74), "셀라인 선택", 34, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_CENTER, W)
	UIKit.text(self, Vector2(0, 104), "누가 크리스마스 이브의 배양실을 지킬까?", 17, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, W)
	_rects.clear()
	var n := DB.CHARACTER_ORDER.size()
	var cw := minf(330.0, (W - 80.0) / n - 20.0)
	var ch := 430.0
	var total := n * cw + (n - 1) * 24.0
	var x := (W - total) / 2.0
	var y := (H - ch) / 2.0 + 30.0
	for i in n:
		var cid: String = DB.CHARACTER_ORDER[i]
		var c: Dictionary = DB.CHARACTERS[cid]
		var r := Rect2(x, y, cw, ch)
		_rects.append(r)
		var sel := i == _sel
		var unlocked := Save.is_unlocked(cid)
		var col: Color = c["color"]
		if sel:
			draw_texture_rect(UIKit.glow_tex, r.grow(40.0), false, Color(col.r, col.g, col.b, 0.12))
		UIKit.panel_box(self, r, Color(0.04, 0.05, 0.10, 0.95), Color(col.r, col.g, col.b, 0.95 if sel else 0.3), 3.0 if sel else 1.5)
		# 셀 그림
		var center := Vector2(r.position.x + cw / 2.0, r.position.y + 120.0)
		var bob := sin(_t * 3.0 + i) * 4.0 if sel else 0.0
		draw_set_transform(center + Vector2(0, bob), 0.0, Vector2(3.0, 3.0))
		CellArt.draw_cell(self, String(c["shape"]), 15.0, col if unlocked else Color(0.3, 0.3, 0.35), c["core"] if unlocked else Color(0.25, 0.25, 0.3), String(c["hat"]) if unlocked else "")
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var ty := r.position.y + 236.0
		UIKit.text(self, Vector2(r.position.x, ty), String(c["name"]), 28, DB.C_TEXT if unlocked else DB.C_TEXT_DIM, true, HORIZONTAL_ALIGNMENT_CENTER, cw)
		UIKit.text(self, Vector2(r.position.x, ty + 28), String(c["tagline"]), 15, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, cw)
		if unlocked:
			var wd: Dictionary = DB.WEAPONS[c["start_weapon"]]
			var lx := r.position.x + 24.0
			UIKit.text(self, Vector2(lx, ty + 68), "HP %d   ·   이동속도 %d%%" % [int(c["max_hp"]), int(float(c["speed"]) / 230.0 * 100.0)], 16, DB.C_TEXT)
			UIKit.text(self, Vector2(lx, ty + 98), "시작 무기", 13, DB.C_TEXT_DIM)
			UIKit.text(self, Vector2(lx, ty + 120), String(wd["name"]), 18, wd["color"], true)
			UIKit.text(self, Vector2(lx, ty + 150), "고유 능력 · " + String(c["perk_name"]), 13, DB.C_TEXT_DIM)
			UIKit.text(self, Vector2(lx, ty + 172), String(c["perk_text"]), 16, DB.C_GFP, false, HORIZONTAL_ALIGNMENT_LEFT, cw - 40.0)
		else:
			UIKit.text(self, Vector2(r.position.x, ty + 110), "잠김", 22, DB.C_TEXT_DIM, true, HORIZONTAL_ALIGNMENT_CENTER, cw)
			UIKit.text(self, Vector2(r.position.x, ty + 140), "Reviewer #2를 한 번 쓰러뜨리면 해금", 15, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, cw)
			UIKit.text(self, Vector2(r.position.x, ty + 164), "또는 연구실에서 연구비 300", 15, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, cw)
		x += cw + 24.0
	UIKit.text(self, Vector2(0, H - 30), "← → 선택   ·   Enter 시작   ·   Backspace 뒤로", 15, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, W)
