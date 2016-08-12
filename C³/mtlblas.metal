//
//  blas.metal
//  C³
//
//  Created by Kota Nakano on 8/5/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void gemvt(device float4 * y [[ buffer(0) ]],
				  device const float4x4 * const A [[ buffer(1) ]],
				  device const float4 * const x [[ buffer(2) ]],
				  constant uint2 const & dim [[ buffer(3) ]],
				  constant float2 const & w [[ buffer(4) ]],
				  uint const g [[ threadgroup_position_in_grid ]],
				  uint const G [[ threadgroups_per_grid ]],
				  uint const t [[ thread_position_in_threadgroup ]],
				  uint const T [[ threads_per_threadgroup ]],
				  threadgroup float4 * const accumulator [[ threadgroup(0) ]] )
{
	//uint const M = dim.x;
	uint const N = dim.y;
	
	uint const rows = g;
	float4 vector = 0.0;
	for ( uint i = 0, I = N ; i < I ; i += T ) {
		uint const cols = i + t;
		if ( cols < N ) {
			vector +=  x[cols] * A[rows*N+cols];
		}
	}
	accumulator[t] = vector;
	
	uint offset = T;
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags :: mem_threadgroup );
		if ( t < offset ) {
			accumulator [ t ] += accumulator [ t + offset ];
		};
	}
	if( !t )
		y[ g ] = w.x * accumulator [ t ] + w.y * y[ g ];
}
kernel void gemv(device float4 * y [[ buffer(0) ]],
				 device const float4x4 * const A [[ buffer(1) ]],
				 device const float4 * const x [[ buffer(2) ]],
				 constant uint2 const & dim [[ buffer(3) ]],
				 constant float2 const & w [[ buffer(4) ]],
				 uint const g [[ threadgroup_position_in_grid ]],
				 uint const G [[ threadgroups_per_grid ]],
				 uint const t [[ thread_position_in_threadgroup ]],
				 uint const T [[ threads_per_threadgroup ]],
				 threadgroup float4 * const accumulator [[ threadgroup(0) ]] )
{
	uint const M = dim.x;
	uint const N = dim.y;
	uint const rows = g;

	float4 vector = 0.0;
	for ( uint i = 0, I = N ; i < I ; i += T ) {
		uint const cols = i + t;
		if ( cols < N ) {
			vector += A[cols*M+rows] * x[cols];
		}
	}
	accumulator[t] = vector;
	
	uint offset = T;
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags :: mem_threadgroup );
		if ( t < offset ) {
			accumulator [ t ] += accumulator [ t + offset ];
		};
	}
	if( !t )
		y[ g ] = w.x * accumulator [ t ] + w.y * y[ g ];
}
kernel void gemm(device float4x4 * const C [[ buffer(0) ]],
				 device const float4x4 * const A [[ buffer(1) ]],
				 device const float4x4 * const B [[ buffer(2) ]],
				 constant const uint4 & dim [[ buffer(3) ]],
				 constant const float2 & w [[ buffer(4) ]],
				 uint2 const g [[ threadgroup_position_in_grid ]],
				 uint2 const G [[ threadgroups_per_grid ]],
				 uint2 const t [[ thread_position_in_threadgroup ]],
				 uint2 const T [[ threads_per_threadgroup ]],
				 threadgroup float4x4 * a [[ threadgroup(0) ]],
				 threadgroup float4x4 * b [[ threadgroup(1) ]]
				 )
{
	uint const M = dim.x;
	uint const K = dim.y;
	uint const N = dim.z;
	uint const L = dim.w;
	
	uint const rows_C = g.y * L + t.y;
	uint const cols_C = g.x * L + t.x;
	
	float4x4 c = float4x4(0.0);
	
	threadgroup float4x4 * a_ref = a + L * t.y;
	threadgroup float4x4 * b_ref = b + L * t.x;
	
	for ( uint i = 0, I = K ; i < I ; i += L ) {
		
		uint const rows_A = rows_C;
		uint const cols_A = i + t.x;
			
		a_ref[t.x] = rows_A < M && cols_A < K ? float4x4(A[cols_A*M+rows_A]) : float4x4(0.0);
		
		uint const rows_B = i + t.y;
		uint const cols_B = cols_C;

		b_ref[t.y] = rows_B < K && cols_B < N ? float4x4(B[cols_B*K+rows_B]) : float4x4(0.0);
			
		threadgroup_barrier( mem_flags :: mem_threadgroup );
			
		for ( uint k = 0, K = L ; k < K ; ++ k )
			c += a_ref[ k ] * b_ref[ k ];
			
		threadgroup_barrier( mem_flags :: mem_threadgroup );
	}
	if ( rows_C < M && cols_C < N ) {
		uint const idx = cols_C * M + rows_C;
		C[idx] = w.x * c + w.y * C[idx];
	}
}
kernel void outer(device float4x4 * const C [[ buffer(0) ]],
				  device const float4 * const A [[ buffer(1) ]],
				  device const float4 * const B [[ buffer(2) ]],
				  constant uint2 const & dim [[ buffer(3) ]],
				  constant float2 const & w [[ buffer(4) ]],
				  uint const g [[ threadgroup_position_in_grid ]],
				  uint const G [[ threadgroups_per_grid ]],
				  uint const t [[ thread_position_in_threadgroup ]],
				  uint const T [[ threads_per_threadgroup ]])
{
	uint const M = dim.x;
	//uint const N = dim.y;
	uint const cols = g;
	float4 const b = B[cols];
	for( uint k = 0, K = M ; k < K ; k += T ) {
		uint const rows = k + t;
		if ( rows < M ) {
			float4 const a = A [ rows ];
			uint const idx = cols * M + rows;
			float4x4 const c = float4x4(a*b.x, a*b.y, a*b.z, a*b.w);
			C[idx] = w.x * c + w.y * C[idx];
		}
	}
}
kernel void sub(device float4 * c [[ buffer(0) ]],
				device const float4 * a [[ buffer(1) ]],
				device const float4 * b [[ buffer(2) ]],
				uint const n [[ thread_position_in_grid ]],
				uint const N [[ threads_per_grid ]]
				)
{
	c[n] = a[n] - b[n];
}
kernel void fromRowMajorMatrix(device float4x4 * dst [[ buffer(0) ]],
							   const device float4 * src [[ buffer(1) ]],
							   constant uint const & M [[ buffer(2) ]],
							   constant uint const & N [[ buffer(3) ]],
							   uint2 const t [[ thread_position_in_grid ]],
							   uint2 const T [[ threads_per_grid ]]) {
	uint const m = t.y;
	uint const n = t.x;
	uint4 ref = ( 4 * m + uint4(0, 1, 2, 3 ) ) * N + n;
	float4x4 v = float4x4(src[ref.x],
						  src[ref.y],
						  src[ref.z],
						  src[ref.w]);
	dst[n*M+m] = transpose(v);
}
kernel void toRowMajorMatrix(device float4 * dst [[ buffer(0) ]],
							 const device float4x4 * src [[ buffer(1) ]],
							 constant uint const & M [[ buffer(2) ]],
							 constant uint const & N [[ buffer(3) ]],
							 uint2 const t [[ thread_position_in_grid ]],
							 uint2 const T [[ threads_per_grid ]]) {
	uint const m = t.y;
	uint const n = t.x;
	uint4 ref = ( 4 * m + uint4(0, 1, 2, 3) ) * N + n;
	float4x4 v = transpose(src[n*M+m]);
	dst[ref.x] = v[0];
	dst[ref.y] = v[1];
	dst[ref.z] = v[2];
	dst[ref.w] = v[3];
}
