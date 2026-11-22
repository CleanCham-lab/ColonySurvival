using UnityEngine;

namespace CS
{
    /// 매 프레임 전부 다시 그린다(쿼드 묶음에 채워 넣기).
    public partial class World
    {
        static Vector4 V(float a, float b = 0, float c = 0, float d = 0) { return new Vector4(a, b, c, d); }

        public void Draw()
        {
            var cam = Game.I.cam;
            Vector2 sh = shake > 0f ? Random.insideUnitCircle * shake : Vector2.zero;
            cam.transform.position = new Vector3(camPos.x + sh.x, camPos.y + sh.y, -10f);
            Vector2 ext = zone.floor == 0 ? new Vector2(zone.size.x + 260f, zone.size.x + 260f) : zone.size + new Vector2(260f, 260f);
            Gfx.Floor.Quad(Vector2.zero, ext, 0f, Vector4.one);

            // 장판·경고
            foreach (var a in areas) { float f = Mathf.Clamp01(a.life / 0.5f); Gfx.Under.Quad(a.pos, a.radius / 0.92f, Gfx.Hdr(a.color, 0.7f * f), V(11)); Gfx.Light(a.pos, a.radius * 1.6f, a.color, 0.35f * f); }
            foreach (var p in pools)
            {
                // 웅덩이: 생길 때 번지고, 사라질 때 옅어진다
                float grow = Mathf.Clamp01((p.maxLife - p.life) / 0.4f), fade = Mathf.Clamp01(p.life / 0.6f);
                Gfx.Under.Quad(p.pos, p.r * (0.5f + 0.5f * grow) / 0.92f, Gfx.Hdr(p.color, 0.85f * fade * (0.5f + 0.5f * grow)), V(11));
            }
            foreach (var q in tele)
            {
                float f = Mathf.Clamp01(q.t / q.dur), blink = f > 0.7f ? 0.65f + 0.35f * Mathf.Sin(q.t * 30f) : 1f;
                Color tc = q.color.a > 0f ? q.color : DB.Yellow;       // 누가 쏘는지에 따라 경고 색이 다르다
                if (q.type == 0)
                {
                    Gfx.Under.Quad(q.a, q.r / 0.92f, Gfx.Hdr(tc, 0.75f * blink), V(11));
                    Gfx.Under.Quad(q.a, q.r, Gfx.Hdr(tc, 1.3f * blink), V(1, f * 0.9f, 0.03f));
                    if (q.cross) { Gfx.Under.Seg(q.a - new Vector2(q.r, q.r) * 0.6f, q.a + new Vector2(q.r, q.r) * 0.6f, 5f, Gfx.Hdr(DB.Red, 1.6f * blink), V(6, 8, 0)); Gfx.Under.Seg(q.a + new Vector2(-q.r, q.r) * 0.6f, q.a + new Vector2(q.r, -q.r) * 0.6f, 5f, Gfx.Hdr(DB.Red, 1.6f * blink), V(6, 8, 0)); }
                }
                else
                {
                    Gfx.Under.Seg(q.a, q.b, q.r * 0.5f, Gfx.Hdr(tc, 0.22f * blink), V(11));
                    Gfx.Under.Seg(q.a, Vector2.Lerp(q.a, q.b, f), q.r * 0.5f, Gfx.Hdr(tc, 0.5f * blink), V(6, 30f, 0));
                }
            }
            foreach (var w in weapons) w.Draw();

            // 줍는 것
            foreach (var p in pickups)
            {
                if (!InView(p.pos, 40f)) continue;
                switch (p.kind)
                {
                    case 0: { float s = p.value >= 25 ? 13f : (p.value >= 5 ? 10.5f : 8.5f); Gfx.Pickups.Quad(p.pos, s, Gfx.Hdr(DB.Green, p.value >= 5 ? 2.0f : 1.5f), V(2, p.seed)); break; }
                    case 1:
                        {
                            // 핫코코아: 김이 나는 머그컵
                            Vector2 mp = p.pos + new Vector2(0f, Mathf.Sin(p.t * 2.2f + p.seed * 6f) * 2.5f);
                            Gfx.Under.Quad(p.pos, 40f, Gfx.Hdr(new Color(1f, 0.7f, 0.4f), 0.35f), V(10));
                            Gfx.Enemies.Quad(mp, 30f, Gfx.Hdr(new Color(1f, 0.75f, 0.45f), 1f), V(18, p.seed, 0, 1), V(0, 0, 0, 0));
                            Gfx.Light(p.pos, 130f, new Color(1f, 0.8f, 0.5f), 0.7f);
                            break;
                        }
                    case 2: Gfx.Pickups.Quad(p.pos, 22f, Gfx.Hdr(DB.Green, 1.6f), V(9, 0.35f + 0.4f * Mathf.Repeat(p.t, 1f), 0.06f)); Gfx.Pickups.Quad(p.pos, 10f, Gfx.Hdr(DB.Green, 2f), V(3)); break;
                    default: Gfx.Pickups.Quad(p.pos, 30f + 3f * Mathf.Sin(p.t * 4f), Gfx.Hdr(DB.Green, 2.2f), V(5)); Gfx.Pickups.Quad(p.pos, 46f, Gfx.Hdr(DB.Green, 0.8f), V(10)); Gfx.Light(p.pos, 220f, DB.Green, 1.0f); break;
                }
            }

            // 적
            foreach (var e in enemies)
            {
                if (e.dead || !InView(e.pos, e.radius * 3f + 40f)) continue;
                if (e.IsBoss) { DrawBoss(e); continue; }
                var d = e.def;
                if (d.trait == "slow")
                {
                    // 저해제: 이 고리 안에서는 발이 느려진다
                    float ar = WorldAuraR(e);
                    Gfx.Under.Quad(e.pos, ar, Gfx.Hdr(d.color, 0.55f + 0.15f * Mathf.Sin(Gfx.Time * 3f + e.seed * 6f)), V(1, 0.96f, 0.022f));
                    Gfx.Under.Quad(e.pos, ar, Gfx.Hdr(d.color, 0.10f), V(10));
                }
                else if (d.behavior == "spray" && e.state == 1)
                {
                    // 에어로졸: 뿜을 방향을 부채꼴로 미리 보여 준다
                    Gfx.Under.Quad(e.pos, new Vector2(245f, 245f), Mathf.Atan2(e.aim.y, e.aim.x), Gfx.Hdr(d.color, 0.35f + 0.5f * e.charge), V(7, 0.50f));
                }
                Gfx.Enemies.Quad(e.pos, e.radius / d.body, Gfx.Hdr(d.color, 1.55f, e.downT > 0f ? 0.30f + 0.12f * Mathf.Sin(Gfx.Time * 18f) : 1f), V(d.shape, e.seed, e.flash > 0f ? 1f : 0f, e.hp / e.maxHp), V(e.facing, Dev.Has("gallery") && e.elite ? 1f : e.charge, e.infected > 0f ? 1f : 0f, e.elite ? 1f : 0f));
                if (e.elite || d.radius >= 20f) Gfx.Light(e.pos, e.radius * 6f, d.color, 0.55f);
            }

            // 저해제 곁이라 느려진 상태: 발밑에 붉은 고리
            if (slowT > 0f) Gfx.Under.Quad(pos, 36f, Gfx.Hdr(new Color(0.95f, 0.12f, 0.28f), 1.1f), V(1, 0.80f, 0.05f));

            // 플레이어
            foreach (var g in ghosts) Gfx.Player.Quad(new Vector2(g.x, g.y), DB.PlayerRadius / 0.58f, Gfx.Hdr(ch.color, 1.2f, g.z / 0.28f * 0.45f), V(ch.shape, 0.31f, 0, 1), V(0, 0, 0, 0));
            float pulse = ultActive > 0f ? 1.6f + 0.4f * Mathf.Sin(Gfx.Time * 20f) : 1f;
            Gfx.Light(pos, 430f, ch.color, 2.0f * pulse);
            Gfx.Under.Quad(pos, 74f, Gfx.Hdr(ch.color, 0.32f * pulse), V(10));
            float alpha = invuln > 0f && dashT <= 0f && hurtFlash <= 0f ? 0.55f + 0.45f * Mathf.Round(Mathf.Repeat(invuln * 10f, 1f)) : 1f;
            Gfx.Player.Quad(pos, DB.PlayerRadius / 0.58f, Gfx.Hdr(ch.color, 1.5f * pulse, alpha), V(ch.shape, 0.31f, hurtFlash > 0f ? 1f : 0f, 1), V(0, look.x, look.y, ch.hat ? 1 : 0));

            // 아군 탄환
            foreach (var p in projs)
            {
                if (p.kind == 0) { Gfx.Over.Quad(p.pos, 15f, Gfx.Hdr(p.color, 2.2f), V(3)); Gfx.Over.Seg(p.pos - p.vel.normalized * 26f, p.pos, 6f, Gfx.Hdr(p.color, 0.9f), V(6, 3f, 0)); Gfx.Light(p.pos, 110f, p.color, 0.6f); }
                else { Vector2 d = p.vel.normalized; Gfx.Over.Seg(p.pos - d * 60f, p.pos + d * 10f, 7f, Gfx.Hdr(p.color, 2.6f), V(6, 4f, 0)); Gfx.Light(p.pos, 150f, p.color, 0.8f); }
            }
            // 이펙트
            foreach (var x in fx)
            {
                float f = x.t / x.dur, inv = 1f - f;
                switch (x.type)
                {
                    case 0: { float r = Mathf.Lerp(x.r0, x.r1, f), big = Mathf.Max(x.r0, x.r1) * 1.08f; Gfx.Over.Quad(x.a, big, Gfx.Hdr(x.color, 1.1f * inv), V(9, r / big, Mathf.Max(0.012f, x.w / big * (1f - f * 0.5f)))); Gfx.Light(x.a, big * 1.3f, x.color, 0.9f * inv); break; }
                    case 1: Gfx.Over.Seg(x.a, x.b, x.w * (0.6f + inv), Gfx.Hdr(x.color, 2.6f * inv), V(6, 10f, 1f)); Gfx.Light((x.a + x.b) * 0.5f, (x.b - x.a).magnitude * 0.6f + 60f, x.color, 0.5f * inv); break;
                    case 2: Gfx.Over.Quad(x.a, new Vector2(x.r0, x.r0) * 1.25f, x.ang, Gfx.Hdr(x.color, 2.4f * inv), V(7, 1.15f)); Gfx.Light(x.a, x.r0 * 1.8f, x.color, 0.8f * inv); break;
                    default: Gfx.Over.Seg(x.a + new Vector2(0, 460f), x.a, 9f * inv + 3f, Gfx.Hdr(x.color, 2.2f * inv), V(6, 3f, 0)); Gfx.Over.Quad(x.a, x.r0 * 1.2f, Gfx.Hdr(x.color, 1.6f * inv), V(9, 0.5f + 0.4f * f, 0.06f)); Gfx.Over.Quad(x.a, x.r0, Gfx.Hdr(x.color, 1.8f * inv), V(0)); Gfx.Light(x.a, x.r0 * 3.5f, x.color, 1.6f * inv); break;
                }
            }
            foreach (var p in parts) { float f = p.life / p.max; Gfx.Over.Quad(p.pos, p.size * (0.5f + f), Gfx.Hdr(p.color, 2.0f * f), V(p.shape)); }
            // 시퀀싱실 스캔 레이저
            if (laserState != 0)
            {
                float y0 = camPos.y - 460f, y1 = camPos.y + 460f;
                if (laserState == 1)
                {
                    float bl = 0.55f + 0.45f * Mathf.Sin(laserWarn * 22f);
                    Gfx.Bullets.Seg(new Vector2(laserX + laserDir * 40f, y0), new Vector2(laserX + laserDir * 40f, y1), 3f, Gfx.Hdr(DB.Yellow, 1.6f * bl), V(6, 60f, 0f));
                    for (int k = -2; k <= 2; k++) Gfx.Bullets.Quad(new Vector2(laserX + laserDir * (70f + 14f * Mathf.Repeat(Gfx.Time * 3f, 1f)), camPos.y + k * 150f), 14f, Gfx.Hdr(DB.Yellow, 1.8f * bl), V(5));
                }
                else
                {
                    Gfx.Bullets.Seg(new Vector2(laserX, y0), new Vector2(laserX, y1), 20f, Gfx.Hdr(DB.Green, 3.0f), V(6, 60f, 1f));
                    Gfx.Bullets.Seg(new Vector2(laserX - laserDir * 26f, y0), new Vector2(laserX - laserDir * 26f, y1), 34f, Gfx.Hdr(DB.Green, 0.5f), V(6, 60f, 0f));
                    for (int k = -2; k <= 2; k++) Gfx.Light(new Vector2(laserX, camPos.y + k * 190f), 260f, DB.Green, 0.9f);
                }
            }
            // 적 탄환
            foreach (var b in bullets)
            {
                if (!InView(b.pos, 30f)) continue;
                if (b.kind == 0) Gfx.Bullets.Quad(b.pos, b.radius * 2.1f, Gfx.Hdr(b.color, 1.9f), V(4));
                else
                {
                    // 방울(1)·막대(2)·네모 조각(3): 날아가는 방향으로 돌려 그린다
                    float ba = Mathf.Atan2(b.vel.y, b.vel.x), fadeB = Mathf.Clamp01(b.life / 0.25f);
                    float sz = b.radius * (b.kind == 2 ? 2.6f : 2.3f);
                    Gfx.Bullets.Quad(b.pos, new Vector2(sz, sz), b.kind == 3 ? ba + Gfx.Time * 5f : ba, Gfx.Hdr(b.color, 2.0f * fadeB), V(11 + b.kind));
                }
            }
        }

