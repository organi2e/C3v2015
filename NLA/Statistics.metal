//
//  Statistics.metal
//  C³
//
//  Created by Kota Nakano on 7/20/16.
//
//

#include <metal_stdlib>
using namespace metal;
float4 erf(float4);
kernel void normal(device float4 * random [[buffer(0)]],
				   device const uint * const noise [[buffer(3)]],
				   uint const id [[thread_position_in_grid]]
				   ){
	float4 const n = unpack_unorm4x8_to_float(noise[id]) + 1/256.0;
	float2 const c = cospi(2.0*n.xy);
	float2 const s = sinpi(2.0*n.xy);
	float2 const l = sqrt(-2.0*log(saturate(n.zw)));
	
	random[id].x = c.x*l.x;
	random[id].y = s.x*l.x;
	random[id].z = c.y*l.y;
	random[id].w = s.y*l.y;
	
	random[id].xz = c;
	random[id].yw = s;
	random[id].xy *= l.x;
	random[id].zw *= l.y;
}
kernel void pdf(device float4 * const p [[ buffer(0) ]],
				device const float4 * const x [[ buffer(1) ]],
				device const float4 * const u [[ buffer(2) ]],
				device const float4 * const s [[ buffer(3) ]],
				constant float const & M_1_SQRT2PI [[ buffer(4) ]],
				uint const id [[thread_position_in_grid]]
				) {
	float4 const lambda = ( x[id] - u[id] ) / s[id];
	p[id] = M_1_SQRT2PI / s[id] * exp ( - 0.5 * lambda * lambda );
}
kernel void cdf(device float4 * const p [[ buffer(0) ]],
				device const float4 * const x [[ buffer(1) ]],
				device const float4 * const u [[ buffer(2) ]],
				device const float4 * const s [[ buffer(3) ]],
				constant float const & M_1_SQRT2 [[ buffer(4) ]],
				uint const id [[thread_position_in_grid]]
				) {
	float4 const lambda = ( x[id] - u[id] ) * M_1_SQRT2 / s[id];
	p[id] = 0.5 + 0.5 * erf( lambda );
}

kernel void sigmoid(device float4 * const p [[ buffer(0) ]],
					device const float4 * const x [[ buffer(1) ]],
					uint const id [[thread_position_in_grid]]
					) {
	p[id] = 0.5 + 0.5 * tanh(x[id]);
}
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
