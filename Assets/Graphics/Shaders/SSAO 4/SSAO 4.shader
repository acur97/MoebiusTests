Shader "Custom/SSAO 4"
{
    Properties
    {
        _NoiseTexture("Noise Texture", 2D) = "white"
        _Intensity("SSAO Intensity", Float) = 1.1
        _Intensity("SSAO Intensity", Float) = 1.1
        _Intensity("SSAO Intensity", Float) = 1.1
        _Intensity("SSAO Intensity", Float) = 1.1
        _Intensity("SSAO Intensity", Float) = 1.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Transparent" }
        Pass
        {
            Name "FullScreenPass"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            TEXTURE2D(_NoiseTexture);
            SAMPLER(sampler_NoiseTexture);

            TEXTURE2D(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            float _Intensity;

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(uint vertexID : SV_VertexID)
            {
                v2f o;
                o.pos = GetFullScreenTriangleVertexPosition(vertexID);
                o.uv = GetFullScreenTriangleTexCoord(vertexID);
                return o;
            }

            float3 getPosition(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).xyz;
            }

            float3 getNormal(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv).xyz;
            }

            float2 getRandom(float2 uv)
            {
                return normalize(SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, uv).xy * 2.0 - 1.0);
            }

            float doAmbientOcclusion(float2 uv, float2 offset, float3 p, float3 n)
            {
                float3 diff = getPosition(uv + offset) - p;
                float3 v = normalize(diff);
                float d = length(v) * _Scale;
                float ao = max(0.0, dot(n, v) - _Bias) * (1.0 / (1.0 + d)) * _Intensity;
                float l = length(diff);
                ao *= smoothstep(_DisConstraint, _DisConstraint * 0.5, l);
                return ao;
            }
            
            half4 frag(v2f i) : SV_Target
            {
                float2 uv = input.uv;
                float3 p = getPosition(uv);
                float3 n = getNormal(uv);
                float2 rand = getRandom(uv);

                const float2 dire[4] = { float2(1,0), float2(-1,0), float2(0,1), float2(0,-1) };

                float ssao = 0.0;
                int iterations = 4;
                for (int i = 0; i < iterations; i++) {
                    float2 coord1 = reflect(dire[i], rand) * _SampleRad;
                    float2 coord2 = float2(coord1.x * cos(radians(45.0)) - coord1.y * sin(radians(45.0)), 
                                           coord1.x * cos(radians(45.0)) + coord1.y * sin(radians(45.0)));
                    ssao += doAmbientOcclusion(uv, coord1 * 0.25, p, n);
                    ssao += doAmbientOcclusion(uv, coord2 * 0.5, p, n);
                    ssao += doAmbientOcclusion(uv, coord1 * 0.75, p, n);
                    ssao += doAmbientOcclusion(uv, coord2, p, n);
                }

                ssao /= (iterations * 4.0);
                ssao = 1.0 - ssao * _Intensity;

                return float4(ssao, ssao, ssao, 1.0);
            }
            ENDHLSL
        }
    }
}