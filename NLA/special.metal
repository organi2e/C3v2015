//
//  Special.metal
//  C³
//
//  Created by Kota Nakano on 7/21/16.
//
//

#include <metal_stdlib>
using namespace metal;
float4 erf(float4);
float4 erf(float4 x) {
	float4 t = 1.0 / ( 1.0 + 0.5 * fabs(x) );
	float4 ans = 1.0 - t * exp( -x*x -  1.26551223 +
							   t * ( 1.00002368 +
									t * ( 0.37409196 +
										 t * ( 0.09678418 +
											  t * (-0.18628806 +
												   t * ( 0.27886807 +
														t * (-1.13520398 +
															 t * ( 1.48851587 +
																  t * (-0.82215223 +
																	   t * ( 0.17087277
																			))))))))));
	return sign(x) * ans;
}
kernel void step(device float4 * const y [[ buffer(0) ]],
				 device const float4 * const x [[ buffer(1) ]],
				 uint const id [[thread_position_in_grid]]
				 ) {
	y[id] = step(float4(0), x[id]);
}
kernel void sign(device float4 * const y [[ buffer(0) ]],
				 device const float4 * const x [[ buffer(1) ]],
				 uint const id [[thread_position_in_grid]]
				 ) {
	y[id] = sign(x[id]);
}