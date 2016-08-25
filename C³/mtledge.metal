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
		level_value [ m ] = * th_value;
		level_mu [ m ] = * th_mu;
		level_sigma [ m ] = * th_sigma;
	}
	
}
kernel void edgeCorrectLightWeight(device float4 * const input_error [[ buffer(0) ]],
								   device float4x4 * const edge_logmu [[ buffer(1) ]],
								   device float4x4 * const edge_logsigma [[ buffer(2) ]],
								   device const float4 * const input_state [[ buffer(3) ]],
								   device const float4x4 * const edge_value [[ buffer(4) ]],
								   device const float4x4 * const edge_mu [[ buffer(5) ]],
								   device const float4x4 * const edge_sigma [[ buffer(6) ]],
								   device const float4 * const delta_value [[ buffer(7) ]],
								   device const float4 * const delta_mu [[ buffer(8) ]],
								   device const float4 * const delta_sigma [[ buffer(9) ]],
								   constant const float & eta [[ buffer(10) ]],
								   constant const uint2 & dim [[ buffer(11) ]],
								   threadgroup float4 * const accumulator [[ threadgroup(0) ]],
								   uint const g [[ threadgroup_position_in_grid ]],
								   uint const G [[ threadgroups_per_grid ]],
								   uint const t [[ thread_position_in_threadgroup ]],
								   uint const T [[ threads_per_threadgroup ]])
{
	uint const M = dim.y;
	uint const n = g;
	
	float4 const state = input_state [ n ];
	
	float4 error = 0.0;
	
	for( uint m = t ; m < M ; m += T ) {
		
		float4 const value = delta_value[m];
		float4 const mu = delta_mu[m];
		float4 const sigma = delta_sigma[m];
		
		uint const idx = n * M + m;
		
		error += value * edge_value[idx];
		//error += ( mu * edge_mu[ idx ] );
		//error += ( sigma * edge_sigma[ idx ] );
		
		float4x4 const jm = edge_mu[idx];
		edge_logmu[idx] += eta * float4x4(state[0] * artMuGradient(jm[0]) * mu,
										  state[1] * artMuGradient(jm[1]) * mu,
										  state[2] * artMuGradient(jm[2]) * mu,
										  state[3] * artMuGradient(jm[3]) * mu);
		
		float4x4 const js = edge_sigma[idx];
		edge_logsigma[idx] += eta * float4x4(state[0] * artSigmaGradient(js[0]) * sigma,
											 state[1] * artSigmaGradient(js[1]) * sigma,
											 state[2] * artSigmaGradient(js[2]) * sigma,
											 state[3] * artSigmaGradient(js[3]) * sigma);
	}
	
	accumulator[t] = error;
	
	uint offset = T;
	while ( offset >>= 1 ) {
		threadgroup_barrier( mem_flags :: mem_threadgroup );
		if ( t < offset ) {
			accumulator [ t ] += accumulator [ t + offset ];
		}
	}
	if ( !t ) {
		input_error [ n ] = * accumulator;
	}
}
/*
kernel void edgeCollect(device float4 * level_value [[ buffer(0) ]],
						device float4 * level_mu [[ buffer(1) ]],
						device float4 * level_sigma [[ buffer(2) ]],
						device const float4 * const edge_value [[ buffer(3) ]],
						device const float4 * const edge_mu [[ buffer(4) ]],
						device const float4 * const edge_sigma [[ buffer(5) ]],
						device const float4 * const state [[ buffer(6) ]],
						constant const uint & M [[ buffer(7) ]],
						constant const uint & N [[ buffer(8) ]],
						uint const g [[ threadgroup_position_in_grid ]],
						uint const G [[ threadgroups_per_grid ]],
						uint const t [[ thread_position_in_threadgroup ]],
						uint const T [[ threads_per_threadgroup ]],
						threadgroup float4 * const th_state [[ threadgroup(0) ]]
						)
{
	uint const row = g * T + t;
	
	float4 value = float4(0.0);
	float4 mu = float4(0.0);
	float4 sigma = float4(0.0);
	
	for( uint i = 0, I = ( N - 1 ) / T + 1 ; i < I ; ++ i ) {
		
		th_state[t] = i * T + t < N ? state [ i * T + t ] : 0.0;
		
		threadgroup_barrier( mem_flags::mem_threadgroup );
		for( uint k = 0, K = T ; k < K ; ++ k ) {
			
			uint4 const rows_edge = row;
			uint4 const cols_edge = i * T + k;
			bool4 const mask_edge = rows_edge < M && cols_edge < N;
			uint4 const indx_edge = (4 * rows_edge + uint4(0,1,2,3)) * N + cols_edge;
			
			value += th_state[k] *
				float4x4(mask_edge[0] ? edge_value[indx_edge[0]] : 0.0,
						 mask_edge[1] ? edge_value[indx_edge[1]] : 0.0,
						 mask_edge[2] ? edge_value[indx_edge[2]] : 0.0,
						 mask_edge[3] ? edge_value[indx_edge[3]] : 0.0
				);
			
			mu += th_state[k] *
				float4x4(mask_edge[0] ? edge_mu[indx_edge[0]] : 0.0,
						 mask_edge[1] ? edge_mu[indx_edge[1]] : 0.0,
						 mask_edge[2] ? edge_mu[indx_edge[2]] : 0.0,
						 mask_edge[3] ? edge_mu[indx_edge[3]] : 0.0
				);
			
			sigma += th_state[k] * th_state[k] *
				float4x4(mask_edge[0] ? edge_sigma[indx_edge[0]] : 0.0,
						 mask_edge[1] ? edge_sigma[indx_edge[1]] : 0.0,
						 mask_edge[2] ? edge_sigma[indx_edge[2]] : 0.0,
						 mask_edge[3] ? edge_sigma[indx_edge[3]] : 0.0
				);
			
		}
		threadgroup_barrier( mem_flags::mem_threadgroup );
	}
	if ( row < M ) {
		level_value[row] = value;
		level_mu[row] = mu;
		level_sigma[row] = sigma;
	}
}
*/