#!/usr/bin/env python3
"""
Colony Survival — 배경음악/효과음 생성기 (전부 오리지널, 코드로 합성)

  python3 tools/make_audio.py            # assets/audio/ 에 .ogg(음악) / .wav(효과음) 생성
  필요: numpy, scipy, ffmpeg(ogg 인코딩)

음악 3곡 + 징글 2개
  title.ogg  "Quiet Incubator"   84 BPM  F장조   — 타이틀/메뉴
  run.ogg    "Overnight Culture" 128 BPM A단조   — 플레이
  boss.ogg   "Mold Season"       140 BPM D단조   — 보스전
  victory.ogg / defeat.ogg                       — 결과 징글
악기: FM 벨(글로켄슈필), 썰매방울, 신스 패드, 플럭 아르페지오, 베이스, 드럼
"""
import os, subprocess
import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(2412)

# ── 기본 ──────────────────────────────────────────────────────
NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}

def m(name):  # "A4" -> midi 69
    n, o = name[:-1], int(name[-1])
    return 12 * (o + 1) + NOTE[n]

def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)

def t_arr(dur):
    return np.arange(int(dur * SR)) / SR

def lp(x, cutoff, order=2):
    sos = butter(order, min(cutoff, SR * 0.45) / (SR / 2), "low", output="sos")
    return sosfilt(sos, x)

def hp(x, cutoff, order=2):
    sos = butter(order, cutoff / (SR / 2), "high", output="sos")
    return sosfilt(sos, x)

def bp(x, lo, hi, order=2):
    sos = butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band", output="sos")
    return sosfilt(sos, x)

def adsr(n, a, d, s, r):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    env = np.full(n, s, dtype=float)
    a = min(a, n); env[:a] = np.linspace(0, 1, a, endpoint=False)
    d = min(d, n - a); env[a:a + d] = np.linspace(1, s, d, endpoint=False)
    if r > 0 and n > r:
        env[-r:] *= np.linspace(1, 0, r)
    return env

def saw(f, t):
    # 밴드리밋에 가깝게: 배음 합성(최대 12배음)
    out = np.zeros_like(t)
    for k in range(1, 13):
        if f * k > SR * 0.45:
            break
        out += ((-1) ** (k + 1)) * np.sin(2 * np.pi * f * k * t) / k
    return out * 0.6

def square(f, t, harmonics=9):
    out = np.zeros_like(t)
    for k in range(1, harmonics * 2, 2):
        if f * k > SR * 0.45:
            break
        out += np.sin(2 * np.pi * f * k * t) / k
    return out * 0.8

# ── 악기 ──────────────────────────────────────────────────────
def bell(f, dur=1.6, vel=1.0, bright=1.0):
    t = t_arr(dur)
    idx = 2.2 * bright * np.exp(-t * 6.0)
    car = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 3.5 * t))
    car += 0.25 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t * 4)
    env = np.exp(-t * 3.2) * np.minimum(1, t * 400)
    return car * env * vel * 0.5

def pluck(f, dur=0.35, vel=1.0, cutoff=2400):
    t = t_arr(dur)
    x = saw(f, t) * np.exp(-t * 9)
    x = lp(x, cutoff) * vel
    return x * np.minimum(1, t * 300)

def pad(freqs, dur, vel=0.5, cutoff=1600, attack=0.6, release=0.8):
    t = t_arr(dur)
    l = np.zeros_like(t); r = np.zeros_like(t)
    for i, f in enumerate(freqs):
        for det, pan in ((-0.006, 0.2), (0.0, 0.5), (0.007, 0.8)):
            v = saw(f * (1 + det), t + rng.random() * 0.01)
            l += v * (1 - pan); r += v * pan
    env = adsr(len(t), attack, 0.4, 0.85, release)
    l = lp(l, cutoff) * env * vel / len(freqs)
    r = lp(r, cutoff) * env * vel / len(freqs)
    return np.stack([l, r], 1)

def bass(f, dur, vel=1.0, drive=1.6):
    t = t_arr(dur)
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2 * t)
    x = np.tanh(x * drive) * adsr(len(t), 0.005, 0.15, 0.7, 0.05)
    return lp(x, 900) * vel * 0.6

def lead(f, dur, vel=1.0):
    t = t_arr(dur)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t * 3)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = np.sign(np.sin(ph)) * 0.5 + 0.5 * np.sin(ph)
    x = lp(x, 3200) * adsr(len(t), 0.01, 0.1, 0.75, 0.06)
    return x * vel * 0.32

