extends Node
## 폰트·테마·입력키·글로우 텍스처 등 공용 리소스.
## (에디터 없이도 돌도록 전부 코드로 생성합니다)

var font_regular: Font
var font_bold: Font
var theme: Theme
var glow_tex: Texture2D      # 부드러운 형광 번짐
var soft_tex: Texture2D      # 더 넓고 옅은 번짐(배경용)
var vignette_tex: Texture2D  # 현미경 시야 테두리
var add_mat: CanvasItemMaterial
var _notice_layer: CanvasLayer
var _notice_label: Label
var _notice_t := 0.0
var _windowed_rect := Rect2i()
var _fps_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	DB.apply_palette(String(Save.setting("color_mode")))
	font_regular = _load_font("res://assets/fonts/Pretendard-Regular.otf")
	font_bold = _load_font("res://assets/fonts/Pretendard-Bold.otf")
	theme = Theme.new()
	theme.default_font = font_regular
	theme.default_font_size = 18
	get_tree().root.theme = theme
	add_mat = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_tex = _radial(128, [0.0, 0.12, 0.35, 1.0], [Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0)])
	soft_tex = _radial(128, [0.0, 0.5, 1.0], [Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.0)])
	vignette_tex = _radial(256, [0.0, 0.66, 0.9, 1.0], [Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.38), Color(0, 0, 0, 0.75)])
	_build_notice()
	if bool(Save.setting("fullscreen")) and not OS.has_feature("web") and not _embedded():
		set_fullscreen.call_deferred(true)

# ── 화면 위 짧은 안내문(전체화면 실패 등) ───────────────────
func _build_notice() -> void:
	_notice_layer = CanvasLayer.new()
	_notice_layer.layer = 100
	add_child(_notice_layer)
	_notice_label = Label.new()
	_notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_notice_label.offset_top = -110
	_notice_label.offset_bottom = -60
	_notice_label.offset_left = -560
	_notice_label.offset_right = 560
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.add_theme_font_size_override("font_size", 17)
	_notice_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	_notice_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_notice_label.add_theme_constant_override("outline_size", 6)
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_label.visible = false
	_notice_layer.add_child(_notice_label)
	_fps_label = Label.new()
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps_label.offset_left = -140
	_fps_label.offset_top = -34
	_fps_label.offset_right = -14
	_fps_label.offset_bottom = -8
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.8))
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_layer.add_child(_fps_label)

func notice(msg: String, seconds := 4.0) -> void:
	_notice_label.text = msg
	_notice_label.visible = true
	_notice_label.modulate.a = 1.0
	_notice_t = seconds

func _process(delta: float) -> void:
	_fps_label.visible = bool(Save.setting("show_fps"))
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if _notice_t > 0.0:
		_notice_t -= delta
		_notice_label.modulate.a = clampf(_notice_t, 0.0, 1.0)
		if _notice_t <= 0.0:
			_notice_label.visible = false

func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var r: Variant = load(path)
		if r is Font:
			return r
	# 에디터 임포트 없이 실행될 때(테스트 등)를 위한 대비
	var ff := FontFile.new()
	if ff.load_dynamic_font(path) == OK:
		return ff
	return ThemeDB.fallback_font

func _radial(size: int, offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t

# ── 입력 ─────────────────────────────────────────────────────
func _setup_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]], [JOY_BUTTON_DPAD_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]], [JOY_BUTTON_DPAD_RIGHT])
	_action("move_up", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]], [JOY_BUTTON_DPAD_UP])
	_action("move_down", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]], [JOY_BUTTON_DPAD_DOWN])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_action("confirm", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], [JOY_BUTTON_A])
	_action("back", [KEY_BACKSPACE], [JOY_BUTTON_B])
	_action("reroll", [KEY_R], [JOY_BUTTON_Y])
	_action("choice_1", [KEY_1, KEY_KP_1])
	_action("choice_2", [KEY_2, KEY_KP_2])
	_action("choice_3", [KEY_3, KEY_KP_3])
	_action("fullscreen", [KEY_F11])
	# macOS 표준 전체화면 단축키 ⌘+Ctrl+F (Mac에서는 F11이 '데스크탑 보기'라서 게임에 안 들어옴)
	var mac_fs := InputEventKey.new()
	mac_fs.physical_keycode = KEY_F
	mac_fs.meta_pressed = true
	mac_fs.ctrl_pressed = true
	InputMap.action_add_event("fullscreen", mac_fs)

func _action(name: String, keys: Array, buttons: Array = [], axes: Array = [], more_buttons: Array = []) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.3)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)
	for b in buttons + more_buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(name, jb)
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = a[0]
		jm.axis_value = a[1]
		InputMap.action_add_event(name, jm)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen") and not OS.has_feature("web"):
		toggle_fullscreen()

func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	if m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return true
	return get_window().borderless and get_window().size == DisplayServer.screen_get_size(get_window().current_screen)

func _embedded() -> bool:
	return Engine.has_method("is_embedded_in_editor") and bool(Engine.call("is_embedded_in_editor"))

func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())

func set_fullscreen(on: bool) -> void:
	if OS.has_feature("web"):
		notice("웹 버전은 브라우저의 전체화면 버튼을 사용하세요.")
		return
	if _embedded():
		notice("지금은 Godot 에디터 안에 끼워진 창이라 전체화면이 막혀 있습니다. 내보낸 앱(.app / .exe)에서는 정상 동작합니다.", 6.0)
		return
	var w := get_window()
	if on:
		w.mode = Window.MODE_FULLSCREEN
		await get_tree().process_frame
		await get_tree().process_frame
		if not is_fullscreen():
			# 일부 환경에서 네이티브 전체화면이 거부되면: 테두리 없는 창으로 화면을 덮는다
			var scr := w.current_screen
			w.mode = Window.MODE_WINDOWED
			_windowed_rect = Rect2i(w.position, w.size)
			w.borderless = true
			w.position = DisplayServer.screen_get_position(scr)
			w.size = DisplayServer.screen_get_size(scr)
	else:
		if w.borderless and _windowed_rect.size != Vector2i.ZERO:
			# 대체 경로로 켰던 경우에만 원래 창 크기로 되돌린다
			w.borderless = false
			w.position = _windowed_rect.position
			w.size = _windowed_rect.size
		w.mode = Window.MODE_WINDOWED  # 네이티브 전체화면은 OS가 원래 크기로 복원
	Save.set_setting("fullscreen", on)
	if on and OS.get_name() == "macOS":
		notice("전체화면 켜기/끄기: ⌘ + Ctrl + F", 2.5)

# ── 그리기 헬퍼 ──────────────────────────────────────────────
func text(ci: CanvasItem, pos: Vector2, s: String, size := 18, col := Color(0.92, 0.94, 1.0), bold := false, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f: Font = font_bold if bold else font_regular
	ci.draw_string(f, pos, s, align, width, size, col)

func text_width(s: String, size := 18, bold := false) -> float:
	var f: Font = font_bold if bold else font_regular
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func glow(ci: CanvasItem, pos: Vector2, radius: float, col: Color) -> void:
	ci.draw_texture_rect(glow_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)

func panel_box(ci: CanvasItem, r: Rect2, fill := Color(0.04, 0.05, 0.09, 0.92), border := Color(0.36, 0.72, 1.0, 0.55), width := 2.0) -> void:
	ci.draw_rect(r, fill, true)
	ci.draw_rect(r, border, false, width)
