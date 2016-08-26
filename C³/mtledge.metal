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
						
						device const float4 * const edge_value [[ buffer(3) ]],
						device const float4 * const edge_mu [[ buffer(4) ]],
						device const float4 * const edge_sigma [[ buffer(5) ]],
						
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
		uint4 const idx = ( n * 4 + uint4(0, 1, 2, 3) ) * M + m;
		value += float4x4(edge_value[idx[0]],
						  edge_value[idx[1]],
						  edge_value[idx[2]],
						  edge_value[idx[3]]) * state;
		
		mu += float4x4(edge_mu[idx[0]],
					   edge_mu[idx[1]],
					   edge_mu[idx[2]],
					   edge_mu[idx[3]]) * state;
		
		sigma += float4x4(edge_sigma[idx[0]],
						  edge_sigma[idx[1]],
						  edge_sigma[idx[2]],
						  edge_sigma[idx[3]]) * state;
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
kernel void edgeCorrect(device float4 * const edge_logmu [[ buffer(0) ]],
						device float4 * const edge_logsigma [[ buffer(1) ]],
						device const float4 * const edge_mu [[ buffer(2) ]],
						device const float4 * const edge_sigma [[ buffer(3) ]],
						device const float4 * const grad_mu [[ buffer(4) ]],
						device const float4 * const grad_sigma [[ buffer(5) ]],
						device const float * const delta_mu [[ buffer(6) ]],
						device const float * const delta_sigma [[ buffer(7) ]],
						constant const float & eta [[ buffer(8) ]],
						constant const uint2 & dim [[ buffer(9) ]],
						threadgroup float4 * const accumulator_mu [[ threadgroup(0) ]],
						threadgroup float4 * const accumulator_sigma [[ threadgroup(1) ]],
						uint3 const g [[ threadgroup_position_in_grid ]],
						uint3 const G [[ threadgroups_per_grid ]],
						uint3 const t [[ thread_position_in_threadgroup ]],
						uint3 const T [[ threads_per_threadgroup ]]) {
	
	uint const I = dim.x, i = g.x;
	uint const J = dim.y, j = g.y;
	
	float4 sum_mu = 0;
	float4 sum_sigma = 0;
	
	for ( uint k = t.z, K = I ; k < K ; k += T.z ) {
		uint const idx = i + I * ( j + J * k );
		sum_mu += delta_mu[k] * grad_mu[idx];
		sum_sigma += delta_sigma[k] * grad_sigma[idx];
	}
	
	accumulator_mu[t.z] = sum_mu;
	accumulator_sigma[t.z] = sum_sigma;
	
	uint offset = T.z;
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags :: mem_threadgroup );
		if ( t.z < offset ) {
			accumulator_mu[t.z] += accumulator_mu[t.z+offset];
			accumulator_sigma[t.z] += accumulator_sigma[t.z+offset];
		}
	}
	
	if ( !t.z ) {
		uint const idx = j * I + i;
		edge_logmu[idx] += eta * artMuGradient(edge_mu[idx]) * *accumulator_mu;
		edge_logsigma[idx] += eta * artSigmaGradient(edge_sigma[idx]) * *accumulator_sigma;
	}
}
kernel void edgeCorrectLightWeight(device float4 * const edge_logmu [[ buffer(0) ]],
								   device float4 * const edge_logsigma [[ buffer(1) ]],
								   device const float4 * const edge_mu [[ buffer(2) ]],
								   device const float4 * const edge_sigma [[ buffer(3) ]],
								   device const float4 * const input_state [[ buffer(4) ]],
								   device const float4 * const delta_mu [[ buffer(5) ]],
								   device const float4 * const delta_sigma [[ buffer(6) ]],
								   constant const float & eta [[ buffer(7) ]],
								   threadgroup float4 * const accumulator [[ threadgroup(0) ]],
								   uint2 const t [[ thread_position_in_grid ]],
								   uint2 const T [[ threads_per_grid ]]) {
	uint const n = t.x;
	uint const m = t.y, M = T.y;

	float4 const state = input_state[n];
	float4 const mu = delta_mu[m];
	float4 const sigma = delta_sigma[m];

	uint4 const idx = ( n * 4 + uint4(0,1,2,3) ) * M + m;
	
	edge_logmu[idx[0]] += eta * artMuGradient(edge_mu[idx[0]]) * mu * state[0];
	edge_logmu[idx[1]] += eta * artMuGradient(edge_mu[idx[1]]) * mu * state[1];
	edge_logmu[idx[2]] += eta * artMuGradient(edge_mu[idx[2]]) * mu * state[2];
	edge_logmu[idx[3]] += eta * artMuGradient(edge_mu[idx[3]]) * mu * state[3];
	
	edge_logsigma[idx[0]] += eta * artSigmaGradient(edge_sigma[idx[0]]) * sigma * state[0];
	edge_logsigma[idx[1]] += eta * artSigmaGradient(edge_sigma[idx[1]]) * sigma * state[1];
	edge_logsigma[idx[2]] += eta * artSigmaGradient(edge_sigma[idx[2]]) * sigma * state[2];
	edge_logsigma[idx[3]] += eta * artSigmaGradient(edge_sigma[idx[3]]) * sigma * state[3];
	
}
kernel void edgeGradientInitialize(device float * const mu [[ buffer(0) ]],
								   device float * const sigma [[ buffer(1) ]],
								   device const float * const input [[ buffer(2) ]],
								   constant const uint2 & dim [[ buffer(3) ]],
								   uint const t [[ thread_position_in_grid ]],
								   uint const T [[ threads_per_grid ]]) {
	uint const IK = dim.y;
	uint const J = dim.x, j = t;
	float const value = input[j];
	for ( uint ik = 0 ; ik < IK ; ++ ik ) {
		uint const idx = ik + ( IK * ( j + J * ik ) );
		mu[idx] = value;
		sigma[idx] = value;
	}
}

kernel void edgeBackpropagation(device float4 * const error [[ buffer(0) ]],
								device const float4 * const value [[ buffer(1) ]],
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
		uint4 const idx = ( n * 4 + uint4(0, 1, 2, 3) ) * M + m;
		sum += delta[m] * float4x4(value[idx[0]],
								   value[idx[1]],
								   value[idx[2]],
								   value[idx[3]]);
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