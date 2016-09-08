//
//  mtlcell.metal
//  C³
//
//  Created by Kota Nakano on 8/11/16.
//
//

#include<metal_stdlib>
using namespace metal;

kernel void cellActivate(device float4 * const state [[ buffer(0) ]],
						 device const float4 * const level [[ buffer(1) ]],
						 uint const t [[ thread_position_in_grid ]],
						 uint const T [[ threads_per_grid ]]
						 ) {
	state[t] = step(0.0, level[t]);
}
kernel void cellDerivate(device float4 * const delta [[ buffer(0) ]],
						 device const float4 * const error [[ buffer(1) ]],
						 uint const t [[ thread_position_in_grid ]],
						 uint const T [[ threads_per_grid ]]
						 ) {
	delta[t] = sign(error[t]);
}
kernel void cellDifference(device float4 * const error [[ buffer(0) ]],
						   device const float4 * const train [[ buffer(1) ]],
						   device const float4 * const state [[ buffer(2) ]],
						   uint const t [[ thread_position_in_grid ]],
						   uint const T [[ threads_per_grid ]]
						   ) {
	error[t] = train[t] - state[t];
}
kernel void cellForget(device float4 * const error [[ buffer(0) ]],
					   constant float const & rate [[ buffer(1) ]],
					   uint const t [[ thread_position_in_grid ]],
					   uint const T [[ threads_per_grid ]]
						   ) {
	error[t] *= rate;
}