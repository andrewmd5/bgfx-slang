// SMAA - Subpixel Morphological Anti-Aliasing
// Ported from the original implementation by Jorge Jimenez et al.
// http://www.iryoku.com/smaa/

/**
 * Copyright (C) 2013 Jorge Jimenez (jorge@iryoku.com)
 * Copyright (C) 2013 Jose I. Echevarria (joseignacioechevarria@gmail.com)
 * Copyright (C) 2013 Belen Masia (bmasia@unizar.es)
 * Copyright (C) 2013 Fernando Navarro (fernandn@microsoft.com)
 * Copyright (C) 2013 Diego Gutierrez (diegog@unizar.es)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is furnished to
 * do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software. As clarification, there
 * is no requirement that the copyright notice and permission be included in
 * binary distributions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 *                  _______  ___  ___       ___           ___
 *                 /       ||   \/   |     /   \         /   \
 *                |   (---- |  \  /  |    /  ^  \       /  ^  \
 *                 \   \    |  |\/|  |   /  /_\  \     /  /_\  \
 *              ----)   |   |  |  |  |  /  _____  \   /  _____  \
 *             |_______/    |__|  |__| /__/     \__\ /__/     \__\
 *
 *                               E N H A N C E D
 *       S U B P I X E L   M O R P H O L O G I C A L   A N T I A L I A S I N G
 *
 *                         http://www.iryoku.com/smaa/
 *
 * The shader has three passes, chained together as follows:
 *
 *                           |input|------------------+
 *                              v                     |
 *                    [ SMAA*EdgeDetection ]          |
 *                              v                     |
 *                          |edgesTex|                |
 *                              v                     |
 *              [ SMAABlendingWeightCalculation ]     |
 *                              v                     |
 *                          |blendTex|                |
 *                              v                     |
 *                [ SMAANeighborhoodBlending ] <------+
 *                              v
 *                           |output|
 *
 * Edge detection methods available:
 * - Depth: Usually fastest but may miss some edges
 * - Luma: More expensive than depth but catches visible edges depth can miss
 * - Color: Most expensive but catches chroma-only edges
 *
 * Available quality presets:
 *     SMAA_PRESET_LOW          (60% quality)
 *     SMAA_PRESET_MEDIUM       (80% quality)
 *     SMAA_PRESET_HIGH         (95% quality)
 *     SMAA_PRESET_ULTRA        (99% quality)
 */

#ifndef SMAA_SLANGI
#define SMAA_SLANGI

//-----------------------------------------------------------------------------
// Quality Presets

#if defined(SMAA_PRESET_LOW)
#define SMAA_THRESHOLD 0.15
#define SMAA_MAX_SEARCH_STEPS 4
#define SMAA_DISABLE_DIAG_DETECTION
#define SMAA_DISABLE_CORNER_DETECTION
#elif defined(SMAA_PRESET_MEDIUM)
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 8
#define SMAA_DISABLE_DIAG_DETECTION
#define SMAA_DISABLE_CORNER_DETECTION
#elif defined(SMAA_PRESET_HIGH)
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 16
#define SMAA_MAX_SEARCH_STEPS_DIAG 8
#define SMAA_CORNER_ROUNDING 25
#elif defined(SMAA_PRESET_ULTRA)
#define SMAA_THRESHOLD 0.05
#define SMAA_MAX_SEARCH_STEPS 32
#define SMAA_MAX_SEARCH_STEPS_DIAG 16
#define SMAA_CORNER_ROUNDING 25
#endif

//-----------------------------------------------------------------------------
// Configurable Defines

#ifndef SMAA_THRESHOLD
#define SMAA_THRESHOLD 0.1
#endif

#ifndef SMAA_DEPTH_THRESHOLD
#define SMAA_DEPTH_THRESHOLD (0.1 * SMAA_THRESHOLD)
#endif

#ifndef SMAA_MAX_SEARCH_STEPS
#define SMAA_MAX_SEARCH_STEPS 16
#endif

#ifndef SMAA_MAX_SEARCH_STEPS_DIAG
#define SMAA_MAX_SEARCH_STEPS_DIAG 8
#endif

#ifndef SMAA_CORNER_ROUNDING
#define SMAA_CORNER_ROUNDING 25
#endif

#ifndef SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR
#define SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR 2.0
#endif

//-----------------------------------------------------------------------------
// Texture Access Defines

