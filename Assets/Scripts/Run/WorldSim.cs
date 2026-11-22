using System.Collections.Generic;
using UnityEngine;

namespace CS
{
    /// 탄환 · 장판 · 줍기 · 레벨업 · 선물상자
    public partial class World
    {
        void TickProjs(float dt)
        {
            foreach (var p in projs)
            {
                if (p.dead) continue;
                p.life -= dt; if (p.life <= 0f) { p.dead = true; continue; }
                if (p.kind == 0)
                {
                    if (p.target == null || p.target.dead) p.target = Nearest(p.pos, 420f, p.hit);
                    if (p.target != null)
                    {
                        Vector2 want = (p.target.pos - p.pos).normalized * p.speed;
                        p.vel = Vector2.Lerp(p.vel, want, 1f - Mathf.Exp(-p.turn * dt));
                    }
                }
                p.pos += p.vel * dt;
                foreach (var e in Query(p.pos, p.radius))
                {
                    if (p.hit.Contains(e)) continue;
                    p.hit.Add(e);
                    p.src.OnHit(p, e);
                    if (--p.pierce < 0) { p.dead = true; break; }
                }
                if (!InBounds(p.pos, -200f)) p.dead = true;
            }
        }

        void TickBullets(float dt)
        {
            float pr = DB.PlayerRadius * 0.7f;
            foreach (var b in bullets)
            {
                if (b.dead) continue;
                if (b.turn != 0f) { float ca = Mathf.Cos(b.turn * dt), sa = Mathf.Sin(b.turn * dt); b.vel = new Vector2(b.vel.x * ca - b.vel.y * sa, b.vel.x * sa + b.vel.y * ca); }
                b.life -= dt; b.pos += b.vel * dt;
                if (b.life <= 0f || !InBounds(b.pos, -60f)) { b.dead = true; continue; }
                if ((b.pos - pos).magnitude < b.radius + pr) { b.dead = true; Hurt(b.dmg, "bullet"); }
            }
        }

        void TickPools(float dt)
        {
            float pr = DB.PlayerRadius * 0.6f;
            for (int i = pools.Count - 1; i >= 0; i--)
            {
                var p = pools[i]; p.life -= dt;
                if (p.life <= 0f) { pools.RemoveAt(i); continue; }
                // 생긴 직후 0.4초는 아직 해가 없다(발밑에 갑자기 생겨도 피할 틈이 있게)
                if (p.maxLife - p.life > 0.4f && (pos - p.pos).magnitude < p.r * 0.85f + pr) Hurt(p.dmg, "puddle");
            }
        }

        void TickAreas(float dt)
        {
            for (int i = areas.Count - 1; i >= 0; i--)
            {
                var a = areas[i]; a.life -= dt; a.acc += dt;
                if (a.block > 0f) BlockBullets(a.pos, a.radius, a.block, a.bit, a.color);
                if (a.acc >= 0.5f) { a.acc = 0f; foreach (var e in new List<Enemy>(Query(a.pos, a.radius))) Hit(e, a.dmg, Vector2.zero, 0f, a.color); }
                if (a.life <= 0f) areas.RemoveAt(i);
            }
        }

        void TickPickups(float dt)
        {
            foreach (var p in pickups)
            {
                if (p.dead) continue;
                p.t += dt;
                Vector2 to = pos - p.pos; float d = to.magnitude;
                if (!p.attracted && d < (p.kind == 0 ? magnet : DB.PlayerRadius + 26f)) p.attracted = true;
                if (!p.attracted) continue;
                p.vel = Vector2.MoveTowards(p.vel, to.normalized * 780f, 2600f * dt);
                p.pos += p.vel * dt;
                if (d < DB.PlayerRadius + 10f) Collect(p);
            }
        }

