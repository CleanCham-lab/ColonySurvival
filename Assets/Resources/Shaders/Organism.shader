// 세포·미생물을 수식(SDF)으로 그린다. 해상도와 무관하게 선명하고, 막이 살아 있는 것처럼 움직인다.
//   uv0.xy : 쿼드 안 좌표(-1..1)      col : HDR 형광색(rgb), 전체 불투명도(a)
//   p1 = (종류, 시드, 피격 플래시, HP 비율)
//   p2 = 플레이어(0~9): (0, 시선x, 시선y, 모자)   그 외: (진행 방향 각도, 차지 0..1, 감염 0..1, 엘리트)
Shader "CS/Organism"
{
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
        Blend One OneMinusSrcAlpha
        ZWrite Off Cull Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex CSVert
            #pragma fragment frag
            #include "CSCommon.hlsl"
            #include "CSArtifacts.hlsl"

            float cellRadius(float a, float seed, float t, int kind)
            {
                if (kind == 1) return 0.55 * (1.0 + 0.10 * sin(a * 3.0 + seed * 6.28 + t * 0.7) + 0.07 * sin(a * 5.0 - t * 0.9 + seed * 11.0) + 0.045 * sin(a * 8.0 + seed * 3.0 + t * 0.5));
                if (kind == 2) return 0.50 * (1.0 + 0.22 * pow(abs(sin(a * 1.5 + t * 0.9 + seed * 6.28)), 3.0) + 0.14 * pow(abs(sin(a * 2.5 - t * 1.3 + seed * 2.0)), 4.0) + 0.04 * sin(a * 7.0 + t * 2.0));
                return 0.58 * (1.0 + 0.035 * sin(a * 4.0 + t * 2.2 + seed * 6.28) + 0.025 * sin(a * 7.0 - t * 1.7));
            }

            // 공통 마무리: 막(rim) + 속 + 후광
            void shade(float d, float3 tint, float inner, float rimW, out float3 col, out float alpha)
            {
                float inside = aq(d);
                float rim = exp(-pow(d / rimW, 2.0));
                col = tint * (inner * inside + rim * 1.5) + tint * exp(-max(d, 0.0) * 9.0) * 0.28 * (1.0 - inside) * gEdge;
                alpha = saturate(inside * 0.6 + rim * 0.5);
            }

            half4 frag(CSVary i) : SV_Target
            {
                int kind = (int)(i.p1.x + 0.5);
                float seed = i.p1.y, t = _CSTime;
                float3 tint = i.col.rgb;
                float2 q = i.uv0.xy;
                float3 col = 0; float alpha = 0;
                // 가장자리를 부드럽게 하는 두께(쿼드 좌표에서 화면 한 픽셀의 크기). 분기 밖에서 한 번만 구한다 —
                // 분기 안에서 화면 미분을 쓰면 컴파일러가 분기를 모두 펼쳐, 픽셀마다 모든 모양을 다 계산하게 된다.
                gAA = max(length(float2(ddx(q.x), ddy(q.x))), length(float2(ddx(q.y), ddy(q.y)))) * 1.45 + 1e-4;
                gEdge = smoothstep(1.0, 0.80, max(abs(q.x), abs(q.y)));

                UNITY_BRANCH if (kind < 10)
                {
                    // ── 플레이어 셀라인 ──
                    float a = atan2(q.y, q.x), r = length(q);
                    float d = r - cellRadius(a, seed, t, kind);
                    float inside = aq(d);
                    float rim = exp(-pow(d / 0.045, 2.0));
                    float ds = max(1.0, i.uv0.z / 28.0);                 // 크게 그릴 때(타이틀 로고)는 결을 그만큼 곱게
                    float gran = fbm(q * 7.0 * ds + seed * 10.0 + t * 0.15);
                    float dots = pow(vnoise(q * 16.0 * ds + seed * 20.0 + float2(t * 0.3, 0.0)), 5.0);
                    float3 cyto = tint * (0.16 + 0.30 * gran + 0.9 * dots) * inside;
                    float2 look = i.p2.yz;
                    float2 nc = 0.06 * float2(cos(seed * 6.28), sin(seed * 6.28)) - look * 0.05 + float2(0.0, -0.20);
                    float nd = length((q - nc) * float2(1.0, 1.2)) - 0.20;
                    float nuc = aq(nd);
                    float3 nucCol = float3(0.22, 0.45, 1.7);
                    float chrom = 0.55 + 0.45 * fbm(q * 11.0 * ds + seed * 3.0);
                    col = cyto * (1.0 - nuc * 0.7) + nucCol * nuc * chrom * 0.8 + nucCol * exp(-pow(nd / 0.03, 2.0)) * 0.5 * inside;
                    col += tint * rim * 1.5;
                    col += tint * exp(-max(d, 0.0) * 9.0) * 0.30 * (1.0 - inside);
                    alpha = saturate(inside * 0.62 + rim * 0.5);
                    // 얼굴
                    float blink = step(0.965, frac(t * 0.31 + seed * 3.7));
                    float2 ec = float2(0.0, 0.13) + look * 0.07;
                    float2 eq = float2(abs(q.x - ec.x) - 0.16, (q.y - ec.y) * (1.0 + blink * 5.0));
                    float eye = aq(length(eq * float2(1.0, 0.82)) - 0.07) * inside;
                    float2 hq = float2(abs(q.x - ec.x) - 0.16, q.y - ec.y) - float2(0.022, 0.026);
                    float hl = aq(length(hq) - 0.022) * (1.0 - blink) * inside;
                    float2 mc = ec + float2(0.0, -0.10);
                    float smile = aq(abs(length(q - mc) - 0.10) - 0.016) * step(q.y, mc.y - 0.035) * inside;
                    float dark = saturate(eye + smile);
                    col = col * (1.0 - dark * 0.92) + float3(1.8, 1.9, 2.0) * hl;
                    alpha = saturate(alpha + dark * 0.4);
                    // 산타 모자
                    if (i.p2.w > 0.5)
                    {
                        float2 h = rot2(q - float2(0.0, 0.50), 0.22);
                        float cone = sdTri(h, float2(-0.34, 0.0), float2(0.34, 0.0), float2(0.26, 0.47)) - 0.02;
                        float band = sdBox(h - float2(0.0, 0.0), float2(0.37, 0.055)) - 0.03;
                        float pom = length(h - float2(0.30, 0.47)) - 0.085;
                        float cA = aq(cone);
                        float wA = saturate(aq(band) + aq(pom));
                        float3 red = float3(1.9, 0.16, 0.2) * (0.75 + 0.25 * fbm(h * 9.0));
                        col = lerp(col, red, cA); alpha = max(alpha, cA);
                        col = lerp(col, float3(1.7, 1.75, 1.8), wA); alpha = max(alpha, wA);
                    }
                }
                else
                {
                    float2 q0 = q;
                    q = rot2(q, i.p2.x);
                    float a = atan2(q.y, q.x), r = length(q);
                    float charge = i.p2.y;
                    UNITY_BRANCH if (kind >= 20)
                    {
                        // 구역 3~5의 적(CSArtifacts.hlsl)
                        artifact(kind, q0, q, seed, t, charge, i.p2.x, tint, col, alpha);
                    }
                    else if (kind == 10)
                    {
                        // 마이코플라스마: 아주 작은 발광점
                        float d = r - 0.42 * (1.0 + 0.10 * sin(a * 3.0 + t * 7.0 + seed * 9.0));
                        shade(d, tint, 0.45, 0.08, col, alpha);
                        col += tint * exp(-r * r * 9.0) * 0.9;
                    }
                    else if (kind == 11)
                    {
                        // 대장균: 막대 + 편모
                        float d = sdSeg(q, float2(-0.26, 0.0), float2(0.30, 0.0)) - 0.20;
                        float inner = 0.20 + 0.35 * fbm(q * 9.0 + seed * 5.0) + 0.5 * exp(-pow(length((q - float2(0.03, 0.0)) * float2(0.6, 1.6)) / 0.16, 2.0));
                        shade(d, tint, inner, 0.04, col, alpha);
                        float amp = saturate((-0.44 - q.x) * 3.0);
                        float fy = 0.10 * sin(q.x * 15.0 + t * 20.0 + seed * 6.0) * amp;
                        float fl = exp(-pow((q.y - fy) / 0.028, 2.0)) * step(q.x, -0.44) * smoothstep(-1.0, -0.88, q.x);
                        col += tint * fl * 0.9; alpha = saturate(alpha + fl * 0.3);
                    }
                    else if (kind == 12)
                    {
                        // 효모: 출아
                        float bud = 0.17 + 0.07 * (0.5 + 0.5 * sin(t * 1.3 + seed * 6.28));
                        float d1 = length((q - float2(-0.10, 0.0)) * float2(0.92, 1.06)) - 0.44;
                        float d2 = length(q - float2(0.44, 0.16)) - bud;
                        float d = min(d1, d2);
                        float vac = aq(length(q - float2(-0.18, -0.04)) - 0.17);
                        float inner = (0.30 + 0.25 * fbm(q * 8.0 + seed * 4.0)) * (1.0 - vac * 0.75);
                        shade(d, tint, inner, 0.045, col, alpha);
                        col += tint * exp(-pow(max(d1, d2) / 0.03, 2.0)) * 0.5;
                    }
                    else if (kind == 13)
                    {
                        // 박테리오파지 T4
                        float2 hq = rot2(q - float2(0.32, 0.0), 0.5236);
                        float dh = sdHex(hq, 0.25);
                        float tail = sdSeg(q, float2(0.06, 0.0), float2(-0.42, 0.0)) - 0.05;
                        float plate = sdBox(q - float2(-0.44, 0.0), float2(0.03, 0.12));
                        float2 m = float2(q.x, abs(q.y));
                        float w = 0.04 * sin(t * 9.0 + seed * 6.0);
                        float legs = min(sdSeg(m, float2(-0.44, 0.06), float2(-0.52, 0.30 + w)), sdSeg(m, float2(-0.52, 0.30 + w), float2(-0.88, 0.44 + w * 2.0)));
                        legs = min(legs, min(sdSeg(m, float2(-0.44, 0.08), float2(-0.36, 0.34 - w)), sdSeg(m, float2(-0.36, 0.34 - w), float2(-0.60, 0.62 - w)))) - 0.016;
                        float d = min(min(dh, tail), plate);
                        float inner = 0.25 + 0.9 * exp(-pow(length(q - float2(0.32, 0.0)) / 0.14, 2.0)) * (0.6 + 0.4 * sin(t * 6.0 + seed) + charge * 1.5);
                        shade(d, tint * (1.0 + charge * 1.2), inner, 0.035, col, alpha);
                        float lg = aq(legs);
                        col += tint * (lg * 1.1 + exp(-pow(legs / 0.03, 2.0)) * 0.35); alpha = saturate(alpha + lg * 0.6);
                    }
                    else if (kind == 14)
                    {
                        // 아스페르길루스 포자낭
                        float n = 10.0, seg = 6.2831853 / n;
                        float a2 = fmod(a + 3.14159265 + t * 0.25 + seed, seg) - seg * 0.5;
                        float2 p = r * float2(cos(a2), sin(a2));
                        float pulse = 1.0 + 0.10 * sin(t * 3.0 + seed * 6.0) + charge * 0.25;
                        float dc = min(min(length(p - float2(0.40, 0.0)) - 0.062, length(p - float2(0.52, 0.0) * pulse) - 0.056), min(length(p - float2(0.63, 0.0) * pulse) - 0.05, length(p - float2(0.73, 0.0) * pulse) - 0.042));
                        float stalk = sdSeg(p, float2(0.24, 0.0), float2(0.36, 0.0)) - 0.022;
                        float dv = r - 0.27;
                        float d = min(min(dv, dc), stalk);
                        float inner = 0.35 + 0.8 * exp(-r * r * 12.0) * (1.0 + charge * 2.0) + 0.3 * fbm(q * 10.0 + seed);
                        shade(d, tint * (1.0 + charge), inner, 0.03, col, alpha);
                    }
                    else if (kind == 15)
                    {
                        // 바이오필름: 끈적한 덩어리
                        float R = 0.66 * (1.0 + 0.11 * sin(a * 3.0 + seed * 6.0) + 0.07 * sin(a * 5.0 - t * 0.5) + 0.05 * sin(a * 9.0 + t * 0.35 + seed));
                        float d = r - R;
                        float cells = smoothstep(0.50, 0.72, vnoise(q * 8.5 + seed * 7.0 + t * 0.05));
                        float inner = 0.16 + 0.55 * cells + 0.2 * fbm(q * 5.0 + t * 0.1);
                        shade(d, tint, inner, 0.085, col, alpha);
                        alpha = saturate(alpha + aq(d) * 0.2);
                    }
                    else if (kind == 17)
                    {
                        // Reviewer: 원고 한 장 + 눈 + 펜 자국. seed = 눈동자가 향하는 각도, p1.w = 0 Reviewer #1(순함, 체크 표시) / 1 Reviewer #2(화남, X 표시)
                        float v2 = step(0.5, i.p1.w);
                        float2 pq = rot2(q, 0.035 * sin(t * 1.3));
                        float page = sdBox(pq, float2(0.50, 0.66)) - 0.05;
                        float inside = aq(page);
                        float rowId = floor(pq.y * 7.5 + 0.25);
                        float rows = step(0.45, frac(pq.y * 7.5 + 0.25)) * step(abs(pq.y), 0.60);
                        float len = 0.42 - 0.30 * hash11(rowId + 3.0) * step(0.55, hash11(rowId * 1.7 + 1.0));
                        float text = rows * step(-0.42, pq.x) * step(pq.x, len);
                        float2 ec = float2(0.0, 0.06);
                        float eyeD = length((pq - ec) * float2(1.0, lerp(1.30, 1.75 + 0.5 * charge, v2))) - 0.36;
                        float eyeIn = aq(eyeD);
                        float2 look = float2(cos(seed), sin(seed)) * float2(0.12, 0.07);
                        float iris = aq(length(pq - ec - look) - 0.125);
                        float pupil = aq(length(pq - ec - look * 1.12) - 0.055);
                        float hl = aq(length(pq - ec - look * 1.12 - float2(0.03, 0.035)) - 0.02);
                        float2 b0 = float2(0.07, lerp(0.46, 0.30 - 0.05 * charge, v2)), b1 = float2(0.40, lerp(0.43, 0.46, v2));
                        float brow = aq(sdSeg(float2(abs(pq.x), pq.y), b0, b1) - 0.035);
                        float2 xq = pq - float2(-0.24, -0.42);
                        float xmark = aq(min(sdSeg(xq, float2(-0.11, -0.11), float2(0.11, 0.11)), sdSeg(xq, float2(-0.11, 0.11), float2(0.11, -0.11))) - 0.028) * v2;
                        float chk = aq(min(sdSeg(xq, float2(-0.11, 0.0), float2(-0.03, -0.09)), sdSeg(xq, float2(-0.03, -0.09), float2(0.13, 0.11))) - 0.026) * (1.0 - v2);
                        float3 paper = float3(0.50, 0.55, 0.68) * (0.30 + 0.12 * fbm(pq * 6.0)) * (1.0 - text * 0.62);
                        col = paper * inside;
                        col = lerp(col, float3(0.03, 0.0, 0.01), eyeIn * inside);
                        col += tint * exp(-pow(eyeD / 0.03, 2.0)) * 1.3 * inside;
                        col += tint * (2.2 + 1.2 * charge) * iris * eyeIn * (1.0 - pupil);
                        col += float3(2.4, 2.3, 2.2) * hl * eyeIn;
                        col += tint * 1.7 * saturate(brow + xmark + chk) * inside * (1.0 - eyeIn);
                        col += tint * exp(-pow(page / 0.05, 2.0)) * (1.3 + charge);
                        col += tint * exp(-max(page, 0.0) * 8.0) * 0.3 * (1.0 - inside);
                        alpha = saturate(inside * 0.94 + exp(-pow(page / 0.05, 2.0)) * 0.5);
                    }
                    else if (kind == 18)
                    {
                        // 핫코코아 머그컵: 크림색 컵 + 빨간 띠 + 손잡이 + 코코아 + 마시멜로 + 김
                        float2 bq = q - float2(-0.10, -0.14);
                        float body = sdBox(bq, float2(0.34, 0.34)) - 0.09;
                        float2 hq = q - float2(0.38, -0.14);
                        float handle = max(abs(length(hq * float2(1.0, 0.85)) - 0.21) - 0.06, -(hq.x + 0.06));
                        float cup = min(body, handle);
                        float inside = aq(cup), bodyIn = aq(body);
                        float3 ceramic = float3(1.0, 0.94, 0.86) * 0.92;
                        float band = step(abs(bq.y + 0.04), 0.11) * bodyIn;
                        float3 cupCol = lerp(ceramic, float3(0.95, 0.14, 0.18), band);
                        float dotsM = aq(length(float2(frac(bq.x * 3.2 + 0.5) - 0.5, (bq.y + 0.04) * 3.2)) - 0.13) * band;
                        cupCol = lerp(cupCol, float3(1.0, 1.0, 1.0), dotsM);
                        cupCol *= 0.74 + 0.26 * saturate(0.62 - bq.x * 0.9);
                        float2 tq = (q - float2(-0.10, 0.25)) / float2(0.35, 0.105);
                        float tl = length(tq);
                        float top = aq((tl - 0.86) * 0.105), rimTop = aq((tl - 1.0) * 0.105);
                        float3 cocoa = float3(0.40, 0.19, 0.08) * (0.85 + 0.35 * vnoise(q * 9.0 + t * 0.4));
                        float marsh = saturate(aq(sdBox(rot2(q - float2(-0.21, 0.27), 0.3), float2(0.07, 0.045)) - 0.03) + aq(sdBox(rot2(q - float2(0.03, 0.24), -0.4), float2(0.065, 0.04)) - 0.03));
                        col = cupCol * inside;
                        col = lerp(col, ceramic * 1.06, rimTop);
                        col = lerp(col, cocoa, top);
                        col = lerp(col, float3(1.0, 0.97, 0.93), marsh * top);
                        alpha = saturate(inside + rimTop);
                        float sy = q.y - 0.40;
                        float s1 = exp(-pow((q.x + 0.24 - 0.05 * sin(sy * 9.0 + t * 2.4)) / 0.04, 2.0));
                        float s2 = exp(-pow((q.x - 0.02 - 0.05 * sin(sy * 8.0 - t * 2.0 + 1.7)) / 0.04, 2.0));
                        float steam = (s1 + s2) * smoothstep(0.0, 0.10, sy) * smoothstep(0.56, 0.16, sy) * (0.65 + 0.35 * sin(t * 1.3 + seed * 6.0));
                        col += float3(1.0, 0.96, 0.9) * steam * 0.6 * (1.0 - alpha);
                        alpha = saturate(alpha + steam * 0.4);
                        col += tint * exp(-pow(max(cup, 0.0) / 0.07, 2.0)) * 0.45 * (1.0 - inside);
                    }
                    else
                    {
                        // 팁 박스(부수면 아이템)
                        float d = sdBox(q, float2(0.62, 0.46)) - 0.08;
                        float2 g = frac(q * float2(4.2, 4.2) + 0.5) - 0.5;
                        float tips = aq(length(g) - 0.22) * aq(sdBox(q, float2(0.54, 0.38)));
                        shade(d, tint, 0.12 + tips * 0.7, 0.04, col, alpha);
                    }
                    // 감염(렌티바이러스) 표시: 청록 반점
                    float inf = i.p2.z;
                    if (inf > 0.01)
                    {
                        float sp = pow(vnoise(q * 12.0 + t * 1.5 + seed * 9.0), 4.0) * alpha;
                        col += float3(0.3, 1.9, 1.7) * sp * inf * 2.2;
                    }
                    // 엘리트: 노란 회전 고리
                    if (i.p2.w > 0.5)
                    {
                        float ring = exp(-pow((r - 0.90) / 0.035, 2.0)) * (0.55 + 0.45 * step(0.0, sin(a * 8.0 + t * 3.0)));
                        col += float3(2.2, 1.8, 0.35) * ring;
                    }
                }
                float fl = saturate(i.p1.z);
                col = lerp(col, float3(2.4, 2.4, 2.4) * saturate(alpha * 1.6), fl);
                return half4(col * i.col.a, alpha * i.col.a);
            }
            ENDHLSL
        }
    }
}
