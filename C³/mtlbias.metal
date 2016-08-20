//
//  mtlbias.metal
//  C³
//
//  Created by Kota Nakano on 8/6/16.
//
//

#include <metal_stdlib>
using namespace metal;

float4 artMu(float4 const);
float4 artMuInverse(float4 const);
float4 artMuGradient(float4 const);

float4 artSigma(float4 const);
float4 artSigmaInverse(float4 const);
float4 artSigmaGradient(float4 const);

kernel void biasCollect(device float4 * level_value [[ buffer(0) ]],
						device float4 * level_mu [[ buffer(1) ]],
						device float4 * level_sigma [[ buffer(2) ]],
						device const float4 * bias_value [[ buffer(3) ]],
						device const float4 * bias_mu [[ buffer(4) ]],
						device const float4 * bias_sigma [[ buffer(5) ]],
						uint const n [[ thread_position_in_grid ]],
						uint const N [[ threads_per_grid ]]
						) {
	level_value[n] += bias_value[n];
	level_mu[n] += bias_mu[n];
	level_sigma[n] += bias_sigma[n];
}
kernel void biasCorrectFF(device float4 * bias_logmu [[ buffer(0) ]],
						  device float4 * bias_logsigma [[ buffer(1) ]],
						  device const float4 * bias_mu [[ buffer(2) ]],
						  device const float4 * bias_sigma [[ buffer(3) ]],
						  device const float4 * delta_mu [[ buffer(4) ]],
						  device const float4 * delta_sigma [[ buffer(5) ]],
						  constant const float & eps [[ buffer(6) ]],
						  uint const n [[ thread_position_in_grid ]],
						  uint const N [[ threads_per_grid ]]
						  ) {
	bias_logmu[n] += eps * artMuGradient(bias_mu[n]) * delta_mu[n];
	bias_logsigma[n] += eps * artSigmaGradient(bias_sigma[n]) * delta_sigma[n];
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