// 바닥(불투명). 실제 조명은 CS/FloorLight가 그 위에 가산으로 얹는다.
Shader "CS/Floor"
{
    SubShader
    {
        Tags { "Queue" = "Geometry" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        ZWrite Off Cull Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex CSVert
            #pragma fragment frag
            #include "CSFloor.hlsl"
            TEXTURE2D(_CSLightTex);
            float4 _CSLightRect;     // 조명 버퍼가 덮는 월드 영역: (왼쪽, 아래, 1/가로, 1/세로)
            half4 frag(CSVary i) : SV_Target
            {
                float2 w = i.wpos;
                float3 base; float grid, rough, ed;
                floorPattern(w, base, grid, rough);
                float m = arenaMask(w, ed);
                float3 gridCol = _CSZone < 0.5 ? float3(0.16, 0.30, 0.75) : (_CSZone < 1.5 ? float3(0.30, 0.38, 0.50) : (_CSZone < 2.5 ? float3(0.12, 0.62, 0.42) : (_CSZone < 3.5 ? float3(0.78, 0.36, 0.20) : (_CSZone < 4.5 ? float3(0.22, 0.46, 0.92) : float3(0.52, 0.36, 0.95)))));
                float3 col = (base + gridCol * grid * 0.16) * m;
                // 벽(접시 유리 / 벤치 측면 유리)
                float wall = exp(-pow(ed / 9.0, 2.0)) * 0.9 + exp(-pow((ed - 26.0) / 5.0, 2.0)) * 0.35;
                float meniscus = exp(-max(-ed, 0.0) / 110.0) * 0.05 * m;
                float3 wallCol = _CSZone < 1.5 ? float3(0.30, 0.50, 1.0) : (_CSZone < 2.5 ? float3(0.20, 0.95, 0.55) : (_CSZone < 3.5 ? float3(1.0, 0.50, 0.25) : (_CSZone < 4.5 ? float3(0.30, 0.62, 1.0) : float3(0.62, 0.45, 1.0))));
                col += wallCol * (wall * 0.55 + meniscus);
                // 조명: 누적 버퍼를 한 번 읽어 표면 무늬와 곱한다
                float2 luv = (w - _CSLightRect.xy) * _CSLightRect.zw;
                float3 light = SAMPLE_TEXTURE2D(_CSLightTex, sampler_LinearClamp, luv).rgb;
                float3 surf = float3(0.046, 0.050, 0.060) * (0.5 + 1.0 * rough) + grid * 0.16;
                col += light * (surf * m + exp(-pow(ed / 10.0, 2.0)) * 1.4);
                return half4(col, 1);
            }
            ENDHLSL
        }
    }
}
