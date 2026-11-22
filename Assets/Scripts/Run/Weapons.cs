using System.Collections.Generic;
using UnityEngine;

namespace CS
{
    /// 무기 10종. 각자 쿨다운대로 자동 발사한다. 수치는 DB.Weapons.
    public abstract class Weapon
    {
        public WeaponDef def; public int level = 1; public bool evolved;
        protected float timer; protected World w;
        public float Dmg => def.dmg[level - 1] * w.pDamage * (evolved ? 1.35f : 1f);
        public float Cd => def.cd[level - 1] * w.pCooldown;
        public float A => def.a[level - 1];
        public float B => def.b[level - 1];
        public string Name => evolved ? def.evolvedName : def.name;

        public static Weapon Create(string id, World world)
        {
            Weapon x;
            switch (id)
            {
                case "qpcr_beam": x = new QpcrBeam(); break;
                case "gel_cutter": x = new GelCutter(); break;
                case "lentiviral_orb": x = new LentiviralOrb(); break;
                case "nanopore_ring": x = new NanoporeRing(); break;
                case "antibody_chain": x = new AntibodyChain(); break;
                case "centrifuge_wave": x = new CentrifugeWave(); break;
                case "crispr_lance": x = new CrisprLance(); break;
                case "uv_flash": x = new UvFlash(); break;
                case "etoh_splash": x = new EtohSplash(); break;
                default: x = new LysozymeField(); break;
            }
            x.def = DB.Weapon(id); x.w = world;
            return x;
        }

        public virtual void Tick(float dt) { timer -= dt * w.CdRate; if (timer <= 0f) timer = Fire() ? Cd : 0.12f; }
        protected abstract bool Fire();
        public virtual void OnHit(Proj p, Enemy e) { }
        public virtual void Draw() { }
        protected static Vector2 Dir(float a) { return new Vector2(Mathf.Cos(a), Mathf.Sin(a)); }
    }

    class QpcrBeam : Weapon
    {
        float ang, acc;
        public override void Tick(float dt)
        {
            if (!evolved) { base.Tick(dt); return; }
            ang += 2.3f * dt * w.CdRate; acc += dt;
            if (acc < 0.12f) return; acc = 0f;
            for (int i = 0; i < 4; i++) { Vector2 end = w.pos + Dir(ang + i * 1.5708f) * B * w.pArea; w.LineHit(w.pos, end, 10f * w.pArea, Dmg * 0.34f, def.color, 0f); w.BlockBulletsLine(w.pos, end, 12f * w.pArea, def.block, def.bit, def.color); }
        }
        public override void Draw()
        {
            if (!evolved) return;
            for (int i = 0; i < 4; i++) { Vector2 d = Dir(ang + i * 1.5708f); Gfx.Over.Seg(w.pos + d * 22f, w.pos + d * B * w.pArea, 10f, Gfx.Hdr(def.color, 2.4f), new Vector4(6, 8f, 1f, 0)); }
        }
        protected override bool Fire()
        {
            var tg = w.Nearest(w.pos, B + 60f); if (tg == null) return false;
            float a0 = Mathf.Atan2(tg.pos.y - w.pos.y, tg.pos.x - w.pos.x); int n = (int)A;
            for (int i = 0; i < n; i++)
            {
                Vector2 d = Dir(a0 + (i - (n - 1) * 0.5f) * 0.24f), end = w.pos + d * B * w.pArea;
                w.LineHit(w.pos, end, 9f * w.pArea, Dmg, def.color, 40f);
                w.BlockBulletsLine(w.pos, end, 12f * w.pArea, def.block, def.bit, def.color);
                w.Beam(w.pos + d * 20f, end, 8f, def.color, 0.16f);
            }
            return true;
        }
    }

    class GelCutter : Weapon
    {
        protected override bool Fire()
        {
            float R = A * w.pArea;
            var tg = w.Nearest(w.pos, R + 50f);
            if (tg == null) return false;
            Vector2 d = (tg.pos - w.pos).normalized;
            Cut(d, R); if (B > 1.5f) Cut(-d, R);
            return true;
        }
        void Cut(Vector2 d, float R)
        {
            float a0 = Mathf.Atan2(d.y, d.x);
            foreach (var e in new List<Enemy>(w.Query(w.pos, R)))
            {
                Vector2 to = e.pos - w.pos;
                if (Mathf.Abs(Mathf.DeltaAngle(Mathf.Atan2(to.y, to.x) * Mathf.Rad2Deg, a0 * Mathf.Rad2Deg)) < 62f) w.Hit(e, Dmg, to.normalized, 150f, def.color);
            }
            w.BlockBulletsArc(w.pos, R, a0, 62f, def.block, def.bit, def.color);
            w.Slash(w.pos, a0, R, def.color);
        }
    }

