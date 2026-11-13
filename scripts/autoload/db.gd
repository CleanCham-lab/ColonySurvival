extends Node
## ─────────────────────────────────────────────────────────────
##  Colony Survival — 밸런스 데이터 테이블
##  게임 수치는 전부 여기 있습니다. 숫자만 고치면 게임이 바뀝니다.
##  (파이썬 dict와 거의 같은 문법)
## ─────────────────────────────────────────────────────────────

# ── 형광 팔레트: 색 = 게임 의미 ───────────────────────────────
# 파랑/시안(DAPI·Hoechst) = 나와 아군 / 초록(GFP) = 주울 것 / 빨강(mCherry·PI) = 피할 것 / 노랑(YFP) = 경고·엘리트
# 아래 7개는 색 모드(기본 / 색각 보정)에 따라 바뀐다 → apply_palette()
var C_PLAYER := Color(0.36, 0.72, 1.0)
var C_PLAYER_CORE := Color(0.55, 0.45, 1.0)
var C_ALLY := Color(0.35, 0.92, 1.0)
var C_GFP := Color(0.35, 1.0, 0.45)
var C_ENEMY := Color(1.0, 0.26, 0.36)
var C_ENEMY_MAG := Color(1.0, 0.25, 0.78)
var C_ENEMY_ORANGE := Color(1.0, 0.52, 0.22)
var C_WARN := Color(1.0, 0.88, 0.25)
var palette := "default"
const C_BG := Color(0.02, 0.024, 0.04)
const C_GRID := Color(0.30, 0.42, 0.62)
const C_TEXT := Color(0.92, 0.94, 1.0)
const C_TEXT_DIM := Color(0.62, 0.68, 0.80)

# ── 런 전체 ────────────────────────────────────────────────────
const RUN_LENGTH := 900.0          # 15분 (실제 1분 = 게임 1시간, 18:00 → 09:00)
const CLOCK_START_HOUR := 18
const DISH_RADIUS := 2400.0        # 배양접시 반지름(px)
const MAX_WEAPONS := 5
const MAX_PASSIVES := 5
const WEAPON_MAX_LEVEL := 8
const BASE_MAGNET := 95.0
const PLAYER_RADIUS := 15.0
const INVULN_TIME := 0.5
const BASE_REROLLS := 1

# ── 캐릭터 (셀라인) ───────────────────────────────────────────
const CHARACTERS := {
	"hek293t": {
		"name": "HEK293T",
		"tagline": "표준형 · 형질주입이 잘 되는 세포",
		"start_weapon": "qpcr_beam",
		"perk": "transfection",
		"perk_name": "형질주입 효율",
		"perk_text": "새로 얻는 무기는 Lv2로 시작",
		"max_hp": 100, "speed": 230.0,
		"color": Color(0.36, 0.78, 1.0), "core": Color(0.55, 0.45, 1.0),
		"hat": "santa", "shape": "round",
		"unlock": "",
	},
	"hela": {
		"name": "HeLa",
		"tagline": "튼튼함 · 죽지 않는 세포",
		"start_weapon": "gel_cutter",
		"perk": "immortal",
		"perk_name": "불멸화",
		"perk_text": "런당 1회, HP 50%로 부활",
		"max_hp": 130, "speed": 210.0,
		"color": Color(0.58, 0.48, 1.0), "core": Color(0.35, 0.55, 1.0),
		"hat": "antlers", "shape": "spread",
		"unlock": "",
	},
	"raw264": {
		"name": "RAW 264.7",
		"tagline": "근접형 · 잡아먹는 대식세포",
		"start_weapon": "lysozyme_field",
		"perk": "phagocytosis",
		"perk_name": "포식",
		"perk_text": "적 10마리 처치마다 HP 1 회복",
		"max_hp": 120, "speed": 220.0,
		"color": Color(0.30, 0.95, 0.85), "core": Color(0.30, 0.60, 1.0),
		"hat": "elf", "shape": "amoeba",
		"unlock": "first_clear",
	},
}
const CHARACTER_ORDER := ["hek293t", "hela", "raw264"]

