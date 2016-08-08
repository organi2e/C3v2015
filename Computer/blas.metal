//
//  linalg.metal
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//

#include <metal_stdlib>
#include <metal_common>
#include <metal_atomic>
#include <metal_math>
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
/*4096*4096
 <unknown>:0: Test Case '-[ComputerTests.mtlComputerTests testOuterProduct]' measured [Time, seconds] average: 0.472, relative standard deviation: 3.437%, values: [0.519003, 0.473434, 0.475507, 0.467887, 0.462862, 0.462153, 0.460501, 0.464026, 0.469315, 0.468458], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
 Test Case '-[ComputerTests.mtlComputerTests testOuterProduct]' passed (18.019 seconds).
 */
/*
kernel void outerproduct(device float4 * const C [[ buffer(0) ]],
						 device const float4 * const A [[ buffer(1) ]],
						 device const float4 * const B [[ buffer(2) ]],
						 constant const uint & M [[ buffer(3) ]],
						 constant const uint & N [[ buffer(4) ]],
						 uint2 const g [[ threadgroup_position_in_grid ]],
						 uint2 const G [[ threadgroups_per_grid ]],
						 uint2 const t [[ thread_position_in_threadgroup ]],
						 uint2 const T [[ threads_per_threadgroup ]]
						 ){
	float4x4 a = float4x4(A[g.y],float4(0.0),float4(0.0),float4(0.0));
	float4x4 b = float4x4(B[g.x],float4(0.0),float4(0.0),float4(0.0));
	
	float4x4 c = b * transpose(a);
	
	C[(4*g.y+0)*G.x+g.x] = c[0];
	C[(4*g.y+1)*G.x+g.x] = c[1];
	C[(4*g.y+2)*G.x+g.x] = c[2];
	C[(4*g.y+3)*G.x+g.x] = c[3];
	
}
 */
/*
 <unknown>:0: Test Case '-[ComputerTests.mtlComputerTests testOuterProduct]' measured [Time, seconds] average: 0.118, relative standard deviation: 11.988%, values: [0.160577, 0.116588, 0.112900, 0.112105, 0.112194, 0.113642, 0.117755, 0.114637, 0.112146, 0.111482], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
 Test Case '-[ComputerTests.mtlComputerTests testOuterProduct]' passed (14.604 seconds).
 */
kernel void gemmx(device float4 * C [[ buffer(0) ]],
				  device const float4 * const A [[ buffer(1) ]],
				  device const float4 * const B [[ buffer(2) ]],
				  constant const uint & M [[ buffer(3) ]],
				  constant const uint & K [[ buffer(4) ]],
				  constant const uint & N [[ buffer(5) ]],
				  uint2 const g [[ threadgroup_position_in_grid ]],
				  uint2 const G [[ threadgroups_per_grid ]],
				  uint2 const t [[ thread_position_in_threadgroup ]],
				  uint2 const T [[ threads_per_threadgroup ]],
				  threadgroup float4x4 * const c [[ threadgroup(0) ]] )
{
	uint s = t.x;
	uint S = T.x;
	
	c[s] = float4x4(0.0);
	
	for( uint k = 0 ; k < K ; k += S ) {
		
		uint4 idx_a = (4 * g.y + uint4(0,1,2,3))*M+k+s;
		float4x4 a = float4x4(A[idx_a.x],
							  A[idx_a.y],
							  A[idx_a.z],
							  A[idx_a.w]);
		
		uint4 idx_b = (4*(k+s)+uint4(0,1,2,3))*N+(g.x);
		float4x4 b = float4x4(B[idx_b.x],
							  B[idx_b.y],
							  B[idx_b.z],
							  B[idx_b.w]
							  );
		c[s] += b * a;
	}
	
	while ( S >>= 1 ) {
		threadgroup_barrier ( mem_flags::mem_threadgroup );
		if ( s < S ) {
			c[s]+=c[S+s];
		};
	}
	
	if(!s) {
		uint4 idx_c = (4*g.y+uint4(0,1,2,3))*G.x+g.x;
		C[idx_c.x] = c[0][0];
		C[idx_c.y] = c[0][1];
		C[idx_c.z] = c[0][2];
		C[idx_c.w] = c[0][3];
	}
}

