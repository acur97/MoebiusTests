Shader "Custom/SSAO 4"
{
    Properties
    {
        _Radius("Radius", Range(0, 0.05)) = 0.2
        _MinRadius("Min Radius", Range(0, 0.1)) = 8.0
        _Bias("Bias", Range(0, 0.001)) = 0.05
        _Intensity("Intensity", Float) = 1.0
        _Intensity2("Intensity2", Float) = 1.0
        _SampleCount("Sample Count", Range(1, 32)) = 16
        _NoiseScale("Noise Scale", Float) = 8.0
        _NoiseTex("Noise Texture", 2D) = "white" {}

        _PatternTexture("Pattern Texture", 2D) = "black"
        _PatternIntensity("Pattern Intensity", Float) = 1
        _PatternRepetition("Pattern Repetition", Float) = 1
        _PatternRotate("Pattern Rotate", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Overlay" }
        Pass
        {
            Name "SSAO"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #define MOD3 half3(0.1031, 0.11369, 0.13787)

            float _Radius;
            float _MinRadius;
            float _Bias;
            float _Intensity;
            float _Intensity2;
            int _SampleCount;
            float _NoiseScale;

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE2D(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);

            TEXTURE2D(_NoiseTex);
            SAMPLER(sampler_NoiseTex);

			TEXTURE2D(_PatternTexture);
			SAMPLER(sampler_PatternTexture);
			half _PatternIntensity;
			half _PatternRepetition;
			half _PatternRotate;

            struct v2f
            {
                half4 pos : SV_POSITION;
                half2 uv : TEXCOORD0;
            };

            v2f vert(uint vertexID : SV_VertexID)
            {
                v2f o;
                o.pos = GetFullScreenTriangleVertexPosition(vertexID);
                o.uv = GetFullScreenTriangleTexCoord(vertexID);
                return o;
            }

            float3 ComputeViewSpacePosition(float2 uv, float rawDepth)
            {
                float2 ndc = uv * 2.0 - 1.0;
                float4 clipPos = float4(ndc, rawDepth, 1.0);
                float4 viewPos = mul(unity_CameraInvProjection, clipPos);
                return viewPos.xyz / viewPos.w;
            }

            float3 GetViewSpaceNormal(float2 uv)
            {
                float4 enc = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv);
                return normalize(enc.xyz * 2.0 - 1.0);
            }

            float2 RotateUV(float2 uv, float angleDeg)
            {
                float angle = radians(angleDeg); // convertir a radianes
                float s = sin(angle);
                float c = cos(angle);

                // trasladar al centro (0.5,0.5)
                uv -= 0.5;

                // rotar
                float2x2 rot = float2x2(c, -s, s, c);
                uv = mul(rot, uv);

                // regresar a espacio de textura
                uv += 0.5;

                return uv;
            }
            
            half hash12(half2 p)
            {
                half3 p3  = frac(half3(p.x, p.y, p.x) * MOD3);
                p3 += dot(p3, p3.yzx + 19.19);
                return frac((p3.x + p3.y) * p3.z);
            }

            half2 hash22(half2 p)
            {
                half3 p3 = frac(half3(p.x, p.y, p.x) * MOD3);
                p3 += dot(p3, p3.yzx + 19.19);
                return frac(half2((p3.x + p3.y)*p3.z, (p3.x + p3.z)*p3.y));
            }

            float4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv;

                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
                float3 posVS = ComputeViewSpacePosition(uv, rawDepth);
                float3 normalVS = GetViewSpaceNormal(uv);

                float2 noiseUV = uv * _NoiseScale;
                float2 rand = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).rg * 2.0 - 1.0;
                // half2 rand = normalize(hash22(uv * 100.0) * 200.0 - 1.0);
                float2x2 rot = float2x2(rand.x, -rand.y, rand.y, rand.x);

                float occlusion = 0.0;
                // float2 dir = float2(0.0, _Radius);
                float2 dir = float2(_MinRadius, _Radius);

                for (int s = 0; s < _SampleCount; s++)
                {
                    float2 sampleUV = uv + dir;
                    float sampleDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, sampleUV).r;
                    float3 sampleVS = ComputeViewSpacePosition(sampleUV, sampleDepth);

                    float3 v = sampleVS - posVS;
                    float dist = length(v);
                    float3 vDir = v / (dist + 1e-5);

                    float NdotD = saturate(dot(normalVS, vDir));

                    occlusion += step(sampleVS.z, posVS.z - _Bias) * NdotD;

                    dir = mul(rot, dir);
                }

                occlusion = 1.0 - (occlusion / _SampleCount) * _Intensity;
                return float4(occlusion.xxx, 1.0);
                
                occlusion = (1 - occlusion) * (1 - saturate(SAMPLE_TEXTURE2D(_PatternTexture, sampler_PatternTexture, RotateUV(i.uv, _PatternRotate) * _PatternRepetition).r * _PatternIntensity));
                occlusion = 1 - occlusion * _Intensity2;

                half3 blit = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv).rgb;
                return half4(blit.r * occlusion, blit.g * occlusion, blit.b * occlusion, 1.0);
            }
            ENDHLSL
        }
    }
}