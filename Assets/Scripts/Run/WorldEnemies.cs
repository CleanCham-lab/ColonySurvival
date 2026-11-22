using System.Collections.Generic;
using UnityEngine;

namespace CS
{
    /// 스폰 디렉터 · 적 행동 · 보스 패턴 · 구역 기믹
    public partial class World
    {
        float Progress => Mathf.Clamp01(t / zone.length);

        void Director(float dt)
        {
            if (Dev.Has("gallery")) return;
            float prog = Progress;
            // 엘리트·포위 이벤트
            float[] marks = { 0.28f, 0.5f, 0.62f, 0.85f };
            if (eventIdx < marks.Length && prog >= marks[eventIdx])
            {
                if (eventIdx == 1)
                {
                    Toast(zone.swarmToast); Audio.Play("boss_warn", 0.6f);
                    for (int i = 0; i < 26; i++) Spawn("mycoplasma", Clamp(pos + new Vector2(Mathf.Cos(i * 0.2417f), Mathf.Sin(i * 0.2417f)) * 430f, 30f), false);
                }
                else
                {
                    string[] kinds = { "yeast", "phage", "biofilm" };
                    Spawn(kinds[Mathf.Min(eventIdx / 2 + (eventIdx == 3 ? 1 : 0), 2)], SpawnPos(), true);
                    Toast("엘리트 출현 — 노란 고리"); Audio.Play("boss_warn", 0.5f);
                }
                eventIdx++;
            }
            // 구역 보스
            if (!bossSpawned && t >= zone.length)
            {
                bossSpawned = true; bossSpawnT = t;
                foreach (var e in enemies) if (!e.dead) { e.dead = true; if (InView(e.pos, 60f)) Burst(e.pos, e.def.color, 4, 120f, 0.4f); if (e.xp > 0 && rng.NextDouble() < 0.35) Drop(e.pos, 0, e.xp); }
                foreach (var b in bullets) b.dead = true;
                Ring(pos, DB.Yellow, 30f, 900f, 1f, 8f);
                SpawnBoss(zone.boss);
            }
            // 일반 스폰
            var wave = DB.Waves[Mathf.Min((int)(prog * DB.Waves.Length), DB.Waves.Length - 1)];
            spawnT -= dt;
            if (spawnT <= 0f)
            {
                spawnT = wave.interval / (diff.spawn * DB.SpawnMul) * (bossSpawned ? 3f : 1f);
                int cap = bossSpawned ? 16 : (int)(wave.max * diff.spawn * DB.SpawnMul);
                int alive = enemies.Count;
                for (int i = 0; i < wave.batch && alive < cap; i++, alive++) Spawn(Pick(wave.pool), SpawnPos(), false);
            }
            tipT -= dt;
            if (tipT <= 0f)
            {
                tipT = Random.Range(32f, 46f) * diff.tip;
                Vector2 p = pos + Random.insideUnitCircle.normalized * Random.Range(250f, 430f);
                if (InBounds(p, 80f)) Spawn("tipbox", p, false);
            }
        }

        string Pick((string, int)[] pool)
        {
            int total = 0; foreach (var p in pool) total += p.Item2;
            int r = rng.Next(total);
            foreach (var p in pool) { r -= p.Item2; if (r < 0) return p.Item1; }
            return pool[0].Item1;
        }

        Vector2 SpawnPos()
        {
            float ring = ViewHalf.magnitude + 70f;
            for (int i = 0; i < 12; i++)
            {
                float a = Random.value * Mathf.PI * 2f;
                if (i < 6 && look.sqrMagnitude > 0.1f) a = Mathf.Atan2(look.y, look.x) + Random.Range(-1.3f, 1.3f);   // 가는 방향 앞쪽에 더 자주
                Vector2 p = pos + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * ring;
                if (InBounds(p, 40f)) return p;
            }
            return Clamp(pos + Random.insideUnitCircle.normalized * ring, 40f);
        }

        public Enemy Spawn(string id, Vector2 p, bool elite)
        {
            id = DB.Cast(zone, id);                   // 구역 3~5에서는 그 방에 맞는 적으로 바뀐다
            var d = DB.Enemy(id); float min = t / 60f;
            var e = new Enemy { def = d, pos = p, seed = Random.value, radius = d.radius, xp = d.xp, speed = d.speed * Random.Range(0.9f, 1.1f),
                maxHp = d.hp * DB.HpMul(min) * diff.hp * zone.tier, dmg = d.dmg * (1f + DB.DmgPerMin * min) * (1f + (zone.tier - 1f) * 0.35f), stateT = Random.Range(0.6f, 2.2f) };
            if (d.Base == "biofilm") e.knockRes = 0.35f;
            if (Dev.Has("gallery")) { e.speed = 0f; e.stateT = 999f; e.dmg = 0f; }
            if (elite) { e.elite = true; e.maxHp *= DB.EliteHp; e.radius *= DB.EliteScale; e.dmg *= 1.5f; e.xp *= 8; e.knockRes = 0.25f; }
            e.hp = e.maxHp;
            enemies.Add(e);
            return e;
        }

        void SpawnBoss(string id)
        {
            var d = DB.Boss(id);
            var b = new Enemy { bdef = d, boss = true, radius = d.radius, maxHp = d.hp * diff.boss, dmg = d.dmg, speed = d.speed, knockRes = 0f, seed = 0.37f, stateT = 1.6f };
            b.hp = b.maxHp;
            Vector2 dir = Random.insideUnitCircle.normalized;
            b.pos = Clamp(pos + dir * 340f, 120f);
            enemies.Add(b); boss = b; bossIntro = 2.2f;
            Shake(10f); if (!demo) { Audio.Play("boss_warn"); Audio.PlayMusic("boss", 2); }
            Toast(d.name + " — " + d.title);
        }

