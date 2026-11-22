using System.Collections.Generic;
using UnityEngine;

namespace CS
{
    /// 효과음(풀링) + 배경음악.
    /// 음악은 길이가 똑같은 레이어(a 바탕 · b 리듬 · c 선율 · d 질주)를 동시에 틀어 두고,
    /// 긴장도(Intensity 0~1)에 따라 레이어를 켜고 끈다. 일시정지·레벨업 중에는 로우패스로 먹먹하게.
    public static class Audio
    {
        class Deck
        {
            public AudioSource[] src = new AudioSource[4]; public AudioLowPassFilter[] lp = new AudioLowPassFilter[4];
            public float[] gain = new float[4]; public int n; public string name = ""; public float fade;
        }

        static readonly Dictionary<string, AudioClip> clips = new Dictionary<string, AudioClip>();
        static readonly Dictionary<string, float> last = new Dictionary<string, float>();
        static AudioSource[] pool; static int next;
        static Deck cur, old;
        static float intensity, muffle, syncT;
        public static float Master = 0.8f, Music = 0.55f, Sfx = 0.8f;
        /// 목표 긴장도. 실제 값은 천천히 따라간다(레이어가 깜빡이지 않게).
        public static float Intensity;
        public static bool Muffle;
        public static float CurrentIntensity => intensity;
        public static string Current => cur != null ? cur.name : "";

        public static void Init(GameObject host)
        {
            pool = new AudioSource[14];
            for (int i = 0; i < pool.Length; i++) { pool[i] = host.AddComponent<AudioSource>(); pool[i].playOnAwake = false; }
            cur = NewDeck(host.transform, "MusicA"); old = NewDeck(host.transform, "MusicB");
            Master = Save.D.master; Music = Save.D.music; Sfx = Save.D.sfx;
        }

        static Deck NewDeck(Transform parent, string name)
        {
            var d = new Deck();
            for (int i = 0; i < 4; i++)
            {
                var go = new GameObject(name + i); go.transform.SetParent(parent, false);
                d.src[i] = go.AddComponent<AudioSource>(); d.src[i].playOnAwake = false; d.src[i].loop = true; d.src[i].volume = 0f;
                d.lp[i] = go.AddComponent<AudioLowPassFilter>(); d.lp[i].cutoffFrequency = 22000f;
            }
            return d;
        }

        static AudioClip Clip(string n)
        {
            if (!clips.TryGetValue(n, out var c)) { c = Resources.Load<AudioClip>("Audio/" + n); clips[n] = c; }
            return c;
        }

        /// 구역 음악을 미리 읽어 둔다(런 시작·보스 등장 때 멈칫하지 않게). 백그라운드로 읽고, 끝나면 캐시에 넣는다.
        public static void Preload(string track, int layers)
        {
            for (int i = 0; i < layers; i++)
            {
                string n = layers == 1 ? track : "Music/" + track + "_" + (char)('a' + i);
                if (clips.ContainsKey(n) || loading.Contains(n)) continue;
                loading.Add(n);
                var req = Resources.LoadAsync<AudioClip>("Audio/" + n);
                req.completed += _ => { loading.Remove(n); if (!clips.ContainsKey(n)) clips[n] = req.asset as AudioClip; };
            }
        }
        static readonly HashSet<string> loading = new HashSet<string>();

        public static void Play(string name, float vol = 1f, float pitchVar = 0f, float minGap = 0.04f)
        {
            var c = Clip(name); if (c == null || pool == null) return;
            float now = Time.unscaledTime;
            if (last.TryGetValue(name, out float t) && now - t < minGap) return;
            last[name] = now;
            var s = pool[next]; next = (next + 1) % pool.Length;
            s.pitch = 1f + Random.Range(-pitchVar, pitchVar);
            s.volume = vol * Sfx * Master;
            s.clip = c; s.Play();
        }

