//
//  mtlcauchy.metal
//  C³
//
//  Created by Kota Nakano on 8/19/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void cauchyGradient(device float4 * grads [[ buffer(0) ]],
						   device float4 * const mu [[ buffer(1) ]],
						   device float4 * const sigma [[ buffer(2) ]],
						   constant float const & M_PI [[ buffer(3) ]],
						   uint const n [[ thread_position_in_grid ]],
						   uint const N [[ threads_per_grid ]]) {
	grads[n] = sigma[n] / ( M_PI * ( sigma[n] * sigma[n] + mu[n] * mu[n] ) );
}
kernel void cauchyShuffle(device float4 * const value [[ buffer(0) ]],
						  device const float4 * const mu [[ buffer(1) ]],
						  device const float4 * const sigma [[ buffer(2) ]],
						  device const short4 * const seed [[ buffer(3) ]],
						  uint const n [[ thread_position_in_grid ]],
						  uint const N [[ threads_per_grid ]]) {
	value[n] = mu[n] + sigma[n] * tanpi((float4(seed[n])+0.5)/32768.0);
}
