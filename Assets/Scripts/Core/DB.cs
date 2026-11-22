using System.Collections.Generic;
using UnityEngine;

namespace CS
{
    /// 밸런스 데이터 전부. 숫자만 고치면 게임이 바뀐다.
    public class CharDef { public string id, name, perk, perkText, ult, ultText, startWeapon; public int shape; public float hp, speed; public Color color; public bool hat; public string unlock = ""; }
    public class EnemyDef { public string id, name, behavior; public int shape; public float hp, speed, dmg, radius, body; public int xp; public Color color; public string split = ""; public int splitCount; public float armor = 1f;
        /// 구역 전용 적: baseId = 능력치·행동을 물려받은 원형, group = 도감 분류(0 오염균 1 PCR 2 숏리드 3 롱리드 4 서버 5 심사), child = 갈라져 나온 것(도감에 따로 싣지 않는다)
        public string baseId = ""; public int group; public bool child; public string Base => baseId != "" ? baseId : id;
        /// 공격 방식: shot = 포탑이 쏘는 방식(mortar 포물선 / stream 회전 연사 / noise 무작위 / orbit 맴도는 탄), move = 다가오는 방식(wobble 비틀 / zigzag),
        /// trait = 특성(slow 주변 감속 / pop 터지며 방울 / unravel 죽으면 조각 / revive 한 번 부활 / leak 웅덩이)
        public string shot = "", move = "", trait = ""; }
    public class BossDef { public string id, name, title; public float hp, radius, dmg, speed, softCap; public Color color;
        /// hp2 > 0 이면 체력을 다 깎았을 때 죽지 않고 2단계로 변신한다(체력 줄이 hp2로 다시 찬다)
        public float hp2; public string title2 = ""; }
    public class WeaponDef { public string id, name, desc, evolveWith = "", evolvedName = "", evolvedDesc = ""; public float block; public int bit; public Color color; public float[] dmg, cd; public float[] a, b; public string[] lv; }
    public class PassiveDef { public string id, name, text; }
    public class UpgradeDef { public string id, name, text; public int max, cost; }
    public class Wave { public float interval; public int batch, max; public (string, int)[] pool; }
    public class DiffDef { public string id, name, desc; public float hp, dmg, spawn, boss, grant, regen, invuln = 0.6f, tip = 1f; }
    public class ZoneDef { public string id, name, desc, boss, mech, music, clearText, variantOf, variantName; public string cast = "", swarmToast = "마이코플라스마 떼가 포위한다!"; public float tier = 1f; public int floor; public Vector2 size; public float length; public Color ambient; }

    public static class DB
    {
        public const int MaxWeapons = 5, MaxPassives = 5, WeaponMaxLevel = 8, PassiveMaxLevel = 5;
        public const float PlayerRadius = 16f, BaseMagnet = 110f, Invuln = 0.6f;
        public const float EliteHp = 6f, EliteScale = 1.5f;

        // 난이도
        public static readonly DiffDef[] Diffs =
        {
            new DiffDef { id = "easy", name = "쉬움 · 학부연구생", desc = "적이 적고 약하다. 받는 피해 -55%, 체력이 천천히 회복되고 코코아가 자주 나온다. 연구비 ×0.7", hp = 0.75f, dmg = 0.45f, spawn = 0.7f, boss = 0.7f, grant = 0.7f, regen = 0.25f, invuln = 0.9f, tip = 0.7f },
            new DiffDef { id = "normal", name = "보통 · 대학원생", desc = "기본 난이도", hp = 1f, dmg = 1f, spawn = 1f, boss = 1f, grant = 1f },
            new DiffDef { id = "hard", name = "어려움 · 리뷰어 모드", desc = "적이 많고 단단하다. 받는 피해 +35%. 연구비 ×1.5", hp = 1.25f, dmg = 1.3f, spawn = 1.25f, boss = 1.3f, grant = 1.5f },
        };

        // 형광 채널 색
        public static readonly Color Cyan = new Color(0.25f, 0.85f, 1f), Green = new Color(0.3f, 1f, 0.42f), Red = new Color(1f, 0.22f, 0.32f), Mag = new Color(1f, 0.2f, 0.75f),
            Orange = new Color(1f, 0.5f, 0.18f), Yellow = new Color(1f, 0.85f, 0.25f), Violet = new Color(0.62f, 0.45f, 1f), Teal = new Color(0.2f, 1f, 0.85f), White = new Color(0.92f, 0.95f, 1f);

