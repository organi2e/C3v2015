//
//  mtlcell.metal
//  C³
//
//  Created by Kota Nakano on 8/11/16.
//
//

#include<metal_stdlib>
using namespace metal;

float4 gaussCDF(float4 const, float4 const, float const);
float4 gaussPDF(float4 const, float4 const, float const);
float4 cauchyCDF(float4 const, float4 const, float const);
float4 cauchyPDF(float4 const, float4 const, float const);

kernel void cellActivate(device float4 * const state [[ buffer(0) ]],
						 device const float4 * const level [[ buffer(1) ]],
						 uint const t [[ thread_position_in_grid ]],
						 uint const T [[ threads_per_grid ]]
						 ) {
	state[t] = step(0.0, level[t]);
}
kernel void cellDerivate(device float4 * const delta_value [[ buffer(0) ]],
						 device float4 * const delta_mu [[ buffer(1) ]],
						 device float4 * const delta_sigma [[ buffer(2) ]],
						 device const float4 * const level_value [[ buffer(3) ]],
						 device const float4 * const level_mu [[ buffer(4) ]],
						 device const float4 * const level_sigma [[ buffer(5) ]],
						 device const float4 * const state_error [[ buffer(6) ]],
						 constant float const & M_PI [[ buffer(7) ]],
						 uint const t [[ thread_position_in_grid ]],
						 uint const T [[ threads_per_grid ]]
						 ) {
	float4 const mu = level_mu[t];
	float4 const sigma = level_sigma[t];
	float4 const value = mu / sigma;
	//float4 const pdf = cauchyPDF ( mu, sigma, M_PI);
	//float4 const cdf = cauchyCDF ( mu, sigma, M_PI);
	float4 const gradient = 1 / ( 1 + ( value ) * ( value ) );
	float4 const error = sign ( state_error[t] );
	float4 const delta = gradient * error;
	delta_value[t] = delta;
	delta_mu[t] = delta / sigma;
	delta_sigma[t] = - delta * mu;
}
kernel void cellDifference(device float4 * const error [[ buffer(0) ]],
						   device const float4 * const train [[ buffer(1) ]],
						   device const float4 * const state [[ buffer(2) ]],
						   uint const t [[ thread_position_in_grid ]],
						   uint const T [[ threads_per_grid ]]
						   ) {
	error[t] = train[t] - state[t];
}
kernel void cellForget(device float4 * const error [[ buffer(0) ]],
					   constant float const & rate [[ buffer(1) ]],
					   uint const t [[ thread_position_in_grid ]],
					   uint const T [[ threads_per_grid ]]
						   ) {
	error[t] *= rate;
}