# ── 무기 10종 ────────────────────────────────────────────────
# base: Lv1 수치. levels: Lv2~Lv8에서 더해지는 값(…_mult 키는 곱함).
# 공통 키: damage, cooldown, count, pierce, speed, area, duration, knockback
const WEAPONS := {
	"qpcr_beam": {
		"name": "qPCR Beam", "short": "qP", "color": Color(0.35, 0.95, 1.0),
		"desc": "가장 가까운 적 방향으로 관통 빔을 쏜다.",
		"base": {"damage": 12.0, "cooldown": 0.85, "count": 1, "pierce": 2, "speed": 950.0, "area": 1.0, "duration": 0.9},
		"levels": [
			{"text": "빔 +1", "count": 1},
			{"text": "피해 +5", "damage": 5.0},
			{"text": "관통 +2", "pierce": 2},
			{"text": "빔 +1", "count": 1},
			{"text": "쿨다운 -20%", "cooldown_mult": 0.8},
			{"text": "피해 +8", "damage": 8.0},
			{"text": "빔 +1, 관통 +2", "count": 1, "pierce": 2},
		],
		"evolve_with": "dmso", "evolved_name": "Real-time Thermocycler",
		"evolved_desc": "끊기지 않는 회전 빔이 사방을 쓸어낸다.",
	},
	"gel_cutter": {
		"name": "Gel Cutter", "short": "Gl", "color": Color(0.45, 0.85, 1.0),
		"desc": "바라보는 방향으로 넓게 베어낸다.",
		"base": {"damage": 14.0, "cooldown": 1.2, "count": 1, "area": 1.0, "duration": 0.18},
		"levels": [
			{"text": "양방향 베기", "count": 1},
			{"text": "피해 +6", "damage": 6.0},
			{"text": "범위 +15%", "area": 0.15},
			{"text": "쿨다운 -15%", "cooldown_mult": 0.85},
			{"text": "피해 +8", "damage": 8.0},
			{"text": "범위 +20%", "area": 0.2},
			{"text": "피해 +10, 쿨다운 -10%", "damage": 10.0, "cooldown_mult": 0.9},
		],
	},
	"crispr_lance": {
		"name": "CRISPR Lance", "short": "CR", "color": Color(0.62, 0.55, 1.0),
		"desc": "HP가 가장 높은 적을 노리는 고위력 창.",
		"base": {"damage": 34.0, "cooldown": 1.6, "count": 1, "pierce": 0, "speed": 1150.0, "area": 1.0, "duration": 1.0},
		"levels": [
			{"text": "피해 +15", "damage": 15.0},
			{"text": "관통 +1", "pierce": 1},
			{"text": "쿨다운 -15%", "cooldown_mult": 0.85},
			{"text": "창 +1", "count": 1},
			{"text": "피해 +20", "damage": 20.0},
			{"text": "관통 +2", "pierce": 2},
			{"text": "피해 +30", "damage": 30.0},
		],
		"evolve_with": "penstrep", "evolved_name": "Prime Editor",
		"evolved_desc": "HP 15% 이하 일반 적은 즉사, 보스·엘리트에게 피해 +50%.",
	},
	"lentiviral_orb": {
		"name": "Lentiviral Orb", "short": "Lv", "color": Color(0.30, 0.85, 0.95),
		"desc": "느린 유도탄. 맞은 적을 감염시키고, 감염된 적이 죽으면 주변으로 번진다.",
		"base": {"damage": 8.0, "cooldown": 1.8, "count": 1, "pierce": 2, "speed": 260.0, "area": 1.0, "duration": 4.0, "dot": 6.0, "spread": 2},
		"levels": [
			{"text": "전파 +1", "spread": 1},
			{"text": "감염 피해 +4/초", "dot": 4.0},
			{"text": "구슬 +1", "count": 1},
			{"text": "감염 지속 +2초", "duration": 2.0},
			{"text": "전파 +2", "spread": 2},
			{"text": "쿨다운 -20%", "cooldown_mult": 0.8},
			{"text": "감염 피해 +8/초", "dot": 8.0},
		],
		"evolve_with": "lipofectamine", "evolved_name": "Pandemic Vector",
		"evolved_desc": "감염이 끝없이 번진다.",
	},
	"nanopore_ring": {
		"name": "Nanopore Ring", "short": "Np", "color": Color(0.40, 0.65, 1.0),
		"desc": "몸 주위를 도는 나노포어 기공.",
		"base": {"damage": 9.0, "cooldown": 2.0, "count": 2, "area": 1.0, "duration": 3.5, "speed": 3.0},
		"levels": [
			{"text": "기공 +1", "count": 1},
			{"text": "반경 +20%", "area": 0.2},
			{"text": "피해 +5", "damage": 5.0},
			{"text": "기공 +1", "count": 1},
			{"text": "지속 +1초", "duration": 1.0},
			{"text": "회전 속도 +30%", "speed_mult": 1.3},
			{"text": "기공 +1, 피해 +5", "count": 1, "damage": 5.0},
		],
	},
	"lysozyme_field": {
		"name": "Lysozyme Field", "short": "Ly", "color": Color(0.35, 0.75, 1.0),
		"desc": "주변의 균을 계속 녹이는 효소 장.",
		"base": {"damage": 4.0, "cooldown": 0.5, "area": 1.0, "knockback": 30.0},
		"levels": [
			{"text": "반경 +20%", "area": 0.2},
			{"text": "피해 +2", "damage": 2.0},
			{"text": "반경 +20%", "area": 0.2},
			{"text": "틱 간격 -15%", "cooldown_mult": 0.85},
			{"text": "피해 +3", "damage": 3.0},
			{"text": "반경 +20%", "area": 0.2},
			{"text": "피해 +4", "damage": 4.0},
		],
	},
	"etoh_splash": {
		"name": "70% EtOH Splash", "short": "Et", "color": Color(0.55, 0.85, 1.0),
		"desc": "근처 적 위치에 에탄올을 뿌려 장판을 깐다.",
		"base": {"damage": 5.0, "cooldown": 3.0, "count": 1, "area": 1.0, "duration": 2.5},
		"levels": [
			{"text": "장판 +1", "count": 1},
			{"text": "피해 +3", "damage": 3.0},
			{"text": "범위 +20%", "area": 0.2},
			{"text": "지속 +1초", "duration": 1.0},
			{"text": "장판 +1", "count": 1},
			{"text": "피해 +4", "damage": 4.0},
			{"text": "범위 +25%, 쿨다운 -15%", "area": 0.25, "cooldown_mult": 0.85},
		],
	},
	"uv_flash": {
		"name": "UV Flash", "short": "UV", "color": Color(0.70, 0.48, 1.0),
		"desc": "화면 안 무작위 적에게 자외선 섬광을 내리꽂는다.",
		"base": {"damage": 18.0, "cooldown": 2.2, "count": 2, "area": 1.0},
		"levels": [
			{"text": "타격 +1", "count": 1},
			{"text": "피해 +8", "damage": 8.0},
			{"text": "범위 +25%", "area": 0.25},
			{"text": "타격 +1", "count": 1},
			{"text": "쿨다운 -15%", "cooldown_mult": 0.85},
			{"text": "피해 +10", "damage": 10.0},
			{"text": "타격 +2", "count": 2},
		],
	},
	"antibody_chain": {
		"name": "Antibody Chain", "short": "Ab", "color": Color(0.45, 0.80, 1.0),
		"desc": "적 사이를 튕기며 연쇄로 붙는 항체.",
		"base": {"damage": 9.0, "cooldown": 1.3, "count": 1, "speed": 820.0, "bounces": 3, "area": 1.0},
		"levels": [
			{"text": "튕김 +2", "bounces": 2},
			{"text": "피해 +4", "damage": 4.0},
			{"text": "쿨다운 -15%", "cooldown_mult": 0.85},
			{"text": "튕김 +2", "bounces": 2},
			{"text": "발사 +1", "count": 1},
			{"text": "피해 +6", "damage": 6.0},
			{"text": "튕김 +3", "bounces": 3},
		],
	},
	"centrifuge_wave": {
		"name": "Centrifuge Wave", "short": "Cf", "color": Color(0.50, 0.70, 1.0),
		"desc": "주기적으로 원형 충격파를 내보내 적을 밀어낸다.",
		"base": {"damage": 12.0, "cooldown": 3.5, "count": 1, "area": 1.0, "knockback": 260.0},
		"levels": [
			{"text": "피해 +6", "damage": 6.0},
			{"text": "반경 +20%", "area": 0.2},
			{"text": "넉백 +40%", "knockback_mult": 1.4},
			{"text": "쿨다운 -20%", "cooldown_mult": 0.8},
			{"text": "피해 +8", "damage": 8.0},
			{"text": "반경 +25%", "area": 0.25},
			{"text": "충격파 2연속", "count": 1},
		],
		"evolve_with": "matrigel", "evolved_name": "Ultracentrifuge",
		"evolved_desc": "적을 끌어당긴 뒤 두 배의 충격파로 터뜨린다.",
	},
}
const WEAPON_ORDER := ["qpcr_beam", "gel_cutter", "crispr_lance", "lentiviral_orb", "nanopore_ring",
	"lysozyme_field", "etoh_splash", "uv_flash", "antibody_chain", "centrifuge_wave"]

