using System;
using System.Collections.Generic;
using UnityEngine;

namespace CS
{
    /// 한 판(구역 하나)의 모든 것: 플레이어, 적, 무기, 스폰, 충돌, 드롭, 레벨업, 그리기.
    public partial class World
    {
        // ── 설정 ──
        public CharDef ch; public ZoneDef zone; public DiffDef diff = DB.Diffs[1]; public int diffIdx = 1;
        // ── 플레이어 ──
        public Vector2 pos, look, facing = Vector2.right;
        public float hp, maxHp, speed, armor, pDamage = 1f, pCooldown = 1f, pArea = 1f, pDuration = 1f, magnet, invuln, hurtFlash; public PlayRecord record = new PlayRecord();
        // 프레임 시간 통계(멈춰 있지 않은 프레임만)
        public readonly int[] ftHist = new int[121]; public int ftN, hitchN, hitchMin; public float ftSum, ftMax;
        public void FrameStat(float udt) { ftN++; ftSum += udt; if (udt > ftMax) ftMax = udt; ftHist[Mathf.Clamp((int)(udt * 1000f), 0, 120)]++; if (udt > 0.025f) { hitchN++; hitchMin++; } }
        public string lastHurtBy = ""; public float viewMinAcc; public int viewMinN; int minuteMark;
        public int hitsTaken, viewNow; public float dmgTaken, viewAcc, bossSpawnT = -1f, bossDeadT = -1f; public int viewN;
        public const int MaxDash = 2;
        public int dashCharges = MaxDash; public float dashRegen, dashT; Vector2 dashDir; bool dashQueued, ultQueued;
        public float ult, ultActive; public int revives; int phago;
        public float CdRate => ultActive > 0f && ch.id == "hek293t" ? 2.5f : 1f;
        readonly List<Vector3> ghosts = new List<Vector3>();   // 대시 잔상 (x, y, 남은 시간)
        // ── 런 ──
        public float t; public int level = 1, xp, xpNext, kills, bossKills, rerolls = 1, pendingLevelUps;
        public bool finished, victory, demo; public RunResult result;
        public readonly List<Weapon> weapons = new List<Weapon>();
        public readonly Dictionary<string, int> passives = new Dictionary<string, int>();
        public readonly List<Enemy> enemies = new List<Enemy>(512);
        public readonly List<Proj> projs = new List<Proj>(128);
        public readonly List<EBullet> bullets = new List<EBullet>(256);
        public readonly List<EPool> pools = new List<EPool>();     // 바닥에 남은 웅덩이(메모리 누수)
        public float slowT;                                         // 저해제 곁에 있어 느려진 상태(남은 시간)
        public readonly List<Pickup> pickups = new List<Pickup>(512);
        public readonly List<Area> areas = new List<Area>();
        public readonly List<Particle> parts = new List<Particle>(1024);
        public readonly List<FxItem> fx = new List<FxItem>(64);
        public readonly List<Telegraph> tele = new List<Telegraph>();
        public readonly List<DmgNum> nums = new List<DmgNum>(128);
        public readonly List<(float, Action)> sched = new List<(float, Action)>(); readonly List<Action> due = new List<Action>();
        public readonly List<string> toasts = new List<string>(); public float toastT;
        public Enemy boss; bool bossSpawned; float bossIntro;
        public List<string> lastGift = new List<string>(); public float giftT;
        Vector2 camPos; float shake; float spawnT, tipT = 20f, uvT = 30f; int eventIdx; int gems;
        // 공간 해시
        const float Cell = 100f; const int GN = 56; readonly List<Enemy>[] grid = new List<Enemy>[GN * GN];
        readonly List<Enemy>[] qpool = new List<Enemy>[12]; int qi;
        public System.Random rng = new System.Random();

