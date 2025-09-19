// Parallax Mapping sin textura, con height procedural
void ParallaxProcedural_float(
    float2 UV,            // Coordenadas base
    float3 ViewDirTS,     // Dirección de vista en Tangent Space (normalizado)
    float Height,         // Valor de altura (procedural noise, 0-1)
    float HeightScale,    // Escala del parallax
    out float2 OutUV      // UV desplazadas
)
{
    // Tomamos la componente Z de la vista para escalar el desplazamiento
    float viewZ = max(ViewDirTS.z, 0.001);

    // Offset en las UV basado en la altura
    float2 offset = (Height * HeightScale) * (ViewDirTS.xy / viewZ);

    OutUV = UV - offset;
}