# ── 패시브(시약) 8종 ─────────────────────────────────────────
const PASSIVES := {
	"fbs":           {"name": "FBS",           "short": "FB", "stat": "max_hp",   "per": 20.0, "text": "최대 HP +20"},
	"penstrep":      {"name": "Pen-Strep",     "short": "PS", "stat": "damage",   "per": 0.10, "text": "피해 +10%"},
	"trypsin":       {"name": "Trypsin",       "short": "Tr", "stat": "cooldown", "per": 0.08, "text": "쿨다운 -8%"},
	"agarose":       {"name": "Agarose",       "short": "Ag", "stat": "area",     "per": 0.10, "text": "공격 범위 +10%"},
	"dmso":          {"name": "DMSO",          "short": "DM", "stat": "duration", "per": 0.10, "text": "효과 지속시간 +10%"},
	"matrigel":      {"name": "Matrigel",      "short": "Mg", "stat": "armor",    "per": 1.0,  "text": "받는 피해 -1"},
	"egf":           {"name": "EGF",           "short": "EG", "stat": "speed",    "per": 0.08, "text": "이동속도 +8%"},
	"lipofectamine": {"name": "Lipofectamine", "short": "Lf", "stat": "magnet",   "per": 0.25, "text": "ATP 획득 반경 +25%"},
}
const PASSIVE_ORDER := ["fbs", "penstrep", "trypsin", "agarose", "dmso", "matrigel", "egf", "lipofectamine"]
const PASSIVE_MAX_LEVEL := 5

