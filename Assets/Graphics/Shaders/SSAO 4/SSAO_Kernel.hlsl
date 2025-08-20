#ifndef SSAO_KERNEL_INCLUDED
#define SSAO_KERNEL_INCLUDED

// Número máximo de muestras del kernel
#define SSAO_KERNEL_SIZE 16

// Kernel de direcciones predefinidas en un hemisferio
// Distribuidas dentro de la semiesfera + escalado progresivo
static const float3 SSAO_Kernel[SSAO_KERNEL_SIZE] =
{
    float3(0.5381, 0.1856, 0.4319),
    float3(0.1379, 0.2486, 0.4430),
    float3(0.3371, 0.5679, 0.0057),
    float3(0.7250, 0.0466, 0.4780),
    float3(0.2451, 0.2451, 0.8010),
    float3(0.3320, 0.7302, 0.5940),
    float3(0.5852, 0.4334, 0.6870),
    float3(0.1305, 0.9566, 0.2730),
    float3(0.1029, 0.2709, 0.9160),
    float3(0.5379, 0.8230, 0.1790),
    float3(0.7180, 0.6680, 0.2040),
    float3(0.4090, 0.5520, 0.7240),
    float3(0.7750, 0.4210, 0.4700),
    float3(0.4600, 0.6900, 0.5600),
    float3(0.2500, 0.3300, 0.9100),
    float3(0.6200, 0.2100, 0.7500)
};

// Ruido en 2D para orientar el kernel
// Se repite en mosaico sobre la pantalla
#define SSAO_NOISE_SIZE 16
static const float2 SSAO_Noise[SSAO_NOISE_SIZE] =
{
    float2(1.0, 0.0), float2(-1.0, 0.0),
    float2(0.0, 1.0), float2(0.0, -1.0),
    float2(0.707, 0.707), float2(-0.707, 0.707),
    float2(0.707, -0.707), float2(-0.707, -0.707),
    float2(0.923, 0.382), float2(-0.923, 0.382),
    float2(0.382, 0.923), float2(-0.382, 0.923),
    float2(0.923, -0.382), float2(-0.923, -0.382),
    float2(0.382, -0.923), float2(-0.382, -0.923)
};

// Función helper para obtener ruido 2D en base a la UV del pixel
float2 GetSSAONoise(float2 uv, float2 screenSize)
{
    // Escala para que el ruido se repita en mosaico
    int xi = (int) (uv.x * screenSize.x) % 4;
    int yi = (int) (uv.y * screenSize.y) % 4;
    int idx = (yi * 4 + xi) % SSAO_NOISE_SIZE;
    return SSAO_Noise[idx];
}

#endif // SSAO_KERNEL_INCLUDED
