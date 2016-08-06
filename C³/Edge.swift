//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//
import Metal
import CoreData

internal class Edge: Gauss {
	
}
extension Edge {
	@NSManaged internal var input: Cell
	@NSManaged internal var output: Cell
}
extension Edge {
	func collect(let level level_value: MTLBuffer, let mean level_mean: MTLBuffer, let variance level_variance: MTLBuffer, let visit: Set<Cell>) {
		if let context: Context = managedObjectContext as? Context {
			
			let edge_value: MTLBuffer = value
			let edge_mean: MTLBuffer = mean
			let edge_variance: MTLBuffer = variance
			
			let group: MTLSize = MTLSize(width: (rows-1)/4+1, height: 1, depth: 1)
			let local: MTLSize = MTLSize(width: (cols-1)/4+1, height: 1, depth: 1)
			
			let input_state: MTLBuffer = input.collect(visit: visit)
			let local_memry: Int = sizeof(Float)*cols
			
			context.newComputeCommand(function: "edgeCollect") {
				
				$0.setBuffer(level_value, offset: 0, atIndex: 0)
				$0.setBuffer(level_mean, offset: 0, atIndex: 1)
				$0.setBuffer(level_variance, offset: 0, atIndex: 2)
				$0.setBuffer(edge_value, offset: 0, atIndex: 3)
				$0.setBuffer(edge_mean, offset: 0, atIndex: 4)
				$0.setBuffer(edge_variance, offset: 0, atIndex: 5)
				$0.setBuffer(input_state, offset: 0, atIndex: 6)
				
				$0.setThreadgroupMemoryLength(local_memry, atIndex: 0)
				$0.setThreadgroupMemoryLength(local_memry, atIndex: 1)
				$0.setThreadgroupMemoryLength(local_memry, atIndex: 2)
				
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		
	}
	func correct(let eps eps: Float, let visit: Set<Cell>) -> (MTLBuffer) {
		
		return value
	}
}
extension Context {
	internal func newEdge(let output output: Cell, let input: Cell) throws -> Edge {
		guard let edge: Edge = new() else {
			throw Error.CoreData.InsertionFails(entity: Cell.className())
		}
		edge.resize(rows: output.width, cols: input.width)
		edge.output = output
		edge.input = input
		return edge
	}
}