# ── 적 ───────────────────────────────────────────────────────
# behavior: chase / dash / turret / static
const ENEMIES := {
	"mycoplasma": {"name": "Mycoplasma", "hp": 4.0,   "speed": 175.0, "damage": 5.0,  "radius": 7.0,  "xp": 1, "behavior": "chase",  "shape": "dot",   "color": Color(1.0, 0.30, 0.42)},
	"ecoli":      {"name": "E. coli",    "hp": 12.0,  "speed": 95.0,  "damage": 8.0,  "radius": 13.0, "xp": 1, "behavior": "chase",  "shape": "rod",   "color": Color(1.0, 0.24, 0.32)},
	"yeast":      {"name": "Yeast",      "hp": 26.0,  "speed": 75.0,  "damage": 10.0, "radius": 16.0, "xp": 2, "behavior": "chase",  "shape": "yeast", "color": Color(1.0, 0.52, 0.22), "split": "yeast_bud", "split_count": 2},
	"yeast_bud":  {"name": "Yeast bud",  "hp": 8.0,   "speed": 110.0, "damage": 6.0,  "radius": 9.0,  "xp": 1, "behavior": "chase",  "shape": "yeast", "color": Color(1.0, 0.58, 0.28)},
	"phage":      {"name": "Phage T4",   "hp": 30.0,  "speed": 80.0,  "damage": 14.0, "radius": 15.0, "xp": 3, "behavior": "dash",   "shape": "phage", "color": Color(1.0, 0.25, 0.78)},
	"spore_pod":  {"name": "Aspergillus", "hp": 45.0, "speed": 35.0,  "damage": 10.0, "radius": 18.0, "xp": 3, "behavior": "turret", "shape": "pod",   "color": Color(1.0, 0.62, 0.25)},
	"biofilm":    {"name": "Biofilm",    "hp": 160.0, "speed": 45.0,  "damage": 18.0, "radius": 30.0, "xp": 6, "behavior": "chase",  "shape": "blob",  "color": Color(0.95, 0.16, 0.30), "armor_mult": 0.7},
	"tipbox":     {"name": "Tip box",    "hp": 20.0,  "speed": 0.0,   "damage": 0.0,  "radius": 16.0, "xp": 0, "behavior": "static", "shape": "tipbox", "color": Color(0.55, 0.75, 1.0)},
}
const ELITE_HP_MULT := 5.0
const ELITE_SCALE := 1.5

# ── 보스 ─────────────────────────────────────────────────────
const BOSSES := {
	"mold_wreath": {"name": "Mold Wreath", "title": "곰팡이 화환", "hp": 5500.0, "radius": 64.0, "damage": 20.0, "speed": 45.0},
	"krampus_proto": {"name": "Krampus Phage", "title": "뿔 달린 크람푸스 파지", "hp": 11000.0, "radius": 40.0, "damage": 24.0, "speed": 95.0},
	"reviewer2": {"name": "Reviewer #2", "title": "최종 심사위원", "hp": 17000.0, "radius": 58.0, "damage": 26.0, "speed": 70.0},
}

