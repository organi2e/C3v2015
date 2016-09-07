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
	return sigma / ( mu * mu + sigma * sigma ) / pi;
}

float4 cauchyCDF(float4 const mu, float4 const sigma, float const pi) {
	return atan ( mu / sigma ) / pi + 0.5;
}

kernel void cauchyShuffle(device float4 * const value [[ buffer(0) ]],
						  device const float4 * const mu [[ buffer(1) ]],
						  device const float4 * const sigma [[ buffer(2) ]],
						  device const float4 * const uniform [[ buffer(3) ]],
						  uint const n [[ thread_position_in_grid ]],
						  uint const N [[ threads_per_grid ]]) {
	value[n] = mu[n] + sigma[n] * tanpi ( uniform [ n ] - 0.5 );
}
kernel void cauchyRNG(device float4 * const value [[ buffer(0) ]],
					  device const float4 * const mu [[ buffer(1) ]],
					  device const float4 * const sigma [[ buffer(2) ]],
					  constant uint4 * const seeds [[ buffer(3) ]],
					  constant uint4 const & param [[ buffer(4) ]],
					  uint const t [[ thread_position_in_grid ]],
					  uint const T [[ threads_per_grid ]]) {
	uint const a = param.x;
	uint const b = param.y;
	uint const c = param.z;
	uint const K = param.w;
	uint4 seq = select(seeds[t], -1, seeds[t]==0);
	for ( uint k = t ; k < K ; k += T ) {
		float4 const u = (float4(seq)+0.5)/4294967296.0;
		value [ k ] = tanpi( u - 0.5 ) * sigma [ k ] + mu [ k ];
		seq ^= seq >> a;
		seq ^= seq << b;
		seq ^= seq >> c;
	}
}
