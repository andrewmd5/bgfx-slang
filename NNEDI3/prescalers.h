// Copyright (c) 2016 mpv developers <mpv-team@googlegroups.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// NNEDI3, an intra-field deinterlacer
//
// The original filter was authored by Kevin Stone (aka. tritical) and is
// licensed under GPL2 terms:
//     http://bengal.missouri.edu/~kes25c/
//
// A LGPLv3 licensed OpenCL kernel was created by SEt:
//     http://forum.doom9.org/showthread.php?t=169766
//
// A HLSL port further modified by madshi, Shiandow and Zach Saw could be
// found at (also LGPLv3 licensed):
//     https://github.com/zachsaw/MPDN_Extensions
//
// Auto-generated from https://github.com/bjin/mpv-prescalers

#ifndef PRESCALERS_H
#define PRESCALERS_H

// BT.709 color space conversion
static const float3 rgb2y = float3(0.2126, 0.7152, 0.0722);
static const float2x3 rgb2uv = {
    -0.2126 / 1.8556, -0.7152 / 1.8556,  0.9278 / 1.8556,
     0.7874 / 1.5748, -0.7152 / 1.5748, -0.0722 / 1.5748
};
static const float3x3 yuv2rgb = {
    1,  0,         1.5748,
    1, -0.187324, -0.468124,
    1,  1.8556,    0
};

// Neural network weight unpacking and accumulation
#define T(x) asfloat(x)
#define W(i,w0,w1,w2,w3) dot(samples[i],float4(T(w0),T(w1),T(w2),T(w3)))
#define WS(w0,w1) \
sum1 = exp(sum1 * mstd2 + T(w0)); \
sum2 = sum2 * mstd2 + T(w1); \
wsum += sum1; \
vsum += sum1*(sum2/(1.0+abs(sum2)));

#endif
