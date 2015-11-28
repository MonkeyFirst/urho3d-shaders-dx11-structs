#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

#ifdef COMPILEVS

struct VS_INPUT
{
	float4 iPos : POSITION;
#ifdef DIFFMAP
	float2 iTexCoord : TEXCOORD0;
#endif
#ifdef VERTEXCOLOR
	float4 iColor : COLOR0;
#endif
#ifdef SKINNED
	float4 iBlendWeights : BLENDWEIGHT;
	int4 iBlendIndices : BLENDINDICES;
#endif
#ifdef INSTANCED
	float4x3 iModelInstance : TEXCOORD2;
#endif
#ifdef BILLBOARD
	float2 iSize : TEXCOORD1;
#endif
};

struct VS_OUTPUT
{
#ifdef DIFFMAP
	float2 oTexCoord : TEXCOORD0;
#endif
#ifdef VERTEXCOLOR
	float4 oColor : COLOR0;
#endif
#if defined(D3D11) && defined(CLIPPLANE)
	float oClip : SV_CLIPDISTANCE0;
#endif
	float4 oPos : OUTPOSITION;
};

VS_OUTPUT VS(VS_INPUT IN)
{
	VS_OUTPUT OUT;

    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
	OUT.oPos = GetClipPos(worldPos);

    #if defined(D3D11) && defined(CLIPPLANE)
		OUT.oClip = dot(OUT.oPos, cClipPlane);
    #endif

    #ifdef VERTEXCOLOR
		OUT.oColor = IN.iColor;
    #endif
    #ifdef DIFFMAP
		OUT.oTexCoord = IN.iTexCoord;
    #endif
	
	return OUT;
};
#endif

#ifdef COMPILEPS

struct PS_INPUT
{
#if defined(DIFFMAP) || defined(ALPHAMAP)
	float2 iTexCoord : TEXCOORD0;
#endif
#ifdef VERTEXCOLOR
	float4 iColor : COLOR0;
#endif
#if defined(D3D11) && defined(CLIPPLANE)
	float iClip : SV_CLIPDISTANCE0;
#endif
};

struct PS_OUTPUT
{
	float4 oColor : OUTCOLOR0;
};

PS_OUTPUT PS(PS_INPUT IN)
{
	PS_OUTPUT OUT;

	float4 diffColor = cMatDiffColor;

    #ifdef VERTEXCOLOR
		diffColor *= IN.iColor;
    #endif

    #if (!defined(DIFFMAP)) && (!defined(ALPHAMAP))
		OUT.oColor = diffColor;
    #endif
    #ifdef DIFFMAP
		float4 diffInput = Sample2D(DiffMap, IN.iTexCoord);
        #ifdef ALPHAMASK
            if (diffInput.a < 0.5)
                discard;
        #endif
		OUT.oColor = diffColor * diffInput;
    #endif
    #ifdef ALPHAMAP
		float alphaInput = Sample2D(DiffMap, IN.iTexCoord).a;
		OUT.oColor = float4(diffColor.rgb, diffColor.a * alphaInput);
    #endif
	
	return OUT;
}
#endif
