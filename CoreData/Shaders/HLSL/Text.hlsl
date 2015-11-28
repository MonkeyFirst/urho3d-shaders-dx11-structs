#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float2 cShadowOffset;
uniform float4 cShadowColor;
uniform float4 cStrokeColor;

#else

#ifdef COMPILEPS
// D3D11 constant buffers
cbuffer CustomPS : register(b6)
{
    float2 cShadowOffset;
    float4 cShadowColor;
    float4 cStrokeColor;
}
#endif

#endif

#ifdef COMPILEVS

struct VS_INPUT
{
    float4 iPos : POSITION;
    float2 iTexCoord : TEXCOORD0;
    float4 iColor : COLOR0;
};

struct VS_OUTPUT
{
    float2 oTexCoord : TEXCOORD0;
    float4 oColor : COLOR0;
    float4 oPos : OUTPOSITION;
};

VS_OUTPUT VS(VS_INPUT IN)
{
    VS_OUTPUT OUT;
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    OUT.oPos = GetClipPos(worldPos);
    OUT.oColor = IN.iColor;
    OUT.oTexCoord = IN.iTexCoord;
    return OUT;
}

#endif

#ifdef COMPILEPS

struct PS_INPUT
{
    float2 iTexCoord : TEXCOORD0;
    float4 iColor : COLOR0;
};

struct PS_OUTPUT
{
    float4 oColor : OUTCOLOR0;
};

PS_OUTPUT PS(PS_INPUT IN)
{
    PS_OUTPUT OUT;
    OUT.oColor.rgb = IN.iColor.rgb;

#ifdef SIGNED_DISTANCE_FIELD
    float distance = Sample2D(DiffMap, IN.iTexCoord).a;
    if (distance < 0.5f)
    {
    #ifdef TEXT_EFFECT_SHADOW
        if (Sample2D(DiffMap, IN.iTexCoord - cShadowOffset).a > 0.5f)
            OUT.oColor = cShadowColor;
        else
    #endif
        OUT.oColor.a = 0.0f;
    }
    else
    {
    #ifdef TEXT_EFFECT_STROKE
        if (distance < 0.525f)
            OUT.oColor.rgb = cStrokeColor.rgb;
    #endif

    #ifdef TEXT_EFFECT_SHADOW
        if (Sample2D(DiffMap, IN.iTexCoord + cShadowOffset).a < 0.5f)
            OUT.oColor.a = IN.iColor.a;
        else
    #endif
        OUT.oColor.a = IN.iColor.a * smoothstep(0.5f, 0.505f, distance);
    }
#else
    OUT.oColor.a = IN.iColor.a * Sample2D(DiffMap, IN.iTexCoord).a;
#endif
    return OUT;
}
#endif