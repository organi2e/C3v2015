//
//  math.metal
//  C³
//
//  Created by Kota Nakano on 6/7/16.
//
//

#include <metal_stdlib>
using namespace metal;
float4 erf(float4);
float4 erf(float4 z) {
	float4 t = 1.0 / (1.0 + 0.5 * fabs(z));
	float4 ans = 1.0 - t * exp( -z*z -  1.26551223 +
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
	return sign(z) * ans;
}
kernel void sq(device float4 * const y [[ buffer(0) ]],
			   device const float4 * const x [[ buffer(1) ]],
			   uint const id [[thread_position_in_grid]]
			   ) {
	y[id] = x[id] * x[id];
}
kernel void sqrt(device float4 * const y [[ buffer(0) ]],
				 device const float4 * const x [[ buffer(1) ]],
				 uint const id [[thread_position_in_grid]]
				 ) {
	y[id] = sqrt(x[id]);
}
kernel void exp(device float4 * const y [[ buffer(0) ]],
				device const float4 * const x [[ buffer(1) ]],
				uint const id [[thread_position_in_grid]]
				) {
	y[id] = exp(x[id]);
}
kernel void log(device float4 * const y [[ buffer(0) ]],
				device const float4 * const x [[ buffer(1) ]],
				uint const id [[thread_position_in_grid]]
				) {
	y[id] = log(x[id]);
}