        public static readonly CharDef[] Chars =
        {
            new CharDef { id = "hek293t", name = "HEK293T", shape = 0, hp = 100, speed = 230, color = Cyan, hat = true, startWeapon = "qpcr_beam",
                perk = "형질주입 효율", perkText = "새로 얻는 무기는 Lv2로 시작", ult = "형질주입 폭주", ultText = "6초 동안 모든 무기 쿨다운 -60%" },
            new CharDef { id = "hela", name = "HeLa", shape = 1, hp = 130, speed = 207, color = Violet, hat = true, startWeapon = "gel_cutter",
                perk = "불멸화", perkText = "런당 1회, HP 50%로 부활", ult = "무한 증식", ultText = "HP 35% 회복 + 4초 무적 + 충격파" },
            new CharDef { id = "raw264", name = "RAW 264.7", shape = 2, hp = 120, speed = 218, color = Teal, hat = true, startWeapon = "lysozyme_field", unlock = "zone1",
                perk = "포식", perkText = "적 10마리 처치마다 HP 1 회복", ult = "포식 폭발", ultText = "주변 적을 끌어당겨 큰 피해, 처치마다 회복" },
        };
        public static CharDef Char(string id) { foreach (var c in Chars) if (c.id == id) return c; return Chars[0]; }

