//
//  MM.metal
//  MM
//
//  Created by Kota Nakano on 8/27/16.
//  Copyright © 2016 organi2e. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void exp4(device float4 * const y [[ buffer(0) ]],
				  const device float4 * const x [[ buffer(1) ]],
				  uint const n [[ thread_position_in_grid ]],
				  uint const N [[ threads_per_grid ]]) {
	y[n] = exp(x[n]);
}

kernel void tan4(device float4 * const y [[ buffer(0) ]],
				  const device float4 * const x [[ buffer(1) ]],
				  uint const n [[ thread_position_in_grid ]],
				  uint const N [[ threads_per_grid ]]) {
	y[n] = tanpi(x[n]);
}

kernel void step4(device float4 * const y [[ buffer(0) ]],
				  const device float4 * const x [[ buffer(1) ]],
				  uint const n [[ thread_position_in_grid ]],
				  uint const N [[ threads_per_grid ]]) {
	y[n] = step(0.0, x[n]);
}

kernel void sign4(device float4 * const y [[ buffer(0) ]],
				  const device float4 * const x [[ buffer(1) ]],
				  uint const n [[ thread_position_in_grid ]],
				  uint const N [[ threads_per_grid ]]) {
	y[n] = sign(x[n]);
}

kernel void sign(device float * const y [[ buffer(0) ]],
				 const device float * const x [[ buffer(1) ]],
				 uint const n [[ thread_position_in_grid ]],
				 uint const N [[ threads_per_grid ]]) {
	y[n] = sign(x[n]);
}

kernel void gemm1x1(device float * const C [[ buffer(0) ]],
					device const float * const A [[ buffer(1) ]],
					device const float * const B [[ buffer(2) ]],
					constant uint const & K [[ buffer(3) ]],
					threadgroup float * cacheA [[ threadgroup(0) ]],
					threadgroup float * cacheB [[ threadgroup(1) ]],
					uint2 g [[ threadgroup_position_in_grid ]],
					uint2 G [[ threadgroups_per_grid ]],
					uint2 t [[ thread_position_in_threadgroup ]],
					uint2 T [[ threads_per_threadgroup ]]) {
	uint const cols = G.x * 16, col = g.x * 16 + t.x;
	uint const rows = G.y * 16, row = g.y * 16 + t.y;
	float c = 0;
	for( uint k = 0 ; k < K ; k += 16 ) {
		threadgroup float * ta = cacheA + t.x*16;
		threadgroup float * tb = cacheB + t.y*16;
		ta[t.y] = A[row*cols+k];
		tb[t.x] = B[k*cols+col];
		threadgroup_barrier(mem_flags::mem_threadgroup);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		threadgroup_barrier(mem_flags::mem_threadgroup);
	}
	C[row*cols+col] = c;
}
kernel void gemm4x4(device float4x4 * const C [[ buffer(0) ]],
					device const float4x4 * const A [[ buffer(1) ]],
					device const float4x4 * const B [[ buffer(2) ]],
					constant uint const & K [[ buffer(3) ]],
					threadgroup float4x4 * cacheA [[ threadgroup(0) ]],
					threadgroup float4x4 * cacheB [[ threadgroup(1) ]],
					uint2 g [[ threadgroup_position_in_grid ]],
					uint2 G [[ threadgroups_per_grid ]],
					uint2 t [[ thread_position_in_threadgroup ]],
					uint2 T [[ threads_per_threadgroup ]]) {
	uint const cols = G.x * 16, col = g.x * 16 + t.x;
	uint const rows = G.y * 16, row = g.y * 16 + t.y;
	float4x4 c = float4x4(0.0);
	for( uint k = 0 ; k < K ; k += 16 ) {
		threadgroup float4x4 * ta = cacheA + t.x*16;
		threadgroup float4x4 * tb = cacheB + t.y*16;
		ta[t.y] = A[row*cols+k];
		tb[t.x] = B[k*cols+col];
		threadgroup_barrier(mem_flags::mem_threadgroup);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		c += *(ta++) * *(tb++);
		
		threadgroup_barrier(mem_flags::mem_threadgroup);
	}
	C[row*cols+col] = c;
}

