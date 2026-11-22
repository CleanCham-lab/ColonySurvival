using System.Collections.Generic;
using UnityEngine;

namespace CS
{
    /// 타이틀 화면의 살아 있는 배경.
    /// 네온 로고 뒤에서 세포(HEK293T·HeLa, 해금했으면 RAW 264.7)가 떠다니며 양옆에서 몰려오는 오염균을 쏘아 잡는다. 눈과 전구 장식.
    /// 로고·눈·전구·세포는 카메라에 붙어 있고, 바닥과 적은 월드에 있어서 카메라가 천천히 흐르면 시차가 생긴다.
    public class TitleScene
    {
        class Cell { public CharDef ch; public Vector2 home, pos, vel, look; public float r, cd, pulse, ph; }
        class Mob { public EnemyDef def; public Vector2 pos; public float seed, facing, flash, swirl, hp, wob; }
        class Flake { public Vector2 p; public float size, fall, sway, ph, bright; public bool front; }
        class Gem { public Vector2 pos, vel; public float t, seed; public Cell to; }
        class Zap { public Vector2 a, b; public float t, dur; public Color c; }
        class Spark { public Vector2 pos, vel; public float t, dur, size; public Color c; }
        class Ring { public Vector2 pos; public float t, dur, r; public Color c; }

        readonly GlyphText logo;
        readonly List<Cell> cells = new List<Cell>();
        readonly List<Mob> mobs = new List<Mob>(); readonly List<Flake> flakes = new List<Flake>(); readonly List<Gem> gems = new List<Gem>();
        readonly List<Zap> zaps = new List<Zap>(); readonly List<Spark> sparks = new List<Spark>(); readonly List<Ring> rings = new List<Ring>();
        readonly EnemyDef[] pool;
        readonly System.Random rng = new System.Random(24);
        float t, spawnT, hw = 587f, mouseIdle = 9f; Vector2 cam, lastMouse;
        const float HH = 330f;
        static readonly Vector2 LogoC = new Vector2(0f, 112f), MenuC = new Vector2(0f, -190f);
        static readonly Color Ice = new Color(0.78f, 0.94f, 1f), Gold = new Color(1f, 0.82f, 0.38f);
        static Vector4 V(float a, float b = 0, float c = 0, float d = 0) { return new Vector4(a, b, c, d); }
        float R(float a, float b) { return a + (float)rng.NextDouble() * (b - a); }

        public TitleScene(Transform root)
        {
            logo = new GlyphText("Fonts/Pretendard-Bold", root, 45);
            logo.Add("COLONY", new Vector2(4f, 101f), 132f, 0.04f, new Vector4(0.01f, 0.03f, 0.08f, 0.7f), '\0', 0f);       // 그림자
            logo.Add("COLONY", new Vector2(0f, 106f), 132f, 0.04f, Gfx.Hdr(new Color(0.96f, 0.99f, 1f), 1.75f), '\0', 0f, Gfx.Hdr(new Color(0.42f, 0.86f, 1f), 1.55f));
            logo.Add("SURVIVAL", new Vector2(0f, 30f), 58f, 0.46f, Gfx.Hdr(new Color(1f, 0.5f, 0.56f), 2.1f), '\0', 1f, Gfx.Hdr(DB.Red, 2.4f));
            logo.Add("LAB  XMAS  EDITION", new Vector2(0f, -8f), 19f, 0.55f, Gfx.Hdr(Gold, 1.5f), '\0', 0f);
            pool = new[] { DB.Enemy("ecoli"), DB.Enemy("ecoli"), DB.Enemy("mycoplasma"), DB.Enemy("mycoplasma"), DB.Enemy("yeast"), DB.Enemy("phage") };
            for (int i = 0; i < 90; i++)
            {
                bool big = i < 12;
                flakes.Add(new Flake { p = new Vector2(R(-1f, 1f), R(-1f, 1f)), size = big ? R(12f, 24f) : R(1.8f, 4.6f), fall = big ? R(10f, 18f) : R(16f, 44f), sway = R(6f, 22f), ph = R(0f, 6.28f), bright = big ? R(0.08f, 0.16f) : R(0.5f, 1.3f), front = i % 3 != 0 });
            }
            Visible = false;
        }

