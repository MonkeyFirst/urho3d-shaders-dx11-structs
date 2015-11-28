#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

#ifdef COMPILEVS

#ifndef D3D11

// D3D9 uniforms
uniform float cWindHeightFactor;
uniform float cWindHeightPivot;
uniform float cWindPeriod;
uniform float2 cWindWorldSpacing;

#else

// D3D11 constant buffer
cbuffer CustomVS : register(b6)
{
    float cWindHeightFactor;
    float cWindHeightPivot;
    float cWindPeriod;
    float2 cWindWorldSpacing;
}

#endif

struct VS_INPUT
{
    float4 iPos : POSITION;
#ifdef SKINNED
    float4 iBlendWeights : BLENDWEIGHT;
    int4 iBlendIndices : BLENDINDICES;
#endif
#ifdef INSTANCED
    float4x3 iModelInstance : TEXCOORD2;
#endif
    float2 iTexCoord : TEXCOORD0;
};

struct VS_OUTPUT
{
    float2 oTexCoord : TEXCOORD0;
    float4 oPos : OUTPOSITION;
};

VS_OUTPUT VS(VS_INPUT IN)
{
    VS_OUTPUT OUT;
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);

    float windStrength = max(IN.iPos.y - cWindHeightPivot, 0.0) * cWindHeightFactor;
    float windPeriod = cElapsedTime * cWindPeriod + dot(worldPos.xz, cWindWorldSpacing);
    worldPos.x += windStrength * sin(windPeriod);
    worldPos.z -= windStrength * cos(windPeriod);

    OUT.oPos = GetClipPos(worldPos);
    OUT.oTexCoord = GetTexCoord(IN.iTexCoord);
    return OUT;
}

#endif
