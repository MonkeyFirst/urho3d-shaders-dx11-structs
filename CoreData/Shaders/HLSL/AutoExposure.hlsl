#include "Uniforms.hlsl"
#include "Transform.hlsl"
#include "Samplers.hlsl"
#include "ScreenPos.hlsl"
#include "PostProcess.hlsl"

uniform float cAutoExposureAdaptRate;
uniform float2 cAutoExposureLumRange;
uniform float cAutoExposureMiddleGrey;
uniform float2 cHDR128Offsets;
uniform float2 cLum64Offsets;
uniform float2 cLum16Offsets;
uniform float2 cLum4Offsets;
uniform float2 cHDR128InvSize;
uniform float2 cLum64InvSize;
uniform float2 cLum16InvSize;
uniform float2 cLum4InvSize;

#ifndef D3D11
float GatherAvgLum(sampler2D texSampler, float2 texCoord, float2 texelSize)
#else
float GatherAvgLum(Texture2D tex, SamplerState texSampler, float2 texCoord, float2 texelSize)
#endif
{
    float lumAvg = 0.0;
    #ifndef D3D11
    lumAvg += tex2D(texSampler, texCoord + float2(0.0, 0.0) * texelSize).r;
    lumAvg += tex2D(texSampler, texCoord + float2(0.0, 2.0) * texelSize).r;
    lumAvg += tex2D(texSampler, texCoord + float2(2.0, 2.0) * texelSize).r;
    lumAvg += tex2D(texSampler, texCoord + float2(2.0, 0.0) * texelSize).r;
    #else
    lumAvg += tex.Sample(texSampler, texCoord + float2(0.0, 0.0) * texelSize).r;
    lumAvg += tex.Sample(texSampler, texCoord + float2(0.0, 2.0) * texelSize).r;
    lumAvg += tex.Sample(texSampler, texCoord + float2(2.0, 2.0) * texelSize).r;
    lumAvg += tex.Sample(texSampler, texCoord + float2(2.0, 0.0) * texelSize).r;
    #endif
    return lumAvg / 4.0;
}

#ifdef COMPILEVS

struct VS_INPUT
{
    float4 iPos : POSITION;
};

struct VS_OUT
{
    float2 oTexCoord : TEXCOORD0;
    float2 oScreenPos : TEXCOORD1;
    float4 oPos : OUTPOSITION;
};

VS_OUT VS(VS_INPUT IN)
{
    VS_OUT OUT;
    float4x3 modelMatrix = iModelMatrix;
    float3 worldPos = GetWorldPos(modelMatrix);
    OUT.oPos = GetClipPos(worldPos);

    OUT.oTexCoord = GetQuadTexCoord(OUT.oPos);

    #ifdef LUMINANCE64
    OUT.oTexCoord = GetQuadTexCoord(OUT.oPos) + cHDR128Offsets;
    #endif

    #ifdef LUMINANCE16
    OUT.oTexCoord = GetQuadTexCoord(OUT.oPos) + cLum64Offsets;
    #endif

    #ifdef LUMINANCE4
    OUT.oTexCoord = GetQuadTexCoord(OUT.oPos) + cLum16Offsets;
    #endif

    #ifdef LUMINANCE1
    OUT.oTexCoord = GetQuadTexCoord(OUT.oPos) + cLum4Offsets;
    #endif

    OUT.oScreenPos = GetScreenPosPreDiv(OUT.oPos);

    return OUT;
}

#endif

#ifdef COMPILEPS

struct PS_INPUT
{
    float2 iTexCoord : TEXCOORD0;
    float2 iScreenPos : TEXCOORD1;
};

struct PS_OUT
{
    float4 oColor : OUTCOLOR0;
};

PS_OUT PS(PS_INPUT IN)
{
    PS_OUT OUT;
    #ifdef LUMINANCE64
    float logLumSum = 0.0;
    logLumSum += log(dot(Sample2D(DiffMap, IN.iTexCoord + float2(0.0, 0.0) * cHDR128InvSize).rgb, LumWeights) + 1e-5);
    logLumSum += log(dot(Sample2D(DiffMap, IN.iTexCoord + float2(0.0, 2.0) * cHDR128InvSize).rgb, LumWeights) + 1e-5);
    logLumSum += log(dot(Sample2D(DiffMap, IN.iTexCoord + float2(2.0, 2.0) * cHDR128InvSize).rgb, LumWeights) + 1e-5);
    logLumSum += log(dot(Sample2D(DiffMap, IN.iTexCoord + float2(2.0, 0.0) * cHDR128InvSize).rgb, LumWeights) + 1e-5);
    OUT.oColor = logLumSum;
    #endif

    #ifdef LUMINANCE16
    #ifndef D3D11
    OUT.oColor = GatherAvgLum(sDiffMap, IN.iTexCoord, cLum64InvSize);
    #else
    OUT.oColor = GatherAvgLum(tDiffMap, sDiffMap, IN.iTexCoord, cLum64InvSize);
    #endif
    #endif

    #ifdef LUMINANCE4
    #ifndef D3D11
    OUT.oColor = GatherAvgLum(sDiffMap, IN.iTexCoord, cLum16InvSize);
    #else
    OUT.oColor = GatherAvgLum(tDiffMap, sDiffMap, IN.iTexCoord, cLum16InvSize);
    #endif
    #endif

    #ifdef LUMINANCE1
    #ifndef D3D11
    OUT.oColor = exp(GatherAvgLum(sDiffMap, IN.iTexCoord, cLum4InvSize) / 16.0);
    #else
    OUT.oColor = exp(GatherAvgLum(tDiffMap, sDiffMap, IN.iTexCoord, cLum4InvSize) / 16.0);
    #endif
    #endif

    #ifdef ADAPTLUMINANCE
    float adaptedLum = Sample2D(DiffMap, IN.iTexCoord).r;
    float lum = clamp(Sample2D(NormalMap, IN.iTexCoord).r, cAutoExposureLumRange.x, cAutoExposureLumRange.y);
    OUT.oColor = adaptedLum + (lum - adaptedLum) * (1.0 - exp(-cDeltaTimePS * cAutoExposureAdaptRate));
    #endif

    #ifdef EXPOSE
    float3 color = Sample2D(DiffMap, IN.iScreenPos).rgb;
    float adaptedLum = Sample2D(NormalMap, IN.iTexCoord).r;
    OUT.oColor = float4(color * (cAutoExposureMiddleGrey / adaptedLum), 1.0);
    #endif
    return OUT;
}

#endif