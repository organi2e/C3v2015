//
//  linalg.metal
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

#include <metal_stdlib>
using namespace metal;

kernel void add(device float4 * y [[ buffer(0) ]],
				device const float4 * const a [[ buffer(1) ]],
				device const float4 * const b [[ buffer(2) ]],
				uint const id [[ thread_position_in_grid ]]
				) {
	y [ id ] = a [ id ] + b [ id ];
}
kernel void sub(device float4 * y [[ buffer(0) ]],
				device const float4 * const a [[ buffer(1) ]],
				device const float4 * const b [[ buffer(2) ]],
				uint const id [[ thread_position_in_grid ]]
				) {
	y [ id ] = a [ id ] - b [ id ];
}
kernel void mul(device float4 * y [[ buffer(0) ]],
				device float4 * const a [[ buffer(1) ]],
				device float4 * const b [[ buffer(2) ]],
				uint const id [[ thread_position_in_grid ]]
				) {
	y [ id ] = a [ id ] * b [ id ];
}
kernel void div(device float4 * y [[ buffer(0) ]],
				device float4 * const a [[ buffer(1) ]],
				device float4 * const b [[ buffer(2) ]],
				uint const id [[ thread_position_in_grid ]]
				) {
	y [ id ] = a [ id ] / b [ id ];
}
//Y = alphaAX + betaY
kernel void gemv(device float4 * y [[ buffer(0) ]],
				 device const float4x4 * const A [[ buffer(1) ]],
				 device const float4 * const x [[ buffer(2) ]],
				 constant const float & alpha [[ buffer(3) ]],
				 constant const float & beta [[ buffer(4) ]],
				 constant const bool & t [[ buffer(5) ]],
				 uint const m [[ threadgroup_position_in_grid ]],
				 uint const M [[ threadgroups_per_grid ]],
				 uint const n [[ thread_position_in_threadgroup ]],
				 uint const N [[ threads_per_threadgroup ]],
				 threadgroup float4 * const accumulator [[ threadgroup(0) ]] )
{
	accumulator [ n ] = ( t ? transpose( A [ m * N + n ] ) : float4x4 ( A [ n * M + m ] ) ) * x [ n ];
	uint offset = 1 << ( clz ( uint( 1 ) ) - clz ( N ) );
	threadgroup_barrier ( mem_flags::mem_threadgroup );
	if ( n < ( N % offset ) ) {
		accumulator [ n ] += accumulator [ offset + n ];
	}
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags::mem_threadgroup );
		if ( n < offset ) {
			accumulator [ n ] += accumulator [ offset + n ];
		}
	}
	if( !n )
		y[ m ] = alpha * accumulator [ n ] + beta * y[ m ];
}
//Y = alphaAX + betaY
kernel void gemm(device float4x4 * y [[ buffer(0) ]],
				 device const float4x4 * const A [[ buffer(1) ]],
				 device const float4x4 * const X [[ buffer(2) ]],
				 constant const float & alpha [[ buffer(3) ]],
				 constant const float & beta [[ buffer(4) ]],
				 constant const bool & ta [[ buffer(5) ]],
				 constant const bool & tx [[ buffer(6) ]],
				 uint3 const m [[ threadgroup_position_in_grid ]],
				 uint3 const M [[ threadgroups_per_grid ]],
				 uint3 const n [[ thread_position_in_threadgroup ]],
				 uint3 const N [[ threads_per_threadgroup ]],
				 threadgroup float4x4 * const accumulator [[ threadgroup(0) ]] )
{
	uint const i = m.x, I = M.x;
	uint const j = m.y, J = M.y;
	uint const k = n.z, K = N.z;
	
	accumulator [ k ] = ( ta ? transpose( A [ i * K + k ] ) : float4x4 ( A [ k * I + i ] ) ) * ( tx ? transpose( X [ k * J + j ] ) : float4x4 ( X [ j * K + k ] ) );
	
	uint offset = 1 << ( clz ( uint( 1 ) ) - clz ( K ) );
	threadgroup_barrier ( mem_flags::mem_threadgroup );
	if ( k < ( K % offset ) ) {
		accumulator [ k ] += accumulator [ offset + k ];
	}
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags::mem_threadgroup );
		if ( k < offset ) {
			accumulator [ k ] += accumulator [ offset + k ];
		}
	}
	if( !k )
		y[ j * I + i ] = alpha * accumulator [ k ] + beta * y[ j * I + i ];
}
kernel void transpose(device float4x4 * y [[ buffer(0) ]],
					  device const float4x4 * x [[ buffer(1) ]],
					  uint const m [[ threadgroup_position_in_grid ]],
					  uint const M [[ threadgroups_per_grid ]],
					  uint const n [[ thread_position_in_threadgroup ]],
					  uint const N [[ threads_per_threadgroup ]]
					  ) {
	float4x4 v = transpose(y[0]);
	threadgroup_barrier( mem_flags :: mem_device_and_threadgroup );
}