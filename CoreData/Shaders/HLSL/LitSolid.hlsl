#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Fog.hlsl"

#ifdef COMPILEVS

struct VS_INPUT 
{
	float4 iPos : POSITION;
#ifndef BILLBOARD
	float3 iNormal : NORMAL;
#endif
#ifndef NOUV
	float2 iTexCoord : TEXCOORD0;
#endif
#ifdef VERTEXCOLOR
	float4 iColor : COLOR0;
#endif
#if defined(LIGHTMAP) || defined(AO)
	float2 iTexCoord2 : TEXCOORD1;
#endif
#ifdef NORMALMAP
	float4 iTangent : TANGENT;
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
#ifndef NORMALMAP
	float2 oTexCoord : TEXCOORD0;
#else
	float4 oTexCoord : TEXCOORD0;
	float4 oTangent : TEXCOORD3;
#endif
	float3 oNormal : TEXCOORD1;
	float4 oWorldPos : TEXCOORD2;
#ifdef VERTEXCOLOR
	float4 oColor : COLOR0;
#endif
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
#ifdef ENVCUBEMAP
	float3 oReflectionVec : TEXCOORD6;
#endif
#if defined(LIGHTMAP) || defined(AO)
	float2 oTexCoord2 : TEXCOORD7;
#endif
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
	#endif

    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
	OUT.oPos = GetClipPos(worldPos);
	OUT.oNormal = GetWorldNormal(modelMatrix);
	OUT.oWorldPos = float4(worldPos, GetDepth(OUT.oPos));

    #if defined(D3D11) && defined(CLIPPLANE)
		OUT.oClip = dot(OUT.oPos, cClipPlane);
    #endif

    #ifdef VERTEXCOLOR
		OUT.oColor = IN.iColor;
    #endif

    #ifdef NORMALMAP
        float3 tangent = GetWorldTangent(modelMatrix);
		float3 bitangent = cross(tangent, OUT.oNormal) * IN.iTangent.w;
		OUT.oTexCoord = float4(GetTexCoord(IN.iTexCoord), bitangent.xy);
		OUT.oTangent = float4(tangent, bitangent.z);
    #else
		#ifdef NOUV
			OUT.oTexCoord = GetTexCoord(float2(0.0, 0.0));
		#else
			OUT.oTexCoord = GetTexCoord(IN.iTexCoord);
		#endif
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
        #if defined(LIGHTMAP) || defined(AO)
            // If using lightmap, disregard zone ambient light
            // If using AO, calculate ambient in the PS
			OUT.oVertexLight = float3(0.0, 0.0, 0.0);
			OUT.oTexCoord2 = IN.iTexCoord2;
        #else
			OUT.oVertexLight = GetAmbient(GetZonePos(worldPos));
        #endif

        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
				OUT.oVertexLight += GetVertexLight(i, worldPos, OUT.oNormal) * cVertexLights[i * 3].rgb;
        #endif
        
		OUT.oScreenPos = GetScreenPos(OUT.oPos);

        #ifdef ENVCUBEMAP
			OUT.oReflectionVec = worldPos - cCameraPos;
        #endif
    #endif

	return OUT;
}

#endif

#ifdef COMPILEPS

struct PS_INPUT
{
#ifndef NORMALMAP
	float2 iTexCoord : TEXCOORD0;
#else
	float4 iTexCoord : TEXCOORD0;
	float4 iTangent : TEXCOORD3;
#endif
	float3 Normal : TEXCOORD1;
	float4 iWorldPos : TEXCOORD2;
#ifdef VERTEXCOLOR
	float4 iColor : COLOR0;
#endif
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
#ifdef ENVCUBEMAP
	float3 iReflectionVec : TEXCOORD6;
#endif
#if defined(LIGHTMAP) || defined(AO)
	float2 iTexCoord2 : TEXCOORD7;
#endif
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
		float4 diffInput = Sample2D(DiffMap, IN.iTexCoord.xy);
        #ifdef ALPHAMASK
            if (diffInput.a < 0.5)
                discard;
        #endif
        float4 diffColor = cMatDiffColor * diffInput;
    #else
        float4 diffColor = cMatDiffColor;
    #endif

