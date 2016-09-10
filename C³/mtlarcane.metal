//
//  mtlarcane.metal
//  C³
//
//  Created by Kota Nakano on 9/8/16.
//
//

#include <metal_stdlib>
using namespace metal;
kernel void arcaneValue(device float4 * mu [[ buffer(0) ]],
						device float4 * sigma [[ buffer(1) ]],
						const device float4 * const logmu [[ buffer(2) ]],
						const device float4 * const logsigma [[ buffer(3) ]],
						uint const n [[ thread_position_in_grid ]],
						uint const N [[ threads_per_grid ]]) {
	mu [ n ] = logmu [ n ];
	sigma [ n ] = fast :: log ( fast :: exp ( logsigma [ n ] ) + 1 );
}
kernel void arcaneLogvalue(device float4 * const logmu [[ buffer(0) ]],
						   device float4 * const logsigma [[ buffer(1) ]],
						   const device float4 * const mu [[ buffer(2) ]],
						   const device float4 * const sigma [[ buffer(3) ]],
						   uint const n [[ thread_position_in_grid ]],
						   uint const N [[ threads_per_grid ]]
						   ) {
	logmu [ n ] = mu [ n ];
	logsigma [ n ] = fast :: log ( fast :: exp ( sigma [ n ] ) - 1);
}
kernel void arcaneGradient(device float4 * const gradmu [[ buffer(0) ]],
						   device float4 * const gradsigma [[ buffer(1) ]],
						   const device float4 * mu [[ buffer(2) ]],
						   const device float4 * sigma [[ buffer(3) ]],
						   uint const n [[ thread_position_in_grid ]],
						   uint const N [[ threads_per_grid ]]
						   ) {
	gradmu [ n ] = 1;
	gradsigma [ n ] = 1 - fast :: exp ( - sigma [ n ] );
}
kernel void arcaneRefresh(device float4 * mu [[ buffer(0) ]],
						  device float4 * sigma [[ buffer(1) ]],
						  device float4 * gradmu [[ buffer(2) ]],
						  device float4 * gradsigma [[ buffer(3) ]],
						  const device float4 * const logmu [[ buffer(4) ]],
						  const device float4 * const logsigma [[ buffer(5) ]],
						  uint const n [[ thread_position_in_grid ]],
						  uint const N [[ threads_per_grid ]]) {
	
	mu [ n ] = logmu [ n ];
	gradmu [ n ] = 1;
	
	float4 const s = fast :: exp ( logsigma [ n ] );
	float4 const S = s + 1;
	
	sigma [ n ] = fast :: log ( S );
	gradsigma [ n ] = s / S;
	
}