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
/*
 <unknown>:0: Test Case '-[ComputerTests.mtlComputerTests testGEMM]' measured [Time, seconds] average: 3.406, relative standard deviation: 8.578%, values: [3.096253, 3.121881, 3.561484, 3.097569, 3.135809, 3.737424, 3.566952, 3.360777, 3.994759, 3.388189], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
 Test Case '-[ComputerTests.mtlComputerTests testGEMM]' passed (35.081 seconds).
*/
/*
kernel void gemm(device float4 * const y [[ buffer(0) ]],
				 device const float4 * const w [[ buffer(1) ]],
				 device const float4 * const x [[ buffer(2) ]],
				 constant const float & alpha [[ buffer(3) ]],
				 constant const float & beta [[ buffer(4) ]],
				 constant const uint & K [[ buffer(5) ]],
				 uint const g [[ threadgroup_position_in_grid ]],
				 uint const G [[ threadgroups_per_grid ]],
				 uint const t [[ thread_position_in_threadgroup ]],
				 uint const T [[ threads_per_threadgroup ]],
				 threadgroup float4x4 * const X [[ threadgroup(0) ]]
				 ){
	if (t==0) {
		for(uint k=0;k<K;++k){
			X[k] = float4x4(x[(4*k+0)*G+g],
							x[(4*k+1)*G+g],
							x[(4*k+2)*G+g],
							x[(4*k+3)*G+g]);
		}
	}
	threadgroup_barrier ( mem_flags::mem_threadgroup );
	
	float4x4 accumulator = float4x4(0.0);
	for(uint k=0;k<K;++k) {
		accumulator += float4x4(x[(4*k+0)*G+g],
								x[(4*k+1)*G+g],
								x[(4*k+2)*G+g],
								x[(4*k+3)*G+g]) *
						float4x4(w[(4*t+0)*K+k],
								 w[(4*t+1)*K+k],
								 w[(4*t+2)*K+k],
								 w[(4*t+3)*K+k]
								 );
	}
	y[(4*t+0)*G+g] = accumulator[0];
	y[(4*t+1)*G+g] = accumulator[1];
	y[(4*t+2)*G+g] = accumulator[2];
	y[(4*t+3)*G+g] = accumulator[3];
}
*/
/*
 mem_none
 Test Case '-[ComputerTests.mtlComputerTests testGEMM]' started.
 <unknown>:0: Test Case '-[ComputerTests.mtlComputerTests testGEMM]' measured [Time, seconds] average: 18.250, relative standard deviation: 4.081%, values: [16.275147, 17.837913, 18.532227, 18.795564, 18.967208, 18.830613, 18.724124, 18.259694, 18.139502, 18.141566], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
 Test Case '-[ComputerTests.mtlComputerTests testGEMM]' passed (199.394 seconds).
 
 mem_threadgroup
 <unknown>:0: Test Case '-[ComputerTests.mtlComputerTests testGEMM]' measured [Time, seconds] average: 6.327, relative standard deviation: 6.309%, values: [5.247520, 6.326768, 6.209370, 6.342950, 6.291725, 6.479529, 6.345767, 6.765200, 6.543246, 6.714444], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
 Test Case '-[ComputerTests.mtlComputerTests testGEMM]' passed (79.675 seconds).
 */
