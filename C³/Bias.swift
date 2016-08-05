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
	override func setup() {
		super.setup()
		
	}
}
extension Bias {
	func collect() -> (MTLBuffer, MTLBuffer, MTLBuffer) {
		return(value, mean, variance)
	}
	func correct(let eps eps: Float, let deltamean: MTLBuffer, let deltavariance: MTLBuffer, let lambda: MTLBuffer?, let dydv: MTLBuffer, let feedback: MTLBuffer?) {
		guard let context: Context = managedObjectContext as? Context else {
			fatalError(Context.Error.InvalidContext.description)
		}
		context.axpy(mean, x: deltamean, alpha: eps)
		context.smvmv(logvariance, alpha: (-0.5*eps), a: deltavariance, b: variance)

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