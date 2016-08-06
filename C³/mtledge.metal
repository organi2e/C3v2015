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
						
						device const float4 * const edge_value [[ buffer(3) ]],
						device const float4 * const edge_mean [[ buffer(4) ]],
						device const float4 * const edge_variance [[ buffer(5) ]],
						device const float4 * const input_state [[ buffer(6) ]],
						
						uint const m [[ threadgroup_position_in_grid ]],
						uint const M [[ threadgroups_per_grid ]],
						uint const n [[ thread_position_in_threadgroup ]],
						uint const N [[ threads_per_threadgroup ]],
						
						threadgroup float4 * const th_value [[ threadgroup(0) ]],
						threadgroup float4 * const th_mean [[ threadgroup(1) ]],
						threadgroup float4 * const th_variance [[ threadgroup(2) ]])
{
	float4 const state = input_state [ n ];
	
	uint4 const idx = ( uint4(0,1,2,3) + 4 * m ) * N + n;
	
	th_value[n] = ( state ) *
		float4x4(edge_value[idx[0]],
				 edge_value[idx[1]],
				 edge_value[idx[2]],
				 edge_value[idx[3]]);
	
	th_mean[n] = ( state ) *
		float4x4(edge_mean[idx[0]],
				 edge_mean[idx[1]],
				 edge_mean[idx[2]],
				 edge_mean[idx[3]]);
	
	th_variance[n] = ( state * state ) *
		float4x4(edge_variance[idx[0]],
				 edge_variance[idx[1]],
				 edge_variance[idx[2]],
				 edge_variance[idx[3]]);
	
	uint offset = 1 << ( clz ( uint( 1 ) ) - clz ( N ) );
	
	threadgroup_barrier ( mem_flags::mem_threadgroup );
	if ( n < ( N % offset ) ) {
		th_value[n] += th_value[offset+n];
		th_mean[n] += th_mean[offset+n];
		th_variance[n] += th_variance[offset+n];
	}
	
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags::mem_threadgroup );
		if ( n < offset ) {
			th_value[n] += th_value[offset+n];
			th_mean[n] += th_mean[offset+n];
			th_variance[n] += th_variance[offset+n];
		};
	}
	
	if(!n) {
		level_value[m] = th_value[n];
		level_mean[m] = th_mean[n];
		level_variance[m] = th_variance[n];
		
	}
	
}
kernel void edgeCorrect(device float4 * edge_mean [[ buffer(0) ]],
						device float4 * edge_logvariance [[ buffer(1) ]],
						device const float4 * edge_variance [[ buffer(2) ]],
						constant const float & eps [[ buffer(3) ]],
						device const float4 * delta_mean [[ buffer(4) ]],
						device const float4 * delta_variance [[ buffer(5) ]],
						device const float4 * input_state [[ buffer(6) ]],
						
						) {
	float4x4 s = float4x4(0.0);
	float4x4 m = float4x4(0.0);
	float4x4 v = float4x4(0.0);
	

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