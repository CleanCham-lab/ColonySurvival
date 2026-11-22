// 바닥 조명(누적 버퍼용): 빛나는 것 하나마다 쿼드 한 장을 가산으로 그린다.
// 화면의 1/4 해상도 버퍼(_CSLightTex)에 그려 두고, 바닥 셰이더(CS/Floor)가 픽셀당 한 번 읽어 표면 무늬와 곱한다.
// col = 빛의 색(HDR), 쿼드 크기 = 빛이 닿는 반경
Shader "CS/FloorLight"
{
    SubShader
    {
        Tags { "Queue" = "Geometry+10" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
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
                float r = length(i.uv0.xy);
                float att = saturate(1.0 - r); att = att * att;
                return half4(i.col.rgb * i.col.a * att, 0);
            }
            ENDHLSL
        }
    }
}