        void TickEnemies(float dt)
        {
            float pr = DB.PlayerRadius * 0.8f;
            for (int ei = 0, en = enemies.Count; ei < en; ei++)   // 도는 중에 새 적이 추가될 수 있어 인덱스로
            {
                var e = enemies[ei];
                if (e.dead) continue;
                e.flash = Mathf.Max(0f, e.flash - dt); e.poreCd -= dt; e.fieldCd -= dt; e.laserCd -= dt;
                if (e.infected > 0f)
                {
                    e.infected -= dt; e.infectAcc += dt;
                    if (e.infectAcc >= 0.5f) { e.infectAcc = 0f; Hit(e, e.infectDps * 0.5f, Vector2.zero, 0f, DB.Teal); if (e.dead) continue; }
                }
                if (e.downT > 0f)
                {
                    // 쓰러진 좀비 프로세스: 잠깐 꼼짝 않다가 다시 일어난다
                    e.downT -= dt;
                    if (e.downT <= 0f) { Ring(e.pos, e.def.color, e.radius * 0.4f, e.radius * 2.6f, 0.3f, 4f); e.flash = 0.12f; }
                    continue;
                }
                Vector2 to = pos - e.pos; float dist = to.magnitude; Vector2 dir = dist > 0.001f ? to / dist : Vector2.right;
                Vector2 v = Vector2.zero;
                if (e.IsBoss) { TickBoss(e, dt, dir, dist); v = e.vel; }
                else
                {
                    switch (e.def.behavior)
                    {
                        case "chase":
                            v = dir * e.speed;
                            if (e.def.move == "wobble")
                            {
                                // 저품질 리드: 좌우로 크게 비틀거린다
                                v += new Vector2(-dir.y, dir.x) * e.speed * 0.95f * Mathf.Sin(t * 5.5f + e.seed * 40f);
                            }
                            else if (e.def.move == "zigzag" && dist > 70f)
                            {
                                // 버그: 비스듬히 기어 오다가 0.6초마다 방향을 바꾼다
                                float sgn = (((int)(t * 1.6f + e.seed * 10f)) & 1) == 0 ? 1f : -1f;
                                v = (dir * 0.72f + new Vector2(-dir.y, dir.x) * 0.92f * sgn) * e.speed * 1.2f;
                            }
                            float fa = v.sqrMagnitude > 1f ? Mathf.Atan2(v.y, v.x) : Mathf.Atan2(dir.y, dir.x);
                            e.facing = Mathf.LerpAngle(e.facing * Mathf.Rad2Deg, fa * Mathf.Rad2Deg, 1f - Mathf.Exp(-6f * dt)) * Mathf.Deg2Rad;
                            break;
                        case "dash": v = TickDash(e, dt, dir, dist); break;
                        case "turret": v = TickTurret(e, dt, dir, dist); break;
                        case "spray": v = TickSpray(e, dt, dir, dist); break;
                        case "blink": v = TickBlink(e, dt, dir, dist); break;
                        case "snipe": v = TickSnipe(e, dt, dir, dist); break;
                        case "zigdash": v = TickZigDash(e, dt, dir, dist); break;
                    }
                    if (e.def.trait == "slow") { if (dist < WorldAuraR(e)) slowT = 0.12f; }
                    else if (e.def.trait == "leak")
                    {
                        // 메모리 누수: 지나간 자리에 웅덩이를 남긴다
                        e.auxT -= dt;
                        if (e.auxT <= 0f && pools.Count < 70) { e.auxT = 0.75f; float life = 3.4f; pools.Add(new EPool { pos = e.pos, r = e.elite ? 46f : 34f, life = life, maxLife = life, dmg = e.dmg * 0.45f, color = e.def.color }); }
                    }
                    // 서로 겹치지 않게
                    var cell = grid[GI(e.pos.y) * GN + GI(e.pos.x)];
                    for (int i = 0; i < cell.Count; i++)
                    {
                        var o = cell[i]; if (o == e || o.dead) continue;
                        Vector2 d = e.pos - o.pos; float rr = e.radius + o.radius; float l2 = d.sqrMagnitude;
                        if (l2 < rr * rr && l2 > 0.0001f) v += d / Mathf.Sqrt(l2) * 46f;
                    }
                }
                e.pos += (v + e.knock) * dt;
                e.knock *= Mathf.Exp(-7f * dt);
                if (!e.IsBoss || true) e.pos = Clamp(e.pos, e.radius * 0.5f);
                if (dist < e.radius + pr && e.dmg > 0f) Hurt(e.dmg, e.Id);
            }
        }

        Vector2 TickDash(Enemy e, float dt, Vector2 dir, float dist)
        {
            e.stateT -= dt;
            if (e.state == 0)
            {
                e.facing = Mathf.Atan2(dir.y, dir.x); e.charge = 0f;
                if (dist < 280f && e.stateT <= 0f) { e.state = 1; e.stateT = 0.65f; e.aim = dir; }
                return dir * e.speed;
            }
            if (e.state == 1)
            {
                e.charge = 1f - e.stateT / 0.65f;
                if (e.stateT <= 0f) { e.state = 2; e.stateT = 0.42f; }
                return Vector2.zero;
            }
            if (e.state == 2) { e.charge = 1f; if (e.stateT <= 0f) { e.state = 0; e.stateT = Random.Range(1.2f, 2.0f); } return e.aim * 540f; }
            return Vector2.zero;
        }

        Vector2 TickTurret(Enemy e, float dt, Vector2 dir, float dist)
        {
            e.stateT -= dt;
            e.charge = e.stateT < 0.6f ? 1f - e.stateT / 0.6f : 0f;
            string shot = e.def.shot; Color c = e.def.color;
            // 연사 중(회전 연사·잡음): 정해진 시간 동안 한 발씩 계속 쏜다
            if (e.auxT > 0f)
            {
                e.auxT -= dt; e.auxB += dt; e.charge = 1f;
                float step = shot == "noise" ? 0.085f : 0.105f;
                while (e.auxB >= step)
                {
                    e.auxB -= step;
                    if (shot == "noise")
                    {
                        // 막힌 포어: 방향도 빠르기도 제멋대로
                        float a = Random.value * 6.2832f;
                        Bullet(e.pos, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * Random.Range(85f, 200f), 5f, e.dmg * 0.8f, c, 3, 4.5f);
                    }
                    else
                    {
                        // 폴리G 웰: 돌면서 줄줄이
                        e.auxA += 0.40f;
                        int arms = e.elite ? 2 : 1;
                        for (int k = 0; k < arms; k++) { float a = e.auxA + 3.14159f * k; Bullet(e.pos, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 150f, 6f, e.dmg * 0.9f, c, 2, 5f); }
                    }
                }
            }
            if (e.stateT <= 0f)
            {
                e.stateT = 3.4f;
                if (dist < 620f)
                {
                    if (shot == "mortar")
                    {
                        // 오염된 NTC: 플레이어가 있는 자리로 던져 올린다. 떨어지기 전에 원이 먼저 보인다
                        int n = e.elite ? 3 : 1;
                        for (int k = 0; k < n; k++)
                        {
                            Vector2 lead = look.sqrMagnitude > 0.1f ? look.normalized * 45f : Vector2.zero;
                            Vector2 target = Clamp(pos + lead + (k == 0 ? Vector2.zero : Random.insideUnitCircle.normalized * 120f), 30f);
                            Beam(e.pos, target, 2.5f, c, 0.22f);
                            TeleCircle(target, 68f, 1.0f, () => { if (e.dead) return; HazardCircle(target, 68f, e.dmg, c); }, false, c);
                        }
                        e.stateT = 3.0f;
                    }
                    else if (shot == "stream") { e.auxT = 1.7f; e.auxB = 0f; e.auxA = Random.value * 6.28f; e.stateT = 4.2f; }
                    else if (shot == "noise") { e.auxT = 1.5f; e.auxB = 0f; e.stateT = 4.0f; }
                    else if (shot == "orbit")
                    {
                        // 무한 루프: 쏜 탄이 원을 그리며 포탑 둘레를 계속 맴돈다(가까이 가기 어렵다)
                        int n = e.elite ? 9 : 6; float a0 = Random.value * 6.28f; float w = (e.pattern++ % 2 == 0 ? 1f : -1f) * 1.05f;
                        for (int i = 0; i < n; i++) { float a = a0 + 6.2832f * i / n; Bullet(e.pos, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 150f, 6.5f, e.dmg, c, 3, 5.6f, w); }
                    }
                    else
                    {
                        int n = e.elite ? 12 : 8; float a0 = Random.value * 6.28f;
                        for (int i = 0; i < n; i++) { float a = a0 + 6.2832f * i / n; Bullet(e.pos, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 135f, 7f, e.dmg, DB.Yellow); }
                    }
                }
            }
            return dist > 300f ? dir * e.speed : Vector2.zero;
        }

