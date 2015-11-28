#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"

#line 5
#ifdef COMPILEVS

struct VS_INPUT
{
	float4 iPos : POSITION;
	float2 iTexCoord : TEXCOORD0;
	float4 iColor : COLOR0;
};

struct VS_OUTPUT
{
	float4 oColor : COLOR0;
	float2 oTexCoord : TEXCOORD0;
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
	float4 iColor : COLOR0;
	float2 iTexCoord : TEXCOORD0;
};

struct PS_OUTPUT
{
	float4 oColor : OUTCOLOR0;
};

PS_OUTPUT PS(PS_INPUT IN)
{
	PS_OUTPUT OUT;
	float4 diffColor = cMatDiffColor * IN.iColor;
	float4 diffInput = Sample2D(DiffMap, IN.iTexCoord);
	OUT.oColor = diffColor * diffInput;
	return OUT;
}

#endif