        void DrawBoss(Enemy b)
        {
            Color c = b.bdef.color; float fl = b.flash > 0f ? 0.38f : 0f, hot = b.stage2 ? 1.65f : (b.phase2 ? 1.35f : 1f);
            if (b.invulnT > 0f) fl = 0.45f + 0.35f * Mathf.Sin(Gfx.Time * 24f);          // 2단계로 변신하는 중: 하얗게 번쩍인다
            if (b.stage2) Gfx.Under.Quad(b.pos, b.radius * 2.3f, Gfx.Hdr(c, 0.9f), V(9, 0.80f + 0.06f * Mathf.Sin(Gfx.Time * 5f), 0.035f));
            Gfx.Light(b.pos, b.radius * 9f, c, 1.8f * hot);
            Gfx.Under.Quad(b.pos, b.radius * 3.2f, Gfx.Hdr(c, 0.45f * hot), V(10));
            if (b.bdef.id == "mold_wreath")
            {
                // 화환: 포자낭을 고리 모양으로 엮는다
                int n = 12;
                for (int i = 0; i < n; i++)
                {
                    float a = b.facing + 6.2832f * i / n;
                    Vector2 p = b.pos + new Vector2(Mathf.Cos(a), Mathf.Sin(a)) * b.radius * 0.72f;
                    Color cc = i % 3 == 0 ? DB.Yellow : c;
                    Gfx.BossBody.Quad(p, b.radius * 0.36f / 0.6f, Gfx.Hdr(cc, 1.7f * hot), V(14, i * 0.137f, fl, 1), V(a, bossIntro > 0f ? 1f : 0f, 0, 0));
                }
                Gfx.BossBody.Quad(b.pos, b.radius * 0.5f, Gfx.Hdr(c, 1.2f * hot), V(10, 0.5f, fl, 1), V(0, 0, 0, 0));
                // 빨간 리본
                Gfx.Top.Quad(b.pos + new Vector2(0, -b.radius * 0.78f), b.radius * 0.34f, Gfx.Hdr(DB.Red, 2.0f), V(5));
            }
            else if (b.bdef.id == "concatemer")
            {
                // 긴 리드: 염기 색 구슬이 줄줄이. 머리만 맞는다.
                int segs = SnakeSegs(b); Color[] bases = { DB.Green, DB.Red, DB.Cyan, DB.Yellow }; Vector2 prev = b.pos;
                for (int i = 1; i <= segs; i++)
                {
                    int ti = i * 4; if (ti >= snakeTrail.Count) break;
                    Vector2 p = snakeTrail[ti];
                    Gfx.Under.Seg(prev, p, 5f, Gfx.Hdr(c, 0.9f), V(6, 60f, 0f));
                    Gfx.Bullets.Quad(p, 15f, Gfx.Hdr(bases[(i * 7 + i / 3) % 4], 1.8f), V(4));
                    prev = p;
                }
                Gfx.BossBody.Quad(b.pos, b.radius / 0.42f, Gfx.Hdr(c, 1.9f * hot), V(10, 0.3f, fl, 1), V(b.facing, 0, 0, 0));
                Gfx.Top.Quad(b.pos, b.radius * 1.25f, Gfx.Hdr(c, 1.4f), V(1, 0.82f, 0.05f));
            }
            else if (b.bdef.id == "adapter_dimer")
            {
                int arms = b.phase3 ? 4 : 2;
                for (int i = 0; i < arms; i++)
                {
                    float a = b.bossA + 6.2832f * i / arms; Vector2 u = new Vector2(Mathf.Cos(a), Mathf.Sin(a)), p1 = b.pos + u * b.bossC;
                    Color ac = i % 2 == 0 ? DB.Cyan : DB.Orange;
                    Gfx.Bullets.Seg(b.pos + u * b.radius * 0.5f, p1, 9f, Gfx.Hdr(ac, 2.4f), V(6, 30f, 1f));
                    Gfx.Bullets.Quad(p1, 30f, Gfx.Hdr(ac, 2.0f), V(8)); Gfx.Light(p1, 150f, ac, 0.8f);
                }
                Gfx.BossBody.Quad(b.pos, b.radius / 0.52f, Gfx.Hdr(c, 1.7f * hot), V(12, 0.4f, fl, 1), V(b.bossA * 0.5f, 0, 0, 0));
                Gfx.Top.Quad(b.pos, 16f, Gfx.Hdr(DB.Cyan, 2.2f), V(8));
            }
            else if (b.bdef.id == "reviewer2" || b.bdef.id == "reviewer1")
            {
                Vector2 lk = pos - b.pos; float la = Mathf.Atan2(lk.y, lk.x);
                Vector2 bp = b.pos + new Vector2(0f, Mathf.Sin(Gfx.Time * 1.6f) * 5f);
                Gfx.BossBody.Quad(bp, b.radius / 0.62f, Gfx.Hdr(c, 1.7f * hot), V(17, la, fl, b.bdef.id == "reviewer1" ? 0f : 1f), V(0, b.charge, 0, 0));
                // 주위를 도는 빨간 펜 끝
                int pens = b.phase3 ? 5 : (b.phase2 ? 4 : 3);
                for (int i = 0; i < pens; i++)
                {
                    float a = Gfx.Time * (b.phase3 ? 2.6f : 1.3f) + 6.2832f * i / pens;
                    Vector2 p = bp + new Vector2(Mathf.Cos(a), Mathf.Sin(a) * 0.62f) * b.radius * 1.55f;
                    Gfx.Top.Quad(p, 10f, Gfx.Hdr(c, 2.4f), V(5)); Gfx.Light(p, 70f, c, 0.5f);
                }
            }
            else
            {
                Gfx.BossBody.Quad(b.pos, b.radius / 0.34f, Gfx.Hdr(c, 1.8f * hot), V(13, 0.2f, fl, 1), V(b.facing, Mathf.Max(b.charge, b.phase2 ? 0.4f : 0f), 0, 1));
            }
        }
    }
}
