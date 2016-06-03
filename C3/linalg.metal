//
//  linalg.metal
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

#include <metal_stdlib>
using namespace metal;


kernel void add(device float4 * y [[ buffer(0) ]],
				const device float4 * a [[ buffer(1) ]],
				const device float4 * b [[ buffer(2) ]],
				uint id [[ thread_position_in_grid ]]
				) {
	y [ id ] = a [ id ] + b [ id ];
}
kernel void sub(device float4 * y [[ buffer(0) ]],
				const device float4 * a [[ buffer(1) ]],
				const device float4 * b [[ buffer(2) ]],
				uint id [[ thread_position_in_grid ]]
				) {
	y [ id ] = a [ id ] - b [ id ];
}