        public const float SlowAuraR = 135f;
        public static float WorldAuraR(Enemy e) { return SlowAuraR * (e.elite ? 1.25f : 1f); }

        // ── 구역 전용 적의 공격 ──
        /// 에어로졸: 적당히 떨어져 멈춘 뒤, 숨을 모아 부채꼴로 잔방울을 뿜는다(멀리 가지 못한다)
        Vector2 TickSpray(Enemy e, float dt, Vector2 dir, float dist)
        {
            e.stateT -= dt;
            if (e.state == 0)
            {
                e.facing = Mathf.Atan2(dir.y, dir.x); e.charge = 0f;
                if (dist < 235f && e.stateT <= 0f) { e.state = 1; e.stateT = 0.6f; e.aim = dir; }
                return dist > 175f ? dir * e.speed * 1.3f : (dist < 115f ? -dir * e.speed * 0.6f : Vector2.zero);
            }
            e.charge = 1f - e.stateT / 0.6f;
            if (e.stateT <= 0f)
            {
                int n = e.elite ? 7 : 5; float a0 = Mathf.Atan2(e.aim.y, e.aim.x);
                for (int i = 0; i < n; i++) { float a = a0 + (i - (n - 1) * 0.5f) * 0.17f; Bullet(e.pos, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * Random.Range(185f, 245f), 5f, e.dmg * 0.6f, e.def.color, 1, 1.15f); }
                e.state = 0; e.stateT = Random.Range(2.2f, 3.0f); e.charge = 0f;
            }
            return Vector2.zero;
        }

        /// 인덱스 호핑: 플레이어 근처 한 점을 표시하고, 잠시 뒤 그 자리로 건너뛰어 덮친다
        Vector2 TickBlink(Enemy e, float dt, Vector2 dir, float dist)
        {
            e.stateT -= dt;
            if (e.state == 0)
            {
                e.facing = Mathf.Atan2(dir.y, dir.x); e.charge = 0f;
                if (dist < 420f && e.stateT <= 0f)
                {
                    Vector2 lead = look.sqrMagnitude > 0.1f ? look.normalized * 55f : Vector2.zero;
                    Vector2 target = Clamp(pos + lead + Random.insideUnitCircle * 42f, 30f);
                    float rr = e.elite ? 60f : 46f; Color c = e.def.color;
                    e.state = 1; e.stateT = 0.75f;
                    TeleCircle(target, rr, 0.75f, () =>
                    {
                        if (e.dead) return;
                        Ring(e.pos, c, 30f, 6f, 0.22f, 4f); e.pos = target; HazardCircle(target, rr, e.dmg, c);
                        e.state = 0; e.stateT = Random.Range(2.4f, 3.2f);
                    }, false, c);
                }
                return dir * e.speed * 0.9f;
            }
            e.charge = Mathf.Clamp01(1f - e.stateT / 0.75f);
            if (e.stateT < -0.5f) { e.state = 0; e.stateT = 1f; }       // 표시가 지워졌을 때(보스 처치 등)를 위한 안전장치
            return Vector2.zero;
        }

        /// 호모폴리머: 멀찍이 서서 조준선을 긋고, 잠시 뒤 그 선을 따라 한 줄로 쏜다
        Vector2 TickSnipe(Enemy e, float dt, Vector2 dir, float dist)
        {
            e.stateT -= dt;
            if (e.state == 0)
            {
                e.facing = Mathf.Atan2(dir.y, dir.x); e.charge = 0f;
                if (dist < 430f && e.stateT <= 0f && InView(e.pos, -20f))
                {
                    float w = e.elite ? 30f : 22f; Color c = e.def.color;
                    e.state = 1; e.stateT = 0.85f; e.aim = dir; e.auxP = e.pos;
                    TeleLine(e.pos, e.pos + dir * 640f, w, 0.85f, () =>
                    {
                        if (e.dead) return;
                        HazardLine(e.auxP, e.auxP + e.aim * 640f, w, e.dmg, c); Audio.Play("boss_hit_big", 0.18f, 0.2f);
                        e.state = 2; e.stateT = 0.35f;
                    }, c);
                }
                return dist > 330f ? dir * e.speed * 1.2f : (dist < 215f ? -dir * e.speed * 0.8f : Vector2.zero);
            }
            if (e.state == 1) { e.charge = Mathf.Clamp01(1f - e.stateT / 0.85f); if (e.stateT < -0.5f) { e.state = 0; e.stateT = 1f; } return Vector2.zero; }
            e.charge = 1f;
            if (e.stateT <= 0f) { e.state = 0; e.stateT = Random.Range(2.6f, 3.4f); }
            return Vector2.zero;
        }

        /// 세그폴트: 짧게 세 번 튄다. 튈 때마다 플레이어 쪽에서 살짝 빗나간 방향으로 꺾는다
        Vector2 TickZigDash(Enemy e, float dt, Vector2 dir, float dist)
        {
            e.stateT -= dt;
            if (e.state == 0)
            {
                e.facing = Mathf.Atan2(dir.y, dir.x); e.charge = 0f;
                if (dist < 300f && e.stateT <= 0f) { e.state = 1; e.stateT = 0.5f; e.auxA = 0f; }
                return dir * e.speed;
            }
            if (e.state == 1)
            {
                e.charge = 1f - e.stateT / 0.5f;
                if (e.stateT <= 0f) NextZig(e, dir);
                return Vector2.zero;
            }
            e.charge = 1f;
            if (e.stateT <= 0f)
            {
                if (e.auxA >= 3f) { e.state = 0; e.stateT = Random.Range(1.5f, 2.3f); return Vector2.zero; }
                NextZig(e, dir);
            }
            return e.aim * 520f;
        }
        void NextZig(Enemy e, Vector2 dir)
        {
            float side = (((int)e.auxA & 1) == 0 ? 1f : -1f) * (e.seed > 0.5f ? 1f : -1f);
            float a = Mathf.Atan2(dir.y, dir.x) + side * 0.62f;
            e.aim = new Vector2(Mathf.Cos(a), Mathf.Sin(a)); e.facing = a; e.state = 2; e.stateT = 0.2f; e.auxA += 1f;
            Burst(e.pos, e.def.color, 3, 90f, 0.2f);
        }

