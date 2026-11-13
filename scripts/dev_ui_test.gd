extends Node
## 개발용: --ui_test 로 메뉴 흐름을 자동으로 한 바퀴 돌려 본다(스크립트 오류 확인용).
## 타이틀 → 연구실(구매) → 설정(값 바꾸기) → 실험 설정(모드·스테이지 바꾸기) → 셀라인 → 런 → 일시정지·설정 → 타이틀

var main: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _wait(s := 0.25) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _run() -> void:
	await _wait()
	var g0 := int(Save.data["grant"])
	Save.data["grant"] = 500
	main.show_shop()
	await _wait()
	main.screen._press(0, 0)   # 배양 조건 최적화 구매
	await _wait()
	print("[ui] shop bought culture -> lv=", Save.upgrade("culture"), " grant=", Save.data["grant"])
	main.screen._press(main.screen.rows.size() - 1, 0)  # 돌아가기
	await _wait()
	main.show_options()
	await _wait()
	main.screen._press(1, -1)  # 음악 -10%
	main.screen._press(3, 1)   # 색각 모드
	print("[ui] options music=", Save.setting("music"), " palette=", DB.palette)
	main.screen._press(3, 1)   # 원래대로
	main.screen._press(1, 1)
	main.screen.close()
	await _wait()
	main.show_run_setup()
	await _wait()
	main.screen._press(0, 1)   # 모드 → 다음
	main.screen._press(1, 1)   # 스테이지 → 다음
	print("[ui] setup cfg=", main.screen.cfg())
	main.screen._press(3, 0)   # 셀라인 고르기
	await _wait()
	print("[ui] screen after setup: ", main.screen.get_script().resource_path, " cfg=", main.setup_cfg)
	main.screen.chosen.emit("hela")
	await _wait(1.0)
	print("[ui] world mode=", main.world.mode, " zone=", main.world.zone, " hp=", main.world.player.max_hp)
	main.world.pause_menu._show()
	await _wait()
	main.world.pause_menu._open_options()
	await _wait()
	main.world.pause_menu._opts._press(3, 1)
	await _wait()
	main.world.pause_menu._opts.close()
	await _wait()
	main.world.pause_menu._activate(2)  # 타이틀로
	await _wait()
	print("[ui] back at: ", main.screen.get_script().resource_path)
	# 원상복구
	(Save.data["upgrades"] as Dictionary).erase("culture")
	Save.data["grant"] = g0
	Save.set_setting("color_mode", "default")
	DB.apply_palette("default")
	Save.data["last_setup"] = {"mode": "normal", "zone": "dish", "difficulty": "normal"}
	Save.save_data()
	print("[ui] done OK")
	get_tree().quit()
