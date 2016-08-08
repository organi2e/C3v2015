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
						 device float4 * variance [[ buffer(1) ]],
						 device const float4 * mean [[ buffer(2) ]],
						 device const float4 * logvariance [[ buffer(3) ]],
						 device const ushort4 * seed [[ buffer(4) ]],
						 uint const n [[ thread_position_in_grid  ]],
						 uint const N [[ threads_per_grid  ]]) {
	
	float4 u = ( float4 ( seed [ n ] ) + 1.0 ) / 65536.0;
	float4 d = exp ( 0.5 * logvariance [ n ] );
	
	value [ n ] = mean [ n ] + d * float4( cospi( 2.0 * u.xy ), sinpi( 2.0 * u.xy ) ).xzyw * sqrt( - 2.0 * log( u.zw ) ).xxyy;
	variance [ n ] = d * d;
	
}
