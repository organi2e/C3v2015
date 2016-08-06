//
//  mtlgauss.metal
//  C³
//
//  Created by Kota Nakano on 8/6/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void gaussShuffle(device float4 * value [[ buffer(0) ]],
						 device float4 * deviation [[ buffer(1) ]],
						 device float4 * variance [[ buffer(2) ]],
						 device const float4 * mean [[ buffer(3) ]],
						 device const float4 * logvariance [[ buffer(4) ]],
						 device const ushort4 * seed [[ buffer(5) ]],
						 uint const n [[ thread_position_in_grid  ]],
						 uint const N [[ threads_per_grid  ]]) {
	
	float4 u = ( float4(seed[n]) + 1.0 )/ 65536.0;
	float4 d = exp ( 0.5 * logvariance [ n ] );
	float4 v = d * d;
	
	deviation[n] = d;
	variance[n] = v;
	value[n] = mean[n] + deviation[n] * float4(cospi(u.xy), sinpi(u.xy)) * sqrt(-2.0*log(u.zw)).xyxy;
	
}
