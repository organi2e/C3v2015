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
}
extension Context {
	internal func newBias(let rows: UInt) throws -> Bias {
		guard let bias: Bias = new() else {
			throw NSError(domain: "", code: 0, userInfo: nil)
		}
		return bias
	}
}