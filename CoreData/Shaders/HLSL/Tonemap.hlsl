#include "Uniforms.hlsl"
#include "Transform.hlsl"
#include "Samplers.hlsl"
#include "ScreenPos.hlsl"
#include "PostProcess.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float cTonemapExposureBias;
uniform float cTonemapMaxWhite;

#else

#ifdef COMPILEPS
// D3D11 constant buffers
cbuffer CustomPS : register(b6)
{
    float cTonemapExposureBias;
    float cTonemapMaxWhite;
}
#endif

#endif

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
    return VS_OUTPUT;
}

#endif

#ifdef COMPILEPS

struct PS_INPUT
{
    float2 iScreenPos : TEXCOORD0;
};

struct PS_OUTPUT
{
    out float4 oColor : OUTCOLOR0;
};

PS_OUTPUT PS(PS_INPUT IN)
{
    PS_OUTPUT OUT;
    #ifdef REINHARDEQ3
    float3 color = ReinhardEq3Tonemap(max(Sample2D(DiffMap, IN.iScreenPos).rgb * cTonemapExposureBias, 0.0));
    OUT.oColor = float4(color, 1.0);
    #endif

    #ifdef REINHARDEQ4
    float3 color = ReinhardEq4Tonemap(max(Sample2D(DiffMap, IN.iScreenPos).rgb * cTonemapExposureBias, 0.0), cTonemapMaxWhite);
    OUT.oColor = float4(color, 1.0);
    #endif

    #ifdef UNCHARTED2
    float3 color = Uncharted2Tonemap(max(Sample2D(DiffMap, IN.iScreenPos).rgb * cTonemapExposureBias, 0.0)) /
        Uncharted2Tonemap(float3(cTonemapMaxWhite, cTonemapMaxWhite, cTonemapMaxWhite));
    OUT.oColor = float4(color, 1.0);
    #endif
}

#endif