        public bool Visible { set { logo.Visible = value; } }

        public void Begin()
        {
            t = 0f; spawnT = 0.2f; cells.Clear(); mobs.Clear(); gems.Clear(); zaps.Clear(); sparks.Clear(); rings.Clear();
            Gfx.SetArena(0, new Vector2(2200f, 0f));
            Visible = true;
            hw = HH * Game.I.cam.aspect;
            float fx = Mathf.Max(430f, hw - 130f);
            Vector2[] homes = { new Vector2(-fx, 30f), new Vector2(fx, -60f), new Vector2(-fx + 60f, -235f) };
            for (int i = 0; i < DB.Chars.Length && i < homes.Length; i++)
            {
                if (!Save.CharOpen(DB.Chars[i])) continue;
                cells.Add(new Cell { ch = DB.Chars[i], home = homes[i], pos = homes[i], r = 27f, ph = i * 2.1f, cd = 0.5f + i * 0.2f });
            }
            for (int i = 0; i < 12; i++) Spawn(true);
        }

        /// 로고 타원과 메뉴 타원 중 가까운 쪽까지의 정규화 거리(1 미만이면 글자 위)
        float SafeDist(Vector2 local, out Vector2 away)
        {
            Vector2 a = local - LogoC, b = local - MenuC;
            float d1 = Mathf.Sqrt(a.x * a.x / (400f * 400f) + a.y * a.y / (170f * 170f));
            float d2 = Mathf.Sqrt(b.x * b.x / (230f * 230f) + b.y * b.y / (165f * 165f));
            away = (d1 < d2 ? a : b).normalized;
            return Mathf.Min(d1, d2);
        }

        void Spawn(bool anywhere)
        {
            var d = pool[rng.Next(pool.Length)];
            float side = rng.Next(2) == 0 ? -1f : 1f;
            Vector2 local = anywhere ? new Vector2(side * R(430f, hw + 40f), R(-320f, 300f)) : new Vector2(side * (hw + R(40f, 110f)), R(-330f, 290f));
            if (SafeDist(local, out _) < 1.2f) return;
            mobs.Add(new Mob { def = d, pos = cam + local, seed = R(0f, 1f), swirl = R(-0.6f, 0.6f), hp = d.id == "yeast" || d.id == "phage" ? 2f : 1f, wob = R(0f, 6.28f) });
        }

        void Kill(Mob m, Cell by)
        {
            for (int i = 0; i < 7; i++) { float a = R(0f, 6.28f), s = R(40f, 170f); sparks.Add(new Spark { pos = m.pos, vel = new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * s, dur = R(0.25f, 0.5f), size = R(3f, 6f), c = m.def.color }); }
            rings.Add(new Ring { pos = m.pos, dur = 0.3f, r = m.def.radius * 3.2f, c = m.def.color });
            gems.Add(new Gem { pos = m.pos, vel = new Vector2(R(-60f, 60f), R(20f, 90f)), to = by, seed = R(0f, 1f) });
            mobs.Remove(m);
        }

