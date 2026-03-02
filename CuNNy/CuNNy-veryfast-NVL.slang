// CuNNy - https://github.com/funnyplanter/CuNNy
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import bgfx;

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH * 2", "INPUT_HEIGHT * 2")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam1;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
Texture2D t0;
[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> t0_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
Texture2D t1;
[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> t1_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
Texture2D t2;
[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> t2_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
Texture2D t3;
[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> t3_UAV;


#define L0(x, y) half(dot(half3(0.299h, 0.587h, 0.114h), (half3)(INPUT.SampleLevel(sam, pos + float2(x, y) * pt, 0).rgb)))

[bgfx::EFFECT("CuNNy veryfast", 2)]
[bgfx::CATEGORY("Neural Network")]
[bgfx::DESCRIPTION("CuNNy veryfast neural network 2x upscaler")]
[bgfx::FP16]
[bgfx::PASS(1, "in (1x8)")]
[bgfx::PASS_IO("INPUT", "t0, t1")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid : SV_DispatchThreadID)
{
	uint2 gxy = Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8))
	    + (tid.xy / 8) * 8;
	uint2 inputSize = GetInputSize();
	if (gxy.x >= inputSize.x || gxy.y >= inputSize.y) return;
	float2 pt = GetInputPt();
	float2 pos = (float2(gxy) + 0.5) * pt;
	half s0_0_0, s0_0_1, s0_0_2, s0_1_0, s0_1_1, s0_1_2, s0_2_0, s0_2_1, s0_2_2;
	half4 r0 = half4(1.026e-03h, -2.981e-03h, 2.268e-03h, -1.057e-03h);
	half4 r1 = half4(-1.665e-03h, 3.286e-03h, -3.161e-03h, -9.035e-04h);
	s0_0_0 = L0(-1.0, -1.0); s0_0_1 = L0(0.0, -1.0); s0_0_2 = L0(1.0, -1.0);
	s0_1_0 = L0(-1.0, 0.0); s0_1_1 = L0(0.0, 0.0); s0_1_2 = L0(1.0, 0.0);
	s0_2_0 = L0(-1.0, 1.0); s0_2_1 = L0(0.0, 1.0); s0_2_2 = L0(1.0, 1.0);
	r0 = mad(s0_0_0, half4(4.998e-03h, -1.996e-02h, 2.062e-02h, -1.826e-02h), r0);
	r1 = mad(s0_0_0, half4(-5.265e-03h, 2.075e-03h, 2.429e-02h, 3.332e-02h), r1);
	r0 = mad(s0_0_1, half4(2.804e-02h, 4.874e-02h, 3.034e-02h, 7.068e-03h), r0);
	r1 = mad(s0_0_1, half4(2.430e-02h, -1.450e-01h, 1.032e-02h, 4.446e-01h), r1);
	r0 = mad(s0_0_2, half4(1.752e-02h, -4.398e-02h, -1.954e-02h, 1.824e-02h), r0);
	r1 = mad(s0_0_2, half4(-2.447e-02h, 3.411e-02h, -3.408e-02h, -8.259e-02h), r1);
	r0 = mad(s0_1_0, half4(3.185e-02h, -3.662e-01h, -1.870e-02h, 8.200e-01h), r0);
	r1 = mad(s0_1_0, half4(-7.897e-03h, 1.151e-01h, -2.607e-01h, -3.053e-02h), r1);
	r0 = mad(s0_1_1, half4(-9.682e-02h, 4.676e-01h, -1.874e-01h, -8.066e-01h), r0);
	r1 = mad(s0_1_1, half4(-8.105e-01h, 4.792e-01h, 8.066e-01h, 9.627e-02h), r1);
	r0 = mad(s0_1_2, half4(4.775e-01h, -8.455e-02h, 8.943e-02h, -2.106e-02h), r0);
	r1 = mad(s0_1_2, half4(8.912e-02h, -9.258e-02h, 3.846e-02h, -7.281e-02h), r1);
	r0 = mad(s0_2_0, half4(-1.763e-02h, -2.789e-01h, 4.132e-01h, -2.679e-02h), r0);
	r1 = mad(s0_2_0, half4(8.231e-03h, 8.443e-02h, -2.719e-01h, 4.610e-04h), r1);
	r0 = mad(s0_2_1, half4(3.664e-03h, 2.998e-01h, -6.781e-02h, 2.461e-02h), r0);
	r1 = mad(s0_2_1, half4(7.667e-01h, -1.057e-02h, -2.979e-01h, 5.408e-02h), r1);
	r0 = mad(s0_2_2, half4(-6.392e-02h, -1.812e-02h, 1.094e-02h, 2.662e-03h), r0);
	r1 = mad(s0_2_2, half4(-3.848e-02h, 2.277e-02h, -1.486e-02h, -1.206e-02h), r1);
	r0 = max(r0, 0.0h);
	t0_UAV[gxy] = float4(r0);
	r1 = max(r1, 0.0h);
	t1_UAV[gxy] = float4(r1);
}

#undef L0

#define L0(x, y) (half4)(t0.SampleLevel(sam, pos + float2(x, y) * pt, 0))
#define L1(x, y) (half4)(t1.SampleLevel(sam, pos + float2(x, y) * pt, 0))

[bgfx::PASS(2, "conv1 (8x8)")]
[bgfx::PASS_IO("t0, t1", "t2, t3")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid : SV_DispatchThreadID)
{
	uint2 gxy = Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8))
	    + (tid.xy / 8) * 8;
	uint2 inputSize = GetInputSize();
	if (gxy.x >= inputSize.x || gxy.y >= inputSize.y) return;
	float2 pt = GetInputPt();
	float2 pos = (float2(gxy) + 0.5) * pt;
	half4 s0_0_0, s0_0_1, s0_0_2, s0_1_0, s0_1_1, s0_1_2, s0_2_0, s0_2_1, s0_2_2, s1_0_0, s1_0_1, s1_0_2, s1_1_0, s1_1_1, s1_1_2, s1_2_0, s1_2_1, s1_2_2;
	half4 r0 = half4(0.0h, 0.0h, 0.0h, 0.0h);
	half4 r1 = half4(0.0h, 0.0h, 0.0h, 0.0h);
	s0_0_0 = L0(-1.0, -1.0); s0_0_1 = L0(0.0, -1.0); s0_0_2 = L0(1.0, -1.0);
	s0_1_0 = L0(-1.0, 0.0); s0_1_1 = L0(0.0, 0.0); s0_1_2 = L0(1.0, 0.0);
	s0_2_0 = L0(-1.0, 1.0); s0_2_1 = L0(0.0, 1.0); s0_2_2 = L0(1.0, 1.0);
	s1_0_0 = L1(-1.0, -1.0); s1_0_1 = L1(0.0, -1.0); s1_0_2 = L1(1.0, -1.0);
	s1_1_0 = L1(-1.0, 0.0); s1_1_1 = L1(0.0, 0.0); s1_1_2 = L1(1.0, 0.0);
	s1_2_0 = L1(-1.0, 1.0); s1_2_1 = L1(0.0, 1.0); s1_2_2 = L1(1.0, 1.0);
	r0 = MulAdd(s0_0_0, half4x4(3.294e-01h, 4.686e-02h, -1.020e-01h, -3.003e-01h, -9.869e-02h, 3.719e-02h, -7.138e-03h, 2.881e-01h, 3.220e-01h, -6.357e-02h, -6.724e-02h, 7.248e-02h, -4.531e-02h, 1.142e-02h, -1.283e-02h, 3.312e-03h), r0);
	r1 = MulAdd(s0_0_0, half4x4(-1.897e-02h, 1.714e-01h, 7.384e-02h, 5.059e-01h, 1.216e-02h, -7.572e-02h, -1.294e-01h, 1.965e-02h, -2.641e-02h, 3.440e-02h, -3.206e-01h, 7.578e-02h, 4.822e-02h, -5.309e-02h, 4.980e-02h, -2.297e-01h), r1);
	r0 = MulAdd(s0_0_1, half4x4(-5.258e-02h, -4.673e-02h, -2.457e-01h, 5.254e-01h, -9.082e-01h, -4.544e-01h, -9.198e-02h, 1.782e-01h, -2.241e-01h, -8.426e-02h, -1.917e-01h, 1.895e-01h, 1.256e-01h, 2.920e-01h, -1.948e-01h, 1.098e-02h), r0);
	r1 = MulAdd(s0_0_1, half4x4(-1.061e-01h, 3.819e-01h, 9.685e-02h, -5.909e+00h, -8.986e-03h, -5.059e-01h, -6.348e-01h, -4.566e-01h, 1.974e-02h, -3.641e-01h, -6.473e-02h, -7.168e-01h, 8.116e-02h, -9.474e-02h, 6.230e-01h, 1.415e-01h), r1);
	r0 = MulAdd(s0_0_2, half4x4(8.010e-02h, -4.801e-02h, 6.959e-02h, -1.714e-01h, -1.210e-02h, -3.453e-02h, 7.624e-02h, 1.421e-01h, -8.770e-01h, 2.378e-01h, -8.130e-01h, 5.840e-01h, 2.632e-02h, 1.018e-01h, -1.675e-01h, 2.058e-01h), r0);
	r1 = MulAdd(s0_0_2, half4x4(1.740e-02h, -2.677e-02h, -6.515e-02h, -1.401e+01h, -4.665e-01h, -4.795e-02h, -1.572e-01h, -2.678e+00h, -5.329e-01h, -4.122e-01h, 2.206e-01h, -1.176e+01h, 9.385e-02h, 1.746e-01h, 1.694e-01h, -2.664e+00h), r1);
	r0 = MulAdd(s0_1_0, half4x4(-3.246e-02h, 3.232e-01h, -4.307e-01h, 2.822e-01h, 3.894e-03h, -3.894e-02h, 1.196e-01h, -2.086e-01h, 1.110e-01h, -3.645e-03h, 1.001e-02h, -5.595e-02h, -4.108e-02h, 5.774e-02h, -1.192e-02h, -5.918e-02h), r0);
	r1 = MulAdd(s0_1_0, half4x4(-1.642e-01h, -1.149e+00h, 2.587e-01h, -7.493e-01h, 3.742e-02h, 2.881e-01h, 1.076e-01h, 3.382e-02h, -7.062e-02h, 6.909e-02h, -8.023e-02h, -3.361e-02h, 6.265e-02h, -4.848e-02h, 1.150e-01h, -5.995e-02h), r1);
	r0 = MulAdd(s0_1_1, half4x4(2.838e-01h, -5.586e-01h, 6.230e-01h, -4.002e-01h, 3.255e-01h, -1.077e-01h, -5.773e-01h, 1.763e-01h, -2.401e-01h, 1.249e-01h, 3.205e-01h, -7.300e-02h, 6.839e-03h, 3.467e-01h, 7.362e-01h, -7.519e-01h), r0);
	r1 = MulAdd(s0_1_1, half4x4(-2.741e-01h, 9.805e-01h, -1.780e-01h, 7.361e-01h, -7.676e-01h, 1.490e-01h, 4.947e-01h, 9.604e-02h, -2.708e-01h, 6.055e-01h, -2.115e-01h, 3.844e-01h, 1.176e+00h, 1.091e-01h, -3.643e-01h, -2.254e-01h), r1);
	r0 = MulAdd(s0_1_2, half4x4(4.413e-02h, 2.526e-02h, 7.251e-02h, 5.943e-02h, 3.701e-01h, -4.031e-02h, -1.190e-01h, -9.990e-02h, -3.710e-02h, 3.842e-02h, -3.715e-02h, -4.212e-01h, 5.410e-01h, 9.975e-03h, 5.684e-01h, 1.869e-01h), r0);
	r1 = MulAdd(s0_1_2, half4x4(8.257e-02h, 4.720e-02h, 2.332e-02h, -2.108e-01h, 1.474e-02h, 2.510e-01h, 1.372e-01h, 2.900e-01h, 9.461e-03h, 1.588e-01h, 6.632e-02h, 3.074e-01h, -1.391e-01h, 4.718e-01h, -4.072e-02h, -4.638e-01h), r1);
	r0 = MulAdd(s0_2_0, half4x4(2.017e-02h, -6.963e-02h, -2.059e-01h, 5.522e-02h, 3.876e-03h, -2.700e-02h, -7.056e-02h, -8.622e-02h, -8.871e-02h, -2.346e-02h, 3.707e-02h, -5.105e-02h, -5.580e-02h, 1.536e-02h, -6.917e-02h, 1.723e-01h), r0);
	r1 = MulAdd(s0_2_0, half4x4(1.041e-01h, -3.692e-01h, -1.067e-01h, -4.372e-01h, 7.756e-02h, -7.766e-02h, -2.291e-02h, 7.570e-02h, 5.341e-02h, -2.788e-02h, -8.032e-02h, 3.647e-02h, 4.171e-02h, -1.244e-01h, -5.408e-02h, 1.956e-02h), r1);
	r0 = MulAdd(s0_2_1, half4x4(2.526e-01h, -8.803e-02h, -3.521e-02h, -1.952e-01h, 9.958e-02h, 1.918e-02h, 9.500e-02h, -1.255e-01h, 9.954e-02h, 8.401e-02h, 1.860e-01h, -7.880e-02h, -1.647e-01h, -8.276e-04h, 5.116e-02h, 2.928e-01h), r0);
	r1 = MulAdd(s0_2_1, half4x4(5.802e-01h, 1.341e-01h, 1.434e-02h, -1.704e-01h, 1.346e-01h, 1.339e-01h, 9.508e-02h, -3.802e-02h, -3.687e-02h, 2.012e-01h, 2.227e-01h, -5.216e-02h, 2.646e-01h, -3.975e-01h, -2.920e-01h, -1.163e-01h), r1);
	r0 = MulAdd(s0_2_2, half4x4(5.494e-04h, 1.475e-03h, 5.538e-03h, 7.359e-02h, 1.837e-01h, 6.217e-02h, 1.074e-01h, 5.277e-03h, 1.910e-02h, 5.994e-02h, 5.796e-02h, -1.437e-01h, -5.969e-02h, 1.504e-02h, 5.454e-03h, 1.468e-01h), r0);
	r1 = MulAdd(s0_2_2, half4x4(-6.347e-02h, -6.738e-02h, -2.679e-02h, 6.836e-03h, 2.155e-01h, 2.283e-01h, -1.834e-02h, -2.290e-05h, 1.763e-01h, -2.847e-02h, 3.850e-02h, -1.163e-01h, -7.949e-01h, -2.105e-01h, -2.335e-02h, -8.468e-02h), r1);
	r0 = MulAdd(s1_0_0, half4x4(-5.303e-02h, 6.088e-02h, 3.405e-02h, -2.250e-01h, -1.050e-01h, -1.489e-02h, 1.661e-01h, 2.608e-01h, 6.371e-02h, -6.136e-02h, 3.083e-02h, -2.826e-01h, -1.023e-01h, -1.921e-02h, 9.302e-02h, 1.577e-02h), r0);
	r1 = MulAdd(s1_0_0, half4x4(1.050e-01h, -8.178e-02h, 5.020e-01h, -1.824e-01h, -1.509e-01h, -8.470e-02h, -2.997e-01h, -2.193e-01h, -3.256e-02h, -5.481e-02h, 7.575e-02h, -6.707e-02h, -4.388e-02h, -1.462e-02h, -5.667e-02h, 8.515e-02h), r1);
	r0 = MulAdd(s1_0_1, half4x4(1.863e+00h, 8.300e-01h, 1.364e-01h, -3.951e-01h, 5.022e-01h, 2.851e-02h, 6.264e-01h, -1.539e-01h, 7.931e-01h, 2.568e-01h, 4.988e-01h, -4.003e-01h, 1.147e-01h, 5.882e-02h, 1.213e-01h, 4.826e-02h), r0);
	r1 = MulAdd(s1_0_1, half4x4(4.619e-01h, 5.371e-01h, 3.185e-01h, 8.274e-02h, 1.200e-01h, -1.226e-01h, -2.706e-01h, -8.163e-01h, 1.243e-01h, 5.196e-01h, 1.733e-01h, 2.327e-01h, 3.773e-03h, -8.958e-02h, -6.588e-02h, -5.215e-01h), r1);
	r0 = MulAdd(s1_0_2, half4x4(-5.725e-02h, 9.622e-02h, -1.639e-01h, 4.223e-01h, -7.787e-02h, 1.686e-01h, -1.608e-01h, 2.978e-01h, 4.661e-01h, 1.002e-01h, 2.627e-01h, -1.418e-01h, 8.262e-02h, 5.574e-02h, 3.143e-02h, 2.579e-02h), r0);
	r1 = MulAdd(s1_0_2, half4x4(-2.046e-01h, 9.959e-02h, 2.075e-01h, -2.096e+00h, -4.847e-01h, -6.149e-01h, 4.701e-02h, -5.941e+00h, 1.440e-01h, 2.179e-01h, 1.561e-01h, -3.578e+00h, -6.861e-02h, -1.618e-01h, 9.439e-03h, -1.287e+01h), r1);
	r0 = MulAdd(s1_1_0, half4x4(-9.579e-02h, 6.189e-02h, -1.159e-01h, 2.150e-01h, -4.549e-01h, -2.409e-01h, 3.925e-01h, -4.460e-01h, 1.360e-01h, -4.751e-04h, -3.381e-02h, 2.064e-01h, -1.230e-01h, -4.066e-01h, 5.518e-02h, -5.011e-01h), r0);
	r1 = MulAdd(s1_1_0, half4x4(1.352e-01h, -2.319e-01h, -1.343e-01h, -3.817e-02h, -3.801e-02h, 4.277e-01h, 4.445e-01h, 4.374e-01h, -2.427e-01h, -1.002e-01h, -1.179e-01h, 1.841e-02h, 1.593e-01h, 4.485e-01h, -2.762e-01h, 5.878e-01h), r1);
	r0 = MulAdd(s1_1_1, half4x4(7.918e-02h, 3.248e-02h, 5.526e-01h, 3.818e-01h, -5.114e-01h, 3.427e-01h, -5.737e-01h, 4.692e-01h, -1.458e-01h, 1.323e-01h, -5.878e-02h, -1.936e-01h, 8.602e-02h, -1.909e-01h, -2.575e-02h, -3.231e-01h), r0);
	r1 = MulAdd(s1_1_1, half4x4(1.096e-01h, 8.324e-02h, -1.157e+00h, -1.651e-01h, 1.479e-02h, 3.467e-01h, 1.509e-01h, 8.535e-01h, 2.386e-02h, -7.060e-01h, -1.040e-02h, 1.156e-01h, 4.657e-01h, 8.064e-01h, 3.275e-01h, 5.316e-01h), r1);
	r0 = MulAdd(s1_1_2, half4x4(-2.163e-01h, 6.235e-03h, -8.975e-02h, 2.083e-01h, 5.216e-01h, 1.365e-01h, 1.431e-01h, -4.618e-02h, 1.459e-01h, 1.150e-01h, -4.137e-02h, 9.075e-03h, -4.688e-01h, -1.238e-01h, -1.970e-01h, -3.330e-01h), r0);
	r1 = MulAdd(s1_1_2, half4x4(-7.615e-01h, -1.597e-01h, -4.504e-02h, -3.390e-01h, 1.909e-01h, 2.195e-01h, -5.178e-02h, -6.446e-01h, 3.213e-01h, -3.822e-02h, 9.009e-02h, 1.444e-01h, 6.707e-01h, 2.809e-01h, -1.399e-02h, 6.922e-01h), r1);
	r0 = MulAdd(s1_2_0, half4x4(-7.206e-02h, -1.223e-02h, -3.867e-02h, 9.155e-02h, 4.327e-01h, 1.158e-01h, -2.036e-01h, -1.259e-01h, 6.557e-02h, -1.204e-03h, 5.246e-02h, -6.929e-02h, 1.062e-01h, -4.244e-02h, -3.571e-01h, 5.444e-01h), r0);
	r1 = MulAdd(s1_2_0, half4x4(-1.416e-02h, -6.707e-02h, -1.206e-01h, 2.679e-02h, -3.135e-01h, -8.026e-02h, 3.923e-01h, -2.604e-01h, -1.131e-01h, 5.136e-02h, 6.091e-02h, -6.370e-02h, -2.769e-01h, -6.045e-01h, 2.380e-01h, -1.016e-01h), r1);
	r0 = MulAdd(s1_2_1, half4x4(-5.873e-02h, -7.936e-02h, -7.740e-02h, 9.037e-02h, 1.292e-02h, -2.422e-01h, -2.022e-01h, -5.898e-01h, -2.129e-02h, 6.206e-02h, 1.817e-02h, -7.300e-02h, -1.877e-02h, 4.453e-01h, 4.070e-01h, 7.967e-01h), r0);
	r1 = MulAdd(s1_2_1, half4x4(-1.115e-01h, -3.104e-02h, 2.083e-02h, -9.055e-02h, 4.538e-01h, 1.284e-01h, -2.979e-01h, 1.177e-01h, 1.194e-01h, -3.457e-02h, 5.920e-02h, 1.283e-01h, -1.695e-01h, -3.700e-01h, -1.649e-01h, 2.046e-01h), r1);
	r0 = MulAdd(s1_2_2, half4x4(-3.303e-02h, 2.488e-04h, -4.218e-02h, 7.275e-03h, -3.436e-02h, -5.248e-02h, 1.132e-01h, 8.247e-02h, -2.631e-02h, 1.910e-02h, 5.824e-02h, 2.078e-02h, -2.627e-01h, 9.032e-02h, 5.265e-02h, 7.366e-02h), r0);
	r1 = MulAdd(s1_2_2, half4x4(1.975e-02h, -6.391e-02h, -2.874e-02h, -5.150e-02h, 2.261e-01h, -2.319e-01h, -9.771e-02h, 4.567e-01h, 3.352e-04h, -4.777e-02h, -2.349e-02h, -1.224e-03h, -4.864e-01h, -5.346e-01h, 3.012e-02h, -3.242e-01h), r1);
	r0 = max(r0, 0.0h);
	t2_UAV[gxy] = float4(r0);
	r1 = max(r1, 0.0h);
	t3_UAV[gxy] = float4(r1);
}

