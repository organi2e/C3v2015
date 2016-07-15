//
//  common.metal
//  C³
//
//  Created by Kota Nakano on 6/6/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void normal(device float4 * random [[buffer(0)]],
				   const device float4 * mu [[buffer(1)]],
				   const device float4 * sigma [[buffer(2)]],
				   const device uint * noise [[buffer(3)]],
				   const uint id [[thread_position_in_grid]]
				   ){
	float2 const radius = unpack_unorm2x16_to_float(noise[2*id+0]);
	float2 const radian = unpack_unorm2x16_to_float(noise[2*id+1]);
	
	float2 const s = sinpi(2.0*radian);
	float2 const c = cospi(2.0*radian);
	float2 const l = sqrt(-2.0*log(saturate(radius+1.0/65536.0)));
	
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
enum STAGE {
	CLEAR = 1 << 0,
	VALUE = 1 << 1,
	LUCKY = 1 << 2,
	STATE = 1 << 3,
	ERROR = 1 << 4,
	DELTA = 1 << 5,
};
kernel void state(device uint & stage [[buffer(0)]],
				  device float4 * state [[buffer(1)]],
				  const device float4 * lucky [[buffer(2)]],
				  const device uint * noise [[buffer(3)]],
				  const uint id [[ thread_position_in_grid]]) {
	if (stage|~STATE) {
		stage |= STATE;
		state [ id ] = step( unpack_unorm4x8_to_float( noise[ id ] ), lucky[ id ]);
	}
}
kernel void lucky(device float4 * lucky [[ buffer(0) ]],
				  const device float4 * value [[ buffer(1) ]],
				  const device float4 * basis [[ buffer(2) ]],
				  constant float & sigma [[ buffer(3) ]],
				  const uint id [[ thread_position_in_grid ]] ) {
	lucky [ id ] = 0.5 + 0.5 * tanh ( sigma * ( value[ id ] + basis[ id ] ) );
	
}
kernel void error(device float4 * error [[ buffer(0) ]],
				  const device float4 * state [[ buffer(1) ]],
				const device float4 * ideal [[ buffer(2) ]],
				constant float & eps[[ buffer(3) ]],
				uint id [[ thread_position_in_grid ]] ) {
	error [ id ] = ( ideal[ id ] - state[ id ] );
}
kernel void delta(device float4 * delta [[ buffer(0) ]],
				  const device float4 * error [[ buffer(1) ]],
				  const device float4 * lucky [[ buffer(2) ]],
				  const device uint * noise [[buffer(3)]],
				  constant float & sigma [[ buffer(4) ]],
				  uint id [[ thread_position_in_grid ]],
				  uint width [[ threads_per_grid ]]) {
	const float4 n = unpack_unorm4x8_to_float( noise[ id ] );
	//	const float4 e = sign ( error [ id ] ) + n;
	//	const float4 d = lucky [ id ] - n;
	//	const float4 e = sign ( error [ id ] ) * exp ( - 16 * d * d );
	const float4 e = sign ( error [ id ] ) * 4.0 * n * ( 1.0 - n );
	//	const float4 e = sign ( error [ id ] );// although faster learning, the formula is not accurately obtained
	delta [ id ] = ( 0.1 / width ) * e * 2.0 * sigma * lucky[ id ] * ( 1.0 - lucky[ id ] );
}
kernel void eval(device float2 * ans [[buffer(0)]],
				 const device uint * integer [[buffer(1)]],
				 const uint id [[thread_position_in_grid]]
				 ){
	ans[id] = log2(unpack_unorm2x16_to_float(integer[id]));
}