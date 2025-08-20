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

            #define MOD3 half3(0.1031, 0.11369, 0.13787)

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE2D(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);

            int _SAMPLES;
            half _INTENSITY;
            half _SCALE;
            half _BIAS;
            half _SAMPLE_RAD;
            half _MAX_DISTANCE;

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

            half3 GetViewPos(half2 uv)
            {
                half depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
                // depth = LinearEyeDepth(depth, _ZBufferParams);
                half3 viewPos = ComputeViewSpacePosition(uv, depth, unity_CameraInvProjection);
                return viewPos;
            }

            half3 GetNormal(half2 uv)
            {
                return SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv).xyz * 2.0 - 1.0;
            }

            half doAmbientOcclusion(half2 baseUv, half2 offset, half3 p, half3 cnorm)
            {
                half3 diff = GetViewPos(baseUv + offset) - p;
                half l = length(diff);
                half3 v = diff / l;
                half d = l * _SCALE;
                half ao = max(0.0, dot(cnorm, v) - _BIAS) * (1.0 / (1.0 + d));
                ao *= smoothstep(_MAX_DISTANCE, _MAX_DISTANCE * 0.5, l);
                return ao;
            }

            half spiralAO(half2 uv, half3 p, half3 n, half rad)
            {
                half goldenAngle = 2.4;
                half ao = 0.0;
                half inv = 1.0 / _SAMPLES;
                half radius = 0.0;

                half rotatePhase = hash12(uv * 100.0) * 6.2831853;
                half rStep = inv * rad;
                half2 spiralUV;

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
                half2 uv = i.uv;
                half3 p = GetViewPos(uv);
                half3 n = normalize(GetNormal(uv));

                half rad = _SAMPLE_RAD / max(p.z, 0.0001);
                half ao = spiralAO(uv, p, n, rad);
                ao = 1.0 - ao * _INTENSITY;
                ao = 1 - ao;

                return half4(ao, ao, ao, 1.0);
            }
            ENDHLSL
        }
    }
}