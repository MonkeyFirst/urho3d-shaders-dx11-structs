#include "Uniforms.hlsl"
#include "Transform.hlsl"

#ifdef COMPILEVS

struct VS_INPUT
{
	float4 iPos : POSITION;
};

struct VS_OUTPUT
{
	float4 oPos : OUTPOSITION;
};

VS_OUTPUT VS(VS_INPUT IN)
{
	VS_OUTPUT OUT;
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
	OUT.oPos = GetClipPos(worldPos);
	return OUT;
}
#endif

#ifdef COMPILEPS

struct PS_OUTPUT
{
	float4 oColor : OUTCOLOR0;
};

PS_OUTPUT PS()
{
	PS_OUTPUT OUT;
	OUT.oColor = 1.0;
	return OUT;
}

#endif