using UnityEngine;
using UnityEngine.UIElements;

namespace CS
{
    /// 무기·시약 그림 아이콘(글자 약어 대신 픽토그램). Painter2D로 그려서 어떤 크기에서도 선명하다.
    public class Icon : VisualElement
    {
        public string id; public Color col;
        public Icon(string id, Color col, float size)
        {
            this.id = id; this.col = col;
            style.width = size; style.height = size; pickingMode = PickingMode.Ignore;
            generateVisualContent += Gen;
        }
        public void Set(string i, Color c) { id = i; col = c; MarkDirtyRepaint(); }

        void Gen(MeshGenerationContext m)
        {
            var p = m.painter2D; var r = contentRect; float s = Mathf.Min(r.width, r.height) * 0.5f; Vector2 c = r.center;
            p.strokeColor = col; p.fillColor = col; p.lineWidth = Mathf.Max(1.5f, s * 0.13f); p.lineCap = LineCap.Round; p.lineJoin = LineJoin.Round;
            Vector2 P(float x, float y) { return c + new Vector2(x, y) * s * 0.78f; }
            void L(params float[] v) { p.BeginPath(); p.MoveTo(P(v[0], v[1])); for (int i = 2; i < v.Length; i += 2) p.LineTo(P(v[i], v[i + 1])); p.Stroke(); }
            void F(params float[] v) { p.BeginPath(); p.MoveTo(P(v[0], v[1])); for (int i = 2; i < v.Length; i += 2) p.LineTo(P(v[i], v[i + 1])); p.ClosePath(); p.Fill(); }
            void C(float x, float y, float rad) { p.BeginPath(); p.Arc(P(x, y), rad * s * 0.78f, 0f, 360f); p.Stroke(); }
            void D(float x, float y, float rad) { p.BeginPath(); p.Arc(P(x, y), rad * s * 0.78f, 0f, 360f); p.Fill(); }
            void A(float x, float y, float rad, float a0, float a1) { p.BeginPath(); p.Arc(P(x, y), rad * s * 0.78f, a0, a1); p.Stroke(); }
            switch (id)
            {
                case "qpcr_beam":      // 증폭 곡선
                    L(-0.9f, 0.8f, 0.9f, 0.8f); L(-0.9f, 0.8f, -0.9f, -0.9f);
                    p.BeginPath(); p.MoveTo(P(-0.8f, 0.6f)); p.BezierCurveTo(P(0.0f, 0.6f), P(0.0f, -0.7f), P(0.85f, -0.7f)); p.Stroke(); break;
                case "gel_cutter":     // 메스 + 젤 밴드
                    L(-0.8f, 0.8f, 0.2f, -0.2f); F(0.2f, -0.2f, 0.85f, -0.9f, 0.55f, -0.05f); L(-0.2f, 0.75f, 0.7f, 0.75f); L(0.1f, 0.35f, 0.8f, 0.35f); break;
                case "lentiviral_orb": // 바이러스
                    C(0, 0, 0.5f); D(0, 0, 0.2f);
                    for (int i = 0; i < 8; i++) { float a = i * 0.7854f; L(Mathf.Cos(a) * 0.5f, Mathf.Sin(a) * 0.5f, Mathf.Cos(a) * 0.85f, Mathf.Sin(a) * 0.85f); D(Mathf.Cos(a) * 0.9f, Mathf.Sin(a) * 0.9f, 0.09f); }
                    break;
                case "nanopore_ring":  // 육각 기공
                    p.BeginPath(); for (int i = 0; i <= 6; i++) { float a = i * 1.0472f + 0.5236f; var q = P(Mathf.Cos(a) * 0.85f, Mathf.Sin(a) * 0.85f); if (i == 0) p.MoveTo(q); else p.LineTo(q); }
                    p.Stroke(); C(0, 0, 0.32f); break;
                case "antibody_chain": // Y자 항체
                    L(0, 0.9f, 0, 0.05f); L(0, 0.05f, -0.65f, -0.75f); L(0, 0.05f, 0.65f, -0.75f); L(-0.25f, 0.0f, -0.85f, -0.45f); L(0.25f, 0.0f, 0.85f, -0.45f); break;
                case "centrifuge_wave":// 로터
                    C(0, 0, 0.85f); C(0, 0, 0.2f); for (int i = 0; i < 6; i++) { float a = i * 1.0472f; D(Mathf.Cos(a) * 0.55f, Mathf.Sin(a) * 0.55f, 0.12f); }
                    break;
                case "crispr_lance":   // 창
                    L(-0.85f, 0.85f, 0.35f, -0.35f); F(0.9f, -0.9f, 0.1f, -0.5f, 0.5f, -0.1f); L(-0.55f, 0.15f, -0.15f, 0.55f); break;
                case "uv_flash":       // 번개
                    F(0.2f, -0.95f, -0.55f, 0.1f, -0.05f, 0.1f, -0.25f, 0.95f, 0.6f, -0.2f, 0.05f, -0.2f); break;
                case "etoh_splash":    // 물방울
                    p.BeginPath(); p.MoveTo(P(0, -0.9f)); p.BezierCurveTo(P(0.9f, 0.1f), P(0.6f, 0.9f), P(0, 0.9f)); p.BezierCurveTo(P(-0.6f, 0.9f), P(-0.9f, 0.1f), P(0, -0.9f)); p.Stroke(); A(0, 0.25f, 0.35f, 20f, 100f); break;
                case "lysozyme_field": // 효소(팩맨) + 장
                    p.BeginPath(); p.Arc(P(0, 0), 0.5f * s * 0.78f, 35f, 325f); p.LineTo(P(0, 0)); p.ClosePath(); p.Fill(); A(0, 0, 0.9f, 200f, 340f); A(0, 0, 0.9f, 20f, 160f); break;
                case "fbs":            // 하트
                    p.BeginPath(); p.MoveTo(P(0, 0.85f)); p.BezierCurveTo(P(-1.3f, -0.1f), P(-0.6f, -1.1f), P(0, -0.35f)); p.BezierCurveTo(P(0.6f, -1.1f), P(1.3f, -0.1f), P(0, 0.85f)); p.Fill(); break;
                case "penstrep":       // 주사기
                    L(-0.8f, 0.8f, -0.4f, 0.4f); F(-0.5f, 0.2f, 0.3f, -0.6f, 0.6f, -0.3f, -0.2f, 0.5f); L(0.45f, -0.45f, 0.85f, -0.85f); L(0.6f, -0.95f, 0.95f, -0.6f); break;
                case "trypsin":        // 시계
                    C(0, 0.05f, 0.75f); L(0, 0.05f, 0, -0.4f); L(0, 0.05f, 0.35f, 0.25f); L(-0.25f, -0.95f, 0.25f, -0.95f); break;
                case "agarose":        // 넓어지는 범위
                    C(0, 0, 0.3f); L(-0.9f, -0.5f, -0.9f, -0.9f, -0.5f, -0.9f); L(0.9f, -0.5f, 0.9f, -0.9f, 0.5f, -0.9f); L(-0.9f, 0.5f, -0.9f, 0.9f, -0.5f, 0.9f); L(0.9f, 0.5f, 0.9f, 0.9f, 0.5f, 0.9f); break;
                case "dmso":           // 모래시계
                    L(-0.6f, -0.9f, 0.6f, -0.9f, 0f, 0f, 0.6f, 0.9f, -0.6f, 0.9f, 0f, 0f, -0.6f, -0.9f); F(-0.35f, 0.85f, 0.35f, 0.85f, 0f, 0.3f); break;
                case "matrigel":       // 방패
                    p.BeginPath(); p.MoveTo(P(0, -0.9f)); p.LineTo(P(0.75f, -0.6f)); p.LineTo(P(0.75f, 0.1f)); p.BezierCurveTo(P(0.7f, 0.6f), P(0.3f, 0.8f), P(0, 0.95f)); p.BezierCurveTo(P(-0.3f, 0.8f), P(-0.7f, 0.6f), P(-0.75f, 0.1f)); p.LineTo(P(-0.75f, -0.6f)); p.ClosePath(); p.Stroke(); L(0, -0.4f, 0, 0.45f); L(-0.35f, 0f, 0.35f, 0f); break;
                case "egf":            // 빠르게(겹화살)
                    L(-0.8f, -0.7f, -0.1f, 0f, -0.8f, 0.7f); L(0f, -0.7f, 0.7f, 0f, 0f, 0.7f); break;
                case "lipofectamine":  // 자석
                    p.BeginPath(); p.MoveTo(P(-0.65f, -0.8f)); p.LineTo(P(-0.65f, 0.15f)); p.Arc(P(0, 0.15f), 0.65f * s * 0.78f, 180f, 0f, ArcDirection.CounterClockwise); p.LineTo(P(0.65f, -0.8f)); p.Stroke(); L(-0.9f, -0.5f, -0.4f, -0.5f); L(0.4f, -0.5f, 0.9f, -0.5f); break;
                case "heal":           // 코코아 컵
                    L(-0.6f, -0.2f, -0.6f, 0.8f, 0.4f, 0.8f, 0.4f, -0.2f, -0.6f, -0.2f); A(0.4f, 0.25f, 0.3f, -90f, 90f); L(-0.3f, -0.9f, -0.3f, -0.5f); L(0.1f, -0.9f, 0.1f, -0.5f); break;
                default: C(0, 0, 0.7f); break;
            }
        }
    }
}