        public void Begin(CharDef c, ZoneDef z, int difficulty = 1)
        {
            ch = c; zone = z; diffIdx = Mathf.Clamp(difficulty, 0, 2); diff = DB.Diffs[diffIdx];
            for (int i = 0; i < grid.Length; i++) grid[i] = new List<Enemy>(8);
            for (int i = 0; i < qpool.Length; i++) qpool[i] = new List<Enemy>(64);
            if (Dev.Has("seed")) { rng = new System.Random((int)Dev.F("seed", 1)); UnityEngine.Random.InitState((int)Dev.F("seed", 1)); }
            Gfx.SetArena(zone.floor, zone.size);
            pos = Vector2.zero; camPos = pos;
            revives = (ch.id == "hela" ? 1 : 0) + Save.Upgrade("backup"); rerolls = 1 + Save.Upgrade("reroll");
            xpNext = DB.XpToNext(level);
            Recalc(); hp = maxHp;
            AddWeapon(ch.startWeapon, false);
            t = Dev.F("start", 0f);
            if (Dev.Has("weapons")) foreach (var id in Dev.S("weapons", "").Split(',')) if (DB.Weapon(id) != null && GetWeapon(id) == null) AddWeapon(id, false);
            if (Dev.Has("wlevel")) foreach (var w in weapons) w.level = Mathf.Clamp((int)Dev.F("wlevel", 1), 1, DB.WeaponMaxLevel);
            if (Dev.Has("cocoa")) { Drop(pos + new Vector2(90f, 30f), 1, 1); Drop(pos + new Vector2(-150f, -60f), 1, 1); }
            if (Dev.Has("gallery"))
            {
                // 개발용: 한 분류의 적을 한 화면에 세워 놓는다(윗줄 보통, 아랫줄 엘리트+차지)
                int g = (int)Dev.F("gallery", 1); var defs = new List<EnemyDef>(); foreach (var d in DB.Enemies) if (d.group == g || (g == 4 && d.group == 5)) defs.Add(d);
                for (int i = 0; i < defs.Count; i++)
                {
                    float x = (i - (defs.Count - 1) * 0.5f) * 118f;
                    for (int row = 0; row < 2; row++) { var e = Spawn(defs[i].id, pos + new Vector2(x, row == 0 ? 150f : -170f), row == 1); e.hp = e.maxHp = 1e9f; e.seed = 0.13f + i * 0.21f; }
                }
            }
            if (demo) return;
            Toast(zone.name + " — " + DB.Clock(0) + ", 모두 퇴근했다");
            Audio.PlayMusic(zone.music ?? "dish", 4);
        }

        public void Recalc()
        {
            int P(string id) { return passives.TryGetValue(id, out int v) ? v : 0; }
            float old = maxHp;
            maxHp = ch.hp + 20f * P("fbs") + 10f * Save.Upgrade("culture");
            if (maxHp > old && old > 0f) hp += maxHp - old;
            pDamage = (1f + 0.10f * P("penstrep")) * (1f + 0.05f * Save.Upgrade("reagent"));
            pCooldown = Mathf.Max(0.35f, (1f - 0.08f * P("trypsin")) * (1f - 0.03f * Save.Upgrade("pipette")));
            pArea = 1f + 0.10f * P("agarose"); pDuration = 1f + 0.10f * P("dmso");
            armor = P("matrigel");
            speed = ch.speed * (1f + 0.08f * P("egf")) * (1f + 0.04f * Save.Upgrade("shoes"));
            magnet = DB.BaseMagnet * (1f + 0.25f * P("lipofectamine")) * (1f + 0.10f * Save.Upgrade("magnet"));
        }

        // ── 경계 ──
        public int laserState; public float laserX, laserDir, laserWarn, laserEnd, laserT = 26f, thermT = 20f, packT = 16f, lrT = 22f; bool packHoriz, packTold;
        public readonly List<Vector2> snakeTrail = new List<Vector2>();
        public bool InBounds(Vector2 p, float m = 0f) { return zone.floor == 0 ? p.magnitude < zone.size.x - m : Mathf.Abs(p.x) < zone.size.x - m && Mathf.Abs(p.y) < zone.size.y - m; }
        public Vector2 Clamp(Vector2 p, float m = 0f)
        {
            if (zone.floor == 0) { float lim = zone.size.x - m; return p.magnitude > lim ? p.normalized * lim : p; }
            return new Vector2(Mathf.Clamp(p.x, -zone.size.x + m, zone.size.x - m), Mathf.Clamp(p.y, -zone.size.y + m, zone.size.y - m));
        }
        public Vector2 ViewHalf { get { var c = Game.I.cam; return new Vector2(c.orthographicSize * c.aspect, c.orthographicSize); } }
        public bool InView(Vector2 p, float m = 0f) { var v = ViewHalf; return Mathf.Abs(p.x - camPos.x) < v.x + m && Mathf.Abs(p.y - camPos.y) < v.y + m; }

        // ── 입력은 Update에서 받아 두었다가 고정 틱에서 쓴다 ──
        public void PollInput() { if (Inp.Dash) dashQueued = true; if (Inp.Ultimate) ultQueued = true; }
        public void ClearInput() { dashQueued = false; ultQueued = false; }

