extends "res://scripts/ui/menu_base.gd"
## 설정: 볼륨(전체/음악/효과음), 색각 모드, 화면 흔들림, 피해 숫자, FPS, 전체화면.
## 타이틀에서는 단독 화면, 일시정지에서는 overlay=true 로 위에 띄운다.

signal palette_changed

func _init() -> void:
	title = "설정"
	panel_w = 560.0

func _pct(k: String) -> String:
	return "%d%%" % int(round(float(Save.setting(k)) * 100.0))

func _onoff(k: String) -> String:
	return "켜짐" if bool(Save.setting(k)) else "꺼짐"

func _build_rows() -> Array:
	var r: Array = [
		{"id": "master", "label": "전체 볼륨", "value": _pct("master"), "adjust": true, "slider": float(Save.setting("master"))},
		{"id": "music", "label": "배경음악", "value": _pct("music"), "adjust": true, "slider": float(Save.setting("music"))},
		{"id": "sfx", "label": "효과음", "value": _pct("sfx"), "adjust": true, "slider": float(Save.setting("sfx"))},
		{"id": "color_mode", "label": "색 구분 모드", "value": "색각 친화" if DB.palette == "cvd" else "기본", "adjust": true},
		{"id": "shake", "label": "화면 흔들림", "value": _onoff("shake"), "adjust": true},
		{"id": "damage_numbers", "label": "피해 숫자", "value": _onoff("damage_numbers"), "adjust": true},
		{"id": "show_fps", "label": "FPS 표시", "value": _onoff("show_fps"), "adjust": true},
	]
	if not OS.has_feature("web"):
		r.append({"id": "fullscreen", "label": "전체화면", "value": "켜짐" if UIKit.is_fullscreen() else "꺼짐", "adjust": true})
	r.append({"id": "back", "label": "돌아가기"})
	subtitle = "색각 친화: 아군 파랑 · 적 주황/노랑 · 경고 흰색" if DB.palette == "cvd" else "색각 친화 모드는 빨강/초록 대신 파랑/주황 계열을 씁니다"
	return r

func _on_row(id: String, dir: int) -> void:
	match id:
		"master", "music", "sfx":
			var v := float(Save.setting(id))
			if dir == 0:
				v = 0.0 if v >= 0.999 else v + 0.1
			else:
				v = clampf(v + 0.1 * dir, 0.0, 1.0)
			Save.set_setting(id, snappedf(v, 0.05))
			Audio.apply_volume()
			if id == "sfx" or id == "master":
				Audio.play("pickup", 1.0, 0.0, 0.0)
		"color_mode":
			var m := "default" if DB.palette == "cvd" else "cvd"
			Save.set_setting("color_mode", m)
			DB.apply_palette(m)
			palette_changed.emit()
		"shake", "damage_numbers", "show_fps":
			Save.set_setting(id, not bool(Save.setting(id)))
		"fullscreen":
			await UIKit.set_fullscreen(not UIKit.is_fullscreen())
			if is_inside_tree():
				refresh()
		"back":
			close()
