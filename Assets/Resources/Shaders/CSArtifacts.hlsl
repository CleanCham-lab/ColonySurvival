#ifndef CS_ARTIFACTS_INCLUDED
#define CS_ARTIFACTS_INCLUDED
// 구역 3~5의 적: 오염균이 아니라 그 방에서 생기는 것들(PCR 산물, 시퀀싱 아티팩트, 서버 오류, 심사 의견).
// 종류 번호 20~49. 분기 안에서는 화면 미분(fwidth)을 쓰지 않는다 — 쓰면 컴파일러가 분기를 모두 펼쳐서
// 한 픽셀마다 모든 모양을 다 계산하게 된다. 가장자리 두께는 frag 맨 앞에서 한 번 구해 gAA에 둔다.

static float gAA = 0.02;
static float gEdge = 1.0;     // 쿼드 가장자리로 갈수록 0 — 후광이 쿼드 모서리에서 네모나게 잘려 보이지 않게
float aq(float d) { return saturate(0.5 - d / gAA); }

// 공통 마무리: 막(rim) + 속 + 후광
void ash(float d, float3 tint, float inner, float rimW, out float3 col, out float alpha)
{
    float inside = aq(d);
    float rim = exp(-pow(d / rimW, 2.0));
    col = tint * (inner * inside + rim * 1.5) + tint * exp(-max(d, 0.0) * 9.0) * 0.28 * (1.0 - inside) * gEdge;
    alpha = saturate(inside * 0.6 + rim * 0.5);
}

// 이중나선(x축 방향, 길이 2L, 진폭 A). 돌아오는 값 = 두 가닥까지의 거리, rung = 가로대(염기쌍)까지의 거리
float helixD(float2 p, float L, float A, float k, float ph, float n, out float rung)
{
    float s = sin(k * p.x + ph), c = cos(k * p.x + ph);
    float sl = 1.0 / sqrt(1.0 + A * A * k * k * c * c);
    float d = min(abs(p.y - A * s), abs(p.y + A * s)) * sl;
    float capx = max(abs(p.x) - L, 0.0);
    d = sqrt(d * d + capx * capx);
    float rx = abs(frac(p.x * n + 0.5) - 0.5) / n;
    rung = max(max(rx, abs(p.y) - abs(A * s)), abs(p.x) - L);
    return d;
}

