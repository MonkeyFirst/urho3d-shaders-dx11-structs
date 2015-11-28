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
    float2 oScreenPos : TEXCOORD0;
    float4 oPos : OUTPOSITION;
};

VS_OUTPUT VS(VS_INPUT IN)
{
    VS_OUTPUT OUT;
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    OUT.oPos = GetClipPos(worldPos);
    OUT.oScreenPos = GetScreenPosPreDiv(OUT.oPos);
    return OUT;
}

#endif

#ifdef COMPILEPS

struct PS_INPUT
{
    float2 iScreenPos : TEXCOORD0;
};

struct PS_OUTPUT
{
    float4 oColor : OUTCOLOR0;
};

PS_OUTPUT PS(PS_INPUT IN)
{
    PS_OUTPUT OUT;
    float3 rgb = Sample2D(DiffMap, IN.iScreenPos).rgb;
    float intensity = GetIntensity(rgb);
    OUT.oColor = float4(intensity, intensity, intensity, 1.0);
    return OUT;
}

#endif
