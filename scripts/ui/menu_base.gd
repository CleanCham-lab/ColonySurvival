extends Control
## 키보드 / 마우스 / 패드 공통 세로 메뉴. 설정·실험 설정·연구실 상점이 이걸 상속한다.
## 서브클래스는 _build_rows() / _on_row(id, dir) / _draw_info(rect, row)만 채우면 된다.
##   row = {"id", "label", "value": String(""=버튼), "adjust": bool(◀▶), "slider": float(-1=없음),
##          "disabled": bool, "color": Color}

signal closed

var title := ""
var subtitle := ""
var rows: Array = []
var sel := 0
var panel_w := 540.0
var row_h := 48.0
var info_w := 0.0        # >0 이면 오른쪽 정보 패널
var overlay := false     # true: 게임 위에 반투명으로 / false: 단독 화면
var hint := "↑↓ 선택   ·   ←→ 조절   ·   Enter 확인   ·   Esc 뒤로"
var _row_rects: Array = []
var _left_rects: Array = []
var _right_rects: Array = []
var _t := 0.0
var _bg_cells: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 26:
		_bg_cells.append({"p": Vector2(rng.randf(), rng.randf()), "r": rng.randf_range(8.0, 30.0), "ph": rng.randf() * TAU,
			"c": [DB.C_ALLY, DB.C_GFP, DB.C_ENEMY][rng.randi() % 3]})
	refresh()

func refresh() -> void:
	rows = _build_rows()
	sel = clampi(sel, 0, maxi(0, rows.size() - 1))
	queue_redraw()

# ── 서브클래스용 ─────────────────────────────────────────────
func _build_rows() -> Array:
	return []

func _on_row(_id: String, _dir: int) -> void:
	pass

func _draw_info(_r: Rect2, _row: Dictionary) -> void:
	pass

func close() -> void:
	closed.emit()

# ── 입력 ────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_t += delta
	if not overlay:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or rows.is_empty():
		return
	if event.is_action_pressed("move_up", true):
		_move(-1)
	elif event.is_action_pressed("move_down", true):
		_move(1)
	elif event.is_action_pressed("move_left", true):
		_press(sel, -1)
	elif event.is_action_pressed("move_right", true):
		_press(sel, 1)
	elif event.is_action_pressed("confirm"):
		_press(sel, 0)
	elif event.is_action_pressed("back") or event.is_action_pressed("pause"):
		Audio.play("ui_move")
		close()
	else:
		return
	get_viewport().set_input_as_handled()

func _move(d: int) -> void:
	for k in rows.size():
		sel = (sel + d + rows.size()) % rows.size()
		if not bool((rows[sel] as Dictionary).get("disabled", false)):
			break
	Audio.play("ui_move")
	queue_redraw()

func _press(i: int, dir: int) -> void:
	if i < 0 or i >= rows.size():
		return
	var row: Dictionary = rows[i]
	if dir != 0 and not bool(row.get("adjust", false)):
		return
	if bool(row.get("disabled", false)):
		return
	Audio.play("ui_select" if dir == 0 else "ui_move")
	_on_row(String(row["id"]), dir)
	if is_inside_tree():
		refresh()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		for i in _row_rects.size():
			if (_row_rects[i] as Rect2).has_point(event.position) and sel != i:
				sel = i
				queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			for i in _row_rects.size():
				if (_left_rects[i] as Rect2).has_area() and (_left_rects[i] as Rect2).has_point(event.position):
					_press(i, -1)
					return
				if (_right_rects[i] as Rect2).has_area() and (_right_rects[i] as Rect2).has_point(event.position):
					_press(i, 1)
					return
				if (_row_rects[i] as Rect2).has_point(event.position):
					_press(i, 0)
					return
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			close()

# ── 그리기 ──────────────────────────────────────────────────
func _layout() -> Dictionary:
	var W := size.x
	var H := size.y
	var total_w := panel_w + (info_w + 24.0 if info_w > 0.0 else 0.0)
	var top := 96.0 if subtitle == "" else 118.0
	var ph := top + rows.size() * row_h + 22.0
	var px := (W - total_w) / 2.0
	var py := maxf(24.0, (H - ph) / 2.0 - 10.0)
	return {"px": px, "py": py, "ph": ph, "top": top}