def kick(vel=1.0):
    t = t_arr(0.35)
    f = 45 + 95 * np.exp(-t * 28)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    x += 0.3 * np.exp(-t * 200) * rng.standard_normal(len(t))
    return np.tanh(x * 1.6) * vel * 0.9

def snare(vel=1.0):
    t = t_arr(0.25)
    n = bp(rng.standard_normal(len(t)), 1200, 7000) * np.exp(-t * 18)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 25)
    return (n * 0.7 + tone * 0.5) * vel * 0.8

def hat(vel=1.0, open_=False):
    t = t_arr(0.3 if open_ else 0.06)
    n = hp(rng.standard_normal(len(t)), 7000) * np.exp(-t * (12 if open_ else 70))
    return n * vel * 0.35

def sleigh(vel=1.0):
    t = t_arr(0.18)
    x = np.zeros_like(t)
    for f in rng.uniform(4800, 9800, 7):
        x += np.sin(2 * np.pi * f * t + rng.random() * 6.28)
    x *= np.exp(-t * 30) * (1 + 0.6 * np.sin(2 * np.pi * 38 * t))
    x += hp(rng.standard_normal(len(t)), 8000) * np.exp(-t * 40) * 0.6
    return x * vel * 0.12

def tom(f=110, vel=1.0):
    t = t_arr(0.4)
    ff = f * (1 + 0.6 * np.exp(-t * 20))
    return np.sin(2 * np.pi * np.cumsum(ff) / SR) * np.exp(-t * 7) * vel * 0.7

# ── 믹스 도구 ─────────────────────────────────────────────────
class Track:
    def __init__(self, bpm, beats, tail=4.0):
        self.bpm = bpm
        self.spb = 60.0 / bpm
        self.loop_n = int(round(beats * self.spb * SR))
        self.buf = np.zeros((self.loop_n + int(tail * SR), 2))
        self.verb_send = np.zeros_like(self.buf)

    def at(self, beat):
        return int(round(beat * self.spb * SR))

    def add(self, beat, sig, pan=0.5, vol=1.0, verb=0.0):
        s = self.at(beat)
        if sig.ndim == 1:
            sig = np.stack([sig * (1 - pan) * 2 ** 0.5 * 0.7, sig * pan * 2 ** 0.5 * 0.7], 1)
        e = min(len(self.buf), s + len(sig))
        self.buf[s:e] += sig[:e - s] * vol
        if verb > 0:
            self.verb_send[s:e] += sig[:e - s] * vol * verb

    def render(self, verb_size=0.82, master=0.9):
        wet = reverb(self.verb_send, verb_size)
        mix = self.buf + wet
        # 루프 이음새: 끝을 넘어간 꼬리(리버브 등)를 처음에 더한다
        out = mix[:self.loop_n].copy()
        tail = mix[self.loop_n:]
        k = min(len(tail), self.loop_n)
        out[:k] += tail[:k]
        return master_bus(out, master)

def _comb(s, d, g):
    # y[n] = x[n] + g*y[n-d]  (d 샘플 블록 단위로 벡터 처리 → 빠름)
    y = s.copy()
    for i in range(d, len(s), d):
        e = min(i + d, len(s))
        y[i:e] += g * y[i - d:e - d]
    return y

def _allpass(s, d, g=0.5):
    # y[n] = -g*x[n] + x[n-d] + g*y[n-d]
    y = -g * s
    y[d:] += s[:-d]
    for i in range(d, len(s), d):
        e = min(i + d, len(s))
        y[i:e] += g * y[i - d:e - d]
    return y

def reverb(x, size=0.82):
    out = np.zeros_like(x)
    combs = [1557, 1617, 1491, 1422, 1277, 1356]
    aps = [225, 556, 441]
    for ch in range(2):
        s = x[:, ch]
        acc = np.zeros_like(s)
        for d in combs:
            acc += _comb(lp(s, 5000, 1), d + ch * 23, size)
        acc /= len(combs)
        for d in aps:
            acc = _allpass(acc, d + ch * 11)
        out[:, ch] = lp(acc, 6000) * 0.35
    return out

def master_bus(x, target=0.9):
    x = x - x.mean(0)
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * 1.25
    x = np.tanh(x) / np.tanh(1.25)
    return x * target

