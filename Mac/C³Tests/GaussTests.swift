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
		
		let dμ: Float = Float(arc4random_uniform(256))/128.0-1.0
		let dσ: Float = Float(1+arc4random_uniform(1024))/256.0
		
		var yμ: Float = 0.0
		var yσ: Float = 0.0
		
		let rows: Int = 1024//4*Int(1+arc4random_uniform(256))
		let cols: Int = 1024//4*Int(1+arc4random_uniform(256))
		
		gauss.resize(count: rows*cols)
		gauss.adjust(μ: dμ, σ: dσ)
		
		gauss.shuffle()
		
		let value: la_object_t = context.newLaObjectFromBuffer(gauss.χ, rows: rows*cols, cols: 1)
		let cache: [Float] = [Float](count: rows*cols, repeatedValue: 0.0)
		
		context.join()

		la_matrix_to_float_buffer(UnsafeMutablePointer<Float>(cache), 1, value)
		
		let fp = fopen("/tmp/gauss.raw", "wb")
		fwrite(cache, sizeof(Float), cache.count, fp)
		fclose(fp)
		
		vDSP_meanv(UnsafePointer<Float>(cache), 1, &yμ, vDSP_Length(rows*cols))
		XCTAssert(!isnan(yμ))
		XCTAssert(!isinf(yμ))
		
		var dump: Bool = false
		
		if 1e-2 < abs(log(yμ)-log(dμ)) {
			dump = true
			XCTFail("mean: \(yμ) vs \(dμ)")
		}
		
		vDSP_vsadd(UnsafePointer<Float>(cache), 1, [-yμ], UnsafeMutablePointer<Float>(cache), 1, vDSP_Length(rows*cols))
		vDSP_rmsqv(UnsafePointer<Float>(cache), 1, &yσ, vDSP_Length(rows*cols))
		XCTAssert(!isnan(yσ))
		XCTAssert(!isinf(yσ))
		
		if 1e-2 < abs(log(yσ)-log(dσ)) {
			dump = true
			XCTFail("var.: \(yσ) vs \(dσ)")
		}
		
		if dump {
			(0..<rows).forEach {
				print(cache[$0*rows..<$0*rows+cols])
			}
		}
		
		
		
	}
}