        public static EnemyDef[] Enemies =
        {
            new EnemyDef { id = "mycoplasma", name = "Mycoplasma", shape = 10, hp = 6, speed = 112, dmg = 5, radius = 7, body = 0.42f, xp = 1, color = Red, behavior = "chase" },
            new EnemyDef { id = "ecoli", name = "E. coli", shape = 11, hp = 14, speed = 78, dmg = 8, radius = 12, body = 0.46f, xp = 1, color = Red, behavior = "chase" },
            new EnemyDef { id = "yeast", name = "Yeast", shape = 12, hp = 34, speed = 60, dmg = 10, radius = 16, body = 0.52f, xp = 3, color = Orange, behavior = "chase", split = "yeast_bud", splitCount = 2 },
            new EnemyDef { id = "yeast_bud", child = true, name = "Yeast bud", shape = 12, hp = 10, speed = 92, dmg = 6, radius = 9, body = 0.52f, xp = 1, color = Orange, behavior = "chase" },
            new EnemyDef { id = "phage", name = "Phage T4", shape = 13, hp = 28, speed = 70, dmg = 14, radius = 14, body = 0.50f, xp = 4, color = Mag, behavior = "dash" },
            new EnemyDef { id = "spore_pod", name = "Aspergillus", shape = 14, hp = 70, speed = 26, dmg = 10, radius = 20, body = 0.60f, xp = 6, color = Yellow, behavior = "turret" },
            new EnemyDef { id = "biofilm", name = "Biofilm", shape = 15, hp = 230, speed = 36, dmg = 16, radius = 32, body = 0.66f, xp = 12, color = new Color(0.95f, 0.12f, 0.28f), behavior = "chase", armor = 0.7f },
            new EnemyDef { id = "tipbox", name = "Tip box", shape = 16, hp = 22, speed = 0, dmg = 0, radius = 17, body = 0.66f, xp = 0, color = new Color(0.55f, 0.78f, 1f), behavior = "static" },
        };
        // ── 구역 3~5 전용 적 ──
        // 배양접시·클린벤치의 오염균이 PCR실이나 서버실에 나오면 말이 안 되니, 방마다 그 방에서 생기는 것으로 바꾼다.
        // 능력치와 행동은 원형(오염균)과 같고 이름·모습·설명만 다르다 — 그래서 난이도는 그대로다.
        public static readonly Dictionary<string, string> CastMap = new Dictionary<string, string>();
        public static string Cast(ZoneDef z, string id) { return z != null && z.cast != "" && CastMap.TryGetValue(z.cast + ":" + id, out var v) ? v : id; }
        static void InitEnemies()
        {
            var list = new List<EnemyDef>(Enemies);
            EnemyDef B(string id) { foreach (var e in list) if (e.id == id) return e; return null; }
            void S(string cast, int group, string baseId, string id, string name, int shape, float body, string split = "", bool child = false, Color? color = null)
            {
                var b = B(baseId);
                list.Add(new EnemyDef { id = id, name = name, shape = shape, body = body, hp = b.hp, speed = b.speed, dmg = b.dmg, radius = b.radius, xp = b.xp, color = color ?? b.color, behavior = b.behavior, armor = b.armor,
                    split = split, splitCount = split != "" ? b.splitCount : 0, baseId = baseId, group = group, child = child });
                if (cast != "") CastMap[cast + ":" + baseId] = id;
            }
            // PCR실: 증폭이 잘못되어 생기는 것들
            S("pcr", 1, "mycoplasma", "primer_dimer", "Primer Dimer", 20, 0.45f);
            S("pcr", 1, "ecoli", "nonspecific", "Nonspecific Band", 21, 0.46f);
            S("pcr", 1, "yeast", "carryover", "Carryover Amplicon", 22, 0.52f, "ssdna");
            S("pcr", 1, "yeast_bud", "ssdna", "ssDNA", 23, 0.50f, "", true);
            S("pcr", 1, "phage", "aerosol", "Aerosol", 24, 0.50f);
            S("pcr", 1, "spore_pod", "ntc", "Contaminated NTC", 25, 0.60f);
            S("pcr", 1, "biofilm", "inhibitor", "PCR Inhibitor", 26, 0.66f);
            // 시퀀싱실 · 숏리드: 런에서 나오는 아티팩트
            S("sr", 2, "mycoplasma", "dup_read", "Duplicate Read", 27, 0.45f);
            S("sr", 2, "ecoli", "lowq_read", "Low-Q Read", 28, 0.46f);
            S("sr", 2, "yeast", "polyclonal", "Polyclonal Cluster", 29, 0.52f, "mixed_read");
            S("sr", 2, "yeast_bud", "mixed_read", "Mixed Read", 30, 0.50f, "", true);
            S("sr", 2, "phage", "index_hop", "Index Hopper", 31, 0.50f);
            S("sr", 2, "spore_pod", "polyg", "Poly-G Well", 32, 0.60f);
            S("sr", 2, "biofilm", "bubble", "Flow Cell Bubble", 33, 0.66f);
            // 시퀀싱실 · 롱리드
            S("lr", 3, "mycoplasma", "short_frag", "Short Fragment", 34, 0.45f);
            S("lr", 3, "ecoli", "fail_read", "Fail Read", 35, 0.48f);
            S("lr", 3, "yeast", "chimera", "Chimeric Read", 36, 0.52f, "read_frag");
            S("lr", 3, "yeast_bud", "read_frag", "Read Fragment", 37, 0.48f, "", true);
            S("lr", 3, "phage", "homopolymer", "Homopolymer", 38, 0.50f);
            S("lr", 3, "spore_pod", "blocked_pore", "Blocked Pore", 39, 0.60f);
            S("lr", 3, "biofilm", "tangle", "HMW Tangle", 40, 0.66f);
            // 분석 서버실: 파이프라인이 내는 오류
            S("srv", 4, "mycoplasma", "warning", "Warning", 41, 0.48f, "", false, new Color(1f, 0.62f, 0.10f));
            S("srv", 4, "ecoli", "bug", "Bug", 42, 0.48f);
            S("srv", 4, "yeast", "zombie", "Zombie Process", 43, 0.54f);
            S("srv", 4, "phage", "segfault", "Segfault", 45, 0.50f);
            S("srv", 4, "spore_pod", "inf_loop", "Infinite Loop", 46, 0.60f);
            S("srv", 4, "biofilm", "mem_leak", "Memory Leak", 47, 0.56f);
            // Reviewer가 불러내는 것들(구역과 상관없이 직접 소환한다)
            S("", 5, "phage", "co_reviewer", "Co-reviewer", 48, 0.56f);
            S("", 5, "mycoplasma", "comment", "Minor Comment", 49, 0.46f);
            // 방마다 공격 방식을 다르게: 같은 '돌진형·포탑형'이라도 하는 짓이 다르다
            void A(string id, string behavior = null, string shot = null, string move = null, string trait = null)
            { var e = B(id); if (behavior != null) e.behavior = behavior; if (shot != null) e.shot = shot; if (move != null) e.move = move; if (trait != null) e.trait = trait; }
            A("aerosol", behavior: "spray");          // 거리를 두고 부채꼴로 방울을 뿜는다
            A("ntc", shot: "mortar");                 // 산물을 던져 올린다(떨어질 자리에 원 표시)
            A("inhibitor", trait: "slow");            // 가까이 가면 느려진다
            A("lowq_read", move: "wobble");           // 비틀거리며 다가온다
            A("index_hop", behavior: "blink");        // 표시한 자리로 순간이동
            A("polyg", shot: "stream");               // 돌면서 줄줄이 쏜다
            A("bubble", trait: "pop");                // 터지면 사방으로 방울
            A("homopolymer", behavior: "snipe");      // 멀리서 조준선 → 한 줄 사격
            A("blocked_pore", shot: "noise");         // 아무 방향으로나 흩뿌린다
            A("tangle", trait: "unravel");            // 부수면 조각이 쏟아진다
            A("bug", move: "zigzag");                 // 지그재그로 기어 온다
            A("zombie", trait: "revive");             // 한 번 되살아난다
            A("segfault", behavior: "zigdash");       // 방향을 꺾으며 세 번 튄다
            A("inf_loop", shot: "orbit");             // 쏜 탄이 원을 그리며 맴돈다
            A("mem_leak", trait: "leak");             // 지나간 자리에 웅덩이
            Enemies = list.ToArray(); enemyMap = null;
        }
        static Dictionary<string, EnemyDef> enemyMap;
        public static EnemyDef Enemy(string id) { if (enemyMap == null) { enemyMap = new Dictionary<string, EnemyDef>(); foreach (var e in Enemies) enemyMap[e.id] = e; } return enemyMap[id]; }