        void Collect(Pickup p)
        {
            p.dead = true;
            switch (p.kind)
            {
                case 0: gems--; Audio.Play("pickup", 0.35f, 0.12f, 0.03f); AddXp(Mathf.Max(1, Mathf.RoundToInt(p.value * (1f + 0.08f * Save.Upgrade("growth"))))); break;
                case 1: hp = Mathf.Min(maxHp, hp + 25f); Audio.Play("heal"); Toast("핫코코아 +25 HP"); Ring(pos, DB.Green, 10f, 90f, 0.4f, 5f); break;
                case 2: foreach (var g in pickups) if (g.kind == 0) g.attracted = true; Audio.Play("gift", 0.7f); Toast("볼텍스 — ATP를 모두 끌어온다"); break;
                case 3: OpenGift(p.value); break;
            }
        }

        public void AddXp(int v)
        {
            xp += v;
            while (xp >= xpNext) { xp -= xpNext; level++; xpNext = DB.XpToNext(level); pendingLevelUps++; }
        }

        // ── 레벨업 선택지 ──
        public List<LevelOption> BuildOptions(int n)
        {
            var cand = new List<LevelOption>(); var weight = new List<float>();
            foreach (var w in weapons)
                if (w.level < DB.WeaponMaxLevel) { cand.Add(new LevelOption { type = "weapon", id = w.def.id, title = w.def.name, text = w.def.lv[w.level], color = w.def.color, level = w.level + 1 }); weight.Add(3f); }
            if (weapons.Count < DB.MaxWeapons)
                foreach (var d in DB.Weapons)
                    if (GetWeapon(d.id) == null) { cand.Add(new LevelOption { type = "weapon", id = d.id, title = d.name, text = d.desc + (d.block > 0f ? "  ·  탄환 차단 " + Mathf.RoundToInt(d.block * 100f) + "%" : ""), color = d.color, isNew = true, level = ch.id == "hek293t" ? 2 : 1 }); weight.Add(2f); }
            foreach (var d in DB.Passives)
            {
                int lv = passives.TryGetValue(d.id, out int v) ? v : 0;
                if (lv >= DB.PassiveMaxLevel || (lv == 0 && passives.Count >= DB.MaxPassives)) continue;
                cand.Add(new LevelOption { type = "passive", id = d.id, title = d.name, text = d.text, color = DB.Green, isNew = lv == 0, level = lv + 1 }); weight.Add(lv == 0 ? 1.6f : 2.2f);
            }
            var res = new List<LevelOption>();
            while (res.Count < n && cand.Count > 0)
            {
                float tot = 0f; foreach (var x in weight) tot += x;
                float r = (float)rng.NextDouble() * tot; int k = 0;
                for (; k < cand.Count - 1; k++) { r -= weight[k]; if (r < 0f) break; }
                res.Add(cand[k]); cand.RemoveAt(k); weight.RemoveAt(k);
            }
            if (res.Count == 0) res.Add(new LevelOption { type = "heal", id = "heal", title = "핫코코아", text = "HP 30 회복", color = DB.Green });
            return res;
        }

        public void Apply(LevelOption o)
        {
            if (o.type == "weapon") { var w = GetWeapon(o.id); if (w == null) AddWeapon(o.id); else w.level++; }
            else if (o.type == "passive") { passives[o.id] = (passives.TryGetValue(o.id, out int v) ? v : 0) + 1; Save.Discover(o.id); Recalc(); }
            else hp = Mathf.Min(maxHp, hp + 30f);
        }

        /// 선물상자: 진화 가능하면 진화, 아니면 강화 count개
        void OpenGift(int count)
        {
            lastGift.Clear(); giftT = 4f; Audio.Play("gift");
            foreach (var w in weapons)
                if (!w.evolved && w.level >= DB.WeaponMaxLevel && w.def.evolveWith != "" && passives.ContainsKey(w.def.evolveWith))
                { w.evolved = true; lastGift.Add("진화!  " + w.def.name + " → " + w.def.evolvedName); Save.Discover(w.def.id + "_evo"); Shake(8f); Ring(pos, DB.Yellow, 20f, 300f, 0.7f, 10f); count--; break; }
            for (int i = 0; i < count; i++)
            {
                var opts = BuildOptions(1); var o = opts[0];
                Apply(o); lastGift.Add(o.title + (o.type == "heal" ? "" : "  Lv" + o.level) + "  ·  " + o.text);
            }
            Ring(pos, DB.Green, 10f, 160f, 0.5f, 6f);
        }
    }
}
