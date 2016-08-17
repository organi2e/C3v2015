//
//  mtlbias.metal
//  C³
//
//  Created by Kota Nakano on 8/6/16.
//
//

#include <metal_stdlib>
using namespace metal;

kernel void biasCollect(device float4 * level_value [[ buffer(0) ]],
						device float4 * level_mean [[ buffer(1) ]],
						device float4 * level_variance [[ buffer(2) ]],
						device const float4 * bias_value [[ buffer(3) ]],
						device const float4 * bias_mean [[ buffer(4) ]],
						device const float4 * bias_variance [[ buffer(5) ]],
						uint const n [[ thread_position_in_grid ]],
						uint const N [[ threads_per_grid ]]
						) {
	level_value[n] += bias_value[n];
	level_mean[n] += bias_mean[n];
	level_variance[n] += bias_variance[n];
}
kernel void biasCorrectFF(device float4 * bias_logmean [[ buffer(0) ]],
						  device float4 * bias_logvariance [[ buffer(1) ]],
						  device const float4 * bias_mean [[ buffer(2) ]],
						  device const float4 * bias_variance [[ buffer(3) ]],
						  device const float4 * delta_mean [[ buffer(4) ]],
						  device const float4 * delta_variance [[ buffer(5) ]],
						  constant const float & eps [[ buffer(6) ]],
						  uint const n [[ thread_position_in_grid ]],
						  uint const N [[ threads_per_grid ]]
						  ) {
	
//	bias_logmean[n] += eps * delta_mean[n];
//	bias_logvariance[n] += eps * delta_variance[n];
	bias_logmean[n] += eps * ( 1.0 - bias_mean[n] * bias_mean[n] ) * delta_mean[n];
	bias_logvariance[n] += eps * ( 1.0 - exp ( - bias_variance[n] ) ) * delta_variance[n];
}
kernel void biasCorrectFB(device float4 * bias_mean [[ buffer(0) ]],
						  device float4 * bias_logvariance [[ buffer(1) ]],
						  constant const float & eps [[ buffer(2) ]],
						  device const float4 * delta_mean [[ buffer(3) ]],
						  device const float4 * delta_variance [[ buffer(4) ]],
						  device const float4 * bias_variance [[ buffer(5) ]],
						  uint const n [[ thread_position_in_grid ]],
						  uint const N [[ threads_per_grid ]]
						  ) {
	bias_mean[n] += eps * delta_mean[n];
	bias_logvariance[n] -= ( 0.5 * eps ) * delta_variance[n] * bias_variance[n];
}