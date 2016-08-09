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
	func collect(let value level_value: MTLBuffer, let mean level_mean: MTLBuffer, let variance level_variance: MTLBuffer, let visit: Set<Cell>) {
		
		if let context: Context = managedObjectContext as? Context {
			
			let input_state: MTLBuffer = input.collect(visit: visit)
			
			let bs: Int = 64
			
			let edge_rows: Int = rows/4
			let edge_cols: Int = cols/4
			
			let group: MTLSize = MTLSize(width: edge_rows, height: 1, depth: 1)
			let local: MTLSize = MTLSize(width: bs, height: 1, depth: 1)
			
			let edge_value: MTLBuffer = value
			let edge_mean: MTLBuffer = mean
			let edge_variance: MTLBuffer = variance
			
			let local_memry: Int = sizeof(Float)*16*bs
			
			context.newComputeCommand(function: "edgeCollect") {
				
				$0.setBuffer(level_value, offset: 0, atIndex: 0)
				$0.setBuffer(level_mean, offset: 0, atIndex: 1)
				$0.setBuffer(level_variance, offset: 0, atIndex: 2)
				$0.setBuffer(edge_value, offset: 0, atIndex: 3)
				$0.setBuffer(edge_mean, offset: 0, atIndex: 4)
				$0.setBuffer(edge_variance, offset: 0, atIndex: 5)
				$0.setBuffer(input_state, offset: 0, atIndex: 6)
				
				$0.setBytes([UInt32(edge_rows), UInt32(edge_cols)], length: 2*sizeof(UInt32), atIndex: 7)
				
				$0.setThreadgroupMemoryLength(local_memry, atIndex: 0)
				$0.setThreadgroupMemoryLength(local_memry, atIndex: 1)
				$0.setThreadgroupMemoryLength(local_memry, atIndex: 2)
				
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		
	}
	func correct(let eps eps: Float, let error input_error: MTLBuffer, let state input_state: MTLBuffer, let visit: Set<Cell>) {
		
		if let context: Context = managedObjectContext as? Context {
			
			let (delta_mean, delta_variance) = output.correct(eps: eps, visit: visit)
			
			let edge_mean: MTLBuffer = mean
			let edge_logvariance: MTLBuffer = logvariance
			let edge_variance: MTLBuffer = variance
			
			let group: MTLSize = MTLSize(width: rows/4, height: 1, depth: 1)
			let local: MTLSize = MTLSize(width: 16, height: 1, depth: 1)
			
			let edge_rows: Int = rows
			let edge_cols: Int = cols
			
			context.newComputeCommand(function: "edgeCorrect") {
				
				$0.setBuffer(edge_mean, offset: 0, atIndex: 0)
				$0.setBuffer(edge_logvariance, offset: 0, atIndex: 1)
				$0.setBuffer(edge_variance, offset: 0, atIndex: 2)
				$0.setBuffer(input_state, offset: 0, atIndex: 3)
				$0.setBytes([eps], length: sizeof(Float), atIndex: 4)
				$0.setBuffer(delta_mean, offset: 0, atIndex: 5)
				$0.setBuffer(delta_variance, offset: 0, atIndex: 6)
				
				$0.setBytes([UInt32(edge_rows/4)], length: sizeof(UInt32), atIndex: 7)
				$0.setBytes([UInt32(edge_cols/4)], length: sizeof(UInt32), atIndex: 8)
				
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
				
			}
			
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
		
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