#ifndef SMAA_AREATEX_SELECT
#define SMAA_AREATEX_SELECT(sample) sample.rg
#endif

#ifndef SMAA_SEARCHTEX_SELECT
#define SMAA_SEARCHTEX_SELECT(sample) sample.r
#endif

#ifndef SMAA_DECODE_VELOCITY
#define SMAA_DECODE_VELOCITY(sample) sample.rg
#endif

//-----------------------------------------------------------------------------
// Non-Configurable Defines

#define SMAA_AREATEX_MAX_DISTANCE 16
#define SMAA_AREATEX_MAX_DISTANCE_DIAG 20
#define SMAA_AREATEX_PIXEL_SIZE (1.0 / float2(160.0, 560.0))
#define SMAA_AREATEX_SUBTEX_SIZE (1.0 / 7.0)
#define SMAA_SEARCHTEX_SIZE float2(66.0, 33.0)
#define SMAA_SEARCHTEX_PACKED_SIZE float2(64.0, 16.0)
#define SMAA_CORNER_ROUNDING_NORM (float(SMAA_CORNER_ROUNDING) / 100.0)

//-----------------------------------------------------------------------------
// Porting Functions

#define SMAATexture2D(tex) Texture2D tex
#define SMAATexturePass2D(tex) tex
#define SMAASampleLevelZero(tex, coord) tex.SampleLevel(SMAA_LINEAR_SAMPLER, coord, 0)
#define SMAASampleLevelZeroOffset(tex, coord, offset) tex.SampleLevel(SMAA_LINEAR_SAMPLER, coord, 0, offset)
#define SMAASample(tex, coord) tex.SampleLevel(SMAA_LINEAR_SAMPLER, coord, 0)
#define SMAASamplePoint(tex, coord) tex.SampleLevel(SMAA_POINT_SAMPLER, coord, 0)
#define SMAA_FLATTEN [flatten]
#define SMAA_BRANCH [branch]

//-----------------------------------------------------------------------------
// Utility Functions

void SMAAMovc(bool2 cond, inout float2 variable, float2 value) {
	SMAA_FLATTEN if (cond.x) variable.x = value.x;
	SMAA_FLATTEN if (cond.y) variable.y = value.y;
}

void SMAAMovc(bool4 cond, inout float4 variable, float4 value) {
	SMAAMovc(cond.xy, variable.xy, value.xy);
	SMAAMovc(cond.zw, variable.zw, value.zw);
}

//-----------------------------------------------------------------------------
// Edge Detection (First Pass)

float2 SMAALumaEdgeDetectionPS(float2 texcoord, Texture2D<float4> colorTex) {
	float4 offset[3];
	offset[0] = mad(SMAA_RT_METRICS.xyxy, float4(-1.0, 0.0, 0.0, -1.0), texcoord.xyxy);
	offset[1] = mad(SMAA_RT_METRICS.xyxy, float4(1.0, 0.0, 0.0, 1.0), texcoord.xyxy);
	offset[2] = mad(SMAA_RT_METRICS.xyxy, float4(-2.0, 0.0, 0.0, -2.0), texcoord.xyxy);

	float2 threshold = float2(SMAA_THRESHOLD, SMAA_THRESHOLD);

	float3 weights = float3(0.2126, 0.7152, 0.0722);
	float L = dot(SMAASamplePoint(colorTex, texcoord).rgb, weights);

	float Lleft = dot(SMAASamplePoint(colorTex, offset[0].xy).rgb, weights);
	float Ltop = dot(SMAASamplePoint(colorTex, offset[0].zw).rgb, weights);

	float4 delta;
	delta.xy = abs(L - float2(Lleft, Ltop));
	float2 edges = step(threshold, delta.xy);

	if (dot(edges, float2(1.0, 1.0)) == 0.0) {
		return float2(0, 0);
	}

	float Lright = dot(SMAASamplePoint(colorTex, offset[1].xy).rgb, weights);
	float Lbottom = dot(SMAASamplePoint(colorTex, offset[1].zw).rgb, weights);
	delta.zw = abs(L - float2(Lright, Lbottom));

	float2 maxDelta = max(delta.xy, delta.zw);

	float Lleftleft = dot(SMAASamplePoint(colorTex, offset[2].xy).rgb, weights);
	float Ltoptop = dot(SMAASamplePoint(colorTex, offset[2].zw).rgb, weights);
	delta.zw = abs(float2(Lleft, Ltop) - float2(Lleftleft, Ltoptop));

	maxDelta = max(maxDelta.xy, delta.zw);
	float finalDelta = max(maxDelta.x, maxDelta.y);

	edges.xy *= step(finalDelta, SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta.xy);

	return edges;
}

