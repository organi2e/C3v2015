//
//  mtlgauss.metal
//  C³
//
//  Created by Kota Nakano on 8/6/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void gaussCDF(device float4 * const value [[ buffer(0) ]],
					 device const float4 * const mu [[ buffer(1) ]],
					 device const float4 * const lambda [[ buffer(2) ]],
					 constant const float & M_1_SQRT2 [[ buffer(3) ]],
					 uint const n [[ thread_position_in_grid ]],
					 uint const N [[ threads_per_grid ]]) {
	float4 const x = mu [ n ] * lambda [ n ] * M_1_SQRT2;
	float4 const t = 1 / ( 1 + 0.5 * abs ( x ) );
	float4 const c = 1 - t * fast :: exp ( - x * x -  1.26551223 + t * ( 1.00002368 + t * ( 0.37409196 + t * ( 0.09678418 + t * ( - 0.18628806 + t * ( 0.27886807 + t * ( - 1.13520398 + t * ( 1.48851587 + t * ( - 0.82215223 + t * ( 0.17087277 ) ) ) ) ) ) ) ) ) );//approximation of erf with Horner's method
	value [ n ] = 0.5 * ( 1 + select ( c, -c, x < 0 ) );
}
kernel void gaussPDF(device float4 * const value [[ buffer(0) ]],
					 device const float4 * const mu [[ buffer(1) ]],
					 device const float4 * const lambda [[ buffer(2) ]],
					 constant const float & M_1_SQRT2PI [[ buffer(3) ]],
					 uint const n [[ thread_position_in_grid ]],
					 uint const N [[ threads_per_grid ]]) {
	
	float4 const m = mu [ n ];
	float4 const l = lambda [ n ];
	float4 const v = m * l;
	
	value [ n ] = exp( - 0.5 * v * v ) * l * M_1_SQRT2PI;
	
}
kernel void gaussGradient(device float4 * const gradmu [[ buffer(0) ]],
						   device float4 * const gradsigma [[ buffer(1) ]],
						   const device float4 * const mu [[ buffer(2) ]],
						   const device float4 * const sigma [[ buffer(3) ]],
						   constant const float & M_1_SQRT2PI [[ buffer(4) ]],
						   uint const n [[ thread_position_in_grid ]],
						   uint const N [[ threads_per_grid ]]) {
	float4 const m = mu [ n ];
	float4 const l = lambda [ n ];
	float4 const v = m * l;
	float4 const p = exp( - 0.5 * v * v ) * M_1_SQRT2PI;
	gradmu[n] = p * l;
	gradsigma[n] = p * m;
}
kernel void gaussRNG(device float4 * const value [[ buffer(0) ]],
					 device const float4 * const mu [[ buffer(1) ]],
					 device const float4 * const sigma [[ buffer(2) ]],
					 constant uint4 * const seeds [[ buffer(3) ]],
					 constant uint4 const & param [[ buffer(4) ]],
					 uint const t [[ thread_position_in_grid ]],
					 uint const T [[ threads_per_grid ]]) {
	
	uint const a = param.x;
	uint const b = param.y;
	uint const c = param.z;
	uint const K = param.w;
	
	uint4 seq = select ( seeds [ t ], -1, seeds [ t ] == 0 );
	
	for ( uint k = t ; k < K ; k += T ) {
		
		float4 const u = ( float4 ( seq ) + 1 ) / 4294967296.0;
		value [ k ] = mu [ k ] + sigma [ k ] * float4( fast :: cospi( 2 * u.xy ), fast :: sinpi( 2 * u.xy ) ) * fast :: sqrt( -2 * fast :: log( u.zw ).xyxy );
		
		seq ^= seq >> a;
		seq ^= seq << b;
		seq ^= seq >> c;
		
	}
}
