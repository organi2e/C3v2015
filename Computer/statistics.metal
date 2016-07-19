//
//  macro.metal
//  Mac
//
//  Created by Kota Nakano on 7/15/16.
//
//

#include <metal_stdlib>
using namespace metal;
float4 erf(float4);
kernel void normal(device float4 * random [[buffer(0)]],
				   device const float4 * const mu [[buffer(1)]],
				   device const float4 * const sigma [[buffer(2)]],
				   device const uint * const noise [[buffer(3)]],
				   uint const id [[thread_position_in_grid]]
				   ){
	float4 const n = unpack_unorm4x8_to_float(noise[id]);
	float2 const c = cospi(2.0*n.xy);
	float2 const s = sinpi(2.0*n.xy);
	float2 const l = sqrt(-2.0*log(saturate(n.zw+1.0/65536.0)));
	
	random[id].x = c.x*l.x;
	random[id].y = s.x*l.x;
	random[id].z = c.y*l.y;
	random[id].w = s.y*l.y;
	
	random[id].xz = c;
	random[id].yw = s;
	random[id].xy *= l.x;
	random[id].zw *= l.y;
	
	random[id] = random[id] * sigma[id] + mu[id];
}
kernel void pdf(device float4 * const p [[ buffer(0) ]],
				device const float4 * const x [[ buffer(1) ]],
				device const float4 * const u [[ buffer(2) ]],
				device const float4 * const s [[ buffer(3) ]],
				constant float const & M_1_SQRT2PI [[ buffer(4) ]],
				uint const id [[thread_position_in_grid]]
				) {
	float4 const lambda = ( x[id] - u[id] ) / s[id];
	p[id] = M_1_SQRT2PI / s[id] * exp( - lambda * lambda / 2.0 );
}
kernel void cdf(device float4 * const p [[ buffer(0) ]],
				device const float4 * const x [[ buffer(1) ]],
				device const float4 * const u [[ buffer(2) ]],
				device const float4 * const s [[ buffer(3) ]],
				constant float const & M_1_SQRT2 [[ buffer(4) ]],
				uint const id [[thread_position_in_grid]]
				) {
	float4 const lambda = ( x[id] - u[id] ) / s[id] / M_1_SQRT2;
	p[id] = 0.5 + 0.5 * erf(lambda);
}
