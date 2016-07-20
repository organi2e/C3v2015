//
//  Gaussian.swift
//  Mac
//
//  Created by Kota Nakano on 7/20/16.
//
//
import Accelerate
import Foundation

let HINT: la_hint_t = la_hint_t(LA_NO_HINT)
let ATTR: la_attribute_t = la_attribute_t(LA_DEFAULT_ATTRIBUTES)

internal class LA {
	let buffer: [Float]
	let la: la_object_t
	init( let row: Int, let col: Int ){
		buffer = [Float](count: row*col, repeatedValue: 0.0)
		la = la_matrix_from_float_buffer_nocopy(UnsafeMutablePointer<Float>(buffer), la_count_t(row), la_count_t(col), la_count_t(col), LA.HINT, nil, LA.ATTR)
	}
	var pointer: UnsafeMutablePointer<Float> {
		return UnsafeMutablePointer<Float>(buffer)
	}
	var length: Int {
		return row * col
	}
	var row: Int {
		return Int(la_matrix_rows(la))
	}
	var col: Int {
		return Int(la_matrix_cols(la))
	}
	func fill ( let source: [Float] ) {
		assert(length==source.count)
		NSData(bytesNoCopy: UnsafeMutablePointer<Void>(source), length: sizeof(Float)*source.count, freeWhenDone: false).getBytes(UnsafeMutablePointer<Void>(buffer), length: sizeof(Float)*length)
	}
	func clear() {
		vDSP_vclr(UnsafeMutablePointer<Float>(buffer), 1, vDSP_Length(length))
	}
	func normal() {
		let W: [UInt32] = [UInt32](count: length, repeatedValue: 0)
		let N: [Float] = [Float](count: length, repeatedValue: 0)
		let H: Int = length / 2
		let L: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(N)
		let R: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(N).advancedBy(length/2)
		let P: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(buffer)
		let Q: UnsafeMutablePointer<Float> = UnsafeMutablePointer<Float>(buffer).advancedBy(length/2)
		
		arc4random_buf(UnsafeMutablePointer<Void>(W), sizeof(UInt32)*length)
		
		vDSP_vfltu32(W, 1, UnsafeMutablePointer<Float>(N), 1, vDSP_Length(length))
		
		vDSP_vsmul(R, 1, [Float(2.0)], R, 1, vDSP_Length(H))
		vDSP_vsadd(L, 1, [Float(1.0)], L, 1, vDSP_Length(H))
		vDSP_vsdiv(L, 1, [Float(4294967296.0)], L, 1, vDSP_Length(length))
		
		vvlogf(L, L, [Int32(H)])
		vDSP_vsmul(L, 1, [Float(-2.0)], L, 1, vDSP_Length(H))
		vvsqrtf(L, L, [Int32(H)])
		
		vvcospif(P, R, [Int32(H)])
		vDSP_vmul(L, 1, P, 1, P, 1, vDSP_Length(H))
		
		vvsinpif(Q, R, [Int32(H)])
		vDSP_vmul(L, 1, Q, 1, Q, 1, vDSP_Length(H))
		
	}
	static let HINT: la_hint_t = la_hint_t(LA_NO_HINT)
	static let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
}