        // ── 메인 틱 ──
        public void Tick(float dt)
        {
            if (finished) return;
            t += dt;
            due.Clear();
            for (int i = sched.Count - 1; i >= 0; i--) { var s = sched[i]; s.Item1 -= dt; if (s.Item1 <= 0f) { sched.RemoveAt(i); due.Add(s.Item2); } else sched[i] = s; }
            foreach (var a in due) a();
            Sweep();
            if (((int)(t * 4f)) != ((int)((t - dt) * 4f))) { int c = 0; foreach (var e in enemies) if (!e.dead && InView(e.pos)) c++; viewAcc += c; viewN++; viewNow = c; viewMinAcc += c; viewMinN++; TickMusic(); }
            if (!demo && (int)(t / 60f) > minuteMark) { minuteMark = (int)(t / 60f); PlayLog.Minute(this, record); }
            Director(dt);
            RebuildGrid();
            TickPlayer(dt);
            if (zone.mech == "airflow") TickAirflow(dt);
            if (!Dev.Has("nohazard"))
            {
                if (zone.mech == "laser") TickLaser(dt);
                if (zone.mech == "thermal") TickThermal(dt);
                if (zone.mech == "packets") TickPackets(dt);
                if (zone.mech == "longreads") TickLongReads(dt);
            }
            if (!Dev.Has("gallery")) foreach (var w in weapons) w.Tick(dt);
            TickEnemies(dt);
            TickProjs(dt);
            TickBullets(dt);
            TickPools(dt);
            TickAreas(dt);
            TickPickups(dt);
            TickTele(dt);
            TickFx(dt);
            if (hp <= 0f) OnDown();
        }

        void Sweep()
        {
            enemies.RemoveAll(e => e.dead); projs.RemoveAll(p => p.dead); bullets.RemoveAll(b => b.dead); pickups.RemoveAll(p => p.dead);
            if (boss != null && boss.dead) boss = null;
        }

        public void After(float delay, Action a) { sched.Add((delay, a)); }
        public void Toast(string s) { toasts.Add(s); if (toasts.Count > 3) toasts.RemoveAt(0); toastT = 3.4f; }
        public void Shake(float a) { if (Save.D.shake) shake = Mathf.Max(shake, a); }

        // ── 플레이어 ──
        void TickPlayer(float dt)
        {
            if (diff.regen > 0f && hp > 0f) hp = Mathf.Min(maxHp, hp + diff.regen * dt);
            Vector2 mv = demo || Dev.Has("autoplay") ? Bot() : Inp.Move();
            if (mv.sqrMagnitude > 0.01f) facing = mv.normalized;
            look = Vector2.Lerp(look, mv, 1f - Mathf.Exp(-10f * dt));
            // 대시: 짧게 튀어 나가며 무적
            if (dashCharges < MaxDash) { dashRegen -= dt; if (dashRegen <= 0f) { dashCharges++; dashRegen = 2.2f; } }
            if (dashQueued && dashCharges > 0 && dashT <= 0f)
            {
                dashCharges--; if (dashCharges == MaxDash - 1) dashRegen = 2.2f;
                dashT = 0.17f; dashDir = facing; invuln = Mathf.Max(invuln, 0.3f);
                Audio.Play("ui_move", 0.9f, 0.1f); Burst(pos, ch.color, 10, 160f, 0.35f);
            }
            dashQueued = false;
            if (dashT > 0f)
            {
                dashT -= dt; pos += dashDir * speed * 4.2f * dt;
                ghosts.Add(new Vector3(pos.x, pos.y, 0.28f));
            }
            else pos += mv * speed * (slowT > 0f ? 0.70f : 1f) * dt;      // 대시는 느려지지 않는다(빠져나갈 수단)
            slowT -= dt;
            pos = Clamp(pos, DB.PlayerRadius);
            for (int i = ghosts.Count - 1; i >= 0; i--) { var g = ghosts[i]; g.z -= dt; if (g.z <= 0f) ghosts.RemoveAt(i); else ghosts[i] = g; }
            // 궁극기
            if (ultQueued && ult >= 100f) UseUlt();
            ultQueued = false;
            if (ultActive > 0f) ultActive -= dt;
            invuln = Mathf.Max(0f, invuln - dt); hurtFlash = Mathf.Max(0f, hurtFlash - dt);
            camPos = Vector2.Lerp(camPos, pos + look * 30f, 1f - Mathf.Exp(-8f * dt));
            shake = Mathf.Max(0f, shake - 40f * dt);
            toastT -= dt; giftT -= dt;
        }

