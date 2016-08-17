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
};

vertex Vertex vertex_main(device float4 * const pos [[buffer(0)]],
						  uint id [[vertex_id]]) {
	return {pos[id]};
}
fragment float4 fragment_main(Vertex const vert [[stage_in]]) {
	return 1.0;
}
