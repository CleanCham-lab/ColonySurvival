extends CanvasLayer
## 레벨업 3택1. 1/2/3 키, ↑↓+Enter, 마우스 클릭, R = 다시 뽑기.

const HUD = preload("res://scripts/ui/hud.gd")

var world: Node
var _root: Control
var _opts: Array = []
var _sel := 0
var _rerolls := 0
var _open := false
var _lock := 0.0
var _cards: Array = []

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_root.draw.connect(_draw_panel)
	_root.gui_input.connect(_on_gui_input)
	visible = false

func is_open() -> bool:
	return _open

func open(opts: Array, rerolls: int) -> void:
	_opts = opts
	_rerolls = rerolls
	_sel = 0
	_open = true
	visible = true
	_lock = 0.3
	_root.queue_redraw()

func close() -> void:
	_open = false
	visible = false

func choose(i: int) -> void:
	if not _open or i < 0 or i >= _opts.size():
		return
	Audio.play("ui_select")
	world.on_levelup_chosen(_opts[i])

func _process(delta: float) -> void:
	if _open:
		_lock = maxf(0.0, _lock - delta)
		_root.queue_redraw()

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if _lock > 0.0:
		if event is InputEventKey or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
		return
	var handled := true
	if event.is_action_pressed("move_up"):
		_sel = (_sel - 1 + _opts.size()) % _opts.size()
		Audio.play("ui_move")
	elif event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % _opts.size()
		Audio.play("ui_move")
	elif event.is_action_pressed("confirm"):
		choose(_sel)
	elif event.is_action_pressed("choice_1"):
		choose(0)
	elif event.is_action_pressed("choice_2"):
		choose(1)
	elif event.is_action_pressed("choice_3"):
		choose(2)
	elif event.is_action_pressed("reroll"):
		if _rerolls > 0:
			Audio.play("ui_move")
			world.on_reroll()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _on_gui_input(event: InputEvent) -> void:
	if not _open or _lock > 0.0:
		return
	if event is InputEventMouseMotion:
		for i in _cards.size():
			if (_cards[i] as Rect2).has_point(event.position):
				_sel = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _cards.size():
			if (_cards[i] as Rect2).has_point(event.position):
				choose(i)
				return

func _draw_panel() -> void:
	var W := _root.size.x
	var H := _root.size.y
	_root.draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.02, 0.72))
	UIKit.text(_root, Vector2(0, H * 0.5 - 230), "LEVEL UP", 40, DB.C_GFP, true, HORIZONTAL_ALIGNMENT_CENTER, W)
	UIKit.text(_root, Vector2(0, H * 0.5 - 196), "Lv %d  ·  하나를 고르세요" % world.level, 18, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, W)
	_cards.clear()
	var cw := minf(620.0, W - 60.0)
	var ch := 100.0
	var y := H * 0.5 - 160.0
	for i in _opts.size():
		var o: Dictionary = _opts[i]
		var r := Rect2((W - cw) / 2.0, y, cw, ch)
		_cards.append(r)
		var sel := i == _sel
		var col: Color = o.get("color", DB.C_ALLY)
		var a := 1.0 if _lock <= 0.0 else 0.5
		UIKit.panel_box(_root, r, Color(0.04, 0.06, 0.11, 0.95 * a), Color(col.r, col.g, col.b, (1.0 if sel else 0.35) * a), 3.0 if sel else 1.5)
		if sel:
			_root.draw_texture_rect(UIKit.glow_tex, r.grow(30.0), false, Color(col.r, col.g, col.b, 0.10))
		HUD.icon(_root, Rect2(r.position.x + 18, r.position.y + 20, 60, 60), String(o.get("id", "")), col, 0, 0)
		UIKit.text(_root, Vector2(r.position.x + 18, r.position.y + 94), str(i + 1), 13, DB.C_TEXT_DIM, true)
		var tx := r.position.x + 96
		UIKit.text(_root, Vector2(tx, r.position.y + 36), String(o["title"]), 24, DB.C_TEXT, true)
		var tag := String(o.get("tag", ""))
		var tag_col := DB.C_WARN if tag.begins_with("NEW") else DB.C_TEXT_DIM
		UIKit.text(_root, Vector2(tx + UIKit.text_width(String(o["title"]), 24, true) + 14, r.position.y + 35), tag, 16, tag_col, true)
		UIKit.text(_root, Vector2(tx, r.position.y + 70), String(o.get("desc", "")), 17, Color(0.82, 0.86, 0.95), false, HORIZONTAL_ALIGNMENT_LEFT, cw - 120)
		y += ch + 14.0
	var hint := "1 · 2 · 3   또는   ↑↓ + Enter   ·   마우스 클릭"
	if _rerolls > 0:
		hint += "      R  다시 뽑기 (%d회 남음)" % _rerolls
	UIKit.text(_root, Vector2(0, y + 24), hint, 15, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, W)