    class LentiviralOrb : Weapon
    {
        protected override bool Fire()
        {
            var tg = w.Nearest(w.pos, 520f); if (tg == null) return false;
            float a0 = Mathf.Atan2(tg.pos.y - w.pos.y, tg.pos.x - w.pos.x); int n = (int)A;
            for (int i = 0; i < n; i++)
                w.projs.Add(new Proj { kind = 0, pos = w.pos, vel = Dir(a0 + (i - (n - 1) * 0.5f) * 0.7f) * 300f, speed = 300f, turn = 5f, radius = 9f, dmg = Dmg, life = 3.5f * w.pDuration, pierce = 0, color = def.color, src = this });
            return true;
        }
        public override void OnHit(Proj p, Enemy e)
        {
            w.Hit(e, p.dmg, p.vel.normalized, 60f, def.color);
            if (!e.dead) w.Infect(e, p.dmg * 0.5f, (int)B, evolved);
            w.Burst(p.pos, def.color, 5, 110f, 0.3f);
        }
    }

    class NanoporeRing : Weapon
    {
        float ang;
        public override void Tick(float dt)
        {
            ang += 2.6f * dt * w.CdRate;
            int n = (int)A; float R = B * w.pArea;
            for (int i = 0; i < n; i++)
            {
                Vector2 p = w.pos + Dir(ang + 6.2832f * i / n) * R;
                var near = w.QueryTmp(p, 13f * w.pArea);
                for (int k = 0; k < near.Count; k++) { var e = near[k]; if (!e.dead && e.poreCd <= 0f) { e.poreCd = Cd; w.Hit(e, Dmg, (e.pos - w.pos).normalized, 70f, def.color); } }
                w.FreeTmp();
                w.BlockBullets(p, 17f * w.pArea, def.block, def.bit, def.color);      // 기공이 적 탄환을 막는다
            }
        }
        protected override bool Fire() { return true; }
        public override void Draw()
        {
            int n = (int)A; float R = B * w.pArea;
            for (int i = 0; i < n; i++)
            {
                Vector2 p = w.pos + Dir(ang + 6.2832f * i / n) * R;
                Gfx.Over.Quad(p, 17f * w.pArea, Gfx.Hdr(def.color, 2.0f), new Vector4(8, 0, 0, 0));
                Gfx.Light(p, 70f, def.color, 0.5f);
            }
        }
    }

    class AntibodyChain : Weapon
    {
        readonly HashSet<Enemy> used = new HashSet<Enemy>();
        protected override bool Fire()
        {
            used.Clear(); bool any = false;
            for (int c = 0; c < (int)B; c++)
            {
                var e = w.Nearest(w.pos, 380f, used); Vector2 from = w.pos;
                for (int i = 0; i < (int)A && e != null; i++)
                {
                    used.Add(e); any = true;
                    w.Beam(from, e.pos, 5f, def.color, 0.18f);
                    Vector2 at = e.pos;
                    w.Hit(e, Dmg, (e.pos - from).normalized, 40f, def.color);
                    from = at; e = w.Nearest(from, 230f, used);
                }
            }
            return any;
        }
    }

    class CentrifugeWave : Weapon
    {
        protected override bool Fire()
        {
            float R = A * w.pArea;
            if (w.Query(w.pos, R).Count == 0) return false;
            if (evolved)
            {
                foreach (var e in w.Query(w.pos, R * 1.4f)) if (!e.IsBoss) e.knock += (w.pos - e.pos).normalized * 420f;
                w.Ring(w.pos, def.color, R * 1.4f, 20f, 0.25f, 6f);
                w.After(0.28f, () => Blast(R, 2f));
            }
            else Blast(R, 1f);
            return true;
        }
        void Blast(float R, float mult)
        {
            foreach (var e in new List<Enemy>(w.Query(w.pos, R))) w.Hit(e, Dmg * mult, (e.pos - w.pos).normalized, B, def.color);
            w.BlockBullets(w.pos, R, def.block, def.bit, def.color);
            w.Ring(w.pos, def.color, 20f, R, 0.35f, 12f); w.Shake(2f * mult);
        }
    }

