// 개발용 브리지: 에디터 밖에서 파일로 명령을 보내고(AgentBridge/cmd.txt) 상태를 읽는다(AgentBridge/state.json).
// 게임 코드와 분리된 어셈블리라서 게임 스크립트에 컴파일 오류가 있어도 계속 동작한다.
//   cmd.txt 형식:  "<번호> <명령> [인자...]"   (번호가 바뀌면 실행)
//   명령: refresh | play | stop | gameview W H | exec Namespace.Type.Method | ping
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEditor.Compilation;
using UnityEngine;

namespace CS.Bridge
{
    [InitializeOnLoad]
    public static class Bridge
    {
        static readonly string Dir = Path.GetFullPath(Path.Combine(Application.dataPath, "../AgentBridge"));
        const string K_LAST = "cs.bridge.lastCmd";
        const string K_ERR = "cs.bridge.errors";
        const string K_PENDING_PLAY = "cs.bridge.pendingPlay";
        static double nextPoll, nextBeat;
        static readonly List<string> compileErrors = new List<string>();
        static readonly StringBuilder pendingLog = new StringBuilder();
        static readonly object logLock = new object();
        static string note = "loaded";

        static Bridge()
        {
            try { Directory.CreateDirectory(Dir); Directory.CreateDirectory(Path.Combine(Dir, "shots")); } catch { }
            var saved = SessionState.GetString(K_ERR, "");
            if (saved.Length > 0) compileErrors.AddRange(saved.Split('\n'));
            EditorApplication.update += Tick;
            CompilationPipeline.compilationStarted += _ => { compileErrors.Clear(); SessionState.SetString(K_ERR, ""); note = "compiling"; WriteState(); };
            CompilationPipeline.assemblyCompilationFinished += (asm, msgs) =>
            {
                foreach (var m in msgs)
                    if (m.type == CompilerMessageType.Error)
                        compileErrors.Add(m.file + "(" + m.line + "," + m.column + "): " + m.message);
                SessionState.SetString(K_ERR, string.Join("\n", compileErrors));
            };
            CompilationPipeline.compilationFinished += _ => { note = compileErrors.Count > 0 ? "compile_failed" : "compiled"; WriteState(); };
            Application.logMessageReceivedThreaded += OnLog;
            EditorApplication.playModeStateChanged += s =>
            {
                if (s == PlayModeStateChange.ExitingEditMode) { try { File.WriteAllText(Path.Combine(Dir, "console.log"), ""); } catch { } }
                note = "playmode:" + s; WriteState();
            };
            WriteState();
        }

        static void OnLog(string msg, string stack, LogType type)
        {
            bool mine = msg.StartsWith("[cs]");
            if (type == LogType.Log && !mine) return;
            lock (logLock)
            {
                pendingLog.Append(type == LogType.Log ? "" : "[" + type + "] ").Append(msg).Append('\n');
                if (type == LogType.Exception || type == LogType.Error)
                {
                    var lines = stack.Split('\n');
                    for (int i = 0; i < lines.Length && i < 6; i++) if (lines[i].Length > 0) pendingLog.Append("    ").Append(lines[i]).Append('\n');
                }
            }
        }

        static void Tick()
        {
            double now = EditorApplication.timeSinceStartup;
            if (now < nextPoll) return;
            nextPoll = now + 0.4;
            FlushLog();
            if (SessionState.GetBool(K_PENDING_PLAY, false) && !EditorApplication.isCompiling && !EditorApplication.isUpdating && !EditorApplication.isPlayingOrWillChangePlaymode)
            {
                SessionState.SetBool(K_PENDING_PLAY, false);
                if (compileErrors.Count == 0) EditorApplication.EnterPlaymode(); else { note = "play_blocked_by_compile_errors"; }
            }
            try
            {
                var p = Path.Combine(Dir, "cmd.txt");
                if (File.Exists(p))
                {
                    var raw = File.ReadAllText(p).Trim();
                    var sp = raw.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                    if (sp.Length >= 2 && int.TryParse(sp[0], out int id) && id != SessionState.GetInt(K_LAST, -1))
                    {
                        SessionState.SetInt(K_LAST, id);
                        Run(sp);
                    }
                }
            }
            catch (Exception e) { note = "cmd_error: " + e.Message; }
            if (now >= nextBeat) { nextBeat = now + 1.0; WriteState(); }
        }