# ── 웨이브 (분 단위) ─────────────────────────────────────────
# interval: 스폰 간격(초), batch: 한 번에 스폰 수, max: 동시 최대, pool: 가중치
const WAVES := [
	{"interval": 1.00, "batch": 2, "max": 40,  "pool": {"ecoli": 3, "mycoplasma": 2}},
	{"interval": 0.80, "batch": 3, "max": 70,  "pool": {"ecoli": 3, "mycoplasma": 3}},
	{"interval": 0.70, "batch": 3, "max": 90,  "pool": {"ecoli": 3, "mycoplasma": 4}},
	{"interval": 0.70, "batch": 4, "max": 110, "pool": {"ecoli": 3, "mycoplasma": 3, "yeast": 2}},
	{"interval": 0.60, "batch": 4, "max": 130, "pool": {"ecoli": 3, "mycoplasma": 4, "yeast": 2}},
	{"interval": 0.90, "batch": 3, "max": 80,  "pool": {"ecoli": 2, "mycoplasma": 3, "phage": 1}},
	{"interval": 0.55, "batch": 4, "max": 150, "pool": {"ecoli": 3, "mycoplasma": 3, "yeast": 2, "phage": 2}},
	{"interval": 0.50, "batch": 5, "max": 170, "pool": {"ecoli": 2, "yeast": 3, "phage": 2, "spore_pod": 1}},
	{"interval": 0.50, "batch": 5, "max": 190, "pool": {"ecoli": 2, "mycoplasma": 3, "yeast": 3, "phage": 2, "spore_pod": 1}},
	{"interval": 0.45, "batch": 5, "max": 210, "pool": {"ecoli": 2, "yeast": 2, "phage": 2, "spore_pod": 1, "biofilm": 1}},
	{"interval": 0.70, "batch": 4, "max": 140, "pool": {"ecoli": 3, "mycoplasma": 3, "yeast": 2}},
	{"interval": 0.40, "batch": 6, "max": 240, "pool": {"mycoplasma": 4, "yeast": 2, "phage": 3, "spore_pod": 1, "biofilm": 1}},
	{"interval": 0.40, "batch": 6, "max": 260, "pool": {"ecoli": 2, "mycoplasma": 3, "phage": 4, "spore_pod": 1, "biofilm": 1}},
	{"interval": 0.35, "batch": 7, "max": 280, "pool": {"ecoli": 2, "mycoplasma": 3, "yeast": 2, "phage": 3, "spore_pod": 2, "biofilm": 2}},
	{"interval": 0.30, "batch": 8, "max": 300, "pool": {"ecoli": 3, "mycoplasma": 3, "yeast": 2, "phage": 3, "spore_pod": 2, "biofilm": 2}},
]
const HP_SCALE_PER_MIN := 0.15
const DMG_SCALE_PER_MIN := 0.05

# 시간 이벤트(초)
const EVENTS := [
	{"t": 180.0, "type": "elite", "kind": "yeast", "toast": "엘리트 효모 출현 — 선물상자를 떨어뜨린다"},
	{"t": 240.0, "type": "ring", "kind": "mycoplasma", "count": 36, "toast": "마이코플라즈마 포위!"},
	{"t": 300.0, "type": "boss", "kind": "mold_wreath", "toast": "23:00 — Mold Wreath가 자라났다"},
	{"t": 480.0, "type": "burst", "kind": "yeast", "count": 24, "toast": "효모 대증식"},
	{"t": 485.0, "type": "elite", "kind": "yeast", "toast": ""},
	{"t": 600.0, "type": "boss", "kind": "krampus_proto", "toast": "04:00 — Krampus Phage가 착지했다"},
	{"t": 720.0, "type": "burst", "kind": "phage", "count": 18, "toast": "파지 떼 습격"},
	{"t": 780.0, "type": "elite", "kind": "biofilm", "toast": "엘리트 바이오필름 출현"},
	{"t": 900.0, "type": "boss", "kind": "reviewer2", "toast": "12/25 09:00 — 랩미팅 대신 심사평이 도착했다"},
]
# 야근 모드: 15분 이후 5분마다 보스가 강해져 돌아온다
const ENDLESS_BOSS_CYCLE := ["mold_wreath", "krampus_proto", "reviewer2"]

# ── 색 모드 ──────────────────────────────────────────────────
# default : 형광 기본 (GFP 초록 = 주울 것, mCherry 빨강 = 적)
# cvd     : 색각 보정 (Okabe-Ito 계열) — 파랑 = 나, 노랑 = 주울 것, 주황 = 적, 흰색 = 경고
const PALETTES := {
	"default": {"name": "형광 기본 (GFP / mCherry)", "ally": Color(0.35, 0.92, 1.0), "pickup": Color(0.35, 1.0, 0.45),
		"enemy": Color(1.0, 0.26, 0.36), "enemy2": Color(1.0, 0.25, 0.78), "enemy3": Color(1.0, 0.52, 0.22), "warn": Color(1.0, 0.88, 0.25)},
	"cvd": {"name": "색각 보정 (파랑 / 노랑 / 주황)", "ally": Color(0.40, 0.78, 1.0), "pickup": Color(1.0, 0.90, 0.30),
		"enemy": Color(0.98, 0.45, 0.12), "enemy2": Color(0.90, 0.35, 0.20), "enemy3": Color(1.0, 0.62, 0.30), "warn": Color(1.0, 1.0, 1.0)},
}
const PALETTE_ORDER := ["default", "cvd"]
# 적 종류별로 쓸 색 슬롯(enemy / enemy2 / enemy3)과 밝기
const ENEMY_TINT := {"mycoplasma": ["enemy", 1.05], "ecoli": ["enemy", 1.0], "yeast": ["enemy3", 1.0], "yeast_bud": ["enemy3", 1.08],
	"phage": ["enemy2", 1.0], "spore_pod": ["enemy3", 1.05], "biofilm": ["enemy", 0.9]}