        /// layers = 1 이면 Audio/track 한 곡, 2~4 면 Audio/Music/track_a, _b … 레이어 세트
        public static void PlayMusic(string track, int layers = 1)
        {
            if (cur == null || track == cur.name) return;
            var t = cur; cur = old; old = t;                 // old = 나가는 덱
            foreach (var s in cur.src) s.Stop();
            cur.name = track; cur.n = 0; cur.fade = 0f; intensity = 0f; Intensity = 0f;
            if (track == "") return;
            double at = AudioSettings.dspTime + 0.15;
            for (int i = 0; i < layers && i < 4; i++)
            {
                var c = Clip(layers == 1 ? track : "Music/" + track + "_" + (char)('a' + i));
                if (c == null) break;
                cur.src[i].clip = c; cur.src[i].volume = 0f; cur.gain[i] = i == 0 ? 1f : 0f;
                cur.src[i].PlayScheduled(at); cur.n++;
            }
        }

        public static void Stinger(string name) { PlayMusic(""); Play(name, 1.2f); }

        static float LayerTarget(Deck d, int i)
        {
            if (i == 0) return 1f;
            float th = d.n == 2 ? 0.5f : (i == 1 ? 0.16f : i == 2 ? 0.40f : 0.70f);
            return Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(th, th + 0.10f, intensity));
        }

        public static void Update(float dt)
        {
            if (cur == null) return;
            dt = Mathf.Min(dt, 0.1f);
            intensity = Mathf.MoveTowards(intensity, Mathf.Clamp01(Intensity), dt * (Intensity > intensity ? 0.09f : 0.045f));
            muffle = Mathf.MoveTowards(muffle, Muffle ? 1f : 0f, dt * 3.5f);
            float cut = Mathf.Lerp(22000f, 650f, 1f - (1f - muffle) * (1f - muffle));
            float v = Music * Master;
            cur.fade = Mathf.Min(1f, cur.fade + dt / 1.2f); old.fade = Mathf.Max(0f, old.fade - dt / 1.2f);
            // 레이어가 적을 때는 조금 키워서 체감 음량을 맞춘다
            float comp = cur.n > 1 ? Mathf.Lerp(1.45f, 1f, Mathf.Clamp01(intensity / 0.7f)) : 1f;
            for (int i = 0; i < cur.n; i++)
            {
                cur.gain[i] = Mathf.MoveTowards(cur.gain[i], LayerTarget(cur, i), dt * 0.55f);
                cur.src[i].volume = v * cur.fade * cur.gain[i] * comp * (1f - 0.35f * muffle);
                cur.lp[i].cutoffFrequency = cut;
            }
            for (int i = 0; i < old.n; i++)
            {
                old.src[i].volume = v * old.fade * old.gain[i];
                if (old.fade <= 0f && old.src[i].isPlaying) old.src[i].Stop();
            }
            // 레이어끼리 어긋났으면 다시 맞춘다(보통은 일어나지 않는다)
            syncT += dt;
            if (syncT > 2f && cur.n > 1 && cur.src[0].isPlaying)
            {
                syncT = 0f; int t0 = cur.src[0].timeSamples;
                for (int i = 1; i < cur.n; i++)
                    if (cur.src[i].isPlaying && Mathf.Abs(cur.src[i].timeSamples - cur.src[0].timeSamples) > 2048 && t0 > 4096 && t0 < cur.src[0].clip.samples - 8192)
                    { cur.src[i].timeSamples = cur.src[0].timeSamples; Drift++; }
            }
        }

        public static int Drift;
        public static string Debug()
        {
            var sb = new System.Text.StringBuilder();
            sb.Append("music=").Append(cur.name).Append(" int=").Append(intensity.ToString("0.00")).Append(" layers=");
            for (int i = 0; i < cur.n; i++) sb.Append(cur.gain[i].ToString("0.0")).Append(i < cur.n - 1 ? "/" : "");
            sb.Append(" pos=").Append(cur.n > 0 ? cur.src[0].timeSamples : 0).Append(" drift=").Append(Drift);
            return sb.ToString();
        }
    }
}