        static void Run(string[] a)
        {
            note = "cmd:" + a[1];
            switch (a[1])
            {
                case "ping": break;
                case "refresh":
                    AssetDatabase.Refresh();
                    break;
                case "play": // refresh → (컴파일 끝나면) 플레이
                    if (EditorApplication.isPlaying) EditorApplication.ExitPlaymode();
                    AssetDatabase.Refresh();
                    SessionState.SetBool(K_PENDING_PLAY, true);
                    break;
                case "stop":
                    SessionState.SetBool(K_PENDING_PLAY, false);
                    if (EditorApplication.isPlaying) EditorApplication.ExitPlaymode();
                    break;
                case "gameview":
                    try { PlayModeWindow.SetCustomRenderingResolution(uint.Parse(a[2]), uint.Parse(a[3]), "CS " + a[2] + "x" + a[3]); }
                    catch (Exception e) { note = "gameview_error: " + e.Message; }
                    break;
                case "exec":
                    {
                        int dot = a[2].LastIndexOf('.');
                        var typeName = a[2].Substring(0, dot); var method = a[2].Substring(dot + 1);
                        Type t = null;
                        foreach (var asm in AppDomain.CurrentDomain.GetAssemblies()) { t = asm.GetType(typeName); if (t != null) break; }
                        if (t == null) { note = "exec: type not found " + typeName; break; }
                        var mi = t.GetMethod(method, System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic);
                        if (mi == null) { note = "exec: method not found " + method; break; }
                        mi.Invoke(null, null);
                        break;
                    }
                default: note = "unknown_cmd:" + a[1]; break;
            }
            WriteState();
        }

        static void FlushLog()
        {
            string s;
            lock (logLock) { if (pendingLog.Length == 0) return; s = pendingLog.ToString(); pendingLog.Length = 0; }
            try { File.AppendAllText(Path.Combine(Dir, "console.log"), s); } catch { }
        }

        static string Esc(string s) { return s.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\n", "\\n").Replace("\r", ""); }

        static void WriteState()
        {
            try
            {
                var sb = new StringBuilder();
                sb.Append("{\n");
                sb.Append("  \"lastCmd\": ").Append(SessionState.GetInt(K_LAST, -1)).Append(",\n");
                sb.Append("  \"note\": \"").Append(Esc(note)).Append("\",\n");
                sb.Append("  \"compiling\": ").Append(EditorApplication.isCompiling ? "true" : "false").Append(",\n");
                sb.Append("  \"updating\": ").Append(EditorApplication.isUpdating ? "true" : "false").Append(",\n");
                sb.Append("  \"playing\": ").Append(EditorApplication.isPlaying ? "true" : "false").Append(",\n");
                sb.Append("  \"pendingPlay\": ").Append(SessionState.GetBool(K_PENDING_PLAY, false) ? "true" : "false").Append(",\n");
                sb.Append("  \"focused\": ").Append(UnityEditorInternal.InternalEditorUtility.isApplicationActive ? "true" : "false").Append(",\n");
                sb.Append("  \"unity\": \"").Append(Application.unityVersion).Append("\",\n");
                sb.Append("  \"time\": \"").Append(DateTime.Now.ToString("HH:mm:ss")).Append("\",\n");
                sb.Append("  \"errors\": [");
                for (int i = 0; i < compileErrors.Count && i < 40; i++) sb.Append(i > 0 ? "," : "").Append("\n    \"").Append(Esc(compileErrors[i])).Append("\"");
                sb.Append(compileErrors.Count > 0 ? "\n  ]\n" : "]\n");
                sb.Append("}\n");
                File.WriteAllText(Path.Combine(Dir, "state.json"), sb.ToString());
            }
            catch { }
        }
    }
}
