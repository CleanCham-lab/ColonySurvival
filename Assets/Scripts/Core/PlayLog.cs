using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace CS
{
    /// 사람이 플레이한 런의 기록. 난이도를 실제 플레이 기준으로 맞추기 위한 것(개인 정보는 없다).
    /// 한 판이 끝날 때마다 playlog.jsonl 에 한 줄씩 붙인다.
    ///   위치: Application.persistentDataPath/playlog.jsonl  (에디터에서는 프로젝트의 AgentBridge/playlog.jsonl 에도)
    [Serializable]
    public class PlayRecord
    {
        public string when, version, zone, cell, diff, platform, resolution;
        public bool victory; public float time, zoneLength, bossFight, renderScale;
        public int level, kills, bossKills, hits, dmgTaken, revivesLeft, grant;
        public string build, upgrades, deathBy;
        public float fps, frameP95, frameWorst; public int hitches;       // 화면 부드러움: 평균 fps, 95% 프레임 시간(ms), 가장 긴 프레임(ms), 25ms 넘은 프레임 수
        public List<int> minHitch = new List<int>();
        public List<int> minLevel = new List<int>(), minHp = new List<int>(), minHits = new List<int>(), minKills = new List<int>(), minView = new List<int>();
    }

    public static class PlayLog
    {
        public static void Minute(World w, PlayRecord r)
        {
            r.minLevel.Add(w.level); r.minHp.Add(Mathf.RoundToInt(w.hp / Mathf.Max(1f, w.maxHp) * 100f)); r.minHits.Add(w.hitsTaken); r.minKills.Add(w.kills);
            r.minView.Add(w.viewMinN > 0 ? Mathf.RoundToInt(w.viewMinAcc / w.viewMinN) : 0); w.viewMinAcc = 0f; w.viewMinN = 0;
            r.minHitch.Add(w.hitchMin); w.hitchMin = 0;
        }

        public static void Write(World w, RunResult res)
        {
            try
            {
                var r = w.record;
                r.when = DateTime.Now.ToString("yyyy-MM-dd HH:mm"); r.version = Application.version; r.platform = Application.platform.ToString(); r.resolution = Screen.width + "x" + Screen.height;
                r.zone = w.zone.id; r.cell = w.ch.id; r.diff = DB.Diffs[w.diffIdx].id; r.victory = res.victory; r.time = Mathf.Round(w.t); r.zoneLength = w.zone.length;
                r.bossFight = w.bossSpawnT >= 0f ? Mathf.Round((w.bossDeadT >= 0f ? w.bossDeadT : w.t) - w.bossSpawnT) : -1f;
                r.level = w.level; r.kills = w.kills; r.bossKills = w.bossKills; r.hits = w.hitsTaken; r.dmgTaken = Mathf.RoundToInt(w.dmgTaken); r.revivesLeft = w.revives; r.grant = res.grant;
                r.build = string.Join(", ", res.build); r.deathBy = res.victory ? "" : w.lastHurtBy; r.renderScale = Gfx.RenderScale;
                if (w.ftN > 0)
                {
                    r.fps = Mathf.Round(w.ftN / Mathf.Max(0.001f, w.ftSum) * 10f) / 10f; r.frameWorst = Mathf.Round(w.ftMax * 1000f); r.hitches = w.hitchN;
                    int acc = 0, target = Mathf.CeilToInt(w.ftN * 0.95f); for (int i = 0; i < w.ftHist.Length; i++) { acc += w.ftHist[i]; if (acc >= target) { r.frameP95 = i; break; } }
                }
                var up = new List<string>(); foreach (var u in DB.Upgrades) { int lv = Save.Upgrade(u.id); if (lv > 0) up.Add(u.id + ":" + lv); }
                r.upgrades = string.Join(",", up);
                string line = JsonUtility.ToJson(r) + "\n";
                File.AppendAllText(Path.Combine(Application.persistentDataPath, "playlog.jsonl"), line);
#if UNITY_EDITOR
                File.AppendAllText(Path.GetFullPath(Path.Combine(Application.dataPath, "../AgentBridge/playlog.jsonl")), line);
#endif
            }
            catch (Exception e) { Debug.LogWarning("playlog failed: " + e.Message); }
        }
    }
}
