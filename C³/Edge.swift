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
	func collect(let level level: (MTLBuffer, MTLBuffer, MTLBuffer), let visit: Set<Cell>) {
		let state: MTLBuffer = input.collect(visit: visit)
		if let context: Context = managedObjectContext as? Context {
			Edge.collect(context: context, level: level, edge: (value, mean, variance), state: state, rows: rows, cols: cols)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		
	}
	internal func correct(let error error: MTLBuffer, let eps: Float, let state: MTLBuffer, let visit: Set<Cell>) {
		let delta: (MTLBuffer, MTLBuffer) = output.correct(eps: eps, visit: visit)
		if let context: Context = managedObjectContext as? Context {
			func schedule() {
				willChangeValueForKey(Edge.logmeankey)
				willChangeValueForKey(Edge.logvariancekey)
			}
			func complete() {
				didChangeValueForKey(Edge.logvariancekey)
				didChangeValueForKey(Edge.logmeankey)
			}
			//dump("v")
			Edge.correctFF(context: context, eps: eps, error: error, edge: (logmean, logvariance, mean, variance), state: state, delta: delta, rows: rows, cols: cols, schedule: schedule, complete: complete)
			//dump("d")
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
	}
}
extension Edge {
	internal static func collect(let context context: Context, let level: (MTLBuffer, MTLBuffer, MTLBuffer), let edge: (MTLBuffer, MTLBuffer, MTLBuffer), let state: MTLBuffer, let rows: Int, let cols: Int, let bs: Int = 64) {
		
		context.newComputeCommand(function: "edgeCollect") {
			
			$0.setBuffer(level.0, offset: 0, atIndex: 0)
			$0.setBuffer(level.1, offset: 0, atIndex: 1)
			$0.setBuffer(level.2, offset: 0, atIndex: 2)
			$0.setBuffer(edge.0, offset: 0, atIndex: 3)
			$0.setBuffer(edge.1, offset: 0, atIndex: 4)
			$0.setBuffer(edge.2, offset: 0, atIndex: 5)
			$0.setBuffer(state, offset: 0, atIndex: 6)
			
			$0.setBytes([uint(rows/4), uint(cols/4)], length: 2*sizeof(uint), atIndex: 7)
			
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 0)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 1)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 2)
			
			$0.dispatchThreadgroups(MTLSize(width: rows/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: bs, height: 1, depth: 1))
			
		}
	}
	internal static func correctFF(let context context: Context, let eps: Float, let error: MTLBuffer, let edge: (MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer), let state: MTLBuffer, let delta: (MTLBuffer, MTLBuffer), let rows: Int, let cols: Int, let bs: Int = 4, let schedule: (()->())?=nil, let complete:(()->())?=nil) {
		context.newComputeCommand(function: "edgeCorrectFF", schedule: schedule, complete: complete) {
			$0.setBuffer(error, offset: 0, atIndex: 0)
			$0.setBuffer(edge.0, offset: 0, atIndex: 1)
			$0.setBuffer(edge.1, offset: 0, atIndex: 2)
			$0.setBuffer(state, offset: 0, atIndex: 3)
			$0.setBuffer(edge.2, offset: 0, atIndex: 4)
			$0.setBuffer(edge.3, offset: 0, atIndex: 5)
			$0.setBuffer(delta.0, offset: 0, atIndex: 6)
			$0.setBuffer(delta.1, offset: 0, atIndex: 7)
			$0.setBytes([eps], length: sizeof(Float), atIndex: 8)
			$0.setBytes([uint(rows/4), uint(cols/4)], length: 2*sizeof(uint), atIndex: 9)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*bs, atIndex: 0)
			$0.dispatchThreadgroups(MTLSize(width: cols/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: bs, height: 1, depth: 1))
		}
	}

}
extension Context {
	internal func newEdge(let output output: Cell, let input: Cell) throws -> Edge {
		guard let edge: Edge = new() else {
			throw Error.CoreData.InsertionFails(entity: Cell.className())
		}
		edge.resize(rows: output.width, cols: input.width)
		edge.adjust(mean: 0, variance: 1/Float(input.width))//Xavier's initial value
		edge.output = output
		edge.input = input
		return edge
	}
}