    #ifdef VERTEXCOLOR
			diffColor *= IN.iColor;
    #endif

    // Get material specular albedo
    #ifdef SPECMAP
		float3 specColor = cMatSpecColor.rgb * Sample2D(SpecMap, IN.iTexCoord.xy).rgb;
    #else
        float3 specColor = cMatSpecColor.rgb;
    #endif

    // Get normal
    #ifdef NORMALMAP
		float3x3 tbn = float3x3(IN.iTangent.xyz, float3(IN.iTexCoord.zw, IN.iTangent.w), IN.Normal);
		float3 normal = normalize(mul(DecodeNormal(Sample2D(NormalMap, IN.iTexCoord.xy)), tbn));
    #else
		float3 normal = normalize(IN.Normal);
    #endif

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
		OUT.oDepth = IN.iWorldPos.w;
    #elif defined(DEFERRED)
        // Fill deferred G-buffer
        float specIntensity = specColor.g;
        float specPower = cMatSpecColor.a / 255.0;
		float3 finalColor = IN.iVertexLight * diffColor.rgb;
        #ifdef AO
            // If using AO, the vertex light ambient is black, calculate occluded ambient here
			finalColor += Sample2D(EmissiveMap, IN.iTexCoord2).rgb * cAmbientColor * diffColor.rgb;
        #endif
        #ifdef ENVCUBEMAP
			finalColor += cMatEnvMapColor * SampleCube(EnvCubeMap, reflect(IN.iReflectionVec, normal)).rgb;
        #endif
        #ifdef LIGHTMAP
			finalColor += Sample2D(EmissiveMap, IN.iTexCoord2).rgb * diffColor.rgb;
        #endif
        #ifdef EMISSIVEMAP
			finalColor += cMatEmissiveColor * Sample2D(EmissiveMap, IN.iTexCoord.xy).rgb;
        #else
            finalColor += cMatEmissiveColor;
        #endif

		OUT.oColor = float4(GetFog(finalColor, fogFactor), 1.0);
		OUT.oAlbedo = fogFactor * float4(diffColor.rgb, specIntensity);
		OUT.oNormal = float4(normal * 0.5 + 0.5, specPower);
		OUT.oDepth = IN.iWorldPos.w;
    #else
        // Ambient & per-vertex lighting
		float3 finalColor = IN.iVertexLight * diffColor.rgb;
        #ifdef AO
            // If using AO, the vertex light ambient is black, calculate occluded ambient here
			finalColor += Sample2D(EmissiveMap, IN.iTexCoord2).rgb * cAmbientColor * diffColor.rgb;
        #endif
        #ifdef MATERIAL
            // Add light pre-pass accumulation result
            // Lights are accumulated at half intensity. Bring back to full intensity now
            float4 lightInput = 2.0 * Sample2DProj(LightBuffer, IN.iScreenPos);
            float3 lightSpecColor = lightInput.a * lightInput.rgb / max(GetIntensity(lightInput.rgb), 0.001);
            finalColor += lightInput.rgb * diffColor.rgb + lightSpecColor * specColor;
        #endif
        #ifdef ENVCUBEMAP
			finalColor += cMatEnvMapColor * SampleCube(EnvCubeMap, reflect(IN.iReflectionVec, normal)).rgb;
        #endif
        #ifdef LIGHTMAP
			finalColor += Sample2D(EmissiveMap, IN.iTexCoord2).rgb * diffColor.rgb;
        #endif
        #ifdef EMISSIVEMAP
			finalColor += cMatEmissiveColor * Sample2D(EmissiveMap, IN.iTexCoord.xy).rgb;
        #else
            finalColor += cMatEmissiveColor;
        #endif

		OUT.oColor = float4(GetFog(finalColor, fogFactor), diffColor.a);
    #endif
	
	return OUT;
}
#endif