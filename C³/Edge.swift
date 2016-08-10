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
			Edge.collect(context: context,
			             level_value: level_value,
			             level_mean: level_mean,
			             level_variance: level_variance,
			             edge_value: value,
			             edge_mean: mean,
			             edge_variance: variance,
			             input_state: input.collect(visit: visit),
			             rows: rows,
			             cols: cols
			)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		
	}
	internal func correct(let eps eps: Float, let error input_error: MTLBuffer, let state input_state: MTLBuffer, let visit: Set<Cell>) {
		
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
				
				$0.setBytes([uint(edge_rows/4), uint(edge_cols/4)], length: 2*sizeof(uint), atIndex: 7)
				
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
				
			}
			
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		
		}
		
	}
}
extension Edge {
	internal static func collect(let context context: Context, let level_value: MTLBuffer, let level_mean: MTLBuffer, let level_variance: MTLBuffer, let edge_value: MTLBuffer, let edge_mean: MTLBuffer, let edge_variance: MTLBuffer, let input_state: MTLBuffer, let rows: Int, let cols: Int, let bs: Int = 64) {
		
		context.newComputeCommand(function: "edgeCollect") {
			
			$0.setBuffer(level_value, offset: 0, atIndex: 0)
			$0.setBuffer(level_mean, offset: 0, atIndex: 1)
			$0.setBuffer(level_variance, offset: 0, atIndex: 2)
			$0.setBuffer(edge_value, offset: 0, atIndex: 3)
			$0.setBuffer(edge_mean, offset: 0, atIndex: 4)
			$0.setBuffer(edge_variance, offset: 0, atIndex: 5)
			$0.setBuffer(input_state, offset: 0, atIndex: 6)
			
			$0.setBytes([uint(rows/4), uint(cols/4)], length: 2*sizeof(uint), atIndex: 7)
			
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 0)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 1)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 2)
			
			$0.dispatchThreadgroups(MTLSize(width: rows/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: bs, height: 1, depth: 1))
			
		}
	}
	internal static func correctFF(let context context: Context, let eps: Float, let mean: MTLBuffer, let logvariance: MTLBuffer, let delta: MTLBuffer, let variance: MTLBuffer, let state: MTLBuffer, let rows: Int, let cols: Int) {
		context.newComputeCommand(function: "edgeCorrectFF") {
			$0.setBuffer(mean, offset: 0, atIndex: 0)
			$0.setBuffer(logvariance, offset: 0, atIndex: 1)
			
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
