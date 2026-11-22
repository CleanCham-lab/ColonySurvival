// 빌드 스크립트. 메뉴(Colony Survival ▸ Build ▸ …)나 AgentBridge의 exec 명령으로 부른다.
//   결과물: <프로젝트>/Builds/mac-arm64, mac-x64, win64   로그: AgentBridge/build.log
using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace CS.Bridge
{
    public static class Build
    {
        const string Version = "3.0.0";
        static string Root => Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
        static void Log(string s) { try { File.AppendAllText(Path.Combine(Root, "AgentBridge/build.log"), DateTime.Now.ToString("HH:mm:ss ") + s + "\n"); } catch { } Debug.Log("[build] " + s); }

        static void Common()
        {
            PlayerSettings.productName = "Colony Survival";
            PlayerSettings.companyName = "CleanCham-lab";
            PlayerSettings.bundleVersion = Version;
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Standalone, "com.cleanchamlab.colonysurvival");
            PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
            PlayerSettings.defaultScreenWidth = 1600; PlayerSettings.defaultScreenHeight = 900;
            PlayerSettings.resizableWindow = true;
            PlayerSettings.runInBackground = true;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Standalone, ScriptingImplementation.Mono2x);
            SetIcon();
        }

        // 앱 아이콘: Assets/Icon/icon.png (1024×1024, 투명 배경의 둥근 네모)를 기본 아이콘으로 지정한다. 맥 .icns와 윈도우 exe 아이콘이 여기서 만들어진다.
        const string IconPath = "Assets/Icon/icon.png";
        static void SetIcon()
        {
            try
            {
                var imp = AssetImporter.GetAtPath(IconPath) as TextureImporter;
                if (imp == null) { Log("icon: " + IconPath + " 가 없습니다 — 기본 아이콘으로 빌드합니다"); return; }
                if (imp.textureCompression != TextureImporterCompression.Uncompressed || imp.mipmapEnabled || !imp.alphaIsTransparency || imp.npotScale != TextureImporterNPOTScale.None)
                {
                    imp.textureCompression = TextureImporterCompression.Uncompressed; imp.mipmapEnabled = false; imp.alphaIsTransparency = true; imp.npotScale = TextureImporterNPOTScale.None; imp.maxTextureSize = 1024;
                    imp.SaveAndReimport();
                }
                var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(IconPath);
                PlayerSettings.SetIcons(NamedBuildTarget.Unknown, new[] { tex }, IconKind.Any);
                Log("icon: set (" + tex.width + "x" + tex.height + ")");
            }
            catch (Exception e) { Log("icon: EXCEPTION " + e.Message); }
        }

        static string[] Scenes()
        {
            var s = EditorBuildSettings.scenes.Where(x => x.enabled && File.Exists(x.path)).Select(x => x.path).ToArray();
            if (s.Length == 0) s = AssetDatabase.FindAssets("t:Scene", new[] { "Assets" }).Select(AssetDatabase.GUIDToAssetPath).Take(1).ToArray();
            return s;
        }

        // macOS 아키텍처: "ARM64" | "x64" | "x64ARM64"
        static void MacArch(string arch)
        {
            bool ok = false;
            try
            {
                Type t = null;
                foreach (var asm in AppDomain.CurrentDomain.GetAssemblies()) { t = asm.GetType("UnityEditor.OSXStandalone.UserBuildSettings"); if (t != null) break; }
                var p = t != null ? t.GetProperty("architecture", System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.Public) : null;
                if (p != null) { p.SetValue(null, Enum.Parse(p.PropertyType, arch, true)); ok = true; }
            }
            catch (Exception e) { Log("arch via UserBuildSettings failed: " + e.Message); }
            if (!ok) EditorUserBuildSettings.SetPlatformSettings("OSXUniversal", "Architecture", arch);
            Log("mac architecture = " + arch + (ok ? "" : " (platform setting)"));
        }

        static void Run(BuildTarget target, string path, string label)
        {
            try
            {
                if (!BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Standalone, target)) { Log(label + ": FAILED — 이 Unity에 해당 빌드 모듈이 설치되어 있지 않습니다 (" + target + ")"); return; }
                Common();
                var scenes = Scenes();
                if (scenes.Length == 0) { Log(label + ": FAILED — 씬이 없습니다"); return; }
                string full = Path.Combine(Root, path);
                Directory.CreateDirectory(Path.GetDirectoryName(full));
                Log(label + ": start → " + path + "  scenes=" + string.Join(",", scenes));
                var rep = BuildPipeline.BuildPlayer(new BuildPlayerOptions { scenes = scenes, locationPathName = full, target = target, targetGroup = BuildTargetGroup.Standalone, options = BuildOptions.None });
                var sm = rep.summary;
                bool exists = File.Exists(full) || Directory.Exists(full);
                bool ok = sm.result == BuildResult.Succeeded && sm.totalErrors == 0 && exists;
                Log(label + ": " + (ok ? "OK" : "FAILED") + "  size=" + (sm.totalSize / 1048576) + "MB  time=" + (int)sm.totalTime.TotalSeconds + "s  errors=" + sm.totalErrors + "  warnings=" + sm.totalWarnings);
                if (!exists) Log("  결과물이 없습니다 — 이 플랫폼의 빌드 모듈이 설치되어 있는지 확인하세요 (Unity Hub ▸ Installs ▸ Add modules).");
                if (!ok)
                    foreach (var step in rep.steps) foreach (var m in step.messages) if (m.type == LogType.Error) Log("  error: " + m.content);
            }
            catch (Exception e) { Log(label + ": EXCEPTION " + e); }
        }

        [MenuItem("Colony Survival/Build/macOS (Apple Silicon)")]
        public static void MacSilicon() { MacArch("ARM64"); Run(BuildTarget.StandaloneOSX, "Builds/mac-arm64/Colony Survival.app", "mac-arm64"); }
        [MenuItem("Colony Survival/Build/macOS (Intel)")]
        public static void MacIntel() { MacArch("x64"); Run(BuildTarget.StandaloneOSX, "Builds/mac-x64/Colony Survival.app", "mac-x64"); }
        [MenuItem("Colony Survival/Build/Windows (x64)")]
        public static void Windows() { Run(BuildTarget.StandaloneWindows64, "Builds/win64/ColonySurvival.exe", "win64"); }
        [MenuItem("Colony Survival/Build/All")]
        public static void All() { MacSilicon(); MacIntel(); Windows(); BackToMac(); }

        // ── 배포용 묶음: Builds/ 의 세 빌드를 Release/ 아래 zip 3개로 ──
        // 맥에서 직접 ditto로 묶는다(실행 권한·심볼릭 링크·서명이 그대로 보존된다). 각 zip에 HOW_TO_PLAY.txt를 같이 넣는다.
        static int Sh(string exe, string args, out string output)
        {
            var p = new System.Diagnostics.Process();
            p.StartInfo = new System.Diagnostics.ProcessStartInfo(exe, args) { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
            p.Start(); string o = p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd(); p.WaitForExit();
            output = o.Trim(); return p.ExitCode;
        }
        static string Q(string s) { return "\"" + s + "\""; }

        static void PackOne(string build, string name, bool mac)
        {
            // 임시 폴더(시스템 temp)에서 묶는다 — 프로젝트가 iCloud가 관리하는 폴더 아래에 있으면 파일에 Finder 정보 같은 확장 속성이 붙어서
            // 서명이 깨진다("resource fork, Finder information, or similar detritus not allowed"). 깨진 서명으로 배포하면 받은 사람 맥에서 "손상되었습니다"가 뜬다.
            string tmp = Path.Combine(Path.GetTempPath(), "cs_pkg_" + name);
            try
            {
                string src = Path.Combine(Root, "Builds", build), rel = Path.Combine(Root, "Release"), stage = Path.Combine(tmp, name), zip = Path.Combine(rel, name + ".zip");
                if (!Directory.Exists(src)) { Log("package " + name + ": FAILED — 빌드가 없습니다 (" + build + ")"); return; }
                if (Directory.Exists(tmp)) Directory.Delete(tmp, true);
                Directory.CreateDirectory(stage); Directory.CreateDirectory(rel);
                string o, app = null;
                foreach (var e in Directory.GetFileSystemEntries(src))
                {
                    string fn = Path.GetFileName(e);
                    if (fn.Contains("DontShipItWithYourGame") || fn.Contains("DoNotShip") || fn == ".DS_Store") continue;      // 디버그용 폴더는 배포하지 않는다
                    Sh("/usr/bin/ditto", "--norsrc --noextattr --noqtn " + Q(e) + " " + Q(Path.Combine(stage, fn)), out o);
                    if (mac && fn.EndsWith(".app")) app = Path.Combine(stage, fn);
                }
                Sh("/usr/bin/xattr", "-cr " + Q(stage), out o);
                if (mac && app != null)
                {
                    // 임시(ad-hoc) 서명을 새로 붙이고 확인한다. 애플 실리콘에서는 서명이 온전해야 "그래도 열기"로 열 수 있다.
                    int sg = Sh("/usr/bin/codesign", "--force --deep --sign - " + Q(app), out o);
                    if (sg != 0) Log("  " + name + ": 서명 실패: " + o);
                    int v = Sh("/usr/bin/codesign", "--verify --deep --strict " + Q(app), out o);
                    Log("  " + name + ": codesign " + (v == 0 ? "ok" : "FAILED " + o));
                }
                string howto = Path.Combine(Root, "HOW_TO_PLAY.txt");
                if (File.Exists(howto)) File.Copy(howto, Path.Combine(stage, "HOW_TO_PLAY.txt"), true);
                if (File.Exists(zip)) File.Delete(zip);
                int z = Sh("/usr/bin/ditto", "-c -k " + (mac ? "--sequesterRsrc" : "--norsrc --noextattr") + " --keepParent " + Q(stage) + " " + Q(zip), out o);
                bool ok = z == 0 && File.Exists(zip);
                Log("package " + name + ": " + (ok ? "OK  " + (new FileInfo(zip).Length / 1048576) + "MB" : "FAILED " + o));
                if (ok && mac && app != null)
                {
                    // 만든 zip을 다시 풀어서, 받는 사람 쪽에서도 서명이 온전하고 실행 권한이 남아 있는지 확인한다
                    string chk = Path.Combine(tmp, "check");
                    Sh("/usr/bin/ditto", "-x -k " + Q(zip) + " " + Q(chk), out o);
                    string app2 = Path.Combine(chk, name, Path.GetFileName(app));
                    int v2 = Sh("/usr/bin/codesign", "--verify --deep --strict " + Q(app2), out o);
                    string exe = Path.Combine(app2, "Contents/MacOS/Colony Survival"); string o2;
                    Sh("/bin/ls", "-l " + Q(exe), out o2);
                    string arch; Sh("/usr/bin/lipo", "-archs " + Q(exe), out arch);
                    Log("  " + name + ": zip을 풀어 확인 — 서명 " + (v2 == 0 ? "ok" : "FAILED " + o) + ", 실행 파일 " + (o2.StartsWith("-rwx") ? "실행 권한 있음" : "권한 이상: " + o2) + ", 아키텍처 " + arch);
                }
            }
            catch (Exception e) { Log("package " + name + ": EXCEPTION " + e.Message); }
            finally { try { if (Directory.Exists(tmp)) Directory.Delete(tmp, true); } catch { } }
        }

        [MenuItem("Colony Survival/Build/Package (zip 3종)")]
        public static void Package()
        {
            if (Application.platform != RuntimePlatform.OSXEditor) { Log("package: 맥 에디터에서만 됩니다(ditto 사용)"); return; }
            PackOne("mac-arm64", "ColonySurvival_v" + Version + "_macOS_AppleSilicon", true);
            PackOne("mac-x64", "ColonySurvival_v" + Version + "_macOS_Intel", true);
            PackOne("win64", "ColonySurvival_v" + Version + "_Windows", false);
            string st = Path.Combine(Root, "Release", "stage"); if (Directory.Exists(st)) Directory.Delete(st, true);
            Log("package: done → Release/");
        }

        /// 방금 만든 맥 빌드를 9초 동안 실제로 띄워 보고 닫는다(로그: AgentBridge/player_smoke.log).
        public static void Smoke()
        {
            string app = Path.Combine(Root, "Builds/mac-arm64/Colony Survival.app/Contents/MacOS/Colony Survival"), log = Path.Combine(Root, "AgentBridge/player_smoke.log");
            try
            {
                if (File.Exists(log)) File.Delete(log);
                var p = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(app, "-logFile " + Q(log)) { UseShellExecute = false });
                System.Threading.Thread.Sleep(9000);
                bool alive = !p.HasExited;
                if (alive) p.Kill();
                Log("smoke: " + (alive ? "9초 동안 실행된 뒤 닫음" : "일찍 꺼짐 (exit " + p.ExitCode + ")"));
            }
            catch (Exception e) { Log("smoke: EXCEPTION " + e.Message); }
        }

        /// 빌드 대상을 다시 macOS로 돌려놓는다(에디터에서 Play할 때는 맥이 기준).
        public static void BackToMac()
        {
            if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.StandaloneOSX)
                Log("switch back to macOS: " + EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Standalone, BuildTarget.StandaloneOSX));
        }

        /// 에디터를 같은 프로젝트로 다시 연다(새로 설치한 빌드 모듈을 인식시키려고).
        public static void Restart() { Log("restarting editor"); EditorApplication.OpenProject(Root); }

        public static void Info() { Log("activeBuildTarget=" + EditorUserBuildSettings.activeBuildTarget + "  win64 supported=" + BuildPipeline.IsBuildTargetSupported(BuildTargetGroup.Standalone, BuildTarget.StandaloneWindows64) + "  scene=" + UnityEngine.SceneManagement.SceneManager.GetActiveScene().path); }
    }
}
