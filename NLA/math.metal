//
//  math.metal
//  C³
//
//  Created by Kota Nakano on 7/22/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void exp(device float4 * const y [[ buffer(0) ]],
				 device const float4 * const x [[ buffer(1) ]],
				 uint const id [[thread_position_in_grid]]
				 ) {
	y[id] = exp(x[id]);
}
kernel void sqrt(device float4 * const y [[ buffer(0) ]],
				device const float4 * const x [[ buffer(1) ]],
				uint const id [[thread_position_in_grid]]
				) {
	y[id] = sqrt(x[id]);
}