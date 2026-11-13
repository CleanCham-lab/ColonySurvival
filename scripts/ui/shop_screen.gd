extends "res://scripts/ui/menu_base.gd"
## 연구실(영구 강화). 런에서 번 연구비로 산다.


var _flash := ""
var _flash_t := 0.0

func _init() -> void:
	title = "연구실"
	panel_w = 560.0
	info_w = 380.0
	row_h = 44.0
	hint = "↑↓ 선택   ·   Enter 구매   ·   Esc 뒤로"

func _build_rows() -> Array:
	subtitle = "보유 연구비  %d" % int(Save.data["grant"])
	var r: Array = []
	for id in DB.SHOP_ORDER:
		var u: Dictionary = DB.SHOP[id]
		var lv := Save.upgrade(id)
		var cost := Save.upgrade_cost(id)
		var mx := int(u["max"])
		var v := ""
		var vc := DB.C_ALLY
		if cost < 0:
			v = ("해금됨" if DB.CHARACTERS.has(id) else "완료") if mx == 1 else "MAX"
			vc = DB.C_GFP
		else:
			v = "%d" % cost
			vc = DB.C_WARN if int(Save.data["grant"]) >= cost else Color(0.55, 0.6, 0.7)
		var pips := ""
		if mx > 1:
			pips = "  " + "●".repeat(lv) + "○".repeat(mx - lv)
		r.append({"id": id, "label": String(u["name"]) + pips, "value": v, "value_color": vc})
	r.append({"id": "back", "label": "돌아가기"})
	return r

func _on_row(id: String, _dir: int) -> void:
	if id == "back":
		close()
		return
	var cost := Save.upgrade_cost(id)
	if cost < 0:
		_flash = "이미 최대치입니다"
	elif Save.buy(id):
		_flash = "구매 완료: %s" % String(DB.SHOP[id]["name"])
		Audio.play("levelup", 0.7)
	else:
		_flash = "연구비가 %d 부족합니다" % (cost - int(Save.data["grant"]))
	_flash_t = 2.0

func _process(delta: float) -> void:
	super._process(delta)
	if _flash_t > 0.0:
		_flash_t -= delta

func _draw_info(r: Rect2, row: Dictionary) -> void:
	UIKit.panel_box(self, r, Color(0.03, 0.05, 0.09, 0.92), Color(DB.C_WARN.r, DB.C_WARN.g, DB.C_WARN.b, 0.4))
	var x := r.position.x + 24.0
	var w := r.size.x - 48.0
	var y := r.position.y + 46.0
	var id := String(row["id"])
	if DB.SHOP.has(id):
		var u: Dictionary = DB.SHOP[id]
		UIKit.text(self, Vector2(x, y), String(u["name"]), 22, DB.C_TEXT, true)
		y += 34.0
		UIKit.text(self, Vector2(x, y), String(u["text"]), 18, DB.C_GFP, true)
		y += 30.0
		var lv := Save.upgrade(id)
		var mx := int(u["max"])
		UIKit.text(self, Vector2(x, y), "단계  %d / %d" % [lv, mx], 16, DB.C_TEXT_DIM)
		y += 26.0
		var cost := Save.upgrade_cost(id)
		if cost >= 0:
			UIKit.text(self, Vector2(x, y), "다음 단계 비용  %d" % cost, 16, DB.C_WARN)
			y += 26.0
		if id == "raw264":
			y = wrap_text(Vector2(x, y + 6.0), "Reviewer #2를 한 번 쓰러뜨려도(클리어) 해금됩니다.", w, 15, DB.C_TEXT_DIM)
		elif id == "backup":
			y = wrap_text(Vector2(x, y + 6.0), "-80℃에 얼려둔 백업 스톡. 쓰러지면 한 번 다시 일어선다.", w, 15, DB.C_TEXT_DIM)
	else:
		UIKit.text(self, Vector2(x, y), "연구비 모으는 법", 20, DB.C_TEXT, true)
		y = wrap_text(Vector2(x, y + 32.0), "버틴 시간, 처치 수, 보스 처치로 받습니다. 클리어하면 ×1.5, 난이도 '리뷰어 모드'는 ×1.5.", w, 15, DB.C_TEXT_DIM)
	if _flash_t > 0.0:
		var c := DB.C_GFP if _flash.begins_with("구매") else DB.C_WARN
		UIKit.text(self, Vector2(x, r.end.y - 30.0), _flash, 16, Color(c.r, c.g, c.b, clampf(_flash_t, 0.0, 1.0)), true)
	var tg := int(Save.data["total_grant"])
	UIKit.text(self, Vector2(x, r.end.y - 58.0), "지금까지 받은 연구비  %d" % tg, 14, DB.C_TEXT_DIM)