func apply_palette(mode: String) -> void:
	if not PALETTES.has(mode):
		mode = "default"
	palette = mode
	var p: Dictionary = PALETTES[mode]
	C_ALLY = p["ally"]
	C_GFP = p["pickup"]
	C_ENEMY = p["enemy"]
	C_ENEMY_MAG = p["enemy2"]
	C_ENEMY_ORANGE = p["enemy3"]
	C_WARN = p["warn"]

func enemy_color(kind: String) -> Color:
	if kind == "tipbox":
		return (ENEMIES[kind] as Dictionary)["color"]
	if palette == "default":
		return (ENEMIES[kind] as Dictionary)["color"]
	var tint: Array = ENEMY_TINT.get(kind, ["enemy", 1.0])
	var c: Color = (PALETTES[palette] as Dictionary)[tint[0]]
	return Color(minf(1.0, c.r * float(tint[1])), minf(1.0, c.g * float(tint[1])), minf(1.0, c.b * float(tint[1])))

# ── 난이도 ───────────────────────────────────────────────────
const DIFFICULTY := {
	"easy":   {"name": "학부연구생", "desc": "적 HP -25%, 적 피해 -40%, 연구비 ×0.7", "enemy_hp": 0.75, "enemy_dmg": 0.6, "spawn": 0.85, "boss_hp": 0.75, "grant": 0.7},
	"normal": {"name": "대학원생",   "desc": "기본 난이도", "enemy_hp": 1.0, "enemy_dmg": 1.0, "spawn": 1.0, "boss_hp": 1.0, "grant": 1.0},
	"hard":   {"name": "리뷰어 모드", "desc": "적 HP +35%, 적 피해 +40%, 스폰 +20%, 연구비 ×1.5", "enemy_hp": 1.35, "enemy_dmg": 1.4, "spawn": 1.2, "boss_hp": 1.3, "grant": 1.5},
}
const DIFFICULTY_ORDER := ["easy", "normal", "hard"]

# ── 게임 모드 ────────────────────────────────────────────────
const MODES := {
	"normal": {"name": "정규 실험", "desc": "아침 9시까지 버티고 최종 보스 Reviewer #2를 쓰러뜨려라."},
	"endless": {"name": "야근 모드", "desc": "끝이 없다. 보스가 5분마다 더 강해져 돌아온다. 얼마나 버티나?"},
	"daily": {"name": "오늘의 실험 조건", "desc": "날짜마다 바뀌는 버프 1개 + 디버프 1개. 정규 실험 규칙."},
}
const MODE_ORDER := ["normal", "endless", "daily"]

# ── 구역 ─────────────────────────────────────────────────────
const ZONES := {
	"dish": {"name": "배양접시", "desc": "혈구계산판 격자 위의 넓은 원형 접시."},
	"hood": {"name": "클린벤치", "desc": "층류가 계속 아래로 밀어내고, UV 램프가 주기적으로 작업대를 쓸고 지나간다(적도 맞는다)."},
}
const ZONE_ORDER := ["dish", "hood"]
const HOOD_SIZE := Vector2(4600.0, 2800.0)
const HOOD_AIRFLOW := Vector2(0.0, 42.0)

