//
//  mtlrand.metal
//  C³
//
//  Created by Kota Nakano on 8/5/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void gauss(device float4 * value,
				  device float4 * deviation,
				  device float4 * variance,
				  device const float4 * mean,
				  device const float4 * logvariance,
				  device const ushort4 * seed,
				  uint const n [[ thread_position_in_grid  ]],
				  uint const N [[ threads_per_grid  ]]) {
	float4 u = float4(seed[n]) / 65536.0 + 1.0;
	float4 d = exp(0.5*logvariance[n]);
	float4 v = d * d;
	
	deviation[n] = d;
	variance[n] = v;
	value[n] = mean[n] + deviation[n] * float4(cospi(u.xy), sinpi(u.xy)) * sqrt(-2.0*log(u.zw)).xyxy;
}