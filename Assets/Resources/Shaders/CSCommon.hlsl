#ifndef CS_COMMON_INCLUDED
#define CS_COMMON_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// 게임이 매 프레임 넣어 주는 시간(일시정지하면 멈춘다)
float _CSTime;

struct CSAttr { float4 positionOS : POSITION; float4 uv0 : TEXCOORD0; float4 p1 : TEXCOORD1; float4 col : TEXCOORD2; float4 p2 : TEXCOORD3; };
struct CSVary { float4 positionCS : SV_POSITION; float4 uv0 : TEXCOORD0; float4 p1 : TEXCOORD1; float4 col : TEXCOORD2; float4 p2 : TEXCOORD3; float2 wpos : TEXCOORD4; };

CSVary CSVert(CSAttr i)
{
    CSVary o;
    o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
    o.uv0 = i.uv0; o.p1 = i.p1; o.col = i.col; o.p2 = i.p2; o.wpos = i.positionOS.xy;
    return o;
}

float hash11(float n) { return frac(sin(n * 127.1) * 43758.5453); }
float hash21(float2 p) { p = frac(p * float2(123.34, 456.21)); p += dot(p, p + 45.32); return frac(p.x * p.y); }
float2 hash22(float2 p) { float n = hash21(p); return float2(n, hash21(p + n * 31.7)); }
float vnoise(float2 p)
{
    float2 i = floor(p), f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(hash21(i), hash21(i + float2(1, 0)), f.x), lerp(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), f.x), f.y);
}
float fbm(float2 p) { float a = 0.5, s = 0.0; for (int k = 0; k < 4; k++) { s += a * vnoise(p); p = p * 2.03 + 17.1; a *= 0.5; } return s; }
float2 rot2(float2 p, float a) { float s = sin(a), c = cos(a); return float2(c * p.x + s * p.y, -s * p.x + c * p.y); }
float sdSeg(float2 p, float2 a, float2 b) { float2 pa = p - a, ba = b - a; float h = saturate(dot(pa, ba) / dot(ba, ba)); return length(pa - ba * h); }
float sdHex(float2 p, float r) { const float3 k = float3(-0.866025404, 0.5, 0.577350269); p = abs(p); p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy; p -= float2(clamp(p.x, -k.z * r, k.z * r), r); return length(p) * sign(p.y); }
float sdBox(float2 p, float2 b) { float2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }
float sdTri(float2 p, float2 p0, float2 p1, float2 p2)
{
    float2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
    float2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
    float2 pq0 = v0 - e0 * saturate(dot(v0, e0) / dot(e0, e0));
    float2 pq1 = v1 - e1 * saturate(dot(v1, e1) / dot(e1, e1));
    float2 pq2 = v2 - e2 * saturate(dot(v2, e2) / dot(e2, e2));
    float s = sign(e0.x * e2.y - e0.y * e2.x);
    float2 d = min(min(float2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)), float2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))), float2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
    return -sqrt(d.x) * sign(d.y);
}
// 부드러운 가장자리(화면 미분으로 두께를 맞춘다)
float aa(float d) { float w = fwidth(d) * 1.2 + 1e-4; return saturate(0.5 - d / w); }
#endif