        public void Bullet(Vector2 p, Vector2 v, float r, float dmg, Color c, int kind = 0, float life = 7f, float turn = 0f)
        { if (bullets.Count < 500) bullets.Add(new EBullet { pos = p, vel = v, radius = r, dmg = dmg, life = life, color = c, kind = kind, turn = turn }); }

        // ── 보스 ──
        void TickBoss(Enemy b, float dt, Vector2 dir, float dist)
        {
            if (bossIntro > 0f) { bossIntro -= dt; b.vel = Vector2.zero; return; }
            if (b.invulnT > 0f)
            {
                // 2단계로 변신하는 중: 움직이지 않고, 맞지 않고, 체력 줄이 다시 차오른다
                b.invulnT -= dt; b.vel = Vector2.zero; b.charge = 1f;
                b.hp = Mathf.Min(b.maxHp, b.hp + b.maxHp * dt / Stage2Time);
                if (b.invulnT <= 0f)
                {
                    b.hp = b.maxHp; b.capAcc = 0f; b.stateT = 0.9f; Shake(14f); Audio.Play("boss_warn", 0.9f);
                    Ring(b.pos, b.bdef.color, 30f, 700f, 0.8f, 12f); Ring(b.pos, DB.White, 20f, 520f, 0.6f, 6f);
                    Toast(b.bdef.name + "  ·  " + b.bdef.title2);
                }
                return;
            }
            if (b.bdef.softCap > 0f) b.capAcc = Mathf.Max(0f, b.capAcc - b.maxHp * b.bdef.softCap * dt);
            if (b.bdef.id == "reviewer2" || b.bdef.id == "reviewer1") { TickReviewer(b, dt, dir, dist); return; }
            if (b.bdef.id == "adapter_dimer") { TickDimer(b, dt, dir, dist); return; }
            if (b.bdef.id == "concatemer") { TickSnake(b, dt, dir, dist); return; }
            if (!b.phase2 && b.hp < b.maxHp * 0.5f)
            {
                b.phase2 = true; Shake(8f); Audio.Play("boss_warn", 0.7f);
                if (b.bdef.id == "mold_wreath") { Toast("포자낭이 돋아난다!"); for (int i = 0; i < 4; i++) Spawn("spore_pod", Clamp(b.pos + new Vector2(Mathf.Cos(i * 1.571f), Mathf.Sin(i * 1.571f)) * 210f, 40f), false); }
                else Toast(b.bdef.name + " 분노!");
            }
            b.stateT -= dt;
            if (b.bdef.id == "mold_wreath")
            {
                b.vel = dist > 150f ? dir * b.speed : Vector2.zero;
                b.facing += dt * 0.35f;
                if (b.stateT > 0f) return;
                if (b.pattern++ % 2 == 0)
                {
                    // 포자 고리: 틈 한 곳
                    int n = b.phase2 ? 30 : 24; float gap = Random.value * 6.2832f;
                    TeleCircle(b.pos, b.radius + 26f, 0.7f, () =>
                    {
                        if (b.dead) return;
                        for (int i = 0; i < n; i++) { float a = 6.2832f * i / n; if (Mathf.Abs(Mathf.DeltaAngle(a * Mathf.Rad2Deg, gap * Mathf.Rad2Deg)) < 26f) continue; Bullet(b.pos + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * b.radius * 0.8f, new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 150f, 8f, 12f, DB.Orange); }
                        Audio.Play("boss_hit_big", 0.4f);
                    });
                }
                else
                {
                    // 균사 뻗기
                    int n = b.phase2 ? 5 : 3; float baseA = Mathf.Atan2(dir.y, dir.x);
                    for (int i = 0; i < n; i++)
                    {
                        float a = baseA + (i - (n - 1) * 0.5f) * 0.3f;
                        Vector2 from = b.pos, to = b.pos + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 620f;
                        TeleLine(from, to, 36f, 0.95f, () => { if (!b.dead) HazardLine(from, to, 36f, 18f, DB.Orange); });
                    }
                }
                b.stateT = b.phase2 ? 1.7f : 2.4f;
            }
            else
            {
                // 크람푸스 파지: 3연속 돌진 / 착지 / 꼬리 섬유
                if (b.state == 1) { b.vel = b.aim * 760f; b.charge = 1f; if (b.stateT <= 0f) { b.state = 0; b.stateT = 0.25f; } return; }
                if (b.state == 2) { b.vel = Vector2.zero; b.charge = Mathf.Min(1f, b.charge + dt * 1.6f); return; }   // 조준 중
                b.facing = Mathf.Atan2(dir.y, dir.x); b.charge = 0f;
                b.vel = dist > 240f ? dir * b.speed : Vector2.zero;
                if (b.stateT > 0f) return;
                int pat = b.pattern % (b.phase2 ? 6 : 5);
                if (pat < 3)
                {
                    Vector2 from = b.pos, aim = dir, to = Clamp(b.pos + dir * 520f, 30f);
                    b.state = 2; b.pattern++;
                    TeleLine(from, to, 60f, b.phase2 ? 0.5f : 0.62f, () => { if (b.dead) return; b.state = 1; b.aim = aim; b.stateT = 0.66f; });
                }
                else if (pat == 3)
                {
                    Vector2 target = pos; b.pattern++; b.stateT = 1.7f;
                    TeleCircle(target, 150f, 0.95f, () => { if (b.dead) return; b.pos = target; HazardCircle(target, 150f, 24f, DB.Mag); Shake(10f); });
                }
                else
                {
                    b.pattern++; b.stateT = 1.4f;
                    for (int i = 0; i < 5; i++) { float a = Mathf.Atan2(dir.y, dir.x) + (i - 2) * 0.35f; var p = Spawn("phage", b.pos + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 80f, false); p.stateT = 0.2f; }
                }
            }
        }

        // ── 최종 보스 Reviewer #2: 코멘트 탄막 · REJECT 도장 · 추가 실험(십자 레이저) · 데스크 리젝트(나선) ──
        static readonly string[] ReviewerLines =
        {
            "Comment 1: n수가 부족합니다.", "Comment 2: 대조군이 적절하지 않습니다.", "Comment 3: 통계 분석을 다시 하십시오.",
            "Comment 4: 선행 연구 인용이 부족합니다.", "Comment 5: 그림 해상도가 낮습니다.", "Comment 6: 영문 교정이 필요합니다.",
            "Comment 7: 임상적 의의가 불분명합니다.", "Comment 8: 결론이 데이터로 뒷받침되지 않습니다.", "Comment 9: 제 논문을 인용하십시오.",
        };

        static readonly string[] Reviewer1Lines =
        {
            "Minor comment: 오타가 있습니다.", "참고문헌 12번의 형식을 확인해 주십시오.", "흥미로운 연구입니다. 다만…", "Figure 2의 축 레이블이 작습니다.",
            "약어는 처음 나올 때 풀어 써 주십시오.", "Supplementary Table이 본문에서 언급되지 않습니다.", "방법 섹션에 시약 카탈로그 번호를 적어 주십시오.",
        };

