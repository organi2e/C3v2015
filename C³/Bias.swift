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
	internal func collect(let value level_value: MTLBuffer, let mean level_mean: MTLBuffer, let variance level_variance: MTLBuffer) {
		
		if let context: Context = managedObjectContext as? Context {
			
			let group: MTLSize = MTLSize(width: (rows-1)/4+1, height: 1, depth: 1)
			let local: MTLSize = MTLSize(width: (cols-1)/4+1, height: 1, depth: 1)
			
			let bias_value: MTLBuffer = value
			let bias_mean: MTLBuffer = mean
			let bias_variance: MTLBuffer = variance
			
			context.newComputeCommand(function: "biasCollect") {
				
				$0.setBuffer(level_value, offset: 0, atIndex: 0)
				$0.setBuffer(level_mean, offset: 0, atIndex: 1)
				$0.setBuffer(level_variance, offset: 0, atIndex: 2)
				$0.setBuffer(bias_value, offset: 0, atIndex: 3)
				$0.setBuffer(bias_mean, offset: 0, atIndex: 4)
				$0.setBuffer(bias_variance, offset: 0, atIndex: 5)
				
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
				
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
		}
		
	}
	internal func correctFF(let eps eps: Float, let mean delta_mean: MTLBuffer, let variance delta_variance: MTLBuffer) {
		
		if let context: Context = managedObjectContext as? Context {
			
			let group: MTLSize = MTLSize(width: (rows-1)/4+1, height: 1, depth: 1)
			let local: MTLSize = MTLSize(width: (cols-1)/4+1, height: 1, depth: 1)
			
			let bias_mean: MTLBuffer = mean
			let bias_logvariance: MTLBuffer = logvariance
			let bias_variance: MTLBuffer = variance
			
			context.newComputeCommand(function: "biasCorrectFF") {
				
				$0.setBuffer(bias_mean, offset: 0, atIndex: 0)
				$0.setBuffer(bias_logvariance, offset: 0, atIndex: 1)
				$0.setBuffer(bias_variance, offset: 0, atIndex: 2)
				$0.setBytes([eps], length: sizeof(Float), atIndex: 3)
				$0.setBuffer(delta_mean, offset: 0, atIndex: 4)
				$0.setBuffer(delta_variance, offset: 0, atIndex: 5)
				
				$0.dispatchThreadgroups(group, threadsPerThreadgroup: local)
				
			}
			
		} else {
			assertionFailure(Context.Error.InvalidContext.rawValue)
			
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