        void UseUlt()
        {
            ult = 0f; Audio.Play("levelup", 0.9f); Shake(8f);
            Ring(pos, ch.color, 20f, 420f, 0.6f, 10f);
            Toast(ch.ult + "!");
            if (ch.id == "hek293t") ultActive = 6f;
            else if (ch.id == "hela")
            {
                hp = Mathf.Min(maxHp, hp + maxHp * 0.35f); invuln = 4f; ultActive = 4f;
                foreach (var e in Query(pos, 300f)) Hit(e, 40f * pDamage, (e.pos - pos).normalized, 600f, ch.color);
            }
            else
            {
                ultActive = 1f;
                var list = new List<Enemy>(Query(pos, 340f));
                foreach (var e in list)
                {
                    if (!e.IsBoss) e.pos = Vector2.Lerp(e.pos, pos, 0.55f);
                    bool wasAlive = !e.dead; Hit(e, 90f * pDamage, Vector2.zero, 0f, ch.color);
                    if (wasAlive && e.dead) hp = Mathf.Min(maxHp, hp + 1.5f);
                }
            }
        }

        public void Hurt(float amount, string by = "hazard")
        {
            if (invuln > 0f || demo || Dev.Has("god") || finished) return;
            lastHurtBy = by;
            float d = Mathf.Max(1f, amount * diff.dmg - armor);
            hp -= d; hitsTaken++; dmgTaken += d; invuln = diff.invuln; hurtFlash = 0.14f; Shake(5f);
            Audio.Play("hurt", 0.9f, 0.08f);
            Burst(pos, DB.Red, 8, 140f, 0.4f);
        }

        void OnDown()
        {
            if (revives > 0)
            {
                revives--; hp = maxHp * 0.5f; invuln = 2f;
                foreach (var e in Query(pos, 260f)) if (!e.IsBoss) e.knock += (e.pos - pos).normalized * 700f;
                Ring(pos, ch.color, 10f, 260f, 0.6f, 8f); Toast(ch.id == "hela" ? "불멸화 발동 — HeLa는 죽지 않는다" : "백업 스톡 해동 — 부활!");
                return;
            }
            Finish(false);
        }

        public void Finish(bool win)
        {
            if (finished) return;
            finished = true; victory = win;
            result = new RunResult { victory = win, time = t, level = level, kills = kills, bossKills = bossKills, charId = ch.id, zoneId = zone.id, diff = diffIdx };
            foreach (var w in weapons) result.build.Add(w.Name + " Lv" + w.level);
            foreach (var kv in passives) result.build.Add(DB.Passive(kv.Key).name + " Lv" + kv.Value);
            if (!demo) Audio.Stinger(win ? "victory" : "defeat");
        }

        // 음악 긴장도: 구역 진행도 + 화면 안 적 수 + 위기(체력 낮음). 보스전은 2페이즈에 분노 레이어.
        void TickMusic()
        {
            if (demo || finished) return;
            if (boss != null) { Audio.Intensity = boss.phase2 || boss.hp < boss.maxHp * 0.6f ? 1f : 0f; return; }
            if (bossSpawned) return;
            float prog = Mathf.Clamp01(t / zone.length), dens = Mathf.Clamp01(viewNow / 45f);
            Audio.Intensity = Mathf.Clamp01(0.10f + 0.75f * prog + 0.30f * dens + (hp < maxHp * 0.35f ? 0.12f : 0f));
        }

        /// 자동 플레이용 선택: 진화 > 가진 무기 강화 > (무기 3개 미만이면) 새 무기 > 시약
        public LevelOption BotPick(List<LevelOption> opts)
        {
            LevelOption best = opts[0]; int bs = -1;
            foreach (var o in opts)
            {
                int sc = o.evolve ? 9 : o.type == "weapon" ? (o.isNew ? (weapons.Count < 3 ? 5 : 1) : 6) : (o.type == "passive" ? (o.isNew ? 3 : 4) : 0);
                if (sc > bs) { bs = sc; best = o; }
            }
            return best;
        }

