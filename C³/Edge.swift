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
	@NSManaged private var input: Cell
	@NSManaged private var output: Cell
}

extension Edge {
	func collect(let Φ Φ: (MTLBuffer, MTLBuffer, MTLBuffer)) {
		let ϰ: MTLBuffer = input.collect()
		if let context: Context = managedObjectContext as? Context {
			let rows: Int = output.width
			let cols: Int = input.width
			self.dynamicType.collect(context: context, Φ: Φ, edge: (χ, μ, σ), ϰ: ϰ, rows: rows, cols: cols)
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
	internal func correct(let δ δ: MTLBuffer, let η: Float, let ϰ: MTLBuffer) {
		let Δ: (MTLBuffer, MTLBuffer, MTLBuffer) = output.correct(η: η)
		if let context: Context = managedObjectContext as? Context {
			let rows: Int = output.width
			let cols: Int = input.width
			self.dynamicType.correctLightWeight(context: context, η: η, δ: δ, edge: (logμ, logσ, χ, μ, σ), ϰ: ϰ, Δ: Δ, rows: rows, cols: cols, schedule: willChange, complete: didChange)
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
		}
	}
	internal func iClear() {
		shuffle()
		input.iClear()
	}
	internal func oClear() {
		refresh()
		output.oClear()
	}
}
extension Edge {
	internal class var collectKernel: String { return "edgeCollect" }
	internal class var correctLightWeightKernel: String { return "edgeCorrectLightWeight" }
	internal static func collect(let context context: Context, let Φ: (MTLBuffer, MTLBuffer, MTLBuffer), let edge: (MTLBuffer, MTLBuffer, MTLBuffer), let ϰ: MTLBuffer, let rows: Int, let cols: Int, let bs: Int = 64) {
		
		context.newComputeCommand(function: collectKernel) {
			
			$0.setBuffer(Φ.0, offset: 0, atIndex: 0)
			$0.setBuffer(Φ.1, offset: 0, atIndex: 1)
			$0.setBuffer(Φ.2, offset: 0, atIndex: 2)
			$0.setBuffer(edge.0, offset: 0, atIndex: 3)
			$0.setBuffer(edge.1, offset: 0, atIndex: 4)
			$0.setBuffer(edge.2, offset: 0, atIndex: 5)
			$0.setBuffer(ϰ, offset: 0, atIndex: 6)
			
			$0.setBytes([uint(rows/4), uint(cols/4)], length: sizeof(uint)*2, atIndex: 7)
			
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 0)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 1)
			$0.setThreadgroupMemoryLength(sizeof(Float)*4*4*bs, atIndex: 2)
			
			$0.dispatchThreadgroups(MTLSize(width: rows/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: bs, height: 1, depth: 1))
			
		}
	}
	internal static func correctLightWeight(let context context: Context, let η: Float, let δ: MTLBuffer, let edge: (MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer), let ϰ: MTLBuffer, let Δ: (MTLBuffer, MTLBuffer, MTLBuffer), let rows: Int, let cols: Int, let bs: Int = 4, let schedule: (()->())?=nil, let complete:(()->())?=nil) {
		context.newComputeCommand(function: correctLightWeightKernel, schedule: schedule, complete: complete) {
			$0.setBuffer(δ, offset: 0, atIndex: 0)
			$0.setBuffer(edge.0, offset: 0, atIndex: 1)
			$0.setBuffer(edge.1, offset: 0, atIndex: 2)
			$0.setBuffer(ϰ, offset: 0, atIndex: 3)
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
		edge.output = output
		edge.input = input
		edge.resize(count: output.width*input.width)
		edge.adjust(μ: 0, σ: 1/Float(input.width))
		return edge
	}
}
