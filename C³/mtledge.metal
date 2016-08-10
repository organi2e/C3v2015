//
//  mtledge.metal
//  C³
//
//  Created by Kota Nakano on 8/6/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void edgeCollect(device float4 * level_value [[ buffer(0) ]],
						device float4 * level_mean [[ buffer(1) ]],
						device float4 * level_variance [[ buffer(2) ]],
						
						device const float4x4 * const edge_value [[ buffer(3) ]],
						device const float4x4 * const edge_mean [[ buffer(4) ]],
						device const float4x4 * const edge_variance [[ buffer(5) ]],
						
						device const float4 * const input_state [[ buffer(6) ]],
						
						constant uint2 const & dim [[ buffer(7) ]],
						
						uint const t [[ thread_position_in_threadgroup ]],
						uint const T [[ threads_per_threadgroup ]],
						
						uint const g [[ threadgroup_position_in_grid ]],
						uint const G [[ threadgroups_per_grid ]],
						
						threadgroup float4 * const th_value [[ threadgroup(0) ]],
						threadgroup float4 * const th_mean [[ threadgroup(1) ]],
						threadgroup float4 * const th_variance [[ threadgroup(2) ]])
{
	uint const M = dim.x;
	uint const N = dim.y;
	
	float4 value = 0.0;
	float4 mean = 0.0;
	float4 variance = 0.0;
	
	uint const rows = g;
	for ( uint k = 0, K = N ; k < K ; k += T ) {
		uint const cols = k + t;
		if ( cols < K ) {
			float4 const state = input_state [ cols ];
			uint const idx = cols * M + rows;
			value += edge_value[idx] * ( state );
			mean += edge_mean[idx] * ( state );
			variance += edge_variance[idx] * ( state * state );
		}
	}
	
	th_value[t] = value;
	th_mean[t] = mean;
	th_variance[t] = variance;
	
	uint offset = T;
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags :: mem_threadgroup );
		if ( t < offset ) {
			th_value [ t ] += th_value [ offset + t ];
			th_mean [ t ] += th_mean [ offset + t ];
			th_variance [ t ] += th_variance [ offset + t ];
		};
	}
	
	if ( !t ) {
		level_value [ rows ] = *th_value;
		level_mean [ rows ] = *th_mean;
		level_variance [ rows ] = *th_variance;
	}
	
}
kernel void edgeCorrectFF(device float4x4 * edge_mean [[ buffer(0) ]],
						  device float4x4 * edge_logvariance [[ buffer(1) ]],
						  device const float4x4 * edge_variance [[ buffer(2) ]],
						  device const float4 * input_state [[ buffer(3) ]],
						  constant const float & eps [[ buffer(4) ]],
						  device const float4 * delta_mean [[ buffer(5) ]],
						  device const float4 * delta_variance [[ buffer(6) ]],
						  constant const uint2 & dim [[ buffer(7) ]],
						  uint const g [[ threadgroup_position_in_grid ]],
						  uint const G [[ threadgroups_per_grid ]],
						  uint const t [[ thread_position_in_threadgroup ]],
						  uint const T [[ threads_per_threadgroup ]])
{
	uint const M = dim.x;
	uint const N = dim.y;
	
	float4 const mean = delta_mean[g];
	float4 const variance = delta_variance[g];
	
	for( uint k = 0, K = N ; k < K ; k += T ) {
		
		uint const rows = g;
		uint const cols = k + t;
		
		if ( cols < N ) {
			
			uint const idx = cols * M + rows;
			
			float4 const state_p1 = input_state [ cols ];
			float4 const state_p2 = state_p1 * state_p1;
			
			float4x4 dm = float4x4(mean, mean, mean, mean);
			
			dm[0] *= state_p1[0];
			dm[1] *= state_p1[1];
			dm[2] *= state_p1[2];
			dm[3] *= state_p1[3];
			
			edge_mean[idx] += eps * dm;
			
			float4x4 dv = float4x4(variance, variance, variance, variance);
			float4x4 ev = edge_variance[idx];
			
			dv[0] *= ev[0] * state_p2[0];
			dv[1] *= ev[1] * state_p2[1];
			dv[2] *= ev[2] * state_p2[2];
			dv[3] *= ev[3] * state_p2[3];
			
			edge_logvariance[idx] -= ( 0.5 * eps ) * dv;
			
		}
	}
}
/*
kernel void edgeCollect(device float4 * level_value [[ buffer(0) ]],
						device float4 * level_mean [[ buffer(1) ]],
						device float4 * level_variance [[ buffer(2) ]],
						device const float4 * const edge_value [[ buffer(3) ]],
						device const float4 * const edge_mean [[ buffer(4) ]],
						device const float4 * const edge_variance [[ buffer(5) ]],
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
	float4 mean = float4(0.0);
	float4 variance = float4(0.0);
	
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
			
			mean += th_state[k] *
				float4x4(mask_edge[0] ? edge_mean[indx_edge[0]] : 0.0,
						 mask_edge[1] ? edge_mean[indx_edge[1]] : 0.0,
						 mask_edge[2] ? edge_mean[indx_edge[2]] : 0.0,
						 mask_edge[3] ? edge_mean[indx_edge[3]] : 0.0
				);
			
			variance += th_state[k] * th_state[k] *
				float4x4(mask_edge[0] ? edge_variance[indx_edge[0]] : 0.0,
						 mask_edge[1] ? edge_variance[indx_edge[1]] : 0.0,
						 mask_edge[2] ? edge_variance[indx_edge[2]] : 0.0,
						 mask_edge[3] ? edge_variance[indx_edge[3]] : 0.0
				);
			
		}
		threadgroup_barrier( mem_flags::mem_threadgroup );
	}
	if ( row < M ) {
		level_value[row] = value;
		level_mean[row] = mean;
		level_variance[row] = variance;
	}
}
*/