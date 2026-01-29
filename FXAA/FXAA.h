// FXAA Anti-Aliasing Core Implementation
// Based on the original FXAA algorithm by Timothy Lottes (NVIDIA)
// Ported from libretro slang-shaders

/*
FXAA Configuration Parameters:
------------------------------------------------------------------------------
FXAA_EDGE_THRESHOLD - Minimum local contrast required to apply algorithm.
                      1.0/3.0  - too little
                      1.0/4.0  - good start
                      1.0/8.0  - applies to more edges
                      1.0/16.0 - overkill
------------------------------------------------------------------------------
FXAA_EDGE_THRESHOLD_MIN - Trims algorithm from processing darks (perf optimization).
                          1.0/32.0 - visible limit (smaller isnt visible)
                          1.0/16.0 - good compromise
                          1.0/12.0 - upper limit (seeing artifacts)
------------------------------------------------------------------------------
FXAA_SEARCH_STEPS - Maximum number of search steps for end of span.
------------------------------------------------------------------------------
FXAA_SEARCH_THRESHOLD - Controls when to stop searching.
                        1.0/4.0 - seems to be the best quality wise
------------------------------------------------------------------------------
FXAA_SUBPIX_TRIM - Controls sub-pixel aliasing removal.
                   1.0/2.0 - low removal
                   1.0/3.0 - medium removal
                   1.0/4.0 - default removal
                   1.0/8.0 - high removal
                   0.0 - complete removal
------------------------------------------------------------------------------
FXAA_SUBPIX_CAP - Insures fine detail is not completely removed.
                  Important for transitions of sub-pixel detail like fences/wires.
                  3.0/4.0 - default (medium filtering)
                  7.0/8.0 - high filtering
                  1.0 - no capping
*/

#ifndef FXAA_SLANGI
#define FXAA_SLANGI

#ifndef FXAA_PRESET
#define FXAA_PRESET 5
#endif

#if (FXAA_PRESET == 3)
#define FXAA_EDGE_THRESHOLD      (1.0/8.0)
#define FXAA_EDGE_THRESHOLD_MIN  (1.0/16.0)
#define FXAA_SEARCH_STEPS        16
#define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
#define FXAA_SUBPIX_CAP          (3.0/4.0)
#define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif

#if (FXAA_PRESET == 4)
#define FXAA_EDGE_THRESHOLD      (1.0/8.0)
#define FXAA_EDGE_THRESHOLD_MIN  (1.0/24.0)
#define FXAA_SEARCH_STEPS        24
#define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
#define FXAA_SUBPIX_CAP          (3.0/4.0)
#define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif

#if (FXAA_PRESET == 5)
#define FXAA_EDGE_THRESHOLD      (1.0/8.0)
#define FXAA_EDGE_THRESHOLD_MIN  (1.0/24.0)
#define FXAA_SEARCH_STEPS        32
#define FXAA_SEARCH_THRESHOLD    (1.0/4.0)
#define FXAA_SUBPIX_CAP          (3.0/4.0)
#define FXAA_SUBPIX_TRIM         (1.0/4.0)
#endif

#define FXAA_SUBPIX_TRIM_SCALE (1.0/(1.0 - FXAA_SUBPIX_TRIM))

float ComputeFxaaLuma(float3 rgb) {
	return rgb.y * (0.587 / 0.299) + rgb.x;
}

float3 BlendFxaaColors(float3 colorA, float3 colorB, float blendFactor) {
	return (colorA - colorB) * blendFactor + colorB;
}

