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
			half _Radius;
			half _Bias;

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

            half GetLinearDepth(half2 uv)
            {
                half depth01 = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
                return LinearEyeDepth(depth01, _ZBufferParams);
            }

            half4 frag(v2f i) : SV_Target
            {
                half farClip = _ProjectionParams.z;

                half3 normalVS = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.uv).xyz * 2.0 - 1.0;
                normalVS = normalize(normalVS);

                half depth = GetLinearDepth(i.uv);
                half scale = _Radius / depth;

                half ao = 0.0;

                [Unroll]
                for (int j = 0; j < _Samples; j++)
                {
                    half2 noiseUV = (i.uv * _ScreenParams.xy + 23.71 * j) / _ScreenParams.xy;
                    half3 randNor = SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, noiseUV).xyz * 2.0 - 1.0;

                    if (dot(normalVS, randNor) < 0.0)
                    {
						randNor *= -1.0;
                    }

                    half2 off = randNor.xy * scale;
                    half2 sampleUV = i.uv + off;

                    half3 sampleNormalVS = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, sampleUV).xyz * 2.0 - 1.0;
                    sampleNormalVS = normalize(sampleNormalVS);

                    half sampleDepth = GetLinearDepth(sampleUV);
                    half depthDelta = depth - sampleDepth;

                    half3 sampleDir = half3(randNor.xy * _Radius, depthDelta);

                    half occ = max(0.0, dot(normalVS, normalize(sampleDir)) - _Bias) / (length(sampleDir) + 1.0);

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