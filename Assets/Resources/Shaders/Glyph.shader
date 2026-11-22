// 월드에 그리는 글자(타이틀 로고). 동적 폰트 아틀라스의 알파를 읽고 HDR 색을 곱해 블룸이 번지게 한다.
// uv0 = 폰트 UV, uv1 = HDR 색(rgb) + 알파, uv2.x = 글자마다 다른 씨앗(네온 깜빡임)
Shader "CS/Glyph"
{
    Properties { _MainTex ("Font", 2D) = "white" {} _Fade ("Fade", Float) = 1 }
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" }
        Blend One OneMinusSrcAlpha
        ZWrite Off Cull Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            float _Fade; float _CSTime;
            struct A { float4 pos : POSITION; float2 uv : TEXCOORD0; float4 col : TEXCOORD1; float4 p : TEXCOORD2; };
            struct V { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; float4 col : TEXCOORD1; float4 p : TEXCOORD2; };
            V vert(A i) { V o; o.pos = TransformObjectToHClip(i.pos.xyz); o.uv = i.uv; o.col = i.col; o.p = i.p; return o; }
            half4 frag(V i) : SV_Target
            {
                half a = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).a;
                // 네온 사인: 아주 약한 숨쉬기 + 가끔 한 글자가 깜빡
                float seed = i.p.x;
                float breathe = 0.93 + 0.07 * sin(_CSTime * 1.7 + seed * 6.0);
                float tick = floor(_CSTime * 9.0);
                float flick = step(0.992, frac(sin((tick + seed * 37.0) * 91.7) * 43758.5)) * i.p.y;
                float k = breathe * (1.0 - 0.75 * flick) * _Fade;
                a *= i.col.a * saturate(_Fade);
                return half4(i.col.rgb * k * a, a);
            }
            ENDHLSL
        }
    }
}