kernel void gemm(device float4 * const C [[ buffer(0) ]],
				 device const float4 * const A [[ buffer(1) ]],
				 device const float4 * const B [[ buffer(2) ]],
				 constant const uint & N [[ buffer(3) ]],
				 constant const uint & K [[ buffer(4) ]],
				 constant const uint & M [[ buffer(5) ]],
				 uint2 const g [[ threadgroup_position_in_grid ]],
				 uint2 const G [[ threadgroups_per_grid ]],
				 uint2 const t [[ thread_position_in_threadgroup ]],
				 uint2 const T [[ threads_per_threadgroup ]],
				 threadgroup float4x4 * a [[ threadgroup(0) ]],
				 threadgroup float4x4 * b [[ threadgroup(1) ]]
				 ){
	
	uint const bx = T.x, by = T.y;
	uint const tx = t.x, ty = t.y;
	uint const col = g.x * bx + tx;
	uint const row = g.y * by + ty;
	
	float4x4 c = float4x4(0.0);
	
	for(uint i = 0 ; i < K ; ++ i ) {
		a[t.y*8+t.x] = float4x4(A[(4*row+0)*K+i*8+tx],
								A[(4*row+1)*K+i*8+tx],
								A[(4*row+2)*K+i*8+tx],
								A[(4*row+3)*K+i*8+tx]
								);
		b[t.y*8+t.x] = float4x4(B[(4*(i*8+ty)+0)*M+col],
								B[(4*(i*8+ty)+1)*M+col],
								B[(4*(i*8+ty)+2)*M+col],
								B[(4*(i*8+ty)+3)*M+col]
								);
		threadgroup_barrier( mem_flags::mem_threadgroup );
		for(uint k=0;k<8;++k)
			c += b[k*8+t.x] * a[t.y*8+k];
		threadgroup_barrier( mem_flags::mem_threadgroup );
	}
	C[((8*g.y+t.y)*4+0)*M+(8*g.x+t.x)] = c[0];
	C[((8*g.y+t.y)*4+1)*M+(8*g.x+t.x)] = c[1];
	C[((8*g.y+t.y)*4+2)*M+(8*g.x+t.x)] = c[2];
	C[((8*g.y+t.y)*4+3)*M+(8*g.x+t.x)] = c[3];
}

/*
kernel void gemm(device float * const C [[ buffer(0) ]],
				 device const float * const A [[ buffer(1) ]],
				 device const float * const B [[ buffer(2) ]],
				 constant const uint & N [[ buffer(3) ]],
				 constant const uint & K [[ buffer(4) ]],
				 constant const uint & M [[ buffer(5) ]],
				 uint2 const g [[ threadgroup_position_in_grid ]],
				 uint2 const G [[ threadgroups_per_grid ]],
				 uint2 const t [[ thread_position_in_threadgroup ]],
				 uint2 const T [[ threads_per_threadgroup ]],
				 threadgroup float * a [[ threadgroup(0) ]],
				 threadgroup float * b [[ threadgroup(1) ]]
				 ){
	
	uint const bx = T.x, by = T.y;
	uint const tx = t.x, ty = t.y;
	uint const col = g.x * bx + tx;
	uint const row = g.y * by + ty;
	
	float c = 0.0;
	
	for(uint m = 0 ; m < K ; ++ m ) {
		a[ty*bx+tx] = A[row*K+m*8+tx];
		b[ty*bx+tx] = B[(m*8+ty)*M+col];
		threadgroup_barrier( mem_flags::mem_threadgroup );
		for(uint k=0;k<8;++k)
			c += a[ty*bx+k] * b[k*bx+tx];
		//threadgroup_barrier( mem_flags::mem_threadgroup );
	}
	C[row*M+col] = c;
}
*/
/*
kernel void gemm2(device float4x4 * y [[ buffer(0) ]],
				 device const float4x4 * const A [[ buffer(1) ]],
				 device const float4x4 * const X [[ buffer(2) ]],
				 constant const float & alpha [[ buffer(3) ]],
				 constant const float & beta [[ buffer(4) ]],
				 constant const bool & ta [[ buffer(5) ]],
				 constant const bool & tx [[ buffer(6) ]],
				 constant const uint & K [[ buffer(7) ]],
				 uint const i [[ threadgroup_position_in_grid ]],
				 uint const I [[ threadgroups_per_grid ]],
				 uint const j [[ thread_position_in_threadgroup ]],
				 uint const J [[ threads_per_threadgroup ]])
{
	float4x4 accumulator = float4x4(0.0);
	for(uint k = 0 ; k < K ; ++ k ) {
		accumulator +=
			( ta ? transpose( A [ i * K + k ] ) : float4x4 ( A [ k * I + i ] ) ) *
			( tx ? transpose( X [ k * J + j ] ) : float4x4 ( X [ j * K + k ] ) );
	}
	y[j*I+i] = alpha * accumulator + beta * y[j*I+i];
	
	
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

kernel void gemm1(device float4x4 * y [[ buffer(0) ]],
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
 */
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