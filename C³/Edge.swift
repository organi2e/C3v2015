//
//  Edge.swift
//  iOS
//
//  Created by Kota Nakano on 6/1/16.
//
//
import Metal
import CoreData

internal class Edge: Cauchy {
	
}

extension Edge {
	@NSManaged internal var input: Cell
	@NSManaged internal var output: Cell
}

extension Edge {
	func collect(let level level: (MTLBuffer, MTLBuffer, MTLBuffer), let visit: Set<Cell>) {
		let state: MTLBuffer = input.collect(visit: visit)
		if let context: Context = managedObjectContext as? Context {
			self.dynamicType.collect(context: context, level: level, edge: (χ, μ, σ), state: state, rows: rows, cols: cols)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		
	}
	internal func correct(let δ δ: MTLBuffer, let η: Float, let state: MTLBuffer, let visit: Set<Cell>) {
		let Δ: (MTLBuffer, MTLBuffer, MTLBuffer) = output.correct(η: η, visit: visit)
		if let context: Context = managedObjectContext as? Context {
			func schedule() {
				willChangeValueForKey(self.dynamicType.logμkey)
				willChangeValueForKey(self.dynamicType.logσkey)
			}
			func complete() {
				didChangeValueForKey(self.dynamicType.logσkey)
				didChangeValueForKey(self.dynamicType.logμkey)
			}
			self.dynamicType.correctFF(context: context, η: η, δ: δ, edge: (logμ, logσ, χ, μ, σ), state: state, Δ: Δ, rows: rows, cols: cols, schedule: schedule, complete: complete)

		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
	}
}
extension Edge {
	internal class var collectKernel: String { return "edgeCollect" }
	internal class var correctFFKernel: String { return "edgeCorrectFF" }
	internal static func collect(let context context: Context, let level: (MTLBuffer, MTLBuffer, MTLBuffer), let edge: (MTLBuffer, MTLBuffer, MTLBuffer), let state: MTLBuffer, let rows: Int, let cols: Int, let bs: Int = 64) {
		
		context.newComputeCommand(function: collectKernel) {
			
			$0.setBuffer(level.0, offset: 0, atIndex: 0)
			$0.setBuffer(level.1, offset: 0, atIndex: 1)
			$0.setBuffer(level.2, offset: 0, atIndex: 2)
			$0.setBuffer(edge.0, offset: 0, atIndex: 3)
			$0.setBuffer(edge.1, offset: 0, atIndex: 4)
			$0.setBuffer(edge.2, offset: 0, atIndex: 5)
			$0.setBuffer(state, offset: 0, atIndex: 6)
			
			$0.setBytes([uint(rows/4), uint(cols/4)], length: sizeof(uint)*2, atIndex: 7)
			
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 0)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 1)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 2)
			
			$0.dispatchThreadgroups(MTLSize(width: rows/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: bs, height: 1, depth: 1))
			
		}
	}
	internal static func correctFF(let context context: Context, let η: Float, let δ: MTLBuffer, let edge: (MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer), let state: MTLBuffer, let Δ: (MTLBuffer, MTLBuffer, MTLBuffer), let rows: Int, let cols: Int, let bs: Int = 4, let schedule: (()->())?=nil, let complete:(()->())?=nil) {
		context.newComputeCommand(function: correctFFKernel, schedule: schedule, complete: complete) {
			$0.setBuffer(δ, offset: 0, atIndex: 0)
			$0.setBuffer(edge.0, offset: 0, atIndex: 1)
			$0.setBuffer(edge.1, offset: 0, atIndex: 2)
			$0.setBuffer(state, offset: 0, atIndex: 3)
			$0.setBuffer(edge.2, offset: 0, atIndex: 4)
			$0.setBuffer(edge.3, offset: 0, atIndex: 5)
			$0.setBuffer(edge.4, offset: 0, atIndex: 6)
			$0.setBuffer(Δ.0, offset: 0, atIndex: 7)
			$0.setBuffer(Δ.1, offset: 0, atIndex: 8)
			$0.setBuffer(Δ.2, offset: 0, atIndex: 9)
			$0.setBytes([η], length: sizeof(Float), atIndex: 10)
			$0.setBytes([uint(rows/4), uint(cols/4)], length: 2*sizeof(uint), atIndex: 11)
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
		edge.adjust(μ: 0, σ: 1/Float(input.width))
		edge.output = output
		edge.input = input
		return edge
	}
}