float3 ProcessFXAA(float3 src[4][4], uint i, uint j, Texture2D<float4> INPUT, SamplerState sam, float2 pos, float2 inputPt) {
	float lumaNorth = ComputeFxaaLuma(src[i][j - 1]);
	float lumaWest = ComputeFxaaLuma(src[i - 1][j]);
	float lumaCenter = ComputeFxaaLuma(src[i][j]);
	float lumaEast = ComputeFxaaLuma(src[i + 1][j]);
	float lumaSouth = ComputeFxaaLuma(src[i][j + 1]);

	float rangeMin = min(lumaCenter, min(min(lumaNorth, lumaWest), min(lumaSouth, lumaEast)));
	float rangeMax = max(lumaCenter, max(max(lumaNorth, lumaWest), max(lumaSouth, lumaEast)));
	float range = rangeMax - rangeMin;

	if (range < max(FXAA_EDGE_THRESHOLD_MIN, rangeMax * FXAA_EDGE_THRESHOLD)) {
		return src[i][j];
	}

	float3 rgbAccum = src[i][j - 1] + src[i - 1][j] + src[i][j] + src[i + 1][j] + src[i][j + 1];

	float lumaAvg = (lumaNorth + lumaWest + lumaEast + lumaSouth) * 0.25;
	float rangeLocal = abs(lumaAvg - lumaCenter);
	float blendSubpix = max(0.0, (rangeLocal / range) - FXAA_SUBPIX_TRIM) * FXAA_SUBPIX_TRIM_SCALE;
	blendSubpix = min(FXAA_SUBPIX_CAP, blendSubpix);

	rgbAccum += (src[i - 1][j - 1] + src[i + 1][j - 1] + src[i - 1][j + 1] + src[i + 1][j + 1]);
	rgbAccum *= 1.0 / 9.0;

	float lumaNW = ComputeFxaaLuma(src[i - 1][j - 1]);
	float lumaNE = ComputeFxaaLuma(src[i + 1][j - 1]);
	float lumaSW = ComputeFxaaLuma(src[i - 1][j + 1]);
	float lumaSE = ComputeFxaaLuma(src[i + 1][j + 1]);

	float edgeVertical =
		abs((0.25 * lumaNW) + (-0.5 * lumaNorth) + (0.25 * lumaNE)) +
		abs((0.50 * lumaWest) + (-1.0 * lumaCenter) + (0.50 * lumaEast)) +
		abs((0.25 * lumaSW) + (-0.5 * lumaSouth) + (0.25 * lumaSE));
	float edgeHorizontal =
		abs((0.25 * lumaNW) + (-0.5 * lumaWest) + (0.25 * lumaSW)) +
		abs((0.50 * lumaNorth) + (-1.0 * lumaCenter) + (0.50 * lumaSouth)) +
		abs((0.25 * lumaNE) + (-0.5 * lumaEast) + (0.25 * lumaSE));

	bool isHorizontalSpan = edgeHorizontal >= edgeVertical;
	float stepLength = isHorizontalSpan ? -inputPt.y : -inputPt.x;

	if (!isHorizontalSpan) {
		lumaNorth = lumaWest;
		lumaSouth = lumaEast;
	}

	float gradientNeg = abs(lumaNorth - lumaCenter);
	float gradientPos = abs(lumaSouth - lumaCenter);
	lumaNorth = (lumaNorth + lumaCenter) * 0.5;
	lumaSouth = (lumaSouth + lumaCenter) * 0.5;

	if (gradientNeg < gradientPos) {
		lumaNorth = lumaSouth;
		gradientNeg = gradientPos;
		stepLength *= -1.0;
	}

	float2 searchPosNeg;
	searchPosNeg.x = pos.x + (isHorizontalSpan ? 0.0 : stepLength * 0.5);
	searchPosNeg.y = pos.y + (isHorizontalSpan ? stepLength * 0.5 : 0.0);

	gradientNeg *= FXAA_SEARCH_THRESHOLD;

	float2 searchPosPos = searchPosNeg;
	float2 searchOffset = isHorizontalSpan ? float2(inputPt.x, 0.0) : float2(0.0, inputPt.y);
	float lumaEndNeg = lumaNorth;
	float lumaEndPos = lumaNorth;
	bool doneNeg = false;
	bool donePos = false;

	searchPosNeg += searchOffset * float2(-1.0, -1.0);
	searchPosPos += searchOffset * float2(1.0, 1.0);

	for (int iter = 0; iter < FXAA_SEARCH_STEPS; iter++) {
		if (!doneNeg) {
			lumaEndNeg = ComputeFxaaLuma(INPUT.SampleLevel(sam, searchPosNeg.xy, 0).xyz);
		}
		if (!donePos) {
			lumaEndPos = ComputeFxaaLuma(INPUT.SampleLevel(sam, searchPosPos.xy, 0).xyz);
		}

		doneNeg = doneNeg || (abs(lumaEndNeg - lumaNorth) >= gradientNeg);
		donePos = donePos || (abs(lumaEndPos - lumaNorth) >= gradientNeg);

		if (doneNeg && donePos) {
			break;
		}
		if (!doneNeg) {
			searchPosNeg -= searchOffset;
		}
		if (!donePos) {
			searchPosPos += searchOffset;
		}
	}

	float distNeg = isHorizontalSpan ? pos.x - searchPosNeg.x : pos.y - searchPosNeg.y;
	float distPos = isHorizontalSpan ? searchPosPos.x - pos.x : searchPosPos.y - pos.y;
	bool isNegCloser = distNeg < distPos;
	lumaEndNeg = isNegCloser ? lumaEndNeg : lumaEndPos;

	if (((lumaCenter - lumaNorth) < 0.0) == ((lumaEndNeg - lumaNorth) < 0.0)) {
		stepLength = 0.0;
	}

	float spanLength = (distPos + distNeg);
	distNeg = isNegCloser ? distNeg : distPos;
	float subPixelOffset = (0.5 + (distNeg * (-1.0 / spanLength))) * stepLength;

	float3 rgbFiltered = INPUT.SampleLevel(sam, float2(
		pos.x + (isHorizontalSpan ? 0.0 : subPixelOffset),
		pos.y + (isHorizontalSpan ? subPixelOffset : 0.0)), 0).xyz;

	return BlendFxaaColors(rgbAccum, rgbFiltered, blendSubpix);
}

#endif // FXAA_SLANGI