        const float Stage2Time = 3.2f;
        /// 체력을 다 깎인 보스가 죽지 않고 2단계로 넘어간다(Reviewer #2). 탄과 졸개를 모두 걷어 내고, 체력 줄을 새로 채운다.
        public void BeginStage2(Enemy b)
        {
            b.stage2 = true; b.invulnT = Stage2Time; b.hp = 1f; b.maxHp = b.bdef.hp2 * diff.boss; b.capAcc = 0f;
            b.phase2 = true; b.phase3 = true; b.state = 0; b.pattern = 0; b.vel = Vector2.zero; b.knock = Vector2.zero; b.radius *= 1.14f; b.infected = 0f;
            foreach (var bl in bullets) bl.dead = true; tele.Clear(); sched.Clear(); pools.Clear();
            foreach (var o in enemies) if (!o.dead && !o.IsBoss) { o.dead = true; Burst(o.pos, o.def.color, 5, 120f, 0.4f); }
            Shake(18f); Audio.Play("boss_hit_big"); Audio.Play("boss_warn", 0.8f);
            Ring(b.pos, b.bdef.color, 30f, 620f, 0.8f, 10f); Burst(b.pos, b.bdef.color, 40, 380f, 1.0f);
            Drop(b.pos + new Vector2(0f, -90f), 1, 1);                    // 숨 돌릴 코코아 한 잔
            Toast("Reviewer #2: \"…Reject.\"");
            After(1.5f, () => { if (!b.dead && !finished) Toast("Reviewer #2: \"재투고는 받아 드리죠. 다시 봅시다.\""); });
        }

        void TickReviewer(Enemy b, float dt, Vector2 dir, float dist)
        {
            bool r1 = b.bdef.id == "reviewer1"; Color bc = b.bdef.color;      // Reviewer #1 = 순한 버전(2페이즈까지, 탄 수 적음)
            if (!b.phase2 && b.hp < b.maxHp * 0.5f)
            {
                b.phase2 = true; b.stateT = 1.4f; b.state = 0; Shake(10f); Audio.Play("boss_warn", 0.7f);
                foreach (var bl in bullets) bl.dead = true;
                Ring(b.pos, bc, 30f, 520f, 0.7f, 8f); Toast(r1 ? "Reviewer #1: \"흥미롭습니다. 다만 NGS 데이터가 있으면 좋겠군요.\"" : "Reviewer #2: \"추가 실험이 필요합니다.\"  — Major Revision");
            }
            // Reviewer #2의 3번째 패턴 묶음은 2단계(BeginStage2)에서 시작한다. 2단계에서 체력이 40% 아래로 내려가면 마지막 폭주
            if (b.stage2 && !b.enraged && b.hp < b.maxHp * 0.4f)
            {
                b.enraged = true; b.stateT = 1.2f; b.state = 0; Shake(12f); Audio.Play("boss_warn", 0.8f);
                foreach (var bl in bullets) bl.dead = true;
                Ring(b.pos, bc, 30f, 620f, 0.8f, 10f); Toast("Reviewer #2: \"이 연구는 본 저널의 범위를 벗어납니다.\"");
            }
            // 플레이어와 거리를 두고 옆으로 흐른다
            Vector2 side = new Vector2(-dir.y, dir.x) * Mathf.Sin(t * 0.55f);
            b.vel = (dir * Mathf.Clamp((dist - 235f) / 90f, -1f, 1f) + side * 0.7f) * b.speed * (b.phase3 ? 1.3f : 1f);
            if (!InView(b.pos, -70f)) b.vel = dir * b.speed * 3.2f;          // 화면 밖으로 밀려나면 서둘러 돌아온다
            b.charge = b.phase3 ? 1f : (b.phase2 ? 0.5f : 0f);
            if (b.state == 3)
            {
                // 나선 탄막
                b.vel *= 0.25f; b.bossA -= dt; b.bossC += dt;
                int arms = b.phase3 ? 3 : 2;
                while (b.bossC >= 0.085f)
                {
                    b.bossC -= 0.085f; b.bossB += 0.21f;
                    for (int i = 0; i < arms; i++) { float a = b.bossB + 6.2832f * i / arms; Vector2 d = new Vector2(Mathf.Cos(a), Mathf.Sin(a)); Bullet(b.pos + d * b.radius * 0.5f, d * 165f, 7f, 12f, bc); }
                }
                if (b.bossA <= 0f) { b.state = 0; b.stateT = 1.3f; }
                return;
            }
            b.stateT -= dt;
            if (b.stateT > 0f) return;
            float cool = b.enraged ? 1.15f : (b.phase3 ? 1.5f : (b.phase2 ? 2.0f : 2.4f));
            string[] seq = r1 ? (b.phase2 ? new[] { "fan", "cross", "stamps", "minions" } : new[] { "fan", "stamps", "ring" }) : b.phase3 ? new[] { "spiral", "stamps", "cross", "fan", "blink" } : (b.phase2 ? new[] { "fan", "cross", "stamps", "minions", "ring" } : new[] { "fan", "stamps", "ring" });
            string pat = seq[b.pattern++ % seq.Length];
            if (rng.NextDouble() < 0.4) { int qi = (int)b.bossC2; var lines = r1 ? Reviewer1Lines : ReviewerLines; qi = (qi + 1 + rng.Next(lines.Length - 1)) % lines.Length; b.bossC2 = qi; Toast(lines[qi]); }
            switch (pat)
            {
                case "fan":
                    for (int k = 0; k < 3; k++)
                        After(k * 0.36f, () =>
                        {
                            if (b.dead || finished) return;
                            Vector2 d = (pos - b.pos).normalized; float a0 = Mathf.Atan2(d.y, d.x); int n = r1 ? 5 : (b.phase3 ? 9 : 7);
                            for (int i = 0; i < n; i++) { float a = a0 + (i - (n - 1) * 0.5f) * 0.16f; Vector2 u = new Vector2(Mathf.Cos(a), Mathf.Sin(a)); Bullet(b.pos + u * b.radius * 0.6f, u * 205f, 7f, 12f, bc); }
                            Audio.Play("boss_hit_big", 0.25f, 0.1f);
                        });
                    b.stateT = 1.1f + cool; break;
                case "stamps":
                    {
                        int n = b.phase3 ? 5 : (b.phase2 ? 4 : 3);
                        for (int k = 0; k < n; k++)
                            After(k * 0.42f, () =>
                            {
                                if (b.dead || finished) return;
                                Vector2 target = Clamp(pos + Random.insideUnitCircle * 40f, 30f);
                                TeleCircle(target, 112f, 0.8f, () => { if (b.dead) return; HazardCircle(target, 112f, 22f, bc); Shake(5f); Audio.Play("boss_hit_big", 0.35f, 0.1f); }, !r1);
                            });
                        b.stateT = n * 0.42f + 0.6f + cool; break;
                    }
                case "ring":
                    for (int k = 0; k < 2; k++)
                    {
                        float off = k * 0.5f, gap = Random.value * 6.2832f + k * 1.5708f;
                        After(k * 0.65f, () =>
                        {
                            if (b.dead || finished) return;
                            int n = 30;
                            for (int i = 0; i < n; i++)
                            {
                                float a = 6.2832f * (i + off) / n;
                                if (Mathf.Abs(Mathf.DeltaAngle(a * Mathf.Rad2Deg, gap * Mathf.Rad2Deg)) < 17f || Mathf.Abs(Mathf.DeltaAngle(a * Mathf.Rad2Deg, gap * Mathf.Rad2Deg + 180f)) < 17f) continue;
                                Vector2 u = new Vector2(Mathf.Cos(a), Mathf.Sin(a)); Bullet(b.pos + u * b.radius * 0.7f, u * 140f, 8f, 12f, bc);
                            }
                            Audio.Play("boss_hit_big", 0.3f);
                        });
                    }
                    b.stateT = 0.8f + cool; break;
                case "cross":
                    {
                        Vector2 c0 = b.pos; float a0 = Random.value * 1.5708f;
                        for (int k = 0; k < (r1 ? 1 : 2); k++)
                        {
                            float ak = a0 + k * 0.7854f;
                            After(k * 0.75f, () =>
                            {
                                if (b.dead || finished) return;
                                for (int i = 0; i < 2; i++)
                                {
                                    float a = ak + i * 1.5708f; Vector2 u = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                                    Vector2 from = c0 - u * 760f, to = c0 + u * 760f;
                                    TeleLine(from, to, 44f, 0.9f, () => { if (!b.dead) { HazardLine(from, to, 44f, 20f, bc); Shake(4f); } });
                                }
                            });
                        }
                        b.stateT = 1.9f + cool; break;
                    }
                case "minions":
                    Toast("공동 심사위원 등장!");
                    for (int i = 0; i < 2; i++) Spawn("co_reviewer", Clamp(b.pos + new Vector2(i == 0 ? -110f : 110f, 0f), 40f), true);
                    for (int i = 0; i < 6; i++) { float a = i * 1.047f; Spawn("comment", Clamp(b.pos + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * 150f, 40f), false); }
                    b.stateT = cool; break;
                case "spiral":
                    b.state = 3; b.bossA = 3.2f; b.bossB = Random.value * 6.28f; b.bossC = 0f; break;
                case "blink":
                    {
                        Vector2 target = Clamp(pos + Random.insideUnitCircle.normalized * 300f, 120f);
                        TeleCircle(target, 96f, 0.7f, () =>
                        {
                            if (b.dead) return;
                            Ring(b.pos, bc, 20f, 160f, 0.3f, 6f); b.pos = target; Ring(target, bc, 160f, 20f, 0.3f, 6f); Shake(6f);
                            for (int i = 0; i < 14; i++) { float a = 6.2832f * i / 14f; Vector2 u = new Vector2(Mathf.Cos(a), Mathf.Sin(a)); Bullet(target + u * 40f, u * 150f, 7f, 12f, bc); }
                        });
                        b.stateT = 0.9f + cool; break;
                    }
            }
        }

