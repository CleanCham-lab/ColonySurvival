extends Node
## 메타 진행 저장: 연구비(Grant), 해금, 설정, 기록.
## user://save.json — macOS/Windows는 사용자 폴더, 웹은 브라우저 저장소에 저장됩니다.

const PATH := "user://save.json"

var data := {
	"grant": 0,
	"total_grant": 0,
	"runs": 0,
	"clears": 0,
	"best_time": 0.0,
	"best_kills": 0,
	"unlocked": {},
	"papers": {},
	"upgrades": {},
	"best_endless": 0.0,
	"daily": {},
	"last_setup": {"mode": "normal", "zone": "dish", "difficulty": "normal"},
	"settings": {
		"master": 0.8,
		"music": 0.55,
		"sfx": 0.8,
		"shake": true,
		"damage_numbers": true,
		"fullscreen": false,
		"color_mode": "default",
		"show_fps": false,
	},
}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)

func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if dst.has(k) and dst[k] is Dictionary and src[k] is Dictionary:
			_merge(dst[k], src[k])
		else:
			dst[k] = src[k]

func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % PATH)
		return
	f.store_string(JSON.stringify(data, "  "))

func setting(key: String) -> Variant:
	return (data["settings"] as Dictionary).get(key)

func set_setting(key: String, value: Variant) -> void:
	(data["settings"] as Dictionary)[key] = value
	save_data()

func is_unlocked(char_id: String) -> bool:
	var need: String = String((DB.CHARACTERS[char_id] as Dictionary).get("unlock", ""))
	if need == "":
		return true
	if upgrade(char_id) > 0:
		return true
	return bool((data["unlocked"] as Dictionary).get(char_id, false))

# ── 연구실 상점 ──────────────────────────────────────────────
func upgrade(id: String) -> int:
	return int((data["upgrades"] as Dictionary).get(id, 0))

func upgrade_cost(id: String) -> int:
	var u: Dictionary = DB.SHOP[id]
	var lv := upgrade(id)
	if lv >= int(u["max"]):
		return -1
	if DB.CHARACTERS.has(id) and is_unlocked(id):  # 클리어로 이미 해금된 셀라인
		return -1
	return int((u["costs"] as Array)[lv])

func buy(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or int(data["grant"]) < cost:
		return false
	data["grant"] = int(data["grant"]) - cost
	(data["upgrades"] as Dictionary)[id] = upgrade(id) + 1
	save_data()
	return true

## 런 결과를 기록하고 이번 런에서 받은 연구비를 돌려준다.
func record_run(result: Dictionary) -> int:
	var time_s: float = float(result.get("time", 0.0))
	var kills: int = int(result.get("kills", 0))
	var bosses: int = int(result.get("boss_kills", 0))
	var victory: bool = bool(result.get("victory", false))
	var grant := int(time_s / 10.0) + int(kills / 25.0) + bosses * 30
	if victory:
		grant = int(grant * 1.5)
	var diff: Dictionary = DB.DIFFICULTY.get(String(result.get("difficulty", "normal")), DB.DIFFICULTY["normal"])
	grant = int(grant * float(diff["grant"]) * (1.0 + 0.10 * upgrade("grant")))
	var mode := String(result.get("mode", "normal"))
	if mode == "endless":
		result["new_record"] = time_s > float(data["best_endless"])
		data["best_endless"] = maxf(float(data["best_endless"]), time_s)
	elif mode == "daily":
		var key := String(result.get("daily_key", ""))
		var prev := float((data["daily"] as Dictionary).get(key, 0.0))
		var score := time_s + (1000.0 if victory else 0.0)  # 클리어하면 생존 시간보다 우선
		result["new_record"] = score > prev
		(data["daily"] as Dictionary)[key] = maxf(prev, score)
	data["grant"] = int(data["grant"]) + grant
	data["total_grant"] = int(data["total_grant"]) + grant
	data["runs"] = int(data["runs"]) + 1
	if mode != "endless":
		data["best_time"] = maxf(float(data["best_time"]), minf(time_s, DB.RUN_LENGTH))
	data["best_kills"] = maxi(int(data["best_kills"]), kills)
	var newly: Array = []
	if victory:
		data["clears"] = int(data["clears"]) + 1
		for cid in DB.CHARACTER_ORDER:
			var c: Dictionary = DB.CHARACTERS[cid]
			if String(c.get("unlock", "")) == "first_clear" and not is_unlocked(cid):
				(data["unlocked"] as Dictionary)[cid] = true
				newly.append(cid)
	for p in result.get("papers", []):
		(data["papers"] as Dictionary)[p] = true
	result["newly_unlocked"] = newly
	save_data()
	return grant
