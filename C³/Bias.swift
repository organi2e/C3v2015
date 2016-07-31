//
//  Bias.swift
//  C³
//
//  Created by Kota Nakano on 7/31/16.
//
//
import Foundation
internal class Bias: Alter {
	
}
extension Bias {

}
extension Context {
	internal func newBias(let rows: UInt) throws -> Bias {
		guard let bias: Bias = new() else {
			throw NSError(domain: "", code: 0, userInfo: nil)
		}
		bias.setValue(NSData(bytes: [Float](count: Int(rows), repeatedValue: 0), length: sizeof(Float)*Int(rows)), forKey: "mean")
		bias.setValue(NSData(bytes: [Float](count: Int(rows), repeatedValue: 0), length: sizeof(Float)*Int(rows)), forKey: "logvariance")
		return bias
	}
}