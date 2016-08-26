//
//  mtledge.metal
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

kernel void edgeCollect(device float4 * level_value [[ buffer(0) ]],
						device float4 * level_mu [[ buffer(1) ]],
						device float4 * level_sigma [[ buffer(2) ]],
						
						device const float4x4 * const edge_value [[ buffer(3) ]],
						device const float4x4 * const edge_mu [[ buffer(4) ]],
						device const float4x4 * const edge_sigma [[ buffer(5) ]],
						
						device const float4 * const input_state [[ buffer(6) ]],
						
						constant uint2 const & dim [[ buffer(7) ]],
						
						uint const t [[ thread_position_in_threadgroup ]],
						uint const T [[ threads_per_threadgroup ]],
						
						uint const g [[ threadgroup_position_in_grid ]],
						uint const G [[ threadgroups_per_grid ]],
						
						threadgroup float4 * const th_value [[ threadgroup(0) ]],
						threadgroup float4 * const th_mu [[ threadgroup(1) ]],
						threadgroup float4 * const th_sigma [[ threadgroup(2) ]])
{
	uint const M = dim.y;
	uint const N = dim.x;
	
	float4 value = 0.0;
	float4 mu = 0.0;
	float4 sigma = 0.0;
	
	uint const m = g;
	for ( uint n = t ; n < N ; n += T ) {
		float4 const state = input_state [ n ];
		uint const idx = n * M + m;
		value += edge_value[idx] * state;
		mu += edge_mu[idx] * state;
		sigma += edge_sigma[idx] * state;
	}
	
	th_value[t] = value;
	th_mu[t] = mu;
	th_sigma[t] = sigma;
	
	uint offset = T;
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags :: mem_threadgroup );
		if ( t < offset ) {
			th_value [ t ] += th_value [ offset + t ];
			th_mu [ t ] += th_mu [ offset + t ];
			th_sigma [ t ] += th_sigma [ offset + t ];
		};
	}
	
	if ( !t ) {
		level_value [ m ] += * th_value;
		level_mu [ m ] += * th_mu;
		level_sigma [ m ] += * th_sigma;
	}
	
}
kernel void edgeCorrect(device float4x4 * const edge_logmu [[ buffer(0) ]],
						device float4x4 * const edge_logsigma [[ buffer(1) ]],
						device const float4x4 * const edge_mu [[ buffer(2) ]],
						device const float4x4 * const edge_sigma [[ buffer(3) ]],
						device const float4x4 * const grad_mu [[ buffer(4) ]],
						device const float4x4 * const grad_sigma [[ buffer(5) ]],
						device const float4 * const delta_mu [[ buffer(6) ]],
						device const float4 * const delta_sigma [[ buffer(7) ]],
						constant const float & eta [[ buffer(8) ]],
						constant const uint2 & dim [[ buffer(9) ]],
						threadgroup float4x4 * const accumulator_mu [[ threadgroup(0) ]],
						threadgroup float4x4 * const accumulator_sigma [[ threadgroup(1) ]],
						uint3 const g [[ threadgroup_position_in_grid ]],
						uint3 const G [[ threadgroups_per_grid ]],
						uint3 const t [[ thread_position_in_threadgroup ]],
						uint3 const T [[ threads_per_threadgroup ]]) {
	
	uint const I = dim.x, i = g.x;
	uint const J = dim.y, j = g.y;
	
	float4x4 sum_mu = float4x4(0.0);
	float4x4 sum_sigma = float4x4(0.0);
	
	for ( uint k = t.z, K = 4 * I ; k < K ; k += 4 * T.z ) {
		
		uint4 const idx = ( ( k + uint4(0,1,2,3)) * J + j ) * I + i;
		
		sum_mu += delta_mu[k][0] * grad_mu[idx[0]];
		sum_mu += delta_mu[k][1] * grad_mu[idx[1]];
		sum_mu += delta_mu[k][2] * grad_mu[idx[2]];
		sum_mu += delta_mu[k][3] * grad_mu[idx[3]];
		
		sum_sigma += delta_sigma[k][0] * grad_sigma[idx[0]];
		sum_sigma += delta_sigma[k][1] * grad_sigma[idx[1]];
		sum_sigma += delta_sigma[k][2] * grad_sigma[idx[2]];
		sum_sigma += delta_sigma[k][3] * grad_sigma[idx[3]];
		
	}
	
	accumulator_mu[t.z] = sum_mu;
	accumulator_sigma[t.z] = sum_sigma;
	
	uint offset = T.z;
	while ( offset >>= 1 ) {
		if ( t.z < offset ) {
			accumulator_mu[t.z] += accumulator_mu[t.z+offset];
			accumulator_sigma[t.z] += accumulator_sigma[t.z+offset];
		}
	}
	
	if ( !t.z ) {
		
		uint const idx = j * I + i;
		
		float4x4 const delta_mu_cache = *accumulator_mu;
		float4x4 const mu_cache = edge_mu[idx];
		edge_logmu[idx] += eta * float4x4(artMuGradient(mu_cache[0]) * delta_mu_cache[0],
										  artMuGradient(mu_cache[1]) * delta_mu_cache[1],
										  artMuGradient(mu_cache[2]) * delta_mu_cache[2],
										  artMuGradient(mu_cache[3]) * delta_mu_cache[3]);
		
		float4x4 const delta_sigma_cache = *accumulator_sigma;
		float4x4 const sigma_cache = edge_sigma[idx];
		edge_logsigma[idx] += eta * float4x4(artSigmaGradient(sigma_cache[0]) * delta_sigma_cache[0],
											 artSigmaGradient(sigma_cache[1]) * delta_sigma_cache[1],
											 artSigmaGradient(sigma_cache[2]) * delta_sigma_cache[2],
											 artSigmaGradient(sigma_cache[3]) * delta_sigma_cache[3]);
	}
}
kernel void edgeCorrectLightWeight(device float4x4 * const edge_logmu [[ buffer(0) ]],
								   device float4x4 * const edge_logsigma [[ buffer(1) ]],
								   device const float4x4 * const edge_mu [[ buffer(2) ]],
								   device const float4x4 * const edge_sigma [[ buffer(3) ]],
								   device const float4 * const input_state [[ buffer(4) ]],
								   device const float4 * const delta_mu [[ buffer(5) ]],
								   device const float4 * const delta_sigma [[ buffer(6) ]],
								   constant const float & eta [[ buffer(7) ]],
								   threadgroup float4 * const accumulator [[ threadgroup(0) ]],
								   uint2 const t [[ thread_position_in_grid ]],
								   uint2 const T [[ threads_per_grid ]]) {
	uint const m = t.y, M = T.y;
	uint const n = t.x;
	
	float4 const grad_mu = input_state[n];
	float4 const grad_sigma = input_state[n];
	
	float4 const delta_mu_cache = delta_mu[m];
	float4 const delta_sigma_cache = delta_sigma[m];
		
	uint const idx = n * M + m;
	
	float4x4 const mu_cache = edge_mu[idx];
	edge_logmu[idx] += eta * float4x4(artMuGradient(mu_cache[0]) * grad_mu[0] * delta_mu_cache,
									  artMuGradient(mu_cache[1]) * grad_mu[1] * delta_mu_cache,
									  artMuGradient(mu_cache[2]) * grad_mu[2] * delta_mu_cache,
									  artMuGradient(mu_cache[3]) * grad_mu[3] * delta_mu_cache);
	
	float4x4 const sigma_cache = edge_sigma[idx];
	edge_logsigma[idx] += eta * float4x4(artSigmaGradient(sigma_cache[0]) * grad_sigma[0] * delta_sigma_cache,
										 artSigmaGradient(sigma_cache[1]) * grad_sigma[1] * delta_sigma_cache,
										 artSigmaGradient(sigma_cache[2]) * grad_sigma[2] * delta_sigma_cache,
										 artSigmaGradient(sigma_cache[3]) * grad_sigma[3] * delta_sigma_cache);
	
}
kernel void edgeGradientInitialize(device float4x4 * const mu [[ buffer(0) ]],
								   device float4x4 * const sigma [[ buffer(1) ]],
								   device const float4 * const input [[ buffer(2) ]],
								   constant const uint2 & dim [[ buffer(3) ]],
								   threadgroup float4 * const accumulator [[ threadgroup(0) ]],
								   uint const g [[ threadgroup_position_in_grid ]],
								   uint const G [[ threadgroups_per_grid ]],
								   uint const t [[ thread_position_in_threadgroup ]],
								   uint const T [[ threads_per_threadgroup ]]) {
	uint const I = dim.y;
	uint const J = dim.x, j = g;
	float4x4 value = float4x4(0.0);
	value[t] = input[j];
	value = transpose(value);
	for ( uint i = 0 ; i < I ; ++ i ) {
		uint const k = i * T + t;
		uint const idx = ( ( k * J ) + j ) * I + i;
		mu[idx] = value;
		sigma[idx] = value;
	}
}

kernel void edgeBackpropagation(device float4 * const error [[ buffer(0) ]],
								device const float4x4 * const value [[ buffer(1) ]],
								device const float4 * const delta [[ buffer(2) ]],
								constant const uint2 & dim [[ buffer(3) ]],
								threadgroup float4 * const accumulator [[ threadgroup(0) ]],
								uint const g [[ threadgroup_position_in_grid ]],
								uint const G [[ threadgroups_per_grid ]],
								uint const t [[ thread_position_in_threadgroup ]],
								uint const T [[ threads_per_threadgroup ]]) {
	uint const M = dim.y;
	uint const n = g;
	float4 sum = 0;
	for ( uint m = t ; m < M ; m += T ) {
		uint const idx = n * M + m;
		sum += delta[m] * value[idx];
	}
	accumulator[t] = sum;
	uint offset = T;
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags :: mem_threadgroup );
		if ( t < offset ) {
			accumulator [ t ] += accumulator [ t + offset ];
		}
	}
	if ( !t ) {
		error[n] += * accumulator;
	}
}