        // ── 4구역 보스 Adapter Dimer: 양 끝에 어댑터가 달린 팔이 돈다. PCR 증폭(2배씩 증식) · 클러스터 생성 · 리드 버스트 · 인덱스 호핑 ──
        void TickDimer(Enemy b, float dt, Vector2 dir, float dist)
        {
            if (!b.phase2 && b.hp < b.maxHp * 0.55f) { b.phase2 = true; Shake(9f); Audio.Play("boss_warn", 0.7f); Ring(b.pos, DB.Orange, 30f, 480f, 0.6f, 8f); Toast("Adapter Dimer: 라이게이션 폭주 — 팔이 길어진다"); }
            if (!b.phase3 && b.hp < b.maxHp * 0.25f) { b.phase3 = true; Shake(11f); Audio.Play("boss_warn", 0.8f); Ring(b.pos, DB.Cyan, 30f, 560f, 0.7f, 9f); Toast("Adapter Dimer: 콘카테머 형성 — 팔이 넷"); }
            if (b.bossB == 0f) { b.bossB = 1f; b.bossC = 50f; }
            b.bossA += (b.phase3 ? 0.95f : (b.phase2 ? 1.05f : 0.85f)) * b.bossB * dt;
            float L = b.phase3 ? 235f : (b.phase2 ? 300f : 215f); int arms = b.phase3 ? 4 : 2;
            b.bossC = Mathf.MoveTowards(b.bossC, L, dt * 130f);
            for (int i = 0; i < arms; i++)
            {
                float a = b.bossA + 6.2832f * i / arms; Vector2 u = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                Vector2 p0 = b.pos + u * (b.radius * 0.6f), p1 = b.pos + u * b.bossC, ab = p1 - p0;
                float f = Mathf.Clamp01(Vector2.Dot(pos - p0, ab) / Mathf.Max(ab.sqrMagnitude, 1f));
                if ((pos - (p0 + ab * f)).magnitude < 12f + DB.PlayerRadius * 0.7f || (pos - p1).magnitude < 24f + DB.PlayerRadius * 0.7f) Hurt(18f, "dimer_arm");
            }
            b.vel = dist > 150f ? dir * b.speed * (b.phase2 ? 1.15f : 1f) : Vector2.zero;
            b.stateT -= dt;
            if (b.stateT > 0f) return;
            float cool = b.phase3 ? 1.6f : (b.phase2 ? 2.1f : 2.6f);
            switch (b.pattern++ % 4)
            {
                case 0:   // PCR 증폭: 2 → 4 → 8
                    Toast("PCR 증폭 — 다이머가 두 배씩 늘어난다");
                    for (int k = 0; k < 3; k++)
                    {
                        int n = 2 << k; float rad = 90f + k * 42f;
                        After(k * 0.7f, () =>
                        {
                            if (b.dead || finished) return;
                            for (int i = 0; i < n; i++) { float a = 6.2832f * i / n + b.bossA; Spawn("mycoplasma", Clamp(b.pos + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * rad, 30f), false); }
                            Ring(b.pos, DB.Orange, 20f, rad + 30f, 0.35f, 5f);
                        });
                    }
                    b.stateT = 1.4f + cool; break;
                case 1:   // 클러스터 생성: 3×3 격자, 한 칸은 비운다
                    {
                        Vector2 c0 = pos; int safe = rng.Next(9);
                        for (int j = -1; j <= 1; j++)
                            for (int i = -1; i <= 1; i++)
                            {
                                if ((j + 1) * 3 + (i + 1) == safe) continue;
                                Vector2 c = Clamp(c0 + new Vector2(i, j) * 150f, 20f);
                                TeleCircle(c, 66f, 1.0f, () => { if (!b.dead) HazardCircle(c, 66f, 20f, DB.Cyan); });
                            }
                        b.stateT = 1.2f + cool; break;
                    }
                case 2:   // 리드 버스트: 조준 연사
                    for (int k = 0; k < (b.phase2 ? 14 : 10); k++)
                        After(k * 0.1f, () =>
                        {
                            if (b.dead || finished) return;
                            Vector2 d = (pos - b.pos).normalized; float a = Mathf.Atan2(d.y, d.x) + Random.Range(-0.09f, 0.09f); Vector2 u = new Vector2(Mathf.Cos(a), Mathf.Sin(a));
                            Bullet(b.pos + u * b.radius * 0.6f, u * 235f, 7f, 12f, DB.Orange);
                        });
                    b.stateT = 1.4f + cool; break;
                default:  // 인덱스 호핑: 순간이동 + 회전 방향 반전
                    {
                        Vector2 target = Clamp(pos + Random.insideUnitCircle.normalized * 270f, 120f);
                        TeleCircle(target, 90f, 0.75f, () =>
                        {
                            if (b.dead) return;
                            Ring(b.pos, DB.Cyan, 20f, 150f, 0.3f, 6f); b.pos = target; b.bossC = 50f; b.bossB = -b.bossB; Ring(target, DB.Orange, 150f, 20f, 0.3f, 6f); Shake(6f);
                            for (int i = 0; i < 12; i++) { float a = 6.2832f * i / 12f; Vector2 u = new Vector2(Mathf.Cos(a), Mathf.Sin(a)); Bullet(target + u * 40f, u * 150f, 7f, 12f, i % 2 == 0 ? DB.Cyan : DB.Orange); }
                        });
                        b.stateT = 0.9f + cool; break;
                    }
            }
        }

