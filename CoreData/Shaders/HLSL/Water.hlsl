#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Fog.hlsl"

#ifndef D3D11

// D3D9 uniforms
uniform float2 cNoiseSpeed;
uniform float cNoiseTiling;
uniform float cNoiseStrength;
uniform float cFresnelPower;
uniform float3 cWaterTint;

#else

// D3D11 constant buffers
#ifdef COMPILEVS
cbuffer CustomVS : register(b6)
{
    float2 cNoiseSpeed;
    float cNoiseTiling;
}
#else
cbuffer CustomPS : register(b6)
{
    float cNoiseStrength;
    float cFresnelPower;
    float3 cWaterTint;
}
#endif

#endif

#ifdef COMPILEVS

struct VS_INPUT 
{
	float4 iPos : POSITION;
	float3 iNormal : NORMAL;
	float2 iTexCoord : TEXCOORD0;
};

struct VS_OUTPUT 
{
	float4 oScreenPos : TEXCOORD0;
	float2 oReflectUV : TEXCOORD1;
	float2 oWaterUV : TEXCOORD2;
	float3 oNormal : TEXCOORD3;
	float4 oEyeVec : TEXCOORD4;
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

    OUT.oScreenPos = GetScreenPos(OUT.oPos);
    // GetQuadTexCoord() returns a float2 that is OK for quad rendering; multiply it with OUT W
    // coordinate to make it work with arbitrary meshes such as the water plane (perform divide in pixel shader)
    OUT.oReflectUV = GetQuadTexCoord(OUT.oPos) * OUT.oPos.w;
    OUT.oWaterUV = IN.iTexCoord * cNoiseTiling + cElapsedTime * cNoiseSpeed;
    OUT.oNormal = GetWorldNormal(modelMatrix);
    OUT.oEyeVec = float4(cCameraPos - worldPos, GetDepth(OUT.oPos));

    #if defined(D3D11) && defined(CLIPPLANE)
    OUT.oClip = dot(OUT.oPos, cClipPlane);
    #endif

	return OUT;
}

#endif

#ifdef COMPILEPS

struct PS_INPUT
{
    float4 iScreenPos : TEXCOORD0;
    float2 iReflectUV : TEXCOORD1;
    float2 iWaterUV : TEXCOORD2;
    float3 iNormal : TEXCOORD3;
    float4 iEyeVec : TEXCOORD4;
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
    float2 refractUV = IN.iScreenPos.xy / IN.iScreenPos.w;
    float2 reflectUV = IN.iReflectUV.xy / IN.iScreenPos.w;

    float2 noise = (Sample2D(NormalMap, IN.iWaterUV).rg - 0.5) * cNoiseStrength;
    refractUV += noise;
    // Do not shift reflect UV coordinate upward, because it will reveal the clipping of geometry below water
    if (noise.y < 0.0)
        noise.y = 0.0;
    reflectUV += noise;

    float fresnel = pow(1.0 - saturate(dot(normalize(IN.iEyeVec.xyz), IN.iNormal)), cFresnelPower);
    float3 refractColor = Sample2D(EnvMap, refractUV).rgb * cWaterTint;
    float3 reflectColor = Sample2D(DiffMap, reflectUV).rgb;
    float3 finalColor = lerp(refractColor, reflectColor, fresnel);

    OUT.oColor = float4(GetFog(finalColor, GetFogFactor(IN.iEyeVec.w)), 1.0);
    return OUT;
}
#endif