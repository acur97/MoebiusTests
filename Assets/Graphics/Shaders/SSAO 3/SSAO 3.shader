Shader "Custom/SSAO 3"
{
    Properties
    {
        _SAMPLES("_SAMPLES", Int) = 16
        _INTENSITY("_INTENSITY", Float) = 1
        _SCALE("_SCALE", Float) = 2.5
        _BIAS("_BIAS", Float) = 0.05
        _SAMPLE_RAD("_SAMPLE_RAD", Float) = 0.02
        _MAX_DISTANCE("_MAX_DISTANCE", Float) = 0.07
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

            #define MOD3 float3(0.1031, 0.11369, 0.13787)

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE2D(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);

            int _SAMPLES;
            float _INTENSITY;
            float _SCALE;
            float _BIAS;
            float _SAMPLE_RAD;
            float _MAX_DISTANCE;

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

            float hash12(float2 p)
            {
                float3 p3  = frac(float3(p.x, p.y, p.x) * MOD3);
                p3 += dot(p3, p3.yzx + 19.19);
                return frac((p3.x + p3.y) * p3.z);
            }

            float2 hash22(float2 p)
            {
                float3 p3 = frac(float3(p.x, p.y, p.x) * MOD3);
                p3 += dot(p3, p3.yzx + 19.19);
                return frac(float2((p3.x + p3.y)*p3.z, (p3.x + p3.z)*p3.y));
            }

            float3 GetViewPos(float2 uv)
            {
                float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
                // depth = LinearEyeDepth(depth, _ZBufferParams);
                float3 viewPos = ComputeViewSpacePosition(uv, depth, unity_CameraInvProjection);
                return viewPos;
            }

            float3 GetNormal(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv).xyz * 2.0 - 1.0;
            }

            float doAmbientOcclusion(float2 baseUv, float2 offset, float3 p, float3 cnorm)
            {
                float3 diff = GetViewPos(baseUv + offset) - p;
                float l = length(diff);
                float3 v = diff / l;
                float d = l * _SCALE;
                float ao = max(0.0, dot(cnorm, v) - _BIAS) * (1.0 / (1.0 + d));
                ao *= smoothstep(_MAX_DISTANCE, _MAX_DISTANCE * 0.5, l);
                return ao;
            }

            float spiralAO(float2 uv, float3 p, float3 n, float rad)
            {
                float goldenAngle = 2.4;
                float ao = 0.0;
                float inv = 1.0 / _SAMPLES;
                float radius = 0.0;

                float rotatePhase = hash12(uv * 100.0) * 6.2831853;
                float rStep = inv * rad;
                float2 spiralUV;

                [Unroll]
                for (int i = 0; i < _SAMPLES; i++)
                {
                    spiralUV.x = sin(rotatePhase);
                    spiralUV.y = cos(rotatePhase);
                    radius += rStep;
                    ao += doAmbientOcclusion(uv, spiralUV * radius, p, n);
                    rotatePhase += goldenAngle;
                }
                return ao * inv;
            }

            half4 frag(v2f i) : SV_Target
            {
                float2 uv = i.uv;
                float3 p = GetViewPos(uv);
                float3 n = normalize(GetNormal(uv));

                float rad = _SAMPLE_RAD / max(p.z, 0.0001);
                float ao = spiralAO(uv, p, n, rad);
                ao = 1.0 - ao * _INTENSITY;
                ao = 1 - ao;

                return float4(ao, ao, ao, 1.0);
            }
            ENDHLSL
        }
    }
}