# ── 연구실 상점(영구 강화, 연구비로 구매) ─────────────────────
const SHOP := {
	"culture":  {"name": "배양 조건 최적화", "text": "최대 HP +10", "max": 5, "costs": [30, 60, 100, 150, 220]},
	"reagent":  {"name": "고순도 시약", "text": "피해 +5%", "max": 5, "costs": [40, 80, 130, 190, 260]},
	"pipette":  {"name": "자동 피펫", "text": "쿨다운 -3%", "max": 5, "costs": [40, 80, 130, 190, 260]},
	"shoes":    {"name": "랩 슬리퍼", "text": "이동속도 +4%", "max": 3, "costs": [35, 80, 140]},
	"magnet":   {"name": "넓은 시야", "text": "ATP 획득 반경 +10%", "max": 3, "costs": [25, 60, 110]},
	"growth":   {"name": "효율적 대사", "text": "ATP(경험치) +8%", "max": 5, "costs": [40, 80, 130, 190, 260]},
	"notebook": {"name": "연구 노트", "text": "레벨업 다시 뽑기 +1", "max": 3, "costs": [50, 120, 220]},
	"backup":   {"name": "백업 스톡(-80℃)", "text": "런당 부활 +1 (HP 50%)", "max": 1, "costs": [400]},
	"grant":    {"name": "연구비 협상", "text": "연구비 획득 +10%", "max": 3, "costs": [60, 140, 260]},
	"raw264":   {"name": "RAW 264.7 분양", "text": "대식세포 셀라인 해금", "max": 1, "costs": [300]},
}
const SHOP_ORDER := ["culture", "reagent", "pipette", "shoes", "magnet", "growth", "notebook", "backup", "grant", "raw264"]

# ── 오늘의 실험 조건: 알파 버전 버프/디버프 재활용 ────────────
# 키: hp_mult, hp_add, damage, cooldown, speed, magnet, area, duration, proj_speed, pierce, xp,
#     enemy_hp, enemy_speed, spawn_extra, weapon_slots   (배율은 1.0 기준)
const DAILY_BUFFS := [
	{"name": "과카페인 상태", "speed": 1.20, "cooldown": 0.90},
	{"name": "집중 모드", "damage": 1.20},
	{"name": "두꺼운 장갑", "hp_mult": 1.30},
	{"name": "랩 본능", "magnet": 1.40},
	{"name": "정교한 손놀림", "cooldown": 0.85},
	{"name": "초정밀 피펫", "proj_speed": 1.25},
	{"name": "오버클럭 PCR", "damage": 1.15, "area": 1.20},
	{"name": "고요한 발걸음", "speed": 1.10},
	{"name": "철의 위장", "hp_add": 20},
	{"name": "행운의 팁 박스", "xp": 1.25},
	{"name": "젤 마스터", "pierce": 1, "proj_speed": 1.10},
	{"name": "유세포 분석 전문가", "damage": 1.10, "duration": 1.15},
	{"name": "나노 정밀도", "area": 1.30},
	{"name": "멸균의 손", "magnet": 1.20, "xp": 1.10},
	{"name": "콜드룸 단련", "hp_mult": 1.10, "speed": 1.05},
	{"name": "바이오해저드 베테랑", "damage": 1.15, "hp_add": 10},
	{"name": "Q10 플로우", "cooldown": 0.88, "proj_speed": 1.08},
	{"name": "통계 장인", "xp": 1.15},
	{"name": "예비 발전기", "hp_add": 25},
	{"name": "완전한 집중", "damage": 1.25, "cooldown": 1.05},
	{"name": "점착성 신발", "speed": 0.95, "magnet": 1.50},
	{"name": "빠른 발놀림", "speed": 1.25},
	{"name": "심호흡", "hp_mult": 1.15},
	{"name": "선명한 광학계", "proj_speed": 1.15, "duration": 1.10},
	{"name": "멀티 채널 피펫", "pierce": 2},
	{"name": "플레이트 테트리스", "xp": 1.30},
	{"name": "젠 모드", "speed": 0.95, "damage": 1.20},
	{"name": "피펫 스나이퍼", "proj_speed": 1.30, "duration": 1.20},
]
const DAILY_DEBUFFS := [
	{"name": "깨지기 쉬운 유리기구", "hp_mult": 0.70},
	{"name": "무거운 피펫", "speed": 0.80},
	{"name": "무딘 팁", "damage": 0.85},
	{"name": "오염된 벤치", "enemy_hp": 1.20},
	{"name": "가득 찬 인큐베이터", "enemy_speed": 1.15},
	{"name": "시약 부족", "xp": 0.70},
	{"name": "절전 모드", "cooldown": 1.20},
	{"name": "학부 인턴의 도움(?)", "spawn_extra": 1},
	{"name": "카페인 금단", "speed": 0.90, "cooldown": 1.10},
	{"name": "상급자의 압박", "enemy_hp": 1.10, "xp": 0.90},
	{"name": "시끄러운 흄후드", "cooldown": 1.15},
	{"name": "냉동고 알람", "enemy_speed": 1.10},
	{"name": "산소 부족", "hp_mult": 0.80, "speed": 0.95},
	{"name": "잘못 붙인 라벨", "xp": 0.85, "enemy_hp": 1.10},
	{"name": "지연된 택배", "weapon_slots": -1},
	{"name": "실험실 격리", "spawn_extra": 1},
	{"name": "바이오해저드 경보", "enemy_hp": 1.15, "enemy_speed": 1.05},
	{"name": "예산 삭감", "xp": 0.75, "weapon_slots": -1},
	{"name": "고장난 칠러", "damage": 0.90, "enemy_hp": 1.10},
	{"name": "피펫 보정 불량", "damage": 0.90, "xp": 0.90},
	{"name": "멘탈 붕괴 직전", "hp_mult": 0.85, "speed": 0.95},
	{"name": "위험 회피 모드", "damage": 0.80},
	{"name": "포토블리칭", "proj_speed": 0.85},
	{"name": "안 좋은 세포주", "damage": 0.90, "enemy_hp": 1.05},
	{"name": "돌연변이 폭풍", "spawn_extra": 2},
	{"name": "젤 대참사", "xp": 0.80, "cooldown": 1.10},
	{"name": "난장판 벤치", "speed": 0.95, "cooldown": 1.05},
	{"name": "교대 직전", "enemy_speed": 1.05},
]
const MOD_LABELS := {"hp_mult": ["최대 HP", "%"], "hp_add": ["최대 HP", "+"], "damage": ["피해", "%"], "cooldown": ["쿨다운", "%"],
	"speed": ["이동속도", "%"], "magnet": ["획득 반경", "%"], "area": ["범위", "%"], "duration": ["지속시간", "%"],
	"proj_speed": ["탄속", "%"], "pierce": ["관통", "+"], "xp": ["ATP 획득", "%"], "enemy_hp": ["적 HP", "%"],
	"enemy_speed": ["적 속도", "%"], "spawn_extra": ["스폰마다 적", "+"], "weapon_slots": ["무기 슬롯", "+"]}

