using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace CS
{
    /// 시작점. 씬에는 아무것도 두지 않고 전부 코드로 만든다(카메라·후처리·오디오·UI·월드).
    /// 흐름: 타이틀(뒤에서 자동 시연이 돈다) → 실험 준비(구역·셀라인) → 런 → 결과
    public class Game : MonoBehaviour
    {
        public static Game I;
        public const float Step = 1f / 60f;       // 시뮬레이션 고정 간격
        public Camera cam;
        public World world;
        public TitleScene title;
        public Ui ui;
        public Bloom bloom; public Vignette vignette; public ChromaticAberration chroma; public ColorAdjustments grade;
        float acc, finishT;
        public bool paused, attract;
        bool resultShown;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void Boot()
        {
            if (I != null) return;
            foreach (var go in SceneManager.GetActiveScene().GetRootGameObjects()) DestroyImmediate(go);
            var g = new GameObject("Game");
            DontDestroyOnLoad(g);
            I = g.AddComponent<Game>();
        }

        void Awake()
        {
            I = this;
            Application.runInBackground = true;
            QualitySettings.vSyncCount = 1;
            var cgo = new GameObject("Camera") { tag = "MainCamera" };
            cgo.transform.SetParent(transform, false);
            cgo.transform.position = new Vector3(0, 0, -10);
            cam = cgo.AddComponent<Camera>();
            cam.orthographic = true; cam.orthographicSize = 330f;
            cam.clearFlags = CameraClearFlags.SolidColor; cam.backgroundColor = Color.black;
            cam.nearClipPlane = 0.1f; cam.farClipPlane = 50f; cam.allowHDR = true;
            cgo.AddComponent<AudioListener>();
            cam.GetUniversalAdditionalCameraData().renderPostProcessing = true;
            cam.allowMSAA = false;
            SetupPostFX();
            Gfx.Init(transform);
            Gfx.SetupLightBuffer(cam);
            SetupQuality();
            Save.Load();
            Audio.Init(gameObject);
            ui = gameObject.AddComponent<Ui>(); ui.Init();
            Dev.Load();
#if UNITY_EDITOR
            EditorVSync(!Dev.Has("perf") || Dev.Has("vsync"));     // 성능 측정 때만 풀어서 잰다
#endif
            if (Dev.Has("lang")) Save.D.lang = Dev.S("lang", "ko") == "en" ? 1 : 0;
            Debug.Log("[cs] boot ok  unity=" + Application.unityVersion + "  screen=" + Screen.width + "x" + Screen.height);
            string scr = Dev.S("screen", "");
            if (Dev.Has("autoplay") || scr == "levelup" || scr == "result" || scr == "ending" || scr == "pause" || scr == "run") StartRun(Dev.S("char", "hek293t"), Dev.S("zone", "dish"));
            else { ToTitle(); if (scr == "prep") ui.ShowPrep(); if (scr == "credits") ui.ShowCredits(); if (scr == "settings") ui.ShowSettings(); if (scr == "lab") ui.ShowLab(); if (scr == "codex") ui.ShowCodex((int)Dev.F("cat", 0)); }
            if (scr == "levelup") world.AddXp(60);
            if (scr == "result" || scr == "ending") world.After(0.5f, () => world.Finish(Dev.Has("win") || scr == "ending"));
        }

        void SetupPostFX()
        {
            var go = new GameObject("PostFX");
            go.transform.SetParent(transform, false);
            var vol = go.AddComponent<Volume>();
            vol.isGlobal = true; vol.priority = 10;
            var p = ScriptableObject.CreateInstance<VolumeProfile>();
            p.hideFlags = HideFlags.DontSave;
            bloom = p.Add<Bloom>(true);
            bloom.threshold.value = 0.95f; bloom.intensity.value = 1.15f; bloom.scatter.value = 0.74f;
            bloom.highQualityFiltering.value = false; bloom.maxIterations.value = 5;
            var tm = p.Add<Tonemapping>(true); tm.mode.value = TonemappingMode.Neutral;
            vignette = p.Add<Vignette>(true); vignette.intensity.value = 0.42f; vignette.smoothness.value = 0.55f; vignette.rounded.value = false;
            chroma = p.Add<ChromaticAberration>(true); chroma.intensity.value = 0.12f;
            var grain = p.Add<FilmGrain>(true); grain.type.value = FilmGrainLookup.Thin1; grain.intensity.value = 0.22f; grain.response.value = 0.7f;
            grade = p.Add<ColorAdjustments>(true); grade.contrast.value = 8f; grade.saturation.value = 6f; grade.postExposure.value = 0f;
            vol.profile = p;
        }

        // ── 화질: 내부 렌더 해상도를 낮춰 그리고 화면 크기로 늘린다(UI는 항상 원래 해상도). ──
        // 그래픽 설정 0 자동(1440p 상한에서 시작, 느리면 더 낮춤) / 1 낮음 900p / 2 보통 1260p / 3 높음 1800p / 4 최고(원래 해상도)
        UniversalRenderPipelineAsset urp; float urpScale0 = 1f; int urpMsaa0 = 1;
        float dynScale = 1f, appliedScale = -1f, ftAcc, qT, goodT; int ftN;
        public static readonly int[] QualityCap = { 1440, 900, 1260, 1800, 100000 };
        void SetupQuality()
        {
            urp = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
            if (urp == null) return;
            urpScale0 = urp.renderScale; urpMsaa0 = urp.msaaSampleCount;
            urp.msaaSampleCount = 1;
            dynScale = Mathf.Clamp(QualityCap[Mathf.Clamp(Save.D.gfx, 0, 4)] / (float)Mathf.Max(1, Screen.height), 0.3f, 1f);
        }
        void OnDestroy()
        {
            if (urp != null) { urp.renderScale = urpScale0; urp.msaaSampleCount = urpMsaa0; }      // 에디터에서는 에셋이 바뀐 채 남지 않게 되돌린다
        }
        float ceilScale = 1f, ceilT, settleT = 2f, lvuiT; bool wasRunning;
        void TickQuality(float udt)
        {
            if (urp == null) return;
            int g = Mathf.Clamp(Dev.Has("gfx") ? (int)Dev.F("gfx", 0) : Save.D.gfx, 0, 4);
            float maxScale = Mathf.Clamp(QualityCap[g] / (float)Mathf.Max(1, Screen.height), 0.3f, 1f);
            if (g == 0)
            {
                // 일시정지·레벨업 창이 떠 있는 동안과 그 직후, 런 시작 직후의 프레임은 재지 않는다(창을 만드느라 한두 프레임 튀는 것을 '느리다'로 오해하지 않게)
                if (paused || ui.ModalOpen) settleT = 1.5f;
                if (settleT > 0f) { settleT -= udt; ftAcc = 0f; ftN = 0; qT = 0f; }
                else
                {
                    ftAcc += Mathf.Min(udt, 0.06f); ftN++; qT += udt;
                    if (qT >= 1.0f)
                    {
                        float avg = ftAcc / ftN * 1000f; ftAcc = 0f; ftN = 0; qT = 0f;
                        float minScale = Mathf.Min(maxScale, 720f / Mathf.Max(1, Screen.height));
                        if (avg > 21f)
                        {
                            // 느리다 → 낮추고, 방금 그 해상도는 한동안(90초) 다시 시도하지 않는다
                            ceilScale = Mathf.Max(minScale, dynScale * 0.94f); ceilT = 90f;
                            dynScale = Mathf.Max(minScale, dynScale * 0.86f); goodT = 0f;
                        }
                        else if (avg < 17.6f) { goodT += 1f; if (goodT > 10f && dynScale < Mathf.Min(maxScale, ceilScale)) { dynScale = Mathf.Min(Mathf.Min(maxScale, ceilScale), dynScale * 1.05f); goodT = 6f; } }
                        else goodT = 0f;
                    }
                }
                if (ceilT > 0f) { ceilT -= udt; if (ceilT <= 0f) ceilScale = 1f; }
            }
            else { dynScale = maxScale; ceilScale = 1f; }
            dynScale = Mathf.Min(dynScale, maxScale);
            if (Mathf.Abs(dynScale - appliedScale) > 0.012f) { appliedScale = dynScale; urp.renderScale = dynScale; Gfx.RenderScale = dynScale; }
        }

        // ── 흐름 ──
        public void ToTitle()
        {
            attract = true; paused = false; resultShown = false; Time.timeScale = Dev.F("timescale", 1f);
            Gfx.Time = 0f; acc = 0f; world = null;
            if (title == null) title = new TitleScene(transform);
            title.Begin();
            Audio.PlayMusic("title");
            ui.ShowTitle();
        }

        public void StartRun(string charId, string zoneId, int diff = -1)
        {
            attract = false; paused = false; resultShown = false; finishT = 0f;
            Gfx.Time = 0f; acc = 0f;
            if (title != null) title.Visible = false;
            ui.Close();
            if (Dev.Has("hpA")) DB.HpA = Dev.F("hpA", DB.HpA); if (Dev.Has("hpB")) DB.HpB = Dev.F("hpB", DB.HpB); if (Dev.Has("spawnmul")) DB.SpawnMul = Dev.F("spawnmul", 1f); if (Dev.Has("dmgA")) DB.DmgPerMin = Dev.F("dmgA", DB.DmgPerMin);
            if (diff < 0) diff = Dev.Has("diff") ? (int)Dev.F("diff", 1) : Save.D.lastDiff;
            world = new World();
            world.Begin(DB.Char(charId), DB.Zone(zoneId), diff);
            settleT = 2.5f; Audio.Preload("boss", 2);
        }

        public void Resume() { ui.Close(); paused = false; world.ClearInput(); }
        public void AfterLevelUp()
        {
            world.pendingLevelUps--;
            if (world.pendingLevelUps > 0) ui.ShowLevelUp(world); else { paused = false; world.ClearInput(); }
        }

#if UNITY_EDITOR
        // 에디터에서는 진짜 전체화면이 안 된다(Unity 제약). 대신 게임 뷰를 최대화/복원한다.
        static UnityEditor.EditorWindow GameView()
        {
            var t = typeof(UnityEditor.EditorWindow).Assembly.GetType("UnityEditor.GameView");
            return t != null ? UnityEditor.EditorWindow.GetWindow(t, false, null, false) : null;
        }
        public bool IsFullscreen { get { var gv = GameView(); return gv != null && gv.maximized; } }
        /// 에디터의 게임 뷰는 기본이 수직동기 꺼짐이라 프레임이 풀려서 돈다(몇 프레임 몰아 그리고 한 번 길게 멈추는 식으로 끊겨 보인다).
        /// 빌드처럼 화면 주사율에 맞춰 돌도록 게임 뷰의 VSync를 켠다. 못 켜면 주사율로 프레임을 제한한다.
        static void EditorVSync(bool on)
        {
            string how = "none";
            try
            {
                var gv = GameView();
                if (gv != null)
                {
                    const System.Reflection.BindingFlags bf = System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic;
                    for (var t = gv.GetType(); t != null && how == "none"; t = t.BaseType)
                    {
                        var p = t.GetProperty("vSyncEnabled", bf | System.Reflection.BindingFlags.DeclaredOnly);
                        if (p != null && p.CanWrite) { p.SetValue(gv, on); how = "property"; }
                    }
                }
            }
            catch (System.Exception e) { how = "error " + e.GetType().Name; }
            int hz = Mathf.RoundToInt((float)Screen.currentResolution.refreshRateRatio.value); if (hz < 30) hz = 60;
            Application.targetFrameRate = on && how != "property" ? hz : -1;
            Debug.Log("[cs] editor vsync=" + on + " via " + how + " refresh=" + hz);
        }
        public void ToggleFullscreen() { var gv = GameView(); if (gv != null) gv.maximized = !gv.maximized; }
#else
        public bool IsFullscreen => Screen.fullScreen;
        public void ToggleFullscreen()
        {
            if (Screen.fullScreen) Screen.SetResolution(1600, 900, FullScreenMode.Windowed);
            else { var r = Screen.currentResolution; Screen.SetResolution(r.width, r.height, FullScreenMode.FullScreenWindow); }
        }
#endif

        void OnFinished()
        {
            resultShown = true; paused = true;
            var r = world.result;
            r.grant = (int)(r.time / 10f) + r.kills / 25 + r.bossKills * 40;
            if (r.victory) r.grant = (int)(r.grant * 1.5f);
            r.grant = (int)(r.grant * DB.Diffs[r.diff].grant * (1f + 0.10f * Save.Upgrade("funding")));
            Save.D.grant += r.grant; Save.D.totalGrant += r.grant; Save.D.runs++;
            Save.D.bestKills = Mathf.Max(Save.D.bestKills, r.kills);
            if (r.victory)
            {
                Save.D.clears++;
                string baseId = DB.Zone(r.zoneId).variantOf ?? r.zoneId;      // 변형(롱리드 등)을 깨도 본 구역이 깨진 것으로 친다
                if (r.zoneId != baseId && !Save.Cleared(r.zoneId)) Save.D.clearedZones.Add(r.zoneId);
                if (!Save.Cleared(baseId))
                {
                    Save.D.clearedZones.Add(baseId);
                    int idx = System.Array.FindIndex(DB.Zones, z => z.id == baseId);
                    if (idx + 1 < DB.Zones.Length) r.unlocked.Add("구역 " + DB.Zones[idx + 1].name);
                    foreach (var c in DB.Chars) if (c.unlock == "zone1" && r.zoneId == "dish") r.unlocked.Add("셀라인 " + c.name);
                }
            }
            Save.Write();
            if (!Dev.Has("autoplay")) PlayLog.Write(world, r);
            bool finale = r.victory && r.zoneId == DB.Zones[DB.Zones.Length - 1].id;
            if (finale || Dev.S("screen", "") == "ending") ui.ShowEnding(r); else ui.ShowResult(r);
        }

        void Update()
        {
            Dev.PreUpdate();
            float dt = Time.deltaTime;
            Audio.Muffle = paused && !attract && world != null && !world.finished;
            Audio.Update(Time.unscaledDeltaTime);
            if (Inp.Fullscreen) ToggleFullscreen();
            TickQuality(Time.unscaledDeltaTime);
            if (attract)
            {
                title.Tick(dt); Gfx.Time += dt;
                Gfx.Begin(); title.Draw(); Gfx.End();
                ui.Tick(null, false);
                Dev.PostUpdate();
                return;
            }
            bool auto = Dev.Has("autoplay");
            if (!paused) world.PollInput();
            if (world.pendingLevelUps > 0 && !world.finished)
            {
                if (auto && !Dev.Has("lvui")) while (world.pendingLevelUps > 0) { world.pendingLevelUps--; world.Apply(world.BotPick(world.BuildOptions(3))); }
                else if (!ui.ModalOpen) { paused = true; Audio.Play("levelup"); ui.ShowLevelUp(world); lvuiT = 0f; }
                else if (auto) { lvuiT += Time.unscaledDeltaTime; if (lvuiT > Dev.F("lvui", 0.8f)) { lvuiT = 0f; if (ui.DevPickLevel(world)) Dev.LvUps++; } }   // 개발용: 사람처럼 창을 띄웠다가 고른다
            }
            if (!world.finished && !paused && Inp.Pause) { paused = true; ui.ShowPause(world); }
            long t0 = System.Diagnostics.Stopwatch.GetTimestamp();
            if (!paused && dt > 0f)
            {
                // 화면 한 장마다 그 프레임 시간만큼 정확히 진행한다. 길면 1/60초 이하로 쪼갠다.
                // (예전에는 1/60초 고정 틱을 모아서 돌렸는데, 화면 주기와 어긋나면 0틱·2틱 프레임이 섞여 끊겨 보였다)
                float fdt = Mathf.Min(dt, 0.25f);
                int n = Mathf.Max(1, Mathf.CeilToInt(fdt / Step - 0.02f));
                float sdt = fdt / n;
                for (int i = 0; i < n; i++) world.Tick(sdt);
                Gfx.Time += dt;
                if (wasRunning && !world.finished) world.FrameStat(Time.unscaledDeltaTime);     // 창을 닫은 바로 다음 프레임은 빼고 센다
            }
            wasRunning = !paused;
            long t1 = System.Diagnostics.Stopwatch.GetTimestamp();
            if (world.finished)
            {
                if (!resultShown) { finishT += Time.unscaledDeltaTime; Gfx.Time += Time.unscaledDeltaTime * 0.3f; if (finishT > 1.3f) OnFinished(); }
            }
            Gfx.Begin();
            world.Draw();
            Gfx.End();
            long t2 = System.Diagnostics.Stopwatch.GetTimestamp();
            ui.Tick(world, true);
            long t3 = System.Diagnostics.Stopwatch.GetTimestamp();
            double k = 1000.0 / System.Diagnostics.Stopwatch.Frequency;
            Dev.Cpu((float)((t1 - t0) * k), (float)((t2 - t1) * k), (float)((t3 - t2) * k));
            Dev.PostUpdate();
        }
    }
}
