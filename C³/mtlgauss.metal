//
//  mtlgauss.metal
//  C³
//
//  Created by Kota Nakano on 8/6/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void gaussShuffle(device float4 * const value [[ buffer(0) ]],
						 device const float4 * const mean [[ buffer(1) ]],
						 device const float4 * const variance [[ buffer(2) ]],
						 device const ushort4 * const seed [[ buffer(3) ]],
						 uint const n [[ thread_position_in_grid ]],
						 uint const N [[ threads_per_grid ]]) {
	float4 u = (float4(seed[n]) + 1.0) / 65536.0;
	value[n] = mean[n] + float4(cospi(2.0*u.xy), sinpi(2.0*u.xy)).xzyw * sqrt(-2.0*variance[n]*log(u.zw).xxyy);
}
kernel void gaussRefresh(device float4 * const mean [[ buffer(0) ]],
						 device float4 * const variance [[ buffer(1) ]],
						 device const float4 * const logmean [[ buffer(2) ]],
						 device const float4 * const logvariance [[ buffer(3) ]],
						 uint const n [[ thread_position_in_grid  ]],
						 uint const N [[ threads_per_grid  ]]) {
	mean[n] = tanh(logmean[n]);
	variance[n] = log(1.0+exp(logvariance[n]));
}
kernel void gaussAdjust(device float4 * const logmean [[ buffer(0) ]],
						 device float4 * const logvariance [[ buffer(1) ]],
						 constant const float2 & params [[ buffer(2) ]],
						 uint const n [[ thread_position_in_grid  ]],
						 uint const N [[ threads_per_grid  ]]) {
	logmean[n] = params.x;
	logvariance[n] = params.y;
}