        // 개발용 자동 플레이: 적에게서 멀어지고 ATP 쪽으로
        Vector2 Bot()
        {
            Vector2 v = Vector2.zero; float nearest = 1e9f;
            foreach (var e in Query(pos, 230f)) { Vector2 d = pos - e.pos; float l = Mathf.Max(d.magnitude, 1f); v += d / l * (230f / l); nearest = Mathf.Min(nearest, l - e.radius); }
            foreach (var b in bullets) { Vector2 d = pos - b.pos; float l = d.magnitude; if (l < 110f) v += d / Mathf.Max(l, 1f) * 3f; }
            Pickup best = null; float bd = 560f;
            foreach (var p in pickups) { float d = (p.pos - pos).magnitude; if (d < bd) { bd = d; best = p; } }
            if (best != null) v += (best.pos - pos).normalized * (nearest > 90f ? 2.6f : 1.4f);
            v += new Vector2(Mathf.Cos(t * 0.31f), Mathf.Sin(t * 0.23f)) * 0.5f - pos / Mathf.Max(zone.size.x, 1f) * 1.5f;
            Vector2 inner = Clamp(pos, 320f); if ((inner - pos).sqrMagnitude > 1f) v += (inner - pos) / 60f;     // 벽에 몰리지 않게
            // 예고된 위험(원·선)에서 벗어난다 — 사람이라면 피할 것들
            foreach (var q in tele)
            {
                if (q.type == 0) { Vector2 d = pos - q.a; float l = d.magnitude; if (l < q.r + 45f) v += (l > 1f ? d / l : Vector2.right) * 5f; }
                else
                {
                    Vector2 ab = q.b - q.a; float f = Mathf.Clamp01(Vector2.Dot(pos - q.a, ab) / Mathf.Max(ab.sqrMagnitude, 1f));
                    Vector2 d = pos - (q.a + ab * f); float l = d.magnitude;
                    if (l < q.r * 0.5f + 45f) v += (l > 1f ? d / l : new Vector2(-ab.y, ab.x).normalized) * 5f;
                }
            }
            if (laserState == 2 && Mathf.Abs(pos.x - laserX) < 75f) { v = new Vector2(-laserDir, 0f) * 8f; if (Mathf.Abs(pos.x - laserX) < 55f) dashQueued = true; }
            if (nearest < 26f) dashQueued = true;
            if (ult >= 100f) ultQueued = true;
            return v.sqrMagnitude > 0.001f ? v.normalized : Vector2.zero;
        }

        // ── 공간 해시 ──
        int GI(float x) { return Mathf.Clamp((int)((x + GN * Cell * 0.5f) / Cell), 0, GN - 1); }
        void RebuildGrid()
        {
            for (int i = 0; i < grid.Length; i++) grid[i].Clear();
            foreach (var e in enemies) if (!e.dead) grid[GI(e.pos.y) * GN + GI(e.pos.x)].Add(e);
        }
        /// 반경 안의 적. 버퍼 12개를 돌려 쓰므로 겹쳐 불러도(피해 → 처치 → 전파) 안전하다.
        public List<Enemy> Query(Vector2 p, float r)
        {
            var qbuf = qpool[qi]; qi = (qi + 1) % qpool.Length;
            qbuf.Clear();
            int x0 = GI(p.x - r - 70f), x1 = GI(p.x + r + 70f), y0 = GI(p.y - r - 70f), y1 = GI(p.y + r + 70f);
            for (int y = y0; y <= y1; y++)
                for (int x = x0; x <= x1; x++)
                    foreach (var e in grid[y * GN + x])
                        if (!e.dead && (e.pos - p).sqrMagnitude < (r + e.radius) * (r + e.radius)) qbuf.Add(e);
            return qbuf;
        }
        public Enemy Nearest(Vector2 p, float range, HashSet<Enemy> exclude = null)
        {
            Enemy best = null; float bd = range * range;
            foreach (var e in Query(p, range)) { if (e.def != null && e.def.behavior == "static") continue; if (e.downT > 0f) continue; if (exclude != null && exclude.Contains(e)) continue; float d = (e.pos - p).sqrMagnitude; if (e.IsBoss) d *= 0.2f; if (d < bd) { bd = d; best = e; } }   // 보스가 사거리 안이면 우선
            return best;
        }

        // ── 피해 ──
        // ── 적 탄환 차단: 플레이어의 공격이 닿은 탄환을 확률로 지운다. 탄환 하나에 무기마다 한 번만 굴린다. ──
        public int blocked;
        void BlockOne(EBullet b, float chance, int bit, Color col)
        {
            b.tried |= bit;
            if (rng.NextDouble() >= chance) return;
            b.dead = true; blocked++;
            Burst(b.pos, col, 4, 90f, 0.25f); Audio.Play("ui_move", 0.22f, 0.25f, 0.07f);
        }
        public void BlockBullets(Vector2 c, float r, float chance, int bit, Color col)
        {
            if (chance <= 0f || bullets.Count == 0) return;
            foreach (var b in bullets)
            {
                if (b.dead || (b.tried & bit) != 0) continue;
                float rr = r + b.radius; if ((b.pos - c).sqrMagnitude > rr * rr) continue;
                BlockOne(b, chance, bit, col);
            }
        }
        public void BlockBulletsLine(Vector2 a, Vector2 e, float halfW, float chance, int bit, Color col)
        {
            if (chance <= 0f || bullets.Count == 0) return;
            Vector2 ab = e - a; float len2 = ab.sqrMagnitude; if (len2 < 0.01f) return;
            foreach (var b in bullets)
            {
                if (b.dead || (b.tried & bit) != 0) continue;
                float f = Mathf.Clamp01(Vector2.Dot(b.pos - a, ab) / len2);
                if ((b.pos - (a + ab * f)).sqrMagnitude > (halfW + b.radius) * (halfW + b.radius)) continue;
                BlockOne(b, chance, bit, col);
            }
        }
        public void BlockBulletsArc(Vector2 c, float r, float a0, float halfDeg, float chance, int bit, Color col)
        {
            if (chance <= 0f || bullets.Count == 0) return;
            foreach (var b in bullets)
            {
                if (b.dead || (b.tried & bit) != 0) continue;
                Vector2 to = b.pos - c; if (to.sqrMagnitude > (r + b.radius) * (r + b.radius)) continue;
                if (Mathf.Abs(Mathf.DeltaAngle(Mathf.Atan2(to.y, to.x) * Mathf.Rad2Deg, a0 * Mathf.Rad2Deg)) > halfDeg) continue;
                BlockOne(b, chance, bit, col);
            }
        }

