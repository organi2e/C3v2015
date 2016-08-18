//
//  mtlrender.metal
//  C³
//
//  Created by Kota Nakano on 8/17/16.
//
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
	float4 pos [[position]];
	float2 crd;
};

vertex Vertex planeview_vert(device float2 * const pos [[ buffer(0) ]],
							 constant bool2 const & inverse [[ buffer(1) ]],
							 uint id [[vertex_id]]) {
	return {
		float4(pos[id], float2(0, 1)),
		select(float2(0.5), float2(-0.5), inverse) * pos[id] + 0.5
	};
}
fragment float4 planeview_frag(Vertex const vert [[ stage_in ]],
								 texture2d<float> t [[ texture(0) ]],
								 sampler s [[ sampler(0) ]]) {
	return t.sample(s, vert.crd).xxxx;
}
