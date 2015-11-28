#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Fog.hlsl"

#ifndef D3D11

// D3D9 uniforms and samplers
#ifdef COMPILEVS
uniform float2 cDetailTiling;
#else
sampler2D sWeightMap0 : register(s0);
sampler2D sDetailMap1 : register(s1);
sampler2D sDetailMap2 : register(s2);
sampler2D sDetailMap3 : register(s3);
#endif

#else

// D3D11 constant buffers and samplers
#ifdef COMPILEVS
cbuffer CustomVS : register(b6)
{
    float2 cDetailTiling;
}
#else
Texture2D tWeightMap0 : register(t0);
Texture2D tDetailMap1 : register(t1);
Texture2D tDetailMap2 : register(t2);
Texture2D tDetailMap3 : register(t3);
SamplerState sWeightMap0 : register(s0);
SamplerState sDetailMap1 : register(s1);
SamplerState sDetailMap2 : register(s2);
SamplerState sDetailMap3 : register(s3);
#endif

#endif

#ifdef COMPILEVS

struct VS_INPUT
{
	float4 iPos : POSITION;
	float3 iNormal : NORMAL;
	float2 iTexCoord : TEXCOORD0;
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
	float3 oNormal : TEXCOORD1;
	float4 oWorldPos : TEXCOORD2;
	float2 oDetailTexCoord : TEXCOORD3;
#ifdef PERPIXEL
#ifdef SHADOW
	float4 oShadowPos[NUMCASCADES] : TEXCOORD4;
#endif
#ifdef SPOTLIGHT
	float4 oSpotPos : TEXCOORD5;
#endif
#ifdef POINTLIGHT
	float3 oCubeMaskVec : TEXCOORD5;
#endif
#else
	float3 oVertexLight : TEXCOORD4;
	float4 oScreenPos : TEXCOORD5;
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
	OUT.oNormal = GetWorldNormal(modelMatrix);
	OUT.oWorldPos = float4(worldPos, GetDepth(OUT.oPos));
	OUT.oTexCoord = GetTexCoord(IN.iTexCoord);
	OUT.oDetailTexCoord = cDetailTiling * OUT.oTexCoord;

    #if defined(D3D11) && defined(CLIPPLANE)
		OUT.oClip = dot(OUT.oPos, cClipPlane);
    #endif

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        float4 projWorldPos = float4(worldPos.xyz, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
			GetShadowPos(projWorldPos, OUT.oShadowPos);
        #endif

        #ifdef SPOTLIGHT
            // Spotlight projection: transform from world space to projector texture coordinates
			OUT.oSpotPos = mul(projWorldPos, cLightMatrices[0]);
        #endif

        #ifdef POINTLIGHT
			OUT.oCubeMaskVec = mul(worldPos - cLightPos.xyz, (float3x3)cLightMatrices[0]);
        #endif
    #else
        // Ambient & per-vertex lighting
		OUT.oVertexLight = GetAmbient(GetZonePos(worldPos));

        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
				OUT.oVertexLight += GetVertexLight(i, worldPos, OUT.oNormal) * cVertexLights[i * 3].rgb;
        #endif
        
		OUT.oScreenPos = GetScreenPos(OUT.oPos);
    #endif
	
	return OUT;
}

#endif

#ifdef COMPILEPS

struct PS_INPUT
{
	float2 iTexCoord : TEXCOORD0;
	float3 iNormal : TEXCOORD1;
	float4 iWorldPos : TEXCOORD2;
	float2 iDetailTexCoord : TEXCOORD3;
#ifdef PERPIXEL
#ifdef SHADOW
	float4 iShadowPos[NUMCASCADES] : TEXCOORD4;
#endif
#ifdef SPOTLIGHT
	float4 iSpotPos : TEXCOORD5;
#endif
#ifdef CUBEMASK
	float3 iCubeMaskVec : TEXCOORD5;
#endif
#else
	float3 iVertexLight : TEXCOORD4;
	float4 iScreenPos : TEXCOORD5;
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
	float3 weights = Sample2D(WeightMap0, IN.iTexCoord).rgb;
    float sumWeights = weights.r + weights.g + weights.b;
    weights /= sumWeights;
    float4 diffColor = cMatDiffColor * (
		weights.r * Sample2D(DetailMap1, IN.iDetailTexCoord) +
		weights.g * Sample2D(DetailMap2, IN.iDetailTexCoord) +
		weights.b * Sample2D(DetailMap3, IN.iDetailTexCoord)
    );