//-----------------------------------------------------------------------------
// Diagonal Search Functions

#if !defined(SMAA_DISABLE_DIAG_DETECTION)

float2 SMAADecodeDiagBilinearAccess(float2 e) {
	e.r = e.r * abs(5.0 * e.r - 5.0 * 0.75);
	return round(e);
}

float4 SMAADecodeDiagBilinearAccess(float4 e) {
	e.rb = e.rb * abs(5.0 * e.rb - 5.0 * 0.75);
	return round(e);
}

float2 SMAASearchDiag1(Texture2D<float2> edgesTex, float2 texcoord, float2 dir, out float2 e) {
	float4 coord = float4(texcoord, -1.0, 1.0);
	float3 t = float3(SMAA_RT_METRICS.xy, 1.0);
	while (coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) &&
		coord.w > 0.9) {
		coord.xyz = mad(t, float3(dir, 1.0), coord.xyz);
		e = SMAASampleLevelZero(edgesTex, coord.xy).rg;
		coord.w = dot(e, float2(0.5, 0.5));
	}
	return coord.zw;
}

float2 SMAASearchDiag2(Texture2D<float2> edgesTex, float2 texcoord, float2 dir, out float2 e) {
	float4 coord = float4(texcoord, -1.0, 1.0);
	coord.x += 0.25 * SMAA_RT_METRICS.x;
	float3 t = float3(SMAA_RT_METRICS.xy, 1.0);
	while (coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) &&
		coord.w > 0.9) {
		coord.xyz = mad(t, float3(dir, 1.0), coord.xyz);
		e = SMAASampleLevelZero(edgesTex, coord.xy).rg;
		e = SMAADecodeDiagBilinearAccess(e);
		coord.w = dot(e, float2(0.5, 0.5));
	}
	return coord.zw;
}

float2 SMAAAreaDiag(Texture2D<float4> areaTex, float2 dist, float2 e, float offset) {
	float2 texcoord = mad(float2(SMAA_AREATEX_MAX_DISTANCE_DIAG, SMAA_AREATEX_MAX_DISTANCE_DIAG), e, dist);

	texcoord = mad(SMAA_AREATEX_PIXEL_SIZE, texcoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);

	texcoord.x += 0.5;

	texcoord.y += SMAA_AREATEX_SUBTEX_SIZE * offset;

	return SMAA_AREATEX_SELECT(SMAASampleLevelZero(areaTex, texcoord));
}

float2 SMAACalculateDiagWeights(Texture2D<float2> edgesTex, Texture2D<float4> areaTex, float2 texcoord, float2 e, float4 subsampleIndices) {
	float2 weights = float2(0.0, 0.0);

	float4 d;
	float2 end;
	if (e.r > 0.0) {
		d.xz = SMAASearchDiag1(SMAATexturePass2D(edgesTex), texcoord, float2(-1.0, 1.0), end);
		d.x += float(end.y > 0.9);
	} else
		d.xz = float2(0.0, 0.0);
	d.yw = SMAASearchDiag1(SMAATexturePass2D(edgesTex), texcoord, float2(1.0, -1.0), end);

	SMAA_BRANCH
		if (d.x + d.y > 2.0) {
			float4 coords = mad(float4(-d.x + 0.25, d.x, d.y, -d.y - 0.25), SMAA_RT_METRICS.xyxy, texcoord.xyxy);
			float4 c;
			c.xy = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(-1, 0)).rg;
			c.zw = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2(1, 0)).rg;
			c.yxwz = SMAADecodeDiagBilinearAccess(c.xyzw);

			float2 cc = mad(float2(2.0, 2.0), c.xz, c.yw);

			SMAAMovc(bool2(step(0.9, d.zw)), cc, float2(0.0, 0.0));

			weights += SMAAAreaDiag(SMAATexturePass2D(areaTex), d.xy, cc, subsampleIndices.z);
		}

	d.xz = SMAASearchDiag2(SMAATexturePass2D(edgesTex), texcoord, float2(-1.0, -1.0), end);
	if (SMAASampleLevelZeroOffset(edgesTex, texcoord, int2(1, 0)).r > 0.0) {
		d.yw = SMAASearchDiag2(SMAATexturePass2D(edgesTex), texcoord, float2(1.0, 1.0), end);
		d.y += float(end.y > 0.9);
	} else
		d.yw = float2(0.0, 0.0);

	SMAA_BRANCH
		if (d.x + d.y > 2.0) {
			float4 coords = mad(float4(-d.x, -d.x, d.y, d.y), SMAA_RT_METRICS.xyxy, texcoord.xyxy);
			float4 c;
			c.x = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(-1, 0)).g;
			c.y = SMAASampleLevelZeroOffset(edgesTex, coords.xy, int2(0, -1)).r;
			c.zw = SMAASampleLevelZeroOffset(edgesTex, coords.zw, int2(1, 0)).gr;
			float2 cc = mad(float2(2.0, 2.0), c.xz, c.yw);

			SMAAMovc(bool2(step(0.9, d.zw)), cc, float2(0.0, 0.0));

			weights += SMAAAreaDiag(SMAATexturePass2D(areaTex), d.xy, cc, subsampleIndices.w).gr;
		}

	return weights;
}
#endif

