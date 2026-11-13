extends Node
## 화면 흐름: 타이틀 → 실험 설정(모드·스테이지·난이도) → 셀라인 선택 → 런(World) → 결과.
## 타이틀에서 연구실(영구 강화)·설정으로도 갈 수 있다.

const World = preload("res://scripts/run/world.gd")
const TitleScreen = preload("res://scripts/ui/title_screen.gd")
const CharSelect = preload("res://scripts/ui/char_select.gd")
const ResultScreen = preload("res://scripts/ui/result_screen.gd")
const RunSetup = preload("res://scripts/ui/run_setup.gd")
const ShopScreen = preload("res://scripts/ui/shop_screen.gd")
const OptionsScreen = preload("res://scripts/ui/options_screen.gd")

var world: Node2D = null
var ui: CanvasLayer
var screen: Control = null
var dev: Dictionary = {}
var last_char := "hek293t"
var setup_cfg: Dictionary = {"mode": "normal", "zone": "dish", "difficulty": "normal"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = CanvasLayer.new()
	ui.layer = 30
	add_child(ui)
	dev = _parse_args()
	if dev.has("palette"):
		DB.apply_palette(String(dev["palette"]))
	var ls: Dictionary = Save.data.get("last_setup", {})
	for k in ["mode", "zone", "difficulty"]:
		if ls.has(k):
			setup_cfg[k] = String(ls[k])
		if dev.has(k):
			setup_cfg[k] = String(dev[k])
	if dev.has("autoplay") or dev.has("start"):
		start_run(String(dev.get("char", "hek293t")))
	else:
		match String(dev.get("screen", "")):
			"select":
				show_char_select()
			"icons":
				_set_screen(preload("res://scripts/ui/icon_sheet.gd").new())
			"setup":
				show_run_setup()
			"shop":
				show_shop()
			"options":
				show_options()
			_:
				show_title()
	if dev.has("screen"):
		_screen_shot_and_quit()
	if dev.has("ui_test"):
		var t: Node = load("res://scripts/dev_ui_test.gd").new()
		t.main = self
		add_child(t)

## 개발용 인자: godot --path . -- --autoplay --start=290 --shots=10,60 --shotdir=/tmp/x --quit_after=120 --god
func _parse_args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		d[kv[0]] = kv[1] if kv.size() > 1 else true
	return d

func _set_screen(c: Control) -> void:
	if screen != null:
		screen.queue_free()
	screen = c
	if c != null:
		ui.add_child(c)

func _clear_world() -> void:
	if world != null:
		world.queue_free()
		world = null
	get_tree().paused = false
	Engine.time_scale = 1.0

func show_title() -> void:
	_clear_world()
	Audio.play_music("title")
	var s := TitleScreen.new()
	s.start_pressed.connect(show_run_setup)
	s.shop_pressed.connect(show_shop)
	s.options_pressed.connect(show_options)
	s.quit_pressed.connect(func() -> void: get_tree().quit())
	_set_screen(s)

func show_run_setup() -> void:
	_clear_world()
	Audio.play_music("title")
	var s := RunSetup.new()
	s.next.connect(func(c: Dictionary) -> void:
		setup_cfg = c
		show_char_select())
	s.closed.connect(show_title)
	_set_screen(s)

func show_shop() -> void:
	_clear_world()
	Audio.play_music("title")
	var s := ShopScreen.new()
	s.closed.connect(show_title)
	_set_screen(s)

func show_options() -> void:
	var s := OptionsScreen.new()
	s.closed.connect(show_title)
	_set_screen(s)

func show_char_select() -> void:
	_clear_world()
	Audio.play_music("title")
	var s := CharSelect.new()
	s.chosen.connect(start_run)
	s.back.connect(show_run_setup)
	_set_screen(s)

func start_run(cid: String) -> void:
	_clear_world()
	_set_screen(null)
	last_char = cid
	Audio.play_music("run")
	world = World.new()
	var cfg := setup_cfg.duplicate()
	cfg["char"] = cid
	cfg["dev"] = dev
	world.setup(cfg)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.run_finished.connect(_on_run_finished)
	world.quit_to_title.connect(show_title)
	add_child(world)

func _on_run_finished(result: Dictionary) -> void:
	result["grant"] = Save.record_run(result)
	var rs := ResultScreen.new()
	rs.setup(result)
	rs.retry.connect(func() -> void: start_run(last_char))
	rs.to_select.connect(show_char_select)
	rs.to_title.connect(show_title)
	_set_screen(rs)

func _screen_shot_and_quit() -> void:
	await get_tree().create_timer(1.0).timeout
	if dev.has("fs"):
		await UIKit.set_fullscreen(true)
		await get_tree().create_timer(0.5).timeout
		print("[fs] on=", UIKit.is_fullscreen(), " mode=", get_window().mode, " size=", get_window().size)
		await UIKit.set_fullscreen(false)
		await get_tree().create_timer(0.5).timeout
		print("[fs] off=", not UIKit.is_fullscreen(), " mode=", get_window().mode, " size=", get_window().size)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var dir := String(dev.get("shotdir", "user://shots"))
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("screen_%s.png" % String(dev["screen"])))
	get_tree().quit()