#undef L0
#undef L1

#define L0(x, y) (half4)(t2.SampleLevel(sam, pos + float2(x, y) * pt, 0))
#define L1(x, y) (half4)(t3.SampleLevel(sam, pos + float2(x, y) * pt, 0))

[bgfx::PASS(3, "conv2 (8x4)")]
[bgfx::PASS_IO("t2, t3", "t0")]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass3(uint3 tid : SV_DispatchThreadID)
{
	uint2 gxy = Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8))
	    + (tid.xy / 8) * 8;
	uint2 inputSize = GetInputSize();
	if (gxy.x >= inputSize.x || gxy.y >= inputSize.y) return;
	float2 pt = GetInputPt();
	float2 pos = (float2(gxy) + 0.5) * pt;
	half4 s0_0_0, s0_0_1, s0_0_2, s0_1_0, s0_1_1, s0_1_2, s0_2_0, s0_2_1, s0_2_2, s1_0_0, s1_0_1, s1_0_2, s1_1_0, s1_1_1, s1_1_2, s1_2_0, s1_2_1, s1_2_2;
	half4 r0 = half4(0.0h, 0.0h, 0.0h, 0.0h);
	s0_0_0 = L0(-1.0, -1.0); s0_0_1 = L0(0.0, -1.0); s0_0_2 = L0(1.0, -1.0);
	s0_1_0 = L0(-1.0, 0.0); s0_1_1 = L0(0.0, 0.0); s0_1_2 = L0(1.0, 0.0);
	s0_2_0 = L0(-1.0, 1.0); s0_2_1 = L0(0.0, 1.0); s0_2_2 = L0(1.0, 1.0);
	s1_0_0 = L1(-1.0, -1.0); s1_0_1 = L1(0.0, -1.0); s1_0_2 = L1(1.0, -1.0);
	s1_1_0 = L1(-1.0, 0.0); s1_1_1 = L1(0.0, 0.0); s1_1_2 = L1(1.0, 0.0);
	s1_2_0 = L1(-1.0, 1.0); s1_2_1 = L1(0.0, 1.0); s1_2_2 = L1(1.0, 1.0);
	r0 = MulAdd(s0_0_0, half4x4(-8.148e-03h, 2.568e-02h, 4.651e-02h, -7.485e-02h, 1.790e-02h, -8.190e-02h, -1.489e-01h, 1.323e-01h, 3.400e-02h, 6.812e-02h, 3.208e-02h, -2.434e-02h, 6.154e-02h, 8.815e-02h, 6.566e-02h, 5.507e-02h), r0);
	r0 = MulAdd(s0_0_1, half4x4(3.119e-02h, -4.280e-03h, -6.519e-03h, 1.538e-01h, -2.105e-01h, -1.431e-01h, -1.406e-01h, -4.139e-01h, 8.038e-02h, -1.392e-01h, 9.856e-03h, -9.555e-02h, 1.765e-01h, 2.941e-01h, 9.466e-02h, 3.756e-01h), r0);
	r0 = MulAdd(s0_0_2, half4x4(-1.209e-01h, 4.339e-02h, -7.104e-02h, -6.860e-02h, 4.313e-02h, -1.887e-01h, 1.963e-02h, -4.690e-02h, -6.567e-02h, -1.265e-01h, -4.360e-02h, -1.146e-01h, -5.670e-02h, 1.087e-01h, -4.472e-02h, 1.739e-02h), r0);
	r0 = MulAdd(s0_1_0, half4x4(-4.968e-02h, -1.421e-01h, 3.657e-02h, -2.672e-01h, -7.897e-04h, -3.623e-01h, 3.450e-02h, -2.245e-01h, -4.632e-03h, -1.128e-01h, -1.792e-01h, 5.298e-01h, 1.125e-01h, -1.141e-01h, -8.822e-02h, 6.274e-02h), r0);
	r0 = MulAdd(s0_1_1, half4x4(-1.880e-01h, -3.701e-01h, -1.155e-01h, 3.115e-01h, 3.475e-01h, 8.071e-01h, 7.021e-01h, -3.410e-01h, -2.617e-01h, 1.043e+00h, -3.493e-01h, -2.318e-01h, -4.900e-01h, -5.969e-01h, -1.215e-01h, -3.721e-01h), r0);
	r0 = MulAdd(s0_1_2, half4x4(3.329e-01h, 1.936e-01h, 1.228e-01h, -1.891e-02h, -3.213e-01h, -4.152e-01h, -1.440e-01h, 4.134e-02h, 2.842e-01h, -5.296e-02h, 3.641e-01h, 5.137e-01h, 1.812e-01h, 8.146e-02h, 1.061e-01h, 3.798e-02h), r0);
	r0 = MulAdd(s0_2_0, half4x4(-6.376e-03h, 2.285e-01h, 5.671e-02h, -8.081e-02h, -9.302e-02h, -1.174e-01h, -1.714e-01h, 2.654e-02h, -1.334e-02h, 1.460e-01h, 5.519e-02h, -1.432e-01h, 3.235e-02h, 5.162e-02h, 3.121e-02h, 6.723e-03h), r0);
	r0 = MulAdd(s0_2_1, half4x4(1.175e-01h, -3.771e-02h, 5.432e-02h, 3.030e-01h, 1.248e-01h, 3.087e-02h, -5.464e-02h, 9.374e-02h, 1.291e-01h, 2.582e-02h, 2.026e-01h, 3.218e-02h, -3.019e-02h, -6.113e-02h, 1.022e-03h, -1.526e-02h), r0);
	r0 = MulAdd(s0_2_2, half4x4(-4.480e-02h, 4.266e-02h, -1.878e-02h, -7.446e-02h, 4.263e-02h, -1.403e-01h, -1.898e-01h, -1.598e-01h, -4.898e-02h, -1.334e-01h, -4.467e-03h, 2.087e-02h, 6.375e-03h, 8.764e-02h, 7.014e-02h, 3.828e-02h), r0);
	r0 = MulAdd(s1_0_0, half4x4(-1.823e-02h, -5.078e-02h, -4.285e-02h, 4.404e-02h, -9.971e-03h, -3.043e-02h, -1.849e-02h, 1.066e-01h, 1.313e-02h, 2.819e-02h, 6.397e-02h, -4.005e-02h, -2.264e-02h, -4.141e-02h, -6.211e-02h, 2.856e-02h), r0);
	r0 = MulAdd(s1_0_1, half4x4(-1.643e-01h, -6.951e-02h, -5.324e-02h, -1.595e-01h, 4.259e-02h, 1.606e-01h, 2.015e-02h, -3.517e-04h, 7.591e-02h, 1.665e-01h, 1.284e-01h, 1.572e-01h, -8.479e-02h, -9.076e-02h, -3.720e-02h, -7.167e-02h), r0);
	r0 = MulAdd(s1_0_2, half4x4(1.875e-01h, 4.330e-02h, 7.509e-02h, 9.155e-02h, 1.067e-01h, -9.226e-03h, 6.569e-02h, 1.057e-01h, 9.918e-02h, 2.543e-03h, 6.361e-02h, 4.849e-02h, -3.967e-02h, 9.021e-02h, -2.580e-02h, -8.976e-03h), r0);
	r0 = MulAdd(s1_1_0, half4x4(7.936e-03h, 4.667e-02h, 1.710e-01h, -5.760e-01h, 5.680e-03h, 6.270e-01h, 3.174e-01h, 4.808e-02h, 7.891e-03h, -5.142e-03h, 1.486e-02h, -1.813e-02h, -2.654e-02h, -6.394e-01h, -8.960e-02h, -4.404e-01h), r0);
	r0 = MulAdd(s1_1_1, half4x4(-9.929e-04h, -5.820e-01h, 1.195e-01h, 4.442e-01h, 9.473e-01h, -7.623e-01h, 3.154e-01h, -6.255e-01h, 4.396e-04h, 7.951e-01h, -1.909e-01h, 1.098e+00h, -2.184e-02h, -4.709e-01h, -1.576e-01h, -5.169e-01h), r0);
	r0 = MulAdd(s1_1_2, half4x4(3.076e-01h, 2.549e-01h, 2.183e-01h, 2.803e-01h, -6.310e-01h, -3.174e-01h, -4.287e-01h, -4.186e-01h, 1.036e-02h, 1.632e-01h, -9.137e-04h, -2.596e-02h, -2.581e-02h, -9.876e-03h, 6.714e-02h, 3.123e-02h), r0);
	r0 = MulAdd(s1_2_0, half4x4(7.675e-03h, 5.052e-03h, -3.337e-02h, 9.983e-02h, 1.332e-02h, 1.577e-01h, 1.304e-01h, 1.257e-01h, -6.344e-03h, 1.044e-01h, 5.069e-02h, 2.343e-02h, 8.552e-02h, -9.318e-01h, -1.662e-02h, -5.734e-01h), r0);
	r0 = MulAdd(s1_2_1, half4x4(-3.231e-02h, 9.578e-02h, -6.091e-02h, -1.283e-01h, 8.889e-02h, -7.374e-02h, 1.334e-01h, 2.598e-02h, 2.393e-01h, 8.617e-02h, 3.545e-01h, 9.125e-02h, 3.194e-01h, 6.674e-01h, -2.021e-02h, -1.412e-01h), r0);
	r0 = MulAdd(s1_2_2, half4x4(9.790e-02h, 1.380e-02h, 4.626e-02h, 9.249e-02h, 8.255e-03h, 6.021e-02h, 2.871e-04h, 1.201e-01h, 1.724e-01h, 1.096e-01h, 1.130e-01h, 1.430e-01h, -4.326e-01h, -3.163e-01h, -1.880e-01h, -1.765e-01h), r0);
	r0 = max(r0, 0.0h);
	t0_UAV[gxy] = float4(r0);
}