        // ── 4구역 롱리드 보스 Concatemer: 머리만 맞는다. 몸통은 머리가 지나간 길을 따라오고, 체력이 깎일수록 짧아진다. ──
        public int SnakeSegs(Enemy b) { return 8 + Mathf.RoundToInt(26f * Mathf.Clamp01(b.hp / b.maxHp)); }
        void TickSnake(Enemy b, float dt, Vector2 dir, float dist)
        {
            if (!b.phase2 && b.hp < b.maxHp * 0.5f) { b.phase2 = true; Shake(9f); Audio.Play("boss_warn", 0.7f); Ring(b.pos, DB.Violet, 30f, 480f, 0.6f, 8f); Toast("Concatemer: 폴리머라제 폭주 — 더 빨라진다"); }
            if (b.aim == Vector2.zero) b.aim = dir;
            float sp = b.state == 1 ? 340f : (b.phase2 ? 205f : 168f), turn = b.state == 1 ? 0.4f : (b.phase2 ? 2.0f : 1.7f);
            Vector2 goal = InBounds(b.pos, 80f) ? dir : (-b.pos).normalized;
            float cur = Mathf.MoveTowardsAngle(Mathf.Atan2(b.aim.y, b.aim.x) * Mathf.Rad2Deg, Mathf.Atan2(goal.y, goal.x) * Mathf.Rad2Deg, turn * Mathf.Rad2Deg * dt) * Mathf.Deg2Rad;
            b.aim = new Vector2(Mathf.Cos(cur), Mathf.Sin(cur)); b.vel = b.aim * sp; b.facing = cur;
            if (snakeTrail.Count == 0 || (snakeTrail[0] - b.pos).sqrMagnitude > 36f) { snakeTrail.Insert(0, b.pos); if (snakeTrail.Count > 180) snakeTrail.RemoveAt(snakeTrail.Count - 1); }
            int segs = SnakeSegs(b);
            for (int i = 1; i <= segs; i++)
            {
                int ti = i * 4; if (ti >= snakeTrail.Count) break;
                if ((pos - snakeTrail[ti]).magnitude < 12f + DB.PlayerRadius * 0.7f) { Hurt(16f, "concatemer_body"); break; }
            }
            if (b.state == 1) { b.bossA -= dt; if (b.bossA <= 0f) b.state = 0; }
            b.stateT -= dt;
            if (b.stateT > 0f) return;
            if (b.pattern++ % 2 == 0)
            {
                // 키네틱스 펄스: 몸통 마디에서 양옆으로 탄이 나간다
                for (int i = 3; i <= segs; i += b.phase2 ? 3 : 4)
                {
                    int ti = i * 4; if (ti >= snakeTrail.Count) break;
                    Vector2 p = snakeTrail[ti], d = (snakeTrail[ti - 2] - p).normalized, n = new Vector2(-d.y, d.x);
                    Bullet(p, n * 115f, 6f, 11f, DB.Violet); Bullet(p, -n * 115f, 6f, 11f, DB.Violet);
                }
                Audio.Play("boss_hit_big", 0.3f);
                b.stateT = b.phase2 ? 2.6f : 3.4f;
            }
            else
            {
                // 리드 스루: 조준선을 보여 준 뒤 곧게 돌진
                Vector2 from = b.pos, to = Clamp(b.pos + dir * 600f, 30f);
                TeleLine(from, to, 50f, 0.7f, () => { if (b.dead) return; Vector2 d = to - b.pos; if (d.sqrMagnitude > 1f) b.aim = d.normalized; b.state = 1; b.bossA = 1.3f; });
                b.stateT = b.phase2 ? 3.0f : 3.8f;
            }
        }

        // ── 시퀀싱실(롱리드): 아주 긴 리드 다섯 가닥이 비스듬히 지나간다. 같은 자리를 세 번 읽는다(CCS). ──
        void TickLongReads(float dt)
        {
            if (boss != null || bossSpawned) return;
            lrT -= dt; if (lrT > 0f) return;
            lrT = Random.Range(17f, 23f);
            Toast("롱리드 통과 — 같은 자리를 세 번 읽는다 (CCS)"); Audio.Play("boss_warn", 0.45f);
            float ang = (Random.value < 0.5f ? 1f : -1f) * (Random.value < 0.5f ? 0.35f : 1.2f), off = Random.Range(-60f, 60f);
            Vector2 u = new Vector2(Mathf.Cos(ang), Mathf.Sin(ang)), nrm = new Vector2(-u.y, u.x), c0 = pos;
            for (int k = -2; k <= 2; k++)
            {
                Vector2 c = c0 + nrm * (k * 185f + off), from = c - u * 1100f, to = c + u * 1100f;
                TeleLine(from, to, 36f, 1.3f + (k + 2) * 0.12f, () =>
                {
                    for (int p = 0; p < 3; p++)
                        After(p * 0.55f, () =>
                        {
                            if (finished) return;
                            HazardLine(from, to, 36f, 16f, DB.Violet);
                            Vector2 ab = to - from;
                            foreach (var e in new List<Enemy>(enemies))
                            {
                                if (e.dead) continue;
                                float f = Mathf.Clamp01(Vector2.Dot(e.pos - from, ab) / ab.sqrMagnitude);
                                if ((e.pos - (from + ab * f)).magnitude < 18f + e.radius) Hit(e, e.IsBoss ? e.maxHp * 0.005f : Mathf.Max(20f, e.maxHp * 0.2f), Vector2.zero, 0f, DB.Violet);
                            }
                        });
                });
            }
        }

