//
//  Bias.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Metal
internal class Bias: Gauss {

}

extension Bias {
	@NSManaged internal var cell: Cell
	
}

extension Bias {
	internal func collect(let context: Context, let level: (MTLBuffer, MTLBuffer, MTLBuffer)) {
		Bias.collect(context: context, level: level, bias: (value, mean, variance), rows: rows, cols: cols)
		
	}
	internal func correctFF(let context: Context, let eps: Float, let delta: (MTLBuffer, MTLBuffer)) {
		func schedule() {
			willChangeValueForKey(Bias.logmeankey)
			willChangeValueForKey(Bias.logvariancekey)
		}
		func complete() {
			didChangeValueForKey(Bias.logmeankey)
			didChangeValueForKey(Bias.logvariancekey)
		}
		Bias.correctFF(context: context, eps: eps, bias: (logmean, logvariance, mean, variance), delta: delta, rows: rows, cols: cols, schedule: schedule, complete: complete)
		
	}
}
extension Bias {
	internal static func collect(let context context: Context, let level: (MTLBuffer, MTLBuffer, MTLBuffer), let bias: (MTLBuffer, MTLBuffer, MTLBuffer), let rows: Int, let cols: Int) {
		context.newComputeCommand(function: "biasCollect") {
			$0.setBuffer(level.0, offset: 0, atIndex: 0)
			$0.setBuffer(level.1, offset: 0, atIndex: 1)
			$0.setBuffer(level.2, offset: 0, atIndex: 2)
			$0.setBuffer(bias.0, offset: 0, atIndex: 3)
			$0.setBuffer(bias.1, offset: 0, atIndex: 4)
			$0.setBuffer(bias.2, offset: 0, atIndex: 5)
			
			$0.dispatchThreadgroups(MTLSize(width: (rows-1)/4+1, height: 1, depth: 1),
			                        threadsPerThreadgroup: MTLSize(width: (cols-1)/4+1, height: 1, depth: 1))
		}
	}
	internal static func correctFF(let context context: Context, let eps: Float, let bias: (MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer), let delta: (MTLBuffer, MTLBuffer), let rows: Int, let cols: Int, let schedule: (()->())?=nil, let complete: (()->())?=nil) {
		context.newComputeCommand(function: "biasCorrect", schedule: schedule, complete: complete) {
			$0.setBuffer(bias.0, offset: 0, atIndex: 0)
			$0.setBuffer(bias.1, offset: 0, atIndex: 1)
			$0.setBuffer(bias.2, offset: 0, atIndex: 2)
			$0.setBuffer(bias.3, offset: 0, atIndex: 3)
			$0.setBuffer(delta.0, offset: 0, atIndex: 4)
			$0.setBuffer(delta.1, offset: 0, atIndex: 5)
			$0.setBytes([eps], length: sizeof(Float), atIndex: 6)
			$0.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1),
			                        threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
		
	}
}
extension Context {
	internal func newBias(let width width: Int) throws -> Bias {
		guard let bias: Bias = new() else {
			throw Error.CoreData.InsertionFails(entity: Bias.className())
		}
		bias.resize(rows: width, cols: 1)
		return bias
	}
}