//
//  Bias.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Accelerate
internal class Bias: Gauss {
	
}
extension Bias {
	@NSManaged internal var cell: Cell
}
extension Context {
	internal func newBias(let width width: UInt) throws -> Bias {
		guard let bias: Bias = new() else {
			throw Error.EntityError.InsertionFails(entity: className)
		}
		bias.resize(rows: width, cols: 1)
		return bias
	}
}