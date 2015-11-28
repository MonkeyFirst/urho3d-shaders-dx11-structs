#include "Uniforms.hlsl"
#include "Samplers.hlsl"
#include "Transform.hlsl"
#include "ScreenPos.hlsl"
#include "Lighting.hlsl"
#include "Fog.hlsl"

#ifdef COMPILEVS

#ifndef D3D11

// D3D9 uniforms
uniform float cWindHeightFactor;
uniform float cWindHeightPivot;
uniform float cWindPeriod;
uniform float2 cWindWorldSpacing;

#else

// D3D11 constant buffer
cbuffer CustomVS : register(b6)
{
    float cWindHeightFactor;
    float cWindHeightPivot;
    float cWindPeriod;
    float2 cWindWorldSpacing;
}

#endif

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
    float height = worldPos.y - cModel._m31;

    float windStrength = max(height - cWindHeightPivot, 0.0) * cWindHeightFactor;
    float windPeriod = cElapsedTime * cWindPeriod + dot(worldPos.xz, cWindWorldSpacing);
    worldPos.x += windStrength * sin(windPeriod);
    worldPos.z -= windStrength * cos(windPeriod);

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
        // Define a 0,0 UV coord if not expected from the vertex data
        #ifdef NOUV
            OUT.oTexCoord = float2(0.0, 0.0);
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