        public void Tick(float dt)
        {
            t += dt;
            var c = Game.I.cam; hw = HH * c.aspect;
            cam = new Vector2(Mathf.Sin(t * 0.07f) * 70f + Mathf.Sin(t * 0.031f) * 40f, Mathf.Cos(t * 0.053f) * 46f);
            logo.Update();

            Vector2 mouse = Inp.MousePos; mouseIdle = (mouse - lastMouse).sqrMagnitude > 4f ? 0f : mouseIdle + dt; lastMouse = mouse;
            Vector2 mw = c.ScreenToWorldPoint(new Vector3(mouse.x, mouse.y, 10f));

            spawnT -= dt;
            if (spawnT <= 0f) { spawnT = R(0.3f, 0.65f); if (mobs.Count < 30) Spawn(false); }

            // 세포: 제자리 근처를 떠다니다가, 적이 다가오면 살짝 물러나며 쏜다
            foreach (var ce in cells)
            {
                Vector2 wp = cam + ce.pos;
                ce.pulse = Mathf.Max(0f, ce.pulse - dt * 3f);
                Mob best = null; float bd = 250f; Vector2 flee = Vector2.zero;
                foreach (var m in mobs)
                {
                    Vector2 dv = wp - m.pos; float l = dv.magnitude;
                    if (l < bd) { bd = l; best = m; }
                    if (l < 130f) flee += dv / Mathf.Max(l, 1f) * (130f - l) / 130f;
                }
                Vector2 drift = ce.home + new Vector2(Mathf.Sin(t * 0.37f + ce.ph) * 95f + Mathf.Sin(t * 0.13f + ce.ph * 2f) * 40f, Mathf.Cos(t * 0.29f + ce.ph * 1.3f) * 70f);
                Vector2 want = (drift - ce.pos) * 0.9f + flee * 150f;
                float sd = SafeDist(ce.pos, out Vector2 away);
                if (sd < 1.25f) want += away * (1.25f - sd) * 600f;
                ce.vel = Vector2.Lerp(ce.vel, Vector2.ClampMagnitude(want, 120f), 1f - Mathf.Exp(-dt * 2.2f));
                ce.pos += ce.vel * dt;
                ce.pos.x = Mathf.Clamp(ce.pos.x, -hw + 50f, hw - 50f); ce.pos.y = Mathf.Clamp(ce.pos.y, -HH + 50f, HH - 80f);
                Vector2 lookWant = mouseIdle < 2.5f ? Vector2.ClampMagnitude((mw - wp) / 220f, 1f) : (best != null ? (best.pos - wp).normalized * 0.9f : Vector2.ClampMagnitude(ce.vel / 60f, 1f));
                ce.look = Vector2.Lerp(ce.look, lookWant, 1f - Mathf.Exp(-dt * 7f));
                ce.cd -= dt;
                if (ce.cd <= 0f && best != null)
                {
                    ce.cd = R(0.4f, 0.8f);
                    Vector2 dir = (best.pos - wp).normalized;
                    zaps.Add(new Zap { a = wp + dir * ce.r * 0.9f, b = best.pos, dur = 0.16f, c = ce.ch.color });
                    best.hp -= 1f; best.flash = 0.12f; ce.pulse = Mathf.Max(ce.pulse, 0.5f);
                    if (best.hp <= 0f) Kill(best, ce);
                }
            }

            // 적: 가장 가까운 세포를 쫓되, 글자 위로는 올라오지 않는다
            for (int k = mobs.Count - 1; k >= 0; k--)
            {
                var m = mobs[k]; Vector2 local = m.pos - cam;
                Cell tgt = null; float bd = 1e9f;
                foreach (var ce in cells) { float l = (ce.pos - local).sqrMagnitude; if (l < bd) { bd = l; tgt = ce; } }
                Vector2 to = (tgt != null ? tgt.pos : new Vector2(Mathf.Sign(local.x) * 480f, 0f)) - local; float dist = to.magnitude; Vector2 dir = to / Mathf.Max(dist, 1f);
                Vector2 vel = (dir + new Vector2(-dir.y, dir.x) * m.swirl).normalized * m.def.speed * 0.5f;
                float sd = SafeDist(local, out Vector2 away);
                if (sd < 1.3f) vel += away * (1.3f - sd) * 260f;
                vel += new Vector2(Mathf.Sin(t * 1.7f + m.wob), Mathf.Cos(t * 1.3f + m.wob * 1.7f)) * 9f;
                m.pos += vel * dt; m.facing = Mathf.Atan2(vel.y, vel.x); m.flash = Mathf.Max(0f, m.flash - dt);
                if (tgt != null && dist < tgt.r + m.def.radius + 6f)
                {
                    rings.Add(new Ring { pos = cam + tgt.pos, dur = 0.35f, r = 90f, c = tgt.ch.color }); tgt.pulse = 0.8f;
                    Kill(m, tgt);
                }
                else if (Mathf.Abs(local.x) > hw + 240f || Mathf.Abs(local.y) > HH + 240f) mobs.RemoveAt(k);
            }

            for (int k = gems.Count - 1; k >= 0; k--)
            {
                var g = gems[k]; g.t += dt;
                Vector2 goal = cam + g.to.pos; Vector2 d = goal - g.pos; float l = d.magnitude;
                if (g.t > 0.35f) g.vel = Vector2.Lerp(g.vel, d / Mathf.Max(l, 1f) * (260f + g.t * 700f), 1f - Mathf.Exp(-dt * 8f)); else g.vel *= Mathf.Exp(-dt * 3f);
                g.pos += g.vel * dt;
                if ((l < g.to.r && g.t > 0.35f) || g.t > 4f) { g.to.pulse = Mathf.Max(g.to.pulse, 0.35f); gems.RemoveAt(k); }
            }
            for (int k = zaps.Count - 1; k >= 0; k--) { zaps[k].t += dt; if (zaps[k].t >= zaps[k].dur) zaps.RemoveAt(k); }
            for (int k = rings.Count - 1; k >= 0; k--) { rings[k].t += dt; if (rings[k].t >= rings[k].dur) rings.RemoveAt(k); }
            for (int k = sparks.Count - 1; k >= 0; k--) { var s = sparks[k]; s.t += dt; s.pos += s.vel * dt; s.vel *= Mathf.Exp(-dt * 4f); if (s.t >= s.dur) sparks.RemoveAt(k); }
            foreach (var f in flakes)
            {
                f.p.y -= f.fall * dt / (HH + 30f);
                if (f.p.y < -1f) { f.p.y = 1f; f.p.x = R(-1f, 1f); }
            }
        }