def write_wav(path, x):
    import wave
    x = np.clip(x, -1, 1)
    if x.ndim == 1:
        x = x[:, None]
    data = (x * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(x.shape[1]); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())

def write_ogg(path, x, q=6):
    tmp = path + ".tmp.wav"
    write_wav(tmp, x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.remove(tmp)

def notes(track, seq, inst, offset=0.0, **kw):
    for beat, name, dur, vel in seq:
        track.add(offset + beat, inst(hz(m(name)), dur * track.spb + 0.3, vel), **kw)

# ── 1) 타이틀: Quiet Incubator (84 BPM, F장조, 16마디) ───────
def make_title():
    tr = Track(84, 64, tail=5)
    chords = [["F3", "A3", "C4", "E4"], ["D3", "F3", "A3", "C4", "E4"], ["Bb2", "D3", "F3", "A3"], ["C3", "F3", "G3", "Bb3"],
              ["A2", "C3", "E3", "G3"], ["D3", "F3", "A3", "C4"], ["G2", "Bb2", "D3", "F3"], ["C3", "E3", "G3", "Bb3"]]
    roots = ["F2", "D2", "Bb1", "C2", "A1", "D2", "G1", "C2"]
    for cyc in range(2):
        for i, ch in enumerate(chords):
            b = (cyc * 8 + i) * 4
            tr.add(b, pad([hz(m(n)) for n in ch], 4 * tr.spb + 0.8, vel=0.55, cutoff=1300), vol=0.9, verb=0.5)
            tr.add(b, bass(hz(m(roots[i])), 3.6 * tr.spb, vel=0.55, drive=1.0), pan=0.5, vol=0.8)
            # 부드러운 셀레스타 아르페지오
            for k, n in enumerate(ch[1:] + [ch[1]]):
                tr.add(b + k, bell(hz(m(n) + 12), 1.2, 0.18, 0.6), pan=0.3 + 0.1 * k, verb=0.6)
    mel = [(0, "C6", 1, .9), (1, "A5", .5, .7), (1.5, "C6", .5, .7), (2, "D6", 1, .85), (3, "C6", 1, .7),
           (4, "A5", 1.5, .8), (5.5, "G5", .5, .6), (6, "F5", 2, .8),
           (8, "D6", 1, .85), (9, "C6", .5, .7), (9.5, "A5", .5, .7), (10, "F5", 1, .75), (11, "G5", 1, .7),
           (12, "A5", 1, .8), (13, "G5", 1, .7), (14, "C5", 2, .75),
           (16, "E6", 1, .9), (17, "D6", .5, .7), (17.5, "C6", .5, .7), (18, "A5", 1, .8), (19, "C6", 1, .7),
           (20, "D6", 1.5, .85), (21.5, "C6", .5, .6), (22, "A5", 2, .8),
           (24, "G5", 1, .75), (25, "A5", 1, .75), (26, "Bb5", 1, .8), (27, "A5", .5, .65), (27.5, "G5", .5, .65),
           (28, "F5", 1, .75), (29, "E5", 1, .7), (30, "E5", 2, .7)]
    notes(tr, mel, lambda f, d, v: bell(f, 2.0, v * 0.55), offset=32, pan=0.55, verb=0.7)
    notes(tr, [(b, n, d, v * 0.5) for b, n, d, v in mel[:16]], lambda f, d, v: bell(f, 2.0, v * 0.5), offset=0, pan=0.6, verb=0.7)
    for b in np.arange(32, 64, 1.0):  # 후반부 썰매방울
        tr.add(b + 0.5, sleigh(0.6), pan=0.75, verb=0.2)
    return tr.render(verb_size=0.86, master=0.82)

# ── 2) 플레이: Overnight Culture (128 BPM, A단조, 32마디) ────
def make_run():
    tr = Track(128, 128, tail=3)
    prog_main = [(["A3", "C4", "E4"], "A1"), (["F3", "A3", "C4"], "F1"), (["C4", "E4", "G4"], "C2"), (["G3", "B3", "D4"], "G1")]
    prog_brk = [(["D4", "F4", "A4"], "D2"), (["A3", "C4", "E4"], "A1"), (["F3", "A3", "C4"], "F1"), (["E3", "G#3", "B3"], "E2")]
    for bar in range(32):
        sec = bar // 8  # 0 A, 1 B, 2 C(breakdown), 3 D
        ch, root = (prog_brk if sec == 2 else prog_main)[bar % 4]
        b0 = bar * 4
        rf = hz(m(root))
        # 베이스 8분음표
        pat = [1, 1, 2, 1, 1, 2, 1.5, 2] if sec != 2 else [1, 0, 0, 0, 1, 0, 0, 0]
        for k, mul in enumerate(pat):
            if mul:
                tr.add(b0 + k * 0.5, bass(rf * mul, 0.45 * tr.spb, vel=0.9), vol=0.85)
        # 아르페지오 16분음표
        if sec != 2:
            tones = [hz(m(n) + 12) for n in ch] + [hz(m(ch[0]) + 24)]
            for k in range(16):
                f = tones[[0, 1, 2, 3, 2, 1, 2, 3][k % 8]]
                tr.add(b0 + k * 0.25, pluck(f, 0.3, 0.32, 2600 if sec != 0 else 1800), pan=0.35 + 0.3 * (k % 2), verb=0.15)
        else:
            tr.add(b0, pad([hz(m(n)) for n in ch], 4 * tr.spb + 0.6, vel=0.7, cutoff=1800), verb=0.5)
            for k in range(4):
                tr.add(b0 + k, bell(hz(m(ch[k % 3]) + 24), 1.4, 0.25), pan=0.7, verb=0.6)
        # 드럼
        if sec == 2:
            tr.add(b0, kick(0.8)); tr.add(b0 + 2, snare(0.5), verb=0.3)
        else:
            for k in range(4):
                tr.add(b0 + k, kick(1.0))
            tr.add(b0 + 1, snare(0.8), verb=0.2); tr.add(b0 + 3, snare(0.85), verb=0.2)
            for k in range(4):
                tr.add(b0 + k + 0.5, hat(0.9), pan=0.65)
            if bar % 8 == 7:
                for k, f in enumerate([180, 150, 120, 95]):
                    tr.add(b0 + 3 + k * 0.25, tom(f, 0.8), pan=0.3 + 0.13 * k)
        if sec in (1, 2, 3):
            for k in range(16 if sec != 2 else 8):
                step = 0.25 if sec != 2 else 0.5
                tr.add(b0 + k * step, sleigh(0.5 + 0.3 * (k % 2 == 0)), pan=0.8, verb=0.1)
    mel = [(0, "E5", .5, .8), (.5, "A5", .5, .8), (1, "C6", 1, .9), (2, "B5", .5, .7), (2.5, "A5", .5, .7), (3, "E5", 1, .8),
           (4, "F5", .5, .8), (4.5, "A5", .5, .8), (5, "C6", 1, .9), (6, "D6", 1, .85), (7, "C6", 1, .8),
           (8, "E6", 1, .95), (9, "D6", .5, .75), (9.5, "C6", .5, .75), (10, "G5", 1, .8), (11, "C6", 1, .8),
           (12, "B5", 1.5, .85), (13.5, "A5", .5, .7), (14, "G5", 1, .75), (15, "D5", 1, .75),
           (16, "A5", .5, .8), (16.5, "C6", .5, .8), (17, "E6", 1, .95), (18, "D6", .5, .75), (18.5, "C6", .5, .75), (19, "A5", 1, .8),
           (20, "C6", 1, .85), (21, "A5", .5, .7), (21.5, "F5", .5, .7), (22, "A5", 1, .8), (23, "C6", 1, .8),
           (24, "G5", .5, .8), (24.5, "C6", .5, .8), (25, "E6", 1, .9), (26, "G6", 1, .95), (27, "E6", 1, .85),
           (28, "D6", 2, .9), (30, "B5", 1, .8), (31, "G5", 1, .8)]
    for off in (32, 96):
        notes(tr, mel, lambda f, d, v: bell(f, 1.4, v * 0.55), offset=off, pan=0.5, verb=0.35)
        notes(tr, mel, lambda f, d, v: lead(f / 2, d, v * 0.55), offset=off, pan=0.45, verb=0.2)
    return tr.render(verb_size=0.78, master=0.88)

# ── 3) 보스: Mold Season (140 BPM, D단조, 16마디) ─────────────
def make_boss():
    tr = Track(140, 64, tail=3)
    prog = [(["D3", "F3", "A3"], "D2"), (["Bb2", "D3", "F3"], "Bb1"), (["G2", "Bb2", "D3"], "G1"), (["A2", "C#3", "E3"], "A1")]
    for bar in range(16):
        ch, root = prog[(bar // 2) % 4]
        b0 = bar * 4
        rf = hz(m(root))
        for k in range(16):
            mul = [1, 1, 2, 1, 1.5, 1, 2, 1][k % 8]
            tr.add(b0 + k * 0.25, bass(rf * mul, 0.22 * tr.spb, vel=0.8, drive=2.4), vol=0.8)
        if bar % 2 == 0:
            tr.add(b0, pad([hz(m(n)) for n in ch] + [hz(m(ch[0]) + 7)], 8 * tr.spb + 0.4, vel=0.6, cutoff=1100, attack=0.2), verb=0.35)
        for k in (0, 1.5, 2, 3.5):
            tr.add(b0 + k, kick(1.0))
        tr.add(b0 + 1, snare(0.9), verb=0.25); tr.add(b0 + 3, snare(0.95), verb=0.25)
        for k in range(8):
            tr.add(b0 + k * 0.5, hat(0.7 if k % 2 else 0.4), pan=0.65)
        if bar % 4 == 3:
            for k, f in enumerate([200, 170, 140, 115, 95, 80]):
                tr.add(b0 + 2.5 + k * 0.25, tom(f, 0.9), pan=0.25 + 0.1 * k)
    mel = [(0, "D5", .75, .9), (.75, "F5", .75, .8), (1.5, "A5", .5, .85), (2, "G5", 1, .8), (3, "F5", .5, .7), (3.5, "E5", .5, .7),
           (4, "D5", 2, .85), (6, "A4", 1, .7), (7, "C#5", 1, .75),
           (8, "D5", .75, .9), (8.75, "F5", .75, .8), (9.5, "Bb5", .5, .85), (10, "A5", 1, .8), (11, "F5", 1, .75),
           (12, "D5", 2, .85), (14, "C5", 1, .7), (15, "Bb4", 1, .7),
           (16, "G5", .75, .9), (16.75, "Bb5", .75, .8), (17.5, "D6", .5, .9), (18, "C6", 1, .8), (19, "Bb5", .5, .7), (19.5, "A5", .5, .7),
           (20, "G5", 2, .85), (22, "D5", 1, .7), (23, "F5", 1, .75),
           (24, "E5", .75, .9), (24.75, "A5", .75, .85), (25.5, "C#6", .5, .9), (26, "E6", 1, .95), (27, "D6", .5, .8), (27.5, "C#6", .5, .8),
           (28, "A5", 2, .9), (30, "E5", 1, .75), (31, "C#5", 1, .75)]
    notes(tr, mel, lambda f, d, v: lead(f, d, v * 0.8), offset=0, pan=0.45, verb=0.2)
    notes(tr, mel, lambda f, d, v: lead(f, d, v * 0.7), offset=32, pan=0.45, verb=0.2)
    notes(tr, mel, lambda f, d, v: bell(f * 2, 1.0, v * 0.35), offset=32, pan=0.6, verb=0.4)
    return tr.render(verb_size=0.75, master=0.9)

def make_stinger(win=True):
    tr = Track(120, 8, tail=0.1)
    if win:
        for k, n in enumerate(["C5", "E5", "G5", "C6", "E6"]):
            tr.add(k * 0.25, bell(hz(m(n)), 2.5, 0.8), pan=0.3 + 0.1 * k, verb=0.6)
        tr.add(1.5, pad([hz(m(n)) for n in ["C4", "E4", "G4", "C5"]], 2.4, vel=0.7, cutoff=2200, attack=0.05), verb=0.5)
        for k in range(10):
            tr.add(1.5 + k * 0.25, sleigh(0.7), pan=0.75)
    else:
        for k, n in enumerate(["A4", "F4", "D4"]):
            tr.add(k * 0.5, bell(hz(m(n)), 2.0, 0.7, 0.5), pan=0.5, verb=0.6)
        tr.add(1.5, pad([hz(m(n)) for n in ["D3", "F3", "A3"]], 2.6, vel=0.7, cutoff=900, attack=0.05), verb=0.6)
    x = tr.render(verb_size=0.84, master=0.85)
    fade = np.ones(len(x)); fade[-int(0.6 * SR):] = np.linspace(1, 0, int(0.6 * SR))
    return x * fade[:, None]

# ── 효과음 (모노 wav) ─────────────────────────────────────────
def norm(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-9) * peak

def sfx():
    out = {}
    t = t_arr(0.05)
    out["ui_move"] = norm(np.sin(2 * np.pi * 1350 * t) * np.exp(-t * 90), 0.5)
    a = bell(hz(m("E6")), 0.5, 1.0); b = bell(hz(m("B6")), 0.6, 1.0)
    x = np.zeros(int(0.65 * SR)); x[:len(a)] += a; x[int(0.07 * SR):int(0.07 * SR) + len(b)] += b[:len(x) - int(0.07 * SR)]
    out["ui_select"] = norm(x, 0.7)
    t = t_arr(0.22)
    thud = np.sin(2 * np.pi * np.cumsum(60 + 120 * np.exp(-t * 30)) / SR) * np.exp(-t * 14)
    crunch = bp(rng.standard_normal(len(t)), 500, 2500) * np.exp(-t * 30)
    out["hurt"] = norm(np.tanh((thud + crunch * 0.6) * 2), 0.85)
    t = t_arr(0.07)
    f = 900 + 700 * t / 0.07
    out["pickup"] = norm(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 35) * np.minimum(1, t * 800), 0.45)
    x = np.zeros(int(1.4 * SR))
    for k, n in enumerate(["C6", "E6", "G6", "C7"]):
        s = bell(hz(m(n)), 1.0, 0.8); i = int(k * 0.07 * SR); x[i:i + len(s)] += s[:len(x) - i]
    out["levelup"] = norm(x, 0.75)
    t = t_arr(0.09)
    pop = np.sin(2 * np.pi * np.cumsum(520 * np.exp(-t * 25) + 140) / SR) * np.exp(-t * 40)
    pop += bp(rng.standard_normal(len(t)), 1500, 5000) * np.exp(-t * 80) * 0.3
    out["enemy_die"] = norm(pop, 0.4)
    x = np.zeros(int(1.6 * SR))
    for k in range(10):
        s = sleigh(1.0); i = int(k * 0.06 * SR); x[i:i + len(s)] += s
    for k, n in enumerate(["G5", "C6", "E6", "G6"]):
        s = bell(hz(m(n)), 1.2, 0.7); i = int((0.1 + k * 0.05) * SR); x[i:i + len(s)] += s[:len(x) - i]
    out["gift"] = norm(x, 0.8)
    t = t_arr(1.4)
    sw = saw(55, t) + saw(55 * 1.5 * 1.003, t)
    ramp = t / 1.4  # 필터가 서서히 열리는 효과: 어두운 소리 → 밝은 소리로 크로스페이드
    sw = (lp(sw, 400) * (1 - ramp) + lp(sw, 2200) * ramp) * adsr(len(t), 0.5, 0.2, 0.9, 0.4)
    siren = np.sin(2 * np.pi * np.cumsum(600 + 200 * np.sin(2 * np.pi * 3 * t)) / SR) * 0.25 * adsr(len(t), 0.3, 0.1, 0.8, 0.4)
    out["boss_warn"] = norm(np.tanh((sw + siren) * 1.5), 0.85)
    x = np.zeros(int(1.0 * SR))
    for k, n in enumerate(["F5", "A5", "C6"]):
        s = bell(hz(m(n)), 0.9, 0.6, 0.5); i = int(k * 0.09 * SR); x[i:i + len(s)] += s[:len(x) - i]
    out["heal"] = norm(x, 0.6)
    t = t_arr(0.5)
    kk = np.zeros(len(t)); kd = kick(1.0); kk[:len(kd)] = kd
    out["boss_hit_big"] = norm(np.tanh(kk * 1.5 + bp(rng.standard_normal(len(t)), 200, 1500) * np.exp(-t * 10) * 0.5), 0.8)
    return out

def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("title", make_title), ("run", make_run), ("boss", make_boss)]:
        x = fn(); write_ogg(os.path.join(OUT, name + ".ogg"), x); print(f"{name}.ogg  {len(x) / SR:.1f}s")
    write_ogg(os.path.join(OUT, "victory.ogg"), make_stinger(True)); print("victory.ogg")
    write_ogg(os.path.join(OUT, "defeat.ogg"), make_stinger(False)); print("defeat.ogg")
    for k, x in sfx().items():
        write_wav(os.path.join(OUT, k + ".wav"), x); print(f"{k}.wav  {len(x) / SR:.2f}s")

if __name__ == "__main__":
    main()
