using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace CS
{
    [Serializable]
    public class SaveData
    {
        public int grant, totalGrant, runs, clears, bestKills;
        public float master = 0.8f, music = 0.55f, sfx = 0.8f;
        public bool shake = true, damageNumbers = true, fullscreen;
        public List<string> clearedZones = new List<string>();      // 클리어한 구역
        public List<string> unlocked = new List<string>();          // 해금한 셀라인·유물
        public List<string> codex = new List<string>();             // 도감에 기록된 것
        public List<string> upgradeIds = new List<string>(); public List<int> upgradeLv = new List<int>();
        public string lastChar = "hek293t", lastZone = "dish"; public int lastDiff = 1;
        public int gfx;            // 그래픽: 0 자동, 1 낮음, 2 보통, 3 높음, 4 최고
        public int lang = -1;      // -1 아직 안 고름(시스템 언어를 따른다), 0 한국어, 1 English
    }

    /// 메타 진행 저장 (persistentDataPath/save.json)
    public static class Save
    {
        public static SaveData D = new SaveData();
        static string PathFile => Path.Combine(Application.persistentDataPath, "save.json");

        public static void Load()
        {
            try { if (File.Exists(PathFile)) D = JsonUtility.FromJson<SaveData>(File.ReadAllText(PathFile)) ?? new SaveData(); }
            catch (Exception e) { Debug.LogWarning("save load failed: " + e.Message); D = new SaveData(); }
            if (D.lang < 0) D.lang = Application.systemLanguage == SystemLanguage.Korean ? 0 : 1;
        }
        public static void Write()
        {
            if (Dev.Has("autoplay") || Dev.Has("nosave")) return;      // 자동 테스트 결과는 세이브에 남기지 않는다
            WriteNow();
        }
        static void WriteNow()
        {
            try { File.WriteAllText(PathFile, JsonUtility.ToJson(D, true)); }
            catch (Exception e) { Debug.LogWarning("save failed: " + e.Message); }
        }
        public static bool Cleared(string zone) { return D.clearedZones.Contains(zone); }
        public static bool ZoneOpen(int idx) { return idx == 0 || Cleared(DB.Zones[idx - 1].id); }
        public static bool CharOpen(CharDef c) { return c.unlock == "" || D.unlocked.Contains(c.id) || (c.unlock == "zone1" && Cleared("dish")); }
        public static int Upgrade(string id)
        {
            if (Dev.Has("upg")) { foreach (var u in DB.Upgrades) if (u.id == id) return Mathf.Min((int)Dev.F("upg", 0), u.max); return 0; }      // 테스트: 모든 강화를 같은 단계로
            int i = D.upgradeIds.IndexOf(id); return i < 0 ? 0 : D.upgradeLv[i]; }
        public static void SetUpgrade(string id, int lv) { int i = D.upgradeIds.IndexOf(id); if (i < 0) { D.upgradeIds.Add(id); D.upgradeLv.Add(lv); } else D.upgradeLv[i] = lv; }
        public static void Discover(string id) { if (!D.codex.Contains(id)) D.codex.Add(id); }
    }
}
