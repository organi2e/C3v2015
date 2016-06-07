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
				const device float4 * a [[ buffer(1) ]],
				const device float4 * b [[ buffer(2) ]],
				uint id [[ thread_position_in_grid ]]
				) {
	y [ id ] = a [ id ] + b [ id ];
}
kernel void sub(device float4 * y [[ buffer(0) ]],
				const device float4 * a [[ buffer(1) ]],
				const device float4 * b [[ buffer(2) ]],
				uint id [[ thread_position_in_grid ]]
				) {
	y [ id ] = a [ id ] - b [ id ];
}
kernel void mul(device float4 * y [[ buffer(0) ]],
				const device float4 * a [[ buffer(1) ]],
				const device float4 * b [[ buffer(2) ]],
				uint id [[ thread_position_in_grid ]]
				) {
	y [ id ] = a [ id ] * b [ id ];
}
kernel void div(device float4 * y [[ buffer(0) ]],
				const device float4 * a [[ buffer(1) ]],
				const device float4 * b [[ buffer(2) ]],
				uint id [[ thread_position_in_grid ]]
				) {
	y [ id ] = a [ id ] / b [ id ];
}
//Y = alphaAX + betaY
kernel void gemv(device float4 * y [[ buffer(0) ]],
				 constant float & beta [[ buffer(1) ]],
				 const device float4x4 * A [[ buffer(2) ]],
				 uint lda_m [[ threadgroups_per_grid ]],
				 uint lda_n [[ threads_per_threadgroup ]],
				 const device float4 * x [[ buffer(3) ]],
				 constant float & alpha [[ buffer(4) ]],
				 uint n [[ thread_position_in_threadgroup ]],
				 uint m [[ threadgroup_position_in_grid ]],
				 constant bool & t [[ buffer(5) ]],
				 threadgroup float4 * accumulator [[ threadgroup(0) ]] )
{
	accumulator [ n ] = ( t ? transpose( A [ m * lda_n + n ] ) : float4x4 ( A [ n * lda_m + m ] ) ) * x [ n ];
	uint offset = 1 << ( clz ( uint( 1 ) ) - clz ( lda_n ) );
	threadgroup_barrier ( mem_flags::mem_threadgroup );
	if ( n < ( lda_n % offset ) ) {
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