//-----------------------------------------------------------------------------
// Horizontal/Vertical Search Functions

float SMAASearchLength(Texture2D<float> searchTex, float2 e, float offset) {
	float2 scale = SMAA_SEARCHTEX_SIZE * float2(0.5, -1.0);
	float2 bias = SMAA_SEARCHTEX_SIZE * float2(offset, 1.0);

	scale += float2(-1.0, 1.0);
	bias += float2(0.5, -0.5);

	scale *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;
	bias *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;

	return SMAA_SEARCHTEX_SELECT(SMAASampleLevelZero(searchTex, mad(scale, e, bias)));
}

float SMAASearchXLeft(Texture2D<float2> edgesTex, Texture2D<float> searchTex, float2 texcoord, float end) {
	float2 e = float2(0.0, 1.0);
	while (texcoord.x > end &&
		e.g > 0.8281 &&
		e.r == 0.0) {
		e = SMAASampleLevelZero(edgesTex, texcoord).rg;
		texcoord = mad(-float2(2.0, 0.0), SMAA_RT_METRICS.xy, texcoord);
	}

	float offset = mad(-(255.0 / 127.0), SMAASearchLength(SMAATexturePass2D(searchTex), e, 0.0), 3.25);
	return mad(SMAA_RT_METRICS.x, offset, texcoord.x);
}

float SMAASearchXRight(Texture2D<float2> edgesTex, Texture2D<float> searchTex, float2 texcoord, float end) {
	float2 e = float2(0.0, 1.0);
	while (texcoord.x < end &&
		e.g > 0.8281 &&
		e.r == 0.0) {
		e = SMAASampleLevelZero(edgesTex, texcoord).rg;
		texcoord = mad(float2(2.0, 0.0), SMAA_RT_METRICS.xy, texcoord);
	}
	float offset = mad(-(255.0 / 127.0), SMAASearchLength(SMAATexturePass2D(searchTex), e, 0.5), 3.25);
	return mad(-SMAA_RT_METRICS.x, offset, texcoord.x);
}

float SMAASearchYUp(Texture2D<float2> edgesTex, Texture2D<float> searchTex, float2 texcoord, float end) {
	float2 e = float2(1.0, 0.0);
	while (texcoord.y > end &&
		e.r > 0.8281 &&
		e.g == 0.0) {
		e = SMAASampleLevelZero(edgesTex, texcoord).rg;
		texcoord = mad(-float2(0.0, 2.0), SMAA_RT_METRICS.xy, texcoord);
	}
	float offset = mad(-(255.0 / 127.0), SMAASearchLength(SMAATexturePass2D(searchTex), e.gr, 0.0), 3.25);
	return mad(SMAA_RT_METRICS.y, offset, texcoord.y);
}

float SMAASearchYDown(Texture2D<float2> edgesTex, Texture2D<float> searchTex, float2 texcoord, float end) {
	float2 e = float2(1.0, 0.0);
	while (texcoord.y < end &&
		e.r > 0.8281 &&
		e.g == 0.0) {
		e = SMAASampleLevelZero(edgesTex, texcoord).rg;
		texcoord = mad(float2(0.0, 2.0), SMAA_RT_METRICS.xy, texcoord);
	}
	float offset = mad(-(255.0 / 127.0), SMAASearchLength(SMAATexturePass2D(searchTex), e.gr, 0.5), 3.25);
	return mad(-SMAA_RT_METRICS.y, offset, texcoord.y);
}

