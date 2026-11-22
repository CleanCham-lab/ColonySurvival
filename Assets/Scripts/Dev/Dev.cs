using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace CS
{
    /// 개발용 자동 실행. 에디터에서 AgentBridge/run.txt 를 읽는다(빌드에서는 꺼져 있다).
    ///   key=value 한 줄씩:  autoplay=1  god=1  timescale=3  start=290  shots=2,10,30  quit=35  …
    public static class Dev
    {
        public static readonly Dictionary<string, string> cfg = new Dictionary<string, string>();
        public static bool Active;
        static string dir;
        static readonly List<float> shots = new List<float>();
        static int shotIdx;
        static float quitAt = -1f, realT;
        static bool quitting; static float nextStat, finT, perfT; static int pressIdx;
        static readonly List<float> frames = new List<float>(4096);

        public static bool Has(string k) { return Active && cfg.ContainsKey(k); }
        public static float F(string k, float d) { return Has(k) && float.TryParse(cfg[k], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float v) ? v : d; }
        public static string S(string k, string d) { return Has(k) ? cfg[k] : d; }

        public static void Load()
        {
            cfg.Clear(); shots.Clear(); shotIdx = 0; quitting = false; realT = 0f; finT = 0f; pressIdx = 0; Active = false; nextStat = 0f; quitAt = -1f;
#if UNITY_EDITOR
            dir = Path.GetFullPath(Path.Combine(Application.dataPath, "../AgentBridge"));
            string p = Path.Combine(dir, "run.txt");
            if (!File.Exists(p)) return;
            foreach (var line in File.ReadAllLines(p))
            {
                var s = line.Trim();
                if (s.Length == 0 || s.StartsWith("#")) continue;
                int eq = s.IndexOf('=');
                if (eq < 0) cfg[s] = "1"; else cfg[s.Substring(0, eq).Trim()] = s.Substring(eq + 1).Trim();
            }
            Active = cfg.Count > 0;
            if (!Active) return;
            if (cfg.ContainsKey("shots"))
                foreach (var t in cfg["shots"].Split(','))
                    if (float.TryParse(t, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out float v)) shots.Add(v);
            quitAt = F("quit", -1f);
            Time.timeScale = F("timescale", 1f);
            Directory.CreateDirectory(Path.Combine(dir, "shots"));
            Debug.Log("[cs] dev run: " + string.Join(" ", cfg));
            LvUps = 0; slowLogN = 0; dumpN = 0; dumpSb.Clear(); if (cfg.ContainsKey("perf")) StartRecs();
#endif
        }

        public static void PreUpdate() { }
#if UNITY_EDITOR
        // 프레임 시간 진단: 게임 쪽(PlayerLoop)과 에디터 쪽(EditorLoop)을 따로 잰다
        static string[] recNames = { "PlayerLoop" };
        static Unity.Profiling.ProfilerRecorder[] recs; static List<float>[] recVals;
        static void StartRecs()
        {
            if (recs != null) foreach (var r in recs) if (r.Valid) r.Dispose();
            var names = new List<string> { "PlayerLoop" }; foreach (var x in S("perfrec", "").Split(';')) if (x.Trim() != "") names.Add(x.Trim());
            recNames = names.ToArray();
            recs = new Unity.Profiling.ProfilerRecorder[recNames.Length]; recVals = new List<float>[recNames.Length];
            for (int i = 0; i < recNames.Length; i++) { recs[i] = new Unity.Profiling.ProfilerRecorder(recNames[i], 1); recs[i].Start(); recVals[i] = new List<float>(2048); }
            if (Has("perfnames"))
            {
                var hs = new List<Unity.Profiling.LowLevel.Unsafe.ProfilerRecorderHandle>(); Unity.Profiling.LowLevel.Unsafe.ProfilerRecorderHandle.GetAvailable(hs);
                foreach (var key in S("perfnames", "UI").Split(';'))
                {
                    var sb = new System.Text.StringBuilder();
                    foreach (var h in hs) { var d = Unity.Profiling.LowLevel.Unsafe.ProfilerRecorderHandle.GetDescription(h); if (d.Name.IndexOf(key, System.StringComparison.OrdinalIgnoreCase) >= 0) sb.Append(d.Name).Append(" | "); }
                    Debug.Log("[cs] markers(" + key + "): " + sb);
                }
            }
        }
        static string RecStats()
        {
            if (recs == null) return "";
            var sb = new System.Text.StringBuilder(" ||");
            for (int i = 0; i < recs.Length; i++)
            {
                var v = recVals[i]; if (!recs[i].Valid || v.Count < 10) continue;
                float sum = 0f; int big = 0; foreach (var x in v) { sum += x; if (x > 5f) big++; }
                v.Sort();
                sb.Append(' ').Append(recNames[i]).Append('=').Append((sum / v.Count).ToString("0.00")).Append('/').Append(v[(int)(v.Count * 0.95f)].ToString("0.0")).Append('/').Append(v[v.Count - 1].ToString("0.0")).Append("ms >5ms:").Append(big);
                v.Clear();
            }
            return sb.ToString();
        }
#endif
        static readonly System.Text.StringBuilder dumpSb = new System.Text.StringBuilder(); static int dumpN, slowLogN;
        static float cSim, cDraw, cUi, cMax; static int cN, slowN, midN, midHud; public static int LvUps;
        public static void Cpu(float sim, float draw, float ui) { if (!Active) return; cSim += sim; cDraw += draw; cUi += ui; cN++; cMax = Mathf.Max(cMax, sim + draw + ui); }

        public static void PostUpdate()
        {
            if (!Active || quitting) return;
            realT += Time.unscaledDeltaTime;
            if (Has("press"))
            {
                var seq = S("press", "").Split(',');
                int due = (int)((realT - 1.2f) / 0.6f);
                while (pressIdx < seq.Length && pressIdx <= due && realT > 1.2f)
                {
                    var kv = seq[pressIdx].Split(':'); pressIdx++;
                    string res = Game.I.ui.DevPress(int.Parse(kv[0]), kv.Length > 1 ? int.Parse(kv[1]) : 1);
                    Debug.Log("[cs] " + res + " → lang=" + Save.D.lang + " master=" + Save.D.master.ToString("0.00") + " music=" + Save.D.music.ToString("0.00") + " sfx=" + Save.D.sfx.ToString("0.00") + " gfx=" + Save.D.gfx + " | audio master=" + Audio.Master.ToString("0.00") + " music=" + Audio.Music.ToString("0.00") + " sfx=" + Audio.Sfx.ToString("0.00") + " | fullscreen=" + Game.I.IsFullscreen + " scale=" + Gfx.RenderScale.ToString("0.00"));
                }
            }
            // 성능: 구간마다 평균 fps, 95% 프레임 시간, 최악 프레임
            if (Has("perf"))
            {
                if (realT > 1.5f) { frames.Add(Time.unscaledDeltaTime * 1000f); if (Time.unscaledDeltaTime > 0.020f) slowN++; if (Time.unscaledDeltaTime > 0.009f) { midN++; if (Time.frameCount - Ui.HudTextFrame <= 1) midHud++; } }
#if UNITY_EDITOR
                if (recs != null && realT > 1.5f) for (int i = 0; i < recs.Length; i++) if (recs[i].Valid) recVals[i].Add(recs[i].LastValue * 1e-6f);
                // 길게 걸린 프레임 하나하나가 어디서 시간을 썼는지(앞 25개만)
                if (recs != null && realT > 3f && Has("slowlog") && Time.unscaledDeltaTime > F("slowlog", 0.024f) && slowLogN < 25)
                {
                    slowLogN++; var sl = new System.Text.StringBuilder("[cs] slowframe " + (Time.unscaledDeltaTime * 1000f).ToString("0") + "ms t=" + realT.ToString("0.0") + (Time.frameCount - Ui.HudTextFrame <= 1 ? " hudtext" : "") + (Game.I.paused ? " paused" : "") + " |");
                    for (int i = 0; i < recs.Length; i++) if (recs[i].Valid) sl.Append(' ').Append(recNames[i]).Append('=').Append((recs[i].LastValue * 1e-6f).ToString("0.0"));
                    Debug.Log(sl.ToString());
                }
#endif
                if (Has("perfdump") && realT > F("perfdump", 6f) && dumpN < 420) { dumpSb.Append((Time.unscaledDeltaTime * 1000f).ToString("0")).Append(':').Append(Gfx.Dump()).Append(' '); if (++dumpN == 420) Debug.Log("[cs] dump " + dumpSb); }
                perfT += Time.unscaledDeltaTime;
                if (perfT >= F("perf", 5f) && frames.Count > 10)
                {
                    perfT = 0f; float sum = 0f; foreach (var f in frames) sum += f;
                    frames.Sort(); float avg = sum / frames.Count;
                    var w = Game.I.world;
                    Debug.Log("[cs] perf " + Screen.width + "x" + Screen.height + " avg=" + (1000f / avg).ToString("0") + "fps (" + avg.ToString("0.0") + "ms) p95=" + frames[(int)(frames.Count * 0.95f)].ToString("0.0") + "ms max=" + frames[frames.Count - 1].ToString("0.0") + "ms" + (w != null ? " t=" + (int)w.t + " enemies=" + w.enemies.Count + " view=" + w.viewNow : " title") + " " + Gfx.Stats()
                        + (cN > 0 ? " | cpu sim=" + (cSim / cN).ToString("0.00") + " draw=" + (cDraw / cN).ToString("0.00") + " ui=" + (cUi / cN).ToString("0.00") + " max=" + cMax.ToString("0.0") + "ms" : "") + " slow(>20ms)=" + slowN + "/" + frames.Count + " mid(>9ms)=" + midN + " ofWhichHudText=" + midHud + " lvups=" + LvUps + (Has("lightdbg") ? " | " + Gfx.LightProbe() : "")
#if UNITY_EDITOR
                        + RecStats()
#endif
                        );
                    frames.Clear(); cSim = cDraw = cUi = cMax = 0f; cN = 0; slowN = 0; midN = 0; midHud = 0;
                }
            }
            float t = Has("realtime") ? realT : (Game.I.world != null ? Game.I.world.t : realT);
            while (shotIdx < shots.Count && t >= shots[shotIdx])
            {
                Shot("t" + shots[shotIdx].ToString("0000.#", System.Globalization.CultureInfo.InvariantCulture));
                shotIdx++;
            }
            if (Game.I.world != null && Game.I.world.t >= nextStat) { nextStat = Game.I.world.t + F("stat", 30f); Debug.Log("[cs] " + Game.I.world.Summary()); }
            bool fin = Game.I.world != null && Game.I.world.finished && quitAt >= 0f && Has("autoplay");
            if (fin) { finT += Time.unscaledDeltaTime; if (finT > 2.2f && finT - Time.unscaledDeltaTime <= 2.2f) Shot("end"); }
            if (quitAt >= 0f && ((t >= quitAt && shotIdx >= shots.Count) || finT > 3f))
            {
                quitting = true;
                Debug.Log("[cs] final " + (Game.I.world != null ? Game.I.world.Summary() : ""));
                Game.I.StartCoroutine(QuitSoon());
            }
        }

        public static void Shot(string name)
        {
            string p = Path.Combine(dir, "shots", name + ".png");
            ScreenCapture.CaptureScreenshot(p);
            Debug.Log("[cs] shot " + name + "  " + Screen.width + "x" + Screen.height);
        }

        static System.Collections.IEnumerator QuitSoon()
        {
            yield return new WaitForSecondsRealtime(0.6f);
#if UNITY_EDITOR
            UnityEditor.EditorApplication.ExitPlaymode();
#endif
        }
    }
}