        public static readonly BossDef[] Bosses =
        {
            new BossDef { id = "mold_wreath", name = "Mold Wreath", title = "곰팡이 화환", hp = 4000, radius = 64, dmg = 20, speed = 46, color = Orange },
            new BossDef { id = "krampus", name = "Krampus Phage", title = "뿔 달린 크람푸스 파지", hp = 7000, radius = 42, dmg = 24, speed = 95, color = Mag },
            new BossDef { id = "reviewer1", name = "Reviewer #1", title = "친절한 심사위원", hp = 9000, softCap = 0.016f, radius = 54, dmg = 20, speed = 62, color = Yellow },
            new BossDef { id = "adapter_dimer", name = "Adapter Dimer", title = "라이브러리의 불청객", hp = 11000, softCap = 0.014f, radius = 46, dmg = 22, speed = 78, color = Orange },
            new BossDef { id = "concatemer", name = "Concatemer", title = "끝나지 않는 리드", hp = 11000, softCap = 0.014f, radius = 34, dmg = 20, speed = 165, color = Violet },
            new BossDef { id = "reviewer2", name = "Reviewer #2", title = "최종 심사위원", title2 = "2차 심사", hp = 8000, hp2 = 9500, softCap = 0.025f, radius = 58, dmg = 26, speed = 70, color = Red },
        };
        public static BossDef Boss(string id) { foreach (var b in Bosses) if (b.id == id) return b; return Bosses[0]; }

        // 캠페인 구역. floor = 바닥 셰이더 종류(0 접시 / 1 직사각형 작업대)
        public static readonly ZoneDef[] Zones =
        {
            new ZoneDef { id = "dish", name = "배양접시", desc = "혈구계산판 격자 위의 넓은 원형 접시. 기본기를 익히는 곳.", floor = 0, size = new Vector2(2200, 0), length = 420, boss = "mold_wreath", mech = "", music = "dish", tier = 1f, ambient = Cyan },
            new ZoneDef { id = "hood", name = "클린벤치", desc = "층류가 아래로 밀어내고, UV 램프가 주기적으로 작업대를 쓸고 지나간다.", floor = 1, size = new Vector2(2300, 1400), length = 480, boss = "krampus", mech = "airflow", music = "hood", tier = 1.06f, ambient = Violet },
            new ZoneDef { id = "pcr", cast = "pcr", swarmToast = "프라이머 다이머 떼가 포위한다!", name = "PCR실", desc = "라이브러리 프렙. 히팅 블록이 온도 사이클에 맞춰 달아오른다 — 붉어지는 칸에서 나와라.", floor = 3, size = new Vector2(2200, 1320), length = 480, boss = "reviewer1", mech = "thermal", music = "pcr", tier = 1.12f, ambient = Orange,
                clearText = "Reviewer #1: \"Minor Revision — NGS 데이터를 추가해 주십시오.\"  시퀀싱실이 열렸다." },
            new ZoneDef { id = "sequencer", cast = "sr", swarmToast = "중복 리드 떼가 포위한다!", variantName = "숏리드", name = "시퀀싱실", desc = "숏리드 런. 스캔 레이저가 플로우셀을 훑고 지나간다 — 대시로 통과하라.", floor = 2, size = new Vector2(2400, 1300), length = 480, boss = "adapter_dimer", mech = "laser", music = "seq", tier = 1.18f, ambient = Green,
                clearText = "런 완료, Q30 통과. 이제 분석해서 다시 투고할 차례다 — 분석 서버실이 열렸다." },
            new ZoneDef { id = "server", cast = "srv", swarmToast = "경고 로그가 쏟아진다!", name = "분석 서버실", desc = "밤새 도는 파이프라인. 데이터 패킷이 타일 이음매를 따라 달린다 — 타일 안쪽에 서라. 끝에는 최종 심사가 기다린다.", floor = 4, size = new Vector2(2400, 1400), length = 480, boss = "reviewer2", mech = "packets", music = "server", tier = 1.25f, ambient = Cyan },
            // v3.1 예정: CO₂ 인큐베이터(열), -80℃ 냉동고(얼음)
        };
        public static ZoneDef Zone(string id) { foreach (var z in Zones) if (z.id == id) return z; foreach (var z in Variants) if (z.id == id) return z; return Zones[0]; }
        /// 같은 구역의 다른 버전(실험 준비 화면에서 고른다). 어느 쪽을 깨도 다음 구역이 열린다.
        public static readonly ZoneDef[] Variants =
        {
            new ZoneDef { id = "sequencer_lr", cast = "lr", swarmToast = "짧은 단편 떼가 포위한다!", variantOf = "sequencer", variantName = "롱리드", name = "시퀀싱실 · 롱리드", desc = "롱리드 런. 아주 긴 리드가 구역을 비스듬히 가로지른다 — 같은 자리를 세 번 읽으니 틈에서 기다려라.", floor = 5, size = new Vector2(2400, 1300), length = 480, boss = "concatemer", mech = "longreads", music = "seq", tier = 1.18f, ambient = Violet,
                clearText = "HiFi 리드 확보. 이제 분석해서 다시 투고할 차례다 — 분석 서버실이 열렸다." },
        };
        public static ZoneDef VariantOf(string baseId) { foreach (var z in Variants) if (z.variantOf == baseId) return z; return null; }