#undef L0
#undef L1

#define L0(x, y) (half4)(t0.SampleLevel(sam, pos + float2(x, y) * pt, 0))

[bgfx::PASS(4, "out-shuffle (4x4)")]
[bgfx::PASS_IO("t0, INPUT", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass4(uint3 tid : SV_DispatchThreadID)
{
	uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1)
	    + (tid.xy / 8) * 16;
	uint2 outputSize = GetOutputSize();
	if (gxy.x >= outputSize.x || gxy.y >= outputSize.y) return;
	float2 pt = GetInputPt();
	float2 pos = ((gxy >> 1) + 0.5) * pt;
	half4 s0_0_0, s0_0_1, s0_0_2, s0_1_0, s0_1_1, s0_1_2, s0_2_0, s0_2_1, s0_2_2;
	half4 r0 = half4(1.026e-04h, 2.907e-04h, -2.278e-04h, -8.361e-05h);
	s0_0_0 = L0(-1.0, -1.0); s0_0_1 = L0(0.0, -1.0); s0_0_2 = L0(1.0, -1.0);
	s0_1_0 = L0(-1.0, 0.0); s0_1_1 = L0(0.0, 0.0); s0_1_2 = L0(1.0, 0.0);
	s0_2_0 = L0(-1.0, 1.0); s0_2_1 = L0(0.0, 1.0); s0_2_2 = L0(1.0, 1.0);
	r0 = MulAdd(s0_0_0, half4x4(-2.078e-02h, 2.658e-02h, 5.912e-03h, -8.754e-04h, 3.267e-02h, 6.010e-03h, -8.934e-03h, -7.844e-03h, -3.699e-02h, -2.191e-02h, 1.024e-02h, 1.211e-02h, 2.276e-03h, -2.706e-02h, -1.511e-02h, -6.482e-03h), r0);
	r0 = MulAdd(s0_0_1, half4x4(4.173e-03h, -2.643e-02h, 4.702e-03h, 8.715e-03h, 1.479e-02h, -1.440e-01h, 3.235e-02h, 3.772e-02h, 1.870e-01h, 1.372e-01h, -6.517e-02h, -4.455e-02h, -1.782e-01h, 9.614e-02h, 5.090e-02h, 1.126e-02h), r0);
	r0 = MulAdd(s0_0_2, half4x4(9.667e-03h, -4.513e-04h, 6.245e-03h, 1.301e-02h, -5.169e-03h, 1.161e-02h, -1.311e-02h, -1.338e-02h, -2.069e-02h, 2.227e-02h, -7.714e-03h, -3.542e-02h, 1.850e-02h, -5.652e-02h, 1.112e-02h, 4.749e-02h), r0);
	r0 = MulAdd(s0_1_0, half4x4(-4.541e-01h, 4.950e-02h, -2.319e-01h, 1.072e-01h, 5.148e-02h, -1.947e-02h, 6.616e-02h, 1.984e-02h, -7.690e-02h, 1.773e-02h, -1.006e-01h, -6.559e-02h, 2.260e-03h, -8.378e-03h, -3.693e-02h, -7.541e-02h), r0);
	r0 = MulAdd(s0_1_1, half4x4(-8.618e-02h, -6.200e-01h, -3.466e-02h, -3.779e-01h, 5.723e-01h, -2.387e-02h, 6.342e-02h, -4.658e-01h, 1.304e-01h, 1.130e-01h, 7.051e-01h, 5.566e-01h, 2.580e-02h, 3.877e-01h, -5.566e-01h, 1.724e-01h), r0);
	r0 = MulAdd(s0_1_2, half4x4(-9.982e-03h, 6.074e-03h, 5.088e-03h, -8.145e-03h, -4.550e-02h, 9.498e-02h, -4.190e-02h, -2.528e-02h, 1.080e-02h, -6.524e-02h, -2.383e-02h, 1.350e-01h, -3.786e-03h, 1.538e-01h, 2.104e-02h, -1.411e-01h), r0);
	r0 = MulAdd(s0_2_0, half4x4(3.114e-02h, -2.459e-02h, -6.471e-02h, 5.313e-02h, -9.421e-03h, 5.377e-03h, 1.764e-02h, 4.711e-03h, 2.045e-02h, 1.029e-02h, -2.045e-02h, 1.090e-02h, 2.616e-02h, -3.509e-03h, 1.584e-02h, 2.190e-02h), r0);
	r0 = MulAdd(s0_2_1, half4x4(1.764e-02h, 7.804e-02h, -4.490e-02h, -1.519e-01h, -7.934e-02h, 5.097e-03h, 5.826e-02h, 6.307e-03h, -1.490e-02h, -3.430e-02h, 4.749e-02h, -1.289e-02h, -1.011e-02h, -2.436e-02h, 3.430e-02h, 2.518e-02h), r0);
	r0 = MulAdd(s0_2_2, half4x4(-3.636e-03h, -1.442e-02h, -1.291e-02h, -2.985e-02h, 1.788e-02h, 5.287e-03h, -1.129e-02h, 1.125e-02h, 1.328e-02h, 3.210e-02h, 1.753e-03h, 1.867e-02h, -4.918e-03h, -3.528e-02h, 2.455e-03h, 5.595e-02h), r0);
	static const half3x3 rgb2yuv = {
	    0.299h, 0.587h, 0.114h,
	    -0.169h, -0.331h, 0.5h,
	    0.5h, -0.419h, -0.081h
	};
	static const half3x3 yuv2rgb = {
	    1.0h, -0.00093h, 1.401687h,
	    1.0h, -0.3437h, -0.71417h,
	    1.0h, 1.77216h, 0.00099h
	};
	half3 yuv;
	float2 opt = GetOutputPt();
	float2 fpos = (float2(gxy) + 0.5) * opt;
	yuv = mul(rgb2yuv, (half3)(INPUT.SampleLevel(sam1, fpos + float2(0.0, 0.0) * opt, 0).rgb));
	OUTPUT[gxy + uint2(0, 0)] = float4(mul(yuv2rgb, half3(saturate(yuv.r + r0.x), yuv.yz)), 1.0);
	yuv = mul(rgb2yuv, (half3)(INPUT.SampleLevel(sam1, fpos + float2(1.0, 0.0) * opt, 0).rgb));
	OUTPUT[gxy + uint2(1, 0)] = float4(mul(yuv2rgb, half3(saturate(yuv.r + r0.y), yuv.yz)), 1.0);
	yuv = mul(rgb2yuv, (half3)(INPUT.SampleLevel(sam1, fpos + float2(0.0, 1.0) * opt, 0).rgb));
	OUTPUT[gxy + uint2(0, 1)] = float4(mul(yuv2rgb, half3(saturate(yuv.r + r0.z), yuv.yz)), 1.0);
	yuv = mul(rgb2yuv, (half3)(INPUT.SampleLevel(sam1, fpos + float2(1.0, 1.0) * opt, 0).rgb));
	OUTPUT[gxy + uint2(1, 1)] = float4(mul(yuv2rgb, half3(saturate(yuv.r + r0.w), yuv.yz)), 1.0);
}

#undef L0