func _draw() -> void:
	var W := size.x
	var H := size.y
	if overlay:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0.02, 0.8))
	else:
		draw_rect(Rect2(0, 0, W, H), DB.C_BG)
		for c in _bg_cells:
			var p: Vector2 = (c["p"] as Vector2) * Vector2(W, H)
			var r: float = float(c["r"]) * (1.0 + 0.08 * sin(_t * 1.3 + float(c["ph"])))
			var col: Color = c["c"]
			draw_texture_rect(UIKit.glow_tex, Rect2(p - Vector2(r, r) * 2.5, Vector2(r, r) * 5.0), false, Color(col.r, col.g, col.b, 0.14))
			draw_arc(p, r, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.3), 1.5, true)
		draw_texture_rect(UIKit.vignette_tex, Rect2(0, 0, W, H), false)
	var L := _layout()
	var px: float = L["px"]
	var py: float = L["py"]
	var ph: float = L["ph"]
	UIKit.panel_box(self, Rect2(px, py, panel_w, ph))
	UIKit.text(self, Vector2(px, py + 48), title, 28, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_CENTER, panel_w)
	if subtitle != "":
		UIKit.text(self, Vector2(px, py + 78), subtitle, 15, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, panel_w)
	_row_rects.clear()
	_left_rects.clear()
	_right_rects.clear()
	var y: float = py + float(L["top"]) - 10.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		var r := Rect2(px + 26, y, panel_w - 52, row_h - 8)
		_row_rects.append(r)
		var on := i == sel
		var dis := bool(row.get("disabled", false))
		var tc: Color = row.get("color", DB.C_TEXT)
		if dis:
			tc = Color(tc.r, tc.g, tc.b, 0.4)
		draw_rect(r, Color(0.2, 0.4, 0.7, 0.45) if on else Color(0.08, 0.1, 0.16, 0.8))
		draw_rect(r, Color(DB.C_ALLY.r, DB.C_ALLY.g, DB.C_ALLY.b, 0.9 if on else 0.22), false, 1.5)
		var base := r.position.y + r.size.y * 0.5 + 7.0
		var value := String(row.get("value", ""))
		if value == "":
			UIKit.text(self, Vector2(r.position.x, base), String(row["label"]), 19, tc, on, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			_left_rects.append(Rect2())
			_right_rects.append(Rect2())
		else:
			UIKit.text(self, Vector2(r.position.x + 16, base), String(row["label"]), 18, tc, on)
			var va := Rect2(r.end.x - 230, r.position.y, 226, r.size.y)
			var vc: Color = row.get("value_color", DB.C_ALLY)
			if dis:
				vc = Color(vc.r, vc.g, vc.b, 0.4)
			if bool(row.get("adjust", false)):
				var lr := Rect2(va.position.x, va.position.y, 30, va.size.y)
				var rr := Rect2(va.end.x - 30, va.position.y, 30, va.size.y)
				_left_rects.append(lr)
				_right_rects.append(rr)
				_tri(lr.get_center(), -1, Color(vc.r, vc.g, vc.b, 0.9 if on else 0.5))
				_tri(rr.get_center(), 1, Color(vc.r, vc.g, vc.b, 0.9 if on else 0.5))
			else:
				_left_rects.append(Rect2())
				_right_rects.append(Rect2())
			var sl := float(row.get("slider", -1.0))
			var vb := base if sl < 0.0 else base - 4.0
			UIKit.text(self, Vector2(va.position.x + 30, vb), value, 17, vc, on, HORIZONTAL_ALIGNMENT_CENTER, va.size.x - 60)
			if sl >= 0.0:
				var bw := va.size.x - 76.0
				var bar := Rect2(va.position.x + 38, r.end.y - 9, bw, 3)
				draw_rect(bar, Color(1, 1, 1, 0.12))
				draw_rect(Rect2(bar.position, Vector2(bw * clampf(sl, 0.0, 1.0), 3)), vc)
		y += row_h
	if info_w > 0.0 and not rows.is_empty():
		_draw_info(Rect2(px + panel_w + 24.0, py, info_w, ph), rows[sel])
	UIKit.text(self, Vector2(0, minf(H - 18.0, py + ph + 34.0)), hint, 15, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, W)

func _tri(c: Vector2, dir: int, col: Color) -> void:
	var s := 7.0
	var pts := PackedVector2Array([c + Vector2(s * dir, 0), c + Vector2(-s * 0.7 * dir, -s), c + Vector2(-s * 0.7 * dir, s)])
	draw_colored_polygon(pts, col)

## 정보 패널 안에서 여러 줄 문장을 폭에 맞춰 줄바꿈해서 그린다. 그린 뒤의 y를 돌려준다.
func wrap_text(pos: Vector2, s: String, width: float, fsize: int, col: Color, line_h := 0.0) -> float:
	if line_h <= 0.0:
		line_h = fsize * 1.45
	var y := pos.y
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var cand := word if line == "" else line + " " + word
			if UIKit.text_width(cand, fsize) > width and line != "":
				UIKit.text(self, Vector2(pos.x, y), line, fsize, col)
				y += line_h
				line = word
			else:
				line = cand
		UIKit.text(self, Vector2(pos.x, y), line, fsize, col)
		y += line_h
	return y
