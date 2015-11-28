#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"

#ifdef COMPILEVS

struct VS_INPUT
{
    float4 iPos : POSITION;
};

struct VS_OUTPUT
{
#ifdef DIRLIGHT
    float2 oScreenPos : TEXCOORD0;
#else
    float4 oScreenPos : TEXCOORD0;
#endif
    float3 oFarRay : TEXCOORD1;
#ifdef ORTHO
    float3 oNearRay : TEXCOORD2;
#endif
    float4 oPos : OUTPOSITION;
};

VS_OUTPUT VS(VS_INPUT IN)
{
    VS_OUTPUT OUT;
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    OUT.oPos = GetClipPos(worldPos);
    #ifdef DIRLIGHT
        OUT.oScreenPos = GetScreenPosPreDiv(OUT.oPos);
        OUT.oFarRay = GetFarRay(OUT.oPos);
        #ifdef ORTHO
            OUT.oNearRay = GetNearRay(OUT.oPos);
        #endif
    #else
        OUT.oScreenPos = GetScreenPos(OUT.oPos);
        OUT.oFarRay = GetFarRay(OUT.oPos) * OUT.oPos.w;
        #ifdef ORTHO
            OUT.oNearRay = GetNearRay(OUT.oPos) * OUT.oPos.w;
        #endif
    #endif
    return OUT;
}

#endif

#ifdef COMPILEPS

struct PS_INPUT
{
#ifdef DIRLIGHT
    float2 iScreenPos : TEXCOORD0;
#else
    float4 iScreenPos : TEXCOORD0;
#endif
    float3 iFarRay : TEXCOORD1;
#ifdef ORTHO
    float3 iNearRay : TEXCOORD2;
#endif
};

struct PS_OUTPUT
{
    float4 oColor : OUTCOLOR0;
};

PS_OUTPUT PS(PS_INPUT IN)
{
    PS_OUTPUT OUT;
    // If rendering a directional light quad, optimize out the w divide
    #ifdef DIRLIGHT
        float depth = Sample2DLod0(DepthBuffer, IN.iScreenPos).r;
        #ifdef HWDEPTH
            depth = ReconstructDepth(depth);
        #endif
        #ifdef ORTHO
            float3 worldPos = lerp(IN.iNearRay, IN.iFarRay, depth);
        #else
            float3 worldPos = IN.iFarRay * depth;
        #endif
            float4 normalInput = Sample2DLod0(NormalBuffer, IN.iScreenPos);
    #else
        float depth = Sample2DProj(DepthBuffer, IN.iScreenPos).r;
        #ifdef HWDEPTH
            depth = ReconstructDepth(depth);
        #endif
        #ifdef ORTHO
            float3 worldPos = lerp(IN.iNearRay, IN.iFarRay, depth) / IN.iScreenPos.w;
        #else
            float3 worldPos = IN.iFarRay * depth / IN.iScreenPos.w;
        #endif
        float4 normalInput = Sample2DProj(NormalBuffer, IN.iScreenPos);
    #endif

    float3 normal = normalize(normalInput.rgb * 2.0 - 1.0);
    float4 projWorldPos = float4(worldPos, 1.0);
    float3 lightColor;
    float3 lightDir;

    // Accumulate light at half intensity to allow 2x "overburn"
    float diff = 0.5 * GetDiffuse(normal, worldPos, lightDir);

    #ifdef SHADOW
        diff *= GetShadowDeferred(projWorldPos, depth);
    #endif

    #if defined(SPOTLIGHT)
        float4 spotPos = mul(projWorldPos, cLightMatricesPS[0]);
        lightColor = spotPos.w > 0.0 ? Sample2DProj(LightSpotMap, spotPos).rgb * cLightColor.rgb : 0.0;
    #elif defined(CUBEMASK)
        lightColor = texCUBE(sLightCubeMap, mul(worldPos - cLightPosPS.xyz, (float3x3)cLightMatricesPS[0])).rgb * cLightColor.rgb;
    #else
        lightColor = cLightColor.rgb;
    #endif

    #ifdef SPECULAR
        float spec = lightColor.g * GetSpecular(normal, -worldPos, lightDir, normalInput.a * 255.0);
        OUT.oColor = diff * float4(lightColor, spec * cLightColor.a);
    #else
        OUT.oColor = diff * float4(lightColor, 0.0);
    #endif

    return OUT;
}
#endif