        // ── 매 틱 도는 곳에서 쓰는 임시 목록(새로 만들지 않는다). 쓰고 나면 FreeTmp ──
        readonly List<List<Enemy>> scratch = new List<List<Enemy>>(); int scratchDepth;
        public List<Enemy> QueryTmp(Vector2 p, float r)
        {
            if (scratchDepth >= scratch.Count) scratch.Add(new List<Enemy>(64));
            var l = scratch[scratchDepth++]; l.Clear(); l.AddRange(Query(p, r)); return l;
        }
        public void FreeTmp() { if (scratchDepth > 0) scratchDepth--; }

        public void Hit(Enemy e, float dmg, Vector2 dir, float knock, Color c)
        {
            if (e.dead || e.downT > 0f || e.invulnT > 0f) return;      // 쓰러져 있는 좀비·변신 중인 보스는 맞지 않는다
            if (e.def != null) dmg *= e.def.armor;
            if (e.bdef != null && e.bdef.softCap > 0f)
            {
                // 최종 보스: 초당 일정량(최대 체력의 softCap)까지만 온전히 들어가고, 넘치는 피해는 1/4만 — 빌드가 아무리 세도 패턴을 볼 수 있게
                float room = Mathf.Max(0f, e.maxHp * e.bdef.softCap - e.capAcc), full = Mathf.Min(dmg, room);
                e.capAcc += full; dmg = full + (dmg - full) * 0.25f;
            }
            e.hp -= dmg; e.flash = 0.12f;
            if (knock > 0f) e.knock += dir * knock * e.knockRes;
            if (Save.D.damageNumbers && !Dev.Has("nonums") && dmg >= 1f && nums.Count < 90) nums.Add(new DmgNum { pos = e.pos + new Vector2(UnityEngine.Random.Range(-8f, 8f), e.radius), value = Mathf.RoundToInt(dmg), color = c });
            if (e.hp <= 0f)
            {
                if (e.IsBoss && e.bdef.hp2 > 0f && !e.stage2) { BeginStage2(e); return; }          // 체력을 다 깎았다 → 죽지 않고 2단계로
                if (e.def != null && e.def.trait == "revive" && !e.revived)
                {
                    // 좀비 프로세스: 한 번은 쓰러졌다가 다시 일어난다
                    e.revived = true; e.downT = e.elite ? 1.6f : 1.2f; e.hp = e.maxHp * 0.5f; e.knock = Vector2.zero; e.infected = 0f;
                    Burst(e.pos, e.def.color, 6, 130f, 0.4f); Audio.Play("enemy_die", 0.3f, 0.2f, 0.05f);
                    return;
                }
                Kill(e);
            }
        }

