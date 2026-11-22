using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace CS
{
    /// 매 프레임 다시 채우는 쿼드 묶음. 개체 수백 개를 드로콜 한 번으로 그린다.
    /// 정점 데이터: uv0 = (쿼드 좌표 -1..1, 반크기), uv1 = p1, uv2 = HDR 색, uv3 = p2  → 셰이더 CSCommon.hlsl 참고
    public class QuadBatch
    {
        readonly Mesh mesh;
        readonly List<Vector3> v = new List<Vector3>(1024);
        readonly List<Vector4> uv0 = new List<Vector4>(1024), a1 = new List<Vector4>(1024), cl = new List<Vector4>(1024), a2 = new List<Vector4>(1024);
        readonly List<int> tri = new List<int>(1536);
        public readonly MeshRenderer renderer;
        public int Count => v.Count / 4;

        public QuadBatch(string name, Material mat, int order, Transform parent)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            mesh = new Mesh { name = name, indexFormat = IndexFormat.UInt32 };
            mesh.MarkDynamic();
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            renderer = go.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = mat;
            renderer.sortingOrder = order;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            renderer.lightProbeUsage = LightProbeUsage.Off;
            renderer.reflectionProbeUsage = ReflectionProbeUsage.Off;
        }

        public void Clear() { v.Clear(); uv0.Clear(); a1.Clear(); cl.Clear(); a2.Clear(); tri.Clear(); }

        void Push(Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3, Vector2 half, Vector4 color, Vector4 pa, Vector4 pb)
        {
            int n = v.Count;
            v.Add(p0); v.Add(p1); v.Add(p2); v.Add(p3);
            uv0.Add(new Vector4(-1, -1, half.x, half.y)); uv0.Add(new Vector4(1, -1, half.x, half.y));
            uv0.Add(new Vector4(1, 1, half.x, half.y)); uv0.Add(new Vector4(-1, 1, half.x, half.y));
            for (int i = 0; i < 4; i++) { a1.Add(pa); cl.Add(color); a2.Add(pb); }
            tri.Add(n); tri.Add(n + 1); tri.Add(n + 2); tri.Add(n); tri.Add(n + 2); tri.Add(n + 3);
        }

        public void Quad(Vector2 c, Vector2 half, float rot, Vector4 color, Vector4 pa = default, Vector4 pb = default)
        {
            Vector2 ax, ay;
            if (rot == 0f) { ax = new Vector2(half.x, 0); ay = new Vector2(0, half.y); }
            else { float s = Mathf.Sin(rot), co = Mathf.Cos(rot); ax = new Vector2(co, s) * half.x; ay = new Vector2(-s, co) * half.y; }
            Push(c - ax - ay, c + ax - ay, c + ax + ay, c - ax + ay, half, color, pa, pb);
        }

        public void Quad(Vector2 c, float half, Vector4 color, Vector4 pa = default, Vector4 pb = default) { Quad(c, new Vector2(half, half), 0f, color, pa, pb); }

        /// a→b 선분을 폭 halfW*2 쿼드로. 셰이더에서 uv.x가 길이 방향.
        public void Seg(Vector2 a, Vector2 b, float halfW, Vector4 color, Vector4 pa = default, Vector4 pb = default)
        {
            Vector2 d = b - a; float len = d.magnitude; if (len < 0.0001f) return;
            Vector2 ax = d * 0.5f, ay = new Vector2(-d.y, d.x) / len * halfW, c = (a + b) * 0.5f;
            Push(c - ax - ay, c + ax - ay, c + ax + ay, c - ax + ay, new Vector2(len * 0.5f, halfW), color, pa, pb);
        }

        public void Apply()
        {
            mesh.Clear();
            if (v.Count == 0) return;
            mesh.SetVertices(v); mesh.SetUVs(0, uv0); mesh.SetUVs(1, a1); mesh.SetUVs(2, cl); mesh.SetUVs(3, a2);
            mesh.SetTriangles(tri, 0, false);
            mesh.bounds = new Bounds(Vector3.zero, new Vector3(1e6f, 1e6f, 10f));
        }
    }

    /// 그리기 층. 숫자가 클수록 위.
    public static class Gfx
    {
        public static QuadBatch Floor, Lights, Under, Pickups, Enemies, Player, Over, Bullets, Top;
        public static QuadBatch BossBody;
        static readonly List<QuadBatch> all = new List<QuadBatch>();
        static readonly int idTime = Shader.PropertyToID("_CSTime"), idZone = Shader.PropertyToID("_CSZone"), idArena = Shader.PropertyToID("_CSArena");
        public static float Time;   // 셰이더 애니메이션 시간(일시정지 때 멈춤)

        public static Material Mat(string shader)
        {
            var sh = Resources.Load<Shader>("Shaders/" + shader);
            if (sh == null) { Debug.LogError("[cs] shader not found: " + shader); sh = Shader.Find("Universal Render Pipeline/2D/Sprite-Unlit-Default"); }
            return new Material(sh) { hideFlags = HideFlags.DontSave };
        }

        public static void Init(Transform root)
        {
            all.Clear();
            Material glow = Mat("Glow"), org = Mat("Organism");
            Floor = Add("Floor", Mat("Floor"), -100, root);
            Lights = Add("Lights", Mat("FloorLight"), -90, root);
            Under = Add("Under", glow, -50, root);       // 장판·경고·후광
            Pickups = Add("Pickups", glow, 0, root);
            Enemies = Add("Enemies", org, 10, root);
            BossBody = Add("Boss", org, 15, root);
            Player = Add("Player", org, 20, root);
            Over = Add("Over", glow, 30, root);          // 아군 탄환·이펙트
            Bullets = Add("Bullets", glow, 40, root);    // 적 탄환
            Top = Add("Top", glow, 50, root);            // 화면 맨 위 이펙트
        }

        static QuadBatch Add(string n, Material m, int order, Transform root) { var b = new QuadBatch(n, m, order, root); all.Add(b); return b; }
        public static void Begin() { foreach (var b in all) b.Clear(); Shader.SetGlobalFloat(idTime, Time); }
        public static void End() { foreach (var b in all) b.Apply(); UpdateLightBuffer(); }

        // ── 조명 누적 버퍼: 빛 쿼드는 화면의 1/4 해상도 텍스처에만 그린다(4K에서도 싸다) ──
        const int LightLayer = 30;
        static Camera mainCam, lightCam; static RenderTexture lightRT;
        static readonly int idLightTex = Shader.PropertyToID("_CSLightTex"), idLightRect = Shader.PropertyToID("_CSLightRect");
        public static void SetupLightBuffer(Camera main)
        {
            mainCam = main;
            main.cullingMask &= ~(1 << LightLayer);
            Lights.renderer.gameObject.layer = LightLayer;
            var go = new GameObject("LightCamera"); go.transform.SetParent(main.transform, false);
            lightCam = go.AddComponent<Camera>();
            lightCam.orthographic = true; lightCam.clearFlags = CameraClearFlags.SolidColor; lightCam.backgroundColor = Color.black;
            lightCam.cullingMask = 1 << LightLayer; lightCam.depth = main.depth - 10; lightCam.allowHDR = true; lightCam.allowMSAA = false;
            lightCam.nearClipPlane = main.nearClipPlane; lightCam.farClipPlane = main.farClipPlane;
            var data = lightCam.GetUniversalAdditionalCameraData(); data.renderPostProcessing = false; data.antialiasing = AntialiasingMode.None;
            UpdateLightBuffer();
        }
        /// 진단용: 조명 버퍼 한가운데 픽셀 값
        public static string LightProbe()
        {
            if (lightRT == null) return "no RT";
            var prev = RenderTexture.active; RenderTexture.active = lightRT;
            var t = new Texture2D(1, 1, TextureFormat.RGBAHalf, false);
            t.ReadPixels(new Rect(lightRT.width / 2, lightRT.height / 2, 1, 1), 0, 0); t.Apply();
            var c = t.GetPixel(0, 0); RenderTexture.active = prev; Object.Destroy(t);
            return "rt=" + lightRT.width + "x" + lightRT.height + " created=" + lightRT.IsCreated() + " cam=" + (lightCam != null && lightCam.isActiveAndEnabled) + " mask=" + lightCam.cullingMask + " layer=" + Lights.renderer.gameObject.layer + " center=" + c.r.ToString("0.000") + "," + c.g.ToString("0.000") + "," + c.b.ToString("0.000");
        }
        static void UpdateLightBuffer()
        {
            if (lightCam == null) return;
            int w = Mathf.Clamp(Screen.width / 4, 320, 1280), h = Mathf.Clamp(Mathf.RoundToInt(w * (float)Screen.height / Mathf.Max(1, Screen.width)), 180, 720);
            if (lightRT == null || lightRT.width != w || lightRT.height != h)
            {
                if (lightRT != null) { lightCam.targetTexture = null; lightRT.Release(); Object.Destroy(lightRT); }
                lightRT = new RenderTexture(w, h, 16, RenderTextureFormat.ARGBHalf) { name = "CSLight", filterMode = FilterMode.Bilinear, wrapMode = TextureWrapMode.Clamp, hideFlags = HideFlags.DontSave };
                lightRT.Create(); lightCam.targetTexture = lightRT;
                Shader.SetGlobalTexture(idLightTex, lightRT);
            }
            lightCam.orthographicSize = mainCam.orthographicSize;
            float hh = mainCam.orthographicSize, hw = hh * w / h; Vector3 p = mainCam.transform.position;
            Shader.SetGlobalVector(idLightRect, new Vector4(p.x - hw, p.y - hh, 0.5f / hw, 0.5f / hh));
        }
        public static string Stats() { int q = 0; foreach (var b in all) q += b.Count; return "quads=" + q + " lights=" + Lights.Count + " scale=" + RenderScale.ToString("0.00"); }
        public static float RenderScale = 1f;
        /// 진단용: 층마다 쿼드 수 (F L U P E B Pl O Bu T 순서)
        public static string Dump() { var sb = new System.Text.StringBuilder(); foreach (var b in all) sb.Append(b.Count).Append(','); return sb.ToString(); }
        public static void SetArena(int zone, Vector2 size) { Shader.SetGlobalFloat(idZone, zone); Shader.SetGlobalVector(idArena, new Vector4(size.x, size.y, 0, 0)); }

        /// 형광색 × 밝기(1을 넘으면 블룸이 번진다)
        public static Vector4 Hdr(Color c, float intensity = 1f, float alpha = 1f) { return new Vector4(c.r * intensity, c.g * intensity, c.b * intensity, alpha); }
        /// 바닥에 떨어지는 빛
        public static void Light(Vector2 pos, float radius, Color c, float intensity) { Lights.Quad(pos, radius, Hdr(c, intensity)); }
    }
}
