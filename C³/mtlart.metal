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
float4 artMuGradient(float4 const, float4 const);

float4 artSigma(float4 const);
float4 artSigmaInverse(float4 const);
float4 artSigmaGradient(float4 const, float4 const);

float4 artMu(float4 const x) {
	return x;//tanh(x);
}
float4 artMuInverse(float4 const y) {
	return y;//atanh(y);
}
float4 artMuGradient(float4 const y, float4 const x) {
	return 1;// - y * y;
}

float4 artSigma(float4 const x) {
	return exp(x);
}
float4 artSigmaInverse(float4 const y) {
	return log(y);
}
float4 artSigmaGradient(float4 const y, float4 const x) {
	return y;
}

kernel void artXorShift(device uint * const value [[ buffer(0) ]],
						device atomic_uint * const seed [[ buffer(1) ]],
						uint const n [[ thread_position_in_grid ]],
						uint const N [[ threads_per_grid ]]) {
	atomic_fetch_xor_explicit(seed, atomic_load_explicit(seed, memory_order_relaxed)<<13, memory_order_relaxed);
	atomic_fetch_xor_explicit(seed, atomic_load_explicit(seed, memory_order_relaxed)>>17, memory_order_relaxed);
	atomic_fetch_xor_explicit(seed, atomic_load_explicit(seed, memory_order_relaxed)<<5, memory_order_relaxed);
	value[n] = atomic_load_explicit(seed, memory_order_relaxed);
}

kernel void artShuffle(device float4 * const value [[ buffer(0) ]],
					   device const float4 * const mu [[ buffer(1) ]],
					   device const float4 * const sigma [[ buffer(2) ]],
					   device const ushort4 * const seed [[ buffer(3) ]],
					   uint const n [[ thread_position_in_grid ]],
					   uint const N [[ threads_per_grid ]]) {
	value[n] = mu[n] + sigma[n] * float4(seed[n])/65536.0;
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