float2 SMAAArea(Texture2D<float4> areaTex, float2 dist, float e1, float e2, float offset) {
	float2 texcoord = mad(float2(SMAA_AREATEX_MAX_DISTANCE, SMAA_AREATEX_MAX_DISTANCE), round(4.0 * float2(e1, e2)), dist);

	texcoord = mad(SMAA_AREATEX_PIXEL_SIZE, texcoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);

	texcoord.y = mad(SMAA_AREATEX_SUBTEX_SIZE, offset, texcoord.y);

	return SMAA_AREATEX_SELECT(SMAASampleLevelZero(areaTex, texcoord));
}

//-----------------------------------------------------------------------------
// Corner Detection Functions

void SMAADetectHorizontalCornerPattern(Texture2D<float2> edgesTex, inout float2 weights, float4 texcoord, float2 d) {
#if !defined(SMAA_DISABLE_CORNER_DETECTION)
	float2 leftRight = step(d.xy, d.yx);
	float2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight;

	rounding /= leftRight.x + leftRight.y;

	float2 factor = float2(1.0, 1.0);
	factor.x -= rounding.x * SMAASampleLevelZeroOffset(edgesTex, texcoord.xy, int2(0, 1)).r;
	factor.x -= rounding.y * SMAASampleLevelZeroOffset(edgesTex, texcoord.zw, int2(1, 1)).r;
	factor.y -= rounding.x * SMAASampleLevelZeroOffset(edgesTex, texcoord.xy, int2(0, -2)).r;
	factor.y -= rounding.y * SMAASampleLevelZeroOffset(edgesTex, texcoord.zw, int2(1, -2)).r;

	weights *= saturate(factor);
#endif
}

void SMAADetectVerticalCornerPattern(Texture2D<float2> edgesTex, inout float2 weights, float4 texcoord, float2 d) {
#if !defined(SMAA_DISABLE_CORNER_DETECTION)
	float2 leftRight = step(d.xy, d.yx);
	float2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight;

	rounding /= leftRight.x + leftRight.y;

	float2 factor = float2(1.0, 1.0);
	factor.x -= rounding.x * SMAASampleLevelZeroOffset(edgesTex, texcoord.xy, int2(1, 0)).g;
	factor.x -= rounding.y * SMAASampleLevelZeroOffset(edgesTex, texcoord.zw, int2(1, 1)).g;
	factor.y -= rounding.x * SMAASampleLevelZeroOffset(edgesTex, texcoord.xy, int2(-2, 0)).g;
	factor.y -= rounding.y * SMAASampleLevelZeroOffset(edgesTex, texcoord.zw, int2(-2, 1)).g;

	weights *= saturate(factor);
#endif
}

//-----------------------------------------------------------------------------
// Blending Weight Calculation (Second Pass)

