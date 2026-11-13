extends "res://scripts/ui/menu_base.gd"
## 실험 설정: 모드(정규/야근/오늘의 조건) · 스테이지(배양접시/클린벤치) · 난이도 → 셀라인 고르기.

signal next(cfg: Dictionary)

var mode := "normal"
var zone := "dish"
var difficulty := "normal"

func _init() -> void:
	title = "실험 설정"
	panel_w = 520.0
	info_w = 420.0
	var ls: Dictionary = Save.data.get("last_setup", {})
	mode = String(ls.get("mode", "normal"))
	zone = String(ls.get("zone", "dish"))
	difficulty = String(ls.get("difficulty", "normal"))
	if not DB.MODES.has(mode):
		mode = "normal"
	if not DB.ZONES.has(zone):
		zone = "dish"
	if not DB.DIFFICULTY.has(difficulty):
		difficulty = "normal"

func cfg() -> Dictionary:
	return {"mode": mode, "zone": zone, "difficulty": difficulty}

func _build_rows() -> Array:
	subtitle = "고른 설정은 다음에도 그대로 기억합니다"
	return [
		{"id": "mode", "label": "모드", "value": String(DB.MODES[mode]["name"]), "adjust": true},
		{"id": "zone", "label": "스테이지", "value": String(DB.ZONES[zone]["name"]), "adjust": true},
		{"id": "difficulty", "label": "난이도", "value": String(DB.DIFFICULTY[difficulty]["name"]), "adjust": true,
			"value_color": DB.C_GFP if difficulty == "easy" else (DB.C_ENEMY if difficulty == "hard" else DB.C_ALLY)},
		{"id": "go", "label": "셀라인 고르기  →", "color": DB.C_GFP},
		{"id": "back", "label": "돌아가기"},
	]

func _cycle(arr: Array, cur: String, dir: int) -> String:
	var i := arr.find(cur)
	return String(arr[(i + (dir if dir != 0 else 1) + arr.size()) % arr.size()])

func _on_row(id: String, dir: int) -> void:
	match id:
		"mode":
			mode = _cycle(DB.MODE_ORDER, mode, dir)
		"zone":
			zone = _cycle(DB.ZONE_ORDER, zone, dir)
		"difficulty":
			difficulty = _cycle(DB.DIFFICULTY_ORDER, difficulty, dir)
		"go":
			Save.data["last_setup"] = cfg()
			Save.save_data()
			next.emit(cfg())
			return
		"back":
			close()
			return
	Save.data["last_setup"] = cfg()

func _fmt(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]

func _draw_info(r: Rect2, row: Dictionary) -> void:
	UIKit.panel_box(self, r, Color(0.03, 0.05, 0.09, 0.92), Color(DB.C_GFP.r, DB.C_GFP.g, DB.C_GFP.b, 0.4))
	var x := r.position.x + 24.0
	var w := r.size.x - 48.0
	var y := r.position.y + 44.0
	var id := String(row["id"])
	var head := ""
	var body := ""
	match id:
		"zone":
			head = String(DB.ZONES[zone]["name"])
			body = String(DB.ZONES[zone]["desc"])
		"difficulty":
			head = String(DB.DIFFICULTY[difficulty]["name"])
			body = String(DB.DIFFICULTY[difficulty]["desc"])
		_:
			head = String(DB.MODES[mode]["name"])
			body = String(DB.MODES[mode]["desc"])
	UIKit.text(self, Vector2(x, y), head, 22, DB.C_TEXT, true)
	y = wrap_text(Vector2(x, y + 32.0), body, w, 16, DB.C_TEXT_DIM) + 6.0
	if mode == "daily":
		var d := DB.daily_for(DB.today_key())
		y += 6.0
		UIKit.text(self, Vector2(x, y), "오늘의 실험 조건  (%s)" % DB.today_key(), 17, DB.C_WARN, true)
		y += 28.0
		var b: Dictionary = d["buff"]
		var db: Dictionary = d["debuff"]
		UIKit.text(self, Vector2(x, y), "▲ " + String(b["name"]), 17, DB.C_GFP, true)
		y = wrap_text(Vector2(x + 18, y + 22.0), DB.mod_text(b), w - 18, 15, DB.C_GFP) + 4.0
		UIKit.text(self, Vector2(x, y), "▼ " + String(db["name"]), 17, DB.C_ENEMY, true)
		y = wrap_text(Vector2(x + 18, y + 22.0), DB.mod_text(db), w - 18, 15, DB.C_ENEMY) + 4.0
	# 기록
	var by := r.end.y - 92.0
	r = Rect2(x - 8, by - 26, w + 16, 1)
	draw_rect(r, Color(1, 1, 1, 0.12))
	UIKit.text(self, Vector2(x, by), "기록", 16, DB.C_TEXT, true)
	var best := float(Save.data["best_time"])
	var line1 := "정규 최고 생존  %s   ·   클리어 %d회" % [_fmt(best), int(Save.data["clears"])]
	var line2 := "야근 최장  %s" % _fmt(float(Save.data["best_endless"]))
	var ds := float((Save.data["daily"] as Dictionary).get(DB.today_key(), 0.0))
	if ds > 0.0:
		line2 += "   ·   오늘의 조건  %s" % ("클리어!" if ds >= 1000.0 else _fmt(ds))
	UIKit.text(self, Vector2(x, by + 24), line1, 15, DB.C_TEXT_DIM)
	UIKit.text(self, Vector2(x, by + 46), line2, 15, DB.C_TEXT_DIM)