    // Get material specular albedo
    float3 specColor = cMatSpecColor.rgb;

    // Get normal
	float3 normal = normalize(IN.iNormal);

    // Get fog factor
    #ifdef HEIGHTFOG
	float fogFactor = GetHeightFogFactor(IN.iWorldPos.w, IN.iWorldPos.y);
    #else
	float fogFactor = GetFogFactor(IN.iWorldPos.w);
    #endif

    #if defined(PERPIXEL)
        // Per-pixel forward lighting
        float3 lightDir;
        float3 lightColor;
        float3 finalColor;
        
		float diff = GetDiffuse(normal, IN.iWorldPos.xyz, lightDir);

        #ifdef SHADOW
		diff *= GetShadow(IN.iShadowPos, IN.iWorldPos.w);
        #endif
    
        #if defined(SPOTLIGHT)
			lightColor = IN.iSpotPos.w > 0.0 ? Sample2DProj(LightSpotMap, IN.iSpotPos).rgb * cLightColor.rgb : 0.0;
        #elif defined(CUBEMASK)
			lightColor = SampleCube(LightCubeMap, IN.iCubeMaskVec).rgb * cLightColor.rgb;
        #else
            lightColor = cLightColor.rgb;
        #endif
    
        #ifdef SPECULAR
			float spec = GetSpecular(normal, cCameraPosPS - IN.iWorldPos.xyz, lightDir, cMatSpecColor.a);
            finalColor = diff * lightColor * (diffColor.rgb + spec * specColor * cLightColor.a);
        #else
            finalColor = diff * lightColor * diffColor.rgb;
        #endif

        #ifdef AMBIENT
            finalColor += cAmbientColor * diffColor.rgb;
            finalColor += cMatEmissiveColor;
			OUT.oColor = float4(GetFog(finalColor, fogFactor), diffColor.a);
        #else
			OUT.oColor = float4(GetLitFog(finalColor, fogFactor), diffColor.a);
        #endif
    #elif defined(PREPASS)
        // Fill light pre-pass G-Buffer
        float specPower = cMatSpecColor.a / 255.0;

		OUT.oColor = float4(normal * 0.5 + 0.5, specPower);
		OUT.oDepth = iWorldPos.w;
    #elif defined(DEFERRED)
        // Fill deferred G-buffer
        float specIntensity = specColor.g;
        float specPower = cMatSpecColor.a / 255.0;

		float3 finalColor = IN.iVertexLight * diffColor.rgb;

		OUT.oColor = float4(GetFog(finalColor, fogFactor), 1.0);
		OUT.oAlbedo = fogFactor * float4(diffColor.rgb, specIntensity);
		OUT.oNormal = float4(normal * 0.5 + 0.5, specPower);
		OUT.oDepth = IN.iWorldPos.w;
    #else
        // Ambient & per-vertex lighting
	float3 finalColor = IN.iVertexLight * diffColor.rgb;

        #ifdef MATERIAL
            // Add light pre-pass accumulation result
            // Lights are accumulated at half intensity. Bring back to full intensity now
            float4 lightInput = 2.0 * Sample2DProj(LightBuffer, iScreenPos);
            float3 lightSpecColor = lightInput.a * (lightInput.rgb / GetIntensity(lightInput.rgb));

            finalColor += lightInput.rgb * diffColor.rgb + lightSpecColor * specColor;
        #endif

		OUT.oColor = float4(GetFog(finalColor, fogFactor), diffColor.a);
    #endif
	return OUT;
}

#endif