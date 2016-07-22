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
				   device const uchar4 * const noise [[buffer(1)]],
				   uint const id [[thread_position_in_grid]]
				   ){
	float4 const n = (float4(noise[id])+1.0)/256.0;//( unpack_unorm4x8_to_float ( noise[id] ) * 255.0 + 1.0 ) / 256.0;
	float2 const c = cospi(2.0*n.xy);
	float2 const s = sinpi(2.0*n.xy);
	float2 const l = sqrt(-2.0*log(n.zw));
	
	random[id].xz = c;
	random[id].yw = s;
	random[id].xy *= l.x;
	random[id].zw *= l.y;
}
kernel void pdf(device float4 * const p [[ buffer(0) ]],
				device const float4 * const x [[ buffer(1) ]],
				device const float4 * const s [[ buffer(2) ]],
				constant float const & M_1_SQRT2PI [[ buffer(3) ]],
				uint const id [[thread_position_in_grid]]
				) {
	float4 const lambda = x[id] / s[id];
	p[id] = M_1_SQRT2PI / s[id] * exp ( - 0.5 * lambda * lambda );
}
kernel void cdf(device float4 * const p [[ buffer(0) ]],
				device const float4 * const x [[ buffer(1) ]],
				device const float4 * const s [[ buffer(2) ]],
				constant const float & M_SQRT1_2 [[ buffer(3) ]],
				uint const id [[thread_position_in_grid]]
				) {
	p[id] = 0.5 + 0.5 * erf( M_SQRT1_2 * x[id] / s[id] );
}

kernel void sigmoid(device float4 * const p [[ buffer(0) ]],
					device const float4 * const x [[ buffer(1) ]],
					uint const id [[thread_position_in_grid]]
					) {
	p[id] = 0.5 + 0.5 * tanh( 0.5 * x[id] );
}

