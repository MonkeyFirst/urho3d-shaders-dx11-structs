#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "Fog.hlsl"

#ifdef COMPILEVS

struct VS_INPUT 
{
	float4 iPos : POSITION;
#ifndef NOUV
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
	float2 oTexCoord : TEXCOORD0;
	float4 oWorldPos : TEXCOORD2;
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

    // Define a 0,0 UV coord if not expected from the vertex data
    #ifdef NOUV
		OUT.oTexCoord = GetTexCoord(float2(0.0, 0.0));
	#else
		OUT.oTexCoord = GetTexCoord(IN.iTexCoord);
	#endif

    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
	OUT.oPos = GetClipPos(worldPos);
	OUT.oWorldPos = float4(worldPos, GetDepth(OUT.oPos));

    #if defined(D3D11) && defined(CLIPPLANE)
		OUT.oClip = dot(OUT.oPos, cClipPlane);
    #endif
    
    #ifdef VERTEXCOLOR
		OUT.oColor = IN.iColor;
    #endif

	return OUT;
}

#endif

#ifdef COMPILEPS

struct PS_INPUT
{
	float2 iTexCoord : TEXCOORD0;
	float4 iWorldPos : TEXCOORD2;
#ifdef VERTEXCOLOR
	float4 iColor : COLOR0;
#endif
#if defined(D3D11) && defined(CLIPPLANE)
	float iClip : SV_CLIPDISTANCE0;
#endif
};

struct PS_OUTPUT
{
#ifdef PREPASS
	float4 oDepth : OUTCOLOR1;
#endif
#ifdef DEFERRED
	float4 oAlbedo : OUTCOLOR1;
	float4 oNormal : OUTCOLOR2;
	float4 oDepth : OUTCOLOR3;
#endif
	float4 oColor : OUTCOLOR0;
};

PS_OUTPUT PS(PS_INPUT IN)
{
	PS_OUTPUT OUT;
    // Get material diffuse albedo
    #ifdef DIFFMAP
	float4 diffColor = cMatDiffColor * Sample2D(DiffMap, IN.iTexCoord);
        #ifdef ALPHAMASK
            if (diffColor.a < 0.5)
                discard;
        #endif
    #else
		float4 diffColor = cMatDiffColor;
    #endif

    #ifdef VERTEXCOLOR
			diffColor *= IN.iColor;
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
		float fogFactor = GetHeightFogFactor(IN.iWorldPos.w, IN.iWorldPos.y);
    #else
		float fogFactor = GetFogFactor(IN.iWorldPos.w);
    #endif

    #if defined(PREPASS)
        // Fill light pre-pass G-Buffer
		OUT.oColor = float4(0.5, 0.5, 0.5, 1.0);
		OUT.oDepth = iWorldPos.w;
    #elif defined(DEFERRED)
        // Fill deferred G-buffer
		OUT.oColor = float4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
		OUT.oAlbedo = float4(0.0, 0.0, 0.0, 0.0);
		OUT.oNormal = float4(0.5, 0.5, 0.5, 1.0);
		OUT.oDepth = IN.iWorldPos.w;
    #else
		OUT.oColor = float4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
    #endif

	return OUT;
}
#endif