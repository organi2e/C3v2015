//
//  mtlart.metal
//  C³
//
//  Created by Kota Nakano on 8/19/16.
//
//

#include <metal_stdlib>
using namespace metal;

float4 artMu(float4 const);
float4 artMuInverse(float4 const);
float4 artMuGradient(float4 const);

float4 artSigma(float4 const);
float4 artSigmaInverse(float4 const);
float4 artSigmaGradient(float4 const);

float4 artMu(float4 const x) {
	return x;//tanh(x);
}
float4 artMuInverse(float4 const y) {
	return y;//atanh(y);
}
float4 artMuGradient(float4 const y) {
	return 1;// - y * y;
}

float4 artSigma(float4 const x) {
	return log(exp(x)+1.0);
}
float4 artSigmaInverse(float4 const y) {
	return log(exp(y)-1.0);
}
float4 artSigmaGradient(float4 const y) {
	return 1.0 - exp(-y);
}

kernel void artUniform(device float4 * const value [[ buffer(0) ]],
					   constant uint4 * const seeds [[ buffer(1) ]],
					   constant uint4 const & param [[ buffer(2) ]],
					   uint const t [[ thread_position_in_grid ]],
					   uint const T [[ threads_per_grid ]]) {
	uint const a = param.x;
	uint const b = param.y;
	uint const c = param.z;
	uint const K = param.w;
	uint4 seq = select(seeds[t], -1, seeds[t]==0);//avoid 0
	for ( uint k = t ; k < K ; k += T ) {
		seq ^= seq >> a;
		seq ^= seq << b;
		seq ^= seq >> c;
		value[k] = float4(seq)/4294967296.0;
	}
}
kernel void artShuffle(device float4 * const value [[ buffer(0) ]],
					   device const float4 * const mu [[ buffer(1) ]],
					   device const float4 * const sigma [[ buffer(2) ]],
					   device const float4 * const uniform [[ buffer(3) ]],
					   uint const n [[ thread_position_in_grid ]],
					   uint const N [[ threads_per_grid ]]) {
	value[n] = mu[n] + sigma[n] * uniform[n];
}
kernel void artRefresh(device float4 * const mu [[ buffer(0) ]],
					   device float4 * const sigma [[ buffer(1) ]],
					   device const float4 * const logmu [[ buffer(2) ]],
					   device const float4 * const logsigma [[ buffer(3) ]],
					   uint const n [[ thread_position_in_grid  ]],
					   uint const N [[ threads_per_grid  ]]) {
	mu[n] = artMu(logmu[n]);
	sigma[n] = artSigma(logsigma[n]);
}
kernel void artAdjust(device float4 * const logmu [[ buffer(0) ]],
					  device float4 * const logsigma [[ buffer(1) ]],
					  constant const float2 & params [[ buffer(2) ]],
					  uint const n [[ thread_position_in_grid  ]],
					  uint const N [[ threads_per_grid  ]]) {
	logmu[n] = artMuInverse(params.x);
	logsigma[n] = artSigmaInverse(params.y);
}