        // 무기. dmg/cd = 레벨별 피해·쿨다운, a/b = 무기마다 뜻이 다른 레벨별 값(주석 참고), lv = 레벨업 설명
        public static readonly WeaponDef[] Weapons =
        {
            new WeaponDef { id = "qpcr_beam", name = "qPCR Beam", desc = "가장 가까운 적 쪽으로 관통 빔", color = Cyan, evolveWith = "dmso", evolvedName = "Real-time Thermocycler", evolvedDesc = "끊기지 않는 회전 빔이 사방을 쓸어낸다",
                dmg = new float[] { 12, 14, 14, 17, 17, 20, 20, 24 }, cd = new float[] { 0.85f, 0.85f, 0.8f, 0.8f, 0.72f, 0.72f, 0.65f, 0.6f }, a = new float[] { 1, 1, 2, 2, 2, 3, 3, 4 } /*갈래*/, b = new float[] { 420, 440, 440, 470, 470, 500, 500, 540 } /*길이*/,
                lv = new[] { "", "피해 +2", "빔 2갈래", "피해 +3", "쿨다운 감소", "빔 3갈래", "쿨다운 감소", "빔 4갈래, 피해 +4" } },
            new WeaponDef { id = "gel_cutter", name = "Gel Cutter", desc = "가까운 적 쪽으로 넓게 베기", color = new Color(0.55f, 0.9f, 1f),
                dmg = new float[] { 20, 24, 24, 29, 29, 35, 35, 42 }, cd = new float[] { 1.1f, 1.1f, 1.0f, 1.0f, 0.9f, 0.9f, 0.8f, 0.75f }, a = new float[] { 95, 100, 112, 112, 125, 125, 140, 150 } /*범위*/, b = new float[] { 1, 1, 1, 2, 2, 2, 2, 2 } /*양방향*/,
                lv = new[] { "", "피해 +4", "범위 증가", "뒤쪽도 벤다", "범위 증가", "피해 +6", "범위 증가", "피해 +7, 범위 증가" } },
            new WeaponDef { id = "lentiviral_orb", name = "Lentiviral Orb", desc = "유도탄. 감염된 적이 죽으면 주변에 전파", color = Teal, evolveWith = "lipofectamine", evolvedName = "Pandemic Vector", evolvedDesc = "감염이 끝없이 번진다",
                dmg = new float[] { 9, 9, 11, 11, 13, 13, 15, 18 }, cd = new float[] { 1.6f, 1.5f, 1.5f, 1.4f, 1.4f, 1.3f, 1.3f, 1.2f }, a = new float[] { 1, 1, 2, 2, 2, 3, 3, 3 } /*발사 수*/, b = new float[] { 2, 3, 3, 3, 4, 4, 5, 6 } /*전파 횟수*/,
                lv = new[] { "", "전파 +1", "유도탄 2발", "쿨다운 감소", "전파 +1", "유도탄 3발", "전파 +1", "피해 +3, 전파 +1" } },
            new WeaponDef { id = "nanopore_ring", name = "Nanopore Ring", desc = "주위를 도는 기공이 닿는 적을 뚫는다", color = new Color(0.45f, 0.7f, 1f),
                dmg = new float[] { 8, 8, 10, 10, 12, 12, 14, 16 }, cd = new float[] { 0.5f, 0.5f, 0.45f, 0.45f, 0.4f, 0.4f, 0.35f, 0.3f }, a = new float[] { 2, 3, 3, 4, 4, 5, 5, 6 } /*개수*/, b = new float[] { 80, 80, 90, 90, 100, 100, 112, 124 } /*반경*/,
                lv = new[] { "", "기공 3개", "반경·피해 증가", "기공 4개", "반경·피해 증가", "기공 5개", "반경·피해 증가", "기공 6개" } },
            new WeaponDef { id = "antibody_chain", name = "Antibody Chain", desc = "적 사이를 튀어 다니는 항체", color = new Color(0.4f, 0.75f, 1f),
                dmg = new float[] { 11, 11, 13, 13, 15, 15, 18, 21 }, cd = new float[] { 1.3f, 1.3f, 1.2f, 1.2f, 1.1f, 1.1f, 1.0f, 0.9f }, a = new float[] { 3, 4, 4, 5, 5, 6, 7, 8 } /*튀는 횟수*/, b = new float[] { 1, 1, 1, 1, 2, 2, 2, 2 } /*발사 수*/,
                lv = new[] { "", "튐 +1", "피해 +2", "튐 +1", "항체 2개", "튐 +1", "피해 +3, 튐 +1", "피해 +3, 튐 +1" } },
            new WeaponDef { id = "centrifuge_wave", name = "Centrifuge Wave", desc = "원형 충격파로 밀어낸다", color = new Color(0.5f, 0.8f, 1f), evolveWith = "matrigel", evolvedName = "Ultracentrifuge", evolvedDesc = "적을 끌어당긴 뒤 두 배로 터뜨린다",
                dmg = new float[] { 10, 12, 12, 15, 15, 18, 18, 22 }, cd = new float[] { 3.0f, 3.0f, 2.7f, 2.7f, 2.4f, 2.4f, 2.1f, 1.9f }, a = new float[] { 150, 160, 175, 175, 195, 195, 215, 235 } /*반경*/, b = new float[] { 320, 340, 360, 380, 400, 420, 440, 480 } /*넉백*/,
                lv = new[] { "", "피해 +2", "반경 증가", "피해 +3", "반경 증가", "피해 +3", "반경 증가", "피해 +4, 반경 증가" } },
            new WeaponDef { id = "crispr_lance", name = "CRISPR Lance", desc = "가장 튼튼한 적을 노리는 고위력 창", color = new Color(0.35f, 0.95f, 0.95f), evolveWith = "penstrep", evolvedName = "Prime Editor", evolvedDesc = "HP 15% 이하 일반 적은 즉사, 보스·엘리트 피해 +50%",
                dmg = new float[] { 42, 52, 52, 64, 64, 78, 78, 96 }, cd = new float[] { 2.2f, 2.2f, 2.0f, 2.0f, 1.8f, 1.8f, 1.6f, 1.5f }, a = new float[] { 1, 1, 2, 2, 3, 3, 4, 5 } /*관통*/, b = new float[] { 1, 1, 1, 1, 1, 2, 2, 2 } /*발사 수*/,
                lv = new[] { "", "피해 +10", "관통 +1", "피해 +12", "관통 +1", "창 2개", "관통 +1", "피해 +18, 관통 +1" } },
            new WeaponDef { id = "uv_flash", name = "UV Flash", desc = "화면 안 적에게 내리꽂는 섬광", color = new Color(0.7f, 0.5f, 1f),
                dmg = new float[] { 18, 18, 22, 22, 26, 26, 30, 36 }, cd = new float[] { 1.8f, 1.8f, 1.7f, 1.7f, 1.6f, 1.5f, 1.4f, 1.3f }, a = new float[] { 1, 2, 2, 3, 3, 4, 4, 5 } /*타격 수*/, b = new float[] { 46, 46, 52, 52, 58, 58, 64, 72 } /*범위*/,
                lv = new[] { "", "섬광 2개", "피해·범위 증가", "섬광 3개", "피해·범위 증가", "섬광 4개", "피해·범위 증가", "섬광 5개" } },
            new WeaponDef { id = "etoh_splash", name = "70% EtOH Splash", desc = "바닥에 남는 소독 장판", color = new Color(0.5f, 0.9f, 1f),
                dmg = new float[] { 5, 5, 6, 6, 7, 7, 8, 10 }, cd = new float[] { 3.2f, 3.2f, 3.0f, 3.0f, 2.8f, 2.8f, 2.6f, 2.4f }, a = new float[] { 1, 2, 2, 2, 3, 3, 3, 4 } /*장판 수*/, b = new float[] { 70, 70, 80, 90, 90, 100, 110, 120 } /*크기*/,
                lv = new[] { "", "장판 2개", "크기·피해 증가", "크기 증가", "장판 3개", "크기 증가", "크기·피해 증가", "장판 4개" } },
            new WeaponDef { id = "lysozyme_field", name = "Lysozyme Field", desc = "몸 주변에 늘 켜져 있는 용해 장", color = Teal,
                dmg = new float[] { 4, 5, 5, 6, 6, 7, 8, 10 }, cd = new float[] { 0.5f, 0.5f, 0.5f, 0.45f, 0.45f, 0.4f, 0.4f, 0.35f }, a = new float[] { 78, 78, 90, 90, 104, 104, 118, 132 } /*반경*/, b = new float[] { 0, 0, 0, 0, 0, 0, 0, 0 },
                lv = new[] { "", "피해 +1", "반경 증가", "피해 +1, 틱 빨라짐", "반경 증가", "피해 +1, 틱 빨라짐", "반경 증가", "피해 +2, 반경 증가" } },
        };
        // 플레이어 공격이 적 탄환을 막을 확률(탄환 하나에 무기마다 한 번만 굴린다)
        static readonly Dictionary<string, float> BlockChance = new Dictionary<string, float>
        {
            { "nanopore_ring", 0.75f }, { "centrifuge_wave", 0.6f }, { "gel_cutter", 0.5f }, { "uv_flash", 0.4f }, { "etoh_splash", 0.35f }, { "qpcr_beam", 0.25f }, { "lysozyme_field", 0.25f },
        };
        static DB() { InitWeapons(); InitEnemies(); }
        static bool weaponInit;
        static void InitWeapons()
        {
            if (weaponInit) return; weaponInit = true;
            for (int k = 0; k < Weapons.Length; k++) { Weapons[k].bit = 1 << k; BlockChance.TryGetValue(Weapons[k].id, out Weapons[k].block); }
        }
        public static WeaponDef Weapon(string id) { InitWeapons(); foreach (var w in Weapons) if (w.id == id) return w; return null; }