kernel void outerproduct(device float4 * const C [[ buffer(0) ]],
						 device const float4 * const A [[ buffer(1) ]],
						 device const float4 * const B [[ buffer(2) ]],
						 constant const uint & M [[ buffer(3) ]],
						 constant const uint & N [[ buffer(4) ]],
						 uint const g [[ threadgroup_position_in_grid ]],
						 uint const G [[ threadgroups_per_grid ]],
						 uint const t [[ thread_position_in_threadgroup ]],
						 uint const T [[ threads_per_threadgroup ]]
						 ){
	
	threadgroup float4 a;
	
	if ( !t ) a = A[g];
	
	threadgroup_barrier ( mem_flags :: mem_threadgroup );

	for( uint k = 0, K = N ; k < K ; k += T ) {
		float4 const b = k + t < N ? B [ k + t ] : 0.0;
		uint4 const row = g;
		uint4 const col = k + t;
		bool4 const msk = row < M && col < N;
		uint4 const idx = ( uint4 ( 0, 1, 2, 3 ) + 4 * row ) * N + col;
		if ( msk.x ) C [ idx.x ] = a.x * b;
		if ( msk.y ) C [ idx.y ] = a.y * b;
		if ( msk.z ) C [ idx.z ] = a.z * b;
		if ( msk.w ) C [ idx.w ] = a.w * b;
	}
}

