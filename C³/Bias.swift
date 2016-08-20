//
//  Bias.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Metal
internal class Bias: Cauchy {

}

extension Bias {
	@NSManaged internal var cell: Cell
	
}

extension Bias {
	internal func collect(let level level: (MTLBuffer, MTLBuffer, MTLBuffer)) {
		if let context: Context = managedObjectContext as? Context {
			self.dynamicType.collect(context: context, level: level, bias: (value, mu, sigma), rows: rows, cols: cols)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
	}
	internal func correctFF(let eps eps: Float, let delta: (MTLBuffer, MTLBuffer)) {
		if let context: Context = managedObjectContext as? Context {
			func schedule() {
				willChangeValueForKey(self.dynamicType.logmukey)
				willChangeValueForKey(self.dynamicType.logsigmakey)
			}
			func complete() {
				didChangeValueForKey(self.dynamicType.logsigmakey)
				didChangeValueForKey(self.dynamicType.logmukey)
			}
			self.dynamicType.correctFF(context: context, eps: eps, bias: (logmu, logsigma, mu, sigma), delta: delta, rows: rows, cols: cols, schedule: schedule, complete: complete)
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
	}
}
extension Bias {
	internal class var collectKernel: String { return "biasCollect" }
	internal class var correctFFKernel: String { return "biasCorrectFF" }
	internal static func collect(let context context: Context, let level: (MTLBuffer, MTLBuffer, MTLBuffer), let bias: (MTLBuffer, MTLBuffer, MTLBuffer), let rows: Int, let cols: Int) {
		context.newComputeCommand(function: collectKernel) {
			$0.setBuffer(level.0, offset: 0, atIndex: 0)
			$0.setBuffer(level.1, offset: 0, atIndex: 1)
			$0.setBuffer(level.2, offset: 0, atIndex: 2)
			$0.setBuffer(bias.0, offset: 0, atIndex: 3)
			$0.setBuffer(bias.1, offset: 0, atIndex: 4)
			$0.setBuffer(bias.2, offset: 0, atIndex: 5)
			$0.dispatchThreadgroups(MTLSize(width: rows*cols/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
		}
	}
	internal static func correctFF(let context context: Context, let eps: Float, let bias: (MTLBuffer, MTLBuffer, MTLBuffer, MTLBuffer), let delta: (MTLBuffer, MTLBuffer), let rows: Int, let cols: Int, let schedule: (()->())? = nil, let complete: (()->())? = nil) {
		context.newComputeCommand(function: correctFFKernel, schedule: schedule, complete: complete) {
			$0.setBuffer(bias.0, offset: 0, atIndex: 0)
			$0.setBuffer(bias.1, offset: 0, atIndex: 1)
			$0.setBuffer(bias.2, offset: 0, atIndex: 2)
			$0.setBuffer(bias.3, offset: 0, atIndex: 3)
			$0.setBuffer(delta.0, offset: 0, atIndex: 4)
			$0.setBuffer(delta.1, offset: 0, atIndex: 5)
			$0.setBytes([eps], length: sizeof(Float), atIndex: 6)
			$0.dispatchThreadgroups(MTLSize(width: rows*cols/4, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
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