// q0 = 돌리지 않은 좌표(똑바로 서 있어야 하는 것들), q = 진행 방향으로 돌린 좌표(+x가 앞), fa = 진행 방향 각도
void artifact(int kind, float2 q0, float2 q, float seed, float t, float charge, float fa, float3 tint, out float3 col, out float alpha)
{
    col = 0; alpha = 0;
    float a = atan2(q.y, q.x), r = length(q);

    UNITY_BRANCH if (kind < 27)
    {
        // ── PCR실 ──
        UNITY_BRANCH if (kind == 20)
        {
            // 프라이머 다이머: 짧은 두 가닥이 끝에서 서로 물렸다
            float wob = 0.05 * sin(t * 8.0 + seed * 9.0);
            float d1 = sdSeg(q, float2(-0.50, 0.13 + wob), float2(0.17, 0.13)) - 0.065;
            float d2 = sdSeg(q, float2(-0.17, -0.13), float2(0.50, -0.13 - wob)) - 0.065;
            float rx = abs(frac(q.x * 8.0 + 0.5) - 0.5) / 8.0;
            float rung = max(max(rx - 0.02, abs(q.y) - 0.13), abs(q.x) - 0.18);
            ash(min(min(d1, d2), rung), tint, 0.55, 0.05, col, alpha);
            col += tint * exp(-r * r * 10.0) * 0.5;
        }
        UNITY_BRANCH if (kind == 21)
        {
            // 비특이 산물: 짧은 이중가닥
            float rung;
            float d = helixD(q, 0.50, 0.17, 5.0, t * 3.0 + seed * 6.28, 6.0, rung) - 0.05;
            ash(min(d, rung - 0.018), tint, 0.5, 0.04, col, alpha);
        }
        UNITY_BRANCH if (kind == 22)
        {
            // 캐리오버 앰플리콘: 굵고 길게 꼬인 이중나선
            float rung;
            float d = helixD(q, 0.58, 0.27, 7.0, t * 2.0 + seed * 6.28, 6.5, rung) - 0.065;
            ash(min(d, rung - 0.022), tint, 0.6, 0.045, col, alpha);
            float core = exp(-pow(q.y / 0.30, 2.0)) * smoothstep(0.75, 0.45, abs(q.x));
            col += tint * core * 0.22; alpha = saturate(alpha + core * 0.15);
        }
        UNITY_BRANCH if (kind == 23)
        {
            // 단일 가닥: 한 줄 + 한쪽으로만 난 염기
            float ph = 7.0 * q.x + t * 5.0 + seed * 6.28;
            float s = sin(ph), c = cos(ph);
            float sl = 1.0 / sqrt(1.0 + 1.5876 * c * c);
            float capx = max(abs(q.x) - 0.50, 0.0);
            float d = sqrt(pow(abs(q.y - 0.18 * s) * sl, 2.0) + capx * capx) - 0.06;
            float rx = abs(frac(q.x * 5.0 + 0.5) - 0.5) / 5.0;
            float tick = max(max(rx - 0.02, abs(q.y - 0.18 * s - 0.13) - 0.10), abs(q.x) - 0.50);
            ash(min(d, tick), tint, 0.5, 0.04, col, alpha);
        }
        UNITY_BRANCH if (kind == 24)
        {
            // 에어로졸: 앞이 둥글고 뒤로 꼬리가 빠지는 방울 + 뒤따르는 잔방울
            float hd = length(q - float2(0.20, 0.0)) - 0.30;
            float h = saturate((q.x + 0.60) / 0.80);
            float tl = max(abs(q.y) - 0.29 * h * h, max(-0.60 - q.x, q.x - 0.20));
            float d = min(hd, tl * 0.7);
            float inner = 0.25 + 0.9 * exp(-pow(length(q - float2(0.26, 0.08)) / 0.12, 2.0)) + charge * 1.2;
            ash(d, tint * (1.0 + charge * 1.2), inner, 0.04, col, alpha);
            float s1 = length(q - float2(-0.62, 0.26 + 0.05 * sin(t * 7.0 + seed * 6.0))) - 0.07;
            float s2 = length(q - float2(-0.80, -0.18 - 0.05 * sin(t * 6.0 + seed * 3.0))) - 0.05;
            float sm = aq(min(s1, s2));
            col += tint * sm; alpha = saturate(alpha + sm * 0.6);
        }
        UNITY_BRANCH if (kind == 25)
        {
            // 오염된 NTC: 뚜껑 달린 PCR 튜브, 안에서 산물이 끓는다
            float2 p = q0;
            float capD = sdBox(p - float2(0.0, 0.46), float2(0.33, 0.06)) - 0.04;
            float h = saturate((p.y + 0.62) / 0.98);
            float wdt = lerp(0.07, 0.27, pow(h, 0.6));
            float body = max(abs(p.x) - wdt, max(-0.66 - p.y, p.y - 0.40));
            float tip = length(p - float2(0.0, -0.61)) - 0.075;
            float d = min(min(capD, body), tip);
            float lvl = -0.10 + 0.04 * sin(t * 3.0 + seed * 6.0) + charge * 0.22;
            float liquid = step(p.y, lvl) * aq(body + 0.05);
            float inner = 0.12 + liquid * (0.8 + charge * 1.5 + 0.3 * sin(t * 5.0 + p.y * 20.0));
            ash(d, tint * (1.0 + charge), inner, 0.035, col, alpha);
        }
        UNITY_BRANCH if (kind == 26)
        {
            // PCR 저해제: 각진 결정 덩어리
            float2 p = rot2(q0, seed * 6.28 + t * 0.08);
            float d = min(min(sdHex(p - float2(-0.20, 0.10), 0.36), sdHex(rot2(p - float2(0.28, 0.16), 0.5), 0.28)),
                          min(sdHex(rot2(p - float2(0.10, -0.30), 0.3), 0.30), sdHex(rot2(p - float2(-0.38, -0.30), 0.9), 0.18)));
            float facet = abs(frac((p.x * 0.8 + p.y * 0.6) * 4.0 + seed) - 0.5);
            float inner = 0.18 + 0.35 * smoothstep(0.30, 0.48, facet) + 0.25 * fbm(p * 6.0);
            ash(d, tint, inner, 0.07, col, alpha);
            alpha = saturate(alpha + aq(d) * 0.25);
        }
    }
    UNITY_BRANCH if (kind >= 27 && kind < 34)
    {
        // ── 시퀀싱실 · 숏리드 ──
        UNITY_BRANCH if (kind == 27)
        {
            // 중복 리드: 똑같은 무늬의 막대 두 개
            float bob = 0.03 * sin(t * 9.0 + seed * 9.0);
            float d1 = sdBox(q - float2(0.04, 0.16 + bob), float2(0.40, 0.055)) - 0.04;
            float d2 = sdBox(q - float2(-0.04, -0.16 - bob), float2(0.40, 0.055)) - 0.04;
            float cx = floor((q.x + (q.y > 0.0 ? -0.04 : 0.04) + 1.0) * 6.0);
            float cells = 0.45 + 0.55 * step(0.5, hash11(cx + floor(seed * 7.0)));
            ash(min(d1, d2), tint, 0.35 + 0.5 * cells, 0.04, col, alpha);
        }
        UNITY_BRANCH if (kind == 28)
        {
            // 저품질 리드: 앞은 멀쩡한데 뒤로 갈수록 조각조각 흩어진다
            float bar = sdBox(q - float2(0.14, 0.0), float2(0.40, 0.13)) - 0.05;
            float cx = floor((q.x + 1.0) * 7.0);
            float jit = 0.16 * (hash11(cx + floor(t * 6.0 + seed * 9.0)) - 0.5) * 2.0;
            float fade = saturate((-0.26 - q.x) / 0.45);
            float blk = max(abs(frac((q.x + 1.0) * 7.0) - 0.5) / 7.0 - 0.045, abs(q.y - jit * fade) - 0.11 * (1.0 - fade * 0.6));
            blk = max(blk, max(q.x + 0.30, -0.78 - q.x));
            float cells = 0.45 + 0.55 * step(0.45, hash11(cx + seed * 13.0));
            ash(min(bar, blk), tint, (0.3 + 0.5 * cells) * (1.0 - fade * 0.6), 0.04, col, alpha);
        }
        UNITY_BRANCH if (kind == 29)
        {
            // 다클론 클러스터: 결이 다른 두 덩어리가 겹쳤다
            float pul = 0.03 * sin(t * 2.0 + seed * 6.28);
            float d1 = length(q - float2(-0.20, 0.06)) - (0.40 + pul);
            float d2 = length(q - float2(0.26, -0.08)) - (0.34 - pul);
            float i1 = aq(d1), i2 = aq(d2);
            float st1 = step(0.5, frac((q.x + q.y) * 5.0 + t * 0.5));
            float st2 = step(0.5, frac((q.x - q.y) * 5.0 - t * 0.5));
            float inner = 0.20 + 0.45 * (i1 * st1 * (1.0 - i2) + i2 * st2 * (1.0 - i1)) + 0.9 * i1 * i2;
            ash(min(d1, d2), tint, inner, 0.045, col, alpha);
            col += tint * exp(-pow(max(d1, d2) / 0.03, 2.0)) * 0.5;
        }
        UNITY_BRANCH if (kind == 30)
        {
            // 혼합 리드: 갈라져 나온 작은 덩어리
            float d = length(q * float2(0.9, 1.1)) - 0.42;
            float st = step(0.5, frac((q.x + q.y) * 5.0 + t));
            ash(d, tint, 0.25 + 0.5 * st, 0.05, col, alpha);
        }
        UNITY_BRANCH if (kind == 31)
        {
            // 인덱스 호핑: 꼬리에 인덱스 표식을 단 화살
            float shaft = sdBox(q - float2(-0.02, 0.0), float2(0.30, 0.09)) - 0.03;
            float hd = sdTri(q, float2(0.30, 0.27), float2(0.30, -0.27), float2(0.68, 0.0)) - 0.03;
            float tag = sdBox(q - float2(-0.54, 0.0), float2(0.09, 0.16)) - 0.03;
            float inner = 0.3 + 0.9 * aq(tag) * (0.6 + 0.4 * sin(t * 12.0 + seed * 6.0)) + charge * 1.3;
            ash(min(min(shaft, hd), tag), tint * (1.0 + charge * 1.2), inner, 0.04, col, alpha);
            float gh = aq(sdBox(q - float2(-0.82, 0.0), float2(0.04, 0.12)));
            col += tint * gh * (0.25 + charge * 0.6); alpha = saturate(alpha + gh * 0.3);
        }
        UNITY_BRANCH if (kind == 32)
        {
            // 폴리G 웰: 어두운 웰 안에 G 한 글자
            float2 p = q0;
            float well = sdBox(p, float2(0.46, 0.46)) - 0.12;
            float ring = abs(length(p) - 0.25) - 0.065;
            float cut = max(abs(p.y - 0.09) - 0.10, -p.x);
            float gch = min(max(ring, -cut), sdBox(p - float2(0.16, -0.04), float2(0.12, 0.055)));
            float pulse = 0.5 + 0.5 * sin(t * 4.0 + seed * 6.0);
            ash(well, tint * (1.0 + charge), 0.08 + 0.9 * aq(gch) * (0.55 + 0.45 * pulse + charge * 1.5), 0.04, col, alpha);
        }
        UNITY_BRANCH if (kind == 33)
        {
            // 플로우셀 기포: 얇은 막 + 하이라이트
            float R = 0.64 * (1.0 + 0.03 * sin(a * 3.0 + t * 1.5 + seed * 6.0) + 0.02 * sin(a * 5.0 - t * 2.0));
            float d = r - R;
            float inside = aq(d);
            float rim = exp(-pow(d / 0.05, 2.0));
            float rim2 = exp(-pow((d + 0.13) / 0.03, 2.0)) * 0.35;
            float hl = aq(length((q0 - float2(-0.26, 0.30)) * float2(1.0, 1.7)) - 0.16);
            col = tint * (0.10 * inside + rim * 1.6 + rim2 * inside) + float3(2.0, 2.0, 2.0) * hl * 0.5 * inside + tint * exp(-max(d, 0.0) * 9.0) * 0.28 * (1.0 - inside);
            alpha = saturate(inside * 0.35 + rim * 0.6 + hl * 0.3);
        }
    }
    UNITY_BRANCH if (kind >= 34 && kind < 41)
    {
        // ── 시퀀싱실 · 롱리드 ──
        UNITY_BRANCH if (kind == 34)
        {
            // 짧은 단편: 작은 막대 하나와 부스러기
            float d = sdBox(rot2(q, 0.25 * sin(t * 6.0 + seed * 9.0)), float2(0.30, 0.07)) - 0.05;
            float b1 = length(q - float2(-0.50, 0.14)) - 0.07, b2 = length(q - float2(0.52, -0.12)) - 0.06;
            ash(min(d, min(b1, b2)), tint, 0.6, 0.05, col, alpha);
        }
        UNITY_BRANCH if (kind == 35)
        {
            // 페일 리드: 가운데가 끊긴 긴 리드 + X 표
            float l1 = sdBox(q - float2(-0.38, 0.03), float2(0.22, 0.075)) - 0.035;
            float l2 = sdBox(rot2(q - float2(0.36, -0.05), -0.22), float2(0.22, 0.075)) - 0.035;
            float xm = min(sdSeg(q, float2(-0.10, -0.14), float2(0.10, 0.14)), sdSeg(q, float2(-0.10, 0.14), float2(0.10, -0.14))) - 0.035;
            float cells = 0.45 + 0.55 * step(0.5, hash11(floor((q.x + 1.0) * 8.0) + seed * 17.0));
            ash(min(min(l1, l2), xm), tint, 0.3 + 0.4 * cells + aq(xm) * 0.8, 0.04, col, alpha);
        }
        UNITY_BRANCH if (kind == 36)
        {
            // 키메라 리드: 서로 다른 두 리드가 한 점에서 이어 붙었다
            float bend = 0.45 + 0.10 * sin(t * 2.0 + seed * 6.28);
            float2 o = float2(0.0, -0.22);
            float2 e1 = float2(-0.58 * cos(bend), 0.58 * sin(bend)), e2 = float2(0.58 * cos(bend), 0.58 * sin(bend));
            float d1 = sdSeg(q, o, o + e1) - 0.10, d2 = sdSeg(q, o, o + e2) - 0.10;
            float j = length(q - o) - 0.15;
            float st = step(0.5, frac(length(q - o) * 6.0 - t));
            float inner = 0.25 + 0.40 * (d1 < d2 ? st : 1.0 - st) + aq(j);
            ash(min(min(d1, d2), j), tint, inner, 0.045, col, alpha);
        }
        UNITY_BRANCH if (kind == 37)
        {
            // 조각 리드
            float d = sdBox(q, float2(0.40, 0.085)) - 0.045;
            float st = step(0.5, frac(q.x * 6.0 - t));
            ash(d, tint, 0.3 + 0.45 * st, 0.045, col, alpha);
        }
        UNITY_BRANCH if (kind == 38)
        {
            // 호모폴리머: 똑같은 칸이 줄줄이 이어진 긴 화살
            float shaft = sdBox(q - float2(-0.10, 0.0), float2(0.52, 0.075)) - 0.03;
            float hd = sdTri(q, float2(0.42, 0.21), float2(0.42, -0.21), float2(0.76, 0.0)) - 0.02;
            float cell = step(0.18, abs(frac(q.x * 6.0 - t * (2.0 + charge * 10.0)) - 0.5));
            ash(min(shaft, hd), tint * (1.0 + charge * 1.2), 0.25 + 0.6 * cell + charge, 0.035, col, alpha);
        }
        UNITY_BRANCH if (kind == 39)
        {
            // 막힌 포어: 고리 한가운데가 막혔다
            float ringD = abs(r - 0.46) - 0.10;
            float plug = r - 0.22 * (1.0 + 0.10 * sin(a * 4.0 + t * 2.0 + seed * 6.0));
            float seg = 6.2831853 / 12.0;
            float a2 = fmod(a + 3.14159265 + seed, seg) - seg * 0.5;
            float2 pp = r * float2(cos(a2), sin(a2));
            float tick = sdBox(pp - float2(0.66, 0.0), float2(0.07, 0.03));
            float inner = 0.2 + aq(plug) * (0.7 + 0.5 * sin(t * 5.0 + seed * 6.0) + charge * 2.0);
            ash(min(min(ringD, plug), tick), tint * (1.0 + charge), inner, 0.035, col, alpha);
        }
        UNITY_BRANCH if (kind == 40)
        {
            // 엉킨 초고분자 DNA: 실뭉치
            float l1 = abs(r - 0.40 * (1.0 + 0.45 * sin(a * 2.0 + t * 0.4 + seed * 6.0)));
            float l2 = abs(r - 0.36 * (1.0 + 0.50 * sin(a * 3.0 - t * 0.3 + seed * 2.0)));
            float l3 = abs(r - 0.44 * (1.0 + 0.35 * sin(a * 5.0 + t * 0.25 + seed * 4.0)));
            float ball = r - 0.64;
            float d = max(min(min(l1, l2), l3) - 0.04, ball);
            ash(min(d, r - 0.16), tint, 0.55, 0.045, col, alpha);
            float fill = aq(ball);
            col += tint * 0.10 * fill; alpha = saturate(alpha + fill * 0.28);
        }
    }
    UNITY_BRANCH if (kind >= 41 && kind < 48)
    {
        // ── 분석 서버실 ──
        UNITY_BRANCH if (kind == 41)
        {
            // 경고: 세모 안의 느낌표
            float2 p = q0 + float2(0.0, 0.06);
            float tri = sdTri(p, float2(-0.50, -0.36), float2(0.50, -0.36), float2(0.0, 0.50)) - 0.06;
            float ex = min(sdSeg(p, float2(0.0, 0.20), float2(0.0, -0.06)) - 0.055, length(p - float2(0.0, -0.22)) - 0.06);
            float blink = 0.6 + 0.4 * step(0.5, frac(t * 2.0 + seed));
            ash(tri, tint, 0.95 * blink, 0.05, col, alpha);
            float e = aq(ex);
            col = lerp(col, float3(0.02, 0.01, 0.0), e * 0.9); alpha = saturate(alpha + e * 0.4);
        }
        UNITY_BRANCH if (kind == 42)
        {
            // 버그: 딱정벌레
            float bodyD = length((q - float2(-0.08, 0.0)) * float2(0.80, 1.15)) - 0.30;
            float headD = length(q - float2(0.34, 0.0)) - 0.15;
            float2 m = float2(q.x, abs(q.y));
            float w = 0.05 * sin(t * 14.0 + seed * 6.0);
            float legs = min(min(sdSeg(m, float2(0.10, 0.20), float2(0.24 + w, 0.50)), sdSeg(m, float2(-0.10, 0.25), float2(-0.10 - w, 0.56))), sdSeg(m, float2(-0.28, 0.20), float2(-0.46 + w, 0.48))) - 0.03;
            float ant = sdSeg(m, float2(0.44, 0.06), float2(0.64, 0.20 + w)) - 0.022;
            float seam = exp(-pow(q.y / 0.02, 2.0)) * step(q.x, 0.18) * step(-0.42, q.x);
            ash(min(min(bodyD, headD), min(legs, ant)), tint, 0.35 + 0.25 * fbm(q * 8.0 + seed * 5.0) - seam * 0.3, 0.04, col, alpha);
        }
        UNITY_BRANCH if (kind == 43)
        {
            // 좀비 프로세스: 눈이 X인 터미널 창
            float2 p = q0;
            float win = sdBox(p, float2(0.52, 0.42)) - 0.07;
            float winIn = aq(win);
            float bar = step(0.24, p.y) * winIn;
            float2 ex = float2(abs(p.x) - 0.20, p.y);
            float eyes = min(sdSeg(ex, float2(-0.08, -0.08), float2(0.08, 0.08)), sdSeg(ex, float2(-0.08, 0.08), float2(0.08, -0.08))) - 0.03;
            float mouth = max(abs(p.y + 0.24 - 0.04 * sign(frac(p.x * 6.0) - 0.5)) - 0.025, abs(p.x) - 0.26);
            float face = aq(min(eyes, mouth));
            float dots = aq(length(float2(frac((p.x + 0.44) * 8.0) - 0.5, (p.y - 0.36) * 8.0)) / 8.0 - 0.03) * step(p.x, -0.07) * step(-0.44, p.x);
            ash(win, tint, 0.14 + 0.5 * bar + 0.9 * face * (0.6 + 0.4 * sin(t * 4.0 + seed * 6.0)), 0.04, col, alpha);
            col = lerp(col, float3(0.02, 0.01, 0.01), dots * 0.8);
        }
        UNITY_BRANCH if (kind == 44)
        {
            // 고아 프로세스: 커서만 깜빡이는 작은 창
            float2 p = q0;
            float win = sdBox(p, float2(0.42, 0.32)) - 0.06;
            float bar = step(0.16, p.y) * aq(win);
            float cur = aq(sdBox(p - float2(-0.14, -0.08), float2(0.07, 0.10))) * step(0.5, frac(t * 2.5 + seed));
            ash(win, tint, 0.14 + 0.5 * bar + cur * 0.9, 0.045, col, alpha);
        }
        UNITY_BRANCH if (kind == 45)
        {
            // 세그폴트: 지직거리는 번개 화살
            float gl = (hash11(floor(q.y * 7.0) + floor(t * 10.0) + seed * 5.0) - 0.5) * 0.10 * (1.0 + charge * 2.0);
            float2 p = q + float2(gl, 0.0);
            float b1 = sdTri(p, float2(-0.62, 0.10), float2(0.06, 0.26), float2(-0.04, -0.06));
            float b2 = sdTri(p, float2(-0.10, 0.06), float2(0.66, -0.06), float2(0.02, -0.24));
            ash(min(b1, b2) - 0.03, tint * (1.0 + charge * 1.3), 0.5 + charge * 1.2, 0.04, col, alpha);
        }
        UNITY_BRANCH if (kind == 46)
        {
            // 무한 루프: 제자리에서 도는 화살 고리
            float2 p = rot2(q0, t * (1.5 + charge * 6.0) + seed * 6.28);
            float pr = length(p);
            float arc = max(abs(pr - 0.44) - 0.08, -sdTri(p, float2(0.0, 0.0), float2(0.95, -0.04), float2(0.50, 0.85)));
            float hd = sdTri(p, float2(0.20, -0.04), float2(0.70, -0.04), float2(0.45, 0.36)) - 0.02;
            float dotc = pr - 0.08;
            ash(min(min(arc, hd), dotc), tint * (1.0 + charge), 0.45 + charge * 1.5 + aq(dotc) * (0.5 + 0.5 * sin(t * 6.0)), 0.04, col, alpha);
        }
        UNITY_BRANCH if (kind == 47)
        {
            // 메모리 누수: 램 칩에서 방울이 샌다
            float2 p = q0 * 1.18 + float2(0.0, -0.135);
            float chip = sdBox(p - float2(0.0, 0.12), float2(0.50, 0.30)) - 0.05;
            float pins = max(max(abs(frac(p.x * 5.0 + 0.5) - 0.5) / 5.0 - 0.035, abs(abs(p.y - 0.12) - 0.42) - 0.07), abs(p.x) - 0.46);
            float g1 = frac(t * 0.5 + seed), g2 = frac(t * 0.5 + seed + 0.5);
            float drip = min(length(p - float2(-0.18, -0.30 - g1 * 0.45)) - 0.09 * (1.0 - g1 * 0.5), length(p - float2(0.22, -0.30 - g2 * 0.45)) - 0.08 * (1.0 - g2 * 0.5));
            float2 pe = (p - float2(0.0, -0.76)) * float2(0.55, 1.8);
            float pk = length(pe);
            float puddle = (pk - 0.22) * pk / max(length(pe * float2(0.55, 1.8)), 1e-3);     // 타원까지의 거리(기울기 보정)
            float wet = min(drip, puddle);
            float cellsM = step(0.5, hash21(floor((p - float2(0.0, 0.12)) * float2(9.0, 7.0)) + floor(t * 2.0 + seed * 3.0)));
            float inner = 0.16 + 0.55 * cellsM * aq(sdBox(p - float2(0.0, 0.12), float2(0.42, 0.22))) + 0.5 * aq(wet);
            ash(min(min(chip, pins), wet), tint, inner, 0.045, col, alpha);
        }
    }
    UNITY_BRANCH if (kind >= 48)
    {
        // ── Reviewer가 불러내는 것들 ──
        UNITY_BRANCH if (kind == 48)
        {
            // 공동 심사위원: 눈 하나 달린 작은 원고
            float2 p = rot2(q0, 0.06 * sin(t * 2.0 + seed * 6.0));
            float page = sdBox(p, float2(0.40, 0.54)) - 0.05;
            float inside = aq(page);
            float rows = step(0.45, frac(p.y * 7.5 + 0.25)) * step(abs(p.y), 0.48) * step(abs(p.x), 0.32);
            float2 ec = float2(0.0, 0.10);
            float eyeD = length((p - ec) * float2(1.0, 1.7 + charge)) - 0.28;
            float eyeIn = aq(eyeD);
            float2 look = float2(cos(fa), sin(fa)) * float2(0.10, 0.06);
            float iris = aq(length(p - ec - look) - 0.10);
            float3 paper = float3(0.50, 0.55, 0.68) * (0.30 + 0.12 * fbm(p * 6.0)) * (1.0 - rows * 0.6);
            float2 xq = p - float2(0.0, -0.32);
            float xm = aq(min(sdSeg(xq, float2(-0.09, -0.09), float2(0.09, 0.09)), sdSeg(xq, float2(-0.09, 0.09), float2(0.09, -0.09))) - 0.028);
            float edge = exp(-pow(page / 0.05, 2.0));
            col = paper * inside;
            col = lerp(col, float3(0.03, 0.0, 0.01), eyeIn * inside);
            col += tint * exp(-pow(eyeD / 0.03, 2.0)) * 1.3 * inside;
            col += tint * (2.2 + 1.5 * charge) * iris * eyeIn;
            col += tint * 1.7 * xm * inside * (1.0 - eyeIn);
            col += tint * edge * (1.3 + charge);
            col += tint * exp(-max(page, 0.0) * 8.0) * 0.3 * (1.0 - inside);
            alpha = saturate(inside * 0.94 + edge * 0.5);
        }
        UNITY_BRANCH if (kind == 49)
        {
            // 지적 사항: 점 세 개가 깜빡이는 말풍선
            float2 p = q0 - float2(0.0, 0.08);
            float bub = sdBox(p, float2(0.38, 0.24)) - 0.12;
            float tl = sdTri(p, float2(-0.26, -0.30), float2(-0.02, -0.30), float2(-0.34, -0.62));
            float idx = floor(p.x * 3.4 + 0.5);
            float dots = aq(length(float2(frac(p.x * 3.4 + 0.5) - 0.5, p.y * 3.4)) / 3.4 - 0.06) * step(abs(p.x), 0.44);
            ash(min(bub, tl), tint, 0.38, 0.045, col, alpha);
            float dk = dots * (0.75 + 0.25 * sin(t * 6.0 + seed * 9.0 + idx * 1.5));
            col = lerp(col, float3(0.03, 0.0, 0.01), dk * 0.9); alpha = saturate(alpha + dk * 0.3);
        }
    }
}
#endif
