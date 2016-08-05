//
//  blas.metal
//  C³
//
//  Created by Kota Nakano on 8/5/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void vsma(device float4 * y [[ buffer(0) ]],
				 device const float4 * const x [[ buffer(1) ]],
				 constant const float & alpha [[ buffer(2) ]],
				 uint const n [[ threads_position_in_grid ]],
				 uint const N [[ threads_per_grid ]]
				 ) {
	y[n] = y[n] + alpha * x[n];
}
kernel void smvmv(device float4 * y [[ buffer(0) ]],
				  constant float & alpha [[ buffer(1) ]],
				  device float4 * b [[ buffer(2) ]],
				  device float4 * c [[ buffer(3) ]],
				  uint const n [[ threads_position_in_grid ]],
				  uint const N [[ threads_per_grid ]]) {
	y[n] = y[n] + alpha * b[n] * c[n];
}
kernel void gemv(device float4 * Y [[ buffer(0) ]],
				  device const float4 * const A [[ buffer(1) ]],
				  device const float4 * const X [[ buffer(2) ]],
				  constant const uint & M [[ buffer(3) ]],
				  constant const uint & N [[ buffer(4) ]],
				  uint const g [[ threadgroup_position_in_grid ]],
				  uint const G [[ threadgroups_per_grid ]],
				  uint const t [[ thread_position_in_threadgroup ]],
				  uint const T [[ threads_per_threadgroup ]],
				  threadgroup float4x4 * const a [[ threadgroup(0) ]],
				  threadgroup float4 * const x [[ threadgroup(1) ]]
				  )
{
	uint const row = g * T + t;
	float4 y = float4(0.0);
	for( uint i = 0, I = (N-1)/T+1 ; i < I ; ++ i ) {
		
		x[t] = i * T + t < N ? X [ i * T + t ] : 0.0;
		
		threadgroup_barrier( mem_flags::mem_threadgroup );
		for( uint k = 0, K = T ; k < K ; ++ k ) {
			
			uint4 const rows_A = row;
			uint4 const cols_A = i * T + k;
			bool4 const mask_A = rows_A < M && cols_A < N;
			uint4 const indx_A = (4 * rows_A + uint4(0,1,2,3)) * N + cols_A;
			
			y += x[k] * float4x4(mask_A[0] ? A[indx_A[0]] : 0.0,
								 mask_A[1] ? A[indx_A[1]] : 0.0,
								 mask_A[2] ? A[indx_A[2]] : 0.0,
								 mask_A[3] ? A[indx_A[3]] : 0.0
								 );
			
		}
		threadgroup_barrier( mem_flags::mem_threadgroup );
	}
	if ( row < M ) Y[row] = y;
}
kernel void gemm(device float4 * const C [[ buffer(0) ]],
				 device const float4 * const A [[ buffer(1) ]],
				 device const float4 * const B [[ buffer(2) ]],
				 constant const uint & M [[ buffer(3) ]],
				 constant const uint & K [[ buffer(4) ]],
				 constant const uint & N [[ buffer(5) ]],
				 uint2 const g [[ threadgroup_position_in_grid ]],
				 uint2 const G [[ threadgroups_per_grid ]],
				 uint2 const t [[ thread_position_in_threadgroup ]],
				 uint2 const T [[ threads_per_threadgroup ]],
				 threadgroup float4x4 * a [[ threadgroup(0) ]],
				 threadgroup float4x4 * b [[ threadgroup(1) ]]
				 ){
	
	uint const col = g.x * T.x + t.x;
	uint const row = g.y * T.y + t.y;
	
	float4x4 c = float4x4(0.0);
	
	for ( uint i = 0, I = ( K - 1 ) / T.x + 1 ; i < I ; ++ i ) {
		
		uint4 const rows_A = row;
		uint4 const cols_A = i*T.x+t.x;
		bool4 const mask_A = rows_A < M && cols_A < K;
		uint4 const indx_A = (4 * rows_A + uint4(0,1,2,3)) * K + cols_A;
		
		uint4 const rows_B = i*T.y+t.y;
		uint4 const cols_B = col;
		bool4 const mask_B = rows_B < K && cols_B < N;
		uint4 const indx_B = (4 * rows_B + uint4(0,1,2,3)) * N + cols_B;
		
		a[t.y*T.x+t.x] = float4x4(mask_A[0] ? A[indx_A[0]] : 0.0,
								  mask_A[1] ? A[indx_A[1]] : 0.0,
								  mask_A[2] ? A[indx_A[2]] : 0.0,
								  mask_A[3] ? A[indx_A[3]] : 0.0);
		
		b[t.y*T.x+t.x] = float4x4(mask_B[0] ? B[indx_B[0]] : 0.0,
								  mask_B[0] ? B[indx_B[1]] : 0.0,
								  mask_B[0] ? B[indx_B[2]] : 0.0,
								  mask_B[0] ? B[indx_B[3]] : 0.0);
		
		threadgroup_barrier( mem_flags::mem_threadgroup );
		
		for ( uint k = 0, K = T.x ; k < K ; ++ k )
			c += b[ k * T.x + t.x ] * a[ t.y * T.x + k ];
		
		threadgroup_barrier( mem_flags::mem_threadgroup );
	}
	uint4 const rows_C = row;
	uint4 const cols_C = col;
	bool4 const mask_C = rows_C < K && cols_C < N;
	uint4 const indx_C = ( 4 * rows_C + uint4(0,1,2,3) ) * N + cols_C;
	
	if ( mask_C[0] ) C[indx_C[0]] = c[0];
	if ( mask_C[1] ) C[indx_C[1]] = c[1];
	if ( mask_C[2] ) C[indx_C[2]] = c[2];
	if ( mask_C[3] ) C[indx_C[3]] = c[3];
}
kernel void gemva(device float4 * y [[ buffer(0) ]],
				  device const float4 * const A [[ buffer(1) ]],
				  device const float4 * const x [[ buffer(2) ]],
				  uint const m [[ threadgroup_position_in_grid ]],
				  uint const M [[ threadgroups_per_grid ]],
				  uint const n [[ thread_position_in_threadgroup ]],
				  uint const N [[ threads_per_threadgroup ]],
				  threadgroup float4 * const accumulator [[ threadgroup(0) ]] )
{
	uint4 const idx_A = (uint4(0,1,2,3)+4*m)*N+n;
	float4x4 a = float4x4(A[idx_A[0]],
						  A[idx_A[1]],
						  A[idx_A[2]],
						  A[idx_A[3]]);
	accumulator [ n ] =  x [ n ] * a;
	uint offset = 1 << ( clz ( uint( 1 ) ) - clz ( N ) );
	threadgroup_barrier ( mem_flags::mem_threadgroup );
	if ( n < ( N % offset ) ) {
		accumulator [ n ] += accumulator [ offset + n ];
	}
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags::mem_threadgroup );
		if ( n < offset ) {
			accumulator [ n ] += accumulator [ offset + n ];
		};
	}
	if( !n )
		y[ m ] = accumulator [ n ];
}