        // ── PCR실: 온도 사이클. 플레이어 주변 웰이 달아올랐다가 세 번 끓는다(적도 맞는다). 웰 사이 통로는 안전하다. ──
        void TickThermal(float dt)
        {
            if (boss != null || bossSpawned) return;
            thermT -= dt; if (thermT > 0f) return;
            thermT = Random.Range(15f, 21f);
            Toast("변성 단계 95℃ — 달아오르는 칸에서 나와라"); Audio.Play("boss_warn", 0.45f);
            int ci = Mathf.RoundToInt(pos.x / 110f), cj = Mathf.RoundToInt(pos.y / 110f);
            for (int j = -3; j <= 3; j++)
                for (int i = -4; i <= 4; i++)
                {
                    if (!(i == 0 && j == 0) && Random.value > 0.4f) continue;
                    Vector2 c = new Vector2((ci + i) * 110f, (cj + j) * 110f);
                    if (!InBounds(c, 40f)) continue;
                    TeleCircle(c, 42f, 1.5f, () => { for (int k = 0; k < 2; k++) After(k * 0.7f, () => HotWell(c)); });
                }
        }
        void HotWell(Vector2 c)
        {
            if (finished) return;
            Ring(c, DB.Orange, 12f, 48f, 0.35f, 6f);
            if ((pos - c).magnitude < 40f + DB.PlayerRadius * 0.5f) Hurt(14f, "heat");
            foreach (var e in new List<Enemy>(Query(c, 44f))) if (!e.IsBoss) Hit(e, Mathf.Max(20f, e.maxHp * 0.2f), Vector2.zero, 0f, DB.Orange);
        }

        // ── 분석 서버실: 데이터 패킷이 타일 이음매(200 간격)를 따라 달린다. 가로·세로가 번갈아 온다. ──
        void TickPackets(float dt)
        {
            if (boss != null || bossSpawned) return;
            packT -= dt; if (packT > 0f) return;
            packT = Random.Range(10f, 14f); packHoriz = !packHoriz;
            if (!packTold) { packTold = true; Toast("데이터 패킷이 이음매를 따라 달린다 — 타일 안쪽에 서라"); }
            Audio.Play("boss_warn", 0.4f);
            int k0 = Mathf.RoundToInt((packHoriz ? pos.y : pos.x) / 200f);
            for (int k = -2; k <= 2; k++)
            {
                if (k != 0 && Random.value > (Mathf.Abs(k) == 1 ? 0.75f : 0.4f)) continue;
                float v = (k0 + k) * 200f; bool hz = packHoriz;
                if (Mathf.Abs(v) > (hz ? zone.size.y : zone.size.x) - 20f) continue;
                Vector2 from = hz ? new Vector2(-zone.size.x, v) : new Vector2(v, -zone.size.y), to = hz ? new Vector2(zone.size.x, v) : new Vector2(v, zone.size.y);
                TeleLine(from, to, 46f, 1.15f, () =>
                {
                    if (finished) return;
                    HazardLine(from, to, 46f, 16f, DB.Cyan);
                    foreach (var e in new List<Enemy>(enemies)) if (!e.dead && Mathf.Abs((hz ? e.pos.y : e.pos.x) - v) < 23f + e.radius) Hit(e, e.IsBoss ? e.maxHp * 0.01f : Mathf.Max(30f, e.maxHp * 0.35f), Vector2.zero, 0f, DB.Cyan);
                });
            }
        }

        // ── 시퀀싱실: 스캔 레이저(세로 줄이 화면을 가로질러 지나간다). 대시의 무적 시간으로 통과한다. ──
        void TickLaser(float dt)
        {
            if (laserState == 0)
            {
                if (boss != null || bossSpawned) return;
                laserT -= dt; if (laserT > 0f) return;
                laserDir = Random.value < 0.5f ? 1f : -1f;
                float hwv = ViewHalf.x + 60f;
                laserX = camPos.x - laserDir * hwv; laserEnd = camPos.x + laserDir * (hwv + 500f);
                laserState = 1; laserWarn = 1.7f;
                Toast("스캔 레이저! 대시(Space)로 통과하라 — 적도 맞는다"); Audio.Play("boss_warn", 0.5f);
                return;
            }
            if (laserState == 1) { laserWarn -= dt; if (laserWarn <= 0f) { laserState = 2; Shake(4f); } return; }
            float prev = laserX; laserX += laserDir * 340f * dt;
            float lo = Mathf.Min(prev, laserX) - 12f, hi = Mathf.Max(prev, laserX) + 12f;
            if (pos.x > lo - DB.PlayerRadius * 0.6f && pos.x < hi + DB.PlayerRadius * 0.6f) Hurt(20f, "laser");
            foreach (var e in new List<Enemy>(enemies))
                if (!e.dead && e.pos.x > lo && e.pos.x <= hi && e.laserCd <= 0f) { e.laserCd = 0.5f; Hit(e, e.IsBoss ? e.maxHp * 0.02f : Mathf.Max(40f, e.maxHp * 0.5f), Vector2.zero, 0f, DB.Green); }
            if ((laserX - laserEnd) * laserDir > 0f) { laserState = 0; laserT = Random.Range(24f, 34f); }
        }

        // ── 클린벤치: 층류 + UV 램프 ──
        void TickAirflow(float dt)
        {
            Vector2 drift = new Vector2(0f, -42f) * dt;
            pos = Clamp(pos + drift, DB.PlayerRadius);
            foreach (var e in enemies) if (!e.dead && !e.IsBoss && e.def.behavior != "static") e.pos += drift;
            foreach (var b in bullets) b.pos += drift;
            uvT -= dt;
            if (uvT > 0f) return;
            uvT = Random.Range(34f, 46f);
            float band = 230f, y = Mathf.Clamp(pos.y + Random.Range(-110f, 110f), -zone.size.y + band * 0.5f, zone.size.y - band * 0.5f);
            Toast("UV 램프 점등! 경고 띠에서 벗어나라 (적도 맞는다)"); Audio.Play("boss_warn", 0.5f);
            TeleLine(new Vector2(-zone.size.x, y), new Vector2(zone.size.x, y), band, 1.7f, () =>
            {
                Beam(new Vector2(-zone.size.x, y), new Vector2(zone.size.x, y), band * 0.5f, DB.Violet, 0.55f); Shake(6f);
                if (Mathf.Abs(pos.y - y) < band * 0.5f) Hurt(22f, "uv");
                foreach (var e in new List<Enemy>(enemies)) if (!e.dead && Mathf.Abs(e.pos.y - y) < band * 0.5f) Hit(e, e.IsBoss ? e.maxHp * 0.025f : Mathf.Max(30f, e.maxHp * 0.45f), Vector2.zero, 0f, DB.Violet);
            });
        }
    }
}
