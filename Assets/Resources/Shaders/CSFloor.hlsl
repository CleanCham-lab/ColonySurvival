#ifndef CS_FLOOR_INCLUDED
#define CS_FLOOR_INCLUDED
#include "CSCommon.hlsl"

float _CSZone;      // 0 배양접시, 1 클린벤치, 2 시퀀싱실(숏리드), 3 PCR실, 4 분석 서버실, 5 시퀀싱실(롱리드)
float4 _CSArena;    // 접시: (반지름,0,0,0) / 직사각형 구역: (가로 절반, 세로 절반,0,0)

float gridLine(float x, float period, float width)
{
    float d = abs(frac(x / period + 0.5) - 0.5) * period;
    float w = fwidth(x) * 1.2;
    return 1.0 - smoothstep(width, width + w, d);
}

// 구역 안쪽이면 1 (가장자리는 부드럽게)
float arenaMask(float2 w, out float edgeDist)
{
    if (_CSZone < 0.5) { edgeDist = length(w) - _CSArena.x; }
    else { float2 d = abs(w) - _CSArena.xy; edgeDist = max(d.x, d.y); }
    return 1.0 - smoothstep(0.0, 6.0, edgeDist);
}

// 시퀀싱실 바닥: 정렬된 리드가 층층이 깔린 모양(IGV 파일업). 반환 = 막대 안이면 1, tick = 염기 표시 자리
float readBar(float2 w, float rowH, float slotLen, float minLen, out float2 baseId)
{
    float row = floor(w.y / rowH), fy = frac(w.y / rowH) - 0.5;
    float x = w.x + hash11(row * 1.37) * slotLen * 2.3;
    float slot = floor(x / slotLen), fx = frac(x / slotLen);
    float len = minLen + (0.94 - minLen) * hash21(float2(slot, row));
    float present = step(0.30, hash21(float2(slot + 7.0, row * 3.0)));
    float ex = fwidth(w.x) / slotLen;
    float bar = present * smoothstep(0.03, 0.03 + ex * 2.0, fx) * (1.0 - smoothstep(0.03 + len * 0.9, 0.03 + len * 0.9 + ex * 2.0, fx)) * (1.0 - smoothstep(0.24, 0.24 + fwidth(w.y) / rowH * 1.5, abs(fy)));
    baseId = float2(floor(x / 7.0), row);
    return bar;
}

// 조명용(가벼움): 새겨진 선과 거칠기만
void floorDetail(float2 w, out float grid, out float rough)
{
    rough = vnoise(w * 0.006) * 0.6 + vnoise(w * 0.021) * 0.4;
    if (_CSZone < 0.5)
    {
        float fine = (gridLine(w.x, 30.0, 0.6) + gridLine(w.y, 30.0, 0.6)) * step(abs(w.x), 300.5) * step(abs(w.y), 300.5);
        float mid = gridLine(w.x, 150.0, 0.8) + gridLine(w.y, 150.0, 0.8);
        float big = gridLine(w.x, 600.0, 1.0) + gridLine(w.y, 600.0, 1.0) + gridLine(w.x + 6.0, 600.0, 0.8) + gridLine(w.y + 6.0, 600.0, 0.8) + gridLine(w.x - 6.0, 600.0, 0.8) + gridLine(w.y - 6.0, 600.0, 0.8);
        grid = saturate(fine * 0.30 + mid * 0.5 + big * 0.7);
    }
    else if (_CSZone > 4.5)
    {
        float lane = gridLine(w.y, 640.0, 2.0) + gridLine(w.x, 1200.0, 1.2) * 0.5;
        float2 bid; float bar = readBar(w, 34.0, 1250.0, 0.62, bid);
        grid = saturate(lane * 0.8 + bar * 0.18);
    }
    else if (_CSZone > 3.5)
    {
        float seam = gridLine(w.x, 200.0, 1.4) + gridLine(w.y, 200.0, 1.4);
        grid = saturate(seam * 0.85 + (gridLine(w.x + 13.0, 40.0, 0.5) + gridLine(w.y + 13.0, 40.0, 0.5)) * 0.08);
    }
    else if (_CSZone > 2.5)
    {
        float2 g = (frac(w / 110.0 + 0.5) - 0.5) * 110.0;
        float d = sdBox(g, float2(33.0, 33.0)) - 9.0;
        grid = saturate(exp(-pow(d / 2.4, 2.0)) * 0.9 + (gridLine(w.x + 55.0, 110.0, 0.6) + gridLine(w.y + 55.0, 110.0, 0.6)) * 0.10 * step(0.0, d));
        rough *= 1.0 + 0.3 * aa(d);
    }
    else if (_CSZone > 1.5)
    {
        float lane = gridLine(w.y, 640.0, 2.0) + gridLine(w.x, 1200.0, 1.2) * 0.5;
        float2 bid; float bar = readBar(w, 20.0, 170.0, 0.40, bid);
        grid = saturate(lane * 0.8 + bar * 0.16);
    }
    else
    {
        float brush = vnoise(float2(w.x * 0.004, w.y * 0.35)) * 0.5 + vnoise(float2(w.x * 0.02, w.y * 1.3)) * 0.5;
        float2 hs = _CSArena.xy;
        float2 g = frac(w / 24.0) - 0.5;
        float hole = aa((length(g) - 0.17) * 24.0) * step(w.y, -hs.y + 170.0);
        grid = saturate(gridLine(w.x, 920.0, 1.5) * 0.7 + (brush - 0.5) * 0.3) * (1.0 - hole);
        rough = brush * (1.0 - hole * 0.9);
    }
}