        public static readonly PassiveDef[] Passives =
        {
            new PassiveDef { id = "fbs", name = "FBS", text = "최대 HP +20" }, new PassiveDef { id = "penstrep", name = "Pen-Strep", text = "피해 +10%" },
            new PassiveDef { id = "trypsin", name = "Trypsin", text = "쿨다운 -8%" }, new PassiveDef { id = "agarose", name = "Agarose", text = "공격 범위 +10%" },
            new PassiveDef { id = "dmso", name = "DMSO", text = "효과 지속시간 +10%" }, new PassiveDef { id = "matrigel", name = "Matrigel", text = "받는 피해 -1" },
            new PassiveDef { id = "egf", name = "EGF", text = "이동속도 +8%" }, new PassiveDef { id = "lipofectamine", name = "Lipofectamine", text = "ATP 획득 반경 +25%" },
        };
        public static PassiveDef Passive(string id) { foreach (var p in Passives) if (p.id == id) return p; return null; }

        // 분 단위 웨이브(구역 길이에 맞춰 0~1 진행도로 고른다)
        public static readonly Wave[] Waves =
        {
            new Wave { interval = 1.2f, batch = 2, max = 28, pool = new[] { ("ecoli", 5), ("mycoplasma", 3) } },
            new Wave { interval = 1.0f, batch = 2, max = 46, pool = new[] { ("ecoli", 5), ("mycoplasma", 5) } },
            new Wave { interval = 0.88f, batch = 3, max = 66, pool = new[] { ("ecoli", 5), ("mycoplasma", 4), ("yeast", 2) } },
            new Wave { interval = 0.8f, batch = 3, max = 88, pool = new[] { ("ecoli", 4), ("mycoplasma", 4), ("yeast", 3), ("phage", 1) } },
            new Wave { interval = 0.74f, batch = 4, max = 110, pool = new[] { ("ecoli", 4), ("mycoplasma", 3), ("yeast", 3), ("phage", 2), ("spore_pod", 1) } },
            new Wave { interval = 0.68f, batch = 4, max = 132, pool = new[] { ("ecoli", 3), ("mycoplasma", 4), ("yeast", 3), ("phage", 2), ("spore_pod", 1) } },
            new Wave { interval = 0.62f, batch = 5, max = 155, pool = new[] { ("ecoli", 3), ("mycoplasma", 3), ("yeast", 3), ("phage", 3), ("spore_pod", 1), ("biofilm", 1) } },
            new Wave { interval = 0.56f, batch = 5, max = 180, pool = new[] { ("ecoli", 3), ("mycoplasma", 4), ("yeast", 3), ("phage", 3), ("spore_pod", 2), ("biofilm", 1) } },
        };

