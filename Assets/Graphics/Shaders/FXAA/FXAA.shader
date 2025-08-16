Shader "Unlit/FXAA"
{
    Properties
    {
        _EdgeThreshold ("Edge Detection Threshold", Range(0.01, 0.5)) = 0.1
        _BlendAmount ("Blend Strength", Range(0.0, 1.0)) = 0.75
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Overlay" }
        Pass
        {
            Name "FXAA"
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);

            float _EdgeThreshold;
            float _BlendAmount;

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
                float2 texelSize = rcp(_ScreenParams.xy);

                float3 colCenter = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv).rgb;
                float3 colLeft   = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv + float2(-texelSize.x, 0)).rgb;
                float3 colRight  = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv + float2(texelSize.x, 0)).rgb;
                float3 colUp     = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv + float2(0, texelSize.y)).rgb;
                float3 colDown   = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv + float2(0, -texelSize.y)).rgb;

                float lumCenter = dot(colCenter, float3(0.299, 0.587, 0.114));
                float lumLeft   = dot(colLeft, float3(0.299, 0.587, 0.114));
                float lumRight  = dot(colRight, float3(0.299, 0.587, 0.114));
                float lumUp     = dot(colUp, float3(0.299, 0.587, 0.114));
                float lumDown   = dot(colDown, float3(0.299, 0.587, 0.114));

                float edgeDetect = max(max(abs(lumCenter - lumLeft), abs(lumCenter - lumRight)),
                                       max(abs(lumCenter - lumUp), abs(lumCenter - lumDown)));

                float blendFactor = smoothstep(_EdgeThreshold * 0.5, _EdgeThreshold, edgeDetect) * _BlendAmount;

                float3 smoothedColor = (colLeft + colRight + colUp + colDown) * 0.25;

                float3 finalColor = lerp(colCenter, smoothedColor, blendFactor);

                return float4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}