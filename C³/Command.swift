//
//  Command.swift
//  C³
//
//  Created by Kota Nakano on 9/8/16.
//
//
import Metal

internal typealias Command = MTLCommandBuffer
internal typealias Compute = MTLComputeCommandEncoder
internal typealias Pipeline = MTLComputePipelineState
extension Compute {
	func dispatch(grid grid: (Int,Int,Int), threads: (Int, Int, Int)) {
		dispatchThreadgroups(MTLSize(width: grid.0, height: grid.1, depth: grid.2), threadsPerThreadgroup: MTLSize(width: threads.0, height: threads.1, depth: threads.2))
	}
}