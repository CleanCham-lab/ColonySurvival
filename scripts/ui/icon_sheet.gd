extends Control
## 개발용: 모든 무기·시약 아이콘 한눈에 보기 (--screen=icons)

const Icons = preload("res://scripts/ui/icons.gd")
const HUD = preload("res://scripts/ui/hud.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DB.C_BG)
	UIKit.text(self, Vector2(0, 50), "무기 10종", 24, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var x0 := (size.x - 5 * 230.0) / 2.0
	for i in DB.WEAPON_ORDER.size():
		var id: String = DB.WEAPON_ORDER[i]
		var d: Dictionary = DB.WEAPONS[id]
		var p := Vector2(x0 + (i % 5) * 230.0 + 115.0, 140.0 + (i / 5) * 150.0)
		HUD.icon(self, Rect2(p - Vector2(40, 40), Vector2(80, 80)), id, d["color"], 3, DB.WEAPON_MAX_LEVEL)
		UIKit.text(self, Vector2(p.x - 115, p.y + 68), String(d["name"]), 17, d["color"], true, HORIZONTAL_ALIGNMENT_CENTER, 230)
	UIKit.text(self, Vector2(0, 470), "시약 8종", 24, DB.C_TEXT, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var x1 := (size.x - 8 * 150.0) / 2.0
	for i in DB.PASSIVE_ORDER.size():
		var id: String = DB.PASSIVE_ORDER[i]
		var pd: Dictionary = DB.PASSIVES[id]
		var p := Vector2(x1 + i * 150.0 + 75.0, 560.0)
		HUD.icon(self, Rect2(p - Vector2(34, 34), Vector2(68, 68)), id, DB.C_GFP, 2, DB.PASSIVE_MAX_LEVEL)
		UIKit.text(self, Vector2(p.x - 75, p.y + 60), String(pd["name"]), 15, DB.C_GFP, true, HORIZONTAL_ALIGNMENT_CENTER, 150)
		UIKit.text(self, Vector2(p.x - 75, p.y + 82), String(pd["text"]), 13, DB.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_CENTER, 150)
