Shader "Custom/SSAO"
{
    Properties
    {
        _PatternTexture("Pattern Texture", 2D) = "black"
        _PatternIntensity("Pattern Intensity", Float) = 1
        _PatternRepetition("Pattern Repetition", Float) = 1
        _PatternRotate("Pattern Rotate", Float) = 0
        _NoiseTexture("Noise Texture", 2D) = "white"
        _Intensity("Intensity", Float) = 1
        _Intensity2("Intensity2", Float) = 1
        _Samples("Samples", Int) = 8
        _Offset("Offset", Float) = 16
        _Limit("Limit", Float) = 0
        _LimitPasses("Limit Passes", Float) = 0.25
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
            
            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

			TEXTURE2D(_NoiseTexture);
			SAMPLER(sampler_NoiseTexture);

			TEXTURE2D(_PatternTexture);
			SAMPLER(sampler_PatternTexture);
            
			half _Intensity;
			half _Intensity2;
            int _Samples;
			half _Offset;
			half _Limit;
			half _LimitPasses;
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

            float remap(float value, float minOld, float maxOld, float minNew, float maxNew)
            {
                return (value - minOld) / (maxOld - minOld) * (maxNew - minNew) + minNew;
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

            half4 frag(v2f i) : SV_Target
            {
                half2 fragCoord = i.uv * _ScreenParams.xy;

                half zr = 1.0 - SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv).r;

	            half ao = 0.0;
                [Unroll]
                for (int j = 0; j < _Samples; j++)
	            {
                    half2 noiseUV = (fragCoord + 23.71 * j) / _ScreenParams.xy;
                    half2 off = -1.0 + 2.0 * SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, noiseUV).rg;

                    half2 neighborUV = (fragCoord + floor(off * _Offset)) / _ScreenParams.xy;

                    half z = 1.0 - SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, neighborUV).r;

                    ao += clamp((zr - z) / 0.1, 0.0, 1.0);
                }
                ao *= _LimitPasses;
                [Unroll]
                for (int j = 0; j < _Samples; j++)
	            {
                    half2 noiseUV = (fragCoord + 23.71 * j) / _ScreenParams.xy;
                    half2 off = -1.0 + 2.0 * SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, noiseUV).rg;
                    off.x = -off.x;

                    half2 neighborUV = (fragCoord + floor(off * _Offset)) / _ScreenParams.xy;

                    half z = 1.0 - SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, neighborUV).r;

                    ao += clamp((zr - z) / 0.1, 0.0, 1.0);
                }
                ao *= _LimitPasses;
                [Unroll]
                for (int j = 0; j < _Samples; j++)
	            {
                    half2 noiseUV = (fragCoord + 23.71 * j) / _ScreenParams.xy;
                    half2 off = -1.0 + 2.0 * SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, noiseUV).rg;
					off.y = -off.y;

                    half2 neighborUV = (fragCoord + floor(off * _Offset)) / _ScreenParams.xy;

                    half z = 1.0 - SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, neighborUV).r;

                    ao += clamp((zr - z) / 0.1, 0.0, 1.0);
                }
                ao *= _LimitPasses;
                [Unroll]
                for (int j = 0; j < _Samples; j++)
	            {
                    half2 noiseUV = (fragCoord + 23.71 * j) / _ScreenParams.xy;
                    half2 off = -1.0 + 2.0 * SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, noiseUV).rg;
					off.x = -off.x;
					off.y = -off.y;

                    half2 neighborUV = (fragCoord + floor(off * _Offset)) / _ScreenParams.xy;

                    half z = 1.0 - SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, neighborUV).r;

                    ao += clamp((zr - z) / 0.1, 0.0, 1.0);
                }
                ao *= _LimitPasses;

                half depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv).r * 10000;
                depth = 1 - saturate(clamp(LinearEyeDepth(depth, _ZBufferParams), 0.0, 1.0));
                // return half4(depth, depth, depth, 1.0);
                
                ao *= depth;
                ao = clamp(1.0 - ao * _Intensity, _Limit, 1.0);
                ao = remap(ao, _Limit, 1, 0, 1);

                ao = (1 - ao) * (1 - saturate(SAMPLE_TEXTURE2D(_PatternTexture, sampler_PatternTexture, RotateUV(i.uv, _PatternRotate) * _PatternRepetition).r * _PatternIntensity));
                ao = 1 - ao * _Intensity2;

                half3 blit = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv).rgb;
                
                // return half4(ao, ao, ao, 1.0);
                return half4(blit.r * ao, blit.g * ao, blit.b * ao, 1.0);
                // return half4(blit.r, blit.g, blit.b, 1.0);
            }
            ENDHLSL
        }
    }
}