float4 SMAABlendingWeightCalculationPS(
	float2 texcoord,
	Texture2D<float2> edgesTex,
	Texture2D<float4> areaTex,
	Texture2D<float> searchTex,
	float4 subsampleIndices
) {
	float2 pixcoord = texcoord * SMAA_RT_METRICS.zw;

	float4 offset[3];
	offset[0] = mad(SMAA_RT_METRICS.xyxy, float4(-0.25, -0.125, 1.25, -0.125), texcoord.xyxy);
	offset[1] = mad(SMAA_RT_METRICS.xyxy, float4(-0.125, -0.25, -0.125, 1.25), texcoord.xyxy);

	offset[2] = mad(SMAA_RT_METRICS.xxyy,
		float4(-2.0, 2.0, -2.0, 2.0) * float(SMAA_MAX_SEARCH_STEPS),
		float4(offset[0].xz, offset[1].yw));

	float4 weights = float4(0.0, 0.0, 0.0, 0.0);

	float2 e = SMAASample(edgesTex, texcoord).rg;

	SMAA_BRANCH
		if (e.g > 0.0) {
#if !defined(SMAA_DISABLE_DIAG_DETECTION)
			weights.rg = SMAACalculateDiagWeights(SMAATexturePass2D(edgesTex), SMAATexturePass2D(areaTex), texcoord, e, subsampleIndices);

			SMAA_BRANCH
				if (weights.r == -weights.g) {
#endif

					float2 d;

					float3 coords;
					coords.x = SMAASearchXLeft(SMAATexturePass2D(edgesTex), SMAATexturePass2D(searchTex), offset[0].xy, offset[2].x);
					coords.y = offset[1].y;
					d.x = coords.x;

					float e1 = SMAASampleLevelZero(edgesTex, coords.xy).r;

					coords.z = SMAASearchXRight(SMAATexturePass2D(edgesTex), SMAATexturePass2D(searchTex), offset[0].zw, offset[2].y);
					d.y = coords.z;

					d = abs(round(mad(SMAA_RT_METRICS.zz, d, -pixcoord.xx)));

					float2 sqrt_d = sqrt(d);

					float e2 = SMAASampleLevelZeroOffset(edgesTex, coords.zy, int2(1, 0)).r;

					weights.rg = SMAAArea(SMAATexturePass2D(areaTex), sqrt_d, e1, e2, subsampleIndices.y);

					coords.y = texcoord.y;
					SMAADetectHorizontalCornerPattern(SMAATexturePass2D(edgesTex), weights.rg, coords.xyzy, d);

#if !defined(SMAA_DISABLE_DIAG_DETECTION)
				} else
					e.r = 0.0;
#endif
		}

	SMAA_BRANCH
		if (e.r > 0.0) {
			float2 d;

			float3 coords;
			coords.y = SMAASearchYUp(SMAATexturePass2D(edgesTex), SMAATexturePass2D(searchTex), offset[1].xy, offset[2].z);
			coords.x = offset[0].x;
			d.x = coords.y;

			float e1 = SMAASampleLevelZero(edgesTex, coords.xy).g;

			coords.z = SMAASearchYDown(SMAATexturePass2D(edgesTex), SMAATexturePass2D(searchTex), offset[1].zw, offset[2].w);
			d.y = coords.z;

			d = abs(round(mad(SMAA_RT_METRICS.ww, d, -pixcoord.yy)));

			float2 sqrt_d = sqrt(d);

			float e2 = SMAASampleLevelZeroOffset(edgesTex, coords.xz, int2(0, 1)).g;

			weights.ba = SMAAArea(SMAATexturePass2D(areaTex), sqrt_d, e1, e2, subsampleIndices.x);

			coords.x = texcoord.x;
			SMAADetectVerticalCornerPattern(SMAATexturePass2D(edgesTex), weights.ba, coords.xyxz, d);
		}

	return weights;
}

//-----------------------------------------------------------------------------
// Neighborhood Blending (Third Pass)

float4 SMAANeighborhoodBlendingPS(
	float2 texcoord,
	Texture2D<float4> colorTex,
	Texture2D<float4> blendTex
) {
	float4 offset = mad(SMAA_RT_METRICS.xyxy, float4(1.0, 0.0, 0.0, 1.0), texcoord.xyxy);

	float4 a;
	a.x = SMAASample(blendTex, offset.xy).a;
	a.y = SMAASample(blendTex, offset.zw).g;
	a.wz = SMAASample(blendTex, texcoord).xz;

	SMAA_BRANCH
		if (dot(a, float4(1.0, 1.0, 1.0, 1.0)) < 1e-5) {
			float4 color = SMAASampleLevelZero(colorTex, texcoord);
			return color;
		} else {
			bool h = max(a.x, a.z) > max(a.y, a.w);

			float4 blendingOffset = float4(0.0, a.y, 0.0, a.w);
			float2 blendingWeight = a.yw;
			SMAAMovc(bool4(h, h, h, h), blendingOffset, float4(a.x, 0.0, a.z, 0.0));
			SMAAMovc(bool2(h, h), blendingWeight, a.xz);
			blendingWeight /= dot(blendingWeight, float2(1.0, 1.0));

			float4 blendingCoord = mad(blendingOffset, float4(SMAA_RT_METRICS.xy, -SMAA_RT_METRICS.xy), texcoord.xyxy);

			float4 color = blendingWeight.x * SMAASampleLevelZero(colorTex, blendingCoord.xy);
			color += blendingWeight.y * SMAASampleLevelZero(colorTex, blendingCoord.zw);

			return color;
		}
}

#endif // SMAA_SLANGI
