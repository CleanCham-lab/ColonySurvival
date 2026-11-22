// 가산(Additive) 발광 도형: 탄환·ATP·파티클·빔·링. HDR 색을 넣으면 블룸이 번진다.
// p1.x = 도형 번호, p1.yzw = 도형별 값
Shader "CS/Glow"
{
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
        Blend One One
        ZWrite Off Cull Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex CSVert
            #pragma fragment frag
            #include "CSCommon.hlsl"

            half4 frag(CSVary i) : SV_Target
            {
                float2 q = i.uv0.xy;
                float r = length(q);
                int shape = (int)(i.p1.x + 0.5);
                float v = 0.0;
                if (shape == 0) { v = exp(-r * r * 4.5) * saturate(1.0 - r); }                                   // 부드러운 원
                else if (shape == 1) { float w = max(i.p1.z, 0.01); float d = (r - i.p1.y) / w; v = exp(-d * d) * saturate(1.05 - r); } // 링
                else if (shape == 2)                                                                              // ATP 결정
                {
                    float d = abs(q.x) / 0.42 + abs(q.y) / 0.66 - 1.0;
                    float body = aa(d * 0.4);
                    float facet = 0.55 + 0.45 * step(0.0, q.x * q.y) + 0.35 * saturate(0.3 - abs(q.x + q.y));
                    float tw = 0.75 + 0.25 * sin(_CSTime * 5.0 + i.p1.y * 40.0);
                    v = body * facet * tw + exp(-r * r * 5.0) * 0.55;
                }
                else if (shape == 3) { float core = exp(-r * r * 9.0); v = core * 1.6 + exp(-r * r * 2.5) * 0.4; v *= saturate(1.0 - r); }  // 뜨거운 점
                else if (shape == 4)                                                                              // 적 탄환: 속이 비친 구슬
                {
                    float rim = exp(-pow((r - 0.55) / 0.13, 2.0));
                    v = rim * 1.3 + exp(-r * r * 14.0) * 1.5 + exp(-r * r * 3.0) * 0.35; v *= saturate(1.0 - r);
                }
                else if (shape == 5) { float s = 0.012 / (abs(q.x) * abs(q.y) + 0.012); v = saturate(s) * saturate(1.0 - r) * 1.4 + exp(-r * r * 10.0); } // 반짝임
                else if (shape == 6)                                                                              // 빔: x = 길이 방향, y = 폭 방향
                {
                    float ends = saturate((1.0 - abs(q.x)) * i.p1.y);
                    float flick = 0.85 + 0.15 * sin(q.x * i.p1.z * 30.0 - _CSTime * 40.0);
                    v = (exp(-q.y * q.y * 22.0) * 1.5 + exp(-q.y * q.y * 3.5) * 0.45) * ends * flick;
                }
                else if (shape == 7)                                                                              // 베기(초승달)
                {
                    float a = atan2(q.y, q.x);
                    float ang = saturate(1.0 - abs(a) / max(i.p1.y, 0.05));
                    float d = (r - 0.78 + 0.16 * (1.0 - ang)) / 0.09;
                    v = exp(-d * d) * pow(ang, 0.6) * 1.8 + exp(-pow((r - 0.6) / 0.25, 2.0)) * ang * 0.35;
                }
                else if (shape == 8)                                                                              // 나노포어(육각 고리)
                {
                    float d = abs(sdHex(rot2(q, _CSTime * 2.0), 0.55)) - 0.07;
                    v = aa(d) * 1.4 + exp(-d * d * 60.0) * 0.6 + exp(-r * r * 16.0) * 0.8;
                }
                else if (shape == 9)                                                                              // 충격파 링
                {
                    float a = atan2(q.y, q.x);
                    float wob = 0.02 * sin(a * 9.0 + _CSTime * 12.0);
                    float w = max(i.p1.z, 0.01); float d = (r - i.p1.y + wob) / w;
                    v = exp(-d * d) * 1.2 + exp(-pow((r - i.p1.y) / (w * 4.0), 2.0)) * 0.25 * step(r, i.p1.y);
                    v *= saturate(1.05 - r) * 4.0;
                }
                else if (shape == 10) { v = saturate(1.0 - r) * saturate(1.0 - r) * 0.9 + exp(-r * r * 8.0) * 0.4; } // 넓은 후광
                else if (shape == 11)                                                                             // 채워진 장판(잔물결)
                {
                    float edge = exp(-pow((r - 0.9) / 0.05, 2.0));
                    float fill = step(r, 0.92) * (0.22 + 0.12 * sin(r * 26.0 - _CSTime * 6.0) + 0.1 * fbm(q * 5.0 + _CSTime * 0.6));
                    v = edge + fill;
                }
                else if (shape == 12)                                                                             // 방울: 앞(+x)이 둥글고 뒤로 꼬리
                {
                    float hd = length(q - float2(0.28, 0.0));
                    float tl = abs(q.y) / max(0.30 * saturate((q.x + 0.85) / 1.13), 0.001);
                    float body = max(exp(-hd * hd * 14.0), exp(-tl * tl * 1.6) * step(-0.85, q.x) * step(q.x, 0.28) * 0.75);
                    v = body * 1.5 + exp(-hd * hd * 40.0) * 1.2;
                    v *= saturate(1.05 - r);
                }
                else if (shape == 13)                                                                             // 막대: 날아가는 방향으로 누운 짧은 줄
                {
                    float dx = max(abs(q.x) - 0.55, 0.0), dy = abs(q.y);
                    float d = sqrt(dx * dx + dy * dy);
                    v = exp(-pow(d / 0.16, 2.0)) * 1.5 + exp(-pow(d / 0.38, 2.0)) * 0.35;
                    v *= saturate(1.05 - r);
                }
                else if (shape == 14)                                                                             // 네모 조각(데이터·잡음)
                {
                    float d = max(abs(q.x), abs(q.y)) - 0.42;
                    v = saturate(0.5 - d / 0.10) * 0.9 + exp(-pow(d / 0.09, 2.0)) * 0.9 + exp(-r * r * 3.0) * 0.25;
                    v *= saturate(1.1 - max(abs(q.x), abs(q.y)));
                }
                half3 c = i.col.rgb * v * i.col.a;
                return half4(c, 0);
            }
            ENDHLSL
        }
    }
}
