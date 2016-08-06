//
//  mtlmath.metal
//  C³
//
//  Created by Kota Nakano on 8/5/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void step(device float4 * y [[ buffer(0) ]],
				 device const float4 * x [[ buffer(1) ]],
				 uint const n [[ thread_position_in_grid ]],
				 uint const N [[ threads_per_grid ]]
				 ) {
	y[n] = step(0.0, x[n]);
}
kernel void sign(device float4 * y [[ buffer(0) ]],
				 device const float4 * x [[ buffer(1) ]],
				 uint const n [[ thread_position_in_grid ]],
				 uint const N [[ threads_per_grid ]]
				 ) {
	y[n] = sign(x[n]);
}