        void Kill(Enemy e)
        {
            e.dead = true;
            Color c = e.IsBoss ? e.bdef.color : e.def.color;
            Burst(e.pos, c, e.IsBoss ? 60 : (e.elite ? 22 : 7), e.IsBoss ? 420f : 170f, e.IsBoss ? 1.1f : 0.5f);
            Ring(e.pos, c, e.radius * 0.6f, e.radius * (e.IsBoss ? 7f : 2.6f), e.IsBoss ? 0.9f : 0.35f, e.IsBoss ? 10f : 3f);
            if (e.def != null && e.def.id == "tipbox") { Drop(e.pos, rng.NextDouble() < 0.65 ? 1 : 2, 1); return; }
            kills++; ult = Mathf.Min(100f, ult + (e.IsBoss ? 100f : (e.elite ? 12f : 1.1f)));
            Audio.Play("enemy_die", 0.45f, 0.25f, 0.05f);
            Save.Discover(e.Id);
            if (ch.id == "raw264" && ++phago >= 10) { phago = 0; hp = Mathf.Min(maxHp, hp + 1f); }
            if (e.IsBoss)
            {
                bossKills++; bossDeadT = t; Audio.Play("boss_hit_big"); Shake(16f);
                foreach (var b in bullets) b.dead = true; tele.Clear(); sched.Clear(); pools.Clear();
                foreach (var o in enemies) if (!o.dead && !o.IsBoss) { o.dead = true; Burst(o.pos, o.def.color, 5, 120f, 0.4f); }
                Drop(e.pos, 3, 3);
                Toast(e.bdef.name + " 처치!");
                After(2.2f, () => Finish(true));
                return;
            }
            if (e.elite) Drop(e.pos, 3, 1); else if (e.xp > 0) Drop(e.pos, 0, e.xp);
            if (e.def.split != "") for (int i = 0; i < e.def.splitCount; i++) Spawn(e.def.split, e.pos + UnityEngine.Random.insideUnitCircle * 14f, false);
            if (e.def.trait == "pop")
            {
                // 기포가 터지며 사방으로 방울이 튄다(느리고 금방 사라진다)
                int n = e.elite ? 12 : 8; float a0 = UnityEngine.Random.value * 6.28f;
                for (int i = 0; i < n; i++) { float a = a0 + 6.2832f * i / n; Bullet(e.pos, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 125f, 6f, e.dmg * 0.5f, e.def.color, 1, 1.5f); }
                Ring(e.pos, e.def.color, e.radius * 0.5f, e.radius * 3.4f, 0.35f, 5f);
            }
            else if (e.def.trait == "unravel")
            {
                // 뭉치가 풀리며 짧은 조각들이 쏟아진다
                int n = e.elite ? 8 : 5;
                for (int i = 0; i < n; i++) { float a = 6.2832f * i / n; var fr = Spawn("mycoplasma", Clamp(e.pos + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 26f, 20f), false); fr.knock = new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 260f; fr.xp = 0; }
            }
            if (e.infected > 0f && e.infectSpread > 0)
            {
                int n = 0; var near = new List<Enemy>(Query(e.pos, 190f));
                foreach (var o in near) { if (o.dead || o.infected > 0f || o == e) continue; Infect(o, e.infectDps, e.pandemic ? e.infectSpread : e.infectSpread - 1, e.pandemic); Beam(e.pos, o.pos, 4f, DB.Teal, 0.2f); if (++n >= 3) break; }
            }
        }

        public void Infect(Enemy e, float dps, int spread, bool pandemic) { e.infected = 4f * pDuration; e.infectDps = Mathf.Max(e.infectDps, dps); e.infectSpread = spread; e.pandemic = pandemic; }

        void Drop(Vector2 p, int kind, int value)
        {
            if (kind == 0 && gems >= 450)
            {
                foreach (var g in pickups) if (g.kind == 0 && !g.dead && !g.attracted) { g.value += value; return; }
            }
            if (kind == 0) gems++;
            pickups.Add(new Pickup { kind = kind, value = value, pos = p, seed = UnityEngine.Random.value });
        }

        // ── 이펙트 ──
        public void Burst(Vector2 p, Color c, int n, float spd, float life)
        {
            for (int i = 0; i < n && parts.Count < 1400; i++)
            {
                Vector2 d = UnityEngine.Random.insideUnitCircle.normalized * UnityEngine.Random.Range(0.25f, 1f) * spd;
                parts.Add(new Particle { pos = p, vel = d, life = life * UnityEngine.Random.Range(0.6f, 1.1f), max = life, size = UnityEngine.Random.Range(3f, 7f), color = c, drag = 3.5f, shape = 3 });
            }
        }
        public void Ring(Vector2 p, Color c, float r0, float r1, float dur, float w) { fx.Add(new FxItem { type = 0, a = p, r0 = r0, r1 = r1, dur = dur, w = w, color = c }); }
        public void Beam(Vector2 a, Vector2 b, float w, Color c, float dur) { fx.Add(new FxItem { type = 1, a = a, b = b, w = w, dur = dur, color = c }); }
        public void Slash(Vector2 p, float ang, float r, Color c) { fx.Add(new FxItem { type = 2, a = p, ang = ang, r0 = r, dur = 0.2f, color = c }); }
        public void Strike(Vector2 p, float r, Color c) { fx.Add(new FxItem { type = 3, a = p, r0 = r, dur = 0.32f, color = c }); }
        void TickFx(float dt)
        {
            for (int i = fx.Count - 1; i >= 0; i--) { fx[i].t += dt; if (fx[i].t >= fx[i].dur) fx.RemoveAt(i); }
            for (int i = parts.Count - 1; i >= 0; i--)
            {
                var p = parts[i]; p.life -= dt;
                if (p.life <= 0f) { parts[i] = parts[parts.Count - 1]; parts.RemoveAt(parts.Count - 1); continue; }
                p.pos += p.vel * dt; p.vel *= Mathf.Exp(-p.drag * dt);
            }
            for (int i = nums.Count - 1; i >= 0; i--) { nums[i].t += dt; nums[i].pos.y += 38f * dt; if (nums[i].t > 0.6f) nums.RemoveAt(i); }
        }

