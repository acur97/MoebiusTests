Shader "Custom/SSAO 2"
{
    Properties
    {
        _NoiseTexture("Noise Texture", 2D) = "white"
        _Samples ("Samples", Int) = 8
        _Radius ("AO Radius", Float) = 0.1
        _Bias ("AO Bias", Float) = 0.01
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
            
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            TEXTURE2D(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);

            TEXTURE2D(_NoiseTexture);
            SAMPLER(sampler_NoiseTexture);

            int _Samples;
			float _Radius;
			float _Bias;

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

            float GetLinearDepth(float2 uv)
            {
                float depth01 = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
                return LinearEyeDepth(depth01, _ZBufferParams);
            }

            half4 frag(v2f i) : SV_Target
            {
                // Near & far
                float farClip = _ProjectionParams.z;

                // Normals (view space)
                float3 normalVS = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.uv).xyz * 2.0 - 1.0;
                normalVS = normalize(normalVS);

                // Depth
                float depth = GetLinearDepth(i.uv);

                float scale = _Radius / depth;

                float ao = 0.0;

                [Unroll] for (int j = 0; j < _Samples; j++)
                {
                    // Random normal
                    float2 noiseUV = (i.uv * _ScreenParams.xy + 23.71 * j) / _ScreenParams.xy;
                    float3 randNor = SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, noiseUV).xyz * 2.0 - 1.0;

                    if (dot(normalVS, randNor) < 0.0)
                    {
						randNor *= -1.0;
                    }

                    float2 off = randNor.xy * scale;
                    float2 sampleUV = i.uv + off;

                    // Sample normals and depth
                    float3 sampleNormalVS = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, sampleUV).xyz * 2.0 - 1.0;
                    sampleNormalVS = normalize(sampleNormalVS);

                    float sampleDepth = GetLinearDepth(sampleUV);
                    float depthDelta = depth - sampleDepth;

                    float3 sampleDir = float3(randNor.xy * _Radius, depthDelta);

                    float occ = max(0.0, dot(normalVS, normalize(sampleDir)) - _Bias) / (length(sampleDir) + 1.0);

                    ao += 1.0 - occ;
                }

                ao /= _Samples;
                ao = 1 - ao;

                return half4(ao, ao, ao, 1.0);
            }
            ENDHLSL
        }
    }
}