// 바닥 무늬. base = 어두운 바탕색, grid = 새겨진 선(빛을 받으면 밝아진다)
void floorPattern(float2 w, out float3 base, out float grid, out float rough)
{
    float n = vnoise(w * 0.0035) * 0.62 + vnoise(w * 0.0071 + 17.1) * 0.38;      // 바탕 얼룩(2옥타브면 충분)
    rough = n;
    if (_CSZone < 0.5)
    {
        base = float3(0.008, 0.012, 0.026) + float3(0.012, 0.018, 0.034) * n;
        // 초점 밖 세포들(보케)
        float2 cell = floor(w / 560.0 - 0.5);      // 가장 가까운 2×2 칸만 본다(원 반지름이 칸의 절반보다 작다)
        float3 bok = 0;
        for (int y = 0; y <= 1; y++)
            for (int x = 0; x <= 1; x++)
            {
                float2 c = cell + float2(x, y);
                float2 h = hash22(c);
                float2 ctr = (c + 0.2 + 0.6 * h) * 560.0 + 22.0 * float2(sin(_CSTime * 0.21 + h.x * 40.0), cos(_CSTime * 0.17 + h.y * 40.0));
                float rad = 70.0 + 120.0 * hash21(c + 7.3);
                float d = length(w - ctr) / rad;
                float disc = smoothstep(1.0, 0.72, d) * (0.6 + 0.4 * smoothstep(0.5, 1.0, d));
                float3 tint = lerp(float3(0.10, 0.20, 0.55), float3(0.26, 0.14, 0.50), step(0.5, h.x));
                tint = lerp(tint, float3(0.06, 0.32, 0.42), step(0.8, h.y));
                bok += tint * disc * 0.085;
            }
        base += bok;
        float fine = gridLine(w.x, 30.0, 0.6) + gridLine(w.y, 30.0, 0.6);
        fine *= step(abs(w.x), 300.5) * step(abs(w.y), 300.5);
        float mid = gridLine(w.x, 150.0, 0.8) + gridLine(w.y, 150.0, 0.8);
        float big = gridLine(w.x, 600.0, 1.0) + gridLine(w.y, 600.0, 1.0) + gridLine(w.x + 6.0, 600.0, 0.8) + gridLine(w.y + 6.0, 600.0, 0.8) + gridLine(w.x - 6.0, 600.0, 0.8) + gridLine(w.y - 6.0, 600.0, 0.8);
        grid = saturate(fine * 0.30 + mid * 0.55 + big * 0.8);
    }
    else if (_CSZone > 4.5)
    {
        // 시퀀싱실(롱리드): 화면을 가로지를 만큼 긴 리드가 띄엄띄엄 깔려 있다.
        base = float3(0.008, 0.007, 0.018) + float3(0.010, 0.009, 0.020) * n;
        float2 bid; float bar = readBar(w, 34.0, 1250.0, 0.62, bid);
        float isTick = step(0.975, hash21(bid * float2(1.0, 1.9)));
        float h = hash21(bid * 1.31 + 4.0);
        float3 bc = h < 0.25 ? float3(0.12, 1.0, 0.38) : (h < 0.5 ? float3(1.0, 0.24, 0.32) : (h < 0.75 ? float3(0.26, 0.56, 1.0) : float3(1.0, 0.84, 0.22)));
        float tw = 0.55 + 0.45 * sin(_CSTime * (1.2 + 1.5 * hash21(bid + 9.0)) + h * 40.0);
        base += bar * (float3(0.016, 0.013, 0.034) + bc * isTick * tw * 0.085);
        float lane = gridLine(w.y, 640.0, 2.0) + gridLine(w.x, 1200.0, 1.2) * 0.5;
        grid = saturate(lane * 0.9);
    }
    else if (_CSZone > 3.5)
    {
        // 분석 서버실: 이중 바닥 타일 + 배선. 배선을 따라 데이터가 흐르고 타일 모서리 LED가 깜빡인다.
        base = float3(0.006, 0.009, 0.018) + float3(0.008, 0.010, 0.018) * n;
        float seam = gridLine(w.x, 200.0, 1.4) + gridLine(w.y, 200.0, 1.4);
        float2 tile = floor(w / 200.0), tf = frac(w / 200.0);
        float hsel = step(0.5, hash21(tile));
        float across = hsel > 0.5 ? w.y : w.x, along = hsel > 0.5 ? w.x : w.y;
        float tr = gridLine(across + 13.0, 40.0, 0.5);
        float lane = floor((across + 13.0) / 40.0 + 0.5);
        float pulse = saturate(1.0 - abs(frac(along / 400.0 - _CSTime * (0.25 + 0.2 * hash11(lane)) + hash11(lane * 3.1)) - 0.5) * 8.0);
        base += float3(0.02, 0.10, 0.16) * tr * pulse * pulse * 0.55 + float3(0.010, 0.016, 0.030) * tr * 0.5;
        float2 lf = (tf - float2(0.08, 0.08)) * 200.0;
        float led = aa(length(lf) - 2.6) * step(0.55, hash21(tile + floor(_CSTime * 1.5 + hash21(tile * 2.3) * 3.0)));
        base += lerp(float3(0.1, 1.0, 0.4), float3(1.0, 0.65, 0.1), step(0.8, hash21(tile * 5.7))) * led * 0.22;
        grid = saturate(seam * 0.85 + tr * 0.12);
    }
    else if (_CSZone > 2.5)
    {
        // PCR실: 히팅 블록. 모서리가 둥근 네모 패드가 온도 사이클에 따라 은은하게 달아오른다.
        base = float3(0.016, 0.012, 0.013) + float3(0.014, 0.010, 0.010) * n;
        float2 g = (frac(w / 110.0 + 0.5) - 0.5) * 110.0;
        float d = sdBox(g, float2(33.0, 33.0)) - 9.0;
        float inside = aa(d);
        float heat = 0.5 + 0.5 * sin(_CSTime * 0.35);
        float3 well = float3(0.022, 0.016, 0.017) + float3(0.045, 0.012, 0.004) * heat * (0.4 + 0.6 * vnoise(w * 0.02 + _CSTime * 0.2));
        base = lerp(base, well, inside);
        grid = saturate(exp(-pow(d / 2.2, 2.0)) * 0.9 + (gridLine(w.x + 55.0, 110.0, 0.6) + gridLine(w.y + 55.0, 110.0, 0.6)) * 0.12 * (1.0 - inside));
    }
    else if (_CSZone > 1.5)
    {
        // 시퀀싱실: 리드가 층층이 정렬된 바닥. 군데군데 염기(A/C/G/T) 표시가 반짝인다.
        base = float3(0.005, 0.012, 0.011) + float3(0.008, 0.016, 0.014) * n;
        float2 bid; float bar = readBar(w, 20.0, 170.0, 0.40, bid);
        float isTick = step(0.955, hash21(bid * float2(1.0, 1.9)));
        float h = hash21(bid * 1.31 + 4.0);
        float3 bc = h < 0.25 ? float3(0.12, 1.0, 0.38) : (h < 0.5 ? float3(1.0, 0.24, 0.32) : (h < 0.75 ? float3(0.26, 0.56, 1.0) : float3(1.0, 0.84, 0.22)));
        float tw = 0.55 + 0.45 * sin(_CSTime * (1.2 + 1.5 * hash21(bid + 9.0)) + h * 40.0);
        base += bar * (float3(0.010, 0.024, 0.022) + bc * isTick * tw * 0.085);
        float lane = gridLine(w.y, 640.0, 2.0) + gridLine(w.x, 1200.0, 1.2) * 0.5;
        grid = saturate(lane * 0.9);
    }
    else
    {
        // 클린벤치: 브러시드 스테인리스
        float brush = vnoise(float2(w.x * 0.004, w.y * 0.35)) * 0.5 + vnoise(float2(w.x * 0.02, w.y * 1.3)) * 0.5;
        base = float3(0.014, 0.017, 0.022) + float3(0.016, 0.018, 0.022) * brush + float3(0.006, 0.008, 0.012) * n;
        float seam = gridLine(w.x, 920.0, 1.5);
        float2 hs = _CSArena.xy;
        float grille = step(w.y, -hs.y + 170.0);
        float2 g = frac(w / 24.0) - 0.5;
        float hole = aa((length(g) - 0.17) * 24.0) * grille;
        base = lerp(base, float3(0.001, 0.001, 0.002), hole * 0.95);
        float hepa = step(hs.y - 120.0, w.y);
        base += float3(0.02, 0.03, 0.045) * hepa * gridLine(w.x, 14.0, 1.0);
        grid = saturate(seam * 0.7 + (brush - 0.5) * 0.25 + hepa * 0.2);
        rough = brush;
    }
}
#endif
