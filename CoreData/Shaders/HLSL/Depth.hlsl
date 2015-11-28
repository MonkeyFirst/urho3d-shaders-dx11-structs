#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

#ifdef COMPILEVS

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
    float3 oTexCoord : TEXCOORD0;
    float4 oPos : OUTPOSITION;
};

VS_OUTPUT VS(VS_INPUT IN)
{
    VS_OUTPUT OUT;
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    OUT.oPos = GetClipPos(worldPos);
    OUT.oTexCoord = float3(GetTexCoord(IN.iTexCoord), GetDepth(OUT.oPos));
    return OUT;
}
#endif

#ifdef COMPILEPS

struct PS_INPUT
{
    float3 iTexCoord : TEXCOORD0;
};

struct PS_OUTPUT
{
    float4 oColor : OUTCOLOR0;
};

PS_OUTPUT PS(PS_INPUT IN)
{
    PS_OUTPUT OUT;
    #ifdef ALPHAMASK
    float alpha = Sample2D(sDiffMap, IN.iTexCoord.xy).a;
        if (alpha < 0.5)
            discard;
    #endif
    OUT.oColor = IN.iTexCoord.z;
    return OUT;
}

#endif
