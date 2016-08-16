//
//  mtlcell.metal
//  C³
//
//  Created by Kota Nakano on 8/11/16.
//
//

#include<metal_stdlib>
#include<metal_math>
using namespace metal;
kernel void cellActivate(device float4 * const state [[ buffer(0) ]],
						 device const float4 * const level [[ buffer(1) ]],
						 uint const n [[ thread_position_in_grid ]],
						 uint const N [[ threads_per_grid ]]
						 ) {
	state[n] = step(0.0,level[n]);
}
kernel void cellDerivate(device float4 * const delta_mean [[ buffer(0) ]],
						 device float4 * const delta_variance [[ buffer(1) ]],
						 device const float4 * const level_mean [[ buffer(2) ]],
						 device const float4 * const level_variance [[ buffer(3) ]],
						 device const float4 * const state_error [[ buffer(4) ]],
						 constant float const & M_PI [[ buffer(5) ]],
						 uint const n [[ thread_position_in_grid ]],
						 uint const N [[ threads_per_grid ]]
						 ) {
	float4 const jacob = exp(-0.5*(level_mean[n]*level_mean[n])/level_variance[n])*rsqrt(2.0*M_PI*level_variance[n]);
	float4 const error = sign(state_error[n]);
	delta_mean[n] = jacob * error;
	delta_variance[n] = - 0.5 * jacob * error * level_mean[n] / level_variance[n];
}
kernel void cellDifference(device float4 * const error [[ buffer(0) ]],
						   device const float4 * const train [[ buffer(1) ]],
						   device const float4 * const state [[ buffer(2) ]],
						   uint const n [[ thread_position_in_grid ]],
						   uint const N [[ threads_per_grid ]]
						   ) {
	error[n] = train[n] - state[n];
}
kernel void cellForget(device float4 * const error [[ buffer(0) ]],
					   constant float const & rate [[ buffer(1) ]],
					   uint const n [[ thread_position_in_grid ]],
					   uint const N [[ threads_per_grid ]]
						   ) {
	error[n] *= rate;
}