kernel void gemv4(device float4 * Y [[ buffer(0) ]],
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
kernel void gemv(device float4 * y [[ buffer(0) ]],
				 device const float4 * const A [[ buffer(1) ]],
				 device const float4 * const x [[ buffer(2) ]],
				 constant const uint & M [[ buffer(3) ]],
				 constant const uint & N [[ buffer(4) ]],
				 uint const g [[ threadgroup_position_in_grid ]],
				 uint const G [[ threadgroups_per_grid ]],
				 uint const t [[ thread_position_in_threadgroup ]],
				 uint const T [[ threads_per_threadgroup ]],
				 threadgroup float4 * const accumulator [[ threadgroup(0) ]] )
{
	accumulator[t] = 0;
	
	for ( uint k = 0, K = N ; k < K ; k += T ) {
		
		uint4 const row = g;
		uint4 const col = k + t;
		bool4 const msk = row < M && col < N;
		uint4 const idx = ( uint4(0, 1, 2, 3) + 4 * row ) * K + col;
	
		accumulator [ t ] +=  x [ k + t ] * float4x4(msk.x ? A[idx.x] : 0.0,
													 msk.y ? A[idx.y] : 0.0,
													 msk.z ? A[idx.z] : 0.0,
													 msk.w ? A[idx.w] : 0.0);

	}
	
	uint offset = T;
	while ( offset >>= 1 ) {
		threadgroup_barrier ( mem_flags::mem_threadgroup );
		if ( t < offset ) {
			accumulator [ t ] += accumulator [ t + offset ];
		};
	}
	if( !t )
		y[ g ] = accumulator [ t ];
}
/*
kernel void gemv(device float4 * y [[ buffer(0) ]],
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
*/
/*
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
 */
//Y = alphaAX + betaY
/*
 <unknown>:0: Test Case '-[ComputerTests.mtlComputerTests testGEMM]' measured [Time, seconds] average: 3.406, relative standard deviation: 8.578%, values: [3.096253, 3.121881, 3.561484, 3.097569, 3.135809, 3.737424, 3.566952, 3.360777, 3.994759, 3.388189], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
 Test Case '-[ComputerTests.mtlComputerTests testGEMM]' passed (35.081 seconds).
*/
kernel void gemm(device float4 * const C [[ buffer(0) ]],
				 device const float4 * const A [[ buffer(1) ]],
				 device const float4 * const B [[ buffer(2) ]],
				 constant const uint & M [[ buffer(3) ]],
				 constant const uint & K [[ buffer(4) ]],
				 constant const uint & N [[ buffer(5) ]],
				 uint3 const g [[ threadgroup_position_in_grid ]],
				 uint3 const G [[ threadgroups_per_grid ]],
				 uint3 const t [[ thread_position_in_threadgroup ]],
				 uint3 const T [[ threads_per_threadgroup ]],
				 threadgroup float4x4 * const a [[ threadgroup(0) ]],
				 threadgroup float4x4 * const b [[ threadgroup(1) ]],
				 threadgroup float4x4 * const c [[ threadgroup(2) ]]
				 ){
	
	uint const col = g.x * T.x + t.x;
	uint const row = g.y * T.y + t.y;
	
	c[t.z] = float4x4(0.0);
	for ( uint i = 0, I = K ; i < I ; i += T.x ) {
		
		uint4 const rows_A = row;
		uint4 const cols_A = i+t.x;
		bool4 const mask_A = rows_A < M && cols_A < K;
		uint4 const indx_A = (4 * rows_A + uint4(0,1,2,3)) * K + cols_A;
		
		uint4 const rows_B = i+t.y;
		uint4 const cols_B = col;
		bool4 const mask_B = rows_B < K && cols_B < N;
		uint4 const indx_B = (4 * rows_B + uint4(0,1,2,3)) * N + cols_B;
		
		a[t.y*T.x+t.x] = float4x4(mask_A[0] ? A[indx_A[0]] : 0.0,
								  mask_A[1] ? A[indx_A[1]] : 0.0,
								  mask_A[2] ? A[indx_A[2]] : 0.0,
								  mask_A[3] ? A[indx_A[3]] : 0.0);
		
		b[t.y*T.x+t.x] = float4x4(mask_B[0] ? B[indx_B[0]] : 0.0,
								  mask_B[1] ? B[indx_B[1]] : 0.0,
								  mask_B[2] ? B[indx_B[2]] : 0.0,
								  mask_B[3] ? B[indx_B[3]] : 0.0);
		
		threadgroup_barrier( mem_flags::mem_threadgroup );
		
		for ( uint k = 0, K = T.x ; k < K ; k += T.z )
			c[t.z] += b[ (k+t.z) * T.x + t.x ] * a[ t.y * T.x + (k+t.z)];
		
		threadgroup_barrier( mem_flags::mem_threadgroup );
		
	}
	
	uint offset = T.z;
	while(offset>>=1) {
		threadgroup_barrier( mem_flags::mem_threadgroup );
		if (t.z<offset) {
			c[t.z] += c[t.z+offset];
		}
		threadgroup_barrier( mem_flags::mem_threadgroup );
	}
	
	if ( t.z == 0 ) {
		
		uint4 const rows_C = row;
		uint4 const cols_C = col;
		bool4 const mask_C = rows_C < K && cols_C < N;
		uint4 const indx_C = ( 4 * rows_C + uint4(0,1,2,3) ) * N + cols_C;
	
		if ( mask_C[0] ) C[indx_C[0]] = c[0][0];
		if ( mask_C[1] ) C[indx_C[1]] = c[0][1];
		if ( mask_C[2] ) C[indx_C[2]] = c[0][2];
		if ( mask_C[3] ) C[indx_C[3]] = c[0][3];
	}
}

/*
 mem_none
 Test Case '-[ComputerTests.mtlComputerTests testGEMM]' started.
 <unknown>:0: Test Case '-[ComputerTests.mtlComputerTests testGEMM]' measured [Time, seconds] average: 18.250, relative standard deviation: 4.081%, values: [16.275147, 17.837913, 18.532227, 18.795564, 18.967208, 18.830613, 18.724124, 18.259694, 18.139502, 18.141566], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
 Test Case '-[ComputerTests.mtlComputerTests testGEMM]' passed (199.394 seconds).
 
 mem_threadgroup
 <unknown>:0: Test Case '-[ComputerTests.mtlComputerTests testGEMM]' measured [Time, seconds] average: 6.327, relative standard deviation: 6.309%, values: [5.247520, 6.326768, 6.209370, 6.342950, 6.291725, 6.479529, 6.345767, 6.765200, 6.543246, 6.714444], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
 Test Case '-[ComputerTests.mtlComputerTests testGEMM]' passed (79.675 seconds).
 */
/*
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
	
	float4x4 c[2][2] = {{float4x4(0.0),float4x4(0.0)},{float4x4(0.0),float4x4(0.0)}};
	
	for(uint i = 0 ; i < K ; ++ i ) {
		
		a[(2*t.y+0)*8+(2*t.x+0)] = float4x4(A[(8*row+0)*K+(i*8+tx)*2+0],
											A[(8*row+1)*K+(i*8+tx)*2+0],
											A[(8*row+2)*K+(i*8+tx)*2+0],
											A[(8*row+3)*K+(i*8+tx)*2+0]
											);
		
		a[(2*t.y+0)*8+(2*t.x+1)] = float4x4(A[(8*row+0)*K+(i*8+tx)*2+1],
											A[(8*row+1)*K+(i*8+tx)*2+1],
											A[(8*row+2)*K+(i*8+tx)*2+1],
											A[(8*row+3)*K+(i*8+tx)*2+1]);
		
		a[(2*t.y+1)*8+(2*t.x+0)] = float4x4(A[(8*row+4)*K+(i*8+tx)*2+0],
											A[(8*row+5)*K+(i*8+tx)*2+0],
											A[(8*row+6)*K+(i*8+tx)*2+0],
											A[(8*row+7)*K+(i*8+tx)*2+0]);
		
		a[(2*t.y+1)*8+(2*t.x+1)] = float4x4(A[(8*row+4)*K+(i*8+tx)*2+1],
											A[(8*row+5)*K+(i*8+tx)*2+1],
											A[(8*row+6)*K+(i*8+tx)*2+1],
											A[(8*row+7)*K+(i*8+tx)*2+1]);
		
		b[(2*t.y+0)*8+(2*t.x+0)] = float4x4(B[(4*(i*8+(2*ty+0))+0)*M+(2*col+0)],
											B[(4*(i*8+(2*ty+0))+1)*M+(2*col+0)],
											B[(4*(i*8+(2*ty+0))+2)*M+(2*col+0)],
											B[(4*(i*8+(2*ty+0))+3)*M+(2*col+0)]);
		
		b[(2*t.y+0)*8+(2*t.x+1)] = float4x4(B[(4*(i*8+(2*ty+0))+0)*M+(2*col+1)],
											B[(4*(i*8+(2*ty+0))+1)*M+(2*col+1)],
											B[(4*(i*8+(2*ty+0))+2)*M+(2*col+1)],
											B[(4*(i*8+(2*ty+0))+3)*M+(2*col+1)]);
		
		b[(2*t.y+1)*8+(2*t.x+0)] = float4x4(B[(4*(i*8+(2*ty+1))+0)*M+(2*col+0)],
											B[(4*(i*8+(2*ty+1))+1)*M+(2*col+0)],
											B[(4*(i*8+(2*ty+1))+2)*M+(2*col+0)],
											B[(4*(i*8+(2*ty+0))+3)*M+(2*col+0)]);
		
		b[(2*t.y+1)*8+(2*t.x+1)] = float4x4(B[(4*(i*8+(2*ty+1))+0)*M+(2*col+1)],
											B[(4*(i*8+(2*ty+1))+1)*M+(2*col+1)],
											B[(4*(i*8+(2*ty+1))+2)*M+(2*col+1)],
											B[(4*(i*8+(2*ty+0))+3)*M+(2*col+1)]);
		
		threadgroup_barrier( mem_flags::mem_threadgroup );
		for(uint k=0;k<8;++k) {
			c[0][0] += b[(2*k+0)*8+(2*t.x+0)] * a[(2*t.y+0)*8+2*k+0];
			c[0][1] += b[(2*k+0)*8+(2*t.x+1)] * a[(2*t.y+0)*8+2*k+1];
			c[1][0] += b[(2*k+1)*8+(2*t.x+0)] * a[(2*t.y+1)*8+2*k+0];
			c[1][1] += b[(2*k+1)*8+(2*t.x+1)] * a[(2*t.y+1)*8+2*k+1];
		}
		threadgroup_barrier( mem_flags::mem_threadgroup );
	}
	
	C[((8*g.y+t.y)*8+0)*M+(8*g.x+t.x)*2+0] = c[0][0][0];
	C[((8*g.y+t.y)*8+1)*M+(8*g.x+t.x)*2+0] = c[0][0][1];
	C[((8*g.y+t.y)*8+2)*M+(8*g.x+t.x)*2+0] = c[0][0][2];
	C[((8*g.y+t.y)*8+3)*M+(8*g.x+t.x)*2+0] = c[0][0][3];
	
	C[((8*g.y+t.y)*8+0)*M+(8*g.x+t.x)*2+1] = c[0][1][0];
	C[((8*g.y+t.y)*8+1)*M+(8*g.x+t.x)*2+1] = c[0][1][1];
	C[((8*g.y+t.y)*8+2)*M+(8*g.x+t.x)*2+1] = c[0][1][2];
	C[((8*g.y+t.y)*8+3)*M+(8*g.x+t.x)*2+1] = c[0][1][3];
	
	C[((8*g.y+t.y)*8+4)*M+(8*g.x+t.x)*2+0] = c[1][0][0];
	C[((8*g.y+t.y)*8+5)*M+(8*g.x+t.x)*2+0] = c[1][0][1];
	C[((8*g.y+t.y)*8+6)*M+(8*g.x+t.x)*2+0] = c[1][0][2];
	C[((8*g.y+t.y)*8+7)*M+(8*g.x+t.x)*2+0] = c[1][0][3];
	
	C[((8*g.y+t.y)*8+4)*M+(8*g.x+t.x)*2+1] = c[1][1][0];
	C[((8*g.y+t.y)*8+5)*M+(8*g.x+t.x)*2+1] = c[1][1][1];
	C[((8*g.y+t.y)*8+6)*M+(8*g.x+t.x)*2+1] = c[1][1][2];
	C[((8*g.y+t.y)*8+7)*M+(8*g.x+t.x)*2+1] = c[1][1][3];
}
*/
kernel void gemm8(device float4 * const C [[ buffer(0) ]],
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
	
	float4x4 c[2][2] = {{float4x4(0.0),float4x4(0.0)},{float4x4(0.0),float4x4(0.0)}};
	
	for(uint i = 0 ; i < K/T.x ; ++ i ) {
		a[4*(t.y*T.x+t.x)+0] = float4x4(A[(8*row+0)*K+2*(i*T.x+t.x)+0],
										A[(8*row+1)*K+2*(i*T.x+t.x)+0],
										A[(8*row+2)*K+2*(i*T.x+t.x)+0],
										A[(8*row+3)*K+2*(i*T.x+t.x)+0]);
		
		a[4*(t.y*T.x+t.x)+1] = float4x4(A[(8*row+0)*K+2*(i*T.x+t.x)+1],
										A[(8*row+1)*K+2*(i*T.x+t.x)+1],
										A[(8*row+2)*K+2*(i*T.x+t.x)+1],
										A[(8*row+3)*K+2*(i*T.x+t.x)+1]);
		
		a[4*(t.y*T.x+t.x)+2] = float4x4(A[(8*row+4)*K+2*(i*T.x+t.x)+0],
										A[(8*row+5)*K+2*(i*T.x+t.x)+0],
										A[(8*row+6)*K+2*(i*T.x+t.x)+0],
										A[(8*row+7)*K+2*(i*T.x+t.x)+0]);
		
		a[4*(t.y*T.x+t.x)+3] = float4x4(A[(8*row+4)*K+2*(i*T.x+t.x)+1],
										A[(8*row+5)*K+2*(i*T.x+t.x)+1],
										A[(8*row+6)*K+2*(i*T.x+t.x)+1],
										A[(8*row+7)*K+2*(i*T.x+t.x)+1]);
		
		b[4*(t.y*T.x+t.x)+0] = float4x4(B[(8*(i*T.y+t.y)+0)*N+2*col+0],
										B[(8*(i*T.y+t.y)+1)*N+2*col+0],
										B[(8*(i*T.y+t.y)+2)*N+2*col+0],
										B[(8*(i*T.y+t.y)+3)*N+2*col+0]);
		
		b[4*(t.y*T.x+t.x)+1] = float4x4(B[(8*(i*T.y+t.y)+0)*N+2*col+1],
										B[(8*(i*T.y+t.y)+1)*N+2*col+1],
										B[(8*(i*T.y+t.y)+2)*N+2*col+1],
										B[(8*(i*T.y+t.y)+3)*N+2*col+1]);
		
		b[4*(t.y*T.x+t.x)+2] = float4x4(B[(8*(i*T.y+t.y)+4)*N+2*col+0],
										B[(8*(i*T.y+t.y)+5)*N+2*col+0],
										B[(8*(i*T.y+t.y)+6)*N+2*col+0],
										B[(8*(i*T.y+t.y)+7)*N+2*col+0]);
		
		b[4*(t.y*T.x+t.x)+3] = float4x4(B[(8*(i*T.y+t.y)+4)*N+2*col+1],
										B[(8*(i*T.y+t.y)+5)*N+2*col+1],
										B[(8*(i*T.y+t.y)+6)*N+2*col+1],
										B[(8*(i*T.y+t.y)+7)*N+2*col+1]);
		
		threadgroup_barrier( mem_flags::mem_threadgroup );
		for(uint k=0;k<T.x;++k) {
			c[0][0] += b[4*(k*T.x+t.x)+0] * a[4*(t.y*T.x+k)+0] + b[4*(k*T.x+t.x)+2] * a[4*(t.y*T.x+k)+1];
			c[0][1] += b[4*(k*T.x+t.x)+1] * a[4*(t.y*T.x+k)+0] + b[4*(k*T.x+t.x)+3] * a[4*(t.y*T.x+k)+1];
			c[1][0] += b[4*(k*T.x+t.x)+0] * a[4*(t.y*T.x+k)+2] + b[4*(k*T.x+t.x)+2] * a[4*(t.y*T.x+k)+3];
			c[1][1] += b[4*(k*T.x+t.x)+1] * a[4*(t.y*T.x+k)+2] + b[4*(k*T.x+t.x)+3] * a[4*(t.y*T.x+k)+3];
		}
		threadgroup_barrier( mem_flags::mem_threadgroup );
	}
	
	C[(8*row+0)*N+2*col+0] = c[0][0][0];
	C[(8*row+1)*N+2*col+0] = c[0][0][1];
	C[(8*row+2)*N+2*col+0] = c[0][0][2];
	C[(8*row+3)*N+2*col+0] = c[0][0][3];
	
	C[(8*row+0)*N+2*col+1] = c[0][1][0];
	C[(8*row+1)*N+2*col+1] = c[0][1][1];
	C[(8*row+2)*N+2*col+1] = c[0][1][2];
	C[(8*row+3)*N+2*col+1] = c[0][1][3];
	
	C[(8*row+4)*N+2*col+0] = c[1][0][0];
	C[(8*row+5)*N+2*col+0] = c[1][0][1];
	C[(8*row+6)*N+2*col+0] = c[1][0][2];
	C[(8*row+7)*N+2*col+0] = c[1][0][3];
	
	C[(8*row+4)*N+2*col+1] = c[1][1][0];
	C[(8*row+5)*N+2*col+1] = c[1][1][1];
	C[(8*row+6)*N+2*col+1] = c[1][1][2];
	C[(8*row+7)*N+2*col+1] = c[1][1][3];
}
kernel void gemm4(device float4 * const C [[ buffer(0) ]],
				  device const float4 * const A [[ buffer(1) ]],
				  device const float4 * const B [[ buffer(2) ]],
				  constant const uint & M [[ buffer(3) ]],
				  constant const uint & K [[ buffer(4) ]],
				  constant const uint & N [[ buffer(5) ]],
				  uint2 const g [[ threadgroup_position_in_grid ]],
				  uint2 const G [[ threadgroups_per_grid ]],
				  uint2 const t [[ thread_position_in_threadgroup ]],
				  uint2 const T [[ threads_per_threadgroup ]],
				  threadgroup float4x4 * block_a [[ threadgroup(0) ]],
				  threadgroup float4x4 * block_b [[ threadgroup(1) ]]
				  ){
	
	uint const cols = g.x * T.x + t.x;
	uint const rows = g.y * T.y + t.y;
	
	if(rows<M&&cols<N) {
		
		float4x4 c = float4x4(0.0);
		
		for ( uint i = 0, I = K ; i < I ; i += T.x ) {
			
			uint const rows_A = rows;
			uint const cols_A = i+t.x;
			
			uint4 const idx_A = (4 * rows_A + uint4(0,1,2,3)) * K + cols_A;
			
			block_a[t.y*T.x+t.x] = rows_A < M && cols_A < K ?
			float4x4(A[idx_A[0]],
					 A[idx_A[1]],
					 A[idx_A[2]],
					 A[idx_A[3]]) : float4x4(0.0);
			
			uint const rows_B = i+t.y;
			uint const cols_B = cols;
			
			uint4 const idx_B = (4 * rows_B + uint4(0,1,2,3)) * N + cols_B;
			
			block_b[t.y*T.x+t.x] = rows_B < K && cols_B < N ?
			float4x4(B[idx_B[0]],
					 B[idx_B[1]],
					 B[idx_B[2]],
					 B[idx_B[3]]) : float4x4(0.0);
			
			threadgroup_barrier( mem_flags::mem_threadgroup );
			
			for ( uint k = 0, K = T.x ; k < K ; ++ k )
				c += block_b[ k * T.x + t.x ] * block_a[ t.y * T.x + k ];
			
			threadgroup_barrier( mem_flags::mem_threadgroup );
		}
		uint4 const idx_C = ( 4 * rows + uint4(0, 1, 2, 3) ) * N + cols;
		C[idx_C[0]] = c[0];
		C[idx_C[1]] = c[1];
		C[idx_C[2]] = c[2];
		C[idx_C[3]] = c[3];
	}
}
kernel void gemm1(device float * const C [[ buffer(0) ]],
				 device const float * const A [[ buffer(1) ]],
				 device const float * const B [[ buffer(2) ]],
				 constant const uint & M [[ buffer(3) ]],
				 constant const uint & K [[ buffer(4) ]],
				 constant const uint & N [[ buffer(5) ]],
				 uint2 const g [[ threadgroup_position_in_grid ]],
				 uint2 const G [[ threadgroups_per_grid ]],
				 uint2 const t [[ thread_position_in_threadgroup ]],
				 uint2 const T [[ threads_per_threadgroup ]],
				 threadgroup float * a [[ threadgroup(0) ]],
				 threadgroup float * b [[ threadgroup(1) ]]
				 ){
	
	uint const col = g.x * T.x + t.x;
	uint const row = g.y * T.y + t.y;
	
	float c = 0.0;
	
	for(uint m = 0, M = K ; m < M ; m += T.x ) {
		a[t.y*T.x+t.x] = A[row*K+(m+t.x)];
		b[t.y*T.x+t.x] = B[(m+t.y)*N+col];
		threadgroup_barrier( mem_flags::mem_threadgroup );
		for(uint k=0;k<T.x;++k)
			c += a[t.y*T.x+k] * b[k*T.x+t.x];
		threadgroup_barrier( mem_flags::mem_threadgroup );
	}
	C[row*N+col] = c;
}
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
					  uint2 const m [[ threadgroup_position_in_grid ]],
					  uint2 const M [[ threadgroups_per_grid ]]
					  ) {
	uint const src = m.y * M.x + m.x;
	uint const dst = m.x * M.y + m.y;
	y[dst] = transpose(x[src]);
}
kernel void transpose_inplace(device float4x4 * y [[ buffer(0) ]],
							  uint2 const m [[ threadgroup_position_in_grid ]],
							  uint2 const M [[ threadgroups_per_grid ]]
							  ) {
	uint const src = m.y * M.x + m.x;
	uint const dst = m.x * M.y + m.y;
	float4x4 v = transpose(y[src]);
	threadgroup_barrier( mem_flags :: mem_device_and_threadgroup );
	y[dst] = v;
}