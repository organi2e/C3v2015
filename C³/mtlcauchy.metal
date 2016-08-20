//
//  mtlcauchy.metal
//  C³
//
//  Created by Kota Nakano on 8/19/16.
//
//

#include <metal_stdlib>
using namespace metal;

float4 cauchyPDF(float4 const, float4 const, float const);
float4 cauchyCDF(float4 const, float4 const, float const);

float4 cauchyPDF(float4 const mu, float4 const sigma, float const pi) {
	float4 p = sigma / ( mu * mu + sigma * sigma ) / pi;
	float4 f = cauchyCDF(mu, sigma, pi);
	float4 c = 1.0 - f;
	return p;
}

float4 cauchyCDF(float4 const mu, float4 const sigma, float const pi) {
	return atan(mu/sigma)/pi + 0.5;
}

kernel void cauchyShuffle(device float4 * const value [[ buffer(0) ]],
						  device const float4 * const mu [[ buffer(1) ]],
						  device const float4 * const sigma [[ buffer(2) ]],
						  device const short4 * const seed [[ buffer(3) ]],
						  uint const n [[ thread_position_in_grid ]],
						  uint const N [[ threads_per_grid ]]) {
	float4 u = (float4(seed[n])+0.5)/65536.0;
	value[n] = mu[n] + sigma[n] * tanpi(u);
}
