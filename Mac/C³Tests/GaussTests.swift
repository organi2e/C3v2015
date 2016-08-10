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
		
		guard let gauss: Gauss = context.new() else {
			XCTFail()
			return
		}
		
		let dmean: Float = Float(arc4random_uniform(256))/256.0-0.5
		let dvariance: Float = Float(1+arc4random_uniform(256))/256.0
		
		var ymean: Float = 0.0
		var yvariance: Float = 0.0
		
		let rows: Int = 256
		let cols: Int = 256
		
		gauss.resize(rows: rows, cols: cols)
		gauss.adjust(mean: dmean, variance: dvariance)
		gauss.shuffle()
		
		let value: la_object_t = context.toLAObject(gauss.value, rows: rows*cols, cols: 1)
		let cache: [Float] = [Float](count: rows*cols, repeatedValue: 0.0)
		
		context.join()

		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, value)
		
		vDSP_meanv(UnsafePointer<Float>(cache), 1, &ymean, vDSP_Length(rows*cols))
		XCTAssert(!isnan(ymean))
		XCTAssert(!isinf(ymean))
		
		var dump: Bool = false
		
		if 1e-1 < abs(log(ymean)-log(dmean)) {
			dump = true
			XCTFail("mean: \(ymean) vs \(dmean)")
		}
		
		vDSP_vsadd(UnsafePointer<Float>(cache), 1, [-ymean], UnsafeMutablePointer<Float>(cache), 1, vDSP_Length(rows*cols))
		vDSP_rmsqv(UnsafePointer<Float>(cache), 1, &yvariance, vDSP_Length(rows*cols))
		XCTAssert(!isnan(yvariance))
		XCTAssert(!isinf(yvariance))
		
		if 1e-1 < abs(2.0*log(yvariance)-log(dvariance)) {
			dump = true
			XCTFail("var.: \(yvariance) vs \(dvariance)")
		}
		
		if dump {
			(0..<rows).forEach {
				print(cache[$0*rows..<$0*rows+cols])
			}
		}
		
	}
}
