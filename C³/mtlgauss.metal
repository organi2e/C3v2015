//
//  mtlgauss.metal
//  C³
//
//  Created by Kota Nakano on 8/6/16.
//
//

#include <metal_stdlib>
using namespace metal;

float4 gaussPDF(float4 const, float4 const, float const);

float4 gaussPDF(float4 const mu, float4 const sigma, float const M_PI) {
	float4 v = mu / sigma;
	return exp(-0.5*v*v)*rsqrt(2.0*M_PI)/sigma;
}

kernel void gaussShuffle(device float4 * const value [[ buffer(0) ]],
						 device const float4 * const mu [[ buffer(1) ]],
						 device const float4 * const sigma [[ buffer(2) ]],
						 device const ushort4 * const seed [[ buffer(3) ]],
						 uint const n [[ thread_position_in_grid ]],
						 uint const N [[ threads_per_grid ]]) {
	float4 u = (float4(seed[n]) + 1.0) / 65536.0;
	value[n] = mu[n] + sigma[n] * float4(cospi(2.0*u.xy), sinpi(2.0*u.xy)).xzyw * sqrt(-2.0*log(u.zw).xxyy);
}
