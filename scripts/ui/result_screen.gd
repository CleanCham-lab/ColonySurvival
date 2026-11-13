extends Control
## 런 결과: 생존 시간, 처치, 빌드, 연구비 정산.

signal retry
signal to_select
signal to_title

var result: Dictionary = {}
var _sel := 0
var _rects: Array = []
const ITEMS := ["다시하기", "셀라인 선택", "타이틀로"]

func setup(r: Dictionary) -> void:
	result = r

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		_sel = (_sel - 1 + ITEMS.size()) % ITEMS.size()
		Audio.play("ui_move")
	elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % ITEMS.size()
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
	match i:
		0:
			retry.emit()
		1:
			to_select.emit()
		2:
			to_title.emit()

func _draw() -> void:
	var W := size.x
	var H := size.y
	draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.02, 0.8))
	var win := bool(result.get("victory", false))
	var tsec := float(result.get("time", 0.0))
	var pw := minf(760.0, W - 60.0)
	var px := (W - pw) / 2.0
	var py := H * 0.12
	var accent := DB.C_GFP if win else DB.C_ENEMY
	UIKit.text(self, Vector2(0, py + 30), "콜로니 생존!" if win else "컨탐되었습니다…", 48, accent, true, HORIZONTAL_ALIGNMENT_CENTER, W)
	var mode := String(result.get("mode", "normal"))
	var sub := "12월 25일 09:00 — Reviewer #2의 심사를 통과했다. Accepted!" if win else "%s 에 배양이 끝났다." % DB.game_clock_text(tsec)
	if mode == "endless" and not win:
		sub = "야근 %d분 %02d초 만에 쓰러졌다. (%s)" % [int(tsec) / 60, int(tsec) % 60, DB.game_clock_text(tsec)]
	if bool(result.get("new_record", false)):
		sub += "   ★ 새 기록!"
	UIKit.text(self, Vector2(0, py + 70), sub, 18, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, W)
	var box := Rect2(px, py + 100, pw, 330)
	UIKit.panel_box(self, box, Color(0.03, 0.05, 0.09, 0.95), Color(accent.r, accent.g, accent.b, 0.5))
	var cname := String((DB.CHARACTERS[result.get("char_id", "hek293t")] as Dictionary)["name"])
	var lx := box.position.x + 32.0
	var y := box.position.y + 44.0
	var tline := "%d:%02d / 15:00" % [int(tsec) / 60, int(tsec) % 60]
	if mode == "endless":
		tline = "%d:%02d" % [int(tsec) / 60, int(tsec) % 60]
	var setup_line := "%s · %s · %s" % [DB.MODES.get(mode, DB.MODES["normal"])["name"], DB.ZONES.get(String(result.get("zone", "dish")), DB.ZONES["dish"])["name"],
		DB.DIFFICULTY.get(String(result.get("difficulty", "normal")), DB.DIFFICULTY["normal"])["name"]]
	var stats := [
		["셀라인", cname],
		["실험", setup_line],
		["생존 시간", tline],
		["레벨", str(result.get("level", 1))],
		["처치", str(result.get("kills", 0))],
		["보스 처치", str(result.get("boss_kills", 0))],
	]
	for s in stats:
		UIKit.text(self, Vector2(lx, y), String(s[0]), 16, DB.C_TEXT_DIM)
		UIKit.text(self, Vector2(lx + 120, y), String(s[1]), 18, DB.C_TEXT, true)
		y += 32.0
	var gx := box.position.x + pw * 0.5
	y = box.position.y + 44.0
	UIKit.text(self, Vector2(gx, y), "빌드", 16, DB.C_TEXT_DIM)
	y += 28.0
	for wline in result.get("weapons", []):
		UIKit.text(self, Vector2(gx, y), String(wline), 16, DB.C_ALLY)
		y += 24.0
	for pline in result.get("passives", []):
		UIKit.text(self, Vector2(gx, y), String(pline), 15, DB.C_GFP)
		y += 22.0
	var gy := box.end.y + 44.0
	UIKit.text(self, Vector2(0, gy), "연구비 +%d   (보유 %d)" % [int(result.get("grant", 0)), int(Save.data["grant"])], 22, DB.C_WARN, true, HORIZONTAL_ALIGNMENT_CENTER, W)
	var newly: Array = result.get("newly_unlocked", [])
	if not newly.is_empty():
		var names: Array = []
		for cid in newly:
			names.append(String((DB.CHARACTERS[cid] as Dictionary)["name"]))
		UIKit.text(self, Vector2(0, gy + 32), "새 셀라인 해금: " + ", ".join(PackedStringArray(names)), 18, DB.C_GFP, true, HORIZONTAL_ALIGNMENT_CENTER, W)
	_rects.clear()
	var bw := 200.0
	var bx := (W - (bw * 3.0 + 40.0)) / 2.0
	var by := gy + 70.0
	for i in ITEMS.size():
		var r := Rect2(bx + i * (bw + 20.0), by, bw, 48)
		_rects.append(r)
		var sel := i == _sel
		draw_rect(r, Color(0.12, 0.25, 0.45, 0.6) if sel else Color(0.05, 0.07, 0.12, 0.85))
		draw_rect(r, Color(DB.C_ALLY.r, DB.C_ALLY.g, DB.C_ALLY.b, 0.95 if sel else 0.3), false, 2.0 if sel else 1.0)
		UIKit.text(self, Vector2(r.position.x, r.position.y + 31), String(ITEMS[i]), 19, DB.C_TEXT, sel, HORIZONTAL_ALIGNMENT_CENTER, bw)