        public void Draw()
        {
            var c = Game.I.cam;
            c.transform.position = new Vector3(cam.x, cam.y, -10f);
            logo.go.transform.position = new Vector3(cam.x, cam.y, 0f);
            float intro = Mathf.Clamp01(t / 1.1f); intro = intro * intro * (3f - 2f * intro);
            logo.Fade = intro;
            Gfx.Floor.Quad(Vector2.zero, new Vector2(2460f, 2460f), 0f, Vector4.one);

            // 로고 뒤 색 안개 + 바닥에 떨어지는 빛
            Gfx.Under.Quad(cam + LogoC + new Vector2(0f, 20f), new Vector2(560f, 250f), 0f, Gfx.Hdr(DB.Cyan, 0.10f * intro), V(10));
            Gfx.Under.Quad(cam + new Vector2(0f, 40f), new Vector2(430f, 120f), 0f, Gfx.Hdr(DB.Red, 0.10f * intro), V(10));
            Gfx.Light(cam + LogoC, 760f, DB.Cyan, 0.75f * intro);
            Gfx.Light(cam + new Vector2(0f, 20f), 420f, DB.Red, 0.5f * intro);
            Gfx.Light(cam + MenuC, 520f, new Color(0.3f, 0.5f, 1f), 0.35f);

            foreach (var m in mobs)
            {
                var d = m.def; float sz = d.radius * 1.25f;
                Gfx.Enemies.Quad(m.pos, sz / d.body, Gfx.Hdr(d.color, 1.3f), V(d.shape, m.seed, m.flash > 0f ? 1f : 0f, 1f), V(m.facing, 0f, 0f, 0f));
                Gfx.Light(m.pos, sz * 5f, d.color, 0.3f);
            }

            foreach (var ce in cells)
            {
                Vector2 p = cam + ce.pos + new Vector2(0f, Mathf.Sin(t * 1.4f + ce.ph) * 2.2f);
                float r = ce.r * (1f + 0.08f * ce.pulse);
                Gfx.Light(p, 360f, ce.ch.color, 1.6f * intro);
                Gfx.Under.Quad(p, r * 2.8f, Gfx.Hdr(ce.ch.color, (0.3f + 0.5f * ce.pulse) * intro), V(10));
                Gfx.Player.Quad(p, r / 0.58f, Gfx.Hdr(ce.ch.color, (1.5f + 0.9f * ce.pulse) * intro, intro), V(ce.ch.shape, 0.31f + ce.ph * 0.1f, 0f, 1f), V(0f, ce.look.x, ce.look.y, ce.ch.hat ? 1f : 0f));
            }

            foreach (var z in zaps)
            {
                float inv = 1f - z.t / z.dur;
                Gfx.Over.Seg(z.a, z.b, 7f * (0.6f + inv), Gfx.Hdr(z.c, 2.6f * inv), V(6, 10f, 1f));
                Gfx.Over.Quad(z.b, 20f * (0.6f + inv), Gfx.Hdr(z.c, 2.2f * inv), V(3));
                Gfx.Light(z.b, 150f, z.c, 0.7f * inv);
            }
            foreach (var g in rings) { float f = g.t / g.dur; Gfx.Over.Quad(g.pos, g.r, Gfx.Hdr(g.c, 1.2f * (1f - f)), V(9, 0.25f + 0.7f * f, 0.05f)); }
            foreach (var s in sparks) { float f = 1f - s.t / s.dur; Gfx.Over.Quad(s.pos, s.size * (0.5f + f), Gfx.Hdr(s.c, 2.0f * f), V(0)); }
            foreach (var g in gems) Gfx.Pickups.Quad(g.pos, 8.5f, Gfx.Hdr(DB.Green, 1.6f), V(2, g.seed));

            // 눈
            foreach (var f in flakes)
            {
                Vector2 p = cam + new Vector2(f.p.x * (hw + 30f) + Mathf.Sin(t * 0.7f + f.ph) * f.sway, f.p.y * (HH + 30f));
                float tw = 0.8f + 0.2f * Mathf.Sin(t * 2.3f + f.ph * 3f);
                (f.front ? Gfx.Top : Gfx.Under).Quad(p, f.size, Gfx.Hdr(Ice, f.bright * tw), V(f.size > 8f ? 10 : 0));
            }

            // 전구 줄(화면 위쪽에 늘어진 세 가닥)
            int spans = 3; float w = (hw + 30f) * 2f / spans, top = HH - 6f;
            Color[] bulbs = { DB.Red, DB.Green, Gold, DB.Cyan, DB.Mag };
            int bi = 0; Vector2 prev = Vector2.zero;
            for (int s = 0; s < spans; s++)
            {
                int n = Mathf.Max(6, Mathf.RoundToInt(w / 44f));
                for (int k = 0; k <= n; k++)
                {
                    float u = k / (float)n;
                    Vector2 p = cam + new Vector2(-hw - 30f + (s + u) * w, top - 4f - 46f * 4f * u * (1f - u) + Mathf.Sin(t * 0.9f + s + u * 3f) * 1.5f);
                    if (k > 0) Gfx.Top.Seg(prev, p, 1.6f, Gfx.Hdr(new Color(0.2f, 0.45f, 0.35f), 0.5f), V(6, 60f, 0f));
                    prev = p;
                    if (k == 0 || k == n) continue;
                    Color col = bulbs[bi % bulbs.Length]; float ph = bi * 1.7f; bi++;
                    float tw = 0.55f + 0.45f * Mathf.Sin(t * (1.1f + (bi % 3) * 0.35f) + ph); tw = 0.5f + 0.9f * tw * tw;
                    Vector2 bp = p + new Vector2(0f, -7f);
                    Gfx.Top.Quad(bp, 7.5f, Gfx.Hdr(col, 2.0f * tw), V(3));
                    Gfx.Top.Quad(bp, 30f, Gfx.Hdr(col, 0.22f * tw), V(0));
                }
            }
        }
    }
}