        // ── 경고 표시 → 실제 공격 ──
        public void TeleCircle(Vector2 p, float r, float dur, Action cb, bool cross = false, Color col = default) { tele.Add(new Telegraph { type = 0, a = p, r = r, dur = dur, cb = cb, cross = cross, color = col }); }
        public void TeleLine(Vector2 a, Vector2 b, float w, float dur, Action cb, Color col = default) { tele.Add(new Telegraph { type = 1, a = a, b = b, r = w, dur = dur, cb = cb, color = col }); }
        void TickTele(float dt)
        {
            due.Clear();
            for (int i = tele.Count - 1; i >= 0; i--)
            {
                var q = tele[i]; q.t += dt;
                if (q.t >= q.dur) { tele.RemoveAt(i); if (q.cb != null) due.Add(q.cb); }
            }
            foreach (var a in due) a();
        }
        public void HazardCircle(Vector2 p, float r, float dmg, Color c)
        {
            Ring(p, c, r * 0.3f, r * 1.1f, 0.4f, 8f); Burst(p, c, 12, 220f, 0.45f);
            if ((pos - p).magnitude < r + DB.PlayerRadius * 0.7f) Hurt(dmg);
        }
        public void HazardLine(Vector2 a, Vector2 b, float w, float dmg, Color c)
        {
            Beam(a, b, w * 0.5f, c, 0.4f);
            Vector2 ab = b - a; float f = Mathf.Clamp01(Vector2.Dot(pos - a, ab) / ab.sqrMagnitude);
            if ((pos - (a + ab * f)).magnitude < w * 0.5f + DB.PlayerRadius * 0.7f) Hurt(dmg);
        }

        // ── 무기 / 시약 ──
        public Weapon GetWeapon(string id) { foreach (var w in weapons) if (w.def.id == id) return w; return null; }
        public void AddWeapon(string id, bool perk = true)
        {
            var w = Weapon.Create(id, this);
            if (perk && ch.id == "hek293t") w.level = 2;
            weapons.Add(w); Save.Discover(id);
        }

        public string Summary()
        {
            var sb = new System.Text.StringBuilder();
            sb.Append("t=").Append(t.ToString("0")).Append(" lv=").Append(level).Append(" hp=").Append(Mathf.CeilToInt(hp)).Append("/").Append((int)maxHp)
              .Append(" kills=").Append(kills).Append(" bosses=").Append(bossKills).Append(" enemies=").Append(enemies.Count).Append(" gems=").Append(gems)
              .Append(" view=").Append(viewN > 0 ? (int)(viewAcc / viewN) : 0).Append(" blocked=").Append(blocked).Append(" hits=").Append(hitsTaken).Append(" dmgIn=").Append((int)dmgTaken).Append(" ult=").Append((int)ult).Append(" fps=").Append((int)(1f / Mathf.Max(Time.unscaledDeltaTime, 0.0001f)))
              .Append(" boss=").Append(boss != null ? boss.bdef.id + (boss.stage2 ? "(stage2)" : "") + " " + (int)(boss.hp / boss.maxHp * 100f) + "%" : "-").Append(" weapons=");
            foreach (var w in weapons) sb.Append(w.def.id).Append(":").Append(w.level).Append(w.evolved ? "*" : "").Append(",");
            sb.Append(" passives=");
            foreach (var kv in passives) sb.Append(kv.Key).Append(":").Append(kv.Value).Append(",");
            if (!demo) sb.Append(" ").Append(Audio.Debug());
            if (bossSpawnT >= 0f) sb.Append(" bossFight=").Append((int)((bossDeadT >= 0f ? bossDeadT : t) - bossSpawnT)).Append("s");
            if (finished) sb.Append(victory ? " VICTORY" : " DEFEAT");
            viewAcc = 0f; viewN = 0;
            return sb.ToString();
        }
    }
}