    class CrisprLance : Weapon
    {
        protected override bool Fire()
        {
            var list = w.InViewEnemies(); if (list.Count == 0) return false;
            list.Sort((x, y) => y.hp.CompareTo(x.hp));
            for (int i = 0; i < (int)B && i < list.Count; i++)
            {
                Vector2 d = (list[i].pos - w.pos).normalized;
                w.projs.Add(new Proj { kind = 1, pos = w.pos, vel = d * 950f, radius = 11f, dmg = Dmg, life = 1.2f, pierce = (int)A, color = def.color, src = this });
            }
            return true;
        }
        public override void OnHit(Proj p, Enemy e)
        {
            float d = p.dmg;
            if (evolved) { if (e.IsBoss || e.elite) d *= 1.5f; else if (e.hp < e.maxHp * 0.15f) d = e.hp + 1f; }
            w.Hit(e, d, p.vel.normalized, 120f, def.color);
            w.Burst(p.pos, def.color, 4, 140f, 0.25f);
        }
    }

    class UvFlash : Weapon
    {
        protected override bool Fire()
        {
            var list = w.InViewEnemies(); if (list.Count == 0) return false;
            float R = B * w.pArea, dmg = Dmg;
            for (int i = 0; i < (int)A; i++)
            {
                Vector2 p = list[w.rng.Next(list.Count)].pos;
                w.After(0.1f * i, () =>
                {
                    foreach (var e in new List<Enemy>(w.Query(p, R))) w.Hit(e, dmg, Vector2.zero, 0f, def.color);
                    w.BlockBullets(p, R, def.block, def.bit, def.color);
                    w.Strike(p, R, def.color);
                });
            }
            return true;
        }
    }

    class EtohSplash : Weapon
    {
        protected override bool Fire()
        {
            var near = new List<Enemy>(w.Query(w.pos, 330f)); if (near.Count == 0) return false;
            for (int i = 0; i < (int)A; i++)
            {
                Vector2 p = near[w.rng.Next(near.Count)].pos + Random.insideUnitCircle * 30f;
                float life = 4f * w.pDuration;
                w.areas.Add(new Area { pos = p, radius = B * w.pArea, dmg = Dmg, life = life, maxLife = life, color = def.color, block = def.block, bit = def.bit });
                w.Burst(p, def.color, 8, 150f, 0.4f);
            }
            return true;
        }
    }

    class LysozymeField : Weapon
    {
        protected override bool Fire()
        {
            foreach (var e in new List<Enemy>(w.Query(w.pos, A * w.pArea))) w.Hit(e, Dmg, Vector2.zero, 0f, def.color);
            w.BlockBullets(w.pos, A * w.pArea, def.block, def.bit, def.color);
            return true;
        }
        public override void Draw() { Gfx.Under.Quad(w.pos, A * w.pArea / 0.92f, Gfx.Hdr(def.color, 0.55f), new Vector4(11, 0, 0, 0)); }
    }

    public partial class World
    {
        public void LineHit(Vector2 a, Vector2 b, float halfW, float dmg, Color c, float knock)
        {
            Vector2 ab = b - a; float len2 = ab.sqrMagnitude; if (len2 < 0.01f) return;
            Vector2 dir = ab / Mathf.Sqrt(len2);
            var near = QueryTmp((a + b) * 0.5f, Mathf.Sqrt(len2) * 0.5f + halfW);
            for (int k = 0; k < near.Count; k++)
            {
                var e = near[k]; if (e.dead) continue;
                float f = Mathf.Clamp01(Vector2.Dot(e.pos - a, ab) / len2);
                if ((e.pos - (a + ab * f)).magnitude < halfW + e.radius) Hit(e, dmg, dir, knock, c);
            }
            FreeTmp();
        }
        public List<Enemy> InViewEnemies()
        {
            var l = new List<Enemy>();
            foreach (var e in enemies) if (!e.dead && e.downT <= 0f && (e.def == null || e.def.behavior != "static") && InView(e.pos, -10f)) l.Add(e);
            return l;
        }
    }
}
