extends CanvasLayer
## 일시정지(Esc/P). 창이 포커스를 잃어도 자동으로 멈춘다.

const Icons = preload("res://scripts/ui/icons.gd")
const OptionsScreen = preload("res://scripts/ui/options_screen.gd")

var world: Node
var _root: Control
var _open := false
var _sel := 0
var _rects: Array = []
var _opts: Control = null

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_root.draw.connect(_draw_menu)
	_root.gui_input.connect(_on_gui_input)
	visible = false

func _items() -> Array:
	return ["계속하기", "설정", "타이틀로 (이번 런 포기)"]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _open and world != null and not world.finished and not get_tree().paused:
		_show()

func _input(event: InputEvent) -> void:
	if _opts != null:
		return
	if event.is_action_pressed("pause"):
		if _open:
			_hide()
			get_viewport().set_input_as_handled()
		elif not get_tree().paused and not world.finished:
			_show()
			get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	var n := _items().size()
	if event.is_action_pressed("move_up"):
		_sel = (_sel - 1 + n) % n
		Audio.play("ui_move")
	elif event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % n
		Audio.play("ui_move")
	elif event.is_action_pressed("confirm"):
		_activate(_sel)
	elif event.is_action_pressed("back"):
		_hide()
	else:
		return
	get_viewport().set_input_as_handled()

func _show() -> void:
	_open = true
	visible = true
	_sel = 0
	get_tree().paused = true
	_root.queue_redraw()

func _hide() -> void:
	_open = false
	visible = false
	get_tree().paused = false

func _activate(i: int) -> void:
	Audio.play("ui_select")
	match i:
		0:
			_hide()
		1:
			_open_options()
		2:
			_open = false
			visible = false
			get_tree().paused = false
			world.quit_to_title.emit()
	_root.queue_redraw()

func _open_options() -> void:
	_opts = OptionsScreen.new()
	_opts.overlay = true
	_opts.palette_changed.connect(func() -> void: world.refresh_palette())
	_opts.closed.connect(func() -> void:
		_opts.queue_free()
		_opts = null
		_root.queue_redraw())
	add_child(_opts)

func _on_gui_input(event: InputEvent) -> void:
	if not _open or _opts != null:
		return
	if event is InputEventMouseMotion:
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(event.position) and _sel != i:
				_sel = i
				_root.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(event.position):
				_activate(i)
				return

func _draw_menu() -> void:
	var W := _root.size.x
	var H := _root.size.y
	_root.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0.02, 0.7))
	var pw := 420.0
	var items := _items()
	var ph := maxf(110.0 + items.size() * 52.0, 120.0 + (world.weapons.size() + world.passives.size()) * 28.0)
	var px := W / 2.0 - pw - 20.0
	var py := (H - ph) / 2.0
	UIKit.panel_box(_root, Rect2(px, py, pw, ph))
	UIKit.text(_root, Vector2(px, py + 46), "일시정지", 28, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_CENTER, pw)
	_rects.clear()
	for i in items.size():
		var r := Rect2(px + 30, py + 76 + i * 52, pw - 60, 42)
		_rects.append(r)
		var sel := i == _sel
		_root.draw_rect(r, Color(0.2, 0.4, 0.7, 0.45) if sel else Color(0.08, 0.1, 0.16, 0.8))
		_root.draw_rect(r, Color(DB.C_ALLY.r, DB.C_ALLY.g, DB.C_ALLY.b, 0.9 if sel else 0.25), false, 1.5)
		UIKit.text(_root, Vector2(r.position.x, r.position.y + 28), String(items[i]), 18, DB.C_TEXT, sel, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# 오른쪽: 현재 빌드
	var bx := W / 2.0 + 20.0
	UIKit.panel_box(_root, Rect2(bx, py, pw, ph), Color(0.03, 0.05, 0.09, 0.92), Color(DB.C_GFP.r, DB.C_GFP.g, DB.C_GFP.b, 0.4))
	UIKit.text(_root, Vector2(bx + 24, py + 44), "이번 런 빌드", 20, DB.C_TEXT, true)
	UIKit.text(_root, Vector2(bx + 24, py + 68), "%s · %s · %s" % [DB.MODES[world.mode]["name"], DB.ZONES[world.zone]["name"], DB.DIFFICULTY[world.difficulty]["name"]], 14, DB.C_TEXT_DIM)
	var y := py + 98.0
	for w in world.weapons:
		var wc: Color = (DB.WEAPONS[w.id] as Dictionary)["color"]
		Icons.draw(_root, String(w.id), Vector2(bx + 36, y - 6), 22.0, wc)
		UIKit.text(_root, Vector2(bx + 58, y), "%s  Lv%d" % [w.display_name(), w.level], 17, wc)
		y += 28.0
	y += 8.0
	for k in world.passives.keys():
		Icons.draw(_root, String(k), Vector2(bx + 36, y - 6), 20.0, DB.C_GFP)
		UIKit.text(_root, Vector2(bx + 58, y), "%s  Lv%d  ·  %s" % [DB.PASSIVES[k]["name"], world.passives[k], DB.PASSIVES[k]["text"]], 16, DB.C_GFP)
		y += 28.0
	UIKit.text(_root, Vector2(0, py + ph + 40), "WASD / 방향키 이동   ·   Esc 계속   ·   전체화면 %s" % ("⌘ + Ctrl + F" if OS.get_name() == "macOS" else "F11"), 15, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, W)