        // 연구실: 연구비로 사는 영구 강화. 값은 World.Recalc / Begin, Game.OnFinished 에서 읽는다.
        public static readonly UpgradeDef[] Upgrades =
        {
            new UpgradeDef { id = "culture", name = "고급 배양 배지", text = "최대 HP +10", max = 5, cost = 40 },
            new UpgradeDef { id = "reagent", name = "고순도 시약", text = "피해 +5%", max = 5, cost = 50 },
            new UpgradeDef { id = "pipette", name = "전동 피펫", text = "쿨다운 -3%", max = 5, cost = 50 },
            new UpgradeDef { id = "shoes", name = "실험화", text = "이동속도 +4%", max = 5, cost = 40 },
            new UpgradeDef { id = "magnet", name = "마그네틱 비드", text = "ATP 획득 반경 +10%", max = 5, cost = 30 },
            new UpgradeDef { id = "growth", name = "성장 인자", text = "경험치 +8%", max = 5, cost = 50 },
            new UpgradeDef { id = "funding", name = "과제 수주", text = "연구비 획득 +10%", max = 5, cost = 60 },
            new UpgradeDef { id = "reroll", name = "재실험", text = "레벨 업 다시 뽑기 +1", max = 3, cost = 100 },
            new UpgradeDef { id = "backup", name = "백업 스톡", text = "런당 1회, HP 50%로 부활", max = 1, cost = 400 },
        };
        public static int UpgradeCost(UpgradeDef u, int lv) { return Mathf.RoundToInt(u.cost * (1f + 0.7f * lv) / 10f) * 10; }

