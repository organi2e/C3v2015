//
//  BlobTests.swift
//  Mac
//
//  Created by Kota Nakano on 7/23/16.
//
//
import Accelerate
import XCTest
@testable import C3

class GaussTests: XCTestCase {
	let NOHINT: la_hint_t = la_hint_t(LA_NO_HINT)
	let ATTR: la_attribute_t = la_attribute_t(LA_ATTRIBUTE_ENABLE_LOGGING)
	let context: Context = try!Context()
	func testRefresh() {
		guard let gauss: Gauss = new() else {
			XCTFail()
			return
		}
		let dmean: Float = Float(arc4random())/Float(UInt16.max)
		let dvariance: Float = Float(arc4random())/Float(UInt16.max)
		let rows: Int = 64
		let cols: Int = 64
		let count: Int = Int(rows*cols)
		
		gauss.resize(rows: rows, cols: cols)
		gauss.adjust(mean: dmean, variance: dvariance)
		gauss.refresh()
		
		let value: la_object_t = context.toLAObject(gauss.value, rows: count, cols: 1)
		
		var ymean: Float = 0.0
		var ydeviation: Float = 0.0
		
		let cache: [Float] = [Float](count: count, repeatedValue: 0.0)
		
		context.join()
		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, value)
		
		vDSP_meanv(UnsafePointer<Float>(cache), 1, &ymean, vDSP_Length(count))
		XCTAssert(!isnan(ymean))
		XCTAssert(!isinf(ymean))
		
		if 1e-1 < abs(log(ymean)-log(dmean)) {
			XCTFail("\(ymean) vs \(dmean)")
		}
		
		vDSP_vsadd(UnsafePointer<Float>(cache), 1, [-ymean], UnsafeMutablePointer<Float>(cache), 1, vDSP_Length(count))
		vDSP_rmsqv(UnsafePointer<Float>(cache), 1, &ydeviation, vDSP_Length(count))
		XCTAssert(!isnan(ydeviation))
		XCTAssert(!isinf(ydeviation))
		
		if 1e-1 < abs(2.0*log(ydeviation)-log(dvariance)) {
			XCTFail("\(ydeviation*ydeviation) vs \(dvariance)")
		}
	}
	func new() -> Gauss? {
		let gauss: Gauss? = context.new()
		gauss?.resize(rows: 4, cols: 4)
		return gauss
	}
}
