Shader "Custom/SSAO"
{
    Properties
    {
        _NoiseTexture("Noise Texture", 2D) = "white"
        _Samples("Samples", Int) = 8
        _Offset("Offset", Float) = 16
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

			TEXTURE2D(_NoiseTexture);
			SAMPLER(sampler_NoiseTexture);

            int _Samples;
			float _Offset;

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

            half4 frag(v2f i) : SV_Target
            {
                // Convert normalized UV to pixel coords
                float2 fragCoord = i.uv * _ScreenParams.xy;

                // Sample depth at current pixel
                float zr = 1.0 - SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv).r;

                // sample neighbor pixels
	            float ao = 0.0;
                [Unroll] for (int j = 0; j < _Samples; j++)
	            {
                    // Get random offset from noise texture
                    float2 noiseUV = (fragCoord + 23.71 * j) / _ScreenParams.xy;
                    float2 off = -1.0 + 2.0 * SAMPLE_TEXTURE2D(_NoiseTexture, sampler_NoiseTexture, noiseUV).rg;

                    // Offset by ~16px radius in screen space
                    float2 neighborUV = (fragCoord + floor(off * _Offset)) / _ScreenParams.xy;

                    // Sample neighbor depth
                    float z = 1.0 - SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, neighborUV).r;

                    // Accumulate occlusion
                    ao += clamp((zr - z) / 0.1, 0.0, 1.0);
                }

                // average down the occlusion	
                ao = clamp(1.0 - ao / _Samples, 0.0, 1.0);
	
	            float3 col = float3(ao, ao, ao);

                return float4(col.r, col.g, col.b, 1.0);
            }
            ENDHLSL
        }
    }
}