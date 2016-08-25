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

kernel void biasCollect(device float4 * const level_value [[ buffer(0) ]],
						device float4 * const level_mu [[ buffer(1) ]],
						device float4 * const level_sigma [[ buffer(2) ]],
						device const float4 * const bias_value [[ buffer(3) ]],
						device const float4 * const bias_mu [[ buffer(4) ]],
						device const float4 * const bias_sigma [[ buffer(5) ]],
						uint const n [[ thread_position_in_grid ]],
						uint const N [[ threads_per_grid ]]
						) {
	level_value[n] += bias_value[n];
	level_mu[n] += bias_mu[n];
	level_sigma[n] += bias_sigma[n];
}
kernel void biasCorrect(device float4 * const bias_logmu [[ buffer(0) ]],
						device float4 * const bias_logsigma [[ buffer(1) ]],
						device const float4 * const bias_mu [[ buffer(2) ]],
						device const float4 * const bias_sigma [[ buffer(3) ]],
						device const float4x4 * const gradient_mu [[ buffer(4) ]],
						device const float4x4 * const gradient_sigma [[ buffer(5) ]],
						device const float4 * const delta_mu [[ buffer(6) ]],
						device const float4 * const delta_sigma [[ buffer(7) ]],
						constant const uint2 & dim [[ buffer(8) ]],
						constant const float & eta [[ buffer(9) ]],
						threadgroup float4 * const accum_mu [[ threadgroup(0) ]],
						threadgroup float4 * const accum_sigma [[ threadgroup(1) ]],
						uint const g [[ threadgroup_position_in_grid ]],
						uint const G [[ threadgroups_per_grid ]],
						uint const t [[ thread_position_in_threadgroup ]],
						uint const T [[ threads_per_threadgroup ]]) {
	
	uint const M = dim.x;
	uint const n = g;
	
	float4 mu = float4(0);
	float4 sigma = float4(0);
	
	for ( uint m = t ; m < M ; m += T ) {
		uint const idx = n * M + m;
		mu += delta_mu[m] * gradient_mu[idx];
		sigma += delta_sigma[m] * gradient_sigma[idx];
	}
	
	accum_mu[t] = mu;
	accum_sigma[t] = sigma;
	
	uint offset = T;
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags :: mem_threadgroup );
		if ( t < offset ) {
			accum_mu[t] += accum_mu[t+offset];
			accum_sigma[t] += accum_sigma[t+offset];
		}
	}
	
	if ( !t ) {
		bias_logmu[n] += eta * artMuGradient(bias_mu[n]) * * accum_mu;
		bias_logsigma[n] += eta * artSigmaGradient(bias_sigma[n]) * * accum_sigma;
	}
	
}
kernel void biasGradientEye(device float4x4 * const gradient_mu [[ buffer(0) ]],
							device float4x4 * const gradient_sigma [[ buffer(1) ]],
							uint const t [[ thread_position_in_grid ]],
							uint const T [[ threads_per_grid ]]) {
	gradient_mu[t*T+t] = float4x4(1.0);
	gradient_sigma[t*T+t] = float4x4(1.0);
}
kernel void biasCorrectLightWeight(device float4 * const bias_logmu [[ buffer(0) ]],
								   device float4 * const bias_logsigma [[ buffer(1) ]],
								   device const float4 * const bias_mu [[ buffer(2) ]],
								   device const float4 * const bias_sigma [[ buffer(3) ]],
								   device const float4 * const delta_mu [[ buffer(4) ]],
								   device const float4 * const delta_sigma [[ buffer(5) ]],
								   constant const float & eta [[ buffer(6) ]],
								   uint const n [[ thread_position_in_grid ]],
								   uint const N [[ threads_per_grid ]]
								   ) {
	bias_logmu[n] += eta * artMuGradient(bias_mu[n]) * delta_mu[n];
	bias_logsigma[n] += eta * artSigmaGradient(bias_sigma[n]) * delta_sigma[n];
}
