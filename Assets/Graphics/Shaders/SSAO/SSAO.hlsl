void mainImage_float(
    float count, // COUNT en Shadertoy
    float farclip, // FARCLIP en Shadertoy
    float bias, // BIAS en Shadertoy
    float2 resolution, // iResolution.xy
    float2 fragCoord, // posición en pixeles
    Texture2D<float4> iChannel0, SamplerState iChannel0_sampler,
    Texture2D<float4> iChannel1, SamplerState iChannel1_sampler,
    out float3 fragColor)
{
    float2 uv = fragCoord / resolution;
    float4 norz = SAMPLE_TEXTURE2D(iChannel0, iChannel0_sampler, uv);
    float depth = norz.w * farclip;
    float radius = 0.1;
    float scale = radius / depth;
    
    float ao = 0.0;
    for (int i = 0; i < count; i++)
    {
        float2 randUv = (fragCoord + 23.71 * float(i)) / resolution;
        float3 randNor = SAMPLE_TEXTURE2D(iChannel1, iChannel1_sampler, randUv).xyz * 2.0 - 1.0;
        if (dot(norz.xyz, randNor) < 0.0)
            randNor *= -1.0;
        
        float2 off = randNor.xy * scale;
        float4 sampleNorz = SAMPLE_TEXTURE2D(iChannel0, iChannel0_sampler, uv + off);
        float depthDelta = depth - sampleNorz.w * farclip;
        
        float3 sampleDir = float3(randNor.xy * radius, depthDelta);
        float occ = max(0.0, dot(normalize(norz.xyz), normalize(sampleDir)) - bias) / (length(sampleDir) + 1.0);
        ao += 1.0 - occ;
    }
    ao /= count;
    
    fragColor = float3(ao, ao, ao);
}
