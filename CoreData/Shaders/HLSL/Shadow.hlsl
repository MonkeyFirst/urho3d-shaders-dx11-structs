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
#ifndef NOUV
    float2 iTexCoord : TEXCOORD0;
#endif
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
	OUT.oPos = GetClipPos(worldPos);
    #ifndef NOUV
	OUT.oTexCoord = GetTexCoord(IN.iTexCoord);
	#else
    OUT.oTexCoord = float2(0,0);
    #endif
    return OUT;
}
#endif

#ifdef COMPILEPS

struct PS_INPUT 
{
	float2 iTexCoord : TEXCOORD0;
};

struct PS_OUTPUT 
{
	float4 oColor : OUTCOLOR0;
};

PS_OUTPUT PS(PS_INPUT IN)
{
	PS_OUTPUT OUT;

    #ifdef ALPHAMASK
		float alpha = Sample2D(DiffMap, IN.iTexCoord).a;
        if (alpha < 0.5)
            discard;
    #endif

	OUT.oColor = 1.0;

	return OUT;
}
#endif