using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace CS
{
    /// 월드 공간 글자. 동적 폰트에서 글리프를 꺼내 메시 하나로 만든다(HDR 색 → 블룸).
    /// 글자를 건너뛰고(skip) 그 자리를 돌려받을 수 있어서, 로고의 O 자리에 세포를 그려 넣는다.
    public class GlyphText
    {
        struct Run { public string s; public int px; public Vector2 pos; public float em, track; public Vector4 color, color2; public char skip; public float flicker; }
        public readonly GameObject go; readonly Mesh mesh; readonly MeshRenderer mr; readonly Material mat; readonly Font font;
        readonly List<Run> runs = new List<Run>();
        /// 건너뛴 글자의 자리(중심 x, 중심 y, 폭, 높이) — Apply 후에 채워진다
        public readonly List<Vector4> holes = new List<Vector4>();
        bool dirty;
        static readonly int idFade = Shader.PropertyToID("_Fade");

        public GlyphText(string fontPath, Transform parent, int order)
        {
            font = Resources.Load<Font>(fontPath);
            go = new GameObject("GlyphText"); go.transform.SetParent(parent, false);
            mesh = new Mesh { name = "GlyphText" }; mesh.MarkDynamic();
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            mr = go.AddComponent<MeshRenderer>();
            mat = Gfx.Mat("Glyph"); mat.mainTexture = font.material.mainTexture;
            mr.sharedMaterial = mat; mr.sortingOrder = order;
            mr.shadowCastingMode = ShadowCastingMode.Off; mr.receiveShadows = false;
            Font.textureRebuilt += f => { if (f == font) dirty = true; };
        }

        public bool Visible { set { mr.enabled = value; } }
        public float Fade { set { mat.SetFloat(idFade, value); } }
        public void Clear() { runs.Clear(); dirty = true; }

        /// em = 글자 크기(월드 단위), track = 자간(em 비율). pos = 글줄의 가운데·기준선
        public void Add(string s, Vector2 centerBaseline, float em, float track, Vector4 color, char skip = '\0', float flicker = 1f, Vector4? bottom = null)
        {
            int px = Mathf.Clamp(Mathf.CeilToInt(em * 1.8f), 32, 300);
            runs.Add(new Run { s = s, px = px, pos = centerBaseline, em = em, track = track, color = color, color2 = bottom ?? color, skip = skip, flicker = flicker });
            dirty = true;
        }

        public void Update() { if (dirty) Build(); }

        void Build()
        {
            dirty = false;
            foreach (var r in runs) font.RequestCharactersInTexture(r.s, r.px, FontStyle.Normal);
            var v = new List<Vector3>(); var uv = new List<Vector2>(); var col = new List<Vector4>(); var prm = new List<Vector4>(); var tri = new List<int>();
            holes.Clear();
            int gi = 0;
            foreach (var r in runs)
            {
                float k = r.em / r.px, trackPx = r.track * r.px, w = 0f;
                foreach (char c in r.s) { font.GetCharacterInfo(c, out var ci, r.px, FontStyle.Normal); w += ci.advance + trackPx; }
                w -= trackPx;
                float x = -w * 0.5f;
                foreach (char c in r.s)
                {
                    font.GetCharacterInfo(c, out var ci, r.px, FontStyle.Normal);
                    Vector2 a = r.pos + new Vector2(x + ci.minX, ci.minY) * k, b = r.pos + new Vector2(x + ci.maxX, ci.maxY) * k;
                    if (c == r.skip) holes.Add(new Vector4((a.x + b.x) * 0.5f, (a.y + b.y) * 0.5f, b.x - a.x, b.y - a.y));
                    else if (c != ' ')
                    {
                        int n = v.Count;
                        v.Add(new Vector3(a.x, a.y)); v.Add(new Vector3(b.x, a.y)); v.Add(new Vector3(b.x, b.y)); v.Add(new Vector3(a.x, b.y));
                        uv.Add(ci.uvBottomLeft); uv.Add(ci.uvBottomRight); uv.Add(ci.uvTopRight); uv.Add(ci.uvTopLeft);
                        var p = new Vector4(gi * 0.137f + 0.31f, r.flicker, 0, 0);
                        col.Add(r.color2); col.Add(r.color2); col.Add(r.color); col.Add(r.color); for (int i = 0; i < 4; i++) prm.Add(p);
                        tri.Add(n); tri.Add(n + 1); tri.Add(n + 2); tri.Add(n); tri.Add(n + 2); tri.Add(n + 3);
                    }
                    x += ci.advance + trackPx; gi++;
                }
            }
            mesh.Clear();
            mesh.SetVertices(v); mesh.SetUVs(0, uv); mesh.SetUVs(1, col); mesh.SetUVs(2, prm); mesh.SetTriangles(tri, 0, false);
            mesh.bounds = new Bounds(Vector3.zero, new Vector3(1e5f, 1e5f, 10f));
            mat.mainTexture = font.material.mainTexture;
        }
    }
}