        // 도감 설명
        public static readonly Dictionary<string, string> Lore = new Dictionary<string, string>
        {
            { "mycoplasma", "너무 작아서 필터도 통과한다. 떼로 몰려와 포위한다." },
            { "ecoli", "가장 흔한 오염균. 느리지만 끝없이 몰려온다." },
            { "yeast", "출아로 늘어난다. 잡으면 작은 싹 둘로 갈라진다." },
            { "phage", "잠깐 멈췄다가 일직선으로 돌진한다." },
            { "spore_pod", "제자리에서 포자를 사방으로 쏜다. 먼저 잡아라." },
            { "biofilm", "끈적한 덩어리. 느리지만 아주 단단하다." },
            { "tipbox", "부수면 핫코코아나 볼텍스가 나온다." },
            { "primer_dimer", "프라이머끼리 붙어 버린 짧은 산물. 작고 빠르며 떼로 몰려온다." },
            { "nonspecific", "엉뚱한 자리에서 증폭된 산물. 가장 흔하고 끝없이 나온다." },
            { "carryover", "지난 런에서 넘어온 증폭 산물. 잡으면 두 가닥으로 풀려 갈라진다." },
            { "aerosol", "파이펫에서 튄 에어로졸. 거리를 두고 멈춰서 부채꼴로 잔방울을 뿜는다." },
            { "ntc", "음성 대조군인데 밴드가 뜬다. 산물을 던져 올린다 — 표시된 원에서 벗어나라." },
            { "inhibitor", "헤파린과 에탄올 찌꺼기가 뭉친 결정. 가까이 가면 발이 느려진다." },
            { "dup_read", "PCR 중복. 똑같은 리드가 떼로 몰려온다." },
            { "lowq_read", "뒤로 갈수록 퀄리티가 무너지는 리드. 비틀비틀 흔들리며 다가온다." },
            { "polyclonal", "한 자리에 두 가닥이 자란 클러스터. 잡으면 둘로 갈라진다." },
            { "index_hop", "다른 샘플로 건너뛰는 리드. 표시한 자리로 순간이동해 덮친다." },
            { "polyg", "신호가 꺼져 G만 읽히는 웰. 빙글빙글 돌며 G를 줄줄이 쏟아낸다." },
            { "bubble", "플로우셀에 낀 기포. 터뜨리면 사방으로 방울이 튄다." },
            { "short_frag", "사이즈 셀렉션을 빠져나온 짧은 조각. 떼로 몰려온다." },
            { "fail_read", "퀄리티가 모자라 fail로 떨어진 리드. 가장 흔하다." },
            { "chimera", "두 분자가 이어 붙은 리드. 잡으면 원래의 두 조각으로 갈라진다." },
            { "homopolymer", "같은 염기가 끝없이 이어진다. 멀리서 조준선을 그은 뒤 한 줄로 쏜다." },
            { "blocked_pore", "막혀 버린 포어. 제멋대로인 방향으로 잡음을 흩뿌린다." },
            { "tangle", "풀리지 않은 초고분자 DNA 뭉치. 부수면 짧은 조각들이 쏟아져 나온다." },
            { "warning", "무시해도 된다던 경고 로그. 떼로 쏟아진다." },
            { "bug", "가장 흔한 버그. 지그재그로 기어 온다." },
            { "zombie", "끝났는데 사라지지 않는 프로세스. 한 번 쓰러뜨려도 다시 일어난다." },
            { "segfault", "엉뚱한 주소를 세 번 찍으며 지그재그로 튀어 든다." },
            { "inf_loop", "제자리에서 돈다. 쏜 탄도 원을 그리며 계속 맴돈다." },
            { "mem_leak", "조금씩 새는 덩어리. 지나간 자리에 웅덩이를 남긴다." },
            { "co_reviewer", "Reviewer가 불러온 공동 심사위원. 노려보다가 일직선으로 달려든다." },
            { "comment", "'사소한' 지적 사항. 떼로 몰려온다." },
            { "mold_wreath", "배양접시의 주인 행세를 하는 곰팡이. 포자 고리의 틈을 찾아라." },
            { "krampus", "클린벤치를 휘젓는 파지. 세 번 연속 돌진한 뒤 뛰어내린다." },
            { "reviewer1", "친절한 말투로 고칠 곳을 끝없이 찾아낸다." },
            { "adapter_dimer", "인서트 없이 어댑터끼리 붙은 불청객. PCR 사이클마다 두 배로 늘어난다." },
            { "concatemer", "끝없이 이어 붙은 리드. 머리만 약점이고, 잘려 나갈수록 짧아진다." },
            { "reviewer2", "최종 심사위원. 체력을 다 깎으면 2차 심사가 시작된다. 끝까지 버티면 Accept가 온다." },
        };

        public static int XpToNext(int level) { int n = 5 * level; if (level >= 20) n += (level - 19) * 8; return n; }
                /// 시간이 갈수록 적이 단단해진다(무기 성장 속도를 따라가도록 뒤로 갈수록 가파르게)
        public static float HpA = 0.14f, HpB = 0.02f, SpawnMul = 1.08f, DmgPerMin = 0.035f;
        public static float HpMul(float min) { return 1f + HpA * min + HpB * min * min; }
        /// 게임 속 시계: 18:00에서 시작, 구역 하나가 밤의 일부
        public static string Clock(float t) { int m = (int)(t * 1.5f); int h = (18 + m / 60) % 24; return h.ToString("00") + ":" + (m % 60).ToString("00"); }
    }
}
