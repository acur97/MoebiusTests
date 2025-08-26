Shader "Custom/SSAO 4"
{
    Properties
    {
        _Blend("Blend", Range(0, 1)) = 1
        _Color ("Main Color", Color) = (1,1,1,1)

        _Radius("Radius", Range(0, 0.001)) = 0.2
        _MinRadius("Min Radius", Range(0, 0.0001)) = 8.0
        _Bias("Bias", Range(0, 0.001)) = 0.05
        _Intensity("Intensity", Float) = 1.0
        _Intensity2("Intensity2", Float) = 1.0
        _SampleCount("Sample Count", Range(1, 17)) = 16
        _NoiseScale("Noise Scale", Float) = 8.0
        _NoiseScale2("Noise Scale2", Float) = 100
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
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

            #define MOD3 half3(0.1031, 0.11369, 0.13787)

            half _Radius;
            half _MinRadius;
            half _Bias;
            half _Intensity;
            half _Intensity2;
            int _SampleCount;
            half _NoiseScale;
            half _NoiseScale2;
            half4 _Color;
            half _Blend;

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

            half3 ComputeViewSpacePosition(half2 uv, half rawDepth)
            {
                half2 ndc = uv * 2.0 - 1.0;
                half4 clipPos = half4(ndc, rawDepth, 1.0);
                half4 viewPos = mul(unity_CameraInvProjection, clipPos);
                return viewPos.xyz / viewPos.w;
            }

            half3 GetViewSpaceNormal(half2 uv)
            {
                half4 enc = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv);
                return normalize(enc.xyz * 2.0 - 1.0);
            }

            half2 RotateUV(half2 uv, half angleDeg)
            {
                half angle = radians(angleDeg); // convertir a radianes
                half s = sin(angle);
                half c = cos(angle);

                // trasladar al centro (0.5,0.5)
                uv -= 0.5;

                // rotar
                half2x2 rot = half2x2(c, -s, s, c);
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

            half2 hash22_smooth(half2 p)
            {
                const half2 k = half2(0.3183099, 0.3678794); // 1/PI , 1/E
                p = p * k + k.yx;
                return frac(16.0 * k * frac(p.x * p.y * (p.x + p.y)));
            }

            half2 hash22_perlin(half2 p)
            {
                half2 f = frac(p * half2(5.3983, 5.4427));
                f += dot(f, f + 19.19);
                return frac(half2((f.x + f.y) * f.x, (f.x + f.y) * f.y));
            }

            // Burn
            half4 BlendBurn(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = 1.0 - (1.0 - Blend) / Base;
                return lerp(Base, Out, Opacity);
            }

            // Darken
            half4 BlendDarken(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = min(Blend, Base);
                return lerp(Base, Out, Opacity);
            }

            // Difference
            half4 BlendDifference(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = abs(Blend - Base);
                return lerp(Base, Out, Opacity);
            }

            // Dodge
            half4 BlendDodge(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = Base / (1.0 - Blend);
                return lerp(Base, Out, Opacity);
            }

            // Divide
            half4 BlendDivide(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = Base / (Blend + 1e-10);
                return lerp(Base, Out, Opacity);
            }

            // Exclusion
            half4 BlendExclusion(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = Blend + Base - (2.0 * Blend * Base);
                return lerp(Base, Out, Opacity);
            }

            // HardLight
            half4 BlendHardLight(half4 Base, half4 Blend, half Opacity)
            {
                half4 result1 = 1.0 - 2.0 * (1.0 - Base) * (1.0 - Blend);
                half4 result2 = 2.0 * Base * Blend;
                half4 zeroOrOne = step(Blend, 0.5);
                half4 Out = result2 * zeroOrOne + (1 - zeroOrOne) * result1;
                return lerp(Base, Out, Opacity);
            }

            // HardMix
            half4 BlendHardMix(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = step(1 - Base, Blend);
                return lerp(Base, Out, Opacity);
            }

            // Lighten
            half4 BlendLighten(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = max(Blend, Base);
                return lerp(Base, Out, Opacity);
            }

            // LinearBurn
            half4 BlendLinearBurn(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = Base + Blend - 1.0;
                return lerp(Base, Out, Opacity);
            }

            // LinearDodge
            half4 BlendLinearDodge(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = Base + Blend;
                return lerp(Base, Out, Opacity);
            }

            // LinearLight
            half4 BlendLinearLight(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = (Blend < 0.5) ? max(Base + (2 * Blend) - 1, 0) : min(Base + 2 * (Blend - 0.5), 1);
                return lerp(Base, Out, Opacity);
            }

            // LinearLight Add/Sub
            half4 BlendLinearLightAddSub(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = Blend + 2.0 * Base - 1.0;
                return lerp(Base, Out, Opacity);
            }

            // Multiply
            half4 BlendMultiply(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = Base * Blend;
                return lerp(Base, Out, Opacity);
            }

            // Negation
            half4 BlendNegation(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = 1.0 - abs(1.0 - Blend - Base);
                return lerp(Base, Out, Opacity);
            }

            // Overlay
            half4 BlendOverlay(half4 Base, half4 Blend, half Opacity)
            {
                half4 result1 = 1.0 - 2.0 * (1.0 - Base) * (1.0 - Blend);
                half4 result2 = 2.0 * Base * Blend;
                half4 zeroOrOne = step(Base, 0.5);
                half4 Out = result2 * zeroOrOne + (1 - zeroOrOne) * result1;
                return lerp(Base, Out, Opacity);
            }

            // PinLight
            half4 BlendPinLight(half4 Base, half4 Blend, half Opacity)
            {
                half4 check = step(0.5, Blend);
                half4 result1 = check * max(2.0 * (Base - 0.5), Blend);
                half4 Out = result1 + (1.0 - check) * min(2.0 * Base, Blend);
                return lerp(Base, Out, Opacity);
            }

            // Screen
            half4 BlendScreen(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = 1.0 - (1.0 - Blend) * (1.0 - Base);
                return lerp(Base, Out, Opacity);
            }

            // SoftLight
            half4 BlendSoftLight(half4 Base, half4 Blend, half Opacity)
            {
                half4 result1 = 2.0 * Base * Blend + Base * Base * (1.0 - 2.0 * Blend);
                half4 result2 = sqrt(Base) * (2.0 * Blend - 1.0) + 2.0 * Base * (1.0 - Blend);
                half4 zeroOrOne = step(0.5, Blend);
                half4 Out = result2 * zeroOrOne + (1 - zeroOrOne) * result1;
                return lerp(Base, Out, Opacity);
            }

            // Subtract
            half4 BlendSubtract(half4 Base, half4 Blend, half Opacity)
            {
                half4 Out = Base - Blend;
                return lerp(Base, Out, Opacity);
            }

            // VividLight
            half4 BlendVividLight(half4 Base, half4 Blend, half Opacity)
            {
                half4 result1 = 1.0 - (1.0 - Blend) / (2.0 * Base);
                half4 result2 = Blend / (2.0 * (1.0 - Base));
                half4 zeroOrOne = step(0.5, Base);
                half4 Out = result2 * zeroOrOne + (1 - zeroOrOne) * result1;
                return lerp(Base, Out, Opacity);
            }

            // Overwrite
            half4 BlendOverwrite(half4 Base, half4 Blend, half Opacity)
            {
                return lerp(Base, Blend, Opacity);
            }

            half4 frag(v2f i) : SV_Target
            {
                half2 uv = i.uv;

                half rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
                half3 posVS = ComputeViewSpacePosition(uv, rawDepth);
                half3 normalVS = GetViewSpaceNormal(uv);

                half2 noiseUV = uv * _NoiseScale;
                // half2 rand = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).rg * 2.0 - 1.0;
                // half2 rand = normalize(hash22(uv * 100.0) * 200.0 - 1.0);
                half2 rand = hash12(uv * _NoiseScale2) * 6.2831853;
                half2x2 rot = half2x2(rand.x, -rand.y, rand.y, rand.x);

                half occlusion = 0.0;
                // half2 dir = half2(0.0, _Radius);
                half2 dir = half2(_MinRadius, _Radius);

                for (int s = 0; s < _SampleCount; s++)
                {
                    half2 sampleUV = uv + dir;
                    half sampleDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, sampleUV).r;
                    half3 sampleVS = ComputeViewSpacePosition(sampleUV, sampleDepth);

                    half3 v = sampleVS - posVS;
                    half dist = length(v);
                    half3 vDir = v / (dist + 1e-5);

                    half NdotD = saturate(dot(normalVS, vDir));

                    occlusion += step(sampleVS.z, posVS.z - _Bias) * NdotD;

                    dir = mul(rot, dir);
                }
                
                occlusion = 1 - (occlusion / _SampleCount) * _Intensity;
                // occlusion = (occlusion / _SampleCount) * _Intensity;
                return half4(occlusion.xxx, 1.0);
                
                occlusion = (1 - occlusion) * (1 - saturate(SAMPLE_TEXTURE2D(_PatternTexture, sampler_PatternTexture, RotateUV(i.uv, _PatternRotate) * _PatternRepetition).r * _PatternIntensity));
                // occlusion = 1 - occlusion * _Intensity2;
                occlusion = occlusion * _Intensity2;

                // half4 final = half4(occlusion * _Color.r, occlusion * _Color.g, occlusion * _Color.b, 1.0);
                // return half4(final);

                half4 blit = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv);
                // return half4(blit.r * occlusion, blit.g * occlusion, blit.b * occlusion, 1.0);
                // return half4(blit.r + final.r, blit.g + final.g, blit.b + final.b, 1.0);
                // return BlendScreen(blit, final, _Blend);

                // return half4((occlusion.xxx * _Color.rgb), 1.0);
                
                half4 end = lerp(SRGBToLinear(blit), _Color, occlusion);
                // half4 end = lerp(0, _Color, occlusion);
                return LinearToSRGB(end);
            }
            ENDHLSL
        }
    }
}