func mod_text(m: Dictionary) -> String:
	var parts: Array = []
	for k in m.keys():
		if k == "name" or not MOD_LABELS.has(k):
			continue
		var lab: Array = MOD_LABELS[k]
		var v := float(m[k])
		if String(lab[1]) == "%":
			parts.append("%s %+d%%" % [lab[0], int(round((v - 1.0) * 100.0))])
		else:
			parts.append("%s %+d" % [lab[0], int(v)])
	return ", ".join(PackedStringArray(parts))

## 날짜(YYYYMMDD)로 오늘의 버프/디버프를 고른다. 모든 컴퓨터에서 같은 날엔 같은 조건.
func daily_for(date_key: String) -> Dictionary:
	var h := absi(date_key.hash())
	return {"date": date_key, "buff": DAILY_BUFFS[h % DAILY_BUFFS.size()], "debuff": DAILY_DEBUFFS[(h / 7 + 3) % DAILY_DEBUFFS.size()]}

func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d%02d%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

# ── 경험치(ATP) ──────────────────────────────────────────────
func xp_to_next(level: int) -> int:
	var need := 5 * level
	if level >= 20:
		need += (level - 19) * 8
	return need

# ── 헬퍼 ─────────────────────────────────────────────────────
func wave_at(t: float) -> Dictionary:
	var idx := clampi(int(t / 60.0), 0, WAVES.size() - 1)
	return WAVES[idx]

func weapon_stats(id: String, level: int) -> Dictionary:
	var w: Dictionary = WEAPONS[id]
	var s: Dictionary = (w["base"] as Dictionary).duplicate()
	var lv: Array = w["levels"]
	for i in range(mini(level - 1, lv.size())):
		var up: Dictionary = lv[i]
		for k in up.keys():
			if k == "text":
				continue
			if String(k).ends_with("_mult"):
				var base_key := String(k).trim_suffix("_mult")
				s[base_key] = float(s.get(base_key, 1.0)) * float(up[k])
			else:
				s[k] = s.get(k, 0) + up[k]
	return s

func weapon_level_text(id: String, next_level: int) -> String:
	var lv: Array = WEAPONS[id]["levels"]
	var i := next_level - 2
	if i >= 0 and i < lv.size():
		return String((lv[i] as Dictionary)["text"])
	return ""

func game_clock_text(t: float) -> String:
	var total_min := int(t)  # 실제 1초 = 게임 1분
	var h := (CLOCK_START_HOUR + total_min / 60) % 24
	var m := total_min % 60
	var day := 24 + (CLOCK_START_HOUR + total_min / 60) / 24
	if day > 31:
		return "1/%d  %02d:%02d" % [day - 31, h, m]
	return "12/%d  %02d:%02d" % [day, h, m]

func passage_of(t: float) -> int:
	return clampi(int(t / 300.0) + 1, 1, 3)
