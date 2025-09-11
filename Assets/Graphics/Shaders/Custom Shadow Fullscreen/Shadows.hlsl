#ifndef CUSTOM_SCREENSPACE_SHADOW_INCLUDED
#define CUSTOM_SCREENSPACE_SHADOW_INCLUDED

void SampleScreenSpaceShadow_half(half2 uv, out half shadow)
{
    #if defined(SHADERGRAPH_PREVIEW)
            shadow = 1.0;
    #else
        shadow = SAMPLE_TEXTURE2D(_ScreenSpaceShadowmapTexture, sampler_ScreenSpaceShadowmapTexture, uv).r;
    #endif
}

#endif
